;;;; ============================================================
;;;; emitter: builtins: container.lisp
;;;; ============================================================

;; :taffish.emitter.<AUTHOR>.<TAG-NAME>
(defpackage :taffish.emitter.builtins.container
  (:use :cl)
  (:export
   :match-container-tag
   :emit-container))

(in-package :taffish.emitter.builtins.container)

(defun %split-once (string split-char)
  (let ((len (length string)))
    (labels ((sb (index)
               (if (>= index len)
                   (values string nil)
                   (if (char= split-char (char string index))
                       (values (subseq string 0 index)
                               (subseq string (1+ index)))
                       (sb (1+ index))))))
      (sb 0))))

(defun %split-every (string split-char)
  (unless (stringp string)
    (error "STRING must be string, but got: ~S"
           (type-of string)))
  (let ((out-list nil))
    (labels ((se (last-string)
               (multiple-value-bind (left right)
                   (%split-once last-string split-char)
                 (push left out-list)
                 (when right
                   (se right)))))
      (se string)
      (nreverse out-list))))

(defun %clean-string (string)
  (string-trim '(#\Space #\Tab) string))

(defun %string-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (string= prefix (subseq string 0 (length prefix)))))

(defun %trim-run-args (string)
  (and string (%clean-string string)))

(defun %parse-container-kind (container)
  (let ((clean-container (%clean-string container)))
    (cond
      ((string-equal clean-container "container")
       :container)
      ((string-equal clean-container "docker")
       :docker)
      ((string-equal clean-container "podman")
       :podman)
      ((string-equal clean-container "apptainer")
       :apptainer)
      (t nil))))

(defun %parse-container-arg-kind (container)
  (let ((clean-container (%clean-string container)))
    (cond
      ((string-equal clean-container "all")
       :all)
      ((string-equal clean-container "container")
       :all)
      (t
       (%parse-container-kind clean-container)))))

(defun %parse-container-head (container-head)
  (let ((containers (mapcar #'%parse-container-kind
                            (%split-every container-head #\/))))
    (unless (some #'null containers)
      containers)))

(defun %parse-container-arg-targets (target-string raw-tag line-number)
  (let ((targets (mapcar #'%parse-container-arg-kind
                         (%split-every target-string #\/))))
    (when (or (null targets)
              (some #'null targets))
      (taffish.core:signal-taffish-error
       "Invalid container run-args target in <CONTAINER:IMAGE$@[backend: ARGS]>."
       :line line-number
       :column nil
       :source-string raw-tag))
    targets))

(defun %blank-string-p (string)
  (or (null string)
      (string= "" (%clean-string string))))

(defun %parse-tag-heredoc-switch (raw-tag)
  (let ((clean-tag (%clean-string raw-tag)))
    (if (ignore-errors (char= #\' (char clean-tag 0)))
        (values (subseq raw-tag 1) t)
        (values raw-tag nil))))

(defun %structured-run-args-p (run-args)
  (%string-prefix-p "@[" (%clean-string run-args)))

(defun %read-container-arg-block (string index raw-tag line-number)
  (let ((len (length string))
        (out nil)
        (i index))
    (unless (and (< i len)
                 (char= #\[ (char string i)))
      (taffish.core:signal-taffish-error
       "Expected '[' in structured container run args."
       :line line-number
       :column nil
       :source-string raw-tag))
    (incf i)
    (loop
      (when (>= i len)
        (taffish.core:signal-taffish-error
         "Unclosed structured container run-args block."
         :line line-number
         :column nil
         :source-string raw-tag))
      (let ((char (char string i)))
        (cond
          ((char= char #\])
           (return
             (values (coerce (nreverse out) 'string)
                     (1+ i))))
          ((and (char= char #\\)
                (< (1+ i) len)
                (char= (char string (1+ i)) #\]))
           (push #\] out)
           (incf i 2))
          (t
           (push char out)
           (incf i)))))))

(defun %parse-container-arg-block (content raw-tag line-number)
  (multiple-value-bind (target-string arg-string)
      (%split-once content #\:)
    (unless arg-string
      (taffish.core:signal-taffish-error
       "Structured container run-args block must be [backend: ARGS]."
       :line line-number
       :column nil
       :source-string raw-tag))
    (let ((targets (%parse-container-arg-targets target-string raw-tag line-number))
          (args (%trim-run-args arg-string)))
      (when (%blank-string-p args)
        (taffish.core:signal-taffish-error
         "Structured container run-args block has empty ARGS."
         :line line-number
         :column nil
         :source-string raw-tag))
      (loop for target in targets
            collect (cons target args)))))

(defun %parse-structured-run-args (run-args raw-tag line-number)
  (let* ((clean-run-args (%clean-string run-args))
         (len (length clean-run-args))
         (i 1)
         (out nil))
    (loop
      (loop while (and (< i len)
                       (member (char clean-run-args i)
                               '(#\Space #\Tab #\Newline #\Return)))
            do (incf i))
      (when (>= i len)
        (return (nreverse out)))
      (unless (char= #\[ (char clean-run-args i))
        (taffish.core:signal-taffish-error
         "Structured container run args must be @[...] blocks."
         :line line-number
         :column nil
         :source-string raw-tag))
      (multiple-value-bind (content next-index)
          (%read-container-arg-block clean-run-args i raw-tag line-number)
        (dolist (entry (%parse-container-arg-block content raw-tag line-number))
          (push entry out))
        (setf i next-index)))))

(defun %parse-container-run-args (run-args raw-tag line-number)
  (cond
    ((%blank-string-p run-args)
     (values nil nil))
    ((%structured-run-args-p run-args)
     (values nil
             (%parse-structured-run-args run-args raw-tag line-number)))
    (t
     (values (%clean-string run-args) nil))))

;; <CONTAINERS:IMAGE$RUN-ARGS>
(defun match-container-tag (raw-tag line-number)
  (multiple-value-bind (tag force-heredoc-p)
      (%parse-tag-heredoc-switch raw-tag)
    (multiple-value-bind (container-head image-args)
        (%split-once tag #\:)
      (when image-args
        (multiple-value-bind (image run-args)
            (%split-once image-args #\$)
          (when (%blank-string-p image)
            ;;(error "CONTAINER IMAGE is missing in tag: <~A>" tag)
            (taffish.core:signal-taffish-error
             "IMAGE is missing in tag <CONTAINER:IMAGE($ARGS)>."
             :line line-number
             :column nil
             :source-string raw-tag))
          (multiple-value-bind (legacy-run-args backend-run-args)
              (%parse-container-run-args run-args raw-tag line-number)
            (let ((container-kinds (%parse-container-head container-head))
                  (clean-image (%clean-string image)))
              (when container-kinds
                (list :kind :container
                      :tag raw-tag
                      :line-number line-number
                      :heredoc-quoted-p force-heredoc-p
                      :backend-kinds container-kinds
                      :image clean-image
                      :run-args legacy-run-args
                      :backend-run-args backend-run-args)))))))))

(defun %container-ref (container-config key)
  (let ((pair (assoc key container-config :test #'eql)))
    (if pair
        (values (cdr pair) t)
        (values nil nil))))

(defun %choose-available-backend (may-containers available-backends
                                  &optional (backend-order '(:apptainer
                                                             :podman
                                                             :docker)))
  "Choose the first available backend from MAY-CONTAINERS.
If one candidate is :CONTAINER, it expands to BACKEND-ORDER and continues
selection against AVAILABLE-BACKENDS."
  (unless (and (member :apptainer backend-order)
               (member :podman backend-order)
               (member :docker backend-order))

    (error "BACKEND-ORDER must include all three container apps, but got: ~S"
           backend-order))
  (when may-containers
    (let ((the-container (car may-containers)))
      (case the-container
        ;; backend-order already include all apps, so don't need (cdr may-containers)
        (:container
         (%choose-available-backend backend-order available-backends))
        (t
         (if (member the-container available-backends :test #'eql)
             the-container
             (%choose-available-backend
              (cdr may-containers) available-backends backend-order)))))))

(defun %container-backend-kind-p (backend)
  (member backend '(:apptainer :podman :docker) :test #'eql))

(defun %choose-forced-container-backend (backend-kinds force-backend
                                         available-backends)
  (when force-backend
    (unless (%container-backend-kind-p force-backend)
      (error "FORCE-BACKEND must be one of :APPTAINER, :PODMAN or :DOCKER, but got: ~S"
             force-backend))
    (when (member :container backend-kinds :test #'eql)
      (unless (member force-backend available-backends :test #'eql)
        (error "Forced container backend ~A is not available. Available backends: ~S"
               force-backend available-backends))
      force-backend)))

(defun %taf-container-config (taf-result)
  (let ((context (taffish.core:taf-result-context taf-result)))
    (and context
         (taffish.core:taf-context-container context))))

(defun %choose-container-backend (backend-kinds taf-result)
  "Choose one actual backend from BACKEND-KINDS and TAF-RESULT context."
  (let* ((container-config (%taf-container-config taf-result))
         (backend-order (%container-ref container-config :backend-order))
         (available-backends (%container-ref container-config :available-backends))
         (force-backend (%container-ref container-config :force-backend)))
    (or (%choose-forced-container-backend backend-kinds
                                          force-backend
                                          available-backends)
        (%choose-available-backend backend-kinds
                                   available-backends
                                   backend-order))))

;;;; ============================================================
;;;; helper emitter
;;;; ============================================================

(defun %singlep (list)
  (and list
       (null (cdr list))))

(defun %single-cmd-p (line)
  (when (and line (stringp line)
             (not (string= "" (%clean-string line))))
    (dotimes (i (length line))
      (let ((char (char line i)))
        (if (member char '(#\; #\& #\| #\< #\> #\`))
            (return-from %single-cmd-p nil)
            (when (char= char #\$)
              (when (ignore-errors (char= #\( (char line (1+ i))))
                (return-from %single-cmd-p nil))))))
    t))

(defun %skip-line-p (line)
  (let ((clean-line (%clean-string line)))
    (or (string= "" clean-line)
        (char= #\# (char clean-line 0)))))

(defun %single-cmd-line-p (lines-strings)
  (let ((real-lines (remove-if #'%skip-line-p lines-strings)))
    (when (%singlep real-lines)
      (let ((line (car real-lines)))
        (when (%single-cmd-p line) line)))))

(defun %heredoc-open (quoted-p)
  (if quoted-p
      "bash <<'EOF'"
      "bash <<EOF"))

(defun %resolved-lines->strings (lines)
  (mapcar #'(lambda (line)
              (getf line :line))
          lines))

(defun %join-non-empty-strings (&rest strings)
  (format nil "~{~A~^ ~}"
          (remove-if #'(lambda (x)
                         (or (null x)
                             (and (stringp x)
                                  (string= "" (%clean-string x)))))
                     strings)))

(defun %ensure-string-list (value key-name)
  (cond
    ((null value) nil)
    ((stringp value) (list value))
    ((listp value)
     (dolist (item value)
       (unless (stringp item)
         (error "~A must be a string or list of strings, but got item: ~S"
                key-name item)))
     value)
    (t
     (error "~A must be a string or list of strings, but got: ~S"
            key-name value))))

(defun %container-config-value (taf-result key)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result) key)
    (if found-p value nil)))

(defun %container-config-bool (taf-result key &optional default)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result) key)
    (if found-p value default)))

(defun %host-user (taf-result)
  (or (let ((context (taffish.core:taf-result-context taf-result)))
        (and context
             (taffish.core:taf-context-user context)))
      (han.args:get-arg "*USER*"
                        (taffish.core:taf-result-args-result taf-result))))

(defun %host-homedir (taf-result)
  (let ((context (taffish.core:taf-result-context taf-result)))
    (or (and context
             (taffish.core:taf-context-homedir context))
        (han.args:get-arg "*HOMEDIR*"
                          (taffish.core:taf-result-args-result taf-result)))))

(defun %host-workdir (taf-result)
  (or (let ((context (taffish.core:taf-result-context taf-result)))
        (and context
             (taffish.core:taf-context-workdir context)))
      (han.args:get-arg "*WORKDIR*"
                        (taffish.core:taf-result-args-result taf-result))
      "/work"))

(defun %container-home-path (taf-result)
  (let* ((mode (%container-config-value taf-result :container-home-mode))
         (homedir (%host-homedir taf-result))
         (user (%host-user taf-result)))
    (case mode
      ((nil :same-as-host)
       homedir)
      (:linux-user-home
       (if user
           (format nil "/home/~A" user)
           "/home/user"))
      (t
       (error "Unknown :CONTAINER-HOME-MODE: ~S" mode)))))

(defun %effective-container-workdir (taf-result)
  (let ((host-workdir (%host-workdir taf-result))
        (mount-workdir-p (%container-config-bool taf-result :mount-workdir-p t))
        (container-home (%container-home-path taf-result)))
    (cond
      ((and mount-workdir-p host-workdir)
       host-workdir)
      (container-home
       container-home)
      (t
       "/work"))))

(defun %container-debug-prelude (backend parsed-info taf-result final-run-args quoted-p)
  (let* ((container-config (%taf-container-config taf-result))
         (force-heredoc-p (getf parsed-info :heredoc-quoted-p))
         (heredoc-quoted-p (or quoted-p force-heredoc-p))
         (backend-kinds (getf parsed-info :backend-kinds))
         (backend-order (%container-ref container-config :backend-order))
         (available-backends (%container-ref container-config :available-backends))
         (force-backend (%container-ref container-config :force-backend))
         (image (getf parsed-info :image)))
    (list
     "### Generated by TAFFISH: CONTAINER"
     (format nil "# CHOSEN BACKEND: ~A" (string-upcase (string backend)))
     (format nil "# REQUESTED BACKENDS: ~S" backend-kinds)
     (format nil "# BACKEND ORDER: ~S" backend-order)
     (format nil "# AVAILABLE BACKENDS: ~S" available-backends)
     (format nil "# FORCE BACKEND: ~S" force-backend)
     (format nil "# IMAGE: ~A" image)
     (format nil "# FINAL RUN ARGS: ~A" (or final-run-args ""))
     (format nil "# PAYLOAD LIMIT: ~A"
             (if force-heredoc-p "heredoc" "command + heredoc"))
     (format nil "# HEREDOC QUOTED: ~A"
             (if heredoc-quoted-p "yes" "no")))))

;;;; ============================================================
;;;; podman / docker shared emitter
;;;; ============================================================

(defun %podman-or-docker-command (backend)
  (case backend
    (:docker "docker")
    (:podman "podman")
    (t
     (error "BACKEND must be :DOCKER or :PODMAN, but got: ~S"
            backend))))

(defun %podman-or-docker-heredoc-quoted-p (backend taf-result)
  (let ((key (case backend
               (:docker :docker-heredoc-quoted-p)
               (:podman :podman-heredoc-quoted-p)
               (t
                (error "BACKEND must be :DOCKER or :PODMAN, but got: ~S"
                       backend)))))
    (multiple-value-bind (value found-p)
        (%container-ref (%taf-container-config taf-result) key)
      (if found-p
          value
          t))))

(defun %podman-or-docker-workdir (taf-result)
  (%effective-container-workdir taf-result))

(defun %podman-or-docker-default-run-args-list (backend taf-result)
  "Return docker/podman default run args as an ordered list of strings."
  (declare (ignore backend))
  (let* ((mount-homedir-p (%container-config-bool taf-result :mount-homedir-p t))
         (mount-workdir-p (%container-config-bool taf-result :mount-workdir-p t))
         (pass-user-env-p (%container-config-bool taf-result :pass-user-env-p t))
         (host-homedir (%host-homedir taf-result))
         (host-workdir (%host-workdir taf-result))
         (container-home (%container-home-path taf-result))
         (user (%host-user taf-result))
         (extra-mounts (%ensure-string-list
                        (%container-config-value taf-result :extra-mounts)
                        ":EXTRA-MOUNTS"))
         (args nil))
    (when (and mount-homedir-p host-homedir container-home)
      (setf args
            (append args
                    (list "-v"
                          (format nil "\"~A:~A\"" host-homedir container-home)))))
    (when (and mount-workdir-p host-workdir)
      (setf args
            (append args
                    (list "-v"
                          (format nil "\"~A:~A\"" host-workdir host-workdir)))))
    (dolist (mount extra-mounts)
      (setf args
            (append args
                    (list "-v"
                          (format nil "\"~A\"" mount)))))
    (when pass-user-env-p
      (when container-home
        (setf args
              (append args
                      (list "-e"
                            (format nil "\"HOME=~A\"" container-home)))))
      (when user
        (setf args
              (append args
                      (list "-e"
                            (format nil "\"USER=~A\"" user))))))
    args))

(defun %podman-or-docker-config-run-args-list (backend taf-result)
  (let* ((key (case backend
                (:docker :docker-run-args)
                (:podman :podman-run-args)
                (t
                 (error "BACKEND must be :DOCKER or :PODMAN, but got: ~S"
                        backend))))
         (value (%container-config-value taf-result key)))
    (%ensure-string-list value key)))

(defun %backend-tag-run-args-list (backend parsed-info)
  (let ((run-args (getf parsed-info :run-args)))
    (append
     (if (%blank-string-p run-args)
         nil
         (list run-args))
     (loop for (target . args) in (getf parsed-info :backend-run-args)
           when (member target (list :all backend) :test #'eql)
           collect args))))

(defun %podman-or-docker-env-run-args-list (backend taf-result)
  (let* ((key (case backend
                (:docker :docker-env-run-args)
                (:podman :podman-env-run-args)
                (t
                 (error "BACKEND must be :DOCKER or :PODMAN, but got: ~S"
                        backend))))
         (value (%container-config-value taf-result key)))
    (%ensure-string-list value key)))

(defun %podman-or-docker-run-args-string (backend parsed-info taf-result)
  (let ((all-args
          (append (%podman-or-docker-default-run-args-list backend taf-result)
                  (%podman-or-docker-config-run-args-list backend taf-result)
                  (%backend-tag-run-args-list backend parsed-info)
                  (%podman-or-docker-env-run-args-list backend taf-result))))
    (if all-args
        (apply #'%join-non-empty-strings all-args)
        "")))

(defun %podman-or-docker-image-exists-shell (command image)
  (cond
    ((string= command "docker")
     (format nil "if docker image inspect ~S >/dev/null 2>&1; then" image))
    ((string= command "podman")
     (format nil "if podman image exists ~S >/dev/null 2>&1; then" image))
    (t
     (error "COMMAND must be \"docker\" or \"podman\", but got: ~S"
            command))))

(defun %emit-podman-or-docker (backend parsed-info lines taf-result)
  (let* ((command (%podman-or-docker-command backend))
         (image (getf parsed-info :image))
         (workdir (%podman-or-docker-workdir taf-result))
         (run-args-string
           (%podman-or-docker-run-args-string backend parsed-info taf-result))
         (line-strings (%resolved-lines->strings lines))
         (force-heredoc-p (getf parsed-info :heredoc-quoted-p))
         (single-cmd-line-p (and (not force-heredoc-p)
                                 (%single-cmd-line-p line-strings)))
         (quoted-p (or force-heredoc-p
                       (%podman-or-docker-heredoc-quoted-p backend taf-result)))
         (heredoc-open (%heredoc-open quoted-p))
         (debug-prelude (%container-debug-prelude
                         backend parsed-info taf-result run-args-string quoted-p)))
    (append
     debug-prelude
     (list
      (format nil "if command -v ~A >/dev/null 2>&1; then" command)
      "    :"
      "else"
      (format nil "    echo \"[TAFFISH] ~A not found\" >&2" command)
      "    exit 1"
      "fi"
      ""
      (%podman-or-docker-image-exists-shell command image)
      "    :"
      "else"
      (format nil "    echo \"[TAFFISH] Pull image: ~A\" >&2" image)
      (format nil "    ~A pull ~S" command image)
      "fi"
      ""
      (format nil "~A run --rm -i -w ~S~@[ ~A~] ~S ~A"
              command
              workdir
              (and run-args-string
                   (not (string= "" (%clean-string run-args-string)))
                   run-args-string)
              image
              (if single-cmd-line-p
                  single-cmd-line-p
                  heredoc-open)))
     (if single-cmd-line-p
         nil
         line-strings)
     (if single-cmd-line-p
         nil
         (list "EOF")))))

(defun %emit-docker (parsed-info lines taf-result)
  (%emit-podman-or-docker :docker parsed-info lines taf-result))

(defun %emit-podman (parsed-info lines taf-result)
  (%emit-podman-or-docker :podman parsed-info lines taf-result))

;;;; ============================================================
;;;; apptainer emitter
;;;; ============================================================

(defun %apptainer-heredoc-quoted-p (taf-result)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result)
                      :apptainer-heredoc-quoted-p)
    (if found-p
        value
        t)))

(defun %apptainer-workdir (taf-result)
  (%effective-container-workdir taf-result))

(defun %apptainer-image-dirs (taf-result)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result)
                      :apptainer-image-dir)
    (let ((dirs (if found-p
                    value
                    '("${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif"
                      "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif"))))
      (cond
        ((null dirs)
         '("${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif"
           "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif"))
        ((stringp dirs)
         (list dirs))
        ((listp dirs)
         (mapcar #'(lambda (dir)
                     (cond
                       ((string= dir "~/.taffish/images")
                        "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif")
                       ((string= dir "~/.local/share/taffish/images/sif")
                        "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif")
                       (t dir)))
                 dirs))
        (t
         (error ":APPTAINER-IMAGE-DIR must be STRING/LIST, but got: ~S"
                dirs))))))

(defun %apptainer-auto-pull-p (taf-result)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result)
                      :apptainer-auto-pull-p)
    (if found-p
        value
        t)))

(defun %apptainer-quiet-p (taf-result)
  (multiple-value-bind (value found-p)
      (%container-ref (%taf-container-config taf-result)
                      :apptainer-quiet-p)
    (if found-p
        value
        t)))

(defun %apptainer-pull-source (parsed-info taf-result)
  (let ((image (getf parsed-info :image)))
    (multiple-value-bind (source found-p)
        (%container-ref (%taf-container-config taf-result)
                        :apptainer-pull-source)
      (let ((pull-source (if found-p source :docker)))
        (case pull-source
          (:docker
           (format nil "docker://~A" image))
          (:oras
           (format nil "oras://~A" image))
          (:library
           (format nil "library://~A" image))
          (t
           (error "Unknown :APPTAINER-PULL-SOURCE: ~S" pull-source)))))))

(defun %strip-trailing-slashes (path)
  (let ((end (length path)))
    (loop while (and (> end 1)
                     (char= #\/ (char path (1- end))))
          do (decf end))
    (subseq path 0 end)))

(defun %same-or-child-path-p (directory path)
  (when (and (stringp directory)
             (stringp path)
             (not (%blank-string-p directory))
             (not (%blank-string-p path)))
    (let ((dir (%strip-trailing-slashes directory))
          (target (%strip-trailing-slashes path)))
      (or (string= dir target)
          (and (< (length dir) (length target))
               (char= #\/ (char target (length dir)))
               (string= dir (subseq target 0 (length dir))))))))

(defun %apptainer-home-bind-covers-workdir-p (host-homedir host-workdir
                                              container-home)
  (and host-homedir
       host-workdir
       container-home
       (string= host-homedir container-home)
       (%same-or-child-path-p host-homedir host-workdir)))

(defun %apptainer-default-exec-args-list (taf-result)
  "Return apptainer default exec args as an ordered list of strings."
  (let* ((mount-homedir-p (%container-config-bool taf-result :mount-homedir-p t))
         (mount-workdir-p (%container-config-bool taf-result :mount-workdir-p t))
         (host-homedir (%host-homedir taf-result))
         (host-workdir (%host-workdir taf-result))
         (container-home (%container-home-path taf-result))
         (home-bind-covers-workdir-p
           (and mount-homedir-p
                (%apptainer-home-bind-covers-workdir-p host-homedir
                                                       host-workdir
                                                       container-home)))
         (extra-mounts (%ensure-string-list
                        (%container-config-value taf-result :extra-mounts)
                        ":EXTRA-MOUNTS"))
         (args nil))
    (when (and mount-homedir-p host-homedir container-home)
      (setf args
            (append args
                    (list "--no-home"
                          "--bind"
                          (format nil "\"~A:~A\"" host-homedir container-home)))))
    (when (and mount-workdir-p host-workdir (not home-bind-covers-workdir-p))
      (setf args
            (append args
                    (list "--bind"
                          (format nil "\"~A:~A\"" host-workdir host-workdir)))))
    (dolist (mount extra-mounts)
      (setf args
            (append args
                    (list "--bind"
                          (format nil "\"~A\"" mount)))))
    args))

(defun %apptainer-config-exec-args-list (taf-result)
  (let ((value (%container-config-value taf-result :apptainer-exec-args)))
    (%ensure-string-list value :apptainer-exec-args)))

(defun %apptainer-env-exec-args-list (taf-result)
  (let ((value (%container-config-value taf-result :apptainer-env-exec-args)))
    (%ensure-string-list value :apptainer-env-exec-args)))

(defun %apptainer-exec-args-string (parsed-info taf-result)
  (let ((all-args
          (append (%apptainer-default-exec-args-list taf-result)
                  (%apptainer-config-exec-args-list taf-result)
                  (%backend-tag-run-args-list :apptainer parsed-info)
                  (%apptainer-env-exec-args-list taf-result))))
    (if all-args
        (apply #'%join-non-empty-strings all-args)
        "")))

(defun %apptainer-env-prefix (taf-result)
  (let ((pass-user-env-p (%container-config-bool taf-result :pass-user-env-p t))
        (user (%host-user taf-result))
        (container-home (%container-home-path taf-result)))
    (if pass-user-env-p
        (%join-non-empty-strings
         (when container-home
           (format nil "HOME=~S" container-home))
         (when user
           (format nil "USER=~S" user)))
        "")))

(defun %apptainer-sif-name-shell (image)
  (format nil "$(printf '%s' ~S | sed 's#[/:@]#_#g').sif"
          image))

(defun %emit-apptainer (parsed-info lines taf-result)
  (let* ((image (getf parsed-info :image))
         (pull-source (%apptainer-pull-source parsed-info taf-result))
         (workdir (%apptainer-workdir taf-result))
         (image-dirs (%apptainer-image-dirs taf-result))
         (auto-pull-p (%apptainer-auto-pull-p taf-result))
         (apptainer-command (if (%apptainer-quiet-p taf-result)
                                "apptainer --quiet"
                                "apptainer"))
         (force-heredoc-p (getf parsed-info :heredoc-quoted-p))
         (quoted-p (or (%apptainer-heredoc-quoted-p taf-result)
                       force-heredoc-p))
         (heredoc-open (%heredoc-open quoted-p))
         (exec-args-string (%apptainer-exec-args-string parsed-info taf-result))
         (env-prefix (%apptainer-env-prefix taf-result))
         (line-strings (%resolved-lines->strings lines))
         (single-cmd-line-p (and (not force-heredoc-p)
                                 (%single-cmd-line-p line-strings)))
         (debug-run-args (%join-non-empty-strings env-prefix exec-args-string))
         (debug-prelude (%container-debug-prelude
                         :apptainer
                         parsed-info
                         taf-result
                         debug-run-args
                         quoted-p))
         (dir-list-string (format nil "~{~S~^ ~}" image-dirs))
         (mksquashfs-lines
           (when (%string-prefix-p "docker://" pull-source)
             (list "    if command -v mksquashfs >/dev/null 2>&1; then"
                   "        :"
                   "    else"
                   "        echo \"[TAFFISH] mksquashfs not found; apptainer needs squashfs-tools to convert Docker/OCI images to SIF.\" >&2"
                   "        echo \"[TAFFISH] Install squashfs-tools, or pre-create the SIF file at: $taffish_sif_file\" >&2"
                   "        exit 1"
                   "    fi")))
         (pull-lines
           (if auto-pull-p
               (append
                mksquashfs-lines
                (list "    echo \"[TAFFISH] Pull apptainer image: $taffish_pull_ref\" >&2"
                      (format nil "    if ~A pull \"$taffish_sif_file\" \"$taffish_pull_ref\"; then"
                              apptainer-command)
                      "        :"
                      "    else"
                      "        echo \"[TAFFISH] apptainer pull failed: $taffish_pull_ref\" >&2"
                      "        exit 1"
                      "    fi"))
               (list "    echo \"[TAFFISH] apptainer image file not found and auto-pull disabled\" >&2"
                     "    exit 1"))))
    (append
     debug-prelude
     (list
      "if command -v apptainer >/dev/null 2>&1; then"
      "    :"
      "else"
      "    echo \"[TAFFISH] apptainer not found\" >&2"
      "    exit 1"
      "fi"
      ""
      (format nil "taffish_image_ref=~S" image)
      (format nil "taffish_pull_ref=~S" pull-source)
      (format nil "taffish_sif_name=~A" (%apptainer-sif-name-shell image))
      "taffish_sif_file=''"
      ""
      (format nil "for taffish_dir in ~A" dir-list-string)
      "do"
      "    if [ -f \"$taffish_dir/$taffish_sif_name\" ]; then"
      "        taffish_sif_file=\"$taffish_dir/$taffish_sif_name\""
      "        break"
      "    fi"
      "done"
      ""
      "if [ -z \"$taffish_sif_file\" ]; then"
      (format nil "    for taffish_dir in ~A" dir-list-string)
      "    do"
      "        if [ -d \"$taffish_dir\" ]; then"
      "            if [ -w \"$taffish_dir\" ]; then"
      "                taffish_sif_file=\"$taffish_dir/$taffish_sif_name\""
      "                break"
      "            fi"
      "        else"
      "            taffish_parent=\"$(dirname \"$taffish_dir\")\""
      "            if [ -d \"$taffish_parent\" ] && [ -w \"$taffish_parent\" ]; then"
      "                mkdir -p \"$taffish_dir\""
      "                taffish_sif_file=\"$taffish_dir/$taffish_sif_name\""
      "                break"
      "            fi"
      "        fi"
      "    done"
      "fi"
      ""
      "if [ -z \"$taffish_sif_file\" ]; then"
      "    echo \"[TAFFISH] no writable apptainer image directory found\" >&2"
      "    exit 1"
      "fi"
      ""
      "if [ -f \"$taffish_sif_file\" ]; then"
      "    :"
      "else")
     pull-lines
     (list
      "fi"
      ""
      (format nil "~@[~A ~]~A exec --pwd ~S~@[ ~A~] \"$taffish_sif_file\" ~A"
              (and env-prefix
                   (not (string= "" (%clean-string env-prefix)))
                   env-prefix)
              apptainer-command
              workdir
              (and exec-args-string
                   (not (string= "" (%clean-string exec-args-string)))
                   exec-args-string)
              (if single-cmd-line-p
                  single-cmd-line-p
                  heredoc-open)))
     (if single-cmd-line-p
         nil
         line-strings)
     (if single-cmd-line-p
         nil
         (list "EOF")))))

;;;; ============================================================
;;;; container emitter
;;;; ============================================================

(defun emit-container (parsed-info lines taf-result)
  (let* ((backend-kinds (getf parsed-info :backend-kinds))
         (backend (%choose-container-backend backend-kinds taf-result)))
    (unless backend
      (error "No available container backend found. Need one of: ~A"
             (if (member :container backend-kinds :test #'eql)
                 '(:apptainer :podman :docker)
                 backend-kinds)))
    (case backend
      (:docker    (%emit-docker    parsed-info lines taf-result))
      (:podman    (%emit-podman    parsed-info lines taf-result))
      (:apptainer (%emit-apptainer parsed-info lines taf-result))
      (t (error "Unknown container kind: ~A" backend)))))

;;;; ============================================================
;;;; emitter: builtins: container.lisp
;;;; ============================================================

(in-package :taffish.core)

(defemitter container
  :match-function #'taffish.emitter.builtins.container:match-container-tag
  :emit-function #'taffish.emitter.builtins.container:emit-container)
