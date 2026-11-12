;;;; Developer build adapter, invoked by build-from-source.sh from the repository root.
(require :asdf)

(defparameter *build-stage*
  (uiop:ensure-directory-pathname
   (uiop:parse-native-namestring (uiop:getenv "TAFFISH_BUILD_STAGE"))))

(asdf:initialize-output-translations
 (list :output-translations
       (list t (list (merge-pathnames "cache/" *build-stage*) :implementation))
       :ignore-inherited-configuration))
(asdf:initialize-source-registry '(:source-registry :ignore-inherited-configuration))
(asdf:load-asd (truename "vendor/han/han.asd"))
(asdf:load-asd (truename "taffish.asd"))

(defparameter *programs*
  '(("taf" "TAF.CLI" "%STANDALONE-MAIN")
    ("taffish" "TAFFISH.CLI" "MAIN")
    ("taffish-mcp" "TAFFISH.MCP" "MAIN")))

(defun program-path (name)
  (merge-pathnames name (merge-pathnames "bin/" *build-stage*)))

#+ecl
(progn
  (require :cmp)
  (asdf:operate 'asdf:monolithic-lib-op :taffish))

#+ecl
(let ((libraries (asdf:output-files 'asdf:monolithic-lib-op :taffish))
      (selection (uiop:getenv "TAFFISH_BUILD_PROGRAM")))
  (dolist (program *programs*)
    (destructuring-bind (name package function) program
      (when (or (null selection) (string= selection "all") (string= selection name))
        (c:build-program (namestring (program-path name)) :lisp-files libraries
                         :epilogue-code `(funcall (find-symbol ,function ,package)))))))

#+ccl
(progn
  (asdf:load-system :taffish)
  (defclass taffish-application (ccl::application) ())
  ;; --help, --version and all other arguments belong to the chosen TAFFISH program.
  (defmethod ccl::parse-application-arguments ((app taffish-application))
    (declare (ignore app))
    (values nil nil nil nil))
  (destructuring-bind (name package function)
      (assoc (uiop:getenv "TAFFISH_BUILD_PROGRAM") *programs* :test #'equal)
    (ccl:save-application (program-path name)
                          :toplevel-function (symbol-function (find-symbol function package))
                          :application-class 'taffish-application
                          :init-file nil :mode #o755 :prepend-kernel t)))
