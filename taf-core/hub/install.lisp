(in-package :taf.core)

;;;; ============================================================
;;;; hub / install.lisp
;;;; ============================================================

(defparameter *hub-install-stack* nil)

(defun %hub-install-safe-path-part (value label)
  (unless (%hub-non-empty-string-p value)
    (error "[install] ~A must be a non-empty string." label))
  (when (or (find #\/ value)
            (find #\\ value)
            (string= value ".")
            (string= value ".."))
    (error "[install] ~A must not contain path separators: ~S" label value))
  value)

(defun %hub-install-command-name (record)
  (let ((command (%hub-json-ref record "command")))
    (unless (han.json:json-object-p command)
      (error "[install] version record is missing command object."))
    (let ((name (%hub-json-string command "name")))
      (unless (%hub-non-empty-string-p name)
        (error "[install] version record is missing command.name."))
      name)))

(defun %hub-install-record-version-id (record fallback)
  (or (%hub-json-string record "version_id")
      fallback
      (let ((version (%hub-json-string record "version"))
            (release (%hub-json-integer-string record "release")))
        (when (and version release)
          (format nil "~A-r~A" version release)))))

(defun %hub-install-tag (record version-id)
  (or (%hub-json-string record "tag")
      (format nil "v~A" version-id)))

(defun %hub-install-artifact-name (record version-id)
  (declare (ignore version-id))
  (let ((command-name (%hub-install-command-name record))
        (version (%hub-json-string record "version"))
        (release (%hub-json-integer-string record "release")))
    (unless (and version release)
      (error "[install] version record must contain version and release."))
    (format nil "~A-v~A-r~A" command-name version release)))

(defun %hub-install-source-object (record)
  (let ((source (%hub-json-ref record "source")))
    (and (han.json:json-object-p source) source)))

(defun %hub-install-source-url (record)
  (let ((source (%hub-install-source-object record)))
    (or (and source (%hub-json-string source "local_path"))
        (and source (%hub-json-string source "clone_url"))
        (and source (%hub-json-string source "repository_url"))
        (%hub-json-string record "repository_url"))))

(defun %hub-install-source-ref (record version-id)
  (let ((source (%hub-install-source-object record)))
    (or (and source (%hub-json-string source "ref"))
        (%hub-install-tag record version-id))))

(defun %hub-install-source-commit (record)
  (let ((source (%hub-install-source-object record)))
    (and source (%hub-json-string source "commit"))))

(defun %hub-install-origin-kind-string (origin-kind)
  (cond
    ((keywordp origin-kind)
     (string-downcase (string origin-kind)))
    ((stringp origin-kind)
     origin-kind)
    ((null origin-kind)
     nil)
    (t
     (string-downcase (princ-to-string origin-kind)))))

(defun %hub-install-origin-display (origin-kind origin)
  (let ((kind (%hub-install-origin-kind-string origin-kind)))
    (cond
      ((and (%hub-non-empty-string-p kind)
            (%hub-non-empty-string-p origin))
       (format nil "[~A] ~A" kind origin))
      ((%hub-non-empty-string-p kind)
       (format nil "[~A]" kind))
      ((%hub-non-empty-string-p origin)
       origin)
      (t nil))))

(defun %hub-install-file-url-path (source)
  (and source (%hub-file-url-path source)))

(defun %hub-install-git-source-p (source)
  (and (%hub-non-empty-string-p source)
       (or (%hub-http-url-p source)
           (%hub-string-prefix-p "git@" source)
           (%hub-string-prefix-p "ssh://" source))))

(defun %hub-install-local-source-dir (source)
  (let ((path (or (%hub-install-file-url-path source) source)))
    (when (and (%hub-non-empty-string-p path)
               (not (%hub-install-git-source-p path)))
      (han.path:directory-exists-p (han.path:directory-pathname path)))))

(defun %hub-install-run-program
    (program args &key (noninteractive t) (prompt nil) (verbose nil))
  (han.os:run-program
   (if noninteractive
       (cons (%publish-env-program)
             (append (%publish-noninteractive-env-args)
                     (cons (%publish-program-argument program) args)))
       (cons program args))
   :input (and prompt t)
   :output (if verbose t :string)
   :error-output (if verbose t :string)
   :ignore-error-status t))

(defun %hub-install-run-git-clone
    (source ref target-dir &key prompt-p (verbose t))
  (let ((args (append (list "clone" "--depth" "1")
                      (when (%hub-non-empty-string-p ref)
                        (list "--branch" ref "--single-branch"))
                      (list source (han.path:->namestring target-dir)))))
    (when verbose
      (format t "[TAF] cloning source: ~A (~A)~%"
              source
              (or ref "default"))
      (finish-output))
    (multiple-value-bind (out err code)
        (%hub-install-run-program
         (%publish-git-program)
         args
         :noninteractive (not prompt-p)
         :prompt prompt-p
         :verbose verbose)
      (unless (and (integerp code) (= code 0))
        (error "[install] git clone failed (~A): git ~{~A~^ ~}~%~A~A~@[~%~A~]"
               code args out err
               (and (not prompt-p)
                    (%publish-noninteractive-auth-hint))))
      (values out err code))))

(defun %hub-install-copy-local-source (source target-dir &key (verbose t))
  (let ((local-dir (%hub-install-local-source-dir source)))
    (unless local-dir
      (error "[install] local source directory does not exist: ~A" source))
    (when verbose
      (format t "[TAF] copying local source: ~A~%"
              (han.path:->namestring local-dir)))
    (%copy-directory-tree/supersede local-dir target-dir)))

(defun %hub-install-copy-or-clone-source
    (source ref target-dir &key prompt-p (verbose t))
  (cond
    ((%hub-install-local-source-dir source)
     (%hub-install-copy-local-source source target-dir :verbose verbose))
    ((%hub-install-git-source-p source)
     (%hub-install-run-git-clone source ref target-dir
                                 :prompt-p prompt-p
                                 :verbose verbose))
    (t
     (error "[install] source must be a Git URL or local directory, but got: ~A"
            source))))

(defun %hub-install-trim-output (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return)
               (or string "")))

(defun %hub-install-git-head-commit (source-dir)
  (multiple-value-bind (out err code)
      (%hub-install-run-program
       (%publish-git-program)
       (list "-C"
             (han.path:->namestring
              (han.path:directory-pathname source-dir))
             "rev-parse"
             "HEAD")
       :noninteractive t
       :prompt nil
       :verbose nil)
    (unless (and (integerp code) (= code 0))
      (error "[install] failed to inspect installed source commit in ~A.~%~A~A"
             (han.path:->namestring source-dir)
             out
             err))
    (%hub-install-trim-output out)))

(defun %hub-install-git-status (source-dir)
  (multiple-value-bind (out err code)
      (%hub-install-run-program
       (%publish-git-program)
       (list "-C"
             (han.path:->namestring
              (han.path:directory-pathname source-dir))
             "status"
             "--porcelain"
             "--untracked-files=all")
       :noninteractive t
       :prompt nil
       :verbose nil)
    (unless (and (integerp code) (= code 0))
      (error "[install] failed to inspect installed source status in ~A.~%~A~A"
             (han.path:->namestring source-dir)
             out
             err))
    (%hub-install-trim-output out)))

(defun %hub-install-verify-source-commit
    (source-dir expected-commit &key source-url source-ref)
  (when (%hub-non-empty-string-p expected-commit)
    (let ((actual-commit (%hub-install-git-head-commit source-dir))
          (source-status (%hub-install-git-status source-dir)))
      (unless (string-equal actual-commit expected-commit)
        (error "[install] source commit mismatch.~%  source  : ~A~%  ref     : ~A~%  expected: ~A~%  got     : ~A"
               (or source-url "<unknown>")
               (or source-ref "<unknown>")
               expected-commit
               actual-commit))
      (unless (string= source-status "")
        (error "[install] source commit matches, but source worktree is not clean.~%  source: ~A~%  ref   : ~A~%  status:~%~A"
               (or source-url "<unknown>")
               (or source-ref "<unknown>")
               source-status))
      actual-commit)))

(defun %hub-install-source-verification-dir (source target-dir)
  (or (%hub-install-local-source-dir source)
      (han.path:directory-pathname target-dir)))

(defun %hub-install-metadata-json (result record)
  (let* ((origin-kind (getf result :origin-kind))
         (origin (getf result :origin))
         (origin-display (%hub-install-origin-display origin-kind origin)))
    (han.json:json-object
     (cons "schema_version" "taffish.install/v1")
     (cons "installed_at" (%hub-timestamp))
     (cons "scope" (string-downcase (string (getf result :scope))))
     (cons "name" (getf result :package-name))
     (cons "version_id" (getf result :version-id))
     (cons "artifact_name" (getf result :artifact-name))
     (cons "command_name" (or (getf result :command-name) :null))
     (cons "command_file" (getf result :command-file))
     (cons "launcher_file" (getf result :launcher-file))
     (cons "command_launcher_file"
           (or (getf result :command-launcher-file) :null))
     (cons "bin_dir" (getf result :bin-dir))
     (cons "install_root" (getf result :install-root))
     (cons "source_dir" (getf result :source-dir))
     (cons "repository_url" (or (%hub-json-string record "repository_url")
                                :null))
     (cons "source_url" (or (getf result :source-url) :null))
     (cons "resolved_source_url"
           (or (getf result :resolved-source-url) :null))
     (cons "source_ref" (or (getf result :source-ref) :null))
     (cons "source_commit" (or (getf result :source-commit) :null))
     (cons "source_commit_actual"
           (or (getf result :actual-source-commit) :null))
     (cons "source_commit_verified"
           (if (getf result :source-commit-verified-p) t nil))
     (cons "origin_kind"
           (or (%hub-install-origin-kind-string origin-kind) :null))
     (cons "origin" (or origin :null))
     (cons "origin_display" (or origin-display :null)))))

(defun %hub-install-write-json-file (path object)
  (ensure-directories-exist path)
  (han.json:write-json-file path object :indent 2))

(defun %hub-install-launcher-string
    (command-file &key launcher-name artifact-name)
  (format nil "#!/bin/sh
TAF_LAUNCHER_NAME=~A
TAF_LAUNCHER_ARTIFACT=~A
export TAF_LAUNCHER_NAME TAF_LAUNCHER_ARTIFACT
exec ~A \"$@\"
"
          (%build-shell-token (or launcher-name artifact-name))
          (%build-shell-token (or artifact-name launcher-name))
          (%build-shell-token command-file)))

(defun %hub-install-write-launcher
    (launcher-file command-file &key launcher-name artifact-name)
  (ensure-directories-exist launcher-file)
  (with-open-file (out launcher-file
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (write-string (%hub-install-launcher-string
                   command-file
                   :launcher-name launcher-name
                   :artifact-name artifact-name)
                  out))
  (%chmod-executable launcher-file))

(defun %hub-install-delete-file-if-exists (path)
  (when (han.path:file-exists-p path)
    (delete-file path)))

(defun %hub-install-delete-dir-if-exists (path)
  (when (han.path:directory-exists-p (han.path:directory-pathname path))
    (han.path:delete-directory-tree (han.path:directory-pathname path)
                                :validate t
                                :if-does-not-exist :ignore)))

(defun %hub-install-metadata-files (home)
  (let ((apps-dir (%taffish-home-dir home "apps")))
    (when (han.path:directory-exists-p apps-dir)
      (loop for package-dir in (han.path:subdirectories apps-dir)
            append
            (loop for version-dir in (han.path:subdirectories package-dir)
                  for metadata-file = (han.path:join-path version-dir
                                                          "install.json")
                  when (han.path:file-exists-p metadata-file)
                    collect metadata-file)))))

(defun %hub-install-read-entry (metadata-file)
  (handler-case
      (let* ((metadata (han.json:read-json-file metadata-file))
             (package-name (%hub-json-string metadata "name"))
             (version-id (%hub-json-string metadata "version_id"))
             (artifact-name (%hub-json-string metadata "artifact_name"))
             (command-name (%hub-json-string metadata "command_name"))
             (command-file (%hub-json-string metadata "command_file"))
             (bin-dir (%hub-json-string metadata "bin_dir"))
             (command-launcher-file
               (%hub-json-string metadata "command_launcher_file")))
        (when (and (han.json:json-object-p metadata)
                   (%hub-non-empty-string-p package-name)
                   (%hub-non-empty-string-p version-id)
                   (%hub-non-empty-string-p artifact-name)
                   (%hub-non-empty-string-p command-name)
                   (%hub-non-empty-string-p command-file)
                   (%hub-non-empty-string-p bin-dir))
          (list :metadata metadata
                :metadata-file (han.path:->namestring metadata-file)
                :package-name package-name
                :version-id version-id
                :artifact-name artifact-name
                :command-name command-name
                :command-file command-file
                :bin-dir bin-dir
                :command-launcher-file command-launcher-file)))
    (error ()
      nil)))

(defun %hub-install-normalize-dir-string (dir)
  (han.path:->namestring (han.path:directory-pathname dir)))

(defun %hub-install-command-entries (home command-name command-bin-dir)
  (let ((bin-dir (%hub-install-normalize-dir-string command-bin-dir)))
    (remove-if-not
     (lambda (entry)
       (and (string= command-name (getf entry :command-name))
            (string= bin-dir
                     (%hub-install-normalize-dir-string
                      (getf entry :bin-dir)))
            (han.path:file-exists-p (getf entry :command-file))))
     (loop for metadata-file in (%hub-install-metadata-files home)
           for entry = (%hub-install-read-entry metadata-file)
           when entry
             collect entry))))

(defun %hub-install-latest-command-entry (entries)
  (first
   (sort (copy-list entries)
         #'%hub-version-id-newer-p
         :key (lambda (entry) (getf entry :version-id)))))

(defun %hub-install-refresh-command-alias (home command-name command-bin-dir)
  (when (%hub-non-empty-string-p command-name)
    (let* ((bin-dir (han.path:directory-pathname command-bin-dir))
           (alias-file (han.path:join-path bin-dir command-name))
           (latest (%hub-install-latest-command-entry
                    (%hub-install-command-entries home
                                                  command-name
                                                  bin-dir))))
      (cond
        (latest
         (%hub-install-write-launcher
          alias-file
          (getf latest :command-file)
          :launcher-name command-name
          :artifact-name (getf latest :artifact-name))
         (list :alias-file (han.path:->namestring alias-file)
               :alias-version-id (getf latest :version-id)
               :alias-artifact-name (getf latest :artifact-name)))
        (t
         (%hub-install-delete-file-if-exists alias-file)
         (list :alias-file (han.path:->namestring alias-file)
               :alias-version-id nil
               :alias-artifact-name nil))))))

(defun %hub-install-ensure-free-paths
    (install-root launcher-file force-p dry-run-p)
  (let ((install-exists-p
          (han.path:directory-exists-p (han.path:directory-pathname install-root)))
        (launcher-exists-p
          (han.path:file-exists-p launcher-file)))
    (cond
      ((and force-p install-exists-p (not dry-run-p))
       (%hub-install-delete-dir-if-exists install-root))
      (install-exists-p
       (unless force-p
         (error "[install] app version is already installed: ~A~%Use --force to reinstall."
                (han.path:->namestring install-root)))))
    (cond
      ((and force-p launcher-exists-p (not dry-run-p))
       (%hub-install-delete-file-if-exists launcher-file))
      (launcher-exists-p
       (unless force-p
         (error "[install] command already exists: ~A~%Use --force to replace it."
                (han.path:->namestring launcher-file)))))))

(defun %hub-install-print-result (result)
  (format t "[TAF] ~A: ~A ~A~%"
          (if (getf result :dry-run-p) "install dry-run" "installed")
          (getf result :package-name)
          (getf result :version-id))
  (%print-hub-info-field "scope"
                         (string-downcase (string (getf result :scope))))
  (%print-hub-info-field "source" (getf result :source-url))
  (%print-hub-info-field
   "origin"
   (%hub-install-origin-display (getf result :origin-kind)
                                (getf result :origin)))
  (when (and (getf result :resolved-source-url)
             (not (string= (getf result :source-url)
                           (getf result :resolved-source-url))))
    (%print-hub-info-field "resolved source"
                           (getf result :resolved-source-url)))
  (%print-hub-info-field "ref" (getf result :source-ref))
  (%print-hub-info-field "app" (getf result :install-root))
  (%print-hub-info-field "command" (getf result :launcher-file))
  (when (and (getf result :command-launcher-file)
             (not (string= (getf result :command-name)
                           (getf result :artifact-name))))
    (%print-hub-info-field "alias" (getf result :command-launcher-file)))
  (when (getf result :dependency-results)
    (%print-hub-info-field "deps"
                           (length (getf result :dependency-results))))
  (%print-hub-info-field "bin" (getf result :bin-dir))
  (%print-hub-info-field "path"
                         (if (getf result :bin-in-path-p)
                             "ok"
                             "not in PATH"))
  (unless (getf result :bin-in-path-p)
    (%print-hub-info-field
     "hint"
     (%taffish-bin-path-export-command (getf result :bin-dir))))
  (when (getf result :dry-run-p)
    (%print-hub-info-field "action" "rerun without --dry-run to install"))
  nil)

(defun %hub-install-paths
    (home package-name version-id artifact-name &key bin-dir command-name)
  (let* ((install-root
           (%taffish-home-dir
            home
            (format nil "apps/~A/~A/" package-name version-id)))
         (source-dir (han.path:join-path install-root "source"))
         (command-bin-dir
           (han.path:directory-pathname
            (or bin-dir (%taffish-home-dir home "bin"))))
         (launcher-file (han.path:join-path command-bin-dir artifact-name))
         (command-launcher-file
           (and command-name
                (han.path:join-path command-bin-dir command-name)))
         (metadata-file (han.path:join-path install-root "install.json")))
    (list :install-root (han.path:->namestring install-root)
          :source-dir (han.path:->namestring source-dir)
          :bin-dir (han.path:->namestring command-bin-dir)
          :launcher-file (han.path:->namestring launcher-file)
          :command-launcher-file
          (and command-launcher-file
               (han.path:->namestring command-launcher-file))
          :metadata-file (han.path:->namestring metadata-file))))

(defun %hub-install-dependency-version-id (value)
  (cond
    ((or (null value) (eq value :null)) nil)
    ((and (stringp value)
          (or (string= value "")
              (string-equal value "latest")
              (string= value "*")))
     nil)
    ((stringp value)
     (%hub-normalize-version-id value))
    (t
     (error "[install] dependency version must be a string, but got: ~S"
            value))))

(defun %hub-install-dependency-version-ids (value)
  (cond
    ((han.json:json-array-p value)
     (let ((items nil))
       (loop for item across value
             do (push (%hub-install-dependency-version-id item) items))
       (when (null items)
         (error "[install] dependency version array must not be empty."))
       (nreverse items)))
    (t
     (list (%hub-install-dependency-version-id value)))))

(defun %hub-install-record-dependencies (record)
  (let ((dependencies (%hub-json-ref record "dependencies")))
    (cond
      ((or (null dependencies) (eq dependencies :null))
       nil)
      ((han.json:json-object-p dependencies)
       (mapcan
        (lambda (query)
          (mapcar (lambda (version-id)
                    (list :query query
                          :version-id version-id))
                  (%hub-install-dependency-version-ids
                   (han.json:get-json dependencies query))))
        (han.json:json-keys dependencies)))
      (t
       (error "[install] version record dependencies must be an object.")))))

(defun %hub-install-key (package-name version-id)
  (format nil "~A@~A" package-name version-id))

(defun %hub-install-installed-p
    (home package-name version-id artifact-name command-bin-dir
     &key command-name)
  (let* ((paths (%hub-install-paths home
                                    package-name
                                    version-id
                                    artifact-name
                                    :bin-dir command-bin-dir
                                    :command-name command-name))
         (metadata-file (getf paths :metadata-file))
         (launcher-file (getf paths :launcher-file))
         (command-launcher-file (getf paths :command-launcher-file)))
    (when (and (han.path:file-exists-p metadata-file)
               (han.path:file-exists-p launcher-file))
      (when (and command-name
                 command-launcher-file
                 (not (string= command-name artifact-name)))
        (%hub-install-refresh-command-alias home
                                           command-name
                                           command-bin-dir))
      t)))

(defun %hub-install-dependency
    (dependency index scope home user-home system-home system-bin-dir
     force-p dry-run-p prompt-p verbose)
  (let* ((query (getf dependency :query))
         (version-id (getf dependency :version-id))
         (resolved (%hub-resolve-info-target index query version-id "install"))
         (record (getf resolved :record))
         (package-name (%hub-install-safe-path-part
                        (getf resolved :package-name)
                        "dependency package name"))
         (resolved-version-id
           (%hub-install-safe-path-part
            (%hub-install-record-version-id record (getf resolved :version-id))
            "dependency version id"))
         (artifact-name
           (%hub-install-safe-path-part
            (%hub-install-artifact-name record resolved-version-id)
            "dependency artifact name"))
         (command-bin-dir
           (%taffish-command-bin-dir scope home system-bin-dir)))
    (cond
      ((%hub-install-installed-p home
                                package-name
                                resolved-version-id
                                artifact-name
                                command-bin-dir
                                :command-name
                                (%hub-install-command-name record))
       (list :query query
             :version-id resolved-version-id
             :package-name package-name
             :artifact-name artifact-name
             :installed-p t
             :skipped-p t))
      (dry-run-p
       (list :query query
             :version-id resolved-version-id
             :package-name package-name
             :artifact-name artifact-name
             :installed-p nil
             :dry-run-p t))
      (t
       (hub-install :query query
                    :version-id resolved-version-id
                    :scope scope
                    :user-home user-home
                    :system-home system-home
                    :system-bin-dir system-bin-dir
                    :force-p force-p
                    :dry-run-p nil
                    :prompt-p prompt-p
                    :install-dependencies-p t
                    :verbose verbose)))))

(defun hub-install (&key
                      query
                      version-id
                      (scope :user)
                      user-home
                      system-home
                      system-bin-dir
                      force-p
                      dry-run-p
                      prompt-p
                      (install-dependencies-p t)
                      (verbose t)
                      record
                      package-name
                      query-kind
                      origin-kind
                      origin)
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (system-bin-path (%taffish-system-bin-dir system-bin-dir))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (index (unless record
                  (%hub-load-index home "install")))
         (resolved (and index
                        (%hub-resolve-info-target index
                                                  query
                                                  version-id
                                                  "install")))
         (record (or record (getf resolved :record)))
         (record-repository-url (%hub-json-string record "repository_url"))
         (package-name (%hub-install-safe-path-part
                        (or package-name
                            (getf resolved :package-name)
                            (%hub-json-string record "name"))
                        "package name"))
         (resolved-version-id
           (%hub-install-safe-path-part
            (%hub-install-record-version-id record
                                            (or version-id
                                                (getf resolved :version-id)))
            "version id"))
         (source-url (%hub-install-source-url record))
         (source-resolution
           (multiple-value-list
            (%resolve-taffish-source-url source-url
                                         :scope normalized-scope
                                         :user-home user-home-path
                                         :system-home system-home-path)))
         (resolved-source-url (first source-resolution))
         (source-rewrite-rule (second source-resolution))
         (source-ref (%hub-install-source-ref record resolved-version-id))
         (source-commit (%hub-install-source-commit record))
         (artifact-name
           (%hub-install-safe-path-part
            (%hub-install-artifact-name record resolved-version-id)
            "artifact name"))
         (command-name
           (%hub-install-safe-path-part
            (%hub-install-command-name record)
            "command name"))
         (command-bin-dir
           (%taffish-command-bin-dir normalized-scope home system-bin-path))
         (paths (%hub-install-paths home
                                    package-name
                                    resolved-version-id
                                    artifact-name
                                    :bin-dir command-bin-dir
                                    :command-name command-name))
         (install-root (getf paths :install-root))
         (source-dir (getf paths :source-dir))
         (bin-dir (getf paths :bin-dir))
         (launcher-file (getf paths :launcher-file))
         (command-launcher-file (getf paths :command-launcher-file))
         (metadata-file (getf paths :metadata-file))
         (dependencies (%hub-install-record-dependencies record))
         (install-key (%hub-install-key package-name resolved-version-id))
         (origin-kind (or origin-kind :hub-index))
         (origin (or origin record-repository-url source-url))
         (result (append
                  (list :scope normalized-scope
                        :home (%directory-namestring home)
                        :query (or query package-name)
                        :query-kind (or query-kind
                                        (getf resolved :query-kind))
                        :package-name package-name
                        :version-id resolved-version-id
                        :artifact-name artifact-name
                        :command-name command-name
                        :source-url source-url
                        :resolved-source-url resolved-source-url
                        :source-rewrite-rule source-rewrite-rule
                        :source-ref source-ref
                        :source-commit source-commit
                        :source-commit-verified-p nil
                        :actual-source-commit nil
                        :origin-kind origin-kind
                        :origin origin
                        :dependencies dependencies
                        :bin-in-path-p
                        (%taffish-command-bin-dir-in-path-p command-bin-dir)
                        :force-p force-p
                        :dry-run-p dry-run-p
                        :installed-p nil
                        :record record)
                  paths)))
    (unless (%hub-non-empty-string-p source-url)
      (error "[install] version record has no repository/source URL."))
    (when (member install-key *hub-install-stack* :test #'string=)
      (error "[install] circular dependency detected: ~{~A~^ -> ~} -> ~A"
             (reverse *hub-install-stack*)
             install-key))
    (let ((*hub-install-stack* (cons install-key *hub-install-stack*)))
      (%hub-install-ensure-free-paths install-root
                                      launcher-file
                                      force-p
                                      dry-run-p)
      (cond
        (dry-run-p
         (when verbose
           (%hub-install-print-result result))
         result)
        (t
         (let ((success-p nil)
               (wrote-command-launcher-p nil)
               (alias-result nil)
               (dependency-results nil))
           (handler-case
               (progn
                 (when install-dependencies-p
                   (dolist (dependency dependencies)
                     (push (%hub-install-dependency dependency
                                                   index
                                                   normalized-scope
                                                   home
                                                   user-home-path
                                                   system-home-path
                                                   system-bin-path
                                                   nil
                                                   nil
                                                   prompt-p
                                                   verbose)
                           dependency-results))
                   (setf dependency-results (nreverse dependency-results)))
                 (%ensure-directory (%taffish-home-dir home "apps"))
                 (%ensure-directory bin-dir)
                 (%ensure-directory install-root)
                 (%hub-install-copy-or-clone-source
                  resolved-source-url
                  source-ref
                  source-dir
                  :prompt-p prompt-p
                  :verbose verbose)
                 (let ((actual-source-commit
                         (%hub-install-verify-source-commit
                          (%hub-install-source-verification-dir
                           resolved-source-url
                           source-dir)
                          source-commit
                          :source-url resolved-source-url
                          :source-ref source-ref)))
                   (when actual-source-commit
                     (setf result
                           (append
                            (list :actual-source-commit actual-source-commit
                                  :source-commit-verified-p t)
                            result))))
                 (let* ((build (project-build :start-dir source-dir
                                              :command-p t
                                              :image-p nil
                                              :user-home user-home-path
                                              :system-home system-home-path
                                              :verbose nil))
                        (command (getf build :command))
                        (built-artifact (getf command :artifact-name))
                        (command-file (getf command :command-file)))
                   (unless (and built-artifact
                                (string= built-artifact artifact-name))
                     (error "[install] built command does not match index.~%  expected: ~A~%  got     : ~A"
                            artifact-name
                            (or built-artifact "<missing>")))
                   (%hub-install-write-launcher launcher-file
                                                command-file
                                                :launcher-name artifact-name
                                                :artifact-name artifact-name)
                   (setf result
                         (append
                          (list :command-file command-file
                                :command-launcher-file command-launcher-file
                                :dependency-results dependency-results
                                :build build
                                :installed-p t)
                          result))
                   (%hub-install-write-json-file
                    metadata-file
                    (%hub-install-metadata-json result record))
                   (when (and command-launcher-file
                              (not (string= command-name artifact-name)))
                     (setf alias-result
                           (%hub-install-refresh-command-alias
                            home
                            command-name
                            command-bin-dir)
                           wrote-command-launcher-p t)
                     (setf result (append alias-result result)))
                   (setf success-p t)
                   (when verbose
                     (%hub-install-print-result result))
                   result))
             (error (c)
               (unless success-p
                 (%hub-install-delete-file-if-exists launcher-file)
                 (when wrote-command-launcher-p
                   (%hub-install-delete-file-if-exists command-launcher-file))
                 (%hub-install-delete-dir-if-exists install-root))
             (error c)))))))))

(defun %hub-install-project-version-id (project)
  (format nil "~A-r~A"
          (getf project :version)
          (getf project :release)))

(defun %hub-install-project-kind-string (project)
  (string-downcase (string (getf project :kind))))

(defun %hub-install-project-dependencies-json (dependencies)
  (when dependencies
    (let ((table (make-hash-table :test #'equal))
          (items nil))
      (dolist (dependency dependencies)
        (pushnew (getf dependency :version)
                 (gethash (getf dependency :command) table)
                 :test #'string=))
      (maphash
       (lambda (command versions)
         (let ((ordered (nreverse versions)))
           (push (cons command
                       (if (cdr ordered)
                           (coerce ordered 'vector)
                           (first ordered)))
                 items)))
       table)
      (apply #'han.json:json-object
             (sort items #'string< :key #'car)))))

(defun %hub-install-project-smoke-json (smoke)
  (when smoke
    (han.json:json-object
     (cons "backend" (getf smoke :backend))
     (cons "timeout" (getf smoke :timeout))
     (cons "exist" (coerce (or (getf smoke :exist) nil) 'vector))
     (cons "test" (coerce (or (getf smoke :test) nil) 'vector)))))

(defun %hub-install-project-record (project)
  (let* ((version-id (%hub-install-project-version-id project))
         (container-image (getf project :container-image))
         (dockerfile (getf project :dockerfile))
         (dependencies
           (%hub-install-project-dependencies-json
            (getf project :dependencies)))
         (smoke (%hub-install-project-smoke-json (getf project :smoke))))
    (han.json:json-object
     (cons "name" (getf project :name))
     (cons "kind" (%hub-install-project-kind-string project))
     (cons "version" (getf project :version))
     (cons "release" (getf project :release))
     (cons "version_id" version-id)
     (cons "tag" (format nil "v~A" version-id))
     (cons "license" (or (getf project :license) :null))
     (cons "repository_url" (or (getf project :repository-url) :null))
     (cons "command"
           (han.json:json-object
            (cons "name" (getf project :command-name))))
     (cons "runtime"
           (han.json:json-object
            (cons "pipe" (getf project :runtime-pipe))
            (cons "command_mode" (getf project :runtime-command-mode))))
     (cons "paths"
           (han.json:json-object
            (cons "main" (getf project :main-path))
            (cons "help" "docs/help.md")
            (cons "dockerfile" (or dockerfile :null))))
     (cons "container"
           (if container-image
               (han.json:json-object
                (cons "image" container-image)
                (cons "dockerfile" (or dockerfile :null))
                (cons "image_tag" version-id))
               :null))
     (cons "smoke" (or smoke :null))
     (cons "source"
           (han.json:json-object
            (cons "local_path" (getf project :root-dir))
            (cons "ref" "working-tree")))
     (cons "dependencies" (or dependencies :null)))))

(defun hub-install-from-project (&key
                                   (start-dir (han.os:current-directory))
                                   (scope :user)
                                   user-home
                                   system-home
                                   system-bin-dir
                                   force-p
                                   dry-run-p
                                   prompt-p
                                   (verbose t))
  (let* ((project (project-check start-dir nil))
         (version-id (%hub-install-project-version-id project))
         (record (%hub-install-project-record project)))
    (hub-install :query (getf project :name)
                 :version-id version-id
                 :scope scope
                 :user-home user-home
                 :system-home system-home
                 :system-bin-dir system-bin-dir
                 :force-p force-p
                 :dry-run-p dry-run-p
                 :prompt-p prompt-p
                 :install-dependencies-p nil
                 :verbose verbose
                 :record record
                 :package-name (getf project :name)
                 :query-kind :local-project
                 :origin-kind :local-project
                 :origin (getf project :root-dir))))

(defun %hub-install-print-many-summary (results)
  (format t "[TAF] install batch summary: ~D target~:P~%"
          (length results))
  (format t "  installed/skipped : ~D/~D~%"
          (count-if (lambda (result)
                      (getf result :installed-p))
                    results)
          (count-if-not (lambda (result)
                          (getf result :installed-p))
                        results))
  (format t "  commands          : ~{~A~^, ~}~%"
          (mapcar (lambda (result)
                    (or (getf result :artifact-name)
                        (getf result :query)))
                  results)))

(defun hub-install-many (&key
                           targets
                           (scope :user)
                           user-home
                           system-home
                           system-bin-dir
                           force-p
                           dry-run-p
                           prompt-p
                           (install-dependencies-p t)
                           (verbose t))
  (let ((items (%hub-normalize-targets targets "install"))
        (results nil))
    (dolist (item items)
      (push (hub-install :query (getf item :query)
                         :version-id (getf item :version-id)
                         :scope scope
                         :user-home user-home
                         :system-home system-home
                         :system-bin-dir system-bin-dir
                         :force-p force-p
                         :dry-run-p dry-run-p
                         :prompt-p prompt-p
                         :install-dependencies-p install-dependencies-p
                         :verbose verbose)
            results))
    (let* ((ordered-results (nreverse results))
           (summary (list :scope scope
                          :target-count (length ordered-results)
                          :targets items
                          :results ordered-results
                          :dry-run-p dry-run-p
                          :force-p force-p)))
      (when (and verbose
                 (> (length ordered-results) 1))
        (%hub-install-print-many-summary ordered-results))
      summary)))
