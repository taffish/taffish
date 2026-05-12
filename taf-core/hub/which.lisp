(in-package :taf.core)

;;;; ============================================================
;;;; hub / which.lisp
;;;; ============================================================

(defun %hub-which-find-installed (home query version-id)
  (let* ((normalized-version-id (%hub-normalize-version-id version-id))
         (matches
           (remove-if-not
            (lambda (entry)
              (%hub-uninstall-entry-match-p entry query normalized-version-id))
            (%hub-uninstall-installed-entries home))))
    (cond
      ((null matches)
       (error "[which] local TAFFISH command is not installed: ~A~@[ ~A~]"
              query
              normalized-version-id))
      ((> (length matches) 1)
       (error "[which] multiple installed versions match ~A. Specify VERSION-ID.~%Candidates: ~{~A~^; ~}"
              query
              (mapcar #'%hub-uninstall-candidate-string matches)))
      (t
       (first matches)))))

(defun %hub-which-metadata-string (entry key)
  (let ((metadata (getf entry :metadata)))
    (and (han.json:json-object-p metadata)
         (%hub-json-string metadata key))))

(defun %hub-which-existing-file-p (path)
  (not (null (and path (han.path:file-exists-p path)))))

(defun %hub-which-existing-dir-p (path)
  (not (null (and path
                  (han.path:directory-exists-p
                   (han.path:directory-pathname path))))))

(defun %hub-which-result (entry scope home query version-id)
  (let* ((command-file (%hub-which-metadata-string entry "command_file"))
         (repository-url (%hub-which-metadata-string entry "repository_url"))
         (source-ref (%hub-which-metadata-string entry "source_ref"))
         (source-commit (%hub-which-metadata-string entry "source_commit"))
         (origin-kind (%hub-which-metadata-string entry "origin_kind"))
         (origin (%hub-which-metadata-string entry "origin"))
         (origin-display (%hub-which-metadata-string entry "origin_display"))
         (bin-dir (or (getf entry :bin-dir)
                      (%directory-namestring
                       (%taffish-home-dir home "bin")))))
    (append
     (list :scope scope
           :home (%directory-namestring home)
           :query query
           :requested-version-id version-id
           :package-name (getf entry :package-name)
           :version-id (getf entry :version-id)
           :artifact-name (getf entry :artifact-name)
           :command-base (getf entry :command-base)
           :command-file command-file
           :command-exists-p (%hub-which-existing-file-p command-file)
           :launcher-exists-p
           (%hub-which-existing-file-p (getf entry :launcher-file))
           :install-root-exists-p
           (%hub-which-existing-dir-p (getf entry :install-root))
           :source-dir-exists-p
           (%hub-which-existing-dir-p (getf entry :source-dir))
           :metadata-exists-p
           (%hub-which-existing-file-p (getf entry :metadata-file))
           :repository-url repository-url
           :source-ref source-ref
           :source-commit source-commit
           :origin-kind origin-kind
           :origin origin
           :origin-display
           (or origin-display
               (%hub-install-origin-display origin-kind origin))
           :bin-dir (%directory-namestring bin-dir)
           :bin-in-path-p (%taffish-command-bin-dir-in-path-p bin-dir))
     entry)))

(defun %hub-which-json (result)
  (han.json:json-object
   (cons "schema_version" "taffish.which/v1")
   (cons "scope" (string-downcase (string (getf result :scope))))
   (cons "query" (getf result :query))
   (cons "name" (getf result :package-name))
   (cons "version_id" (getf result :version-id))
   (cons "artifact_name" (getf result :artifact-name))
   (cons "command_name" (or (getf result :command-base) :null))
   (cons "launcher_file" (or (getf result :launcher-file) :null))
   (cons "launcher_exists" (getf result :launcher-exists-p))
   (cons "command_file" (or (getf result :command-file) :null))
   (cons "command_exists" (getf result :command-exists-p))
   (cons "install_root" (or (getf result :install-root) :null))
   (cons "install_root_exists" (getf result :install-root-exists-p))
   (cons "source_dir" (or (getf result :source-dir) :null))
   (cons "source_dir_exists" (getf result :source-dir-exists-p))
   (cons "metadata_file" (or (getf result :metadata-file) :null))
   (cons "metadata_exists" (getf result :metadata-exists-p))
   (cons "repository_url" (or (getf result :repository-url) :null))
   (cons "source_ref" (or (getf result :source-ref) :null))
   (cons "source_commit" (or (getf result :source-commit) :null))
   (cons "origin_kind" (or (getf result :origin-kind) :null))
   (cons "origin" (or (getf result :origin) :null))
   (cons "origin_display" (or (getf result :origin-display) :null))
   (cons "bin_dir" (or (getf result :bin-dir) :null))
   (cons "bin_in_path" (getf result :bin-in-path-p))))

(defun %hub-which-status-string (exists-p)
  (if exists-p "yes" "no"))

(defun %hub-which-print-result (result)
  (format t "[TAF] which: ~A~%" (getf result :artifact-name))
  (%print-hub-info-field "scope"
                         (string-downcase (string (getf result :scope))))
  (%print-hub-info-field "name" (getf result :package-name))
  (%print-hub-info-field "version id" (getf result :version-id))
  (%print-hub-info-field "command" (getf result :command-base))
  (%print-hub-info-field "launcher" (getf result :launcher-file))
  (%print-hub-info-field "command file" (getf result :command-file))
  (%print-hub-info-field "app" (getf result :install-root))
  (%print-hub-info-field "source" (getf result :source-dir))
  (%print-hub-info-field "metadata" (getf result :metadata-file))
  (%print-hub-info-field "origin" (getf result :origin-display))
  (%print-hub-info-field "repository" (getf result :repository-url))
  (%print-hub-info-field "source ref" (getf result :source-ref))
  (%print-hub-info-field "source commit" (getf result :source-commit))
  (%print-hub-info-field "bin" (getf result :bin-dir))
  (%print-hub-info-field
   "path"
   (if (getf result :bin-in-path-p) "ok" "not in PATH"))
  (%print-hub-info-field
   "exists"
   (format nil "launcher=~A, command=~A, app=~A, source=~A"
           (%hub-which-status-string (getf result :launcher-exists-p))
           (%hub-which-status-string (getf result :command-exists-p))
           (%hub-which-status-string (getf result :install-root-exists-p))
           (%hub-which-status-string (getf result :source-dir-exists-p))))
  nil)

(defun hub-which (&key
                    query
                    version-id
                    (scope :user)
                    user-home
                    system-home
                    json-p
                    (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (unless (%hub-non-empty-string-p query)
      (error "[which] app name or command name missing."))
    (let* ((entry (%hub-which-find-installed home query version-id))
           (result (%hub-which-result entry
                                      normalized-scope
                                      home
                                      query
                                      version-id)))
      (when verbose
        (if json-p
            (format t "~A" (han.json:encode-json (%hub-which-json result)
                                                 :indent 2))
            (%hub-which-print-result result)))
      result)))

(defun hub-which-many (&key
                         targets
                         (scope :user)
                         user-home
                         system-home
                         json-p
                         (verbose t))
  (let* ((items (%hub-normalize-targets targets "which"))
         (results
           (mapcar (lambda (target)
                     (hub-which :query (getf target :query)
                                :version-id (getf target :version-id)
                                :scope scope
                                :user-home user-home
                                :system-home system-home
                                :json-p nil
                                :verbose nil))
                   items))
         (summary (list :scope scope
                        :target-count (length results)
                        :targets items
                        :results results
                        :json-p json-p)))
    (when verbose
      (if json-p
          (format t "~A"
                  (han.json:encode-json
                   (%hub-json-array-from-list
                    (mapcar #'%hub-which-json results))
                   :indent 2))
          (loop for result in results
                for first-p = t then nil do
                  (unless first-p
                    (format t "~%"))
                  (%hub-which-print-result result))))
    summary))
