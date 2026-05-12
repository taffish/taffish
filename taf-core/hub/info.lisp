(in-package :taf.core)

;;;; ============================================================
;;;; hub / info.lisp
;;;; ============================================================

(defun %hub-json-ref (object key &optional default)
  (han.json:get-json object key default))

(defun %hub-json-string (object key &optional default)
  (let ((value (%hub-json-ref object key default)))
    (cond
      ((eq value :null) nil)
      ((or (stringp value) (null value)) value)
      (t (princ-to-string value)))))

(defun %hub-json-integer-string (object key &optional default)
  (let ((value (%hub-json-ref object key default)))
    (cond
      ((null value) nil)
      ((eq value :null) nil)
      ((integerp value) (princ-to-string value))
      ((stringp value) value)
      (t (princ-to-string value)))))

(defun %hub-json-bool-string (object key)
  (multiple-value-bind (value present-p)
      (han.json:get-json object key)
    (if present-p
        (if value "yes" "no")
        "<unknown>")))

(defun %hub-normalize-version-id (version-id)
  (cond
    ((null version-id) nil)
    ((and (stringp version-id)
          (> (length version-id) 1)
          (char= (char version-id 0) #\v))
     (subseq version-id 1))
    (t version-id)))

(defun %hub-normalize-target (target label)
  (cond
    ((stringp target)
     (list :query target :version-id nil))
    ((and (consp target)
          (%hub-non-empty-string-p (getf target :query)))
     (list :query (getf target :query)
           :version-id (getf target :version-id)))
    (t
     (error "[~A] invalid target: ~S" label target))))

(defun %hub-normalize-targets (targets label)
  (let ((items (mapcar (lambda (target)
                         (%hub-normalize-target target label))
                       targets)))
    (unless items
      (error "[~A] app name or command name missing." label))
    items))

(defun %hub-json-array-from-list (items)
  (coerce items 'vector))

(defun %hub-index-file (home)
  (%hub-index-current-file home))

(defun %hub-load-index (home &optional (label "info"))
  (let ((file (%hub-index-file home)))
    (unless (han.path:file-exists-p file)
      (error "[~A] local TAFFISH index does not exist: ~A~%Run `taf update` first."
             label
             (han.path:->namestring file)))
    (let ((index (han.json:read-json-file file)))
      (unless (han.json:json-object-p index)
        (error "[~A] local TAFFISH index is not a JSON object: ~A"
               label
               (han.path:->namestring file)))
      (unless (string= (or (%hub-json-string index "schema_version") "")
                       "taffish.index/v1")
        (error "[~A] unsupported TAFFISH index schema: ~A"
               label
               (or (%hub-json-string index "schema_version")
                   "<missing>")))
      index)))

(defun %hub-object-keys-string (object)
  (if (han.json:json-object-p object)
      (format nil "~{~A~^, ~}" (han.json:json-keys object))
      ""))

(defun %hub-record-command-name (package-entry record)
  (let ((record-command (%hub-json-ref record "command"))
        (package-command (%hub-json-ref package-entry "command")))
    (or (and (han.json:json-object-p record-command)
             (%hub-json-string record-command "name"))
        (and (han.json:json-object-p package-command)
             (%hub-json-string package-command "name")))))

(defun %hub-record-artifact-name (package-entry record)
  (let ((command-name (%hub-record-command-name package-entry record))
        (version (%hub-json-string record "version"))
        (release (%hub-json-integer-string record "release")))
    (and (%hub-non-empty-string-p command-name)
         (%hub-non-empty-string-p version)
         (%hub-non-empty-string-p release)
         (format nil "~A-v~A-r~A" command-name version release))))

(defun %hub-version-id-info (version-id)
  (and (%hub-non-empty-string-p version-id)
       (%publish-release-info-from-tag (format nil "v~A" version-id))))

(defun %hub-version-id-newer-p (a b)
  (let ((a-info (%hub-version-id-info a))
        (b-info (%hub-version-id-info b)))
    (cond
      ((and a-info b-info)
       (> (%publish-compare-version-release
           (getf a-info :version)
           (getf a-info :release)
           (getf b-info :version)
           (getf b-info :release))
          0))
      (a-info t)
      (b-info nil)
      (t (string> a b)))))

(defun %hub-package-version-ids (package-entry)
  (let ((versions (%hub-json-ref package-entry "versions")))
    (when (han.json:json-object-p versions)
      (sort (copy-list (han.json:json-keys versions))
            #'%hub-version-id-newer-p))))

(defun %hub-format-version-list
    (version-ids latest-version-id selected-version-id)
  (format nil "~{~A~^, ~}"
          (mapcar
           (lambda (version-id)
             (let ((marks nil))
               (when (and latest-version-id
                          (string= version-id latest-version-id))
                 (push "latest" marks))
               (when (and selected-version-id
                          (string= version-id selected-version-id)
                          (not (and latest-version-id
                                    (string= version-id latest-version-id))))
                 (push "selected" marks))
               (if marks
                   (format nil "~A [~{~A~^, ~}]" version-id (nreverse marks))
                   version-id)))
           version-ids)))

(defun %hub-find-artifact-target (packages query)
  (let ((found nil))
    (maphash
     (lambda (package-name package-entry)
       (when (and (null found)
                  (han.json:json-object-p package-entry))
         (let ((versions (%hub-json-ref package-entry "versions")))
           (when (han.json:json-object-p versions)
             (maphash
              (lambda (version-id record)
                (when (and (null found)
                           (han.json:json-object-p record)
                           (string= query
                                    (or (%hub-record-artifact-name
                                         package-entry record)
                                        "")))
                  (setf found
                        (list :package-name package-name
                              :package-entry package-entry
                              :version-id version-id
                              :record record))))
              versions)))))
     packages)
    found))

(defun %hub-resolve-info-target
    (index query requested-version-id &optional (label "info"))
  (unless (%hub-non-empty-string-p query)
    (error "[~A] app name or command name missing." label))
  (let* ((packages (%hub-json-ref index "packages"))
         (commands (%hub-json-ref index "commands"))
         (normalized-version-id (%hub-normalize-version-id requested-version-id)))
    (unless (han.json:json-object-p packages)
      (error "[~A] index is missing object field: packages" label))
    (unless (han.json:json-object-p commands)
      (error "[~A] index is missing object field: commands" label))
    (multiple-value-bind (package-entry package-present-p)
        (han.json:get-json packages query)
      (let* ((command-entry nil)
             (command-present-p nil)
             (query-kind nil)
             (package-name nil)
             (default-version-id nil))
        (if package-present-p
            (setf query-kind :package
                  package-name query
                  default-version-id (%hub-json-string package-entry "latest"))
            (multiple-value-setq (command-entry command-present-p)
              (han.json:get-json commands query)))
        (when command-present-p
          (unless (han.json:json-object-p command-entry)
            (error "[~A] command entry is not an object: ~A" label query))
          (setf query-kind :command
                package-name (%hub-json-string command-entry "package")
                default-version-id (%hub-json-string command-entry "version"))
          (multiple-value-setq (package-entry package-present-p)
            (han.json:get-json packages package-name)))
        (when (and (not package-present-p)
                   (not command-present-p))
          (let ((artifact (%hub-find-artifact-target packages query)))
            (when artifact
              (setf query-kind :artifact
                    package-name (getf artifact :package-name)
                    package-entry (getf artifact :package-entry)
                    package-present-p t
                    default-version-id (getf artifact :version-id)))))
        (unless package-present-p
          (error "[~A] can't find TAFFISH app or command in local index: ~A"
                 label query))
        (unless (han.json:json-object-p package-entry)
          (error "[~A] package entry is not an object: ~A" label package-name))
        (when (and (eq query-kind :artifact)
                   normalized-version-id
                   default-version-id
                   (not (string= normalized-version-id default-version-id)))
          (error "[~A] exact command ~A already contains version ~A, but VERSION-ID is ~A."
                 label query default-version-id normalized-version-id))
        (let* ((versions (%hub-json-ref package-entry "versions"))
               (version-id (or normalized-version-id
                               default-version-id
                               (%hub-json-string package-entry "latest"))))
          (unless (han.json:json-object-p versions)
            (error "[~A] package has no versions object: ~A" label package-name))
          (unless (%hub-non-empty-string-p version-id)
            (error "[~A] package has no latest version: ~A" label package-name))
          (multiple-value-bind (record present-p)
              (han.json:get-json versions version-id)
            (unless present-p
              (error "[~A] package ~A has no version ~A.~%Available versions: ~A"
                     label
                     package-name
                     version-id
                     (%hub-object-keys-string versions)))
            (unless (han.json:json-object-p record)
              (error "[~A] version record is not an object: ~A ~A"
                     label package-name version-id))
            (list :query query
                  :query-kind query-kind
                  :package-name package-name
                  :package-entry package-entry
                  :version-id version-id
                  :record record)))))))

(defun %print-hub-info-field (label value)
  (when (and value (not (eq value :null)))
    (format t "  ~15A : ~A~%" label value)))

(defun %hub-json-array-string (value)
  (cond
    ((or (null value) (eq value :null))
     nil)
    ((vectorp value)
     (format nil "~{~A~^, ~}" (loop for item across value collect item)))
    ((listp value)
     (format nil "~{~A~^, ~}" value))
    (t
     (princ-to-string value))))

(defun %hub-json-array-length (value)
  (cond
    ((or (null value) (eq value :null)) 0)
    ((or (vectorp value) (listp value)) (length value))
    (t 1)))

(defun %print-hub-info-result (result)
  (let* ((record (getf result :record))
         (package-entry (getf result :package-entry))
         (latest-version-id (%hub-json-string package-entry "latest"))
         (version-ids (%hub-package-version-ids package-entry))
         (command (%hub-json-ref record "command"))
         (runtime (%hub-json-ref record "runtime"))
         (paths (%hub-json-ref record "paths"))
         (container (%hub-json-ref record "container"))
         (smoke (%hub-json-ref record "smoke"))
         (source (%hub-json-ref record "source")))
    (format t "[TAF] app info: ~A~%" (getf result :package-name))
    (%print-hub-info-field "scope"
                           (string-downcase (string (getf result :scope))))
    (%print-hub-info-field "query"
                           (format nil "~A (~A)"
                                   (getf result :query)
                                   (string-downcase
                                    (string (getf result :query-kind)))))
    (%print-hub-info-field "index" (getf result :index-file))
    (%print-hub-info-field "latest" latest-version-id)
    (%print-hub-info-field
     "versions"
     (and version-ids
          (%hub-format-version-list
           version-ids
           latest-version-id
           (getf result :version-id))))
    (%print-hub-info-field "name" (%hub-json-string record "name"))
    (%print-hub-info-field "kind" (%hub-json-string record "kind"))
    (%print-hub-info-field "version" (%hub-json-string record "version"))
    (%print-hub-info-field "release" (%hub-json-integer-string record "release"))
    (%print-hub-info-field "version id" (%hub-json-string record "version_id"))
    (%print-hub-info-field "tag" (%hub-json-string record "tag"))
    (%print-hub-info-field "license" (%hub-json-string record "license"))
    (%print-hub-info-field "command"
                           (and (han.json:json-object-p command)
                                (%hub-json-string command "name")))
    (%print-hub-info-field "repository"
                           (%hub-json-string record "repository_url"))
    (%print-hub-info-field "repo slug"
                           (%hub-json-string record "repository_slug"))
    (when (han.json:json-object-p runtime)
      (%print-hub-info-field
       "runtime"
       (format nil "pipe=~A, command-mode=~A"
               (%hub-json-bool-string runtime "pipe")
               (%hub-json-bool-string runtime "command_mode"))))
    (when (han.json:json-object-p paths)
      (%print-hub-info-field "main" (%hub-json-string paths "main"))
      (%print-hub-info-field "help" (%hub-json-string paths "help"))
      (%print-hub-info-field "dockerfile" (%hub-json-string paths "dockerfile")))
    (when (han.json:json-object-p container)
      (%print-hub-info-field "container" (%hub-json-string container "image"))
      (%print-hub-info-field "image tag" (%hub-json-string container "image_tag"))
      (%print-hub-info-field "digest" (%hub-json-string container "digest"))
      (%print-hub-info-field
       "platforms"
       (%hub-json-array-string (%hub-json-ref container "platforms"))))
    (when (han.json:json-object-p smoke)
      (%print-hub-info-field
       "smoke"
       (format nil "~A, timeout=~A, exist=~A, test=~A"
               (or (%hub-json-string smoke "backend") "<unknown>")
               (or (%hub-json-integer-string smoke "timeout") "<unknown>")
               (%hub-json-array-length (%hub-json-ref smoke "exist"))
               (%hub-json-array-length (%hub-json-ref smoke "test"))))
      (%print-hub-info-field
       "smoke exist"
       (%hub-json-array-string (%hub-json-ref smoke "exist")))
      (%print-hub-info-field
       "smoke test"
       (%hub-json-array-string (%hub-json-ref smoke "test"))))
    (when (han.json:json-object-p source)
      (%print-hub-info-field "source ref" (%hub-json-string source "ref"))
      (%print-hub-info-field "source commit" (%hub-json-string source "commit"))
      (%print-hub-info-field "source url" (%hub-json-string source "html_url")))
    nil))

(defun hub-info (&key
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
                              :system-home system-home-path))
         (index-file (%hub-index-file home))
         (index (%hub-load-index home))
         (resolved (%hub-resolve-info-target index query version-id))
         (result (append (list :scope normalized-scope
                               :home (%directory-namestring home)
                               :index-file (han.path:->namestring index-file))
                         resolved)))
    (when verbose
      (if json-p
          (format t "~A" (han.json:encode-json (getf result :record)
                                               :indent 2))
          (%print-hub-info-result result)))
    result))

(defun hub-info-many (&key
                        targets
                        (scope :user)
                        user-home
                        system-home
                        json-p
                        (verbose t))
  (let* ((items (%hub-normalize-targets targets "info"))
         (results
           (mapcar (lambda (target)
                     (hub-info :query (getf target :query)
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
                    (mapcar (lambda (result)
                              (getf result :record))
                            results))
                   :indent 2))
          (loop for result in results
                for first-p = t then nil do
                  (unless first-p
                    (format t "~%"))
                  (%print-hub-info-result result))))
    summary))
