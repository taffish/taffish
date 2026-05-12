(in-package :taf.core)

;;;; ============================================================
;;;; hub / uninstall.lisp
;;;; ============================================================

(defun %hub-uninstall-string-suffix-p (suffix string)
  (and (stringp suffix)
       (stringp string)
       (let ((suffix-len (length suffix))
             (string-len (length string)))
         (and (<= suffix-len string-len)
              (string= suffix
                       (subseq string (- string-len suffix-len)))))))

(defun %hub-uninstall-command-base (artifact-name version-id)
  (let ((suffix (and (%hub-non-empty-string-p version-id)
                     (format nil "-v~A" version-id))))
    (when (and suffix
               (%hub-non-empty-string-p artifact-name)
               (%hub-uninstall-string-suffix-p suffix artifact-name))
      (subseq artifact-name
              0
              (- (length artifact-name) (length suffix))))))

(defun %hub-uninstall-metadata-files (home)
  (let ((apps-dir (%taffish-home-dir home "apps")))
    (when (han.path:directory-exists-p apps-dir)
      (loop for package-dir in (han.path:subdirectories apps-dir)
            append
            (loop for version-dir in (han.path:subdirectories package-dir)
                  for metadata-file = (han.path:join-path version-dir
                                                          "install.json")
                  when (han.path:file-exists-p metadata-file)
                    collect metadata-file)))))

(defun %hub-uninstall-read-entry (home metadata-file)
  (handler-case
      (let* ((metadata (han.json:read-json-file metadata-file))
             (package-name (%hub-json-string metadata "name"))
             (version-id (%hub-json-string metadata "version_id"))
             (artifact-name (%hub-json-string metadata "artifact_name"))
             (metadata-install-root
               (%hub-json-string metadata "install_root"))
             (metadata-source-dir
               (%hub-json-string metadata "source_dir"))
             (metadata-bin-dir
               (%hub-json-string metadata "bin_dir"))
             (metadata-launcher-file
               (%hub-json-string metadata "launcher_file"))
             (metadata-command-launcher-file
               (%hub-json-string metadata "command_launcher_file"))
             (metadata-command-file
               (%hub-json-string metadata "command_file")))
        (when (and (han.json:json-object-p metadata)
                   (%hub-non-empty-string-p package-name)
                   (%hub-non-empty-string-p version-id)
                   (%hub-non-empty-string-p artifact-name))
          (%hub-install-safe-path-part package-name "installed package name")
          (%hub-install-safe-path-part version-id "installed version id")
          (%hub-install-safe-path-part artifact-name "installed artifact name")
          (let* ((paths (%hub-install-paths home
                                            package-name
                                            version-id
                                            artifact-name))
                 (command-base
                   (%hub-uninstall-command-base artifact-name version-id)))
            (append
             (list :metadata metadata
                   :metadata-file (han.path:->namestring metadata-file)
                   :package-name package-name
                   :version-id version-id
                   :artifact-name artifact-name
                   :command-base command-base
                   :install-root (or metadata-install-root
                                     (getf paths :install-root))
                   :source-dir (or metadata-source-dir
                                   (getf paths :source-dir))
                   :bin-dir (or metadata-bin-dir
                                (getf paths :bin-dir))
                   :launcher-file (or metadata-launcher-file
                                      (getf paths :launcher-file))
                   :command-launcher-file metadata-command-launcher-file
                   :command-file metadata-command-file)
             paths))))
    (error ()
      nil)))

(defun %hub-uninstall-installed-entries (home)
  (loop for metadata-file in (%hub-uninstall-metadata-files home)
        for entry = (%hub-uninstall-read-entry home metadata-file)
        when entry
          collect entry))

(defun %hub-uninstall-entry-match-p (entry query version-id)
  (and (%hub-non-empty-string-p query)
       (or (string= query (getf entry :package-name))
           (string= query (getf entry :artifact-name))
           (string= query (or (getf entry :command-base) "")))
       (or (null version-id)
           (string= version-id (getf entry :version-id)))))

(defun %hub-uninstall-candidate-string (entry)
  (format nil "~A ~A (~A)"
          (getf entry :package-name)
          (getf entry :version-id)
          (getf entry :artifact-name)))

