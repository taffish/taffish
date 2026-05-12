(in-package :taffish.core)

;;;; ============================================================
;;;; binder.lisp
;;;; ============================================================

(defun %ensure-taf-context (context)
  (cond
    ((taf-context-p context)
     context)
    (t
     (normalize-input-context context))))

(defun %stringify-context-value (value)
  (cond
    ((null value) nil)
    ((stringp value) value)
    ((listp value)
     (format nil "~{~A~^ ~}" value))
    (t
     (format nil "~A" value))))

(defun %put-builtin-binding (table name value)
  (when value
    (setf (gethash name table)
          (han.args:make-arg-binding
           :name name
           :value (%stringify-context-value value)
           :status :input)))
  table)

(defun %context-to-builtin-bindings (context)
  (let ((table (make-hash-table :test #'equalp)))
    (%put-builtin-binding table "*USER*"      (taf-context-user context))
    (%put-builtin-binding table "*HOMEDIR*"   (taf-context-homedir context))
    (%put-builtin-binding table "*WORKDIR*"   (taf-context-workdir context))
    (%put-builtin-binding table "*LOADDIR*"   (taf-context-loaddir context))
    (%put-builtin-binding table "*ARGV*"      (format nil "~{~A~^ ~}"
                                                      (taf-context-argv context)))
    (%put-builtin-binding table "*CMD*"       (taf-context-cmd context))
    (%put-builtin-binding table "*CPUS*"      (taf-context-cpus context))
    (%put-builtin-binding table "*CONTAINER*" (taf-context-container context))
    table))


;; validate-parts
(defun %string-prefix-p (prefix string &key (test #'char-equal))
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (loop for i from 0 below (length prefix)
             always (funcall test
                             (char prefix i)
                             (char string i)))))

(defun %taf-app-tag-p (tag)
  (and (stringp tag)
       (%string-prefix-p "taf-app:" tag :test #'char-equal)))

(defun %taf-app-block-present-p (taf-program)
  (let ((body (taf-program-body taf-program)))
    (dolist (a-block body)
      (let* ((head (car a-block))
             (tag (%subtag-head-string head)))
        (when (%taf-app-tag-p tag)
          (return-from %taf-app-block-present-p t))))
    nil))

(defun %argv-command-mode-p (context)
  (let* ((argv (and context (taf-context-argv context)))
         (first (car argv)))
    (and (stringp first)
         (> (length (string-trim '(#\Space #\Tab) first)) 0)
         (not (char= #\- (char (string-trim '(#\Space #\Tab) first) 0))))))

(defun %taf-app-command-mode-p (taf-program context)
  (and (%taf-app-block-present-p taf-program)
       (%argv-command-mode-p context)))

(defun %ignore-diagnostic-p (diagnostic taf-program context)
  (and (%taf-app-command-mode-p taf-program context)
       (eql :missing-required
            (han.args:arg-diagnostic-code diagnostic))))

(defun %diagnostic-error-p (diagnostic)
  (eql :error (han.args:arg-diagnostic-kind diagnostic)))

(defun %validate-args-result (args-result taf-program context)
  (dolist (diagnostic (han.args:args-result-diagnostics args-result))
    (when (and (%diagnostic-error-p diagnostic)
               (not (%ignore-diagnostic-p diagnostic taf-program context)))
      (error "~A" (han.args:arg-diagnostic-message diagnostic))))
  args-result)

(defun bind-taf (taf-program input-args &optional context)
  "Bind TAF-PROGRAM with INPUT-ARGS and CONTEXT, returning a TAF-RESULT."
  (unless (taf-program-p taf-program)
    (error "TAF-PROGRAM must be a TAF-PROGRAM, but got: ~A."
           (type-of taf-program)))
  (let* ((args-input (normalize-input-args input-args))
         (taf-context (%ensure-taf-context context))
         (builtin-bindings (%context-to-builtin-bindings taf-context))
         (args-result
           (han.args:bind-args
               (taf-program-args-spec taf-program)
             args-input
             builtin-bindings)))
    (%validate-args-result args-result taf-program taf-context)
    (make-taf-result
     :program taf-program
     :args-result args-result
     :context taf-context
     :body (taf-program-body taf-program)
     :diagnostics (han.args:args-result-diagnostics args-result))))
