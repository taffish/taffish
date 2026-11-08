(in-package :taf.core)

;;;; ============================================================
;;;; system / history.lisp
;;;; ============================================================

(defparameter *taffish-history-file-name*
  "history.jsonl")

(defvar *history-id-counter* 0)

(defun %history-format-character-string (control &rest arguments)
  "Format history data into a full CHARACTER string."
  (with-output-to-string (out nil :element-type 'character)
    (apply #'format out control arguments)))

(defun %history-file (&key user-home)
  (han.path:join-path (%taffish-user-home user-home)
                      "logs"
                      *taffish-history-file-name*))

(defun %history-timestamp ()
  (multiple-value-bind (second minute hour date month year)
      (decode-universal-time (get-universal-time) 0)
    (%history-format-character-string "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month date hour minute second)))

(defun %history-id (&optional (timestamp (%history-timestamp)))
  (let ((compact (remove #\: (remove #\- timestamp))))
    (%history-format-character-string
     "~A-~36R-~36R"
     (subseq compact 0 (min (length compact) 15))
     (han.host:current-process-id)
     (incf *history-id-counter*))))

(defun %history-key-string (key)
  (string-downcase
   (substitute #\_ #\-
               (etypecase key
                 (keyword (symbol-name key))
                 (symbol (symbol-name key))
                 (string key)))))

(defun %history-json-escape (string)
  (with-output-to-string (out nil :element-type 'character)
    (loop for char across (princ-to-string string) do
      (case char
        (#\" (write-string "\\\"" out))
        (#\\ (write-string "\\\\" out))
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (t (if (< (char-code char) 32)
               (format out "\\u~4,'0X" (char-code char))
               (write-char char out)))))))

(defun %history-plist-p (value)
  (and (listp value)
       (evenp (length value))
       (loop for key in value by #'cddr
             always (or (keywordp key) (symbolp key)))))

(defun %history-json-value (value)
  (cond
    ((eql value t) "true")
    ((null value) "null")
    ((stringp value)
     (%history-format-character-string "\"~A\"" (%history-json-escape value)))
    ((vectorp value)
     (%history-format-character-string "[~{~A~^,~}]"
                                      (map 'list #'%history-json-value value)))
    ((or (integerp value) (floatp value))
     (princ-to-string value))
    ((or (keywordp value) (symbolp value))
     (%history-format-character-string "\"~A\"" (%history-key-string value)))
    ((%history-plist-p value)
     (%history-json-object value))
    ((listp value)
     (%history-format-character-string "[~{~A~^,~}]"
             (mapcar #'%history-json-value value)))
    (t
     (%history-format-character-string "\"~A\"" (%history-json-escape (princ-to-string value))))))

(defun %history-json-object (plist)
  (let ((pairs nil))
    (loop for (key value) on plist by #'cddr do
      (push (%history-format-character-string "\"~A\":~A"
                    (%history-key-string key)
                    (%history-json-value value))
            pairs))
    (%history-format-character-string "{~{~A~^,~}}" (nreverse pairs))))

(defun %history-project-fields (project)
  (when project
    (list :project-name (getf project :name)
          :project-kind (getf project :kind)
          :project-version (getf project :version)
          :project-release (getf project :release)
          :project-command (getf project :command-name)
          :project-root (getf project :root-dir)
          :project-main (getf project :main-path)
          :repository-url (getf project :repository-url)
          :container-image (getf project :container-image))))

(defun %history-clean-plist (plist)
  (let ((out nil))
    (loop for (key value) on plist by #'cddr do
      (unless (null value)
        (push key out)
        (push value out)))
    (nreverse out)))

(defun %call-with-history-lock (file function)
  ;; --clear can unlink FILE. The stable sidecar survives clear and recreation.
  (let ((lock (etypecase file
                (string (concatenate 'string file ".lock"))
                (pathname (pathname (concatenate 'string (namestring file) ".lock"))))))
    (han.host:call-with-exclusive-file-lock lock function)))

(defun %history-append-line (file line)
  (%call-with-history-lock file (lambda () (han.host:append-utf8-line file line))))

(defun %read-wrapper-history-fields (stream)
  ;; EOF is only valid between fields. A NUL by itself denotes an empty field.
  (loop while (peek-char nil stream nil nil)
        collect (with-output-to-string (out nil :element-type 'character)
                  (loop for char = (read-char stream)
                        until (zerop (char-code char))
                        do (write-char char out)))))

(defun system-record-wrapper-history (file stream)
  "Read the generated wrapper's private field stream and append one exec event."
  (destructuring-bind (pid cwd command name kind version release project-command
                       root main repository image status exit stage argc &rest args)
      (%read-wrapper-history-fields stream)
    (unless (= (parse-integer argc) (length args))
      (error "Incomplete wrapper history arguments."))
    (let* ((time (%history-timestamp))
           (id (concatenate 'string (remove-if (lambda (c) (find c "-:Z")) time)
                            "-" pid))
           (event (list :id id :time time :event "exec" :status status
                        :command command :args (coerce args 'simple-vector)
                        :cwd cwd :exit-code (parse-integer exit)
                        :project-name name :project-kind kind :project-version version
                        :project-release release :project-command project-command
                        :project-root root :project-main main
                        :repository-url (unless (zerop (length repository)) repository)
                        :container-image (unless (zerop (length image)) image)
                        :stage stage :snapshot-root root :history-backend "shell-wrapper")))
      (%history-append-line file (%history-json-object event)))))

(defun system-record-history-event
    (&key event
          status
          project
          command
          args
          cwd
          backend
          exit-code
          extra
          taf-version
          user-home
          (safe t))
  (labels ((record ()
             (let* ((time (%history-timestamp))
                    (event-plist
                      (%history-clean-plist
                       (append
                        (list :id (%history-id time)
                              :time time
                              :event event
                              :status status
                              :command command
                              :args args
                              :cwd cwd
                              :backend backend
                              :exit-code exit-code
                              :taf-version taf-version)
                        (%history-project-fields project)
                        extra)))
                    (file (%history-file :user-home user-home))
                    (line (%history-json-object event-plist)))
               (%history-append-line file line)
               (list :file (han.path:->namestring file)
                     :event event-plist
                     :line line))))
    (if safe
        (handler-case (record)
          (error () nil))
        (record))))

(defun %history-read-lines (file)
  (if (han.path:file-exists-p file)
      (han.os:load-lines file)
      nil))

(defun %history-take-last (lines n)
  (if (or (null n) (>= n (length lines)))
      lines
      (nthcdr (- (length lines) n) lines)))

(defun %history-json-string-field (line key)
  (let* ((needle (%history-format-character-string "\"~A\":" key))
         (start (search needle line :test #'char=)))
    (when start
      (let* ((value-start (+ start (length needle)))
             (len (length line)))
        (cond
          ((and (< value-start len)
                (char= #\" (char line value-start)))
           (with-output-to-string (out nil :element-type 'character)
             (loop with escaped-p = nil
                   for i from (1+ value-start) below len
                   for char = (char line i)
                   do (cond
                        (escaped-p
                         (write-char char out)
                         (setf escaped-p nil))
                        ((char= char #\\)
                         (setf escaped-p t))
                        ((char= char #\")
                         (return))
                        (t
                         (write-char char out))))))
          (t
           (let ((end (or (position #\, line :start value-start)
                          (position #\} line :start value-start)
                          len)))
             (subseq line value-start end))))))))

(defun %history-id-line-p (id line)
  (and id
       (string= id (or (%history-json-string-field line "id") ""))))

(defun %history-line-summary (line)
  (let* ((time (%history-json-string-field line "time"))
         (event (%history-json-string-field line "event"))
         (status (%history-json-string-field line "status"))
         (project (%history-json-string-field line "project_name"))
         (version (%history-json-string-field line "project_version"))
         (release (%history-json-string-field line "project_release"))
         (exit-code (%history-json-string-field line "exit_code"))
         (id (%history-json-string-field line "id")))
    (%history-format-character-string "~@[~A ~]~@[~A ~]~@[~A~]~@[ ~A~]~@[ v~A~]~@[-r~A~]~@[ exit=~A~]~@[ id=~A~]"
            time event status project version release exit-code id)))

(defun %print-history-lines (lines file json-p)
  (if json-p
      (dolist (line lines)
        (format t "~A~%" line))
      (progn
        (format t "~A~%" (%history-message "header"))
        (format t "  ~A : ~A~%"
                (%history-message "label.file")
                (han.path:->namestring file))
        (if (null lines)
            (format t "~A~%" (%history-message "empty"))
            (progn
              (format t "~%~A~%" (%history-message "events"))
              (dolist (line lines)
                (format t "  ~A~%" (%history-line-summary line))))))))

(defun system-history (&key
                         (last 20)
                         id
                         json-p
                         path-p
                         clear-p
                         user-home
                         (verbose t))
  (let ((file (%history-file :user-home user-home)))
    (cond
      (path-p
       (when verbose
         (format t "~A~%" (han.path:->namestring file)))
       (list :file (han.path:->namestring file)
             :path-p t))
      (clear-p
       (let ((existed-p
               (and (han.path:file-exists-p file)
                    (%call-with-history-lock
                     file (lambda () (when (han.path:file-exists-p file)
                                       (delete-file file)
                                       t))))))
         (when verbose
           (format t "~A~%"
                   (%history-message
                    "clear.result"
                    :state (%history-message
                            (if existed-p
                                "clear.cleared"
                                "clear.not-found"))
                    :path (han.path:->namestring file))))
         (list :file (han.path:->namestring file)
               :cleared-p existed-p)))
      (t
       (let* ((all-lines (%history-read-lines file))
              (matched-lines (if id
                                 (remove-if-not
                                  (lambda (line)
                                    (%history-id-line-p id line))
                                  all-lines)
                                 all-lines))
              (lines (%history-take-last matched-lines last)))
         (when verbose
           (%print-history-lines lines file json-p))
         (list :file (han.path:->namestring file)
               :lines lines
               :count (length lines)
               :total (length all-lines)
               :id id))))))
