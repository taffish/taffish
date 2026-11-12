(in-package :han.path)

(defun ->pathname (x)
  "Convert X to pathname. Accepts pathname or string."
  (let ((p (etypecase x
             (pathname x)
             (string (pathname x)))))
    (if (pathname-directory p)
        p
        (make-pathname :directory (han.host:pathname-directory-list p) :defaults p))))

(define-condition no-namestring (file-error) ()
  (:report "The host cannot express this pathname as a namestring."))

(defun ->namestring (x)
  "Return the host spelling of X, or signal a FILE-ERROR with its pathname."
  (let ((path (->pathname x)))
    (or (ignore-errors (namestring path))
        ;; An explicit :UNSPECIFIC type also denotes an extensionless filename.
        (and (eq (pathname-type path) :unspecific)
             (stringp (pathname-name path))
             (not (typep path 'logical-pathname))
             (ignore-errors (namestring (make-pathname :type nil :defaults path))))
        (error 'no-namestring :pathname path))))

(defun directory-pathname-p (x)
  "Return T if X looks like a directory pathname."
  (let ((p (->pathname x)))
    (and (member (pathname-name p) '(nil :unspecific))
         (member (pathname-type p) '(nil :unspecific))
         t)))

(defun directory-pathname (x)
  "Convert X to a directory pathname."
  (let ((p (->pathname x)))
    (if (and (null (pathname-name p)) (null (pathname-type p)))
        p
        (let ((file (unless (directory-pathname-p p) (file-namestring p))))
          (make-pathname
           :directory (if (plusp (length file))
                          (append (han.host:pathname-directory-list p) (list file))
                          (pathname-directory p))
           :name nil
           :type nil
           :version nil
           :defaults p)))))

(defun parent-directory-pathname (x)
  "Return X's directory with the file name and type cleared."
  (let ((p (->pathname x)))
    (if (and (null (pathname-name p)) (null (pathname-type p)))
        p
        (make-pathname :name nil :type nil :version nil :defaults p))))

(defun %join-path-2 (base child)
  "Join BASE and CHILD into one pathname."
  (let ((base-dir (directory-pathname base))
        (child-p (->pathname child)))
    (merge-pathnames child-p base-dir)))

(defun join-path (base &rest parts)
  "Join BASE with one or more path PARTS and return a pathname."
  (reduce #'%join-path-2
          parts
          :initial-value (->pathname base)))

(defun absolute-pathname-p (x)
  "Return T if X is an absolute pathname."
  (let ((directory (pathname-directory (->pathname x))))
    (or (stringp directory)
        (eq directory :wild)
        (and (consp directory) (eq (first directory) :absolute)))))

(defun absolute-pathname (x &optional (base nil base-supplied-p))
  "Return an absolute pathname for X relative to BASE."
  (let ((p (->pathname x)))
    (if (absolute-pathname-p p)
        p
        (merge-pathnames
         p (directory-pathname
            (if base-supplied-p base (han.host:working-directory-pathname)))))))

(defun %common-prefix-length (a b)
  (loop for x in a
        for y in b
        while (equal x y)
        count 1))

(defun relative-path (target &optional (base (han.host:working-directory-pathname)))
  "Return TARGET as a pathname relative to BASE when possible."
  (let* ((target-p (absolute-pathname target))
         (base-p   (directory-pathname (absolute-pathname base))))
    (if (or (not (equal (pathname-host target-p) (pathname-host base-p)))
            (not (equal (pathname-device target-p) (pathname-device base-p))))
        target-p
        (let* ((target-dir (han.host:pathname-directory-list target-p))
               (base-dir (han.host:pathname-directory-list base-p))
               (common-len (%common-prefix-length target-dir base-dir))
               (target-rest (nthcdr common-len target-dir))
               (base-rest   (nthcdr common-len base-dir)))
          ;; Logical namestrings have no spelling for a parent step.
          (if (and base-rest (typep target-p 'logical-pathname))
              target-p
              (make-pathname
               :directory (cons :relative
                                (append (make-list (length base-rest) :initial-element :up)
                                        target-rest))
               :name (pathname-name target-p)
               :type (pathname-type target-p)
               :version (pathname-version target-p)
               :defaults target-p))))))

(defun file-exists-p (path)
  "Return the truename/pathname of PATH when it names an existing file, else NIL."
  (han.host:file-exists-p path))

(defun directory-exists-p (path)
  "Return the directory pathname of PATH when it names an existing directory, else NIL."
  (han.host:directory-exists-p (directory-pathname path)))

(defun directory-files (directory)
  "Return files directly under DIRECTORY."
  (han.host:directory-files (directory-pathname directory)))

(defun subdirectories (directory)
  "Return subdirectories directly under DIRECTORY."
  (han.host:subdirectories (directory-pathname directory)))

(defun copy-file (source target)
  "Copy SOURCE file to TARGET."
  (han.host:copy-file source target))

(defun delete-directory-tree (directory &key (validate t) (if-does-not-exist :ignore))
  "Delete DIRECTORY recursively."
  (han.host:delete-directory-tree
   (directory-pathname directory)
   :validate validate
   :if-does-not-exist if-does-not-exist))

(defun temporary-directory ()
  "Return the implementation's temporary directory pathname."
  (han.host:temporary-directory))
