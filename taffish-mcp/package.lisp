(defpackage :taffish.mcp
  (:use :cl)
  (:export
   :*taffish-mcp-version*
   :help
   :version
   :main

   ;; protocol helpers used by tests
   :handle-json-rpc-message
   :handle-json-rpc-string
   :tools-list
   :call-tool
   :resources-list
   :read-resource
   :prompts-list
   :get-prompt))
