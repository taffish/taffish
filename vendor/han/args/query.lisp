(in-package :han.args)

;;;; ============================================================
;;;; bind.lisp
;;;; ============================================================

(defun %eval-arg-expression (expr args-result history)
  (cond
    ((null expr)
     (values nil :default))
    ((stringp expr)
     (values expr :default))
    ((and (consp expr)
          (eql :query (car expr)))
     (get-arg (second expr) args-result history))
    ((and (consp expr)
          (eql :concat (car expr)))
     (values
      (with-output-to-string (out)
        (dolist (part (cdr expr))
          (multiple-value-bind (value status)
              (%eval-arg-expression part args-result history)
            (declare (ignore status))
            (when value
              (princ value out)))))
      :default))
    (t
     (values expr :default))))

(defun get-arg (name-or-spec args-result &optional (history nil))
  (labels ((ga (name-string arg-bindings history)
             (when (member name-string history :test #'equalp)
               (error "Cyclic query detected [~A] in: ~A -> ~{~A~^ -> ~}"
                      (string-upcase  name-string) name-string history))
             (multiple-value-bind (binding find-p)
                 (gethash name-string arg-bindings)
               (if find-p
                   (let ((value (arg-binding-value binding))
                         (status (arg-binding-status binding)))
                     (cond
                       ((and (consp value)
                             (member (car value) '(:query :concat) :test #'eq))
                        (%eval-arg-expression value args-result
                                              (cons name-string history)))
                       (t
                        (values value status))))
                   (values nil nil)))))
    (let ((name (arg-spec-name
                 (cond
                   ((arg-spec-p name-or-spec)
                    name-or-spec)
                   ((stringp name-or-spec)
                    (parse-arg-spec name-or-spec))
                   ((integerp name-or-spec)
                    (parse-arg-spec (format nil "$~A" name-or-spec)))
                   (t (error "NAME-OR-SPEC must be STRING/ARG-SPEC/INTEGER but: ~A"
                             (type-of name-or-spec))))))
          (bindings (args-result-bindings args-result))
          (builtin-bindings (args-result-builtin-bindings args-result)))
      (multiple-value-bind (v v-p)
          (ga name builtin-bindings history)
        (if v-p
            (values v v-p)
            (ga name bindings history))))))
