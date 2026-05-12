(in-package :han.test)

;;;; ============================================================
;;;; han.host tests
;;;; ============================================================

(defun non-empty-string-p (x)
  (and (stringp x)
       (> (length x) 0)))

(defun string-or-nil-p (x)
  (or (null x) (stringp x)))

(defun integer-or-nil-p (x)
  (or (null x) (integerp x)))

(defun stream-or-nil-p (x)
  (or (null x) (streamp x)))

(defun %han-host-temp-file (prefix type)
  (let ((symbol (find-symbol "%HOST-TEMP-FILE" "HAN.HOST")))
    (unless (and symbol (fboundp symbol))
      (error "Can't find HAN.HOST::%HOST-TEMP-FILE."))
    (funcall symbol prefix type)))

(defun %unique-string-list-p (strings)
  (= (length strings)
     (length (remove-duplicates strings :test #'string=))))

(unless (fboundp 'signal-error-p)
  (defun signal-error-p (thunk)
    (handler-case
        (progn
          (funcall thunk)
          nil)
      (error () t))))

(defun %han-host-test-directory ()
  (merge-pathnames
   (make-pathname :directory
                  (list :relative
                        (format nil "han-host-test-~A-~A"
                                (get-universal-time)
                                (random 1000000)))
                  :name nil
                  :type nil)
   (han.host:temporary-directory)))

(deftest test-han-test-help-and-version ()
  (let ((help-string (han.test:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.test" help-string))
    (check-true (search "run-all-tests" help-string)))
  (check-equal "0.1.0" (han.test:version nil)))

(deftest test-han-host-help-and-version ()
  (let ((help-string (han.host:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.host" help-string))
    (check-true (search "run-program" help-string)))
  (check-equal "0.1.0" (han.host:version nil)))

(deftest test-host-argv ()
  (let ((argv (han.host:argv)))
    (check-equal (listp argv) t)
    ;; argv 里的每一项通常都应是 string
    (check-equal
     (every #'stringp argv)
     t)))

(deftest test-host-run-program-basic ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "printf hello"))))
    (check-equal (null process) nil)
    (check-equal
     (stream-or-nil-p (han.host:host-process-output-stream process))
     t)
    (check-equal
     (stream-or-nil-p (han.host:host-process-error-stream process))
     t)
    (check-equal
     (integer-or-nil-p (han.host:host-process-pid process))
     t)
    (han.host:process-wait process)
    (check-equal
     (integerp (han.host:process-exit-code process))
     t)
    (check-equal
     (han.host:process-exit-code process)
     0)
    (han.host:process-close process)))

(deftest test-host-run-program-nonzero-exit ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "exit 7"))))
    (han.host:process-wait process)
    (check-equal (han.host:process-exit-code process) 7)
    (han.host:process-close process)))

(deftest test-host-run-program-sync-default-input-is-eof ()
  (multiple-value-bind (out err code)
      (han.host:run-program-sync
       (list "/bin/sh" "-c" "cat")
       :output :string
       :error-output :string
       :ignore-error-status t)
    (check-equal code 0)
    (check-equal out "")
    (check-equal err "")))

(deftest test-host-run-program-sync-input-t-uses-standard-input ()
  (with-input-from-string (*standard-input* "abc")
    (multiple-value-bind (out err code)
        (han.host:run-program-sync
         (list "/bin/sh" "-c" "cat")
         :input t
         :output :string
         :error-output :string
         :ignore-error-status t)
      (check-equal code 0)
      (check-equal out "abc")
      (check-equal err ""))))

(deftest test-host-run-program-sync-output-t-replays-to-standard-output ()
  (let ((captured
          (with-output-to-string (*standard-output*)
            (multiple-value-bind (out err code)
                (han.host:run-program-sync
                 (list "/bin/sh" "-c" "printf replay")
                 :output t
                 :error-output :string
                 :ignore-error-status t)
              (check-equal code 0)
              (check-equal out nil)
              (check-equal err "")))))
    (check-equal captured "replay")))

(deftest test-host-run-program-output ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "printf hello"))))
    (han.host:process-wait process)
    (let ((out (han.host:host-process-output-stream process)))
      (check-equal (streamp out) t)
      (check-equal (read-line out nil "") "hello"))
    (han.host:process-close process)))

