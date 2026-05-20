(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / tools.lisp
;;;; ============================================================

(defmacro %quietly (&body body)
  `(let ((*standard-output* (make-broadcast-stream)))
     ,@body))

(defun %schema-object (&rest properties)
  (%json-object
   (cons "type" "object")
   (cons "properties" (apply #'%json-object properties))))

(defun %schema-string (&optional description)
  (if description
      (%json-object (cons "type" "string") (cons "description" description))
      (%json-object (cons "type" "string"))))

(defun %schema-container-backend ()
  (%schema-string
   "Force container backend: apptainer, podman, or docker. If omitted, TAFFISH_CONTAINER_BACKEND is used when set."))

(defun %schema-integer (&optional description)
  (if description
      (%json-object (cons "type" "integer") (cons "description" description))
      (%json-object (cons "type" "integer"))))

(defun %schema-boolean (&optional description)
  (if description
      (%json-object (cons "type" "boolean") (cons "description" description))
      (%json-object (cons "type" "boolean"))))

(defun %schema-string-array (&optional description)
  (let ((schema (%json-object
                 (cons "type" "array")
                 (cons "items" (%json-object (cons "type" "string"))))))
    (when description
      (han.json:set-json schema "description" description))
    schema))

(defun %tool-schema (&key properties required)
  (let ((schema (%schema-object
                 (cons "scope" (%schema-string "TAFFISH scope: user or system."))
                 (cons "userHome" (%schema-string "Override TAFFISH user home."))
                 (cons "systemHome" (%schema-string "Override TAFFISH system home.")))))
    (dolist (pair properties)
      (han.json:set-json (han.json:get-json schema "properties")
                         (car pair)
                         (cdr pair)))
    (when required
      (han.json:set-json schema "required" (coerce required 'vector)))
    schema))

(defun %tool (name title description input-schema)
  (%json-object
   (cons "name" name)
   (cons "title" title)
   (cons "description" description)
   (cons "inputSchema" input-schema)))

(defun tools-list ()
  (%json-object
   (cons "tools"
         (%json-array
          (%tool "taffish_get_version"
                 "Get TAFFISH Version"
                 "Return TAFFISH MCP, taf, taffish, protocol, and feature version metadata. Read-only."
                 (%tool-schema))
          (%tool "taffish_get_help"
                 "Get TAFFISH MCP Help"
                 "Return concise MCP help text for a topic and the backing resource URI. Read-only."
                 (%tool-schema
                  :properties (list (cons "topic" (%schema-string "Help topic: mcp, tools, compiler, hub, app, project, or safety.")))))
          (%tool "taffish_validate_source"
                 "Validate TAF Source"
                 "Validate a TAF source string by parsing, binding, and compiling it. Read-only; does not execute shell code."
                 (%tool-schema
                  :properties (list (cons "source" (%schema-string "TAF source string."))
                                    (cons "args" (%schema-string-array "Optional runtime arguments for argument binding."))
                                    (cons "containerBackend" (%schema-container-backend)))
                  :required '("source")))
          (%tool "taffish_compile_source"
                 "Compile TAF Source"
                 "Compile a TAF source string into shell code. Read-only; does not execute shell code."
                 (%tool-schema
                  :properties (list (cons "source" (%schema-string "TAF source string."))
                                    (cons "args" (%schema-string-array "Optional runtime arguments for argument binding."))
                                    (cons "containerBackend" (%schema-container-backend)))
                  :required '("source")))
          (%tool "taffish_summarize_source"
                 "Summarize TAF Source"
                 "Summarize tags, arguments, container blocks, and taf-app calls from a TAF source string. Read-only."
                 (%tool-schema
                  :properties (list (cons "source" (%schema-string "TAF source string.")))
                  :required '("source")))
          (%tool "taffish_validate_file"
                 "Validate TAF File"
                 "Validate a local .taf file by parsing, binding, and compiling it. Read-only; does not execute shell code."
                 (%tool-schema
                  :properties (list (cons "path" (%schema-string "Path to a local .taf file."))
                                    (cons "args" (%schema-string-array "Optional runtime arguments for argument binding."))
                                    (cons "containerBackend" (%schema-container-backend)))
                  :required '("path")))
          (%tool "taffish_compile_file"
                 "Compile TAF File"
                 "Compile a local .taf file into shell code. Read-only; does not execute shell code."
                 (%tool-schema
                  :properties (list (cons "path" (%schema-string "Path to a local .taf file."))
                                    (cons "args" (%schema-string-array "Optional runtime arguments for argument binding."))
                                    (cons "containerBackend" (%schema-container-backend)))
                  :required '("path")))
          (%tool "taffish_summarize_file"
                 "Summarize TAF File"
                 "Summarize tags, arguments, container blocks, and taf-app calls from a local .taf file. Read-only."
                 (%tool-schema
                  :properties (list (cons "path" (%schema-string "Path to a local .taf file.")))
                  :required '("path")))
          (%tool "taffish_check_environment"
                 "Check TAFFISH Environment"
                 "Check local TAFFISH directories, PATH, and related executables. Does not initialize or modify the system."
                 (%tool-schema))
          (%tool "taffish_get_config"
                 "Get TAFFISH Config"
                 "Return effective TAFFISH runtime configuration. Read-only."
                 (%tool-schema))
          (%tool "taffish_get_config_paths"
                 "Get TAFFISH Config Paths"
                 "Return TAFFISH config file paths. Read-only."
                 (%tool-schema))
          (%tool "taffish_update_index"
                 "Update TAFFISH Index"
                 "Download and update the local TAFFISH index. Writes index files under TAFFISH home."
                 (%tool-schema
                  :properties (list (cons "url" (%schema-string "Override index URL.")))))
          (%tool "taffish_search_apps"
                 "Search TAFFISH Apps"
                 "Search apps from the local TAFFISH index."
                 (%tool-schema
                  :properties (list (cons "query" (%schema-string "Search keyword(s)."))
                                    (cons "limit" (%schema-integer "Maximum result count.")))
                  :required '("query")))
          (%tool "taffish_get_app_info"
                 "Get TAFFISH App Info"
                 "Resolve an app, command, or artifact from the local index and return its version record."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id such as 1.2.3-r1 or v1.2.3-r1.")))
                  :required '("target")))
          (%tool "taffish_resolve_app"
                 "Resolve TAFFISH App"
                 "Resolve an app, command alias, or version-pinned artifact command using the local index and local install metadata."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id such as 1.2.3-r1 or v1.2.3-r1.")))
                  :required '("target")))
          (%tool "taffish_inspect_app"
                 "Inspect TAFFISH App"
                 "Inspect index metadata plus installed taffish.toml, src/main.taf, docs/help.md, smoke, and trust metadata when local source is installed. Read-only."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id."))
                                    (cons "includeHelp" (%schema-boolean "Include docs/help.md text. Default true."))
                                    (cons "includeSource" (%schema-boolean "Include src/main.taf text. Default false."))
                                    (cons "helpMaxBytes" (%schema-integer "Maximum help bytes returned. Default 262144.")))
                  :required '("target")))
          (%tool "taffish_summarize_app_usage"
                 "Summarize TAFFISH App Usage"
                 "Return AI-oriented usage data for an indexed/installed taf-app: command, args, help, containers, smoke, trust, and dependencies. Read-only."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id."))
                                    (cons "includeHelp" (%schema-boolean "Include docs/help.md text. Default true."))
                                    (cons "helpMaxBytes" (%schema-integer "Maximum help bytes returned. Default 262144.")))
                  :required '("target")))
          (%tool "taffish_compile_app_invocation"
                 "Compile TAFFISH App Invocation"
                 "Validate candidate taf-app arguments and compile the installed app's main.taf to shell code without running it."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id."))
                                    (cons "args" (%schema-string-array "Runtime arguments as if passed after taf-xxx --compile."))
                                    (cons "containerBackend" (%schema-container-backend)))
                  :required '("target")))
          (%tool "taffish_list_apps"
                 "List TAFFISH Apps"
                 "List installed apps or indexed online apps."
                 (%tool-schema
                  :properties (list (cons "mode" (%schema-string "Accepted: local/installed or online/index. Returned mode is canonicalized to local or online."))
                                    (cons "limit" (%schema-integer "Maximum result count.")))))
          (%tool "taffish_check_outdated"
                 "Check Outdated TAFFISH Apps"
                 "Compare local installs with the local index and return an upgrade plan. Read-only."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "Optional single app or command."))
                                    (cons "targets" (%schema-string-array "Optional apps or commands."))
                                    (cons "kind" (%schema-string "Filter: tool, flow, or all. Default all.")))))
          (%tool "taffish_plan_install_all"
                 "Plan Install All TAFFISH Apps"
                 "Plan installation of all indexed apps selected by kind. Dry-run only; does not write files."
                 (%tool-schema
                  :properties (list (cons "kind" (%schema-string "Filter: tool, flow, or all. Default all."))
                                    (cons "pruneOld" (%schema-boolean "Plan keeping only newest local versions after install. Does not delete.")))))
          (%tool "taffish_plan_upgrade"
                 "Plan TAFFISH Upgrade"
                 "Plan installing newer indexed versions for local apps. Dry-run only; does not install."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "Optional single app or command."))
                                    (cons "targets" (%schema-string-array "Optional apps or commands."))
                                    (cons "kind" (%schema-string "Filter: tool, flow, or all. Default all."))
                                    (cons "pruneOld" (%schema-boolean "Plan pruning old versions after upgrade. Does not delete.")))))
          (%tool "taffish_plan_prune"
                 "Plan TAFFISH Prune"
                 "Plan removal of older local app versions. Dry-run only; does not delete files."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "Optional single app or command."))
                                    (cons "targets" (%schema-string-array "Optional apps or commands."))
                                    (cons "kind" (%schema-string "Filter: tool, flow, or all. Default all.")))))
          (%tool "taffish_locate_app"
                 "Locate TAFFISH App"
                 "Show local install paths and metadata for an installed app or command."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "App name, command name, or artifact command."))
                                    (cons "version" (%schema-string "Optional version id.")))
                  :required '("target")))
          (%tool "taffish_list_history"
                 "List TAFFISH History"
                 "Read local TAFFISH run history. Does not clear history."
                 (%tool-schema
                  :properties (list (cons "last" (%schema-integer "Number of latest events."))
                                    (cons "id" (%schema-string "Filter by history id."))
                                    (cons "pathOnly" (%schema-boolean "Return only the history file path.")))))
          (%tool "taffish_install_app"
                 "Install TAFFISH App"
                 "Install apps or commands from the local index. Defaults to dryRun=true for safety."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "Single app or command to install."))
                                    (cons "targets" (%schema-string-array "Multiple apps or commands to install."))
                                    (cons "version" (%schema-string "Optional version id for single target."))
                                    (cons "dryRun" (%schema-boolean "Plan only without writing. Default true."))
                                    (cons "force" (%schema-boolean "Replace existing install paths if needed."))
                                    (cons "installDependencies" (%schema-boolean "Install index dependencies. Default true.")))
                  :required nil))
          (%tool "taffish_uninstall_app"
                 "Uninstall TAFFISH App"
                 "Uninstall local apps or commands. Defaults to dryRun=true for safety."
                 (%tool-schema
                  :properties (list (cons "target" (%schema-string "Single app or command to uninstall."))
                                    (cons "targets" (%schema-string-array "Multiple apps or commands to uninstall."))
                                    (cons "version" (%schema-string "Optional version id for single target."))
                                    (cons "dryRun" (%schema-boolean "Plan only without deleting. Default true."))
                                    (cons "force" (%schema-boolean "Allow missing or ambiguous targets when supported.")))))
          (%tool "taffish_create_project"
                 "Create TAFFISH Project"
                 "Create a new TAFFISH app project in the current working directory. Writes files."
                 (%tool-schema
                  :properties (list (cons "name" (%schema-string "Project/app name."))
                                    (cons "kind" (%schema-string "tool or flow."))
                                    (cons "version" (%schema-string "Project version."))
                                    (cons "release" (%schema-integer "Project release number."))
                                    (cons "license" (%schema-string "License id."))
                                    (cons "repo" (%schema-string "GitHub repository URL."))
                                    (cons "image" (%schema-string "Container image URL."))
                                    (cons "docker" (%schema-boolean "Create Dockerfile."))
                                    (cons "actions" (%schema-boolean "Create GitHub Actions image workflow.")))
                  :required '("name")))
          (%tool "taffish_check_project"
                 "Check TAFFISH Project"
                 "Check the current TAFFISH app project, including smoke metadata validation for containerized projects. Read-only."
                 (%tool-schema
                  :properties (list (cons "startDir" (%schema-string "Directory inside the project.")))))
          (%tool "taffish_inspect_project"
                 "Inspect TAFFISH Project"
                 "Inspect the current TAFFISH app project: manifest, main.taf summary, docs/help.md, release.md, local artifacts, smoke, and trust metadata. Read-only."
                 (%tool-schema
                  :properties (list (cons "startDir" (%schema-string "Directory inside the project."))
                                    (cons "includeHelp" (%schema-boolean "Include docs/help.md text. Default true."))
                                    (cons "includeSource" (%schema-boolean "Include src/main.taf text. Default false."))
                                    (cons "includeRelease" (%schema-boolean "Include release.md text. Default true."))
                                    (cons "helpMaxBytes" (%schema-integer "Maximum help bytes returned. Default 262144."))
                                    (cons "releaseMaxBytes" (%schema-integer "Maximum release.md bytes returned. Default 262144.")))))
          (%tool "taffish_summarize_project_usage"
                 "Summarize TAFFISH Project Usage"
                 "Return AI-oriented usage data for the current TAFFISH project: command, args, help, containers, smoke, trust, and dependencies. Read-only."
                 (%tool-schema
                  :properties (list (cons "startDir" (%schema-string "Directory inside the project."))
                                    (cons "includeHelp" (%schema-boolean "Include docs/help.md text. Default true."))
                                    (cons "helpMaxBytes" (%schema-integer "Maximum help bytes returned. Default 262144.")))))
          (%tool "taffish_compile_project"
                 "Compile TAFFISH Project"
                 "Compile the current project and return generated shell. Does not execute it."
                 (%tool-schema
                  :properties (list (cons "startDir" (%schema-string "Directory inside the project."))
                                    (cons "args" (%schema-string-array "Runtime arguments passed to the taf script."))
                                    (cons "containerBackend" (%schema-container-backend)))))
          (%tool "taffish_build_project"
                 "Build TAFFISH Project Wrapper"
                 "Build the current project command wrapper. Container image builds are intentionally not exposed."
                 (%tool-schema
                  :properties (list (cons "startDir" (%schema-string "Directory inside the project.")))))))))

(defun %mcp-scope (arguments)
  (let ((scope (%json-string arguments "scope" "user")))
    (cond
      ((string-equal scope "user") :user)
      ((string-equal scope "system") :system)
      (t (error "scope must be user or system, got: ~S" scope)))))

(defun %mcp-targets (arguments)
  (let ((targets (%json-string-array-or-single arguments "targets"))
        (target (%json-string arguments "target")))
    (or targets
        (and target (list target))
        (error "target or targets is required."))))

(defun %mcp-optional-targets (arguments)
  (let ((targets (%json-string-array-or-single arguments "targets"))
        (target (%json-string arguments "target")))
    (or targets
        (and target (list target)))))

(defun %mcp-target-plists (targets version)
  (if (and version (= (length targets) 1))
      (list (list :query (first targets) :version-id version))
      targets))

(defun %mcp-kind (arguments)
  (or (%json-string arguments "kind") "all"))

(defun %call-get-version (arguments)
  (declare (ignore arguments))
  (%tool-success
   "TAFFISH version metadata."
   (list :taffish-mcp *taffish-mcp-version*
         :taf taf.cli:*taf-version*
         :taffish taffish.cli:*taffish-version*
         :mcp-protocol *mcp-default-protocol-version*
         :features '("compiler_source"
                     "compiler_file"
                     "app_resolve"
                     "app_inspect"
                     "app_usage"
                     "app_invocation_compile"
                     "hub_read"
                     "hub_safe_install_dry_run"
                     "hub_outdated"
                     "hub_upgrade_plan"
                     "hub_install_all_plan"
                     "hub_prune_plan"
                     "project_check"
                     "project_inspect"
                     "project_usage"
                     "project_compile"
                     "project_build_no_image"
                     "smoke_metadata"
                     "trust_metadata"
                     "resources"
                     "prompts")
         :not-exposed '("taf_run"
                        "taf_publish"
                        "container_image_build"))))

(defun %help-topic-uri (topic)
  (cond
    ((or (null topic) (string-equal topic "mcp"))
     "taffish://mcp/help")
    ((string-equal topic "tools")
     "taffish://mcp/tool-groups")
    ((string-equal topic "compiler")
     "taffish://compiler/help")
    ((string-equal topic "hub")
     "taffish://hub/install-model")
    ((string-equal topic "app")
     "taffish://mcp/app-inspection-model")
    ((string-equal topic "project")
     "taffish://mcp/project-inspection-model")
    ((string-equal topic "safety")
     "taffish://mcp/safety")
    (t
     (error "Unknown help topic: ~A. Expected mcp, tools, compiler, hub, app, project, or safety."
            topic))))

(defun %resource-first-text (resource-result)
  (let* ((contents (han.json:get-json resource-result "contents"))
         (first (and (han.json:json-array-p contents)
                     (> (length contents) 0)
                     (aref contents 0))))
    (or (and first (han.json:get-json first "text"))
        "")))

(defun %call-get-help (arguments)
  (let* ((topic (%json-string arguments "topic" "mcp"))
         (uri (%help-topic-uri topic))
         (text (%resource-first-text (read-resource uri))))
    (%tool-success
     (format nil "TAFFISH MCP help topic: ~A" topic)
     (list :topic topic
           :uri uri
           :text text))))

(defun %call-doctor-check (arguments)
  (let ((result (taf.core:system-doctor :scope (%mcp-scope arguments)
                                        :user-home (%json-string arguments "userHome")
                                        :system-home (%json-string arguments "systemHome")
                                        :init-p nil
                                        :verbose nil)))
    (%tool-success (format nil "TAFFISH doctor status: ~A"
                           (getf result :status))
                   (append result
                           (list :taffish-container-backend
                                 (han.host:getenv "TAFFISH_CONTAINER_BACKEND"))))))

(defun %call-config-get (arguments)
  (let ((result (taf.core:system-config :scope (%mcp-scope arguments)
                                        :user-home (%json-string arguments "userHome")
                                        :system-home (%json-string arguments "systemHome")
                                        :verbose nil)))
    (%tool-success "TAFFISH effective config." result)))

(defun %call-config-path (arguments)
  (let ((result (taf.core:system-config-path :scope (%mcp-scope arguments)
                                             :user-home (%json-string arguments "userHome")
                                             :system-home (%json-string arguments "systemHome")
                                             :verbose nil)))
    (%tool-success "TAFFISH config paths." result)))

(defun %call-update-index (arguments)
  (let ((result (taf.core:hub-update :scope (%mcp-scope arguments)
                                     :user-home (%json-string arguments "userHome")
                                     :system-home (%json-string arguments "systemHome")
                                     :index-url (%json-string arguments "url")
                                     :verbose nil)))
    (%tool-success (format nil "Updated TAFFISH index from ~A."
                           (getf result :source))
                   result)))

(defun %call-search-apps (arguments)
  (let ((result (taf.core:hub-search :query (%json-string arguments "query")
                                     :scope (%mcp-scope arguments)
                                     :user-home (%json-string arguments "userHome")
                                     :system-home (%json-string arguments "systemHome")
                                     :limit (%json-int arguments "limit" 20)
                                     :verbose nil)))
    (%tool-success (format nil "Found ~A matching TAFFISH app(s)."
                           (getf result :total))
                   result)))

(defun %call-get-app-info (arguments)
  (let ((result (taf.core:hub-info :query (%json-string arguments "target")
                                   :version-id (%json-string arguments "version")
                                   :scope (%mcp-scope arguments)
                                   :user-home (%json-string arguments "userHome")
                                   :system-home (%json-string arguments "systemHome")
                                   :verbose nil)))
    (%tool-success (format nil "Resolved TAFFISH target ~A."
                           (getf result :query))
                   result)))

(defun %call-list-apps (arguments)
  (let ((result (taf.core:hub-list :mode (or (%json-string arguments "mode") "local")
                                   :scope (%mcp-scope arguments)
                                   :user-home (%json-string arguments "userHome")
                                   :system-home (%json-string arguments "systemHome")
                                   :limit (%json-int arguments "limit" nil)
                                   :verbose nil)))
    (%tool-success (format nil "Listed ~A TAFFISH app(s)."
                           (length (getf result :items)))
                   result)))

(defun %call-check-outdated (arguments)
  (let ((result (taf.core:hub-outdated
                 :targets (%mcp-optional-targets arguments)
                 :scope (%mcp-scope arguments)
                 :user-home (%json-string arguments "userHome")
                 :system-home (%json-string arguments "systemHome")
                 :kind (%mcp-kind arguments)
                 :verbose nil)))
    (%tool-success
     (format nil "Found ~A outdated TAFFISH app(s)."
             (getf (getf result :summary) :outdated))
     (append (list :ok t) result))))

(defun %call-plan-install-all (arguments)
  (let ((result (taf.core:hub-install-all
                 :scope (%mcp-scope arguments)
                 :user-home (%json-string arguments "userHome")
                 :system-home (%json-string arguments "systemHome")
                 :kind (%mcp-kind arguments)
                 :dry-run-p t
                 :yes-p nil
                 :prune-old-p (%json-bool arguments "pruneOld" nil)
                 :verbose nil)))
    (%tool-success
     (format nil "Planned install-all for ~A TAFFISH app(s)."
             (getf (getf result :summary) :total))
     (append (list :ok t) result))))

(defun %call-plan-upgrade (arguments)
  (let ((result (taf.core:hub-upgrade
                 :targets (%mcp-optional-targets arguments)
                 :scope (%mcp-scope arguments)
                 :user-home (%json-string arguments "userHome")
                 :system-home (%json-string arguments "systemHome")
                 :kind (%mcp-kind arguments)
                 :dry-run-p t
                 :yes-p nil
                 :prune-old-p (%json-bool arguments "pruneOld" nil)
                 :verbose nil)))
    (%tool-success
     (format nil "Planned upgrade for ~A TAFFISH app(s)."
             (getf (getf result :summary) :installable))
     (append (list :ok t) result))))

(defun %call-plan-prune (arguments)
  (let ((result (taf.core:hub-prune
                 :targets (%mcp-optional-targets arguments)
                 :scope (%mcp-scope arguments)
                 :user-home (%json-string arguments "userHome")
                 :system-home (%json-string arguments "systemHome")
                 :kind (%mcp-kind arguments)
                 :dry-run-p t
                 :yes-p nil
                 :verbose nil)))
    (%tool-success
     (format nil "Planned prune for ~A TAFFISH app(s)."
             (getf (getf result :summary) :prunable))
     (append (list :ok t) result))))

(defun %call-which (arguments)
  (let ((result (taf.core:hub-which :query (%json-string arguments "target")
                                    :version-id (%json-string arguments "version")
                                    :scope (%mcp-scope arguments)
                                    :user-home (%json-string arguments "userHome")
                                    :system-home (%json-string arguments "systemHome")
                                    :verbose nil)))
    (%tool-success (format nil "Located TAFFISH target ~A."
                           (getf result :query))
                   result)))

(defun %call-history-list (arguments)
  (let ((result (taf.core:system-history :last (%json-int arguments "last" 20)
                                         :id (%json-string arguments "id")
                                         :path-p (%json-bool arguments "pathOnly" nil)
                                         :clear-p nil
                                         :user-home (%json-string arguments "userHome")
                                         :verbose nil)))
    (%tool-success (format nil "Read ~A TAFFISH history event(s)."
                           (or (getf result :count) 0))
                   result)))

(defun %call-install-app (arguments)
  (let* ((targets (%mcp-targets arguments))
         (version (%json-string arguments "version"))
         (dry-run (if (nth-value 1 (%json-get arguments "dryRun"))
                      (%json-bool arguments "dryRun" t)
                      t))
         (force (%json-bool arguments "force" nil))
         (install-dependencies
           (if (nth-value 1 (%json-get arguments "installDependencies"))
               (%json-bool arguments "installDependencies" t)
               t))
         (target-specs (%mcp-target-plists targets version)))
    (handler-case
        (let ((result (taf.core:hub-install-many
                       :targets target-specs
                       :scope (%mcp-scope arguments)
                       :user-home (%json-string arguments "userHome")
                       :system-home (%json-string arguments "systemHome")
                       :force-p force
                       :dry-run-p dry-run
                       :install-dependencies-p install-dependencies
                       :verbose nil)))
          (%tool-success (format nil "TAFFISH install ~A for ~A target(s)."
                                 (if dry-run "dry-run completed" "completed")
                                 (getf result :target-count))
                         (append (list :ok t) result)))
      (error (c)
        (%tool-success
         "TAFFISH install failed."
         (list :ok nil
               :dry-run-p dry-run
               :force-p force
               :targets target-specs
               :error (%mcp-error-object c "install-error")))))))

(defun %call-uninstall-app (arguments)
  (let* ((targets (%mcp-targets arguments))
         (version (%json-string arguments "version"))
         (dry-run (if (nth-value 1 (%json-get arguments "dryRun"))
                      (%json-bool arguments "dryRun" t)
                      t))
         (force (%json-bool arguments "force" nil))
         (target-specs (%mcp-target-plists targets version)))
    (handler-case
        (let ((result (taf.core:hub-uninstall-many
                       :targets target-specs
                       :scope (%mcp-scope arguments)
                       :user-home (%json-string arguments "userHome")
                       :system-home (%json-string arguments "systemHome")
                       :force-p force
                       :dry-run-p dry-run
                       :verbose nil)))
          (%tool-success (format nil "TAFFISH uninstall ~A for ~A target(s)."
                                 (if dry-run "dry-run completed" "completed")
                                 (getf result :target-count))
                         (append (list :ok t) result)))
      (error (c)
        (%tool-success
         "TAFFISH uninstall failed."
         (list :ok nil
               :dry-run-p dry-run
               :force-p force
               :targets target-specs
               :error (%mcp-error-object c "uninstall-error")))))))

(defun %project-new-argv (arguments)
  (let ((args nil))
    (let ((kind (%json-string arguments "kind")))
      (cond
        ((and kind (string-equal kind "tool")) (push "--tool" args))
        ((and kind (string-equal kind "flow")) (push "--flow" args))
        ((null kind) nil)
        (t (error "kind must be tool or flow, got: ~S" kind))))
    (labels ((add (flag value)
               (when value
                 (push flag args)
                 (push (princ-to-string value) args))))
      (add "--version" (%json-string arguments "version"))
      (add "--release" (%json-int arguments "release" nil))
      (add "--license" (%json-string arguments "license"))
      (add "--repo" (%json-string arguments "repo"))
      (add "--image" (%json-string arguments "image")))
    (when (%json-bool arguments "docker" nil)
      (push "--docker" args))
    (when (and (nth-value 1 (%json-get arguments "actions"))
               (not (%json-bool arguments "actions" t)))
      (push "--no-actions" args))
    (nreverse args)))

(defun %call-new-project (arguments)
  (let* ((name (%json-string arguments "name"))
         (project-dir (and name (han.path:join-path (han.os:current-directory) name))))
    (unless name
      (error "name is required."))
    (%quietly
      (taf.core:project-new name (%project-new-argv arguments)))
    (%tool-success (format nil "Created TAFFISH project: ~A" name)
                   (list :name name
                         :project-dir (han.path:->namestring project-dir)))))

(defun %call-check-project (arguments)
  (let ((result (taf.core:project-check
                 (or (%json-string arguments "startDir")
                     (han.os:current-directory))
                 nil)))
    (%tool-success (format nil "TAFFISH project check passed: ~A"
                           (getf result :name))
                   result)))

(defun %call-compile-project (arguments)
  (let* ((args (%json-string-array-or-single arguments "args"))
         (shell (apply #'taf.core:project-compile
                       (or args nil)
                       (or (%json-string arguments "startDir")
                           (han.os:current-directory))
                       (let ((backend (%json-string arguments "containerBackend")))
                         (if backend
                             (list :container-backend backend)
                             nil)))))
    (%tool-success "Compiled TAFFISH project to shell code."
                   (list :ok t
                         :shell shell
                         :bytes (length shell)))))

(defun %call-build-project (arguments)
  (let ((result (taf.core:project-build
                 :command-p t
                 :image-p nil
                 :start-dir (or (%json-string arguments "startDir")
                                (han.os:current-directory))
                 :verbose nil)))
    (%tool-success "Built TAFFISH project command wrapper."
                   result)))

(defun call-tool (name arguments)
  (let ((args (if (han.json:json-object-p arguments)
                  arguments
                  (han.json:make-json-object))))
    (handler-case
        (cond
          ((string= name "taffish_get_version") (%call-get-version args))
          ((string= name "taffish_get_help") (%call-get-help args))
          ((string= name "taffish_validate_source") (%call-taffish-validate-source args))
          ((string= name "taffish_compile_source") (%call-taffish-compile-source args))
          ((string= name "taffish_summarize_source") (%call-taffish-summarize-source args))
          ((string= name "taffish_validate_file") (%call-taffish-validate-file args))
          ((string= name "taffish_compile_file") (%call-taffish-compile-file args))
          ((string= name "taffish_summarize_file") (%call-taffish-summarize-file args))
          ((string= name "taffish_check_environment") (%call-doctor-check args))
          ((string= name "taffish_get_config") (%call-config-get args))
          ((string= name "taffish_get_config_paths") (%call-config-path args))
          ((string= name "taffish_update_index") (%call-update-index args))
          ((string= name "taffish_search_apps") (%call-search-apps args))
          ((string= name "taffish_get_app_info") (%call-get-app-info args))
          ((string= name "taffish_resolve_app") (%call-resolve-app args))
          ((string= name "taffish_inspect_app") (%call-inspect-app args))
          ((string= name "taffish_summarize_app_usage") (%call-summarize-app-usage args))
          ((string= name "taffish_compile_app_invocation") (%call-compile-app-invocation args))
          ((string= name "taffish_list_apps") (%call-list-apps args))
          ((string= name "taffish_check_outdated") (%call-check-outdated args))
          ((string= name "taffish_plan_install_all") (%call-plan-install-all args))
          ((string= name "taffish_plan_upgrade") (%call-plan-upgrade args))
          ((string= name "taffish_plan_prune") (%call-plan-prune args))
          ((string= name "taffish_locate_app") (%call-which args))
          ((string= name "taffish_list_history") (%call-history-list args))
          ((string= name "taffish_install_app") (%call-install-app args))
          ((string= name "taffish_uninstall_app") (%call-uninstall-app args))
          ((string= name "taffish_create_project") (%call-new-project args))
          ((string= name "taffish_check_project") (%call-check-project args))
          ((string= name "taffish_inspect_project") (%call-inspect-project args))
          ((string= name "taffish_summarize_project_usage") (%call-summarize-project-usage args))
          ((string= name "taffish_compile_project") (%call-compile-project args))
          ((string= name "taffish_build_project") (%call-build-project args))
          (t (%tool-error (format nil "Unknown TAFFISH MCP tool: ~A" name))))
      (error (c)
        (%business-error-result c)))))
