(in-package :taf.core)

;;;; ============================================================
;;;; project / build.lisp
;;;; ============================================================

(defparameter *build-manifest-schema* "taffish.build/v1")
(defparameter *build-transaction-test-hook* nil)

(defun %build-artifact-name (project)
  (let ((command-name (getf project :command-name))
        (version (getf project :version))
        (release (getf project :release)))
    (dolist (part (list command-name version))
      (when (find #\/ part)
        (%project-error "build-artifact-part"
                        :value (%project-repr part))))
    (%project-format-character-string "~A-v~A-r~A" command-name version release)))

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
      (%project-error "directory-leaf"
                      :path (han.path:->namestring path)))
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

(defun %build-string-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun %build-relative-child-path (prefix leaf)
  (if (%blank-string-p prefix)
      leaf
      (%project-format-character-string "~A/~A" prefix leaf)))

(defun %build-directory-inventory (directory prefix)
  (let ((entries (list (list :directory prefix))))
    (dolist (file (sort (copy-list (han.path:directory-files directory))
                        #'string< :key #'file-namestring))
      (let ((relative (%build-relative-child-path
                       prefix (file-namestring file))))
        (push (list :file relative (%project-sha256-file file)) entries)))
    (dolist (subdir (sort (copy-list (han.path:subdirectories directory))
                          #'string< :key #'%directory-leaf-name))
      (setf entries
            (nconc (%build-directory-inventory
                    subdir
                    (%build-relative-child-path
                     prefix (%directory-leaf-name subdir)))
                   entries)))
    entries))

(defun %build-inventory-entry< (left right)
  (let ((left-path (second left))
        (right-path (second right)))
    (if (string= left-path right-path)
        (string< (symbol-name (first left))
                 (symbol-name (first right)))
        (string< left-path right-path))))

(defun %build-inventory-digest (entries)
  (let ((canonical
          (han.host:with-character-output-to-string (out)
            (dolist (entry (sort (copy-list entries)
                                 #'%build-inventory-entry<))
              (ecase (first entry)
                (:directory
                 (format out "D:~D:~A~%"
                         (length (second entry)) (second entry)))
                (:file
                 (format out "F:~D:~A:~A~%"
                         (length (second entry)) (second entry)
                         (third entry))))))))
    (%project-sha256-string canonical)))

(defun %build-source-inventory (project)
  (let* ((root (getf project :root-dir))
         (src-dir (han.path:join-path root "src"))
         (docs-dir (han.path:join-path root "docs"))
         (main-path (getf project :main-path))
         (entries
           (list (list :file "taffish.toml"
                       (%project-sha256-file
                        (han.path:join-path root "taffish.toml"))))))
    (when (han.path:directory-exists-p src-dir)
      (setf entries
            (nconc (%build-directory-inventory src-dir "src") entries)))
    (when (han.path:directory-exists-p docs-dir)
      (setf entries
            (nconc (%build-directory-inventory docs-dir "docs") entries)))
    (unless (or (string= main-path "taffish.toml")
                (%build-string-prefix-p "src/" main-path)
                (%build-string-prefix-p "docs/" main-path))
      (push (list :file main-path
                  (%project-sha256-file
                   (han.path:join-path root main-path)))
            entries))
    entries))

(defun %build-snapshot-inventory (snapshot-dir)
  (let ((entries nil))
    (dolist (file (sort (copy-list (han.path:directory-files snapshot-dir))
                        #'string< :key #'file-namestring))
      (let ((name (file-namestring file)))
        (unless (string= name ".taf-build.json")
          (push (list :file name (%project-sha256-file file)) entries))))
    (dolist (subdir (sort (copy-list (han.path:subdirectories snapshot-dir))
                          #'string< :key #'%directory-leaf-name))
      (setf entries
            (nconc (%build-directory-inventory
                    subdir (%directory-leaf-name subdir))
                   entries)))
    entries))

(defun %build-source-digest (project)
  (%build-inventory-digest (%build-source-inventory project)))

(defun %build-snapshot-digest (snapshot-dir)
  (%build-inventory-digest (%build-snapshot-inventory snapshot-dir)))

(defun %build-manifest-file (snapshot-dir)
  (han.path:join-path snapshot-dir ".taf-build.json"))

(defun %build-manifest-object (artifact-name source-digest wrapper-digest)
  (han.json:json-object
   (cons "schema" *build-manifest-schema*)
   (cons "artifact" artifact-name)
   (cons "source_sha256" source-digest)
   (cons "wrapper_sha256" wrapper-digest)))

(defun %build-write-manifest
    (snapshot-dir artifact-name source-digest wrapper-digest)
  (han.json:write-json-file
   (%build-manifest-file snapshot-dir)
   (%build-manifest-object artifact-name source-digest wrapper-digest)
   :indent 2))

(defun %build-read-manifest (snapshot-dir)
  (let ((path (%build-manifest-file snapshot-dir)))
    (when (han.path:file-exists-p path)
      (handler-case
          (han.json:read-json-file path)
        (error () nil)))))

(defun %build-manifest-string (manifest key)
  (let ((value (and manifest (han.json:get-json manifest key))))
    (and (stringp value) value)))

(defun %build-executable-p (path)
  (let ((test (han.os:find-executable "test")))
    (and test
         (multiple-value-bind (out err code)
             (han.os:run-program (list test "-x" (han.path:->namestring path)))
           (declare (ignore out err))
           (and (integerp code) (= code 0))))))

(defun %build-artifacts-current-p
    (artifact-name command-file snapshot-dir source-digest wrapper-digest)
  (and (han.path:file-exists-p command-file)
       (han.path:directory-exists-p snapshot-dir)
       (%build-executable-p command-file)
       (let ((manifest (%build-read-manifest snapshot-dir)))
         (and manifest
              (string= (or (%build-manifest-string manifest "schema") "")
                       *build-manifest-schema*)
              (string= (or (%build-manifest-string manifest "artifact") "")
                       artifact-name)
              (string= (or (%build-manifest-string
                            manifest "source_sha256") "")
                       source-digest)
              (string= (or (%build-manifest-string
                            manifest "wrapper_sha256") "")
                       wrapper-digest)
              (string= (%project-sha256-file command-file) wrapper-digest)
              (string= (%build-snapshot-digest snapshot-dir)
                       source-digest)))))

(defun %build-unique-token ()
  (%project-format-character-string "~36R-~36R-~A"
          (get-universal-time)
          (get-internal-real-time)
          (symbol-name (gensym "B"))))

(defun %build-delete-path (path)
  (cond
    ((han.path:directory-exists-p path)
     (han.path:delete-directory-tree path
                                     :validate t
                                     :if-does-not-exist :ignore))
    ((han.path:file-exists-p path)
     (delete-file path)))
  nil)

(defun %rename-to-exact-path (source target directory-p)
  (if directory-p
      (rename-file (han.path:directory-pathname source)
                   (han.path:directory-pathname target))
      (let ((old (han.path:->pathname source))
            (new (han.path:->pathname target)))
        ;; RENAME-FILE fills missing target components from the source. For
        ;; an extensionless target, keep the old suffix in the filename itself
        ;; so there is no type to inherit (or :UNSPECIFIC to print).
        (when (and (null (pathname-type new)) (stringp (pathname-type old)))
          (setf old (make-pathname :name (concatenate 'string (pathname-name old)
                                                      "." (pathname-type old))
                                   :type nil :defaults old)))
        (rename-file old new))))

(defun %build-path-exists-p (path directory-p)
  (if directory-p
      (han.path:directory-exists-p path)
      (han.path:file-exists-p path)))

(defun %build-rename-path (source target directory-p)
  (multiple-value-bind (defaulted-target old-truename actual-target)
      (%rename-to-exact-path source target directory-p)
    (declare (ignore old-truename))
    (let ((actual (or actual-target defaulted-target target)))
      (unless (%build-path-exists-p target directory-p)
        (ignore-errors (%build-delete-path actual))
        (%project-error "build-rename-invalid"
                        :source (han.path:->namestring source)
                        :target (han.path:->namestring target)
                        :actual (han.path:->namestring actual)))
      actual)))

(defun %build-matching-target-paths (target-dir prefix directory-p)
  (let ((paths (if directory-p
                   (han.path:subdirectories target-dir)
                   (han.path:directory-files target-dir))))
    (remove-if-not
     (lambda (path)
       (%build-string-prefix-p
        prefix
        (if directory-p
            (%directory-leaf-name path)
            (file-namestring path))))
     paths)))

(defun %build-matching-target-paths-for-prefixes
    (target-dir prefixes directory-p)
  (remove-duplicates
   (mapcan (lambda (prefix)
             (%build-matching-target-paths target-dir prefix directory-p))
           prefixes)
   :test #'equal
   :key #'han.path:->namestring))

(defun %build-clean-stale-paths
    (target-dir artifact-name command-file snapshot-dir)
  (labels ((sort-key (path)
             (let ((name (if (han.path:directory-pathname-p path)
                             (%directory-leaf-name path)
                             (file-namestring path))))
               (if (and (> (length name) 0)
                        (char= (char name 0) #\.))
                   (subseq name 1)
                   name)))
           (clean (prefixes directory-p final-path)
             (let ((paths (%build-matching-target-paths-for-prefixes
                           target-dir prefixes directory-p)))
               (if (or (null paths)
                       (han.path:file-exists-p final-path)
                       (han.path:directory-exists-p final-path))
                   (dolist (path paths)
                     (%build-delete-path path))
                   (let* ((sorted
                            (sort (copy-list paths) #'string>
                                  :key #'sort-key))
                          (restore (first sorted)))
                     (%build-rename-path restore final-path directory-p)
                     (dolist (path (rest sorted))
                       (%build-delete-path path)))))))
    (dolist (path (%build-matching-target-paths
                   target-dir
                   (%project-format-character-string ".~A.build-tmp-" artifact-name) t))
      (%build-delete-path path))
    (dolist (path (%build-matching-target-paths-for-prefixes
                   target-dir
                   (list (%project-format-character-string ".~A.wrapper-tmp-" artifact-name)
                         (%project-format-character-string "~A.wrapper-tmp-" artifact-name))
                   nil))
      (%build-delete-path path))
    (clean (list (%project-format-character-string ".~A.build-backup-" artifact-name))
           t snapshot-dir)
    (clean (list (%project-format-character-string ".~A.wrapper-backup-" artifact-name)
                 (%project-format-character-string "~A.wrapper-backup-" artifact-name))
           nil command-file)))

(defun %build-transaction-checkpoint (stage)
  (when *build-transaction-test-hook*
    (funcall *build-transaction-test-hook* stage)))

(defun %build-install-staged-artifacts
    (staged-command staged-snapshot command-file snapshot-dir
     backup-command backup-snapshot validate-installed)
  (let ((snapshot-backed-up-p nil)
        (command-backed-up-p nil)
        (snapshot-installed-p nil)
        (command-installed-p nil)
        (committed-p nil))
    (unwind-protect
         (progn
           (when (han.path:directory-exists-p snapshot-dir)
             (%build-rename-path snapshot-dir backup-snapshot t)
             (setf snapshot-backed-up-p t))
           (when (han.path:file-exists-p command-file)
             (%build-rename-path command-file backup-command nil)
             (setf command-backed-up-p t))
           (%build-transaction-checkpoint :backed-up)
           (%build-rename-path staged-snapshot snapshot-dir t)
           (setf snapshot-installed-p t)
           (%build-transaction-checkpoint :snapshot-installed)
           (%build-rename-path staged-command command-file nil)
           (setf command-installed-p t)
           (%build-transaction-checkpoint :wrapper-installed)
           (unless (funcall validate-installed)
             (%project-error "build-commit-invalid"
                             :artifact (file-namestring command-file)))
           (%build-transaction-checkpoint :validated)
           (setf committed-p t))
      (unless committed-p
        (when command-installed-p
          (ignore-errors (%build-delete-path command-file)))
        (when snapshot-installed-p
          (ignore-errors (%build-delete-path snapshot-dir)))
        (when (and command-backed-up-p
                   (han.path:file-exists-p backup-command))
          (ignore-errors
            (%build-rename-path backup-command command-file nil)))
        (when (and snapshot-backed-up-p
                   (han.path:directory-exists-p backup-snapshot))
          (ignore-errors
            (%build-rename-path backup-snapshot snapshot-dir t)))))
    (when committed-p
      (ignore-errors (%build-delete-path backup-command))
      (ignore-errors (%build-delete-path backup-snapshot)))
    committed-p))

(defun %replace-directory (dir)
  (when (han.path:directory-exists-p (han.path:directory-pathname dir))
    (han.path:delete-directory-tree (han.path:directory-pathname dir)
                                :validate t
                                :if-does-not-exist :ignore))
  (%make-dir dir))

(defun %chmod-executable (path)
  (let* ((namestring (han.path:->namestring path))
         (chmod (han.os:find-executable "chmod")))
    (unless chmod
      (%project-error "build-chmod"
                      :path namestring
                      :detail "chmod executable not found"))
    (multiple-value-bind (out err code)
        (han.os:run-program (list chmod "+x" namestring))
      (unless (and (integerp code) (= code 0))
        (%project-error "build-chmod"
                        :path namestring
                        :detail (%project-format-character-string
                                 "~A~A" (or out "") (or err "")))))))

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
    (%project-format-character-string "#!/bin/sh

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

taf_record_history_call() {
    taf_status=\"$1\"
    taf_exit=\"$2\"
    taf_stage=\"$3\"
    shift 3

    # NUL-delimited fields keep empty arguments, quotes, and newlines intact.
    printf '%s\\000' \"$$\" \"$(pwd)\" \"$artifact_name\" \"$project_name\" \"$project_kind\" \\
        \"$project_version\" \"$project_release\" \"$project_command\" \"$snapshot_root\" \\
        \"$taf_main\" \"$project_repository_url\" \"$project_container_image\" \\
        \"$taf_status\" \"$taf_exit\" \"$taf_stage\" \"$#\" \"$@\" |
        TAFFISH_INTERNAL_HISTORY_FILE=\"$taf_history_file\" \\
        \"$taffish_bin\" --taffish-wrapper-history || :
}

taf_record_history() {
    if [ \"$taf_history_mode\" = \"off\" ] || [ \"$taf_history_mode\" = \"0\" ]; then
        return 0
    fi
    if [ \"$taf_history_mode\" = \"sync\" ]; then
        taf_record_history_call \"$@\" </dev/null >/dev/null 2>&1
    else
        (
            # Redirect the subshell itself: dash saves fds for function-local redirections.
            exec </dev/null >/dev/null 2>&1
            taf_record_history_call \"$@\"
        ) &
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
             (%project-format-character-string "\"~{~A~}\"" (nreverse chars)))
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
                            (%project-format-character-string "[~{~A~^, ~}]"
                                    (mapcar #'%build-toml-quote versions)))))
            (%project-format-character-string "~A = ~A" command value)))
        (nreverse order))))))

(defun %build-lines-string (lines)
  (%project-format-character-string "~{~A~%~}" lines))

(defun %build-rewrite-dependencies-section (toml-path dependencies)
  (let* ((current (han.os:load-string toml-path))
         (lines (%build-remove-toml-section
                 (han.os:load-lines toml-path)
                 "dependencies")))
    (when dependencies
      (when (and lines
                 (not (%blank-string-p (car (last lines)))))
        (setf lines (append lines (list ""))))
      (setf lines
            (append lines
                    (%build-dependencies-section-lines dependencies))))
    (let ((updated (%build-lines-string lines)))
      (unless (string= current updated)
        (%write-string-to-file/supersede toml-path updated)))))

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
         (snapshot-name (%project-format-character-string ".~A" artifact-name))
         (snapshot-dir (han.path:join-path target-dir snapshot-name))
         (command-file (han.path:join-path target-dir artifact-name))
         (main-path (getf project :main-path)))
    (%make-dir target-dir)
    (%operation-stage "inspect-build" :target artifact-name :defer-p t)
    (let* ((dependencies (%build-sync-flow-dependencies project))
           (source-digest (%build-source-digest project))
           (wrapper-string
             (%make-build-wrapper-string
              project snapshot-name main-path artifact-name))
           (wrapper-digest (%project-sha256-string wrapper-string))
           (manifest-file (%build-manifest-file snapshot-dir)))
      (%build-clean-stale-paths
       target-dir artifact-name command-file snapshot-dir)
      (if (%build-artifacts-current-p
           artifact-name command-file snapshot-dir
           source-digest wrapper-digest)
          (list :command-file (han.path:->namestring command-file)
                :snapshot-dir (han.path:->namestring snapshot-dir)
                :artifact-name artifact-name
                :dependencies dependencies
                :status :up-to-date
                :source-sha256 source-digest
                :wrapper-sha256 wrapper-digest
                :manifest-file (han.path:->namestring manifest-file))
          (let* ((token (%build-unique-token))
                 (staged-snapshot
                   (han.path:join-path
                    target-dir
                    (%project-format-character-string ".~A.build-tmp-~A" artifact-name token)))
                 (staged-command
                   (han.path:join-path
                    target-dir
                    (%project-format-character-string ".~A.wrapper-tmp-~A" artifact-name token)))
                 (backup-snapshot
                   (han.path:join-path
                    target-dir
                    (%project-format-character-string ".~A.build-backup-~A" artifact-name token)))
                 (backup-command
                   (han.path:join-path
                    target-dir
                    (%project-format-character-string ".~A.wrapper-backup-~A" artifact-name token))))
            (unwind-protect
                 (progn
                   (%operation-stage "snapshot" :target artifact-name :defer-p t)
                   (%snapshot-project-source project staged-snapshot)
                   (%operation-stage "wrapper" :target artifact-name :defer-p t)
                   (%write-string-to-file/supersede
                    staged-command wrapper-string)
                   (%chmod-executable staged-command)
                   (%build-write-manifest
                    staged-snapshot artifact-name source-digest wrapper-digest)
                   (unless (%build-artifacts-current-p
                            artifact-name staged-command staged-snapshot
                            source-digest wrapper-digest)
                     (%project-error "build-staging-invalid"
                                     :artifact artifact-name))
                   (%build-transaction-checkpoint :staged)
                   (%build-install-staged-artifacts
                    staged-command staged-snapshot command-file snapshot-dir
                    backup-command backup-snapshot
                    (lambda ()
                      (%build-artifacts-current-p
                       artifact-name command-file snapshot-dir
                       source-digest wrapper-digest)))
                   (list :command-file (han.path:->namestring command-file)
                         :snapshot-dir (han.path:->namestring snapshot-dir)
                         :artifact-name artifact-name
                         :dependencies dependencies
                         :status :rebuilt
                         :source-sha256 source-digest
                         :wrapper-sha256 wrapper-digest
                         :manifest-file
                         (han.path:->namestring manifest-file)))
              (ignore-errors (%build-delete-path staged-command))
              (ignore-errors (%build-delete-path staged-snapshot))
              (when (and (han.path:file-exists-p backup-command)
                         (not (han.path:file-exists-p command-file)))
                (ignore-errors
                  (%build-rename-path backup-command command-file nil)))
              (when (and (han.path:directory-exists-p backup-snapshot)
                         (not (han.path:directory-exists-p snapshot-dir)))
                (ignore-errors
                  (%build-rename-path backup-snapshot snapshot-dir t)))))))))

(defun %normalize-build-backend (backend)
  (cond
    ((null backend) nil)
    ((member backend '("docker" "podman") :test #'string-equal)
     (string-downcase backend))
    (t
     (%project-error "build-backend" :value (%project-repr backend)))))

(defun %select-build-backend (backend)
  (or (%normalize-build-backend backend)
      (cond
        ((han.os:find-executable "docker") "docker")
        ((han.os:find-executable "podman") "podman")
        (t
         (%project-error "build-no-backend")))))

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
      (%project-error "build-image-missing"))
    (unless dockerfile
      (%project-error "build-dockerfile-missing"))
    (let* ((selected-backend (%select-build-backend backend))
           (dockerfile-path (han.path:join-path root dockerfile))
           (command (%project-format-character-string "~A build -t ~A -f ~A ~A"
                            (han.os:escape-sh-token selected-backend)
                            (han.os:escape-sh-token image)
                            (han.os:escape-sh-token
                             (han.path:->namestring dockerfile-path))
                            (han.os:escape-sh-token root))))
      (when verbose
        (%project-print-message "build.building-image"
                                :image image :backend selected-backend)
        (%project-print-message "build.command" :command command)
        (finish-output))
      (multiple-value-bind (out err code)
          (%run-build-command command verbose)
        (unless (and (integerp code) (= code 0))
          (%project-error "build-image-failed"
                          :code code
                          :detail (%project-format-character-string "~A~A" out err)))
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
  (%with-operation-progress (verbose)
  (unless (or command-p image-p)
    (%project-error "build-nothing"))
  (let* ((project (project-check start-dir nil nil))
         (image-result nil)
         (command-result nil))
    (when image-p
      (%operation-progress-yield)
      (setf image-result (%build-container-image project backend
                                                 :verbose verbose)))
    (when command-p
      (setf command-result (%build-command-wrapper project
                                                  :user-home user-home
                                                  :system-home system-home
                                                  :verbose verbose)))
    (when command-result
      (%operation-stage "verify" :target (getf project :name) :defer-p t)
      (setf project (project-check start-dir nil)))
    (when verbose
      (%operation-progress-yield)
      (when command-result
        (%project-print-message
         (if (eql (getf command-result :status) :up-to-date)
             "build.command-current"
             "build.built-command")
         :path (getf command-result :command-file)))
      (when (getf command-result :dependencies)
        (%project-print-message
         "build.synced-dependencies"
         :count (length (getf command-result :dependencies))))
      (when image-result
        (%project-print-message "build.built-image"
                                :image (getf image-result :image)
                                :backend (getf image-result :backend))))
    (list :project project
          :command command-result
          :image image-result))))
