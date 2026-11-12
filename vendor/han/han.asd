(asdf:defsystem "han"
  :description "Han foundational Common Lisp utilities"
  :author "Kaiyuan Han"
  :license "MIT"
  :version "0.3.0"
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
     (:file "characters")
     (:file "common")
     (:file "parameters")
     #+lispworks
     (:file "lispworks")
     #+sbcl
     (:file "sbcl")
     #+(and ecl unicode (or darwin linux))
     (:file "ecl")
     #+(and ccl 64-bit-target (or darwin linux))
     (:file "ccl")
     #-(or lispworks sbcl (and ecl unicode (or darwin linux))
           (and ccl 64-bit-target (or darwin linux)))
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
