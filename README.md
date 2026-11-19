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

## License

MIT
