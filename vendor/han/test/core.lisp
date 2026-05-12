(in-package :han.test)

(defparameter *tests* '())

(defstruct test-case
  name
  function)

(defun reset-tests ()
  (setf *tests* '())
  t)

(defmacro deftest (name (&rest args) &body body)
  `(progn
     (setf *tests*
           (remove ',name *tests* :key #'test-case-name :test #'eq))
     (push (make-test-case
            :name ',name
            :function (lambda ,args ,@body))
           *tests*)
     ',name))

(defun %report-pass (name)
  (format t "[PASS] ~A~%" name)
  t)

(defun %report-fail (name reason)
  (format t "[FAIL] ~A~%!!!!!! ~A~%" name reason)
  nil)

(defmacro check-true (form)
  `(let ((value ,form))
     (unless value
       (error "Expected true, but got NIL. FORM=~S" ',form))
     t))

(defmacro check-false (form)
  `(let ((value ,form))
     (when value
       (error "Expected false, but got ~S. FORM=~S" value ',form))
     t))

(defmacro check-equal (expected form)
  `(let ((exp ,expected)
         (value ,form))
     (unless (equal exp value)
       (error "Expected ~S, but got ~S. FORM=~S" exp value ',form))
     t))

(defmacro check-error ((condition-type) &body body)
  `(handler-case
       (progn
         ,@body
         (error "Expected error of type ~S, but no error was signaled."
                ',condition-type))
     (,condition-type (c)
       (declare (ignore c))
       t)))

(defun run-test (name)
  (let ((test (find name *tests* :key #'test-case-name :test #'eq)))
    (unless test
      (error "No test named ~A." name))
    (handler-case
        (progn
          (funcall (test-case-function test))
          (%report-pass name))
      (error (e)
        (%report-fail name e)))))

(defun run-all-tests ()
  (let ((passed 0)
        (failed 0))
    (dolist (test (reverse *tests*))
      (if (run-test (test-case-name test))
          (incf passed)
          (incf failed)))
    (format t "=================================~%")
    (format t "TOTAL: ~D, PASSED: ~D, FAILED: ~D~%"
            (+ passed failed) passed failed)
    (format t "=================================~%")
    (values passed failed)))