(defun %hub-uninstall-find-installed (home query version-id force-p)
  (let* ((normalized-version-id (%hub-normalize-version-id version-id))
         (matches
           (remove-if-not
            (lambda (entry)
              (%hub-uninstall-entry-match-p entry query normalized-version-id))
            (%hub-uninstall-installed-entries home))))
    (cond
      ((null matches)
       (unless force-p
         (error "[uninstall] app version is not installed: ~A~@[ ~A~]"
                query
                normalized-version-id))
       nil)
      ((> (length matches) 1)
       (error "[uninstall] multiple installed versions match ~A. Specify VERSION-ID.~%Candidates: ~{~A~^; ~}"
              query
              (mapcar #'%hub-uninstall-candidate-string matches)))
      (t
       (first matches)))))

(defun %hub-uninstall-owned-command-launcher-p (entry)
  (let ((command-launcher-file (getf entry :command-launcher-file))
        (command-file (getf entry :command-file)))
    (and command-launcher-file
         command-file
         (han.path:file-exists-p command-launcher-file)
         (ignore-errors
           (not (null (search command-file
                              (han.os:load-string command-launcher-file)
                              :test #'char=)))))))

(defun %hub-uninstall-delete-entry (entry dry-run-p)
  (let* ((install-root (getf entry :install-root))
         (launcher-file (getf entry :launcher-file))
         (command-launcher-file (getf entry :command-launcher-file))
         (install-root-exists-p
           (han.path:directory-exists-p (han.path:directory-pathname install-root)))
         (launcher-exists-p
           (han.path:file-exists-p launcher-file))
         (command-launcher-owned-p
           (%hub-uninstall-owned-command-launcher-p entry))
         (install-root-present-p (not (null install-root-exists-p)))
         (launcher-present-p (not (null launcher-exists-p))))
    (unless dry-run-p
      (when launcher-present-p
        (%hub-install-delete-file-if-exists launcher-file))
      (when command-launcher-owned-p
        (%hub-install-delete-file-if-exists command-launcher-file))
      (when install-root-present-p
        (%hub-install-delete-dir-if-exists install-root)))
    (append
     (list :install-root-exists-p install-root-present-p
           :launcher-exists-p launcher-present-p
           :command-launcher-exists-p command-launcher-owned-p
           :install-root-deleted-p (and install-root-present-p
                                        (not dry-run-p))
           :launcher-deleted-p (and launcher-present-p
                                    (not dry-run-p))
           :command-launcher-deleted-p (and command-launcher-owned-p
                                            (not dry-run-p)))
     entry)))

(defun %hub-uninstall-print-result (result)
  (cond
    ((getf result :missing-p)
     (format t "[TAF] uninstall skipped: ~A~%" (getf result :query))
     (%print-hub-info-field "scope"
                            (string-downcase (string (getf result :scope))))
     (%print-hub-info-field "reason" "not installed"))
    (t
     (format t "[TAF] ~A: ~A ~A~%"
             (if (getf result :dry-run-p)
                 "uninstall dry-run"
                 "uninstalled")
             (getf result :package-name)
             (getf result :version-id))
     (%print-hub-info-field "scope"
                            (string-downcase (string (getf result :scope))))
     (%print-hub-info-field "app" (getf result :install-root))
     (%print-hub-info-field "command" (getf result :launcher-file))
     (%print-hub-info-field "bin" (getf result :bin-dir))
     (%print-hub-info-field "images" "kept")
     (when (getf result :dry-run-p)
       (%print-hub-info-field "action"
                              "rerun without --dry-run to uninstall"))))
  nil)

(defun hub-uninstall (&key
                        query
                        version-id
                        (scope :user)
                        user-home
                        system-home
                        force-p
                        dry-run-p
                        (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (unless (%hub-non-empty-string-p query)
      (error "[uninstall] app name or command name missing."))
    (let ((entry (%hub-uninstall-find-installed home query version-id force-p)))
      (let ((result
              (if entry
                  (let* ((delete-result
                           (%hub-uninstall-delete-entry entry dry-run-p))
                         (alias-result
                           (and (not dry-run-p)
                                (%hub-install-refresh-command-alias
                                 home
                                 (getf delete-result :command-base)
                                 (getf delete-result :bin-dir)))))
                    (append
                     alias-result
                     (list :scope normalized-scope
                           :home (%directory-namestring home)
                           :query query
                           :requested-version-id version-id
                           :force-p force-p
                           :dry-run-p dry-run-p
                           :missing-p nil
                           :uninstalled-p (not dry-run-p))
                     delete-result))
                  (list :scope normalized-scope
                        :home (%directory-namestring home)
                        :query query
                        :requested-version-id version-id
                        :force-p force-p
                        :dry-run-p dry-run-p
                        :missing-p t
                        :uninstalled-p nil))))
        (when verbose
          (%hub-uninstall-print-result result))
        result))))

(defun %hub-uninstall-print-many-summary (results)
  (format t "[TAF] uninstall batch summary: ~D target~:P~%"
          (length results))
  (format t "  uninstalled/skipped : ~D/~D~%"
          (count-if (lambda (result)
                      (getf result :uninstalled-p))
                    results)
          (count-if-not (lambda (result)
                          (getf result :uninstalled-p))
                        results))
  (format t "  commands            : ~{~A~^, ~}~%"
          (mapcar (lambda (result)
                    (or (getf result :artifact-name)
                        (getf result :query)))
                  results)))

(defun hub-uninstall-many (&key
                             targets
                             (scope :user)
                             user-home
                             system-home
                             force-p
                             dry-run-p
                             (verbose t))
  (let ((items (%hub-normalize-targets targets "uninstall"))
        (results nil))
    (dolist (item items)
      (push (hub-uninstall :query (getf item :query)
                           :version-id (getf item :version-id)
                           :scope scope
                           :user-home user-home
                           :system-home system-home
                           :force-p force-p
                           :dry-run-p dry-run-p
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
        (%hub-uninstall-print-many-summary ordered-results))
      summary)))
