;;;; ============================================================
;;;; emitter: builtins: taffish.lisp
;;;; ============================================================

(defpackage :taffish.emitter.builtins.taffish
  (:use :cl)
  (:export
   :match-taffish-tag
   :emit-taffish
   ;; :prelude-taffish
   ;; :finalize-taffish
   ))

(in-package :taffish.emitter.builtins.taffish)

;;;; ------------------------------------------------------------
;;;; helper emitter
;;;; ------------------------------------------------------------

(defun %clean-string (string &optional (trim-fun #'string-trim))
  (funcall trim-fun '(#\Space #\Tab) string))

(defun %clean-left-string (string)
  (%clean-string string #'string-left-trim))

(defun %split-first-word (string)
  ;; Inspect only the command/control word; keep the remaining shell text.
  (let ((separator (position-if (lambda (char)
                                  (member char '(#\Space #\Tab) :test #'char=))
                                string)))
    (if separator
        (values (subseq string 0 separator) (subseq string (1+ separator)))
        (values string nil))))

(defun %string-prefix-p (prefix string)
  (let ((src (han.source:make-char-source string)))
    (han.source:source-consume-string-if src prefix)))

;;;; ------------------------------------------------------------
;;;; match emitter
;;;; ------------------------------------------------------------

(defun match-taffish-tag (tag line-number)
  (when (string-equal tag "taffish")
    (list :kind :taffish
          :tag tag
          :line-number line-number)))

;;;; ------------------------------------------------------------
;;;; token emitter
;;;; ------------------------------------------------------------

(defparameter *taf-apps-count* 1)

(defparameter *all-taf-apps* nil)

(defun %chars-to-token (line-number line-column kind chars)
  (let ((token (list :kind kind :value (taffish.core::%format-character-string "~{~A~}" chars)
                     :line-number line-number
                     :line-column line-column
                     :number *taf-apps-count*)))
    (case kind
      (:text token)
      (:taf-app
       (incf *taf-apps-count*)
       (push token *all-taf-apps*)
       token))))

(defun %non-blank-chars-p (chars)
  (and chars
       (some (lambda (c)
               (not (member c '(#\Space #\Tab) :test #'char=)))
             chars)))

(defun %inline-parts-string (parts)
  (taffish.core::%format-character-string
   "~{~A~}" (mapcar (lambda (part) (getf part :text)) parts)))

(defun %source-inline-parts (line)
  "Unbound source parts for dependency scanning; argument text stays opaque."
  (if (member (taffish.core:taf-line-kind line) '(:empty :comment))
      (list (list :kind :text :text (taffish.core:taf-line-raw-string line)))
      (mapcar (lambda (token)
                (list :kind (taffish.core:taf-token-kind token) :token token
                      :text (if (eq (taffish.core:taf-token-kind token) :arg)
                                (taffish.core:taf-token-raw-string token)
                                (taffish.core:taf-token-value token))))
              (taffish.core:taf-line-tokens line))))

(defun %inline-source-column (part offset)
  (let ((token (getf part :token)))
    (if (null token)
        (1+ offset)
        (let ((raw (taffish.core:taf-token-raw-string token)) (index 0))
          (dotimes (i offset)
            (when (and (char= (char raw index) #\\)
                       (< (1+ index) (length raw))
                       (taffish.core::%taf-escaped-char-p (char raw (1+ index))))
              (incf index))
            (incf index))
          (+ (taffish.core:taf-token-column token) index)))))

(defun %scan-inline-parts (parts number source)
  "Scan source text only. Resolved arguments cannot open, close or quote a call."
  (let ((nodes nil) (pieces nil) (kind :text) (quote-char nil)
        (escaped nil) (column 1))
    (labels ((flush-node ()
               (when (or pieces (eq kind :taf-app))
                 (push (list :kind kind :parts (nreverse pieces)
                             :line-number number :line-column column)
                       nodes)
                 (setf pieces nil)))
             (prefix-at-p (text i prefix)
               (and (<= (+ i (length prefix)) (length text))
                    (string= prefix text :start2 i :end2 (+ i (length prefix))))))
      (dolist (part parts)
        (if (eq (getf part :kind) :arg)
            (progn
              (push part pieces)
              ;; Even an empty argument is a boundary, not adjacent source text.
              (setf escaped nil))
            (let* ((text (getf part :text)) (len (length text)) (start 0) (i 0))
              (labels ((save-text (end)
                         (when (< start end)
                           (push (list :kind :text :text (subseq text start end)) pieces))))
                (loop while (< i len)
                      for char = (char text i)
                      do (cond
                           ((eq kind :text)
                            (cond
                              ((and (char= char #\\) (< (1+ i) len)
                                    (find (char text (1+ i)) "[]"))
                               (incf i 2))
                              ((prefix-at-p text i "[[taf:")
                               (save-text i)
                               (flush-node)
                               (setf kind :taf-app quote-char nil escaped nil
                                     column (%inline-source-column part i))
                               (incf i 6)
                               (setf start i))
                              (t (incf i))))
                           (escaped (setf escaped nil) (incf i))
                           ((eql quote-char #\')
                            (when (char= char #\') (setf quote-char nil))
                            (incf i))
                           ((char= char #\\) (setf escaped t) (incf i))
                           (quote-char
                            (when (char= char quote-char) (setf quote-char nil))
                            (incf i))
                           ((find char "\"'") (setf quote-char char) (incf i))
                           ((prefix-at-p text i "]]")
                            (save-text i)
                            (flush-node)
                            (setf kind :text)
                            (incf i 2)
                            (setf start i))
                           (t (incf i))))
                (save-text len)))))
      (when (eq kind :taf-app)
        (taffish.core:signal-taffish-error
         "'[[taf: ...]]' Missing right match ']]'"
         :line number :column column :source-string source))
      (flush-node)
      (nreverse nodes))))

(defun %resolved-inline-parts (line)
  (let* ((absent (gensym))
         (source (getf line :source-line absent))
         (parts (getf line :resolved-parts absent))
         (text (getf line :line))
         (offset 0))
    (when (and (eq source absent) (eq parts absent))
      (return-from %resolved-inline-parts (list (list :kind :text :text text))))
    (unless (and (taffish.core:taf-line-p source) (listp parts)
                 (let ((original (%source-inline-parts source)))
                   (and (= (length original) (length parts))
                        (every (lambda (part initial)
                                 (and (listp part)
                                      (eq (getf part :token) (getf initial :token))
                                      (eq (getf part :kind) (getf initial :kind))
                                      (or (eq (getf part :kind) :arg)
                                          (equal (getf part :text) (getf initial :text)))))
                               parts original)))
                 (every (lambda (part)
                          (let ((value (getf part :text)))
                            (and (member (getf part :kind) '(:text :arg))
                                 (stringp value)
                                 (<= (+ offset (length value)) (length text))
                                 (prog1 (string= value text :start2 offset
                                                           :end2 (+ offset (length value)))
                                   (incf offset (length value))))))
                        parts)
                 (= offset (length text)))
      (taffish.core:signal-taffish-error
       "Inconsistent inline source metadata"
       :line (getf line :number) :source-string text))
    parts))

(defun %decode-text-brackets (string)
  ;; Keep the old text escape behavior, including escapes spanning source/args.
  (let ((src (han.source:make-char-source string)))
    (han.host:with-character-output-to-string (out)
      (loop until (han.source:source-eof-p src)
            do (cond
                 ((han.source:source-consume-string-if src "\\[") (write-char #\[ out))
                 ((han.source:source-consume-string-if src "\\]") (write-char #\] out))
                 (t (write-char (han.source:source-next-char src) out)))))))

;; token: (:kind <:text | :taf-app> :value <string>)
(defun %scan-taffish-line (line)
  (let* ((number (getf line :number))
         (parts (%resolved-inline-parts line))
         (source (getf line :source-line))
         (text (if source (taffish.core:taf-line-raw-string source) (getf line :line))))
    ;; Validate provenance first, then honor the lexer classification. Resolved
    ;; arguments cannot turn a source code line into a comment. Legacy callers
    ;; have no provenance, so classify their supplied text with the same lexer.
    (when (eq :comment (if source (taffish.core:taf-line-kind source)
                          (taffish.core::%line-kind-and-subkind text)))
      (return-from %scan-taffish-line
        (list (%chars-to-token number 1 :text (list (getf line :line))))))
    (mapcar
     (lambda (node)
       (let* ((kind (getf node :kind))
              (value (%inline-parts-string (getf node :parts)))
              (column (getf node :line-column)))
         (when (and (eq kind :taf-app) (not (%non-blank-chars-p value)))
           (taffish.core:signal-taffish-error
            "'[[taf: ...]]' is empty!" :line number :column column :source-string text))
         (%chars-to-token number column kind
                          (list (if (eq kind :text) (%decode-text-brackets value) value)))))
     (%scan-inline-parts parts number text))))

;;;; ------------------------------------------------------------
;;;; emit emitter
;;;; ------------------------------------------------------------

(defun %sure-compiled (taf-app)
  "taf-xxx aaa ... -> taf-xxx --compile aaa ..."
  (let* ((raw-string (getf taf-app :value))
         (string (%clean-string raw-string)))
    (multiple-value-bind (cmd raw-options)
        (%split-first-word string)
      (if (%string-prefix-p "taf-" cmd)
          (if raw-options
              (let ((options (%clean-left-string raw-options)))
                (multiple-value-bind (first-option rest-options)
                    (%split-first-word options)
                  (declare (ignore rest-options))
                  (if (string= "--compile" (%clean-string first-option))
                      string
                      (taffish.core::%format-character-string "~A --compile ~A" cmd options))))
              (taffish.core::%format-character-string "~A --compile" cmd))
          ;;(error "'[[taf: CMD ...]]' CMD must start with 'taf-', but: ~S" cmd)
          (taffish.core:signal-taffish-error
           (taffish.core::%format-character-string "'[[taf: CMD ...]]' CMD must start with 'taf-', but: ~S" cmd)
           :line (getf taf-app :line-number)
           :column (getf taf-app :line-column)
           :source-string raw-string)))))

(defun %make-taf-app-prelude-lines (&optional (taf-apps (reverse *all-taf-apps*)))
  "Make prelude lines for taf-apps"
  (when taf-apps
    (let ((prelude-lines
            (reverse
             (list
              ""
              "taffish_tmpdir=$(mktemp -d \"${TMPDIR:-/tmp}/taffish.XXXXXX\") || exit 1"
              "trap 'rm -rf \"$taffish_tmpdir\"' EXIT INT TERM HUP"
              ""))))
      (dolist (taf-app taf-apps)
        (let* ((number (getf taf-app :number))
               (compiled-value (%sure-compiled taf-app))
               (append-lines
                 (list
                  (taffish.core::%format-character-string "taffish_step_~A=\"$taffish_tmpdir/step-~A-taf-xxx.sh\""
                          number number)
                  (taffish.core::%format-character-string "if ~A > \"$taffish_step_~A\" ; then"
                          compiled-value number)
                  "    :"
                  "else"
                  (taffish.core::%format-character-string "    printf '%s\\n' ~A >&2"
                    (han.os:escape-sh-token
                     (taffish.core::%format-character-string
                      "[TAFFISH] failed to compile taf step: ~A" compiled-value)))
                  "    exit 1"
                  "fi"
                  (taffish.core::%format-character-string "chmod +x \"$taffish_step_~A\" || exit 1" number)
                  "")))
          (dolist (line append-lines) (push line prelude-lines))))
      (nreverse prelude-lines))))

(defun %parse-token-string (token)
  (case (getf token :kind)
    (:text (getf token :value))
    (:taf-app (taffish.core::%format-character-string "\"$taffish_step_~A\"" (getf token :number)))))

(defun %tokened-line-to-string (tokened-line)
  "TOKENED-LINE-LIST -> LINE-STRING"
  (let ((string-list nil))
    (dolist (token tokened-line)
      (push (%parse-token-string token) string-list))
    (taffish.core::%format-character-string "~{~A~}" (nreverse string-list))))

(defun emit-taffish (parsed-info lines taf-result)
  (declare (ignore parsed-info taf-result))
  ;;(setf *taf-apps-count* 1)
  ;;(setf *all-taf-apps* nil)
  (let ((*taf-apps-count* 1)
        (*all-taf-apps* nil)
        (resolved-lines nil))
    (dolist (raw-line lines)
      (let ((tokened-line (%scan-taffish-line raw-line)))
        (push (%tokened-line-to-string tokened-line) resolved-lines)))
    (append (%make-taf-app-prelude-lines (reverse *all-taf-apps*))
            (nreverse resolved-lines))))

;;;; ============================================================
;;;; emitter: builtins: taffish.lisp
;;;; ============================================================

(in-package :taffish.core)

(defemitter taffish
  :match-function #'taffish.emitter.builtins.taffish:match-taffish-tag
  :emit-function  #'taffish.emitter.builtins.taffish:emit-taffish
  ;; :prelude-function  #'taffish.emitter.builtins.taffish:prelude-taffish
  ;; :finalize-function #'taffish.emitter.builtins.taffish:finalize-taffish
  )
