(defpackage :taf.core
  (:use :cl)
  (:export
   ;; Defaults
   :*default-github-host*
   :*default-github-owner*
   :*default-container-registry*
   :*default-docker-base-image*
   :*default-index-repository*
   :*default-index-branch*

   ;; Project
   :project-new
   :project-check
   :project-compile
   :project-build
   :project-run
   :project-publish

   ;; Hub
   :hub-update
   :hub-search
   :hub-info
   :hub-info-many
   :hub-install
   :hub-install-from-project
   :hub-install-many
   :hub-uninstall
   :hub-uninstall-many
   :hub-list
   :hub-which
   :hub-which-many

	   ;; System
	   :system-config
	   :system-config-path
	   :system-config-init
	   :system-doctor
	   :system-history
	   :system-record-history-event
   ))
