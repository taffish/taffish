(in-package :han.test)

(deftest test-han-json-help-and-version ()
  (let ((help-string (han.json:help nil)))
    (check-true (stringp help-string))
    (check-true (search "han.json" help-string))
    (check-true (search "get-json" help-string)))
  (check-equal "0.1.0" (han.json:version nil)))

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
    (check-equal (format nil "a~%~C\\\"/A" #\Tab)
                 (han.json:get-json json "s"))))

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
                 (uiop:temporary-directory))))
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
      (ignore-errors (uiop:delete-directory-tree root :validate t)))))

(deftest test-han-json-errors ()
  (check-error (han.json:json-error)
    (han.json:parse-json "{\"a\":1,}"))
  (check-error (han.json:json-error)
    (han.json:parse-json "01"))
  (check-error (han.json:json-error)
    (han.json:parse-json "\"unterminated")))
