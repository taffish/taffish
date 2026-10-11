(in-package :taf.core)

;; Shared read-only evidence. Missing evidence never becomes a verified install.
(defvar *hub-diagnostic-programs* nil)
(defvar *hub-diagnostic-properties* nil)
(defvar *hub-diagnostic-listings* nil)
(defvar *hub-diagnostic-progress* nil)
(defvar *hub-diagnostic-completed* 0)
(defvar *hub-diagnostic-total* 0)
(defvar *hub-diagnostic-phase* :validate)

(defmacro %with-hub-diagnostic-probes (&body body)
  `(let ((*hub-diagnostic-properties* (or *hub-diagnostic-properties* (make-hash-table :test #'equal)))
         (*hub-diagnostic-listings* (or *hub-diagnostic-listings* (make-hash-table :test #'equal))))
     ,@body))

(defun %hub-diagnostic-path-key (path)
  (let ((name (string-right-trim "/" (han.path:->namestring path))))
    (if (equal name "") "/" name)))

(defparameter *hub-diagnostic-probe-script*
  "emit() {
  flags=
  for flag in -e -f -d -L -r -x; do
    if [ \"$flag\" \"$1\" ]; then flags=${flags}1; else flags=${flags}0; fi
  done
  printf 'F\\000%s\\000%s\\000' \"$1\" \"$flags\"
}
walk() {
  emit \"$1\"
  [ \"$2\" -lt \"$3\" ] || return 0
  if [ ! -d \"$1\" ] || [ ! -r \"$1\" ] || [ ! -x \"$1\" ]; then
    printf 'E\\000%s\\000access\\000' \"$1\"
    return 0
  fi
  printf 'D\\000%s\\000\\000' \"$1\"
  for child in \"$1\"/* \"$1\"/.[!.]* \"$1\"/..?*; do
    [ -e \"$child\" ] || [ -L \"$child\" ] || continue
    printf 'C\\000%s\\000%s\\000' \"$1\" \"$child\"
    if [ ! -L \"$child\" ] && [ -d \"$child\" ]; then
      walk \"$child\" \"$(( $2 + 1 ))\" \"$3\"
    else
      emit \"$child\"
    fi
  done
}
mode=$1
shift
for path do
  case $mode in
    properties) emit \"$path\" ;;
    children) walk \"$path\" 0 1 ;;
    tree) walk \"$path\" 0 129 ;;
    *) exit 2 ;;
  esac
done
")

(defun %hub-diagnostic-progress-tick ()
  (when *hub-diagnostic-progress*
    (funcall *hub-diagnostic-progress* *hub-diagnostic-completed* *hub-diagnostic-total*
             *hub-diagnostic-phase*)))

(defun %hub-diagnostic-progress-phase (phase)
  (setf *hub-diagnostic-phase* phase)
  (%hub-diagnostic-progress-tick))

(defun %hub-make-diagnostic-progress (enabled &optional (clock #'get-internal-real-time))
  (when enabled
    (let ((last (funcall clock)) (previous :validate) (printed nil)
          (terminal (ignore-errors
                      (and (han.host:standard-error-terminal-p)
                           (interactive-stream-p *error-output*)
                           (not (equal (han.host:getenv "TERM") "dumb"))))))
      (lambda (completed total &optional (phase :validate))
        ;; Progress must never turn a successful operation into an I/O failure.
        (when enabled
          (handler-case
              (let* ((now (funcall clock)) (finished (member phase '(:done :failed :repair-done :repair-failed)))
                     (changed (not (eql previous phase))))
                (when (or (and finished printed)
                          (and (not finished)
                               (or (and changed (or (not (eq phase :validate)) (plusp total)))
                                   (and (plusp total)
                                                (>= (- now last) internal-time-units-per-second)))))
                  (let ((text (if (eql phase :validate)
                                  (%hub-message "diagnostic.progress" :completed completed :total total)
                                  (%hub-message (format nil "diagnostic.phase.~(~A~)" phase)
                                                :completed completed :total total))))
                    (when terminal (format *error-output* "~C~C[K" #\Return (code-char 27)))
                    (write-string text *error-output*)
                    (when (or (not terminal) finished) (terpri *error-output*))
                    (finish-output *error-output*))
                  (setf last now printed t))
                (setf previous phase))
            (error () (setf enabled nil))))))))

(defun %hub-diagnostic-capture (shell mode paths)
  ;; Capture the protocol as UTF-8 explicitly, not the host's default text encoding.
  (loop repeat 100
        for path = (han.path:join-path
                    (han.host:temporary-directory)
                    (format nil "taffish-probe-~D-~36R-~36R.tmp"
                            (han.host:current-process-id) (get-internal-real-time)
                            (random (expt 2 64))))
        for stream = (open path :direction :output :if-exists nil
                                :if-does-not-exist :create :external-format :utf-8)
        when stream do
          (return-from %hub-diagnostic-capture
            (unwind-protect
                 (progn
                   (close stream)
                   (multiple-value-bind (out err code)
                       (han.os:run-program
                        (append (list shell "-c"
                                      (format nil "exec > \"$1\"~%shift~%~A"
                                              *hub-diagnostic-probe-script*)
                                      "taffish-file-probe" (namestring path) mode)
                                paths)
                        :output nil)
                     (declare (ignore out err))
                     (unless (eql code 0) (error "Cannot inspect installation paths."))
                     (with-open-file (in path :external-format :utf-8)
                       (han.host:with-character-output-to-string (text)
                         (loop for char = (read-char in nil nil) while char do
                           (write-char char text))))))
              (when (open-stream-p stream) (close stream))
              (delete-file path))))
  (error "Cannot allocate an installation probe capture file."))

(defun %hub-diagnostic-probe (mode paths)
  ;; Fixed script, argv-only paths, and NUL framing: filenames are never code.
  (let ((shell (%hub-diagnostic-program "sh")))
    (unless shell (error "The POSIX shell is unavailable."))
    (let ((out (%hub-diagnostic-capture shell mode paths)))
      (let ((fields nil) (start 0)
            (properties (make-hash-table :test #'equal))
            (listings (make-hash-table :test #'equal)))
        (loop for end = (position (code-char 0) out :start start) while end do
          (push (subseq out start end) fields)
          (setf start (1+ end)))
        (unless (and (= start (length out)) (zerop (mod (length fields) 3)))
          (error "Incomplete installation probe response."))
        (loop for (type path value) on (nreverse fields) by #'cdddr do
          (cond
            ((and (equal type "F") (= (length value) 6)
                  (every (lambda (c) (find c "01")) value))
             (setf (gethash path properties) value))
            ((and (equal type "D") (equal value "")) (setf (gethash path listings) nil))
            ((equal type "E") (setf (gethash path listings) :error))
            ((equal type "C")
             (multiple-value-bind (children present-p) (gethash path listings)
               (unless (and present-p (listp children)) (error "Invalid directory probe response."))
               (push value (gethash path listings))))
            (t (error "Invalid installation probe response."))))
        (dolist (path paths)
          (unless (and (gethash path properties)
                       (or (equal mode "properties") (nth-value 1 (gethash path listings))))
            (error "Missing installation probe result.")))
        ;; Publish only complete responses, never partially parsed evidence.
        (maphash (lambda (k v) (setf (gethash k *hub-diagnostic-properties*) v)) properties)
        (maphash (lambda (k v) (setf (gethash k *hub-diagnostic-listings*) v)) listings))))
  (%hub-diagnostic-progress-tick))

(defun %hub-diagnostic-prime (mode paths)
  ;; Bound UTF-8 argv bytes, including space for each argument pointer.
  (let ((seen (make-hash-table :test #'equal)) (batch nil) (size 0))
    (labels ((flush ()
               (when batch (%hub-diagnostic-probe mode (nreverse batch)))
               (setf batch nil size 0)))
      (dolist (path paths)
        (when path
          (let* ((key (%hub-diagnostic-path-key path))
                 (bytes (+ 16 (loop for char across key
                                    for code = (char-code char)
                                    sum (cond ((< code #x80) 1) ((< code #x800) 2)
                                              ((< code #x10000) 3) (t 4))))))
            (unless (gethash key seen)
              (when (and batch (> (+ size bytes) 65536)) (flush))
              (setf (gethash key seen) t)
              (push key batch)
              (incf size bytes)))))
      (flush))))

(defun %hub-diagnostic-entry-paths (entry)
  (let* ((command (getf entry :command-file))
         (source (getf entry :source-dir))
         (snapshot (and command (getf entry :artifact-name)
                        (han.path:join-path (han.path:parent-directory-pathname command)
                                            (format nil ".~A/" (getf entry :artifact-name))))))
    (append (loop for key in '(:metadata-file :install-root :source-dir :command-file
                              :launcher-file :command-launcher-file :bin-dir)
                  collect (getf entry key))
            (when (getf entry :installation-home)
              (list (%taffish-home-dir (getf entry :installation-home) "apps")))
            (when (getf entry :install-root)
              (list (han.path:parent-directory-pathname
                     (han.path:directory-pathname (getf entry :install-root)))))
            (when (getf entry :metadata-file)
              (list (han.path:parent-directory-pathname (getf entry :metadata-file))))
            (when source (list (han.path:join-path source "target/")))
            (when snapshot
              (mapcar (lambda (relative) (han.path:join-path snapshot relative))
                      '("" "taffish.toml" "src/" "docs/" "docs/help.md" ".taf-build.json"))))))

(defun %hub-diagnostic-schema-issue (entry)
  (let ((schema (han.json:get-json (getf entry :metadata) "schema_version" :missing)))
    (cond
      ((eq schema :missing)
       (%hub-diagnostic-issue "metadata-schema-missing" :unverified (getf entry :metadata-file)))
      ((not (equal schema "taffish.install/v1"))
       (%hub-diagnostic-issue "metadata-schema" :unknown (getf entry :metadata-file))))))

(defun %hub-call-with-diagnostic-batch (entries function)
  ;; This scope ends before any install/delete; never cache across mutations.
  (let ((*hub-diagnostic-properties* (or *hub-diagnostic-properties* (make-hash-table :test #'equal)))
        (*hub-diagnostic-listings* (or *hub-diagnostic-listings* (make-hash-table :test #'equal)))
        (*hub-diagnostic-programs* (or *hub-diagnostic-programs* (make-hash-table :test #'equal)))
        (*hub-diagnostic-total* (length entries))
        (*hub-diagnostic-completed* 0)
        (*hub-diagnostic-phase* :validate))
    (handler-case
        (%hub-diagnostic-prime "properties"
                               (loop for entry in entries
                                     unless (eq :unknown (getf (%hub-diagnostic-schema-issue entry) :state))
                                       append (ignore-errors (%hub-diagnostic-entry-paths entry))))
      (error () nil)) ; Missing probe evidence is retried by the normal diagnostic path.
    (let ((roots nil))
      (dolist (entry entries)
        (ignore-errors
          (when (and (not (eq :unknown (getf (%hub-diagnostic-schema-issue entry) :state)))
                     (null (%hub-installed-path-problem entry)))
            (let ((snapshot (han.path:join-path
                             (han.path:parent-directory-pathname (getf entry :command-file))
                             (format nil ".~A/" (getf entry :artifact-name)))))
              (when (and (not (%hub-diagnostic-test "-L" snapshot))
                         (%hub-diagnostic-test "-d" snapshot)
                         (%hub-diagnostic-contained-p snapshot (getf entry :install-root)))
                (push snapshot roots))))))
      (handler-case (%hub-diagnostic-prime "tree" (nreverse roots)) (error () nil)))
    (let ((success nil))
      (unwind-protect
           (multiple-value-prog1 (funcall function) (setf success t))
        (%hub-diagnostic-progress-phase (if success :done :failed))))))

(defun %hub-diagnostic-program (name)
  (if *hub-diagnostic-programs*
      (or (gethash name *hub-diagnostic-programs*)
          (setf (gethash name *hub-diagnostic-programs*) (han.os:find-executable name)))
      (han.os:find-executable name)))

(defun %hub-diagnostic-issue (code state path &optional detail)
  (list :code code :state state
        :path (and path (han.path:->namestring path)) :detail detail))

(defun %hub-diagnostic-state (issues)
  (or (find-if (lambda (state)
                 (find state issues :key (lambda (issue) (getf issue :state))))
               '(:invalid :unknown :unverified))
      :verified))

(defun %hub-diagnostic-test (flag path)
  (%with-hub-diagnostic-probes
    (let* ((key (%hub-diagnostic-path-key path))
           (index (position flag '("-e" "-f" "-d" "-L" "-r" "-x") :test #'equal)))
      (unless index (error "Unsupported installation probe flag: ~A" flag))
      (unless (gethash key *hub-diagnostic-properties*)
        (%hub-diagnostic-probe "properties" (list key)))
      (char= (char (gethash key *hub-diagnostic-properties*) index) #\1))))

(defun %hub-diagnostic-inaccessible-parent-p (path)
  (let ((pathname (han.path:->pathname path)))
    (loop for parts = (pathname-directory pathname) then (butlast parts)
          while parts
          for parent = (make-pathname :directory parts :name nil :type nil :version nil
                                       :defaults pathname)
          when (and (%hub-diagnostic-test "-d" parent)
                    (not (%hub-diagnostic-test "-x" parent))) return t)))

(defun %hub-diagnostic-file-issues (path &key directory-p executable-p)
  (%with-hub-diagnostic-probes
    (handler-case
        (cond
          ((null path) (list (%hub-diagnostic-issue "metadata-invalid" :invalid nil)))
          ((not (%hub-diagnostic-test (if directory-p "-d" "-f") path))
           (if (%hub-diagnostic-inaccessible-parent-p path)
               (list (%hub-diagnostic-issue "read-error" :unknown path))
               (list (%hub-diagnostic-issue "file-missing" :invalid path))))
          ((or (not (%hub-diagnostic-test "-r" path))
               (and directory-p (not (%hub-diagnostic-test "-x" path))))
           (list (%hub-diagnostic-issue "read-error" :unknown path)))
          ((and executable-p (not (%hub-diagnostic-test "-x" path)))
           (list (%hub-diagnostic-issue "not-executable" :invalid path))))
      (error () (list (%hub-diagnostic-issue "read-error" :unknown path))))))

(defun %hub-diagnostic-json (path code)
  (let ((issues (%hub-diagnostic-file-issues path)))
    (when issues (return-from %hub-diagnostic-json (values nil (first issues)))))
  (handler-case
      (values (han.json:read-json-file path) nil)
    (file-error () (values nil (%hub-diagnostic-issue "read-error" :unknown path)))
    (error () (values nil (%hub-diagnostic-issue code :invalid path)))))

(defun %hub-diagnostic-contained-p (path root)
  (%hub-string-prefix-p
   (namestring (han.path:directory-pathname (truename root)))
   (namestring (truename path))))

(defun %hub-diagnostic-children (dir &optional directories-only)
  (%with-hub-diagnostic-probes
    (let ((key (%hub-diagnostic-path-key dir)))
      (unless (nth-value 1 (gethash key *hub-diagnostic-listings*))
        (%hub-diagnostic-probe "children" (list key)))
      (let ((children (gethash key *hub-diagnostic-listings*)))
        (when (eq children :error) (error "Cannot enumerate installation directory."))
        (loop for path in (reverse children)
              when (or (not directories-only) (%hub-diagnostic-test "-d" path)
                       (%hub-diagnostic-test "-L" path))
              collect (if directories-only (han.path:directory-pathname path)
                          (han.path:->pathname path)))))))

(defun %hub-diagnostic-tree-issues (root)
  ;; Inspect paths before hashing: do not traverse escaping links or cycles.
  (let ((seen (make-hash-table :test #'equal)) (issues nil))
    (labels ((walk (dir depth)
               (let* ((true (namestring (truename dir)))
                      (access (%hub-diagnostic-file-issues dir :directory-p t)))
                 (cond
                   (access (setf issues (append access issues)))
                   ((or (> depth 128) (gethash true seen)
                        (and (> depth 0) (not (%hub-diagnostic-contained-p dir root))))
                    (push (%hub-diagnostic-issue "unsafe-path" :unknown dir) issues))
                   (t
                    (setf (gethash true seen) t)
                    (dolist (child (%hub-diagnostic-children dir))
                      (cond
                        ((%hub-diagnostic-test "-L" child)
                         (push (%hub-diagnostic-issue "unsafe-path" :unknown child) issues))
                        ((%hub-diagnostic-test "-d" child) (walk child (1+ depth)))
                        (t (setf issues (append (%hub-diagnostic-file-issues child) issues))))))))))
      (handler-case (walk root 0)
        (error () (push (%hub-diagnostic-issue "read-error" :unknown root) issues))))
    (nreverse issues)))

(defun %hub-diagnostic-result (entry issues)
  (list :package-name (getf entry :package-name)
        :version-id (getf entry :version-id)
        :artifact-name (getf entry :artifact-name)
        :origin-kind (%hub-json-string (getf entry :metadata) "origin_kind")
        :metadata-file (getf entry :metadata-file)
        :repository-url (%hub-json-string (getf entry :metadata) "repository_url")
        :state (%hub-diagnostic-state issues) :issues issues))

(defun %hub-diagnostic-snapshot-fields (snapshot entry)
  (let ((file (han.path:join-path snapshot "taffish.toml")))
    (handler-case
        (let* ((toml (%parse-taffish-toml file))
               (main (%ensure-main-path (%toml-ref toml "package" "main" :required t)))
               (issues (append (%hub-diagnostic-file-issues (han.path:join-path snapshot main))
                               (%hub-diagnostic-file-issues (han.path:join-path snapshot "docs/help.md")))))
          (unless (and (equal (%toml-ref toml "package" "name") (getf entry :package-name))
                       (equal (format nil "~A-r~A" (%toml-ref toml "package" "version")
                                      (%toml-ref toml "package" "release"))
                              (getf entry :version-id))
                       (equal (format nil "~A-v~A" (%toml-ref toml "command" "name")
                                      (getf entry :version-id))
                              (getf entry :artifact-name)))
            (push (%hub-diagnostic-issue "identity-mismatch" :invalid file) issues))
          issues)
      (file-error () (list (%hub-diagnostic-issue "read-error" :unknown file)))
      (error () (list (%hub-diagnostic-issue "snapshot-metadata" :invalid file))))))

(defun %hub-diagnose-entry (entry)
  (unless *hub-diagnostic-properties*
    (return-from %hub-diagnose-entry
      (%hub-call-with-diagnostic-batch (list entry) (lambda () (%hub-diagnose-entry entry)))))
  (let* ((*hub-diagnostic-programs* (or *hub-diagnostic-programs* (make-hash-table :test #'equal)))
         (command (getf entry :command-file))
         (artifact (getf entry :artifact-name))
         (metadata (getf entry :metadata-file))
         (root (and metadata (han.path:parent-directory-pathname metadata)))
         (launcher (getf entry :launcher-file))
         (issues nil))
    (handler-bind
        ((error (lambda (condition)
                  (declare (ignore condition))
                  (push (%hub-diagnostic-issue "read-error" :unknown (or command metadata)) issues)
                  (incf *hub-diagnostic-completed*)
                  (%hub-diagnostic-progress-tick)
                  (return-from %hub-diagnose-entry
                    (%hub-diagnostic-result entry (nreverse issues))))))
      (block inspection
          (let ((schema-issue (%hub-diagnostic-schema-issue entry)))
            (when schema-issue
              (push schema-issue issues)
              (when (eq (getf schema-issue :state) :unknown) (return-from inspection))))
          (unless (and command artifact root launcher)
            (push (%hub-diagnostic-issue "metadata-invalid" :invalid metadata) issues)
            (return-from inspection))
          (let ((path-problem (%hub-installed-path-problem entry)))
            (when path-problem
              (push (%hub-diagnostic-issue "metadata-path" :unknown metadata path-problem) issues)
              (return-from inspection)))
          (let ((snapshot (han.path:join-path
                           (han.path:parent-directory-pathname command)
                           (format nil ".~A/" artifact))))
            (when (%hub-diagnostic-test "-L" snapshot)
              (push (%hub-diagnostic-issue "unsafe-path" :unknown snapshot) issues)
              (return-from inspection))
            (let ((file-issues (append (%hub-diagnostic-file-issues root :directory-p t)
                                      (%hub-diagnostic-file-issues command :executable-p t)
                                      (%hub-diagnostic-file-issues launcher :executable-p t)
                                      (%hub-diagnostic-file-issues snapshot :directory-p t))))
              (setf issues (append issues file-issues))
              (when file-issues (return-from inspection)))
            (unless (and (%hub-diagnostic-contained-p command root)
                         (%hub-diagnostic-contained-p snapshot root))
              (push (%hub-diagnostic-issue "unsafe-path" :unknown command) issues)
              (return-from inspection))
            (unless (and (equal (file-namestring command) artifact)
                         (equal (file-namestring launcher) artifact)
                         (equal (%directory-leaf-name root) (getf entry :version-id))
                         (%hub-uninstall-command-base artifact (getf entry :version-id)))
              (push (%hub-diagnostic-issue "identity-mismatch" :invalid metadata) issues))
            (setf issues (append issues
                                 (%hub-diagnostic-file-issues (han.path:join-path snapshot "taffish.toml"))
                                 (%hub-diagnostic-file-issues (han.path:join-path snapshot "src/") :directory-p t)
                                 (%hub-diagnostic-file-issues (han.path:join-path snapshot "docs/") :directory-p t)))
            (let ((tree-issues (%hub-diagnostic-tree-issues snapshot))
                  (manifest-path (%build-manifest-file snapshot)))
              (setf issues (append issues tree-issues))
              (unless (find-if (lambda (i) (member (getf i :state) '(:invalid :unknown))) issues)
                (setf issues (append issues (%hub-diagnostic-snapshot-fields snapshot entry))))
              (cond
                (tree-issues nil)
                ((not (%hub-diagnostic-test "-e" manifest-path))
                 (push (%hub-diagnostic-issue "manifest-missing" :unverified manifest-path) issues))
                (t
                 (multiple-value-bind (manifest problem)
                     (%hub-diagnostic-json manifest-path "manifest-invalid")
                   (cond
                     (problem (push problem issues))
                     ((not (han.json:json-object-p manifest))
                      (push (%hub-diagnostic-issue "manifest-invalid" :invalid manifest-path) issues))
                     ((not (equal (%build-manifest-string manifest "schema") *build-manifest-schema*))
                      (push (%hub-diagnostic-issue "manifest-schema" :unknown manifest-path) issues))
                     (t
                      (unless (equal (%build-manifest-string manifest "artifact") artifact)
                        (push (%hub-diagnostic-issue "identity-mismatch" :invalid manifest-path) issues))
                      (dolist (key '("source_sha256" "wrapper_sha256"))
                        (let ((hash (%build-manifest-string manifest key)))
                          (unless (and hash (= (length hash) 64)
                                       (every (lambda (c) (digit-char-p c 16)) hash))
                            (push (%hub-diagnostic-issue "manifest-invalid" :invalid manifest-path key) issues))))
                      (unless (find-if (lambda (i) (member (getf i :state) '(:invalid :unknown))) issues)
                        (unless (string-equal (%project-sha256-file command)
                                              (%build-manifest-string manifest "wrapper_sha256"))
                          (push (%hub-diagnostic-issue "wrapper-digest" :invalid command) issues))
                        (unless (string-equal (%build-snapshot-digest snapshot)
                                              (%build-manifest-string manifest "source_sha256"))
                          (push (%hub-diagnostic-issue "snapshot-digest" :invalid snapshot) issues)))))))))
            ;; An unfamiliar launcher may be an older template or a local edit.
            ;; Never execute it or treat a template mismatch as proof of damage.
            (unless (string= (%project-sha256-file launcher)
                             (%project-sha256-string
                              (%hub-install-launcher-string command :launcher-name artifact
                                                            :artifact-name artifact)))
              (push (%hub-diagnostic-issue "launcher-unrecognized" :unverified launcher) issues)))))
    (incf *hub-diagnostic-completed*)
    (%hub-diagnostic-progress-tick)
    (%hub-diagnostic-result entry (nreverse issues))))

(defun %hub-diagnose-index (home)
  (let* ((*hub-diagnostic-programs* (or *hub-diagnostic-programs* (make-hash-table :test #'equal)))
         (file (%hub-index-file home)) (issues nil) (index nil))
    (handler-case
        (cond
          ((not (%hub-diagnostic-test "-e" file))
           (push (if (%hub-diagnostic-inaccessible-parent-p file)
                     (%hub-diagnostic-issue "read-error" :unknown file)
                     (%hub-diagnostic-issue "index-missing" :unverified file)) issues))
          (t
           (multiple-value-bind (object problem) (%hub-diagnostic-json file "index-json")
             (setf index object)
             (cond
               (problem (push problem issues))
               ((not (han.json:json-object-p object))
                (push (%hub-diagnostic-issue "index-json" :invalid file) issues))
               ((not (equal (%hub-json-string object "schema_version") "taffish.index/v1"))
                (push (%hub-diagnostic-issue "index-schema" :unknown file) issues))
               ((not (han.json:json-object-p (%hub-json-ref object "packages")))
                (push (%hub-diagnostic-issue "index-packages" :invalid file) issues))
               (t
                (maphash
                 (lambda (name package)
                   (let* ((latest (%hub-json-string package "latest"))
                          (versions (%hub-json-ref package "versions"))
                          (record (and latest (han.json:json-object-p versions)
                                       (han.json:get-json versions latest))))
                     (cond
                       ((not (and (han.json:json-object-p package)
                                  (han.json:json-object-p versions)))
                        (push (%hub-diagnostic-issue "index-record" :invalid file name) issues))
                       ((and latest (not (han.json:json-object-p record)))
                        (push (%hub-diagnostic-issue "index-latest" :invalid file name) issues))
                       (latest
                        (handler-case
                            (unless (and (equal latest (%hub-install-record-version-id record latest))
                                         (equal latest (format nil "~A-r~A"
                                                              (%hub-json-string record "version")
                                                              (%hub-json-integer-string record "release")))
                                         (%hub-record-command-name package record))
                              (push (%hub-diagnostic-issue "index-record" :invalid file name) issues))
                          (error () (push (%hub-diagnostic-issue "index-record" :invalid file name) issues)))))))
                 (%hub-json-ref object "packages")))))))
      (error () (push (%hub-diagnostic-issue "read-error" :unknown file) issues)))
    (values (list :state (%hub-diagnostic-state issues) :issues (nreverse issues)
                  :metadata-file (han.path:->namestring file))
            index)))

(defun %hub-diagnose-installations (home &optional targets records-only-p)
  (let ((*hub-diagnostic-programs* (or *hub-diagnostic-programs* (make-hash-table :test #'equal)))
        (*hub-diagnostic-properties* (make-hash-table :test #'equal))
        (*hub-diagnostic-listings* (make-hash-table :test #'equal))
        (*hub-diagnostic-phase* :enumerate)
        (results nil) (matched nil) (entries nil) (selected-entries nil) (unresolved nil)
        (apps (%taffish-home-dir home "apps")))
    (%hub-diagnostic-progress-tick)
    (labels
        ((selected-p (name version &optional entry)
           (let ((queries
                   (remove-if-not
                    (lambda (query)
                      (or (equal query name) (equal query (format nil "taf-~A" name))
                          (and version (equal query (format nil "taf-~A-v~A" name version)))
                          (and (null version) (%hub-string-prefix-p (format nil "taf-~A-v" name) query))
                          (and entry (%hub-uninstall-entry-match-p entry query nil)))) targets)))
             (setf matched (union queries matched :test #'equal))
             (or (null targets) queries)))
         (report-problem (name version path issues)
           (when (find :unknown issues :key (lambda (issue) (getf issue :state)))
             (setf unresolved (find :unknown issues :key (lambda (issue) (getf issue :state)))))
           (when (selected-p name version)
             (push (%hub-diagnostic-result
                    (list :package-name name :version-id version :metadata-file (namestring path))
                    issues) results)))
         (report-root-problem (issues)
           (setf unresolved
                 (or (find :unknown issues :key (lambda (issue) (getf issue :state)))
                     (%hub-diagnostic-issue "read-error" :unknown apps)))
           (push (%hub-diagnostic-result nil issues) results))
         (path-issues (path &key directory-p)
           (handler-case
               (or (when (%hub-diagnostic-test "-L" path)
                     (list (%hub-diagnostic-issue "unsafe-path" :unknown path)))
                   (%hub-diagnostic-file-issues path :directory-p directory-p)
                   (unless (%hub-diagnostic-contained-p path apps)
                     (list (%hub-diagnostic-issue "unsafe-path" :unknown path))))
             (error () (list (%hub-diagnostic-issue "read-error" :unknown path)))))
         (inspect-version (name dir)
           (let* ((version (%directory-leaf-name dir))
                  (file (han.path:join-path dir "install.json")))
             (handler-case
                 (let ((issues (or (path-issues dir :directory-p t) (path-issues file))))
                   (if issues
                       (report-problem name version file issues)
                       (let ((entry (%hub-uninstall-read-entry home file)))
                         (when (and records-only-p entry
                                    (not (and (equal name (getf entry :package-name))
                                              (equal version (getf entry :version-id)))))
                           (return-from inspect-version
                             (report-problem name version file
                              (list (%hub-diagnostic-issue "identity-mismatch" :invalid file)))))
                         (when entry (push entry entries))
                         (when (selected-p name version entry)
                           (if entry
                               (push entry selected-entries)
                               (multiple-value-bind (object problem)
                                   (%hub-diagnostic-json file "metadata-invalid")
                                 (declare (ignore object))
                                 (report-problem name version file
                                  (list (or problem (%hub-diagnostic-issue "metadata-invalid" :invalid file))))))))))
               (error () (report-problem name version file
                          (list (%hub-diagnostic-issue "read-error" :unknown file)))))))
         (inspect-package (dir)
           (let ((name (%directory-leaf-name dir)))
             (handler-case
                 (let ((issues (path-issues dir :directory-p t)))
                   (if issues
                       (report-problem name nil dir issues)
                       (dolist (child (%hub-diagnostic-children dir t)) (inspect-version name child))))
               (error () (report-problem name nil dir
                          (list (%hub-diagnostic-issue "read-error" :unknown dir))))))))
      (handler-case
          (cond
            ((%hub-diagnostic-test "-L" apps)
             (report-root-problem (list (%hub-diagnostic-issue "unsafe-path" :unknown apps))))
            ((%hub-diagnostic-test "-e" apps)
             (let ((issues (%hub-diagnostic-file-issues apps :directory-p t)))
               (if issues
                   (report-root-problem issues)
                   (let* ((dirs (%hub-diagnostic-children apps t))
                          (safe (remove-if (lambda (dir) (path-issues dir :directory-p t)) dirs)))
                     ;; Enumerate safe package directories together, but retain all
                     ;; unsafe entries for the ordinary diagnostic/report path.
                     (ignore-errors (%hub-diagnostic-prime "children" safe))
                     (ignore-errors
                       (%hub-diagnostic-prime
                        "properties"
                        (loop for dir in safe append
                          (loop for version in (%hub-diagnostic-children dir t)
                                unless (path-issues version :directory-p t)
                                  collect (han.path:join-path version "install.json")))))
                     (dolist (dir dirs) (inspect-package dir))))))
            ((%hub-diagnostic-inaccessible-parent-p apps)
             (report-root-problem (list (%hub-diagnostic-issue "read-error" :unknown apps)))))
        (error () (report-root-problem (list (%hub-diagnostic-issue "read-error" :unknown apps))))))
    ;; Repair shares the safe inventory, including records that could not be read.
    ;; Do not run integrity checks twice when its planner will inspect each entry.
    (when records-only-p
      (return-from %hub-diagnose-installations (values entries results)))
    (%hub-call-with-diagnostic-batch
     selected-entries
     (lambda ()
       (dolist (entry selected-entries) (push (%hub-diagnose-entry entry) results))
       (%hub-diagnostic-progress-phase :aliases)
       (setf results (append (%hub-diagnose-aliases entries selected-entries) results))))
    (dolist (query (set-difference targets matched :test #'equal))
      (push (%hub-diagnostic-result (list :package-name query)
             ;; An unreadable package may own a custom command we could not resolve.
             (list (or unresolved (%hub-diagnostic-issue "target-missing" :invalid apps)))) results))
    (sort results #'string< :key (lambda (r) (or (getf r :package-name) "")))))

(defun %hub-diagnose-aliases (entries selected)
  ;; An alias belongs to a command group, not to every installed version.
  ;; Keep its warning separate from artifact integrity and prune eligibility.
  (let ((seen (make-hash-table :test #'equal))
        (groups (make-hash-table :test #'equal)) (results nil))
    (labels ((group-key (entry)
               (list (getf entry :command-base)
                     (%hub-installed-path-key (getf entry :bin-dir) t)))
             (report-issues (entry issues)
               (when issues
                 (push (append (list :check-kind :command-entry)
                               (%hub-diagnostic-result entry issues)) results))))
      (dolist (entry entries)
        (handler-case (push entry (gethash (group-key entry) groups))
          (error () nil))) ; Malformed paths are reported by installation inspection.
      (dolist (entry selected)
        (let ((alias (getf entry :command-launcher-file)))
          (when alias
            (handler-case
                (let ((key (group-key entry)))
                  (when (and (not (gethash key seen))
                             (null (%hub-installed-path-problem entry)))
                    (setf (gethash key seen) t)
                    (let ((candidates nil) (issues nil))
                      (dolist (candidate (gethash key groups))
                        (handler-case
                            (let ((schema-issue (%hub-diagnostic-schema-issue candidate)))
                              (if (eq (getf schema-issue :state) :unknown)
                                  (push schema-issue issues)
                                  (let ((problem (%hub-installed-path-problem candidate)))
                                    (cond
                                      (problem
                                       (push (%hub-diagnostic-issue
                                              "metadata-path" :unknown (getf candidate :metadata-file) problem)
                                             issues))
                                      ((%hub-diagnostic-test "-f" (getf candidate :command-file))
                                       (push candidate candidates))))))
                          (error ()
                            (push (%hub-diagnostic-issue "read-error" :unknown
                                                         (getf candidate :metadata-file)) issues))))
                      ;; Incomplete evidence cannot establish which version owns the alias.
                      (if issues
                          (report-issues entry (nreverse issues))
                          (let* ((latest (%hub-install-latest-command-entry candidates))
                                 (access (%hub-diagnostic-file-issues alias :executable-p t)))
                            (report-issues
                             entry
                             (cond
                               ((find :unknown access :key (lambda (issue) (getf issue :state))) access)
                               (access (list (%hub-diagnostic-issue "alias-missing" :unverified alias)))
                               ((or (null latest)
                                    (not (string= (%project-sha256-file alias)
                                                  (%project-sha256-string
                                                   (%hub-install-launcher-string
                                                    (getf latest :command-file)
                                                    :launcher-name (getf entry :command-base)
                                                    :artifact-name (getf latest :artifact-name))))))
                                (list (%hub-diagnostic-issue "alias-unrecognized" :unverified alias))))))))))
              (error () (report-issues entry (list (%hub-diagnostic-issue "read-error" :unknown alias)))))))))
    (nreverse results)))

(defun %hub-diagnostic-remediation (result scope)
  (let* ((issues (getf result :issues))
         (codes (mapcar (lambda (i) (getf i :code)) issues))
         (name (getf result :package-name)) (version (getf result :version-id))
         (scope-arg (format nil "--~A" (string-downcase (string scope)))))
    (cond
      ((null issues) "")
      ((intersection codes '("read-error" "not-executable" "unsafe-path" "metadata-path") :test #'equal)
       (%hub-message "diagnostic.remedy.access"))
      ((intersection codes '("manifest-schema" "index-schema" "metadata-schema") :test #'equal)
       (%hub-message "diagnostic.remedy.schema"))
      ((intersection codes '("alias-missing" "alias-unrecognized") :test #'equal)
       (%hub-message "diagnostic.remedy.alias" :command (or (getf result :artifact-name) "")))
      ((some (lambda (code) (%hub-string-prefix-p "index-" code)) codes)
       (%hub-message "diagnostic.remedy.index" :command (format nil "taf update ~A" scope-arg)))
      ((member "target-missing" codes :test #'equal) (%hub-message "diagnostic.remedy.target"))
      ((equal (getf result :origin-kind) "local-project") (%hub-message "diagnostic.remedy.private"))
      ((and name version (equal (getf result :origin-kind) "hub-index")
            (not (eq (getf result :source-status) :mismatch)))
       (%hub-message "diagnostic.remedy.reinstall"
                     :command (format nil "taf install ~A ~A ~A --repair --dry-run"
                                      (han.os:escape-sh-token name) (han.os:escape-sh-token version) scope-arg)))
      (t (%hub-message "diagnostic.remedy.inspect")))))

(defun %hub-diagnostic-text (result scope)
  (with-output-to-string (out)
    (format out "~A ~A [~A / ~A]~%"
            (or (getf result :package-name) "index") (or (getf result :version-id) "")
            (string-downcase (string scope)) (%hub-status-display (getf result :state)))
    (dolist (issue (getf result :issues))
      (format out "  ~A: ~A~@[ (~A)~]~@[ [~A]~]~%" (getf issue :code)
              (%hub-message (format nil "diagnostic.~A" (getf issue :code)))
              (getf issue :path) (getf issue :detail)))
    (unless (eql (getf result :state) :verified)
      (format out "  ~A~%  ~A~%"
              (%hub-message (cond ((eql (getf result :check-kind) :command-entry) "diagnostic.alias-impact")
                                  ((getf result :package-name) "diagnostic.impact")
                                  (t "diagnostic.index-impact")))
              (%hub-diagnostic-remediation result scope))
      (when (getf result :package-name)
        (format out "  ~A~%"
                (%hub-message "diagnostic.inspect-command"
                              :command (format nil "taf doctor hub ~A --~A --verbose"
                                               (han.os:escape-sh-token (getf result :package-name))
                                               (string-downcase (string scope)))))))))

(defun %hub-diagnostic-summary-policy (result)
  (let ((codes (mapcar (lambda (issue) (getf issue :code)) (getf result :issues))))
    (cond
      ((intersection codes '("read-error" "not-executable" "unsafe-path" "metadata-path") :test #'equal) :access)
      ((intersection codes '("manifest-schema" "index-schema" "metadata-schema") :test #'equal) :schema)
      ((some (lambda (code) (%hub-string-prefix-p "index-" code)) codes) :index)
      ((eq (getf result :check-kind) :command-entry) :alias)
      ((equal (getf result :origin-kind) "local-project") :private)
      ((and (equal (getf result :origin-kind) "hub-index")
            (not (eq (getf result :source-status) :mismatch))) :repair)
      (t :inspect))))

(defun %hub-diagnostic-brief (text)
  (concatenate 'string
               (map 'string (lambda (char) (if (or (< (char-code char) 32) (= (char-code char) 127)) #\Space char))
                    (subseq text 0 (min 96 (length text))))
               (if (> (length text) 96) "..." "")))

(defun %hub-diagnostic-summary-text (results scope)
  "Bounded human summary; the original results remain complete for JSON/detail."
  (let ((groups (make-hash-table :test #'equal))
        (identities (make-hash-table :test #'equal))
        (packages (make-hash-table :test #'equal))
        (policies nil) (issue-count 0))
    (dolist (result results)
      (unless (eq (getf result :state) :verified)
        (let* ((name (or (getf result :package-name) "index"))
               (version (or (getf result :version-id) ""))
               (identity (format nil "~A~@[ ~A~]" name (unless (equal version "") version)))
               (policy (%hub-diagnostic-summary-policy result)))
          (setf (gethash (list name version) identities) t
                (gethash name packages) t)
          (pushnew policy policies)
          (dolist (issue (getf result :issues))
            (incf issue-count)
            (pushnew identity
                     (gethash (list (getf issue :code) (getf issue :state) policy) groups)
                     :test #'equal)))))
    (with-output-to-string (out)
      (when (plusp issue-count)
        (format out "~A~%"
                (%hub-message "diagnostic.summary"
                              :scope (string-downcase (string scope))
                              :packages (hash-table-count packages)
                              :versions (hash-table-count identities) :issues issue-count))
        (dolist (key (sort (loop for key being the hash-keys of groups collect key)
                          #'string< :key #'prin1-to-string))
          (let ((examples (sort (copy-list (gethash key groups)) #'string<)))
            (format out "  ~A [~A]: ~A~%    ~A~%"
                    (first key) (%hub-status-display (second key))
                    (%hub-message (format nil "diagnostic.~A" (first key)))
                    (%hub-message "diagnostic.group"
                                  :count (length examples)
                                  :examples (format nil "~{~A~^, ~}~A"
                                                    (mapcar #'%hub-diagnostic-brief
                                                            (subseq examples 0 (min 3 (length examples))))
                                                    (if (> (length examples) 3) ", ..." ""))))))
        (dolist (policy (sort policies #'string< :key #'symbol-name))
          (format out "  ~A~%"
                  (%hub-message (format nil "diagnostic.summary-remedy.~(~A~)" policy)
                                :scope (string-downcase (string scope)))))
        (format out "  ~A~%"
                (%hub-message "diagnostic.summary-details"
                              :scope (string-downcase (string scope))))))))

(defun %hub-diagnostic-json-value (value)
  (cond
    ((null value) :null)
    ((stringp value) value)
    ((member value '(t :false :null)) value)
    ((pathnamep value) (han.path:->namestring value))
    ((keywordp value) (string-downcase (string value)))
    ((and (consp value) (keywordp (first value)))
     (let ((object (han.json:make-json-object)))
       (loop for (key val) on value by #'cddr
             for name = (substitute #\_ #\- (string-downcase (string key))) do
         ;; Plists use first occurrence wins. Preserve it in nested results too.
         (unless (nth-value 1 (gethash name object))
           (han.json:set-json object name
                              (if (and (null val) (%hub-uninstall-string-suffix-p "_p" name))
                                  :false (%hub-diagnostic-json-value val)))))
       object))
    ((listp value) (coerce (mapcar #'%hub-diagnostic-json-value value) 'vector))
    ((vectorp value) (map 'vector #'%hub-diagnostic-json-value value))
    (t value)))
