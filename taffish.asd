(asdf:defsystem "taffish"
  :description "TAFFISH project (core + cli)"
  :author "Kaiyuan Han"
  :license "Apache-2.0"
  :version "0.9.0"
  :depends-on ("han")
  :serial t
  :components
  (;; -------------------------
   ;; taffish-core
   ;; -------------------------
   (:module "taffish-core"
    :serial t
    :components
    ((:file "package")
     (:file "model")
     (:file "lexer")
     (:file "parser")
     (:file "input")
     (:file "binder")
     (:module "emitter"
      :serial t
      :components
      ((:file "model")
       (:file "registry")
       (:module "builtins"
        :serial t
        :components
                ((:file "taf-app")
                 (:file "taffish")
                 (:file "shell")
                 (:file "container")))))
     (:file "compiler")
     (:file "main")))


   ;; -------------------------
   ;; taffish-cli (可执行入口相关)
   ;; -------------------------
   (:module "taffish-cli"
    :serial t
    :components
    ((:file "package")
     (:file "run")
     (:file "main")))


   ;; -------------------------
   ;; taf-core
   ;; -------------------------
   (:module "taf-core"
    :serial t
    :components
    ((:file "package")
     (:module "project"
      :serial t
      :components
      ((:file "common")
       (:file "new")
       (:file "check")
       (:file "compile")
       (:file "build")
       (:file "run")
       (:file "publish")))
     (:module "hub"
      :serial t
      :components
      ((:file "update")
       (:file "info")
       (:file "search")
       (:file "install")
       (:file "uninstall")
       (:file "list")
       (:file "which")))
     (:module "system"
     :serial t
     :components
     ((:file "home")
      (:file "config")
      (:file "history")
      (:file "doctor")))))


   ;; -------------------------
   ;; taf-cli
   ;; -------------------------
   (:module "taf-cli"
    :serial t
    :components
    ((:file "package")
     (:file "run")
     (:file "main")))

   ;; -------------------------
   ;; taffish-mcp
   ;; -------------------------
   (:module "taffish-mcp"
    :serial t
    :components
    ((:file "package")
     (:file "protocol")
     (:file "compiler")
     (:file "app")
     (:file "project")
     (:file "tools")
     (:file "resources")
     (:file "prompts")
     (:file "server")
     (:file "main")))
   ))
