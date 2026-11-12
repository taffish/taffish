(in-package :taffish.cli)

;;;; ============================================================
;;;; run.lisp
;;;; ============================================================

;;;; ------------------------------------------------------------
;;;; run: version
;;;; ------------------------------------------------------------

(defparameter *taffish-version*
  "taffish     0.12.0")

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

(defun %get-taffish-help-string-english ()
  "Compile TAF source to POSIX shell on standard output, without executing it.

Usage:
  taffish <FILE.TAF> [ARGS...]
  taffish [ARGS...]
  taffish -- [ARGS...]
  taffish [-h | --help]
  taffish [-v | --version]

Input:
  When compiling, an existing regular file as the first argument is the source.
  Otherwise, read standard input and pass all arguments to the TAF program.
  A nonexistent filename also selects standard input and may wait for input.
  A leading -- forces standard input and forwards the remaining arguments.

Container settings:
  TAFFISH_CONTAINER_BACKEND
    Values: apptainer, podman, docker; unset: choose an available backend.
    Only affects <container:...>, not tags that explicitly name a backend.

  TAFFISH_DOCKER_RUN_ARGS        Append Docker runtime arguments
  TAFFISH_PODMAN_RUN_ARGS        Append Podman runtime arguments
  TAFFISH_APPTAINER_RUN_ARGS     Append Apptainer runtime arguments

Examples:
  taffish example.taf > example.sh
  taffish -- < example.taf > example.sh
  TAFFISH_CONTAINER_BACKEND=podman taffish example.taf > example.sh

Language:
  taf config language         Show current and available languages
  taf config language zh      Chinese; en: English; auto: host locale [default]

More information:
  Website: https://taffish.com
  Hub: https://taffish.github.io/
  Support: support@taffish.com")

(defun run-taffish-help ()
  (format t "~A~%" *taffish-version*)
  (%format-split-line *taffish-version* #\-)
  (format t "~A~%" (%get-taffish-help-string)))

;;;; ------------------------------------------------------------
;;;; run: cli
;;;; ------------------------------------------------------------

(defun run-taffish-cli (input-source core-args core-context)
  "Run TAFFISH CLI
Usage:
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
