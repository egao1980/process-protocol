(in-package #:process-protocol/tests)

(deftest no-backend-signals
  (let ((process-protocol:*process-backend* nil))
    (ok (signals (process-protocol:run '("true"))
                 'process-protocol:process-error))))

;;; A recording backend: the facade forwards the 0.3 keys unchanged.

(defclass recording-backend (process-protocol:process-backend)
  ((calls :initform '() :accessor backend-calls)))

(defmethod process-protocol:backend-run
    ((b recording-backend) command &rest keys
     &key input output error-output error directory env env-mode timeout
       discard-stderr shell external-format process-group)
  (declare (ignore input output error-output error directory env env-mode timeout
                   discard-stderr shell external-format process-group))
  (push (cons command keys) (backend-calls b))
  (values 0 (make-array 0 :element-type '(unsigned-byte 8))
          (make-array 0 :element-type '(unsigned-byte 8))))

(defmethod process-protocol:backend-launch
    ((b recording-backend) command &rest keys
     &key input output error-output error directory env env-mode shell
       element-type external-format process-group)
  (declare (ignore input output error-output error directory env env-mode shell
                   element-type external-format process-group))
  (push (cons command keys) (backend-calls b))
  (make-instance 'process-protocol:process-handle))

(deftest run-forwards-keys
  (let ((b (make-instance 'recording-backend)))
    (process-protocol:run '("x") :backend b :env '(("A" . "1")) :env-mode :replace
                                 :output :string :error-output nil :timeout 2)
    (let ((call (first (backend-calls b))))
      (ok (equal '("x") (car call)))
      (ok (eq :replace (getf (cdr call) :env-mode)))
      (ok (eq :string (getf (cdr call) :output)))
      (ok (= 2 (getf (cdr call) :timeout)))
      (ng (getf (cdr call) :backend)))))

(deftest launch-forwards-element-type
  (let ((b (make-instance 'recording-backend)))
    (process-protocol:launch '("cat") :backend b :element-type :octets)
    (ok (eq :octets (getf (cdr (first (backend-calls b))) :element-type)))))

;;; Conditions

(deftest timeout-error-slots
  (let* ((h (make-instance 'process-protocol:process-handle))
         (c (make-condition 'process-protocol:process-timeout-error
                            :command '("sleep" "10") :timeout 1 :process h)))
    (ok (typep c 'process-protocol:process-error))
    (ok (equal '("sleep" "10") (process-protocol:process-error-command c)))
    (ok (= 1 (process-protocol:process-timeout-error-timeout c)))
    (ok (eq h (process-protocol:process-timeout-error-process c)))
    (ok (search "sleep 10" (princ-to-string c)))))

(deftest error-cause-slot
  (let* ((cause (make-condition 'simple-error :format-control "boom" :format-arguments '()))
         (c (make-condition 'process-protocol:process-error :cause cause)))
    (ok (eq cause (process-protocol:process-error-cause c)))
    (ok (search "boom" (princ-to-string c)))))
