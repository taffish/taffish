(in-package :taf.core)

;;;; ============================================================
;;;; system / history-i18n.lisp
;;;; ============================================================

(defun %register-history-i18n-messages ()
  (dolist
      (entry
       '(("header" "[TAF] history" "[TAF] 执行历史")
         ("label.file" "file" "文件")
         ("empty" "No TAFFISH history yet." "尚无 TAFFISH 执行历史。")
         ("events" "Events:" "事件：")
         ("clear.cleared" "cleared" "已清除")
         ("clear.not-found" "not found" "不存在")
         ("clear.result"
          "[TAF] history {state}: {path}"
          "[TAF] 执行历史{state}：{path}")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.history.~A" suffix)
       english chinese))))

(%register-history-i18n-messages)

(defun %history-message (suffix &rest bindings)
  (apply #'taffish.i18n:message-with
         (format nil "taf.history.~A" suffix)
         bindings))
