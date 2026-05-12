(in-package :han.source)

(defstruct (char-source (:constructor %make-char-source))
  id
  string
  length
  (index  0)
  (line   1)
  (column 1))

(defun make-char-source (string)
  (let ((s (coerce string 'simple-string)))
    (%make-char-source :id (gensym) :string s :length (length s))))

(defstruct (char-source-mark (:constructor %make-char-source-mark))
  from
  index
  line
  column)

(defun make-source-mark (src)
  (declare (type char-source src))
  (%make-char-source-mark
   :from   (char-source-id     src)
   :index  (char-source-index  src)
   :line   (char-source-line   src)
   :column (char-source-column src)))

(defun source-mark-from-source-p (mark src &optional (report-error nil))
  (declare (type char-source-mark mark)
           (type char-source      src))
  (let* ((mark-id (char-source-mark-from mark))
         (src-id  (char-source-id        src))
         (is-from (eql mark-id src-id)))
    (when (and report-error (not is-from))
      (error "Can't reset, because the MARK[~A] is not from the SOURCE[~A]."
             mark-id src-id))
    is-from))

(defun source-location (src)
  (cond
    ((char-source-p src)
     (values (char-source-index  src)
             (char-source-line   src)
             (char-source-column src)))
    ((char-source-mark-p src)
     (values (char-source-mark-index  src)
             (char-source-mark-line   src)
             (char-source-mark-column src)))
    (t
     (error "SRC must be either CHAR-SOURCE or CHAR-SOURCE-MARK."))))

(defun source-reset (src mark)
  (declare (type char-source-mark mark)
           (type char-source      src))
  (when (source-mark-from-source-p mark src t)
    (setf (char-source-index  src) (char-source-mark-index  mark)
          (char-source-line   src) (char-source-mark-line   mark)
          (char-source-column src) (char-source-mark-column mark)))
  src)

(defstruct (char-source-span (:constructor %make-char-source-span))
  from
  start
  end)

(defun make-source-span (start end)
  (declare (type char-source-mark start end))
  (let ((start-from  (char-source-mark-from start))
        (end-from    (char-source-mark-from end))
        (start-index (char-source-mark-index start))
        (end-index   (char-source-mark-index end)))
    (cond
      ((not (eql start-from end-from))
       (error "START-MARK[~A] and END-MARK[~A] must come from the same SOURCE."
              start-from end-from))
      ((< end-index start-index)
       (error "START index ~A must be <= END index ~A."
              start-index end-index))
      (t
       (%make-char-source-span :from  start-from
                               :start (char-source-mark-index start)
                               :end   (char-source-mark-index end))))))

(defun source-span-from-source-p (span src &optional (report-error nil))
  (declare (type char-source-span span)
           (type char-source      src))
  (let* ((span-id (char-source-span-from span))
         (src-id  (char-source-id        src))
         (is-from (eql span-id src-id)))
    (when (and report-error (not is-from))
      (error "Can't reset, because the SPAN[~A] is not from the SOURCE[~A]."
             span-id src-id))
    is-from))

(defun source-same-origin-p (target &rest else)
  (labels ((get-id (s)
             (cond
               ((char-source-p      s) (char-source-id        s))
               ((char-source-mark-p s) (char-source-mark-from s))
               ((char-source-span-p s) (char-source-span-from s))
               (t (error "TARGET must be either CHAR-SOURCE/SOURCE-MARK/SOURCE-SPAN.")))))
    (let ((id (get-id target)))
      (dolist (i else)
        (unless (eql id (get-id i))
          (return-from source-same-origin-p nil)))
      t)))

(defun source-slice (src start &optional (end (char-source-index src)))
  (declare (type char-source src))
  (labels ((sure-index (input)
             (cond
               ((and (integerp input) (>= input 0)) input)
               ((and (char-source-mark-p input)
                     (source-mark-from-source-p input src t))
                (char-source-mark-index input))
               (t (error "START and END must be either a non-negative integer or a CHAR-SOURCE-MARK.")))))
    (subseq (char-source-string src)
            (sure-index start) (sure-index end))))

(defun source-slice-by-span (src span)
  (declare (type char-source src)
           (type char-source-span span))
  (when (source-span-from-source-p span src t)
    (subseq (char-source-string src)
            (char-source-span-start span)
            (char-source-span-end span))))

(defun source-eof-p (src)
  (declare (type char-source src))
  (>= (char-source-index  src)
      (char-source-length src)))

(defun source-peek-char (src)
  (declare (type char-source src))
  (unless (source-eof-p src)
    (schar (char-source-string src)
           (char-source-index  src))))

(defun source-peek-string (src n)
  (declare (type char-source src))
  (let ((source-index (char-source-index  src)))
    (subseq (char-source-string src)
            source-index
            (min (+ source-index n) (char-source-length src)))))

(defun source-next-char (src)
  (declare (type char-source src))
  (unless (source-eof-p src)
    (let ((out (schar (char-source-string src)
                      (char-source-index src))))
      (incf (char-source-index src))
      (if (char= out #\Newline)
          (progn
            (incf (char-source-line src))
            (setf (char-source-column src) 1))
          (incf (char-source-column src)))
      out)))

(defun source-match-char-p (src ch)
  (declare (type char-source src))
  (let ((c (source-peek-char src)))
    (and c (char= c ch))))

(defun source-match-string-p (src target)
  (declare (type char-source src))
  (let* ((target-len   (length target))
         (source-len   (char-source-length src))
         (source-index (char-source-index src)))
    (when (<= (+ source-index target-len) source-len)
      (loop for i from 0 below target-len
            always (char=
                    (schar (char-source-string src) (+ source-index i))
                    (char target i))))))

(defun source-consume-char-if (src ch)
  (declare (type char-source src))
  (when (source-match-char-p src ch)
    (source-next-char src)
    ch))

(defun source-advance-n (src n)
  (declare (type char-source src))
  (dotimes (ignored n)
    (if (source-eof-p src)
        (return-from source-advance-n src)
        (source-next-char src)))
  src)

(defun source-consume-string-if (src str)
  (declare (type char-source src))
  (when (source-match-string-p src str)
    (source-advance-n src (length str))
    str))

(defun source-skip-while (src predicate)
  (declare (type char-source src))
  (loop while (let ((c (source-peek-char src)))
                (and c (funcall predicate c)))
        do (source-next-char src))
  src)

(defun source-read-while (src predicate)
  (declare (type char-source src))
  (with-output-to-string (out)
    (loop while (let ((c (source-peek-char src)))
                  (and c (funcall predicate c)))
          do (write-char (source-next-char src) out))))
