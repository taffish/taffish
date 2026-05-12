;;;; ============================================================
;;;; package.lisp
;;;; ============================================================

(defpackage :han.args
  (:use :cl)
  (:export
   :help
   :version

   ;; ------------------------------------------------------------
   ;; arg-token
   :arg-token
   :arg-token-p
   :make-arg-token
   :arg-token-kind
   :arg-token-text
   :arg-token-value
   :arg-token-extra
   :arg-token-position

   ;; ------------------------------------------------------------
   ;; arg-segment
   :arg-segment
   :arg-segment-p
   :make-arg-segment
   :arg-segment-slot
   :arg-segment-positions

   ;; ------------------------------------------------------------
   ;; args-input
   :args-input
   :args-input-p
   :make-args-input
   :args-input-raw-cmd
   :args-input-raw-argv
   :args-input-tokens
   :args-input-segments
   :args-input-diagnostics

   ;; ------------------------------------------------------------
   ;; arg-diagnostic
   :arg-diagnostic
   :arg-diagnostic-p
   :make-arg-diagnostic
   :arg-diagnostic-kind
   :arg-diagnostic-code
   :arg-diagnostic-message
   :arg-diagnostic-position

   ;; ------------------------------------------------------------
   ;; arg-spec
   :arg-spec
   :arg-spec-p
   :make-arg-spec
   :arg-spec-name
   :arg-spec-long-entry
   :arg-spec-short-entry
   :arg-spec-slot-entry
   :arg-spec-arity
   :arg-spec-required
   :arg-spec-visibility
   :arg-spec-default

   ;; ------------------------------------------------------------
   ;; args-spec
   :args-spec
   :args-spec-p
   :make-args-spec
   :args-spec-command
   :args-spec-args-table

   ;; ------------------------------------------------------------
   ;; arg-binding
   :arg-binding
   :arg-binding-p
   :make-arg-binding
   :arg-binding-name
   :arg-binding-spec
   :arg-binding-value
   :arg-binding-status

   ;; ------------------------------------------------------------
   ;; args-result
   :args-result
   :args-result-p
   :make-args-result
   :args-result-spec
   :args-result-input
   :args-result-builtin-bindings
   :args-result-bindings
   :args-result-diagnostics

   ;; ------------------------------------------------------------
   ;; public functions
   :parse-args-input
   :parse-arg-spec
   :parse-args-spec
   :bind-args
   :get-arg
   :arg-key-equal))

(in-package :han.args)

(defun %get-help-string ()
  "han.args v0.1.0

Purpose:
  Parse command-line-like argv, describe argument specs, and bind input
  values into a structured args-result.

Common usage:
  (han.args:parse-args-input argv)
  (han.args:parse-arg-spec \"(--/-n)name=World\")
  (han.args:parse-args-spec specs \"command-name\")
  (han.args:bind-args args-spec args-input)
  (han.args:get-arg \"name\" args-result)

Core model:
  arg-token       low-level argv token
  arg-segment     token group, optionally under a slot such as @run:
  arg-spec        one argument definition
  args-spec       command-level argument definition set
  arg-binding     one bound argument value and status
  args-result     final binding output plus diagnostics

Spec examples:
  \"(--/-n)name=World\"     option with default value
  \"!(--/-i)input\"         required single-value option
  \"(--/-v)verbose?\"       boolean flag
  \"(@:)run\"               block/slot argument
  \"$1\"                    positional argument

Example:
  (let* ((input (han.args:parse-args-input
                 '(\"cmd\" \"--name\" \"Alice\")))
         (specs (han.args:parse-args-spec
                 (list (han.args:parse-arg-spec
                        \"(--/-n)name=World\"))
                 \"cmd\"))
         (result (han.args:bind-args specs input)))
    (han.args:get-arg \"name\" result))
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.args v~A~%" version))
    version))
