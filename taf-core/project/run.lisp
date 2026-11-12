(in-package :taf.core)

;;;; ============================================================
;;;; project / run.lisp
;;;; ============================================================

(defun %run-utility (name)
  (or (han.os:find-executable name)
      (error "Cannot find ~A for the temporary run directory." name)))

(defun %make-run-temp-dir ()
  (let* ((prefix (han.path:->namestring
                  (han.path:absolute-pathname
                   (han.path:join-path (han.path:temporary-directory) "taffish-run-"))))
         (template (concatenate 'string prefix "XXXXXXXX"))
         (output (han.os:run-program (list (%run-utility "mktemp") "-d" template)
                                     :ignore-error-status nil))
         (name (string-right-trim '(#\Newline) output)))
    ;; Only a child of our template directory may enter recursive cleanup.
    (unless (and (= (length name) (length template))
                 (string= prefix name :end2 (length prefix))
                 (every #'alphanumericp (subseq name (length prefix))))
      (error "Unexpected temporary run directory returned by mktemp: ~S" name))
    name))

(defun %run-shell-file (shell-file input output error-output)
  (han.os:run-program
   (list "/bin/sh" (han.path:->namestring shell-file))
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
    (%project-error "run-args" :value (%project-repr (type-of args))))
  (let* ((shell-string (project-compile args start-dir :container-backend container-backend))
         (rm (%run-utility "rm"))
         (temp-dir (%make-run-temp-dir)))
    (unwind-protect
         (let ((shell-file (han.path:join-path (han.path:directory-pathname temp-dir) "run.sh")))
           (%write-string-to-file/supersede shell-file shell-string)
           (multiple-value-bind (stdout stderr exit-code)
               (%run-shell-file shell-file input output error-output)
             (list :exit-code exit-code
                   :stdout stdout
                   :stderr stderr)))
      ;; Keep the original literal name, even if the script moved its directory.
      (han.os:run-program (list rm "-rf" temp-dir) :ignore-error-status nil))))
