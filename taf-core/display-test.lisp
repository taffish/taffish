(in-package :han.test)

(defun %display-test-text (&rest parts)
  (han.host:with-character-output-to-string (out)
    (dolist (part parts)
      (etypecase part
        (integer (write-char (code-char part) out))
        (string (write-string part out))))))

(defun %display-test-fields (rows &key (min-label-width 0))
  (han.host:with-character-output-to-string (out)
    (taf.core::%print-display-fields rows :stream out :min-label-width min-label-width)))

(deftest test-display-width-ascii-and-empty ()
  (check-equal 0 (taf.core::%display-width ""))
  (check-equal 7 (taf.core::%display-width "TAF 1.0"))
  (check-equal 5 (taf.core::%display-width "#*019")))

(deftest test-display-width-cjk-and-mixed ()
  (check-equal 4 (taf.core::%display-width (%display-test-text #x4E2D #x6587)))
  (check-equal 7 (taf.core::%display-width (%display-test-text "taf" #x4E2D #x6587)))
  (check-equal 4 (taf.core::%display-width (%display-test-text #xFF21 #xFF01)))
  (check-equal 2 (taf.core::%display-width (%display-test-text #xAC00))))

(deftest test-display-width-combining ()
  (check-equal 1 (taf.core::%display-width (%display-test-text "e" #x301)))
  (check-equal 1 (taf.core::%display-width (%display-test-text "A" #x308 #x323)))
  (check-equal 2 (taf.core::%display-width (%display-test-text #x304B #x3099)))
  (check-equal 2 (taf.core::%display-width (%display-test-text "e" #x1DC0 "x")))
  (check-equal nil (taf.core::%display-width (%display-test-text #x301)))
  (check-equal nil (taf.core::%display-width (%display-test-text " " #x301)))
  (check-equal nil (taf.core::%display-width (%display-test-text "e " #x301))))

(deftest test-display-width-unknown-and-ambiguous ()
  (dolist (code '(#xE9 #xA1 #x378 #xE000 #x10FFFF #x1100 #x1161 #x627))
    (check-equal nil (taf.core::%display-width (%display-test-text code))))
  (check-equal 1 (taf.core::%display-width (%display-test-text #x100))))

(deftest test-display-width-control-and-formatting-fallback ()
  (dolist (code '(0 9 10 13 27 #x7F #x85 #xAD #x34F #x200B #x200D #x200E
                 #x2028 #x202E #x2066 #xFE0E #xFE0F #xE0100))
    (check-equal nil (taf.core::%display-width (%display-test-text "a" code "b")))))

(deftest test-display-width-emoji-fallback ()
  (check-equal nil (taf.core::%display-width (%display-test-text #x1F600)))
  (check-equal nil (taf.core::%display-width (%display-test-text #x2764)))
  (check-equal nil (taf.core::%display-width (%display-test-text #x1F469 #x200D #x1F4BB)))
  (check-equal nil (taf.core::%display-width (%display-test-text #x1F44D #x1F3FD)))
  (check-equal nil (taf.core::%display-width (%display-test-text #x1F1E8 #x1F1F3)))
  (check-equal nil (taf.core::%display-width (%display-test-text "1" #x20E3)))
  (check-equal nil (taf.core::%display-width (%display-test-text #x1F3F4 #xE0067 #xE007F))))

(deftest test-display-width-pinned-unicode-boundaries ()
  (dolist (code '(#x3400 #x4DBF #x4E00 #x2EBF0 #x2EE5D #x323AF))
    (check-equal 2 (taf.core::%display-width (%display-test-text code))))
  (dolist (code '(#x4DC0 #x2EE5E #x323B0))
    (check-equal nil (taf.core::%display-width (%display-test-text code)))))

(deftest test-display-fields-english-dynamic-padding ()
  (check-equal (format nil "  Name    : alpha~%  Version : 1.0~%")
               (%display-test-fields '(("Name" "alpha") ("Version" "1.0")))))

(deftest test-display-fields-mixed-language-padding ()
  (let ((name (%display-test-text #x540D #x79F0)))
    (check-equal (%display-test-text "  " name "    : alpha" 10
                                     "  Version : 1.0" 10)
                 (%display-test-fields (list (list name "alpha")
                                             '("Version" "1.0"))))))

(deftest test-display-fields-combining-label-padding ()
  (let ((label (%display-test-text "e" #x301)))
    (check-equal (%display-test-text "  " label "  : one" 10 "  AB : two" 10)
                 (%display-test-fields (list (list label "one") '("AB" "two"))))))

(deftest test-display-fields-long-label-fallback ()
  (check-equal (format nil "  X : one~%  This label is far too long for inline fields:~%    two~%")
               (%display-test-fields
                '(("X" "one") ("This label is far too long for inline fields" "two")))))

(deftest test-display-fields-label-limit ()
  (check-equal (format nil "  123456789012345678901234 : x~%")
               (%display-test-fields '(("123456789012345678901234" "x"))))
  (check-equal (format nil "  1234567890123456789012345:~%    x~%")
               (%display-test-fields '(("1234567890123456789012345" "x")))))

(deftest test-display-fields-long-path-preserved ()
  (let ((path "/a/very/long/path/that/must/not/be/truncated/or/rewritten/and/keeps/going/to/the/original/file.txt"))
    (check-equal (format nil "  Path:~%    ~A~%" path)
                 (%display-test-fields (list (list "Path" path))))))

(deftest test-display-fields-layout-budget ()
  ;; Label width 1 + five layout columns + 74 value columns = 80.
  (let ((value "12345678901234567890123456789012345678901234567890123456789012345678901234"))
    (check-equal (format nil "  X : ~A~%" value)
                 (%display-test-fields (list (list "X" value))))
    (check-equal (format nil "  X:~%    ~A5~%" value)
                 (%display-test-fields (list (list "X" (concatenate 'string value "5")))))))

(deftest test-display-fields-multiline-preserves-empty-lines ()
  (check-equal (format nil "  Path:~%    first~%    ~%    last~%    ~%")
               (%display-test-fields (list (list "Path" (format nil "first~%~%last~%")))))
  (check-equal (format nil "  Long~%  label:~%    value~%")
               (%display-test-fields (list (list (format nil "Long~%label") "value")))))

(deftest test-display-fields-unknown-label-and-value-fallback ()
  (let ((emoji (%display-test-text #x1F600)))
    (check-equal (%display-test-text "  " emoji ":" 10 "    value" 10)
                 (%display-test-fields (list (list emoji "value"))))
    (check-equal (%display-test-text "  State:" 10 "    " emoji 10 "  X     : ok" 10)
                 (%display-test-fields (list (list "State" emoji) '("X" "ok"))))))

(deftest test-display-fields-empty-and-default-stream ()
  (check-equal "" (%display-test-fields nil))
  (check-equal (format nil "   : ~%") (%display-test-fields '(("" ""))))
  (check-equal (format nil "  X : y~%")
               (han.host:with-character-output-to-string (*standard-output*)
                 (check-equal nil (taf.core::%print-display-fields '(("X" "y")))))))

(deftest test-display-fields-separate-calls-share-minimum ()
  (let ((name (%display-test-text #x540D #x79F0)))
    (check-equal (%display-test-text "  Name            : alpha" 10
                                     "  " name "            : beta" 10
                                     "  Version         : 1.0" 10)
                 (han.host:with-character-output-to-string (out)
                   (taf.core::%print-display-fields '(("Name" "alpha"))
                                                    :stream out :min-label-width 15)
                   (taf.core::%print-display-fields (list (list name "beta"))
                                                    :stream out :min-label-width 15)
                   (taf.core::%print-display-fields '(("Version" "1.0"))
                                                    :stream out :min-label-width 15)))))

(deftest test-display-fields-minimum-width-boundaries ()
  (check-equal (format nil "  Version : 1.0~%")
               (%display-test-fields '(("Version" "1.0")) :min-label-width 2))
  (check-equal (format nil "  X:~%    y~%")
               (%display-test-fields '(("X" "y")) :min-label-width 25))
  (check-error (type-error)
    (%display-test-fields '(("X" "y")) :min-label-width -1)))

(deftest test-display-interfaces-stay-internal ()
  (check-equal :internal (nth-value 1 (find-symbol "%DISPLAY-WIDTH" :taf.core)))
  (check-equal :internal (nth-value 1 (find-symbol "%PRINT-DISPLAY-FIELDS" :taf.core))))
