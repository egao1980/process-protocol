(in-package #:process-protocol)

;;; Python signal — current-process handlers. Child kill stays PROCESS-KILL.
;;; Unix: SBCL enable-interrupt + unix-kill.
;;; Windows: in-process dispatch (no enable-interrupt). CRT names only.

(defparameter *signal-aliases*
  '((:sigint . :int) (:sigterm . :term) (:sighup . :hup) (:sigquit . :quit)
    (:sigill . :ill) (:sigtrap . :trap) (:sigabrt . :abrt) (:sigfpe . :fpe)
    (:sigkill . :kill) (:sigsegv . :segv) (:sigpipe . :pipe) (:sigalrm . :alrm)
    (:sigusr1 . :usr1) (:sigusr2 . :usr2) (:sigchld . :chld) (:sigcont . :cont)
    (:sigstop . :stop) (:sigtstp . :tstp) (:sigbreak . :break)))

(defparameter *windows-signal-numbers*
  '((:int . 2) (:ill . 4) (:fpe . 8) (:segv . 11)
    (:term . 15) (:break . 21) (:abrt . 22)))

(defparameter *uncatchable-signals* '(:kill :stop))

(defvar *signal-handlers* (make-hash-table :test #'eql))
(defvar *signal-table* nil)
(defvar *signal-by-number* nil)

(defun %sbcl-symbol (package name)
  (let ((pkg (find-package package)))
    (and pkg (find-symbol name pkg))))

(defun %sbcl-bound (package name)
  (let ((sym (%sbcl-symbol package name)))
    (when (and sym (boundp sym))
      (symbol-value sym))))

(defun %sbcl-fbound (package name)
  (let ((sym (%sbcl-symbol package name)))
    (when (and sym (fboundp sym))
      sym)))

(defun %sbcl-signal-number (posix-name)
  (or (%sbcl-bound :sb-unix posix-name)
      (%sbcl-bound :sb-posix posix-name)))

(defun %canonical-name (name)
  (or (cdr (assoc name *signal-aliases* :test #'eq))
      name))

(defun %build-signal-table ()
  (let ((names '(:hup :int :quit :ill :trap :abrt :fpe :kill :segv :pipe
                 :alrm :term :usr1 :usr2 :chld :cont :stop :tstp :break))
        (table (make-hash-table :test #'eq))
        (by-number (make-hash-table :test #'eql)))
    (dolist (name names)
      (let* ((posix (format nil "SIG~A" (symbol-name name)))
             (n (or (%sbcl-signal-number posix)
                    (let ((win (cdr (assoc name *windows-signal-numbers* :test #'eq))))
                      (when (and win (or (find :win32 *features*)
                                         (find :windows *features*)))
                        win)))))
        (when n
          (setf (gethash name table) n
                (gethash n by-number) name))))
    (values table by-number)))

(defun %ensure-signal-table ()
  (unless *signal-table*
    (multiple-value-bind (table by-number) (%build-signal-table)
      (setf *signal-table* table
            *signal-by-number* by-number)))
  *signal-table*)

(defun signal-number (name)
  "Keyword or integer → integer signo."
  (etypecase name
    (integer name)
    (keyword
     (let ((canon (%canonical-name name)))
       (or (gethash canon (%ensure-signal-table))
           (restart-case
               (error 'process-signal-error
                      :signum name
                      :message (format nil "unknown signal ~S" name))
             (use-value (replacement)
               :report "Use a replacement signal name or number"
               (signal-number replacement))))))))

(defun signal-name (signum)
  "Integer → keyword, or NIL if unknown."
  (check-type signum integer)
  (%ensure-signal-table)
  (gethash signum *signal-by-number*))

(defun valid-signals ()
  "Keywords this image can name. Always includes :INT and :TERM on SBCL / Windows CRT."
  (let ((keys '()))
    (maphash (lambda (k v)
               (declare (ignore v))
               (push k keys))
             (%ensure-signal-table))
    (sort keys #'string< :key #'symbol-name)))

(defun %windows-p ()
  (or (find :win32 *features*) (find :windows *features*)))

(defun %pid ()
  (let ((fn (or (%sbcl-fbound :sb-unix "UNIX-GETPID")
                (%sbcl-fbound :sb-posix "GETPID"))))
    (unless fn
      (error 'process-signal-error :message "cannot determine pid"))
    (funcall fn)))

(defun %enable-interrupt (signo handler)
  (let ((fn (%sbcl-fbound :sb-sys "ENABLE-INTERRUPT")))
    (unless fn
      (error 'process-signal-error :message "enable-interrupt not available"))
    (funcall fn signo handler)))

(defun %raise (signo)
  (let ((unix-kill (%sbcl-fbound :sb-unix "UNIX-KILL"))
        (posix-kill (%sbcl-fbound :sb-posix "KILL")))
    (cond
      (unix-kill
       (multiple-value-bind (status errno) (funcall unix-kill (%pid) signo)
         ;; SBCL unix-kill: 0 / T = success; NIL + errno = failure.
         (when (null status)
           (error 'process-signal-error
                  :signum signo
                  :message (format nil "unix-kill failed~@[ errno ~A~]" errno)))))
      (posix-kill
       (funcall posix-kill (%pid) signo))
      (t
       (error 'process-signal-error
              :signum signo
              :message "raise-signal not available on this image")))))

(defun %wrap-handler (fn)
  (lambda (signo info context)
    (declare (ignore info context))
    (funcall fn signo)))

(defun set-signal (name handler)
  "Install HANDLER for NAME. HANDLER is :DEFAULT, :IGNORE, or a function of signum.
   :KILL and :STOP cannot be caught."
  (let* ((canon (if (keywordp name) (%canonical-name name) (or (signal-name name) name)))
         (signo (signal-number name)))
    (when (and (keywordp canon) (member canon *uncatchable-signals* :test #'eq))
      (error 'process-signal-error
             :signum canon
             :message (format nil "cannot catch ~S" canon)))
    (unless (or (eq handler :default) (eq handler :ignore) (functionp handler))
      (error 'process-signal-error
             :signum signo
             :message "handler must be :default, :ignore, or a function"))
    (setf (gethash signo *signal-handlers*) handler)
    (unless (%windows-p)
      (%enable-interrupt signo
                         (cond
                           ((eq handler :default) :default)
                           ((eq handler :ignore) :ignore)
                           (t (%wrap-handler handler)))))
    handler))

(defun get-signal (name)
  "Last handler installed via SET-SIGNAL, or :DEFAULT if we never set it."
  (let ((signo (signal-number name)))
    (gethash signo *signal-handlers* :default)))

(defun %raise-windows (signo)
  (let ((handler (gethash signo *signal-handlers* :default)))
    (cond
      ((eq handler :ignore) t)
      ((functionp handler)
       (funcall handler signo)
       t)
      (t
       (error 'process-signal-error
              :signum signo
              :message "Windows raise-signal invokes a Lisp handler; :default is not run")))))

(defun raise-signal (name)
  "Send NAME to this process. Unix: OS signal. Windows: in-process handler."
  (let ((signo (signal-number name)))
    (if (%windows-p)
        (%raise-windows signo)
        (%raise signo)))
  t)
