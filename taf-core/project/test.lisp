(in-package :han.test)

;;;; ============================================================
;;;; taf.core project tests
;;;; ============================================================

(defun %taf-project-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %taf-project-string-contains-p (string substring)
  (and (stringp string)
       (stringp substring)
       (not (null (search substring string :test #'char=)))))

(defun %taf-project-replace-substring (string old new)
  (let ((pos (search old string :test #'char=)))
    (unless pos
      (error "Substring not found: ~S" old))
    (concatenate 'string
                 (subseq string 0 pos)
                 new
                 (subseq string (+ pos (length old))))))

(defun %taf-project-realize-smoke (project-name)
  (let* ((path (%taf-project-path project-name "taffish.toml"))
         (toml (han.os:load-string path)))
    (%taf-project-write-string
     path
     (%taf-project-replace-substring
      (%taf-project-replace-substring toml
                                      "exist = [\"TODO\"]"
                                      "exist = [\"sh\"]")
      "test = [\"TODO --help\"]"
      "test = [\"sh -c true\"]"))))

(defmacro %with-taf-project-env ((name value) &body body)
  (let ((old-getenv (gensym "OLD-GETENV"))
        (env-name (gensym "ENV-NAME"))
        (env-value (gensym "ENV-VALUE")))
    `(let ((,old-getenv (symbol-function 'han.host:getenv))
           (,env-name ,name)
           (,env-value ,value))
       (unwind-protect
            (progn
              (setf (symbol-function 'han.host:getenv)
                    (lambda (name)
                      (if (string= name ,env-name)
                          ,env-value
                          (funcall ,old-getenv name))))
              ,@body)
         (setf (symbol-function 'han.host:getenv) ,old-getenv)))))

(defmacro %with-taf-project-available-backends (backends &body body)
  (let ((old-function (gensym "OLD-FUNCTION"))
        (backend-list (gensym "BACKEND-LIST")))
    `(let ((,old-function
             (symbol-function 'taf.core::%get-available-backends))
           (,backend-list ,backends))
       (unwind-protect
            (progn
              (setf (symbol-function 'taf.core::%get-available-backends)
                    (lambda () ,backend-list))
              ,@body)
         (setf (symbol-function 'taf.core::%get-available-backends)
               ,old-function)))))

(defun %taf-project-error-string (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error (condition)
      (princ-to-string condition))))

(defun %taf-project-publish-fake-state ()
  (list :repository-p nil
        :policy-p nil
        :commit nil
        :branch nil
        :local-tag nil
        :remote-tag nil
        :release-intent nil
        :operations nil
        :outage-operation nil))

(defun %taf-project-publish-fake-result (state evidence &rest fields)
  (append (list :state state :evidence evidence) fields))

(defun %taf-project-publish-fake-adapter (state &key interrupt-after)
  (setf (getf state :outage-operation) nil)
  (labels ((record (operation)
             (push operation (getf state :operations)))
           (target (context)
             (getf context :target-commit))
           (matching-commit-result (context key label)
             (let ((actual (getf state key))
                   (expected (target context)))
               (cond
                 ((null actual)
                  (%taf-project-publish-fake-result :missing
                                                    (format nil "~A missing" label)))
                 ((or (null expected) (string= actual expected))
                  (%taf-project-publish-fake-result :matching label
                                                    :commit actual))
                 (t
                  (%taf-project-publish-fake-result
                   :conflicting
                   (format nil "~A points to ~A, expected ~A"
                           label actual expected)
                   :actual actual
                   :expected expected)))))
           (interrupt (mutation inspection)
             (when (eql interrupt-after mutation)
               (setf (getf state :outage-operation) inspection)
               (error "injected publish interruption after ~A" mutation)))
           (outage-p (operation)
             (eql operation (getf state :outage-operation))))
    (lambda (operation context)
      (record operation)
      (if (outage-p operation)
          (%taf-project-publish-fake-result
           :unavailable "injected remote inspection outage")
          (case operation
        (:inspect-repository
         (if (getf state :repository-p)
             (%taf-project-publish-fake-result :matching "repository exists")
             (%taf-project-publish-fake-result :missing "repository missing")))
        (:create-repository
         (setf (getf state :repository-p) t)
         (interrupt operation :inspect-repository)
         nil)
        (:inspect-policy
         (if (not (getf context :policy-required-p))
             (%taf-project-publish-fake-result
              :not-applicable "repository policy not requested")
             (if (getf state :policy-p)
                 (%taf-project-publish-fake-result :matching "policy matches")
                 (%taf-project-publish-fake-result :missing "policy missing"))))
        (:create-policy
         (setf (getf state :policy-p) t)
         (interrupt operation :inspect-policy)
         nil)
        (:inspect-commit
         (matching-commit-result context :commit "commit"))
        (:create-commit
         (setf (getf state :commit) "commit-a")
         (interrupt operation :inspect-commit)
         nil)
        (:inspect-branch
         (matching-commit-result context :branch "remote branch"))
        (:create-branch
         (setf (getf state :branch) (target context))
         (interrupt operation :inspect-branch)
         nil)
        (:inspect-local-tag
         (matching-commit-result context :local-tag "local tag"))
        (:create-local-tag
         (setf (getf state :local-tag) (target context))
         (interrupt operation :inspect-local-tag)
         nil)
        (:inspect-remote-tag
         (matching-commit-result context :remote-tag "remote tag"))
        (:create-remote-tag
         (setf (getf state :remote-tag) (target context))
         (interrupt operation :inspect-remote-tag)
         nil)
        (:inspect-release
         (cond
           ((not (getf context :release-requested-p))
            (%taf-project-publish-fake-result
             :not-applicable "GitHub Release not requested"))
           ((null (getf state :release-intent))
            (%taf-project-publish-fake-result :missing "GitHub Release missing"))
           ((equal (getf state :release-intent)
                   (list (getf context :release-title)
                         (getf context :release-notes-sha256)))
            (%taf-project-publish-fake-result :matching "GitHub Release matches"))
           (t
            (%taf-project-publish-fake-result
             :conflicting "GitHub Release intent differs"))))
        (:create-release
         (setf (getf state :release-intent)
               (list (getf context :release-title)
                     (getf context :release-notes-sha256)))
         (interrupt operation :inspect-release)
         nil)
            (otherwise
             (error "unknown fake publish operation: ~S" operation)))))))

(defmacro with-taf-project-publish-fake
    ((project-name state journal-home &key interrupt-after) &body body)
  `(let* ((,state (%taf-project-publish-fake-state))
          (,journal-home (%taf-project-dir "publish-journal-home"))
          (taf.core::*publish-operation-adapter*
            (%taf-project-publish-fake-adapter
             ,state :interrupt-after ,interrupt-after))
          (taf.core::*publish-journal-user-home* ,journal-home))
     (taf.core:project-new ,project-name
                           '("--version" "1.2.3" "--release" "2"))
     (%taf-project-write-string
      (%taf-project-path ,project-name "release.md")
      "# publish recovery test\n\nDeterministic release notes.\n")
     ,@body))

(defun %taf-project-temp-dir ()
  (let ((name (format nil "taf-project-test-~A/" (gensym "DIR"))))
    (merge-pathnames name (uiop:temporary-directory))))

(defmacro with-taf-project-temp-dir ((dir) &body body)
  `(let ((,dir (%taf-project-temp-dir)))
     (declare (ignorable ,dir))
     (ensure-directories-exist ,dir)
     (unwind-protect
          (uiop:with-current-directory (,dir)
            ,@body)
       (uiop:delete-directory-tree ,dir :validate t :if-does-not-exist :ignore))))

(defun %taf-project-path (&rest parts)
  (apply #'han.path:join-path (han.os:current-directory) parts))

(defun %taf-project-dir (&rest parts)
  (han.path:directory-pathname (apply #'%taf-project-path parts)))

(defun %taf-project-write-string (path string)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
    (format out "~A" string)))

(defun %taf-project-chmod-executable (path)
  (multiple-value-bind (out err code)
      (han.os:run-shell-command
       (format nil "chmod +x ~A"
               (uiop:escape-sh-token (han.path:->namestring path)))
       :wait t
       :lines nil)
    (declare (ignore out err))
    (check-equal code 0)))

(defun %taf-project-write-current-index (home object)
  (han.json:write-json-file
   (han.path:join-path home "index" "current.json")
   object
   :indent 2))

(defun %taf-project-local-dependency-index (source-root)
  (let ((record (han.json:json-object
                 (cons "name" "dep-tool")
                 (cons "kind" "tool")
                 (cons "version" "0.1.0")
                 (cons "release" 1)
                 (cons "version_id" "0.1.0-r1")
                 (cons "tag" "v0.1.0-r1")
                 (cons "license" "Apache-2.0")
                 (cons "repository_url"
                       "https://github.com/taffish/dep-tool")
                 (cons "repository_slug" "taffish/dep-tool")
                 (cons "command"
                       (han.json:json-object
                        (cons "name" "taf-dep-tool")))
                 (cons "runtime"
                       (han.json:json-object
                        (cons "pipe" t)
                        (cons "command_mode" t)))
                 (cons "paths"
                       (han.json:json-object
                        (cons "main" "src/main.taf")
                        (cons "help" "docs/help.md")))
                 (cons "container" :null)
                 (cons "source"
                       (han.json:json-object
                        (cons "repository" "taffish/dep-tool")
                        (cons "ref" "v0.1.0-r1")
                        (cons "local_path"
                              (han.path:->namestring source-root)))))))
    (han.json:json-object
     (cons "schema_version" "taffish.index/v1")
     (cons "generated_at" "2026-05-07T00:00:00Z")
     (cons "packages"
           (han.json:json-object
            (cons "dep-tool"
                  (han.json:json-object
                   (cons "name" "dep-tool")
                   (cons "latest" "0.1.0-r1")
                   (cons "repository_url"
                         "https://github.com/taffish/dep-tool")
                   (cons "command"
                         (han.json:json-object
                          (cons "name" "taf-dep-tool")))
                   (cons "versions"
                         (han.json:json-object
                          (cons "0.1.0-r1" record)))))))
     (cons "commands"
           (han.json:json-object
            (cons "taf-dep-tool"
                  (han.json:json-object
                   (cons "package" "dep-tool")
                   (cons "version" "0.1.0-r1"))))))))

(deftest test-taf-project-new-default-flow ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-flow" nil)
    (let ((toml (han.os:load-string (%taf-project-path "demo-flow" "taffish.toml")))
          (main (han.os:load-string (%taf-project-path "demo-flow" "src" "main.taf")))
          (license (han.os:load-string (%taf-project-path "demo-flow" "LICENSE")))
          (gitignore (han.os:load-string (%taf-project-path "demo-flow" ".gitignore")))
          (release (han.os:load-string (%taf-project-path "demo-flow" "release.md"))))
      (check-true (probe-file (%taf-project-dir "demo-flow" "target")))
      (check-true (probe-file (%taf-project-path "demo-flow" "target" ".gitkeep")))
      (check-true (probe-file (%taf-project-dir "demo-flow" "docs")))
      (check-true (probe-file (%taf-project-path "demo-flow" "docs" "help.md")))
      (check-equal (%taf-project-string-contains-p toml "kind = \"flow\"") t)
      (check-equal (%taf-project-string-contains-p toml "license = \"Apache-2.0\"") t)
      (check-equal (%taf-project-string-contains-p
                    toml
                    "url = \"https://github.com/taffish/demo-flow\"")
                   t)
      (check-equal (%taf-project-string-contains-p toml "command_mode = false") t)
      (check-equal (%taf-project-string-contains-p toml "[smoke]") nil)
      (check-equal (%taf-project-string-contains-p main "<taffish>") t)
      (check-equal (%taf-project-string-contains-p license "Apache License") t)
      (check-equal (%taf-project-string-contains-p license "Version 2.0, January 2004") t)
      (check-equal (%taf-project-string-contains-p license "placeholder") nil)
      (check-equal (%taf-project-string-contains-p gitignore "target/") nil)
      (check-equal (%taf-project-string-contains-p gitignore "release.md") t)
      (check-equal (%taf-project-string-contains-p release "# TODO: release summary") t))))

(deftest test-taf-project-new-tool-with-docker ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo_docker"
     '("--tool" "--docker" "--version" "1.2.3" "--release" "2"
       "--repo" "https://github.com/taffish/custom-demo-docker"))
    (let ((toml (han.os:load-string (%taf-project-path "demo_docker" "taffish.toml")))
          (main (han.os:load-string (%taf-project-path "demo_docker" "src" "main.taf")))
          (dockerfile (han.os:load-string (%taf-project-path "demo_docker" "docker" "Dockerfile")))
          (workflow (han.os:load-string
                     (%taf-project-path "demo_docker" ".github" "workflows"
                                        "build-image.yml"))))
      (check-equal (%taf-project-string-contains-p toml "kind = \"tool\"") t)
      (check-equal (%taf-project-string-contains-p toml "license = \"Apache-2.0\"") t)
      (check-equal (%taf-project-string-contains-p
                    toml
                    "url = \"https://github.com/taffish/custom-demo-docker\"")
                   t)
      (check-equal (%taf-project-string-contains-p toml "image = \"ghcr.io/taffish/demo-docker:1.2.3-r2\"") t)
      (check-equal (%taf-project-string-contains-p toml "dockerfile = \"docker/Dockerfile\"") t)
      (check-equal (%taf-project-string-contains-p toml "build_platforms = \"linux/amd64,linux/arm64\"") t)
      (check-equal (%taf-project-string-contains-p toml "[smoke]") t)
      (check-equal (%taf-project-string-contains-p toml "backend = \"docker\"") t)
      (check-equal (%taf-project-string-contains-p toml "timeout = 60") t)
      (check-equal (%taf-project-string-contains-p toml "exist = [\"TODO\"]") t)
      (check-equal (%taf-project-string-contains-p toml "test = [\"TODO --help\"]") t)
      (check-equal (%taf-project-string-contains-p main "<taf-app:container:ghcr.io/taffish/demo-docker:1.2.3-r2>") t)
      (check-equal (%taf-project-string-contains-p dockerfile "FROM debian:12-slim") t)
      (check-equal (%taf-project-string-contains-p dockerfile "ENV DEBIAN_FRONTEND=noninteractive") t)
      (check-equal (%taf-project-string-contains-p dockerfile "--no-install-recommends") t)
      (check-equal (%taf-project-string-contains-p dockerfile "build-essential") t)
      (check-equal (%taf-project-string-contains-p dockerfile "rm -rf /var/lib/apt/lists/*") t)
      (check-equal (%taf-project-string-contains-p dockerfile "ENV TAFFISH_NAME=demo_docker") t)
      (check-equal (%taf-project-string-contains-p workflow "actions/checkout@v6") t)
      (check-equal (%taf-project-string-contains-p workflow "docker/setup-buildx-action@v4") t)
      (check-equal (%taf-project-string-contains-p workflow "docker/login-action@v4") t)
      (check-equal (%taf-project-string-contains-p workflow "docker/build-push-action@v7") t)
      (check-equal (%taf-project-string-contains-p workflow "taffish.toml") t)
      (check-equal (%taf-project-string-contains-p workflow "ghcr.io") t)
      (check-equal (%taf-project-string-contains-p workflow "ubuntu-24.04-arm") t)
      (check-equal (%taf-project-string-contains-p workflow "source_ref:") t)
      (check-equal (%taf-project-string-contains-p workflow "platforms:") t)
      (check-equal (%taf-project-string-contains-p workflow "fromJSON(needs.prepare.outputs.matrix)") t)
      (check-equal (%taf-project-string-contains-p workflow "scope=build-${{ matrix.arch }}") t)
      (check-equal (%taf-project-string-contains-p workflow "docker buildx imagetools create") t)
      (check-equal (%taf-project-string-contains-p
                    workflow
                    "org.opencontainers.image.source=https://github.com/${{ github.repository }}")
                   t)
      (check-equal (%taf-project-string-contains-p
                    workflow
                    "GHCR packages are private by default")
                   t)
      (check-equal (%taf-project-string-contains-p workflow "${{ needs.prepare.outputs.image }}") t)
      (check-equal (%taf-project-string-contains-p workflow "docker/setup-qemu-action") nil)
      (check-equal (%taf-project-string-contains-p workflow "continue-on-error: true") nil)
      (check-equal (%taf-project-string-contains-p
                    workflow
                    "publishing amd64-only manifest")
                   nil))))

(deftest test-taf-project-new-workflow-native-matrix-contract ()
  (let ((workflow (taf.core::%make-github-actions-build-image-workflow-string)))
    (dolist (required '("workflow_dispatch:"
                        "source_ref:"
                        "platforms:"
                        "SOURCE_REF: ${{ inputs.source_ref || github.ref }}"
                        "REQUESTED_PLATFORMS: ${{ inputs.platforms || '' }}"
                        "ref: ${{ env.SOURCE_REF }}"
                        "jobs:"
                        "prepare:"
                        "build:"
                        "manifest:"
                        "linux/amd64\": \"ubuntu-24.04"
                        "linux/arm64\": \"ubuntu-24.04-arm"
                        "{label} must be non-empty and unique"
                        "requested platforms are not declared"
                        "source tag"
                        "does not match"
                        "container image tag must be"
                        "source_commit="
                        "taffish-{arch}-{source_commit}"
                        "matrix={json.dumps(matrix"
                        "runs-on: ${{ matrix.runner }}"
                        "ref: ${{ needs.prepare.outputs.source_commit }}"
                        "platforms: ${{ matrix.platform }}"
                        "tags: ${{ matrix.image }}"
                        "cache-from: type=gha,scope=build-${{ matrix.arch }}"
                        "cache-to: type=gha,mode=max,scope=build-${{ matrix.arch }}"
                        "org.opencontainers.image.revision=${{ needs.prepare.outputs.source_commit }}"
                        "group: build-container-image-${{ needs.prepare.outputs.image }}"
                        "queue: max"
                        "docker buildx imagetools inspect"
                        "final manifest is missing declared platforms"
                        "final manifest has unexpected platforms"
                        "architecture == \"unknown\""))
      (check-true (%taf-project-string-contains-p workflow required)))
    (dolist (forbidden '("docker/setup-qemu-action"
                         "continue-on-error: true"
                         "publishing amd64-only manifest"
                         "Build and push amd64 image"
                         "Build and push arm64 image"
                         "signac"))
      (check-false (%taf-project-string-contains-p workflow forbidden)))))

(deftest test-taf-project-new-docker-no-actions ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-no-actions" '("--tool" "--docker" "--no-actions"))
    (let ((toml (han.os:load-string (%taf-project-path "demo-no-actions" "taffish.toml"))))
      (check-equal (%taf-project-string-contains-p toml "dockerfile = \"docker/Dockerfile\"") t)
      (check-equal (%taf-project-string-contains-p toml "build_platforms = \"linux/amd64,linux/arm64\"") t)
      (check-equal (%taf-project-string-contains-p toml "[smoke]") t)
      (check-equal (probe-file (%taf-project-path "demo-no-actions"
                                                  ".github" "workflows"
                                                  "build-image.yml"))
                   nil))))

(deftest test-taf-project-new-invalid-name-error ()
  (check-equal
   (%taf-project-signal-error-p
    (lambda ()
      (taf.core:project-new "-bad" nil)))
   t))

(deftest test-taf-project-new-invalid-repo-error ()
  (with-taf-project-temp-dir (dir)
    (check-equal
     (%taf-project-signal-error-p
      (lambda ()
        (taf.core:project-new "demo-bad-repo"
                              '("--repo" "https://example.com"))))
     t)))

(deftest test-taf-project-new-generic-repository-url ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-gitlab-repo"
     '("--repo" "https://gitlab.example.org/group/demo-gitlab-repo"))
    (let ((project (taf.core:project-check
                    (%taf-project-dir "demo-gitlab-repo")
                    nil)))
      (check-equal (getf project :repository-url)
                   "https://gitlab.example.org/group/demo-gitlab-repo"))))

(deftest test-taf-project-new-invalid-license-error ()
  (with-taf-project-temp-dir (dir)
    (check-equal
     (%taf-project-signal-error-p
      (lambda ()
        (taf.core:project-new "demo-bad-license"
                              '("--license" "GPL-3.0"))))
     t)))

(deftest test-taf-project-check-default-flow-from-nested-dir ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-check" nil)
    (let ((expected-root (han.path:->namestring
                          (%taf-project-dir "demo-check"))))
      (uiop:with-current-directory ((%taf-project-dir "demo-check" "src"))
        (let ((project (taf.core:project-check (han.os:current-directory) nil)))
          (check-equal (getf (taf.core:project-check "." nil) :root-dir)
                       expected-root)
          (check-equal (getf project :root-dir) expected-root)
          (check-equal (getf project :name) "demo-check")
          (check-equal (getf project :kind) :flow)
          (check-equal (getf project :version) "0.1.0")
          (check-equal (getf project :release) 1)
          (check-equal (getf project :license) "Apache-2.0")
          (check-equal (getf project :repository-url)
                       "https://github.com/taffish/demo-check")
          (check-equal (getf project :command-name) "taf-demo-check")
          (check-equal (getf project :main-path) "src/main.taf")
          (check-equal (%taf-project-string-contains-p
                        (getf project :help-file)
                        "docs/help.md")
                       t)
          (check-equal (getf project :target-exists-p) t)
          (check-equal (getf project :runtime-pipe) nil)
          (check-equal (getf project :runtime-command-mode) nil))))))

(deftest test-taf-project-check-tool-with-docker ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo_check_docker"
     '("--tool" "--docker" "--version" "1.2.3" "--release" "2"))
    (%taf-project-realize-smoke "demo_check_docker")
    (uiop:with-current-directory ((%taf-project-dir "demo_check_docker"))
      (let ((project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (getf project :name) "demo_check_docker")
        (check-equal (getf project :kind) :tool)
        (check-equal (getf project :version) "1.2.3")
        (check-equal (getf project :release) 2)
        (check-equal (getf project :runtime-pipe) t)
        (check-equal (getf project :runtime-command-mode) t)
        (check-equal (getf project :container-image)
                     "ghcr.io/taffish/demo-check-docker:1.2.3-r2")
        (check-equal (getf project :main-container-images)
                     '("ghcr.io/taffish/demo-check-docker:1.2.3-r2"))
        (check-equal (getf project :dockerfile) "docker/Dockerfile")
        (check-equal (getf project :container-build-platforms)
                     "linux/amd64,linux/arm64")
        (let ((smoke (getf project :smoke)))
          (check-equal (getf smoke :backend) "docker")
          (check-equal (getf smoke :timeout) 60)
          (check-equal (getf smoke :exist) '("sh"))
          (check-equal (getf smoke :test) '("sh -c true")))))))

(deftest test-taf-project-check-smoke-todo-placeholder-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo_smoke_todo" '("--tool" "--docker"))
    (uiop:with-current-directory ((%taf-project-dir "demo_smoke_todo"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-container-requires-smoke ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo_check_missing_smoke"
     '("--tool" "--docker" "--version" "1.2.3" "--release" "2"))
    (let ((toml (han.os:load-string
                 (%taf-project-path "demo_check_missing_smoke"
                                    "taffish.toml"))))
      (%taf-project-write-string
       (%taf-project-path "demo_check_missing_smoke" "taffish.toml")
       (subseq toml 0 (search "[smoke]" toml :test #'char=))))
    (uiop:with-current-directory ((%taf-project-dir "demo_check_missing_smoke"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-smoke-invalid-backend-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo_bad_smoke_backend" '("--tool" "--docker"))
    (let ((toml (han.os:load-string
                 (%taf-project-path "demo_bad_smoke_backend"
                                    "taffish.toml"))))
      (%taf-project-write-string
       (%taf-project-path "demo_bad_smoke_backend" "taffish.toml")
       (%taf-project-replace-substring toml
                                       "backend = \"docker\""
                                       "backend = \"bad\"")))
    (uiop:with-current-directory ((%taf-project-dir "demo_bad_smoke_backend"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-smoke-invalid-timeout-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo_bad_smoke_timeout" '("--tool" "--docker"))
    (let ((toml (han.os:load-string
                 (%taf-project-path "demo_bad_smoke_timeout"
                                    "taffish.toml"))))
      (%taf-project-write-string
       (%taf-project-path "demo_bad_smoke_timeout" "taffish.toml")
       (%taf-project-replace-substring toml
                                       "timeout = 60"
                                       "timeout = 0")))
    (uiop:with-current-directory ((%taf-project-dir "demo_bad_smoke_timeout"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-smoke-empty-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo_empty_smoke" '("--tool" "--docker"))
    (let ((toml (han.os:load-string
                 (%taf-project-path "demo_empty_smoke" "taffish.toml"))))
      (%taf-project-write-string
       (%taf-project-path "demo_empty_smoke" "taffish.toml")
       (%taf-project-replace-substring
        (%taf-project-replace-substring toml
                                        "exist = [\"TODO\"]"
                                        "exist = []")
        "test = [\"TODO --help\"]"
        "test = []")))
    (uiop:with-current-directory ((%taf-project-dir "demo_empty_smoke"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-container-image-main-mismatch-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo_check_image_mismatch"
     '("--tool" "--docker" "--version" "1.2.3" "--release" "2"))
    (%taf-project-realize-smoke "demo_check_image_mismatch")
    (%taf-project-write-string
     (%taf-project-path "demo_check_image_mismatch" "src" "main.taf")
     (format nil "<taf-app:container:ghcr.io/taffish/demo-check-image-mismatch:1.2.3-r3>~%echo mismatch"))
    (uiop:with-current-directory ((%taf-project-dir "demo_check_image_mismatch"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-container-image-tag-release-mismatch-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo_check_release_mismatch"
     '("--tool" "--docker" "--version" "1.2.3" "--release" "2"))
    (%taf-project-write-string
     (%taf-project-path "demo_check_release_mismatch" "taffish.toml")
     (format nil "~{~A~%~}"
             '("[package]"
               "name = \"demo_check_release_mismatch\""
               "kind = \"tool\""
               "version = \"1.2.3\""
               "release = 3"
               "license = \"Apache-2.0\""
               "main = \"src/main.taf\""
               ""
               "[repository]"
               "url = \"https://github.com/taffish/demo-check-release-mismatch\""
               ""
               "[command]"
               "name = \"taf-demo-check-release-mismatch\""
               ""
               "[runtime]"
               "pipe = true"
               "command_mode = true"
               ""
               "[container]"
               "image = \"ghcr.io/taffish/demo-check-release-mismatch:1.2.3-r2\""
               "dockerfile = \"docker/Dockerfile\""
               "build_platforms = \"linux/amd64,linux/arm64\""
               ""
               "[smoke]"
               "backend = \"docker\""
               "timeout = 60"
               "exist = [\"sh\"]"
               "test = [\"sh -c true\"]")))
    (uiop:with-current-directory ((%taf-project-dir "demo_check_release_mismatch"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-missing-target-still-ok ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-no-target" nil)
    (uiop:delete-directory-tree
     (%taf-project-dir "demo-no-target" "target")
     :validate t
     :if-does-not-exist :ignore)
    (uiop:with-current-directory ((%taf-project-dir "demo-no-target"))
      (let ((project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (getf project :name) "demo-no-target")
        (check-equal (getf project :target-exists-p) nil)))))

(deftest test-taf-project-check-no-root-error ()
  (with-taf-project-temp-dir (dir)
    (check-equal
     (%taf-project-signal-error-p
      (lambda ()
        (taf.core:project-check dir nil)))
     t)))

(deftest test-taf-project-check-missing-main-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-missing-main" nil)
    (delete-file (%taf-project-path "demo-missing-main" "src" "main.taf"))
    (uiop:with-current-directory ((%taf-project-dir "demo-missing-main"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-missing-help-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-missing-help" nil)
    (delete-file (%taf-project-path "demo-missing-help" "docs" "help.md"))
    (uiop:with-current-directory ((%taf-project-dir "demo-missing-help"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-missing-flow-dependency-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-missing-flow-dep" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-missing-flow-dep" "src" "main.taf")
     "<taffish>
echo before
[[taf: taf-dep-tool --help]]
echo after")
    (uiop:with-current-directory ((%taf-project-dir "demo-missing-flow-dep"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-flow-dependency-version-mismatch-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-flow-dep-mismatch" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-mismatch" "taffish.toml")
     (format nil "~{~A~%~}"
             '("[package]"
               "name = \"demo-flow-dep-mismatch\""
               "kind = \"flow\""
               "version = \"0.1.0\""
               "release = 1"
               "license = \"Apache-2.0\""
               "main = \"src/main.taf\""
               ""
               "[repository]"
               "url = \"https://github.com/taffish/demo-flow-dep-mismatch\""
               ""
               "[command]"
               "name = \"taf-demo-flow-dep-mismatch\""
               ""
               "[runtime]"
               "pipe = false"
               "command_mode = false"
               ""
               "[dependencies]"
               "taf-dep-tool = \"0.1.0-r1\"")))
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-mismatch" "src" "main.taf")
     "<taffish>
[[taf: taf-dep-tool-v0.2.0-r1 --help]]")
    (uiop:with-current-directory ((%taf-project-dir "demo-flow-dep-mismatch"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-check (han.os:current-directory) nil)))
       t))))

(deftest test-taf-project-check-flow-dependency-version-match ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-flow-dep-match" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-match" "taffish.toml")
     (format nil "~{~A~%~}"
             '("[package]"
               "name = \"demo-flow-dep-match\""
               "kind = \"flow\""
               "version = \"0.1.0\""
               "release = 1"
               "license = \"Apache-2.0\""
               "main = \"src/main.taf\""
               ""
               "[repository]"
               "url = \"https://github.com/taffish/demo-flow-dep-match\""
               ""
               "[command]"
               "name = \"taf-demo-flow-dep-match\""
               ""
               "[runtime]"
               "pipe = false"
               "command_mode = false"
               ""
               "[dependencies]"
               "taf-dep-tool = \"0.2.0-r1\"")))
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-match" "src" "main.taf")
     "<taffish>
[[taf: taf-dep-tool-v0.2.0-r1 --help]]")
    (uiop:with-current-directory ((%taf-project-dir "demo-flow-dep-match"))
      (let ((project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (getf (first (getf project :dependencies)) :command)
                     "taf-dep-tool")
        (check-equal (getf (first (getf project :dependencies)) :version)
                     "0.2.0-r1")))))

(deftest test-taf-project-check-flow-dependency-version-array-match ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-flow-dep-array" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-array" "taffish.toml")
     (format nil "~{~A~%~}"
             '("[package]"
               "name = \"demo-flow-dep-array\""
               "kind = \"flow\""
               "version = \"0.1.0\""
               "release = 1"
               "license = \"Apache-2.0\""
               "main = \"src/main.taf\""
               ""
               "[repository]"
               "url = \"https://github.com/taffish/demo-flow-dep-array\""
               ""
               "[command]"
               "name = \"taf-demo-flow-dep-array\""
               ""
               "[runtime]"
               "pipe = false"
               "command_mode = false"
               ""
               "[dependencies]"
               "taf-dep-tool = [\"0.1.0-r1\", \"0.2.0-r1\"]")))
    (%taf-project-write-string
     (%taf-project-path "demo-flow-dep-array" "src" "main.taf")
     "<taffish>
[[taf: taf-dep-tool-v0.1.0-r1 --help]]
[[taf: taf-dep-tool-v0.2.0-r1 --help]]")
    (uiop:with-current-directory ((%taf-project-dir "demo-flow-dep-array"))
      (let ((project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (length (getf project :dependencies)) 2)
        (check-equal (getf (first (getf project :dependencies)) :command)
                     "taf-dep-tool")
        (check-equal (getf (second (getf project :dependencies)) :command)
                     "taf-dep-tool")))))

(deftest test-taf-project-compile-default-flow-from-nested-dir ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-compile" nil)
    (uiop:with-current-directory ((%taf-project-dir "demo-compile" "src"))
      (let ((shell (taf.core:project-compile nil (han.os:current-directory))))
        (check-equal (%taf-project-string-contains-p shell "#!/bin/sh") t)
        (check-equal (%taf-project-string-contains-p
                      shell
                      "echo '<flow>[demo-compile: 0.1.0] Hello, World!'")
                     t)))))

(deftest test-taf-project-compile-forwards-args-and-project-context ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-context-compile" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-context-compile" "src" "main.taf")
     (format nil "ARGS~%<!(--/-n)name=world>~%RUN~%<taffish>~%echo 'name: ::name::'~%echo 'cmd: ::*CMD*::'~%echo 'argv: ::*ARGV*::'"))
    (uiop:with-current-directory ((%taf-project-dir "demo-context-compile" "src"))
      (let ((shell (taf.core:project-compile
                    '("--name" "alice")
                    (han.os:current-directory))))
        (check-equal (%taf-project-string-contains-p shell "echo 'name: alice'") t)
        (check-equal (%taf-project-string-contains-p shell "echo 'cmd: taf-demo-context-compile'") t)
        (check-equal (%taf-project-string-contains-p shell "echo 'argv: --name alice'") t)))))

(deftest test-taf-project-compile-container-backend-env ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-env-backend" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-env-backend" "src" "main.taf")
     (format nil "RUN~%<container:ghcr.io/taffish/demo-env-backend:0.1.0-r1>~%echo hi"))
    (uiop:with-current-directory ((%taf-project-dir "demo-env-backend"))
      (%with-taf-project-env ("TAFFISH_CONTAINER_BACKEND" "docker")
        (%with-taf-project-available-backends (list :apptainer :podman :docker)
          (let ((shell (taf.core:project-compile
                        nil
                        (han.os:current-directory))))
            (check-equal (%taf-project-string-contains-p
                          shell
                          "# CHOSEN BACKEND: DOCKER")
                         t)
            (check-equal (%taf-project-string-contains-p
                          shell
                          "# FORCE BACKEND: :DOCKER")
                         t)))))))

(deftest test-taf-project-compile-backend-option-overrides-env ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-option-backend" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-option-backend" "src" "main.taf")
     (format nil "RUN~%<container:ghcr.io/taffish/demo-option-backend:0.1.0-r1>~%echo hi"))
    (uiop:with-current-directory ((%taf-project-dir "demo-option-backend"))
      (%with-taf-project-env ("TAFFISH_CONTAINER_BACKEND" "apptainer")
        (%with-taf-project-available-backends (list :apptainer :podman :docker)
          (let ((shell (taf.core:project-compile
                        nil
                        (han.os:current-directory)
                        :container-backend "podman")))
            (check-equal (%taf-project-string-contains-p
                          shell
                          "# CHOSEN BACKEND: PODMAN")
                         t)
            (check-equal (%taf-project-string-contains-p
                          shell
                          "# FORCE BACKEND: :PODMAN")
                         t)))))))

(deftest test-taf-project-compile-container-env-run-args ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-env-run-args" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-env-run-args" "src" "main.taf")
     (format nil "RUN~%<container:ghcr.io/taffish/demo-env-run-args:0.1.0-r1$@[docker: --ipc host]>~%echo hi"))
    (uiop:with-current-directory ((%taf-project-dir "demo-env-run-args"))
      (%with-taf-project-env ("TAFFISH_CONTAINER_BACKEND" "docker")
        (%with-taf-project-env ("TAFFISH_DOCKER_RUN_ARGS" "--gpus all")
          (%with-taf-project-available-backends (list :apptainer :podman :docker)
            (let ((shell (taf.core:project-compile
                          nil
                          (han.os:current-directory))))
              (check-equal (%taf-project-string-contains-p
                            shell
                            "# CHOSEN BACKEND: DOCKER")
                           t)
              (check-equal (%taf-project-string-contains-p
                            shell
                            "--ipc host --gpus all")
                           t))))))))

(deftest test-taf-project-build-command-wrapper-and-frozen-snapshot ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-build" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-build" "src" "helper.txt")
     "helper-v1")
    (%taf-project-write-string
     (%taf-project-path "demo-build" "docs" "help.md")
     "frozen help v1")
    (uiop:with-current-directory ((%taf-project-dir "demo-build" "src"))
      (let* ((result (taf.core:project-build
                      :start-dir (han.os:current-directory)
                      :verbose nil))
             (command (getf result :command))
             (command-file (getf command :command-file))
             (snapshot-dir (getf command :snapshot-dir))
             (wrapper (han.os:load-string command-file))
             (snapshot-main (han.os:load-string
                             (han.path:join-path snapshot-dir "src" "main.taf")))
             (snapshot-helper (han.os:load-string
                               (han.path:join-path snapshot-dir "src" "helper.txt")))
             (snapshot-help (han.os:load-string
                             (han.path:join-path snapshot-dir "docs" "help.md"))))
        (check-equal (getf command :artifact-name) "taf-demo-build-v0.1.0-r1")
        (check-true (probe-file command-file))
        (check-true (probe-file (han.path:join-path snapshot-dir "taffish.toml")))
        (check-equal (%taf-project-string-contains-p
                      wrapper
                      "snapshot_root=\"$script_dir/.taf-demo-build-v0.1.0-r1\"")
                     t)
        (check-equal (%taf-project-string-contains-p
                      wrapper
                      "taf_main=\"$snapshot_root/src/main.taf\"")
                     t)
        (check-equal (%taf-project-string-contains-p wrapper "taf_help=") t)
        (check-equal (%taf-project-string-contains-p wrapper "[ \"${1:-}\" = \"--\" ]") t)
        (check-equal (%taf-project-string-contains-p wrapper "[ \"${1:-}\" = \"-h\" ]") t)
        (check-equal (%taf-project-string-contains-p wrapper "${TAFFISH:-taffish}") t)
        (check-equal (%taf-project-string-contains-p wrapper "TAF_HISTORY_MODE") t)
        (check-equal (%taf-project-string-contains-p wrapper "TAF_HISTORY_FILE") t)
        (check-equal (%taf-project-string-contains-p wrapper "history.jsonl") t)
        (check-equal (%taf-project-string-contains-p wrapper "taf_json_string") t)
        (check-equal (%taf-project-string-contains-p wrapper "taf_record_history_call") t)
        (check-equal (%taf-project-string-contains-p wrapper "taf_record_history()") t)
        (check-equal (%taf-project-string-contains-p wrapper "taf_record_history_call \"$@\" &") t)
        (check-equal (%taf-project-string-contains-p wrapper "history --record-exec") nil)
        (check-equal (%taf-project-string-contains-p wrapper "exec \"$taf_shell\"") nil)
        (check-equal (%taf-project-string-contains-p wrapper "exit \"$taf_exit\"") t)
        (check-equal (%taf-project-string-contains-p wrapper (han.path:->namestring dir)) nil)
        (check-equal (%taf-project-string-contains-p snapshot-main "demo-build") t)
        (check-equal snapshot-helper "helper-v1")
        (check-equal (%taf-project-string-contains-p snapshot-help "frozen help v1") t)
        (%taf-project-write-string
         (han.path:join-path dir "demo-build" "src" "main.taf")
         "<taffish>
echo changed")
        (%taf-project-write-string
         (han.path:join-path dir "demo-build" "docs" "help.md")
         "changed help")
        (check-equal
         (%taf-project-string-contains-p
          (han.os:load-string (han.path:join-path snapshot-dir "src" "main.taf"))
          "changed")
         nil)
        (multiple-value-bind (out err code)
            (han.os:run-shell-command
             (format nil "~A --help" (uiop:escape-sh-token command-file))
             :lines nil)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-project-string-contains-p out "frozen help v1") t))
        (multiple-value-bind (out err code)
            (han.os:run-shell-command
             (format nil "~A --version" (uiop:escape-sh-token command-file))
             :lines nil)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-project-string-contains-p
                        out
                        "taf-demo-build-v0.1.0-r1")
                       t)
          (check-equal (%taf-project-string-contains-p
                        out
                        "version: 0.1.0-r1")
                       t))))))

(deftest test-taf-project-build-wrapper-records-exec-history-hook ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-build-history" nil)
    (uiop:with-current-directory ((%taf-project-dir "demo-build-history"))
      (let* ((result (taf.core:project-build
                      :start-dir (han.os:current-directory)
                      :verbose nil))
             (command-file (getf (getf result :command) :command-file))
             (fake-taffish (han.path:join-path dir "fake-taffish"))
             (record-file (han.path:join-path dir "history.jsonl")))
        (%taf-project-write-string
         fake-taffish
         "#!/bin/sh
cat <<'EOF'
#!/bin/sh
echo fake-app-output
exit 0
EOF
")
        (%taf-project-chmod-executable fake-taffish)
        (multiple-value-bind (out err code)
            (han.os:run-shell-command
             (format nil "TAFFISH=~A TAF_HISTORY_MODE=off ~A -- --version"
                     (uiop:escape-sh-token (han.path:->namestring fake-taffish))
                     (uiop:escape-sh-token command-file))
             :lines nil)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-project-string-contains-p out "fake-app-output") t)
          (check-equal (%taf-project-string-contains-p out "version: 0.1.0-r1") nil))
        (multiple-value-bind (out err code)
            (han.os:run-shell-command
             (format nil "TAFFISH=~A TAF_HISTORY_MODE=sync TAF_HISTORY_FILE=~A ~A --alpha beta"
                     (uiop:escape-sh-token (han.path:->namestring fake-taffish))
                     (uiop:escape-sh-token (han.path:->namestring record-file))
                     (uiop:escape-sh-token command-file))
             :lines nil)
          (declare (ignore err))
          (let ((record (han.os:load-string record-file)))
            (check-equal code 0)
            (check-equal (%taf-project-string-contains-p out "fake-app-output") t)
            (check-equal (%taf-project-string-contains-p record "\"event\":\"exec\"") t)
            (check-equal (%taf-project-string-contains-p record "\"history_backend\":\"shell-wrapper\"") t)
            (check-equal (%taf-project-string-contains-p record "\"status\"") t)
            (check-equal (%taf-project-string-contains-p record "success") t)
            (check-equal (%taf-project-string-contains-p record "\"command\"") t)
            (check-equal (%taf-project-string-contains-p record
                                                         "taf-demo-build-history-v0.1.0-r1")
                         t)
            (check-equal (%taf-project-string-contains-p record "\"project_name\"") t)
            (check-equal (%taf-project-string-contains-p record "demo-build-history") t)
            (check-equal (%taf-project-string-contains-p record "\"exit_code\":0") t)
            (check-equal (%taf-project-string-contains-p record "--alpha") t)
            (check-equal (%taf-project-string-contains-p record "beta") t)))))))

(deftest test-taf-project-build-flow-syncs-toml-dependencies ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "flow-deps" nil)
    (%taf-project-write-string
     (%taf-project-path "flow-deps" "taffish.toml")
     (format nil "~{~A~%~}"
             '("[package]"
               "name = \"flow-deps\""
               "kind = \"flow\""
               "version = \"0.1.0\""
               "release = 1"
               "license = \"Apache-2.0\""
               "main = \"src/main.taf\""
               ""
               "[repository]"
               "url = \"https://github.com/taffish/flow-deps\""
               ""
               "[command]"
               "name = \"taf-flow-deps\""
               ""
               "[runtime]"
               "pipe = false"
               "command_mode = false"
               ""
               "[dependencies]"
               "taf-dep-tool = \"0.1.0-r1\""
               "taf-stale-tool = \"9.9.9-r9\"")))
    (%taf-project-write-string
     (%taf-project-path "flow-deps" "src" "main.taf")
     "<taffish>
echo before
[[taf: taf-dep-tool --help]]
[[taf: taf-new-tool-v1.2.3-r4 --foo]]
echo after")
    (uiop:with-current-directory ((%taf-project-dir "flow-deps"))
      (let* ((result (taf.core:project-build
                      :start-dir (han.os:current-directory)
                      :verbose nil))
             (command (getf result :command))
             (dependencies (getf command :dependencies))
             (wrapper (han.os:load-string (getf command :command-file)))
             (source-toml (han.os:load-string
                           (han.path:join-path dir
                                               "flow-deps"
                                               "taffish.toml")))
             (snapshot-toml (han.os:load-string
                             (han.path:join-path (getf command :snapshot-dir)
                                                 "taffish.toml")))
             (project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (length dependencies) 2)
        (check-equal (getf (first dependencies) :command) "taf-dep-tool")
        (check-equal (getf (first dependencies) :version) "0.1.0-r1")
        (check-equal (getf (second dependencies) :command) "taf-new-tool")
        (check-equal (getf (second dependencies) :version) "1.2.3-r4")
        (check-equal (%taf-project-string-contains-p
                      source-toml
                      "[dependencies]")
                     t)
        (check-equal (%taf-project-string-contains-p
                      source-toml
                      "taf-dep-tool = \"0.1.0-r1\"")
                     t)
        (check-equal (%taf-project-string-contains-p
                      source-toml
                      "taf-new-tool = \"1.2.3-r4\"")
                     t)
        (check-equal (%taf-project-string-contains-p
                      source-toml
                      "taf-stale-tool")
                     nil)
        (check-equal source-toml snapshot-toml)
        (check-equal (%taf-project-string-contains-p
                      wrapper
                      ".taf-deps")
                     nil)
        (check-equal (getf (first (getf project :dependencies)) :command)
                     "taf-dep-tool")))))

(deftest test-taf-project-build-flow-syncs-multiple-dependency-versions ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "flow-multi-deps" nil)
    (%taf-project-write-string
     (%taf-project-path "flow-multi-deps" "src" "main.taf")
     "<taffish>
echo 'step-1' | [[taf: taf-my-test-tool-v0.1.0-r1 cat]]
[[taf: taf-my-test-tool-v0.1.0-r1 uname -a]]
[[taf: taf-my-test-tool-v0.1.0-r1 echo 'END']] | [[taf: taf-my-test-tool-v0.1.0-r2 cat]]")
    (uiop:with-current-directory ((%taf-project-dir "flow-multi-deps"))
      (let* ((result (taf.core:project-build
                      :start-dir (han.os:current-directory)
                      :verbose nil))
             (command (getf result :command))
             (dependencies (getf command :dependencies))
             (source-toml (han.os:load-string
                           (han.path:join-path dir
                                               "flow-multi-deps"
                                               "taffish.toml")))
             (project (taf.core:project-check (han.os:current-directory) nil)))
        (check-equal (length dependencies) 2)
        (check-equal (getf (first dependencies) :command)
                     "taf-my-test-tool")
        (check-equal (getf (first dependencies) :version)
                     "0.1.0-r1")
        (check-equal (getf (second dependencies) :command)
                     "taf-my-test-tool")
        (check-equal (getf (second dependencies) :version)
                     "0.1.0-r2")
        (check-equal (%taf-project-string-contains-p
                      source-toml
                      "taf-my-test-tool = [\"0.1.0-r1\", \"0.1.0-r2\"]")
                     t)
        (check-equal (length (getf project :dependencies)) 2)))))

(deftest test-taf-project-build-recreates-missing-target ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-build-no-target" nil)
    (uiop:delete-directory-tree
     (%taf-project-dir "demo-build-no-target" "target")
     :validate t
     :if-does-not-exist :ignore)
    (uiop:with-current-directory ((%taf-project-dir "demo-build-no-target"))
      (let* ((result (taf.core:project-build
                      :start-dir (han.os:current-directory)
                      :verbose nil))
             (command (getf result :command)))
        (check-true (probe-file (getf command :command-file)))
        (check-true (probe-file (getf command :snapshot-dir)))))))

(deftest test-taf-project-run-forwards-args-and-captures-output ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-run" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-run" "src" "main.taf")
     (format nil "ARGS~%<!(--/-n)name=world>~%RUN~%<shell>~%echo 'run: ::name::'~%"))
    (uiop:with-current-directory ((%taf-project-dir "demo-run" "src"))
      (let ((result (taf.core:project-run
                     :args '("--name" "alice")
                     :start-dir (han.os:current-directory)
                     :input nil
                     :output :string
                     :error-output :string)))
        (check-equal (getf result :exit-code) 0)
        (check-equal (%taf-project-string-contains-p
                      (getf result :stdout)
                      "run: alice")
                     t)))))

(deftest test-taf-project-run-default-does-not-inherit-stdin ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-run-no-stdin" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-run-no-stdin" "src" "main.taf")
     "RUN
<shell>
cat")
    (uiop:with-current-directory ((%taf-project-dir "demo-run-no-stdin"))
      (let ((result (taf.core:project-run
                     :start-dir (han.os:current-directory)
                     :output :string
                     :error-output :string)))
        (check-equal (getf result :exit-code) 0)
        (check-equal (getf result :stdout) "")))))

(deftest test-taf-project-run-keeps-stdin-for-runtime ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-run-stdin" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-run-stdin" "src" "main.taf")
     "RUN
<shell>
cat")
    (uiop:with-current-directory ((%taf-project-dir "demo-run-stdin"))
      (let* ((input (make-string-input-stream (format nil "pipe-data~%")))
             (result (taf.core:project-run
                      :start-dir (han.os:current-directory)
                      :input input
                      :output :string
                      :error-output :string)))
        (check-equal (getf result :exit-code) 0)
        (check-equal (getf result :stdout) (format nil "pipe-data~%"))))))

(deftest test-taf-project-publish-dry-run-latest ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish"
     '("--version" "1.2.3" "--release" "2"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish"))
      (let ((result (taf.core:project-publish
                     :start-dir (han.os:current-directory)
                     :dry-run t
                     :remote-tags '("refs/tags/v1.2.3-r1")
                     :verbose nil)))
        (check-equal (getf result :dry-run) t)
        (check-equal (getf result :published-p) nil)
        (check-equal (getf result :tag) "v1.2.3-r2")
        (check-equal (getf result :channel) :latest)
        (check-equal (getf (getf result :remote-latest) :tag)
                     "v1.2.3-r1")
        (check-equal (%taf-project-string-contains-p
                      (format nil "~S" (getf result :commands))
                      "git")
                     t)))))

(deftest test-taf-project-publish-rejects-non-github-repository ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-gitlab"
     '("--repo" "https://gitlab.example.org/group/demo-publish-gitlab"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-gitlab"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :remote-tags nil
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-existing-tag-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-existing"
     '("--version" "1.2.3" "--release" "2"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-existing"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :remote-tags '("refs/tags/v1.2.3-r2")
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-latest-rejects-older-version ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-old"
     '("--version" "1.2.3" "--release" "2"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-old"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :remote-tags '("refs/tags/v1.3.0-r1")
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-pre-allows-non-latest-version ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-pre"
     '("--version" "1.2.3" "--release" "2"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-pre"))
      (let ((result (taf.core:project-publish
                     :start-dir (han.os:current-directory)
                     :dry-run t
                     :channel :pre
                     :remote-tags '("refs/tags/v1.3.0-r1")
                     :verbose nil)))
        (check-equal (getf result :tag) "v1.2.3-r2")
        (check-equal (getf result :channel) :pre)
        (check-equal (getf (getf result :remote-latest) :tag)
                     "v1.3.0-r1")))))

(deftest test-taf-project-publish-dry-run-build-has-no-side-effect ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-dry-build"
     '("--version" "1.2.3" "--release" "2"))
    (uiop:delete-directory-tree
     (%taf-project-dir "demo-publish-dry-build" "target")
     :validate t
     :if-does-not-exist :ignore)
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-dry-build"))
      (let ((result (taf.core:project-publish
                     :start-dir (han.os:current-directory)
                     :dry-run t
                     :build-p t
                     :remote-tags '("refs/tags/v1.2.3-r1")
                     :verbose nil)))
        (check-equal (getf result :build) nil)
        (check-equal (probe-file (%taf-project-dir
                                  "demo-publish-dry-build" "target"))
                     nil)))))

(deftest test-taf-project-publish-rejects-placeholder-license ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-placeholder-license"
     '("--version" "1.2.3" "--release" "2"))
    (%taf-project-write-string
     (%taf-project-path "demo-publish-placeholder-license" "LICENSE")
     "Apache License 2.0 placeholder.
Please replace this file before publishing.")
    (uiop:with-current-directory ((%taf-project-dir
                                   "demo-publish-placeholder-license"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :remote-tags '("refs/tags/v1.2.3-r1")
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-repository-not-found-output ()
  (check-equal
   (taf.core::%publish-repository-not-found-output-p
    nil
    "remote: Repository not found.")
   t)
  (check-equal
   (taf.core::%publish-repository-not-found-output-p
    "GraphQL: Could not resolve to a Repository"
    nil)
   t)
  (check-equal
   (taf.core::%publish-repository-not-found-output-p
    "fatal: Authentication failed"
    nil)
   nil))

(deftest test-taf-project-publish-normalize-repo-visibility ()
  (check-equal (taf.core::%normalize-publish-repo-visibility nil) :public)
  (check-equal (taf.core::%normalize-publish-repo-visibility :public) :public)
  (check-equal (taf.core::%normalize-publish-repo-visibility "private") :private)
  (check-equal
   (%taf-project-signal-error-p
    (lambda ()
      (taf.core::%normalize-publish-repo-visibility :internal)))
   t))

(deftest test-taf-project-publish-plan-create-repo ()
  (let ((commands
	          (taf.core::%publish-plan-commands
	           "https://github.com/taffish/demo-publish-plan"
	           "v1.2.3-r4"
	           "Publish demo"
	           t
	           :private
	           nil
	           t)))
    (check-equal
     (car commands)
     '("gh" "repo" "create" "taffish/demo-publish-plan"
       "--private" "[if missing]"))
    (check-equal
     (second commands)
     '("gh" "api" "-X" "PUT"
       "repos/taffish/demo-publish-plan/immutable-releases"
       "[if creating repo]"))
    (check-equal
     (third commands)
     '("gh" "api" "-X" "POST"
       "repos/taffish/demo-publish-plan/rulesets"
       "--input" "taffish-release-tag-ruleset.json"
       "[if creating repo]"))))

(deftest test-taf-project-publish-plan-create-repo-no-lock ()
  (let ((commands
          (taf.core::%publish-plan-commands
           "https://github.com/taffish/demo-publish-plan"
           "v1.2.3-r4"
           "Publish demo"
           t
           :public
           nil
           nil)))
    (check-equal 8 (length commands))
    (check-equal
     (car commands)
     '("gh" "repo" "create" "taffish/demo-publish-plan"
       "--public" "[if missing]"))
    (check-equal
     (second commands)
     '("git" "init" "[if needed]"))))

(deftest test-taf-project-publish-release-tag-ruleset-json ()
  (let* ((ruleset (taf.core::%publish-release-tag-ruleset))
         (conditions (han.json:get-json ruleset "conditions"))
         (ref-name (han.json:get-json conditions "ref_name"))
         (include (han.json:get-json ref-name "include"))
         (rules (han.json:get-json ruleset "rules")))
    (check-equal (han.json:get-json ruleset "name") "TAFFISH release tag lock")
    (check-equal (han.json:get-json ruleset "target") "tag")
    (check-equal (han.json:get-json ruleset "enforcement") "active")
    (check-equal (aref include 0) "refs/tags/v*")
    (check-equal (length rules) 2)
    (check-equal (han.json:get-json (aref rules 0) "type") "update")
    (check-equal (han.json:get-json (aref rules 1) "type") "deletion")))

(deftest test-taf-project-publish-release-file-dry-run ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-release"
     '("--version" "1.2.3" "--release" "2"))
    (%taf-project-write-string
     (%taf-project-path "demo-publish-release" "release.md")
     "# fix image mismatch

This release fixes the container image tag.")
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-release"))
      (let* ((result (taf.core:project-publish
                      :start-dir (han.os:current-directory)
                      :dry-run t
                      :release-p t
                      :remote-tags '("refs/tags/v1.2.3-r1")
                      :verbose nil))
             (release (getf result :release))
             (commands (format nil "~S" (getf result :commands))))
        (check-equal (getf release :message) "fix image mismatch")
        (check-equal (getf release :file-display) "release.md")
        (check-equal (%taf-project-string-contains-p
                      (getf release :notes)
                      "container image tag")
                     t)
        (check-equal (%taf-project-string-contains-p
                      (getf result :commit-message)
                      ": fix image mismatch")
                     t)
        (check-equal (%taf-project-string-contains-p
                      commands
                      "release")
                     t)
        (check-equal (%taf-project-string-contains-p
                      commands
                      "release.md")
                     t)
        (check-equal (%taf-project-string-contains-p
                      commands
                      "rm")
                     t)))))

(deftest test-taf-project-publish-release-file-allows-todo-word ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new
     "demo-publish-release-todo-word"
     '("--version" "1.2.3" "--release" "2"))
    (%taf-project-write-string
     (%taf-project-path "demo-publish-release-todo-word" "release.md")
     "# autodock-vina todo wording

This release mentions a todo-like upstream word, but it is not the default template.")
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-release-todo-word"))
      (let* ((result (taf.core:project-publish
                      :start-dir (han.os:current-directory)
                      :dry-run t
                      :release-p t
                      :remote-tags '("refs/tags/v1.2.3-r1")
                      :verbose nil))
             (release (getf result :release)))
        (check-equal (getf release :message) "autodock-vina todo wording")
        (check-equal (%taf-project-string-contains-p
                      (getf release :notes)
                      "todo-like upstream word")
                     t)))))

(deftest test-taf-project-publish-release-file-missing-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-publish-release-missing" nil)
    (delete-file (%taf-project-path "demo-publish-release-missing" "release.md"))
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-release-missing"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :release-p t
           :remote-tags nil
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-release-template-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-publish-release-template" nil)
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-release-template"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :release-p t
           :remote-tags nil
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-release-empty-error ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "demo-publish-release-empty" nil)
    (%taf-project-write-string
     (%taf-project-path "demo-publish-release-empty" "release.md")
     "")
    (uiop:with-current-directory ((%taf-project-dir "demo-publish-release-empty"))
      (check-equal
       (%taf-project-signal-error-p
        (lambda ()
          (taf.core:project-publish
           :start-dir (han.os:current-directory)
           :dry-run t
           :release-p t
           :remote-tags nil
           :verbose nil)))
       t))))

(deftest test-taf-project-publish-noninteractive-git-env ()
  (let ((env (taf.core::%publish-noninteractive-env-args)))
    (dolist (item '("GIT_TERMINAL_PROMPT=0"
                    "GIT_ASKPASS="
                    "SSH_ASKPASS="
                    "GH_PROMPT_DISABLED=1"
                    "GH_NO_UPDATE_NOTIFIER=1"
                    "GIT_SSH_COMMAND=ssh -o BatchMode=yes"))
      (check-equal (not (null (member item env :test #'string=))) t))))

(deftest test-taf-project-publish-env-program-is-executable ()
  (let ((env-program (taf.core::%publish-env-program)))
    (check-true (stringp env-program))
    (check-equal (han.path:->namestring (uiop:file-exists-p env-program))
                 env-program)))

(deftest test-taf-project-publish-sha256-portable-known-vectors ()
  (check-equal
   (taf.core::%publish-sha256 "")
   "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  (check-equal
   (taf.core::%publish-sha256 "abc")
   "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  (check-equal
   (taf.core::%publish-sha256 "中文")
   "72726d8818f693066ceb69afa364218b692e62ea92b385782363780f47529c21")
  (check-equal
   (taf.core::%publish-sha256 "A😀Z")
   "0cfdf4f787538630ab2f98a43b709fb744c6380b0cf350ef895d270a04eecd83"))

(deftest test-taf-project-publish-normalizes-release-note-transport-newlines ()
  (let ((canonical (format nil "# Release title~%~%Release body.")))
    (dolist (equivalent
             (list canonical
                   (format nil "~A~%" canonical)
                   (format nil "~A~%~%" canonical)
                   (format nil
                           "# Release title~C~C~C~CRelease body.~C~C"
                           #\Return #\Newline #\Return #\Newline
                           #\Return #\Newline)))
      (check-equal (taf.core::%publish-normalize-notes equivalent)
                   canonical))
    (check-false
     (string= (taf.core::%publish-normalize-notes canonical)
              (taf.core::%publish-normalize-notes
               (format nil "# Release title~%~%Release body. "))))
    (check-false
     (string= (taf.core::%publish-normalize-notes canonical)
              (taf.core::%publish-normalize-notes
               (format nil "# Release title~%~%Changed body."))))))

(deftest test-taf-project-publish-finds-remote-ref-pairs-portably ()
  (let* ((branch-commit "1111111111111111111111111111111111111111")
         (tag-object "2222222222222222222222222222222222222222")
         (tag-commit "3333333333333333333333333333333333333333")
         (refs (list
                (cons branch-commit "refs/heads/main")
                (cons tag-object "refs/tags/v1.2.3-r2")
                (cons tag-commit "refs/tags/v1.2.3-r2^{}"))))
    (check-equal
     (taf.core::%publish-find-ref "refs/heads/main" refs)
     (cons branch-commit "refs/heads/main"))
    (check-equal
     (taf.core::%publish-remote-tag-commit-from-refs refs "v1.2.3-r2")
     tag-commit)
    (check-equal
     (taf.core::%publish-remote-tag-commit-from-refs refs "v9.9.9-r9")
     nil)))

(deftest test-taf-project-publish-state-machine-first-run-and-safe-noop ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-state-machine" state journal-home)
      (let* ((project-dir (%taf-project-dir "publish-state-machine"))
             (first (taf.core:project-publish
                     :start-dir project-dir
                     :dry-run nil
                     :create-repo-p t
                     :release-p t
                     :verbose nil))
             (journal (taf.core::%publish-journal-file
                       "https://github.com/taffish/publish-state-machine"
                       "v1.2.3-r2")))
        (check-equal (getf first :published-p) t)
        (check-equal (getf first :outcome) :created)
        (check-equal (getf first :complete-p) t)
        (check-equal
         (mapcar (lambda (phase) (getf phase :id)) (getf first :phases))
         '(:project-validated
           :repository-ready
           :repository-policy-ready
           :commit-ready
           :branch-pushed
           :local-tag-ready
           :remote-tag-ready
           :github-release-ready
           :publish-complete))
        (check-true (han.path:file-exists-p journal))
        (setf (getf state :operations) nil)
        (let* ((taf.core::*publish-operation-adapter*
                 (%taf-project-publish-fake-adapter state))
               (second (taf.core:project-publish
                        :start-dir project-dir
                        :dry-run nil
                        :create-repo-p t
                        :release-p t
                        :verbose nil)))
          (check-equal (getf second :outcome) :skipped)
          (check-equal (getf second :complete-p) t)
          (dolist (mutation '(:create-repository
                              :create-policy
                              :create-commit
                              :create-branch
                              :create-local-tag
                              :create-remote-tag
                              :create-release))
            (check-false (member mutation (getf state :operations)))))))))

(deftest test-taf-project-publish-resumes-after-every-side-effect-boundary ()
  (with-taf-project-temp-dir (dir)
    (loop for mutation in '(:create-repository
                            :create-policy
                            :create-commit
                            :create-branch
                            :create-local-tag
                            :create-remote-tag
                            :create-release)
          for expected-last-confirmed in '(:project-validated
                                            :repository-ready
                                            :repository-policy-ready
                                            :commit-ready
                                            :branch-pushed
                                            :local-tag-ready
                                            :remote-tag-ready)
          for index from 1
          for project-name = (format nil "publish-resume-~D" index)
          do
             (with-taf-project-publish-fake
                 (project-name state journal-home :interrupt-after mutation)
               (let* ((project-dir (%taf-project-dir project-name))
                      (first-error
                        (%taf-project-error-string
                         (lambda ()
                           (taf.core:project-publish
                            :start-dir project-dir
                            :dry-run nil
                            :create-repo-p t
                            :release-p t
                            :verbose nil)))))
                 (check-true first-error)
                 (check-true
                  (%taf-project-string-contains-p
                   first-error (string expected-last-confirmed)))
                 (let* ((journal-file
                          (taf.core::%publish-journal-file
                           (format nil "https://github.com/taffish/~A"
                                   project-name)
                           "v1.2.3-r2"))
                        (journal (han.json:read-json-file journal-file)))
                   (check-equal
                    (han.json:get-json journal "last_confirmed_stage")
                    (string-downcase (string expected-last-confirmed))))
                 (let* ((taf.core::*publish-operation-adapter*
                          (%taf-project-publish-fake-adapter state))
                        (result (taf.core:project-publish
                                 :start-dir project-dir
                                 :dry-run nil
                                 :create-repo-p t
                                 :release-p t
                                 :verbose nil)))
                   (check-equal (getf result :outcome) :resumed)
                   (check-equal (getf result :complete-p) t)
                   (check-equal (getf state :remote-tag) "commit-a")
                   (check-true (getf state :release-intent))))))))

(deftest test-taf-project-publish-branch-reconcile-conflicts-with-remote-ref ()
  (let* ((context (list :dry-run t
                        :target-commit "commit-a"
                        :last-confirmed-stage :commit-ready
                        :phases nil
                        :mutation-count 0
                        :resume-evidence-p nil))
         (taf.core::*publish-operation-adapter*
           (lambda (operation ignored-context)
             (declare (ignore ignored-context))
             (case operation
               (:create-branch
                (error "non-fast-forward"))
               (:inspect-branch
                (list :state :missing
                      :evidence "remote branch main is at commit-b, target is commit-a"
                      :actual "commit-b"
                      :commit "commit-a"
                      :branch "main"))
               (otherwise
                (error "unexpected operation: ~S" operation))))))
    (let ((message
            (%taf-project-error-string
             (lambda ()
               (taf.core::%publish-reconcile-mutation
                context :branch-pushed :inspect-branch :create-branch)))))
      (check-true (%taf-project-string-contains-p
                   message "[publish:conflict]"))
      (check-equal (getf (first (getf context :phases)) :status)
                   :conflict)
      (check-equal (getf context :last-confirmed-stage) :commit-ready))))

(deftest test-taf-project-publish-unavailable-inspection-gives-resume-guidance ()
  (with-taf-project-temp-dir (dir)
    (taf.core:project-new "publish-unavailable" nil)
    (let ((taf.core::*publish-journal-user-home*
            (%taf-project-dir "publish-unavailable-journal"))
          (taf.core::*publish-operation-adapter*
            (lambda (operation context)
              (declare (ignore context))
              (case operation
                (:inspect-repository
                 (list :state :unavailable
                       :evidence "GitHub repository inspection is unavailable"))
                (otherwise
                 (error "unexpected publish operation: ~S" operation))))))
      (let ((message
              (%taf-project-error-string
               (lambda ()
                 (taf.core:project-publish
                  :start-dir (%taf-project-dir "publish-unavailable")
                  :dry-run nil
                  :create-repo-p t
                  :verbose nil)))))
        (check-true
         (%taf-project-string-contains-p
          message "rerun the same taf publish command"))
        (check-true
         (%taf-project-string-contains-p
          message "PROJECT-VALIDATED"))))))

(deftest test-taf-project-publish-conflicting-tag-hard-fails ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-identity" state journal-home)
      (setf (getf state :repository-p) t
            (getf state :commit) "commit-a"
            (getf state :branch) "commit-a"
            (getf state :local-tag) "commit-a"
            (getf state :remote-tag) "commit-b")
      (let ((message
              (%taf-project-error-string
               (lambda ()
                 (taf.core:project-publish
                  :start-dir (%taf-project-dir "publish-identity")
                  :dry-run nil
                  :release-p t
                  :verbose nil)))))
        (check-true (%taf-project-string-contains-p
                     message "[publish:conflict]"))
        (check-false (member :create-release (getf state :operations)))))))

(deftest test-taf-project-publish-corrupt-or-missing-journal-defers-to-facts ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-journal" state journal-home)
      (let* ((project-dir (%taf-project-dir "publish-journal"))
             (repository "https://github.com/taffish/publish-journal")
             (tag "v1.2.3-r2")
             (journal (taf.core::%publish-journal-file repository tag)))
        (taf.core:project-publish
         :start-dir project-dir
         :dry-run nil
         :create-repo-p t
         :release-p t
         :verbose nil)
        (%taf-project-write-string journal "{")
        (let ((taf.core::*publish-operation-adapter*
                (%taf-project-publish-fake-adapter state)))
          (check-equal
           (getf (taf.core:project-publish
                  :start-dir project-dir
                  :dry-run nil
                  :create-repo-p t
                  :release-p t
                  :verbose nil)
                 :outcome)
           :skipped))
        (delete-file journal)
        (let ((taf.core::*publish-operation-adapter*
                (%taf-project-publish-fake-adapter state)))
          (check-equal
           (getf (taf.core:project-publish
                  :start-dir project-dir
                  :dry-run nil
                  :create-repo-p t
                  :release-p t
                  :verbose nil)
                 :outcome)
           :skipped))))))

(deftest test-taf-project-publish-dry-run-has-no-journal-or-mutations ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-dry-state" state journal-home)
      (let* ((repository "https://github.com/taffish/publish-dry-state")
             (tag "v1.2.3-r2")
             (journal (taf.core::%publish-journal-file repository tag))
             (result (taf.core:project-publish
                      :start-dir (%taf-project-dir "publish-dry-state")
                      :dry-run t
                      :create-repo-p t
                      :release-p t
                      :verbose nil)))
        (check-equal (getf result :published-p) nil)
        (check-false (han.path:file-exists-p journal))
        (dolist (mutation '(:create-repository
                            :create-policy
                            :create-commit
                            :create-branch
                            :create-local-tag
                            :create-remote-tag
                            :create-release))
          (check-false (member mutation (getf state :operations))))))))

