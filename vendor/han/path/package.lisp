(defpackage :han.path
  (:use :cl)
  (:export
   :help
   :version

   :->pathname
   :->namestring
   :directory-pathname-p
   :directory-pathname
	   :parent-directory-pathname
	   :join-path
	   :absolute-pathname-p
	   :absolute-pathname
	   :relative-path
	   :file-exists-p
	   :directory-exists-p
	   :directory-files
	   :subdirectories
	   :copy-file
	   :delete-directory-tree
	   :temporary-directory))

(in-package :han.path)

(defun %get-help-string ()
  "han.path v0.1.0

Purpose:
  Small pathname helpers for portable Common Lisp path manipulation.

Common usage:
  (han.path:->pathname x)
  (han.path:->namestring x)
  (han.path:directory-pathname x)
  (han.path:parent-directory-pathname x)
	  (han.path:join-path base \"src\" \"main.taf\")
	  (han.path:absolute-pathname x)
	  (han.path:relative-path target base)
	  (han.path:file-exists-p path)
	  (han.path:directory-exists-p path)

Core ideas:
	  directory-pathname-p       test whether a pathname looks like a directory
	  directory-pathname         coerce file-like input into a directory pathname
	  join-path                  merge path parts from left to right
	  absolute-pathname          resolve relative path against a base
	  relative-path              compute relative path when host/device match
	  file/directory helpers     hide implementation-specific filesystem details

Example:
  (han.path:join-path \"/tmp/\" \"taffish\" \"index\" \"current.json\")
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.path v~A~%" version))
    version))
