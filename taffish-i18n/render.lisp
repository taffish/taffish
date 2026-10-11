(in-package :taffish.i18n)

;;;; ============================================================
;;;; render.lisp
;;;; ============================================================

(defun %placeholder-name-char-p (char)
  (or (and (char<= #\a char) (char<= char #\z))
      (and (char<= #\A char) (char<= char #\Z))
      (and (char<= #\0 char) (char<= char #\9))
      (member char '(#\_ #\- #\.) :test #'char=)))

(defun %placeholder-names (template)
  (let ((names nil)
        (position 0)
        (length (length template)))
    (loop while (< position length) do
      (let ((char (char template position)))
        (if (char= char #\{)
            (cond
              ((and (< (1+ position) length)
                    (char= (char template (1+ position)) #\{))
               (incf position 2))
              (t
               (let ((end (position #\} template :start (1+ position))))
                 (if (and end
                          (> end (1+ position))
                          (every #'%placeholder-name-char-p
                                 (subseq template (1+ position) end)))
                     (progn
                       (pushnew (subseq template (1+ position) end)
                                names :test #'string=)
                       (setf position (1+ end)))
                     (incf position)))))
            (incf position))))
    (sort names #'string<)))

(defun %same-placeholders-p (baseline candidate)
  (equal (%placeholder-names baseline)
         (%placeholder-names candidate)))

(defun %binding-value (name bindings)
  (let ((entry (assoc name bindings :test #'string=)))
    (values (cdr entry) (not (null entry)))))

(defun %render-template (template bindings)
  (han.host:with-character-output-to-string (out)
    (let ((position 0)
          (length (length template)))
      (loop while (< position length) do
        (let ((char (char template position)))
          (cond
            ((and (char= char #\{)
                  (< (1+ position) length)
                  (char= (char template (1+ position)) #\{))
             (write-char #\{ out)
             (incf position 2))
            ((and (char= char #\})
                  (< (1+ position) length)
                  (char= (char template (1+ position)) #\}))
             (write-char #\} out)
             (incf position 2))
            ((char= char #\{)
             (let ((end (position #\} template :start (1+ position))))
               (if (and end
                        (> end (1+ position))
                        (every #'%placeholder-name-char-p
                               (subseq template (1+ position) end)))
                   (let ((name (subseq template (1+ position) end)))
                     (multiple-value-bind (value present-p)
                         (%binding-value name bindings)
                       (if present-p
                           (princ value out)
                           (format out "{~A}" name)))
                     (setf position (1+ end)))
                   (progn
                     (write-char char out)
                     (incf position)))))
            (t
             (write-char char out)
             (incf position))))))))
