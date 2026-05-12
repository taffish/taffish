(defpackage :taffish.core
  (:use :cl)
  (:export
   ;; model
   :taffish-error
   :taffish-error-message
   :taffish-error-line
   :taffish-error-column
   :taffish-error-source-string
   :signal-taffish-error
   ;; taf-token
   :taf-token
   :taf-token-p
   :make-taf-token
   :taf-token-raw-string
   :taf-token-value
   :taf-token-kind
   :taf-token-line
   :taf-token-column
   ;; taf-line
   :taf-line
   :taf-line-p
   :make-taf-line
   :taf-line-raw-string
   :taf-line-tokens
   :taf-line-kind
   :taf-line-subkind
   :taf-line-line-number
   ;; taf-context
   :taf-context
   :taf-context-p
   :make-taf-context
   :taf-context-user
   :taf-context-homedir
   :taf-context-workdir
   :taf-context-loaddir
   :taf-context-argv
   :taf-context-cmd
   :taf-context-cpus
   :taf-context-container
   :taf-context-extras
   ;; taf-program
   :taf-program
   :taf-program-p
   :make-taf-program
   :taf-program-source-string
   :taf-program-lines
   :taf-program-args-spec
   :taf-program-body
   :taf-program-metadata
   ;; taf-result
   :taf-result
   :taf-result-p
   :make-taf-result
   :taf-result-program
   :taf-result-args-result
   :taf-result-context
   :taf-result-body
   :taf-result-diagnostics

   ;; lexer
   :lex-taf

   ;; parser
   :parse-taf

   ;; input
   :normalize-input-args
   :normalize-input-context

   ;; bind
   :bind-taf

   ;; emitter
   :*taf-emitters*
   :taf-emitter
   :taf-emitter-p
   :make-taf-emitter
   :taf-emitter-name
   :taf-emitter-match-function
   :taf-emitter-emit-function
   :register-emitter
   :defemitter
   :emit-block
   :default-prelude
   :default-finalize

   ;; compiler
   :compile-taf-result
   ;; :compile-taf-program
   :compile-taf

   ;; main
   :taffish-to-shell))
