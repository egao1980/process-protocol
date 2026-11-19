(in-package #:process-protocol/tests)

;;; 0.4.0: process groups, tree kill, pid, capability query (#9).
;;; RECORDING-BACKEND is defined in protocol-test.lisp.

(defclass recording-handle (process-protocol:process-handle)
  ((kills :initform '() :accessor handle-kills)))

(defmethod process-protocol:process-kill ((h recording-handle) &rest keys &key force tree)
  (declare (ignore force tree))
  (push keys (handle-kills h))
  t)

(defmethod process-protocol:process-pid ((h recording-handle))
  4242)

(defmethod process-protocol:backend-supports-p ((b recording-backend) (capability (eql :pid)))
  t)

(deftest kill-forwards-tree
  (let ((h (make-instance 'recording-handle)))
    (process-protocol:kill h :tree t :force t)
    (process-protocol:kill h)
    (let ((calls (reverse (handle-kills h))))
      (ok (eq t (getf (first calls) :tree)))
      (ok (eq t (getf (first calls) :force)))
      (ng (getf (second calls) :tree))
      (ng (getf (second calls) :force)))))

(deftest launch-and-run-forward-process-group
  (let ((b (make-instance 'recording-backend)))
    (process-protocol:launch '("sh") :backend b :process-group t)
    (ok (eq t (getf (cdr (first (backend-calls b))) :process-group)))
    (process-protocol:run '("sh") :backend b :process-group t :timeout 1)
    (ok (eq t (getf (cdr (first (backend-calls b))) :process-group)))))

(deftest pid-default-and-facade
  (ok (null (process-protocol:pid (make-instance 'process-protocol:process-handle))))
  (ok (eql 4242 (process-protocol:pid (make-instance 'recording-handle)))))

(deftest supports-p-default-nil
  (let ((b (make-instance 'recording-backend)))
    (ng (process-protocol:supports-p :process-group :backend b))
    (ng (process-protocol:supports-p :no-such-capability :backend b))
    (ok (process-protocol:supports-p :pid :backend b))
    (let ((process-protocol:*process-backend* b))
      (ok (process-protocol:supports-p :pid)))))

(deftest supports-p-no-backend
  (let ((process-protocol:*process-backend* nil))
    (ok (signals (process-protocol:supports-p :pid) 'process-protocol:process-error))))

(deftest group-error-condition
  (let* ((h (make-instance 'process-protocol:process-handle))
         (c (make-condition 'process-protocol:process-group-error
                            :command '("sh") :process h)))
    (ok (typep c 'process-protocol:process-error))
    (ok (eq h (process-protocol:process-group-error-process c)))
    (ok (search "process group" (princ-to-string c)))))
