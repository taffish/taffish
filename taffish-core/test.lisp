(in-package :han.test)

;;;; ============================================================
;;;; taffish.core tests
;;;; ============================================================

(defun %taffish-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %taf-token-values (line)
  (mapcar #'taffish.core:taf-token-value
          (taffish.core:taf-line-tokens line)))

(defun %taf-token-kinds (line)
  (mapcar #'taffish.core:taf-token-kind
          (taffish.core:taf-line-tokens line)))

(defun %taf-first-token-value (line)
  (taffish.core:taf-token-value
   (car (taffish.core:taf-line-tokens line))))

(defun %taf-block-head (block)
  (car block))

(defun %taf-block-head-value (block)
  (%taf-first-token-value (%taf-block-head block)))

(defun %taf-program-arg (program name)
  (gethash name
           (han.args:args-spec-args-table
            (taffish.core:taf-program-args-spec program))))

(defun %string-contains-p (string substring)
  (and (stringp string)
       (stringp substring)
       (not (null (search substring string :test #'char=)))))

(defun %line-containing (string substring)
  (with-input-from-string (in string)
    (loop for line = (read-line in nil nil)
          while line
          when (%string-contains-p line substring)
            return line)))

(defun %default-test-context (&optional container-config argv)
  (append
   `((:cmd . "taf-app-xxx")
     (:user . "alice")
     (:homedir . "/home/alice")
     (:workdir . "/home/alice/Desktop")
     ,@(when argv
         `((:argv . ,argv))))
   (when container-config
     (list (cons :container container-config)))))

(defun %default-test-input-args ()
  (list "my-cmd"
        "--name=alice"
        "-c" "blastp"
        "-of" "1"))

(defun %taffish-bind-signal-error-p (code input-args &optional context)
  (%taffish-signal-error-p
   (lambda ()
     (let ((program (taffish.core:parse-taf code)))
       (taffish.core:bind-taf program input-args context)))))

;;;; ------------------------------------------------------------
;;;; lexer
;;;; ------------------------------------------------------------

(deftest test-taffish-lexer-line-kinds-basic ()
  (let* ((code (format nil "ARGS~%# comment~%<docker:test>~%echo ::name::~%"))
         (lines (taffish.core:lex-taf code)))
    (check-equal (length lines) 4)

    (check-equal (taffish.core:taf-line-kind (first lines)) :tag)
    (check-equal (taffish.core:taf-line-subkind (first lines)) :args)

    (check-equal (taffish.core:taf-line-kind (second lines)) :comment)
    (check-equal (taffish.core:taf-line-subkind (second lines)) nil)

    (check-equal (taffish.core:taf-line-kind (third lines)) :tag)
    (check-equal (taffish.core:taf-line-subkind (third lines)) :subtag)
    (check-equal (%taf-first-token-value (third lines)) "docker:test")

    (check-equal (taffish.core:taf-line-kind (fourth lines)) :code)
    (check-equal (%taf-token-kinds (fourth lines)) '(:text :arg))
    (check-equal (%taf-token-values (fourth lines))
                 '("echo " "name"))))

(deftest test-taffish-lexer-newline-variants ()
  (let ((lf-lines   (taffish.core:lex-taf "a
b
c"))
        (crlf-lines (taffish.core:lex-taf (format nil "a~C~Cb~C~Cc"
                                                  #\Return #\Newline
                                                  #\Return #\Newline)))
        (cr-lines   (taffish.core:lex-taf (format nil "a~Cb~Cc"
                                                  #\Return
                                                  #\Return))))
    (check-equal (length lf-lines) 3)
    (check-equal (length crlf-lines) 3)
    (check-equal (length cr-lines) 3)

    (check-equal (mapcar #'taffish.core:taf-line-raw-string lf-lines)
                 '("a" "b" "c"))
    (check-equal (mapcar #'taffish.core:taf-line-raw-string crlf-lines)
                 '("a" "b" "c"))
    (check-equal (mapcar #'taffish.core:taf-line-raw-string cr-lines)
                 '("a" "b" "c"))))

(deftest test-taffish-lexer-code-arg-split ()
  (let* ((lines (taffish.core:lex-taf "echo ::name:: world ::x::"))
         (line (first lines)))
    (check-equal (taffish.core:taf-line-kind line) :code)
    (check-equal (%taf-token-kinds line)
                 '(:text :arg :text :arg))
    (check-equal (%taf-token-values line)
                 '("echo " "name" " world " "x"))))

(deftest test-taffish-lexer-subtag-arg-split ()
  (let* ((lines (taffish.core:lex-taf "<docker::image::>"))
         (line (first lines)))
    (check-equal (taffish.core:taf-line-kind line) :tag)
    (check-equal (taffish.core:taf-line-subkind line) :subtag)
    (check-equal (%taf-token-kinds line)
                 '(:text :arg))
    (check-equal (%taf-token-values line)
                 '("docker" "image"))))

(deftest test-taffish-lexer-escape-arg-marker ()
  (let* ((lines (taffish.core:lex-taf "echo :\\:name:\\:"))
         (line (first lines))
         (token (first (taffish.core:taf-line-tokens line))))
    (check-equal (taffish.core:taf-line-kind line) :code)
    (check-equal (length (taffish.core:taf-line-tokens line)) 1)
    (check-equal (taffish.core:taf-token-kind token) :text)
    (check-equal (taffish.core:taf-token-value token) "echo ::name::")))

(deftest test-taffish-lexer-escape-comment ()
  (let* ((lines (taffish.core:lex-taf "\\# hello"))
         (line (first lines))
         (token (first (taffish.core:taf-line-tokens line))))
    (check-equal (taffish.core:taf-line-kind line) :code)
    (check-equal (taffish.core:taf-token-kind token) :text)
    (check-equal (taffish.core:taf-token-value token) "# hello")))

(deftest test-taffish-lexer-escape-subtag ()
  (let* ((lines (taffish.core:lex-taf "\\<docker:test>"))
         (line (first lines))
         (token (first (taffish.core:taf-line-tokens line))))
    (check-equal (taffish.core:taf-line-kind line) :code)
    (check-equal (taffish.core:taf-token-kind token) :text)
    (check-equal (taffish.core:taf-token-value token) "<docker:test>")))

(deftest test-taffish-lexer-preserve-at-backslash ()
  (let* ((lines (taffish.core:lex-taf "echo \\@name"))
         (line (first lines))
         (token (first (taffish.core:taf-line-tokens line))))
    (check-equal (taffish.core:taf-line-kind line) :code)
    ;; @ is not TAF syntax, so \@ is preserved for han.args/default parser.
    (check-equal (taffish.core:taf-token-value token) "echo \\@name")))

(deftest test-taffish-lexer-preserve-normal-backslash ()
  (let* ((lines (taffish.core:lex-taf "echo a\\b"))
         (line (first lines))
         (token (first (taffish.core:taf-line-tokens line))))
    (check-equal (taffish.core:taf-line-kind line) :code)
    (check-equal (taffish.core:taf-token-value token) "echo a\\b")))

(deftest test-taffish-lexer-unclosed-arg-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:lex-taf "echo ::name")))
   t))

;;;; ------------------------------------------------------------
;;;; parser
;;;; ------------------------------------------------------------

(deftest test-taffish-parser-empty-file-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:parse-taf "")))
   t))

(deftest test-taffish-parser-naked-code-auto-run-taffish ()
  (let* ((program (taffish.core:parse-taf "echo hello"))
         (body (taffish.core:taf-program-body program))
         (block (first body))
         (head (%taf-block-head block))
         (code-line (second block)))
    (check-equal (taffish.core:taf-program-p program) t)
    (check-equal (length body) 1)

    ;; Auto inserted <taffish>
    (check-equal (taffish.core:taf-line-kind head) :tag)
    (check-equal (taffish.core:taf-line-subkind head) :subtag)
    (check-equal (%taf-block-head-value block) "taffish")

    ;; Original code preserved.
    (check-equal (taffish.core:taf-line-kind code-line) :code)
    (check-equal (%taf-token-values code-line) '("echo hello"))))

(deftest test-taffish-parser-leading-subtag-auto-run ()
  (let* ((program (taffish.core:parse-taf
                   (format nil "<docker:test>~%echo hello")))
         (body (taffish.core:taf-program-body program))
         (block (first body)))
    (check-equal (length body) 1)
    (check-equal (%taf-block-head-value block) "docker:test")
    (check-equal (%taf-token-values (second block))
                 '("echo hello"))))

(deftest test-taffish-parser-explicit-args-and-run ()
  (let* ((code (format nil
                       "ARGS~%<!(--/-i)input>~%RUN~%<taffish>~%cat ::input::~%"))
         (program (taffish.core:parse-taf code))
         (input-arg (%taf-program-arg program "input"))
         (body (taffish.core:taf-program-body program)))
    (check-equal (han.args:arg-spec-name input-arg) "input")
    (check-equal (han.args:arg-spec-long-entry input-arg) "--input")
    (check-equal (han.args:arg-spec-short-entry input-arg) "-i")
    (check-equal (han.args:arg-spec-required input-arg) t)

    (check-equal (length body) 1)
    (check-equal (%taf-block-head-value (first body)) "taffish")))

(deftest test-taffish-parser-builtin-args-allowed ()
  (let ((program
          (taffish.core:parse-taf
           (format nil "RUN~%<taffish>~%echo ::*USER*:: ::*WORKDIR*::~%"))))
    (check-equal (taffish.core:taf-program-p program) t)))

(deftest test-taffish-parser-args-empty-subtag-allowed ()
  (let* ((code (format nil
                       "ARGS~%<!(--/-i)input>~%RUN~%<taffish>~%cat ::input::~%"))
         (program (taffish.core:parse-taf code))
         (input-arg (%taf-program-arg program "input")))
    (check-equal (han.args:arg-spec-name input-arg) "input")
    (check-equal (han.args:arg-spec-default input-arg) nil)))

(deftest test-taffish-parser-args-block-default-with-inline-args ()
  (let* ((code (format nil
                       "ARGS~%<(@:)blast-step>~%  --cmd ::!(--/-)cmd::~%  --outfmt ::(--/-of)outfmt=6::~%RUN~%<taffish>~%echo ::(@:)blast-step::~%"))
         (program (taffish.core:parse-taf code))
         (blast-step (%taf-program-arg program "blast-step"))
         (cmd (%taf-program-arg program "cmd"))
         (outfmt (%taf-program-arg program "outfmt")))
    ;; ARGS subtag produces block arg.
    (check-equal (han.args:arg-spec-arity blast-step) :block)
    (check-equal (han.args:arg-spec-slot-entry blast-step) "@blast-step:")
    (check-equal (not (null (han.args:arg-spec-default blast-step))) t)

    ;; Inline args inside ARGS default are also extracted.
    (check-equal (han.args:arg-spec-name cmd) "cmd")
    (check-equal (han.args:arg-spec-long-entry cmd) "--cmd")
    (check-equal (han.args:arg-spec-short-entry cmd) "-c")
    (check-equal (han.args:arg-spec-required cmd) t)

    (check-equal (han.args:arg-spec-name outfmt) "outfmt")
    (check-equal (han.args:arg-spec-long-entry outfmt) "--outfmt")
    (check-equal (han.args:arg-spec-short-entry outfmt) "-of")
    (check-equal (han.args:arg-spec-default outfmt) "6")))

(deftest test-taffish-parser-args-block-preserves-escaped-at-for-han-args ()
  (let* ((code (format nil
                       "ARGS~%<message>~%  echo \\@name~%RUN~%<taffish>~%echo ::message::~%"))
         (program (taffish.core:parse-taf code))
         (message (%taf-program-arg program "message")))
    ;; \@ is not consumed by TAF lexer. It is preserved for han.args,
    ;; so han.args should keep it as literal @name instead of query name.
    (check-equal (han.args:arg-spec-default message) "echo @name")))

(deftest test-taffish-parser-args-block-at-query-default ()
  (let* ((code (format nil
                       "ARGS~%<name>~%  alice~%<message>~%  hello, @name~%RUN~%<taffish>~%echo ::message::~%"))
         (program (taffish.core:parse-taf code))
         (message (%taf-program-arg program "message")))
    (check-equal (han.args:arg-spec-default message)
                 '(:concat "hello, " (:query "name")))))

(deftest test-taffish-parser-args-subtag-head-arg-token-error ()
  (let ((code (format nil
                      "ARGS~%<message::name::>~%  hello~%RUN~%<taffish>~%echo hello~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-args-after-run-error ()
  (let ((code (format nil
                      "RUN~%<taffish>~%echo hello~%ARGS~%<name>~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-duplicate-args-error ()
  (let ((code (format nil
                      "ARGS~%<name>~%  alice~%ARGS~%<other>~%  bob~%RUN~%<taffish>~%echo hello~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-duplicate-run-error ()
  (let ((code (format nil
                      "RUN~%<taffish>~%echo hello~%RUN~%<other>~%echo world~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-missing-run-error ()
  (let ((code (format nil
                      "ARGS~%<name>~%  alice~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-code-before-subtag-error ()
  (let ((code (format nil
                      "RUN~%echo hello~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-empty-run-subtag-error ()
  (let ((code (format nil
                      "RUN~%<taffish>~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-dead-arg-error ()
  (let ((code (format nil
                      "RUN~%<taffish>~%echo ::name::~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:parse-taf code)))
     t)))

(deftest test-taffish-parser-escaped-arg-marker-no-dead-arg ()
  (let* ((program (taffish.core:parse-taf "echo :\\:name:\\:"))
         (body (taffish.core:taf-program-body program))
         (line (second (first body))))
    (check-equal (%taf-token-kinds line) '(:text))
    (check-equal (%taf-token-values line) '("echo ::name::"))))

;;;; ------------------------------------------------------------
;;;; input
;;;; ------------------------------------------------------------

(deftest test-taffish-normalize-input-args-basic ()
  (let* ((input (taffish.core:normalize-input-args
                 '("--name" "alice")))
         (tokens (han.args:args-input-tokens input)))
    (check-equal (han.args:args-input-raw-cmd input) "taffish")
    (check-equal (han.args:args-input-raw-argv input)
                 '("--name" "alice"))
    (check-equal (length tokens) 2)
    (check-equal (han.args:arg-token-kind (aref tokens 0)) :long-option)
    (check-equal (han.args:arg-token-value (aref tokens 0)) "name")
    (check-equal (han.args:arg-token-kind (aref tokens 1)) :value)
    (check-equal (han.args:arg-token-value (aref tokens 1)) "alice")))

(deftest test-taffish-normalize-input-args-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:normalize-input-args "not-a-list")))
   t))

(deftest test-taffish-normalize-input-context-basic ()
  (let ((context
          (taffish.core:normalize-input-context
           '((:workdir . "/tmp/work")
             (:loaddir . "/tmp/load")
             (:user . "alice")
             (:argv . ("taf-demo" "--x" "1"))
             (:cmd . "taf-demo")
             (:cpus . 8)))))
    (check-equal (taffish.core:taf-context-workdir context) "/tmp/work")
    (check-equal (taffish.core:taf-context-loaddir context) "/tmp/load")
    (check-equal (taffish.core:taf-context-user context) "alice")
    (check-equal (taffish.core:taf-context-argv context)
                 '("taf-demo" "--x" "1"))
    (check-equal (taffish.core:taf-context-cmd context) "taf-demo")
    (check-equal (taffish.core:taf-context-cpus context) 8)
    (check-equal (taffish.core:taf-context-extras context) nil)))

(deftest test-taffish-normalize-input-context-empty ()
  (let ((context (taffish.core:normalize-input-context nil)))
    (check-equal (taffish.core:taf-context-workdir context) nil)
    (check-equal (taffish.core:taf-context-loaddir context) nil)
    (check-equal (taffish.core:taf-context-user context) nil)
    (check-equal (taffish.core:taf-context-argv context) nil)
    (check-equal (taffish.core:taf-context-cmd context) nil)
    (check-equal (taffish.core:taf-context-cpus context) nil)
    (check-equal (taffish.core:taf-context-extras context) nil)))

(deftest test-taffish-normalize-input-context-extras ()
  (let ((context
          (taffish.core:normalize-input-context
           '((:workdir . "/tmp/work")
             (:backend . :docker)
             (:dry-run . t)))))
    (check-equal (taffish.core:taf-context-workdir context) "/tmp/work")
    (check-equal (taffish.core:taf-context-extras context)
                 '((:backend . :docker)
                   (:dry-run . t)))))

(deftest test-taffish-normalize-input-context-error-not-list ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:normalize-input-context "not-a-context")))
   t))

(deftest test-taffish-normalize-input-context-error-bad-item ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:normalize-input-context
       '((:workdir . "/tmp")
         :bad-item))))
   t))

;;;; ------------------------------------------------------------
;;;; binder
;;;; ------------------------------------------------------------

(deftest test-taffish-bind-basic-input ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "ARGS~%<!(--/-n)name>~%RUN~%<taffish>~%echo ::name::~%")))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo" "--name" "alice")))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "name" args-result)
      (check-equal value "alice")
      (check-equal status :input))
    (check-equal (taffish.core:taf-result-program result) program)
    (check-equal (taffish.core:taf-result-body result)
                 (taffish.core:taf-program-body program))))

(deftest test-taffish-bind-default-value ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "ARGS~%<(--/-n)name>~%  alice~%RUN~%<taffish>~%echo ::name::~%")))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo")))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "name" args-result)
      (check-equal value "alice")
      (check-equal status :default))))

(deftest test-taffish-bind-default-expression ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "ARGS~%<(--/-n)name>~%  alice~%<message>~%  hello, @name!~%RUN~%<taffish>~%echo ::message::~%")))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo")))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "message" args-result)
      (check-equal value "hello, alice!")
      (check-equal status :default))))

(deftest test-taffish-bind-input-overrides-default ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "ARGS~%<(--/-n)name>~%  default-name~%RUN~%<taffish>~%echo ::name::~%")))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo" "--name" "input-name")))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "name" args-result)
      (check-equal value "input-name")
      (check-equal status :input))))

(deftest test-taffish-bind-required-missing-error ()
  (let ((program (taffish.core:parse-taf
                  (format nil
                          "ARGS~%<!(--/-i)input>~%RUN~%<taffish>~%cat ::input::~%"))))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:bind-taf program '("taf-demo"))))
     t)))

(deftest test-taffish-bind-conflict-error ()
  (let ((program (taffish.core:parse-taf
                  (format nil
                          "ARGS~%<(--/-t)threads>~%RUN~%<taffish>~%echo ::threads::~%"))))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:bind-taf
         program
         '("taf-demo" "--threads" "8" "-t" "16"))))
     t)))

(deftest test-taffish-bind-context-builtins ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "RUN~%<taffish>~%echo ::*USER*:: ::*HOMEDIR*:: ::*WORKDIR*:: ::*LOADDIR*:: ::*CPUS*::~%")))
         (context '((:user . "alice")
                    (:homedir . "/home/alice")
                    (:workdir . "/tmp/work")
                    (:loaddir . "/tmp/load")
                    (:cpus . 8)
                    (:cmd . "taf-demo")
                    (:argv . ("taf-demo" "--x" "1"))))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo" "--x" "1")
                  context))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "*USER*" args-result)
      (check-equal value "alice")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg "*HOMEDIR*" args-result)
      (check-equal value "/home/alice")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg "*WORKDIR*" args-result)
      (check-equal value "/tmp/work")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg "*LOADDIR*" args-result)
      (check-equal value "/tmp/load")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg "*CPUS*" args-result)
      (check-equal value "8")
      (check-equal status :input))
    (multiple-value-bind (value status)
        (han.args:get-arg "*ARGV*" args-result)
      (check-equal value "taf-demo --x 1")
      (check-equal status :input))))

(deftest test-taffish-bind-context-object ()
  (let* ((program (taffish.core:parse-taf
                   (format nil
                           "RUN~%<taffish>~%echo ::*USER*::~%")))
         (context (taffish.core:make-taf-context
                   :user "alice"))
         (result (taffish.core:bind-taf
                  program
                  '("taf-demo")
                  context))
         (args-result (taffish.core:taf-result-args-result result)))
    (multiple-value-bind (value status)
        (han.args:get-arg "*USER*" args-result)
      (check-equal value "alice")
      (check-equal status :input))))

(deftest test-taffish-bind-invalid-program-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:bind-taf
       "not-a-program"
       '("taf-demo"))))
   t))

;;;; ------------------------------------------------------------
;;;; taf-app bind / diagnostic tests
;;;; ------------------------------------------------------------

(deftest test-taffish-bind-no-taf-app-missing-required-still-errors ()
  (let ((code (format nil
                      "ARGS~%<!(--/-i)input>~%RUN~%<shell>~%  echo hello~%")))
    ;; 没有 taf-app，缺失 required 必须报错
    (check-equal
     (%taffish-bind-signal-error-p
      code
      '("demo")
      (%default-test-context nil '("blastp" "-db" "nt")))
     t)))

(deftest test-taffish-bind-taf-app-arg-mode-missing-required-still-errors ()
  (let ((code (format nil
                      "ARGS~%<!(--/-i)input>~%RUN~%<taf-app:shell>~%  echo hello~%")))
    ;; taf-app 存在，但 argv 第一个参数是 -- 开头，属于 arg-mode
    ;; 所以 missing-required 仍然必须报错
    (check-equal
     (%taffish-bind-signal-error-p
      code
      '("demo" "--name" "alice")
      (%default-test-context nil '("--name" "alice")))
     t)))

(deftest test-taffish-bind-taf-app-command-mode-ignores-missing-required ()
  (let* ((code (format nil
                       "ARGS~%<!(--/-i)input>~%RUN~%<taf-app:shell>~%  echo hello~%"))
         (program (taffish.core:parse-taf code))
         (result (taffish.core:bind-taf
                  program
                  '("demo" "blastp" "-db" "nt")
                  (%default-test-context nil '("blastp" "-db" "nt")))))
    ;; taf-app + command-mode 下，应忽略 missing-required，不报错
    (check-equal (taffish.core:taf-result-p result) t)))

(deftest test-taffish-bind-taf-app-command-mode-does-not-ignore-conflict ()
  (let ((code (format nil
                      "ARGS~%<(--/-t)threads>~%RUN~%<taf-app:shell>~%  echo hello~%")))
    ;; taf-app + command-mode 只应忽略 missing-required
    ;; conflict 仍然必须报错
    (check-equal
     (%taffish-bind-signal-error-p
      code
      '("demo" "blastp" "--threads" "8" "-t" "16")
      (%default-test-context nil '("blastp" "--threads" "8" "-t" "16")))
     t)))

(deftest test-taffish-bind-taf-app-command-mode-only-ignores-missing-required ()
  (let* ((code (format nil
                       "ARGS~%<!(--/-i)input>~%<(--/-t)threads>~%RUN~%<taf-app:shell>~%  echo hello~%"))
         (program (taffish.core:parse-taf code)))
    ;; 这里既缺 required input，又制造 conflict
    ;; missing-required 应忽略，但 conflict 不应忽略
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:bind-taf
         program
         '("demo" "blastp" "--threads" "8" "-t" "16")
         (%default-test-context nil
                                '("blastp" "--threads" "8" "-t" "16")))))
     t)))

;;;; ============================================================
;;;; compiler / emitter integration tests
;;;; ============================================================

(deftest test-taffish-to-shell-shell-tag ()
  (let* ((code (format nil
                       "RUN~%<shell>~%  echo 'name: ::(--/-)name=hermit::'~%  echo 'info: ::(--/-)info=hello, @{name}::'~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "echo 'name: alice'") t)
    (check-equal (%string-contains-p shell "echo 'info: hello, alice'") t)
    ;; <shell> should not wrap code into bash heredoc
    (check-equal (%string-contains-p shell "bash <<'EOF'") nil)))

(deftest test-taffish-to-shell-unknown-tag-error ()
  (let ((code (format nil
                      "RUN~%<unknown>~%  echo hello~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:taffish-to-shell
         code
         '("my-cmd")
         (%default-test-context))))
     t)))

(deftest test-taffish-to-shell-podman-container-tag-single-command ()
  (let* ((code (format nil
                       "RUN~%<podman:ghcr.io/taffish/blast:2.16.0>~%  blastp -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell "podman run --rm -i") t)
    (check-equal (%string-contains-p shell " blastp -h") t)
    (check-equal (%string-contains-p shell "bash <<EOF") nil)
    (check-equal (%string-contains-p shell "bash <<'EOF'") nil)
    (check-equal (%string-contains-p shell "# PAYLOAD LIMIT: command + heredoc") t)
    (check-equal (%string-contains-p shell "# HEREDOC QUOTED: no") t)))

(deftest test-taffish-to-shell-podman-container-tag-multiline ()
  (let* ((code (format nil
                       "RUN~%<podman:ghcr.io/taffish/blast:2.16.0>~%  echo \"HOME: $HOME\"~%  pwd~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell "bash <<EOF") t)
    (check-equal (%string-contains-p shell "bash <<'EOF'") nil)
    (check-equal (%string-contains-p shell "# HEREDOC QUOTED: no") t)))

(deftest test-taffish-to-shell-docker-container-tag-quoted-heredoc ()
  (let* ((code (format nil
                       "RUN~%<'docker:ghcr.io/taffish/blast:2.16.0>~%  blastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
    (check-equal (%string-contains-p shell "bash <<'EOF'") t)
    (check-equal (%string-contains-p shell "bash <<EOF") nil)
    (check-equal (%string-contains-p shell "# PAYLOAD LIMIT: heredoc") t)
    (check-equal (%string-contains-p shell "# HEREDOC QUOTED: yes") t)))

(deftest test-taffish-to-shell-docker-podman-order ()
  (let* ((code (format nil
                       "RUN~%<docker/podman:ghcr.io/taffish/blast:2.16.0>~%  blastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
    (check-equal (%string-contains-p shell "docker run --rm -i") t)
    (check-equal (%string-contains-p shell "podman run --rm -i") nil)))

(deftest test-taffish-to-shell-generic-container-uses-default-order ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: APPTAINER") t)
    (check-equal (%string-contains-p shell "apptainer --quiet exec --pwd") t)))

(deftest test-taffish-to-shell-generic-container-uses-forced-backend ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer))
                    (:force-backend . :docker))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
    (check-equal (%string-contains-p shell "# FORCE BACKEND: :DOCKER") t)
    (check-equal (%string-contains-p shell "docker run --rm -i") t)
    (check-equal (%string-contains-p shell "apptainer --quiet exec --pwd") nil)))

(deftest test-taffish-to-shell-container-legacy-run-args-still-work ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0$--network host>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker))
                    (:force-backend . :docker))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
    (check-equal (%string-contains-p shell "--network host") t)))

(deftest test-taffish-to-shell-container-structured-run-args-docker ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[all: --network host][docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker))
                    (:force-backend . :docker))))))
    (let ((final-run-args (%line-containing shell "# FINAL RUN ARGS:")))
      (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
      (check-equal (%string-contains-p final-run-args "--network host --gpus all") t)
      (check-equal (%string-contains-p final-run-args "nvidia.com/gpu") nil)
      (check-equal (%string-contains-p final-run-args "--nv") nil))))

(deftest test-taffish-to-shell-container-structured-run-args-apptainer ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[all: --containall][docker: --gpus all][apptainer: --nv]>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:apptainer))
                    (:force-backend . :apptainer))))))
    (let ((final-run-args (%line-containing shell "# FINAL RUN ARGS:")))
      (check-equal (%string-contains-p shell "# CHOSEN BACKEND: APPTAINER") t)
      (check-equal (%string-contains-p final-run-args "--containall --nv") t)
      (check-equal (%string-contains-p final-run-args "--gpus all") nil))))

(deftest test-taffish-to-shell-container-structured-run-args-combo-target ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[docker/podman: --network host][apptainer: --nv]>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:podman))
                    (:force-backend . :podman))))))
    (let ((final-run-args (%line-containing shell "# FINAL RUN ARGS:")))
      (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
      (check-equal (%string-contains-p final-run-args "--network host") t)
      (check-equal (%string-contains-p final-run-args "--nv") nil))))

(deftest test-taffish-to-shell-container-structured-run-args-escaped-right-bracket ()
  (let* ((code (format nil
                       "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[docker: --label note=a\\]b]>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker))
                    (:force-backend . :docker))))))
    (let ((final-run-args (%line-containing shell "# FINAL RUN ARGS:")))
      (check-equal (%string-contains-p shell "# CHOSEN BACKEND: DOCKER") t)
      (check-equal (%string-contains-p final-run-args "--label note=a]b") t))))

(deftest test-taffish-to-shell-container-structured-run-args-bad-target-error ()
  (let ((code (format nil
                      "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[singularity: --nv]>~%  tblastn -h~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:taffish-to-shell
         code
         (%default-test-input-args)
         (%default-test-context
          '((:available-backends . (:apptainer)))))))
     t)))

(deftest test-taffish-to-shell-container-structured-run-args-empty-error ()
  (let ((code (format nil
                      "RUN~%<container:ghcr.io/taffish/blast:2.16.0$@[docker: ]>~%  tblastn -h~%")))
    (check-equal
     (%taffish-signal-error-p
      (lambda ()
        (taffish.core:taffish-to-shell
         code
         (%default-test-input-args)
         (%default-test-context
          '((:available-backends . (:docker)))))))
     t)))

(deftest test-taffish-to-shell-forced-backend-keeps-explicit-backend ()
  (let* ((code (format nil
                       "RUN~%<podman:ghcr.io/taffish/blast:2.16.0>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer))
                    (:force-backend . :docker))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell "# FORCE BACKEND: :DOCKER") t)
    (check-equal (%string-contains-p shell "podman run --rm -i") t)
    (check-equal (%string-contains-p shell "docker run --rm -i") nil)))

(deftest test-taffish-to-shell-apptainer-container-tag ()
  (let* ((code (format nil
                       "RUN~%<apptainer:ghcr.io/taffish/blast:2.16.0>~%  tblastn -h~%  echo 'workdir: ::*WORKDIR*::'~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: APPTAINER") t)
    (check-equal (%string-contains-p shell "mksquashfs not found") t)
    (check-equal (%string-contains-p shell "squashfs-tools") t)
    (check-equal (%string-contains-p shell "apptainer --quiet pull \"$taffish_sif_file\" \"$taffish_pull_ref\"") t)
    (check-equal (%string-contains-p shell "apptainer --quiet exec --pwd \"/home/alice/Desktop\"") t)
    (check-equal (%string-contains-p shell "--no-home") t)
    (check-equal (%string-contains-p shell "--bind \"/home/alice:/home/alice\"") t)
    (check-equal (%string-contains-p shell "--bind \"/home/alice/Desktop:/home/alice/Desktop\"") nil)
    (check-equal (%string-contains-p shell "HOME=\"/home/alice\" USER=\"alice\" apptainer --quiet exec") t)
    (check-equal (%string-contains-p shell "echo 'workdir: /home/alice/Desktop'") t)))

(deftest test-taffish-to-shell-apptainer-home-workdir-no-duplicate-bind ()
  (let* ((code (format nil
                       "RUN~%<apptainer:ghcr.io/taffish/blast:2.16.0>~%  pwd~%"))
         (context
           '((:cmd . "taf-demo")
             (:user . "someone")
             (:homedir . "/home/someone")
             (:workdir . "/home/someone")
             (:container . ((:available-backends . (:apptainer))))))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 context)))
    (check-equal
     (%string-contains-p
      shell
      "--bind \"/home/someone:/home/someone\" --bind \"/home/someone:/home/someone\"")
     nil)))

(deftest test-taffish-to-shell-apptainer-binds-workdir-outside-home ()
  (let* ((code (format nil
                       "RUN~%<apptainer:ghcr.io/taffish/blast:2.16.0>~%  pwd~%"))
         (context
           '((:cmd . "taf-demo")
             (:user . "someone")
             (:homedir . "/home/someone")
             (:workdir . "/tmp/taf-work")
             (:container . ((:available-backends . (:apptainer))))))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 context)))
    (check-equal (%string-contains-p shell "--bind \"/home/someone:/home/someone\"") t)
    (check-equal (%string-contains-p shell "--bind \"/tmp/taf-work:/tmp/taf-work\"") t)))

(deftest test-taffish-to-shell-apptainer-auto-pull-disabled ()
  (let* ((code (format nil
                       "RUN~%<apptainer:ghcr.io/taffish/blast:2.16.0>~%  tblastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:apptainer))
                    (:apptainer-auto-pull-p . nil))))))
    (check-equal (%string-contains-p shell "apptainer image file not found and auto-pull disabled") t)
    (check-equal (%string-contains-p shell "mksquashfs not found") nil)
    (check-equal (%string-contains-p shell "apptainer --quiet pull \"$taffish_sif_file\" \"$taffish_pull_ref\"") nil)))

;;;; ------------------------------------------------------------
;;;; taf-app integration tests
;;;; ------------------------------------------------------------

(deftest test-taffish-to-shell-taf-app-shell-arg-mode ()
  (let* ((code (format nil
                       "RUN~%<taf-app:shell>~%  echo hello-from-lines~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd" "--name" "alice")
                 (%default-test-context))))
    ;; argv 第一个参数是 -- 开头，所以应保留原始 lines
    (check-equal (%string-contains-p shell "echo hello-from-lines") t)
    (check-equal (%string-contains-p shell "--name alice") nil)))

(deftest test-taffish-to-shell-taf-app-shell-command-mode ()
  (let* ((code (format nil
                       "RUN~%<taf-app:shell>~%  echo hello-from-lines~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("blastp" "-query" "a.fa" "-db" "b")
                 '((:cmd . "taf-app-xxx")
                   (:user . "alice")
                   (:homedir . "/home/alice")
                   (:workdir . "/home/alice/Desktop")
                   (:argv . ("blastp" "-query" "a.fa" "-db" "b"))))))
    ;; argv 第一个参数不是 - 开头，所以应改用 argv-string 作为唯一 line
    (check-equal (%string-contains-p shell "echo hello-from-lines") nil)
    (check-equal (%string-contains-p shell "blastp -query a.fa -db b") t)))

(deftest test-taffish-to-shell-taf-app-podman-arg-mode ()
  (let* ((code (format nil
                       "RUN~%<taf-app:podman:ghcr.io/taffish/blast:2.16.0>~%  blastp -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd" "--name" "alice")
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    ;; 参数模式，保留原始 lines
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell " blastp -h") t)
    (check-equal (%string-contains-p shell "--name alice") nil)))

(deftest test-taffish-to-shell-taf-app-podman-command-mode ()
  (let* ((code (format nil
                       "RUN~%<taf-app:podman:ghcr.io/taffish/blast:2.16.0>~%  blastp -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("blastn" "-db" "nt" "-query" "in.fa")
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))
                  '("blastn" "-db" "nt" "-query" "in.fa")))))
    ;; 命令模式，改用 argv-string 作为唯一 line
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell " blastp -h") nil)
    (check-equal (%string-contains-p shell " blastn -db nt -query in.fa") t)))

(deftest test-taffish-to-shell-taf-app-nil-context-fallback ()
  (let* ((code (format nil
                       "RUN~%<taf-app:shell>~%  echo hello-from-lines~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("blastp" "-query" "a.fa")
                 nil)))
    ;; context 为 NIL 时，不应因为 taf-app 访问 argv/context 报错
    ;; 当前实现应回退为保留原始 lines
    (check-equal (%string-contains-p shell "echo hello-from-lines") t)
    (check-equal (%string-contains-p shell "blastp -query a.fa") nil)))

;;;; ------------------------------------------------------------
;;;; new container edge tests
;;;; ------------------------------------------------------------

(deftest test-taffish-to-shell-container-quoted-tag-preserved ()
  (let* ((code (format nil
                       "RUN~%<'docker:ghcr.io/taffish/blast:2.16.0>~%  blastn -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    ;; strict tag 的原始写法应保留在 prelude 中
    (check-equal (%string-contains-p shell "# TAG: <'docker:ghcr.io/taffish/blast:2.16.0>") t)
    (check-equal (%string-contains-p shell "# PAYLOAD LIMIT: heredoc") t)
    (check-equal (%string-contains-p shell "# HEREDOC QUOTED: yes") t)))

(deftest test-taffish-to-shell-container-single-line-with-pipe-falls-back-heredoc ()
  (let* ((code (format nil
                       "RUN~%<podman:ghcr.io/taffish/blast:2.16.0>~%  echo hello | cat~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    ;; 虽然只有一行，但因为含 |，不能走 command-form，应回退 heredoc
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell "bash <<EOF") t)
    (check-equal (%string-contains-p shell "bash <<'EOF'") nil)
    (check-equal (%string-contains-p shell "echo hello | cat") t)))

(deftest test-taffish-to-shell-container-quoted-single-line-forces-heredoc ()
  (let* ((code (format nil
                       "RUN~%<'podman:ghcr.io/taffish/blast:2.16.0>~%  blastp -h~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 (%default-test-input-args)
                 (%default-test-context
                  '((:available-backends . (:docker :podman :apptainer)))))))
    ;; strict 模式即使只有单行也必须走 quoted heredoc
    (check-equal (%string-contains-p shell "# CHOSEN BACKEND: PODMAN") t)
    (check-equal (%string-contains-p shell "bash <<'EOF'") t)
    (check-equal (%string-contains-p shell "bash <<EOF") nil)
    (check-equal (%string-contains-p shell "# PAYLOAD LIMIT: heredoc") t)
    (check-equal (%string-contains-p shell "# HEREDOC QUOTED: yes") t)))

(deftest test-taffish-to-shell-taffish-plain-lines ()
  (let* ((code (format nil "RUN~%<taffish>~%  echo hello~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd")
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "echo hello") t)
    (check-equal (%string-contains-p shell "mktemp -d") nil)
    (check-equal (%string-contains-p shell "taffish_step_1") nil)))

(deftest test-taffish-to-shell-taffish-one-taf-app ()
  (let* ((code (format nil
                       "RUN~%<taffish>~%  echo hello | [[taf: taf-blast cat ]]~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd")
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "taffish_tmpdir=$(mktemp -d") t)
    (check-equal (%string-contains-p shell "taf-blast --compile cat") t)
    (check-equal (%string-contains-p shell "if taf-blast --compile cat") t)
    (check-equal (%string-contains-p shell "chmod +x \"$taffish_step_1\" || exit 1") t)
    (check-equal (%string-contains-p shell "echo hello | \"$taffish_step_1\"") t)))

(deftest test-taffish-to-shell-taffish-two-taf-apps-pipe ()
  (let* ((code (format nil
                       "RUN~%<taffish>~%  [[taf: taf-a foo]] | [[taf: taf-b bar]]~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd")
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "taf-a --compile foo") t)
    (check-equal (%string-contains-p shell "taf-b --compile bar") t)
    (check-equal (%string-contains-p shell "\"$taffish_step_1\" | \"$taffish_step_2\"") t)))

(deftest test-taffish-to-shell-taffish-escaped-left-bracket ()
  (let* ((code (format nil
                       "RUN~%<taffish>~%  echo \\[[taf: taf-a foo]]~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd")
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "echo [[taf: taf-a foo]]") t)
    (check-equal (%string-contains-p shell "taffish_step_1") nil)
    (check-equal (%string-contains-p shell "mktemp -d") nil)))

(deftest test-taffish-to-shell-taffish-escaped-right-bracket ()
  (let* ((code (format nil
                       "RUN~%<taffish>~%  echo \\] literal~%"))
         (shell (taffish.core:taffish-to-shell
                 code
                 '("my-cmd")
                 (%default-test-context))))
    (check-equal (%string-contains-p shell "echo ] literal") t)
    (check-equal (%string-contains-p shell "taffish_step_1") nil)))

(deftest test-taffish-to-shell-taffish-empty-taf-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:taffish-to-shell
       (format nil "RUN~%<taffish>~%  [[taf:    ]]~%")
       '("my-cmd")
       (%default-test-context))))
   t))

(deftest test-taffish-to-shell-taffish-unclosed-taf-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:taffish-to-shell
       (format nil "RUN~%<taffish>~%  [[taf: taf-a foo~%")
       '("my-cmd")
       (%default-test-context))))
   t))

(deftest test-taffish-to-shell-taffish-non-taf-command-error ()
  (check-equal
   (%taffish-signal-error-p
    (lambda ()
      (taffish.core:taffish-to-shell
       (format nil "RUN~%<taffish>~%  [[taf: echo hello]]~%")
       '("my-cmd")
       (%default-test-context))))
   t))
