(in-package :taf.core)

;;;; ============================================================
;;;; project / publish.lisp
;;;; ============================================================

(defun %publish-split-string (string char)
  (let ((out nil)
        (start 0)
        (len (length string)))
    (labels ((emit (end)
               (push (subseq string start end) out)))
      (loop for i from 0 below len do
        (when (char= (char string i) char)
          (emit i)
          (setf start (1+ i))))
      (emit len)
      (nreverse out))))

(defun %publish-string-suffix-p (suffix string &key (test #'char=))
  (and (stringp suffix)
       (stringp string)
       (<= (length suffix) (length string))
       (loop with start = (- (length string) (length suffix))
             for i from 0 below (length suffix)
             always (funcall test
                             (char suffix i)
                             (char string (+ start i))))))

(defun %publish-strip-suffix (suffix string &key (test #'char=))
  (if (%publish-string-suffix-p suffix string :test test)
      (subseq string 0 (- (length string) (length suffix)))
      string))

(defun %publish-strip-trailing-slash (string)
  (if (and (stringp string)
           (> (length string) 1)
           (char= #\/ (char string (1- (length string)))))
      (%publish-strip-trailing-slash (subseq string 0 (1- (length string))))
      string))

(defun %publish-github-path (url)
  (let ((clean (%publish-strip-trailing-slash
                (%publish-strip-suffix ".git" url :test #'char-equal))))
    (cond
      ((%string-prefix-p "https://github.com/" clean)
       (subseq clean (length "https://github.com/")))
      ((%string-prefix-p "git@github.com:" clean)
       (subseq clean (length "git@github.com:")))
      ((%string-prefix-p "ssh://git@github.com/" clean)
       (subseq clean (length "ssh://git@github.com/")))
      (t nil))))

(defun %publish-github-slug (url)
  (let* ((path (%publish-github-path url))
         (parts (and path (%publish-split-string path #\/))))
    (when (and parts (second parts))
      (string-downcase
       (format nil "~A/~A" (first parts) (second parts))))))

(defun %publish-same-repository-p (a b)
  (let ((slug-a (%publish-github-slug a))
        (slug-b (%publish-github-slug b)))
    (and slug-a slug-b (string= slug-a slug-b))))

(defun %publish-tag-name (project)
  (format nil "v~A-r~A"
          (getf project :version)
          (getf project :release)))

(defun %publish-digit-string-p (string)
  (and (stringp string)
       (> (length string) 0)
       (every #'digit-char-p string)))

(defun %publish-version-numbers (version)
  (let ((parts (%publish-split-string version #\.)))
    (when (every #'%publish-digit-string-p parts)
      (mapcar #'parse-integer parts))))

(defun %publish-compare-number-lists (a b)
  (labels ((scan (x y)
             (cond
               ((and (null x) (null y)) 0)
               ((> (or (car x) 0) (or (car y) 0)) 1)
               ((< (or (car x) 0) (or (car y) 0)) -1)
               (t (scan (cdr x) (cdr y))))))
    (scan a b)))

(defun %publish-compare-versions (a b)
  (let ((a-numbers (%publish-version-numbers a))
        (b-numbers (%publish-version-numbers b)))
    (cond
      ((and a-numbers b-numbers)
       (%publish-compare-number-lists a-numbers b-numbers))
      ((string= a b) 0)
      ((string< a b) -1)
      (t 1))))

(defun %publish-compare-version-release
    (version release other-version other-release)
  (let ((version-order (%publish-compare-versions version other-version)))
    (cond
      ((not (= version-order 0)) version-order)
      ((> release other-release) 1)
      ((< release other-release) -1)
      (t 0))))

(defun %publish-last-search (needle string)
  (let ((pos nil)
        (start 0))
    (loop for next = (search needle string :start2 start :test #'char=)
          while next do
            (setf pos next
                  start (1+ next)))
    pos))

(defun %publish-release-info-from-tag (tag)
  (let* ((clean (%publish-strip-suffix "^{}" tag))
         (name (cond
                 ((%string-prefix-p "refs/tags/" clean)
                  (subseq clean (length "refs/tags/")))
                 (t clean)))
         (split (%publish-last-search "-r" name)))
    (when (and split
               (> split 1)
               (char= #\v (char name 0)))
      (let* ((version (subseq name 1 split))
             (release-string (subseq name (+ split 2)))
             (release (ignore-errors
                        (parse-integer release-string :junk-allowed nil))))
        (when (and release (> release 0))
          (list :tag name
                :version version
                :release release))))))

(defun %publish-tag-from-ls-remote-line (line)
  (let* ((tab (position #\Tab line))
         (raw (if tab (subseq line (1+ tab)) line)))
    (%publish-strip-suffix "^{}" raw)))

(defun %publish-unique-strings (strings)
  (let ((out nil))
    (dolist (string strings)
      (unless (member string out :test #'string=)
        (push string out)))
    (nreverse out)))

(defun %publish-release-infos (remote-tags)
  (let ((infos nil))
    (dolist (tag remote-tags)
      (let ((info (%publish-release-info-from-tag tag)))
        (when (and info
                   (not (member (getf info :tag)
                                infos
                                :key (lambda (x) (getf x :tag))
                                :test #'string=)))
          (push info infos))))
    (nreverse infos)))

(defun %publish-latest-info (infos)
  (let ((latest nil))
    (dolist (info infos latest)
      (when (or (null latest)
                (> (%publish-compare-version-release
                    (getf info :version)
                    (getf info :release)
                    (getf latest :version)
                    (getf latest :release))
                   0))
        (setf latest info)))))

(defun %normalize-publish-channel (channel)
  (cond
    ((or (null channel)
         (eql channel :latest)
         (and (stringp channel) (string-equal channel "latest")))
     :latest)
    ((or (eql channel :pre)
         (and (stringp channel) (string-equal channel "pre")))
     :pre)
    (t
     (error "[publish] channel must be latest or pre, but got: ~S" channel))))

(defun %normalize-publish-repo-visibility (visibility)
  (cond
    ((or (null visibility)
         (eql visibility :public)
         (and (stringp visibility) (string-equal visibility "public")))
     :public)
    ((or (eql visibility :private)
         (and (stringp visibility) (string-equal visibility "private")))
     :private)
    (t
     (error "[publish] repository visibility must be public or private, but got: ~S"
            visibility))))

(defun %publish-git-program ()
  (or (han.os:find-executable "git")
      (error "[publish] can't find git executable.")))

(defun %publish-gh-program ()
  (or (han.os:find-executable "gh")
      (error "[publish] can't find gh executable. Install GitHub CLI or create the repository manually.")))

(defun %publish-env-program ()
  (or (han.os:find-executable "env")
      (error "[publish] can't find env executable.")))

(defun %publish-program-argument (program)
  (etypecase program
    (string program)
    (pathname (namestring program))))

(defun %publish-noninteractive-env-args ()
  ;; Never let git ask for GitHub credentials through TAFFISH.
  '("GIT_TERMINAL_PROMPT=0"
    "GIT_ASKPASS="
    "SSH_ASKPASS="
    "GH_PROMPT_DISABLED=1"
    "GH_NO_UPDATE_NOTIFIER=1"
    "GIT_SSH_COMMAND=ssh -o BatchMode=yes"))

(defun %publish-noninteractive-auth-hint ()
  "TAF does not handle GitHub login. Please authenticate GitHub yourself, for example by using an SSH repository URL with a loaded key, configuring a git credential helper, or running `gh auth login` outside TAF.")

(defun %publish-repository-missing-hint (repository-url)
  (format nil "GitHub repository does not exist or is not accessible: ~A. Create it manually or rerun with --create-repo."
          repository-url))

(defun %publish-run-program
    (program args &key (noninteractive nil) (prompt nil) (interactive-output nil))
  (han.os:run-program
   (if noninteractive
       (cons (%publish-env-program)
             (append (%publish-noninteractive-env-args)
                     (cons (%publish-program-argument program) args)))
       (cons program args))
   :input (and prompt t)
   :output (if interactive-output t :string)
   :error-output (if prompt t :string)
   :ignore-error-status t))

(defun %publish-run-git
    (root args &key (noninteractive nil) (prompt nil) (interactive-output nil))
  (%publish-run-program
   (%publish-git-program)
   (append (list "-C" root) args)
   :noninteractive noninteractive
   :prompt prompt
   :interactive-output interactive-output))

(defun %publish-run-git/checked
    (root args &key (noninteractive nil) (prompt nil) (interactive-output nil))
  (multiple-value-bind (out err code)
      (%publish-run-git root args
                        :noninteractive noninteractive
                        :prompt prompt
                        :interactive-output interactive-output)
    (unless (and (integerp code) (= code 0))
      (error "[publish] git command failed (~A): git -C ~A ~{~A~^ ~}~%~A~A~@[~%~A~]"
             code root args out err
             (and noninteractive
                  (%publish-noninteractive-auth-hint))))
    (values out err code)))

(defun %publish-string-lines (string)
  (let ((out nil))
    (with-input-from-string (in (or string ""))
      (loop for line = (read-line in nil nil)
            while line do
              (push line out)))
    (nreverse out)))

(defun %publish-trim-output (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return) (or string "")))

(defun %publish-output-contains-p (needle out err)
  (not
   (null
    (or (and out (search needle out :test #'char-equal))
        (and err (search needle err :test #'char-equal))))))

(defun %publish-repository-not-found-output-p (out err)
  (or (%publish-output-contains-p "Repository not found" out err)
      (%publish-output-contains-p "Could not resolve to a Repository" out err)))

(defun %publish-remote-tags-from-github (repository-url prompt-p)
  (multiple-value-bind (out err code)
      (%publish-run-program
       (%publish-git-program)
       (list "ls-remote" "--tags" repository-url)
       :noninteractive (not prompt-p)
       :prompt prompt-p)
    (cond
      ((and (integerp code) (= code 0))
       (values
        (%publish-unique-strings
         (mapcar #'%publish-tag-from-ls-remote-line
                 (%publish-string-lines out)))
        nil))
      ((%publish-repository-not-found-output-p out err)
       (values nil t))
      (t
       (error "[publish] failed to inspect remote tags from ~A.~%~A~A~%~A"
              repository-url out err
              (%publish-noninteractive-auth-hint))))))

(defun %publish-get-remote-tags (repository-url remote-tags dry-run prompt-p)
  (cond
    (remote-tags
     (values remote-tags t nil nil))
    (t
     (handler-case
         (multiple-value-bind (tags missing-p)
             (%publish-remote-tags-from-github repository-url prompt-p)
           (values tags t nil missing-p))
       (error (c)
         (if dry-run
             (values nil nil c nil)
             (error c)))))))

(defun %publish-git-worktree-p (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("rev-parse" "--is-inside-work-tree"))
    (declare (ignore err))
    (and (integerp code)
         (= code 0)
         (string= "true" (%publish-trim-output out)))))

(defun %publish-ensure-git-worktree (root verbose)
  (if (%publish-git-worktree-p root)
      nil
      (progn
        (when verbose
          (format t "[TAF] initializing git repository.~%"))
        (%publish-run-git/checked root '("init"))
        t)))

(defun %publish-git-origin-url (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("remote" "get-url" "origin"))
    (declare (ignore err))
    (when (and (integerp code) (= code 0))
      (%publish-trim-output out))))

(defun %publish-ensure-origin (root repository-url verbose)
  (let ((origin (%publish-git-origin-url root)))
    (cond
      ((%blank-string-p origin)
       (when verbose
         (format t "[TAF] adding git remote origin: ~A~%" repository-url))
       (%publish-run-git/checked root
                                 (list "remote" "add" "origin" repository-url))
       :added)
      ((%publish-same-repository-p origin repository-url)
       :ok)
      (t
       (error "[publish] git remote origin does not match [repository].url.~%  origin: ~A~%  toml  : ~A"
              origin repository-url)))))

(defun %publish-local-tag-exists-p (root tag)
  (multiple-value-bind (out err code)
      (%publish-run-git root (list "tag" "--list" tag))
    (declare (ignore err))
    (and (integerp code)
         (= code 0)
         (not (%blank-string-p (%publish-trim-output out))))))

(defun %publish-git-status-lines (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("status" "--porcelain"))
    (unless (and (integerp code) (= code 0))
      (error "[publish] failed to inspect git status.~%~A~A" out err))
    (%publish-string-lines out)))

(defun %publish-head-exists-p (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("rev-parse" "--verify" "HEAD"))
    (declare (ignore out err))
    (and (integerp code) (= code 0))))

(defun %publish-current-branch (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("branch" "--show-current"))
    (declare (ignore err))
    (when (and (integerp code) (= code 0))
      (let ((branch (%publish-trim-output out)))
        (unless (%blank-string-p branch)
          branch)))))

(defun %publish-default-commit-message (project tag channel)
  (format nil "Publish ~A ~A (~A)"
          (getf project :name)
          tag
          (string-downcase (string channel))))

(defun %publish-release-title (project tag)
  (format nil "~A ~A" (getf project :name) tag))

(defun %publish-release-file (project)
  (han.path:join-path (getf project :root-dir) "release.md"))

(defun %publish-release-message-from-line (line)
  (let ((trimmed (%publish-trim-output line)))
    (if (%string-prefix-p "# " trimmed)
        (%publish-trim-output (subseq trimmed 2))
        trimmed)))

(defun %publish-read-release-file (project tag)
  (let ((path (%publish-release-file project)))
    (unless (%project-file-exists-p path)
      (error "[publish] --release requires release.md in project root."))
    (let* ((content (han.os:load-string path))
           (trimmed (%publish-trim-output content))
           (first-line (car (%publish-string-lines content)))
           (message (%publish-release-message-from-line first-line)))
      (when (%blank-string-p trimmed)
        (error "[publish] release.md is empty."))
      (when (%blank-string-p message)
        (error "[publish] first line of release.md is empty."))
      (when (search "TODO" message :test #'char-equal)
        (error "[publish] first line of release.md still contains TODO. Replace the release summary before publishing."))
      (list :file path
            :file-display "release.md"
            :message message
            :notes content
            :title (%publish-release-title project tag)))))

(defun %publish-commit-message (project tag channel commit-message release-info)
  (or commit-message
      (let ((base (%publish-default-commit-message project tag channel)))
        (if release-info
            (format nil "~A: ~A" base (getf release-info :message))
            base))))

(defun %publish-license-file (project)
  (han.path:join-path (getf project :root-dir) "LICENSE"))

(defun %publish-placeholder-license-p (content)
  (or (%publish-output-contains-p "placeholder" content nil)
      (%publish-output-contains-p "Please replace this file" content nil)))

(defun %publish-ensure-license-ready (project)
  (let ((license-file (%publish-license-file project)))
    (unless (%project-file-exists-p license-file)
      (error "[publish] LICENSE is missing. Add a real LICENSE file before publishing."))
    (let ((content (han.os:load-string license-file)))
      (when (%blank-string-p content)
        (error "[publish] LICENSE is empty. Add a real LICENSE file before publishing."))
      (when (%publish-placeholder-license-p content)
        (error "[publish] LICENSE is still a placeholder. Replace it with a real license before publishing."))))
  t)

(defun %publish-lock-repo-plan-commands (slug)
  (list
   (list "gh" "api" "-X" "PUT"
         (format nil "repos/~A/immutable-releases" slug)
         "[if creating repo]")
   (list "gh" "api" "-X" "POST"
         (format nil "repos/~A/rulesets" slug)
         "--input" "taffish-release-tag-ruleset.json"
         "[if creating repo]")))

(defun %publish-plan-commands
    (repository-url tag commit-message create-repo-p repo-visibility
     release-info lock-repo-p)
  (let ((create-commands nil)
        (slug (%publish-github-slug repository-url)))
    (when create-repo-p
      (setf create-commands
            (list
             (list "gh" "repo" "create"
                   (or slug repository-url)
                   (format nil "--~A"
                           (string-downcase (string repo-visibility)))
                   "[if missing]"))))
    (when (and create-repo-p lock-repo-p slug)
      (setf create-commands
            (append create-commands
                    (%publish-lock-repo-plan-commands slug))))
    (let ((commands
            (append create-commands
                  (remove
                   nil
                   (list (list "git" "init" "[if needed]")
                         (list "git" "remote" "add" "origin" repository-url "[if needed]")
                         (list "git" "add" "-A")
                         (and release-info
                              (list "git" "rm" "--cached" "--ignore-unmatch"
                                    "release.md"))
                         (list "git" "commit" "-m" commit-message "[if changed]")
                         (list "git" "tag" tag)
                         (list "git" "push" "-u" "origin" "HEAD")
                         (list "git" "push" "origin" tag))))))
      (when release-info
        (setf commands
              (append commands
                      (list
                       (list "gh" "release" "create" tag
                             "--repo" (or slug repository-url)
                             "--title" (getf release-info :title)
                             "--notes-file"
                             (getf release-info :file-display))))))
      commands)))

(defun %publish-format-command (command)
  (format nil "~{~A~^ ~}" command))

(defun %print-project-publish-summary
    (project tag channel dry-run build-p prompt-p
     create-repo-p repo-visibility remote-checked-p remote-missing-p
     latest-info remote-error commands release-info lock-repo-p)
  (format t "[TAF] publish ~A: ~A~%"
          (if dry-run "dry-run" "ready")
          (getf project :name))
  (format t "  root    : ~A~%" (getf project :root-dir))
  (format t "  repo    : ~A~%" (getf project :repository-url))
  (format t "  tag     : ~A~%" tag)
  (format t "  channel : ~A~%" (string-downcase (string channel)))
  (format t "  build   : ~A~%" (if build-p "yes" "no"))
  (format t "  release : ~A~%" (if release-info "yes" "no"))
  (when release-info
    (format t "  message : ~A~%" (getf release-info :message))
    (format t "  notes   : ~A~%" (getf release-info :file-display)))
  (format t "  prompt  : ~A~%" (if prompt-p "yes" "no"))
  (format t "  create  : ~A~%"
          (if create-repo-p
              (string-downcase (string repo-visibility))
              "no"))
  (format t "  lock    : ~A~%"
          (cond
            ((not create-repo-p) "no")
            (lock-repo-p "yes")
            (t "no")))
  (format t "  remote  : ~A~%"
          (cond
            (remote-missing-p "missing")
            (remote-checked-p "checked")
            (t "not checked")))
  (when latest-info
    (format t "  latest  : ~A~%" (getf latest-info :tag)))
  (when remote-error
    (format t "  warning : remote check skipped in dry-run: ~A~%" remote-error))
  (when (and remote-missing-p (not create-repo-p))
    (format t "  warning : ~A~%"
            (%publish-repository-missing-hint (getf project :repository-url))))
  (when dry-run
    (format t "  action  : use --yes to ~A~%"
            (cond
              ((and remote-missing-p (not create-repo-p))
               "publish after creating the repository manually or adding --create-repo")
              (create-repo-p
               (if lock-repo-p
                   "create missing repo, lock release tags and publish"
                   "create missing repo and publish"))
              (release-info
               "run git commit/tag/push and create GitHub release")
              (t
               "run git commit/tag/push")))
    (format t "  plan    :~%")
    (dolist (command commands)
      (format t "    ~A~%" (%publish-format-command command)))))

(defun %publish-validate-remote-state
    (project tag channel release-infos remote-checked-p)
  (let ((latest-info (%publish-latest-info release-infos)))
    (when remote-checked-p
      (when (member tag release-infos
                    :key (lambda (x) (getf x :tag))
                    :test #'string=)
        (error "[publish] remote tag already exists: ~A" tag))
      (when (and (eql channel :latest)
                 latest-info
                 (<= (%publish-compare-version-release
                      (getf project :version)
                      (getf project :release)
                      (getf latest-info :version)
                      (getf latest-info :release))
                     0))
        (error "[publish] current version is not newer than remote latest tag ~A. Use --pre for a pre-release publish."
               (getf latest-info :tag))))
    latest-info))

(defun %publish-create-remote-repository
    (repository-url repo-visibility prompt-p verbose)
  (let ((slug (%publish-github-slug repository-url)))
    (unless slug
      (error "[publish] can't derive GitHub owner/repo from repository URL: ~A"
             repository-url))
    (when verbose
      (format t "[TAF] creating GitHub repository: ~A (~A)~%"
              slug
              (string-downcase (string repo-visibility))))
    (multiple-value-bind (out err code)
        (%publish-run-program
         (%publish-gh-program)
         (list "repo" "create"
               slug
               (format nil "--~A"
                       (string-downcase (string repo-visibility))))
         :noninteractive (not prompt-p)
         :prompt prompt-p
         :interactive-output prompt-p)
      (unless (and (integerp code) (= code 0))
        (error "[publish] failed to create GitHub repository ~A.~%~A~A~@[~%~A~]"
               slug out err
               (and (not prompt-p)
                    (%publish-noninteractive-auth-hint))))
      (list :slug slug
            :visibility repo-visibility
            :stdout out
            :stderr err))))

(defun %publish-release-tag-ruleset ()
  (han.json:json-object
   (cons "name" "TAFFISH release tag lock")
   (cons "target" "tag")
   (cons "enforcement" "active")
   (cons "conditions"
         (han.json:json-object
          (cons "ref_name"
                (han.json:json-object
                 (cons "include" (han.json:json-array "refs/tags/v*"))
                 (cons "exclude" (han.json:json-array))))))
   (cons "rules"
         (han.json:json-array
          (han.json:json-object
           (cons "type" "update")
           (cons "parameters"
                 (han.json:json-object
                  (cons "update_allows_fetch_and_merge" nil))))
          (han.json:json-object
           (cons "type" "deletion"))))))

(defun %publish-temp-json-file (prefix)
  (merge-pathnames
   (make-pathname
    :name (format nil "~A-~36R-~36R"
                  prefix
                  (get-universal-time)
                  (get-internal-real-time))
    :type "json")
   (han.path:temporary-directory)))

(defun %publish-delete-file-safely (path)
  (ignore-errors
    (when (han.path:file-exists-p path)
      (delete-file path))))

(defun %publish-run-gh-api/checked
    (args &key prompt-p verbose action)
  (multiple-value-bind (out err code)
      (%publish-run-program
       (%publish-gh-program)
       args
       :noninteractive (not prompt-p)
       :prompt prompt-p
       :interactive-output prompt-p)
    (unless (and (integerp code) (= code 0))
      (error "[publish] failed to ~A.~%~A~A~@[~%~A~]"
             action out err
             (and (not prompt-p)
                  (%publish-noninteractive-auth-hint))))
    (when verbose
      (format t "[TAF] ~A.~%" action))
    (values out err code)))

(defun %publish-enable-immutable-releases
    (slug prompt-p verbose)
  (%publish-run-gh-api/checked
   (list "api" "-X" "PUT"
         (format nil "repos/~A/immutable-releases" slug))
   :prompt-p prompt-p
   :verbose verbose
   :action (format nil "enabled immutable releases for ~A" slug)))

(defun %publish-create-release-tag-ruleset
    (slug prompt-p verbose)
  (let ((ruleset-file (%publish-temp-json-file "taffish-release-tag-ruleset")))
    (unwind-protect
         (progn
           (han.json:write-json-file
            ruleset-file
            (%publish-release-tag-ruleset)
            :indent 2)
           (%publish-run-gh-api/checked
            (list "api" "-X" "POST"
                  (format nil "repos/~A/rulesets" slug)
                  "--input" (han.path:->namestring ruleset-file))
            :prompt-p prompt-p
            :verbose verbose
            :action (format nil "created TAFFISH release tag ruleset for ~A"
                            slug)))
      (%publish-delete-file-safely ruleset-file))))

(defun %publish-lock-remote-repository
    (repository-url prompt-p verbose)
  (let ((slug (%publish-github-slug repository-url)))
    (unless slug
      (error "[publish] can't derive GitHub owner/repo from repository URL: ~A"
             repository-url))
    (when verbose
      (format t "[TAF] locking GitHub release/tag settings: ~A~%" slug))
    (%publish-enable-immutable-releases slug prompt-p verbose)
    (%publish-create-release-tag-ruleset slug prompt-p verbose)
    (list :slug slug
          :immutable-releases t
          :release-tag-ruleset t)))

(defun %publish-create-github-release
    (repository-url tag release-info prompt-p verbose)
  (let ((slug (%publish-github-slug repository-url)))
    (unless slug
      (error "[publish] can't derive GitHub owner/repo from repository URL: ~A"
             repository-url))
    (when verbose
      (format t "[TAF] creating GitHub release: ~A~%" tag))
    (multiple-value-bind (out err code)
        (%publish-run-program
         (%publish-gh-program)
         (list "release" "create"
               tag
               "--repo" slug
               "--title" (getf release-info :title)
               "--notes-file" (han.path:->namestring
                               (getf release-info :file)))
         :noninteractive (not prompt-p)
         :prompt prompt-p
         :interactive-output prompt-p)
      (unless (and (integerp code) (= code 0))
        (error "[publish] failed to create GitHub release ~A.~%~A~A~@[~%~A~]"
               tag out err
               (and (not prompt-p)
                    (%publish-noninteractive-auth-hint))))
      (list :tag tag
            :title (getf release-info :title)
            :notes-file (getf release-info :file)
            :stdout out
            :stderr err))))

(defun %publish-execute
    (project tag commit-message initialized-p verbose prompt-p
     create-repo-p repo-visibility remote-missing-p release-info lock-repo-p)
  (let* ((root (getf project :root-dir))
         (repository-url (getf project :repository-url))
         (status-before nil)
         (branch nil)
         (repo-create-result nil)
         (repo-lock-result nil)
         (release-create-result nil))
    (%publish-ensure-origin root repository-url verbose)
    (when (%publish-local-tag-exists-p root tag)
      (error "[publish] local tag already exists: ~A" tag))
    (when (and create-repo-p remote-missing-p)
      (setf repo-create-result
            (%publish-create-remote-repository
             repository-url repo-visibility prompt-p verbose))
      (when lock-repo-p
        (setf repo-lock-result
              (%publish-lock-remote-repository
               repository-url prompt-p verbose))))
    (%publish-run-git/checked root '("add" "-A"))
    (when release-info
      (%publish-run-git/checked root
                                '("rm" "--cached" "--ignore-unmatch"
                                  "release.md")))
    (setf status-before (%publish-git-status-lines root))
    (when status-before
      (when verbose
        (format t "[TAF] committing project changes.~%"))
      (%publish-run-git/checked root
                                (list "commit" "-m" commit-message)))
    (unless (%publish-head-exists-p root)
      (error "[publish] git repository has no commit to tag."))
    (when initialized-p
      (%publish-run-git/checked root '("branch" "-M" "main")))
    (setf branch (%publish-current-branch root))
    (when verbose
      (format t "[TAF] creating git tag: ~A~%" tag))
    (%publish-run-git/checked root (list "tag" tag))
    (when verbose
      (format t "[TAF] pushing project to GitHub.~%"))
    (if branch
        (%publish-run-git/checked root
                                  (list "push" "-u" "origin" branch)
                                  :noninteractive (not prompt-p)
                                  :prompt prompt-p
                                  :interactive-output prompt-p)
        (%publish-run-git/checked root
                                  '("push" "origin" "HEAD")
                                  :noninteractive (not prompt-p)
                                  :prompt prompt-p
                                  :interactive-output prompt-p))
    (%publish-run-git/checked root
                              (list "push" "origin" tag)
                              :noninteractive (not prompt-p)
                              :prompt prompt-p
                              :interactive-output prompt-p)
    (when release-info
      (setf release-create-result
            (%publish-create-github-release
             repository-url tag release-info prompt-p verbose)))
    (list :committed-p (not (null status-before))
          :branch branch
          :created-repo repo-create-result
          :locked-repo repo-lock-result
          :created-release release-create-result)))

(defun project-publish (&key (start-dir (han.os:current-directory))
                             (dry-run t)
                             (build-p nil)
                             (channel :latest)
                             (prompt-p nil)
                             (create-repo-p nil)
                             (repo-visibility :public)
                             (lock-repo-p t)
                             (release-p nil)
                             remote-tags
                             commit-message
                             (verbose t))
  (let* ((normalized-channel (%normalize-publish-channel channel))
         (normalized-visibility
           (%normalize-publish-repo-visibility repo-visibility))
         (project (project-check start-dir nil))
         (repository-url (getf project :repository-url))
         (tag (%publish-tag-name project))
         (release-info (and release-p
                            (%publish-read-release-file project tag)))
         (message (%publish-commit-message
                   project tag normalized-channel commit-message release-info))
         (build-result nil)
         (remote-checked-p nil)
         (remote-missing-p nil)
         (remote-error nil)
         (release-infos nil)
         (latest-info nil)
         (commands (%publish-plan-commands
                    repository-url tag message
                    create-repo-p normalized-visibility
                    release-info lock-repo-p))
         (initialized-p nil)
         (execute-result nil))
    (%ensure-github-repository-url repository-url "[publish] [repository].url")
    (%publish-ensure-license-ready project)
    (multiple-value-bind (tags checked-p error-condition missing-p)
        (%publish-get-remote-tags repository-url remote-tags dry-run prompt-p)
      (setf remote-checked-p checked-p
            remote-missing-p missing-p
            remote-error error-condition
            release-infos (%publish-release-infos tags)))
    (when (and remote-missing-p (not create-repo-p) (not dry-run))
      (error "[publish] ~A" (%publish-repository-missing-hint repository-url)))
    (setf latest-info
          (%publish-validate-remote-state
           project tag normalized-channel release-infos remote-checked-p))
    (when (and build-p (not dry-run))
      (setf build-result
            (project-build :command-p t
                           :image-p nil
                           :start-dir start-dir
                           :verbose verbose)))
    (unless dry-run
      (setf initialized-p
            (%publish-ensure-git-worktree (getf project :root-dir) verbose))
	      (setf execute-result
            (%publish-execute
             project tag message initialized-p verbose prompt-p
             create-repo-p normalized-visibility remote-missing-p
             release-info lock-repo-p)))
    (when verbose
      (%print-project-publish-summary
       project tag normalized-channel dry-run build-p prompt-p
       create-repo-p normalized-visibility remote-checked-p remote-missing-p
       latest-info remote-error commands release-info lock-repo-p))
    (list :project project
          :dry-run dry-run
          :channel normalized-channel
          :prompt-p prompt-p
          :create-repo-p create-repo-p
          :repo-visibility normalized-visibility
          :lock-repo-p lock-repo-p
          :tag tag
          :repository-url repository-url
          :release release-info
          :commit-message message
          :remote-checked-p remote-checked-p
          :remote-missing-p remote-missing-p
          :remote-error remote-error
          :remote-tags release-infos
          :remote-latest latest-info
          :build build-result
          :commands commands
          :execute execute-result
          :published-p (not dry-run))))
