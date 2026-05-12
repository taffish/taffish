(defpackage :han.test
  (:use :cl)
  (:export
   :help
   :version

   :*tests*
   :reset-tests
   :deftest
   :run-test
   :run-all-tests
   :check-true
   :check-false
   :check-equal
   :check-error))

(in-package :han.test)

(defun %get-help-string ()
  "han.test v0.1.0

Purpose:
  Tiny test framework used by han and TAFFISH.

Common usage:
  (han.test:deftest test-name ()
    (han.test:check-equal expected form))

  (han.test:run-test 'test-name)
  (han.test:run-all-tests)

Assertions:
  check-true
  check-false
  check-equal
  check-error

State:
  *tests*       registered test cases
  reset-tests   clear registered tests

Note:
  This is intentionally small. It is meant to be portable and available before
  external test dependencies exist.
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.test v~A~%" version))
    version))
