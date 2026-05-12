(in-package :han.path)

(defun %normalize-directory-list (dir &optional (default-kind :relative))
  "Normalize DIR into a CL pathname directory list.
If DIR is NIL, return a default relative/absolute root according to DEFAULT-KIND.
If DIR already begins with a recognized keyword, return it unchanged.
Otherwise treat it as a relative directory list."
  (cond
    ((null dir)
     (list default-kind))
    ((and (consp dir)
          (keywordp (first dir)))
     dir)
    (t
     (cons default-kind dir))))

(defun ->pathname (x)
  "Convert X to pathname. Accepts pathname or string."
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

(defun ->namestring (x)
  "Convert X to namestring. Accepts pathname or string."
  (namestring (->pathname x)))

(defun directory-pathname-p (x)
  "Return T if X looks like a directory pathname."
  (let* ((p (->pathname x))
         (dir (%normalize-directory-list (pathname-directory p))))
    (and dir
         (null (pathname-name p))
         (null (pathname-type p)))))

(defun directory-pathname (x)
  "Convert X to a directory pathname."
  (let* ((p (->pathname x))
         (dir (%normalize-directory-list (pathname-directory p))))
    (if (directory-pathname-p p)
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

(defun parent-directory-pathname (x)
  "Return the parent directory pathname of X.
If X is already a directory pathname, return it unchanged."
  (let* ((p (->pathname x))
         (dir (%normalize-directory-list (pathname-directory p))))
    (if (directory-pathname-p p)
        p
        (make-pathname
         :host (pathname-host p)
         :device (pathname-device p)
         :directory dir
         :name nil
         :type nil
         :version nil
         :defaults p))))

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
  (let* ((p (->pathname x))
         (dir (%normalize-directory-list (pathname-directory p))))
    (and (consp dir)
         (eq (first dir) :absolute))))

(defun absolute-pathname (x &optional (base (truename ".")))
  "Return an absolute pathname for X relative to BASE."
  (let ((p (->pathname x)))
    (if (absolute-pathname-p p)
        p
        (merge-pathnames p (directory-pathname base)))))

(defun %pathname-directory-list (p)
  (%normalize-directory-list (pathname-directory (->pathname p))))

(defun %common-prefix-length (a b)
  (loop for x in a
        for y in b
        while (equal x y)
        count 1))

(defun relative-path (target &optional (base (truename ".")))
  "Return TARGET as a pathname relative to BASE when possible."
  (let* ((target-p (absolute-pathname target))
         (base-p   (directory-pathname (absolute-pathname base)))
         (target-dir (%pathname-directory-list target-p))
         (base-dir   (%pathname-directory-list base-p)))
    (if (or (not (equal (pathname-host target-p) (pathname-host base-p)))
            (not (equal (pathname-device target-p) (pathname-device base-p))))
        ;; 如果 host/device 都不一样，就没法好好相对化，直接返回 target
        target-p
        (let* ((common-len (%common-prefix-length target-dir base-dir))
               (target-rest (nthcdr common-len target-dir))
               (base-rest   (nthcdr common-len base-dir))
               (up-list (make-list (length base-rest) :initial-element :up))
               (new-dir (cons :relative
                              (append up-list target-rest))))
          (make-pathname
           :directory new-dir
           :name (pathname-name target-p)
           :type (pathname-type target-p)
           :version (pathname-version target-p))))))

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
