(in-package #:process-protocol)

(define-condition process-error (error)
  ((message :initarg :message :reader process-error-message :initform nil))
  (:report (lambda (c s)
             (format s "process error~@[: ~a~]" (process-error-message c)))))

(define-condition process-timeout-error (process-error) ())

(define-condition process-signal-error (process-error)
  ((signum :initarg :signum :reader process-signal-error-signum :initform nil))
  (:report (lambda (c s)
             (format s "process signal error~@[: ~a~]" (process-error-message c)))))
