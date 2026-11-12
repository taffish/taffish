(asdf:defsystem "han.dev"
  :description "Han foundational Common Lisp utilities"
  :author "Kaiyuan Han"
  :license "MIT"
  :version "0.3.0"
  :depends-on ("uiop")
  :serial t
  :components
  ((:module "test"
    :serial t
    :components
    ((:file "package")
     (:file "core")
     (:file "test")))
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
     (:file "unsupported")
     (:file "test")))
   (:module "source"
    :serial t
    :components
    ((:file "package")
     (:file "char-source")
     (:file "test")))
   (:module "os"
    :serial t
    :components
    ((:file "package")
     (:file "io")
     (:file "env")
     (:file "run-shell")
     (:file "test")))
   (:module "path"
    :serial t
    :components
    ((:file "package")
     (:file "core")
     (:file "test")))
   (:module "json"
    :serial t
    :components
    ((:file "package")
     (:file "core")
     (:file "test")))
   (:module "args"
    :serial t
    :components
    ((:file "package")
     (:file "lexer")
     (:file "spec")
     (:file "bind")
     (:file "query")
     (:file "test")))
   (:module "tests"
    :components ((:file "cli")))))
