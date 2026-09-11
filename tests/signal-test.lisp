(in-package #:process-protocol/tests)

(deftest valid-signals-include-int-term
  (let ((names (process-protocol:valid-signals)))
    (ok (member :int names))
    (ok (member :term names))
    (ok (integerp (process-protocol:signal-number :int)))
    (ok (integerp (process-protocol:signal-number :sigterm)))
    (ok (eq :int (process-protocol:signal-name (process-protocol:signal-number :int))))))

(deftest unknown-signal
  (ok (signals (process-protocol:signal-number :not-a-signal)
               'process-protocol:process-signal-error)))

(deftest cannot-catch-kill
  (when (member :kill (process-protocol:valid-signals))
    (ok (signals (process-protocol:set-signal :kill :ignore)
                 'process-protocol:process-signal-error))))

(deftest set-get-ignore
  (unwind-protect
       (progn
         (process-protocol:set-signal :term :ignore)
         (ok (eq :ignore (process-protocol:get-signal :term))))
    (process-protocol:set-signal :term :default)))

(deftest raise-caught
  ;; USR1 is Unix-only; TERM is the portable CRT signal on Windows.
  (let ((name (if (member :usr1 (process-protocol:valid-signals)) :usr1 :term))
        (seen nil))
    (unwind-protect
         (progn
           (process-protocol:set-signal name (lambda (signo)
                                               (setf seen signo)))
           (process-protocol:raise-signal name)
           (sleep 0.15)
           (ok (eql seen (process-protocol:signal-number name))))
      (process-protocol:set-signal name :default))))
