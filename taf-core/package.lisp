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
   :hub-install-all
   :hub-outdated
   :hub-upgrade
   :hub-prune
   :hub-uninstall
   :hub-uninstall-many
   :hub-list
   :hub-which
   :hub-which-many

	   ;; System
	   :system-config
	   :system-config-path
	   :system-config-init
	   :system-config-language
	   :system-doctor
	   :system-history
	   :system-record-history-event
	   :system-record-wrapper-history
   ))

;; Fault-injection and call-count tests replace these functions temporarily.
;; Calls within their defining file must also observe the current definition.
(declaim (notinline taf.core::%build-container-image
                    taf.core::%publish-run-program
                    taf.core::%publish-gh-program
                    taf.core::%publish-gh-query
                    taf.core::%hub-install-run-program
                    taf.core::%hub-read-index-source
                    taf.core::%hub-diagnostic-prime
                    taf.core::%hub-diagnostic-probe
                    taf.core::%hub-diagnostic-test
                    taf.core::%hub-diagnostic-contained-p
                    taf.core::%hub-diagnostic-file-issues
                    taf.core::%hub-diagnostic-snapshot-fields
                    taf.core::%hub-repair-path-issue))
