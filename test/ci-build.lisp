;;;; Internal SBCL adapter for ci-build.sh; not a release delivery interface.
#-sbcl
(error "CI development builds require SBCL.")

(require :asdf)

(defparameter *ci-source-root*
  (truename (merge-pathnames "../" (make-pathname :name nil :type nil
                                                 :defaults *load-truename*))))
(defparameter *ci-output-root* (truename (second sb-ext:*posix-argv*)))
(defparameter *ci-entry-name* (third sb-ext:*posix-argv*))

;; Ignore user output configuration. The location DSL appends recursive source
;; wildcards after :implementation, preserving the full source path. A bare
;; directory pathname here would flatten package/core FASLs and cause collisions
;; when the next entry point reuses the cache in a fresh Lisp process.
(asdf:initialize-output-translations
 (list :output-translations
       (list t (list (merge-pathnames "cache/" *ci-output-root*) :implementation))
       :ignore-inherited-configuration))
(asdf:load-asd (merge-pathnames "vendor/han/han.asd" *ci-source-root*))
(asdf:load-asd (merge-pathnames "taffish.asd" *ci-source-root*))
(asdf:load-system :taffish)

(let ((entry (cond ((string= *ci-entry-name* "taf") #'taf.cli:main)
                   ((string= *ci-entry-name* "taffish") #'taffish.cli:main)
                   ((string= *ci-entry-name* "taffish-mcp") #'taffish.mcp:main)
                   (t (error "Unknown CI entry: ~S" *ci-entry-name*)))))
  ;; Match the existing SBCL loader's executable settings without changing its
  ;; public target/ output contract or the maintainer's LispWorks delivery.
  (sb-ext:save-lisp-and-die (merge-pathnames *ci-entry-name* *ci-output-root*)
                          :save-runtime-options "--end-toplevel-options"
                          :executable t :purify t :toplevel entry))
