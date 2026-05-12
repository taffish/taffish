(in-package :han.args)

;;;; ============================================================
;;;; lexer.lisp
;;;; ============================================================

(defstruct arg-token
  kind      ;; :long-option | :short-option | :slot-switch | :value
  text      ;; original token text
  value     ;; normalized value, e.g. "input", "v", "blast", "abc.txt"
  extra     ;; option's value, e.g. "--input=123" => "123"
  position) ;; argv index

(defstruct arg-segment
  slot       ;; string or nil   ; nil 表示默认 slot
  positions) ;; segment 内每一项对应的 token position

(defstruct args-input
  raw-cmd
  raw-argv
  tokens
  segments
  diagnostics)

(defstruct arg-diagnostic
  kind      ;; :error | :warning
  code
  message
  position)

(defun split-once (string split-char)
  (let ((len (length string)))
    (labels ((sb (index)
               (if (>= index len)
                   string
                   (if (char= split-char (char string index))
                       (values (subseq string 0 index)
                               (subseq string (1+ index)))
                       (sb (1+ index))))))
      (sb 0))))

(defun parse-token (string)
  (let ((len (length string)))
    (if (= len 2)
        (let ((c0 (char string 0))
              (ce (char string 1)))
          (if (char= c0 #\-)
              (if (char= ce #\-)
                  ;; --
                  (values :value string nil
                          "Only --, no name, missed?")
                  ;; -?
                  (values :short-option (format nil "~A" ce)))
              (if (char= c0 #\@)
                  (if (char= ce #\:)
                      ;; @:
                      (values :slot-switch nil)
                      ;; @?
                      (values :value string nil
                              "Is it a slot only head '@' but no tail ':'?"))
                  ;; ??
                  (values :value string))))
        (if (> len 2)
            (let ((c0 (char string 0))
                  (c1 (char string 1))
                  (c2 (char string 2))
                  (ce (char string (1- len))))
              (if (char= c0 #\-)
                  (if (char= c1 #\-)
                      (if (char= c2 #\-)
                          ;; ---???
                          (values :value string nil
                                  "Too many ---, type too much by accident?")
                          ;; --???
                          (multiple-value-bind (value extra)
                              (split-once (subseq string 2) #\=)
                            (values :long-option value extra)))
                      ;; -???
                      (multiple-value-bind (value extra)
                          (split-once (subseq string 1) #\=)
                        (values :short-option value extra)))
                  (if (char= c0 #\@)
                      (if (char= ce #\:)
                          ;; @???:
                          (values :slot-switch (subseq string 1 (1- len)))
                          ;; @???
                          (values :value string nil
                                  "Is it a slot only head '@' but no tail ':'?"))
                      ;; ???
                      (values :value string))))
            (if (char= #\- (char string 0))
                ;; -
                (values :value string nil
                        "Only -, no name, missed?")
                ;; ?
                (values :value string))))))

(defun token-kind-eql (kind token)
  (declare (type arg-token token))
  (eql kind (arg-token-kind token)))

(defun make-end-slot-token ()
  (make-arg-token :kind :slot-switch
                  :text "@:"
                  :value nil
                  :extra nil
                  :position nil))

(defun parse-segments (tokens-list)
  (let ((segments-list nil)
        (now-slot  nil)
        (now-positions nil))
    ;; (make-end-slot-token) not work, just end all args.
    (dolist (token (append tokens-list (list (make-end-slot-token))))
      (if (token-kind-eql :slot-switch token)
          (progn
            (push (make-arg-segment :slot now-slot
                                    :positions (nreverse now-positions))
                  segments-list)
            (setf now-slot (arg-token-value token))
            (setf now-positions nil))
          (push (arg-token-position token) now-positions)))
    (nreverse segments-list)))

(defun parse-args-input (&optional (raw-input-args (han.host:argv t))
                           (add-cmd '()))
  (let ((input-args (append add-cmd raw-input-args)))
    (let ((raw-cmd (car input-args))
          (raw-argv (cdr input-args))
          (position 0)
          (tokens nil)
          (segments nil)
          (diagnostics nil))
      (dolist (arg raw-argv)
        (multiple-value-bind (kind value extra warning)
            (parse-token arg)
          (push (make-arg-token :kind kind
                                :text arg
                                :value value
                                :extra (when extra (string-trim " " extra))
                                :position position)
                tokens)
          (when warning
            (push (make-arg-diagnostic :kind :warning
                                       :message warning
                                       :position position)
                  diagnostics)))
        (incf position))
      (setf tokens (nreverse tokens))
      (setf segments (parse-segments tokens))
      (setf tokens (coerce tokens 'vector))
      (make-args-input :raw-cmd raw-cmd
                       :raw-argv raw-argv
                       :tokens tokens
                       :segments segments
                       :diagnostics (nreverse diagnostics)))))
