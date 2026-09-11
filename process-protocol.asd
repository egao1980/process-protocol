(defsystem "process-protocol"
  :version "0.2.0"
  :description "CLOS subprocess protocol for cl-stack (run/launch/wait/kill + signal)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()

  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol")
               (:file "signals"))
  :in-order-to ((test-op (test-op "process-protocol/tests"))))

(defsystem "process-protocol/tests"
  :depends-on ("process-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "signal-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
