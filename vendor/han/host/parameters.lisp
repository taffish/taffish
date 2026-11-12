(in-package :han.host)

(defparameter *supported-implementations*
  '("SBCL" "LispWorks" "ECL" "CCL"))

(defun supported-implementations-string ()
  (format nil "~{~A~^, ~}" *supported-implementations*))
