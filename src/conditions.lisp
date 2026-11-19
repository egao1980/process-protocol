(in-package #:process-protocol)

(define-condition process-error (error)
  ((message :initarg :message :reader process-error-message :initform nil)
   (command :initarg :command :reader process-error-command :initform nil
            :documentation "The command that failed, as given to RUN / LAUNCH (or NIL).")
   (cause :initarg :cause :reader process-error-cause :initform nil
          :documentation "The underlying condition when a backend wraps one (or NIL)."))
  (:report (lambda (c s)
             (format s "process error~@[: ~a~]~@[ (~a)~]"
                     (process-error-message c)
                     (and (null (process-error-message c))
                          (process-error-cause c))))))

(define-condition process-timeout-error (process-error)
  ((timeout :initarg :timeout :reader process-timeout-error-timeout :initform nil
            :documentation "The timeout in seconds that expired.")
   (process :initarg :process :reader process-timeout-error-process :initform nil
            :documentation "The PROCESS-HANDLE of the child that did not finish in time."))
  (:documentation "TIMEOUT seconds passed before the child exited (BACKEND-RUN, PROCESS-WAIT).
Backends establish a CONTINUE restart that waits another TIMEOUT seconds.
BACKEND-RUN kills the child when control leaves it without that restart.")
  (:report (lambda (c s)
             (format s "process timed out after ~a s~@[: ~{~a~^ ~}~]"
                     (process-timeout-error-timeout c)
                     (let ((cmd (process-error-command c)))
                       (if (listp cmd) cmd (list cmd)))))))

(define-condition process-signal-error (process-error)
  ((signum :initarg :signum :reader process-signal-error-signum :initform nil))
  (:report (lambda (c s)
             (format s "process signal error~@[: ~a~]" (process-error-message c)))))
