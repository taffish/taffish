(require :asdf)

(defun %subdir (base &rest parts)
  (merge-pathnames
   (make-pathname :directory (append '(:relative) parts))
   base))

(defun %load-taffish-argv ()
  #+sbcl
  sb-ext:*posix-argv*
  #+lispworks
  sys:*line-arguments-list*
  #-(or sbcl lispworks)
  nil)

(defun %load-taffish-quit (&optional (code 0))
  #+sbcl
  (sb-ext:exit :code code)
  #+lispworks
  (lw:quit :status code)
  #-(or sbcl lispworks)
  (declare (ignore code)))

(defun %load-taffish-help-option-p (arg)
  (member arg '("-h" "--help" "help") :test #'string-equal))

(defun %load-taffish-dispatch-option-p (arg)
  (or (%load-taffish-help-option-p arg)
      (member arg
              '("--compile"
                "--compile-taffish"
                "--compile-taf"
                "--compile-taffish-mcp"
                "--compile-mcp"
                "--taffish"
                "--taf"
                "--taffish-mcp"
                "--mcp")
              :test #'string-equal)))

(defun %split-at-load-taffish-dispatch-option (argv)
  (loop for tail on argv
        for arg = (car tail)
        when (%load-taffish-dispatch-option-p arg)
          do (return (values arg (cdr tail)))))

(defun %get-load-taffish-help-string ()
  "Usage:
  sbcl --load load-taffish.lisp [-h | help]
  sbcl --load load-taffish.lisp -- --help
  sbcl --load load-taffish.lisp --compile
  sbcl --load load-taffish.lisp --compile-taffish
  sbcl --load load-taffish.lisp --compile-taf
  sbcl --load load-taffish.lisp --compile-taffish-mcp
  sbcl --load load-taffish.lisp --taffish [TAFFISH-ARGS...]
  sbcl --load load-taffish.lisp --taf [TAF-ARGS...]
  sbcl --load load-taffish.lisp --taffish-mcp [MCP-ARGS...]
  lispworks -build load-taffish.lisp --compile
  lispworks -build load-taffish.lisp --compile-taffish
  lispworks -build load-taffish.lisp --compile-taf
  lispworks -build load-taffish.lisp --compile-taffish-mcp
  lispworks -build load-taffish.lisp --taffish [TAFFISH-ARGS...]
  lispworks -build load-taffish.lisp --taf [TAF-ARGS...]
  lispworks -build load-taffish.lisp --taffish-mcp [MCP-ARGS...]

Development loader for TAFFISH.

Options:
  -h, --help, help       Show this loader help
  --compile              Build target/taffish, target/taf and target/taffish-mcp
  --compile-taffish      Build target/taffish only
  --compile-taf          Build target/taf only
  --compile-taffish-mcp  Build target/taffish-mcp only
  --compile-mcp          Alias for --compile-taffish-mcp
  --taffish              Run taffish-cli with following args
  --taf                  Run taf-cli with following args
  --taffish-mcp          Run taffish-mcp with following args
  --mcp                  Alias for --taffish-mcp

SBCL note:
  --help is reserved by SBCL, so use -h directly, or pass --help after --.

LispWorks note:
  --compile starts two child delivery processes because DELIVER may not return
  to the parent image. If lispworks is not in PATH, set LISPWORKS=/path/to/lispworks.

Examples:
  sbcl --noinform --load load-taffish.lisp -h
  sbcl --noinform --load load-taffish.lisp -- --help
  sbcl --load load-taffish.lisp --compile
  sbcl --load load-taffish.lisp --compile-taffish
  sbcl --load load-taffish.lisp --compile-taf
  sbcl --load load-taffish.lisp --compile-taffish-mcp
  lispworks -build load-taffish.lisp --compile
  lispworks -build load-taffish.lisp --compile-taffish
  lispworks -build load-taffish.lisp --compile-taf
  lispworks -build load-taffish.lisp --compile-taffish-mcp
  lispworks -build load-taffish.lisp --taffish -h
  lispworks -build load-taffish.lisp --taf -h
  lispworks -build load-taffish.lisp --taffish-mcp -h
  sbcl --noinform --load load-taffish.lisp --taffish -h
  sbcl --noinform --load load-taffish.lisp --taffish test/test.taf --name alice
  sbcl --noinform --load load-taffish.lisp --taf -h
  sbcl --noinform --load load-taffish.lisp --taf check
  sbcl --noinform --load load-taffish.lisp --taffish-mcp -h")

(defun %print-load-taffish-help ()
  (format t "~A~%" (%get-load-taffish-help-string)))

(defun %load-taffish-system (&key silent)
  (if silent
      (let ((*standard-output* (make-broadcast-stream))
            (*trace-output* (make-broadcast-stream))
            (*compile-verbose* nil)
            (*load-verbose* nil))
        (asdf:load-system :taffish :force t :verbose nil))
      (asdf:load-system :taffish :force t)))

(let* ((root (make-pathname :name nil :type nil :defaults *load-truename*))
       (han-root (%subdir root "vendor" "han")))
  (pushnew root asdf:*central-registry* :test #'equal)
  (pushnew han-root asdf:*central-registry* :test #'equal))

;; (asdf:compile-system :taffish)

(defparameter *load-taffish-argv* (%load-taffish-argv))
(defparameter *load-taffish-dispatch-option* nil)
(defparameter *load-taffish-dispatch-args* nil)

(multiple-value-setq (*load-taffish-dispatch-option*
                      *load-taffish-dispatch-args*)
  (%split-at-load-taffish-dispatch-option *load-taffish-argv*))

(when (%load-taffish-help-option-p *load-taffish-dispatch-option*)
  (%print-load-taffish-help)
  (%load-taffish-quit 0))

(%load-taffish-system
 :silent (member *load-taffish-dispatch-option*
                 '("--taffish" "--taf" "--taffish-mcp" "--mcp")
                 :test #'string-equal))

(defun %make-taffish-bin ()
  (let ((file (han.path:join-path
               (han.path:parent-directory-pathname *load-truename*)
               "target" "taffish")))
    (ensure-directories-exist file)
    #+sbcl
    (progn
      (format t "[SBCL] Compiling TAFFISH -> ~A~%" file)
      (save-lisp-and-die file :save-runtime-options "--end-toplevel-options"
                              :executable t :purify t
                              :toplevel #'taffish.cli:main))
    #+lispworks
    (progn
      (format t "[LispWorks] Delivering TAFFISH -> ~A~%" file)
      (deliver 'taffish.cli::main (han.path:->namestring file) 5))
    #-(or sbcl lispworks)
    (error "[TAFFISH] <COMPILE ERROR> Now only support SBCL and LispWorks!")))

(defun %make-taf-bin ()
  (let ((file (han.path:join-path
               (han.path:parent-directory-pathname *load-truename*)
               "target" "taf")))
    (ensure-directories-exist file)
    #+sbcl
    (progn
      (format t "[SBCL] Compiling TAF -> ~A~%" file)
      (save-lisp-and-die file :save-runtime-options "--end-toplevel-options"
                              :executable t :purify t
                              :toplevel #'taf.cli:main))
    #+lispworks
    (progn
      (format t "[LispWorks] Delivering TAF -> ~A~%" file)
      (deliver 'taf.cli::main (han.path:->namestring file) 5))
    #-(or sbcl lispworks)
    (error "[TAFFISH] <COMPILE ERROR> Now only support SBCL and LispWorks!")))

(defun %make-taffish-mcp-bin ()
  (let ((file (han.path:join-path
               (han.path:parent-directory-pathname *load-truename*)
               "target" "taffish-mcp")))
    (ensure-directories-exist file)
    #+sbcl
    (progn
      (format t "[SBCL] Compiling TAFFISH-MCP -> ~A~%" file)
      (save-lisp-and-die file :save-runtime-options "--end-toplevel-options"
                              :executable t :purify t
                              :toplevel #'taffish.mcp:main))
    #+lispworks
    (progn
      (format t "[LispWorks] Delivering TAFFISH-MCP -> ~A~%" file)
      (deliver 'taffish.mcp::main (han.path:->namestring file) 5))
    #-(or sbcl lispworks)
    (error "[TAFFISH] <COMPILE ERROR> Now only support SBCL and LispWorks!")))

#+sbcl
(defun %sbcl-program-for-compile ()
  (or (ignore-errors
        (and sb-ext:*runtime-pathname*
             (namestring sb-ext:*runtime-pathname*)))
      (han.os:find-executable "sbcl")
      (error "[TAFFISH] can't find SBCL executable for multi-binary compile.")))

#+sbcl
(defun %run-sbcl-single-compile (option)
  (let ((sbcl (%sbcl-program-for-compile))
        (loader (han.path:->namestring *load-truename*)))
    (format t "[SBCL] Starting child compiler: ~A~%" option)
    (finish-output)
    (multiple-value-bind (out err code)
        (han.host:run-program-sync
         (list sbcl
               "--noinform"
               "--disable-debugger"
               "--non-interactive"
               "--load" loader
               option)
         :output t
         :error-output t
         :ignore-error-status t)
      (declare (ignore out err))
      (unless (and (integerp code) (= code 0))
        (error "[TAFFISH] child compiler failed for ~A with exit code ~A."
               option code)))))

#+lispworks
(defun %normalize-executable-candidate (candidate)
  (when (and candidate
             (stringp candidate)
             (> (length candidate) 0))
    (or (ignore-errors
          (let ((found (han.host:file-exists-p candidate)))
            (when found
              (namestring found))))
        (han.os:find-executable candidate))))

#+lispworks
(defun %lispworks-program-from-argv ()
  (let ((argv0 (first *load-taffish-argv*)))
    (%normalize-executable-candidate argv0)))

#+lispworks
(defun %lispworks-program-from-image ()
  (let ((image (ignore-errors (lispworks:lisp-image-name))))
    (%normalize-executable-candidate image)))

#+lispworks
(defun %lispworks-program-for-compile ()
  (or (%normalize-executable-candidate (han.host:getenv "LISPWORKS"))
      (%lispworks-program-from-argv)
      (%lispworks-program-from-image)
      (han.os:find-executable "lispworks")
      (error "[TAFFISH] can't find LispWorks executable for multi-binary compile. Set LISPWORKS=/path/to/lispworks.")))

#+lispworks
(defun %run-lispworks-single-compile (option)
  (let ((lispworks (%lispworks-program-for-compile))
        (loader (han.path:->namestring *load-truename*)))
    (format t "[LispWorks] Starting child delivery: ~A~%" option)
    (finish-output)
    (multiple-value-bind (out err code)
        (han.host:run-program-sync
         (list lispworks
               "-build" loader
               option)
         :output t
         :error-output t
         :ignore-error-status t)
      (declare (ignore out err))
      (unless (and (integerp code) (= code 0))
        (error "[TAFFISH] child delivery failed for ~A with exit code ~A."
               option code)))))

(defun %make-taffish-bins ()
  #+sbcl
  (progn
    ;; SBCL's SAVE-LISP-AND-DIE exits the current image, so compile each
    ;; executable in a fresh child process.
    (%run-sbcl-single-compile "--compile-taffish")
    (%run-sbcl-single-compile "--compile-taf")
    (%run-sbcl-single-compile "--compile-taffish-mcp")
    (format t "[SBCL] Built target/taffish, target/taf and target/taffish-mcp.~%"))
  #+lispworks
  (progn
    ;; LispWorks DELIVER may terminate the current image, so compile each
    ;; executable in a fresh child process, mirroring the SBCL strategy.
    (%run-lispworks-single-compile "--compile-taffish")
    (%run-lispworks-single-compile "--compile-taf")
    (%run-lispworks-single-compile "--compile-taffish-mcp")
    (format t "[LispWorks] Delivered target/taffish, target/taf and target/taffish-mcp.~%"))
  #-(or sbcl lispworks)
  (error "[TAFFISH] <COMPILE ERROR> Now only support SBCL and LispWorks!"))

(defun main (&optional (argv *load-taffish-argv*))
  (multiple-value-bind (dispatch-option dispatch-args)
      (%split-at-load-taffish-dispatch-option argv)
    (cond
      ((null dispatch-option)
       nil)
      ((%load-taffish-help-option-p dispatch-option)
       (%print-load-taffish-help)
       (han.host:quit 0))
      ((string-equal dispatch-option "--compile")
       (%make-taffish-bins)
       (han.host:quit 0))
      ((string-equal dispatch-option "--compile-taffish")
       (%make-taffish-bin)
       (han.host:quit 0))
      ((string-equal dispatch-option "--compile-taf")
       (%make-taf-bin)
       (han.host:quit 0))
      ((or (string-equal dispatch-option "--compile-taffish-mcp")
           (string-equal dispatch-option "--compile-mcp"))
       (%make-taffish-mcp-bin)
       (han.host:quit 0))
      ((string-equal dispatch-option "--taffish")
       ;; taffish.cli keeps argv[0] as command name for $0-like context.
       (taffish.cli:main (cons "taffish" dispatch-args)))
      ((string-equal dispatch-option "--taf")
       (taf.cli:main dispatch-args))
      ((or (string-equal dispatch-option "--taffish-mcp")
           (string-equal dispatch-option "--mcp"))
       (taffish.mcp:main dispatch-args)))))

(main)
