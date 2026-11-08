(in-package :han.host)

(defun %report-cli-error (prefix condition)
  ;; Reporting must never fail recursively or fall back to protocol stdout.
  (ignore-errors
    (format *error-output* "~A ~A~%" prefix condition)
    (finish-output *error-output*))
  nil)

(defmacro %with-cli-error-boundary ((prefix) &body body)
  "Internal boundary for executable entry points, not library operations."
  `(handler-case
       (progn ,@body)
     #+sbcl
     (sb-sys:interactive-interrupt ()
       (%report-cli-error ,prefix "Interrupted.")
       (quit 1))
     (error (condition)
       (%report-cli-error ,prefix condition)
       (quit 1))))

(defun %call-with-character-output-string (function)
  "Call FUNCTION with an output stream backed by a full CHARACTER string."
  (let ((buffer (make-array 64
                            :element-type 'character
                            :adjustable t
                            :fill-pointer 0
                            :initial-element (code-char #x10000))))
    (with-output-to-string (out buffer)
      (funcall function out))
    buffer))

(defmacro with-character-output-to-string ((stream) &body body)
  "Evaluate BODY with STREAM and return a full CHARACTER output string."
  `(%call-with-character-output-string
    (lambda (,stream)
      ,@body)))

(defun %utf8-line-string (line)
  "Return LINE followed by one newline as a full CHARACTER string."
  (check-type line string)
  (with-character-output-to-string (out)
    (write-string line out)
    (write-char #\Newline out)))

(defstruct host-process
  backend
  native-handle
  pid
  input-stream
  output-stream
  error-stream
  exit-code
  signal-code)

(defun %close-stream-safely (stream)
  (when stream
    (ignore-errors
     (close stream))))

(defun cwd ()
  "Return the current working directory namestring, or NIL if unavailable."
  (ignore-errors (namestring (truename "."))))

(defun %normalize-directory-list (dir &optional (default-kind :relative))
  (cond
    ((null dir)
     (list default-kind))
    ((and (consp dir)
          (keywordp (first dir)))
     dir)
    (t
     (cons default-kind dir))))

(defun %->pathname (x)
  (let ((p (etypecase x
             (pathname x)
             (string (pathname x)))))
    (make-pathname
     :host (pathname-host p)
     :device (pathname-device p)
     :directory (%normalize-directory-list (pathname-directory p))
     :name (pathname-name p)
     :type (pathname-type p)
     :version (pathname-version p)
     :defaults p)))

(defun %directory-pathname-p (x)
  (let ((p (%->pathname x)))
    (and (null (pathname-name p))
         (null (pathname-type p)))))

(defun %directory-pathname (x)
  (let* ((p (%->pathname x))
         (dir (%normalize-directory-list (pathname-directory p))))
    (if (%directory-pathname-p p)
        p
        (let ((last (file-namestring p)))
          (make-pathname
           :host (pathname-host p)
           :device (pathname-device p)
           :directory (append dir
                              (if (and last (not (string= last "")))
                                  (list last)
                                  '()))
           :name nil
           :type nil
           :version nil
           :defaults p)))))

(defun %file-parent-directory (path)
  "Return the directory pathname containing file PATH."
  (make-pathname :name nil
                 :type nil
                 :version nil
                 :defaults (%->pathname path)))

(defun %ensure-parent-directories-for-file (path)
  "Ensure PATH's parent exists, tolerating only a concurrent creator."
  (let* ((file (%->pathname path))
         (parent (%file-parent-directory file)))
    (unless (directory-exists-p parent)
      (handler-case
          (ensure-directories-exist file)
        (error (condition)
          ;; Some implementations report EEXIST when another process creates
          ;; the same final directory between the probe and mkdir.  Continue
          ;; only when the requested parent is now demonstrably present.
          (unless (directory-exists-p parent)
            (error condition)))))
    file))

(defun %prepare-native-file (path)
  ;; String inputs come from OS interfaces such as argv and environment
  ;; variables. Do not parse their metacharacters as CL pathname patterns.
  (let ((file (etypecase path
                (pathname path)
                (string (%literal-file-pathname path)))))
    (%ensure-parent-directories-for-file file)))

(defun %native-open-name (path)
  (etypecase path
    (string path)
    (pathname (namestring path))))

(defun call-with-exclusive-file-lock (lock-path function &key (timeout 5))
  "Call FUNCTION with no arguments while holding an exclusive flock on LOCK-PATH.
All cooperating processes must keep and use the same lock file. Return the
callback's values. On contention, wait at most TIMEOUT seconds before
signaling an error. Zero makes a single nonblocking attempt."
  (check-type timeout (real 0))
  #+(and (or sbcl lispworks) (or darwin macosx linux))
  (let* ((file (%prepare-native-file lock-path))
         ;; O_WRONLY | O_CREAT | O_NONBLOCK | O_CLOEXEC (Darwin and Linux
         ;; x86-64/arm64 ABIs). Never truncate or unlink this stable inode.
         (flags #+(or darwin macosx) (logior 1 #x200 #x4 #x1000000)
                #+linux (logior 1 #o100 #o4000 #o2000000)))
    (multiple-value-bind (fd open-error) (%open-lock-file (%native-open-name lock-path) flags)
      (unless fd
        (error "Cannot open lock file ~A (errno ~D)." file open-error))
      (unwind-protect
           (loop with deadline = (+ (get-internal-real-time)
                                    (ceiling (* timeout internal-time-units-per-second)))
                 for errno = (%try-exclusive-file-lock fd)
                 when (null errno) return (funcall function)
                 ;; EINTR or EWOULDBLOCK can be retried until the deadline.
                 unless (member errno '(4 #+(or darwin macosx) 35 #+linux 11))
                   do (error "Cannot lock ~A (errno ~D)." file errno)
                 do (let ((remaining (- deadline (get-internal-real-time))))
                      (when (<= remaining 0)
                        (error "Timed out waiting for lock ~A." file))
                      (sleep (min 1/100 (/ remaining internal-time-units-per-second)))))
        (%close-lock-file fd))))
  #-(and (or sbcl lispworks) (or darwin macosx linux))
  (error "File locking is unsupported on ~A/~A (lock ~A for ~S)."
         (lisp-implementation-type) (software-type) lock-path function))

(defun %safe-probe-file (path)
  (ignore-errors
    (probe-file path)))

(defun file-exists-p (path)
  "Return the truename/pathname of PATH when it names an existing file, else NIL."
  (let* ((p (%->pathname path))
         (found (and (not (%directory-pathname-p p))
                     (%safe-probe-file p))))
    (and found
         (not (%directory-pathname-p found))
         found)))

(defun %probe-directory-found-p (requested-directory found)
  (declare (ignore requested-directory))
  #+lispworks
  (not (null found))
  #-lispworks
  (%directory-pathname-p found))

(defun directory-exists-p (path)
  "Return the directory pathname of PATH when it names an existing directory, else NIL."
  (let* ((dir (%directory-pathname path))
         (found (%safe-probe-file dir)))
    (and found
         (%probe-directory-found-p dir found)
         (%directory-pathname found))))

(defun %directory-entry-wildcard (directory)
  (make-pathname :name :wild
                 :type :wild
                 :defaults (%directory-pathname directory)))

(defun %subdirectory-wildcard (directory)
  (let* ((dir (%directory-pathname directory))
         (dir-list (%normalize-directory-list (pathname-directory dir))))
    (make-pathname :host (pathname-host dir)
                   :device (pathname-device dir)
                   :directory (append dir-list (list :wild))
                   :name nil
                   :type nil
                   :version nil
                   :defaults dir)))

(defun %safe-directory (wildcard)
  (handler-case
      (directory wildcard)
    (error () nil)))

(defun %directory-entries (directory)
  (remove-duplicates
   (append (%safe-directory (%directory-entry-wildcard directory))
           (%safe-directory (%subdirectory-wildcard directory)))
   :test #'equal))

(defun %same-pathname-location-p (left right)
  (let ((left-path (%->pathname left))
        (right-path (%->pathname right)))
    (and (equal (pathname-host left-path) (pathname-host right-path))
         (equal (pathname-device left-path) (pathname-device right-path))
         (equal (pathname-directory left-path)
                (pathname-directory right-path)))))

(defun %direct-file-child-p (directory file)
  (%same-pathname-location-p
   (or (directory-exists-p directory) (%directory-pathname directory))
   (make-pathname :name nil
                  :type nil
                  :version nil
                  :defaults (%->pathname file))))

(defun %direct-directory-child-p (directory child)
  (let* ((parent (or (directory-exists-p directory)
                     (%directory-pathname directory)))
         (child-path (%directory-pathname child))
         (child-directory (pathname-directory child-path)))
    (and (cdr child-directory)
         (%same-pathname-location-p
          parent
          (make-pathname :directory (butlast child-directory)
                         :name nil
                         :type nil
                         :version nil
                         :defaults child-path)))))

(defun directory-files (directory)
  "Return files directly under DIRECTORY."
  (loop for entry in (%directory-entries directory)
        for directory-entry = (directory-exists-p entry)
        for file-entry = (and (not directory-entry)
                              (file-exists-p entry))
        when (and file-entry
                  (%direct-file-child-p directory file-entry))
          collect file-entry))

(defun subdirectories (directory)
  "Return subdirectories directly under DIRECTORY."
  (loop for entry in (%directory-entries directory)
        for directory-entry = (directory-exists-p entry)
        when (and directory-entry
                  (%direct-directory-child-p directory directory-entry))
          collect directory-entry))

(defun copy-file (source target)
  "Copy SOURCE file to TARGET."
  (ensure-directories-exist target)
  (with-open-file (in source :direction :input
                            :element-type '(unsigned-byte 8))
    (with-open-file (out target :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create
                                :element-type '(unsigned-byte 8))
      (loop for byte = (read-byte in nil nil)
            while byte
            do (write-byte byte out))))
  target)

(defun %safe-delete-directory-p (directory)
  (let ((namestring (namestring (%directory-pathname directory))))
    (and namestring
         (> (length namestring) 1)
         (not (string= namestring "/")))))

(defun %split-string (string separator)
  (let ((result '())
        (start 0)
        (len (length string)))
    (labels ((emit (end)
               (push (subseq string start end) result)))
      (loop for i from 0 below len do
        (when (char= (char string i) separator)
          (emit i)
          (setf start (1+ i))))
      (emit len))
    (nreverse result)))

(defparameter *default-executable-search-paths*
  '("/usr/local/bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin"
    "/opt/homebrew/bin" "/opt/local/bin")
  "Fallback executable search paths used by host internals.")

(defun %find-executable (program)
  (let ((search-dirs (append
                      (let ((path (getenv "PATH")))
                        (when path
                          (%split-string path #\:)))
                      *default-executable-search-paths*)))
    (loop for dir-path in search-dirs
          for dir = (directory-exists-p
                     (if (string= dir-path "") "." dir-path))
          when dir
            do (let ((found (file-exists-p
                             (merge-pathnames program dir))))
                 (when found
                   (return (namestring found)))))))

(defun delete-directory-tree (directory &key (validate t) (if-does-not-exist :ignore))
  "Delete DIRECTORY recursively."
  (let* ((dir (%directory-pathname directory))
         (existing-dir (directory-exists-p dir)))
    (cond
      ((not existing-dir)
       (ecase if-does-not-exist
         (:ignore nil)
         (:error (error "Directory does not exist: ~A" (namestring dir)))))
      ((and validate
            (not (%safe-delete-directory-p existing-dir)))
       (error "Refusing to delete unsafe directory: ~A" (namestring existing-dir)))
      (t
       (let ((rm (%find-executable "rm")))
         (unless rm
           (error "Failed to delete directory ~A: can't find rm executable."
                  (namestring existing-dir)))
         (multiple-value-bind (out err code)
             (run-program-sync (list rm "-rf" (namestring existing-dir))
                               :output :string
                               :error-output :string
                               :ignore-error-status t)
           (declare (ignore out))
           (unless (and (integerp code) (= code 0))
             (error "Failed to delete directory ~A: ~A"
                    (namestring existing-dir)
                    err))
           t))))))

(defun temporary-directory ()
  "Return the implementation's temporary directory pathname."
  (%directory-pathname
   (or (getenv "TMPDIR")
       (getenv "TEMP")
       (getenv "TMP")
       "/tmp/")))

(defun escape-sh-token (value)
  "Return VALUE escaped as one POSIX shell token."
  (let ((string (princ-to-string (or value ""))))
    (with-output-to-string (out)
      (write-char #\' out)
      (loop for char across string
            do (if (char= char #\')
                   (write-string "'\\''" out)
                   (write-char char out)))
      (write-char #\' out))))

(defun %host-temp-file (prefix type)
  (labels ((call-symbol (package-name symbol-name)
             (let ((package (find-package package-name)))
               (when package
                 (multiple-value-bind (symbol status)
                     (find-symbol symbol-name package)
                   (declare (ignore status))
                   (when (and symbol (fboundp symbol))
                     (ignore-errors (funcall symbol)))))))
           (process-token ()
             (or
              #+sbcl (call-symbol "SB-UNIX" "UNIX-GETPID")
              #+lispworks (call-symbol "SYSTEM" "GETPID")
              0))
           (urandom-token ()
             (ignore-errors
               (with-open-file (in "/dev/urandom"
                                   :direction :input
                                   :element-type '(unsigned-byte 8))
                 (let ((value 0))
                   (dotimes (i 8 value)
                     (setf value (+ (ash value 8)
                                    (read-byte in))))))))
           (unique-token ()
             (or (urandom-token)
                 (random 1000000000))))
    (loop repeat 1000
          for path = (merge-pathnames
                      (make-pathname
                       :name (format nil "~A-~36R-~A-~36R-~36R-~36R"
                                     prefix
                                     (or (process-token) 0)
                                     (gensym "TMP")
                                     (get-universal-time)
                                     (get-internal-real-time)
                                     (unique-token))
                       :type type)
                      (temporary-directory))
          unless (or (file-exists-p path)
                     (directory-exists-p path))
            return path
          finally
             (error "Failed to allocate a temporary file path for ~A.~@[~A~]"
                    prefix
                    type))))

(defun %delete-file-safely (path)
  (when path
    (ignore-errors
     (when (file-exists-p path)
       (delete-file path)))))

(defun %read-file-to-string (path)
  (if (file-exists-p path)
      (with-open-file (in path :direction :input)
        (with-output-to-string (out)
          (loop for char = (read-char in nil nil)
                while char
                do (write-char char out))))
      ""))

(defun %copy-stream-to-file (stream path)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
    (loop for char = (read-char stream nil nil)
          while char
          do (write-char char out)))
  path)

(defun %prepare-sync-input (input temp-files)
  (cond
    ((null input)
     (let ((path (%host-temp-file "han-host-empty-input" "tmp")))
       (with-open-file (out path :direction :output
                                 :if-exists :supersede
                                 :if-does-not-exist :create)
         (declare (ignorable out)))
       (values path (cons path temp-files))))
    ((eq input t)
     #+lispworks
     (let ((path (%host-temp-file "han-host-stdin" "tmp")))
       (%copy-stream-to-file *standard-input* path)
       (values path (cons path temp-files)))
     #-lispworks
     (values *standard-input* temp-files))
    ((streamp input)
     (let ((path (%host-temp-file "han-host-input" "tmp")))
       (%copy-stream-to-file input path)
       (values path (cons path temp-files))))
    (t
     (values input temp-files))))

(defun %prepare-sync-output
    (output temp-files prefix &optional (interactive-stream *standard-output*))
  (cond
    ((eq output :string)
     (let ((path (%host-temp-file prefix "tmp")))
       (values path path (cons path temp-files))))
    ((eq output t)
     (let ((path (%host-temp-file prefix "tmp")))
       (values path
               (list :replay path interactive-stream)
               (cons path temp-files))))
    ((streamp output)
     (let ((path (%host-temp-file prefix "tmp")))
       (values path
               (list :replay path output)
               (cons path temp-files))))
    (t
     (values output nil temp-files))))

(defun %finalize-sync-output (capture-file)
  (cond
    ((and (consp capture-file)
          (eq (first capture-file) :replay))
     (let ((string (%read-file-to-string (second capture-file)))
           (stream (third capture-file)))
       (when stream
         (write-string string stream)
         (finish-output stream))
       nil))
    (capture-file
     (%read-file-to-string capture-file))
    (t
     nil)))

(defun %cleanup-sync-temp-files (temp-files)
  (dolist (file temp-files)
    (%delete-file-safely file)))

(defun %signal-exit-code (exit-code signal-code)
  (cond
    ((integerp exit-code) exit-code)
    ((integerp signal-code) (+ 128 signal-code))
    (t exit-code)))

(defun %check-sync-exit-code (command exit-code ignore-error-status)
  (when (and (not ignore-error-status)
             (integerp exit-code)
             (not (= exit-code 0)))
    (error "Program exited with error code ~A: ~S" exit-code command))
  exit-code)
