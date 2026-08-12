(in-package :taffish.i18n)

;;;; ============================================================
;;;; locale.lisp
;;;; ============================================================

(defparameter *default-language* "en")

(defparameter *default-language-selection* "auto")

(defparameter *system-home-default* #P"/opt/taffish/")

(defparameter *user-home-relative* ".local/share/taffish/")

(defvar *current-language* nil)
(defvar *current-user-home* nil)
(defvar *current-system-home* nil)
(defvar *external-catalog-cache* nil)

;; Tests bind this reader instead of mutating the parent process environment.
(defvar *environment-reader* #'han.host:getenv)

(defun %getenv (name)
  (funcall *environment-reader* name))

(defun %trim (value)
  (and (stringp value)
       (string-trim '(#\Space #\Tab #\Newline #\Return) value)))

(defun %non-empty-string-p (value)
  (let ((trimmed (%trim value)))
    (and trimmed (> (length trimmed) 0))))

(defun %split-string (string delimiter)
  (let ((result nil)
        (start 0))
    (loop for position = (position delimiter string :start start)
          do (push (subseq string start position) result)
          if position
            do (setf start (1+ position))
          else
            do (return (nreverse result)))))

(defun %join-strings (strings delimiter)
  (with-output-to-string (out)
    (loop for item in strings
          for first-p = t then nil do
            (unless first-p (write-char delimiter out))
            (write-string item out))))

(defun %ascii-alpha-string-p (string)
  (and (> (length string) 0)
       (every (lambda (char)
                (or (and (char<= #\a char) (char<= char #\z))
                    (and (char<= #\A char) (char<= char #\Z))))
              string)))

(defun %ascii-digit-string-p (string)
  (and (> (length string) 0)
       (every (lambda (char)
                (and (char<= #\0 char) (char<= char #\9)))
              string)))

(defun %canonical-locale-part (part index)
  (cond
    ((zerop index) (string-downcase part))
    ((and (= (length part) 4) (%ascii-alpha-string-p part))
     (concatenate 'string
                  (string-upcase (subseq part 0 1))
                  (string-downcase (subseq part 1))))
    ((or (and (= (length part) 2) (%ascii-alpha-string-p part))
         (and (= (length part) 3) (%ascii-digit-string-p part)))
     (string-upcase part))
    (t (string-downcase part))))

(defun %strip-locale-suffix (locale)
  (let* ((dot (position #\. locale))
         (modifier (position #\@ locale))
         (end (cond
                ((and dot modifier) (min dot modifier))
                (dot dot)
                (modifier modifier)
                (t (length locale)))))
    (subseq locale 0 end)))

(defun normalize-language (language)
  "Normalize LANGUAGE without consulting the filesystem.

Built-in aliases collapse to en or zh. Other values use a conservative
BCP-47-style spelling so exact and base-language fallback are deterministic."
  (let ((raw (%trim language)))
    (when (%non-empty-string-p raw)
      (let* ((without-suffix (%strip-locale-suffix raw))
             (hyphenated (substitute #\- #\_ without-suffix))
             (parts (remove "" (%split-string hyphenated #\-)
                            :test #'string=)))
        (when parts
          (let ((canonical
                  (%join-strings
                   (loop for part in parts
                         for index from 0
                         collect (%canonical-locale-part part index))
                   #\-)))
            (cond
              ((member canonical '("c" "posix") :test #'string-equal) "en")
              ((string-equal canonical "auto") "auto")
              ((member canonical '("en" "en-US") :test #'string=) "en")
              ((member canonical '("zh" "zh-CN" "zh-Hans") :test #'string=)
               "zh")
              (t canonical))))))))

(defun language-fallback-chain (language)
  (let ((normalized (or (normalize-language language) *default-language*)))
    (cond
      ((string= normalized "en") '("en"))
      ((string= normalized "zh") '("zh" "en"))
      (t
       (let* ((separator (position #\- normalized))
              (base (and separator (subseq normalized 0 separator))))
         (remove-duplicates
          (remove nil (list normalized base "en"))
          :test #'string=))))))

(defun %directory-pathname (path)
  (and path (han.path:directory-pathname path)))

(defun %home-from-env (name)
  (let ((value (%getenv name)))
    (and (%non-empty-string-p value)
         (%directory-pathname value))))

(defun %default-user-home ()
  (let ((home (or (han.os:home-directory)
                  (let ((value (%getenv "HOME")))
                    (and (%non-empty-string-p value) value)))))
    (and home
         (%directory-pathname
          (han.path:join-path home *user-home-relative*)))))

(defun %user-home (&optional override)
  (%directory-pathname
   (or override
       (%home-from-env "TAFFISH_USER_HOME")
       (%default-user-home))))

(defun %system-home (&optional override)
  (%directory-pathname
   (or override
       (%home-from-env "TAFFISH_SYSTEM_HOME")
       *system-home-default*)))

(defun %config-file (home)
  (and home (han.path:join-path home "config.toml")))

(defun %config-line-before-comment (line)
  (let ((quoted-p nil)
        (escaped-p nil))
    (loop for index from 0 below (length line)
          for char = (char line index) do
            (cond
              (escaped-p (setf escaped-p nil))
              ((and quoted-p (char= char #\\)) (setf escaped-p t))
              ((char= char #\") (setf quoted-p (not quoted-p)))
              ((and (not quoted-p) (char= char #\#))
               (return (subseq line 0 index))))
          finally (return line))))

(defun %parse-config-string (raw)
  (let ((value (%trim raw)))
    (cond
      ((not (%non-empty-string-p value)) nil)
      ((and (>= (length value) 2)
            (char= (char value 0) #\")
            (char= (char value (1- (length value))) #\"))
       (handler-case
           (let ((parsed (han.json:parse-json value)))
             (and (stringp parsed) parsed))
         (error () nil)))
      ((and (>= (length value) 2)
            (char= (char value 0) #\')
            (char= (char value (1- (length value))) #\'))
       (subseq value 1 (1- (length value))))
      (t nil))))

(defun %read-config-language (path)
  "Read only the top-level language key. Any malformed input fails closed."
  (when (and path (han.path:file-exists-p path))
    (handler-case
        (dolist (raw-line (han.os:load-lines path))
          (let ((line (%trim (%config-line-before-comment raw-line))))
            (when (%non-empty-string-p line)
              (when (char= (char line 0) #\[)
                (return nil))
              (let ((separator (position #\= line)))
                (when separator
                  (let ((key (%trim (subseq line 0 separator))))
                    (when (string= key "language")
                      (return (%parse-config-string
                               (subseq line (1+ separator)))))))))))
      (error () nil))))

(defun %explicit-config-path ()
  (let ((path (%getenv "TAFFISH_CONFIG")))
    (and (%non-empty-string-p path) path)))

(defun %language-config-entry (path source)
  (let ((language (%read-config-language path)))
    (and (%non-empty-string-p language)
         (list :language language
               :source source
               :file (han.path:->namestring path)))))

(defun %configured-language-entry
    (&key user-home system-home (include-user-config-p t))
  (let* ((user-root (%user-home user-home))
         (system-root (%system-home system-home))
         (explicit-path (%explicit-config-path)))
    (or (and explicit-path
             (%language-config-entry explicit-path :explicit-config))
        (and include-user-config-p
             (%language-config-entry (%config-file user-root) :user-config))
        (%language-config-entry (%config-file system-root) :system-config)
        (list :language *default-language-selection*
              :source :default
              :file nil))))

(defun %locale-environment-language ()
  (or (let ((value (%getenv "LC_ALL")))
        (and (%non-empty-string-p value) value))
      (let ((value (%getenv "LC_MESSAGES")))
        (and (%non-empty-string-p value) value))
      (let ((value (%getenv "LANG")))
        (and (%non-empty-string-p value) value))))

(defun resolve-language-details
    (&key user-home system-home (include-user-config-p t))
  "Return configured and displayed language selection details.

The returned plist is read-only machine data. INCLUDE-USER-CONFIG-P is used by
system-scope config inspection; normal CLI resolution keeps its default T."
  (let* ((configured
           (%configured-language-entry
            :user-home user-home
            :system-home system-home
            :include-user-config-p include-user-config-p))
         (configured-raw (getf configured :language))
         (configured-normalized
           (or (normalize-language configured-raw) *default-language*))
         (environment-raw (%getenv "TAFFISH_LANGUAGE"))
         (environment-override
           (and (%non-empty-string-p environment-raw) environment-raw))
         (selected-raw (or environment-override configured-raw))
         (selected-normalized
           (or (normalize-language selected-raw) *default-language*))
         (locale-raw (%locale-environment-language))
         (locale-normalized (normalize-language locale-raw))
         (auto-p (string= selected-normalized "auto"))
         (display-language
           (if auto-p
               (or locale-normalized *default-language*)
               selected-normalized))
         (display-source
           (cond
             (auto-p (if locale-normalized :locale-environment :default))
             (environment-override :environment)
             (t (getf configured :source)))))
    (list :configured-language configured-normalized
          :configured-source (getf configured :source)
          :config-file (getf configured :file)
          :display-language display-language
          :display-source display-source
          :environment-override environment-override
          :locale-environment locale-raw)))

(defun resolve-language (&key user-home system-home (include-user-config-p t))
  "Resolve the human CLI language without changing process-global state."
  (getf (resolve-language-details
         :user-home user-home
         :system-home system-home
         :include-user-config-p include-user-config-p)
        :display-language))

(defun current-language ()
  ;; Libraries and machine-facing callers stay deterministic unless a human
  ;; CLI entry point explicitly establishes the resolved language context.
  (or *current-language* *default-language*))

(defun call-with-language (language function &key user-home system-home)
  (let ((*current-language*
          (let ((normalized (normalize-language language)))
            (if (or (null normalized) (string= normalized "auto"))
                *default-language*
                normalized)))
        (*current-user-home* (%user-home user-home))
        (*current-system-home* (%system-home system-home))
        (*external-catalog-cache* (make-hash-table :test #'equal)))
    (funcall function)))

(defun call-with-resolved-language (function &key user-home system-home)
  (let ((resolved (resolve-language :user-home user-home
                                    :system-home system-home)))
    (call-with-language resolved function
                        :user-home user-home
                        :system-home system-home)))

(defmacro with-language ((language &key user-home system-home) &body body)
  `(call-with-language ,language
                       (lambda () ,@body)
                       :user-home ,user-home
                       :system-home ,system-home))
