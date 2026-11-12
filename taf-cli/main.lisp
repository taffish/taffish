(in-package :taf.cli)

;;;; ============================================================
;;;; main.lisp
;;;; ============================================================

(defun %clean-string (string &optional (trim-fun #'string-trim))
  (if (and string (stringp string))
      (funcall trim-fun '(#\Space #\Tab) string)
      string))

(defun %cmd-string-to-symbol (raw-cmd-string)
  (let ((cmd-string (%clean-string raw-cmd-string)))
    (cond
      ((or (null raw-cmd-string)
           (member cmd-string '("-h" "--help" "help") :test #'string=))
       :help)
      ((member cmd-string '("-v" "--version" "version") :test #'string=)
       :version)
      ;; project
      ((string= cmd-string "new")     :new)
      ((string= cmd-string "check")   :check)
      ((string= cmd-string "compile") :compile)
      ((string= cmd-string "build")   :build)
      ((string= cmd-string "run")     :run)
      ((string= cmd-string "publish") :publish)
      ;; hub
      ((string= cmd-string "update")    :update)
      ((string= cmd-string "search")    :search)
      ((string= cmd-string "info")      :info)
      ((string= cmd-string "install")   :install)
      ((string= cmd-string "outdated")  :outdated)
      ((string= cmd-string "upgrade")   :upgrade)
      ((string= cmd-string "prune")     :prune)
      ((string= cmd-string "uninstall") :uninstall)
      ((string= cmd-string "list")      :list)
      ((string= cmd-string "which")     :which)
      ;; system
      ((string= cmd-string "doctor")    :doctor)
      ((string= cmd-string "config")    :config)
      ((string= cmd-string "history")   :history)
      (t :unknown))))

(defun %parse-raw-argv (raw-argv)
  (let ((cmd (%cmd-string-to-symbol (car raw-argv)))
        (args (cdr raw-argv)))
    (values cmd args)))

(defun %main (raw-argv)
  (handler-case
      (progn
        (multiple-value-bind (cmd args)
            (%parse-raw-argv raw-argv)
          (case cmd
            (:help    (run-taf-help args))
            (:version (run-taf-version))
            ;; project
            (:new     (run-taf-new     args))
            (:check   (run-taf-check   args))
            (:compile (run-taf-compile args))
            (:build   (run-taf-build   args))
            (:run     (run-taf-run     args))
            (:publish (run-taf-publish args))
            ;; hub
            (:update  (run-taf-update args))
            (:search  (run-taf-search args))
            (:info    (run-taf-info   args))
            (:install (run-taf-install args))
            (:outdated (run-taf-outdated args))
            (:upgrade (run-taf-upgrade args))
            (:prune   (run-taf-prune args))
            (:uninstall (run-taf-uninstall args))
            (:list    (run-taf-list args))
            (:which   (run-taf-which args))
            ;; system
            (:doctor
             (let ((result (run-taf-doctor args)))
               (when (and (listp result) (getf result :exit-code)
                          (not (zerop (getf result :exit-code))))
                 (han.host:quit (getf result :exit-code)))))
            (:config  (run-taf-config args))
            (:history (run-taf-history args))
            (:unknown
             (error "~A~%~A"
                    (%taf-unknown-command-message raw-argv)
                    (%get-taf-help-string)))))
        (han.host:quit 0))
    (error (c)
      (format *error-output* "[TAF-ERROR] ~A~%" c)
      (han.host:quit 1))))

(defun %run-command-line (raw-argv standalone-p)
  (han.host::%with-cli-error-boundary ("[TAF-ERROR]")
    (han.host:prepare-runtime-io)
    (han.host:configure-runtime-io)
    (let ((taf.core::*cli-terminal-error-output*
            (and standalone-p (ignore-errors (han.host:standard-error-terminal-p))
                 *error-output*)))
      (taffish.i18n:call-with-resolved-language
       (lambda () (%main raw-argv))))))

(defun main (&optional (raw-argv (han.host:argv)))
  (%run-command-line raw-argv nil))

(defun %standalone-main (&optional (raw-argv (han.host:argv)))
  "Executable entry point. After runtime I/O setup, stderr belongs to this process."
  (%run-command-line raw-argv t))
