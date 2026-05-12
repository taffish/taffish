(in-package :taffish.core)

;;;; ============================================================
;;;; parser.lisp
;;;; ============================================================

(defun %get-first-effective-line (taf-lines &optional (skip-kinds '(:empty :comment)))
  (let ((line (car taf-lines)))
    (when line
      (if (member (taf-line-kind line) skip-kinds :test #'eql)
          (%get-first-effective-line (cdr taf-lines) skip-kinds)
          line))))

(defun %make-tag-line (tag)
  (%make-taf-line-from-raw tag 0))

(defun %make-<>-line (value)
  (%make-taf-line-from-raw (format nil "<~A>" value) 0))

(defun %normalize-taf-lines (taf-lines)
  "Normalize RAW-TAF-LINES into normalized TAF-LINES
- ARGS/RUN -> do nothing, must have subtag;
- <...>    -> add \"RUN\" before lines, must ignore ARGS;
- ...      -> add \"RUN\" and \"<taffish>\" before lines.
"
  (let ((first-effective-line (%get-first-effective-line taf-lines)))
    (cond
      ((null first-effective-line)
       (error "You can't compile an empty taf file!"))
      ((eql :tag (taf-line-kind first-effective-line))
       (case (taf-line-subkind first-effective-line)
         (:subtag (cons (%make-tag-line "RUN") taf-lines))
         (t taf-lines)))
      ((eql :code (taf-line-kind first-effective-line))
       (append (list (%make-tag-line "RUN")
                     (%make-<>-line "taffish"))
               taf-lines))
      (t
       ;;(error "Unknown TAF-LINE kind: ~A" (taf-line-kind first-effective-line))
       (signal-taffish-error
        (format nil "Unknown TAF-LINE kind: ~A" (taf-line-kind first-effective-line))
        :line (taf-line-line-number first-effective-line)
        :column nil
        :source-string (taf-line-raw-string first-effective-line))))))

(defun %extract-inline-args (taf-lines)
  "Extract args from all lines ::...::"
  (let ((args nil))
    (dolist (line taf-lines)
      (let ((tokens (taf-line-tokens line)))
        (dolist (token tokens)
          (case (taf-token-kind token)
            (:arg (push (taf-token-value token) args))))))
    (nreverse args)))

(defun %build-args-spec (args-list)
  (han.args:parse-args-spec (mapcar #'han.args:parse-arg-spec args-list)))

(defun %normalize-block-subtags (args-or-run-block)
  (let ((block-list nil)
        (subtag-list nil))
    (dolist (line args-or-run-block)
      (case (taf-line-kind line)
        (:tag
         (unless (eql :subtag (taf-line-subkind line))
           ;;(error "[line: ~A] Unexpected primary tag inside block: ~A"
           ;;       (taf-line-line-number line)
           ;;       (taf-line-raw-string line))
           (signal-taffish-error
            "Unexpected primary tag inside block."
            :line (taf-line-line-number line)
            :column nil
            :source-string (taf-line-raw-string line)))
         (when subtag-list
           (push (nreverse subtag-list) block-list))
         (setf subtag-list (list line)))
        ((:empty :comment)
         (when subtag-list (push line subtag-list)))
        (:code
         (unless subtag-list
           ;;(error "[line: ~A] Code appears before any SUB-TAG: ~A"
           ;;       (taf-line-line-number line)
           ;;       (taf-line-raw-string line))
           (signal-taffish-error
            "Code appears before any SUB-TAG."
            :line (taf-line-line-number line)
            :column nil
            :source-string (taf-line-raw-string line)))
         (push line subtag-list))))
    (when subtag-list (push (nreverse subtag-list) block-list))
    (nreverse block-list)))

(defun %split-args-run (taf-lines)
  (let ((args-or-run :not-start)
        (args-block nil)
        (run-block nil))
    (dolist (line taf-lines)
      (let ((kind (taf-line-kind line))
            (subkind (taf-line-subkind line)))
        (case kind
          ((:empty :comment :code)
           (case args-or-run
             (:args (push line args-block))
             (:run  (push line run-block))))
          (:tag
           (case subkind
             (:args
              (case args-or-run
                (:not-start
                 (setf args-or-run :args))
                (:args
                 ;;(error "[line: ~A] Duplicate ARGS block."
                 ;;       (taf-line-line-number line))
                 (signal-taffish-error
                  "Duplicate ARGS block."
                  :line (taf-line-line-number line)
                  :column nil
                  :source-string (taf-line-raw-string line)))
                (:run
                 ;;(error "[line: ~A] You can't set ARGS after RUN block."
                 ;;       (taf-line-line-number line))
                 (signal-taffish-error
                  "You can't set ARGS after RUN block."
                  :line (taf-line-line-number line)
                  :column nil
                  :source-string (taf-line-raw-string line)))))
             (:run
              (case args-or-run
                (:not-start
                 (setf args-or-run :run))
                (:args
                 (setf args-or-run :run))
                (:run
                 ;;(error "[line: ~A] Duplicate RUN block."
                 ;;       (taf-line-line-number line))
                 (signal-taffish-error
                  "Duplicate RUN block."
                  :line (taf-line-line-number line)
                  :column nil
                  :source-string (taf-line-raw-string line)))))
             (t
              (case args-or-run
                (:args (push line args-block))
                (:run  (push line run-block))))))
          (t
           ;;(error "Unknown TAF-LINE kind: ~A" kind)
           (signal-taffish-error
            "Unknown TAF-LINE kind."
            :line (taf-line-line-number line)
            :column nil
            :source-string (taf-line-raw-string line))))))
    (values (%normalize-block-subtags (nreverse args-block))
            (%normalize-block-subtags (nreverse run-block)))))

(defun %combine-args-value-lines-to-default (args-value-lines)
  (let ((lines (mapcar #'taf-line-tokens
                       (remove-if-not #'(lambda (line)
                                          (eql :code (taf-line-kind line)))
                                      args-value-lines)))
        (default-list nil))
    (dolist (line lines)
      (dolist (token line)
        (let ((kind (taf-token-kind token)))
          (case kind
            (:arg
             (push (format nil "@{~A}"
                           (han.args:arg-spec-name
                            (han.args:parse-arg-spec
                             (taf-token-value token))))
                   default-list))
            (:text
             (push (taf-token-value token)
                   default-list)))))
      (push " " default-list))
    (format nil "~{~A~}" (nreverse (cdr default-list)))))

(defun %subtag-head-p (line)
  (and line
       (eql :tag (taf-line-kind line))
       (eql :subtag (taf-line-subkind line))))

(defun %subtag-head-string (head)
  (unless (%subtag-head-p head)
    ;;(error "ARGS block does not start with SUB-TAG.")
    (signal-taffish-error
     "ARGS block does not start with SUB-TAG."
     :line (taf-line-line-number head)
     :column nil
     :source-string (taf-line-raw-string head)))
  (dolist (token (taf-line-tokens head))
    (unless (eql :text (taf-token-kind token))
      ;;(error "[line: ~A, column: ~A] ARGS SUB-TAG head can't contain arg token: ~A"
      ;;       (taf-token-line token)
      ;;       (taf-token-column token)
      ;;       (taf-token-raw-string token))
      (signal-taffish-error
       "ARGS SUB-TAG head can't contain arg token"
       :line (taf-token-line token)
       :column (taf-token-column token)
       :source-string (taf-line-raw-string head))))
  (format nil "~{~A~}" (mapcar #'taf-token-value (taf-line-tokens head))))

(defun %extract-block-args (args-block)
  (mapcar #'(lambda (arg-block)
              (let ((head (car arg-block)))
                (format nil "~A=~A"
                        (%subtag-head-string head)
                        (%combine-args-value-lines-to-default (cdr arg-block)))))
          args-block))

(defun %singlep (list)
  (and list (null (cdr list))))

(defun %effective-lines (lines)
  (remove-if #'(lambda (line)
                 (member (taf-line-kind line) '(:empty :comment) :test #'eql))
             lines))

(defun %validate-no-empty-subtag (blocks)
  (dolist (a-block blocks)
    (let ((effective-lines (%effective-lines a-block)))
      (when (%singlep effective-lines)
        (let* ((line (car effective-lines))
               (line-string (taf-line-raw-string line)))
          ;;(error "[line: ~A] There is no content under your SUB-TAG [~A]"
          ;;       (taf-line-line-number line)
          ;;       (string-trim '(#\Space #\Tab) (taf-line-raw-string line)))
          (signal-taffish-error
           (format nil "There is no content under your SUB-TAG [~A]."
                   (string-trim '(#\Space #\Tab) line-string))
           :line (taf-line-line-number line)
           :column nil
           :source-string line-string))))))

(defun %validate-run-block (run-block)
  (unless run-block
    (error "Your TAF CODE must have RUN block!"))
  (%validate-no-empty-subtag run-block)
  run-block)

(defun %validate-args-block (args-block)
  ;; allow ARGS has empty subtag
  ;;(%validate-no-empty-subtag args-block)
  args-block)

(defun %builtin-arg-name-p (arg-name)
  (and (stringp arg-name)
       (member (string-upcase arg-name)
               '("*USER*" "*HOMEDIR*" "*WORKDIR*" "*LOADDIR*"
                 "*ARGV*" "*CMD*" "*CPUS*" "*CONTAINER*")
               :test #'string=)))

(defun %dead-arg-p (arg-name args-spec)
  (multiple-value-bind (arg arg-p)
      (gethash arg-name (han.args:args-spec-args-table args-spec))
    (unless arg-p
      (error "Can't find arg <~A> in all args' spec, it's impossible!"
             arg-name))
    (let ((arity (han.args:arg-spec-arity arg))
          (long  (han.args:arg-spec-long-entry  arg))
          (short (han.args:arg-spec-short-entry arg))
          (slot  (han.args:arg-spec-slot-entry  arg))
          (default (han.args:arg-spec-default   arg)))
      (cond
        ((and (eql :single arity)
              (null long) (null short) (null default))
         t)
        ((and (eql :block arity)
              (null slot) (null default))
         t)
        (t
         nil)))))

(defun %validate-args-used (args-spec taf-lines)
  (dolist (line taf-lines)
    (let ((tokens (taf-line-tokens line)))
      (dolist (token tokens)
        (when (eql :arg (taf-token-kind token))
          (let ((arg-name (han.args:arg-spec-name
                           (han.args:parse-arg-spec
                            (taf-token-value token)))))
            (unless (%builtin-arg-name-p arg-name)
              (when (%dead-arg-p arg-name args-spec)
                ;;(error "[line: ~A, column: ~A] ~A arg can't be set and no default!"
                ;;       (taf-token-line token) (taf-token-column token) arg-name)
                (signal-taffish-error
                 (format nil "[~A] arg can't be set and no default!" arg-name)
                 :line (taf-token-line token)
                 :column (taf-token-column token)
                 :source-string (taf-line-raw-string line))))))))))

(defun parse-taf (taf-code)
  "Parse TAF-CODE string into a TAF-PROGRAM."
  (let* ((taf-lines (lex-taf taf-code))
         (lines (%normalize-taf-lines taf-lines))
         (inline-args (%extract-inline-args lines)))
    (multiple-value-bind (raw-args-block raw-run-block)
        (%split-args-run lines)
      (let ((args-block (%validate-args-block raw-args-block))
            (run-block (%validate-run-block raw-run-block)))
        (let* ((block-args (%extract-block-args args-block))
               (args-spec (%build-args-spec (append block-args inline-args)))
               (body run-block))
          (%validate-args-used args-spec lines)
          (make-taf-program
           :source-string taf-code
           :lines lines
           :args-spec args-spec
           :body body
           :metadata nil))))))
