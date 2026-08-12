(in-package :taf.core)

;;;; ============================================================
;;;; system / config.lisp
;;;; ============================================================

(defparameter *taffish-config-schema-version*
  "taffish.config/v1")

(defparameter *default-taffish-language*
  "auto")

(defparameter *default-gitee-host*
  "gitee.com")

(defparameter *default-gitee-owner*
  "taffish-org")

(dolist (entry
         '(("config.path.header" "[TAF] config path" "[TAF] 配置路径")
           ("config.init.header" "[TAF] initialized config" "[TAF] 已初始化配置")
           ("config.header" "[TAF] config" "[TAF] 配置")
           ("config.section.effective" "Effective config:" "生效配置：")
           ("config.section.directories" "Active directories:" "当前目录：")
           ("config.label.scope" "scope" "作用域")
           ("config.label.active-file" "active file" "当前文件")
           ("config.label.user-file" "user file" "用户文件")
           ("config.label.system-file" "system file" "系统文件")
           ("config.label.taffish-user-home" "TAFFISH_USER_HOME" "TAFFISH_USER_HOME")
           ("config.label.taffish-system-home" "TAFFISH_SYSTEM_HOME" "TAFFISH_SYSTEM_HOME")
           ("config.label.taffish-system-bin" "TAFFISH_SYSTEM_BIN_DIR" "TAFFISH_SYSTEM_BIN_DIR")
           ("config.label.taffish-config" "TAFFISH_CONFIG" "TAFFISH_CONFIG")
           ("config.label.profile" "profile" "配置方案")
           ("config.label.file" "file" "文件")
           ("config.label.user-home" "user home" "用户目录")
           ("config.label.system-home" "system home" "系统目录")
           ("config.label.system-command-bin" "system command bin" "系统命令目录")
           ("config.label.active-home" "active home" "当前目录")
           ("config.label.active-command-bin" "active command bin" "当前命令目录")
           ("config.label.active-config-file" "active config file" "当前配置文件")
           ("config.label.language" "language" "配置语言")
           ("config.label.configured-language" "configured" "配置值")
           ("config.label.display-language" "display language" "显示语言")
           ("config.label.configured-source" "configured source" "配置来源")
           ("config.label.display-source" "display source" "显示来源")
           ("config.label.source-file" "source file" "来源文件")
           ("config.label.target-file" "target file" "目标文件")
           ("config.label.saved-language" "saved" "已保存")
           ("config.label.index-url" "index url" "索引地址")
           ("config.label.loaded-files" "loaded config files" "已加载配置文件")
           ("config.label.source-rules" "source rewrite rules" "源码重写规则")
           ("config.label.index-current" "index current" "当前索引")
           ("config.label.apps" "apps" "应用")
           ("config.label.index" "index" "索引")
           ("config.label.images" "images" "镜像")
           ("config.label.images-sif" "images sif" "SIF 镜像")
           ("config.label.bin" "bin" "命令")
           ("config.label.cache" "cache" "缓存")
           ("config.label.share" "share" "共享资源")
           ("config.label.logs" "logs" "日志")
           ("config.value.none" "<none>" "<无>")
           ("config.value.default" "<default>" "<默认>")
           ("config.value.unset" "<unset>" "<未设置>")
           ("config.value.enabled" "enabled" "启用")
           ("config.value.disabled" "disabled" "禁用")
           ("config.language.header" "[TAF] language configuration" "[TAF] 语言配置")
           ("config.language.section.available" "Available languages:" "可用语言：")
           ("config.language.section.mode" "Selection mode:" "选择模式：")
           ("config.language.mode.auto" "Follow the host locale with English fallback." "跟随主机 locale，缺失时回退英文。")
           ("config.language.origin.built-in" "built-in" "内置")
           ("config.language.origin.user" "user" "用户")
           ("config.language.origin.system" "system" "系统")
           ("config.language.source.environment" "TAFFISH_LANGUAGE environment" "TAFFISH_LANGUAGE 环境变量")
           ("config.language.source.explicit-config" "explicit config" "显式配置")
           ("config.language.source.user-config" "user config" "用户配置")
           ("config.language.source.system-config" "system config" "系统配置")
           ("config.language.source.locale-environment" "host locale environment" "主机 locale 环境")
           ("config.language.source.default" "built-in default" "内置默认值")
           ("config.language.error.unknown" "[config] unavailable language: {language}. Run `taf config language --show` to list valid choices." "[config] 语言不可用：{language}。请运行 `taf config language --show` 查看有效选项。")
           ("config.language.error.system-root" "[config] language --system requires root permission." "[config] language --system 需要 root 权限。")))
  (apply #'taffish.i18n:register-message entry))

(defun %config-human-text (key)
  (taffish.i18n:message key))

(defun %config-print-human-field (key value &optional (width 22))
  (format t "  ~VA : ~A~%" width (%config-human-text key) value))

(defun %config-human-env-value (value)
  (cond
    ((string= value "<default>")
     (%config-human-text "config.value.default"))
    ((string= value "<unset>")
     (%config-human-text "config.value.unset"))
    (t value)))

(defun %config-env-value (name)
  (or (han.host:getenv name) "<default>"))

(defun %config-dir (home relative-dir)
  (%directory-namestring (%taffish-home-dir home relative-dir)))

(defun %config-non-empty-string-p (value)
  (and (stringp value)
       (not (%blank-string-p value))))

(defun %config-explicit-file ()
  (let ((value (han.host:getenv "TAFFISH_CONFIG")))
    (when (%config-non-empty-string-p value)
      value)))

(defun %config-file-namestring (path)
  (han.path:->namestring path))

(defun %config-existing-file (path)
  (and path (han.path:file-exists-p path)))

(defun %config-existing-file-or-error (path source)
  (or (%config-existing-file path)
      (error "[config] ~A config file does not exist: ~A" source path)))

(defun %plist-has-key-p (plist key)
  (loop for (k v) on plist by #'cddr
        thereis (eql k key)))

(defun %copy-plist (plist)
  (copy-list plist))

(defun %default-taffish-config ()
  (list :schema-version *taffish-config-schema-version*
        :profile "github"
        :language *default-taffish-language*
        :index-url (%default-index-url)
        :source-rewrite-rules nil
        :config-files nil))

(defun %config-parse-value (raw-value path line-number)
  (handler-case
      (%parse-toml-value raw-value)
    (error (c)
      (error "[config] invalid TOML value in ~A line ~A: ~A"
             (%config-file-namestring path)
             line-number
             c))))

(defun %config-parse-key-value (line path line-number)
  (multiple-value-bind (raw-key raw-value)
      (%split-once line #\=)
    (unless raw-value
      (error "[config] invalid TOML line in ~A line ~A: ~A"
             (%config-file-namestring path)
             line-number
             line))
    (let ((key (%trim-string raw-key)))
      (when (%blank-string-p key)
        (error "[config] empty TOML key in ~A line ~A"
               (%config-file-namestring path)
               line-number))
      (values key (%config-parse-value raw-value path line-number)))))

(defun %config-ensure-string (value field path)
  (unless (%config-non-empty-string-p value)
    (error "[config] ~A in ~A must be a non-empty string, but got: ~S"
           field
           (%config-file-namestring path)
           value))
  value)

(defun %config-ensure-boolean (value field path)
  (unless (or (eql value t) (eql value nil))
    (error "[config] ~A in ~A must be true or false, but got: ~S"
           field
           (%config-file-namestring path)
           value))
  value)

(defun %config-finalize-source-rewrite-rule (rule path)
  (let ((from (getf rule :from))
        (to (getf rule :to))
        (enabled (if (%plist-has-key-p rule :enabled)
                     (getf rule :enabled)
                     t)))
    (list :from (%config-ensure-string from "[[source.rewrite]].from" path)
          :to (%config-ensure-string to "[[source.rewrite]].to" path)
          :enabled (%config-ensure-boolean
                    enabled
                    "[[source.rewrite]].enabled"
                    path))))

(defun %read-taffish-config-file (path)
  "Read the small TAFFISH config TOML subset."
  (let ((existing (%config-existing-file-or-error path "TAFFISH"))
        (section :top)
        (config nil)
        (rules nil)
        (current-rule nil)
        (saw-rules-p nil)
        (line-number 0))
    (labels ((finish-rule ()
               (when current-rule
                 (push (%config-finalize-source-rewrite-rule
                        current-rule
                        existing)
                       rules)
                 (setf current-rule nil))))
      (dolist (line (han.os:load-lines existing))
        (incf line-number)
        (let ((clean (%trim-string line)))
          (cond
            ((or (%blank-string-p clean)
                 (char= #\# (char clean 0)))
             nil)
            ((string= clean "[index]")
             (finish-rule)
             (setf section :index))
            ((string= clean "[[source.rewrite]]")
             (finish-rule)
             (setf section :source-rewrite
                   saw-rules-p t
                   current-rule nil))
            ((and (> (length clean) 0)
                  (char= #\[ (char clean 0)))
             (error "[config] unsupported section in ~A line ~A: ~A"
                    (%config-file-namestring existing)
                    line-number
                    clean))
            (t
             (multiple-value-bind (key value)
                 (%config-parse-key-value clean existing line-number)
               (case section
                 (:top
                  (cond
                    ((string= key "schema_version")
                     (setf (getf config :schema-version)
                           (%config-ensure-string value "schema_version" existing)))
                    ((string= key "profile")
                     (setf (getf config :profile)
                           (%config-ensure-string value "profile" existing)))
                    ((string= key "language")
                     (setf (getf config :language)
                           (%config-ensure-string value "language" existing)))
                    (t
                     (error "[config] unsupported top-level key in ~A line ~A: ~A"
                            (%config-file-namestring existing)
                            line-number
                            key))))
                 (:index
                  (cond
                    ((string= key "url")
                     (setf (getf config :index-url)
                           (%config-ensure-string value "[index].url" existing)))
                    (t
                     (error "[config] unsupported [index] key in ~A line ~A: ~A"
                            (%config-file-namestring existing)
                            line-number
                            key))))
                 (:source-rewrite
                  (cond
                    ((string= key "from")
                     (setf (getf current-rule :from)
                           (%config-ensure-string
                            value
                            "[[source.rewrite]].from"
                            existing)))
                    ((string= key "to")
                     (setf (getf current-rule :to)
                           (%config-ensure-string
                            value
                            "[[source.rewrite]].to"
                            existing)))
                    ((string= key "enabled")
                     (setf (getf current-rule :enabled)
                           (%config-ensure-boolean
                            value
                            "[[source.rewrite]].enabled"
                            existing)))
                    (t
                     (error "[config] unsupported [[source.rewrite]] key in ~A line ~A: ~A"
                            (%config-file-namestring existing)
                            line-number
                            key))))))))))
      (finish-rule))
    (when (and (%plist-has-key-p config :schema-version)
               (not (string= (getf config :schema-version)
                             *taffish-config-schema-version*)))
      (error "[config] unsupported schema_version in ~A: ~A"
             (%config-file-namestring existing)
             (getf config :schema-version)))
    (when saw-rules-p
      (setf (getf config :source-rewrite-rules) (nreverse rules)))
    (setf (getf config :config-files)
          (list (%config-file-namestring existing)))
    config))

(defun %merge-taffish-config (base override)
  (let ((result (%copy-plist base)))
    (dolist (key '(:schema-version :profile :language :index-url
                   :source-rewrite-rules))
      (when (%plist-has-key-p override key)
        (setf (getf result key) (getf override key))))
    (setf (getf result :config-files)
          (append (getf base :config-files)
                  (getf override :config-files)))
    result))

(defun %taffish-config-files (&key (scope :user) user-home system-home)
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (system-file (%taffish-system-config-file system-home))
         (user-file (%taffish-user-config-file user-home))
         (explicit-file (%config-explicit-file))
         (files nil))
    (when (%config-existing-file system-file)
      (push system-file files))
    (when (and (eql normalized-scope :user)
               (%config-existing-file user-file))
      (push user-file files))
    (when explicit-file
      (push (%config-existing-file-or-error explicit-file "TAFFISH_CONFIG")
            files))
    (nreverse files)))

(defun %effective-taffish-config (&key (scope :user) user-home system-home)
  (let ((config (%default-taffish-config)))
    (dolist (file (%taffish-config-files :scope scope
                                          :user-home user-home
                                          :system-home system-home))
      (setf config
            (%merge-taffish-config config
                                   (%read-taffish-config-file file))))
    config))

(defun %resolve-taffish-index-url
    (&key explicit-url (scope :user) user-home system-home)
  (or (and (%config-non-empty-string-p explicit-url) explicit-url)
      (let ((env-url (han.host:getenv "TAFFISH_INDEX_URL")))
        (and (%config-non-empty-string-p env-url) env-url))
      (and (boundp '*taffish-index-default-url*)
           (%config-non-empty-string-p *taffish-index-default-url*)
           *taffish-index-default-url*)
      (getf (%effective-taffish-config :scope scope
                                       :user-home user-home
                                       :system-home system-home)
            :index-url)
      (%default-index-url)))

(defun %rewrite-taffish-source-url (canonical-url rules)
  (dolist (rule rules (values canonical-url nil))
    (let ((from (getf rule :from))
          (to (getf rule :to))
          (enabled (getf rule :enabled)))
      (when (and enabled
                 (%string-prefix-p from canonical-url :test #'char=))
        (return
          (values
           (format nil "~A~A" to (subseq canonical-url (length from)))
           rule))))))

(defun %resolve-taffish-source-url
    (canonical-url &key (scope :user) user-home system-home)
  (let* ((config (%effective-taffish-config :scope scope
                                            :user-home user-home
                                            :system-home system-home))
         (rules (getf config :source-rewrite-rules)))
    (if (%config-non-empty-string-p canonical-url)
        (multiple-value-bind (resolved rule)
            (%rewrite-taffish-source-url canonical-url rules)
          (values resolved rule config))
        (values canonical-url nil config))))

(defun %taffish-config-path-result (&key
                                      (scope :user)
                                      user-home
                                      system-home
                                      system-bin-dir)
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (system-bin-path (%taffish-system-bin-dir system-bin-dir))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (active-file (%taffish-config-file home)))
    (list :scope normalized-scope
          :user-home (%directory-namestring user-home-path)
          :system-home (%directory-namestring system-home-path)
          :system-bin-dir (%directory-namestring system-bin-path)
          :home (%directory-namestring home)
          :config-file (%config-file-namestring active-file)
          :user-config-file
          (%config-file-namestring (%taffish-config-file user-home-path))
          :system-config-file
          (%config-file-namestring (%taffish-config-file system-home-path))
          :explicit-config-file (or (%config-explicit-file) "<unset>"))))

(defun %print-taffish-config-path (result)
  (format t "~A~%" (%config-human-text "config.path.header"))
  (%config-print-human-field
   "config.label.scope"
   (string-downcase (string (getf result :scope))))
  (%config-print-human-field "config.label.active-file"
                             (getf result :config-file))
  (%config-print-human-field "config.label.user-file"
                             (getf result :user-config-file))
  (%config-print-human-field "config.label.system-file"
                             (getf result :system-config-file))
  (%config-print-human-field "config.label.taffish-config"
                             (%config-human-env-value
                              (getf result :explicit-config-file))))

(defun system-config-path (&key
                             (scope :user)
                             user-home
                             system-home
                             system-bin-dir
                             (verbose t))
  (let ((result (%taffish-config-path-result :scope scope
                                             :user-home user-home
                                             :system-home system-home
                                             :system-bin-dir system-bin-dir)))
    (when verbose
      (%print-taffish-config-path result))
    result))

(defun %taffish-config-github-template ()
  (format nil "~{~A~%~}"
          (list
           (format nil "schema_version = \"~A\""
                   *taffish-config-schema-version*)
           "profile = \"github\""
           (format nil "language = \"~A\"" *default-taffish-language*)
           ""
           "[index]"
           (format nil "url = \"~A\"" (%default-index-url)))))

(defun %taffish-config-china-template ()
  (let ((index-url
          (format nil "https://~A/~A/~A/raw/~A/index/index.json"
                  *default-gitee-host*
                  *default-gitee-owner*
                  *default-index-repository*
                  *default-index-branch*))
        (source-to
          (format nil "https://~A/~A/"
                  *default-gitee-host*
                  *default-gitee-owner*)))
    (format nil "~{~A~%~}"
            (list
             (format nil "schema_version = \"~A\""
                     *taffish-config-schema-version*)
             "profile = \"china\""
             (format nil "language = \"~A\"" *default-taffish-language*)
             ""
             "[index]"
             (format nil "url = \"~A\"" index-url)
             ""
             "[[source.rewrite]]"
             (format nil "from = \"https://~A/~A/\""
                     *default-github-host*
                     *default-github-owner*)
             (format nil "to = \"~A\"" source-to)
             "enabled = true"))))

(defun %normalize-taffish-config-profile (profile)
  (cond
    ((or (null profile)
         (eql profile :github)
         (and (stringp profile) (string-equal profile "github")))
     :github)
    ((or (eql profile :china)
         (and (stringp profile) (string-equal profile "china")))
     :china)
    (t
     (error "[config] profile must be github or china, but got: ~S" profile))))

(defun %taffish-config-template (profile)
  (case (%normalize-taffish-config-profile profile)
    (:github (%taffish-config-github-template))
    (:china (%taffish-config-china-template))))

(defun %write-taffish-config-file (path content force-p)
  (let ((existing (%config-existing-file path)))
    (when (and existing (not force-p))
      (error "[config] config file already exists: ~A~%Use --force to replace it."
             (%config-file-namestring existing))))
  (ensure-directories-exist path)
  (with-open-file (out path
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (write-string content out)))

(defun %config-inline-comment-position (line)
  (let ((quoted-p nil)
        (escaped-p nil))
    (loop for index from 0 below (length line)
          for char = (char line index) do
            (cond
              (escaped-p (setf escaped-p nil))
              ((and quoted-p (char= char #\\)) (setf escaped-p t))
              ((char= char #\") (setf quoted-p (not quoted-p)))
              ((and (not quoted-p) (char= char #\#)) (return index)))
          finally (return nil))))

(defun %config-top-level-language-line-p (line)
  (let ((clean (%trim-string line)))
    (and (not (%blank-string-p clean))
         (not (char= #\# (char clean 0)))
         (multiple-value-bind (raw-key raw-value)
             (%split-once clean #\=)
           (and raw-value
                (string= (%trim-string raw-key) "language"))))))

(defun %config-section-line-p (line)
  (let ((clean (%trim-string line)))
    (and (> (length clean) 0)
         (char= #\[ (char clean 0)))))

(defun %config-language-line (language &optional original-line)
  (if original-line
      (let* ((indent-end
               (or (position-if-not
                    (lambda (char) (member char '(#\Space #\Tab) :test #'char=))
                    original-line)
                   0))
             (comment-position (%config-inline-comment-position original-line))
             (suffix-start
               (and comment-position
                    (loop for index = comment-position then (1- index)
                          while (and (> index 0)
                                     (member (char original-line (1- index))
                                             '(#\Space #\Tab)
                                             :test #'char=))
                          finally (return index))))
             (suffix (if suffix-start (subseq original-line suffix-start) "")))
        (format nil "~Alanguage = \"~A\"~A"
                (subseq original-line 0 indent-end)
                language
                suffix))
      (format nil "language = \"~A\"" language)))

(defun %insert-config-language-line (lines language)
  (let* ((section-position (position-if #'%config-section-line-p lines))
         (insertion-position
           (if section-position
               (loop for index = section-position then (1- index)
                     while (and (> index 0)
                                (%blank-string-p (nth (1- index) lines)))
                     finally (return index))
               (length lines))))
    (append (subseq lines 0 insertion-position)
            (list (%config-language-line language))
            (subseq lines insertion-position))))

(defun %rewrite-config-language-lines (lines language)
  (let ((top-level-p t)
        (found-p nil)
        (result nil))
    (dolist (line lines)
      (when (%config-section-line-p line)
        (setf top-level-p nil))
      (if (and top-level-p (%config-top-level-language-line-p line))
          (progn
            (setf found-p t)
            (push (%config-language-line language line) result))
          (push line result)))
    (let ((rewritten (nreverse result)))
      (if found-p
          rewritten
          (%insert-config-language-line rewritten language)))))

(defun %write-config-language (path language)
  (let ((lines
          (if (han.path:file-exists-p path)
              (han.os:load-lines path)
              (list (format nil "schema_version = \"~A\""
                            *taffish-config-schema-version*)))))
    (ensure-directories-exist path)
    (with-open-file (out path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (dolist (line (%rewrite-config-language-lines lines language))
        (write-line line out)))))

(defun %normalize-config-language-choice (language available-languages)
  (let* ((raw (and (stringp language) (%trim-string language)))
         (normalized (and (%config-non-empty-string-p raw)
                          (taffish.i18n:normalize-language raw)))
         (available-ids (mapcar (lambda (entry) (getf entry :id))
                                available-languages)))
    (if (and normalized
             (or (string= normalized "auto")
                 (member normalized available-ids :test #'string=)))
        normalized
        (error "~A"
               (taffish.i18n:message
                "config.language.error.unknown"
                (list (cons "language" (or raw (prin1-to-string language)))))))))

(defun %config-language-source-text (source)
  (%config-human-text
   (case source
     (:environment "config.language.source.environment")
     (:explicit-config "config.language.source.explicit-config")
     (:user-config "config.language.source.user-config")
     (:system-config "config.language.source.system-config")
     (:locale-environment "config.language.source.locale-environment")
     (otherwise "config.language.source.default"))))

(defun %config-language-origin-text (origin)
  (%config-human-text
   (case origin
     (:user "config.language.origin.user")
     (:system "config.language.origin.system")
     (otherwise "config.language.origin.built-in"))))

(defun %print-system-config-language (result)
  (format t "~A~%" (%config-human-text "config.language.header"))
  (%config-print-human-field
   "config.label.scope"
   (string-downcase (string (getf result :scope))))
  (when (getf result :updated-p)
    (%config-print-human-field "config.label.saved-language"
                               (getf result :saved-language)))
  (%config-print-human-field "config.label.configured-language"
                             (getf result :configured-language))
  (%config-print-human-field "config.label.display-language"
                             (getf result :display-language))
  (%config-print-human-field
   "config.label.configured-source"
   (%config-language-source-text (getf result :configured-source)))
  (%config-print-human-field
   "config.label.display-source"
   (%config-language-source-text (getf result :display-source)))
  (%config-print-human-field
   "config.label.source-file"
   (or (getf result :source-file)
       (%config-human-text "config.value.none")))
  (%config-print-human-field "config.label.target-file"
                             (getf result :config-file))
  (format t "~%~A~%" (%config-human-text "config.language.section.available"))
  (dolist (entry (getf result :available-languages))
    (format t "  ~8A [~A]~@[ ~A~]~%"
            (getf entry :id)
            (%config-language-origin-text (getf entry :origin))
            (getf entry :example)))
  (format t "~%~A~%" (%config-human-text "config.language.section.mode"))
  (format t "  ~8A ~A~%"
          "auto"
          (%config-human-text "config.language.mode.auto")))

(defun system-config-language (&key
                                 language
                                 (scope :user)
                                 user-home
                                 system-home
                                 (verbose t))
  "Inspect or update the top-level TAFFISH language preference.

Only the selected scope's language field is changed. Existing config text is
preserved; external locale selection is restricted to valid discovered packs."
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (config-file (%taffish-config-file home))
         (available
           (taffish.i18n:available-languages
            :user-home user-home-path
            :system-home system-home-path))
         (saved-language
           (and language
                (%normalize-config-language-choice language available))))
    (when (and saved-language
               (eql normalized-scope :system)
               (not (%root-user-p)))
      (error "~A" (%config-human-text "config.language.error.system-root")))
    (when saved-language
      (%write-config-language config-file saved-language))
    (let* ((configured
             (taffish.i18n:resolve-language-details
              :user-home user-home-path
              :system-home system-home-path
              :include-user-config-p (eql normalized-scope :user)))
           (displayed
             (taffish.i18n:resolve-language-details
              :user-home user-home-path
              :system-home system-home-path))
           (result
             (list :scope normalized-scope
                   :configured-language (getf configured :configured-language)
                   :configured-source (getf configured :configured-source)
                   :display-language (getf displayed :display-language)
                   :display-source (getf displayed :display-source)
                   :source-file (getf displayed :config-file)
                   :config-file (%config-file-namestring config-file)
                   :available-languages available
                   :updated-p (not (null saved-language))
                   :saved-language saved-language)))
      (when verbose
        (taffish.i18n:with-language ((getf result :display-language)
                                     :user-home user-home-path
                                     :system-home system-home-path)
          (%print-system-config-language result)))
      result)))

(defun %print-system-config-init (result)
  (format t "~A~%" (%config-human-text "config.init.header"))
  (%config-print-human-field
   "config.label.scope"
   (string-downcase (string (getf result :scope))))
  (%config-print-human-field
   "config.label.profile"
   (string-downcase (string (getf result :profile))))
  (%config-print-human-field "config.label.file" (getf result :file)))

(defun system-config-init (&key
                             (scope :user)
                             (profile :github)
                             force-p
                             user-home
                             system-home
                             (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (normalized-profile (%normalize-taffish-config-profile profile))
         (home (%taffish-home
                :scope normalized-scope
                :user-home (%taffish-user-home user-home)
                :system-home (%taffish-system-home system-home)))
         (file (%taffish-config-file home)))
    (when (and (eql normalized-scope :system)
               (not (%root-user-p)))
      (error "[config] init --system requires root permission."))
    (%write-taffish-config-file file
                                (%taffish-config-template normalized-profile)
                                force-p)
    (let ((result (list :scope normalized-scope
                        :profile normalized-profile
                        :file (%config-file-namestring file)
                        :force-p force-p)))
      (when verbose
        (%print-system-config-init result))
      result)))

(defun %print-system-config (config)
  (format t "~A~%" (%config-human-text "config.header"))
  (%config-print-human-field
   "config.label.scope"
   (string-downcase (string (getf config :scope))))
  (%config-print-human-field "config.label.taffish-user-home"
                             (%config-human-env-value
                              (getf config :user-home-env)))
  (%config-print-human-field "config.label.taffish-system-home"
                             (%config-human-env-value
                              (getf config :system-home-env)))
  (%config-print-human-field "config.label.taffish-system-bin"
                             (%config-human-env-value
                              (getf config :system-bin-env)))
  (%config-print-human-field "config.label.taffish-config"
                             (%config-human-env-value
                              (getf config :explicit-config-file)))
  (%config-print-human-field "config.label.user-home" (getf config :user-home))
  (%config-print-human-field "config.label.system-home"
                             (getf config :system-home))
  (%config-print-human-field "config.label.system-command-bin"
                             (getf config :system-bin-dir))
  (%config-print-human-field "config.label.active-home" (getf config :home))
  (%config-print-human-field "config.label.active-command-bin"
                             (getf config :command-bin-dir))
  (%config-print-human-field "config.label.active-config-file"
                             (getf config :config-file))
  (format t "~%~A~%" (%config-human-text "config.section.effective"))
  (%config-print-human-field "config.label.profile" (getf config :profile))
  (%config-print-human-field "config.label.language" (getf config :language))
  (%config-print-human-field "config.label.display-language"
                             (taffish.i18n:current-language))
  (%config-print-human-field "config.label.index-url" (getf config :index-url))
  (%config-print-human-field
   "config.label.loaded-files"
   (format nil "~{~A~^, ~}"
           (or (getf config :loaded-config-files)
               (list (%config-human-text "config.value.none")))))
  (%config-print-human-field "config.label.source-rules"
                             (length (getf config :source-rewrite-rules)))
  (dolist (rule (getf config :source-rewrite-rules))
    (format t "    ~A -> ~A [~A]~%"
            (getf rule :from)
            (getf rule :to)
            (%config-human-text
             (if (getf rule :enabled)
                 "config.value.enabled"
                 "config.value.disabled"))))
  (format t "~%~A~%" (%config-human-text "config.section.directories"))
  (%config-print-human-field "config.label.apps" (getf config :apps-dir))
  (%config-print-human-field "config.label.index" (getf config :index-dir))
  (%config-print-human-field "config.label.index-current"
                             (getf config :index-current-file))
  (%config-print-human-field "config.label.images" (getf config :images-dir))
  (%config-print-human-field "config.label.images-sif"
                             (getf config :images-sif-dir))
  (%config-print-human-field "config.label.bin" (getf config :bin-dir))
  (%config-print-human-field "config.label.cache" (getf config :cache-dir))
  (%config-print-human-field "config.label.share" (getf config :share-dir))
  (%config-print-human-field "config.label.logs" (getf config :logs-dir))
  nil)

(defun system-config (&key
                        (scope :user)
                        user-home
                        system-home
                        system-bin-dir
                        (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (system-bin-path (%taffish-system-bin-dir system-bin-dir))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (command-bin-dir
           (%taffish-command-bin-dir normalized-scope home system-bin-path))
         (index-dir (%config-dir home "index"))
         (effective (%effective-taffish-config
                     :scope normalized-scope
                     :user-home user-home-path
                     :system-home system-home-path))
         (config-paths (%taffish-config-path-result
                        :scope normalized-scope
                        :user-home user-home-path
                        :system-home system-home-path
                        :system-bin-dir system-bin-path))
         (config (list :scope normalized-scope
                       :user-home-env (%config-env-value "TAFFISH_USER_HOME")
                       :system-home-env (%config-env-value "TAFFISH_SYSTEM_HOME")
                       :system-bin-env
                       (%config-env-value "TAFFISH_SYSTEM_BIN_DIR")
                       :explicit-config-file
                       (or (%config-explicit-file) "<unset>")
                       :user-home (%directory-namestring user-home-path)
                       :system-home (%directory-namestring system-home-path)
                       :system-bin-dir (%directory-namestring system-bin-path)
                       :home (%directory-namestring home)
                       :command-bin-dir
                       (%directory-namestring command-bin-dir)
                       :config-file (getf config-paths :config-file)
                       :user-config-file (getf config-paths :user-config-file)
                       :system-config-file
                       (getf config-paths :system-config-file)
                       :schema-version (getf effective :schema-version)
                       :profile (getf effective :profile)
                       :language (getf effective :language)
                       :index-url (getf effective :index-url)
                       :source-rewrite-rules
                       (getf effective :source-rewrite-rules)
                       :loaded-config-files
                       (getf effective :config-files)
                       :apps-dir (%config-dir home "apps")
                       :index-dir index-dir
                       :index-current-file
                       (han.path:->namestring
                        (han.path:join-path index-dir "current.json"))
                       :images-dir (%config-dir home "images")
                       :images-sif-dir (%config-dir home "images/sif")
                       :bin-dir (%config-dir home "bin")
                       :cache-dir (%config-dir home "cache")
                       :share-dir (%config-dir home "share")
                       :logs-dir (%config-dir home "logs"))))
    (when verbose
      (%print-system-config config))
    config))
