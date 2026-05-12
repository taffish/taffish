(in-package :han.test)

;;;; ============================================================
;;;; han.args tests
;;;; ============================================================

(unless (fboundp 'signal-error-p)
  (defun signal-error-p (thunk)
    (handler-case
        (progn
          (funcall thunk)
          nil)
      (error () t))))

(deftest test-han-args-help-and-version ()
  (let ((help-string (han.args:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.args" help-string))
    (check-true (search "parse-args-input" help-string)))
  (check-equal "0.1.0" (han.args:version nil)))

(defun arg-binding-status-of (name result)
  (multiple-value-bind (value status)
      (han.args:get-arg name result)
    (declare (ignore value))
    status))

(defun make-test-input (&rest argv)
  (han.args:parse-args-input argv))

(defun make-test-specs (&rest spec-strings)
  (han.args:parse-args-spec
   (mapcar #'han.args:parse-arg-spec spec-strings)
   "test-app"))

(defun bind-test (specs &rest argv)
  (han.args:bind-args specs (apply #'make-test-input argv)))

(defun arg-default-of (spec-string)
  (han.args:arg-spec-default
   (han.args:parse-arg-spec spec-string)))

(defun %han-diagnostic-code-exists-p (diagnostics kind code)
  (not
   (null
    (find-if #'(lambda (d)
                 (and (eql (han.args:arg-diagnostic-kind d) kind)
                      (eql (han.args:arg-diagnostic-code d) code)))
             diagnostics))))

;;;; ------------------------------------------------------------
;;;; parse-args-input
;;;; ------------------------------------------------------------

(deftest test-args-parse-args-input-basic ()
  (let* ((input (make-test-input "taf-demo"
                                 "--threads=8"
                                 "-v"
                                 "@align:"
                                 "--db" "nt"
                                 "sample.fa"))
         (tokens (han.args:args-input-tokens input))
         (segments (han.args:args-input-segments input)))
    ;; tokens
    (check-equal (length tokens) 6)

    (check-equal (han.args:arg-token-kind (aref tokens 0)) :long-option)
    (check-equal (han.args:arg-token-text (aref tokens 0)) "--threads=8")
    (check-equal (han.args:arg-token-value (aref tokens 0)) "threads")
    (check-equal (han.args:arg-token-extra (aref tokens 0)) "8")

    (check-equal (han.args:arg-token-kind (aref tokens 1)) :short-option)
    (check-equal (han.args:arg-token-value (aref tokens 1)) "v")

    (check-equal (han.args:arg-token-kind (aref tokens 2)) :slot-switch)
    (check-equal (han.args:arg-token-value (aref tokens 2)) "align")

    ;; segments
    (check-equal (length segments) 2)
    (check-equal (han.args:arg-segment-slot (first segments)) nil)
    (check-equal (han.args:arg-segment-positions (first segments)) '(0 1))
    (check-equal (han.args:arg-segment-slot (second segments)) "align")
    (check-equal (han.args:arg-segment-positions (second segments)) '(3 4 5))))

;;;; ------------------------------------------------------------
;;;; parse-arg-spec
;;;; ------------------------------------------------------------

(deftest test-parse-arg-spec-default-escaped-at ()
  (let ((arg (han.args:parse-arg-spec "(--/-x)x=\\@name")))
    (check-equal
     (han.args:arg-spec-default arg)
     "@name")))

(deftest test-parse-arg-spec-default-escaped-at-with-query ()
  (let ((arg (han.args:parse-arg-spec "(--/-x)x=hello, \\@name @{real}")))
    (check-equal
     (han.args:arg-spec-default arg)
     '(:concat "hello, @name " (:query "real")))))

(deftest test-parse-arg-spec-basic ()
  (let ((arg (han.args:parse-arg-spec "(--/-t)threads=8")))
    (check-equal (han.args:arg-spec-name arg) "threads")
    (check-equal (han.args:arg-spec-long-entry arg) "--threads")
    (check-equal (han.args:arg-spec-short-entry arg) "-t")
    (check-equal (han.args:arg-spec-slot-entry arg) nil)
    (check-equal (han.args:arg-spec-arity arg) :single)
    (check-equal (han.args:arg-spec-default arg) "8")
    (check-equal (han.args:arg-spec-required arg) nil)))

(deftest test-parse-arg-spec-flag ()
  (let ((arg (han.args:parse-arg-spec "!(--/-v)verbose?")))
    (check-equal (han.args:arg-spec-name arg) "verbose")
    (check-equal (han.args:arg-spec-arity arg) :flag)
    ;; flag 最终应被强制 optional
    (check-equal (han.args:arg-spec-required arg) nil)
    (check-equal (han.args:arg-spec-default arg) nil)))

(deftest test-parse-arg-spec-block ()
  (let ((arg (han.args:parse-arg-spec "(@:)align")))
    (check-equal (han.args:arg-spec-name arg) "align")
    (check-equal (han.args:arg-spec-slot-entry arg) "@align:")
    (check-equal (han.args:arg-spec-arity arg) :block)))

(deftest test-parse-arg-spec-position ()
  (let ((arg (han.args:parse-arg-spec "$1")))
    (check-equal (han.args:arg-spec-name arg) 1)
    (check-equal (han.args:arg-spec-arity arg) :position)
    (check-equal (han.args:arg-spec-required arg) t)))

(deftest test-parse-arg-spec-query-default ()
  (let ((arg (han.args:parse-arg-spec "(--/-w)who=@name")))
    (check-equal (han.args:arg-spec-name arg) "who")
    (check-equal (han.args:arg-spec-default arg) '(:query "name"))))

(deftest test-parse-arg-spec-concat-default-basic ()
  (check-equal
   (arg-default-of "(--/-m)msg=hello, @name !")
   '(:concat "hello, " (:query "name") " !")))

(deftest test-parse-arg-spec-concat-default-braced ()
  (check-equal
   (arg-default-of "(--/-m)msg=hello,@{name}!")
   '(:concat "hello," (:query "name") "!")))

(deftest test-parse-arg-spec-query-default-braced-only ()
  (check-equal
   (arg-default-of "(--/-w)who=@{name}")
   '(:query "name")))

(deftest test-parse-arg-spec-concat-default-multi-query ()
  (check-equal
   (arg-default-of "(--/-x)x=--db @{db} --query @{query}")
   '(:concat "--db " (:query "db") " --query " (:query "query"))))

(deftest test-parse-arg-spec-default-empty-braced-name-error ()
  (check-equal
   (signal-error-p
    (lambda ()
      (han.args:parse-arg-spec "(--/-x)x=@{}")))
   t))

(deftest test-parse-arg-spec-default-space-in-braced-name-error ()
  (check-equal
   (signal-error-p
    (lambda ()
      (han.args:parse-arg-spec "(--/-x)x=@{na me}")))
   t))

;;;; ------------------------------------------------------------
;;;; parse-args-spec
;;;; ------------------------------------------------------------

(deftest test-parse-args-spec-merge ()
  (let* ((specs (han.args:parse-args-spec
                 (list (han.args:parse-arg-spec "(--/-t)threads")
                       (han.args:parse-arg-spec "threads=8"))
                 "test-app"))
         (arg (gethash "threads" (han.args:args-spec-args-table specs))))
    (check-equal (han.args:arg-spec-name arg) "threads")
    (check-equal (han.args:arg-spec-long-entry arg) "--threads")
    (check-equal (han.args:arg-spec-short-entry arg) "-t")
    (check-equal (han.args:arg-spec-default arg) "8")))

(deftest test-parse-args-spec-duplicate-entry-error ()
  (check-equal
   (signal-error-p
    (lambda ()
      (han.args:parse-args-spec
       (list (han.args:parse-arg-spec "(--/-)input=xxx")
             (han.args:parse-arg-spec "(--/-)info?"))
       "test-app")))
   t))

;;;; ------------------------------------------------------------
;;;; bind + get-arg : single / flag / default / missing
;;;; ------------------------------------------------------------

(deftest test-bind-single-from-extra ()
  (let* ((specs (make-test-specs "(--/-t)threads=1"))
         (result (bind-test specs "taf-demo" "--threads=8")))
    (multiple-value-bind (value status)
        (han.args:get-arg "threads" result)
      (check-equal value "8")
      (check-equal status :input))))

(deftest test-bind-single-from-next-token ()
  (let* ((specs (make-test-specs "(--/-t)threads=1"))
         (result (bind-test specs "taf-demo" "--threads" "16")))
    (multiple-value-bind (value status)
        (han.args:get-arg "threads" result)
      (check-equal value "16")
      (check-equal status :input))))

(deftest test-bind-single-default ()
  (let* ((specs (make-test-specs "(--/-t)threads=4"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "threads" result)
      (check-equal value "4")
      (check-equal status :default))))

(deftest test-bind-required-single-missing ()
  (let* ((specs (make-test-specs "!(--/-i)input"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "input" result)
      (check-equal value nil)
      (check-equal status :missing))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

(deftest test-bind-flag-present ()
  (let* ((specs (make-test-specs "(--/-v)verbose?"))
         (result (bind-test specs "taf-demo" "-v")))
    (multiple-value-bind (value status)
        (han.args:get-arg "verbose" result)
      (check-equal value t)
      (check-equal status :input))))

(deftest test-bind-flag-absent ()
  (let* ((specs (make-test-specs "(--/-v)verbose?"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "verbose" result)
      (check-equal value nil)
      (check-equal status :missing))))

(deftest test-bind-single-conflict ()
  (let* ((specs (make-test-specs "(--/-t)threads"))
         (result (bind-test specs "taf-demo" "--threads=8" "-t" "16")))
    (multiple-value-bind (value status)
        (han.args:get-arg "threads" result)
      (check-equal value nil)
      (check-equal status :conflict))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

;;;; ------------------------------------------------------------
;;;; block
;;;; ------------------------------------------------------------

(deftest test-bind-block ()
  (let* ((specs (make-test-specs "(@:)align"))
         (result (bind-test specs
                            "taf-demo"
                            "@align:" "--db" "nt" "sample.fa")))
    (multiple-value-bind (value status)
        (han.args:get-arg "align" result)
      (check-equal status :input)
      ;; block value 是 token list
      (check-equal (length value) 3)
      (check-equal (mapcar #'han.args:arg-token-text value)
                   '("--db" "nt" "sample.fa")))))

(deftest test-bind-required-block-missing ()
  (let* ((specs (make-test-specs "!(@:)align"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "align" result)
      (check-equal value nil)
      (check-equal status :missing))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

;;;; ------------------------------------------------------------
;;;; position
;;;; ------------------------------------------------------------

(deftest test-bind-position-basic ()
  (let* ((specs (make-test-specs "$1" "$2"))
         (result (bind-test specs "taf-demo" "a.txt" "b.txt")))
    (multiple-value-bind (value status)
        (han.args:get-arg 1 result)
      (check-equal value "a.txt")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg 2 result)
      (check-equal value "b.txt")
      (check-equal status :input))))

(deftest test-bind-position-ignore-options ()
  (let* ((specs (make-test-specs "$1"))
         (result (bind-test specs "taf-demo" "--threads=8" "sample.fa")))
    (multiple-value-bind (value status)
        (han.args:get-arg 1 result)
      (check-equal value "sample.fa")
      (check-equal status :input))))

(deftest test-bind-extra-positional-warning ()
  (let* ((specs (make-test-specs "$1"))
         (result (bind-test specs "taf-demo" "a.txt" "b.txt")))
    (multiple-value-bind (value status)
        (han.args:get-arg 1 result)
      (check-equal value "a.txt")
      (check-equal status :input))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

;;;; ------------------------------------------------------------
;;;; builtin bindings
;;;; ------------------------------------------------------------
#|
(deftest test-builtin-argv ()
(let* ((specs (make-test-specs))
(result (bind-test specs "taf-demo" "--threads=8" "sample.fa")))
(multiple-value-bind (value status)
(han.args:get-arg "*ARGV*" result)
(check-equal value "--threads=8 sample.fa")
(check-equal status :input))))

(deftest test-builtin-zero ()
(let* ((specs (make-test-specs))
(result (bind-test specs "taf-demo" "--threads=8")))
(multiple-value-bind (value status)
(han.args:get-arg 0 result)
(check-equal value "taf-demo")
(check-equal status :input))))
|#

;;;; ------------------------------------------------------------
;;;; query default
;;;; ------------------------------------------------------------

(deftest test-query-default-basic ()
  (let* ((specs (make-test-specs
                 "(--/-n)name=alice"
                 "(--/-w)who=@name"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "who" result)
      (check-equal value "alice")
      ;; 最终状态应沿着被引用目标返回
      (check-equal status :default))))

(deftest test-query-default-chain ()
  (let* ((specs (make-test-specs
                 "a=@b"
                 "b=@c"
                 "c=ok"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "a" result)
      (check-equal value "ok")
      (check-equal status :default))))

(deftest test-query-default-cyclic ()
  (let* ((specs (make-test-specs
                 "a=@b"
                 "b=@a"))
         (result (bind-test specs "taf-demo")))
    (check-equal
     (signal-error-p
      (lambda ()
        (han.args:get-arg "a" result)))
     t)))

(deftest test-query-default-concat-basic ()
  (let* ((specs (make-test-specs
                 "(--/-n)name=alice"
                 "(--/-m)msg=hello, @name !"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "msg" result)
      (check-equal value "hello, alice !")
      (check-equal status :default))))

(deftest test-query-default-concat-braced ()
  (let* ((specs (make-test-specs
                 "(--/-n)name=alice"
                 "(--/-m)msg=hello,@{name}!"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "msg" result)
      (check-equal value "hello,alice!")
      (check-equal status :default))))

(deftest test-query-default-concat-multi-query ()
  (let* ((specs (make-test-specs
                 "db=nt"
                 "query=sample.fa"
                 "cmd=--db @{db} --query @{query}"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "cmd" result)
      (check-equal value "--db nt --query sample.fa")
      (check-equal status :default))))

(deftest test-query-default-concat-with-input-reference ()
  (let* ((specs (make-test-specs
                 "(--/-t)threads"
                 "cpus=-@{threads}"))
         (result (bind-test specs "taf-demo" "--threads" "16")))
    (multiple-value-bind (value status)
        (han.args:get-arg "cpus" result)
      (check-equal value "-16")
      ;; 当前设计下，表达式求值整体按 default 处理
      (check-equal status :default))))

(deftest test-query-default-concat-chain ()
  (let* ((specs (make-test-specs
                 "name=alice"
                 "hello=hello, @{name}"
                 "msg=@{hello}!"))
         (result (bind-test specs "taf-demo")))
    (multiple-value-bind (value status)
        (han.args:get-arg "msg" result)
      (check-equal value "hello, alice!")
      (check-equal status :default))))

(deftest test-query-default-concat-cyclic ()
  (let* ((specs (make-test-specs
                 "a=hello @{b}"
                 "b=world @{a}"))
         (result (bind-test specs "taf-demo")))
    (check-equal
     (signal-error-p
      (lambda ()
        (han.args:get-arg "a" result)))
     t)))

;;;; ------------------------------------------------------------
;;;; undefined input diagnostics
;;;; ------------------------------------------------------------

(deftest test-undefined-option-warning ()
  (let* ((specs (make-test-specs "(--/-t)threads=4"))
         (result (bind-test specs "taf-demo" "--unknown" "123")))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

(deftest test-undefined-slot-warning ()
  (let* ((specs (make-test-specs))
         (result (bind-test specs "taf-demo" "@unknown:" "--x" "1")))
    (check-equal
     (not (null (han.args:args-result-diagnostics result)))
     t)))

;;;; ============================================================
;;;; han.args diagnostic-code tests
;;;; ============================================================

(deftest test-han-args-bind-missing-required-code ()
  (let* ((spec (han.args:parse-args-spec
                (list (han.args:parse-arg-spec "!(--/-i)input"))))
         (input (han.args:parse-args-input '("demo")))
         (result (han.args:bind-args spec input))
         (diagnostics (han.args:args-result-diagnostics result)))
    (check-equal
     (%han-diagnostic-code-exists-p diagnostics :error :missing-required)
     t)))

(deftest test-han-args-bind-conflict-code ()
  (let* ((spec (han.args:parse-args-spec
                (list (han.args:parse-arg-spec "(--/-t)threads"))))
         (input (han.args:parse-args-input
                 '("demo" "--threads" "8" "-t" "16")))
         (result (han.args:bind-args spec input))
         (diagnostics (han.args:args-result-diagnostics result)))
    (check-equal
     (%han-diagnostic-code-exists-p diagnostics :error :conflict)
     t)))

(deftest test-han-args-bind-missing-option-value-code ()
  (let* ((spec (han.args:parse-args-spec
                (list (han.args:parse-arg-spec "(--/-i)input"))))
         (input (han.args:parse-args-input
                 '("demo" "--input")))
         (result (han.args:bind-args spec input))
         (diagnostics (han.args:args-result-diagnostics result)))
    (check-equal
     (%han-diagnostic-code-exists-p diagnostics :error :missing-option-value)
     t)))

(deftest test-han-args-bind-undefined-option-code ()
  (let* ((spec (han.args:parse-args-spec
                (list (han.args:parse-arg-spec "(--/-i)input"))))
         (input (han.args:parse-args-input
                 '("demo" "--xxx" "1")))
         (result (han.args:bind-args spec input))
         (diagnostics (han.args:args-result-diagnostics result)))
    (check-equal
     (%han-diagnostic-code-exists-p diagnostics :warning :undefined-option)
     t)))

(deftest test-han-args-bind-unused-positional-code ()
  (let* ((spec (han.args:parse-args-spec
                (list (han.args:parse-arg-spec "$0"))))
         (input (han.args:parse-args-input
                 '("demo" "a.txt" "b.txt")))
         (result (han.args:bind-args spec input))
         (diagnostics (han.args:args-result-diagnostics result)))
    (check-equal
     (%han-diagnostic-code-exists-p diagnostics :warning :unused-option)
     t)))
