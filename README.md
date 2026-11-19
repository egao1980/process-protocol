# process-protocol

Lispy **CLOS** subprocess API for [cl-stack](https://github.com/egao1980/cl-stack) — `run` / `launch` / `wait` / `kill` plus Python-`signal` handlers (`set-signal` / `raise-signal`).

Windows ships in 0.2.0 (`:int` `:term` `:break` `:abrt`): handlers are in-process (SBCL has no `enable-interrupt` there). Unix uses OS signals.

| System | Role | Repo |
|--------|------|------|
| `process-protocol` (`stack-process`) | Protocol / API | this repo |
| `process-backend-uiop` | Default backend (UIOP) | [`egao1980/process-backend-uiop`](https://github.com/egao1980/process-backend-uiop) |

RPC framing is **not** here — see [`rpc-protocol`](https://github.com/egao1980/rpc-protocol).

```lisp
(asdf:load-system "process-backend-uiop")

(multiple-value-bind (code out err)
    (stack-process:run '("echo" "hi"))
  (declare (ignore err))
  (list code out))
```

## Options (0.3.0)

| Key | Meaning |
|-----|---------|
| `:env` | List of `("NAME" . "value")` or `"NAME=value"`. Added to the inherited environment; a `NIL` value unsets. Names are case-insensitive on Windows. |
| `:env-mode` | `:merge` (default) or `:replace` (the child sees `:env` only). Program lookup uses the parent's `PATH`. `merge-environment` is the reference. |
| `:output` / `:error-output` (`run`) | `:octets` (default): exact bytes, never decoded. `:string`: decoded with `:external-format` (default `:utf-8`). `NIL`: discarded. `:error` and `:discard-stderr` still work. |
| `:input` (`run`) | String (encoded with `:external-format`), octet vector (as is), pathname, or input stream. |
| `:element-type` (`launch`) | `character` (default) or `:octets` — pipe streams take `read-byte` / `read-sequence` / `write-sequence` on octet vectors. |
| `:timeout` (`run`, `wait`) | Seconds. Expiry signals `process-timeout-error` (`process-error-command`, `process-timeout-error-timeout`, `process-timeout-error-process`) with a `continue` restart that waits another `:timeout` seconds. `run` kills the child when control leaves it any other way; `wait` leaves it alive. |

Backend failures are `process-error`; a wrapped implementation condition is in `process-error-cause`.

```lisp
(stack-process:run '("git" "cat-file" "blob" "HEAD:logo.png")
                   :env '(("LC_ALL" . "C") ("GIT_TERMINAL_PROMPT" . "0"))
                   :timeout 30)
;; → 0, #(137 80 78 71 …), #()

(handler-bind ((stack-process:process-timeout-error #'continue)) ; keep waiting
  (stack-process:run '("make") :timeout 60))
```

## Process trees (0.4.0)

`kill` reaches the direct child only. A shell command (`sh -c 'sleep 30 & sleep 30'`, `cmd /c "a & b"`) leaves its children running, still holding the output pipes. To stop the whole command:

```lisp
(let ((h (stack-process:launch '("sh" "-c" "make -j8 test") :process-group t)))
  (stack-process:pid h)              ; → 48213 (OS pid; the group id on Unix)
  …
  (stack-process:kill h :tree t))    ; the child and its descendants

(stack-process:run '("sh" "-c" "…") :process-group t :timeout 60)
;; timeout → process-timeout-error; unwinding kills the whole tree
```

| API | Meaning |
|-----|---------|
| `:process-group t` (`launch`, `run`) | Start the child so a tree kill reaches its descendants. Unix: the child leads a new process group. Default `nil` keeps the 0.3 behaviour. A backend that cannot honour it signals `process-group-error` instead of launching a lone child. |
| `kill h :tree t` | Stop the child and its descendants. Unix: `killpg` on the child's group (SIGTERM, or SIGKILL with `:force t`) — reaches grandchildren even after the shell exited; a descendant that left the group (`setsid`, a pty) is not reached. Windows: `taskkill /T /F /PID`, which walks parent pids at kill time (always forced; orphans whose parent already exited are not reached). On a handle launched without `:process-group t`: `process-group-error` with a `continue` restart that kills the direct child only. |
| `pid h` / `process-pid` | OS pid of the direct child (positive integer), or `nil` if the backend cannot tell. |
| `supports-p cap` / `backend-supports-p` | Capability query: `:process-group`, `:pid`. Unknown capabilities are `nil`. |

Why not a Windows job object: UIOP / SBCL cannot create the child suspended, so a job assigned after `CreateProcess` races with the first grandchildren, and it would add a CFFI native dependency. `taskkill /T` needs neither; a backend may switch to job objects later without changing the API.

Backends written for 0.3 must add `process-group` to their `backend-run` / `backend-launch` methods and `tree` to `process-kill` (the generic lambda lists name them).

## License

MIT
