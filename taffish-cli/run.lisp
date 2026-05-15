(in-package :taffish.cli)

;;;; ============================================================
;;;; run.lisp
;;;; ============================================================

;;;; ------------------------------------------------------------
;;;; run: version
;;;; ------------------------------------------------------------

(defparameter *taffish-version*
  "taffish 0.9.0 (2026-05, Kaiyuan Han)")

(defun run-taffish-version ()
  (format t "~A~%" *taffish-version*))

;;;; ------------------------------------------------------------
;;;; run: help
;;;; ------------------------------------------------------------

(defun %format-split-line (length &optional (char #\-))
  (let ((len (if (stringp length)
                 (length length)
                 (if (numberp length)
                     length
                     (error "LENGTH must be NUMBER or STRING, but got: ~S"
                            (type-of length))))))
    (dotimes (i len)
      (format t "~A" char))
    (format t "~%")))

(defun %get-taffish-help-string ()
  "USAGE:
  taffish [-h | --help]           Print help info and exit
  taffish [-v | --version]        Print version info and exit
  taffish [ARGS...]               Compile TAFFISH code from STDIN
  taffish <FILE.TAF> [ARGS...]    Compile FILE.TAF to shell
  taffish -- [ARGS...]            Compile TAFFISH code from STDIN

DETAILS:
  - If the first argument is an existing file, TAFFISH reads that file.
  - Otherwise TAFFISH reads source code from STDIN and treats arguments
    as .taf program arguments.
  - Generated shell code is printed to STDOUT.
  - TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker forces generic
    <container:...> tags without overriding explicit backend tags.
  - TAFFISH_DOCKER_RUN_ARGS, TAFFISH_PODMAN_RUN_ARGS, and
    TAFFISH_APPTAINER_RUN_ARGS append local backend-specific runtime args.")

(defun run-taffish-help ()
  (format t "~A~%" *taffish-version*)
  (%format-split-line *taffish-version* #\-)
  (format t "~A~%" (%get-taffish-help-string)))

;;;; ------------------------------------------------------------
;;;; run: cli
;;;; ------------------------------------------------------------

(defun run-taffish-cli (input-source core-args core-context)
  "Run TAFFISH CLI
USAGE:
  taffish [file.taf] [args...]
  taffish --
  taffish -h | --help
  taffish -v | --version
ARGS-EXAMPLE:
- input-source: (:file \"/path/xxx.taf\") or (:stdin)
- core-args: (\"--xxx\" \"abc\" ...)
- core-context: ((:user \"alice\")
                 (:homedir \"/home/alice\")
                 ...)"
  (let* ((input (case (car input-source)
                  (:file (cdr input-source))
                  (:stdin *standard-input*)
                  (t (error "Unknown input-source type: ~S"
                            (car input-source)))))
         (code-string (han.os:load-string input))
         (shell-string
           (taffish.core:taffish-to-shell code-string core-args core-context)))
    (format t "~A" shell-string)))
