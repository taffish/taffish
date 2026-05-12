(in-package :taffish.core)

;;;; ============================================================
;;;; main.lisp
;;;; ============================================================

(defun taffish-to-shell (taf-code input-args context)
  "Compile TAF-CODE with INPUT-ARGS and CONTEXT into shell code.
TAF-CODE must be a string.
INPUT-ARGS should be a list like:
  (\"cmd\" \"--name\" \"alice\")
CONTEXT may be an alist or a TAF-CONTEXT object.
Returns the final compiled shell code as a string."
  (unless (stringp taf-code)
    (error "TAF-CODE must be a string, but got: ~S"
           (type-of taf-code)))
  (let* ((taf-program (parse-taf taf-code))
         (taf-result (bind-taf taf-program input-args context)))
    (compile-taf taf-result)))
