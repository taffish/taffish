(in-package :taffish.core)

;;;; ============================================================
;;;; compiler.lisp
;;;; ============================================================

(defun %resolve-taf-token (taf-token args-result)
  (let ((kind (taf-token-kind taf-token))
        (token-value (taf-token-value taf-token)))
    (case kind
      (:text token-value)
      (:arg
       (multiple-value-bind (arg-value status)
           (han.args:get-arg token-value args-result)
         (if status
             (or arg-value "")
             ;;(error "It's impossible to see this error!")
             (error "Failed to resolve arg token: ~A" token-value)))))))

(defun %resolve-taf-line (taf-line args-result)
  (let ((kind (taf-line-kind taf-line)))
    (list :line
          (case kind
            ((:empty :comment)
             (taf-line-raw-string taf-line))
            (t
             (let ((parts nil))
               (dolist (taf-token (taf-line-tokens taf-line))
                 (push (%resolve-taf-token taf-token args-result) parts))
               (format nil "~{~A~}" (nreverse parts)))))
          :number (taf-line-line-number taf-line))))

(defun %resolve-taf-subtag-line (taf-line args-result)
  (let ((kind (taf-line-kind taf-line))
        (subkind (taf-line-subkind taf-line)))
    (if (and (eql kind :tag) (eql subkind :subtag))
        (getf (%resolve-taf-line taf-line args-result) :line)
        (error "Block head must be a :subtag line, but got subkind ~S: ~A"
               subkind taf-line))))

;; resolved-block: '(:tag <tag-value> :lines <lines-list>)
(defun %resolve-a-block (a-block args-result)
  (list :tag (%resolve-taf-subtag-line (car a-block) args-result)
        :lines (mapcar #'(lambda (taf-line)
                           (%resolve-taf-line taf-line args-result))
                       (cdr a-block))))

(defun %resolve-blocks (taf-result)
  (let ((raw-body (taf-result-body taf-result))
        (args-result (taf-result-args-result taf-result)))
    (mapcar #'(lambda (a-block) (%resolve-a-block a-block args-result))
            raw-body)))

;; resolved-body = resolved-blocks
;; lines is a list of resolved-line plist objects
;; resolved-line: (:line <line-string> :number <line-number>)
(defun %emit-resolved-body (resolved-blocks taf-result &optional (emitters *taf-emitters*))
  (mapcar #'(lambda (a-block)
              (let ((tag (getf a-block :tag))
                    (lines (getf a-block :lines)))
                (emit-block tag lines taf-result emitters)))
          resolved-blocks))

(defun compile-taf-result (taf-result &optional (emitters *taf-emitters*))
  (unless (taf-result-p taf-result)
    (error "TAF-RESULT must be a TAF-RESULT, but got: ~S"
           (type-of taf-result)))
  (let* ((resolved-body (%resolve-blocks taf-result))
         (shell-blocks (%emit-resolved-body resolved-body taf-result emitters)))
    (format nil "#!/bin/sh~%~%~{~A~%~}" shell-blocks)))

(defun compile-taf-program (taf-program &optional (emitters *taf-emitters*))
  (declare (ignore emitters))
  (unless (taf-program-p taf-program)
    (error "TAF-PROGRAM must be a TAF-PROGRAM, but got: ~S"
           (type-of taf-program)))
  (error "COMPILE-TAF-PROGRAM is not implemented yet."))

(defun compile-taf (taf-result-or-program &optional (emitters *taf-emitters*))
  (cond
    ((taf-result-p taf-result-or-program)
     (compile-taf-result taf-result-or-program emitters))
    ((taf-program-p taf-result-or-program)
     (compile-taf-program taf-result-or-program emitters))
    (t
     (error "Need TAF-RESULT or TAF-PROGRAM, but got: ~S"
            (type-of taf-result-or-program)))))
