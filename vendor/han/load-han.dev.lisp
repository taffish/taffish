(require :asdf)

(pushnew (make-pathname :name nil :type nil :defaults *load-truename*)
         asdf:*central-registry*
         :test #'equal)

;;(asdf:compile-system :han)

(asdf:load-system :han.dev :force t)
