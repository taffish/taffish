(defpackage :han.json
  (:use :cl)
  (:export
   :help
   :version

   :json-error
   :json-object-p
   :json-array-p
   :json-null-p
   :make-json-object
   :json-object
   :json-array
   :json-keys
   :get-json
   :set-json
   :parse-json
   :parse-json-file
   :read-json-file
   :encode-json
   :write-json
   :write-json-file))

(in-package :han.json)

(defun %get-help-string ()
  "han.json v0.1.0

Purpose:
  Minimal portable Common Lisp JSON parser/writer.

Data model:
  JSON object -> EQUAL hash-table
  JSON array  -> vector
  JSON true   -> T
  JSON false  -> NIL
  JSON null   -> :NULL

Common usage:
  (han.json:parse-json string)
  (han.json:read-json-file path)
  (han.json:get-json object \"key\")
  (han.json:encode-json object)
  (han.json:write-json-file path object)

Construction:
  (han.json:json-object (cons \"name\" \"taffish\"))
  (han.json:json-array 1 2 \"x\")

Important note:
  get-json returns a second value indicating key presence, so JSON false/NIL
  can be distinguished from a missing key.

Example:
  (multiple-value-bind (value present-p)
      (han.json:get-json object \"enabled\")
    (list value present-p))
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.json v~A~%" version))
    version))
