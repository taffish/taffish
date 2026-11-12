(in-package :han.test)

(deftest test-han-json-help-and-version ()
  (let ((help-string (han.json:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.json" help-string))
    (check-true (search "get-json" help-string)))
  (check-equal "0.3.0" (han.json:version nil)))

(deftest test-han-json-parse-object-basic ()
  (let ((json (han.json:parse-json
               "{\"name\":\"taffish\",\"ok\":true,\"missing\":false,\"none\":null,\"n\":12,\"items\":[1,\"x\"]}")))
    (check-true (han.json:json-object-p json))
    (check-equal "taffish" (han.json:get-json json "name"))
    (check-equal t (han.json:get-json json "ok"))
    (multiple-value-bind (value present-p)
        (han.json:get-json json "missing")
      (check-equal nil value)
      (check-equal t present-p))
    (check-equal :null (han.json:get-json json "none"))
    (check-equal 12 (han.json:get-json json "n"))
    (let ((items (han.json:get-json json "items")))
      (check-true (han.json:json-array-p items))
      (check-equal 2 (length items))
      (check-equal 1 (aref items 0))
      (check-equal "x" (aref items 1)))))

(deftest test-han-json-parse-number-without-lisp-reader ()
  (let ((json (han.json:parse-json
               "{\"int\":-12,\"zero\":0,\"frac\":-0.5,\"exp\":1.25e2,\"small\":2E-2}")))
    (check-equal -12 (han.json:get-json json "int"))
    (check-equal 0 (han.json:get-json json "zero"))
    (check-equal -0.5d0 (han.json:get-json json "frac"))
    (check-equal 125.0d0 (han.json:get-json json "exp"))
    (check-equal 0.02d0 (han.json:get-json json "small"))))

(deftest test-han-json-get-json-missing-default ()
  (let ((json (han.json:json-object (cons "exists" nil))))
    (multiple-value-bind (value present-p)
        (han.json:get-json json "exists" :default)
      (check-equal nil value)
      (check-equal t present-p))
    (multiple-value-bind (value present-p)
        (han.json:get-json json "missing" :default)
      (check-equal :default value)
      (check-equal nil present-p))))

(deftest test-han-json-parse-escapes ()
  (let ((json (han.json:parse-json "{\"s\":\"a\\n\\t\\\\\\\"\\/\\u0041\"}")))
    (check-equal (format nil "a~%~C\\\"/A" (han.host:unicode-scalar-char 9))
                 (han.json:get-json json "s"))))

(deftest test-han-json-unicode-escapes ()
  (loop for (code escape) in '((0 "\\u0000") (8 "\\b") (9 "\\t") (10 "\\n")
                               (12 "\\f") (13 "\\r") (31 "\\u001F") (127 "\\u007F")
                               (#x6C49 "\\u6C49") (#x1F600 "\\uD83D\\uDE00"))
        for char = (han.host:unicode-scalar-char code)
        for wire = (format nil "\"~A\"" escape)
        do (if char
               (progn
                 (check-equal wire (han.json:encode-json (string char) :indent nil))
                 (check-equal (string char) (han.json:parse-json wire))
                 (check-equal (string char) (han.json:parse-json (string-downcase wire))))
               (check-error (han.json:json-error) (han.json:parse-json wire))))
  (dolist (bad '("\"\\uD800\"" "\"\\uDC00\"" "\"\\uD800\\u0041\"" "\"\\u00GX\""))
    (check-error (han.json:json-error) (han.json:parse-json bad)))
  (check-error (han.json:json-error)
    (han.json:parse-json (format nil "\"a~Cb\"" #\Newline))))

(deftest test-han-json-numbers-in-printer-environment ()
  (let ((*print-base* 16)
        (*print-radix* t)
        (*print-readably* t)
        (*read-default-float-format* 'double-float))
    (check-equal "-26" (han.json:encode-json -26 :indent nil))
    (dolist (value (list 1.25s0 1.25f0 1.25d0 1.25l0 1.25d-12))
      (let ((wire (han.json:encode-json value :indent nil)))
        (check-true (every (lambda (c) (find c "-+.0123456789eE")) wire))
        (check-true (= value (han.json:parse-json wire))))))
  (let ((digit (han.host:unicode-scalar-char #x0661)))
    (when digit
      (dolist (bad (list (format nil "2~C" digit) (format nil "\"\\u00~CF\"" digit)))
        (check-error (han.json:json-error) (han.json:parse-json bad))))))

(deftest test-han-json-unicode-string-and-file-roundtrip ()
  (let* ((text (make-array 2
                           :element-type 'character
                           :initial-contents
                           (mapcar #'han.host:unicode-scalar-char '(#x4F60 #x597D))))
         (escaped (han.json:parse-json "{\"text\":\"\\u4F60\\u597D\"}"))
         (root (han.path:directory-pathname
                (merge-pathnames
                 (format nil "han-json-unicode-test-~A/" (gensym))
                 (han.host:temporary-directory))))
         (file (han.path:join-path root "data.json")))
    (unwind-protect
         (progn
           (check-equal text (han.json:get-json escaped "text"))
           (han.json:write-json-file
            file (han.json:json-object (cons "text" text)) :indent nil)
           (check-equal
            text
            (han.json:get-json (han.json:read-json-file file) "text")))
      (ignore-errors
        (han.host:delete-directory-tree root :validate t)))))

(deftest test-han-json-encode-compact-sorted ()
  (let ((json (han.json:json-object
               (cons "b" 2)
               (cons "a" t)
               (cons "false" nil)
               (cons "null" :null)
               (cons "items" (han.json:json-array "x" 1)))))
    (check-equal
     "{\"a\":true,\"b\":2,\"false\":false,\"items\":[\"x\",1],\"null\":null}"
     (han.json:encode-json json :indent nil))))

(deftest test-han-json-encode-pretty ()
  (let ((json (han.json:json-object
               (cons "a" (han.json:json-array 1 2)))))
    (check-equal
     (format nil "{~%  \"a\": [~%    1,~%    2~%  ]~%}~%")
     (han.json:encode-json json :indent 2))))

(deftest test-han-json-file-roundtrip ()
  (let* ((root (han.path:directory-pathname
                (merge-pathnames
                 (format nil "han-json-test-~A/" (gensym))
                 (han.host:temporary-directory))))
         (file (han.path:join-path root "data.json")))
    (unwind-protect
         (progn
           (han.json:write-json-file
            file
            (han.json:json-object
             (cons "name" "taf")
             (cons "count" 3))
            :indent nil)
           (let ((json (han.json:read-json-file file)))
             (check-equal "taf" (han.json:get-json json "name"))
             (check-equal 3 (han.json:get-json json "count"))))
      (ignore-errors
        (han.host:delete-directory-tree root :validate t)))))

(deftest test-han-json-errors ()
  (check-error (han.json:json-error)
    (han.json:parse-json "{\"a\":1,}"))
  (check-error (han.json:json-error)
    (han.json:parse-json "01"))
  (check-error (han.json:json-error)
    (han.json:parse-json "\"unterminated")))

(deftest test-han-json-number-syntax ()
  (check-equal '(0 -125.0d0 250.0d0)
               (coerce (han.json:parse-json "[-0,-1.25E+2,2500e-1]") 'list))
  (dolist (input '("+" "+2" ".5" "1." "-01" "1e" "1e+" "1d3" "1/2"))
    (check-error (han.json:json-error) (han.json:parse-json input))))

(deftest test-han-json-duplicate-decoded-keys ()
  (let ((object (han.json:parse-json "{\"A\":0,\"a\":1,\"\\u0061\":false}")))
    (check-equal 2 (hash-table-count object))
    (check-equal 0 (han.json:get-json object "A"))
    (check-equal '(nil t) (multiple-value-list (han.json:get-json object "a")))))

(deftest test-han-json-write-to-caller-stream ()
  (let ((value (han.json:json-array 1 :null)))
    (check-equal
     "[1,null] false"
     (with-output-to-string (out)
       (check-true (eq value (han.json:write-json value out :indent nil)))
       (write-char #\Space out)
       (han.json:write-json nil out :indent nil))))
  (with-output-to-string (out)
    (check-error (han.json:json-error)
      (han.json:write-json (han.json:json-array 1 1/3) out :indent nil))
    (check-true (open-stream-p out))))

(deftest test-han-json-file-utf8-input-and-errors ()
  (let ((file (%han-host-temp-file "han-json-raw" "json")))
    ;; Raw UTF-8 for a quoted U+6C49 U+1F600, independent of the writer.
    (with-open-file (out file :direction :output :if-exists :error
                         :element-type '(unsigned-byte 8))
      (write-sequence #(#x22 #xE6 #xB1 #x89 #xF0 #x9F #x98 #x80 #x22) out))
    (unwind-protect
         (progn
           (check-equal '(#x6C49 #x1F600)
                        (map 'list #'han.host:char-unicode-scalar
                             (han.json:parse-json-file file)))
           (with-open-file (out file :direction :output :if-exists :supersede
                                :element-type '(unsigned-byte 8))
             (write-sequence #(#x5B #x31 #x2C #x5D) out))
           (check-error (han.json:json-error) (han.json:read-json-file file)))
      (delete-file file))
    (check-error (file-error) (han.json:read-json-file file))))

(deftest test-han-json-distinct-accented-keys-and-escape-text ()
  (let* ((composed (string (han.host:unicode-scalar-char #xE9)))
         (decomposed (map 'string #'han.host:unicode-scalar-char '(#x65 #x301)))
         ;; The first value is NUL; the second contains a backslash and "u0000".
         (document "{\"\\u00E9\":\"\\u0000\",\"e\\u0301\":\"\\\\u0000\"}")
         (parsed (han.json:parse-json document))
         (written (han.json:encode-json parsed :indent nil)))
    (dolist (object (list parsed (han.json:parse-json written)))
      (check-equal 2 (hash-table-count object))
      (check-equal '(0) (map 'list #'han.host:char-unicode-scalar
                             (han.json:get-json object composed)))
      (check-equal "\\u0000" (han.json:get-json object decomposed)))))

(deftest test-han-json-line-separators-and-controls ()
  (dolist (code '(0 9 10 13 27))
    (let ((char (han.host:unicode-scalar-char code)))
      (check-error (han.json:json-error) (han.json:parse-json (format nil "\"x~Cy\"" char)))))
  ;; NEL, LINE SEPARATOR and PARAGRAPH SEPARATOR are legal string data.
  ;; None is JSON whitespace between tokens.
  (dolist (code '(#x85 #x2028 #x2029))
    (let ((char (han.host:unicode-scalar-char code)))
      (check-equal (list #x78 code #x79)
                   (map 'list #'han.host:char-unicode-scalar
                        (han.json:parse-json (format nil "\"x~Cy\"" char))))
      (check-error (han.json:json-error) (han.json:parse-json (format nil "[1,~C2]" char))))))

(deftest test-han-json-utf8-file-bidi-and-emoji-sequence ()
  ;; Compare logical order, including right-to-left isolation, a Hebrew
  ;; vowel point, Arabic beh, and the skin tone and joiner in the emoji.
  (let ((file (%han-host-temp-file "han-json-scripts" "json"))
        (codes '(#x41 #x2067 #x05D0 #x05B7 #x0628 #x2069 #x1F469 #x1F3FD #x200D #x1F4BB))
        (wire (concatenate 'string "\"A\\u2067\\u05D0\\u05B7\\u0628\\u2069"
                           "\\uD83D\\uDC69\\uD83C\\uDFFD\\u200D\\uD83D\\uDCBB\"")))
    (with-open-file (out file :direction :output :if-exists :error :element-type '(unsigned-byte 8))
      (write-sequence #(#x22 #x41 #xE2 #x81 #xA7 #xD7 #x90 #xD6 #xB7 #xD8 #xA8 #xE2 #x81 #xA9
                        #xF0 #x9F #x91 #xA9 #xF0 #x9F #x8F #xBD #xE2 #x80 #x8D #xF0 #x9F #x92 #xBB #x22)
                      out))
    (unwind-protect
         (let ((text (han.json:read-json-file file)))
           (check-equal codes (map 'list #'han.host:char-unicode-scalar text))
           (check-equal text (han.json:parse-json wire))
           (han.json:write-json-file file text :indent nil)
           (with-open-file (in file :element-type '(unsigned-byte 8))
             (check-equal (map 'list #'han.host:char-unicode-scalar wire)
                          (loop for octet = (read-byte in nil nil) while octet collect octet))))
      (delete-file file))))
