(in-package :taf.core)

;;;; Human-only, event-driven status. No worker threads or process policy here.

(dolist (entry '(("download" "Downloading index" "正在下载索引")
                 ("locked-check" "Rechecking the repair plan under the write lock" "取得写锁，正在复核修复计划")
                 ("read-index" "Reading index" "正在读取索引")
                 ("save-index" "Checking and saving index" "正在检查并保存索引")
                 ("fetch" "Getting source" "正在获取源码")
                 ("verify-source" "Checking source identity" "正在核对源码身份")
                 ("build" "Building command snapshot" "正在构建命令快照")
                 ("verify" "Checking build and installation" "正在验证构建和安装")
                 ("switch" "Backing up and switching installation" "正在备份并切换安装")
                 ("snapshot" "Copying project snapshot" "正在复制项目快照")
                 ("wrapper" "Writing command wrapper" "正在生成命令入口")
                 ("inspect-build" "Checking existing build" "正在检查已有构建")
                 ("inspect" "Checking installed targets" "正在检查已安装目标")
                 ("remove" "Removing installed version" "正在删除已安装版本")
                 ("prune" "Checking old versions for cleanup" "正在检查可清理的旧版本")
                 ("query" "Querying remote state" "正在查询远端状态")
                 ("retry" "Retrying remote query" "正在重试远端查询")
                 ("confirm" "Confirming remote result" "正在确认远端结果")
                 ("repository" "Checking repository" "正在检查仓库")
                 ("policy" "Checking release protection" "正在检查发布保护")
                 ("commit" "Checking release commit" "正在检查发布提交")
                 ("branch" "Checking remote branch" "正在检查远端分支")
                 ("local-tag" "Checking local tag" "正在检查本地标签")
                 ("remote-tag" "Checking remote tag" "正在检查远端标签")
                 ("release" "Checking GitHub Release" "正在检查 GitHub Release")
                 ("write-remote" "Applying publish step" "正在执行发布步骤")))
  (taffish.i18n:register-message (concatenate 'string "taf.progress." (first entry))
                                (second entry) (third entry)))

(defstruct (%operation-display (:constructor %make-operation-display))
  stream terminal-p active-p disabled-p last-text last-time last-target
  (started (get-internal-real-time)))

(defvar *operation-display* nil)
(defvar *operation-item* nil)
(defvar *operation-total* nil)

(defvar *cli-terminal-error-output* nil
  "The configured stderr stream at CLI entry, when fd 2 is a terminal.")

(defun %progress-terminal-p (stream)
  (ignore-errors
    (and (not (equal (han.host:getenv "TERM") "dumb"))
         (if *cli-terminal-error-output*
             (eq stream *cli-terminal-error-output*)
             (and (interactive-stream-p stream)
                  (han.host:standard-error-terminal-p))))))

(defun %operation-display-create ()
  (ignore-errors
    (%make-operation-display
     :stream *error-output*
     :terminal-p (%progress-terminal-p *error-output*))))

(defun %operation-progress-yield ()
  "End our dynamic line before normal results, child output, or unwinding."
  (let ((display *operation-display*))
    (when (and display (%operation-display-active-p display))
      (setf (%operation-display-active-p display) nil)
      (handler-case
          (progn (terpri (%operation-display-stream display))
                 (finish-output (%operation-display-stream display)))
        (error () (setf (%operation-display-disabled-p display) t))))))

(defmacro %with-operation-progress ((enabled) &body body)
  ;; Nested core helpers share the caller's display, even when their normal
  ;; result printing is disabled. A silent top-level call creates no display.
  `(let ((*operation-display* (or *operation-display*
                                  (and ,enabled (%operation-display-create)))))
     (unwind-protect (progn ,@body)
       (%operation-progress-yield))))

(defun %operation-safe-text (value)
  (let ((text (princ-to-string value)))
    (map 'string (lambda (c)
                   (if (or (< (char-code c) 32) (<= 127 (char-code c) 159)) #\Space c))
         (if (> (length text) 100)
             (concatenate 'string (subseq text 0 97) "...")
             text))))

(defun %operation-stage (stage &key target defer-p force-p)
  "Best-effort status only. Unknown totals, timings and success are not invented."
  (let ((display *operation-display*))
    (when (and display (not (%operation-display-disabled-p display)))
      (handler-case
          (let* ((now (get-internal-real-time))
                 (label (taffish.i18n:message (concatenate 'string "taf.progress." stage)))
                 (text (format nil "[TAF] ~A~@[ | ~A~]~@[ | ~A~]"
                               (%operation-safe-text label)
                               (and target (%operation-safe-text target))
                               (and *operation-item* *operation-total*
                                    (format nil "~D/~D" *operation-item* *operation-total*))))
                 (last (%operation-display-last-time display))
                 (width (%display-width text))
                 (columns (ignore-errors (parse-integer (or (han.host:getenv "COLUMNS") "80"))))
                 (budget (if (and columns (plusp columns)) (min 78 (- columns 2)) 78))
                 (terminal (and (%operation-display-terminal-p display) width (<= width budget))))
            (when (and (or (not defer-p)
                           (>= (- now (%operation-display-started display)) internal-time-units-per-second))
                       (or force-p (null last)
                           (and terminal (not (equal text (%operation-display-last-text display))))
                           (not (equal target (%operation-display-last-target display)))
                           (>= (- now last) internal-time-units-per-second)))
              (unless terminal (%operation-progress-yield))
              (let ((stream (%operation-display-stream display)))
                (when terminal (format stream "~C~C[K" #\Return (code-char 27)))
                (write-string text stream)
                (setf (%operation-display-active-p display) terminal)
                (unless terminal (terpri stream))
                (finish-output stream))
              (setf (%operation-display-last-time display) now
                    (%operation-display-last-target display) target
                    (%operation-display-last-text display) text)))
        (error () (setf (%operation-display-disabled-p display) t))))))
