(in-package :taffish.i18n)

;;;; ============================================================
;;;; builtin.lisp
;;;; ============================================================

;; Shared messages only. Program-specific help and diagnostics register their
;; own semantic keys near the human rendering layer that owns the wording.
(register-message
 "cli.show-help"
 "Show this help"
 "显示此帮助")

(register-message
 "cli.unknown-option"
 "unknown option: {option}"
 "未知选项：{option}")
