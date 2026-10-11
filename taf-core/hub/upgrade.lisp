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
       (t (%hub-error "upgrade-kind"
                      :command label
                      :value (%hub-repr kind)))))
    (t
     (%hub-error "upgrade-kind"
                 :command label
                 :value (%hub-repr kind)))))

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
      (%hub-error "index-missing-object"
                  :command label
                  :field "packages"))
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
      (let ((record (han.json:get-json versions latest-version-id)))
        (when (and (han.json:json-object-p record)
                   (string= latest-version-id
                            (%hub-install-record-version-id record latest-version-id)))
          record)))))

(defun %hub-upgrade-entry-same-source-p (entry package-entry)
  (let* ((versions (%hub-json-ref package-entry "versions"))
         (record (and (han.json:json-object-p versions)
                      (han.json:get-json versions (getf entry :version-id))))
         (repository (or (and (han.json:json-object-p record)
                              (%hub-json-string record "repository_url"))
                         (%hub-json-string package-entry "repository_url")))
         (installed (%hub-upgrade-entry-metadata-string entry "repository_url")))
    (and (string= (or (%hub-upgrade-entry-origin-kind entry) "") "hub-index")
         (%hub-non-empty-string-p repository)
         installed (string= repository installed))))

(defun %hub-upgrade-entry-valid-p (entry)
  "Read-only validation before treating a retained installation as usable."
  (eql (getf (%hub-diagnose-entry entry) :state) :verified))

