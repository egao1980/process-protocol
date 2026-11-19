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

(defgeneric backend-run (backend command &key input output error-output error
                                              directory env env-mode timeout
                                              discard-stderr shell external-format)
  (:documentation "Sync run. → (values exit-code stdout stderr).
COMMAND is a list of strings (preferred) or a string with :SHELL T.

INPUT: NIL (no input), a string (encoded with EXTERNAL-FORMAT), an octet
vector (written as is), a pathname (the file), or an input stream (copied).
OUTPUT / ERROR-OUTPUT: :OCTETS (default) → exact bytes, an OCTET-VECTOR, never
decoded; :STRING → decoded with EXTERNAL-FORMAT; NIL → discarded (empty
OCTET-VECTOR). (UNSIGNED-BYTE 8) and CHARACTER are accepted for :OCTETS and
:STRING (see NORMALIZE-CAPTURE). ERROR is the 0.2 name of ERROR-OUTPUT;
DISCARD-STDERR T means ERROR-OUTPUT NIL.
EXTERNAL-FORMAT: encoding for string INPUT / :STRING capture, default :UTF-8.
ENV / ENV-MODE: see MERGE-ENVIRONMENT. ENV entries are (name . value) or
\"NAME=VALUE\"; :MERGE (default) adds to the inherited environment, NIL value
unsets; :REPLACE gives the child exactly ENV. Program lookup uses the parent's
PATH.
TIMEOUT: seconds (real) or NIL. When it expires the backend signals
PROCESS-TIMEOUT-ERROR (command, timeout, process handle) with a CONTINUE
restart that waits another TIMEOUT seconds. Leaving BACKEND-RUN any other way
kills the child."))

(defgeneric backend-launch (backend command &key input output error-output error
                                                 directory env env-mode shell
                                                 element-type external-format)
  (:documentation "Async spawn → PROCESS-HANDLE.
INPUT / OUTPUT / ERROR-OUTPUT: NIL → :STREAM (a pipe, see PROCESS-STDIN /
PROCESS-STDOUT / PROCESS-STDERR), or a pathname, :OUTPUT (error-output only),
:INTERACTIVE, as UIOP:LAUNCH-PROGRAM. ERROR is the 0.2 name of ERROR-OUTPUT.
ELEMENT-TYPE: CHARACTER (default) or :OCTETS / (UNSIGNED-BYTE 8) → the pipe
streams accept READ-BYTE / WRITE-BYTE / READ-SEQUENCE / WRITE-SEQUENCE on
octet vectors with no decoding (they may also be bivalent, e.g. SBCL).
EXTERNAL-FORMAT applies to character streams (default :UTF-8).
ENV / ENV-MODE: as BACKEND-RUN."))

(defgeneric process-wait (handle &key timeout)
  (:documentation "Block until exit. → exit-code.
TIMEOUT seconds → PROCESS-TIMEOUT-ERROR with a CONTINUE restart that waits
another TIMEOUT seconds. The child is not killed: the caller owns the handle."))

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
