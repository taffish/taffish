(in-package :han.test)

;;;; ============================================================
;;;; taf.core system tests
;;;; ============================================================

(defun %taf-system-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %taf-system-error-string (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (error (condition)
      (princ-to-string condition))))

(defun %taf-system-temp-dir ()
  (let ((name (format nil "taf-system-test-~A/" (gensym "DIR"))))
    (merge-pathnames name (uiop:temporary-directory))))

(defun %taf-system-temp-dir-named (name)
  (han.path:directory-pathname
   (merge-pathnames
    (format nil "~A-~A/" name (gensym "DIR"))
    (uiop:temporary-directory))))

(defmacro with-taf-system-temp-dir ((dir) &body body)
  `(let ((,dir (%taf-system-temp-dir)))
     (declare (ignorable ,dir))
     (unwind-protect
          (progn ,@body)
       (uiop:delete-directory-tree ,dir :validate t :if-does-not-exist :ignore))))

(defun %taf-system-dir (&rest parts)
  (han.path:directory-pathname (apply #'han.path:join-path parts)))

(defun %taf-system-write-string (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type 'character
                            :external-format :utf-8)
    (write-string string out)))

(deftest test-taf-system-path-env-contains-dir-normalizes-slash ()
  (with-taf-system-temp-dir (user-home)
    (let* ((bin-dir (han.path:join-path user-home "bin"))
           (bin-string (string-right-trim
                        '(#\/)
                        (taf.core::%directory-namestring bin-dir))))
      (check-equal
       (taf.core::%path-env-contains-dir-p bin-dir
                                           (format nil "/usr/bin:~A" bin-string))
       t)
      (check-equal
       (taf.core::%path-env-contains-dir-p bin-dir "/usr/bin:/bin")
       nil))))

(deftest test-taf-system-doctor-missing-user-home-needs-init ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-doctor
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :status) :needs-init)
      (check-equal (getf result :scope) :user)
      (check-equal
       (not (null
             (find :missing
                   (getf result :directories)
                   :key (lambda (item) (getf item :status)))))
       t))))

(deftest test-taf-system-doctor-checks-apptainer-squashfs-tools ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-doctor
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))
           (executables (getf result :executables)))
      (check-equal
       (not (null
             (find "apptainer" executables
                   :key (lambda (item) (getf item :name))
                   :test #'string=)))
       t)
      (check-equal
       (not (null
             (find "mksquashfs" executables
                   :key (lambda (item) (getf item :name))
                   :test #'string=)))
       t)
      (check-equal
       (not (null
             (find "squashfuse" executables
                   :key (lambda (item) (getf item :name))
                   :test #'string=)))
       t)
      (check-equal
       (not (null
             (find "fuse2fs" executables
                   :key (lambda (item) (getf item :name))
                   :test #'string=)))
       t)
      (check-equal
       (not (null
             (find "gocryptfs" executables
                   :key (lambda (item) (getf item :name))
                   :test #'string=)))
       t))))

(deftest test-taf-system-config-user-scope-no-side-effect ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-config
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :scope) :user)
      (check-equal (getf result :home) (han.path:->namestring user-home))
      (check-equal (getf result :language) "auto")
      (check-equal
       (not (null
             (search "/apps/" (getf result :apps-dir) :test #'char=)))
       t)
      (check-equal
       (not (null
             (search "/index/current.json"
                     (getf result :index-current-file)
                     :test #'char=)))
       t)
      (check-equal (probe-file user-home) nil))))

(deftest test-taf-system-config-system-scope ()
  (with-taf-system-temp-dir (system-home)
    (let* ((user-home (%taf-system-temp-dir-named "taf-user-unused"))
           (system-bin (%taf-system-temp-dir-named "taf-system-bin"))
           (result (taf.core:system-config
                    :scope :system
                    :user-home user-home
                    :system-home system-home
                    :system-bin-dir system-bin
                    :verbose nil)))
      (check-equal (getf result :scope) :system)
      (check-equal (getf result :home) (han.path:->namestring system-home))
      (check-equal (getf result :command-bin-dir)
                   (han.path:->namestring system-bin))
	      (check-equal
	       (not (null
	             (search "/images/sif/" (getf result :images-sif-dir) :test #'char=)))
	       t))))

(deftest test-taf-system-config-path ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-config-path"))
           (result (taf.core:system-config-path
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :scope) :user)
      (check-equal
       (not (null
             (search "/config.toml"
                     (getf result :config-file)
                     :test #'char=)))
       t)
      (check-equal
       (not (null
             (search (han.path:->namestring user-home)
                     (getf result :user-config-file)
                     :test #'char=)))
       t))))

(deftest test-taf-system-config-user-overrides-system ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/"))
           (system-config (han.path:join-path system-home "config.toml"))
           (user-config (han.path:join-path user-home "config.toml")))
      (%taf-system-write-string
       system-config
       "schema_version = \"taffish.config/v1\"
profile = \"system-test\"

[index]
url = \"file:///system-index.json\"
")
      (%taf-system-write-string
       user-config
       "schema_version = \"taffish.config/v1\"
profile = \"user-test\"

[index]
url = \"file:///user-index.json\"

[[source.rewrite]]
from = \"https://github.com/taffish/\"
to = \"https://gitee.com/taffish-org/\"
enabled = true
")
      (check-equal
       (taf.core::%resolve-taffish-index-url
        :scope :user
        :user-home user-home
        :system-home system-home)
       "file:///user-index.json")
      (check-equal
       (taf.core::%resolve-taffish-index-url
        :scope :system
        :user-home user-home
        :system-home system-home)
       "file:///system-index.json")
      (multiple-value-bind (resolved rule)
          (taf.core::%resolve-taffish-source-url
           "https://github.com/taffish/demo"
           :scope :user
           :user-home user-home
           :system-home system-home)
        (check-equal resolved "https://gitee.com/taffish-org/demo")
        (check-equal (getf rule :enabled) t)))))

(deftest test-taf-system-config-init-china ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-config-init
                    :scope :user
                    :profile :china
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))
           (content (han.os:load-string (getf result :file))))
      (check-equal (getf result :profile) :china)
      (check-equal
       (not (null (search "profile = \"china\"" content :test #'char=)))
       t)
      (check-equal
       (not (null (search "https://gitee.com/taffish-org/" content :test #'char=)))
       t)
      (check-true (search "language = \"auto\"" content :test #'char=)))))

(deftest test-taf-system-config-init-github-defaults-to-auto ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-config-init
                    :scope :user
                    :profile :github
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))
           (content (han.os:load-string (getf result :file))))
      (check-equal (getf result :profile) :github)
      (check-true (search "language = \"auto\"" content :test #'char=)))))

(deftest test-taf-system-config-existing-file-message-is-multiline ()
  (let ((message
          (taffish.i18n:with-language ("en")
            (taf.core::%config-message
             "config.error.exists"
             :path "/tmp/config.toml"))))
    (check-true
     (search
      (format nil
              "config file already exists: /tmp/config.toml~%Use --force")
      message
      :test #'char=))
    (check-equal (search "config.tomlnUse --force"
                         message
                         :test #'char=)
                 nil)))

(deftest test-taf-system-config-language-query-is-read-only ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/")))
      (let ((taffish.i18n::*environment-reader*
              (lambda (name) (declare (ignore name)) nil)))
        (let ((result (taf.core:system-config-language
                       :user-home user-home
                       :system-home system-home
                       :verbose nil)))
          (check-equal (getf result :configured-language) "auto")
          (check-equal (getf result :configured-source) :default)
          (check-equal (getf result :display-language) "en")
          (check-equal (getf result :display-source) :default)
          (check-equal (getf result :updated-p) nil)
          (check-equal
           (mapcar (lambda (entry) (getf entry :id))
                   (getf result :available-languages))
           '("en" "zh"))
          (check-equal (probe-file user-home) nil))))))

(deftest test-taf-system-config-language-preserves-config-text ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/"))
           (config-file (han.path:join-path user-home "config.toml"))
           (original
             "# custom config
schema_version = \"taffish.config/v1\"
profile = \"china\"
language = \"en\"  # keep language comment
future_key = \"preserve-me\"

[index]
url = \"file:///custom-index.json\"
"))
      (%taf-system-write-string config-file original)
      (let ((taffish.i18n::*environment-reader*
              (lambda (name) (declare (ignore name)) nil)))
        (let* ((result
                 (taf.core:system-config-language
                  :language "zh"
                  :user-home user-home
                  :system-home system-home
                  :verbose nil))
               (content (han.os:load-string config-file)))
          (check-equal (getf result :saved-language) "zh")
          (check-equal (getf result :configured-language) "zh")
          (check-true (search "language = \"zh\"  # keep language comment"
                              content :test #'char=))
          (check-true (search "future_key = \"preserve-me\""
                              content :test #'char=))
          (check-true (search "profile = \"china\"" content :test #'char=))
          (check-true (search "url = \"file:///custom-index.json\""
                              content :test #'char=))
          (check-equal
           content
           "# custom config
schema_version = \"taffish.config/v1\"
profile = \"china\"
language = \"zh\"  # keep language comment
future_key = \"preserve-me\"

[index]
url = \"file:///custom-index.json\""))))))

(deftest test-taf-system-config-language-inserts-and-validates-external ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/"))
           (config-file (han.path:join-path user-home "config.toml")))
      (%taf-system-write-string
       config-file
       "schema_version = \"taffish.config/v1\"

[index]
url = \"file:///index.json\"
")
      (%taf-system-write-string
       (han.path:join-path user-home "share/locales/ja/messages.json")
       "{\"hello\":\"こんにちは\"}")
      (let ((taffish.i18n::*environment-reader*
              (lambda (name) (declare (ignore name)) nil)))
        (let ((result
                (taf.core:system-config-language
                 :language "ja"
                 :user-home user-home
                 :system-home system-home
                 :verbose nil)))
          (check-equal (getf result :saved-language) "ja")
          (check-true
           (search "language = \"ja\""
                   (han.os:load-string config-file)
                   :test #'char=)))
        (check-true
         (%taf-system-signal-error-p
          (lambda ()
            (taf.core:system-config-language
             :language "fr"
             :user-home user-home
             :system-home system-home
             :verbose nil))))))))

(deftest test-taf-system-config-language-system-requires-root ()
  (unless (taf.core::%root-user-p)
    (with-taf-system-temp-dir (root)
      (check-true
       (%taf-system-signal-error-p
        (lambda ()
          (taf.core:system-config-language
           :language "zh"
           :scope :system
           :user-home (han.path:join-path root "user/")
           :system-home (han.path:join-path root "system/")
           :verbose nil)))))))

(deftest test-taf-system-doctor-init-user-home-creates-dirs ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-doctor
                    :init-p t
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))
           (dirs (getf result :directories))
           (path-results (getf result :paths)))
      (check-equal
       (not (null
             (find :missing dirs :key (lambda (item) (getf item :status)))))
       nil)
      (check-equal
       (not (null
             (find :not-in-path
                   path-results
                   :key (lambda (item) (getf item :status)))))
       t)
      (dolist (relative-dir '("apps"
                              "index/snapshots"
                              "images/sif"
                              "images/metadata"
                              "images/locks"
                              "images/tmp"
                              "bin"
                              "cache/repos"
                              "cache/downloads"
                              "cache/build"
                              "share/completions/bash"
                              "share/completions/zsh"
                              "share/completions/fish"
                              "share/vim/syntax"
                              "share/vim/ftdetect"
                              "logs"))
        (check-true
         (probe-file
          (han.path:directory-pathname
           (han.path:join-path user-home
                               (format nil "~A/" relative-dir)))))))))

(deftest test-taf-system-doctor-system-check-does-not-create-dirs ()
  (with-taf-system-temp-dir (system-home)
    (let* ((user-home (%taf-system-temp-dir-named "taf-user-unused"))
           (result (taf.core:system-doctor
                    :scope :system
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :scope) :system)
      (check-equal (getf result :status) :needs-init)
      (check-equal (probe-file system-home) nil))))

(defun %taf-system-doctor-diagnostic (result id)
  (find id
        (getf result :diagnostics)
        :key (lambda (item) (getf item :id))
        :test #'eql))

(defun %taf-system-doctor-missing-backend-probe (spec)
  (list :name (first spec)
        :status :missing
        :path nil
        :exit-code nil
        :detail ""))

(defmacro with-taf-system-doctor-stubs (&body body)
  `(let ((taf.core::*taffish-doctor-backend-probe-function*
           #'%taf-system-doctor-missing-backend-probe))
     ,@body))

(defun %taf-system-doctor-share-files (home)
  (dolist (relative '("share/completions/bash/taf"
                      "share/completions/bash/taffish"
                      "share/completions/zsh/_taf"
                      "share/completions/zsh/_taffish"
                      "share/completions/fish/taf.fish"
                      "share/completions/fish/taffish.fish"
                      "share/vim/syntax/taf.vim"
                      "share/vim/ftdetect/taf.vim"))
    (%taf-system-write-string (han.path:join-path home relative) "test\n")))

(defun %taf-system-chmod (mode path)
  (let ((chmod (han.os:find-executable "chmod")))
    (unless chmod
      (error "chmod is required for this test."))
    (multiple-value-bind (out err code)
        (han.os:run-program
         (list chmod mode (han.path:->namestring path))
         :output :string
         :error-output :string
         :ignore-error-status t)
      (declare (ignore out))
      (unless (and (integerp code) (= code 0))
        (error "chmod ~A failed: ~A" mode err)))))

(deftest test-taf-system-doctor-adds-unified-diagnostic-schema ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-doctor
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))
           (diagnostics (getf result :diagnostics)))
      (check-true (consp diagnostics))
      (check-true (member (getf result :diagnostic-status)
                          '(:ok :warning :error :unknown)
                          :test #'eql))
      (dolist (item diagnostics)
        (dolist (key '(:id :status :scope :summary :evidence
                       :remediation :docs-url))
          (check-true (taf.core::%plist-has-key-p item key)))
        (check-true (member (getf item :status)
                            '(:ok :warning :error :unknown :not-applicable)
                            :test #'eql)))
      ;; The legacy result contract remains available to existing callers.
      (check-true (taf.core::%plist-has-key-p result :status))
      (check-true (taf.core::%plist-has-key-p result :directories))
      (check-true (taf.core::%plist-has-key-p result :executables))
      (check-true (taf.core::%plist-has-key-p result :paths)))))

(deftest test-taf-system-doctor-covers-required-diagnostic-groups ()
  (with-taf-system-temp-dir (user-home)
    (let* ((system-home (%taf-system-temp-dir-named "taf-system-unused"))
           (result (taf.core:system-doctor
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (dolist (id '(:home :config :index :command-path :shell-completion
                    :vim-runtime :apptainer-sif-cache :container-backends))
        (check-true (%taf-system-doctor-diagnostic result id))))))

(deftest test-taf-system-doctor-default-remains-read-only ()
  (with-taf-system-temp-dir (user-home)
    (let ((system-home (%taf-system-temp-dir-named "taf-system-unused")))
      (check-equal (probe-file user-home) nil)
      (taf.core:system-doctor :scope :user
                              :user-home user-home
                              :system-home system-home
                              :verbose nil)
      (check-equal (probe-file user-home) nil)
      (check-equal (probe-file system-home) nil))))

(deftest test-taf-system-doctor-config-and-index-diagnostics ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/"))
           (index-file (han.path:join-path user-home "index/current.json")))
      (%taf-system-write-string index-file "{}\n")
      (with-taf-system-doctor-stubs
        (let ((result (taf.core:system-doctor
                       :scope :user
                       :user-home user-home
                       :system-home system-home
                       :verbose nil)))
          (check-equal
           (getf (%taf-system-doctor-diagnostic result :config) :status)
           :ok)
          (check-equal
           (getf (%taf-system-doctor-diagnostic result :index) :status)
           :ok)))
      (%taf-system-write-string
       (han.path:join-path user-home "config.toml")
       "this is not valid TOML\n")
      (with-taf-system-doctor-stubs
        (let ((result (taf.core:system-doctor
                       :scope :user
                       :user-home user-home
                       :system-home system-home
                       :verbose nil)))
          (check-equal
           (getf (%taf-system-doctor-diagnostic result :config) :status)
           :error))))))

