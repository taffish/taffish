(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / main.lisp
;;;; ============================================================

(defun %taffish-mcp-help-option-p (arg)
  (member arg '("-h" "--help" "help") :test #'string-equal))

(defun %taffish-mcp-version-option-p (arg)
  (member arg '("-v" "--version" "version") :test #'string-equal))

(defun main (&optional (raw-argv (han.host:argv)))
  (han.host::%with-cli-error-boundary ("[TAFFISH-MCP-ERROR]")
    (han.host:prepare-runtime-io)
    (han.host:configure-runtime-io)
    (handler-case
        (let ((first (car raw-argv)))
          (cond
            ((%taffish-mcp-help-option-p first)
             (taffish.i18n:call-with-resolved-language
              (lambda ()
                (write-string (%get-taffish-mcp-cli-help-string)
                              *standard-output*)))
             (han.host:quit 0))
            ((%taffish-mcp-version-option-p first)
             (version *standard-output*)
             (han.host:quit 0))
            (t
             (run-stdio-server)
             (han.host:quit 0))))
      (error (c)
        (format *error-output* "[TAFFISH-MCP-ERROR] ~A~%" c)
        (han.host:quit 1)))))
