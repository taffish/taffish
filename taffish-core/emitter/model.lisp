(in-package :taffish.core)

;;;; ============================================================
;;;; emitter: model.lisp
;;;; ============================================================

(defstruct taf-emitter
  name                ;; emitter 名称
  ;;priority          ;; -10, 0, 10 等整数，数字越小，优先级越高
  ;; parsed-info (:kind <name> :tag <tag> :line-number <line-number> ...) | nil
  match-function      ;; (tag line-number) -> parsed-info
  ;; lines is a list of resolved-line plist objects
  ;; resolved-line: (:line <line-string> :number <line-number>)
  emit-function       ;; (parsed-info lines taf-result) -> shell-lines-list
  prelude-function    ;; (parsed-info lines taf-result) -> shell-lines-list
  finalize-function)  ;; (parsed-info shell-lines-list taf-result) -> shell-string | error

(defparameter *taf-emitters* '())
