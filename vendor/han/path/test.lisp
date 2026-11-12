(in-package :han.test)

(deftest test-han-path-help-and-version ()
  (let ((help-string (han.path:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.path" help-string))
    (check-true (search "join-path" help-string)))
  (check-equal "0.3.0" (han.path:version nil)))

(deftest test-->pathname ()
  (check-true (pathnamep (han.path:->pathname ".")))
  (let ((p (han.path:->pathname ".")))
    (check-equal (file-namestring (pathname ".")) (file-namestring p))
    (check-equal (namestring p) (han.path:->namestring p)))
  (check-equal (han.path:->pathname "/usr/local/bin")
               #P"/usr/local/bin"))

(deftest test-pathname-directory-components ()
  (check-equal '(:relative)
               (han.host:pathname-directory-list (make-pathname :directory nil :name "input")))
  (let ((top (make-pathname :directory "project" :name "report" :type "txt")))
    (check-true (han.path:absolute-pathname-p top))
    (check-equal '(:absolute "project") (han.host:pathname-directory-list top))
    (check-equal '(:absolute "project" "report.txt")
                 (han.host:pathname-directory-list (han.path:directory-pathname top))))
  (let ((wild (make-pathname :directory :wild :name "result")))
    (check-true (han.path:absolute-pathname-p wild))
    (check-true (wild-pathname-p (han.path:->pathname wild) :directory))
    (when (consp (pathname-directory wild))
      (check-equal (pathname-directory wild) (han.host:pathname-directory-list wild))))
  (check-error (type-error) (han.host:pathname-directory-list 17)))

(deftest test-->namestring ()
  (check-true (stringp (han.path:->namestring #P"/bin/sh")))
  (check-equal (han.path:->namestring #P"/bin/sh") "/bin/sh"))

(deftest test-namestring-extensionless-physical-file ()
  (let* ((path (make-pathname :directory '(:relative "bin") :name "wrapper"
                              :type :unspecific :version :newest))
         (original-type (pathname-type path)))
    (check-equal "bin/wrapper" (han.path:->namestring path))
    (check-equal original-type (pathname-type path)))
  (let ((pattern #P"reports/*.tsv"))
    (check-equal (namestring pattern) (han.path:->namestring pattern)))
  (check-error (type-error) (han.path:->namestring 42)))

(deftest test-namestring-without-file-name ()
  ;; Some hosts can spell this combination. Preserve their native spelling.
  (let* ((path (make-pathname :directory '(:relative "bin") :name nil :type "txt"))
         (native (ignore-errors (namestring path))))
    (if native
        (check-equal native (han.path:->namestring path))
        (handler-case (progn (han.path:->namestring path)
                             (error "Expected a FILE-ERROR for a pathname without a namestring."))
          (file-error (condition)
            (check-true (eq path (file-error-pathname condition))))))))

(deftest test-han-path-directory-pathname-p ()
  (check-equal (han.path:directory-pathname-p #P"/tmp/") t)
  (check-equal (han.path:directory-pathname-p (han.path:directory-pathname "/tmp")) t)
  (check-equal (han.path:directory-pathname-p #P"/tmp/a.txt") nil)
  (check-equal (han.path:directory-pathname-p "/tmp/a.txt") nil)
  ;; relative directory pathname
  (check-equal (han.path:directory-pathname-p
                (make-pathname :directory '(:relative "foo" "bar")
                               :name nil
                               :type nil))
               t)
  ;; file-like relative pathname
  (check-equal (han.path:directory-pathname-p
                (make-pathname :directory '(:relative "foo")
                               :name "bar"
                               :type "txt"))
               nil))

(deftest test-directory-pathname ()
  (check-true (pathnamep (han.path:directory-pathname "/bin")))
  (check-equal (han.path:directory-pathname "/bin/test.sh") #P"/bin/test.sh/")
  (check-equal (han.path:directory-pathname "/bin") #P"/bin/"))

(deftest test-parent-directory-pathname ()
  (check-true (pathnamep (han.path:parent-directory-pathname "/bin")))
  (check-equal (han.path:parent-directory-pathname "/bin/test.sh") #P"/bin/")
  (check-equal (han.path:parent-directory-pathname "/bin") #P"/"))

(deftest test-join-path ()
  (check-true (pathnamep (han.path:join-path "/" "usr" "bin" "somebin")))
  (check-equal (han.path:->namestring (han.path:join-path "/" "usr" "bin" "somebin"))
               "/usr/bin/somebin"))

(deftest test-absolute-pathname-p ()
  (check-true (han.path:absolute-pathname-p
               (han.path:join-path "/" "bin" "sh")))
  (check-false (han.path:absolute-pathname-p
                (han.path:join-path "./" "src" "core.lisp"))))

(deftest test-absolute-pathname ()
  (check-true (han.path:absolute-pathname-p
               (han.path:absolute-pathname
                (han.path:join-path "./" "src" "core.lisp"))))
  (check-false (han.path:absolute-pathname-p
                (han.path:join-path "./" "src" "core.lisp")))
  (check-equal (merge-pathnames "input.lisp" (han.host:working-directory-pathname))
               (han.path:absolute-pathname "input.lisp"))
  (check-equal "/base/input.lisp" (namestring (han.path:absolute-pathname "input.lisp" "/base/"))))

(deftest test-relative-path ()
  (check-false (han.path:absolute-pathname-p
                (han.path:relative-path "/usr/local/bin/somebin"
                                        "/usr/local")))
  (check-equal (han.path:relative-path "/usr/local/bin/somebin"
                                       "/usr/local")
               #P"bin/somebin"))

(deftest test-relative-path-logical-host ()
  (unless (ignore-errors (logical-pathname-translations "HAN-PATH-TEST"))
    (setf (logical-pathname-translations "HAN-PATH-TEST")
          '(("RUN;DATA;FILE.LISP.NEWEST" "file.lisp"))))
  (let* ((target (logical-pathname "HAN-PATH-TEST:RUN;DATA;FILE.LISP.NEWEST"))
         (base (logical-pathname "HAN-PATH-TEST:RUN;"))
         (relative (han.path:relative-path target base)))
    (check-true (typep relative 'logical-pathname))
    (check-equal (pathname-host target) (pathname-host relative))
    (check-equal '(:relative "DATA") (pathname-directory relative))
    (check-equal target (merge-pathnames relative base))
    (check-equal target (han.path:relative-path target (logical-pathname "HAN-PATH-TEST:OTHER;")))))

(deftest test-join-path-absolute-child-and-dotted-directory ()
  (let ((path (han.path:join-path "local/" "cache" "/shared/" "build.v2" "index.json")))
    (check-equal '(:absolute "shared" "build.v2") (pathname-directory path))
    (check-equal "index" (pathname-name path))
    (check-equal "json" (pathname-type path)))
  (let ((base (han.path:join-path "local/cache")))
    (check-false (han.path:absolute-pathname-p base))
    (check-equal "cache" (pathname-name base))))

(deftest test-relative-path-physical-parent-steps ()
  (let* ((target #P"/runs/input/reads.fq")
         (relative (han.path:relative-path target #P"/runs/jobs/current/")))
    (check-equal '(:relative :up :up "input") (pathname-directory relative))
    (check-equal (pathname-name target) (pathname-name relative))
    (check-equal (pathname-type target) (pathname-type relative)))
  (let* ((base #P"/runs/input/")
         (relative-directory (han.path:relative-path #P"/runs/input/results/" base)))
    (check-true (han.path:directory-pathname-p relative-directory))
    (check-equal '(:relative "results") (pathname-directory relative-directory))))

(defun %make-path-test-directory ()
  (let ((mktemp (or (han.host:find-executable "mktemp")
                    (error "The pathname tests require mktemp.")))
        (template (merge-pathnames "han-path-test-XXXXXXXX" (han.path:temporary-directory))))
    (han.path:directory-pathname
     (string-right-trim '(#\Newline)
                        (han.host:run-program-sync (list mktemp "-d" (namestring template))
                                                   :output :string :error-output :string
                                                   :ignore-error-status nil)))))

(deftest test-path-directory-listing-and-probes ()
  (let* ((root (%make-path-test-directory))
         (file (merge-pathnames "top.bin" root))
         (subdir (merge-pathnames "results.v2/" root))
         (nested (merge-pathnames "day1/deep.bin" subdir)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested)
           (dolist (path (list file nested))
             (with-open-file (out path :direction :output :if-exists :error)
               (write-line "fixture" out)))
           (check-equal (truename file) (han.path:file-exists-p file))
           (check-false (han.path:directory-exists-p file))
           (let ((found (han.path:directory-exists-p subdir)))
             (check-true (pathnamep found))
             (check-equal (truename subdir) (truename found)))
           (check-false (han.path:file-exists-p subdir))
           (check-equal (list (truename file)) (han.path:directory-files root))
           (let ((children (han.path:subdirectories root)))
             (check-true (every #'pathnamep children))
             (check-equal (list (truename subdir)) (mapcar #'truename children))))
      (han.host:delete-directory-tree root))))

(deftest test-path-copy-and-delete-tree ()
  (let* ((root (%make-path-test-directory))
         (source (merge-pathnames "source.bin" root))
         (target (namestring (merge-pathnames "archive/copy.bin" root))))
    (unwind-protect
         (progn
           (with-open-file (out source :direction :output :element-type '(unsigned-byte 8))
             (write-sequence #(1 2 3 4 5) out))
           (check-true (eq target (han.path:copy-file source target)))
           (with-open-file (out source :direction :output :if-exists :supersede
                                :element-type '(unsigned-byte 8))
             (write-sequence #(0 255) out))
           (check-true (eq target (han.path:copy-file source target)))
           (with-open-file (in target :element-type '(unsigned-byte 8))
             (check-equal '(0 255 :eof)
                          (list (read-byte in) (read-byte in) (read-byte in nil :eof))))
           (check-equal t (han.path:delete-directory-tree root))
           (check-false (probe-file target))
           (check-equal nil (han.path:delete-directory-tree root :if-does-not-exist :ignore))
           (check-error (simple-error)
             (han.path:delete-directory-tree root :if-does-not-exist :error)))
      (han.host:delete-directory-tree root :if-does-not-exist :ignore))))
