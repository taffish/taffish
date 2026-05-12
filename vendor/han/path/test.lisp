(in-package :han.test)

(deftest test-han-path-help-and-version ()
  (let ((help-string (han.path:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.path" help-string))
    (check-true (search "join-path" help-string)))
  (check-equal "0.1.0" (han.path:version nil)))

(deftest test-->pathname ()
  (check-true (pathnamep (han.path:->pathname ".")))
  (let ((s (han.path:->namestring (han.path:->pathname "."))))
    (check-true (member s '("" ".") :test #'equal)))
  (check-equal (han.path:->pathname "/usr/local/bin")
               #P"/usr/local/bin"))

(deftest test-->namestring ()
  (check-true (stringp (han.path:->namestring #P"/bin/sh")))
  (check-equal (han.path:->namestring #P"/bin/sh") "/bin/sh"))

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
                (han.path:join-path "./" "src" "core.lisp"))))

(deftest test-relative-path ()
  (check-false (han.path:absolute-pathname-p
                (han.path:relative-path "/usr/local/bin/somebin"
                                        "/usr/local")))
  (check-equal (han.path:relative-path "/usr/local/bin/somebin"
                                       "/usr/local")
               #P"bin/somebin"))
