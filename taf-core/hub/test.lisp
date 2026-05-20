(in-package :han.test)

;;;; ============================================================
;;;; taf.core hub tests
;;;; ============================================================

(defun %taf-hub-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %taf-hub-string-contains-p (string substring)
  (and (stringp string)
       (stringp substring)
       (not (null (search substring string :test #'char=)))))

(defun %taf-hub-temp-dir ()
  (let ((name (format nil "taf-hub-test-~A/" (gensym "DIR"))))
    (merge-pathnames name (uiop:temporary-directory))))

(defmacro with-taf-hub-temp-dir ((dir) &body body)
  `(let ((,dir (%taf-hub-temp-dir)))
     (declare (ignorable ,dir))
     (ensure-directories-exist ,dir)
     (unwind-protect
          (progn ,@body)
       (uiop:delete-directory-tree ,dir :validate t :if-does-not-exist :ignore))))

(defun %taf-hub-write-string (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
    (write-string string out)))

(defun %taf-hub-sample-index ()
  "{\"schema_version\":\"taffish.index/v1\",\"packages\":{},\"commands\":{}}")

(defun %taf-hub-sample-info-index ()
  "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"my-new-test\": {
      \"name\": \"my-new-test\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/my-new-test\",
      \"command\": {\"name\": \"taf-my-new-test\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"my-new-test\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/my-new-test\",
          \"repository_slug\": \"taffish/my-new-test\",
          \"command\": {\"name\": \"taf-my-new-test\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {
            \"main\": \"src/main.taf\",
            \"help\": \"docs/help.md\",
            \"dockerfile\": \"docker/Dockerfile\"
          },
          \"container\": {
            \"image\": \"ghcr.io/taffish/my-new-test:0.1.0-r1\",
            \"dockerfile\": \"docker/Dockerfile\",
            \"image_tag\": \"0.1.0-r1\",
            \"image_tag_matches_version\": true,
            \"digest\": \"sha256:1111111111111111111111111111111111111111111111111111111111111111\",
            \"platforms\": [\"linux/amd64\", \"linux/arm64\"]
          },
          \"smoke\": {
            \"backend\": \"docker\",
            \"timeout\": 60,
            \"exist\": [\"sh\"],
            \"test\": [\"sh --help\"]
          },
          \"source\": {
            \"repository\": \"taffish/my-new-test\",
            \"ref\": \"v0.1.0-r1\",
            \"commit\": \"59ed17d088accc24789672997dc7ba4f36678cdf\",
            \"html_url\": \"https://github.com/taffish/my-new-test/tree/v0.1.0-r1\"
          }
        },
        \"0.0.9-r1\": {
          \"name\": \"my-new-test\",
          \"kind\": \"tool\",
          \"version\": \"0.0.9\",
          \"release\": 1,
          \"version_id\": \"0.0.9-r1\",
          \"tag\": \"v0.0.9-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/my-new-test\",
          \"repository_slug\": \"taffish/my-new-test\",
          \"command\": {\"name\": \"taf-my-new-test\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {
            \"main\": \"src/main.taf\",
            \"help\": \"docs/help.md\"
          },
          \"container\": {
            \"image\": \"ghcr.io/taffish/my-new-test:0.0.9-r1\",
            \"image_tag\": \"0.0.9-r1\"
          },
          \"source\": {
            \"repository\": \"taffish/my-new-test\",
            \"ref\": \"v0.0.9-r1\",
            \"commit\": \"0000000000000000000000000000000000000000\",
            \"html_url\": \"https://github.com/taffish/my-new-test/tree/v0.0.9-r1\"
          }
        }
      }
    }
  },
  \"commands\": {
    \"taf-my-new-test\": {
      \"package\": \"my-new-test\",
      \"version\": \"0.1.0-r1\"
    }
  }
}")

(defun %taf-hub-sample-search-index ()
  "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"bwa-mem\": {
      \"name\": \"bwa-mem\",
      \"latest\": \"0.7.17-r2\",
      \"repository_url\": \"https://github.com/taffish/bwa-mem\",
      \"command\": {\"name\": \"taf-bwa-mem\"},
      \"versions\": {
        \"0.7.17-r2\": {
          \"name\": \"bwa-mem\",
          \"kind\": \"tool\",
          \"version\": \"0.7.17\",
          \"release\": 2,
          \"version_id\": \"0.7.17-r2\",
          \"tag\": \"v0.7.17-r2\",
          \"license\": \"MIT\",
          \"repository_url\": \"https://github.com/taffish/bwa-mem\",
          \"repository_slug\": \"taffish/bwa-mem\",
          \"command\": {\"name\": \"taf-bwa-mem\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": {
            \"image\": \"ghcr.io/taffish/bwa-mem:0.7.17-r2\",
            \"image_tag\": \"0.7.17-r2\"
          },
          \"source\": {\"repository\": \"taffish/bwa-mem\"}
        }
      }
    },
    \"hic-loop-flow\": {
      \"name\": \"hic-loop-flow\",
      \"latest\": \"1.0.0-r1\",
      \"repository_url\": \"https://github.com/taffish/hic-loop-flow\",
      \"command\": {\"name\": \"taf-hic-loop-flow\"},
      \"versions\": {
        \"1.0.0-r1\": {
          \"name\": \"hic-loop-flow\",
          \"kind\": \"flow\",
          \"version\": \"1.0.0\",
          \"release\": 1,
          \"version_id\": \"1.0.0-r1\",
          \"tag\": \"v1.0.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/hic-loop-flow\",
          \"repository_slug\": \"taffish/hic-loop-flow\",
          \"command\": {\"name\": \"taf-hic-loop-flow\"},
          \"runtime\": {\"pipe\": false, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {\"repository\": \"taffish/hic-loop-flow\"}
        }
      }
    }
  },
  \"commands\": {
    \"taf-bwa-mem\": {\"package\": \"bwa-mem\", \"version\": \"0.7.17-r2\"},
    \"taf-hic-loop-flow\": {\"package\": \"hic-loop-flow\", \"version\": \"1.0.0-r1\"}
  }
}")

(defun %taf-hub-sample-install-index (local-source &optional source-commit)
  (format nil "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"install-demo\": {
      \"name\": \"install-demo\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/install-demo\",
      \"command\": {\"name\": \"taf-install-demo\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"install-demo\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/install-demo\",
          \"repository_slug\": \"taffish/install-demo\",
          \"command\": {\"name\": \"taf-install-demo\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {
            \"repository\": \"taffish/install-demo\",
            \"ref\": \"v0.1.0-r1\",
            \"local_path\": \"~A\"~A
          }
        }
      }
    }
  },
  \"commands\": {
    \"taf-install-demo\": {
      \"package\": \"install-demo\",
      \"version\": \"0.1.0-r1\"
    }
  }
}" (han.path:->namestring local-source)
   (if (and (stringp source-commit)
            (> (length source-commit) 0))
       (format nil ",~%            \"commit\": \"~A\"" source-commit)
       "")))

(defun %taf-hub-run-git (source-root args)
  (let ((git (han.os:find-executable "git")))
    (when git
      (multiple-value-bind (out err code)
          (han.os:run-program
           (append (list git
                         "-C"
                         (han.path:->namestring
                          (han.path:directory-pathname source-root)))
                   args)
           :output :string
           :error-output :string
           :ignore-error-status t)
        (unless (and (integerp code) (= code 0))
          (error "git ~{~A~^ ~} failed:~%~A~A" args out err))
        (string-trim '(#\Space #\Tab #\Newline #\Return) out)))))

(defun %taf-hub-init-git-source (source-root)
  (when (han.os:find-executable "git")
    (%taf-hub-run-git source-root '("init"))
    (%taf-hub-run-git source-root
                      '("config" "user.email" "taffish-test@example.org"))
    (%taf-hub-run-git source-root
                      '("config" "user.name" "TAFFISH Test"))
    (%taf-hub-run-git source-root '("add" "-A"))
    (%taf-hub-run-git source-root '("commit" "-m" "initial"))
    (%taf-hub-run-git source-root '("rev-parse" "HEAD"))))

(defun %taf-hub-sample-install-clone-index ()
  "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"install-demo\": {
      \"name\": \"install-demo\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/install-demo\",
      \"command\": {\"name\": \"taf-install-demo\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"install-demo\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/install-demo\",
          \"repository_slug\": \"taffish/install-demo\",
          \"command\": {\"name\": \"taf-install-demo\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {
            \"repository\": \"taffish/install-demo\",
            \"ref\": \"v0.1.0-r1\",
            \"clone_url\": \"https://github.com/taffish/install-demo\"
          }
        }
      }
    }
  },
  \"commands\": {
    \"taf-install-demo\": {
      \"package\": \"install-demo\",
      \"version\": \"0.1.0-r1\"
    }
  }
}")

(defun %taf-hub-sample-install-multi-version-index (source-r1 source-r2)
  (format nil "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"multi-demo\": {
      \"name\": \"multi-demo\",
      \"latest\": \"0.1.0-r2\",
      \"repository_url\": \"https://github.com/taffish/multi-demo\",
      \"command\": {\"name\": \"taf-multi-demo\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"multi-demo\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/multi-demo\",
          \"repository_slug\": \"taffish/multi-demo\",
          \"command\": {\"name\": \"taf-multi-demo\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {\"repository\": \"taffish/multi-demo\", \"ref\": \"v0.1.0-r1\", \"local_path\": \"~A\"}
        },
        \"0.1.0-r2\": {
          \"name\": \"multi-demo\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 2,
          \"version_id\": \"0.1.0-r2\",
          \"tag\": \"v0.1.0-r2\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/multi-demo\",
          \"repository_slug\": \"taffish/multi-demo\",
          \"command\": {\"name\": \"taf-multi-demo\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {\"repository\": \"taffish/multi-demo\", \"ref\": \"v0.1.0-r2\", \"local_path\": \"~A\"}
        }
      }
    }
  },
  \"commands\": {
    \"taf-multi-demo\": {\"package\": \"multi-demo\", \"version\": \"0.1.0-r2\"}
  }
}" (han.path:->namestring source-r1)
   (han.path:->namestring source-r2)))

(defun %taf-hub-sample-install-dependency-index (flow-source dep-source)
  (format nil "{
  \"schema_version\": \"taffish.index/v1\",
  \"generated_at\": \"2026-05-06T15:45:57Z\",
  \"packages\": {
    \"dep-tool\": {
      \"name\": \"dep-tool\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/dep-tool\",
      \"command\": {\"name\": \"taf-dep-tool\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"dep-tool\",
          \"kind\": \"tool\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/dep-tool\",
          \"repository_slug\": \"taffish/dep-tool\",
          \"command\": {\"name\": \"taf-dep-tool\"},
          \"runtime\": {\"pipe\": true, \"command_mode\": true},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"container\": null,
          \"source\": {
            \"repository\": \"taffish/dep-tool\",
            \"ref\": \"v0.1.0-r1\",
            \"local_path\": \"~A\"
          }
        }
      }
    },
    \"flow-with-dep\": {
      \"name\": \"flow-with-dep\",
      \"latest\": \"0.1.0-r1\",
      \"repository_url\": \"https://github.com/taffish/flow-with-dep\",
      \"command\": {\"name\": \"taf-flow-with-dep\"},
      \"versions\": {
        \"0.1.0-r1\": {
          \"name\": \"flow-with-dep\",
          \"kind\": \"flow\",
          \"version\": \"0.1.0\",
          \"release\": 1,
          \"version_id\": \"0.1.0-r1\",
          \"tag\": \"v0.1.0-r1\",
          \"license\": \"Apache-2.0\",
          \"repository_url\": \"https://github.com/taffish/flow-with-dep\",
          \"repository_slug\": \"taffish/flow-with-dep\",
          \"command\": {\"name\": \"taf-flow-with-dep\"},
          \"runtime\": {\"pipe\": false, \"command_mode\": false},
          \"paths\": {\"main\": \"src/main.taf\", \"help\": \"docs/help.md\"},
          \"dependencies\": {\"taf-dep-tool\": \"0.1.0-r1\"},
          \"container\": null,
          \"source\": {
            \"repository\": \"taffish/flow-with-dep\",
            \"ref\": \"v0.1.0-r1\",
            \"local_path\": \"~A\"
          }
        }
      }
    }
  },
  \"commands\": {
    \"taf-dep-tool\": {\"package\": \"dep-tool\", \"version\": \"0.1.0-r1\"},
    \"taf-flow-with-dep\": {\"package\": \"flow-with-dep\", \"version\": \"0.1.0-r1\"}
  }
}" (han.path:->namestring dep-source)
   (han.path:->namestring flow-source)))

(defun %taf-hub-write-current-index (home string)
  (let ((file (han.path:join-path home "index" "current.json")))
    (%taf-hub-write-string file string)
    file))

(deftest test-taf-hub-update-local-file-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((source (han.path:join-path root "source-index.json"))
           (user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-string source (%taf-hub-sample-index))
      (let ((result (taf.core:hub-update
                     :index-url (han.path:->namestring source)
                     :scope :user
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :source) (han.path:->namestring source))
        (check-true (uiop:file-exists-p (getf result :current-file)))
        (check-true (uiop:file-exists-p (getf result :snapshot-file)))
        (check-equal (han.os:load-string (getf result :current-file))
                     (%taf-hub-sample-index))
        (check-equal (not (null (search "/index/current.json"
                                       (getf result :current-file)
                                       :test #'char=)))
                     t)
        (check-equal (not (null (search "/index/snapshots/index-"
                                       (getf result :snapshot-file)
                                       :test #'char=)))
                     t)))))

(deftest test-taf-hub-update-file-url-system-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((source (han.path:join-path root "source-index.json"))
           (user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-string source (%taf-hub-sample-index))
      (let ((result (taf.core:hub-update
                     :index-url (format nil "file://~A" (han.path:->namestring source))
                     :scope :system
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :scope) :system)
        (check-equal (not (null (search (han.path:->namestring system-home)
                                       (getf result :current-file)
                                       :test #'char=)))
                     t)
        (check-true (uiop:file-exists-p (getf result :current-file)))))))

(deftest test-taf-hub-update-invalid-index-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((source (han.path:join-path root "bad-index.json"))
           (user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-string source "{}")
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-update
           :index-url (han.path:->namestring source)
           :user-home user-home
           :system-home system-home
          :verbose nil)))
	       t))))

(deftest test-taf-hub-update-uses-config-index-url ()
  (with-taf-hub-temp-dir (root)
    (let* ((source (han.path:join-path root "source-index.json"))
           (user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (config-file (han.path:join-path user-home "config.toml")))
      (%taf-hub-write-string source (%taf-hub-sample-index))
      (%taf-hub-write-string
       config-file
       (format nil "schema_version = \"taffish.config/v1\"

[index]
url = \"~A\"
" (han.path:->namestring source)))
      (let ((result (taf.core:hub-update
                     :scope :user
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :source) (han.path:->namestring source))
        (check-true (uiop:file-exists-p (getf result :current-file)))))))

(deftest test-taf-hub-info-package-latest ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (let* ((result (taf.core:hub-info
                      :query "my-new-test"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (record (getf result :record))
             (command (han.json:get-json record "command"))
             (container (han.json:get-json record "container")))
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :query-kind) :package)
        (check-equal (getf result :package-name) "my-new-test")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (han.json:get-json record "kind") "tool")
        (check-equal (han.json:get-json command "name") "taf-my-new-test")
        (check-equal (han.json:get-json container "image")
                     "ghcr.io/taffish/my-new-test:0.1.0-r1")))))

(deftest test-taf-hub-info-print-latest-and-versions ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (let ((out
              (with-output-to-string (*standard-output*)
                (taf.core:hub-info
                 :query "my-new-test"
                 :user-home user-home
                 :system-home system-home))))
        (check-equal (%taf-hub-string-contains-p out "latest") t)
        (check-equal (%taf-hub-string-contains-p out "versions") t)
        (check-equal (%taf-hub-string-contains-p out "0.1.0-r1 [latest]") t)
        (check-equal (%taf-hub-string-contains-p out "0.0.9-r1") t)
        (check-equal (%taf-hub-string-contains-p out "sha256:111111") t)
        (check-equal (%taf-hub-string-contains-p out "linux/amd64, linux/arm64") t)
        (check-equal (%taf-hub-string-contains-p out "smoke") t)
        (check-equal (%taf-hub-string-contains-p out "sh --help") t)))))

(deftest test-taf-hub-info-command-resolves-package ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (let* ((result (taf.core:hub-info
                      :query "taf-my-new-test"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (record (getf result :record)))
        (check-equal (getf result :query-kind) :command)
        (check-equal (getf result :package-name) "my-new-test")
        (check-equal (han.json:get-json record "version_id") "0.1.0-r1")))))

(deftest test-taf-hub-info-artifact-command-resolves-version ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (let* ((result (taf.core:hub-info
                      :query "taf-my-new-test-v0.1.0-r1"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (record (getf result :record)))
        (check-equal (getf result :query-kind) :artifact)
        (check-equal (getf result :package-name) "my-new-test")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (han.json:get-json record "version_id") "0.1.0-r1")))))

(deftest test-taf-hub-info-explicit-version-allows-leading-v ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index system-home (%taf-hub-sample-info-index))
      (let ((result (taf.core:hub-info
                     :query "my-new-test"
                     :version-id "v0.1.0-r1"
                     :scope :system
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :scope) :system)
        (check-equal (getf result :version-id) "0.1.0-r1")))))

(deftest test-taf-hub-info-many-targets-json-array ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (let* ((summary
               (taf.core:hub-info-many
                :targets '("my-new-test" "taf-my-new-test-v0.0.9-r1")
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (results (getf summary :results))
             (out
               (with-output-to-string (*standard-output*)
                 (taf.core:hub-info-many
                  :targets '("my-new-test" "taf-my-new-test-v0.0.9-r1")
                  :json-p t
                  :user-home user-home
                  :system-home system-home))))
        (check-equal (getf summary :target-count) 2)
        (check-equal (length results) 2)
        (check-equal (getf (first results) :version-id) "0.1.0-r1")
        (check-equal (getf (second results) :version-id) "0.0.9-r1")
        (check-equal (%taf-hub-string-contains-p out "[") t)
        (check-equal (%taf-hub-string-contains-p out "0.1.0-r1") t)
        (check-equal (%taf-hub-string-contains-p out "0.0.9-r1") t)))))

(deftest test-taf-hub-info-missing-index-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-info
           :query "my-new-test"
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))

(deftest test-taf-hub-info-unknown-target-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-info
           :query "missing-app"
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))

(deftest test-taf-hub-search-package-name ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let* ((result (taf.core:hub-search
                      :query "bwa"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (matches (getf result :matches))
             (first-match (first matches)))
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :total) 1)
        (check-equal (getf first-match :name) "bwa-mem")
        (check-equal (getf first-match :command) "taf-bwa-mem")
        (check-equal (getf first-match :version-id) "0.7.17-r2")))))

(deftest test-taf-hub-search-command-and_kind_terms ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let* ((result (taf.core:hub-search
                      :query "taf-hic flow"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (matches (getf result :matches)))
        (check-equal (getf result :total) 1)
        (check-equal (getf (first matches) :name) "hic-loop-flow")
        (check-equal (getf (first matches) :kind) "flow")))))

(deftest test-taf-hub-search-limit ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let ((result (taf.core:hub-search
                     :query "taffish"
                     :limit 1
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :total) 2)
        (check-equal (length (getf result :matches)) 1)))))

(deftest test-taf-hub-search-missing-index-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-search
           :query "bwa"
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))

(deftest test-taf-hub-install-local-source-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let* ((result (taf.core:hub-install
                      :query "install-demo"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (launcher (getf result :launcher-file))
             (alias (getf result :command-launcher-file))
             (metadata (getf result :metadata-file)))
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :package-name) "install-demo")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (getf result :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-true (uiop:file-exists-p launcher))
        (check-true (uiop:file-exists-p alias))
        (check-true (uiop:file-exists-p metadata))
        (multiple-value-bind (out err code)
            (uiop:run-program (list launcher "--version")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-hub-string-contains-p
                        out
                        "taf-install-demo-v0.1.0-r1")
                       t))
        (multiple-value-bind (out err code)
            (uiop:run-program (list alias "--version")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-hub-string-contains-p
                        out
                        "taf-install-demo -> taf-install-demo-v0.1.0-r1")
                       t))
        (multiple-value-bind (out err code)
            (uiop:run-program (list launcher "-h")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
	        (check-equal
	         (not (null (search "taf-install-demo" out :test #'char=)))
	         t))))))

(deftest test-taf-hub-install-verifies-source-commit ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil)
           (commit nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")
              commit (%taf-hub-init-git-source source-root)))
      ;; Git may be unavailable in a minimal test environment.  The feature is
      ;; still exercised whenever a normal developer/runtime PATH contains git.
      (if commit
          (progn
            (%taf-hub-write-current-index
             user-home
             (%taf-hub-sample-install-index source-root commit))
            (let* ((result (taf.core:hub-install
                            :query "install-demo"
                            :user-home user-home
                            :system-home system-home
                            :verbose nil))
                   (metadata
                     (han.json:read-json-file (getf result :metadata-file))))
              (check-equal (getf result :source-commit) commit)
              (check-equal (getf result :actual-source-commit) commit)
              (check-equal (getf result :source-commit-verified-p) t)
              (check-equal (han.json:get-json metadata "source_commit")
                           commit)
              (check-equal (han.json:get-json metadata
                                              "source_commit_actual")
                           commit)
              (check-equal (han.json:get-json metadata
                                              "source_commit_verified")
                           t)))
          (check-true t)))))

(deftest test-taf-hub-install-rejects-source-commit-mismatch ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil)
           (commit nil)
           (wrong-commit
             "0000000000000000000000000000000000000000"))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")
              commit (%taf-hub-init-git-source source-root)))
      (if commit
          (progn
            (%taf-hub-write-current-index
             user-home
             (%taf-hub-sample-install-index source-root wrong-commit))
            (check-equal
             (%taf-hub-signal-error-p
              (lambda ()
                (taf.core:hub-install
                 :query "install-demo"
                 :user-home user-home
                 :system-home system-home
                 :verbose nil)))
             t))
          (check-true t)))))

(deftest test-taf-hub-install-rejects-dirty-source-with-commit ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil)
           (commit nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")
              commit (%taf-hub-init-git-source source-root))
        (%taf-hub-write-string
         (han.path:join-path source-root "src" "dirty.txt")
         "dirty"))
      (if commit
          (progn
            (%taf-hub-write-current-index
             user-home
             (%taf-hub-sample-install-index source-root commit))
            (check-equal
             (%taf-hub-signal-error-p
              (lambda ()
                (taf.core:hub-install
                 :query "install-demo"
                 :user-home user-home
                 :system-home system-home
                 :verbose nil)))
             t))
          (check-true t)))))

(deftest test-taf-hub-install-from-project-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "local-install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "local-install-demo")))
      (let* ((result (taf.core:hub-install-from-project
                      :start-dir source-root
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (metadata (han.json:read-json-file (getf result :metadata-file)))
             (origin (han.path:->namestring
                      (han.path:directory-pathname source-root)))
             (launcher (getf result :launcher-file))
             (alias (getf result :command-launcher-file)))
        (check-equal (getf result :package-name) "local-install-demo")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (getf result :origin-kind) :local-project)
        (check-equal (getf result :origin) origin)
        (check-equal (han.json:get-json metadata "origin_kind")
                     "local-project")
        (check-equal (han.json:get-json metadata "origin") origin)
        (check-equal
         (%taf-hub-string-contains-p
          (han.json:get-json metadata "origin_display")
          "[local-project]")
         t)
        (check-true (uiop:file-exists-p launcher))
        (check-true (uiop:file-exists-p alias))
        (check-equal
         (uiop:file-exists-p
          (han.path:join-path user-home "index" "current.json"))
         nil)))))

(deftest test-taf-hub-install-from-project-preserves-smoke ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "local-smoke-demo" '("--tool" "--docker"))
        (let* ((toml-path (han.path:join-path root "local-smoke-demo"
                                              "taffish.toml"))
               (toml (han.os:load-string toml-path)))
          (labels ((replace-one (string old new)
                     (let ((pos (search old string :test #'char=)))
                       (unless pos
                         (error "Substring not found: ~S" old))
                       (concatenate 'string
                                    (subseq string 0 pos)
                                    new
                                    (subseq string (+ pos (length old)))))))
            (with-open-file (out toml-path
                                 :direction :output
                                 :if-exists :supersede
                                 :if-does-not-exist :create)
              (format out "~A"
                      (replace-one
                       (replace-one toml
                                    "exist = [\"TODO\"]"
                                    "exist = [\"sh\"]")
                       "test = [\"TODO --help\"]"
                       "test = [\"sh -c true\"]")))))
        (setf source-root (han.path:join-path root "local-smoke-demo")))
      (let* ((result (taf.core:hub-install-from-project
                      :start-dir source-root
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (metadata (han.json:read-json-file (getf result :metadata-file)))
             (record (getf result :record))
             (smoke (han.json:get-json record "smoke")))
        (declare (ignore metadata))
        (check-equal (han.json:get-json smoke "backend") "docker")
        (check-equal (han.json:get-json smoke "timeout") 60)
        (check-equal (length (han.json:get-json smoke "exist")) 1)
        (check-equal (length (han.json:get-json smoke "test")) 1)))))

(deftest test-taf-hub-install-from-project-searches-upward ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "local-upward-demo" '("--tool"))
        (setf source-root (han.path:join-path root "local-upward-demo")))
      (uiop:with-current-directory ((han.path:join-path source-root "target"))
        (let* ((result (taf.core:hub-install-from-project
                        :start-dir "."
                        :user-home user-home
                        :system-home system-home
                        :verbose nil))
               (origin (getf result :origin)))
          (check-equal (getf result :package-name) "local-upward-demo")
          (check-equal (getf result :version-id) "0.1.0-r1")
          (check-equal (getf result :origin-kind) :local-project)
          (check-equal
           (%taf-hub-string-contains-p origin "/local-upward-demo/")
           t)
          (check-true (uiop:file-exists-p (getf result :launcher-file)))
          (check-true (uiop:file-exists-p
                       (getf result :command-launcher-file))))))))

(deftest test-taf-hub-install-from-project-dry-run-has-no-side-effect ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "local-dry-run-demo" '("--tool"))
        (setf source-root (han.path:join-path root "local-dry-run-demo")))
      (let ((result (taf.core:hub-install-from-project
                     :start-dir source-root
                     :user-home user-home
                     :system-home system-home
                     :dry-run-p t
                     :verbose nil)))
        (check-equal (getf result :dry-run-p) t)
        (check-equal (getf result :installed-p) nil)
        (check-equal
         (uiop:directory-exists-p
          (han.path:directory-pathname (getf result :install-root)))
         nil)
        (check-equal (uiop:file-exists-p (getf result :launcher-file))
                     nil)))))

(deftest test-taf-hub-install-rewrites-source-url ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (config-file (han.path:join-path user-home "config.toml"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-clone-index))
      (%taf-hub-write-string
       config-file
       (format nil "schema_version = \"taffish.config/v1\"

[[source.rewrite]]
from = \"https://github.com/taffish/install-demo\"
to = \"~A\"
enabled = true
" (han.path:->namestring source-root)))
      (let* ((result (taf.core:hub-install
                      :query "install-demo"
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (metadata (han.json:read-json-file (getf result :metadata-file))))
        (check-equal (getf result :source-url)
                     "https://github.com/taffish/install-demo")
        (check-equal (getf result :resolved-source-url)
                     (han.path:->namestring source-root))
        (check-equal (han.json:get-json metadata "source_url")
                     "https://github.com/taffish/install-demo")
        (check-equal (han.json:get-json metadata "resolved_source_url")
                     (han.path:->namestring source-root))
        (check-equal (getf result :installed-p) t)))))

(deftest test-taf-hub-install-command-query-explicit-version ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let ((result (taf.core:hub-install
                     :query "taf-install-demo"
                     :version-id "v0.1.0-r1"
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :query-kind) :command)
        (check-equal (getf result :package-name) "install-demo")
        (check-equal (getf result :installed-p) t)))))

(deftest test-taf-hub-install-artifact-command-query ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let ((result (taf.core:hub-install
                     :query "taf-install-demo-v0.1.0-r1"
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :query-kind) :artifact)
        (check-equal (getf result :package-name) "install-demo")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (getf result :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-equal (getf result :installed-p) t)))))

(deftest test-taf-hub-install-many-installs-targets-in-order ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (let* ((summary
               (taf.core:hub-install-many
                :targets '("taf-multi-demo-v0.1.0-r1"
                           "taf-multi-demo-v0.1.0-r2")
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (results (getf summary :results))
             (alias (getf (second results) :command-launcher-file)))
        (check-equal (getf summary :target-count) 2)
        (check-equal (length results) 2)
        (check-equal (getf (first results) :version-id) "0.1.0-r1")
        (check-equal (getf (second results) :version-id) "0.1.0-r2")
        (check-equal (getf (second results) :alias-version-id) "0.1.0-r2")
        (multiple-value-bind (out err code)
            (uiop:run-program (list alias "--version")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-hub-string-contains-p
                        out
                        "taf-multi-demo -> taf-multi-demo-v0.1.0-r2")
                       t))))))

(deftest test-taf-hub-install-dry-run-has-no-side-effect ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let* ((result (taf.core:hub-install
                      :query "install-demo"
                      :dry-run-p t
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (install-root (getf result :install-root))
             (launcher (getf result :launcher-file)))
        (check-equal (getf result :dry-run-p) t)
        (check-equal (getf result :installed-p) nil)
        (check-equal (uiop:directory-exists-p
                      (han.path:directory-pathname install-root))
                     nil)
        (check-equal (uiop:file-exists-p launcher) nil)))))

(deftest test-taf-hub-install-force-dry-run-keeps-existing-install ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let* ((installed (taf.core:hub-install
                         :query "install-demo"
                         :user-home user-home
                         :system-home system-home
                         :verbose nil))
             (launcher (getf installed :launcher-file))
             (install-root (getf installed :install-root))
             (dry-run (taf.core:hub-install
                       :query "install-demo"
                       :dry-run-p t
                       :force-p t
                       :user-home user-home
                       :system-home system-home
                       :verbose nil)))
        (check-equal (getf dry-run :dry-run-p) t)
        (check-true (uiop:file-exists-p launcher))
        (check-true (uiop:directory-exists-p
                     (han.path:directory-pathname install-root)))))))

(deftest test-taf-hub-install-existing-version-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-install
           :query "install-demo"
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))

(deftest test-taf-hub-install-alias-tracks-local-latest ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (let* ((installed-r2
               (taf.core:hub-install
                :query "multi-demo"
                :version-id "0.1.0-r2"
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (installed-r1
               (taf.core:hub-install
                :query "multi-demo"
                :version-id "0.1.0-r1"
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (alias (getf installed-r1 :command-launcher-file)))
        (check-equal (getf installed-r2 :alias-version-id) "0.1.0-r2")
        (check-equal (getf installed-r1 :alias-version-id) "0.1.0-r2")
        (multiple-value-bind (out err code)
            (uiop:run-program (list alias "--version")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-hub-string-contains-p
                        out
                        "taf-multi-demo -> taf-multi-demo-v0.1.0-r2")
                       t))
        (taf.core:hub-uninstall
         :query "multi-demo"
         :version-id "0.1.0-r2"
         :user-home user-home
         :system-home system-home
         :verbose nil)
        (multiple-value-bind (out err code)
            (uiop:run-program (list alias "--version")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal (%taf-hub-string-contains-p
                        out
                        "taf-multi-demo -> taf-multi-demo-v0.1.0-r1")
                       t))
        (taf.core:hub-uninstall
         :query "multi-demo"
         :version-id "0.1.0-r1"
         :user-home user-home
         :system-home system-home
         :verbose nil)
        (check-equal (uiop:file-exists-p alias) nil)))))

(deftest test-taf-hub-install-system-scope-uses-system-bin-dir ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (system-bin (han.path:join-path root "system-bin"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       system-home
       (%taf-hub-sample-install-index source-root))
      (let* ((installed
               (taf.core:hub-install
                :query "install-demo"
                :scope :system
                :user-home user-home
                :system-home system-home
                :system-bin-dir system-bin
                :verbose nil))
             (launcher (getf installed :launcher-file)))
        (check-equal (getf installed :scope) :system)
        (check-equal (getf installed :bin-dir)
                     (han.path:->namestring
                      (han.path:directory-pathname system-bin)))
        (check-equal
         (not (null (search "/system-bin/" launcher :test #'char=)))
         t)
        (check-true (uiop:file-exists-p launcher))
        (multiple-value-bind (out err code)
            (uiop:run-program (list launcher "-h")
                              :output :string
                              :error-output :string
                              :ignore-error-status t)
          (declare (ignore err))
          (check-equal code 0)
          (check-equal
           (not (null (search "taf-install-demo" out :test #'char=)))
           t))
        (taf.core:hub-uninstall
         :query "install-demo"
         :scope :system
         :user-home user-home
         :system-home system-home
         :verbose nil)
        (check-equal (uiop:file-exists-p launcher) nil)))))

(deftest test-taf-hub-install-installs-index-dependencies ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (dep-source nil)
           (flow-source nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "dep-tool" '("--tool"))
        (setf dep-source (han.path:join-path root "dep-tool"))
        (taf.core:project-new "flow-with-dep" nil)
        (setf flow-source (han.path:join-path root "flow-with-dep"))
        (%taf-hub-write-string
         (han.path:join-path flow-source "src" "main.taf")
         "<taffish>
echo before
[[taf: taf-dep-tool --help]]
echo after"))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-dependency-index flow-source dep-source))
      (let* ((installed
               (taf.core:hub-install
                :query "flow-with-dep"
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (dependencies (getf installed :dependency-results))
             (bin-dir (han.path:join-path user-home "bin"))
             (dep-artifact (han.path:join-path bin-dir
                                                "taf-dep-tool-v0.1.0-r1"))
             (dep-alias (han.path:join-path bin-dir "taf-dep-tool"))
             (flow-artifact (han.path:join-path bin-dir
                                                 "taf-flow-with-dep-v0.1.0-r1"))
             (flow-alias (han.path:join-path bin-dir "taf-flow-with-dep")))
        (check-equal (getf installed :package-name) "flow-with-dep")
        (check-equal (length dependencies) 1)
        (check-equal (getf (first dependencies) :package-name) "dep-tool")
        (check-true (uiop:file-exists-p dep-artifact))
        (check-true (uiop:file-exists-p dep-alias))
        (check-true (uiop:file-exists-p flow-artifact))
        (check-true (uiop:file-exists-p flow-alias))))))

(deftest test-taf-hub-install-record-dependencies-array ()
  (let* ((record
           (han.json:json-object
            (cons "dependencies"
                  (han.json:json-object
                   (cons "taf-dep-tool"
                         (han.json:json-array "0.1.0-r1" "0.2.0-r1"))))))
         (dependencies
           (taf.core::%hub-install-record-dependencies record)))
    (check-equal (length dependencies) 2)
    (check-equal (getf (first dependencies) :query) "taf-dep-tool")
    (check-equal (getf (first dependencies) :version-id) "0.1.0-r1")
    (check-equal (getf (second dependencies) :query) "taf-dep-tool")
    (check-equal (getf (second dependencies) :version-id) "0.2.0-r1")))

(deftest test-taf-hub-outdated-detects-local-older-version ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (taf.core:hub-install
       :query "multi-demo"
       :version-id "0.1.0-r1"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((result (taf.core:hub-outdated
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (items (getf result :items))
             (item (first items)))
        (check-equal (length items) 1)
        (check-equal (getf item :package-name) "multi-demo")
        (check-equal (getf item :installed-version-id) "0.1.0-r1")
        (check-equal (getf item :latest-version-id) "0.1.0-r2")
        (check-equal (getf item :status) :outdated)
        (check-equal (getf item :action) :install-latest)))))

(deftest test-taf-hub-upgrade-installs-index-latest ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (taf.core:hub-install
       :query "multi-demo"
       :version-id "0.1.0-r1"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((dry-run (taf.core:hub-upgrade
                       :user-home user-home
                       :system-home system-home
                       :verbose nil))
             (applied (taf.core:hub-upgrade
                       :user-home user-home
                       :system-home system-home
                       :yes-p t
                       :prune-old-p t
                       :verbose nil))
             (prune-result (getf applied :prune-result))
             (installed (taf.core:hub-list
                         :mode :local
                         :user-home user-home
                         :system-home system-home
                         :verbose nil)))
        (check-equal (getf dry-run :dry-run-p) t)
        (check-equal (getf (first (getf dry-run :items)) :action)
                     :install-latest)
        (check-equal (getf applied :dry-run-p) nil)
        (check-true prune-result)
        (check-equal (getf (getf prune-result :summary) :prunable) 1)
        (check-equal (length (getf installed :items)) 1)
        (check-equal (getf (first (getf installed :items)) :version-id)
                     "0.1.0-r2")))))

(deftest test-taf-hub-install-all-dry-run-filters-kind ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let* ((result (taf.core:hub-install-all
                      :kind :flow
                      :dry-run-p t
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (items (getf result :items)))
        (check-equal (getf result :dry-run-p) t)
        (check-equal (length items) 1)
        (check-equal (getf (first items) :package-name) "hic-loop-flow")
        (check-equal (getf (first items) :kind) "flow")
        (check-equal (getf (first items) :action) :install)))))

(deftest test-taf-hub-prune-keeps-newest-local-version ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (taf.core:hub-install-many
       :targets '("taf-multi-demo-v0.1.0-r1" "taf-multi-demo-v0.1.0-r2")
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((dry-run (taf.core:hub-prune
                       :user-home user-home
                       :system-home system-home
                       :verbose nil))
             (item (first (getf dry-run :items))))
        (check-equal (getf dry-run :dry-run-p) t)
        (check-equal (getf item :action) :remove-old)
        (check-equal (getf item :remove-versions) '("0.1.0-r1")))
      (taf.core:hub-prune
       :user-home user-home
       :system-home system-home
       :yes-p t
       :verbose nil)
      (let* ((installed (taf.core:hub-list
                         :mode :local
                         :user-home user-home
                         :system-home system-home
                         :verbose nil))
             (items (getf installed :items)))
        (check-equal (length items) 1)
        (check-equal (getf (first items) :version-id) "0.1.0-r2")))))

(deftest test-taf-hub-maintenance-text-hides-skip-items ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (taf.core:hub-install
       :query "multi-demo"
       :version-id "0.1.0-r2"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (dolist (thunk
               (list
                (lambda ()
                  (taf.core:hub-outdated
                   :user-home user-home
                   :system-home system-home))
                (lambda ()
                  (taf.core:hub-install-all
                   :user-home user-home
                   :system-home system-home))
                (lambda ()
                  (taf.core:hub-upgrade
                   :user-home user-home
                   :system-home system-home))))
        (let ((out (with-output-to-string (*standard-output*)
                     (funcall thunk))))
          (check-equal (%taf-hub-string-contains-p out "no changes") t)
          (check-equal (%taf-hub-string-contains-p out "multi-demo") nil))))))

(deftest test-taf-hub-list-local-installed-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((result (taf.core:hub-list
                      :mode :local
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (items (getf result :items))
             (item (first items)))
        (check-equal (getf result :mode) :local)
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :total) 1)
        (check-equal (getf item :name) "install-demo")
        (check-equal (getf item :version-id) "0.1.0-r1")
        (check-equal (getf item :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-true (getf item :launcher-exists-p))
        (check-true (getf item :metadata-exists-p))))))

(deftest test-taf-hub-list-and-which-show-local-project-origin ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "origin-demo" '("--tool"))
        (setf source-root (han.path:join-path root "origin-demo")))
      (taf.core:hub-install-from-project
       :start-dir source-root
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((list-result (taf.core:hub-list
                           :mode :local
                           :user-home user-home
                           :system-home system-home
                           :verbose nil))
             (origin (han.path:->namestring
                      (han.path:directory-pathname source-root)))
             (item (first (getf list-result :items)))
             (which-result (taf.core:hub-which
                            :query "taf-origin-demo"
                            :user-home user-home
                            :system-home system-home
                            :verbose nil))
             (list-json
               (with-output-to-string (*standard-output*)
                 (taf.core:hub-list
                  :mode :local
                  :json-p t
                  :user-home user-home
                  :system-home system-home)))
             (which-json
               (with-output-to-string (*standard-output*)
                 (taf.core:hub-which
                  :query "taf-origin-demo"
                  :json-p t
                  :user-home user-home
                  :system-home system-home))))
        (check-equal (getf item :origin-kind) "local-project")
        (check-equal (getf item :origin) origin)
        (check-equal (%taf-hub-string-contains-p
                      (getf item :origin-display)
                      "[local-project]")
                     t)
        (check-equal (getf which-result :origin-kind) "local-project")
        (check-equal (%taf-hub-string-contains-p
                      (getf which-result :origin-display)
                      "[local-project]")
                     t)
        (check-equal (%taf-hub-string-contains-p list-json
                                                 "\"origin_kind\"")
                     t)
        (check-equal (%taf-hub-string-contains-p which-json
                                                 "\"origin_display\"")
                     t)))))

(deftest test-taf-hub-list-local-empty ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (result (taf.core:hub-list
                    :mode :local
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :total) 0)
      (check-equal (getf result :items) nil))))

(deftest test-taf-hub-list-online-index-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let* ((result (taf.core:hub-list
                      :mode :online
                      :user-home user-home
                      :system-home system-home
                      :verbose nil))
             (items (getf result :items))
             (first-item (first items))
             (second-item (second items)))
        (check-equal (getf result :mode) :online)
        (check-equal (getf result :total) 2)
        (check-equal (length items) 2)
        (check-equal (getf first-item :name) "bwa-mem")
        (check-equal (getf first-item :latest-version-id) "0.7.17-r2")
        (check-equal (getf first-item :command-name) "taf-bwa-mem")
        (check-equal (getf second-item :name) "hic-loop-flow")))))

(deftest test-taf-hub-list-online-json-and-limit ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-search-index))
      (let ((out
              (with-output-to-string (*standard-output*)
                (taf.core:hub-list
                 :mode :online
                 :limit 1
                 :json-p t
                 :user-home user-home
                 :system-home system-home))))
        (check-equal (%taf-hub-string-contains-p out "taffish.list/v1") t)
        (check-equal (%taf-hub-string-contains-p out "\"mode\": \"online\"") t)
        (check-equal (%taf-hub-string-contains-p out "\"total\": 2") t)
        (check-equal (%taf-hub-string-contains-p out "bwa-mem") t)
        (check-equal (%taf-hub-string-contains-p out "hic-loop-flow") nil)))))

(deftest test-taf-hub-list-online-missing-index-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-list
           :mode :online
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))

(deftest test-taf-hub-uninstall-local-source-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let* ((installed (taf.core:hub-install
                         :query "install-demo"
                         :user-home user-home
                         :system-home system-home
                         :verbose nil))
             (launcher (getf installed :launcher-file))
             (install-root (getf installed :install-root))
             (uninstalled (taf.core:hub-uninstall
                           :query "install-demo"
                           :version-id "0.1.0-r1"
                           :user-home user-home
                           :system-home system-home
                           :verbose nil)))
        (check-equal (getf uninstalled :scope) :user)
        (check-equal (getf uninstalled :package-name) "install-demo")
        (check-equal (getf uninstalled :version-id) "0.1.0-r1")
        (check-equal (getf uninstalled :uninstalled-p) t)
        (check-equal (uiop:file-exists-p launcher) nil)
        (check-equal (uiop:directory-exists-p
                      (han.path:directory-pathname install-root))
                     nil)))))

(deftest test-taf-hub-uninstall-artifact-dry-run-keeps-install ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (let* ((installed (taf.core:hub-install
                         :query "install-demo"
                         :user-home user-home
                         :system-home system-home
                         :verbose nil))
             (launcher (getf installed :launcher-file))
             (install-root (getf installed :install-root))
             (dry-run (taf.core:hub-uninstall
                       :query "taf-install-demo-v0.1.0-r1"
                       :dry-run-p t
                       :user-home user-home
                       :system-home system-home
                       :verbose nil)))
        (check-equal (getf dry-run :dry-run-p) t)
        (check-equal (getf dry-run :uninstalled-p) nil)
        (check-true (uiop:file-exists-p launcher))
        (check-true (uiop:directory-exists-p
                     (han.path:directory-pathname install-root)))))))

(deftest test-taf-hub-uninstall-command-query-single-version ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let ((result (taf.core:hub-uninstall
                     :query "taf-install-demo"
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :command-base) "taf-install-demo")
        (check-equal (getf result :uninstalled-p) t)))))

(deftest test-taf-hub-uninstall-missing-force ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (result (taf.core:hub-uninstall
                    :query "missing-app"
                    :force-p t
                    :user-home user-home
                    :system-home system-home
                    :verbose nil)))
      (check-equal (getf result :missing-p) t)
      (check-equal (getf result :uninstalled-p) nil))))

(deftest test-taf-hub-uninstall-many-removes-targets ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-r1 nil)
           (source-r2 nil))
      (ensure-directories-exist (han.path:join-path root "v1/"))
      (ensure-directories-exist (han.path:join-path root "v2/"))
      (uiop:with-current-directory ((han.path:join-path root "v1/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "1"))
        (setf source-r1 (han.path:join-path root "v1" "multi-demo")))
      (uiop:with-current-directory ((han.path:join-path root "v2/"))
        (taf.core:project-new "multi-demo"
                              '("--tool" "--version" "0.1.0"
                                "--release" "2"))
        (setf source-r2 (han.path:join-path root "v2" "multi-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-multi-version-index source-r1 source-r2))
      (taf.core:hub-install-many
       :targets '("taf-multi-demo-v0.1.0-r1"
                  "taf-multi-demo-v0.1.0-r2")
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((summary
               (taf.core:hub-uninstall-many
                :targets '("taf-multi-demo-v0.1.0-r1"
                           "taf-multi-demo-v0.1.0-r2")
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (results (getf summary :results))
             (alias (han.path:join-path user-home "bin/taf-multi-demo")))
        (check-equal (getf summary :target-count) 2)
        (check-equal (length results) 2)
        (check-equal (getf (first results) :uninstalled-p) t)
        (check-equal (getf (second results) :uninstalled-p) t)
        (check-equal (uiop:file-exists-p alias) nil)))))

(deftest test-taf-hub-which-artifact-command-user-scope ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let ((result (taf.core:hub-which
                     :query "taf-install-demo-v0.1.0-r1"
                     :user-home user-home
                     :system-home system-home
                     :verbose nil)))
        (check-equal (getf result :scope) :user)
        (check-equal (getf result :package-name) "install-demo")
        (check-equal (getf result :version-id) "0.1.0-r1")
        (check-equal (getf result :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-equal (getf result :command-base) "taf-install-demo")
        (check-true (getf result :launcher-exists-p))
        (check-true (getf result :command-exists-p))
        (check-true (getf result :metadata-exists-p))
        (check-equal (getf result :source-ref) "v0.1.0-r1")))))

(deftest test-taf-hub-which-command-query-json-output ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let ((out
              (with-output-to-string (*standard-output*)
                (taf.core:hub-which
                 :query "taf-install-demo"
                 :json-p t
                 :user-home user-home
                 :system-home system-home))))
        (check-equal (%taf-hub-string-contains-p out "taffish.which/v1") t)
        (check-equal (%taf-hub-string-contains-p out "launcher_file") t)
        (check-equal (%taf-hub-string-contains-p out "command_file") t)
        (check-equal (%taf-hub-string-contains-p out "taf-install-demo-v0.1.0-r1") t)))))

(deftest test-taf-hub-which-many-targets-json-array ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home"))
           (source-root nil))
      (uiop:with-current-directory (root)
        (taf.core:project-new "install-demo" '("--tool"))
        (setf source-root (han.path:join-path root "install-demo")))
      (%taf-hub-write-current-index
       user-home
       (%taf-hub-sample-install-index source-root))
      (taf.core:hub-install
       :query "install-demo"
       :user-home user-home
       :system-home system-home
       :verbose nil)
      (let* ((summary
               (taf.core:hub-which-many
                :targets '("install-demo" "taf-install-demo-v0.1.0-r1")
                :user-home user-home
                :system-home system-home
                :verbose nil))
             (results (getf summary :results))
             (out
               (with-output-to-string (*standard-output*)
                 (taf.core:hub-which-many
                  :targets '("install-demo" "taf-install-demo-v0.1.0-r1")
                  :json-p t
                  :user-home user-home
                  :system-home system-home))))
        (check-equal (getf summary :target-count) 2)
        (check-equal (length results) 2)
        (check-equal (getf (first results) :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-equal (getf (second results) :artifact-name)
                     "taf-install-demo-v0.1.0-r1")
        (check-equal (%taf-hub-string-contains-p out "[") t)
        (check-equal (%taf-hub-string-contains-p out "taffish.which/v1") t)
        (check-equal (%taf-hub-string-contains-p out "taf-install-demo-v0.1.0-r1") t)))))

(deftest test-taf-hub-which-missing-error ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (check-equal
       (%taf-hub-signal-error-p
        (lambda ()
          (taf.core:hub-which
           :query "missing-command"
           :user-home user-home
           :system-home system-home
           :verbose nil)))
       t))))