(deftest test-taf-project-publish-release-intent-change-conflicts ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-intent" state journal-home)
      (let ((project-dir (%taf-project-dir "publish-intent")))
        (taf.core:project-publish
         :start-dir project-dir
         :dry-run nil
         :create-repo-p t
         :release-p t
         :verbose nil)
        (%taf-project-write-string
         (%taf-project-path "publish-intent" "release.md")
         "# changed release intent\n\nDifferent immutable notes.\n")
        (setf (getf state :operations) nil)
        (let* ((taf.core::*publish-operation-adapter*
                 (%taf-project-publish-fake-adapter state))
               (message
                 (%taf-project-error-string
                  (lambda ()
                    (taf.core:project-publish
                     :start-dir project-dir
                     :dry-run nil
                     :create-repo-p t
                     :release-p t
                     :verbose nil)))))
          (check-true (%taf-project-string-contains-p message "intent"))
          (dolist (mutation '(:create-repository
                              :create-policy
                              :create-commit
                              :create-branch
                              :create-local-tag
                              :create-remote-tag
                              :create-release))
            (check-false (member mutation (getf state :operations)))))))))

(deftest test-taf-project-publish-history-distinguishes-outcomes ()
  (with-taf-project-temp-dir (dir)
    (with-taf-project-publish-fake
        ("publish-history" state journal-home)
      (let* ((project-dir (%taf-project-dir "publish-history"))
             (history-file (han.path:join-path
                            journal-home "logs" "history.jsonl")))
        (taf.core:project-publish
         :start-dir project-dir
         :dry-run nil
         :create-repo-p t
         :release-p t
         :verbose nil)
        (let ((taf.core::*publish-operation-adapter*
                (%taf-project-publish-fake-adapter state)))
          (taf.core:project-publish
           :start-dir project-dir
           :dry-run nil
           :create-repo-p t
           :release-p t
           :verbose nil))
        (setf (getf state :remote-tag) "conflicting-commit")
        (let ((taf.core::*publish-operation-adapter*
                (%taf-project-publish-fake-adapter state)))
          (%taf-project-error-string
           (lambda ()
             (taf.core:project-publish
              :start-dir project-dir
              :dry-run nil
              :create-repo-p t
              :release-p t
              :verbose nil))))
        (let ((history (han.os:load-string history-file)))
          (check-true (%taf-project-string-contains-p
                       history "\"status\":\"created\""))
          (check-true (%taf-project-string-contains-p
                       history "\"status\":\"skipped\""))
          (check-true (%taf-project-string-contains-p
                       history "\"status\":\"conflict\"")))))))
