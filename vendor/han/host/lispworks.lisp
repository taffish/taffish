(in-package :han.host)

;; LispWorks defaults new strings to BASE-CHAR on Unix.  Establish the
;; Unicode-capable application policy before the remaining systems are
;; compiled or loaded, so delivery cannot specialize their strings narrowly.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (lw:set-default-character-element-type 'character))

(defun argv (&optional (keep-first nil))
  (let ((args sys:*line-arguments-list*))
    (if keep-first args (rest args))))

(defun getenv (name)
  (lw:environment-variable name))

(defun quit (&optional (code 0))
  (ignore-errors (finish-output *standard-output*))
  (ignore-errors (finish-output *error-output*))
  (lw:quit :status code))

(defmacro prepare-runtime-io ()
  "Prepare Unicode character policy before configuring live process streams."
  ;; Expand into the delivered entry point. Level-5 delivery does not retain
  ;; the required startup semantics when this setup is hidden behind a call.
  '(progn
     (lw:set-default-character-element-type 'character)
     (hcl:set-console-external-format :utf-8)
     t))

(fli:define-foreign-function (%lispworks-posix-write "write")
    ((file-descriptor :int)
     (buffer (:pointer :void))
     (count :size-t))
  :result-type :ssize-t)

(fli:define-foreign-function (%lispworks-fopen "fopen")
    ((pathname (:pointer :void))
     (mode (:pointer :void)))
  :result-type (:pointer :void))

(fli:define-foreign-function (%lispworks-fileno "fileno")
    ((file (:pointer :void)))
  :result-type :int)

(fli:define-foreign-function (%lispworks-fclose "fclose")
    ((file (:pointer :void)))
  :result-type :int)

(defclass %lispworks-utf8-output-stream
    (stream:fundamental-character-output-stream)
  ((file-descriptor
    :initarg :file-descriptor
    :reader %lispworks-output-file-descriptor)
   (line-column
    :initform 0
    :accessor %lispworks-output-line-column)))

(defun %lispworks-character-substring (string start end)
  (if (and (zerop start)
           (= end (length string)))
      string
      (let ((result (make-array (- end start) :element-type 'character)))
        (loop for source-index from start below end
              for target-index from 0
              do (setf (char result target-index)
                       (char string source-index)))
        result)))

(defun %lispworks-write-utf8-string (file-descriptor string)
  ;; OPEN treats /dev/stdout and /dev/stderr as console streams and can ignore
  ;; the requested external format when the descriptor is a pipe. Encode and
  ;; write bytes directly so redirected, piped, and terminal output agree.
  (fli:with-dynamic-foreign-objects ()
    (multiple-value-bind (pointer character-count byte-count)
        (fli:convert-to-dynamic-foreign-string
         string :external-format :utf-8 :null-terminated-p nil)
      (declare (ignore character-count))
      (let ((cursor (fli:copy-pointer pointer))
            (remaining byte-count))
        (loop while (> remaining 0)
              for written = (%lispworks-posix-write
                             file-descriptor cursor remaining)
              do (unless (> written 0)
                   (error "write(2) failed for file descriptor ~D."
                          file-descriptor))
                 (fli:incf-pointer cursor written)
                 (decf remaining written)))))
  string)

(defun append-utf8-line (path line)
  "Append LINE and one newline to PATH using C append mode and UTF-8 bytes."
  (let* ((file-path (%->pathname path))
         (path-string (namestring file-path))
         (text (%utf8-line-string line)))
    (%ensure-parent-directories-for-file file-path)
    (fli:with-dynamic-foreign-objects ()
      (multiple-value-bind (path-pointer path-characters path-bytes)
          (fli:convert-to-dynamic-foreign-string
           path-string :external-format :utf-8)
        (declare (ignore path-characters path-bytes))
        (multiple-value-bind (mode-pointer mode-characters mode-bytes)
            (fli:convert-to-dynamic-foreign-string
             "ab" :external-format :utf-8)
          (declare (ignore mode-characters mode-bytes))
          (let ((file (%lispworks-fopen path-pointer mode-pointer)))
            (when (fli:null-pointer-p file)
              (error "fopen(3) failed for append path ~A." path-string))
            (unwind-protect
                 (let ((file-descriptor (%lispworks-fileno file)))
                   (when (< file-descriptor 0)
                     (error "fileno(3) failed for append path ~A."
                            path-string))
                   (%lispworks-write-utf8-string file-descriptor text))
              (%lispworks-fclose file))))))
    file-path))

(defmethod stream:stream-write-char
    ((stream %lispworks-utf8-output-stream) character)
  (%lispworks-write-utf8-string
   (%lispworks-output-file-descriptor stream)
   (make-string 1 :element-type 'character :initial-element character))
  (if (char= character #\Newline)
      (setf (%lispworks-output-line-column stream) 0)
      (incf (%lispworks-output-line-column stream)))
  character)

(defmethod stream:stream-write-string
    ((stream %lispworks-utf8-output-stream) string
     &optional (start 0) (end (length string)))
  (let ((text (%lispworks-character-substring string start end)))
    (%lispworks-write-utf8-string
     (%lispworks-output-file-descriptor stream) text)
    (loop for character across text
          do (if (char= character #\Newline)
                 (setf (%lispworks-output-line-column stream) 0)
                 (incf (%lispworks-output-line-column stream)))))
  string)

(defmethod stream:stream-line-column
    ((stream %lispworks-utf8-output-stream))
  (%lispworks-output-line-column stream))

(defmethod stream:stream-finish-output
    ((stream %lispworks-utf8-output-stream))
  (declare (ignore stream))
  nil)

(defmethod stream:stream-force-output
    ((stream %lispworks-utf8-output-stream))
  (declare (ignore stream))
  nil)

(defmethod stream:stream-clear-output
    ((stream %lispworks-utf8-output-stream))
  (declare (ignore stream))
  nil)

(defun %lispworks-runtime-output (file-descriptor)
  (make-instance '%lispworks-utf8-output-stream
                 :file-descriptor file-descriptor))

(defun configure-runtime-io ()
  "Configure portable command-line character I/O for this host."
  ;; Reassert the saved policy before constructing the live process streams.
  (lw:set-default-character-element-type 'character)
  (hcl:set-console-external-format :utf-8)
  (let ((standard-output (%lispworks-runtime-output 1))
        (error-output (%lispworks-runtime-output 2)))
    (setf *standard-output* standard-output
          *error-output* error-output
          *trace-output* error-output))
  t)

(fli:define-foreign-function (%lispworks-getpid "getpid") ()
  :result-type :int)

(defun current-process-id ()
  "Return the operating-system process ID of the current Lisp process."
  (%lispworks-getpid))

(fli:define-foreign-function (%lispworks-isatty "isatty")
    ((file-descriptor :int))
  :result-type :int)

(defmethod interactive-stream-p ((stream %lispworks-utf8-output-stream))
  ;; LispWorks' fundamental-stream default is NIL, even for a live console fd.
  (and (open-stream-p stream)
       (= (%lispworks-isatty (%lispworks-output-file-descriptor stream)) 1)))

(defun standard-input-terminal-p ()
  "Return true when the process standard input file descriptor is a terminal."
  (= (%lispworks-isatty 0) 1))

(defun standard-error-terminal-p ()
  "Query process stderr (fd 2), not *ERROR-OUTPUT*, without reading or writing."
  (= (%lispworks-isatty 2) 1))

(defun %lispworks-command-designator (program arguments)
  "LispWorks run-shell-command accepts a string, list or vector command."
  (if arguments
      (cons program arguments)
      program))

(defun %lispworks-sync-command-designator (command)
  (cond
    ((stringp command) command)
    ((and (consp command)
          (stringp (car command)))
     command)
    (t
     (error "COMMAND must be a string or a non-empty string list: ~S"
            command))))

(defun run-program-sync
    (command &key input (output :string) (error-output :string)
                  (ignore-error-status t))
  "Run external COMMAND synchronously and return stdout, stderr, and exit code."
  (let ((temp-files nil))
    (unwind-protect
         (multiple-value-bind (run-input input-temp-files)
             (%prepare-sync-input input temp-files)
           (setf temp-files input-temp-files)
           (multiple-value-bind (run-output output-capture output-temp-files)
               (%prepare-sync-output output temp-files "han-host-output")
             (setf temp-files output-temp-files)
             (multiple-value-bind (run-error error-capture error-temp-files)
                 (%prepare-sync-output error-output temp-files
                                       "han-host-error" *error-output*)
               (setf temp-files error-temp-files)
               (multiple-value-bind (exit-code signal-code)
                   (system:run-shell-command
                    (%lispworks-sync-command-designator command)
                    :wait t
                    :input run-input
                    :output run-output
                    :error-output run-error)
                 (let ((code (%signal-exit-code exit-code signal-code))
                       (stdout (%finalize-sync-output output-capture))
                       (stderr (%finalize-sync-output error-capture)))
                   (%check-sync-exit-code command code ignore-error-status)
                   (values stdout stderr code))))))
      (%cleanup-sync-temp-files temp-files))))

;; Start an external program and return a unified host process handle
(defun run-program (program
                    &key
                      (arguments '())
                      input
                      (directory nil dir-p)
                      (environment nil env-p))
  (when (null (file-exists-p program))
    (error "(Need file path) Program file does not exist: ~A" program))
  (let ((command (%lispworks-command-designator program arguments)))
    (multiple-value-bind (out-stream err-stream pid)
        (apply #'system:run-shell-command
               command
               (append (list :wait nil
                             :input input
                             :output :stream
                             :error-output :stream
                             :save-exit-status t)
                       (when dir-p
                         (list :current-directory directory))
                       (when env-p
                         (list :environment environment))))
      (make-host-process
       :backend :lispworks
       :native-handle out-stream
       :pid pid
       :input-stream input
       :output-stream out-stream
       :error-stream err-stream))))

;; Return the current status(:running/:exited/:unknown) of the process
(defun process-status (process)
  (if (null (process-exit-code process))
      :running
      :exited))

;; Return an integer exit code for exited process, or return NIL
(defun process-exit-code (process)
  (or (host-process-exit-code process)
      (let ((status-stream (host-process-native-handle process)))
        (when status-stream
          (multiple-value-bind (exit-code signal-code)
              (system:pipe-exit-status status-stream :wait nil)
            (let ((code (%signal-exit-code exit-code signal-code)))
              (when code
                (setf (host-process-exit-code process) code
                      (host-process-signal-code process) signal-code))
              code))))))

;; Block until the process ends and return the original process handle
(defun process-wait (process)
  (let ((status-stream (host-process-native-handle process)))
    (when status-stream
      (multiple-value-bind (exit-code signal-code)
          (system:pipe-exit-status status-stream :wait t)
        (setf (host-process-exit-code process)
              (%signal-exit-code exit-code signal-code)
              (host-process-signal-code process)
              signal-code))))
  process)

;; Turn off(not kill) local process-related flows/handles
(defun process-close (process)
  (%close-stream-safely (host-process-output-stream process))
  (%close-stream-safely (host-process-error-stream process))
  nil)