(deftest test-taf-system-doctor-command-path-status ()
  (let ((ok (taf.core::%doctor-command-path-diagnostic
             :user
             (list (list :path "/tmp/bin/" :status :ok))
             (list (list :name "taf" :path "/tmp/bin/taf")
                   (list :name "taffish" :path "/tmp/bin/taffish"))))
        (warning (taf.core::%doctor-command-path-diagnostic
                  :user
                  (list (list :path "/tmp/bin/" :status :not-in-path))
                  (list (list :name "taf" :path nil)
                        (list :name "taffish" :path nil)))))
    (check-equal (getf ok :status) :ok)
    (check-equal (getf warning :status) :warning)
    (check-true (search "export PATH=" (getf warning :remediation)))))

(deftest test-taf-system-doctor-completion-missing-unknown-and-active ()
  (with-taf-system-temp-dir (root)
    (let* ((home (han.path:join-path root "taffish/"))
           (os-home (han.path:join-path root "os-home/"))
           (taf.core::*taffish-doctor-os-home-override* os-home))
      (check-equal
       (getf (taf.core::%doctor-completion-diagnostic :user home :bash)
             :status)
       :warning)
      (%taf-system-doctor-share-files home)
      (dolist (shell '(:bash :zsh :fish))
        (check-equal
         (getf (taf.core::%doctor-completion-diagnostic :user home shell)
               :status)
         :unknown))
      (%taf-system-write-string
       (han.path:join-path os-home ".bashrc")
       (format nil "source ~Ashare/completions/bash/taf~%source ~Ashare/completions/bash/taffish~%"
               (han.path:->namestring home)
               (han.path:->namestring home)))
      (check-equal
       (getf (taf.core::%doctor-completion-diagnostic :user home :bash)
             :status)
       :ok)
      (%taf-system-write-string
       (han.path:join-path os-home ".zshrc")
       (format nil "fpath=(~Ashare/completions/zsh $fpath)~%autoload -Uz compinit && compinit~%"
               (han.path:->namestring home)))
      (check-equal
       (getf (taf.core::%doctor-completion-diagnostic :user home :zsh)
             :status)
       :ok)
      (%taf-system-write-string
       (han.path:join-path os-home ".config/fish/completions/taf.fish")
       "test\n")
      (%taf-system-write-string
       (han.path:join-path os-home ".config/fish/completions/taffish.fish")
       "test\n")
      (check-equal
       (getf (taf.core::%doctor-completion-diagnostic :user home :fish)
             :status)
       :ok))))

(deftest test-taf-system-doctor-vim-missing-active-and-not-applicable ()
  (with-taf-system-temp-dir (root)
    (let* ((home (han.path:join-path root "taffish/"))
           (os-home (han.path:join-path root "os-home/"))
           (taf.core::*taffish-doctor-os-home-override* os-home)
           (editors (list (list :name "vim" :path "/usr/bin/vim")
                          (list :name "nvim" :path nil)))
           (no-editors (list (list :name "vim" :path nil)
                             (list :name "nvim" :path nil))))
      (check-equal
       (getf (taf.core::%doctor-vim-diagnostic :user home editors) :status)
       :warning)
      (%taf-system-doctor-share-files home)
      (%taf-system-write-string
       (han.path:join-path os-home ".vim/syntax/taf.vim") "test\n")
      (%taf-system-write-string
       (han.path:join-path os-home ".vim/ftdetect/taf.vim") "test\n")
      (check-equal
       (getf (taf.core::%doctor-vim-diagnostic :user home editors) :status)
       :ok)
      (check-equal
       (getf (taf.core::%doctor-vim-diagnostic :user home no-editors) :status)
       :not-applicable))))

(deftest test-taf-system-doctor-sif-user-and-shared-policies ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user/"))
           (system-home (han.path:join-path root "system/"))
           (user-sif (%taf-system-dir user-home "images/sif/"))
           (system-sif (%taf-system-dir system-home "images/sif/")))
      (check-equal
       (getf (taf.core::%doctor-sif-diagnostic
              :user user-home system-home)
             :status)
       :error)
      (ensure-directories-exist user-sif)
      (%taf-system-chmod "0700" user-sif)
      (check-equal
       (getf (taf.core::%doctor-sif-diagnostic
              :system user-home system-home)
             :status)
       :warning)
      (ensure-directories-exist system-sif)
      (check-equal
       (getf (taf.core::%doctor-sif-diagnostic
              :user user-home system-home)
             :status)
       :ok)
      (unwind-protect
           (progn
             (%taf-system-chmod "1777" system-sif)
             (let ((item (taf.core::%doctor-sif-diagnostic
                          :system user-home system-home)))
               (check-equal (getf item :status) :ok)
               (check-true (search "sticky" (getf item :summary))))
             (%taf-system-chmod "0777" system-sif)
             (check-equal
              (getf (taf.core::%doctor-sif-diagnostic
                     :system user-home system-home)
                    :status)
              :error)
             (%taf-system-chmod "0555" system-sif)
             (let ((item (taf.core::%doctor-sif-diagnostic
                          :system user-home system-home)))
               (check-equal (getf item :status) :ok)
               (check-true (search "read-only" (getf item :summary))))
             (%taf-system-chmod "0555" user-sif)
             (check-equal
              (getf (taf.core::%doctor-sif-diagnostic
                     :system user-home system-home)
                    :status)
              :error))
        (%taf-system-chmod "0700" user-sif)
        (%taf-system-chmod "0700" system-sif)))))

