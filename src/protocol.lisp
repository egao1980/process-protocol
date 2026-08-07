(in-package #:process-protocol)

;;; Python subprocess / Java ProcessBuilder / UIOP — CLOS protocol only.
;;; RPC framing lives in rpc-protocol.

(defclass process-backend () ())

(defvar *process-backend* nil)

(defclass process-handle ()
  ()
  (:documentation "Opaque handle from LAUNCH. Backends subclass."))

(defun %ensure-backend (&optional (backend *process-backend*))
  (or backend
      (error 'process-error
             :message "*process-backend* is nil — load process-backend-uiop")))

(defgeneric backend-run (backend command &key input output error directory env
                          timeout discard-stderr shell)
  (:documentation "Sync run. → (values exit-code stdout-octets stderr-octets).
COMMAND is a list of strings (preferred) or a string with :SHELL T."))

(defgeneric backend-launch (backend command &key input output error directory env shell)
  (:documentation "Async spawn → PROCESS-HANDLE."))

(defgeneric process-wait (handle &key timeout)
  (:documentation "Block until exit. → exit-code. TIMEOUT seconds → process-timeout-error."))

(defgeneric process-kill (handle &key force))

(defgeneric process-alive-p (handle))

(defgeneric process-stdin (handle)
  (:documentation "Writable stream or NIL."))

(defgeneric process-stdout (handle)
  (:documentation "Readable stream or NIL."))

(defgeneric process-stderr (handle)
  (:documentation "Readable stream or NIL."))

(defgeneric process-exit-code (handle)
  (:documentation "Exit code if finished, else NIL."))

(defun run (command &rest keys &key (backend *process-backend*) &allow-other-keys)
  (let ((keys (copy-list keys)))
    (remf keys :backend)
    (apply #'backend-run (%ensure-backend backend) command keys)))

(defun launch (command &rest keys &key (backend *process-backend*) &allow-other-keys)
  (let ((keys (copy-list keys)))
    (remf keys :backend)
    (apply #'backend-launch (%ensure-backend backend) command keys)))

(defun wait (handle &key timeout)
  (process-wait handle :timeout timeout))

(defun kill (handle &key force)
  (process-kill handle :force force))

(defun alive-p (handle)
  (process-alive-p handle))

(defun stdin (handle) (process-stdin handle))
(defun stdout (handle) (process-stdout handle))
(defun stderr (handle) (process-stderr handle))
(defun exit-code (handle) (process-exit-code handle))
