(in-package :taf.core)

;;;; ============================================================
;;;; hub / list.lisp
;;;; ============================================================

(defun %hub-list-normalize-mode (mode)
  (cond
    ((or (null mode) (eql mode :local) (eql mode :installed)) :local)
    ((or (eql mode :online) (eql mode :index)) :online)
    ((and (stringp mode) (member mode '("local" "installed")
                                 :test #'string-equal))
     :local)
    ((and (stringp mode) (member mode '("online" "index")
                                 :test #'string-equal))
     :online)
    (t
     (error "[list] mode must be :local or :online, but got: ~S" mode))))

(defun %hub-list-limit-items (items limit)
  (cond
    ((null limit) items)
    ((<= (length items) limit) items)
    (t (subseq items 0 limit))))

(defun %hub-list-local-entry< (a b)
  (let ((name-a (or (getf a :package-name) ""))
        (name-b (or (getf b :package-name) ""))
        (version-a (or (getf a :version-id) ""))
        (version-b (or (getf b :version-id) "")))
    (cond
      ((string< name-a name-b) t)
      ((string> name-a name-b) nil)
      (t (%hub-version-id-newer-p version-a version-b)))))

(defun %hub-list-metadata-string (entry key)
  (let ((metadata (getf entry :metadata)))
    (and (han.json:json-object-p metadata)
         (%hub-json-string metadata key))))

(defun %hub-list-existing-file-p (path)
  (not (null (and path (han.path:file-exists-p path)))))

(defun %hub-list-existing-dir-p (path)
  (not (null (and path
                  (han.path:directory-exists-p
                   (han.path:directory-pathname path))))))

(defun %hub-list-local-item (entry)
  (list :name (getf entry :package-name)
        :version-id (getf entry :version-id)
        :kind (%hub-list-metadata-string entry "kind")
        :artifact-name (getf entry :artifact-name)
        :command-name (getf entry :command-base)
        :launcher-file (getf entry :launcher-file)
        :bin-dir (getf entry :bin-dir)
        :command-file (%hub-list-metadata-string entry "command_file")
        :install-root (getf entry :install-root)
        :source-dir (getf entry :source-dir)
        :metadata-file (getf entry :metadata-file)
        :repository-url (%hub-list-metadata-string entry "repository_url")
        :source-ref (%hub-list-metadata-string entry "source_ref")
        :source-commit (%hub-list-metadata-string entry "source_commit")
        :origin-kind (%hub-list-metadata-string entry "origin_kind")
        :origin (%hub-list-metadata-string entry "origin")
        :origin-display (%hub-list-metadata-string entry "origin_display")
        :installed-at (%hub-list-metadata-string entry "installed_at")
        :launcher-exists-p
        (%hub-list-existing-file-p (getf entry :launcher-file))
        :install-root-exists-p
        (%hub-list-existing-dir-p (getf entry :install-root))
        :metadata-exists-p
        (%hub-list-existing-file-p (getf entry :metadata-file))))

(defun %hub-list-local-items (home)
  (sort (mapcar #'%hub-list-local-item
                (%hub-uninstall-installed-entries home))
        #'%hub-list-local-entry<))

(defun %hub-list-online-record (package-entry latest-version-id version-ids)
  (let ((versions (%hub-json-ref package-entry "versions")))
    (when (han.json:json-object-p versions)
      (or (and latest-version-id
               (han.json:get-json versions latest-version-id))
          (and version-ids
               (han.json:get-json versions (first version-ids)))))))

(defun %hub-list-online-item (package-name package-entry)
  (when (han.json:json-object-p package-entry)
    (let* ((latest-version-id (%hub-json-string package-entry "latest"))
           (version-ids (%hub-package-version-ids package-entry))
           (record (%hub-list-online-record package-entry
                                            latest-version-id
                                            version-ids))
           (command (or (and (han.json:json-object-p record)
                             (%hub-json-ref record "command"))
                        (%hub-json-ref package-entry "command")))
           (container (and (han.json:json-object-p record)
                           (%hub-json-ref record "container"))))
      (list :name package-name
            :latest-version-id latest-version-id
            :versions version-ids
            :kind (and (han.json:json-object-p record)
                       (%hub-json-string record "kind"))
            :command-name (and (han.json:json-object-p command)
                               (%hub-json-string command "name"))
            :repository-url
            (or (and (han.json:json-object-p record)
                     (%hub-json-string record "repository_url"))
                (%hub-json-string package-entry "repository_url"))
            :container-image
            (and (han.json:json-object-p container)
                 (%hub-json-string container "image"))))))

(defun %hub-list-online-item< (a b)
  (string< (or (getf a :name) "")
           (or (getf b :name) "")))

(defun %hub-list-online-items (index)
  (let ((packages (%hub-json-ref index "packages")))
    (unless (han.json:json-object-p packages)
      (error "[list] index is missing object field: packages"))
    (sort
     (remove nil
             (mapcar (lambda (package-name)
                       (%hub-list-online-item
                        package-name
                        (han.json:get-json packages package-name)))
                     (han.json:json-keys packages)))
     #'%hub-list-online-item<)))

(defun %hub-list-string-or-null (value)
  (or value :null))

(defun %hub-list-vector (items encoder)
  (coerce (mapcar encoder items) 'vector))

(defun %hub-list-local-item-json (item)
  (han.json:json-object
   (cons "name" (%hub-list-string-or-null (getf item :name)))
   (cons "version_id" (%hub-list-string-or-null (getf item :version-id)))
   (cons "kind" (%hub-list-string-or-null (getf item :kind)))
   (cons "artifact_name" (%hub-list-string-or-null (getf item :artifact-name)))
   (cons "command_name" (%hub-list-string-or-null (getf item :command-name)))
   (cons "launcher_file" (%hub-list-string-or-null (getf item :launcher-file)))
   (cons "bin_dir" (%hub-list-string-or-null (getf item :bin-dir)))
   (cons "command_file" (%hub-list-string-or-null (getf item :command-file)))
   (cons "install_root" (%hub-list-string-or-null (getf item :install-root)))
   (cons "source_dir" (%hub-list-string-or-null (getf item :source-dir)))
   (cons "metadata_file" (%hub-list-string-or-null (getf item :metadata-file)))
   (cons "repository_url" (%hub-list-string-or-null (getf item :repository-url)))
   (cons "source_ref" (%hub-list-string-or-null (getf item :source-ref)))
   (cons "source_commit" (%hub-list-string-or-null (getf item :source-commit)))
   (cons "origin_kind" (%hub-list-string-or-null (getf item :origin-kind)))
   (cons "origin" (%hub-list-string-or-null (getf item :origin)))
   (cons "origin_display"
         (%hub-list-string-or-null
          (or (getf item :origin-display)
              (%hub-install-origin-display (getf item :origin-kind)
                                           (getf item :origin)))))
   (cons "installed_at" (%hub-list-string-or-null (getf item :installed-at)))
   (cons "launcher_exists" (getf item :launcher-exists-p))
   (cons "install_root_exists" (getf item :install-root-exists-p))
   (cons "metadata_exists" (getf item :metadata-exists-p))))

(defun %hub-list-online-item-json (item)
  (han.json:json-object
   (cons "name" (%hub-list-string-or-null (getf item :name)))
   (cons "latest_version_id"
         (%hub-list-string-or-null (getf item :latest-version-id)))
   (cons "versions"
         (coerce (or (getf item :versions) nil) 'vector))
   (cons "kind" (%hub-list-string-or-null (getf item :kind)))
   (cons "command_name" (%hub-list-string-or-null (getf item :command-name)))
   (cons "repository_url" (%hub-list-string-or-null (getf item :repository-url)))
   (cons "container_image"
         (%hub-list-string-or-null (getf item :container-image)))))

(defun %hub-list-json (result)
  (let ((mode (getf result :mode)))
    (han.json:json-object
     (cons "schema_version" "taffish.list/v1")
     (cons "mode" (string-downcase (string mode)))
     (cons "scope" (string-downcase (string (getf result :scope))))
     (cons "home" (%hub-list-string-or-null (getf result :home)))
     (cons "index_file" (%hub-list-string-or-null (getf result :index-file)))
     (cons "total" (getf result :total))
     (cons "shown" (length (getf result :items)))
     (cons "limit" (or (getf result :limit) :null))
     (cons "items"
           (%hub-list-vector
            (getf result :items)
            (if (eq mode :online)
                #'%hub-list-online-item-json
                #'%hub-list-local-item-json))))))

(defun %hub-list-print-local-item (item index)
  (format t "  ~2D. ~A  ~A  ~A~%"
          index
          (getf item :name)
          (getf item :version-id)
          (getf item :artifact-name))
  (%print-hub-info-field "kind" (getf item :kind))
  (%print-hub-info-field "command" (getf item :launcher-file))
  (%print-hub-info-field "bin" (getf item :bin-dir))
  (%print-hub-info-field
   "origin"
   (or (getf item :origin-display)
       (%hub-install-origin-display (getf item :origin-kind)
                                    (getf item :origin))))
  (%print-hub-info-field "source" (getf item :source-dir))
  (%print-hub-info-field "metadata" (getf item :metadata-file)))

(defun %hub-list-print-online-item (item index)
  (format t "  ~2D. ~A" index (getf item :name))
  (when (getf item :command-name)
    (format t "  ~A" (getf item :command-name)))
  (when (getf item :kind)
    (format t "  ~A" (getf item :kind)))
  (when (getf item :latest-version-id)
    (format t "  ~A" (getf item :latest-version-id)))
  (format t "~%")
  (%print-hub-info-field
   "versions"
   (and (getf item :versions)
        (%hub-format-version-list
         (getf item :versions)
         (getf item :latest-version-id)
         nil)))
  (%print-hub-info-field "image" (getf item :container-image))
  (%print-hub-info-field "repo" (getf item :repository-url)))

(defun %hub-list-print-result (result)
  (let ((mode (getf result :mode))
        (items (getf result :items)))
    (format t "[TAF] ~A apps~%"
            (if (eq mode :online) "indexed" "installed"))
    (%print-hub-info-field "scope"
                           (string-downcase (string (getf result :scope))))
    (%print-hub-info-field "home" (getf result :home))
    (%print-hub-info-field "index" (getf result :index-file))
    (%print-hub-info-field "found" (getf result :total))
    (%print-hub-info-field "showing" (length items))
    (if items
        (loop for item in items
              for i from 1 do
                (if (eq mode :online)
                    (%hub-list-print-online-item item i)
                    (%hub-list-print-local-item item i)))
        (format t "  no apps~%")))
  nil)

(defun hub-list (&key
                   (mode :local)
                   (scope :user)
                   user-home
                   system-home
                   limit
                   json-p
                   (verbose t))
  (let* ((normalized-mode (%hub-list-normalize-mode mode))
         (normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (when (and limit (not (and (integerp limit) (> limit 0))))
      (error "[list] limit must be a positive integer, but got: ~S" limit))
    (let* ((index-file (and (eq normalized-mode :online)
                            (%hub-index-file home)))
           (all-items
             (if (eq normalized-mode :online)
                 (%hub-list-online-items (%hub-load-index home "list"))
                 (%hub-list-local-items home)))
           (items (%hub-list-limit-items all-items limit))
           (result (list :mode normalized-mode
                         :scope normalized-scope
                         :home (%directory-namestring home)
                         :index-file (and index-file
                                          (han.path:->namestring index-file))
                         :limit limit
                         :total (length all-items)
                         :items items)))
      (when verbose
        (if json-p
            (format t "~A" (han.json:encode-json (%hub-list-json result)
                                                 :indent 2))
            (%hub-list-print-result result)))
      result)))
