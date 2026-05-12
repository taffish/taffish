(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / main.lisp
;;;; ============================================================

(defun %taffish-mcp-help-option-p (arg)
  (member arg '("-h" "--help" "help") :test #'string-equal))

(defun %taffish-mcp-version-option-p (arg)
  (member arg '("-v" "--version" "version") :test #'string-equal))

(defun main (&optional (raw-argv (han.host:argv)))
  (handler-case
      (let ((first (car raw-argv)))
        (cond
          ((%taffish-mcp-help-option-p first)
           (help *standard-output*)
           (han.host:quit 0))
          ((%taffish-mcp-version-option-p first)
           (version *standard-output*)
           (han.host:quit 0))
          (t
           (run-stdio-server)
           (han.host:quit 0))))
    (error (c)
      (format *error-output* "[TAFFISH-MCP-ERROR] ~A~%" c)
      (han.host:quit 1))))
