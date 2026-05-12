(in-package :taf.core)

;;;; ============================================================
;;;; hub / update.lisp
;;;; ============================================================

(defparameter *taffish-index-default-url* nil)

(defun %hub-timestamp ()
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month day hour minute second)))

(defun %hub-safe-timestamp (&optional (timestamp (%hub-timestamp)))
  (with-output-to-string (out)
    (loop for char across timestamp do
      (unless (member char '(#\: #\-) :test #'char=)
        (write-char char out)))))

(defun %hub-string-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (loop for i from 0 below (length prefix)
             always (char= (char prefix i) (char string i)))))

(defun %hub-trim-string (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return) string))

(defun %hub-non-empty-string-p (string)
  (and (stringp string)
       (not (string= "" (%hub-trim-string string)))))

(defun %hub-index-url (index-url)
  (or (and (%hub-non-empty-string-p index-url) index-url)
      (and (%hub-non-empty-string-p *taffish-index-default-url*)
           *taffish-index-default-url*)
      (%default-index-url)))

(defun %hub-file-url-path (source)
  (when (%hub-string-prefix-p "file://" source)
    (subseq source (length "file://"))))

(defun %hub-http-url-p (source)
  (or (%hub-string-prefix-p "https://" source)
      (%hub-string-prefix-p "http://" source)))

(defun %hub-read-local-index-file (path)
  (let ((file (han.path:file-exists-p path)))
    (unless file
      (error "[update] local index file does not exist: ~A" path))
    (han.os:load-string file)))

(defun %hub-curl-command (curl url)
  (append
   (let ((env (han.os:find-executable "env")))
     (when env
       (list env "LC_ALL=C" "LANG=C")))
   (list curl
         "--fail"
         "--silent"
         "--show-error"
         "--location"
         "--connect-timeout" "15"
         "--max-time" "120"
         "--retry" "3"
         "--retry-delay" "2"
         "--retry-all-errors"
         url)))

(defun %hub-download-index-url (url)
  (let ((curl (han.os:find-executable "curl")))
    (unless curl
      (error "[update] can't find curl executable for downloading: ~A" url))
    (multiple-value-bind (out err code)
        (han.os:run-program
         (%hub-curl-command curl url)
         :output :string
         :error-output :string
         :ignore-error-status t)
      (unless (and (integerp code) (= code 0))
        (error "[update] failed to download index from ~A.~%~A~%This is usually a network/proxy problem when accessing the index URL. You can retry later or use `taf update --url <INDEX-URL>` / TAFFISH_INDEX_URL."
               url
               (%hub-trim-string err)))
      out)))

(defun %hub-read-index-source (source)
  (cond
    ((%hub-file-url-path source)
     (%hub-read-local-index-file (%hub-file-url-path source)))
    ((han.path:file-exists-p source)
     (%hub-read-local-index-file source))
    ((%hub-http-url-p source)
     (%hub-download-index-url source))
    (t
     (error "[update] index source must be a local file or http(s) URL, but got: ~A"
            source))))

(defun %hub-index-current-file (home)
  (han.path:join-path (%taffish-home-dir home "index") "current.json"))

(defun %hub-index-snapshots-dir (home)
  (%taffish-home-dir home "index/snapshots"))

(defun %hub-index-snapshot-file (home timestamp)
  (han.path:join-path
   (%hub-index-snapshots-dir home)
   (format nil "index-~A.json" (%hub-safe-timestamp timestamp))))

(defun %hub-write-string-to-file (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
    (write-string string out)))

(defun %hub-validate-index-string (string source)
  (unless (%hub-non-empty-string-p string)
    (error "[update] downloaded index is empty: ~A" source))
  ;; Keep v1 deliberately light: later hub commands will parse the JSON strictly.
  (unless (and (search "\"schema_version\"" string :test #'char=)
               (search "taffish.index/v1" string :test #'char=))
    (error "[update] downloaded file does not look like a TAFFISH index: ~A"
           source))
  string)

(defun %print-hub-update-result (result)
  (format t "[TAF] updated TAFFISH index~%")
  (format t "  scope    : ~A~%"
          (string-downcase (string (getf result :scope))))
  (format t "  source   : ~A~%" (getf result :source))
  (format t "  current  : ~A~%" (getf result :current-file))
  (format t "  snapshot : ~A~%" (getf result :snapshot-file))
  (format t "  bytes    : ~A~%" (getf result :bytes))
  nil)

(defun hub-update (&key
                     index-url
                     (scope :user)
                     user-home
                     system-home
                     (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path))
         (source (%resolve-taffish-index-url
                  :explicit-url index-url
                  :scope normalized-scope
                  :user-home user-home-path
                  :system-home system-home-path))
         (timestamp (%hub-timestamp))
         (current-file (%hub-index-current-file home))
         (snapshot-file (%hub-index-snapshot-file home timestamp))
         (index-string (%hub-validate-index-string
                        (%hub-read-index-source source)
                        source)))
    (%ensure-directory (%taffish-home-dir home "index"))
    (%ensure-directory (%hub-index-snapshots-dir home))
    (%hub-write-string-to-file snapshot-file index-string)
    (%hub-write-string-to-file current-file index-string)
    (let ((result (list :scope normalized-scope
                        :home (%directory-namestring home)
                        :source source
                        :current-file (han.path:->namestring current-file)
                        :snapshot-file (han.path:->namestring snapshot-file)
                        :timestamp timestamp
                        :bytes (length index-string))))
      (when verbose
        (%print-hub-update-result result))
      result)))
