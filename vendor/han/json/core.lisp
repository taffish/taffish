(in-package :han.json)

(define-condition json-error (error)
  ((message :initarg :message :reader json-error-message))
  (:report (lambda (condition stream)
             (format stream "~A" (json-error-message condition)))))

(defun %json-error (format-control &rest args)
  (error 'json-error
         :message (apply #'format nil format-control args)))

(defun make-json-object (&optional pairs)
  "Create a JSON object represented by an EQUAL hash table."
  (let ((object (make-hash-table :test #'equal)))
    (dolist (pair pairs object)
      (unless (and (consp pair) (stringp (car pair)))
        (%json-error "JSON object pair must be (string . value), got ~S" pair))
      (setf (gethash (car pair) object) (cdr pair)))))

(defun json-object (&rest pairs)
  "Create a JSON object from cons pairs: (json-object (cons \"k\" value))."
  (make-json-object pairs))

(defun json-array (&rest values)
  "Create a JSON array represented by a vector."
  (coerce values 'vector))

(defun json-object-p (value)
  (hash-table-p value))

(defun json-array-p (value)
  (and (vectorp value)
       (not (stringp value))))

(defun json-null-p (value)
  (eq value :null))

(defun json-keys (object)
  "Return sorted keys from a JSON object."
  (unless (json-object-p object)
    (%json-error "JSON object expected, got ~S" object))
  (let ((keys nil))
    (maphash (lambda (key value)
               (declare (ignore value))
               (push key keys))
             object)
    (sort keys #'string<)))

(defun get-json (object key &optional default)
  "Return KEY from OBJECT.
The second value is T when KEY exists, so JSON false/NIL can be distinguished
from a missing key."
  (unless (json-object-p object)
    (return-from get-json (values default nil)))
  (unless (stringp key)
    (%json-error "JSON key must be a string, got ~S" key))
  (multiple-value-bind (value present-p)
      (gethash key object)
    (if present-p
        (values value t)
        (values default nil))))

(defun set-json (object key value)
  (unless (json-object-p object)
    (%json-error "JSON object expected, got ~S" object))
  (unless (stringp key)
    (%json-error "JSON key must be a string, got ~S" key))
  (setf (gethash key object) value)
  value)

(defun %json-ws-p (char)
  (member char '(#\Space #\Tab #\Newline #\Return) :test #'char=))

(defun %json-skip-ws (string pos)
  (loop while (and (< pos (length string))
                   (%json-ws-p (char string pos)))
        do (incf pos)
        finally (return pos)))

(defun %json-digit-p (char)
  (and (char<= #\0 char) (char<= char #\9)))

(defun %json-hex-value (char)
  (cond
    ((and (char<= #\0 char) (char<= char #\9))
     (- (char-code char) (char-code #\0)))
    ((and (char<= #\a char) (char<= char #\f))
     (+ 10 (- (char-code char) (char-code #\a))))
    ((and (char<= #\A char) (char<= char #\F))
     (+ 10 (- (char-code char) (char-code #\A))))
    (t nil)))

(defun %json-parse-hex4 (string pos)
  (when (> (+ pos 4) (length string))
    (%json-error "unterminated JSON unicode escape at position ~D" pos))
  (let ((code 0))
    (dotimes (i 4)
      (let ((value (%json-hex-value (char string (+ pos i)))))
        (unless value
          (%json-error "bad JSON unicode escape at position ~D" (+ pos i)))
        (setf code (+ (* code 16) value))))
    (values code (+ pos 4))))

(defun %json-code-char (code pos)
  (let ((char (funcall (symbol-function 'code-char) code)))
    (if char
        char
        (%json-error "unsupported JSON character code U+~4,'0X at position ~D"
                     code pos))))

(defun %json-parse-unicode-escape (string pos)
  (multiple-value-bind (code next-pos)
      (%json-parse-hex4 string pos)
    (cond
      ((<= #xD800 code #xDBFF)
       (unless (and (<= (+ next-pos 6) (length string))
                    (char= (char string next-pos) #\\)
                    (char= (char string (1+ next-pos)) #\u))
         (%json-error "missing low surrogate after high surrogate at position ~D"
                      pos))
       (multiple-value-bind (low low-pos)
           (%json-parse-hex4 string (+ next-pos 2))
         (unless (<= #xDC00 low #xDFFF)
           (%json-error "bad low surrogate U+~4,'0X at position ~D"
                        low (+ next-pos 2)))
         (values (%json-code-char
                  (+ #x10000
                     (* (- code #xD800) #x400)
                     (- low #xDC00))
                  pos)
                 low-pos)))
      ((<= #xDC00 code #xDFFF)
       (%json-error "unexpected low surrogate at position ~D" pos))
      (t
       (values (%json-code-char code pos) next-pos)))))

(defun %json-parse-string (string pos)
  (unless (and (< pos (length string))
               (char= (char string pos) #\"))
    (%json-error "expected JSON string at position ~D" pos))
  (incf pos)
  (let ((out (make-string-output-stream)))
    (loop
      (when (>= pos (length string))
        (%json-error "unterminated JSON string"))
      (let ((char (char string pos)))
        (incf pos)
        (cond
          ((char= char #\")
           (return-from %json-parse-string
             (values (get-output-stream-string out) pos)))
          ((< (char-code char) #x20)
           (%json-error "unescaped control character in JSON string at position ~D"
                        (1- pos)))
          ((char= char #\\)
           (when (>= pos (length string))
             (%json-error "unterminated JSON escape"))
           (let ((escape (char string pos)))
             (incf pos)
             (case escape
               (#\" (write-char #\" out))
               (#\\ (write-char #\\ out))
               (#\/ (write-char #\/ out))
               (#\b (write-char #\Backspace out))
               (#\f (write-char #\Page out))
               (#\n (write-char #\Newline out))
               (#\r (write-char #\Return out))
               (#\t (write-char #\Tab out))
               (#\u
                (multiple-value-bind (unicode-char next-pos)
                    (%json-parse-unicode-escape string pos)
                  (write-char unicode-char out)
                  (setf pos next-pos)))
               (otherwise
                (%json-error "bad JSON escape ~S at position ~D"
                             escape (1- pos))))))
          (t
           (write-char char out)))))))

(defun %json-parse-int (string pos)
  (let ((len (length string)))
    (cond
      ((>= pos len)
       (%json-error "expected JSON integer at position ~D" pos))
      ((char= (char string pos) #\0)
       (values (1+ pos) nil))
         ((and (char<= #\1 (char string pos))
            (char<= (char string pos) #\9))
       (loop do (incf pos)
             while (and (< pos len)
                        (%json-digit-p (char string pos))))
       (values pos nil))
      (t
       (%json-error "expected JSON integer at position ~D" pos)))))

(defun %json-digits-integer (string start end)
  (let ((value 0))
    (loop for index from start below end do
      (setf value (+ (* value 10)
                     (- (char-code (char string index))
                        (char-code #\0)))))
    value))

(defun %json-number-value (raw)
  (let* ((len (length raw))
         (pos 0)
         (negative-p nil)
         (float-p nil))
    (when (and (< pos len) (char= (char raw pos) #\-))
      (setf negative-p t)
      (incf pos))
    (let ((int-start pos))
      (loop while (and (< pos len)
                       (%json-digit-p (char raw pos)))
            do (incf pos))
      (let ((int-value (%json-digits-integer raw int-start pos))
            (frac-value 0)
            (frac-scale 1)
            (exp-sign 1)
            (exp-value 0))
        (when (and (< pos len) (char= (char raw pos) #\.))
          (setf float-p t)
          (incf pos)
          (let ((frac-start pos))
            (loop while (and (< pos len)
                             (%json-digit-p (char raw pos)))
                  do (incf pos))
            (setf frac-value (%json-digits-integer raw frac-start pos)
                  frac-scale (expt 10 (- pos frac-start)))))
        (when (and (< pos len)
                   (member (char raw pos) '(#\e #\E) :test #'char=))
          (setf float-p t)
          (incf pos)
          (when (and (< pos len)
                     (member (char raw pos) '(#\+ #\-) :test #'char=))
            (when (char= (char raw pos) #\-)
              (setf exp-sign -1))
            (incf pos))
          (let ((exp-start pos))
            (loop while (and (< pos len)
                             (%json-digit-p (char raw pos)))
                  do (incf pos))
            (setf exp-value (%json-digits-integer raw exp-start pos))))
        (if float-p
            (let* ((base (+ (coerce int-value 'double-float)
                            (/ (coerce frac-value 'double-float)
                               (coerce frac-scale 'double-float))))
                   (scaled (* base
                              (expt 10d0 (* exp-sign exp-value)))))
              (if negative-p (- scaled) scaled))
            (if negative-p (- int-value) int-value))))))

(defun %json-parse-number (string pos)
  (let* ((start pos)
         (len (length string)))
    (when (and (< pos len) (char= (char string pos) #\-))
      (incf pos))
    (multiple-value-bind (next-pos ignored)
        (%json-parse-int string pos)
      (declare (ignore ignored))
      (setf pos next-pos))
    (when (and (< pos len) (char= (char string pos) #\.))
      (incf pos)
      (unless (and (< pos len) (%json-digit-p (char string pos)))
        (%json-error "expected digit after JSON decimal point at position ~D" pos))
      (loop do (incf pos)
            while (and (< pos len)
                       (%json-digit-p (char string pos)))))
    (when (and (< pos len)
               (member (char string pos) '(#\e #\E) :test #'char=))
      (incf pos)
      (when (and (< pos len)
                 (member (char string pos) '(#\+ #\-) :test #'char=))
        (incf pos))
      (unless (and (< pos len) (%json-digit-p (char string pos)))
        (%json-error "expected digit after JSON exponent at position ~D" pos))
      (loop do (incf pos)
            while (and (< pos len)
                       (%json-digit-p (char string pos)))))
    (let ((raw (subseq string start pos)))
      (when (and (> (length raw) 1)
                 (char= (char raw 0) #\0)
                 (%json-digit-p (char raw 1)))
        (%json-error "leading zero is not allowed in JSON number at position ~D"
                     start))
      (when (and (> (length raw) 2)
                 (char= (char raw 0) #\-)
                 (char= (char raw 1) #\0)
                 (%json-digit-p (char raw 2)))
        (%json-error "leading zero is not allowed in JSON number at position ~D"
                     start))
      (values (%json-number-value raw) pos))))

(defun %json-expect (string pos token value)
  (let ((end (+ pos (length token))))
    (unless (and (<= end (length string))
                 (string= token (subseq string pos end)))
      (%json-error "expected JSON token ~A at position ~D" token pos))
    (values value end)))

(defun %json-parse-array (string pos)
  (incf pos)
  (let ((values nil))
    (setf pos (%json-skip-ws string pos))
    (when (and (< pos (length string)) (char= (char string pos) #\]))
      (return-from %json-parse-array (values #() (1+ pos))))
    (loop
      (multiple-value-bind (value next-pos)
          (%json-parse-value string pos)
        (push value values)
        (setf pos (%json-skip-ws string next-pos)))
      (when (>= pos (length string))
        (%json-error "unterminated JSON array"))
      (cond
        ((char= (char string pos) #\,)
         (setf pos (%json-skip-ws string (1+ pos)))
         (when (and (< pos (length string)) (char= (char string pos) #\]))
           (%json-error "trailing comma in JSON array at position ~D" pos)))
        ((char= (char string pos) #\])
         (return (values (coerce (nreverse values) 'vector) (1+ pos))))
        (t
         (%json-error "expected ',' or ']' at position ~D" pos))))))

(defun %json-parse-object (string pos)
  (incf pos)
  (let ((object (make-json-object)))
    (setf pos (%json-skip-ws string pos))
    (when (and (< pos (length string)) (char= (char string pos) #\}))
      (return-from %json-parse-object (values object (1+ pos))))
    (loop
      (unless (and (< pos (length string)) (char= (char string pos) #\"))
        (%json-error "expected JSON object key at position ~D" pos))
      (multiple-value-bind (key key-pos)
          (%json-parse-string string pos)
        (setf pos (%json-skip-ws string key-pos))
        (unless (and (< pos (length string)) (char= (char string pos) #\:))
          (%json-error "expected ':' at position ~D" pos))
        (multiple-value-bind (value next-pos)
            (%json-parse-value string (%json-skip-ws string (1+ pos)))
          (set-json object key value)
          (setf pos (%json-skip-ws string next-pos))))
      (when (>= pos (length string))
        (%json-error "unterminated JSON object"))
      (cond
        ((char= (char string pos) #\,)
         (setf pos (%json-skip-ws string (1+ pos)))
         (when (and (< pos (length string)) (char= (char string pos) #\}))
           (%json-error "trailing comma in JSON object at position ~D" pos)))
        ((char= (char string pos) #\})
         (return (values object (1+ pos))))
        (t
         (%json-error "expected ',' or '}' at position ~D" pos))))))

(defun %json-parse-value (string pos)
  (setf pos (%json-skip-ws string pos))
  (when (>= pos (length string))
    (%json-error "unexpected end of JSON"))
  (case (char string pos)
    (#\" (%json-parse-string string pos))
    (#\{ (%json-parse-object string pos))
    (#\[ (%json-parse-array string pos))
    (#\t (%json-expect string pos "true" t))
    (#\f (%json-expect string pos "false" nil))
    (#\n (%json-expect string pos "null" :null))
    ((#\- #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
     (%json-parse-number string pos))
    (otherwise
     (%json-error "unexpected JSON character ~S at position ~D"
                  (char string pos) pos))))

(defun parse-json (string)
  "Parse STRING as JSON.
JSON object => EQUAL hash table.
JSON array  => vector.
JSON true   => T.
JSON false  => NIL.
JSON null   => :NULL."
  (unless (stringp string)
    (%json-error "parse-json expects a string, got ~S" string))
  (multiple-value-bind (value pos)
      (%json-parse-value string 0)
    (let ((end (%json-skip-ws string pos)))
      (unless (= end (length string))
        (%json-error "trailing JSON content at position ~D" end))
      value)))

(defun %read-file-string (path)
  (with-open-file (in path :direction :input)
    (let ((out (make-string-output-stream)))
      (loop for char = (read-char in nil nil)
            while char
            do (write-char char out))
      (get-output-stream-string out))))

(defun parse-json-file (path)
  (parse-json (%read-file-string path)))

(defun read-json-file (path)
  (parse-json-file path))

(defun %json-write-hex4 (code out)
  (format out "\\u~4,'0X" code))

(defun %json-write-char (char out)
  (let ((code (char-code char)))
    (cond
      ((char= char #\")
       (write-string "\\\"" out))
      ((char= char #\\)
       (write-string "\\\\" out))
      ((char= char #\Backspace)
       (write-string "\\b" out))
      ((char= char #\Page)
       (write-string "\\f" out))
      ((char= char #\Newline)
       (write-string "\\n" out))
      ((char= char #\Return)
       (write-string "\\r" out))
      ((char= char #\Tab)
       (write-string "\\t" out))
      ((or (< code #x20) (> code #x7E))
       (if (<= code #xFFFF)
           (%json-write-hex4 code out)
           (let* ((rest (- code #x10000))
                  (high (+ #xD800 (floor rest #x400)))
                  (low (+ #xDC00 (mod rest #x400))))
             (%json-write-hex4 high out)
             (%json-write-hex4 low out))))
      (t
       (write-char char out)))))

(defun %json-write-string (string out)
  (write-char #\" out)
  (loop for char across string do
    (%json-write-char char out))
  (write-char #\" out))

(defun %json-number-string (number)
  (cond
    ((integerp number)
     (princ-to-string number))
    ((floatp number)
     (let ((raw (princ-to-string number)))
       (substitute #\e #\d
                   (substitute #\e #\D raw))))
    (t
     (%json-error "JSON number must be an integer or float, got ~S" number))))

(defun %json-write-value (value out indent level)
  (labels ((newline+indent (n)
             (when indent
               (write-char #\Newline out)
               (loop repeat (* indent n) do (write-char #\Space out)))))
    (cond
      ((json-object-p value)
       (write-char #\{ out)
       (let ((keys (json-keys value)))
         (loop for key in keys
               for first-p = t then nil do
           (unless first-p
             (write-char #\, out))
           (newline+indent (1+ level))
           (%json-write-string key out)
           (write-string (if indent ": " ":") out)
           (%json-write-value (gethash key value) out indent (1+ level)))
         (when keys
           (newline+indent level)))
       (write-char #\} out))
      ((stringp value)
       (%json-write-string value out))
      ((json-array-p value)
       (write-char #\[ out)
       (loop for i from 0 below (length value)
             for first-p = t then nil do
         (unless first-p
           (write-char #\, out))
         (newline+indent (1+ level))
         (%json-write-value (aref value i) out indent (1+ level)))
       (when (> (length value) 0)
         (newline+indent level))
       (write-char #\] out))
      ((eq value t)
       (write-string "true" out))
      ((null value)
       (write-string "false" out))
      ((eq value :null)
       (write-string "null" out))
      ((eq value :false)
       (write-string "false" out))
      ((numberp value)
       (write-string (%json-number-string value) out))
      (t
       (%json-error "unsupported JSON value: ~S" value)))))

(defun write-json (value stream &key (indent 2))
  "Write VALUE as JSON to STREAM.
Set INDENT to NIL for compact output."
  (%json-write-value value stream indent 0)
  (when indent
    (write-char #\Newline stream))
  value)

(defun encode-json (value &key (indent 2))
  "Return VALUE encoded as a JSON string.
Set INDENT to NIL for compact output."
  (with-output-to-string (out)
    (write-json value out :indent indent)))

(defun write-json-file (path value &key (indent 2))
  (ensure-directories-exist path)
  (with-open-file (out path
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (write-json value out :indent indent))
  path)
