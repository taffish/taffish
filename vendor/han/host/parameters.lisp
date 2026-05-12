(in-package :han.host)

(defparameter *supported-implementations*
  '("SBCL" "LispWorks"))

(defun supported-implementations-string ()
  (format nil "~{~A~^, ~}" *supported-implementations*))
