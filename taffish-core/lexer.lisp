(in-package :taffish.core)

;;;; ============================================================
;;;; lexer.lisp
;;;; ============================================================

(defun %space-or-tab-p (char)
  (or (char= char #\Space)
      (char= char #\Tab)))

(defun %taf-escaped-char-p (char)
  (member char (list #\: #\< #\# #\\) :test #'char=))

(defun %trim-space-tab (string)
  (string-trim (list #\Space #\Tab) string))

(defun %read-taf-line (source)
  "Read one logical line from SOURCE.
Supports LF, CRLF and CR. Returns NIL at EOF before reading anything."
  (when (han.source:source-eof-p source)
    (return-from %read-taf-line nil))
  (let ((chars nil))
    (labels ((read-next ()
               (if (han.source:source-eof-p source)
                   (coerce (nreverse chars) 'string)
                   (let ((char (han.source:source-next-char source)))
                     (cond
                       ((char= char #\Newline)
                        (coerce (nreverse chars) 'string))
                       ((char= char #\Return)
                        (when (and (not (han.source:source-eof-p source))
                                   (char= (han.source:source-peek-char source)
                                          #\Newline))
                          (han.source:source-next-char source))
                        (coerce (nreverse chars) 'string))
                       (t
                        (push char chars)
                        (read-next)))))))
      (read-next))))

(defun %line-kind-and-subkind (raw-string)
  (let ((trimmed (%trim-space-tab raw-string)))
    (cond
      ((string= trimmed "")
       (values :empty nil))
      ((and (> (length trimmed) 0)
            (char= (char trimmed 0) #\#))
       (values :comment nil))
      ((string= trimmed "ARGS")
       (values :tag :args))
      ((string= trimmed "RUN")
       (values :tag :run))
      ((and (>= (length trimmed) 2)
            (char= (char trimmed 0) #\<)
            (char= (char trimmed (1- (length trimmed))) #\>))
       (values :tag :subtag))
      (t
       (values :code nil)))))

(defun %first-non-space-tab-index (string)
  (let ((len (length string)))
    (labels ((scan (index)
               (cond
                 ((>= index len) nil)
                 ((%space-or-tab-p (char string index))
                  (scan (1+ index)))
                 (t index))))
      (scan 0))))

(defun %last-non-space-tab-index (string)
  (let ((len (length string)))
    (labels ((scan (index)
               (cond
                 ((< index 0) nil)
                 ((%space-or-tab-p (char string index))
                  (scan (1- index)))
                 (t index))))
      (scan (1- len)))))

(defun %make-text-token (text line-number column)
  (make-taf-token :raw-string text
                  :value text
                  :kind :text
                  :line line-number
                  :column column))

(defun %make-arg-token (raw value line-number column)
  (make-taf-token :raw-string raw
                  :value value
                  :kind :arg
                  :line line-number
                  :column column))

(defun %lex-line-content (content line-number base-column)
  "Lex CONTENT into :TEXT and :ARG tokens without shell-style word splitting.

TAF escape rule:
  \\:  => :
  \\<  => <
  \\#  => #
  \\\\  => \\

Only these five escaped characters are consumed by TAF lexer.
Other backslash sequences are preserved as normal text.

BASE-COLUMN is the original column of CONTENT's first character."
  (let ((len (length content))
        (tokens nil))
    (labels ((emit-text (raw-chars value-chars start-index)
               (when raw-chars
                 (push (make-taf-token
                        :raw-string (coerce (nreverse raw-chars) 'string)
                        :value (coerce (nreverse value-chars) 'string)
                        :kind :text
                        :line line-number
                        :column (+ base-column start-index))
                       tokens)))
             (escaped-special-at-p (index)
               (and (< (1+ index) len)
                    (char= (char content index) #\\)
                    (%taf-escaped-char-p (char content (1+ index)))))
             (double-colon-at-p (index)
               (and (< (1+ index) len)
                    (char= (char content index) #\:)
                    (char= (char content (1+ index)) #\:)))
             (find-close (index)
               (cond
                 ((>= (1+ index) len)
                  nil)
                 ((escaped-special-at-p index)
                  ;; Escaped char cannot start a closing :: marker.
                  (find-close (+ index 2)))
                 ((double-colon-at-p index)
                  index)
                 (t
                  (find-close (1+ index)))))
             (scan (index text-start raw-chars value-chars)
               (cond
                 ((>= index len)
                  (emit-text raw-chars value-chars text-start)
                  (nreverse tokens))
                 ((escaped-special-at-p index)
                  ;; Preserve raw form, but emit only the escaped character as value.
                  (scan (+ index 2)
                        text-start
                        (cons (char content (1+ index))
                              (cons (char content index) raw-chars))
                        (cons (char content (1+ index)) value-chars)))
                 ((double-colon-at-p index)
                  (let ((close-index (find-close (+ index 2))))
                    (unless close-index
                      ;;(error "Unclosed arg token at line ~A, column ~A."
                      ;;       line-number (+ base-column index))
                      (signal-taffish-error
                       "Unclosed arg token."
                       :line line-number
                       :column (+ base-column index)
                       :source-string content))
                    (emit-text raw-chars value-chars text-start)
                    (let* ((raw (subseq content index (+ close-index 2)))
                           (value (subseq content (+ index 2) close-index)))
                      (push (%make-arg-token raw value
                                             line-number
                                             (+ base-column index))
                            tokens))
                    (scan (+ close-index 2)
                          (+ close-index 2)
                          nil
                          nil)))
                 (t
                  (scan (1+ index)
                        text-start
                        (cons (char content index) raw-chars)
                        (cons (char content index) value-chars))))))
      (scan 0 0 nil nil))))

(defun %subtag-content-and-column (raw-string line-number)
  "Return inner content of a <...> line and its original base column."
  (let ((left (%first-non-space-tab-index raw-string))
        (right (%last-non-space-tab-index raw-string)))
    (unless (and left right
                 (< left right)
                 (char= (char raw-string left) #\<)
                 (char= (char raw-string right) #\>))
      ;;(error "Invalid subtag line: ~A" raw-string)
      (signal-taffish-error
       "Invalid subtag line."
       :line line-number
       :column nil
       :source-string raw-string))
    (values (subseq raw-string (1+ left) right)
            (+ 2 left))))

(defun %make-taf-line-from-raw (raw-string line-number)
  (multiple-value-bind (kind subkind)
      (%line-kind-and-subkind raw-string)
    (let ((tokens
            (cond
              ((eql kind :code)
               (%lex-line-content raw-string line-number 1))
              ((and (eql kind :tag)
                    (eql subkind :subtag))
               (multiple-value-bind (content base-column)
                   (%subtag-content-and-column raw-string line-number)
                 (%lex-line-content content line-number base-column)))
              (t
               nil))))
      (make-taf-line :raw-string raw-string
                     :tokens tokens
                     :kind kind
                     :subkind subkind
                     :line-number line-number))))

(defun lex-taf (taf-code)
  "Lex TAF-CODE string into a list of TAF-LINE objects."
  (unless (stringp taf-code)
    (error "TAF-CODE must be a string, but got: ~A." (type-of taf-code)))
  (let ((source (han.source:make-char-source taf-code))
        (lines nil))
    (labels ((scan (line-number)
               (let ((raw (%read-taf-line source)))
                 (if raw
                     (progn
                       (push (%make-taf-line-from-raw raw line-number)
                             lines)
                       (scan (1+ line-number)))
                     (nreverse lines)))))
      (scan 1))))
