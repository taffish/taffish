(in-package :taf.core)

;;;; ============================================================
;;;; system / config.lisp
;;;; ============================================================

(defparameter *taffish-config-schema-version*
  "taffish.config/v1")

(defparameter *default-taffish-language*
  "en")

(defparameter *default-gitee-host*
  "gitee.com")

(defparameter *default-gitee-owner*
  "taffish-org")

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
  (format t "[TAF] config path~%")
  (format t "  scope        : ~A~%"
          (string-downcase (string (getf result :scope))))
  (format t "  active file  : ~A~%" (getf result :config-file))
  (format t "  user file    : ~A~%" (getf result :user-config-file))
  (format t "  system file  : ~A~%" (getf result :system-config-file))
  (format t "  TAFFISH_CONFIG : ~A~%" (getf result :explicit-config-file)))

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

(defun %print-system-config-init (result)
  (format t "[TAF] initialized config~%")
  (format t "  scope   : ~A~%"
          (string-downcase (string (getf result :scope))))
  (format t "  profile : ~A~%"
          (string-downcase (string (getf result :profile))))
  (format t "  file    : ~A~%" (getf result :file)))

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
  (format t "[TAF] config~%")
  (format t "  scope                : ~A~%"
          (string-downcase (string (getf config :scope))))
  (format t "  TAFFISH_USER_HOME    : ~A~%" (getf config :user-home-env))
  (format t "  TAFFISH_SYSTEM_HOME  : ~A~%" (getf config :system-home-env))
  (format t "  TAFFISH_SYSTEM_BIN_DIR : ~A~%"
          (getf config :system-bin-env))
  (format t "  TAFFISH_CONFIG       : ~A~%" (getf config :explicit-config-file))
  (format t "  user home            : ~A~%" (getf config :user-home))
  (format t "  system home          : ~A~%" (getf config :system-home))
  (format t "  system command bin   : ~A~%" (getf config :system-bin-dir))
  (format t "  active home          : ~A~%" (getf config :home))
  (format t "  active command bin   : ~A~%" (getf config :command-bin-dir))
  (format t "  active config file   : ~A~%" (getf config :config-file))
  (format t "~%Effective config:~%")
  (format t "  profile              : ~A~%" (getf config :profile))
  (format t "  language             : ~A~%" (getf config :language))
  (format t "  index url            : ~A~%" (getf config :index-url))
  (format t "  loaded config files  : ~{~A~^, ~}~%"
          (or (getf config :loaded-config-files) '("<none>")))
  (format t "  source rewrite rules : ~A~%"
          (length (getf config :source-rewrite-rules)))
  (dolist (rule (getf config :source-rewrite-rules))
    (format t "    ~A -> ~A [~A]~%"
            (getf rule :from)
            (getf rule :to)
            (if (getf rule :enabled) "enabled" "disabled")))
  (format t "~%Active directories:~%")
  (format t "  apps                 : ~A~%" (getf config :apps-dir))
  (format t "  index                : ~A~%" (getf config :index-dir))
  (format t "  index current        : ~A~%" (getf config :index-current-file))
  (format t "  images               : ~A~%" (getf config :images-dir))
  (format t "  images sif           : ~A~%" (getf config :images-sif-dir))
  (format t "  bin                  : ~A~%" (getf config :bin-dir))
  (format t "  cache                : ~A~%" (getf config :cache-dir))
  (format t "  share                : ~A~%" (getf config :share-dir))
  (format t "  logs                 : ~A~%" (getf config :logs-dir))
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
