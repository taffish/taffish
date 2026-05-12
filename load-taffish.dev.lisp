(require :asdf)

(defun %subdir (base &rest parts)
  (merge-pathnames
   (make-pathname :directory (append '(:relative) parts))
   base))

(let* ((root (make-pathname :name nil :type nil :defaults *load-truename*))
       (han-root (%subdir root "vendor" "han")))
  (pushnew root asdf:*central-registry* :test #'equal)
  (pushnew han-root asdf:*central-registry* :test #'equal))

;; (asdf:compile-system :taffish)

(asdf:load-system :taffish.dev :force t)
