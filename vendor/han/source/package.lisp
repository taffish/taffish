(defpackage :han.source
  (:use :cl)
  (:export
   :help
   :version

   ;; char-source
   :char-source       ;; struct
   :char-source-p
   :make-char-source
   :char-source-string
   :char-source-length
   :char-source-mark  ;; struct
   :char-source-mark-p
   :make-source-mark
   :source-mark-from-source-p
   :source-location
   :source-reset
   :char-source-span       ;; struct
   :char-source-span-p
   :make-source-span
   :source-span-from-source-p
   :source-same-origin-p
   :source-slice
   :source-slice-by-span
   :source-eof-p
   :source-peek-char
   :source-peek-string
   :source-next-char
   :source-match-char-p
   :source-match-string-p
   :source-consume-char-if
   :source-advance-n
   :source-consume-string-if
   :source-skip-while
   :source-read-while))

(in-package :han.source)

(defun %get-help-string ()
  "han.source v0.1.0

Purpose:
  Character source abstraction for lexers and parsers.

Core model:
  char-source          mutable input cursor with index/line/column
  char-source-mark     saved cursor position
  char-source-span     source slice from one mark to another

Common usage:
  (han.source:make-char-source string)
  (han.source:source-peek-char source)
  (han.source:source-next-char source)
  (han.source:make-source-mark source)
  (han.source:source-reset source mark)
  (han.source:source-slice source start end)
  (han.source:source-skip-while source predicate)
  (han.source:source-read-while source predicate)

Matching helpers:
  source-match-char-p
  source-match-string-p
  source-consume-char-if
  source-consume-string-if

Example:
  (let ((src (han.source:make-char-source \"abc123\")))
    (han.source:source-read-while src #'alpha-char-p))
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.source v~A~%" version))
    version))
