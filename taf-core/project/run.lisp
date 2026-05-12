(in-package :taf.core)

;;;; ============================================================
;;;; project / run.lisp
;;;; ============================================================

(defun %make-run-temp-dir ()
  (han.path:join-path
   (han.path:temporary-directory)
   (format nil "taffish-run-~A/" (gensym "DIR"))))

(defun %shell-command-string (program args)
  (format nil "~{~A~^ ~}"
          (mapcar #'han.os:escape-sh-token
                  (cons (han.path:->namestring program) args))))

(defun %run-shell-file (shell-file input output error-output)
  (han.os:run-program
   (%shell-command-string shell-file nil)
   :input input
   :output output
   :error-output error-output
   :ignore-error-status t))

(defun project-run (&key (args nil)
                         (start-dir (han.os:current-directory))
                         container-backend
                         (input nil)
                         (output t)
                         (error-output t))
  (unless (listp args)
    (error "[run] ARGS must be a list, but got: ~S" (type-of args)))
  (let* ((temp-dir (%make-run-temp-dir))
         (shell-file (han.path:join-path temp-dir "run.sh"))
         (shell-string (project-compile
                        args start-dir
                        :container-backend container-backend)))
    (unwind-protect
         (progn
           (%make-dir temp-dir)
           (%write-string-to-file/supersede shell-file shell-string)
           (%chmod-executable shell-file)
           (multiple-value-bind (stdout stderr exit-code)
               (%run-shell-file shell-file input output error-output)
             (list :exit-code exit-code
                   :stdout stdout
                   :stderr stderr)))
      (when (han.path:directory-exists-p (han.path:directory-pathname temp-dir))
        (han.path:delete-directory-tree
         (han.path:directory-pathname temp-dir)
         :validate t
         :if-does-not-exist :ignore)))))