(deftest test-host-run-program-error-output ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "printf oops 1>&2"))))
    (han.host:process-wait process)
    (let ((err (han.host:host-process-error-stream process)))
      (check-equal (streamp err) t)
      (check-equal (read-line err nil "") "oops"))
    (han.host:process-close process)))

(deftest test-host-run-program-both-streams ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "printf out; printf err 1>&2"))))
    (han.host:process-wait process)
    (let ((out (han.host:host-process-output-stream process))
          (err (han.host:host-process-error-stream process)))
      (check-equal (read-line out nil "") "out")
      (check-equal (read-line err nil "") "err"))
    (han.host:process-close process)))

(deftest test-host-process-close-safe-after-wait ()
  (let ((process (han.host:run-program "/bin/sh"
                                       :arguments (list "-c" "printf ok"))))
    (han.host:process-wait process)
    (check-equal
     (signal-error-p (lambda () (han.host:process-close process)))
     nil)))

(deftest test-host-invalid-program-error ()
  (check-equal
   (signal-error-p
    (lambda ()
      (han.host:run-program "/definitely/not/exist/program"
                            :arguments nil)))
   t))

(deftest test-host-temp-file-generates-unique-non-existing-paths ()
  (let ((names nil))
    (loop repeat 100 do
      (let ((path (%han-host-temp-file "han-host-output" "tmp")))
        (check-false (han.host:file-exists-p path))
        (check-false (han.host:directory-exists-p path))
        (push (namestring path) names)))
    (check-true (%unique-string-list-p names))))

(deftest test-host-temp-file-unique-with-repeated-image-state ()
  ;; Regression test for SBCL saved-image style collisions: two separately
  ;; started images can share gensym/random/time state, so temp names must use
  ;; process/OS-level entropy instead of only CL image-local state.
  (let ((seed (make-random-state t))
        (names nil))
    (loop repeat 40 do
      (let ((*gensym-counter* 130)
            (*random-state* (make-random-state seed)))
        (push (namestring (%han-host-temp-file "han-host-output" "tmp"))
              names)))
    (check-true (%unique-string-list-p names))))

(deftest test-host-file-directory-helpers-without-uiop ()
  (let* ((root (%han-host-test-directory))
         (file (merge-pathnames "a.txt" root))
         (copy (merge-pathnames "copy/a.txt" root))
         (subdir (merge-pathnames "sub/" root))
         (nested (merge-pathnames "b" subdir)))
    (unwind-protect
         (progn
           (ensure-directories-exist file)
           (with-open-file (out file :direction :output
                                     :if-exists :supersede
                                     :if-does-not-exist :create)
             (write-string "hello" out))
           (ensure-directories-exist nested)
           (with-open-file (out nested :direction :output
                                       :if-exists :supersede
                                       :if-does-not-exist :create)
             (write-string "world" out))
           (check-true (han.host:file-exists-p file))
           (check-true (han.host:directory-exists-p root))
           (check-true (han.host:directory-exists-p subdir))
           (check-true
            (find "a.txt"
                  (mapcar #'file-namestring
                          (han.host:directory-files root))
                  :test #'equal))
           (check-true
            (find "sub"
                  (mapcar (lambda (path)
                            (car (last (pathname-directory path))))
                          (han.host:subdirectories root))
                  :test #'equal))
           (check-equal
            (every (lambda (path)
                     (and (null (pathname-name path))
                          (null (pathname-type path))))
                   (han.host:subdirectories root))
            t)
           (han.host:copy-file file copy)
           (check-true (han.host:file-exists-p copy))
           (check-equal
            (han.host:escape-sh-token "a'b")
            "'a'\\''b'")
           (han.host:delete-directory-tree root)
           (check-false (han.host:directory-exists-p root)))
      (ignore-errors
        (when (han.host:directory-exists-p root)
          (han.host:delete-directory-tree root))))))