(defun %hub-upgrade-check-plan (items scope)
  (let ((problems (remove-if-not
                   (lambda (item)
                     (and (not (member (getf item :status) '(:local-project :missing-index)))
                          (member (getf (getf item :validation) :state) '(:invalid :unknown))))
                   items)))
    (when problems
      (%hub-error "maintenance-diagnostics"
                  :details (%hub-diagnostic-summary-text
                            (mapcar (lambda (item) (getf item :validation)) problems) scope))))
  items)

(defun %hub-upgrade-index-item (package-name package-entry)
  (let* ((latest-version-id (%hub-json-string package-entry "latest"))
         (record (%hub-upgrade-latest-record package-entry)))
    (when (han.json:json-object-p package-entry)
      (list :package-name package-name
            :package-entry package-entry
            :latest-version-id latest-version-id
            :record record
            :kind (or (%hub-upgrade-record-kind record)
                      (%hub-upgrade-record-kind
                       (%hub-list-online-record package-entry latest-version-id
                                                (%hub-package-version-ids package-entry))))
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
    (t
     (multiple-value-bind (order reliable-p)
         (%compare-version-ids latest-version local-version)
       (unless (and reliable-p (not (zerop order)))
         (%hub-error "maintenance-order" :local local-version :latest latest-version))
       (if (plusp order) :outdated :ahead)))))

(defun %hub-upgrade-plan-item (group packages requested-kind)
  (let* ((package-name (car group))
         (entries (cdr group))
         (newest (%hub-upgrade-newest-entry entries))
         (package-entry (%hub-upgrade-package-entry packages package-name))
         (kind (%hub-upgrade-entry-kind newest package-entry)))
    ;; Excluded packages must not trigger validation or version-order errors.
    (unless (%hub-upgrade-kind-match-p kind requested-kind)
      (return-from %hub-upgrade-plan-item nil))
    (let* ((latest-version-id (and package-entry
                                  (%hub-json-string package-entry "latest")))
           (latest-record (and package-entry
                               (%hub-upgrade-latest-record package-entry)))
           (latest-entry (find latest-version-id entries :test #'equal
                               :key (lambda (entry) (getf entry :version-id))))
           (local-project-p (some #'%hub-upgrade-local-project-entry-p entries))
           (same-source-p (and package-entry
                               (every (lambda (entry)
                                        (%hub-upgrade-entry-same-source-p entry package-entry))
                                      entries)))
           (validation (%hub-diagnose-entry (or latest-entry newest)))
           (status (cond
                     (local-project-p :local-project)
                     ((not (and latest-record same-source-p)) :missing-index)
                     (latest-entry :current)
                     (latest-record
                      ;; No automatic downgrade if any local version is ahead.
                      (dolist (entry entries)
                        (%hub-upgrade-package-status (getf entry :version-id) latest-version-id))
                      (%hub-upgrade-package-status (getf newest :version-id)
                                                   latest-version-id))
                     (t :missing-index)))
           (action (if (eql status :outdated) :install-latest :skip))
           (reason (case status
                     (:outdated "local version is older than index latest")
                     (:current "local latest matches index latest")
                     (:ahead "local latest is newer than index latest")
                     (:missing-index "no usable index latest or matching install source")
                     (:local-project "local-project install is private and is not upgraded from the public index")
                     (t nil))))
      (list :package-name package-name
            :kind kind
            :command-name (or (and package-entry
                                   latest-record
                                   (%hub-record-command-name package-entry
                                                             latest-record))
                              (getf newest :command-base))
            :installed-version-id (getf (or latest-entry newest) :version-id)
            :installed-versions (%hub-upgrade-installed-version-ids entries)
            :latest-version-id latest-version-id
            :artifact-name (getf (or latest-entry newest) :artifact-name)
            :origin-kind (%hub-upgrade-entry-origin-kind (or latest-entry newest))
            :validation validation
            :status status
            :action action
            :reason reason))))

(defun %hub-upgrade-missing-target-item (item)
  (list :query (getf item :query)
        :version-id (getf item :version-id)
        :status :not-installed
        :action :skip
        :reason "target is not installed"))

(defun %hub-upgrade-diagnostic-entries (groups packages requested-kind)
  (loop for group in groups
        for entries = (cdr group)
        for newest = (%hub-upgrade-newest-entry entries)
        for package = (%hub-upgrade-package-entry packages (car group))
        when (%hub-upgrade-kind-match-p (%hub-upgrade-entry-kind newest package) requested-kind)
          collect (or (find (and package (%hub-json-string package "latest")) entries
                            :test #'equal :key (lambda (entry) (getf entry :version-id)))
                      newest)))

(defun %hub-upgrade-plan-items (home index requested-kind targets label)
  (let* ((entries (%hub-uninstall-installed-entries home))
         (packages (%hub-upgrade-packages-object index label)))
    (multiple-value-bind (groups missing)
        (%hub-upgrade-target-groups entries targets label)
      (%hub-call-with-diagnostic-batch
       (%hub-upgrade-diagnostic-entries groups packages requested-kind)
       (lambda ()
         (append
          (remove nil
                  (mapcar (lambda (group)
                            (%hub-upgrade-plan-item group packages requested-kind))
                          groups))
          (mapcar #'%hub-upgrade-missing-target-item missing)))))))

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
   (cons "validation" (%hub-diagnostic-json-value (getf item :validation)))
   (cons "validations" (%hub-diagnostic-json-value (getf item :validations)))
   (cons "status" (%hub-upgrade-status-string (getf item :status)))
   (cons "action" (%hub-upgrade-status-string (getf item :action)))
   (cons "reason" (%hub-upgrade-string-or-null (getf item :reason)))
   (cons "install_result"
         (%hub-diagnostic-json-value (getf item :install-result)))
   (cons "remove_versions"
         (%hub-upgrade-list-or-null (getf item :remove-versions)))
   (cons "removed"
         (%hub-diagnostic-json-value (getf item :removed)))))

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
              (%hub-message "value.unknown")))
  (when (getf item :kind)
    (format t "  ~A" (getf item :kind)))
  (format t "  ~A -> ~A  [~A]~%"
          (or (getf item :installed-version-id)
              (getf item :version-id)
              (%hub-message "value.none"))
          (or (getf item :latest-version-id) (%hub-message "value.none"))
          (%hub-status-display (getf item :status)))
  (%print-hub-info-field "action"
                         (%hub-status-display (getf item :action)))
  (%print-hub-info-field "reason"
                         (%hub-reason-display (getf item :reason)))
  (%print-hub-info-field
   "installed"
   (and (getf item :installed-versions)
        (format nil "~{~A~^, ~}" (getf item :installed-versions))))
  (%print-hub-info-field
   "remove"
   (and (getf item :remove-versions)
        (format nil "~{~A~^, ~}" (getf item :remove-versions)))))

(defun %hub-upgrade-display-item-p (item)
  (or (not (eql (getf item :action) :skip))
      (member (getf item :status) '(:missing-index :not-installed))))

(defun %hub-upgrade-display-items (items)
  (remove-if-not #'%hub-upgrade-display-item-p items))

(defun %hub-upgrade-print-result (result)
  (%operation-progress-yield)
  (let* ((operation (getf result :operation))
         (items (getf result :items))
         (display-items (%hub-upgrade-display-items items))
         (summary (getf result :summary)))
    (%hub-print-message "upgrade.header"
                        :operation (%hub-status-display operation)
                        :mode (%hub-message
                               (if (getf result :dry-run-p)
                                   "upgrade.mode.plan"
                                   "upgrade.mode.result")))
    (%print-hub-info-field "scope"
                           (string-downcase (string (getf result :scope))))
    (%print-hub-info-field "home" (getf result :home))
    (%print-hub-info-field "kind" (%hub-upgrade-status-string
                                    (getf result :kind)))
    (%print-hub-info-field "dry-run"
                           (%hub-status-display
                            (if (getf result :dry-run-p) :yes :no)))
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
       (%hub-print-message "upgrade.no-changes"))
      (t
       (%hub-print-message "upgrade.no-apps")))
    (write-string
     (%hub-diagnostic-summary-text
      (loop for item in items append
        (or (getf item :validations)
            (and (getf item :validation) (list (getf item :validation)))))
      (getf result :scope)))
    (when (getf result :prune-result)
      (let ((prune-summary (getf (getf result :prune-result) :summary)))
        (%print-hub-info-field
         "prune"
         (%hub-message "upgrade.prune-summary"
                       :count (getf prune-summary :prunable)))))
    (when (and (getf result :dry-run-p)
               (member operation '(:upgrade :install-all :prune)))
      (%print-hub-info-field "action"
                             (%hub-message "upgrade.apply-hint"))))
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
  (when *operation-total* (incf *operation-item*))
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
    (let* ((*hub-diagnostic-progress* (%hub-make-diagnostic-progress (and verbose (not json-p))))
           (requested-kind (%hub-upgrade-normalize-kind kind "outdated"))
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
    (%hub-call-with-diagnostic-batch
     (%hub-upgrade-diagnostic-entries
      (loop for item in index-items
            for group = (gethash (getf item :package-name) installed-table)
            when (and group (getf item :record)) collect group)
      (%hub-upgrade-packages-object index label) requested-kind)
     (lambda ()
       (dolist (index-item index-items)
         (let* ((package-name (getf index-item :package-name))
                (group (gethash package-name installed-table))
                (latest-version-id (getf index-item :latest-version-id)))
           (cond
             ((null (getf index-item :record))
              (push (list :package-name package-name
                          :kind (getf index-item :kind)
                          :latest-version-id latest-version-id
                          :installed-versions (%hub-upgrade-installed-version-ids (cdr group))
                          :status :missing-index :action :skip
                          :reason "no usable index latest or matching install source")
                    items))
             (group
             (let* ((base-item (%hub-upgrade-plan-item
                                group
                                (%hub-upgrade-packages-object index label)
                                requested-kind))
                    (status (getf base-item :status))
                    (action (case status
                              (:outdated :upgrade)
                              (otherwise :skip))))
               (setf (getf base-item :action) action)
               (push base-item items)))
             (t (push (list :package-name package-name
                         :kind (getf index-item :kind)
                         :command-name (getf index-item :command-name)
                         :installed-version-id nil
                         :installed-versions nil
                         :latest-version-id latest-version-id
                         :status :not-installed
                         :action :install
                         :reason "package is indexed but not installed")
                      items)))))
       (sort (nreverse items)
             #'string<
             :key (lambda (item) (or (getf item :package-name) "")))))))

(defun hub-install-all (&key
                          repair-p
                          all-installed-p
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
  (%with-operation-progress ((and verbose (not json-p)))
  (when (and all-installed-p (not repair-p))
    (%hub-error "repair-installed-requires-repair"))
  (when repair-p
    (when (or force-p prune-old-p) (%hub-error "repair-conflict"))
    (return-from hub-install-all
      (%hub-repair-install :all-p (not all-installed-p) :all-installed-p all-installed-p
                           :kind kind :scope scope
                           :user-home user-home :system-home system-home
                           :system-bin-dir system-bin-dir :dry-run-p (or dry-run-p (not yes-p))
                           :prompt-p prompt-p :json-p json-p :verbose verbose)))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (let* ((*hub-diagnostic-progress* (%hub-make-diagnostic-progress (and verbose (not json-p))))
           (requested-kind (%hub-upgrade-normalize-kind kind "install"))
           (effective-dry-run-p (or dry-run-p (not yes-p)))
           (system-bin-path (%taffish-system-bin-dir system-bin-dir))
           (index (%hub-load-index home "install"))
           (plan-items (%hub-install-all-plan-items home
                                                    index
                                                    requested-kind
                                                    "install"))
           (*operation-item* 0)
           (*operation-total* (count-if (lambda (item) (member (getf item :action) '(:install :upgrade))) plan-items))
           (items nil))
      (%hub-upgrade-check-plan plan-items normalized-scope)
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
                                             (and verbose (not json-p)))
                  item)
              items))
      (setf items (nreverse items))
      (let* ((prune-result
               (and prune-old-p
                    (not effective-dry-run-p)
                    (let ((targets (loop for item in items
                                         when (or (getf item :install-result)
                                                  (eql (getf item :status) :current))
                                           collect (list :query (getf item :package-name)))))
                      (when targets
                        (hub-prune :targets targets :scope normalized-scope
                               :user-home user-home-path
                               :system-home system-home-path
                               :kind requested-kind
                               :dry-run-p nil
                               :yes-p t
                               :verbose nil)))))
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
        result)))))

(defun %hub-repair-inventory-block (inspection reason)
  (let ((evidence (copy-list inspection)))
    ;; A record rejected before integrity checking is not a verified artifact.
    (unless (getf evidence :issues) (setf (getf evidence :state) :unknown))
    (list :query (or (getf inspection :package-name) "apps/")
          :requested-version-id (getf inspection :version-id)
          :action :blocked :blocked-p t :reason reason :validation evidence)))

(defun %hub-repair-prime-installed-paths (entries home scope system-bin)
  ;; Repair checks managed destinations as well as metadata paths. On macOS,
  ;; /var and /private/var can name the same ancestor; probe both spellings in
  ;; this read-only batch without changing keys or resolving away leaf links.
  (ignore-errors
    (let* ((bin (%taffish-command-bin-dir scope home system-bin))
           (canonical-home (%hub-installed-path-key home t))
           (canonical-bin (%hub-installed-path-key bin t)))
      (%hub-diagnostic-prime
       "properties"
       (append (list home bin canonical-home canonical-bin
                     (han.path:join-path canonical-home ".repair/"))
               (loop for parts = (pathname-directory (han.path:->pathname canonical-home))
                       then (butlast parts)
                     while parts collect (make-pathname :directory parts))
               (loop for entry in entries
                     unless (eq :unknown (getf (%hub-diagnostic-schema-issue entry) :state))
                       append
                       (ignore-errors
                         (let ((name (getf entry :package-name))
                               (version (getf entry :version-id))
                               (artifact (getf entry :artifact-name))
                               (command (getf entry :command-base)))
                           (when (every #'%hub-repair-path-part-p (list name version artifact command))
                             (cons (%taffish-home-dir canonical-home (format nil "apps/~A" name))
                                   (%hub-diagnostic-entry-paths
                                    (append (list :installation-home canonical-home)
                                            (%hub-install-paths canonical-home name version artifact
                                                                :bin-dir canonical-bin
                                                                :command-name command)))))))))))))

(defun %hub-repair-installed-plan (home scope user-home system-home system-bin kind)
  (let ((kind (%hub-upgrade-normalize-kind kind "install")))
    (multiple-value-bind (entries problems) (%hub-diagnose-installations home nil t)
      (multiple-value-bind (index-diagnostic index) (%hub-diagnose-index home)
        (let ((selected nil) (plans nil))
          ;; Failed enumeration is evidence too: never silently filter it away.
          (dolist (problem problems)
            (push (%hub-repair-inventory-block problem "unsafe-or-unreadable") plans))
          (dolist (entry entries)
            (let ((actual (%hub-upgrade-entry-metadata-string entry "kind")))
              (cond
                ((and (not (eq kind :all))
                      (not (member actual '("tool" "flow") :test #'equal)))
                 (push (%hub-repair-inventory-block
                        (%hub-diagnostic-result entry nil) "kind-unknown") plans))
                ((%hub-upgrade-kind-match-p actual kind) (push entry selected)))))
          (unless (or entries problems (eq (getf index-diagnostic :state) :verified))
            (push (%hub-repair-inventory-block index-diagnostic "index-target-invalid") plans))
          (%hub-call-with-diagnostic-batch
           selected
           (lambda ()
             (%hub-repair-prime-installed-paths selected home scope system-bin)
             (dolist (entry selected)
               (let* ((name (getf entry :package-name))
                      (version (getf entry :version-id))
                      (package (%hub-json-ref (%hub-json-ref index "packages") name))
                      (record (%hub-json-ref (%hub-json-ref package "versions") version)))
                 (push
                  (cond
                    ((not (equal (%hub-upgrade-entry-origin-kind entry) "hub-index"))
                     (%hub-repair-inventory-block (%hub-diagnostic-result entry nil)
                                                  "private-or-unknown-source"))
                    ((or (not (eq (getf index-diagnostic :state) :verified)) (null record))
                     (%hub-repair-inventory-block (%hub-diagnostic-result entry nil)
                                                  "index-target-invalid"))
                    (t
                     (%hub-repair-plan-one
                      :query name :version-id version :scope scope
                      :user-home user-home :system-home system-home :system-bin-dir system-bin
                      :index-record record :installed-entries entries))) plans)))))
          (list :operation :repair :scope scope :home (%directory-namestring home)
                :bin-dir (%taffish-command-bin-dir scope home system-bin)
                :all-installed-p t :selection :installed-all-versions :kind kind
                :plans (stable-sort plans #'string<
                                    :key (lambda (p) (format nil "~A/~A" (getf p :query)
                                                             (getf p :requested-version-id))))
                :skipped-not-installed 0))))))

(defun %hub-repair-plan (targets all-p kind scope user-home system-home system-bin
                         &optional all-installed-p)
  (when *hub-diagnostic-progress* (funcall *hub-diagnostic-progress* 0 0 :enumerate))
  (multiple-value-bind (scope user-home system-home home)
      (%hub-upgrade-home scope user-home system-home)
    (%hub-repair-check-unfinished home)
    (when all-installed-p
      (return-from %hub-repair-plan
        (%hub-repair-installed-plan home scope user-home system-home system-bin kind)))
    (multiple-value-bind (diagnostic index) (%hub-diagnose-index home)
      (unless (eq (getf diagnostic :state) :verified)
        (%hub-error "maintenance-diagnostics"
                    :details (%hub-diagnostic-text diagnostic scope)))
      (let* ((entries (%hub-uninstall-installed-entries home))
             (selected (if all-p
                           (loop for item in (%hub-upgrade-index-items index
                                               (%hub-upgrade-normalize-kind kind "install") "install")
                                 collect (list :query (getf item :package-name)
                                               :version-id (getf item :latest-version-id)))
                           (%hub-normalize-targets targets "install")))
             (seen (make-hash-table :test #'equal))
             (resolved-targets
               (loop for target in selected
                     for resolved = (%hub-resolve-info-target index (getf target :query)
                                                              (getf target :version-id) "install")
                     for key = (list (getf resolved :package-name) (getf resolved :version-id))
                     unless (gethash key seen)
                       collect resolved and do (setf (gethash key seen) t)))
             (selected-entries
               (remove-if-not (lambda (entry)
                                (gethash (list (getf entry :package-name) (getf entry :version-id)) seen))
                              entries))
             (plans nil) (not-installed 0))
        (%hub-call-with-diagnostic-batch
         selected-entries
         (lambda ()
           (dolist (resolved resolved-targets)
             (let* ((key (list (getf resolved :package-name) (getf resolved :version-id)))
                    (installed (find-if (lambda (entry)
                                          (and (equal (getf entry :package-name) (first key))
                                               (equal (getf entry :version-id) (second key)))) selected-entries)))
                 ;; All-repair migrates existing selected identities, not every
                 ;; historical install and not missing apps or dependencies.
                 (if (and all-p (not installed)
                          (handler-case
                              (let* ((apps (han.path:join-path home "apps/"))
                                     (package (han.path:join-path apps (%hub-install-safe-path-part (first key) "package")))
                                     (path (han.path:join-path (han.path:directory-pathname package)
                                                              (%hub-install-safe-path-part (second key) "version"))))
                                ;; Absence is known only if the managed ancestors
                                ;; are accessible and are not links or wrong types.
                                (and (notany (lambda (p) (%hub-repair-path-issue p t))
                                             (list apps package path))
                                     (not (or (%hub-diagnostic-test "-e" path)
                                              (%hub-diagnostic-test "-L" path)))))
                            (error () nil)))
                     (incf not-installed)
                     (push (%hub-repair-plan-one
                            :query (first key) :version-id (second key) :scope scope
                            :user-home user-home :system-home system-home :system-bin-dir system-bin
                            :index-record (getf resolved :record) :installed-entries entries)
                           plans))))))
        (list :operation :repair :scope scope :home (%directory-namestring home)
              :bin-dir (%taffish-command-bin-dir scope home system-bin)
              :all-p all-p :kind kind :targets targets
              :selection (if all-p :index-latest :explicit) :plans (nreverse plans)
              :skipped-not-installed not-installed)))))

(defun %hub-repair-public-result (result)
  (let ((plans (getf result :plans)))
    (append
     (list :schema-version "taffish.repair-plan/v1"
           :operation :repair :scope (getf result :scope) :home (getf result :home)
           :selection (getf result :selection)
           :dry-run-p (getf result :dry-run-p)
           :summary (list :total (length plans)
                          :repair (count :repair plans :key (lambda (p) (getf p :action)))
                          :skip (count :skip plans :key (lambda (p) (getf p :action)))
                          :blocked (count-if (lambda (p) (getf p :blocked-p)) plans)
                          :skipped-not-installed (getf result :skipped-not-installed))
           :items (coerce (loop for plan in plans
                        for resolved = (getf plan :resolved-result)
                        collect (list :package-name (or (getf resolved :package-name) (getf plan :query))
                                      :version-id (or (getf resolved :version-id) (getf plan :requested-version-id))
                                      :action (getf plan :action) :blocked-p (getf plan :blocked-p)
                                      :reason (getf plan :reason) :validation (getf plan :validation)
                                      :validations (coerce (getf plan :validations) 'vector)
                                      :detail (getf plan :detail))) 'vector))
     (when (getf result :applied) (list :applied (getf result :applied))))))

(defun %hub-repair-print-plan (result)
  (%operation-progress-yield)
  (let* ((public (%hub-repair-public-result result))
         (summary (getf public :summary))
         (groups (make-hash-table :test #'equal)))
    (%hub-print-message (format nil "repair.scope.~(~A~)" (getf result :selection))
                        :scope (string-downcase (string (getf result :scope)))
                        :kind (string-downcase (string (getf result :kind))))
    (%hub-print-message "repair.summary" :total (getf summary :total)
                        :repair (getf summary :repair) :skip (getf summary :skip)
                        :blocked (getf summary :blocked)
                        :absent (getf summary :skipped-not-installed))
    (loop for item across (getf public :items) do
      (unless (eq (getf item :action) :skip)
        (push (format nil "~A ~A" (getf item :package-name) (getf item :version-id))
              (gethash (list (getf item :action) (getf item :reason)) groups))))
    (dolist (key (sort (loop for key being the hash-keys of groups collect key) #'string< :key #'prin1-to-string))
      (let ((names (sort (gethash key groups) #'string<)))
        (format t "  ~A [~A] (~D): ~{~A~^, ~}~A~%    ~A~%"
                (%hub-status-display (first key)) (second key) (length names)
                (mapcar #'%hub-diagnostic-brief (subseq names 0 (min 3 (length names))))
                (if (> (length names) 3) ", ..." "")
                (%hub-message (concatenate 'string "repair.reason." (second key))))))
    (when (getf result :dry-run-p)
      (%hub-print-message "repair.preview")
      (cond
        ((or (getf result :all-p) (getf result :all-installed-p))
         (%hub-print-message "repair.preview-batch"
                             :selector (if (getf result :all-installed-p) "--all-installed" "--all")
                             :scope (string-downcase (string (getf result :scope)))
                             :kind (string-downcase (string (getf result :kind)))))
        (t (%hub-print-message "repair.preview-explicit"))))
    (when (getf result :applied)
      (%hub-print-message "repair.completed"
                          :count (count :repaired (getf result :applied)
                                        :key (lambda (item) (getf item :action))))
      (%print-display-fields
       (list (list (%hub-message "repair.records")
                   (%directory-namestring (han.path:join-path (getf result :home) ".repair/")))
             (list (%hub-message "repair.entry-backups")
                   (han.path:->namestring (getf result :bin-dir))))))
    (when (plusp (getf summary :blocked))
      (%hub-print-message "repair.blocked-hint" :scope (string-downcase (string (getf result :scope))))))
  nil)

(defun %hub-repair-install (&key targets all-p all-installed-p (kind :all) (scope :user)
                               user-home system-home system-bin-dir dry-run-p prompt-p json-p (verbose t))
  (%with-operation-progress ((and verbose (not json-p)))
  (let* ((*hub-diagnostic-progress* (%hub-make-diagnostic-progress (and verbose (not json-p))))
         (bin (%taffish-system-bin-dir system-bin-dir))
         (result (%hub-repair-plan targets all-p kind scope user-home system-home bin all-installed-p)))
    (setf (getf result :dry-run-p) dry-run-p)
    (unless dry-run-p
      (when (some (lambda (p) (getf p :blocked-p)) (getf result :plans))
        (%hub-error "repair-batch-blocked"
                    :details (with-output-to-string (*standard-output*) (%hub-repair-print-plan result))))
      (when (find :repair (getf result :plans) :key (lambda (p) (getf p :action)))
        (%hub-call-with-write-locks
         (getf result :home) (getf result :bin-dir)
         (lambda ()
           ;; Rebuild the complete plan under the lock. Never reuse read-only
           ;; probe caches across a write, including between repaired targets.
           (%operation-stage "locked-check")
           (let ((*hub-diagnostic-progress* nil))
             (setf result (%hub-repair-plan targets all-p kind scope user-home system-home bin all-installed-p)))
           (when (some (lambda (p) (getf p :blocked-p)) (getf result :plans))
             (%hub-error "repair-batch-blocked"
                         :details (with-output-to-string (*standard-output*) (%hub-repair-print-plan result))))
           (let ((applied nil)
                 (total (count :repair (getf result :plans) :key (lambda (p) (getf p :action)))))
             (handler-case
                 (dolist (plan (getf result :plans))
                   (when (eq (getf plan :action) :repair)
                     (setf (getf plan :prompt-p) prompt-p)
                     (let ((*operation-item* (1+ (length applied)))
                           (*operation-total* total))
                       (%operation-stage "verify" :target (getf plan :artifact-name))
                       (push (%hub-repair-apply-one plan) applied))))
               (error (condition)
                 (%operation-progress-yield)
                 (when *hub-diagnostic-progress*
                   (funcall *hub-diagnostic-progress* (length applied) total :repair-failed))
                 (%hub-error "repair-partial" :count (length applied) :detail (princ-to-string condition)
                             :records (%directory-namestring (han.path:join-path (getf result :home) ".repair/"))
                             :bin (han.path:->namestring (getf result :bin-dir)))))
             (%operation-progress-yield)
             (when *hub-diagnostic-progress*
               (funcall *hub-diagnostic-progress* (length applied) total :repair-done))
             (setf (getf result :applied) (nreverse applied)))))))
    (when verbose
      (if json-p
          (format t "~A~%" (han.json:encode-json (%hub-diagnostic-json-value (%hub-repair-public-result result))))
          (%hub-repair-print-plan result)))
    (%hub-repair-public-result result))))

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
  (%with-operation-progress ((and verbose (not json-p)))
  (multiple-value-bind (normalized-scope user-home-path system-home-path home)
      (%hub-upgrade-home scope user-home system-home)
    (let* ((*hub-diagnostic-progress* (%hub-make-diagnostic-progress (and verbose (not json-p))))
           (requested-kind (%hub-upgrade-normalize-kind kind "upgrade"))
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
           (*operation-item* 0)
           (*operation-total* (count :install-latest plan-items :key (lambda (item) (getf item :action))))
           (items nil))
      (%hub-upgrade-check-plan plan-items normalized-scope)
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
                                             (and verbose (not json-p)))
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
        result)))))

(defun %hub-prune-item (group requested-kind packages)
  (let* ((package-name (car group))
         (entries (cdr group))
         (package-entry (%hub-upgrade-package-entry packages package-name))
         (latest (and package-entry (%hub-json-string package-entry "latest")))
         (record (and package-entry (%hub-upgrade-latest-record package-entry)))
         (keep (and latest (find latest entries :test #'equal
                                :key (lambda (entry) (getf entry :version-id)))))
         (display-entry (or keep (%hub-upgrade-newest-entry entries)))
         (kind (%hub-upgrade-entry-kind display-entry package-entry))
         (private-p (some #'%hub-upgrade-local-project-entry-p entries))
         (validations (mapcar #'%hub-diagnose-entry entries))
         (usable-p (and (not private-p) record keep
                        (%hub-upgrade-entry-same-source-p keep package-entry)
                        (every (lambda (v) (eql (getf v :state) :verified)) validations)))
         (remove-entries
           (when usable-p
             (remove-if-not
              (lambda (entry)
                (and (not (eq entry keep))
                     (%hub-upgrade-entry-same-source-p entry package-entry)
                     (multiple-value-bind (order reliable-p)
                         (%compare-version-ids (getf entry :version-id) latest)
                       (and reliable-p (minusp order)))))
              entries)))
         (status (cond (private-p :local-project)
                       ((null record) :missing-index)
                       ((not usable-p) :not-installed)
                       (remove-entries :outdated)
                       (t :current)))
         (reason (cond
                   (private-p "local-project versions are protected from index pruning")
                   ((null record) "no usable index latest or matching install source")
                   ((some (lambda (v) (not (eql (getf v :state) :verified))) validations)
                    "installation evidence is incomplete or invalid; package is protected from pruning")
                   ((not usable-p) "index latest is not a valid same-source installation; nothing is removed")
                   (remove-entries "older same-source versions can be removed; index latest is retained")
                   (t "no safely removable versions; index latest and protected versions are retained"))))
    (when (%hub-upgrade-kind-match-p kind requested-kind)
      (list :package-name package-name
            :kind kind
            :command-name (getf display-entry :command-base)
            :installed-version-id (getf display-entry :version-id)
            :installed-versions (%hub-upgrade-installed-version-ids entries)
            :latest-version-id latest
            :artifact-name (getf display-entry :artifact-name)
            :origin-kind (%hub-upgrade-entry-origin-kind display-entry)
            :validations validations
            :status status
            :action (if remove-entries :remove-old :skip)
            :reason reason
            :keep-entry keep
            :remove-entries remove-entries
            :remove-versions (mapcar (lambda (entry)
                                       (getf entry :version-id))
                                     remove-entries)))))

(defun %hub-prune-apply-item-with-home (item home dry-run-p)
  (flet ((perform-prune ()
    (let ((removed nil)
        (keep (getf item :keep-entry)))
    (unless dry-run-p
      (dolist (entry (cons keep (getf item :remove-entries)))
        (let* ((fresh (%hub-uninstall-read-entry home (getf entry :metadata-file)))
               (validation (if fresh (%hub-diagnose-entry fresh)
                               (%hub-diagnostic-result entry
                                (list (%hub-diagnostic-issue "metadata-invalid" :unknown
                                                              (getf entry :metadata-file)))))))
          (unless (eql (getf validation :state) :verified)
            (%hub-error "maintenance-diagnostics"
                        :details (%hub-diagnostic-text validation (or (getf item :scope) :user)))))))
    (dolist (entry (getf item :remove-entries))
      (unless dry-run-p (%operation-stage "remove" :target (getf entry :artifact-name)))
      (push (%hub-uninstall-delete-entry entry dry-run-p) removed))
    (unless dry-run-p
      (%hub-install-refresh-command-alias home
                                          (getf keep :command-base)
                                          (getf keep :bin-dir)))
    (append (list :removed (nreverse removed)
                  :action-applied-p (and (not dry-run-p)
                                         (not (null removed))))
            item))))
    (let ((keep (getf item :keep-entry)))
      (if dry-run-p
          (perform-prune)
          (progn
            (when (or (null keep) (%hub-installed-path-problem keep))
              (%hub-error "unsafe-installed-path" :path (getf keep :metadata-file)))
            (dolist (entry (getf item :remove-entries))
              (when (%hub-installed-path-problem entry)
                (%hub-error "unsafe-installed-path" :path (getf entry :metadata-file))))
            (%hub-call-with-write-locks
             home (mapcar (lambda (entry) (getf entry :bin-dir))
                          (cons keep (getf item :remove-entries)))
             #'perform-prune))))))

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
  (%with-operation-progress ((and verbose (not json-p)))
  (%operation-stage "prune")
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
        (let ((items nil) (*operation-item* 0) (*operation-total* (length groups)))
          (dolist (group groups)
            (incf *operation-item*)
            (let ((item (%hub-prune-item group requested-kind packages)))
              (when item
                (setf (getf item :scope) normalized-scope)
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
            result)))))))
