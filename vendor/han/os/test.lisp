(in-package :han.test)

(deftest test-han-os-help-and-version ()
  (let ((help-string (han.os:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.os" help-string))
    (check-true (search "run-shell-command" help-string)))
  (check-equal "0.1.0" (han.os:version nil)))

;; io.lisp
;; keep-read & keep-read-line & keep-read-char
(let ((string (format nil "123 456~%(print 789)~%[DATE] Done~%")))
  (deftest test-keep-read ()
    (with-input-from-string (in string)
      (check-equal (han.os:keep-read in 3) '(123 456 (PRINT 789)))
      (check-equal (mapcar #'symbol-name (han.os:keep-read in))
                   '("[DATE]" "DONE"))))
  (deftest test-keep-read-line ()
    (with-input-from-string (in string)
      (check-equal (han.os:keep-read-line in 2) '("123 456" "(print 789)"))
      (check-equal (han.os:keep-read-line in)   '("[DATE] Done"))))
  (deftest test-keep-read-char ()
    (with-input-from-string (in string)
      (check-equal (han.os:keep-read-char in 10)
                   '(#\1 #\2 #\3 #\  #\4 #\5 #\6 #\Newline #\( #\p))
      (check-equal (han.os:keep-read-char in)
                   '(#\r #\i #\n #\t #\Space #\7 #\8 #\9 #\)
                     #\Newline #\[ #\D #\A #\T #\E #\] #\Space
                     #\D #\o #\n #\e #\Newline)))))

;; env.lisp
(deftest test-getenv-default ()
  (check-equal (han.os:getenv-default "" "NO-THIS-ENV") "NO-THIS-ENV")
  (check-true  (han.os:getenv-default "USER" nil)))

(deftest test-find-executable ()
  (check-true (han.os:find-executable "/bin/sh"))
  (check-true (han.os:find-executable "sh")))

;; run-shell.lisp
(deftest test-run-shell-command ()
  (check-equal (multiple-value-list
                (han.os:run-shell-command "echo 1; echo 2 >&2; exit 3"))
               '(("1") ("2") 3))
  (check-equal (multiple-value-list
                (han.os:run-shell-command "echo 1; echo 2 >&2; exit 3"
                                          :lines nil))
               (list (format nil "1~%") (format nil "2~%") 3))
  (multiple-value-bind (out-stream err-stream exit-code process)
      (han.os:run-shell-command "echo 1; echo 2 >&2; exit 3" :wait nil)
    (check-true (streamp out-stream))
    (check-true (streamp err-stream))
    (check-false exit-code)
    (check-true (typep process 'han.host:host-process)))
  (multiple-value-bind (out err code)
      (han.os:run-shell-command
       "i=0; while [ $i -lt 10000 ]; do echo line; i=$((i + 1)); done")
    (check-equal (length out) 10000)
    (check-equal err nil)
    (check-equal code 0))
  (check-error (simple-error)
    (han.os:run-shell-command "echo 1; echo 2 >&2; exit 3"
                              :shell "/bin/error-shell")))