(deftest test-taf-system-doctor-container-statuses ()
  (flet ((probe-with-status (status)
           (lambda (spec)
             (list :name (first spec)
                   :status status
                   :path (unless (eql status :missing) "/tmp/backend")
                   :exit-code (case status (:ok 0) (:timeout 124) (t 1))
                   :detail "fixture"))))
    (dolist (case '((:missing :warning)
                    (:ok :ok)
                    (:timeout :unknown)
                    (:unavailable :warning)))
      (let ((taf.core::*taffish-doctor-backend-probe-function*
              (probe-with-status (first case))))
        (check-equal
         (getf (taf.core::%doctor-container-diagnostic :user) :status)
         (second case))))))

(deftest test-taf-system-doctor-bounded-probe-exit-and-timeout ()
  (let ((sh (or (han.os:find-executable "sh")
                (han.os:find-executable "bash")))
        (sleep (han.os:find-executable "sleep")))
    (check-true sh)
    (check-true sleep)
    (multiple-value-bind (out err code)
        (taf.core::%doctor-bounded-shell-command
         (list sh "-c" "exit 7") 1)
      (declare (ignore out err))
      (check-equal code 7))
    (multiple-value-bind (out err code)
        (taf.core::%doctor-bounded-shell-command (list sleep "5") 1)
      (declare (ignore out err))
      (check-equal code 124))))

