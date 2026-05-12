(in-package :taffish.core)

;;;; ============================================================
;;;; emitter: builtins: shell.lisp
;;;; ============================================================

(defemitter shell
  :match-function #'(lambda (tag line-number)
                      (when (string-equal tag "shell")
                        (list :kind :shell
                              :tag tag
                              :line-number line-number)))
  :emit-function #'(lambda (parsed-info lines taf-result)
                     (declare (ignore parsed-info taf-result))
                     (mapcar #'%get-line-string lines)))
