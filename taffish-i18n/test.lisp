(in-package :han.test)

;;;; ============================================================
;;;; taffish.i18n tests
;;;; ============================================================

(defun %i18n-temp-directory (name)
  (han.path:directory-pathname
   (han.path:join-path (han.path:temporary-directory)
                       (format nil "taffish-i18n-~A-~D/"
                               name (random 1000000)))))

(defun %i18n-write-file (path content)
  (ensure-directories-exist path)
  (with-open-file (out path
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (write-string content out)))

(defun %i18n-language-entry (id entries)
  (find id entries :key (lambda (entry) (getf entry :id)) :test #'string=))

(deftest test-taffish-i18n-normalize-language ()
  (check-equal (taffish.i18n:normalize-language "en") "en")
  (check-equal (taffish.i18n:normalize-language "en-US") "en")
  (check-equal (taffish.i18n:normalize-language "en_US.UTF-8") "en")
  (check-equal (taffish.i18n:normalize-language "zh-CN") "zh")
  (check-equal (taffish.i18n:normalize-language "zh_CN.UTF-8") "zh")
  (check-equal (taffish.i18n:normalize-language "zh-Hans") "zh")
  (check-equal (taffish.i18n:normalize-language "JA_jp.UTF-8") "ja-JP")
  (check-equal (taffish.i18n:normalize-language "C") "en"))

(deftest test-taffish-i18n-fallback-chain ()
  (check-equal (taffish.i18n:language-fallback-chain "en") '("en"))
  (check-equal (taffish.i18n:language-fallback-chain "zh") '("zh" "en"))
  (check-equal (taffish.i18n:language-fallback-chain "ja-JP")
               '("ja-JP" "ja" "en")))

(deftest test-taffish-i18n-builtin-message-and-placeholders ()
  (taffish.i18n:register-message
   "test.greeting"
   "Hello, {name}."
   "你好，{name}。")
  (taffish.i18n:with-language ("en")
    (check-equal "Hello, TAFFISH."
                 (taffish.i18n:message
                  "test.greeting" '(("name" . "TAFFISH")))))
  (taffish.i18n:with-language ("zh")
    (check-equal "你好，TAFFISH。"
                 (taffish.i18n:message
                  "test.greeting" '(("name" . "TAFFISH"))))))

(deftest test-taffish-i18n-rejects-builtin-placeholder-mismatch ()
  (check-true
   (handler-case
       (progn
         (taffish.i18n:register-message
          "test.bad-placeholder" "Path: {path}" "路径：{file}")
         nil)
     (error () t))))

(deftest test-taffish-i18n-external-message-user-over-system ()
  (let ((user-home (%i18n-temp-directory "user"))
        (system-home (%i18n-temp-directory "system")))
    (unwind-protect
         (progn
           (taffish.i18n:register-message
            "test.external" "Value: {value}" "值：{value}")
           (%i18n-write-file
            (han.path:join-path system-home
                                "share/locales/ja/messages.json")
            "{\"test.external\":\"system {value}\"}")
           (%i18n-write-file
            (han.path:join-path user-home
                                "share/locales/ja/messages.json")
            "{\"test.external\":\"user {value}\"}")
           (taffish.i18n:with-language
               ("ja-JP" :user-home user-home :system-home system-home)
             (check-equal "user ok"
                          (taffish.i18n:message
                           "test.external" '(("value" . "ok"))))))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))

(deftest test-taffish-i18n-invalid-external-placeholder-falls-back ()
  (let ((user-home (%i18n-temp-directory "invalid")))
    (unwind-protect
         (progn
           (taffish.i18n:register-message
            "test.external-invalid" "Value: {value}" "值：{value}")
           (%i18n-write-file
            (han.path:join-path user-home
                                "share/locales/ja/messages.json")
            "{\"test.external-invalid\":\"bad {other}\"}")
           (taffish.i18n:with-language ("ja" :user-home user-home)
             (check-equal "Value: ok"
                          (taffish.i18n:message
                           "test.external-invalid"
                           '(("value" . "ok"))))))
      (ignore-errors (han.path:delete-directory-tree user-home)))))

(deftest test-taffish-i18n-external-cannot-override-builtins ()
  (let ((user-home (%i18n-temp-directory "builtin")))
    (unwind-protect
         (progn
           (%i18n-write-file
            (han.path:join-path user-home
                                "share/locales/zh/messages.json")
            "{\"cli.show-help\":\"bad override\"}")
           (taffish.i18n:with-language ("zh" :user-home user-home)
             (check-equal (taffish.i18n:message "cli.show-help")
                          "显示此帮助")))
      (ignore-errors (han.path:delete-directory-tree user-home)))))

(deftest test-taffish-i18n-help-external-and-builtin-fallback ()
  (let ((user-home (%i18n-temp-directory "help")))
    (unwind-protect
         (progn
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/ja/help/taf.txt")
            "TAF ヘルプ")
           (taffish.i18n:with-language ("ja-JP" :user-home user-home)
             (check-equal
              "TAF ヘルプ"
              (taffish.i18n:help-text "taf" nil "TAF help" "TAF 帮助")))
           (taffish.i18n:with-language ("zh" :user-home user-home)
             (check-equal
              "TAF 帮助"
              (taffish.i18n:help-text "taf" nil "TAF help" "TAF 帮助"))))
      (ignore-errors (han.path:delete-directory-tree user-home)))))

(deftest test-taffish-i18n-resolve-priority-and-auto ()
  (let ((user-home (%i18n-temp-directory "resolve-user"))
        (system-home (%i18n-temp-directory "resolve-system")))
    (unwind-protect
         (progn
           (%i18n-write-file (han.path:join-path system-home "config.toml")
                             (format nil "language = \"ja\"~%"))
           (%i18n-write-file (han.path:join-path user-home "config.toml")
                             (format nil "language = \"zh\"~%"))
           (let ((environment
                   (list (cons "TAFFISH_LANGUAGE" nil)
                         (cons "TAFFISH_CONFIG" nil)
                         (cons "LC_ALL" nil)
                         (cons "LC_MESSAGES" nil)
                         (cons "LANG" "C"))))
             (let ((taffish.i18n::*environment-reader*
                     (lambda (name)
                       (cdr (assoc name environment :test #'string=)))))
               (check-equal
                "zh"
                (taffish.i18n:resolve-language
                 :user-home user-home :system-home system-home))
               (setf (cdr (assoc "TAFFISH_LANGUAGE" environment
                                 :test #'string=))
                     "en_US.UTF-8")
               (check-equal
                "en"
                (taffish.i18n:resolve-language
                 :user-home user-home :system-home system-home))
               (setf (cdr (assoc "TAFFISH_LANGUAGE" environment
                                 :test #'string=))
                     "auto")
               (setf (cdr (assoc "LC_ALL" environment :test #'string=))
                     "zh_CN.UTF-8")
               (check-equal
                "zh"
                (taffish.i18n:resolve-language
                 :user-home user-home :system-home system-home)))))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))

(deftest test-taffish-i18n-explicit-config-priority ()
  (let ((user-home (%i18n-temp-directory "explicit-user"))
        (system-home (%i18n-temp-directory "explicit-system"))
        (explicit-config
          (han.path:join-path (%i18n-temp-directory "explicit")
                              "config.toml")))
    (unwind-protect
         (progn
           (%i18n-write-file (han.path:join-path system-home "config.toml")
                             (format nil "language = \"ja\"~%"))
           (%i18n-write-file (han.path:join-path user-home "config.toml")
                             (format nil "language = \"zh\"~%"))
           (%i18n-write-file explicit-config
                             (format nil "language = \"en\"~%"))
           (let ((environment
                   (list (cons "TAFFISH_LANGUAGE" nil)
                         (cons "TAFFISH_CONFIG"
                               (han.path:->namestring explicit-config))
                         (cons "LC_ALL" "zh_CN.UTF-8")
                         (cons "LC_MESSAGES" nil)
                         (cons "LANG" nil))))
             (let ((taffish.i18n::*environment-reader*
                     (lambda (name)
                       (cdr (assoc name environment :test #'string=)))))
               (check-equal
                "en"
                (taffish.i18n:resolve-language
                 :user-home user-home :system-home system-home))
               (setf (cdr (assoc "TAFFISH_LANGUAGE" environment
                                 :test #'string=))
                     "zh")
               (check-equal
                "zh"
                (taffish.i18n:resolve-language
                 :user-home user-home :system-home system-home)))))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home))
      (ignore-errors
        (han.path:delete-directory-tree
         (han.path:parent-directory-pathname explicit-config))))))

(deftest test-taffish-i18n-default-auto-and-explicit-en ()
  (let ((user-home (%i18n-temp-directory "locale-user"))
        (system-home (%i18n-temp-directory "locale-system"))
        (environment
          (list (cons "TAFFISH_LANGUAGE" nil)
                (cons "TAFFISH_CONFIG" nil)
                (cons "LC_ALL" "zh_CN.UTF-8")
                (cons "LC_MESSAGES" nil)
                (cons "LANG" nil))))
    (unwind-protect
         (let ((taffish.i18n::*environment-reader*
                 (lambda (name)
                   (cdr (assoc name environment :test #'string=)))))
           (let ((details
                   (taffish.i18n:resolve-language-details
                    :user-home user-home :system-home system-home)))
             (check-equal (getf details :configured-language) "auto")
             (check-equal (getf details :configured-source) :default)
             (check-equal (getf details :display-language) "zh")
             (check-equal (getf details :display-source) :locale-environment))
           (%i18n-write-file (han.path:join-path user-home "config.toml")
                             (format nil "language = \"en\"~%"))
           (let ((details
                   (taffish.i18n:resolve-language-details
                    :user-home user-home :system-home system-home)))
             (check-equal (getf details :configured-language) "en")
             (check-equal (getf details :configured-source) :user-config)
             (check-equal (getf details :display-language) "en")
             (check-equal (getf details :display-source) :user-config)))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))

(deftest test-taffish-i18n-default-auto-english-fallback ()
  (let ((user-home (%i18n-temp-directory "fallback-user"))
        (system-home (%i18n-temp-directory "fallback-system"))
        (environment
          (list (cons "TAFFISH_LANGUAGE" nil)
                (cons "TAFFISH_CONFIG" nil)
                (cons "LC_ALL" nil)
                (cons "LC_MESSAGES" nil)
                (cons "LANG" nil))))
    (unwind-protect
         (let ((taffish.i18n::*environment-reader*
                 (lambda (name)
                   (cdr (assoc name environment :test #'string=)))))
           (let ((details
                   (taffish.i18n:resolve-language-details
                    :user-home user-home :system-home system-home)))
             (check-equal (getf details :configured-language) "auto")
             (check-equal (getf details :configured-source) :default)
             (check-equal (getf details :display-language) "en")
             (check-equal (getf details :display-source) :default)))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))

(deftest test-taffish-i18n-resolve-language-details ()
  (let ((user-home (%i18n-temp-directory "details-user"))
        (system-home (%i18n-temp-directory "details-system"))
        (environment
          (list (cons "TAFFISH_LANGUAGE" nil)
                (cons "TAFFISH_CONFIG" nil)
                (cons "LC_ALL" "zh_CN.UTF-8")
                (cons "LC_MESSAGES" nil)
                (cons "LANG" nil))))
    (unwind-protect
         (progn
           (%i18n-write-file (han.path:join-path system-home "config.toml")
                             (format nil "language = \"ja\"~%"))
           (%i18n-write-file (han.path:join-path user-home "config.toml")
                             (format nil "language = \"auto\"~%"))
           (let ((taffish.i18n::*environment-reader*
                   (lambda (name)
                     (cdr (assoc name environment :test #'string=)))))
             (let ((details
                     (taffish.i18n:resolve-language-details
                      :user-home user-home :system-home system-home)))
               (check-equal (getf details :configured-language) "auto")
               (check-equal (getf details :configured-source) :user-config)
               (check-equal (getf details :display-language) "zh")
               (check-equal (getf details :display-source) :locale-environment)
               (check-equal
                (getf details :config-file)
                (han.path:->namestring
                 (han.path:join-path user-home "config.toml"))))
             (let ((system-details
                     (taffish.i18n:resolve-language-details
                      :user-home user-home
                      :system-home system-home
                      :include-user-config-p nil)))
               (check-equal (getf system-details :configured-language) "ja")
               (check-equal (getf system-details :configured-source)
                            :system-config))
             (setf (cdr (assoc "TAFFISH_LANGUAGE" environment :test #'string=))
                   "en")
             (let ((details
                     (taffish.i18n:resolve-language-details
                      :user-home user-home :system-home system-home)))
               (check-equal (getf details :configured-language) "auto")
               (check-equal (getf details :display-language) "en")
               (check-equal (getf details :display-source) :environment))))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))

(deftest test-taffish-i18n-available-languages-discovery ()
  (let ((user-home (%i18n-temp-directory "languages-user"))
        (system-home (%i18n-temp-directory "languages-system")))
    (unwind-protect
         (progn
           (%i18n-write-file
            (han.path:join-path system-home
                                "share/locales/ja-JP/messages.json")
            "{\"hello\":\"system\"}")
           (%i18n-write-file
            (han.path:join-path system-home
                                "share/locales/ja-JP/example.txt")
            (format nil "SYSTEM EXAMPLE~%"))
           (%i18n-write-file
            (han.path:join-path user-home
                                "share/locales/ja-JP/help/taf/install.txt")
            (format nil "USER HELP~%"))
           (%i18n-write-file
            (han.path:join-path user-home
                                "share/locales/ja-JP/example.txt")
            (format nil "~%USER EXAMPLE~%ignored~%"))
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/de/messages.json")
            "{\"hello\":\"hallo\"}")
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/de/example.txt")
            (make-string 300 :initial-element #\x))
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/it/example.txt")
            (format nil "EXAMPLE ONLY~%"))
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/fr/messages.json")
            "not json")
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/JA_jp/messages.json")
            "{\"hello\":\"bad directory id\"}")
           (%i18n-write-file
            (han.path:join-path user-home "share/locales/en/messages.json")
            "{\"hello\":\"override\"}")
           (let* ((entries
                    (taffish.i18n:available-languages
                     :user-home user-home :system-home system-home))
                  (ids (mapcar (lambda (entry) (getf entry :id)) entries))
                  (japanese (%i18n-language-entry "ja-JP" entries))
                  (german (%i18n-language-entry "de" entries)))
             (check-equal ids '("en" "zh" "de" "ja-JP"))
             (check-equal (getf japanese :origin) :user)
             (check-equal (getf japanese :example) "USER EXAMPLE")
             (check-equal (length (getf german :example)) 256)
             (check-equal (%i18n-language-entry "it" entries) nil)
             (check-equal (%i18n-language-entry "fr" entries) nil)))
      (ignore-errors (han.path:delete-directory-tree user-home))
      (ignore-errors (han.path:delete-directory-tree system-home)))))
