(in-package :han.os)

;; limit need to be a fun return T/NIL by one arg(reversed-read-list)
(defun %keep-read-by (read-fun stream limit)
  (let ((limit-fun
          (when limit
            (cond
              ((functionp limit) limit)
              ((realp     limit) #'(lambda (l) (< (length l) limit)))
              (t
               (error "limit only support: (NIL :FUNCTION(input: out-list) :REAL-NUMBER)"))))))
    (labels ((krb (out)
               (if (and limit (not (funcall limit-fun out)))
                   (nreverse out)
                   (let* ((eof (gensym))
                          (now (funcall read-fun stream nil eof)))
                     (if (eql now eof)
                         (nreverse out)
                         (krb (push now out)))))))
      (krb nil))))

(defun keep-read (&optional (stream *standard-input*) (limit nil))
  "keep read until limit[list-length or keep-function]"
  (%keep-read-by #'read stream limit))

(defun keep-read-char (&optional (stream *standard-input*) (limit nil))
  "keep read-char until limit[list-length or keep-function]"
  (%keep-read-by #'read-char stream limit))

(defun keep-read-line (&optional (stream *standard-input*) (limit nil))
  "keep read-line until limit[list-length or keep-function]"
  (%keep-read-by #'read-line stream limit))

(defun load-lines (input)
  (cond
    ((streamp input)
     (keep-read-line input))
	    ((or (stringp input)
	         (pathnamep input))
	     (let ((file (han.host:file-exists-p input)))
	       (if file
	           (with-open-file (in file)
	             (load-lines in))
           (error "INPUT file does not exist: ~S" input))))
    (t
     (error "INPUT must be STREAM or PATH(string or pathname), but got: ~S"
            (type-of input)))))

(defun load-string (input)
  (format nil "~{~A~^~%~}" (load-lines input)))
