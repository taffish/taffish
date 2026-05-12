(in-package :taf.core)

;;;; ============================================================
;;;; project / build.lisp
;;;; ============================================================

(defun %build-artifact-name (project)
  (let ((command-name (getf project :command-name))
        (version (getf project :version))
        (release (getf project :release)))
    (dolist (part (list command-name version))
      (when (find #\/ part)
        (error "[build] build artifact name part must not contain '/': ~S"
               part)))
    (format nil "~A-v~A-r~A" command-name version release)))

(defun %write-string-to-file/supersede (filespec string)
  (with-open-file (out filespec :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create)
    (format out "~A" string)))

(defun %copy-file/supersede (source target)
  (ensure-directories-exist target)
  (when (han.path:file-exists-p target)
    (delete-file target))
  (han.path:copy-file source target))

(defun %directory-leaf-name (dir)
  (let* ((path (han.path:directory-pathname dir))
         (parts (pathname-directory path))
         (leaf (car (last parts))))
    (unless (and (stringp leaf)
                 (> (length leaf) 0))
      (error "Can't determine directory leaf name: ~A"
             (han.path:->namestring path)))
    leaf))

(defun %copy-directory-tree/supersede (source-dir target-dir)
  (%make-dir target-dir)
  (dolist (file (han.path:directory-files (han.path:directory-pathname source-dir)))
    (%copy-file/supersede
     file
     (han.path:join-path target-dir (file-namestring file))))
  (dolist (dir (han.path:subdirectories (han.path:directory-pathname source-dir)))
    (%copy-directory-tree/supersede
     dir
     (han.path:join-path target-dir (%directory-leaf-name dir)))))

(defun %replace-directory (dir)
  (when (han.path:directory-exists-p (han.path:directory-pathname dir))
    (han.path:delete-directory-tree (han.path:directory-pathname dir)
                                :validate t
                                :if-does-not-exist :ignore))
  (%make-dir dir))

(defun %chmod-executable (path)
  (multiple-value-bind (out err code)
      (han.os:run-shell-command
       (format nil "chmod +x ~A"
               (han.os:escape-sh-token (han.path:->namestring path)))
       :wait t
       :lines t)
    (unless (and (integerp code) (= code 0))
      (error "[build] chmod failed: ~A~%~{~A~%~}~{~A~%~}"
             (han.path:->namestring path) out err))))

(defun %build-shell-token (value)
  (han.os:escape-sh-token (princ-to-string (or value ""))))

(defun %snapshot-project-source (project snapshot-dir)
  (let* ((root (getf project :root-dir))
         (main-path (getf project :main-path))
         (src-dir (han.path:join-path root "src"))
         (docs-dir (han.path:join-path root "docs"))
         (snapshot-src-dir (han.path:join-path snapshot-dir "src"))
         (snapshot-docs-dir (han.path:join-path snapshot-dir "docs"))
         (snapshot-main-file (han.path:join-path snapshot-dir main-path)))
    (%replace-directory snapshot-dir)
    (%copy-file/supersede
     (han.path:join-path root "taffish.toml")
     (han.path:join-path snapshot-dir "taffish.toml"))
    (when (han.path:directory-exists-p (han.path:directory-pathname src-dir))
      (%copy-directory-tree/supersede src-dir snapshot-src-dir))
    (when (han.path:directory-exists-p (han.path:directory-pathname docs-dir))
      (%copy-directory-tree/supersede docs-dir snapshot-docs-dir))
    (unless (%project-file-exists-p snapshot-main-file)
      (%copy-file/supersede
       (han.path:join-path root main-path)
       snapshot-main-file))))

(defun %make-build-wrapper-string (project snapshot-name main-path artifact-name)
  (let ((project-name (getf project :name))
        (project-kind (getf project :kind))
        (project-version (getf project :version))
        (project-release (getf project :release))
        (project-command (getf project :command-name))
        (repository-url (getf project :repository-url))
        (container-image (getf project :container-image)))
    (format nil "#!/bin/sh

set -u

script_dir=$(CDPATH= cd \"$(dirname \"$0\")\" && pwd) || exit 1
snapshot_root=\"$script_dir/~A\"
taf_main=\"$snapshot_root/~A\"
taf_help=\"$snapshot_root/docs/help.md\"
taffish_bin=\"${TAFFISH:-taffish}\"
taf_history_mode=\"${TAF_HISTORY_MODE:-async}\"
taf_history_home=\"${TAFFISH_USER_HOME:-${HOME:-}/.local/share/taffish}\"
taf_history_file=\"${TAF_HISTORY_FILE:-$taf_history_home/logs/history.jsonl}\"

artifact_name=~A
project_name=~A
project_kind=~A
project_version=~A
project_release=~A
project_command=~A
project_repository_url=~A
project_container_image=~A
taf_launcher_name=\"${TAF_LAUNCHER_NAME:-$artifact_name}\"
taf_launcher_artifact=\"${TAF_LAUNCHER_ARTIFACT:-$artifact_name}\"

taf_json_escape() {
    printf '%s' \"$1\" | awk '
        BEGIN {
            ORS = \"\"
            tab = sprintf(\"%c\", 9)
            cr = sprintf(\"%c\", 13)
        }
        {
            gsub(/\\\\/, \"\\\\\\\\\")
            gsub(/\"/, \"\\\\\\\"\")
            gsub(tab, \"\\\\t\")
            gsub(cr, \"\\\\r\")
            if (NR > 1) {
                printf \"\\\\n\"
            }
            printf \"%s\", $0
        }
    '
}

taf_json_string() {
    printf '\"%s\"' \"$(taf_json_escape \"$1\")\"
}

taf_json_nullable_string() {
    if [ -n \"$1\" ]; then
        taf_json_string \"$1\"
    else
        printf 'null'
    fi
}

taf_history_args_json() {
    taf_first=1
    printf '['
    for taf_arg do
        if [ \"$taf_first\" = 1 ]; then
            taf_first=0
        else
            printf ','
        fi
        taf_json_string \"$taf_arg\"
    done
    printf ']'
}

taf_record_history_call() {
    taf_status=\"$1\"
    taf_exit=\"$2\"
    taf_stage=\"$3\"
    shift 3

    if [ -z \"$taf_history_file\" ]; then
        return 0
    fi

    taf_history_dir=$(dirname \"$taf_history_file\") || return 0
    mkdir -p \"$taf_history_dir\" 2>/dev/null || return 0

    taf_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')
    taf_id=\"$(date -u '+%Y%m%dT%H%M%S' 2>/dev/null || date '+%Y%m%dT%H%M%S')-$$\"
    taf_cwd=$(pwd)
    taf_args_json=$(taf_history_args_json \"$@\")

    {
        printf '{'
        printf '\"id\":'; taf_json_string \"$taf_id\"; printf ','
        printf '\"time\":'; taf_json_string \"$taf_time\"; printf ','
        printf '\"event\":\"exec\",'
        printf '\"status\":'; taf_json_string \"$taf_status\"; printf ','
        printf '\"command\":'; taf_json_string \"$artifact_name\"; printf ','
        printf '\"args\":%s,' \"$taf_args_json\"
        printf '\"cwd\":'; taf_json_string \"$taf_cwd\"; printf ','
        printf '\"exit_code\":%s,' \"$taf_exit\"
        printf '\"project_name\":'; taf_json_string \"$project_name\"; printf ','
        printf '\"project_kind\":'; taf_json_string \"$project_kind\"; printf ','
        printf '\"project_version\":'; taf_json_string \"$project_version\"; printf ','
        printf '\"project_release\":'; taf_json_string \"$project_release\"; printf ','
        printf '\"project_command\":'; taf_json_string \"$project_command\"; printf ','
        printf '\"project_root\":'; taf_json_string \"$snapshot_root\"; printf ','
        printf '\"project_main\":'; taf_json_string \"$taf_main\"; printf ','
        printf '\"repository_url\":'; taf_json_nullable_string \"$project_repository_url\"; printf ','
        printf '\"container_image\":'; taf_json_nullable_string \"$project_container_image\"; printf ','
        printf '\"stage\":'; taf_json_string \"$taf_stage\"; printf ','
        printf '\"snapshot_root\":'; taf_json_string \"$snapshot_root\"; printf ','
        printf '\"history_backend\":\"shell-wrapper\"'
        printf '}\\n'
    } >> \"$taf_history_file\" 2>/dev/null || true
}

taf_record_history() {
    if [ \"$taf_history_mode\" = \"off\" ] || [ \"$taf_history_mode\" = \"0\" ]; then
        return 0
    fi
    if [ \"$taf_history_mode\" = \"sync\" ]; then
        taf_record_history_call \"$@\"
    else
        taf_record_history_call \"$@\" &
    fi
}

if [ \"${1:-}\" = \"--\" ]; then
    shift
elif [ \"${1:-}\" = \"-v\" ] || [ \"${1:-}\" = \"--version\" ]; then
    if [ \"$taf_launcher_name\" != \"$taf_launcher_artifact\" ]; then
        printf '%s -> %s\\n' \"$taf_launcher_name\" \"$taf_launcher_artifact\"
    else
        printf '%s\\n' \"$taf_launcher_artifact\"
    fi
    printf 'package: %s\\n' \"$project_name\"
    printf 'version: %s-r%s\\n' \"$project_version\" \"$project_release\"
    printf 'kind: %s\\n' \"$project_kind\"
    printf 'repository: %s\\n' \"$project_repository_url\"
    exit 0
elif [ \"${1:-}\" = \"--compile\" ]; then
    shift
    exec \"$taffish_bin\" \"$taf_main\" \"$@\"
elif [ \"${1:-}\" = \"-h\" ] || [ \"${1:-}\" = \"--help\" ]; then
    if [ -f \"$taf_help\" ]; then
        cat \"$taf_help\"
        exit 0
    fi
    echo \"help file not found: $taf_help\" >&2
    exit 1
fi

taf_tmpdir=$(mktemp -d \"${TMPDIR:-/tmp}/taffish.XXXXXX\") || exit 1
trap 'rm -rf \"$taf_tmpdir\"' EXIT INT TERM HUP

taf_shell=\"$taf_tmpdir/taf.sh\"
\"$taffish_bin\" \"$taf_main\" \"$@\" > \"$taf_shell\"
taf_exit=$?
if [ \"$taf_exit\" -ne 0 ]; then
    taf_record_history failure \"$taf_exit\" compile \"$@\"
    exit \"$taf_exit\"
fi

chmod +x \"$taf_shell\"
taf_exit=$?
if [ \"$taf_exit\" -ne 0 ]; then
    taf_record_history failure \"$taf_exit\" chmod \"$@\"
    exit \"$taf_exit\"
fi

\"$taf_shell\"
taf_exit=$?

if [ \"$taf_exit\" -eq 0 ]; then
    taf_record_history success \"$taf_exit\" run \"$@\"
else
    taf_record_history failure \"$taf_exit\" run \"$@\"
fi

exit \"$taf_exit\"
"
            snapshot-name
            main-path
            (%build-shell-token artifact-name)
            (%build-shell-token project-name)
            (%build-shell-token project-kind)
            (%build-shell-token project-version)
            (%build-shell-token project-release)
            (%build-shell-token project-command)
            (%build-shell-token repository-url)
            (%build-shell-token container-image))))

(defun %build-toml-quote (string)
  (let ((chars nil))
    (dolist (char (coerce (princ-to-string string) 'list)
             (format nil "\"~{~A~}\"" (nreverse chars)))
      (case char
        (#\\ (push "\\\\" chars))
        (#\" (push "\\\"" chars))
        (t (push char chars))))))

(defun %build-remove-toml-section (lines section-name)
  (let ((result nil)
        (skip-p nil))
    (dolist (line lines)
      (let ((clean (%trim-string line)))
        (cond
          ((%toml-section-line-p clean)
           (let ((current (%toml-section-name clean)))
             (setf skip-p (string= current section-name))
             (unless skip-p
               (push line result))))
          ((not skip-p)
           (push line result)))))
    (nreverse result)))

(defun %build-dependencies-section-lines (dependencies)
  (when dependencies
    (let ((groups nil)
          (order nil))
      (dolist (dep dependencies)
        (let* ((command (getf dep :command))
               (version (getf dep :version))
               (pair (assoc command groups :test #'string=)))
          (unless pair
            (setf pair (cons command nil))
            (push pair groups)
            (push command order))
          (unless (member version (cdr pair) :test #'string=)
            (setf (cdr pair) (append (cdr pair) (list version))))))
      (append
       (list "[dependencies]")
       (mapcar
        (lambda (command)
          (let* ((versions (cdr (assoc command groups :test #'string=)))
                 (value (if (and versions (null (cdr versions)))
                            (%build-toml-quote (car versions))
                            (format nil "[~{~A~^, ~}]"
                                    (mapcar #'%build-toml-quote versions)))))
            (format nil "~A = ~A" command value)))
        (nreverse order))))))

(defun %build-lines-string (lines)
  (format nil "~{~A~%~}" lines))

(defun %build-rewrite-dependencies-section (toml-path dependencies)
  (let ((lines (%build-remove-toml-section
                (han.os:load-lines toml-path)
                "dependencies")))
    (when dependencies
      (when (and lines
                 (not (%blank-string-p (car (last lines)))))
        (setf lines (append lines (list ""))))
      (setf lines
            (append lines
                    (%build-dependencies-section-lines dependencies))))
    (%write-string-to-file/supersede toml-path (%build-lines-string lines))))

(defun %build-sync-flow-dependencies (project)
  (when (eql (getf project :kind) :flow)
    (let* ((toml-path (getf project :toml-file))
           (queries (%flow-dependency-queries project :error-prefix "[build]"))
           (existing (%dependency-alist-from-toml-file
                      toml-path
                      :error-prefix "[build]"))
           (dependencies (%normalized-flow-dependencies
                          queries
                          existing
                          :error-prefix "[build]")))
      (%build-rewrite-dependencies-section toml-path dependencies)
      dependencies)))

(defun %build-command-wrapper (project &key user-home system-home (verbose t))
  (declare (ignore user-home system-home verbose))
  (let* ((target-dir (getf project :target-dir))
         (artifact-name (%build-artifact-name project))
         (snapshot-name (format nil ".~A" artifact-name))
         (snapshot-dir (han.path:join-path target-dir snapshot-name))
         (command-file (han.path:join-path target-dir artifact-name))
         (main-path (getf project :main-path)))
    (%make-dir target-dir)
    (let ((dependencies (%build-sync-flow-dependencies project)))
      (%snapshot-project-source project snapshot-dir)
      (%write-string-to-file/supersede
       command-file
       (%make-build-wrapper-string project snapshot-name main-path artifact-name))
      (%chmod-executable command-file)
      (list :command-file (han.path:->namestring command-file)
            :snapshot-dir (han.path:->namestring snapshot-dir)
            :artifact-name artifact-name
            :dependencies dependencies))))

(defun %normalize-build-backend (backend)
  (cond
    ((null backend) nil)
    ((member backend '("docker" "podman") :test #'string-equal)
     (string-downcase backend))
    (t
     (error "[build] image backend must be docker or podman, but got: ~S"
            backend))))

(defun %select-build-backend (backend)
  (or (%normalize-build-backend backend)
      (cond
        ((han.os:find-executable "docker") "docker")
        ((han.os:find-executable "podman") "podman")
        (t
         (error "[build] can't find docker or podman executable.")))))

(defun %run-build-command (command verbose)
  (if verbose
      (progn
        (finish-output)
        (multiple-value-bind (out err code)
            (han.os:run-program command
                              :output t
                              :error-output t
                              :ignore-error-status t)
          (declare (ignore out err))
          (values nil nil code)))
      (han.os:run-shell-command command :wait t :lines nil)))

(defun %build-container-image (project backend &key (verbose t))
  (let ((image (getf project :container-image))
        (dockerfile (getf project :dockerfile))
        (root (getf project :root-dir)))
    (unless image
      (error "[build] missing [container].image in taffish.toml."))
    (unless dockerfile
      (error "[build] missing [container].dockerfile in taffish.toml."))
    (let* ((selected-backend (%select-build-backend backend))
           (dockerfile-path (han.path:join-path root dockerfile))
           (command (format nil "~A build -t ~A -f ~A ~A"
                            (han.os:escape-sh-token selected-backend)
                            (han.os:escape-sh-token image)
                            (han.os:escape-sh-token
                             (han.path:->namestring dockerfile-path))
                            (han.os:escape-sh-token root))))
      (when verbose
        (format t "[TAF] building image: ~A (~A)~%" image selected-backend)
        (format t "[TAF] build command: ~A~%" command)
        (finish-output))
      (multiple-value-bind (out err code)
          (%run-build-command command verbose)
        (unless (and (integerp code) (= code 0))
          (error "[build] image build failed with ~A.~%~A~A"
                 code out err))
        (list :image image
              :backend selected-backend
              :stdout out
              :stderr err)))))

(defun project-build (&key (command-p t)
                           (image-p nil)
                           backend
                           user-home
                           system-home
                           (start-dir (han.os:current-directory))
                           (verbose t))
  (unless (or command-p image-p)
    (error "[build] nothing to build."))
  (let* ((project (project-check start-dir nil nil))
         (image-result nil)
         (command-result nil))
    (when image-p
      (setf image-result (%build-container-image project backend
                                                 :verbose verbose)))
    (when command-p
      (setf command-result (%build-command-wrapper project
                                                  :user-home user-home
                                                  :system-home system-home
                                                  :verbose verbose)))
    (when command-result
      (setf project (project-check start-dir nil)))
    (when verbose
      (when command-result
        (format t "[TAF] built command: ~A~%"
                (getf command-result :command-file)))
      (when (getf command-result :dependencies)
        (format t "[TAF] synced dependencies: ~A~%"
                (length (getf command-result :dependencies))))
      (when image-result
        (format t "[TAF] built image: ~A (~A)~%"
                (getf image-result :image)
                (getf image-result :backend))))
    (list :project project
          :command command-result
          :image image-result)))
