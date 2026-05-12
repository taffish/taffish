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
                            :if-does-not-exist :create)
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
       t))))

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

(deftest test-taf-system-normalize-scope-error ()
  (check-equal
   (%taf-system-signal-error-p
    (lambda ()
      (taf.core::%normalize-taffish-scope :bad)))
   t))
