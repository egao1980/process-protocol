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
                                              discard-stderr shell external-format
                                              process-group)
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
kills the child (the whole process tree with :PROCESS-GROUP T\).
PROCESS-GROUP: as BACKEND-LAUNCH."))

(defgeneric backend-launch (backend command &key input output error-output error
                                                 directory env env-mode shell
                                                 element-type external-format
                                                 process-group)
  (:documentation "Async spawn → PROCESS-HANDLE.
INPUT / OUTPUT / ERROR-OUTPUT: NIL → :STREAM (a pipe, see PROCESS-STDIN /
PROCESS-STDOUT / PROCESS-STDERR), or a pathname, :OUTPUT (error-output only),
:INTERACTIVE, as UIOP:LAUNCH-PROGRAM. ERROR is the 0.2 name of ERROR-OUTPUT.
ELEMENT-TYPE: CHARACTER (default) or :OCTETS / (UNSIGNED-BYTE 8) → the pipe
streams accept READ-BYTE / WRITE-BYTE / READ-SEQUENCE / WRITE-SEQUENCE on
octet vectors with no decoding (they may also be bivalent, e.g. SBCL).
EXTERNAL-FORMAT applies to character streams (default :UTF-8).
ENV / ENV-MODE: as BACKEND-RUN.
PROCESS-GROUP: NIL (default, the 0.3 behaviour) or T → start the child so that
PROCESS-KILL :TREE T reaches it and every descendant (see PROCESS-KILL). On
Unix the child leads a new process group (setpgid), so a group kill reaches
grandchildren such as the jobs of sh -c 'a & b'. A backend that cannot do this
(BACKEND-SUPPORTS-P :PROCESS-GROUP is NIL), or a combination it cannot honour
\(e.g. stdin inherited from a terminal), signals PROCESS-GROUP-ERROR instead of
silently launching a lone child."))

(defgeneric process-wait (handle &key timeout)
  (:documentation "Block until exit. → exit-code.
TIMEOUT seconds → PROCESS-TIMEOUT-ERROR with a CONTINUE restart that waits
another TIMEOUT seconds. The child is not killed: the caller owns the handle."))

(defgeneric process-kill (handle &key force tree)
  (:documentation "Stop the process. → T.
FORCE NIL asks politely (SIGTERM; Windows: taskkill without /F, which console
programs ignore); FORCE T cannot be refused (SIGKILL / TerminateProcess).
TREE NIL (default) signals the direct child only: its descendants survive.
TREE T stops the child and its descendants. The handle must come from LAUNCH
or RUN with :PROCESS-GROUP T; otherwise PROCESS-GROUP-ERROR, with a CONTINUE
restart that kills the direct child only. Unix: the signal goes to the
child's process group (killpg), even after the child itself exited, so
grandchildren still in the group are reached; a descendant that moved to
another group or session (setsid, a pty) is not. Windows: always forced. A job
object assigned at launch reaches every descendant, also after the child
exited (process-backend-uiop on SBCL); taskkill /T /F /PID walks parent pids
at kill time and misses descendants whose parent already exited, which
includes programs exec'd by an MSYS / Cygwin shell. Killing an exited process
is not an error."))

(defgeneric process-alive-p (handle))

(defgeneric process-stdin (handle)
  (:documentation "Writable stream or NIL."))

(defgeneric process-stdout (handle)
  (:documentation "Readable stream or NIL."))

(defgeneric process-stderr (handle)
  (:documentation "Readable stream or NIL."))

(defgeneric process-exit-code (handle)
  (:documentation "Exit code if finished, else NIL."))

(defgeneric process-pid (handle)
  (:documentation "The OS process id of the direct child (a positive integer), or NIL
when the backend cannot tell (BACKEND-SUPPORTS-P :PID is NIL). On Unix with
:PROCESS-GROUP T it is also the process group id. Stays the same after exit.")
  (:method ((handle process-handle))
    nil))

(defgeneric backend-supports-p (backend capability)
  (:documentation "True when BACKEND implements CAPABILITY (a keyword) on this
implementation / platform. Unknown capabilities are NIL. Defined:
  :PROCESS-GROUP  LAUNCH / RUN accept :PROCESS-GROUP T and KILL :TREE T stops
                  the descendants (see PROCESS-KILL).
  :PID            PROCESS-PID returns the OS pid.")
  (:method ((backend process-backend) capability)
    (declare (ignore capability))
    nil))

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

(defun kill (handle &key force tree)
  (process-kill handle :force force :tree tree))

(defun alive-p (handle)
  (process-alive-p handle))

(defun stdin (handle) (process-stdin handle))
(defun stdout (handle) (process-stdout handle))
(defun stderr (handle) (process-stderr handle))
(defun exit-code (handle) (process-exit-code handle))
(defun pid (handle) (process-pid handle))

(defun supports-p (capability &key (backend *process-backend*))
  "BACKEND-SUPPORTS-P on BACKEND (default *PROCESS-BACKEND*)."
  (backend-supports-p (%ensure-backend backend) capability))
