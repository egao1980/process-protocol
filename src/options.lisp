(in-package #:process-protocol)

;;; Shared option semantics for BACKEND-RUN / BACKEND-LAUNCH.
;;; Pure functions: backends call them so every backend means the same thing.

(deftype octet-vector ()
  "What BACKEND-RUN returns for :OCTETS capture."
  '(simple-array (unsigned-byte 8) (*)))

(defun windows-p ()
  "True on Windows (feature :WIN32, :WINDOWS or :MSWINDOWS)."
  (and (or (member :win32 *features*)
           (member :windows *features*)
           (member :mswindows *features*))
       t))

;;; Environment

(defun %bad-env (entry)
  (error 'process-error
         :message (format nil "bad :env entry ~s — want (name . value) or \"NAME=VALUE\"" entry)))

(defun %env-entry (entry &key lenient)
  "ENTRY as (name . value). Strings are \"NAME=VALUE\". LENIENT keeps junk
inherited entries (no =) as name-only variables instead of signalling."
  (cond
    ((and (consp entry) (stringp (car entry))
          (or (null (cdr entry)) (stringp (cdr entry))))
     (cons (car entry) (cdr entry)))
    ((stringp entry)
     ;; Windows keeps per-drive entries like "=C:=C:\\" — the name may start with =.
     (let ((pos (position #\= entry :start (min 1 (length entry)))))
       (cond (pos (cons (subseq entry 0 pos) (subseq entry (1+ pos))))
             (lenient (cons entry ""))
             (t (%bad-env entry)))))
    (t (%bad-env entry))))

(defun merge-environment (env &key base (mode :merge) (case-insensitive (windows-p)))
  "The child environment for :ENV / :ENV-MODE, as an alist ((name . value) …).

ENV is a list whose entries are (name . value) conses or \"NAME=VALUE\"
strings (the 0.2 shape). A NIL value unsets the variable. Later entries win.
MODE :MERGE (default) starts from BASE (the inherited environment, same entry
shapes) and adds / overrides / unsets ENV. MODE :REPLACE ignores BASE: the
child sees ENV only. Names compare case-insensitively when CASE-INSENSITIVE
\(default: on Windows)."
  (check-type mode (member :merge :replace))
  (let ((test (if case-insensitive #'string-equal #'string=))
        (result '()))
    (flet ((put (entry)
             (setf result (remove (car entry) result :key #'car :test test))
             (when (cdr entry)
               (push entry result))))
      (when (eq mode :merge)
        (dolist (e base)
          (put (%env-entry e :lenient t))))
      (dolist (e env)
        (put (%env-entry e))))
    (nreverse result)))

(defun environment-strings (alist)
  "ALIST ((name . value) …) as a list of \"NAME=VALUE\" strings."
  (loop for (name . value) in alist
        collect (concatenate 'string name "=" value)))

;;; Capture / stream element types

(defun normalize-capture (spec &optional (key :output))
  "BACKEND-RUN :OUTPUT / :ERROR-OUTPUT designator → :OCTETS, :STRING or NIL.
:OCTETS or (UNSIGNED-BYTE 8) → exact bytes (OCTET-VECTOR); :STRING or
CHARACTER → string decoded with :EXTERNAL-FORMAT; NIL → discarded (an empty
OCTET-VECTOR is returned)."
  (cond
    ((null spec) nil)
    ((or (eq spec :octets) (equal spec '(unsigned-byte 8))) :octets)
    ((or (eq spec :string) (eq spec 'character)) :string)
    (t (error 'process-error
              :message (format nil "bad ~s ~s — want :octets, :string or NIL" key spec)))))

(defun normalize-element-type (spec)
  "BACKEND-LAUNCH :ELEMENT-TYPE designator → CHARACTER or (UNSIGNED-BYTE 8).
NIL, :STRING or CHARACTER → CHARACTER; :OCTETS or (UNSIGNED-BYTE 8) → octets."
  (cond
    ((or (null spec) (eq spec :string) (eq spec 'character)) 'character)
    ((or (eq spec :octets) (equal spec '(unsigned-byte 8))) '(unsigned-byte 8))
    (t (error 'process-error
              :message (format nil "bad :element-type ~s — want :octets or CHARACTER" spec)))))
