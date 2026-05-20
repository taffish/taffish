(in-package :taf.core)

;;;; ============================================================
;;;; hub / upgrade.lisp
;;;; ============================================================

(defun %hub-upgrade-normalize-kind (kind label)
  (cond
    ((or (null kind) (eql kind :all)) :all)
    ((and (keywordp kind)
          (member kind '(:tool :flow :all)))
     kind)
    ((stringp kind)
     (cond
       ((string-equal kind "tool") :tool)
       ((string-equal kind "tools") :tool)
       ((string-equal kind "flow") :flow)
       ((string-equal kind "flows") :flow)
       ((string-equal kind "all") :all)
       (t (error "[~A] kind must be tool, flow, or all, but got: ~S"
                 label kind))))
    (t
     (error "[~A] kind must be tool, flow, or all, but got: ~S"
            label kind))))

(defun %hub-upgrade-kind-string (kind)
  (string-downcase (string kind)))

(defun %hub-upgrade-kind-match-p (actual requested)
  (or (eql requested :all)
      (and actual
           (string-equal actual (%hub-upgrade-kind-string requested)))))

(defun %hub-upgrade-status-string (status)
  (string-downcase
   (substitute #\_ #\-
               (etypecase status
                 (keyword (symbol-name status))
                 (symbol (symbol-name status))))))

(defun %hub-upgrade-entry-metadata-string (entry key)
  (let ((metadata (getf entry :metadata)))
    (and (han.json:json-object-p metadata)
         (%hub-json-string metadata key))))

(defun %hub-upgrade-entry-origin-kind (entry)
  (%hub-upgrade-entry-metadata-string entry "origin_kind"))

(defun %hub-upgrade-local-project-entry-p (entry)
  (string-equal (or (%hub-upgrade-entry-origin-kind entry) "")
                "local-project"))

(defun %hub-upgrade-source-kind (source-dir)
  (and source-dir
       (handler-case
           (let ((project (project-check source-dir nil nil)))
             (string-downcase (string (getf project :kind))))
         (error () nil))))

(defun %hub-upgrade-record-kind (record)
  (and (han.json:json-object-p record)
       (%hub-json-string record "kind")))

(defun %hub-upgrade-entry-kind (entry package-entry)
  (or (%hub-upgrade-entry-metadata-string entry "kind")
      (let ((versions (and (han.json:json-object-p package-entry)
                           (%hub-json-ref package-entry "versions")))
            (version-id (getf entry :version-id)))
        (and (han.json:json-object-p versions)
             version-id
             (%hub-upgrade-record-kind
              (han.json:get-json versions version-id))))
      (and (han.json:json-object-p package-entry)
           (%hub-upgrade-record-kind
            (%hub-list-online-record package-entry
                                     (%hub-json-string package-entry "latest")
                                     (%hub-package-version-ids package-entry))))
      (%hub-upgrade-source-kind (getf entry :source-dir))))

(defun %hub-upgrade-packages-object (index label)
  (let ((packages (%hub-json-ref index "packages")))
    (unless (han.json:json-object-p packages)
      (error "[~A] index is missing object field: packages" label))
    packages))

(defun %hub-upgrade-package-entry (packages package-name)
  (when (han.json:json-object-p packages)
    (multiple-value-bind (entry present-p)
        (han.json:get-json packages package-name)
      (and present-p
           (han.json:json-object-p entry)
           entry))))

(defun %hub-upgrade-latest-record (package-entry)
  (let* ((latest-version-id (%hub-json-string package-entry "latest"))
         (versions (%hub-json-ref package-entry "versions")))
    (when (and latest-version-id
               (han.json:json-object-p versions))
      (han.json:get-json versions latest-version-id))))

(defun %hub-upgrade-index-item (package-name package-entry)
  (let* ((latest-version-id (%hub-json-string package-entry "latest"))
         (record (%hub-upgrade-latest-record package-entry)))
    (when (and latest-version-id
               (han.json:json-object-p record))
      (list :package-name package-name
            :package-entry package-entry
            :latest-version-id latest-version-id
            :record record
            :kind (%hub-upgrade-record-kind record)
            :command-name (%hub-record-command-name package-entry record)))))

(defun %hub-upgrade-index-items (index requested-kind label)
  (let ((packages (%hub-upgrade-packages-object index label))
        (items nil))
    (maphash
     (lambda (package-name package-entry)
       (let ((item (%hub-upgrade-index-item package-name package-entry)))
         (when (and item
                    (%hub-upgrade-kind-match-p (getf item :kind)
                                               requested-kind))
           (push item items))))
     packages)
    (sort (nreverse items)
          #'string<
          :key (lambda (item) (or (getf item :package-name) "")))))

(defun %hub-upgrade-group-installed-entries (entries)
  (let ((table (make-hash-table :test #'equal))
        (groups nil))
    (dolist (entry entries)
      (let ((package-name (getf entry :package-name)))
        (when (%hub-non-empty-string-p package-name)
          (push entry (gethash package-name table)))))
    (maphash
     (lambda (package-name package-entries)
       (push (cons package-name
                   (sort package-entries
                         #'%hub-version-id-newer-p
                         :key (lambda (entry)
                                (or (getf entry :version-id) ""))))
             groups))
     table)
    (sort groups #'string< :key #'car)))

(defun %hub-upgrade-newest-entry (entries)
  (first (sort (copy-list entries)
               #'%hub-version-id-newer-p
               :key (lambda (entry) (or (getf entry :version-id) "")))))

(defun %hub-upgrade-installed-version-ids (entries)
  (mapcar (lambda (entry) (getf entry :version-id))
          (sort (copy-list entries)
                #'%hub-version-id-newer-p
                :key (lambda (entry) (or (getf entry :version-id) "")))))

(defun %hub-upgrade-entry-target-match-p (entry target)
  (%hub-uninstall-entry-match-p entry
                                (getf target :query)
                                (%hub-normalize-version-id
                                 (getf target :version-id))))

(defun %hub-upgrade-target-groups (entries targets label)
  (declare (ignore label))
  (if (null targets)
      (values (%hub-upgrade-group-installed-entries entries) nil)
      (let ((selected-table (make-hash-table :test #'equal))
            (missing nil))
        (dolist (target targets)
          (let ((matches
                  (remove-if-not
                   (lambda (entry)
                     (%hub-upgrade-entry-target-match-p entry target))
                   entries)))
            (if matches
                (dolist (match matches)
                  (setf (gethash (getf match :package-name) selected-table) t))
                (push (list :query (getf target :query)
                            :version-id (%hub-normalize-version-id
                                         (getf target :version-id))
                            :status :not-installed
                            :action :skip
                            :reason "target is not installed")
                      missing))))
        (values
         (remove-if-not
          (lambda (group)
            (gethash (car group) selected-table))
          (%hub-upgrade-group-installed-entries entries))
         (nreverse missing)))))

(defun %hub-upgrade-package-status (local-version latest-version)
  (cond
    ((null latest-version) :missing-index)
    ((string= local-version latest-version) :current)
    ((%hub-version-id-newer-p latest-version local-version) :outdated)
    (t :ahead)))

(defun %hub-upgrade-plan-item (group packages requested-kind)
  (let* ((package-name (car group))
         (entries (cdr group))
         (newest (%hub-upgrade-newest-entry entries))
         (package-entry (%hub-upgrade-package-entry packages package-name))
         (latest-version-id (and package-entry
                                 (%hub-json-string package-entry "latest")))
         (latest-record (and package-entry
                             (%hub-upgrade-latest-record package-entry)))
         (kind (%hub-upgrade-entry-kind newest package-entry))
         (local-project-p (%hub-upgrade-local-project-entry-p newest))
         (status (cond
                   (local-project-p :local-project)
                   (package-entry
                    (%hub-upgrade-package-status (getf newest :version-id)
                                                 latest-version-id))
                   (t :missing-index)))
         (action (if (eql status :outdated) :install-latest :skip))
         (reason (case status
                   (:outdated "local version is older than index latest")
                   (:current "local latest matches index latest")
                   (:ahead "local latest is newer than index latest")
                   (:missing-index "installed package is not present in local index")
                   (:local-project "local-project install is private and is not upgraded from the public index")
                   (t nil))))
    (when (%hub-upgrade-kind-match-p kind requested-kind)
      (list :package-name package-name
            :kind kind
            :command-name (or (and package-entry
                                   latest-record
                                   (%hub-record-command-name package-entry
                                                             latest-record))
                              (getf newest :command-base))
            :installed-version-id (getf newest :version-id)
            :installed-versions (%hub-upgrade-installed-version-ids entries)
            :latest-version-id latest-version-id
            :artifact-name (getf newest :artifact-name)
            :origin-kind (%hub-upgrade-entry-origin-kind newest)
            :status status
            :action action
            :reason reason))))

(defun %hub-upgrade-missing-target-item (item)
  (list :query (getf item :query)
        :version-id (getf item :version-id)
        :status :not-installed
        :action :skip
        :reason "target is not installed"))

(defun %hub-upgrade-plan-items (home index requested-kind targets label)
  (let* ((entries (%hub-uninstall-installed-entries home))
         (packages (%hub-upgrade-packages-object index label)))
    (multiple-value-bind (groups missing)
        (%hub-upgrade-target-groups entries targets label)
      (append
       (remove nil
               (mapcar (lambda (group)
                         (%hub-upgrade-plan-item group packages requested-kind))
                       groups))
       (mapcar #'%hub-upgrade-missing-target-item missing)))))

(defun %hub-upgrade-status-count (items status)
  (count-if (lambda (item) (eql (getf item :status) status)) items))

(defun %hub-upgrade-action-count (items action)
  (count-if (lambda (item) (eql (getf item :action) action)) items))

(defun %hub-upgrade-summary (items)
  (list :total (length items)
        :outdated (%hub-upgrade-status-count items :outdated)
        :current (%hub-upgrade-status-count items :current)
        :ahead (%hub-upgrade-status-count items :ahead)
        :missing-index (%hub-upgrade-status-count items :missing-index)
        :local-project (%hub-upgrade-status-count items :local-project)
        :not-installed (%hub-upgrade-status-count items :not-installed)
        :installable (%hub-upgrade-action-count items :install-latest)
        :install (%hub-upgrade-action-count items :install)
        :upgrade (%hub-upgrade-action-count items :upgrade)
        :skip (%hub-upgrade-action-count items :skip)
        :prunable (%hub-upgrade-action-count items :remove-old)))

(defun %hub-upgrade-vector (items encoder)
  (coerce (mapcar encoder items) 'vector))

(defun %hub-upgrade-list-or-null (value)
  (if value
      (coerce value 'vector)
      :null))

(defun %hub-upgrade-string-or-null (value)
  (or value :null))

(defun %hub-upgrade-item-json (item)
  (han.json:json-object
   (cons "query" (%hub-upgrade-string-or-null (getf item :query)))
   (cons "package_name" (%hub-upgrade-string-or-null (getf item :package-name)))
   (cons "kind" (%hub-upgrade-string-or-null (getf item :kind)))
   (cons "command_name" (%hub-upgrade-string-or-null (getf item :command-name)))
   (cons "installed_version_id"
         (%hub-upgrade-string-or-null (getf item :installed-version-id)))
   (cons "installed_versions"
         (%hub-upgrade-list-or-null (getf item :installed-versions)))
   (cons "latest_version_id"
         (%hub-upgrade-string-or-null (getf item :latest-version-id)))
   (cons "artifact_name" (%hub-upgrade-string-or-null (getf item :artifact-name)))
   (cons "origin_kind" (%hub-upgrade-string-or-null (getf item :origin-kind)))
   (cons "status" (%hub-upgrade-status-string (getf item :status)))
   (cons "action" (%hub-upgrade-status-string (getf item :action)))
   (cons "reason" (%hub-upgrade-string-or-null (getf item :reason)))
   (cons "install_result"
         (or (getf item :install-result) :null))
   (cons "remove_versions"
         (%hub-upgrade-list-or-null (getf item :remove-versions)))
   (cons "removed"
         (%hub-upgrade-list-or-null (getf item :removed)))))

(defun %hub-upgrade-result-json (result)
  (let ((summary (getf result :summary)))
    (han.json:json-object
     (cons "schema_version" "taffish.package-plan/v1")
     (cons "operation" (%hub-upgrade-status-string (getf result :operation)))
     (cons "scope" (string-downcase (string (getf result :scope))))
     (cons "home" (%hub-upgrade-string-or-null (getf result :home)))
     (cons "kind" (%hub-upgrade-status-string (getf result :kind)))
     (cons "dry_run" (not (null (getf result :dry-run-p))))
     (cons "yes" (not (null (getf result :yes-p))))
     (cons "prune_old" (not (null (getf result :prune-old-p))))
     (cons "summary"
           (han.json:json-object
            (cons "total" (getf summary :total))
            (cons "outdated" (getf summary :outdated))
            (cons "current" (getf summary :current))
            (cons "ahead" (getf summary :ahead))
            (cons "missing_index" (getf summary :missing-index))
            (cons "local_project" (getf summary :local-project))
            (cons "not_installed" (getf summary :not-installed))
            (cons "installable" (getf summary :installable))
            (cons "install" (getf summary :install))
            (cons "upgrade" (getf summary :upgrade))
            (cons "skip" (getf summary :skip))
            (cons "prunable" (getf summary :prunable))))
     (cons "items"
           (%hub-upgrade-vector (getf result :items)
                                #'%hub-upgrade-item-json))
     (cons "prune_result"
           (let ((prune-result (getf result :prune-result)))
             (if prune-result
                 (%hub-upgrade-result-json prune-result)
                 :null))))))

(defun %hub-upgrade-print-item (item index)
  (format t "  ~2D. ~A" index
          (or (getf item :package-name)
              (getf item :query)
              "<unknown>"))
  (when (getf item :kind)
    (format t "  ~A" (getf item :kind)))
  (format t "  ~A -> ~A  [~A]~%"
          (or (getf item :installed-version-id)
              (getf item :version-id)
              "<none>")
          (or (getf item :latest-version-id) "<none>")
          (%hub-upgrade-status-string (getf item :status)))
  (%print-hub-info-field "action"
                         (%hub-upgrade-status-string (getf item :action)))
  (%print-hub-info-field "reason" (getf item :reason))
  (%print-hub-info-field
   "installed"
   (and (getf item :installed-versions)
        (format nil "~{~A~^, ~}" (getf item :installed-versions))))
  (%print-hub-info-field
   "remove"
   (and (getf item :remove-versions)
        (format nil "~{~A~^, ~}" (getf item :remove-versions)))))

(defun %hub-upgrade-display-item-p (item)
  (not (eql (getf item :action) :skip)))

(defun %hub-upgrade-display-items (items)
  (remove-if-not #'%hub-upgrade-display-item-p items))

(defun %hub-upgrade-print-result (result)
  (let* ((operation (getf result :operation))
         (items (getf result :items))
         (display-items (%hub-upgrade-display-items items))
         (summary (getf result :summary)))
    (format t "[TAF] ~A ~A~%"
            (%hub-upgrade-status-string operation)
            (if (getf result :dry-run-p) "plan" "result"))
    (%print-hub-info-field "scope"
                           (string-downcase (string (getf result :scope))))
    (%print-hub-info-field "home" (getf result :home))
    (%print-hub-info-field "kind" (%hub-upgrade-status-string
                                    (getf result :kind)))
    (%print-hub-info-field "dry-run" (if (getf result :dry-run-p) "yes" "no"))
    (%print-hub-info-field "found" (getf summary :total))
    (%print-hub-info-field "outdated" (getf summary :outdated))
    (%print-hub-info-field "installable" (getf summary :installable))
    (%print-hub-info-field "install" (getf summary :install))
    (%print-hub-info-field "upgrade" (getf summary :upgrade))
    (%print-hub-info-field "prunable" (getf summary :prunable))
    (cond
      (display-items
        (loop for item in display-items
              for i from 1 do
                (%hub-upgrade-print-item item i)))
      (items
       (format t "  no changes~%"))
      (t
       (format t "  no apps~%")))
    (when (getf result :prune-result)
      (let ((prune-summary (getf (getf result :prune-result) :summary)))
        (%print-hub-info-field
         "prune"
         (format nil "~A package group(s) had old versions removed"
                 (getf prune-summary :prunable)))))
    (when (and (getf result :dry-run-p)
               (member operation '(:upgrade :install-all :prune)))
      (%print-hub-info-field "action" "rerun with --yes to apply")))
  nil)

(defun %hub-upgrade-home (scope user-home system-home)
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (values normalized-scope user-home-path system-home-path home)))

(defun %hub-upgrade-install-item (item scope user-home system-home system-bin-dir force-p prompt-p verbose)
  (let ((result (hub-install :query (getf item :package-name)
                             :version-id (getf item :latest-version-id)
                             :scope scope
                             :user-home user-home
                             :system-home system-home
                             :system-bin-dir system-bin-dir
                             :force-p force-p
                             :dry-run-p nil
                             :prompt-p prompt-p
                             :verbose verbose)))
    (append (list :install-result result
                  :action-applied-p t)
            item)))

(defun hub-outdated (&key
                       targets
                       (scope :user)
                       user-home
                       system-home
                       (kind :all)
                       json-p
                       (verbose t))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (declare (ignore user-home-path system-home-path))
    (let* ((requested-kind (%hub-upgrade-normalize-kind kind "outdated"))
           (index (%hub-load-index home "outdated"))
           (target-items (and targets
                              (%hub-normalize-targets targets "outdated")))
           (items (%hub-upgrade-plan-items home
                                           index
                                           requested-kind
                                           target-items
                                           "outdated"))
           (result (list :operation :outdated
                         :scope normalized-scope
                         :home (%directory-namestring home)
                         :kind requested-kind
                         :dry-run-p t
                         :yes-p nil
                         :targets target-items
                         :items items
                         :summary (%hub-upgrade-summary items))))
      (when verbose
        (if json-p
            (format t "~A" (han.json:encode-json
                             (%hub-upgrade-result-json result)
                             :indent 2))
            (%hub-upgrade-print-result result)))
      result)))

(defun %hub-install-all-plan-items (home index requested-kind label)
  (let* ((index-items (%hub-upgrade-index-items index requested-kind label))
         (installed-groups (%hub-upgrade-group-installed-entries
                            (%hub-uninstall-installed-entries home)))
         (installed-table (make-hash-table :test #'equal))
         (items nil))
    (dolist (group installed-groups)
      (setf (gethash (car group) installed-table) group))
    (dolist (index-item index-items)
      (let* ((package-name (getf index-item :package-name))
             (group (gethash package-name installed-table))
             (latest-version-id (getf index-item :latest-version-id)))
        (if group
          (let* ((base-item (%hub-upgrade-plan-item
                             group
                             (%hub-upgrade-packages-object index label)
                             requested-kind))
                 (status (getf base-item :status))
                 (action (case status
                           (:outdated :upgrade)
                           (otherwise :skip))))
            (push (append (list :action action)
                          base-item)
                  items))
          (push (list :package-name package-name
                      :kind (getf index-item :kind)
                      :command-name (getf index-item :command-name)
                      :installed-version-id nil
                      :installed-versions nil
                      :latest-version-id latest-version-id
                      :status :not-installed
                      :action :install
                      :reason "package is indexed but not installed")
                items))))
    (sort (nreverse items)
          #'string<
          :key (lambda (item) (or (getf item :package-name) "")))))

(defun hub-install-all (&key
                          (scope :user)
                          user-home
                          system-home
                          system-bin-dir
                          (kind :all)
                          force-p
                          dry-run-p
                          yes-p
                          prompt-p
                          prune-old-p
                          json-p
                          (verbose t))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (let* ((requested-kind (%hub-upgrade-normalize-kind kind "install"))
           (effective-dry-run-p (or dry-run-p (not yes-p)))
           (system-bin-path (%taffish-system-bin-dir system-bin-dir))
           (index (%hub-load-index home "install"))
           (plan-items (%hub-install-all-plan-items home
                                                    index
                                                    requested-kind
                                                    "install"))
           (items nil))
      (dolist (item plan-items)
        (push (if (and (not effective-dry-run-p)
                       (member (getf item :action) '(:install :upgrade)))
                  (%hub-upgrade-install-item item
                                             normalized-scope
                                             user-home-path
                                             system-home-path
                                             system-bin-path
                                             force-p
                                             prompt-p
                                             verbose)
                  item)
              items))
      (setf items (nreverse items))
      (let* ((prune-result
               (and prune-old-p
                    (not effective-dry-run-p)
                    (hub-prune :scope normalized-scope
                               :user-home user-home-path
                               :system-home system-home-path
                               :kind requested-kind
                               :dry-run-p nil
                               :yes-p t
                               :verbose nil)))
             (result (list :operation :install-all
                           :scope normalized-scope
                           :home (%directory-namestring home)
                           :kind requested-kind
                           :dry-run-p effective-dry-run-p
                           :yes-p yes-p
                           :force-p force-p
                           :prune-old-p prune-old-p
                           :prune-result prune-result
                           :items items
                           :summary (%hub-upgrade-summary items))))
        (when verbose
          (if json-p
              (format t "~A" (han.json:encode-json
                               (%hub-upgrade-result-json result)
                               :indent 2))
              (%hub-upgrade-print-result result)))
        result))))

(defun hub-upgrade (&key
                      targets
                      (scope :user)
                      user-home
                      system-home
                      system-bin-dir
                      (kind :all)
                      force-p
                      dry-run-p
                      yes-p
                      prompt-p
                      prune-old-p
                      json-p
                      (verbose t))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (let* ((requested-kind (%hub-upgrade-normalize-kind kind "upgrade"))
           (effective-dry-run-p (or dry-run-p (not yes-p)))
           (system-bin-path (%taffish-system-bin-dir system-bin-dir))
           (index (%hub-load-index home "upgrade"))
           (target-items (and targets
                              (%hub-normalize-targets targets "upgrade")))
           (plan-items (%hub-upgrade-plan-items home
                                                index
                                                requested-kind
                                                target-items
                                                "upgrade"))
           (items nil))
      (dolist (item plan-items)
        (push (if (and (not effective-dry-run-p)
                       (eql (getf item :action) :install-latest))
                  (%hub-upgrade-install-item item
                                             normalized-scope
                                             user-home-path
                                             system-home-path
                                             system-bin-path
                                             force-p
                                             prompt-p
                                             verbose)
                  item)
              items))
      (setf items (nreverse items))
      (let* ((upgrade-packages
               (remove nil
                       (mapcar (lambda (item)
                                 (and (eql (getf item :action)
                                           :install-latest)
                                      (getf item :package-name)))
                               plan-items)))
             (prune-targets
               (and upgrade-packages
                    (mapcar (lambda (name)
                              (list :query name :version-id nil))
                            upgrade-packages)))
             (prune-result
               (and prune-old-p
                    (not effective-dry-run-p)
                    prune-targets
                    (hub-prune :targets prune-targets
                               :scope normalized-scope
                               :user-home user-home-path
                               :system-home system-home-path
                               :kind requested-kind
                               :dry-run-p nil
                               :yes-p t
                               :verbose nil)))
             (result (list :operation :upgrade
                           :scope normalized-scope
                           :home (%directory-namestring home)
                           :kind requested-kind
                           :dry-run-p effective-dry-run-p
                           :yes-p yes-p
                           :force-p force-p
                           :prune-old-p prune-old-p
                           :prune-result prune-result
                           :targets target-items
                           :items items
                           :summary (%hub-upgrade-summary items))))
        (when verbose
          (if json-p
              (format t "~A" (han.json:encode-json
                               (%hub-upgrade-result-json result)
                               :indent 2))
              (%hub-upgrade-print-result result)))
        result))))

(defun %hub-prune-item (group requested-kind packages)
  (let* ((package-name (car group))
         (entries (cdr group))
         (keep (%hub-upgrade-newest-entry entries))
         (package-entry (%hub-upgrade-package-entry packages package-name))
         (kind (%hub-upgrade-entry-kind keep package-entry))
         (remove-entries
           (remove-if (lambda (entry)
                        (string= (getf entry :version-id)
                                 (getf keep :version-id)))
                      entries)))
    (when (%hub-upgrade-kind-match-p kind requested-kind)
      (list :package-name package-name
            :kind kind
            :command-name (getf keep :command-base)
            :installed-version-id (getf keep :version-id)
            :installed-versions (%hub-upgrade-installed-version-ids entries)
            :latest-version-id (getf keep :version-id)
            :artifact-name (getf keep :artifact-name)
            :origin-kind (%hub-upgrade-entry-origin-kind keep)
            :status (if remove-entries :outdated :current)
            :action (if remove-entries :remove-old :skip)
            :reason (if remove-entries
                        "older locally installed versions can be removed"
                        "only one local version is installed")
            :keep-entry keep
            :remove-entries remove-entries
            :remove-versions (mapcar (lambda (entry)
                                       (getf entry :version-id))
                                     remove-entries)))))

(defun %hub-prune-apply-item-with-home (item home dry-run-p)
  (let ((removed nil)
        (keep (getf item :keep-entry)))
    (dolist (entry (getf item :remove-entries))
      (push (%hub-uninstall-delete-entry entry dry-run-p) removed))
    (unless dry-run-p
      (%hub-install-refresh-command-alias home
                                          (getf keep :command-base)
                                          (getf keep :bin-dir)))
    (append (list :removed (nreverse removed)
                  :action-applied-p (and (not dry-run-p)
                                         (not (null removed))))
            item)))

(defun hub-prune (&key
                    targets
                    (scope :user)
                    user-home
                    system-home
                    (kind :all)
                    dry-run-p
                    yes-p
                    json-p
                    (verbose t))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (declare (ignore user-home-path system-home-path))
    (let* ((requested-kind (%hub-upgrade-normalize-kind kind "prune"))
           (effective-dry-run-p (or dry-run-p (not yes-p)))
           (index (ignore-errors (%hub-load-index home "prune")))
           (packages (and index (%hub-upgrade-packages-object index "prune")))
           (entries (%hub-uninstall-installed-entries home))
           (target-items (and targets
                              (%hub-normalize-targets targets "prune"))))
      (multiple-value-bind (groups missing)
          (%hub-upgrade-target-groups entries target-items "prune")
        (let ((items nil))
          (dolist (group groups)
            (let ((item (%hub-prune-item group requested-kind packages)))
              (when item
                (push (if (and (not effective-dry-run-p)
                               (eql (getf item :action) :remove-old))
                          (%hub-prune-apply-item-with-home item
                                                           home
                                                           nil)
                          item)
                      items))))
          (dolist (item missing)
            (push (%hub-upgrade-missing-target-item item) items))
          (let* ((ordered-items (sort (nreverse items)
                                      #'string<
                                      :key (lambda (item)
                                             (or (getf item :package-name) ""))))
                 (result (list :operation :prune
                               :scope normalized-scope
                               :home (%directory-namestring home)
                               :kind requested-kind
                               :dry-run-p effective-dry-run-p
                               :yes-p yes-p
                               :targets target-items
                               :items ordered-items
                               :summary (%hub-upgrade-summary ordered-items))))
            (when verbose
              (if json-p
                  (format t "~A" (han.json:encode-json
                                   (%hub-upgrade-result-json result)
                                   :indent 2))
                  (%hub-upgrade-print-result result)))
            result))))))
