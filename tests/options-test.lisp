(in-package #:process-protocol/tests)

(defun env-value (name alist)
  (cdr (assoc name alist :test #'string=)))

(deftest merge-keeps-inherited
  (let ((env (process-protocol:merge-environment
              '(("FOO" . "1"))
              :base '("HOME=/home/x" "PATH=/bin") :case-insensitive nil)))
    (ok (equal "1" (env-value "FOO" env)))
    (ok (equal "/home/x" (env-value "HOME" env)))
    (ok (equal "/bin" (env-value "PATH" env)))))

(deftest merge-overrides-and-unsets
  (let ((env (process-protocol:merge-environment
              '(("HOME" . "/tmp/h") ("PATH" . nil) "LC_ALL=C")
              :base '(("HOME" . "/home/x") ("PATH" . "/bin")) :case-insensitive nil)))
    (ok (equal "/tmp/h" (env-value "HOME" env)))
    (ng (assoc "PATH" env :test #'string=))
    (ok (equal "C" (env-value "LC_ALL" env)))
    (ok (= 2 (length env)))))

(deftest merge-later-entry-wins
  (let ((env (process-protocol:merge-environment
              '(("A" . "1") ("A" . "2")) :base '() :case-insensitive nil)))
    (ok (equal '(("A" . "2")) env))))

(deftest merge-case-insensitive
  (let ((env (process-protocol:merge-environment
              '(("Path" . "C:\\x")) :base '("PATH=C:\\Windows") :case-insensitive t)))
    (ok (= 1 (length env)))
    (ok (equal "C:\\x" (cdr (first env))))))

(deftest merge-windows-drive-entries
  (let ((env (process-protocol:merge-environment
              '() :base '("=C:=C:\\work" "A=b=c") :case-insensitive t)))
    (ok (equal "C:\\work" (env-value "=C:" env)))
    (ok (equal "b=c" (env-value "A" env)))))

(deftest replace-ignores-base
  (let ((env (process-protocol:merge-environment
              '(("FOO" . "1") ("BAR" . nil))
              :base '("HOME=/home/x") :mode :replace)))
    (ok (equal '(("FOO" . "1")) env))))

(deftest merge-bad-entries
  (ok (signals (process-protocol:merge-environment '("NOEQUALS"))
               'process-protocol:process-error))
  (ok (signals (process-protocol:merge-environment '((:foo . "1")))
               'process-protocol:process-error))
  (ok (signals (process-protocol:merge-environment '() :mode :bogus)
               'type-error)))

(deftest environment-strings-shape
  (ok (equal '("A=1" "B=")
             (process-protocol:environment-strings '(("A" . "1") ("B" . ""))))))

(deftest capture-designators
  (ok (eq :octets (process-protocol:normalize-capture :octets)))
  (ok (eq :octets (process-protocol:normalize-capture '(unsigned-byte 8))))
  (ok (eq :string (process-protocol:normalize-capture :string)))
  (ok (eq :string (process-protocol:normalize-capture 'character)))
  (ok (null (process-protocol:normalize-capture nil)))
  (ok (signals (process-protocol:normalize-capture :bogus)
               'process-protocol:process-error)))

(deftest element-type-designators
  (ok (eq 'character (process-protocol:normalize-element-type nil)))
  (ok (eq 'character (process-protocol:normalize-element-type 'character)))
  (ok (equal '(unsigned-byte 8) (process-protocol:normalize-element-type :octets)))
  (ok (equal '(unsigned-byte 8) (process-protocol:normalize-element-type '(unsigned-byte 8))))
  (ok (signals (process-protocol:normalize-element-type :bogus)
               'process-protocol:process-error)))

(deftest windows-feature-test
  (ok (eq (and (or (member :win32 *features*) (member :windows *features*)
                   (member :mswindows *features*))
               t)
          (process-protocol:windows-p))))
