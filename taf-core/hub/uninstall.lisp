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

(defun %hub-installed-path-key (path directory-p)
  ;; Resolve existing ancestors, including /tmp vs /private/tmp, without needing
  ;; the leaf to exist. Never accept traversal or relative metadata paths.
  (let* ((p (if directory-p (han.path:directory-pathname path)
                (han.path:->pathname path)))
         (parts (pathname-directory p)))
    (unless (and (eq (first parts) :absolute)
                 (not (wild-pathname-p p))
                 (not (intersection parts '(:up :back))))
      (error "Unsafe installation path."))
    (labels ((resolve-directory (dir)
               (or (han.path:directory-exists-p dir)
                   (let* ((components (pathname-directory dir))
                          (parent (make-pathname :directory (butlast components)
                                                 :defaults dir)))
                     (merge-pathnames
                      (make-pathname :directory (list :relative (car (last components))))
                      (resolve-directory parent))))))
      (namestring
       (if directory-p (resolve-directory p)
           (merge-pathnames (make-pathname :name (pathname-name p) :type (pathname-type p))
                            (resolve-directory (make-pathname :name nil :type nil :defaults p))))))))

(defun %hub-installed-path-problem (entry)
  (handler-case
      (let* ((root (getf entry :install-root))
             (home (getf entry :installation-home))
             (artifact (getf entry :artifact-name))
             (base (getf entry :command-base))
             (metadata (getf entry :metadata))
             (bin (getf entry :bin-dir))
             (expected (%hub-install-paths home (getf entry :package-name)
                                           (getf entry :version-id) artifact))
             (source (getf expected :source-dir)))
        (unless (and home root bin base) (return-from %hub-installed-path-problem "metadata"))
        ;; System installs may persist a custom bin directory. User launchers
        ;; belong to home/bin; both launcher names must agree with their bin.
        (dolist (pair (append
                      (list (list :metadata-file (getf expected :metadata-file) nil)
                            (list :install-root (getf expected :install-root) t)
                            (list :source-dir source t)
                            (list :command-file (han.path:join-path source "target/" artifact) nil)
                            (list :launcher-file (han.path:join-path bin artifact) nil))
                      (unless (equal (%hub-json-string metadata "scope") "system")
                        (list (list :bin-dir (getf expected :bin-dir) t)))
                      (when (getf entry :command-launcher-file)
                        (list (list :command-launcher-file (han.path:join-path bin base) nil)))))
          (destructuring-bind (key path directory-p) pair
            (unless (equal (%hub-installed-path-key (getf entry key) directory-p)
                           (%hub-installed-path-key path directory-p))
              (return-from %hub-installed-path-problem (string-downcase (string key))))))
        (dolist (path (list (%taffish-home-dir home "apps")
                           (han.path:parent-directory-pathname
                            (han.path:directory-pathname root))
                           root (getf entry :metadata-file) source
                           (han.path:join-path source "target/")
                           (getf entry :command-file) (getf entry :launcher-file)
                           (getf entry :command-launcher-file)))
          (when (and path (%hub-diagnostic-test "-L" path))
            (return-from %hub-installed-path-problem (han.path:->namestring path))))
        nil)
    (error () "metadata")))

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
             (list :installation-home (han.path:->namestring home)
                   :metadata metadata
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
         (%hub-error "installed-missing"
                     :command "uninstall"
                     :query query
                     :version (if normalized-version-id
                                  (format nil " ~A" normalized-version-id)
                                  "")))
       nil)
      ((> (length matches) 1)
       (%hub-error "installed-multiple"
                   :command "uninstall"
                   :query query
                   :candidates
                   (format nil "~{~A~^; ~}"
                           (mapcar #'%hub-uninstall-candidate-string matches))))
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
  ;; Re-read before applying a plan. In particular, never delete a directory
  ;; named only by an untrusted install_root field.
  (let* ((fresh (%hub-uninstall-read-entry (getf entry :installation-home)
                                          (getf entry :metadata-file)))
         (problem (or (null fresh) (%hub-installed-path-problem entry)
                      (%hub-installed-path-problem fresh))))
    (when problem
      (%hub-error "unsafe-installed-path" :path (getf entry :metadata-file)))
    (let ((schema (han.json:get-json (getf fresh :metadata) "schema_version" :missing)))
      (unless (or (eq schema :missing) (equal schema "taffish.install/v1"))
        (%hub-error "unsupported-install-schema" :path (getf entry :metadata-file)))))
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
  (%operation-progress-yield)
  (cond
    ((getf result :missing-p)
     (%hub-print-message "uninstall.skipped" :query (getf result :query))
     (%print-hub-info-field "scope"
                            (string-downcase (string (getf result :scope))))
     (%print-hub-info-field "reason" (%hub-message "uninstall.not-installed")))
    (t
     (%hub-print-message
      "uninstall.header"
      :action (%hub-status-display
               (if (getf result :dry-run-p)
                   :uninstall-dry-run
                   :uninstalled))
      :app (getf result :package-name)
      :version (getf result :version-id))
     (%print-hub-info-field "scope"
                            (string-downcase (string (getf result :scope))))
     (%print-hub-info-field "app" (getf result :install-root))
     (%print-hub-info-field "command" (getf result :launcher-file))
     (%print-hub-info-field "bin" (getf result :bin-dir))
     (%print-hub-info-field "images" (%hub-message "uninstall.images-kept"))
     (when (getf result :dry-run-p)
       (%print-hub-info-field "action"
                              (%hub-message "uninstall.apply-hint")))))
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
  (%with-operation-progress (verbose)
  (unless dry-run-p (%operation-stage "inspect" :target query))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (unless (%hub-non-empty-string-p query)
      (%hub-error "target-missing" :command "uninstall"))
    (let* ((entry (%hub-uninstall-find-installed home query version-id force-p))
           (locked-bin (and entry (getf entry :bin-dir))))
      (labels ((perform-uninstall ()
        (let ((result
              (if entry
                  (let* ((notice (unless dry-run-p (%operation-stage "remove" :target (getf entry :artifact-name))))
                         (delete-result
                           (%hub-uninstall-delete-entry entry dry-run-p))
                         (alias-result
                           (and (not dry-run-p)
                                (%hub-install-refresh-command-alias
                                 home
                                 (getf delete-result :command-base)
                                 (getf delete-result :bin-dir)))))
                    (declare (ignore notice))
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
          result)))
        (if (or dry-run-p (null entry))
            (perform-uninstall)
            (progn
              (when (%hub-installed-path-problem entry)
                (%hub-error "unsafe-installed-path" :path (getf entry :metadata-file)))
              (%hub-call-with-write-locks
               home (getf entry :bin-dir)
               (lambda ()
                 ;; A cooperating writer may have changed this entry while the
                 ;; caller was planning. Resolve again before deleting anything.
                 (setf entry (%hub-uninstall-find-installed home query version-id force-p))
                 (when (and entry
                            (not (equal (%hub-installed-path-key locked-bin t)
                                        (%hub-installed-path-key (getf entry :bin-dir) t))))
                   (%hub-error "unsafe-installed-path" :path (getf entry :metadata-file)))
                 (perform-uninstall))))))))))

(defun %hub-uninstall-print-many-summary (results)
  (%hub-print-message "uninstall.batch" :count (length results))
  (%hub-print-message
   "uninstall.batch-counts"
   :uninstalled (count-if (lambda (result) (getf result :uninstalled-p)) results)
   :skipped (count-if-not (lambda (result) (getf result :uninstalled-p)) results))
  (%hub-print-message
   "batch.commands"
   :commands (format nil "~{~A~^, ~}"
                     (mapcar (lambda (result)
                               (or (getf result :artifact-name)
                                   (getf result :query)))
                             results))))

(defun hub-uninstall-many (&key
                             targets
                             (scope :user)
                             user-home
                             system-home
                             force-p
                             dry-run-p
                             (verbose t))
  (%with-operation-progress (verbose)
  (let* ((items (%hub-normalize-targets targets "uninstall"))
         (results nil) (*operation-item* 0) (*operation-total* (length items)))
    (dolist (item items)
      (incf *operation-item*)
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
      summary))))
