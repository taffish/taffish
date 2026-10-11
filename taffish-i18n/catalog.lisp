(in-package :taffish.i18n)

;;;; ============================================================
;;;; catalog.lisp
;;;; ============================================================

(defparameter *builtin-messages* (make-hash-table :test #'equal))

(defparameter *builtin-language-examples*
  '(("en" . "TAFFISH is ready.")
    ("zh" . "TAFFISH 已准备就绪。")))

(defun register-message (key english chinese)
  (unless (and (%non-empty-string-p key)
               (stringp english)
               (stringp chinese))
    (error "i18n message registration requires key, English, and Chinese strings."))
  (unless (%same-placeholders-p english chinese)
    (error "i18n placeholder mismatch for built-in message ~S." key))
  (setf (gethash key *builtin-messages*)
        (list :en english :zh chinese))
  key)

(defun builtin-message-keys ()
  (sort (loop for key being the hash-keys of *builtin-messages*
              collect key)
        #'string<))

(defun %safe-resource-component-p (value)
  (and (%non-empty-string-p value)
       (every (lambda (char)
                (or (and (char<= #\a char) (char<= char #\z))
                    (and (char<= #\A char) (char<= char #\Z))
                    (and (char<= #\0 char) (char<= char #\9))
                    (member char '(#\- #\_) :test #'char=)))
              value)))

(defun %locale-directory (home locale)
  (and home
       (han.path:directory-pathname
        (han.path:join-path home "share" "locales" locale))))

(defun %external-roots ()
  (remove nil
          (list (or *current-user-home* (%user-home))
                (or *current-system-home* (%system-home)))))

(defun %cached-file-value (cache-key loader)
  (if *external-catalog-cache*
      (multiple-value-bind (value present-p)
          (gethash cache-key *external-catalog-cache*)
        (if present-p
            value
            (setf (gethash cache-key *external-catalog-cache*)
                  (funcall loader))))
      (funcall loader)))

(defun %read-external-json-object (path)
  (%cached-file-value
   (list :json (han.path:->namestring path))
   (lambda ()
     (handler-case
         (let ((value (and (han.path:file-exists-p path)
                           (han.json:read-json-file path))))
           (and (han.json:json-object-p value) value))
       (error () nil)))))

(defun %read-external-text (path)
  (%cached-file-value
   (list :text (han.path:->namestring path))
   (lambda ()
     (handler-case
         (and (han.path:file-exists-p path)
              (han.os:load-string path))
       (error () nil)))))

(defun %directory-leaf-name (directory)
  (let* ((path (han.path:directory-pathname directory))
         (parts (pathname-directory path))
         (leaf (and parts (car (last parts)))))
    (and (stringp leaf) leaf)))

(defun %canonical-external-locale-id (directory)
  (let* ((leaf (%directory-leaf-name directory))
         (normalized (and leaf (normalize-language leaf))))
    (and leaf
         normalized
         (%safe-resource-component-p leaf)
         (string= leaf normalized)
         (not (member normalized '("auto" "en" "zh") :test #'string=))
         normalized)))

(defun %non-empty-external-text-p (path)
  (let ((value (%read-external-text path)))
    (and (stringp value) (%non-empty-string-p value))))

(defun %external-messages-p (directory)
  (let* ((path (han.path:join-path directory "messages.json"))
         (object (%read-external-json-object path)))
    (and object
         (some (lambda (key)
                 (multiple-value-bind (value present-p)
                     (han.json:get-json object key)
                   (and present-p (stringp value))))
               (han.json:json-keys object)))))

(defun %external-command-help-p (directory)
  (let ((help-directory
          (han.path:directory-pathname
           (han.path:join-path directory "help" "taf"))))
    (and (han.path:directory-exists-p help-directory)
         (handler-case
             (some (lambda (path)
                     (and (string-equal (or (pathname-type path) "") "txt")
                          (%non-empty-external-text-p path)))
                   (han.path:directory-files help-directory))
           (error () nil)))))

(defun %external-help-p (directory)
  (or (%non-empty-external-text-p
       (han.path:join-path directory "help" "taf.txt"))
      (%non-empty-external-text-p
       (han.path:join-path directory "help" "taffish.txt"))
      (%external-command-help-p directory)))

(defun %external-locale-valid-p (directory)
  (handler-case
      (or (%external-messages-p directory)
          (%external-help-p directory))
    (error () nil)))

(defun %external-language-example (directory)
  (handler-case
      (let ((path (han.path:join-path directory "example.txt")))
        (when (han.path:file-exists-p path)
          (dolist (line (han.os:load-lines path))
            (let ((clean (%trim line)))
              (when (%non-empty-string-p clean)
                (return (if (> (length clean) 256)
                            (subseq clean 0 256)
                            clean)))))))
    (error () nil)))

(defun %external-languages-under (home origin)
  (let ((root (and home
                   (han.path:directory-pathname
                    (han.path:join-path home "share" "locales")))))
    (when (and root (han.path:directory-exists-p root))
      (handler-case
          (loop for directory in (han.path:subdirectories root)
                for id = (%canonical-external-locale-id directory)
                when (and id (%external-locale-valid-p directory))
                  collect (list :id id
                                :origin origin
                                :example (%external-language-example directory)
                                :directory (han.path:->namestring directory)))
        (error () nil)))))

(defun available-languages (&key user-home system-home)
  "Return built-in and valid external language packs as stable plists.

External discovery is shallow and data-only. User packs shadow system packs
with the same canonical id; external packs cannot replace built-in en or zh."
  (let ((external (make-hash-table :test #'equal)))
    (dolist (entry (%external-languages-under (%system-home system-home) :system))
      (setf (gethash (getf entry :id) external) entry))
    (dolist (entry (%external-languages-under (%user-home user-home) :user))
      (setf (gethash (getf entry :id) external) entry))
    (append
     (loop for (id . example) in *builtin-language-examples*
           collect (list :id id :origin :built-in :example example))
     (sort (loop for entry being the hash-values of external collect entry)
           #'string< :key (lambda (entry) (getf entry :id))))))

(defun %external-message (locale key baseline)
  (when (and (not (member locale '("en" "zh") :test #'string=))
             (%safe-resource-component-p locale))
    (dolist (home (%external-roots))
      (let* ((directory (%locale-directory home locale))
             (path (and directory
                        (han.path:join-path directory "messages.json")))
             (object (and path (%read-external-json-object path))))
        (when object
          (multiple-value-bind (value present-p)
              (han.json:get-json object key)
            (when (and present-p
                       (stringp value)
                       (%same-placeholders-p baseline value))
              (return value))))))))

(defun %external-help-path (directory program command)
  (cond
    ((and (string= program "taf") command)
     (han.path:join-path directory "help" "taf"
                         (format nil "~A.txt" command)))
    ((string= program "taf")
     (han.path:join-path directory "help" "taf.txt"))
    ((and (string= program "taffish") (null command))
     (han.path:join-path directory "help" "taffish.txt"))
    (t nil)))

(defun %external-help (locale program command baseline)
  (when (and (not (member locale '("en" "zh") :test #'string=))
             (%safe-resource-component-p locale)
             (%safe-resource-component-p program)
             (or (null command) (%safe-resource-component-p command)))
    (dolist (home (%external-roots))
      (let* ((directory (%locale-directory home locale))
             (path (and directory
                        (%external-help-path directory program command)))
             (value (and path (%read-external-text path))))
        (when (and (stringp value)
                   (%same-placeholders-p baseline value))
          (return value))))))

(defun %message-template (key language)
  (let ((builtins (gethash key *builtin-messages*)))
    (when builtins
      (let ((english (getf builtins :en)))
        (loop for locale in (language-fallback-chain language) do
          (cond
            ((string= locale "en") (return english))
            ((string= locale "zh") (return (or (getf builtins :zh) english)))
            (t
             (let ((external (%external-message locale key english)))
               (when external (return external)))))
          finally (return english))))))

(defun message (key &optional bindings)
  "Render a registered semantic message key for the current human language."
  (let ((template (%message-template key (current-language))))
    (if template
        (%render-template template bindings)
        key)))

(defun %message-binding-name (name)
  (etypecase name
    (string name)
    (symbol (string-downcase (symbol-name name)))))

(defun message-with (key &rest bindings)
  "Render KEY with keyword/string name and value pairs.

This is a convenience layer over MESSAGE. It does not alter locale selection
or fallback and deliberately rejects malformed binding lists."
  (unless (evenp (length bindings))
    (error "i18n message bindings must contain name/value pairs: ~S" bindings))
  (message key
           (loop for (name value) on bindings by #'cddr
                 collect (cons (%message-binding-name name) value))))

(defun help-text (program command english chinese &optional bindings)
  "Render built-in or external help while preserving English as baseline."
  (unless (and (stringp english) (stringp chinese))
    (error "i18n help requires built-in English and Chinese strings."))
  (let* ((safe-chinese (if (%same-placeholders-p english chinese)
                           chinese
                           english))
         (language (current-language))
         (template
           (loop for locale in (language-fallback-chain language) do
             (cond
               ((string= locale "en") (return english))
               ((string= locale "zh") (return safe-chinese))
               (t
                (let ((external (%external-help locale program command english)))
                  (when external (return external)))))
             finally (return english))))
    (%render-template template bindings)))
