(in-package :taf.core)

;;;; ============================================================
;;;; hub / search.lisp
;;;; ============================================================

(defparameter *hub-search-default-limit* 20)

(defun %hub-search-ws-p (char)
  (member char '(#\Space #\Tab #\Newline #\Return) :test #'char=))

(defun %hub-search-split-query (query)
  (unless (%hub-non-empty-string-p query)
    (error "[search] keyword missing."))
  (let ((terms nil)
        (start nil))
    (labels ((emit (end)
               (when start
                 (let ((term (subseq query start end)))
                   (when (%hub-non-empty-string-p term)
                     (push (string-downcase term) terms)))
                 (setf start nil))))
      (loop for i from 0 below (length query)
            for char = (char query i) do
              (if (%hub-search-ws-p char)
                  (emit i)
                  (unless start
                    (setf start i))))
      (emit (length query)))
    (let ((result (nreverse terms)))
      (unless result
        (error "[search] keyword missing."))
      result)))

(defun %hub-search-string (value)
  (cond
    ((null value) nil)
    ((eq value :null) nil)
    ((stringp value) value)
    (t (princ-to-string value))))

(defun %hub-search-lower (value)
  (let ((string (%hub-search-string value)))
    (and string (string-downcase string))))

(defun %hub-search-contains-p (needle haystack)
  (let ((n (%hub-search-lower needle))
        (h (%hub-search-lower haystack)))
    (and n h (not (null (search n h :test #'char=))))))

(defun %hub-search-prefix-p (prefix string)
  (let ((p (%hub-search-lower prefix))
        (s (%hub-search-lower string)))
    (and p s
         (<= (length p) (length s))
         (string= p (subseq s 0 (length p))))))

(defun %hub-search-field-values (package-name package-entry record)
  (let* ((package-command (%hub-json-ref package-entry "command"))
         (record-command (%hub-json-ref record "command"))
         (runtime (%hub-json-ref record "runtime"))
         (paths (%hub-json-ref record "paths"))
         (container (%hub-json-ref record "container"))
         (source (%hub-json-ref record "source")))
    (remove nil
            (list package-name
                  (%hub-json-string package-entry "name")
                  (%hub-json-string package-entry "latest")
                  (%hub-json-string package-entry "repository_url")
                  (and (han.json:json-object-p package-command)
                       (%hub-json-string package-command "name"))
                  (%hub-json-string record "name")
                  (%hub-json-string record "kind")
                  (%hub-json-string record "version")
                  (%hub-json-integer-string record "release")
                  (%hub-json-string record "version_id")
                  (%hub-json-string record "tag")
                  (%hub-json-string record "license")
                  (%hub-json-string record "repository_url")
                  (%hub-json-string record "repository_slug")
                  (and (han.json:json-object-p record-command)
                       (%hub-json-string record-command "name"))
                  (and (han.json:json-object-p runtime)
                       (%hub-json-bool-string runtime "pipe"))
                  (and (han.json:json-object-p runtime)
                       (%hub-json-bool-string runtime "command_mode"))
                  (and (han.json:json-object-p paths)
                       (%hub-json-string paths "main"))
                  (and (han.json:json-object-p paths)
                       (%hub-json-string paths "help"))
                  (and (han.json:json-object-p paths)
                       (%hub-json-string paths "dockerfile"))
                  (and (han.json:json-object-p container)
                       (%hub-json-string container "image"))
                  (and (han.json:json-object-p container)
                       (%hub-json-string container "dockerfile"))
                  (and (han.json:json-object-p container)
                       (%hub-json-string container "image_tag"))
                  (and (han.json:json-object-p source)
                       (%hub-json-string source "repository"))
                  (and (han.json:json-object-p source)
                       (%hub-json-string source "ref"))
                  (and (han.json:json-object-p source)
                       (%hub-json-string source "commit"))
                  (and (han.json:json-object-p source)
                       (%hub-json-string source "html_url"))))))

(defun %hub-search-all-terms-match-p (terms fields)
  (every (lambda (term)
           (some (lambda (field)
                   (%hub-search-contains-p term field))
                 fields))
         terms))

(defun %hub-search-score-one-field (term field base)
  (cond
    ((not (%hub-search-contains-p term field)) 0)
    ((string= (%hub-search-lower term) (%hub-search-lower field))
     (+ base 300))
    ((%hub-search-prefix-p term field)
     (+ base 180))
    (t base)))

(defun %hub-search-score (terms package-name package-entry record)
  (let* ((package-command (%hub-json-ref package-entry "command"))
         (record-command (%hub-json-ref record "command"))
         (command-name (or (and (han.json:json-object-p record-command)
                                (%hub-json-string record-command "name"))
                           (and (han.json:json-object-p package-command)
                                (%hub-json-string package-command "name"))))
         (kind (%hub-json-string record "kind"))
         (version-id (%hub-json-string record "version_id"))
         (repo (or (%hub-json-string record "repository_slug")
                   (%hub-json-string record "repository_url")))
         (container (%hub-json-ref record "container"))
         (image (and (han.json:json-object-p container)
                     (%hub-json-string container "image"))))
    (loop for term in terms
          sum (+ (%hub-search-score-one-field term package-name 700)
                 (%hub-search-score-one-field term command-name 600)
                 (%hub-search-score-one-field term kind 180)
                 (%hub-search-score-one-field term version-id 120)
                 (%hub-search-score-one-field term repo 90)
                 (%hub-search-score-one-field term image 60)))))

(defun %hub-search-match-json (match)
  (han.json:json-object
   (cons "name" (getf match :name))
   (cons "kind" (or (getf match :kind) :null))
   (cons "version_id" (or (getf match :version-id) :null))
   (cons "command" (or (getf match :command) :null))
   (cons "repository_url" (or (getf match :repository-url) :null))
   (cons "container_image" (or (getf match :container-image) :null))))

(defun %hub-search-match< (a b)
  (let ((score-a (or (getf a :score) 0))
        (score-b (or (getf b :score) 0))
        (name-a (or (getf a :name) ""))
        (name-b (or (getf b :name) "")))
    (if (= score-a score-b)
        (string< name-a name-b)
        (> score-a score-b))))

(defun %hub-search-package (package-name package-entry terms)
  (unless (han.json:json-object-p package-entry)
    (return-from %hub-search-package nil))
  (let* ((versions (%hub-json-ref package-entry "versions"))
         (latest-version-id (%hub-json-string package-entry "latest"))
         (record (and (han.json:json-object-p versions)
                      latest-version-id
                      (han.json:get-json versions latest-version-id))))
    (unless (han.json:json-object-p record)
      (setf record package-entry))
    (let ((fields (%hub-search-field-values package-name package-entry record)))
      (when (%hub-search-all-terms-match-p terms fields)
        (let* ((command (%hub-json-ref record "command"))
               (container (%hub-json-ref record "container")))
          (list :name package-name
                :kind (%hub-json-string record "kind")
                :version-id (or (%hub-json-string record "version_id")
                                latest-version-id)
                :command (and (han.json:json-object-p command)
                              (%hub-json-string command "name"))
                :repository-url (or (%hub-json-string record "repository_url")
                                    (%hub-json-string package-entry
                                                      "repository_url"))
                :container-image (and (han.json:json-object-p container)
                                      (%hub-json-string container "image"))
                :score (%hub-search-score terms
                                          package-name
                                          package-entry
                                          record)
                :record record))))))

(defun %hub-search-limit-results (matches limit)
  (cond
    ((null limit) matches)
    ((<= (length matches) limit) matches)
    (t
     (subseq matches 0 limit))))

(defun %print-hub-search-result (result)
  (let ((matches (getf result :matches))
        (total (getf result :total)))
    (format t "[TAF] search: ~A~%" (getf result :query))
    (%print-hub-info-field "scope"
                           (string-downcase (string (getf result :scope))))
    (%print-hub-info-field "index" (getf result :index-file))
    (%print-hub-info-field "found" total)
    (%print-hub-info-field "showing" (length matches))
    (if matches
        (loop for match in matches
              for i from 1 do
                (format t "  ~2D. ~A" i (getf match :name))
                (when (getf match :command)
                  (format t "  ~A" (getf match :command)))
                (when (getf match :kind)
                  (format t "  ~A" (getf match :kind)))
                (when (getf match :version-id)
                  (format t "  ~A" (getf match :version-id)))
                (format t "~%")
                (when (getf match :container-image)
                  (format t "      image: ~A~%" (getf match :container-image)))
                (when (getf match :repository-url)
                  (format t "      repo : ~A~%" (getf match :repository-url))))
        (format t "  no matches~%")))
  nil)

(defun hub-search (&key
                     query
                     (scope :user)
                     user-home
                     system-home
                     (limit *hub-search-default-limit*)
                     json-p
                     (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (index-file (%hub-index-file home))
         (index (%hub-load-index home "search"))
         (packages (%hub-json-ref index "packages"))
         (terms (%hub-search-split-query query)))
    (unless (han.json:json-object-p packages)
      (error "[search] index is missing object field: packages"))
    (let* ((matches
             (sort
              (remove nil
                      (mapcar
                       (lambda (package-name)
                         (%hub-search-package
                          package-name
                          (han.json:get-json packages package-name)
                          terms))
                       (han.json:json-keys packages)))
              #'%hub-search-match<))
           (shown (%hub-search-limit-results matches limit))
           (result (list :scope normalized-scope
                         :home (%directory-namestring home)
                         :index-file (han.path:->namestring index-file)
                         :query query
                         :terms terms
                         :total (length matches)
                         :limit limit
                         :matches shown)))
      (when verbose
        (if json-p
            (format t "~A"
                    (han.json:encode-json
                     (coerce (mapcar #'%hub-search-match-json shown) 'vector)
                     :indent 2))
            (%print-hub-search-result result)))
      result)))
