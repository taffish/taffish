(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / test.lisp
;;;; ============================================================

(defun %mcp-test-parse (string)
  (han.json:parse-json string))

(defun %mcp-test-result (response)
  (han.json:get-json response "result"))

(defun %mcp-test-error (response)
  (han.json:get-json response "error"))

(defun %mcp-test-tool-names ()
  (let* ((result (tools-list))
         (tools (han.json:get-json result "tools")))
    (loop for i from 0 below (length tools)
          collect (han.json:get-json (aref tools i) "name"))))

(defun %mcp-test-structured (tool-result)
  (han.json:get-json tool-result "structuredContent"))

(defun %mcp-test-temp-root ()
  (han.path:join-path
   (han.path:temporary-directory)
   (format nil "taffish-mcp-test-~A-~A/"
           (get-universal-time)
           (random 1000000))))

(defun %mcp-test-write-file (path content)
  (ensure-directories-exist path)
  (with-open-file (out path
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (write-string content out))
  path)

(defun %mcp-test-replace-substring (string old new)
  (let ((pos (search old string :test #'char=)))
    (unless pos
      (error "Substring not found: ~S" old))
    (concatenate 'string
                 (subseq string 0 pos)
                 new
                 (subseq string (+ pos (length old))))))

(defun %mcp-test-realize-smoke (project-dir)
  (let* ((path (han.path:join-path project-dir "taffish.toml"))
         (toml (han.os:load-string path)))
    (%mcp-test-write-file
     path
     (%mcp-test-replace-substring
      (%mcp-test-replace-substring toml
                                   "exist = [\"TODO\"]"
                                   "exist = [\"sh\"]")
      "test = [\"TODO --help\"]"
      "test = [\"sh -c true\"]"))))

(defmacro with-mcp-env ((name value) &body body)
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

(defmacro with-mcp-available-backends (backends &body body)
  (let ((old-function (gensym "OLD-FUNCTION"))
        (backend-list (gensym "BACKEND-LIST")))
    `(let ((,old-function (symbol-function 'taffish.mcp::%mcp-available-backends))
           (,backend-list ,backends))
       (unwind-protect
            (progn
              (setf (symbol-function 'taffish.mcp::%mcp-available-backends)
                    (lambda () ,backend-list))
              ,@body)
         (setf (symbol-function 'taffish.mcp::%mcp-available-backends)
               ,old-function)))))

(defun %mcp-test-write-current-index (home string)
  (let ((file (han.path:join-path home "index" "current.json")))
    (%mcp-test-write-file file string)
    file))

(defun %mcp-test-app-index (source)
  (format nil "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-11T00:00:00Z\",
  \"packages\": {
    \"mcp-demo\": {
      \"name\": \"mcp-demo\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/mcp-demo\",
      \"command\": {\"name\": \"taf-mcp-demo\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"mcp-demo\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"MIT\",
          \"repository_url\": \"https://github.com/taffish/mcp-demo\",
          \"repository_slug\": \"taffish/mcp-demo\",
          \"command\": {\"name\": \"taf-mcp-demo\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": {
            \"image\": \"ghcr.io/taffish/mcp-demo:0.1.0-r1\",
            \"digest\": \"sha256:2222222222222222222222222222222222222222222222222222222222222222\",
            \"platforms\": [\"linux/amd64\"]
          },
          \"smoke\": {
            \"backend\": \"docker\",
            \"timeout\": 60,
            \"exist\": [\"sh\"],
            \"test\": [\"sh -c true\"],
            \"status\": \"passed\"
          },
          \"source\": {
            \"repository\": \"taffish/mcp-demo\",
            \"ref\": \"v0.1.0-r1\",
            \"local_path\": \"~A\"
          }
        }
      }
    }
  },
  \"commands\": {
    \"taf-mcp-demo\": {\"package\": \"mcp-demo\", \"version\": \"0.1.0-r1\"}
  }
}" (han.path:->namestring source)))

(defmacro with-mcp-installed-app ((root user-home system-home) &body body)
  `(let* ((,root (%mcp-test-temp-root))
          (,user-home (han.path:join-path ,root "user-home"))
          (,system-home (han.path:join-path ,root "system-home"))
          (source-root (han.path:join-path ,root "source-root/")))
     (unwind-protect
          (progn
            (ensure-directories-exist source-root)
            (uiop:with-current-directory (source-root)
              (taf.core:project-new "mcp-demo" '("--tool")))
            (%mcp-test-write-file
             (han.path:join-path source-root "mcp-demo" "src" "main.taf")
             "ARGS
<!(--/-i)input>
<(--/-t)threads=1>
RUN
<taf-app:shell>
echo \"input: ::input::\"
echo \"threads: ::threads::\"
")
            (%mcp-test-write-file
             (han.path:join-path source-root "mcp-demo" "docs" "help.md")
             "# mcp-demo

Usage: taf-mcp-demo-v0.1.0-r1 --input reads.fa [--threads 4]
")
            (%mcp-test-write-current-index
             ,user-home
             (%mcp-test-app-index
              (han.path:join-path source-root "mcp-demo")))
            (taf.core:hub-install :query "mcp-demo"
                                  :user-home ,user-home
                                  :system-home ,system-home
                                  :dry-run-p nil
                                  :verbose nil)
            ,@body)
       (han.path:delete-directory-tree ,root :if-does-not-exist :ignore))))

(defmacro with-mcp-project ((root project-dir nested-dir) &body body)
  `(let* ((,root (%mcp-test-temp-root))
          (,project-dir (han.path:join-path ,root "mcp-project"))
          (,nested-dir (han.path:join-path ,project-dir "src")))
     (unwind-protect
          (progn
            (ensure-directories-exist ,root)
            (uiop:with-current-directory (,root)
              (taf.core:project-new "mcp-project" '("--tool")))
            (%mcp-test-write-file
             (han.path:join-path ,project-dir "src" "main.taf")
             "ARGS
<!(--/-i)input>
<(--/-t)threads=1>
RUN
<taf-app:shell>
echo \"input: ::input::\"
echo \"threads: ::threads::\"
")
            (%mcp-test-write-file
             (han.path:join-path ,project-dir "docs" "help.md")
             "# mcp-project

Usage: taf-mcp-project-v0.1.0-r1 --input reads.fa [--threads 4]
")
            (%mcp-test-write-file
             (han.path:join-path ,project-dir "release.md")
             "# mcp-project 0.1.0-r1

Initial MCP project test release.
")
            ,@body)
       (han.path:delete-directory-tree ,root :if-does-not-exist :ignore))))

(han.test:deftest test-taffish-mcp-version-string-basic ()
  (han.test:check-true (search "taffish-mcp 0.10.0" *taffish-mcp-version*)))

(han.test:deftest test-taffish-mcp-initialize-response ()
  (let* ((raw "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\"}}")
         (response (%mcp-test-parse (handle-json-rpc-string raw)))
         (result (%mcp-test-result response)))
    (han.test:check-equal "2.0" (han.json:get-json response "jsonrpc"))
    (han.test:check-equal 1 (han.json:get-json response "id"))
    (han.test:check-equal "2025-06-18"
                          (han.json:get-json result "protocolVersion"))
    (han.test:check-true
     (han.json:json-object-p (han.json:get-json result "capabilities")))))

(han.test:deftest test-taffish-mcp-tools-list ()
  (let ((names (%mcp-test-tool-names)))
    (han.test:check-true (member "taffish_get_version" names :test #'string=))
    (han.test:check-true (member "taffish_get_help" names :test #'string=))
    (han.test:check-true (member "taffish_validate_source" names :test #'string=))
    (han.test:check-true (member "taffish_compile_source" names :test #'string=))
    (han.test:check-true (member "taffish_summarize_source" names :test #'string=))
    (han.test:check-true (member "taffish_validate_file" names :test #'string=))
    (han.test:check-true (member "taffish_compile_file" names :test #'string=))
    (han.test:check-true (member "taffish_summarize_file" names :test #'string=))
    (han.test:check-true (member "taffish_check_environment" names :test #'string=))
    (han.test:check-true (member "taffish_search_apps" names :test #'string=))
    (han.test:check-true (member "taffish_resolve_app" names :test #'string=))
    (han.test:check-true (member "taffish_inspect_app" names :test #'string=))
    (han.test:check-true (member "taffish_summarize_app_usage" names :test #'string=))
    (han.test:check-true (member "taffish_compile_app_invocation" names :test #'string=))
    (han.test:check-true (member "taffish_check_outdated" names :test #'string=))
    (han.test:check-true (member "taffish_plan_install_all" names :test #'string=))
    (han.test:check-true (member "taffish_plan_upgrade" names :test #'string=))
    (han.test:check-true (member "taffish_plan_prune" names :test #'string=))
    (han.test:check-true (member "taffish_build_project" names :test #'string=))
    (han.test:check-true (member "taffish_create_project" names :test #'string=))
    (han.test:check-true (member "taffish_inspect_project" names :test #'string=))
    (han.test:check-true (member "taffish_summarize_project_usage" names :test #'string=))
    (han.test:check-true (member "taffish_locate_app" names :test #'string=))
    (han.test:check-true (member "taffish_list_history" names :test #'string=))
    (han.test:check-false (member "taffish_doctor_check" names :test #'string=))
    (han.test:check-false (member "taffish_config_get" names :test #'string=))
    (han.test:check-false (member "taffish_which" names :test #'string=))
    (han.test:check-false (member "taffish_run_project" names :test #'string=))
    (han.test:check-false (member "taffish_publish_project" names :test #'string=))))

(han.test:deftest test-taffish-mcp-get-version ()
  (let* ((result (call-tool "taffish_get_version" (han.json:make-json-object)))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-true
     (search "taffish-mcp 0.10.0"
             (han.json:get-json structured "taffish_mcp")))
    (han.test:check-true
     (> (length (han.json:get-json structured "features")) 0))
    (han.test:check-true
     (loop with features = (han.json:get-json structured "features")
           for i from 0 below (length features)
           thereis (string= "project_inspect" (aref features i))))
    (han.test:check-true
     (loop with features = (han.json:get-json structured "features")
           for i from 0 below (length features)
           thereis (string= "project_usage" (aref features i))))
    (han.test:check-true
     (loop with features = (han.json:get-json structured "features")
           for i from 0 below (length features)
           thereis (string= "hub_upgrade_plan" (aref features i))))))

(han.test:deftest test-taffish-mcp-get-help ()
  (let* ((result (call-tool
                  "taffish_get_help"
                  (%json-object (cons "topic" "compiler"))))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal "taffish://compiler/help"
                          (han.json:get-json structured "uri"))
    (han.test:check-true
     (search "taffish_compile_source"
             (han.json:get-json structured "text")))))

(han.test:deftest test-taffish-mcp-get-app-help ()
  (let* ((result (call-tool
                  "taffish_get_help"
                  (%json-object (cons "topic" "app"))))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal "taffish://mcp/app-inspection-model"
                          (han.json:get-json structured "uri"))
    (han.test:check-true
     (search "taffish_inspect_app"
             (han.json:get-json structured "text")))))

(han.test:deftest test-taffish-mcp-get-project-help ()
  (let* ((result (call-tool
                  "taffish_get_help"
                  (%json-object (cons "topic" "project"))))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal "taffish://mcp/project-inspection-model"
                          (han.json:get-json structured "uri"))
    (han.test:check-true
     (search "taffish_inspect_project"
             (han.json:get-json structured "text")))))

(han.test:deftest test-taffish-mcp-compile-source ()
  (let* ((result (call-tool
                  "taffish_compile_source"
                  (%json-object (cons "source" "echo hello"))))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal t (han.json:get-json structured "ok"))
    (han.test:check-true
     (search "echo hello" (han.json:get-json structured "shell")))))

(han.test:deftest test-taffish-mcp-validate-source-reports-invalid ()
  (let* ((result (call-tool
                  "taffish_validate_source"
                  (%json-object (cons "source" ""))))
         (structured (%mcp-test-structured result)))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal nil (han.json:get-json structured "ok"))
    (han.test:check-true
     (han.json:json-object-p (han.json:get-json structured "error")))))

(han.test:deftest test-taffish-mcp-summarize-source ()
  (let* ((source "::(--/-n)name=World::\necho hello @name")
         (result (call-tool
                  "taffish_summarize_source"
                  (%json-object (cons "source" source))))
         (structured (%mcp-test-structured result))
         (args (han.json:get-json structured "args")))
    (han.test:check-equal nil (han.json:get-json result "isError"))
    (han.test:check-equal t (han.json:get-json structured "ok"))
    (han.test:check-equal 1 (length args))))

(han.test:deftest test-taffish-mcp-compile-file ()
  (let* ((root (%mcp-test-temp-root))
         (file (han.path:join-path root "main.taf")))
    (unwind-protect
         (progn
           (%mcp-test-write-file file "echo from-file")
           (let* ((result (call-tool
                           "taffish_compile_file"
                           (%json-object
                            (cons "path" (han.path:->namestring file)))))
                  (structured (%mcp-test-structured result)))
             (han.test:check-equal nil (han.json:get-json result "isError"))
             (han.test:check-equal t (han.json:get-json structured "ok"))
             (han.test:check-true
              (search "echo from-file"
                      (han.json:get-json structured "shell")))))
      (han.path:delete-directory-tree root :if-does-not-exist :ignore))))

(han.test:deftest test-taffish-mcp-json-keeps-string-lists-as-arrays ()
  (let ((value (%mcp-json-value '("uname" "-a"))))
    (han.test:check-true (han.json:json-array-p value))
    (han.test:check-equal "uname" (aref value 0))
    (han.test:check-equal "-a" (aref value 1))))

(han.test:deftest test-taffish-mcp-compiler-context-includes-backend-probe ()
  (let* ((context (%compiler-context (han.json:make-json-object)
                                     '("taffish")))
         (container (cdr (assoc :container context :test #'eql))))
    (han.test:check-true
     (assoc :available-backends container :test #'eql))))

(han.test:deftest test-taffish-mcp-compile-source-uses-env-backend ()
  (let ((source (format nil "RUN~%<container:ghcr.io/taffish/mcp-demo:0.1.0-r1>~%echo hi")))
    (with-mcp-env ("TAFFISH_CONTAINER_BACKEND" "podman")
      (with-mcp-available-backends (list :apptainer :podman :docker)
        (let* ((result (call-tool
                        "taffish_compile_source"
                        (%json-object (cons "source" source))))
               (structured (%mcp-test-structured result))
               (shell (han.json:get-json structured "shell")))
          (han.test:check-equal nil (han.json:get-json result "isError"))
          (han.test:check-equal t (han.json:get-json structured "ok"))
          (han.test:check-true (search "# CHOSEN BACKEND: PODMAN" shell))
          (han.test:check-true (search "# FORCE BACKEND: :PODMAN" shell)))))))

(han.test:deftest test-taffish-mcp-container-backend-arg-overrides-env ()
  (let ((source (format nil "RUN~%<container:ghcr.io/taffish/mcp-demo:0.1.0-r1>~%echo hi")))
    (with-mcp-env ("TAFFISH_CONTAINER_BACKEND" "podman")
      (with-mcp-available-backends (list :apptainer :podman :docker)
        (let* ((result (call-tool
                        "taffish_compile_source"
                        (%json-object
                         (cons "source" source)
                         (cons "containerBackend" "docker"))))
               (structured (%mcp-test-structured result))
               (shell (han.json:get-json structured "shell")))
          (han.test:check-equal nil (han.json:get-json result "isError"))
          (han.test:check-equal t (han.json:get-json structured "ok"))
          (han.test:check-true (search "# CHOSEN BACKEND: DOCKER" shell))
          (han.test:check-true (search "# FORCE BACKEND: :DOCKER" shell)))))))

(han.test:deftest test-taffish-mcp-compile-source-uses-env-run-args ()
  (let ((source (format nil "RUN~%<container:ghcr.io/taffish/mcp-demo:0.1.0-r1$@[docker: --ipc host]>~%echo hi")))
    (with-mcp-env ("TAFFISH_CONTAINER_BACKEND" "docker")
      (with-mcp-env ("TAFFISH_DOCKER_RUN_ARGS" "--gpus all")
        (with-mcp-available-backends (list :apptainer :podman :docker)
          (let* ((result (call-tool
                          "taffish_compile_source"
                          (%json-object (cons "source" source))))
                 (structured (%mcp-test-structured result))
                 (shell (han.json:get-json structured "shell")))
            (han.test:check-equal nil (han.json:get-json result "isError"))
            (han.test:check-equal t (han.json:get-json structured "ok"))
            (han.test:check-true (search "# CHOSEN BACKEND: DOCKER" shell))
            (han.test:check-true (search "--ipc host --gpus all" shell))))))))

(han.test:deftest test-taffish-mcp-invalid-env-backend-is-structured-error ()
  (let ((source (format nil "RUN~%<container:ghcr.io/taffish/mcp-demo:0.1.0-r1>~%echo hi")))
    (with-mcp-env ("TAFFISH_CONTAINER_BACKEND" "bad-backend")
      (with-mcp-available-backends (list :apptainer :podman :docker)
        (let* ((result (call-tool
                        "taffish_compile_source"
                        (%json-object (cons "source" source))))
               (structured (%mcp-test-structured result))
               (error (han.json:get-json structured "error")))
          (han.test:check-equal t (han.json:get-json result "isError"))
          (han.test:check-equal nil (han.json:get-json structured "ok"))
          (han.test:check-true
           (search "bad-backend" (han.json:get-json error "message"))))))))

(han.test:deftest test-taffish-mcp-resolve-installed-app ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_resolve_app"
                    (%json-object
                     (cons "target" "taf-mcp-demo-v0.1.0-r1")
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (index (han.json:get-json structured "index"))
           (install (han.json:get-json structured "install")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal "mcp-demo"
                            (han.json:get-json index "package_name"))
      (han.test:check-equal "taf-mcp-demo-v0.1.0-r1"
                            (han.json:get-json index "artifact_name"))
      (han.test:check-equal t
                            (han.json:get-json install "installed_p"))
      (han.test:check-equal t
                            (han.json:get-json install "source_dir_exists_p")))))

(han.test:deftest test-taffish-mcp-inspect-app-reads-project-main-help ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_inspect_app"
                    (%json-object
                     (cons "target" "mcp-demo")
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (project (han.json:get-json structured "project"))
           (main (han.json:get-json structured "main"))
           (summary (han.json:get-json main "summary"))
           (args (han.json:get-json summary "args"))
           (help (han.json:get-json structured "help"))
           (smoke (han.json:get-json structured "smoke"))
           (trust (han.json:get-json structured "trust"))
           (toml (han.json:get-json structured "toml")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "source_available_p"))
      (han.test:check-equal t (han.json:get-json project "ok"))
      (han.test:check-equal t (han.json:get-json main "available_p"))
      (han.test:check-equal 2 (length args))
      (han.test:check-equal "docker" (han.json:get-json smoke "backend"))
      (han.test:check-equal t (han.json:get-json trust "smoke_present"))
      (han.test:check-equal nil
                            (han.json:get-json trust
                                               "smoke_executed_by_mcp"))
      (han.test:check-true
       (search "Usage: taf-mcp-demo-v0.1.0-r1"
               (han.json:get-json help "text")))
      (han.test:check-true
       (search "[package]"
               (han.json:get-json toml "text"))))))

(han.test:deftest test-taffish-mcp-summarize-app-usage ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_summarize_app_usage"
                    (%json-object
                     (cons "target" "taf-mcp-demo")
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (required (han.json:get-json structured "required_args"))
           (smoke (han.json:get-json structured "smoke"))
           (trust (han.json:get-json structured "trust")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal "taf-mcp-demo-v0.1.0-r1"
                            (han.json:get-json structured "recommended_command"))
      (han.test:check-equal 1 (length required))
      (han.test:check-equal "docker" (han.json:get-json smoke "backend"))
      (han.test:check-equal
       "sha256:2222222222222222222222222222222222222222222222222222222222222222"
       (han.json:get-json trust "container_digest")))))

(han.test:deftest test-taffish-mcp-compile-app-invocation ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((args (han.json:json-array "--input" "reads.fa" "--threads" "8"))
           (result (call-tool
                    "taffish_compile_app_invocation"
                    (%json-object
                     (cons "target" "taf-mcp-demo-v0.1.0-r1")
                     (cons "args" args)
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result)))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "ok"))
      (han.test:check-true
       (search "reads.fa" (han.json:get-json structured "shell")))
      (han.test:check-true
       (search "threads: 8" (han.json:get-json structured "shell"))))))

(han.test:deftest test-taffish-mcp-app-compiler-context-includes-backend-probe ()
  (let* ((context (%app-compiler-context (han.json:make-json-object)
                                         "taf-demo"
                                         '("uname" "-a")
                                         nil))
         (container (cdr (assoc :container context :test #'eql))))
    (han.test:check-true
     (assoc :available-backends container :test #'eql))))

(han.test:deftest test-taffish-mcp-app-compiler-context-uses-env-backend ()
  (with-mcp-env ("TAFFISH_CONTAINER_BACKEND" "apptainer")
    (let* ((context (%app-compiler-context (han.json:make-json-object)
                                           "taf-demo"
                                           '("uname" "-a")
                                           nil))
           (container (cdr (assoc :container context :test #'eql))))
      (han.test:check-equal
       (cdr (assoc :force-backend container :test #'eql))
       :apptainer))))

(han.test:deftest test-taffish-mcp-app-compiler-context-uses-env-run-args ()
  (with-mcp-env ("TAFFISH_APPTAINER_RUN_ARGS" "--nv")
    (let* ((context (%app-compiler-context (han.json:make-json-object)
                                           "taf-demo"
                                           '("uname" "-a")
                                           nil))
           (container (cdr (assoc :container context :test #'eql))))
      (han.test:check-equal
       (cdr (assoc :apptainer-env-exec-args container :test #'eql))
       "--nv"))))

(han.test:deftest test-taffish-mcp-compile-app-invocation-keeps-args-array ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((args (han.json:json-array "--input" "reads.fa"))
           (result (call-tool
                    "taffish_compile_app_invocation"
                    (%json-object
                     (cons "target" "taf-mcp-demo-v0.1.0-r1")
                     (cons "args" args)
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (returned-args (han.json:get-json structured "args")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-true (han.json:json-array-p returned-args))
      (han.test:check-equal "--input" (aref returned-args 0))
      (han.test:check-equal "reads.fa" (aref returned-args 1)))))

(han.test:deftest test-taffish-mcp-install-already-installed-is-structured ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_install_app"
                    (%json-object
                     (cons "target" "mcp-demo")
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (error (han.json:get-json structured "error")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal nil (han.json:get-json structured "ok"))
      (han.test:check-equal t (han.json:get-json structured "dry_run_p"))
      (han.test:check-equal "already-installed"
                            (han.json:get-json error "kind")))))

(han.test:deftest test-taffish-mcp-check-outdated-current-install ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_check_outdated"
                    (%json-object
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result))
           (summary (han.json:get-json structured "summary")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "ok"))
      (han.test:check-equal "outdated"
                            (han.json:get-json structured "operation"))
      (han.test:check-equal 1 (han.json:get-json summary "total"))
      (han.test:check-equal 0 (han.json:get-json summary "outdated"))
      (han.test:check-equal 1 (han.json:get-json summary "current")))))

(han.test:deftest test-taffish-mcp-plan-install-all-is-dry-run ()
  (let* ((root (%mcp-test-temp-root))
         (user-home (han.path:join-path root "user-home"))
         (system-home (han.path:join-path root "system-home"))
         (source-root (han.path:join-path root "source-root/")))
    (unwind-protect
         (progn
           (ensure-directories-exist source-root)
           (uiop:with-current-directory (source-root)
             (taf.core:project-new "mcp-demo" '("--tool")))
           (%mcp-test-write-current-index
            user-home
            (%mcp-test-app-index
             (han.path:join-path source-root "mcp-demo")))
           (let* ((result (call-tool
                           "taffish_plan_install_all"
                           (%json-object
                            (cons "kind" "tool")
                            (cons "userHome" (han.path:->namestring user-home))
                            (cons "systemHome" (han.path:->namestring system-home)))))
                  (structured (%mcp-test-structured result))
                  (summary (han.json:get-json structured "summary")))
             (han.test:check-equal nil (han.json:get-json result "isError"))
             (han.test:check-equal t (han.json:get-json structured "ok"))
             (han.test:check-equal "install_all"
                                   (han.json:get-json structured "operation"))
             (han.test:check-equal t
                                   (han.json:get-json structured "dry_run_p"))
             (han.test:check-equal 1 (han.json:get-json summary "total"))
             (han.test:check-equal 1 (han.json:get-json summary "install"))))
      (han.path:delete-directory-tree root :if-does-not-exist :ignore))))

(han.test:deftest test-taffish-mcp-plan-upgrade-and-prune-are-dry-run ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((upgrade-result (call-tool
                            "taffish_plan_upgrade"
                            (%json-object
                             (cons "target" "mcp-demo")
                             (cons "userHome" (han.path:->namestring user-home))
                             (cons "systemHome" (han.path:->namestring system-home)))))
           (upgrade (%mcp-test-structured upgrade-result))
           (upgrade-summary (han.json:get-json upgrade "summary"))
           (prune-result (call-tool
                          "taffish_plan_prune"
                          (%json-object
                           (cons "target" "mcp-demo")
                           (cons "userHome" (han.path:->namestring user-home))
                           (cons "systemHome" (han.path:->namestring system-home)))))
           (prune (%mcp-test-structured prune-result))
           (prune-summary (han.json:get-json prune "summary")))
      (han.test:check-equal nil (han.json:get-json upgrade-result "isError"))
      (han.test:check-equal t (han.json:get-json upgrade "ok"))
      (han.test:check-equal "upgrade" (han.json:get-json upgrade "operation"))
      (han.test:check-equal t (han.json:get-json upgrade "dry_run_p"))
      (han.test:check-equal 1 (han.json:get-json upgrade-summary "total"))
      (han.test:check-equal 0 (han.json:get-json upgrade-summary "installable"))
      (han.test:check-equal nil (han.json:get-json prune-result "isError"))
      (han.test:check-equal t (han.json:get-json prune "ok"))
      (han.test:check-equal "prune" (han.json:get-json prune "operation"))
      (han.test:check-equal t (han.json:get-json prune "dry_run_p"))
      (han.test:check-equal 1 (han.json:get-json prune-summary "total"))
      (han.test:check-equal 0 (han.json:get-json prune-summary "prunable")))))

(han.test:deftest test-taffish-mcp-compile-app-invocation-reports-invalid ()
  (with-mcp-installed-app (root user-home system-home)
    (let* ((result (call-tool
                    "taffish_compile_app_invocation"
                    (%json-object
                     (cons "target" "taf-mcp-demo-v0.1.0-r1")
                     (cons "args" (han.json:json-array))
                     (cons "userHome" (han.path:->namestring user-home))
                     (cons "systemHome" (han.path:->namestring system-home)))))
           (structured (%mcp-test-structured result)))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal nil (han.json:get-json structured "ok"))
      (han.test:check-true
       (han.json:json-object-p
        (han.json:get-json structured "error"))))))

(han.test:deftest test-taffish-mcp-inspect-project ()
  (with-mcp-project (root project-dir nested-dir)
    (let* ((result (call-tool
                    "taffish_inspect_project"
                    (%json-object
                     (cons "startDir" (han.path:->namestring nested-dir)))))
           (structured (%mcp-test-structured result))
           (project (han.json:get-json structured "project"))
           (check (han.json:get-json project "check"))
           (main (han.json:get-json structured "main"))
           (summary (han.json:get-json main "summary"))
           (args (han.json:get-json summary "args"))
           (help (han.json:get-json structured "help"))
           (release (han.json:get-json structured "release")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "ok"))
      (han.test:check-equal t (han.json:get-json project "ok"))
      (han.test:check-equal "mcp-project"
                            (han.json:get-json check "name"))
      (han.test:check-equal t (han.json:get-json main "available"))
      (han.test:check-equal 2 (length args))
      (han.test:check-true
       (search "Usage: taf-mcp-project-v0.1.0-r1"
               (han.json:get-json help "text")))
      (han.test:check-true
       (search "Initial MCP project test release"
               (han.json:get-json release "text"))))))

(han.test:deftest test-taffish-mcp-inspect-project-not-found-is-ok-false ()
  (let ((root (%mcp-test-temp-root)))
    (unwind-protect
         (progn
           (ensure-directories-exist root)
           (let* ((result (call-tool
                           "taffish_inspect_project"
                           (%json-object
                            (cons "startDir" (han.path:->namestring root)))))
                  (structured (%mcp-test-structured result))
                  (error (han.json:get-json structured "error")))
             (han.test:check-equal nil (han.json:get-json result "isError"))
             (han.test:check-equal nil (han.json:get-json structured "ok"))
             (han.test:check-equal "project-not-found"
                                   (han.json:get-json error "kind"))))
      (han.path:delete-directory-tree root :if-does-not-exist :ignore))))

(han.test:deftest test-taffish-mcp-summarize-project-usage ()
  (with-mcp-project (root project-dir nested-dir)
    (let* ((result (call-tool
                    "taffish_summarize_project_usage"
                    (%json-object
                     (cons "startDir" (han.path:->namestring nested-dir)))))
           (structured (%mcp-test-structured result))
           (required (han.json:get-json structured "required_args")))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "ok"))
      (han.test:check-equal "mcp-project"
                            (han.json:get-json structured "name"))
      (han.test:check-equal "taf-mcp-project-v0.1.0-r1"
                            (han.json:get-json structured "recommended_command"))
      (han.test:check-equal 1 (length required)))))

(han.test:deftest test-taffish-mcp-container-project-exposes-smoke ()
  (let* ((root (%mcp-test-temp-root))
         (project-dir (han.path:join-path root "mcp-smoke"))
         (nested-dir (han.path:join-path project-dir "src")))
    (unwind-protect
         (progn
           (ensure-directories-exist root)
           (uiop:with-current-directory (root)
             (taf.core:project-new "mcp-smoke" '("--tool" "--docker")))
           (%mcp-test-realize-smoke project-dir)
           (let* ((result (call-tool
                           "taffish_summarize_project_usage"
                           (%json-object
                            (cons "startDir"
                                  (han.path:->namestring nested-dir)))))
                  (structured (%mcp-test-structured result))
                  (smoke (han.json:get-json structured "smoke"))
                  (trust (han.json:get-json structured "trust")))
             (han.test:check-equal nil (han.json:get-json result "isError"))
             (han.test:check-equal t (han.json:get-json structured "ok"))
             (han.test:check-equal "docker"
                                   (han.json:get-json smoke "backend"))
             (han.test:check-equal "taffish.toml"
                                   (han.json:get-json trust "smoke_source"))
             (han.test:check-equal nil
                                   (han.json:get-json
                                    trust
                                    "smoke_executed_by_mcp"))))
      (han.path:delete-directory-tree root :if-does-not-exist :ignore))))

(han.test:deftest test-taffish-mcp-compile-project-has-ok-field ()
  (with-mcp-project (root project-dir nested-dir)
    (let* ((result (call-tool
                    "taffish_compile_project"
                    (%json-object
                     (cons "startDir" (han.path:->namestring nested-dir))
                     (cons "args" (han.json:json-array "--input" "reads.fa")))))
           (structured (%mcp-test-structured result)))
      (han.test:check-equal nil (han.json:get-json result "isError"))
      (han.test:check-equal t (han.json:get-json structured "ok"))
      (han.test:check-true
       (search "reads.fa" (han.json:get-json structured "shell"))))))

(han.test:deftest test-taffish-mcp-tools-call-unknown-is-tool-error ()
  (let* ((raw "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"missing_tool\",\"arguments\":{}}}")
         (response (%mcp-test-parse (handle-json-rpc-string raw)))
         (result (%mcp-test-result response))
         (structured (%mcp-test-structured result))
         (error (han.json:get-json structured "error")))
    (han.test:check-equal t (han.json:get-json result "isError"))
    (han.test:check-equal nil (han.json:get-json structured "ok"))
    (han.test:check-equal "mcp-error" (han.json:get-json error "kind"))
    (han.test:check-true
     (search "Unknown TAFFISH MCP tool"
             (han.json:get-json
              (aref (han.json:get-json result "content") 0)
              "text")))))

(han.test:deftest test-taffish-mcp-resources-list ()
  (let* ((result (resources-list))
         (resources (han.json:get-json result "resources")))
    (han.test:check-true (> (length resources) 0))
    (han.test:check-equal "taffish://config"
                          (han.json:get-json (aref resources 0) "uri"))
    (han.test:check-true
     (loop for i from 0 below (length resources)
           thereis (string= "taffish://project/current/summary"
                            (han.json:get-json (aref resources i) "uri"))))
    (han.test:check-true
     (loop for i from 0 below (length resources)
           thereis (string= "taffish://project/current/docs/help.md"
                            (han.json:get-json (aref resources i) "uri"))))
    (han.test:check-true
     (loop for i from 0 below (length resources)
           thereis (string= "taffish://project/current/release.md"
                            (han.json:get-json (aref resources i) "uri"))))
    (han.test:check-true
     (loop for i from 0 below (length resources)
           thereis (string= "taffish://mcp/project-inspection-model"
                            (han.json:get-json (aref resources i) "uri"))))))

(han.test:deftest test-taffish-mcp-compiler-help-resource ()
  (let* ((result (read-resource "taffish://compiler/help"))
         (contents (han.json:get-json result "contents"))
         (text (han.json:get-json (aref contents 0) "text")))
    (han.test:check-true (search "taffish_compile_source" text))))

(han.test:deftest test-taffish-mcp-tools-resource ()
  (let* ((result (read-resource "taffish://mcp/tools"))
         (contents (han.json:get-json result "contents"))
         (text (han.json:get-json (aref contents 0) "text")))
    (han.test:check-true (search "taffish_get_version" text))
    (han.test:check-true (search "taffish_compile_source" text))))

(han.test:deftest test-taffish-mcp-resource-unknown-returns-error-content ()
  (let* ((result (read-resource "taffish://missing"))
         (contents (han.json:get-json result "contents"))
         (text (han.json:get-json (aref contents 0) "text")))
    (han.test:check-true (search "TAFFISH-MCP-ERROR" text))))

(han.test:deftest test-taffish-mcp-project-resources ()
  (with-mcp-project (root project-dir nested-dir)
    (uiop:with-current-directory (nested-dir)
      (let* ((summary-result (read-resource "taffish://project/current/summary"))
             (summary-text (han.json:get-json
                            (aref (han.json:get-json summary-result "contents") 0)
                            "text"))
             (summary (han.json:parse-json summary-text))
             (help-result (read-resource "taffish://project/current/docs/help.md"))
             (help-text (han.json:get-json
                         (aref (han.json:get-json help-result "contents") 0)
                         "text"))
             (release-result (read-resource "taffish://project/current/release.md"))
             (release-text (han.json:get-json
                            (aref (han.json:get-json release-result "contents") 0)
                            "text")))
        (han.test:check-equal t (han.json:get-json summary "ok"))
        (han.test:check-true (search "mcp-project" summary-text))
        (han.test:check-true (search "taf-mcp-project-v0.1.0-r1" help-text))
        (han.test:check-true (search "Initial MCP project test release"
                                     release-text))))))

(han.test:deftest test-taffish-mcp-prompts-list ()
  (let* ((result (prompts-list))
         (prompts (han.json:get-json result "prompts")))
    (han.test:check-true (> (length prompts) 0))
    (han.test:check-equal "create-taffish-tool"
                          (han.json:get-json (aref prompts 0) "name"))
    (han.test:check-true
     (loop for i from 0 below (length prompts)
           thereis (string= "explain-taf-source"
                            (han.json:get-json (aref prompts i) "name"))))
    (han.test:check-true
     (loop for i from 0 below (length prompts)
           thereis (string= "inspect-taffish-app"
                            (han.json:get-json (aref prompts i) "name"))))))

(han.test:deftest test-taffish-mcp-prompt-uses-arguments ()
  (let* ((result (get-prompt
                  "inspect-taffish-app"
                  (%json-object (cons "target" "taf-demo-v0.1.0-r1"))))
         (messages (han.json:get-json result "messages"))
         (text (han.json:get-json
                (han.json:get-json (aref messages 0) "content")
                "text")))
    (han.test:check-true (search "Target: taf-demo-v0.1.0-r1" text))))

(han.test:deftest test-taffish-mcp-prompt-unknown ()
  (let* ((result (get-prompt "missing-prompt" (han.json:make-json-object)))
         (messages (han.json:get-json result "messages"))
         (text (han.json:get-json
                (han.json:get-json (aref messages 0) "content")
                "text")))
    (han.test:check-true (search "Unknown TAFFISH MCP prompt" text))))

(han.test:deftest test-taffish-mcp-json-rpc-method-not-found ()
  (let* ((raw "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"no/such\"}")
         (response (%mcp-test-parse (handle-json-rpc-string raw)))
         (error (%mcp-test-error response)))
    (han.test:check-equal -32601 (han.json:get-json error "code"))))
