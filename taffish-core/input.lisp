(in-package :taffish.core)

;;;; ============================================================
;;;; input.lisp
;;;; ============================================================

(defun normalize-input-args (input-args)
  "Normalize INPUT-ARGS into han.args:args-input.
INPUT-ARGS should be a list like:
  (\"command\" \"--name\" \"alice\")
The first element is treated as command name, and the rest as argv."
  (unless (listp input-args)
    (error "INPUT-ARGS must be a list, but got: ~A."
           (type-of input-args)))
  (han.args:parse-args-input input-args '("taffish")))

(defun %context-ref (key context)
  (cdr (assoc key context :test #'eql)))

(defun %default-container-config ()
  '((:backend-order . (:apptainer :podman :docker))
    (:available-backends . ())
    (:force-backend . nil)

    (:pass-user-env-p . t)
    (:mount-homedir-p . t)
    (:mount-workdir-p . t)
    (:container-home-mode . :same-as-host)
    (:extra-mounts . nil)

    (:docker-heredoc-quoted-p . nil)
    (:podman-heredoc-quoted-p . nil)
    (:apptainer-heredoc-quoted-p . nil)

    (:docker-run-args . nil)
    (:podman-run-args . nil)
    (:apptainer-exec-args . nil)
    (:docker-env-run-args . nil)
    (:podman-env-run-args . nil)
    (:apptainer-env-exec-args . nil)

    (:apptainer-image-dir . ("${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif"
                             "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif"))
    (:apptainer-quiet-p . t)
    (:apptainer-auto-pull-p . t)
    (:apptainer-pull-source . :docker)))

(defun %context-container (context)
  (let ((context-container (%context-ref :container context))
        (default-container (%default-container-config)))
    (when (and context-container (not (listp context-container)))
      (error ":CONTAINER in CONTEXT must be an alist/list, but got: ~S"
             context-container))
    (let ((container nil))
      ;; copy default pairs
      (dolist (pair default-container)
        (push (cons (car pair) (cdr pair)) container))
      ;; override / append user pairs
      (dolist (pair context-container)
        (unless (consp pair)
          (error ":CONTAINER item must be a cons pair, but got: ~S" pair))
        (let ((old (assoc (car pair) container :test #'eql)))
          (if old
              (setf (cdr old) (cdr pair))
              (push (cons (car pair) (cdr pair)) container))))
      (nreverse container))))

(defun normalize-input-context (&optional context)
  "Normalize CONTEXT alist into TAF-CONTEXT.
CONTEXT should be an alist, for example:
  ((:user . \"alice\")
   (:homedir . \"/home/user\")
   (:workdir . \"/tmp\")
   (:loaddir . \"/tmp/app\")
   (:argv . (\"taf-demo\" \"--x\" \"1\"))
   (:cmd . \"taf-demo\")
   (:cpus . 8)
   (:container . ((:backend-order . (:apptainer :podman :docker))
                  (:available-backends . (:docker :podman))
                  (:force-backend . nil)
                  (:pass-user-env-p . t)
                  (:mount-homedir-p . t)
                  (:mount-workdir-p . t)
                  (:container-home-mode . :same-as-host)
                  (:extra-mounts . nil)
                  (:docker-heredoc-quoted-p . nil)
                  (:podman-heredoc-quoted-p . nil)
                  (:apptainer-heredoc-quoted-p . nil)
                  (:docker-run-args . nil)
                  (:podman-run-args . nil)
                  (:apptainer-exec-args . nil)
                  (:docker-env-run-args . nil)
                  (:podman-env-run-args . nil)
                  (:apptainer-env-exec-args . nil)
                  (:apptainer-image-dir . (\"${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif\"
                                           \"${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif\"))
                  (:apptainer-quiet-p . t)
                  (:apptainer-auto-pull-p . t)
                  (:apptainer-pull-source . :docker)))
   ...)
Unknown keys are preserved in TAF-CONTEXT-EXTRAS."
  (when (and context (not (listp context)))
    (error "CONTEXT must be an alist/list, but got: ~A."
           (type-of context)))
  (let ((known-keys '(:user :homedir :workdir :loaddir :argv :cmd :cpus :container))
        (extras nil))
    (dolist (pair context)
      (unless (consp pair)
        (error "CONTEXT item must be a cons pair, but got: ~S." pair))
      (unless (member (car pair) known-keys :test #'eql)
        (push pair extras)))
    (make-taf-context
     :user      (%context-ref :user context)
     :homedir   (%context-ref :homedir context)
     :workdir   (%context-ref :workdir context)
     :loaddir   (%context-ref :loaddir context)
     :argv      (%context-ref :argv context)
     :cmd       (%context-ref :cmd context)
     :cpus      (%context-ref :cpus context)
     :container (%context-container context)
     :extras    (nreverse extras))))
