# process-protocol

Lispy **CLOS** subprocess API for [cl-stack](https://github.com/egao1980/cl-stack) — `run` / `launch` / `wait` / `kill`.

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

## License

MIT
