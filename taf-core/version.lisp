(in-package :taf.core)

;;;; Shared internal version precedence. Identity matching remains exact.

(defun %version-parts (text separator)
  (loop for start = 0 then (1+ end)
        for end = (position separator text :start start)
        collect (subseq text start end)
        while end))

(defun %version-digits-p (text)
  (and (plusp (length text)) (every #'digit-char-p text)))

(defun %version-word-p (text)
  (and (plusp (length text))
       (every (lambda (c)
                (or (find c "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
                    (char= c #\-)))
              text)))

(defun %version-structured (text)
  (let* ((plus (position #\+ text))
         (base (subseq text 0 plus))
         (dash (position #\- base))
         (core (%version-parts (subseq base 0 dash) #\.))
         (pre (and dash (%version-parts (subseq base (1+ dash)) #\.))))
    (when (and (every #'%version-digits-p core)
               (or (null pre) (every #'%version-word-p pre))
               (or (null plus)
                   (every #'%version-word-p
                          (%version-parts (subseq text (1+ plus)) #\.))))
      (list (mapcar #'parse-integer core) pre))))

(defun %version-natural-tokens (text)
  (loop for start = 0 then end
        while (< start (length text))
        for numeric = (not (null (digit-char-p (char text start))))
        for end = (or (position-if
                       (lambda (c) (not (eql numeric (not (null (digit-char-p c))))))
                       text :start start)
                      (length text))
        for token = (subseq text start end)
        collect (if numeric (parse-integer token) token)))

(defun %version-natural-order (a b)
  (loop for x on a for y on b
        for left = (car x) for right = (car y)
        do (cond
             ((and (integerp left) (integerp right))
              (unless (= left right)
                (return-from %version-natural-order (if (< left right) -1 1))))
             ((integerp left) (return-from %version-natural-order -1))
             ((integerp right) (return-from %version-natural-order 1))
             ((not (string= left right))
              (return-from %version-natural-order (if (string< left right) -1 1)))))
  (cond ((< (length a) (length b)) -1)
        ((> (length a) (length b)) 1)
        (t 0)))

(defun %version-number-order (a b)
  (loop while (or a b)
        for left = (or (pop a) 0) for right = (or (pop b) 0)
        unless (= left right) do (return-from %version-number-order
                                   (if (< left right) -1 1)))
  0)

(defun %version-prerelease-order (a b)
  (cond
    ((and (null a) (null b)) 0)
    ((null a) 1)
    ((null b) -1)
    (t
     (loop for left in a for right in b
           for order = (cond
                         ((and (%version-digits-p left) (%version-digits-p right))
                          (%version-number-order (list (parse-integer left))
                                                 (list (parse-integer right))))
                         ((%version-digits-p left) -1)
                         ((%version-digits-p right) 1)
                         (t (%version-natural-order (%version-natural-tokens left)
                                                    (%version-natural-tokens right))))
           unless (zerop order) do (return-from %version-prerelease-order order))
     (cond ((< (length a) (length b)) -1)
           ((> (length a) (length b)) 1)
           (t 0)))))

(defun %compare-versions (a b)
  "Return precedence (-1/0/1) and whether it is reliable for maintenance.
Dotted numeric cores support prereleases and ignored build metadata. Opaque
formats use natural ordering; only an identical nonnumeric shape is reliable."
  (let ((left (%version-structured a))
        (right (%version-structured b)))
    (cond
      ((string= a b) (values 0 t))
      ((and left right)
       (let ((core (%version-number-order (first left) (first right))))
         (values (if (zerop core)
                     (%version-prerelease-order (second left) (second right))
                     core)
                 t)))
      ;; Keep a total display order across families, but never infer an upgrade
      ;; from this family ordering. Pairwise lexical fallback is not transitive.
      (left (values 1 nil))
      (right (values -1 nil))
      (t
       (let* ((x (%version-natural-tokens a))
              (y (%version-natural-tokens b))
              (shape-x (mapcar (lambda (part) (if (integerp part) :number part)) x))
              (shape-y (mapcar (lambda (part) (if (integerp part) :number part)) y)))
         (values (%version-natural-order x y)
                 (and (some #'integerp x) (equal shape-x shape-y))))))))

(defun %compare-version-release (version release other-version other-release)
  (multiple-value-bind (order reliable-p) (%compare-versions version other-version)
    (values (if (zerop order)
                (%version-number-order (list release) (list other-release))
                order)
            reliable-p)))

(defun %version-id-info (version-id)
  (when (and (stringp version-id) (plusp (length version-id)))
    (let ((split (search "-r" version-id :from-end t)))
      (when (and split (plusp split))
        (let ((release (subseq version-id (+ split 2))))
          (when (and (%version-digits-p release) (plusp (parse-integer release)))
            (list :version (subseq version-id 0 split)
                  :release (parse-integer release))))))))

(defun %compare-version-ids (a b)
  (let ((left (%version-id-info a)) (right (%version-id-info b)))
    (cond
      ((string= a b) (values 0 t))
      ((and left right)
       (%compare-version-release (getf left :version) (getf left :release)
                                 (getf right :version) (getf right :release)))
      (left (values 1 nil))
      (right (values -1 nil))
      (t (values (%version-natural-order (%version-natural-tokens a)
                                         (%version-natural-tokens b))
                 nil)))))
