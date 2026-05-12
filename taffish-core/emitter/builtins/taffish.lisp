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

(defun %split-once (string split-char)
  (let ((len (length string)))
    (labels ((sb (index)
               (if (>= index len)
                   (values string nil)
                   (if (char= split-char (char string index))
                       (values (subseq string 0 index)
                               (subseq string (1+ index)))
                       (sb (1+ index))))))
      (sb 0))))

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
  (let ((token (list :kind kind :value (format nil "~{~A~}" chars)
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

(defun %scan-taffish-line-source (number src kind tokens chars string)
  (multiple-value-bind (index line column)
      (han.source:source-location src)
    (declare (ignore index line))
    (if (han.source:source-eof-p src)
        (progn
          (if (eql kind :taf-app)
              ;;(error "[line: ~A] '[[taf: ...]]' Missing right match ']]'" number)
              (taffish.core:signal-taffish-error
               "'[[taf: ...]]' Missing right match ']]'"
               :line number
               :column column
               :source-string string)
              (when chars
                (push (%chars-to-token number column kind (nreverse chars))
                      tokens)))
          (nreverse tokens))
        (case kind
          (:text
           (cond
             ((han.source:source-consume-string-if src "\\[")
              (%scan-taffish-line-source
               number src kind tokens (push #\[ chars) string))
             ((han.source:source-consume-string-if src "\\]")
              (%scan-taffish-line-source
               number src kind tokens (push #\] chars) string))
             ((han.source:source-consume-string-if src "[[taf:")
              (%scan-taffish-line-source
               number src :taf-app
               (if chars
                   (push (%chars-to-token number column kind (nreverse chars))
                         tokens)
                   tokens)
               nil string))
             (t
              (%scan-taffish-line-source
               number src kind tokens
               (push (han.source:source-next-char src) chars) string))))
          (:taf-app
           (if (han.source:source-consume-string-if src "]]")
               (%scan-taffish-line-source
                number src :text
                (if (%non-blank-chars-p chars)
                    (push (%chars-to-token number column kind (nreverse chars))
                          tokens)
                    ;;(error "[line: ~A] '[[taf: ...]]' is empty!" number)
                    (taffish.core:signal-taffish-error
                     "'[[taf: ...]]' is empty!"
                     :line number
                     :column column
                     :source-string string))
                nil string)
               (%scan-taffish-line-source
                number src kind tokens
                (push (han.source:source-next-char src) chars) string)))))))

;; token: (:kind <:text | :taf-app> :value <string>)
(defun %scan-taffish-line (taffish-line)
  (let* ((number (getf taffish-line :number))
         (string (getf taffish-line :line))
         (src (han.source:make-char-source string)))
    (%scan-taffish-line-source number src :text nil nil string)))

;;;; ------------------------------------------------------------
;;;; emit emitter
;;;; ------------------------------------------------------------

(defun %sure-compiled (taf-app)
  "taf-xxx aaa ... -> taf-xxx --compile aaa ..."
  (let* ((raw-string (getf taf-app :value))
         (string (%clean-string raw-string)))
    (multiple-value-bind (cmd raw-options)
        (%split-once string #\Space)
      (if (%string-prefix-p "taf-" cmd)
          (if raw-options
              (let ((options (%clean-left-string raw-options)))
                (multiple-value-bind (first-option rest-options)
                    (%split-once options #\Space)
                  (declare (ignore rest-options))
                  (if (string= "--compile" (%clean-string first-option))
                      string
                      (format nil "~A --compile ~A" cmd options))))
              (format nil "~A --compile" cmd))
          ;;(error "'[[taf: CMD ...]]' CMD must start with 'taf-', but: ~S" cmd)
          (taffish.core:signal-taffish-error
           (format nil "'[[taf: CMD ...]]' CMD must start with 'taf-', but: ~S" cmd)
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
                  (format nil "taffish_step_~A=\"$taffish_tmpdir/step-~A-taf-xxx.sh\""
                          number number)
                  (format nil "if ~A > \"$taffish_step_~A\" ; then"
                          compiled-value number)
                  "    :"
                  "else"
                  (format nil "    echo \"[TAFFISH] failed to compile taf step: ~A\" >&2"
                          compiled-value)
                  "    exit 1"
                  "fi"
                  (format nil "chmod +x \"$taffish_step_~A\" || exit 1" number)
                  "")))
          (dolist (line append-lines) (push line prelude-lines))))
      (nreverse prelude-lines))))

(defun %parse-token-string (token)
  (case (getf token :kind)
    (:text (getf token :value))
    (:taf-app (format nil "\"$taffish_step_~A\"" (getf token :number)))))

(defun %tokened-line-to-string (tokened-line)
  "TOKENED-LINE-LIST -> LINE-STRING"
  (let ((string-list nil))
    (dolist (token tokened-line)
      (push (%parse-token-string token) string-list))
    (format nil "~{~A~}" (nreverse string-list))))

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
