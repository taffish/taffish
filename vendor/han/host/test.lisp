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

(deftest test-han-host-help-and-version ()
  (let ((help-string (han.host:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.host" help-string))
    (check-true (search "standard-error-terminal-p" help-string))
    (check-true (search "fd 2" help-string))
    (check-true (search "closed stderr returns NIL" help-string))
    (check-true (search "run-program" help-string)))
  (check-equal "0.3.0" (han.host:version nil)))

(deftest test-host-argv ()
  (let ((argv (han.host:argv)))
    (check-equal (listp argv) t)
    ;; argv 里的每一项通常都应是 string
    (check-equal
     (every #'stringp argv)
     t)))

#+ecl
(deftest test-host-ecl-long-utf8-argv-and-environment ()
  (let ((text (with-output-to-string (out nil :element-type 'character)
                (loop repeat 2048 do (write-string "样本-1-é😀-" out)))))
    (uiop:with-temporary-file (:stream out :pathname script :type "lisp" :external-format :utf-8)
      (write-line "(require :asdf)" out)
      (format out "(asdf:load-asd ~S)~%(asdf:load-system \"han\")~%" (asdf:system-source-file "han"))
      ;; Read the expected value from the script, independently of the OS strings.
      (format out "(let ((expected ~S) (args (rest (member \"--\" (han.host:argv) :test #'string=))))~%"
              text)
      (write-line "  (han.host:quit (if (and (equal args (list expected \"\"))" out)
      (write-line "                           (equal expected (han.host:getenv \"HAN_LONG_UTF8\"))) 0 1)))" out)
      :close-stream
      (check-equal 0
                   (nth-value 2
                     (han.host:run-program-sync
                      (list "/usr/bin/env" (concatenate 'string "HAN_LONG_UTF8=" text)
                            (first (han.host:argv t)) "-norc" "-shell" (namestring script)
                            "--" text "")))))))

(deftest test-host-configure-runtime-io ()
  (check-true (han.host:prepare-runtime-io))
  (check-true (han.host:configure-runtime-io)))

(deftest test-host-working-directory-resolution-and-failure ()
  (let ((root (%han-host-test-directory)))
    (unwind-protect
         (progn
           (ensure-directories-exist (merge-pathnames "anchor" root))
           (let ((*default-pathname-defaults* root))
             (check-equal (namestring (truename root))
                          (namestring (han.host:working-directory-pathname)))
             (check-equal (namestring (truename root)) (han.host:cwd)))
           (let ((*default-pathname-defaults* (merge-pathnames "missing/" root)))
             (check-error (error) (han.host:working-directory-pathname))
             (check-false (han.host:cwd))))
      (han.host:delete-directory-tree root))))

(deftest test-host-shell-command-argv-preserves-command-and-shell ()
  (let ((command "printf '%s' 'with spaces; and a dollar $'")
        (explicit #P"/bin/sh"))
    (check-equal (list explicit "-c" command)
                 (han.host:shell-command-argv command explicit))
    (check-equal (list (or (han.host:find-executable "bash")
                           (han.host:find-executable "sh"))
                       "-c" command)
                 (han.host:shell-command-argv command))
    (check-error (simple-error)
      (han.host:shell-command-argv command (%han-host-temp-file "missing-shell" nil)))))

(deftest test-host-unicode-scalar-boundaries ()
  (dolist (bad '(nil 1/2 -1 #xD800 #xDBFF #xDC00 #xDFFF #x110000))
    (check-false (han.host:unicode-scalar-char bad)))
  (check-equal #x41 (han.host:char-unicode-scalar #\A))
  (dolist (code '(#xD7FF #xE000 #x1F600))
    (check-equal code (han.host:char-unicode-scalar (han.host:unicode-scalar-char code))))
  (check-error (type-error) (han.host:char-unicode-scalar #x41)))

(define-condition %host-test-unprintable-error (error) ()
  (:report (lambda (condition stream)
             (declare (ignore condition stream))
             (error "report failed"))))

(deftest test-host-cli-boundary-preserves-values ()
  (check-equal '(42 :second)
               (multiple-value-list
                (han.host::%with-cli-error-boundary ("[TEST]")
                  (values 42 :second)))))

(deftest test-host-cli-boundary-reports-error ()
  (let ((*standard-output* (make-string-output-stream))
        (*error-output* (make-string-output-stream)))
    (flet ((han.host:quit (&optional (code 0)) (throw 'cli-exit code)))
      (check-equal 1
                   (catch 'cli-exit
                     (han.host::%with-cli-error-boundary ("[TEST]")
                       (error "expected failure")))))
    (check-equal (format nil "[TEST] expected failure~%")
                 (get-output-stream-string *error-output*))
    (check-equal "" (get-output-stream-string *standard-output*))))

(deftest test-host-cli-boundary-tolerates-report-failure ()
  (let ((*standard-output* (make-string-output-stream))
        (*error-output* (make-string-output-stream)))
    (flet ((han.host:quit (&optional (code 0)) (throw 'cli-exit code)))
      (check-equal 1
                   (catch 'cli-exit
                     (han.host::%with-cli-error-boundary ("[TEST]")
                       (error '%host-test-unprintable-error)))))
    (check-equal "" (get-output-stream-string *standard-output*))))

(deftest test-host-cli-boundary-tolerates-unwritable-stderr ()
  (let ((*standard-output* (make-string-output-stream))
        (*error-output* (make-string-input-stream "")))
    (flet ((han.host:quit (&optional (code 0)) (throw 'cli-exit code)))
      (check-equal 1
                   (catch 'cli-exit
                     (han.host::%with-cli-error-boundary ("[TEST]")
                       (error "expected failure")))))
    (check-equal "" (get-output-stream-string *standard-output*))))

(deftest test-host-cli-boundary-preserves-warnings-and-conditions ()
  (let ((warnings 0) (conditions 0))
    (handler-bind
        ((warning (lambda (condition)
                    (incf warnings)
                    (muffle-warning condition)))
         (simple-condition (lambda (condition)
                             (unless (typep condition 'warning)
                               (incf conditions)))))
      (check-equal :continued
                   (han.host::%with-cli-error-boundary ("[TEST]")
                     (warn "expected warning")
                     (signal 'simple-condition :format-control "notice")
                     :continued)))
    (check-equal 1 warnings)
    (check-equal 1 conditions)))

(deftest test-host-exit-flush-preserves-requested-status ()
  (let ((*standard-output* (make-string-output-stream))
        (*error-output* (make-string-output-stream)))
    (write-string "out" *standard-output*)
    (write-string "err" *error-output*)
    (check-equal 0 (han.host::%finish-exit-output 0))
    (check-equal 7 (han.host::%finish-exit-output 7))
    (check-equal "out" (get-output-stream-string *standard-output*))
    (check-equal "err" (get-output-stream-string *error-output*))))

#+(or sbcl ecl ccl)
(deftest test-host-cli-boundary-interrupt-exits-without-debugger ()
  (let ((*error-output* (make-string-output-stream)))
    (flet ((han.host:quit (&optional (code 0)) (throw 'cli-exit code)))
      (check-equal 1
                   (catch 'cli-exit
                     (han.host::%with-cli-error-boundary ("[TEST]")
                       (signal #+sbcl 'sb-sys:interactive-interrupt
                               #+ecl 'ext:interactive-interrupt
                               #+ccl 'ccl::interrupt-signal-condition)))))
    (check-equal (format nil "[TEST] Interrupted.~%")
                 (get-output-stream-string *error-output*))))

(deftest test-host-full-character-output-string ()
  (let* ((character (code-char #x9879))
         (string
           (han.host:with-character-output-to-string (out)
             (write-string "probe-" out)
             (write-char character out))))
    (check-equal (char string (1- (length string))) character)
    (check-true (typep string 'string))))

(deftest test-host-standard-input-terminal-p-returns-boolean ()
  (check-true
   (member (han.host:standard-input-terminal-p) '(nil t))))

(deftest test-host-standard-error-terminal-p-returns-boolean ()
  (check-true
   (member (han.host:standard-error-terminal-p) '(nil t)))
  (check-equal :external
               (nth-value 1 (find-symbol "STANDARD-ERROR-TERMINAL-P" :han.host))))

(deftest test-host-standard-error-terminal-p-has-no-stream-effects ()
  (with-input-from-string (*standard-input* "unread")
    (let ((*standard-output* (make-string-output-stream))
          (*error-output* (make-string-output-stream)))
      (check-true (member (han.host:standard-error-terminal-p) '(nil t)))
      (check-equal "" (get-output-stream-string *standard-output*))
      (check-equal "" (get-output-stream-string *error-output*))
      (close *error-output*)
      (check-true (member (han.host:standard-error-terminal-p) '(nil t)))
      (check-equal "unread" (read-line *standard-input*)))))

#+lispworks
(deftest test-host-runtime-output-interactivity-follows-descriptor ()
  (let ((stream (han.host::%lispworks-runtime-output 2)))
    (check-equal (han.host:standard-error-terminal-p)
                 (not (null (interactive-stream-p stream))))
    (check-equal 0 (han.host::%lispworks-output-line-column stream)))
  (let ((stream (han.host::%lispworks-runtime-output -1)))
    (check-false (interactive-stream-p stream))
    (close stream)
    (check-false (interactive-stream-p stream)))
  (let ((*error-output* (make-string-output-stream)))
    (check-false (interactive-stream-p *error-output*))
    (check-equal "" (get-output-stream-string *error-output*))))

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

#+(or sbcl lispworks ecl ccl)
(deftest test-host-child-terminated-by-sigterm ()
  (let* ((command '("/bin/sh" "-c" "printf out; printf err >&2; kill -TERM $$"))
         (expected #+sbcl 15 #+(or lispworks ecl ccl) 143))
    (check-equal '("" "" 15)
                 (multiple-value-list (han.host:run-program-sync '("/bin/sh" "-c" "exit 15"))))
    (check-equal (list "out" "err" expected)
                 (multiple-value-list (han.host:run-program-sync command)))
    (check-error (simple-error)
      (han.host:run-program-sync command :ignore-error-status nil))
    (let ((child (han.host:run-program (first command) :arguments (rest command))))
      (unwind-protect
           (progn
             (han.host:process-wait child)
             (check-equal :exited (han.host:process-status child))
             (check-equal expected (han.host:process-exit-code child)))
        (han.host:process-close child)))))

#+(and lispworks (or darwin macosx linux))
(deftest test-host-lispworks-async-working-directory ()
  (let* ((parent (han.host:working-directory-pathname))
         (root (%han-host-test-directory))
         (worker (merge-pathnames "script ' = worker" root))
         (input (merge-pathnames "input.txt" root)))
    (unwind-protect
         (progn
           (ensure-directories-exist worker)
           (with-open-file (out worker :direction :output :if-exists :error)
             (dolist (line '("#!/bin/sh" "test -f marker || exit 91"
                             "IFS= read -r line"
                             "printf '%s\\n' \"$$\" \"$1\" \"$line\" \"$HAN_CWD_VALUE\""
                             "printf diagnostic >&2" "kill -TERM $$"))
               (write-line line out)))
           (with-open-file (out input :direction :output :if-exists :error)
             (write-line "stdin" out))
           (han.host:run-program-sync (list "/bin/chmod" "700" (namestring worker))
                                      :ignore-error-status nil)
           (dotimes (i 20)
             (let* ((leaf (format nil "cwd 汉 ' = ~A/" (make-string i :initial-element #\x)))
                    (dir (merge-pathnames leaf root))
                    (marker (merge-pathnames "marker" dir)))
               (ensure-directories-exist marker)
               (with-open-file (out marker :direction :output :if-exists :error)
                 (declare (ignorable out)))
               (let* ((token "a ' = ; $HOME")
                      (child (han.host:run-program
                              worker :directory dir :arguments (list token) :input input
                              :environment '(("HAN_CWD_VALUE" . "extra")))))
                 (unwind-protect
                      (let ((out (han.host:host-process-output-stream child))
                            (err (han.host:host-process-error-stream child)))
                        (han.host:process-wait child)
                        (check-equal 143 (han.host:process-exit-code child))
                        (check-equal (han.host:host-process-pid child) (parse-integer (read-line out)))
                        (check-equal token (read-line out))
                        (check-equal "stdin" (read-line out))
                        (check-equal "extra" (read-line out))
                        (check-equal "diagnostic" (read-line err)))
                   (han.host:process-close child)))))
           (check-equal (namestring parent) (namestring (han.host:working-directory-pathname)))
           (check-error (simple-error)
             (han.host:run-program input :arguments '("arg") :directory root))
           (with-open-file (out worker :direction :output :if-exists :overwrite)
             (write-line "#!/missing-han-test-interpreter" out))
           (let ((child (han.host:run-program worker :arguments '("arg") :directory root)))
             (unwind-protect
                  (progn (han.host:process-wait child)
                         (check-false (zerop (han.host:process-exit-code child))))
               (han.host:process-close child)))
           (check-error (error) (han.host:run-program worker :directory input))
           (check-error (error) (han.host:run-program worker :directory (merge-pathnames "absent/" root)))
           (check-error (error) (han.host:run-program (merge-pathnames "absent" root) :directory root)))
      (han.host:delete-directory-tree root))))

#+(and (or lispworks ccl (and ecl unicode)) (or darwin macosx linux))
(deftest test-host-async-relative-program ()
  (let* ((parent (%han-host-test-directory))
         (child (merge-pathnames "child/" parent))
         (parent-probe (merge-pathnames "han-probe" parent))
         (child-probe (merge-pathnames "han-probe" child)))
    (unwind-protect
         (progn
           (ensure-directories-exist child-probe)
           (han.host:run-program-sync (list "/bin/ln" "-s" "/usr/bin/false" (namestring parent-probe))
                                      :ignore-error-status nil)
           (han.host:run-program-sync (list "/bin/ln" "-s" "/bin/sh" (namestring child-probe))
                                      :ignore-error-status nil)
           (han.host:run-program-sync
            (list "/bin/ln" "-s" "/bin/sh" (namestring (merge-pathnames "child-only" child)))
            :ignore-error-status nil)
           (dolist (scenario (list (list parent child "./han-probe")
                                   (list child nil "./han-probe")
                                   (list parent child "./child-only")
                                   (list parent child "child-only")))
             (destructuring-bind (current-directory child-directory program) scenario
               (uiop:with-current-directory (current-directory)
                 (let ((process (apply #'han.host:run-program program
                                       :arguments '("-c" "printf '%s' \"$0\"")
                                       (when child-directory (list :directory child-directory)))))
                   (unwind-protect
                        (progn
                          (han.host:process-wait process)
                          (check-equal 0 (han.host:process-exit-code process))
                          (check-equal program
                                       (read-line (han.host:host-process-output-stream process) nil)))
                     (han.host:process-close process)))))))
      (han.host:delete-directory-tree parent))))

#+(and lispworks (or darwin macosx linux))
(deftest test-host-lispworks-async-directory-preserves-environment ()
  (let ((directory (%han-host-test-directory))
        (overrides '(("PWD" . "caller-pwd") ("OLDPWD" . "caller-oldpwd")
                     ("SHLVL" . "31") ("HAN_MARKER" . "from caller"))))
    (unwind-protect
         (progn
           (ensure-directories-exist (merge-pathnames "anchor" directory))
           (let ((child (han.host:run-program "/usr/bin/env" :directory directory
                                              :environment overrides)))
             (unwind-protect
                  (let ((lines (loop with out = (han.host:host-process-output-stream child)
                                     for line = (read-line out nil) while line collect line)))
                    (han.host:process-wait child)
                    (check-equal 0 (han.host:process-exit-code child))
                    (dolist (entry overrides)
                      (let ((expected (format nil "~A=~A" (car entry) (cdr entry))))
                        (check-equal expected (find expected lines :test #'string=)))))
               (han.host:process-close child))))
      (han.host:delete-directory-tree directory))))

#+(or ecl ccl)
(deftest #+ecl test-host-ecl-sync-rejects-unowned-pipes-before-launch
         #+ccl test-host-ccl-sync-rejects-unowned-pipes-before-launch ()
  (let* ((marker (%han-host-temp-file "han-host-started" nil))
         (argv (list "/bin/sh" "-c" "printf started > \"$1\"" "sh" (namestring marker))))
    (unwind-protect
         (dolist (channel '(:input :output :error-output))
           (check-error (simple-error) (funcall #'han.host:run-program-sync argv channel :stream))
           (check-false (probe-file marker)))
      (when (probe-file marker) (delete-file marker)))))

#+(or ecl ccl)
(deftest #+ecl test-host-ecl-sync-path-search-with-separate-captures
         #+ccl test-host-ccl-sync-path-search-with-separate-captures ()
  (check-equal '("out" "err" 7)
               (multiple-value-list
                (han.host:run-program-sync '("sh" "-c" "printf out; printf err >&2; exit 7")))))

#+(or ecl ccl)
(deftest #+ecl test-host-ecl-async-input-and-status
         #+ccl test-host-ccl-async-input-and-status ()
  ;; The child cannot exit until we close its stdin.
  (let ((child (han.host:run-program "/bin/cat" :input :stream)))
    (unwind-protect
         (let ((input (han.host:host-process-input-stream child)))
           (check-equal #+ecl :ecl #+ccl :ccl (han.host:host-process-backend child))
           (check-true (plusp (han.host:host-process-pid child)))
           (check-equal :running (han.host:process-status child))
           (check-false (han.host:process-exit-code child))
           (write-line "有空格 😀" input)
           (close input)
           (check-true (eq child (han.host:process-wait child)))
           (check-equal "有空格 😀" (read-line (han.host:host-process-output-stream child)))
           (check-equal :exited (han.host:process-status child))
           (check-equal 0 (han.host:process-exit-code child)))
      (han.host:process-close child))))

#+(or ecl ccl)
(deftest #+ecl test-host-ecl-reports-exec-failure-before-returning
         #+ccl test-host-ccl-reports-exec-failure-before-returning ()
  (let ((file (%han-host-temp-file "han-missing-interpreter" "sh")))
    (unwind-protect
         (progn
           (with-open-file (out file :direction :output :if-exists :error)
             (write-line "#!/nonexistent/han-test-missing-interpreter" out))
           (han.host:run-program-sync (list "/bin/chmod" "700" (namestring file))
                                      :ignore-error-status nil)
           (check-error (error) (han.host:run-program file))
           (check-error (error) (han.host:run-program-sync (list (namestring file)))))
      (when (probe-file file) (delete-file file)))))

#+(or ecl ccl)
(deftest #+ecl test-host-ecl-async-directory-and-environment
         #+ccl test-host-ccl-async-directory-and-environment ()
  (let ((root (%han-host-test-directory)))
    (unwind-protect
         (progn
           (ensure-directories-exist (merge-pathnames "anchor" root))
           (let ((child (han.host:run-program
                         "/bin/sh" :directory root :environment '("HAN_VALUE=中文 😀")
                         :arguments '("-c" "pwd; printf '%s' \"$HAN_VALUE\""))))
             (unwind-protect
                  (let ((out (han.host:host-process-output-stream child)))
                    (han.host:process-wait child)
                    (check-equal 0 (han.host:process-exit-code child))
                    (check-equal (truename root) (truename (read-line out)))
                    (check-equal "中文 😀" (read-line out)))
               (han.host:process-close child)))
           (let ((child (han.host:run-program "/usr/bin/env" :environment nil)))
             (unwind-protect
                  (progn
                    (han.host:process-wait child)
                    (check-equal 0 (han.host:process-exit-code child))
                    (check-equal :eof (read-line (han.host:host-process-output-stream child) nil :eof)))
               (han.host:process-close child))))
      (han.host:delete-directory-tree root))))

#+ccl
(deftest test-host-ccl-native-environment-and-parent-directory ()
  (let* ((root (%han-host-test-directory))
         (directory (merge-pathnames "子目录 = ' 😀/" root))
         (environment '("PWD=given-pwd" "OLDPWD=given-oldpwd" "HAN_TEXT=有 空格😀"))
         (parent (han.host:run-program-sync '("/bin/pwd" "-P"))))
    (unwind-protect
         (progn
           (ensure-directories-exist (merge-pathnames "anchor" directory))
           ;; env observes the exact environment; a shell may rewrite PWD itself.
           (let ((child (han.host:run-program "/usr/bin/env" :directory directory
                                              :environment environment)))
             (unwind-protect
                  (let ((lines (uiop:slurp-stream-lines (han.host:host-process-output-stream child))))
                    (han.host:process-wait child)
                    (check-equal 0 (han.host:process-exit-code child))
                    (check-equal (sort (copy-list environment) #'string<) (sort lines #'string<)))
               (han.host:process-close child)))
           (han.host:run-program-sync
            (list "/bin/ln" "-s" "/bin/sh" (namestring (merge-pathnames "native-shell" directory)))
            :ignore-error-status nil)
           (let* ((argument "有空格 ' ; $HOME")
                  (child (han.host:run-program
                          "./native-shell" :directory directory :environment environment
                          :arguments (list "-c" "pwd -P; printf '%s\\n' \"$$\" \"$0\" \"$1\" \"$HAN_TEXT\"; printf diagnostic >&2; kill -TERM $$"
                                           "./native-shell" argument))))
             (unwind-protect
                  (let ((out (han.host:host-process-output-stream child)))
                    (han.host:process-wait child)
                    (check-equal 143 (han.host:process-exit-code child))
                    (check-equal (truename directory) (truename (read-line out)))
                    (check-equal (han.host:host-process-pid child) (parse-integer (read-line out)))
                    (check-equal "./native-shell" (read-line out))
                    (check-equal argument (read-line out))
                    (check-equal "有 空格😀" (read-line out))
                    (check-equal "diagnostic" (read-line (han.host:host-process-error-stream child))))
               (han.host:process-close child)))
           (check-error (error) (han.host:run-program "./absent" :directory directory))
           (check-error (error)
             (han.host:run-program "/bin/pwd" :directory (merge-pathnames "missing/" directory)))
           (check-equal parent (han.host:run-program-sync '("/bin/pwd" "-P"))))
      (han.host:delete-directory-tree root))))

#+ccl
(deftest test-host-ccl-sync-text-capture-is-utf8 ()
  (let ((ccl:*default-file-character-encoding* :iso-8859-1)
        (text "汉 é 😀"))
    (with-input-from-string (in text)
      (check-equal (list text "خطأ 😀" 7)
                   (multiple-value-list
                    (han.host:run-program-sync
                     '("/bin/sh" "-c" "cat; printf '%s' \"$1\" >&2; exit 7" "sh" "خطأ 😀")
                     :input in))))))

#+ccl
(deftest test-host-ccl-invalid-process-strings-do-not-start-child ()
  (let* ((marker (%han-host-temp-file "han-host-started" nil))
         (command (list "/bin/sh" "-c" "printf started > \"$1\"" "sh" (namestring marker)))
         (nul (format nil "value~Ctail" (code-char 0))))
    (unwind-protect
         (progn
           (check-error (error) (han.host:run-program-sync (append command (list nul))))
           (dolist (bad (list "missing-equals" "=missing-name" (concatenate 'string "HAN=" nul)))
             (check-error (error) (han.host:run-program (first command) :arguments (rest command)
                                                        :environment (list bad))))
           (check-false (probe-file marker)))
      (when (probe-file marker) (delete-file marker)))))

#+ccl
(deftest test-host-ccl-async-input-starts-at-logical-stream-position ()
  (flet ((check-input (input)
           (check-equal #\A (read-char input))
           (let ((child (han.host:run-program "/bin/cat" :input input)))
             (unwind-protect
                  (progn
                    (han.host:process-wait child)
                    (check-equal 0 (han.host:process-exit-code child))
                    (check-equal "BC汉" (uiop:slurp-stream-string
                                         (han.host:host-process-output-stream child))))
               (han.host:process-close child)))
           (check-true (open-stream-p input))
           (check-equal :eof (read-char input nil :eof))))
    (with-input-from-string (input "ABC汉") (check-input input))
    (uiop:with-temporary-file (:stream out :pathname file :external-format :utf-8)
      (write-string "ABC汉" out)
      :close-stream
      (han.host:with-open-utf8-file (input file) (check-input input)))))

#+ccl
(deftest test-host-ccl-argv-and-quit-in-fresh-kernel ()
  (let ((args '("有 空格😀" "" "--literal" "';$HOME")))
    (uiop:with-temporary-file (:stream out :pathname script :type "lisp")
      (write-line "(require :asdf)" out)
      (format out "(asdf:load-asd ~S)~%(asdf:load-system \"han\")~%"
              (asdf:system-source-file "han"))
      (write-line "(assert (equal (han.host:argv) (rest (han.host:argv t))))" out)
      (format out "(assert (equal '~S (rest (member \"--\" (han.host:argv) :test #'string=))))~%"
              args)
      (write-line "(han.host:quit 23)" out)
      :close-stream
      (multiple-value-bind (stdout stderr code)
          (han.host:run-program-sync
           (append (list (first ccl:*command-line-argument-list*) "--no-init" "--batch" "--quiet"
                         "--load" (namestring script) "--")
                   args))
        (unless (eql code 23)
          (error "Child CCL exited with ~S (expected 23).~%~A~%~A" code stdout stderr))))))

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

(deftest test-host-sync-caller-streams-and-nonzero-exit ()
  (with-input-from-string (in "skip:payload" :start 5)
    (let ((out (make-string-output-stream))
          (err (make-string-output-stream)))
      (unwind-protect
           (progn
             (check-equal '(nil nil 9)
                          (multiple-value-list
                           (han.host:run-program-sync
                            '("/bin/sh" "-c" "cat; printf diagnostic >&2; exit 9")
                            :input in :output out :error-output err)))
             (check-true (every #'open-stream-p (list in out err)))
             (check-equal :eof (read-char in nil :eof))
             (check-equal "payload" (get-output-stream-string out))
             (check-equal "diagnostic" (get-output-stream-string err)))
        (close out)
        (close err))))
  (check-error (simple-error)
    (han.host:run-program-sync '("/bin/sh" "-c" "exit 9") :ignore-error-status nil)))

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
  (let ((file (namestring (%han-host-temp-file "han-not-executable" nil))))
    (check-error (error) (han.host:run-program file))
    (check-error (error) (han.host:run-program-sync (list file) :ignore-error-status t))
    (unwind-protect
         (progn
           (with-open-file (out file :direction :output :if-exists :error)
             (write-line "regular file" out))
           (han.host:run-program-sync (list "/bin/chmod" "600" file) :ignore-error-status nil)
           (check-true (han.host:find-executable file))
           (check-error (error)
             (han.host:run-program-sync (list file) :ignore-error-status t)))
      (when (probe-file file) (delete-file file)))))

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

(deftest test-host-current-process-id ()
  (let ((pid (han.host:current-process-id)))
    (check-true (integerp pid))
    (check-true (> pid 0))))

(deftest test-host-exclusive-file-lock ()
  (let* ((root (%han-host-test-directory))
         (file (merge-pathnames "logs/记录.lock" root))
         (entered-again nil))
    (unwind-protect
         (progn
           (check-equal
            '(:first :second)
            (multiple-value-list
             (han.host:call-with-exclusive-file-lock
              file
              (lambda ()
                ;; A separately opened descriptor must contend even in this process.
                (check-true
                 (signal-error-p
                  (lambda ()
                    (han.host:call-with-exclusive-file-lock
                     file (lambda () (setf entered-again t)) :timeout 0))))
                (check-false entered-again)
                (values :first :second)))))
           (check-equal
            :unwound
            (catch 'escape
              (han.host:call-with-exclusive-file-lock
               file (lambda () (throw 'escape :unwound)) :timeout 0)))
           (check-true (han.host:file-exists-p file))
           (check-equal :reacquired
                        (han.host:call-with-exclusive-file-lock
                         file (lambda () :reacquired) :timeout 0)))
      (when (han.host:directory-exists-p root)
        (han.host:delete-directory-tree root)))))

(deftest test-open-utf8-file-bytes-values-and-cleanup ()
  (let ((file (%han-host-temp-file "han-utf8" "txt"))
        (sample (map 'string #'han.host:unicode-scalar-char '(#x6C49 #x1F600)))
        stream)
    (unwind-protect
         (progn
           (check-equal '(42 :written)
             (multiple-value-list
              (han.host:with-open-utf8-file (out file :direction :output
                                                      :if-exists :error)
                (write-string sample out)
                (values 42 :written))))
           (with-open-file (in file :element-type '(unsigned-byte 8))
             (check-equal '(#xE6 #xB1 #x89 #xF0 #x9F #x98 #x80)
               (loop for byte = (read-byte in nil nil) while byte collect byte)))
           (han.host:with-open-utf8-file (in file)
             (check-equal sample (read-line in)))
           (check-error (simple-error)
             (han.host:with-open-utf8-file (in file)
               (setf stream in)
               (error "leave the body")))
           (check-true stream)
           (check-false (open-stream-p stream)))
      (when (probe-file file) (delete-file file)))))

(deftest test-host-append-utf8-line ()
  (let* ((root (%han-host-test-directory))
         (file (merge-pathnames "logs/history.jsonl" root))
         (unicode-line
           (han.host:with-character-output-to-string (out)
             (write-string "unicode-" out)
             (write-char (code-char #x9879) out))))
    (unwind-protect
         (progn
           (han.host:append-utf8-line file "first")
           (han.host:append-utf8-line file unicode-line)
           (with-open-file (in file
                               :direction :input
                               :element-type 'character
                               :external-format :utf-8)
             (check-equal (read-line in nil nil) "first")
             (check-equal (read-line in nil nil) unicode-line)
             (check-equal (read-line in nil :eof) :eof)))
      (ignore-errors
        (when (han.host:directory-exists-p root)
          (han.host:delete-directory-tree root))))))

(deftest test-host-lock-and-append-literal-os-path ()
  (let* ((root (%han-host-test-directory))
         (path (concatenate 'string (namestring root) "dir[*]\\?/bad[.jsonl"))
         (lock (concatenate 'string path ".lock")))
    (unwind-protect
         (progn
           (han.host:call-with-exclusive-file-lock
            lock (lambda () (han.host:append-utf8-line path "literal")))
           ;; Read via the OS, independently of either Lisp's pathname parser.
           (multiple-value-bind (out err code)
               (han.host:run-program-sync (list "/bin/cat" path))
             (check-equal 0 code)
             (check-equal "" err)
             (check-equal (format nil "literal~%") out))
           (check-equal 0 (nth-value 2 (han.host:run-program-sync
                                        (list "/bin/test" "-f" lock)))))
      (when (han.host:directory-exists-p root)
        (han.host:delete-directory-tree root)))))

(deftest test-host-run-program-sync-unicode-path-argument ()
  (let* ((root (%han-host-test-directory))
         (leaf (with-output-to-string (out nil :element-type 'character)
                 (write-string "probe-" out)
                 (write-char (code-char #x9879) out)))
         (file (merge-pathnames leaf root)))
    (unwind-protect
         (progn
           (ensure-directories-exist file)
           (with-open-file (out file
                                :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create
                                :element-type '(unsigned-byte 8))
             (write-byte 120 out))
           (multiple-value-bind (stdout stderr code)
               (han.host:run-program-sync
                (list "/bin/chmod" "+x" (namestring file))
                :output :string
                :error-output :string
                :ignore-error-status t)
             (check-equal stdout "")
             (check-equal stderr "")
             (check-equal code 0)))
      (ignore-errors
        (when (han.host:directory-exists-p root)
          (han.host:delete-directory-tree root))))))

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
           (check-false
            (find "b"
                  (mapcar #'file-namestring
                          (han.host:directory-files root))
                  :test #'equal))
           (check-equal
            (mapcar #'file-namestring
                    (han.host:directory-files subdir))
            '("b"))
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

(deftest test-host-atomic-replace-file-publishes-exact-name-and-mode ()
  (let* ((root (%han-host-test-directory))
         (source (namestring (merge-pathnames "staging/payload.tmp" root)))
         (target (concatenate 'string (namestring root) "运行 [v1]*?")))
    (ensure-directories-exist source)
    (unwind-protect
         (dolist (payload '("first complete version" "new"))
           (with-open-file (out source :direction :output :if-exists :error)
             (write-string payload out))
           (han.host:run-program-sync (list "/bin/chmod" "751" source) :ignore-error-status nil)
           (check-equal '(t) (multiple-value-list (han.host:atomic-replace-file source target)))
           (check-false (probe-file source))
           (check-equal payload
                        (han.host:run-program-sync (list "/bin/cat" target) :ignore-error-status nil))
           (check-equal (format nil "0751~%")
                        (han.host:run-program-sync
                         (list "/usr/bin/find" target "-prune" "-perm" "0751"
                               "-exec" "/bin/echo" "0751" ";")
                         :ignore-error-status nil)))
      (han.host:delete-directory-tree root))))

(deftest test-host-atomic-replace-open-reader-sees-old-file ()
  (let* ((root (%han-host-test-directory))
         (source (namestring (merge-pathnames "staged.tmp" root)))
         (target (namestring (merge-pathnames "journal.json" root))))
    (ensure-directories-exist source)
    (unwind-protect
         (progn
           (with-open-file (out target :direction :output :if-exists :error) (write-string "old" out))
           (with-open-file (out source :direction :output :if-exists :error) (write-string "new" out))
           (with-open-file (old-reader target)
             (han.host:atomic-replace-file source target)
             (check-equal "old" (read-line old-reader)))
           (with-open-file (new-reader target)
             (check-equal "new" (read-line new-reader))))
      (han.host:delete-directory-tree root))))

(deftest test-host-atomic-replace-refuses-nonfiles-and-aliases ()
  (let* ((root (%han-host-test-directory))
         (source (namestring (merge-pathnames "staged.tmp" root)))
         (old (namestring (merge-pathnames "old" root)))
         (dir (namestring (merge-pathnames "directory" root)))
         (hard (namestring (merge-pathnames "alias" root)))
         (link (namestring (merge-pathnames "link" root)))
         (missing (namestring (merge-pathnames "absent" root)))
         (dangling (namestring (merge-pathnames "dangling" root)))
         (fifo (namestring (merge-pathnames "fifo" root))))
    (ensure-directories-exist source)
    (unwind-protect
         (progn
           (with-open-file (out source :direction :output :if-exists :error) (write-string "new" out))
           (with-open-file (out old :direction :output :if-exists :error) (write-string "old" out))
           (dolist (command (list (list "/bin/mkdir" dir) (list "/bin/ln" source hard)
                                  (list "/bin/ln" "-s" old link) (list "/bin/ln" "-s" missing dangling)
                                  (list "/usr/bin/mkfifo" fifo)))
             (han.host:run-program-sync command :ignore-error-status nil))
           (dolist (destination (list dir hard link dangling fifo source))
             (check-error (file-error) (han.host:atomic-replace-file source destination)))
           (dolist (invalid-source (list dir link dangling fifo missing))
             (check-error (file-error) (han.host:atomic-replace-file invalid-source old)))
           (check-error (file-error) (han.host:atomic-replace-file dir missing))
           (check-false (probe-file missing))
           (dolist (entry (list hard source))
             (with-open-file (in entry) (check-equal "new" (read-line in))))
           (check-equal (format nil "~A~%" old)
                        (han.host:run-program-sync (list "/usr/bin/readlink" link) :ignore-error-status nil))
           (with-open-file (in old) (check-equal "old" (read-line in))))
      (han.host:delete-directory-tree root))))

(deftest test-host-atomic-replace-rejects-invalid-path-text ()
  (let* ((root (%han-host-test-directory))
         (file (namestring (merge-pathnames "keep" root)))
         (nul-name (concatenate 'string file (string (code-char 0)) ".extra")))
    (ensure-directories-exist file)
    (unwind-protect
         (progn
           (with-open-file (out file :direction :output :if-exists :error) (write-string "keep" out))
           (dolist (bad (list nul-name ""))
             (check-error (file-error) (han.host:atomic-replace-file bad file))
             (check-error (file-error) (han.host:atomic-replace-file file bad)))
           (check-error (type-error) (han.host:atomic-replace-file #p"source" file))
           (check-error (type-error) (han.host:atomic-replace-file file nil))
           (with-open-file (in file) (check-equal "keep" (read-line in))))
      (han.host:delete-directory-tree root))))
