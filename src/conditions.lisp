(in-package #:process-protocol)

(define-condition process-error (error)
  ((message :initarg :message :reader process-error-message :initform nil))
  (:report (lambda (c s)
             (format s "process error~@[: ~a~]" (process-error-message c)))))

(define-condition process-timeout-error (process-error) ())
