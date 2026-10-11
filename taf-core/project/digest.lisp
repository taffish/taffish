(in-package :taf.core)

;;;; ============================================================
;;;; project / digest.lisp
;;;; ============================================================

(defparameter *project-sha256-round-constants*
  #(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5
    #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3
    #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc
    #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7
    #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13
    #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3
    #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5
    #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208
    #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

(defstruct (%project-sha256-context
            (:constructor %make-project-sha256-context/internal))
  (state (vector #x6a09e667 #xbb67ae85 #x3c6ef372 #xa54ff53a
                 #x510e527f #x9b05688c #x1f83d9ab #x5be0cd19))
  (buffer (make-array 64 :element-type '(unsigned-byte 8)
                          :initial-element 0))
  (buffer-length 0 :type integer)
  (byte-count 0 :type integer))

(defun %project-sha256-u32 (value)
  (logand value #xffffffff))

(defun %project-sha256-rotr32 (value count)
  (%project-sha256-u32
   (logior (ash value (- count))
           (ash value (- 32 count)))))

(defun %project-sha256-small-sigma-0 (value)
  (logxor (%project-sha256-rotr32 value 7)
          (%project-sha256-rotr32 value 18)
          (ash value -3)))

(defun %project-sha256-small-sigma-1 (value)
  (logxor (%project-sha256-rotr32 value 17)
          (%project-sha256-rotr32 value 19)
          (ash value -10)))

(defun %project-sha256-big-sigma-0 (value)
  (logxor (%project-sha256-rotr32 value 2)
          (%project-sha256-rotr32 value 13)
          (%project-sha256-rotr32 value 22)))

(defun %project-sha256-big-sigma-1 (value)
  (logxor (%project-sha256-rotr32 value 6)
          (%project-sha256-rotr32 value 11)
          (%project-sha256-rotr32 value 25)))

(defun %project-sha256-choice (x y z)
  (logxor (logand x y)
          (logand (lognot x) z)))

(defun %project-sha256-majority (x y z)
  (logxor (logand x y)
          (logand x z)
          (logand y z)))

(defun %project-sha256-block-word (block offset)
  (%project-sha256-u32
   (logior (ash (aref block offset) 24)
           (ash (aref block (+ offset 1)) 16)
           (ash (aref block (+ offset 2)) 8)
           (aref block (+ offset 3)))))

(defun %project-sha256-compress (context)
  (let* ((state (%project-sha256-context-state context))
         (block (%project-sha256-context-buffer context))
         (words (make-array 64 :initial-element 0)))
    (dotimes (index 16)
      (setf (aref words index)
            (%project-sha256-block-word block (* index 4))))
    (loop for index from 16 below 64 do
      (setf (aref words index)
            (%project-sha256-u32
             (+ (%project-sha256-small-sigma-1
                 (aref words (- index 2)))
                (aref words (- index 7))
                (%project-sha256-small-sigma-0
                 (aref words (- index 15)))
                (aref words (- index 16))))))
    (let ((a (aref state 0)) (b (aref state 1))
          (c (aref state 2)) (d (aref state 3))
          (e (aref state 4)) (f (aref state 5))
          (g (aref state 6)) (h (aref state 7)))
      (dotimes (index 64)
        (let* ((temp1
                 (%project-sha256-u32
                  (+ h
                     (%project-sha256-big-sigma-1 e)
                     (%project-sha256-choice e f g)
                     (aref *project-sha256-round-constants* index)
                     (aref words index))))
               (temp2
                 (%project-sha256-u32
                  (+ (%project-sha256-big-sigma-0 a)
                     (%project-sha256-majority a b c)))))
          (setf h g
                g f
                f e
                e (%project-sha256-u32 (+ d temp1))
                d c
                c b
                b a
                a (%project-sha256-u32 (+ temp1 temp2)))))
      (setf (aref state 0) (%project-sha256-u32 (+ (aref state 0) a))
            (aref state 1) (%project-sha256-u32 (+ (aref state 1) b))
            (aref state 2) (%project-sha256-u32 (+ (aref state 2) c))
            (aref state 3) (%project-sha256-u32 (+ (aref state 3) d))
            (aref state 4) (%project-sha256-u32 (+ (aref state 4) e))
            (aref state 5) (%project-sha256-u32 (+ (aref state 5) f))
            (aref state 6) (%project-sha256-u32 (+ (aref state 6) g))
            (aref state 7) (%project-sha256-u32 (+ (aref state 7) h))))))

(defun %project-sha256-update-byte (context byte &optional (count-p t))
  (let ((length (%project-sha256-context-buffer-length context)))
    (setf (aref (%project-sha256-context-buffer context) length) byte
          (%project-sha256-context-buffer-length context) (1+ length))
    (when count-p
      (incf (%project-sha256-context-byte-count context)))
    (when (= (%project-sha256-context-buffer-length context) 64)
      (%project-sha256-compress context)
      (setf (%project-sha256-context-buffer-length context) 0)))
  context)

(defun %project-sha256-update-octets (context octets &optional (end (length octets)))
  (loop for index from 0 below end do
    (%project-sha256-update-byte context (aref octets index)))
  context)

(declaim (notinline %project-unicode-code-p))

(defun %project-unicode-code-p (code)
  (<= code #x10ffff))

(defun %project-sha256-update-string (context string)
  (labels ((emit (&rest bytes)
             (dolist (byte bytes)
               (%project-sha256-update-byte context byte))))
    (loop for char across string
          for code = (char-code char)
          do
             (cond
               ((<= code #x7f)
                (emit code))
               ((<= code #x7ff)
                (emit (logior #xc0 (ash code -6))
                      (logior #x80 (logand code #x3f))))
               ((<= code #xffff)
                (emit (logior #xe0 (ash code -12))
                      (logior #x80 (logand (ash code -6) #x3f))
                      (logior #x80 (logand code #x3f))))
               ((%project-unicode-code-p code)
                (emit (logior #xf0 (ash code -18))
                      (logior #x80 (logand (ash code -12) #x3f))
                      (logior #x80 (logand (ash code -6) #x3f))
                      (logior #x80 (logand code #x3f))))
               (t
                (%project-error "publish-utf8"
                                :value (%project-repr char))))))
  context)

(defun %project-sha256-finalize (context)
  (let ((bit-length
          (logand #xffffffffffffffff
                  (* 8 (%project-sha256-context-byte-count context)))))
    (%project-sha256-update-byte context #x80 nil)
    (loop until (= (%project-sha256-context-buffer-length context) 56) do
      (%project-sha256-update-byte context 0 nil))
    (loop for shift from 56 downto 0 by 8 do
      (%project-sha256-update-byte
       context (logand #xff (ash bit-length (- shift))) nil)))
  (let ((state (%project-sha256-context-state context)))
    (string-downcase
     (format nil "~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X"
             (aref state 0) (aref state 1) (aref state 2) (aref state 3)
             (aref state 4) (aref state 5) (aref state 6) (aref state 7)))))

(defun %project-sha256-string (string)
  (%project-sha256-finalize
   (%project-sha256-update-string
    (%make-project-sha256-context/internal) string)))

(defun %project-sha256-file (path)
  (let ((context (%make-project-sha256-context/internal))
        (buffer (make-array 8192 :element-type '(unsigned-byte 8))))
    (with-open-file (in path :direction :input
                             :element-type '(unsigned-byte 8))
      (loop for end = (read-sequence buffer in)
            while (> end 0)
            do (%project-sha256-update-octets context buffer end)))
    (%project-sha256-finalize context)))
