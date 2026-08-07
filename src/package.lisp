(defpackage #:process-protocol
  (:use #:cl)
  (:nicknames #:stack-process)
  (:export #:process-error
           #:process-error-message
           #:process-timeout-error

           #:process-backend
           #:*process-backend*
           #:process-handle

           #:backend-run
           #:backend-launch
           #:process-wait
           #:process-kill
           #:process-alive-p
           #:process-stdin
           #:process-stdout
           #:process-stderr
           #:process-exit-code

           #:run
           #:launch
           #:wait
           #:kill
           #:alive-p
           #:stdin
           #:stdout
           #:stderr
           #:exit-code))

(in-package #:process-protocol)
