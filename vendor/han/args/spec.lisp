(in-package :han.args)

;;;; ============================================================
;;;; spec.lisp
;;;; ============================================================

(defun arg-key-equal (x y)
  (cond
    ((and (stringp x) (stringp y))
     (string-equal x y))
    (t
     (eql x y))))

(defun arg-name-char-p (char)
  (or (alphanumericp char)
      (member char (list #\- #\_ #\* #\+) :test #'char=)))

(defstruct arg-spec
  name              ;; internal normalized name
  (long-entry nil)  ;; e.g. "--input"
  (short-entry nil) ;; e.g. "-i" "-lw"
  (slot-entry nil)  ;; e.g. "@1-blast:"
  (arity :single)   ;; :flag | :single | :block | :position
  (required nil)
  (visibility :public) ;; :public | :hidden
  (default nil))    ;; nil | string | (:query "name") | (:concat ...)

(defstruct args-spec
  command
  args-table)  ;; hash-table: name -> arg-spec

(defun entry-kind (string)
  (let ((len (length string)))
    (case len
      (0 :error)
      (1 (if (string= "-" string)
             :short
             :error))
      (t (if (string= "--" (subseq string 0 2))
             :long
             (if (char= #\- (char string 0))
                 :short
                 (if (and (char= #\@ (char string 0))
                          (char= #\: (char string (1- len))))
                     :slot
                     :error)))))))

(defun validate-no-space (field-name string &optional origin)
  (when (and string (find #\Space string))
    (error "~@[~A: ~]you can't have #\\Space in your ~A."
           origin field-name))
  (when (and string (string= "" string))
    (error "~@[~A: ~]you can't use empty string for your ~A."
           origin field-name)))

(defun validate-arg-spec (arg &optional origin)
  (let ((name (arg-spec-name arg))
        (long-entry  (arg-spec-long-entry arg))
        (short-entry (arg-spec-short-entry arg))
        (slot-entry  (arg-spec-slot-entry arg)))
    (unless name
      (error "~@[~A: ~]missing required field NAME." origin))
    (when (and (eql (arg-spec-arity arg) :flag)
               (arg-spec-required arg))
      (error "~@[~A: ~]FLAG arguments can't be required." origin))
    (when (stringp name)
      (validate-no-space 'name        name        origin))
    (validate-no-space 'long-entry  long-entry  origin)
    (validate-no-space 'short-entry short-entry origin)
    (validate-no-space 'slot-entry  slot-entry  origin)
    (when (and (or long-entry short-entry)
               (arg-spec-slot-entry arg))
      (error "~@[~A: ~]LONG/SHORT-ENTRY and SLOT-ENTRY can't be set together!"
             origin)))
  (when (and (arg-spec-slot-entry arg)
             (eql (arg-spec-arity arg) :flag))
    (error "~@[~A: ~]SLOT-ENTRY can't use :FLAG arity!"
           origin))
  (when (and (arg-spec-required arg)
             (eql (arg-spec-visibility arg) :hidden)
             (not (eql (arg-spec-arity arg) :flag))
             (null (arg-spec-default arg)))
    (error "~@[~A: ~]you can't HIDE a none-default REQUIRED option!"
           origin))
  arg)

(defun parse-default-expression (string)
  "Parse STRING into default expression:
- plain string
- (:query \"name\")
- (:concat ...)

Supported query syntaxes:
1. @name
2. @{name}

Escapes in default expression:
  \\@ => @
  \\\\ => \\
  \\{ => {
  \\} => }"
  (let ((len (length string))
        (parts nil))
    (labels ((default-escaped-char-p (char)
               (member char (list #\@ #\\ #\{ #\}) :test #'char=))
             (emit-text (chars)
               (when chars
                 (push (coerce (nreverse chars) 'string) parts)))
             (read-braced-name (index)
               (labels ((rbn (i chars)
                          (cond
                            ((>= i len)
                             (error "Unclosed @{...} in default expression: ~A"
                                    string))
                            ((char= (char string i) #\})
                             (let ((name (coerce (nreverse chars) 'string)))
                               (when (string= name "")
                                 (error "Empty name in @{...}: ~A" string))
                               (when (find-if-not #'arg-name-char-p name)
                                 (error "Invalid name ~S in @{...}: ~A"
                                        name string))
                               (values name (1+ i))))
                            (t
                             (rbn (1+ i)
                                  (cons (char string i) chars))))))
                 (rbn index nil)))
             (read-plain-name (index)
               (labels ((rpn (i chars)
                          (if (and (< i len)
                                   (arg-name-char-p (char string i)))
                              (rpn (1+ i)
                                   (cons (char string i) chars))
                              (let ((name (coerce (nreverse chars) 'string)))
                                (when (string= name "")
                                  (error "Empty @name in default expression: ~A"
                                         string))
                                (values name i)))))
                 (rpn index nil)))
             (scan (index text-chars)
               (cond
                 ((>= index len)
                  (emit-text text-chars)
                  (let ((result (nreverse parts)))
                    (cond
                      ((null result) "")
                      ((null (cdr result)) (car result))
                      (t (cons :concat result)))))

                 ;; Escape only default-expression special chars.
                 ((and (< (1+ index) len)
                       (char= (char string index) #\\)
                       (default-escaped-char-p
                        (char string (1+ index))))
                  (scan (+ index 2)
                        (cons (char string (1+ index)) text-chars)))

                 ;; Query.
                 ((char= (char string index) #\@)
                  (if (and (< (1+ index) len)
                           (char= (char string (1+ index)) #\{))
                      (multiple-value-bind (name next-index)
                          (read-braced-name (+ index 2))
                        (emit-text text-chars)
                        (push (list :query name) parts)
                        (scan next-index nil))
                      (multiple-value-bind (name next-index)
                          (read-plain-name (1+ index))
                        (emit-text text-chars)
                        (push (list :query name) parts)
                        (scan next-index nil))))

                 ;; Normal character.
                 (t
                  (scan (1+ index)
                        (cons (char string index) text-chars))))))
      (scan 0 nil))))

;; !/% (--/-/@:) name ?/= default
;; "$0" "$1" "$n" ...
(defun parse-arg-spec (spec-string)
  (let ((len (length spec-string))
        (mode :prefix) ;; :prefix | :entry | :name | :default
        (name nil)
        (long-entry nil)
        (short-entry nil)
        (slot-entry nil)
        (arity :single)
        (required nil)
        (visibility :public)
        (default nil))
    (labels ((pas (index start)
               (if (< index len)
                   (let ((now-char (char spec-string index)))
                     (case mode
                       (:prefix
                        (case now-char
                          (#\Space
                           (pas (1+ index) start))
                          (#\!
                           (setf required t)
                           (pas (1+ index) start))
                          (#\%
                           (setf visibility :hidden)
                           (pas (1+ index) start))
                          (#\(
                           (setf mode :entry)
                           (pas (1+ index) (1+ index)))
                          ;; $n 是独立完整 spec，不继续按普通 name/default 语法扫描
                          (#\$
                           (let* ((left (subseq (string-trim " " spec-string) 1))
                                  (position (ignore-errors (parse-integer left))))
                             (if position
                                 (setf name position)
                                 (error "[~A] is not a correct position format."
                                        spec-string)))
                           (setf arity :position)
                           (setf required t))
                          (t
                           (setf mode :name)
                           (pas index index))))
                       (:entry
                        (case now-char
                          (#\/
                           (let ((option (string-trim " " (subseq spec-string start index))))
                             (case (entry-kind option)
                               (:short (setf short-entry option))
                               (:long (setf long-entry option))
                               (:slot (setf slot-entry option) (setf arity :block))
                               (:error (error "[~A] have error entry: [~A]"
                                              spec-string option)))
                             (pas (1+ index) (1+ index))))
                          (#\)
                           (let ((option (string-trim " " (subseq spec-string start index))))
                             (case (entry-kind option)
                               (:short (setf short-entry option))
                               (:long (setf long-entry option))
                               (:slot (setf slot-entry option) (setf arity :block))
                               (:error (error "[~A] have error entry: [~A]"
                                              spec-string option)))
                             (setf mode :name)
                             (pas (1+ index) (1+ index))))
                          (t
                           (pas (1+ index) start))))
                       (:name
                        (case now-char
                          (#\?
                           (setf name (string-trim " " (subseq spec-string start index)))
                           (setf arity :flag)
                           (setf mode :default)
                           (case (ignore-errors (char spec-string (1+ index)))
                             ((#\? #\=)
                              (error "[~A] spec only can be '?' or '='." spec-string)))
                           (pas (1+ index) (1+ index)))
                          (#\=
                           (setf name (string-trim " " (subseq spec-string start index)))
                           (setf mode :default)
                           (case (ignore-errors (char spec-string (1+ index)))
                             ((#\? #\=)
                              (error "[~A] spec only can be '?' or '='." spec-string)))
                           (pas (1+ index) (1+ index)))
                          (t
                           (pas (1+ index) start))))
                       (:default
                        (pas (1+ index) start))
                       (t
                        (error "It's impossible to see this mode [~A]" mode))))
                   (progn
                     (case mode
                       (:name
                        (if (< start len)
                            (setf name (string-trim " " (subseq spec-string start)))
                            (error "[~A] missed the NAME" spec-string)))
                       (:default
                        (when (< start len)
                          (setf default (string-trim " " (subseq spec-string start)))))
                       (t
                        (error "Please check your SPEC-STRING[~A] format!" spec-string)))))))
      (pas 0 0)
      (when (and long-entry (string= long-entry "--"))
        (setf long-entry (format nil "--~A" name)))
      (when (and short-entry (string= short-entry "-"))
        (setf short-entry (format nil "-~A" (char name 0))))
      (when (and slot-entry (string= slot-entry "@:"))
        (setf slot-entry (format nil "@~A:" name)))
      (when (and (eql arity :flag) default (string-equal default "nil"))
        (setf default nil)) ;; everthing else is true
      (when default
        (setf default
              (parse-default-expression
               (string-trim " " default))))
      ;; Flag arguments are always optional: absent => NIL, present => T.
      (when (eql arity :flag)
        (setf required nil))
      (let ((the-arg (make-arg-spec :name name
                                    :long-entry long-entry
                                    :short-entry short-entry
                                    :slot-entry slot-entry
                                    :arity arity
                                    :required required
                                    :visibility visibility
                                    :default default)))
        (validate-arg-spec the-arg spec-string)))))

(defun combine-arg-info (field-name get-info-fun arg1 arg2)
  (let ((info-1 (funcall get-info-fun arg1))
        (info-2 (funcall get-info-fun arg2)))
    (cond
      ((and (null info-1) (null info-2)) nil)
      ((and (null info-1) info-2) info-2)
      ((and (null info-2) info-1) info-1)
      ((and info-1 info-2)
       (if (arg-key-equal info-1 info-2)
           info-1
           (error "[~A] <-> [~A] ~A setting conflict, please check!"
                  info-1 info-2 field-name))))))

(defun combine-args (arg1 arg2)
  (let ((name (combine-arg-info 'name #'arg-spec-name arg1 arg2))
        (long-entry (combine-arg-info 'long-entry #'arg-spec-long-entry arg1 arg2))
        (short-entry (combine-arg-info 'short-entry #'arg-spec-short-entry arg1 arg2))
        (slot-entry (combine-arg-info 'slot-entry #'arg-spec-slot-entry arg1 arg2))
        (arity (combine-arg-info 'arity #'arg-spec-arity arg1 arg2))
        (required (combine-arg-info 'required #'arg-spec-required arg1 arg2))
        (visibility (combine-arg-info 'visibility #'arg-spec-visibility arg1 arg2))
        (default (combine-arg-info 'default #'arg-spec-default arg1 arg2)))
    (let ((the-arg (make-arg-spec
                    :name name :long-entry long-entry
                    :short-entry short-entry :slot-entry slot-entry
                    :arity arity :required required
                    :visibility visibility :default default)))
      (validate-arg-spec the-arg))))

(defun push-arg (arg args-table)
  (let ((name (arg-spec-name arg)))
    (multiple-value-bind (value setp)
        (gethash name args-table)
      (setf (gethash name args-table)
            (if setp
                (combine-args value arg)
                arg))))
  args-table)

(defun continuous-numbers-p (list)
  (if list
      (labels ((cnp (last left)
                 (let ((now (car left)))
                   (cond
                     ((null now) t)
                     ((= now (1+ last)) (cnp now (cdr left)))
                     (t nil)))))
        (cnp (car list) (cdr list)))
      t))

(defun check-args-spec-positions (args-spec)
  (let ((all-positions nil))
    (maphash #'(lambda (key val)
                 (when (eql :position (arg-spec-arity val))
                   (if (numberp key)
                       (push key all-positions)
                       (error "[~S: ~S]~% Why a :POSITION arity'name is not a number?"
                              key val))))
             (args-spec-args-table args-spec))
    (let ((sorted-positions (sort all-positions #'<)))
      (if sorted-positions
          (case (car sorted-positions)
            ((0 1) (if (continuous-numbers-p sorted-positions)
                       args-spec
                       (error "[~A] positions must be continuous!"
                              sorted-positions)))
            (t (error "[~A] positions must start from $0/1."
                      sorted-positions)))
          args-spec))))

(defun check-no-duplicate-entries (name entries seen)
  (dolist (entry entries)
    (when entry
      (multiple-value-bind (other-name foundp)
          (gethash entry seen)
        (when foundp
          (error "Duplicate entry ~S for different args: ~S and ~S."
                 entry other-name name))
        (setf (gethash entry seen) name)))))

(defun check-args-spec-entries (args-spec)
  (let ((seen (make-hash-table :test #'equalp)))
    (maphash
     (lambda (name arg-spec)
       (check-no-duplicate-entries
        name
        (list (arg-spec-slot-entry arg-spec)
              (arg-spec-long-entry arg-spec)
              (arg-spec-short-entry arg-spec))
        seen))
     (args-spec-args-table args-spec))
    args-spec))

(defun validate-args-spec (args-spec)
  (check-args-spec-positions
   (check-args-spec-entries args-spec)))

(defun parse-args-spec (spec-list &optional (command "my-args"))
  (let ((args-table (make-hash-table :test 'equalp)))
    (dolist (arg spec-list)
      (push-arg arg args-table))
    (validate-args-spec
     (make-args-spec :command command :args-table args-table))))
