(asdf:defsystem "han"
  :description "Han foundational Common Lisp utilities"
  :author "Kaiyuan Han"
  :license "MIT"
  :version "0.1.0"
  :serial t
  :components
  ((:module "test"
    :serial t
    :components
    ((:file "package")
     (:file "core")))
   (:module "host"
    :serial t
    :components
    ((:file "package")
     (:file "common")
     (:file "parameters")
     #+lispworks
     (:file "lispworks")
     #+sbcl
     (:file "sbcl")
     #-(or lispworks sbcl)
     (:file "unsupported")))
   (:module "source"
    :serial t
    :components
    ((:file "package")
     (:file "char-source")))
   (:module "os"
    :serial t
    :components
    ((:file "package")
     (:file "io")
     (:file "env")
     (:file "run-shell")))
   (:module "path"
    :serial t
    :components
    ((:file "package")
     (:file "core")))
   (:module "json"
    :serial t
    :components
    ((:file "package")
     (:file "core")))
   (:module "args"
    :serial t
    :components
    ((:file "package")
     (:file "lexer")
     (:file "spec")
     (:file "bind")
     (:file "query")))))
