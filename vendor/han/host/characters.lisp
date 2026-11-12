(in-package :han.host)

(defun %unicode-scalar-p (code)
  (and (typep code '(integer 0 #x10FFFF))
       (not (<= #xD800 code #xDFFF))))

;; These implementations number their characters by Unicode (or a subset
;; such as Latin-1). ANSI CL itself makes no such promise about CHAR-CODE.
#+(or sbcl lispworks clisp (and ccl openmcl-unicode-strings) (and ecl unicode))
(progn
  (defun %scalar-to-char (code)
    (when (< code char-code-limit) (code-char code)))

  (defun %char-to-scalar (char)
    (char-code char)))

#-(or sbcl lispworks clisp (and ccl openmcl-unicode-strings) (and ecl unicode))
(progn
  ;; Do not guess a Unicode encoding from a few matching CHAR-CODE values.
  (defparameter *ascii-characters*
    (let ((table (make-array 128 :initial-element nil)))
      (replace table
               " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
               :start1 32)
      (setf (aref table 10) #\Newline)
      (loop for (code name) in '((8 "Backspace") (9 "Tab") (12 "Page")
                                 (13 "Return") (127 "Rubout"))
            for char = (name-char name)
            when (and char (not (find char table)))
              do (setf (aref table code) char))
      table))

  (defun %scalar-to-char (code)
    (when (< code (length *ascii-characters*)) (aref *ascii-characters* code)))

  (defun %char-to-scalar (char)
    (position char *ascii-characters*)))

(defun unicode-scalar-char (code)
  "Return the character for Unicode scalar CODE, or NIL if it cannot be mapped."
  (when (%unicode-scalar-p code) (%scalar-to-char code)))

(defun char-unicode-scalar (char)
  "Return the Unicode scalar for character CHAR, or NIL if it cannot be mapped."
  (check-type char character)
  (let ((code (%char-to-scalar char)))
    (when (%unicode-scalar-p code) code)))
