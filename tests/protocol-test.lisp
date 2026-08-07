(in-package #:process-protocol/tests)

(deftest no-backend-signals
  (let ((process-protocol:*process-backend* nil))
    (ok (signals (process-protocol:run '("true"))
                 'process-protocol:process-error))))
