(defpackage #:process-protocol
  (:use #:cl)
  (:nicknames #:stack-process)
  (:export #:process-error
           #:process-error-message
           #:process-error-command
           #:process-error-cause
           #:process-timeout-error
           #:process-timeout-error-timeout
           #:process-timeout-error-process
           #:process-signal-error
           #:process-signal-error-signum

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
           #:exit-code

           #:octet-vector
           #:windows-p
           #:merge-environment
           #:environment-strings
           #:normalize-capture
           #:normalize-element-type

           #:signal-number
           #:signal-name
           #:valid-signals
           #:set-signal
           #:get-signal
           #:raise-signal))

(in-package #:process-protocol)
