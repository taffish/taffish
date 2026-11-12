(in-package :han.test)

(deftest test-cli-config-path-through-child-output ()
  (uiop:with-temporary-file (:pathname file :prefix "han config '")
    (han.json:write-json-file file
      (han.json:json-object (cons "label" "汉😀") (cons "enabled" nil)))
    (let* ((spec (han.args:parse-args-spec
                  (list (han.args:parse-arg-spec "(--/-c)config")) "report"))
           (input (han.args:parse-args-input
                   (list "report" "--config" (namestring file))))
           (result (han.args:bind-args spec input)))
      (multiple-value-bind (path status) (han.args:get-arg "config" result)
        (check-equal :input status)
        (multiple-value-bind (out err exit-code)
            (han.os:run-program (list "/bin/cat" path))
          (check-equal 0 exit-code)
          (check-equal "" err)
          (let ((settings (han.json:parse-json out)))
            (check-equal "汉😀" (han.json:get-json settings "label"))
            (check-equal '(nil t) (multiple-value-list (han.json:get-json settings "enabled")))
            (check-equal '(nil nil) (multiple-value-list (han.json:get-json settings "missing")))))))))