(deftest test-taf-system-doctor-text-verbose-and-json-rendering ()
  (with-taf-system-temp-dir (root)
    (let ((user-home (han.path:join-path root "user/"))
          (system-home (han.path:join-path root "system/")))
      (with-taf-system-doctor-stubs
        (let ((summary
                (with-output-to-string (out nil :element-type 'character)
                  (let ((*standard-output* out))
                    (taf.core:system-doctor
                     :scope :user
                     :user-home user-home
                     :system-home system-home))))
              (detail
                (with-output-to-string (out nil :element-type 'character)
                  (let ((*standard-output* out))
                    (taf.core:system-doctor
                     :scope :user
                     :user-home user-home
                     :system-home system-home
                     :detail-p t))))
              (json
                (with-output-to-string (out nil :element-type 'character)
                  (let ((*standard-output* out))
                    (taf.core:system-doctor
                     :scope :user
                     :user-home user-home
                     :system-home system-home
                     :json-p t)))))
          (check-false (search "evidence:" summary))
          (check-true (search "evidence:" detail))
          (let ((parsed (han.json:parse-json json)))
            (check-equal (han.json:get-json parsed "schema_version")
                         "taffish.doctor/v1")
            (check-true
             (vectorp (han.json:get-json parsed "diagnostics")))
            (let* ((diagnostics (han.json:get-json parsed "diagnostics"))
                   (first-item (aref diagnostics 0))
                   (config
                     (loop for item across diagnostics
                           when (string= (han.json:get-json item "id") "config")
                             return item))
                   (evidence (han.json:get-json config "evidence")))
              (check-true
               (stringp (han.json:get-json first-item "summary")))
              (check-true
               (stringp (han.json:get-json first-item "docs_url")))
              (check-true config)
              (check-true
               (vectorp (han.json:get-json evidence "loaded_files")))
              (check-true
               (stringp (han.json:get-json evidence "index_url"))))))))))

(deftest test-taf-system-config-human-output-is-localized ()
  (with-taf-system-temp-dir (root)
    (let ((user-home (han.path:join-path root "user/"))
          (system-home (han.path:join-path root "system/")))
      (let ((english
              (taffish.i18n:with-language ("en")
                (with-output-to-string (out nil :element-type 'character)
                  (let ((*standard-output* out))
                    (taf.core:system-config
                     :user-home user-home :system-home system-home)))))
            (chinese
              (taffish.i18n:with-language ("zh")
                (with-output-to-string (out nil :element-type 'character)
                  (let ((*standard-output* out))
                    (taf.core:system-config
                     :user-home user-home :system-home system-home))))))
        (check-true (search "Effective config:" english :test #'char=))
        (check-true (search "生效配置：" chinese :test #'char=))
        (check-true (search "display language" english :test #'char=))
        (check-true (search "显示语言" chinese :test #'char=))
        (check-true (search "<default>" english :test #'char=))
        (check-true (search "<unset>" english :test #'char=))
        (check-true (search "<默认>" chinese :test #'char=))
        (check-true (search "<未设置>" chinese :test #'char=))
        (check-true (search "TAFFISH_CONFIG" english :test #'char=))
        (check-true (search "TAFFISH_CONFIG" chinese :test #'char=))))))

(deftest test-taf-system-doctor-human-output-localized-json-invariant ()
  (with-taf-system-temp-dir (root)
    (let ((user-home (han.path:join-path root "user/"))
          (system-home (han.path:join-path root "system/")))
      (with-taf-system-doctor-stubs
        (flet ((doctor-result ()
                 (taf.core:system-doctor
                  :scope :user
                  :user-home user-home
                  :system-home system-home
                  :verbose nil))
               (doctor-text ()
                 (with-output-to-string (out nil :element-type 'character)
                   (let ((*standard-output* out))
                     (taf.core:system-doctor
                      :scope :user
                      :user-home user-home
                      :system-home system-home
                      :detail-p t)))))
          (let ((english-result
                  (taffish.i18n:with-language ("en") (doctor-result)))
                (chinese-result
                  (taffish.i18n:with-language ("zh") (doctor-result)))
                (english-text
                  (taffish.i18n:with-language ("en") (doctor-text)))
                (chinese-text
                  (taffish.i18n:with-language ("zh") (doctor-text))))
            (check-equal
             (han.json:encode-json
              (taf.core::%doctor-result-json chinese-result))
             (han.json:encode-json
              (taf.core::%doctor-result-json english-result)))
            (check-true (search "Diagnostics:" english-text :test #'char=))
            (check-true (search "诊断：" chinese-text :test #'char=))
            (check-true (search "修复建议" chinese-text :test #'char=))
            (check-true
             (search "TAFFISH home is not fully initialized."
                     (getf (first (getf chinese-result :diagnostics)) :summary)
                     :test #'char=))))))))

(deftest test-taf-system-doctor-init-does-not-edit-user-config-files ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "taffish/"))
           (system-home (han.path:join-path root "system/"))
           (os-home (han.path:join-path root "os-home/"))
           (bashrc (han.path:join-path os-home ".bashrc"))
           (vimrc (han.path:join-path os-home ".vimrc"))
           (taf.core::*taffish-doctor-os-home-override* os-home))
      (%taf-system-write-string bashrc "# unchanged bashrc\n")
      (%taf-system-write-string vimrc "\" unchanged vimrc\n")
      (with-taf-system-doctor-stubs
        (taf.core:system-doctor :scope :user
                                :init-p t
                                :user-home user-home
                                :system-home system-home
                                :verbose nil))
      (check-equal (han.os:load-string bashrc) "# unchanged bashrc\n")
      (check-equal (han.os:load-string vimrc) "\" unchanged vimrc\n"))))

(deftest test-taf-system-history-path-no-side-effect ()
  (with-taf-system-temp-dir (user-home)
    (let ((result (taf.core:system-history
                   :path-p t
                   :user-home user-home
                   :verbose nil)))
      (check-equal
       (not (null
             (search "/logs/history.jsonl"
                     (getf result :file)
                     :test #'char=)))
       t)
      (check-equal (probe-file user-home) nil))))

(deftest test-taf-system-history-empty ()
  (with-taf-system-temp-dir (user-home)
    (let ((result (taf.core:system-history
                   :user-home user-home
                   :verbose nil)))
      (check-equal (getf result :count) 0)
      (check-equal (getf result :total) 0)
      (check-equal (getf result :lines) nil))))

(deftest test-taf-system-history-record-query-and-clear ()
  (with-taf-system-temp-dir (user-home)
    (let* ((project (list :name "demo"
                          :kind "flow"
                          :version "0.1.0"
                          :release "1"
                          :command-name "taf-demo"
                          :root-dir "/private/tmp/demo/"
                          :main-path "src/main.taf"
                          :repository-url "https://github.com/taffish/demo"
                          :container-image "ghcr.io/taffish/demo:0.1.0-r1"))
           (run-record
             (taf.core:system-record-history-event
              :event "run"
              :status "success"
              :project project
              :command "taf-demo"
              :args '("a" "b")
              :cwd "/private/tmp/demo/"
              :backend "docker"
              :exit-code 0
              :taf-version "taf test"
              :user-home user-home
              :safe nil))
           (run-id (getf (getf run-record :event) :id))
           (file (getf run-record :file)))
      (taf.core:system-record-history-event
       :event "build"
       :status "success"
       :project project
       :cwd "/private/tmp/demo/"
       :extra (list :build-command t)
       :user-home user-home
       :safe nil)
      (let ((last-result (taf.core:system-history
                          :last 1
                          :user-home user-home
                          :verbose nil)))
        (check-equal (getf last-result :count) 1)
        (check-equal
         (not (null
               (search "\"event\":\"build\""
                       (car (getf last-result :lines))
                       :test #'char=)))
         t)
        (check-equal
         (not (null
               (search "\"build_command\":true"
                       (car (getf last-result :lines))
                       :test #'char=)))
         t))
      (let ((id-result (taf.core:system-history
                        :id run-id
                        :user-home user-home
                        :verbose nil)))
        (check-equal (getf id-result :count) 1)
        (check-equal
         (not (null
               (search "\"event\":\"run\""
                       (car (getf id-result :lines))
                       :test #'char=)))
         t)
        (check-equal
         (not (null
               (search "\"project_name\":\"demo\""
                       (car (getf id-result :lines))
                       :test #'char=)))
         t))
      (let ((clear-result (taf.core:system-history
                           :clear-p t
                           :user-home user-home
                           :verbose nil)))
        (check-equal (getf clear-result :cleared-p) t)
        (check-equal (probe-file file) nil)))))

(deftest test-taf-system-history-human-output-localized-json-invariant ()
  (with-taf-system-temp-dir (user-home)
    (taf.core:system-record-history-event
     :event "run"
     :status "success"
     :command "taf-i18n-demo"
     :args '("--sample" "A")
     :exit-code 0
     :user-home user-home
     :safe nil)
    (flet ((render (language json-p)
             (taffish.i18n:with-language (language)
               (with-output-to-string
                   (*standard-output* nil :element-type 'character)
                 (taf.core:system-history
                  :last 1
                  :json-p json-p
                  :user-home user-home)))))
      (let ((english (render "en" nil))
            (chinese (render "zh" nil))
            (english-json (render "en" t))
            (chinese-json (render "zh" t)))
        (check-true (search "[TAF] history" english :test #'char=))
        (check-true (search "[TAF] 执行历史" chinese :test #'char=))
        (check-true (search "taf-i18n-demo" english-json :test #'char=))
        (check-equal chinese-json english-json)))))

(deftest test-taf-system-history-id-survives-repeated-image-state ()
  (let* ((timestamp "2026-08-30T12:34:56Z")
         (seed (make-random-state t))
         (first (let ((*random-state* (make-random-state seed)))
                  (taf.core::%history-id timestamp)))
         (second (let ((*random-state* (make-random-state seed)))
                   (taf.core::%history-id timestamp))))
    (check-false (string= first second))))

(deftest test-taf-system-history-record-preserves-unicode ()
  (with-taf-system-temp-dir (user-home)
    (let* ((record
             (taf.core:system-record-history-event
              :event "build"
              :status "success"
              :project (list :name "unicode-flow"
                             :kind "flow"
                             :version "0.1.0"
                             :release "1"
                             :command-name "taf-unicode-flow"
                             :root-dir "/tmp/项目目录/"
                             :main-path "src/主程序.taf")
              :user-home user-home
              :safe nil))
           (object (han.json:parse-json (getf record :line))))
      (check-equal "/tmp/项目目录/"
                   (han.json:get-json object "project_root"))
      (check-equal "src/主程序.taf"
                   (han.json:get-json object "project_main")))))

(deftest test-taf-system-config-error-localized-and-doctor-evidence-invariant ()
  (with-taf-system-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user"))
           (system-home (han.path:join-path root "system"))
           (config-file (han.path:join-path user-home "config.toml")))
      (%taf-system-write-string
       config-file
       (format nil "schema_version = \"\"~%"))
      (flet ((config-error (language)
               (taffish.i18n:with-language (language)
                 (%taf-system-error-string
                  (lambda ()
                    (taf.core:system-config
                     :scope :user
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))))
             (doctor-json (language)
               (taffish.i18n:with-language (language)
                 (han.json:encode-json
                  (taf.core::%doctor-result-json
                   (taf.core:system-doctor
                    :scope :user
                    :user-home user-home
                    :system-home system-home
                    :verbose nil))))))
        (let ((english (config-error "en"))
              (chinese (config-error "zh")))
          (check-true (search "must be a non-empty string" english
                              :test #'char=))
          (check-true (search "必须是非空字符串" chinese :test #'char=))
          (check-true (search "schema_version" english :test #'char=))
          (check-true (search "schema_version" chinese :test #'char=)))
        (check-equal (doctor-json "zh") (doctor-json "en"))))))

(deftest test-taf-system-normalize-scope-error ()
  (check-equal
   (%taf-system-signal-error-p
    (lambda ()
      (taf.core::%normalize-taffish-scope :bad)))
   t))

(deftest test-taf-system-doctor-index-validation ()
  (with-taf-system-temp-dir (home)
    (flet ((inspect-index ()
             (taf.core:system-doctor :check :index :user-home home :system-home home :verbose nil)))
      (check-equal :warning (getf (inspect-index) :diagnostic-status))
      (check-equal 0 (getf (inspect-index) :exit-code))
      (dolist (case '(("{" :error)
                      ("{\"schema_version\":\"future/v2\"}" :unknown)
                      ("{\"schema_version\":\"taffish.index/v1\",\"packages\":[]}" :error)
                      ("{\"schema_version\":\"taffish.index/v1\",\"packages\":{}}" :ok)
                      ("{\"schema_version\":\"taffish.index/v1\",\"packages\":{\"x\":{\"latest\":\"1-r1\",\"versions\":{}}}}" :error)))
        (%taf-system-write-string (han.path:join-path home "index/current.json") (first case))
        (check-equal (second case) (getf (inspect-index) :diagnostic-status))))))

(deftest test-taf-system-doctor-hub-legacy-corrupt-and-targets ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (manifest (%taf-hub-diagnostic-manifest entry))
             (bad (han.path:join-path home "apps/broken/1-r1/install.json")))
        (delete-file manifest)
        (%taf-system-write-string bad "{")
        (delete-file (taf.core::%hub-index-file home))
        (let ((result (taf.core:system-doctor :check :hub :user-home home :system-home home :verbose nil)))
          (check-equal 1 (getf result :exit-code))
          (check-equal 3 (length (getf result :diagnostics))))
        (let ((result (taf.core:system-doctor :check :hub :targets '("order-demo")
                                             :user-home home :system-home home :verbose nil)))
          (check-equal 0 (getf result :exit-code))
          (check-equal :warning (getf result :diagnostic-status))
          (check-equal 2 (length (getf result :diagnostics))))
        (let ((result (taf.core:system-doctor :check :hub :targets '("absent")
                                             :user-home home :system-home home :verbose nil)))
          (check-equal 1 (getf result :exit-code)))
        (check-equal nil (han.path:file-exists-p manifest))))))

(deftest test-taf-system-doctor-specialized-read-only-and-i18n ()
  (with-taf-system-temp-dir (root)
    (let* ((home (han.path:join-path root "absent/"))
           (taf.core::*taffish-doctor-backend-probe-function*
             (lambda (&rest args) (declare (ignore args)) (error "must not probe backend"))))
      (flet ((result () (taf.core:system-doctor :check :hub :user-home home :system-home home :verbose nil)))
        (check-equal (han.json:encode-json (taf.core::%doctor-result-json (taffish.i18n:with-language ("en") (result))))
                     (han.json:encode-json (taf.core::%doctor-result-json (taffish.i18n:with-language ("zh") (result)))))
        (check-equal nil (han.path:directory-exists-p home)))
      (dolist (language '("en" "zh"))
        (let ((text (with-output-to-string (*standard-output*)
                      (taffish.i18n:with-language (language)
                        (taf.core:system-doctor :check :index :user-home home :system-home home)))))
          (check-true (search "taf update --user" text))
          (check-true (search "index-missing" text))))
      (dolist (options '((:check :hub :init-p t) (:check :index :targets ("x"))
                         (:check :hub :shell :bash) (:check :other)))
        (check-true (%taf-system-signal-error-p
                     (lambda () (apply #'taf.core:system-doctor :user-home home :verbose nil options))))))))

(deftest test-taf-system-progress-phases-and-closed-stream ()
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let* ((*error-output* (make-string-output-stream))
             (callback (taf.core::%hub-make-diagnostic-progress t (lambda () 0))))
        (funcall callback 0 0 :enumerate)
        (funcall callback 0 2 :validate)
        (funcall callback 2 2 :aliases)
        (funcall callback 2 2 :done)
        (let ((text (get-output-stream-string *error-output*)))
          (check-equal 4 (count #\Newline text))
          (check-false (find #\Return text))
          (check-false (find (code-char 27) text)))
        (close *error-output*)
        (check-equal nil (funcall callback 0 2 :enumerate))
        (check-equal nil (funcall callback 2 2 :done))))))

(deftest test-taf-system-doctor-path-fields-align-both-languages ()
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let* ((text (with-output-to-string (*standard-output*)
                     (taf.core::%doctor-print-paths :user #p"/tmp/user/" #p"/tmp/system/")))
             (lines (with-input-from-string (in text)
                      (loop for line = (read-line in nil nil) while line collect line)))
             (columns (mapcar (lambda (line)
                                (taf.core::%display-width (subseq line 0 (position #\: line))))
                              (rest lines))))
        (check-equal 3 (length columns))
        (check-true (apply #'= columns))))))
