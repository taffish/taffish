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

(defun %taf-hub-error-string (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (error (condition)
      (princ-to-string condition))))

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
  ;; A content-only edit must truncate the old bytes and retain its mode.
  (uiop:run-program (list "sh" "-c" "cat > \"$1\"" "fixture" (namestring (pathname path)))
                    :input (make-string-input-stream string)))

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
        (check-equal :verified
                     (getf (taf.core::%hub-diagnose-entry
                            (first (taf.core::%hub-uninstall-installed-entries system-home))) :state))
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

(deftest test-taf-hub-human-output-localized-json-invariant ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (flet ((render (language json-p)
               (taffish.i18n:with-language (language)
                 (with-output-to-string
                     (*standard-output* nil :element-type 'character)
                   (taf.core:hub-info
                    :query "my-new-test"
                    :user-home user-home
                    :system-home system-home
                    :json-p json-p)))))
        (let ((english (render "en" nil))
              (chinese (render "zh" nil))
              (english-json (render "en" t))
              (chinese-json (render "zh" t)))
          (check-true (search "[TAF] app info: my-new-test" english
                              :test #'char=))
          (check-true (search "[TAF] 应用信息：my-new-test" chinese
                              :test #'char=))
          (check-true (search "pipe=yes, command-mode=yes" english
                              :test #'char=))
          (check-true (search "管道=是，命令模式=是" chinese
                              :test #'char=))
          (check-true (search "冒烟测试" chinese :test #'char=))
          (check-equal chinese-json english-json))))))

(deftest test-taf-hub-error-localized-with-stable-query ()
  (with-taf-hub-temp-dir (root)
    (let* ((user-home (han.path:join-path root "user-home"))
           (system-home (han.path:join-path root "system-home")))
      (%taf-hub-write-current-index user-home (%taf-hub-sample-info-index))
      (flet ((message-for (language)
               (taffish.i18n:with-language (language)
                 (%taf-hub-error-string
                  (lambda ()
                    (taf.core:hub-info
                     :query "missing-i18n-app"
                     :user-home user-home
                     :system-home system-home
                     :verbose nil))))))
        (let ((english (message-for "en"))
              (chinese (message-for "zh")))
          (check-true (search "can't find TAFFISH app or command" english
                              :test #'char=))
          (check-true (search "无法在本地索引中找到 TAFFISH 应用或命令"
                              chinese :test #'char=))
          (check-true (search "missing-i18n-app" english :test #'char=))
          (check-true (search "missing-i18n-app" chinese :test #'char=)))))))

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

(deftest test-taf-shared-version-order-mixed-numeric-regression ()
  (dolist (pair '(("2.0.0-a.7.10" "2.0.0-a.7.3")
                  ("2.0.0-rc.10" "2.0.0-rc.2")
                  ("a.7.10" "a.7.3")
                  ("1.0-rc10" "1.0-rc2")
                  ("1.0-beta" "1.0-alpha")
                  ("1.0-alpha.1" "1.0-alpha")
                  ("1.0-alpha" "1.0-10")
                  ("2.0.10" "2.0.3")
                  ("2.0.0" "2.0.0-rc.10")))
    (destructuring-bind (new old) pair
      (check-equal 1 (taf.core::%publish-compare-versions new old))
      (check-equal -1 (taf.core::%publish-compare-versions old new))
      (check-true (taf.core::%hub-version-id-newer-p
                   (format nil "~A-r1" new) (format nil "~A-r1" old)))))
  (check-true (taf.core::%hub-version-id-newer-p "2.0.0-r10" "2.0.0-r9")))

(deftest test-taf-shared-version-order-contract-and-properties ()
  (dolist (pair '(("1.0" "1.0.0") ("1.0+abc" "1.0+xyz")))
    (check-equal 0 (apply #'taf.core::%compare-versions pair)))
  (check-equal '(1 t) (multiple-value-list
                      (taf.core::%compare-versions "a.7.10" "a.7.3")))
  (check-equal nil (nth-value 1 (taf.core::%compare-versions "nightly" "stable")))
  (check-error (error)
    (taf.core::%hub-upgrade-package-status "1.0-r1" "1.0.0-r1"))
  (let ((versions '("1.0" "1.0.0" "1.0+abc" "1.0-alpha.2" "1.0-alpha.10"
                    "1.0-beta" "1.0-rc2" "1.0-rc10" "1.0-1" "2.0"
                    "a.7.3" "a.7.10" "nightly" "2024b" "")))
    (dolist (a versions)
      (check-equal 0 (taf.core::%compare-versions a a))
      (dolist (b versions)
        (check-equal (- (taf.core::%compare-versions a b))
                     (taf.core::%compare-versions b a))
        (dolist (c versions)
          (when (and (<= (taf.core::%compare-versions a b) 0)
                     (<= (taf.core::%compare-versions b c) 0))
            (check-true (<= (taf.core::%compare-versions a c) 0)))))))
  (let* ((ids '("2.0.0-a.7.3-r1" "2.0.0-a.7.10-r1" "2.0.0-r1"))
         (expected (reverse ids)))
    (check-equal expected (sort (copy-list ids) #'taf.core::%hub-version-id-newer-p))
    (check-equal expected (sort (reverse ids) #'taf.core::%hub-version-id-newer-p))
    (check-equal "v2.0.0-r1"
                 (getf (taf.core::%publish-latest-info
                        (taf.core::%publish-release-infos
                         (mapcar (lambda (v) (concatenate 'string "v" v)) ids)))
                       :tag))))

(defun %taf-hub-order-fixture (root &optional (kind :flow))
  (let* ((home (han.path:join-path root "user-home/"))
         (records (han.json:json-object))
         (package (han.json:json-object
                   (cons "latest" "2.0.0-a.7.10-r1")
                   (cons "repository_url" "https://github.com/taffish/order-demo")
                   (cons "command" (han.json:json-object (cons "name" "taf-order-demo")))
                   (cons "versions" records)))
         (index (han.json:json-object
                 (cons "schema_version" "taffish.index/v1")
                 (cons "packages" (han.json:json-object (cons "order-demo" package)))
                 (cons "commands" (han.json:json-object)))))
    (dolist (version '("2.0.0-a.7.3" "2.0.0-a.7.10" "2.0.0-a.7.20"))
      (let ((parent (han.path:join-path root (format nil "src/~A/" version))))
        (ensure-directories-exist parent)
        (uiop:with-current-directory (parent)
          (taf.core:project-new "order-demo"
                                (list (if (eql kind :tool) "--tool" "--flow")
                                      "--version" version)))
        (let* ((source (han.path:join-path parent "order-demo/"))
               (project (taf.core:project-check source nil nil)))
          (setf (gethash (format nil "~A-r1" version) records)
                (taf.core::%hub-install-project-record project)))))
    (%taf-hub-order-write-index home index)
    (values home index package)))

(defun %taf-hub-order-write-index (home index)
  (%taf-hub-write-current-index home (han.json:encode-json index)))

(defun %taf-hub-order-install (home version)
  (taf.core:hub-install :query "order-demo" :version-id version
                        :user-home home :system-home home :verbose nil))

(defun %taf-hub-order-versions (home)
  (sort (mapcar (lambda (e) (getf e :version-id))
                (taf.core::%hub-uninstall-installed-entries home)) #'string<))

(defun %taf-hub-order-plan (home &optional (function #'taf.core:hub-prune))
  (funcall function :user-home home :system-home home :verbose nil))

(defun %taf-hub-kind-filter-fixture (kind metadata-kind-p)
  (let* ((local "2.0.0-a.7.3-r1")
         (repository "https://github.com/taffish/order-demo")
         (metadata (han.json:json-object
                    (cons "origin_kind" "hub-index")
                    (cons "repository_url" repository)))
         (records (han.json:json-object
                   (cons local (han.json:json-object
                                (cons "kind" kind)
                                (cons "version" "2.0.0-a.7.3") (cons "release" 1)))
                   (cons "nightly-r1" (han.json:json-object
                                      (cons "kind" kind)
                                      (cons "version" "nightly") (cons "release" 1)))))
         (package (han.json:json-object
                   (cons "latest" "nightly-r1")
                   (cons "repository_url" repository)
                   (cons "versions" records)))
         (entry (list :package-name "order-demo" :version-id local :metadata metadata)))
    (when metadata-kind-p (setf (gethash "kind" metadata) kind))
    (values (cons "order-demo" (list entry))
            (han.json:json-object (cons "order-demo" package))
            package)))

(deftest test-taf-hub-upgrade-kind-filter-precedes-validation ()
  (let ((original (symbol-function 'taf.core::%hub-diagnose-entry)))
    (unwind-protect
         (progn
           (setf (symbol-function 'taf.core::%hub-diagnose-entry)
                 (lambda (entry)
                   (declare (ignore entry))
                   (error "Excluded kind must not be inspected.")))
           (dolist (pair '(("flow" :tool) ("tool" :flow)))
             (dolist (metadata-kind-p '(t nil))
               (multiple-value-bind (group packages package)
                   (%taf-hub-kind-filter-fixture (first pair) metadata-kind-p)
                 (declare (ignore package))
                 (check-equal nil (taf.core::%hub-upgrade-plan-item
                                   group packages (second pair)))))))
      (setf (symbol-function 'taf.core::%hub-diagnose-entry) original))))

(deftest test-taf-hub-upgrade-kind-filter-keeps-selected-checks ()
  (let ((original (symbol-function 'taf.core::%hub-diagnose-entry))
        (calls 0))
    (unwind-protect
         (progn
           (setf (symbol-function 'taf.core::%hub-diagnose-entry)
                 (lambda (entry)
                   (declare (ignore entry))
                   (incf calls)
                   (list :state :verified)))
           (dolist (pair '(("flow" :flow) ("tool" :tool)))
             (multiple-value-bind (group packages package)
                 (%taf-hub-kind-filter-fixture (first pair) t)
               (dolist (requested (list (second pair) :all))
                 (check-true
                  (search "cannot safely order"
                          (%taf-hub-error-string
                           (lambda () (taf.core::%hub-upgrade-plan-item
                                       group packages requested))))))
               (setf (gethash "latest" package) "2.0.0-a.7.3-r1")
               (dolist (requested (list (second pair) :all))
                 (let ((item (taf.core::%hub-upgrade-plan-item group packages requested)))
                   (check-equal (first pair) (getf item :kind))
                   (check-equal :current (getf item :status))
                   (check-equal :skip (getf item :action))))))
           (check-equal 8 calls))
      (setf (symbol-function 'taf.core::%hub-diagnose-entry) original))))

(deftest test-taf-hub-legacy-install-does-not-block-batch ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (let* ((installed (%taf-hub-order-install home "2.0.0-a.7.10-r1"))
             (snapshot (han.path:join-path
                        (han.path:parent-directory-pathname (getf installed :command-file))
                        ".taf-order-demo-v2.0.0-a.7.10-r1/"))
             (manifest (taf.core::%build-manifest-file snapshot)))
        (delete-file manifest)
        (let* ((result (taf.core:hub-install-all :user-home home :system-home home
                                                :yes-p t :verbose nil))
               (item (first (getf result :items))))
          (check-equal :current (getf item :status))
          (check-equal :skip (getf item :action))
          (check-equal :unverified (getf (getf item :validation) :state))
          (check-equal nil (han.path:file-exists-p manifest)))))))

(deftest test-taf-hub-mixed-versions-install-upgrade-prune ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (let ((single (taf.core:hub-install :query "order-demo" :user-home home
                                        :system-home home :dry-run-p t :verbose nil)))
        (check-equal "2.0.0-a.7.10-r1" (getf single :version-id)))
      (dolist (planner (list #'taf.core:hub-install-all #'taf.core:hub-outdated
                            #'taf.core:hub-upgrade))
        (let ((item (first (getf (%taf-hub-order-plan home planner) :items))))
          (check-equal :outdated (getf item :status))
          (check-equal "2.0.0-a.7.10-r1" (getf item :latest-version-id))))
      (check-equal '("2.0.0-a.7.3-r1") (%taf-hub-order-versions home))
      (taf.core:hub-install-all :user-home home :system-home home :yes-p t :verbose nil)
      (check-equal "2.0.0-a.7.10-r1"
                   (getf (taf.core::%hub-install-latest-command-entry
                          (taf.core::%hub-install-command-entries
                           home "taf-order-demo" (han.path:join-path home "bin/")))
                         :version-id))
      (check-equal '("2.0.0-a.7.3-r1")
                   (getf (first (getf (%taf-hub-order-plan home) :items)) :remove-versions))
      (taf.core:hub-prune :user-home home :system-home home :yes-p t :verbose nil)
      (check-equal '("2.0.0-a.7.10-r1") (%taf-hub-order-versions home))
      (check-equal :skip (getf (first (getf (%taf-hub-order-plan home #'taf.core:hub-install-all)
                                          :items)) :action)))))

(deftest test-taf-hub-index-latest-is-not-the-maximum ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.20-r1")
      (check-equal :ahead
                   (getf (first (getf (%taf-hub-order-plan home #'taf.core:hub-upgrade)
                                     :items)) :status))
      (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let ((item (first (getf (%taf-hub-order-plan home) :items))))
        (check-equal "2.0.0-a.7.10-r1" (getf item :latest-version-id))
        (check-equal '("2.0.0-a.7.3-r1") (getf item :remove-versions)))
      (check-equal :current
                   (getf (first (getf (%taf-hub-order-plan home #'taf.core:hub-install-all)
                                     :items)) :status))
      (taf.core:hub-prune :user-home home :system-home home :yes-p t :verbose nil)
      (check-equal '("2.0.0-a.7.10-r1" "2.0.0-a.7.20-r1") (%taf-hub-order-versions home)))))

(deftest test-taf-hub-prune-missing-invalid-latest-and-source-protection ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
      (let* ((new (%taf-hub-order-install home "2.0.0-a.7.10-r1"))
             (metadata-file (han.path:join-path home "apps/order-demo/2.0.0-a.7.3-r1/install.json"))
             (metadata (han.json:read-json-file metadata-file)))
        (dolist (latest '(nil "absent-r1"))
          (setf (gethash "latest" package) latest)
          (%taf-hub-order-write-index home index)
          (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
          (check-equal :missing-index
                       (getf (first (getf (%taf-hub-order-plan home #'taf.core:hub-install-all)
                                         :items)) :status)))
        (setf (gethash "latest" package) "2.0.0-a.7.10-r1")
        (%taf-hub-order-write-index home index)
        (dolist (origin '("local-project" "unknown" nil))
          (setf (gethash "origin_kind" metadata) origin)
          (han.json:write-json-file metadata-file metadata)
          (taf.core:hub-prune :user-home home :system-home home :yes-p t :verbose nil)
          (check-equal 2 (length (%taf-hub-order-versions home))))
        (setf (gethash "origin_kind" metadata) "hub-index"
              (gethash "repository_url" metadata) "https://example.test/private")
        (han.json:write-json-file metadata-file metadata)
        (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
        (setf (gethash "repository_url" metadata) "https://github.com/taffish/order-demo")
        (han.json:write-json-file metadata-file metadata)
        (%taf-hub-write-string (getf new :command-file) "broken")
        (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
        (check-error (error) (%taf-hub-order-plan home #'taf.core:hub-install-all))
        (check-equal 2 (length (%taf-hub-order-versions home)))))))

(deftest test-taf-hub-prune-old-failure-and-scope ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (let ((record (gethash "2.0.0-a.7.10-r1" (gethash "versions" package))))
        (setf (gethash "local_path" (gethash "source" record)) "/nonexistent/order-source")
        (%taf-hub-order-write-index home index)
        (check-error (error)
          (taf.core:hub-install-all :user-home home :system-home home :yes-p t
                                   :prune-old-p t :verbose nil))
        (check-equal '("2.0.0-a.7.3-r1") (%taf-hub-order-versions home))))))

(deftest test-taf-hub-prune-protects-unordered-and-equal-precedence-identities ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((keep (first (taf.core::%hub-uninstall-installed-entries home)))
             (entries
               (cons keep
                     (mapcar (lambda (id)
                               (let ((entry (copy-list keep)))
                                 (setf (getf entry :version-id) id)
                                 entry))
                             '("stable-r1" "2.0.0-a.7.10+metadata-r1"
                               "2.0.0-a.7.3-r1" "2.0.0-a.7.20-r1"))))
             (plan (taf.core::%hub-prune-item (cons "order-demo" entries) :all
                                             (gethash "packages" index))))
        ;; Fabricated identities without matching frozen metadata are protected.
        (check-equal nil (getf plan :remove-versions))
        (check-equal '("2.0.0-a.7.10-r1") (%taf-hub-order-versions home))))))

(defun %taf-hub-diagnostic-manifest (entry)
  (taf.core::%build-manifest-file
   (han.path:join-path (han.path:parent-directory-pathname (getf entry :command-file))
                       (format nil ".~A/" (getf entry :artifact-name)))))

(defun %taf-hub-diagnostic-codes (diagnosis)
  (mapcar (lambda (i) (getf i :code)) (getf diagnosis :issues)))

(deftest test-taf-hub-probe-matches-posix-test ()
  (with-taf-hub-temp-dir (root)
    (let* ((file (han.path:join-path root (format nil "literal ' $() * ? 中文~%tab~C" #\Tab)))
           (link (han.path:join-path root "link"))
           (missing (han.path:join-path root "missing"))
           (dangling (han.path:join-path root "dangling"))
           (hidden (han.path:join-path root ".hidden")))
      (han.os:run-program (list (han.os:find-executable "sh") "-c"
                               "printf data > \"$1\"" "probe-fixture" (namestring file)))
      (%taf-hub-write-string hidden "hidden")
      (dolist (pair (list (list file link) (list missing dangling)))
        (han.os:run-program (list (han.os:find-executable "ln") "-s"
                                 (namestring (first pair)) (namestring (second pair)))))
      (unwind-protect
           (dolist (mode '("000" "644" "755"))
             (han.os:run-program (list (han.os:find-executable "chmod") mode (namestring file)))
             (taf.core::%with-hub-diagnostic-probes
               (taf.core::%hub-diagnostic-prime "properties" (list root file link missing dangling))
               (dolist (path (list root file link missing dangling))
                 (dolist (flag '("-e" "-f" "-d" "-L" "-r" "-x"))
                   (multiple-value-bind (out err code)
                       (han.os:run-program (list (han.os:find-executable "test") flag
                                                (taf.core::%hub-diagnostic-path-key path)))
                     (declare (ignore out err))
                     (check-equal (zerop code) (taf.core::%hub-diagnostic-test flag path)))))
               (check-equal 4 (length (taf.core::%hub-diagnostic-children root)))
               (check-equal 2 (length (taf.core::%hub-diagnostic-children root t)))))
        (han.os:run-program (list (han.os:find-executable "chmod") "644" (namestring file)))))))

(deftest test-taf-hub-probe-rejects-incomplete-response ()
  (let ((original (symbol-function 'han.os:run-program)))
    (unwind-protect
         (dolist (reply (list "truncated" "" (format nil "F~C/test~C111111~C"
                                                     (code-char 0) (code-char 0) (code-char 0))))
           (setf (symbol-function 'han.os:run-program)
                 (lambda (command &key output)
                   (declare (ignore output))
                   (with-open-file (out (nth 4 command) :direction :output :if-exists :supersede
                                               :external-format :utf-8)
                     (write-string reply out))
                   (values nil "" 0)))
           (taf.core::%with-hub-diagnostic-probes
             (let ((failed nil))
               (handler-case (taf.core::%hub-diagnostic-probe "children" '("/test"))
                 (error () (setf failed t)))
               (check-true failed)
               (check-equal 0 (hash-table-count taf.core::*hub-diagnostic-properties*)))))
      (setf (symbol-function 'han.os:run-program) original))))

(deftest test-taf-hub-probe-batch-limits ()
  (let ((original (symbol-function 'taf.core::%hub-diagnostic-probe))
        (calls 0) (seen (make-hash-table :test #'equal)))
    (unwind-protect
         (progn
           (setf (symbol-function 'taf.core::%hub-diagnostic-probe)
                 (lambda (mode paths)
                   (declare (ignore mode))
                   (incf calls)
                   (check-true (<= (loop for path in paths sum
                                        (+ 16 (loop for c across path sum
                                                    (if (< (char-code c) 128) 1 3))))
                                   65536))
                   (dolist (path paths)
                     (check-false (gethash path seen))
                     (setf (gethash path seen) t))))
           (let ((paths (loop for i below 1000 collect
                             (format nil "/~A/~D" (make-string 200 :initial-element #\中) i))))
             (taf.core::%hub-diagnostic-prime "properties" (append paths paths)))
           (check-equal 1000 (hash-table-count seen))
           (check-true (<= 9 calls 11)))
      (setf (symbol-function 'taf.core::%hub-diagnostic-probe) original))))

(deftest test-taf-hub-probe-cache-lifetime-and-budget ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (original (symbol-function 'han.os:run-program)) (calls 0))
        (unwind-protect
             (progn
               (setf (symbol-function 'han.os:run-program)
                     (lambda (&rest args) (incf calls) (apply original args)))
               (taf.core::%hub-call-with-diagnostic-batch
                (make-list 300 :initial-element entry)
                (lambda ()
                  (dotimes (i 300)
                    (check-equal :verified (getf (taf.core::%hub-diagnose-entry entry) :state)))))
               (check-true (<= calls 3))
               ;; A new operation must observe permission and content changes.
               (han.os:run-program (list (han.os:find-executable "chmod") "644" (getf entry :command-file)))
               (check-true (member "not-executable"
                                   (%taf-hub-diagnostic-codes (taf.core::%hub-diagnose-entry entry))
                                   :test #'equal))
               (han.os:run-program (list (han.os:find-executable "chmod") "755" (getf entry :command-file)))
               (%taf-hub-write-string (getf entry :command-file) "changed")
               (check-equal "changed" (uiop:read-file-string (getf entry :command-file)))
               (let ((codes (%taf-hub-diagnostic-codes (taf.core::%hub-diagnose-entry entry))))
                 (check-true (member "wrapper-digest" codes :test #'equal))
                 (check-false (member "not-executable" codes :test #'equal))))
          (setf (symbol-function 'han.os:run-program) original))))))

(deftest test-taf-hub-doctor-batch-probe-budget-and-target ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (dolist (version '("2.0.0-a.7.3-r1" "2.0.0-a.7.10-r1" "2.0.0-a.7.20-r1"))
        (%taf-hub-order-install home version))
      (let ((original (symbol-function 'taf.core::%hub-diagnostic-probe)) (calls 0))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-probe)
                     (lambda (&rest args) (incf calls) (apply original args)))
               (let ((results (taf.core::%hub-diagnose-installations home)))
                 (check-equal 3 (length results))
                 (check-true (every (lambda (r) (eql (getf r :state) :verified)) results))
                 (check-true (<= calls 8)))
               (let ((results (taf.core::%hub-diagnose-installations
                               home '("taf-order-demo-v2.0.0-a.7.3-r1"))))
                 (check-equal 1 (length results))
                 (check-equal "2.0.0-a.7.3-r1" (getf (first results) :version-id))))
          (setf (symbol-function 'taf.core::%hub-diagnostic-probe) original))))))

(deftest test-taf-hub-diagnostic-progress-delayed-and-localized ()
  (check-equal nil (taf.core::%hub-make-diagnostic-progress nil))
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let* ((now 0) (output (make-string-output-stream)) (*error-output* output)
             (callback (taf.core::%hub-make-diagnostic-progress t (lambda () now))))
        (funcall callback 0 300)
        (check-equal "" (get-output-stream-string output))
        (setf now internal-time-units-per-second)
        (funcall callback 120 300)
        (let ((message (get-output-stream-string output)))
          (check-true (search "120/300" message))
          (check-true (search (if (equal language "en") "Checking local installations" "正在检查本地安装") message)))
        (funcall callback 121 300)
        (check-equal "" (get-output-stream-string output))))))

(deftest test-taf-hub-diagnostics-enumeration-preserves-links ()
  (with-taf-hub-temp-dir (root)
    (let* ((file (han.path:join-path root (format nil "space and~%newline")))
           (link (han.path:join-path root "link")))
      (%taf-hub-write-string file "local")
      (multiple-value-bind (out err code)
          (han.os:run-program (list (han.os:find-executable "ln") "-s"
                                   (namestring file) (namestring link)))
        (declare (ignore out err))
        (check-equal 0 code))
      (check-equal 2 (length (taf.core::%hub-diagnostic-children root)))
      (check-equal 1 (length (taf.core::%hub-diagnostic-children root t)))
      (let ((issues (taf.core::%hub-diagnostic-tree-issues root)))
        (check-equal :unknown (taf.core::%hub-diagnostic-state issues))
        (check-true (find "unsafe-path" issues :test #'equal
                          :key (lambda (issue) (getf issue :code))))))))

(deftest test-taf-hub-diagnostics-manifest-and-file-states ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (file (%taf-hub-diagnostic-manifest entry))
             (original (han.json:read-json-file file)))
        (check-equal :verified (getf (taf.core::%hub-diagnose-entry entry) :state))
        (dolist (case '(("schema" "future/v99" :unknown "manifest-schema")
                        ("artifact" "other" :invalid "identity-mismatch")
                        ("source_sha256" "bad" :invalid "manifest-invalid")
                        ("wrapper_sha256" "0000000000000000000000000000000000000000000000000000000000000000"
                         :invalid "wrapper-digest")))
          (let ((object (han.json:parse-json (han.json:encode-json original))))
            (setf (gethash (first case) object) (second case))
            (han.json:write-json-file file object)
            (let ((diagnosis (taf.core::%hub-diagnose-entry entry)))
              (check-equal (third case) (getf diagnosis :state))
              (check-true (member (fourth case) (%taf-hub-diagnostic-codes diagnosis) :test #'equal)))))
        (%taf-hub-write-string file "{")
        (check-true (member "manifest-invalid" (%taf-hub-diagnostic-codes (taf.core::%hub-diagnose-entry entry)) :test #'equal))
        (han.json:write-json-file file original)
        (%taf-hub-write-string (getf entry :launcher-file) (format nil "#!/bin/sh~%exit 0~%"))
        (check-equal :unverified (getf (taf.core::%hub-diagnose-entry entry) :state))
        (delete-file file)
        (delete-file (getf entry :command-file))
        (check-equal :invalid (getf (taf.core::%hub-diagnose-entry entry) :state))))))

(deftest test-taf-hub-diagnostics-legacy-old-version-is-protected ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (manifest (%taf-hub-diagnostic-manifest entry)))
        (delete-file manifest)
        (taf.core:hub-upgrade :user-home home :system-home home :yes-p t :prune-old-p t :verbose nil)
        (check-equal 2 (length (%taf-hub-order-versions home)))
        (check-equal nil (han.path:file-exists-p manifest))
        (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
        (delete-file (han.path:join-path (han.path:parent-directory-pathname manifest) "src/main.taf"))
        (check-equal :invalid (getf (taf.core::%hub-diagnose-entry entry) :state))))))

(deftest test-taf-hub-diagnostics-read-error-and-blocking-summary ()
  (let ((original (symbol-function 'taf.core::%hub-diagnostic-test)))
    (unwind-protect
         (progn
           (setf (symbol-function 'taf.core::%hub-diagnostic-test)
                 (lambda (&rest args) (declare (ignore args)) (error "access denied")))
           (check-equal :unknown
                        (getf (first (taf.core::%hub-diagnostic-file-issues "/unreadable")) :state)))
      (setf (symbol-function 'taf.core::%hub-diagnostic-test) original)))
  (let* ((items (loop for name in '("broken-one" "broken-two")
                      collect (list :status :current :validation
                                    (list :package-name name :version-id "1-r1" :origin-kind "hub-index"
                                          :state :invalid :issues
                                          (list (taf.core::%hub-diagnostic-issue "wrapper-digest" :invalid "/test"))))))
         (message (handler-case (taf.core::%hub-upgrade-check-plan items :system)
                    (error (c) (princ-to-string c)))))
    (check-true (search "broken-one" message))
    (check-true (search "broken-two" message))
    (check-true (search "wrapper-digest" message))
    (check-true (search "--repair --system" message))
    (check-true (search "--system --verbose" message))
    (check-true (search "--json" message))
    (check-false (search "--force" message))))

(deftest test-taf-hub-diagnostic-paths-and-delete-guard ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (file (getf entry :metadata-file))
             (metadata (han.json:read-json-file file))
             (sentinel (han.path:join-path root "unrelated/keep")))
        (%taf-hub-write-string sentinel "keep")
        (dolist (key '("install_root" "source_dir" "bin_dir" "launcher_file"
                       "command_file" "command_launcher_file"))
          (let ((modified (han.json:parse-json (han.json:encode-json metadata))))
            (setf (gethash key modified) (namestring (han.path:parent-directory-pathname sentinel)))
            (han.json:write-json-file file modified)
            (let* ((fresh (taf.core::%hub-uninstall-read-entry home file))
                   (diagnosis (taf.core::%hub-diagnose-entry fresh)))
              (check-true (member "metadata-path" (%taf-hub-diagnostic-codes diagnosis) :test #'equal))
              (check-error (error) (taf.core::%hub-uninstall-delete-entry fresh nil))
              ;; Even a previously accepted entry cannot bypass a changed record.
              (check-error (error) (taf.core::%hub-uninstall-delete-entry entry nil))
              (check-equal :skip (getf (first (getf (%taf-hub-order-plan home) :items)) :action))
              (check-true (han.path:file-exists-p sentinel)))))
        (han.json:write-json-file file metadata)
        (check-equal :verified (getf (taf.core::%hub-diagnose-entry entry) :state))))))

(deftest test-taf-hub-diagnostic-install-schema ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (file (getf entry :metadata-file))
             (metadata (han.json:read-json-file file)))
        (dolist (schema '("future/v99" 7 :null :missing "taffish.install/v1"))
          (if (eq schema :missing) (remhash "schema_version" metadata)
              (setf (gethash "schema_version" metadata) schema))
          (han.json:write-json-file file metadata)
          (let ((diagnosis (taf.core::%hub-diagnose-entry
                            (taf.core::%hub-uninstall-read-entry home file))))
            (check-equal (cond ((eq schema :missing) :unverified)
                               ((equal schema "taffish.install/v1") :verified)
                               (t :unknown))
                         (getf diagnosis :state))))))))

(deftest test-taf-hub-diagnostic-apps-root-and-alias ()
  (with-taf-hub-temp-dir (root)
    (let* ((home (han.path:join-path root "empty/"))
           (apps (han.path:join-path home "apps")))
      (check-equal nil (taf.core::%hub-diagnose-installations home))
      (%taf-hub-write-string apps "not a directory")
      (check-true (member "file-missing"
                          (%taf-hub-diagnostic-codes
                           (first (taf.core::%hub-diagnose-installations home))) :test #'equal)))
    (multiple-value-bind (home index package) (%taf-hub-order-fixture (han.path:join-path root "fixture/"))
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((alias (han.path:join-path home "bin/taf-order-demo")))
        (check-equal 2 (length (taf.core::%hub-diagnose-installations home)))
        (delete-file alias)
        (let* ((results (taf.core::%hub-diagnose-installations home))
               (warning (find :command-entry results :key (lambda (r) (getf r :check-kind)))))
          (check-true warning)
          (check-equal :unverified (getf warning :state))
          (check-true (every (lambda (r) (eql (getf r :state) :verified)) (remove warning results))))))))

(deftest test-taf-hub-maintenance-json-applied-results ()
  (let* ((data (taf.core::%hub-upgrade-item-json
                (list :install-result (list :dry-run-p nil :installed-p t :path #P"/tmp/demo"
                                            :nested (list (list :state :ok)))
                      :removed (list (list :install-root-deleted-p t :launcher-deleted-p nil
                                           :install-root "/actual/" :install-root "/wrong/")))))
         (json (han.json:parse-json (han.json:encode-json data)))
         (installed (han.json:get-json json "install_result"))
         (removed (aref (han.json:get-json json "removed") 0)))
    (check-equal t (han.json:get-json installed "installed_p"))
    (check-equal nil (han.json:get-json installed "dry_run_p"))
    (check-equal "/tmp/demo" (han.json:get-json installed "path"))
    (check-equal "/actual/" (han.json:get-json removed "install_root"))
    (check-equal t (han.json:get-json removed "install_root_deleted_p"))
    (check-equal nil (han.json:get-json removed "launcher_deleted_p"))))

(deftest test-taf-hub-prune-rechecks-metadata-schema-before-removal ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((item (first (getf (%taf-hub-order-plan home) :items)))
             (entry (getf item :keep-entry))
             (file (getf entry :metadata-file))
             (metadata (han.json:read-json-file file)))
        (setf (gethash "schema_version" metadata) "future/v99")
        (han.json:write-json-file file metadata)
        (check-error (error) (taf.core::%hub-prune-apply-item-with-home item home nil))
        (check-equal 2 (length (%taf-hub-order-versions home)))
        (%taf-hub-write-string file "{")
        (check-error (error) (taf.core::%hub-prune-apply-item-with-home item home nil))
        (check-true (han.path:file-exists-p file))
        (check-true (han.path:directory-exists-p
                     (han.path:join-path home "apps/order-demo/2.0.0-a.7.3-r1/")))))))

(deftest test-taf-hub-maintenance-applied-json-has-no-progress-text ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (let* ((text (with-output-to-string (*standard-output*)
                     (taf.core:hub-install-all :user-home home :system-home home
                                              :yes-p t :prune-old-p t :json-p t)))
             (result (han.json:parse-json text)))
        (check-equal "taffish.package-plan/v1" (han.json:get-json result "schema_version"))
        (check-equal '("2.0.0-a.7.10-r1") (%taf-hub-order-versions home))
        (check-equal nil (search "[TAF]" text))))))

(deftest test-taf-hub-diagnostic-unsafe-tree-stops-content-read ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (snapshot (han.path:parent-directory-pathname (%taf-hub-diagnostic-manifest entry)))
             (link (han.path:join-path snapshot "unsafe-link"))
             (original (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields))
             (called nil))
        (han.os:run-program (list (han.os:find-executable "ln") "-s"
                                 (namestring root) (namestring link)))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields)
                     (lambda (&rest args) (declare (ignore args)) (setf called t) nil))
               (check-equal :unknown (getf (taf.core::%hub-diagnose-entry entry) :state))
               (check-equal nil called))
          (setf (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields) original))))))

(deftest test-taf-hub-stage1-blocked-target-is-unknown ()
  (with-taf-hub-temp-dir (root)
    (let* ((home (han.path:join-path root "home/"))
           (apps (han.path:join-path home "apps"))
           (outside (han.path:join-path root "outside/"))
           (original (symbol-function 'taf.core::%hub-diagnostic-file-issues)))
      (ensure-directories-exist home)
      (ensure-directories-exist outside)
      (flet ((inspect-blocked ()
               (let* ((results (taf.core::%hub-diagnose-installations home '("demo")))
                      (target (find "demo" results :test #'equal
                                    :key (lambda (r) (getf r :package-name)))))
                 (check-true target)
                 (check-equal :unknown (getf target :state))
                 (check-false (find "target-missing" (mapcan #'%taf-hub-diagnostic-codes results)
                                    :test #'equal)))))
        (dolist (destination (list outside (han.path:join-path root "absent/")))
          (han.os:run-program (list (han.os:find-executable "ln") "-s"
                                   (namestring destination) (namestring apps)))
          (unwind-protect (inspect-blocked) (delete-file apps)))
        (ensure-directories-exist (han.path:directory-pathname apps))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-file-issues)
                     (lambda (path &rest options)
                       (if (equal (taf.core::%hub-diagnostic-path-key path)
                                  (taf.core::%hub-diagnostic-path-key apps))
                           (list (taf.core::%hub-diagnostic-issue "read-error" :unknown path))
                           (apply original path options))))
               (inspect-blocked))
          (setf (symbol-function 'taf.core::%hub-diagnostic-file-issues) original)))
      (let ((results (taf.core::%hub-diagnose-installations home '("demo"))))
        (check-equal :invalid (getf (first results) :state))
        (check-equal '("target-missing") (%taf-hub-diagnostic-codes (first results)))))))

(deftest test-taf-hub-stage1-enumeration-failure-is-local ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((broken (han.path:join-path home "apps/broken/"))
             (original (symbol-function 'taf.core::%hub-diagnostic-contained-p)))
        (%taf-hub-write-string (han.path:join-path broken "1-r1/install.json") "{")
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-contained-p)
                     (lambda (path parent)
                       (when (equal (taf.core::%hub-diagnostic-path-key path)
                                    (taf.core::%hub-diagnostic-path-key broken))
                         (error "Injected package path failure."))
                       (funcall original path parent)))
               (let* ((results (taf.core::%hub-diagnose-installations home))
                      (good (find "order-demo" results :test #'equal
                                  :key (lambda (r) (getf r :package-name))))
                      (bad (find "broken" results :test #'equal
                                 :key (lambda (r) (getf r :package-name)))))
                 (check-equal :verified (getf good :state))
                 (check-equal :unknown (getf bad :state)))
               (let ((results (taf.core::%hub-diagnose-installations home '("order-demo"))))
                 (check-equal 1 (length results))
                 (check-equal :verified (getf (first results) :state))))
          (setf (symbol-function 'taf.core::%hub-diagnostic-contained-p) original))))))

(deftest test-taf-hub-stage1-alias-canonical-bin-group ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entries (taf.core::%hub-uninstall-installed-entries home))
             (old (find "2.0.0-a.7.3-r1" entries :test #'equal
                        :key (lambda (e) (getf e :version-id))))
             (metadata (getf old :metadata))
             (alias (getf old :command-launcher-file)))
        (setf (gethash "bin_dir" metadata) (string-right-trim "/" (getf old :bin-dir)))
        (han.json:write-json-file (getf old :metadata-file) metadata)
        (setf entries (taf.core::%hub-uninstall-installed-entries home)
              old (find "2.0.0-a.7.3-r1" entries :test #'equal
                        :key (lambda (e) (getf e :version-id))))
        (dolist (ordered (list entries (reverse entries)))
          (check-equal nil (taf.core::%hub-diagnose-aliases ordered (list old)))
          (check-equal nil (taf.core::%hub-diagnose-aliases ordered ordered)))
        (let ((results (taf.core::%hub-diagnose-installations home '("taf-order-demo-v2.0.0-a.7.3-r1"))))
          (check-equal 1 (length results))
          (check-equal :verified (getf (first results) :state)))
        (%taf-hub-write-string alias
          (taf.core::%hub-install-launcher-string (getf old :command-file)
                                                 :launcher-name (getf old :command-base)
                                                 :artifact-name (getf old :artifact-name)))
        (dolist (ordered (list entries (reverse entries)))
          (let ((results (taf.core::%hub-diagnose-aliases ordered ordered)))
            (check-equal 1 (length results))
            (check-equal :unverified (getf (first results) :state))
            (check-equal '("alias-unrecognized") (%taf-hub-diagnostic-codes (first results)))))))))

(deftest test-taf-hub-stage1-alias-probe-failure-is-unknown ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((new (find "2.0.0-a.7.10-r1" (taf.core::%hub-uninstall-installed-entries home)
                        :test #'equal :key (lambda (e) (getf e :version-id))))
             (original (symbol-function 'taf.core::%hub-diagnostic-test)))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-test)
                     (lambda (flag path)
                       (when (and (equal flag "-f") (equal path (getf new :command-file)))
                         (error "Injected unselected alias candidate failure."))
                       (funcall original flag path)))
               (let* ((results (taf.core::%hub-diagnose-installations
                                home '("taf-order-demo-v2.0.0-a.7.3-r1")))
                      (command (find :command-entry results :key (lambda (r) (getf r :check-kind))))
                      (artifact (find nil results :key (lambda (r) (getf r :check-kind)))))
                 (check-equal :verified (getf artifact :state))
                 (check-equal :unknown (getf command :state))
                 (check-true (member "read-error" (%taf-hub-diagnostic-codes command) :test #'equal))))
          (setf (symbol-function 'taf.core::%hub-diagnostic-test) original))))))

(deftest test-taf-hub-stage1-unknown-schema-stops-deep-scan-and-alias ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((new (find "2.0.0-a.7.10-r1" (taf.core::%hub-uninstall-installed-entries home)
                        :test #'equal :key (lambda (e) (getf e :version-id))))
             (metadata (getf new :metadata))
             (snapshot (han.path:parent-directory-pathname (%taf-hub-diagnostic-manifest new)))
             (prime (symbol-function 'taf.core::%hub-diagnostic-prime))
             (hash-file (symbol-function 'taf.core::%project-sha256-file))
             (properties-checked nil)
             (violations nil))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-prime)
                     (lambda (mode paths)
                       (when (and paths (equal mode "properties"))
                         (setf properties-checked t))
                       (when (and (equal mode "tree")
                                  (find (taf.core::%hub-diagnostic-path-key snapshot) paths
                                        :test #'equal :key #'taf.core::%hub-diagnostic-path-key))
                         (push :tree violations)
                         (error "Unknown schema must not prefetch its snapshot."))
                       (funcall prime mode paths))
                     (symbol-function 'taf.core::%project-sha256-file)
                     (lambda (path)
                       (when (or (equal path (getf new :command-file))
                                 (equal path (getf new :command-launcher-file))
                                 (taf.core::%hub-string-prefix-p (namestring snapshot)
                                                                 (han.path:->namestring path)))
                         (push :hash violations)
                         (error "Unknown schema must not supply alias or content evidence."))
                       (funcall hash-file path)))
               (dolist (schema '("future/v99" 7 :null nil))
                 (setf (gethash "schema_version" metadata) schema)
                 (han.json:write-json-file (getf new :metadata-file) metadata)
                 (dolist (query '("taf-order-demo-v2.0.0-a.7.3-r1" "taf-order-demo-v2.0.0-a.7.10-r1"))
                   (let* ((results (taf.core::%hub-diagnose-installations home (list query)))
                          (command (find :command-entry results :key (lambda (r) (getf r :check-kind)))))
                     (check-equal :unknown (getf command :state))
                     (check-true (member "metadata-schema" (%taf-hub-diagnostic-codes command) :test #'equal))
                     (check-equal nil violations))))
               ;; The negative tree assertion is meaningful only if the probe was installed.
               (check-true properties-checked))
          (setf (symbol-function 'taf.core::%hub-diagnostic-prime) prime
                (symbol-function 'taf.core::%project-sha256-file) hash-file))
        (remhash "schema_version" metadata)
        (han.json:write-json-file (getf new :metadata-file) metadata)
        (let ((results (taf.core::%hub-diagnose-installations home '("taf-order-demo-v2.0.0-a.7.10-r1"))))
          (check-equal 1 (length results))
          (check-equal :unverified (getf (first results) :state)))))))

(deftest test-taf-hub-stage1-unsafe-snapshot-root-is-not-traversed ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.10-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (snapshot (han.path:parent-directory-pathname (%taf-hub-diagnostic-manifest entry)))
             (saved (han.path:join-path (getf entry :install-root) "saved-snapshot/"))
             (prime (symbol-function 'taf.core::%hub-diagnostic-prime))
             (fields (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields))
             (deep-calls 0))
        (rename-file snapshot saved)
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-diagnostic-prime)
                     (lambda (mode paths)
                       (when (and (equal mode "tree") paths)
                         (incf deep-calls)
                         (error "Unsafe snapshot root must not be traversed."))
                       (funcall prime mode paths))
                     (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields)
                     (lambda (&rest args)
                       (declare (ignore args)) (incf deep-calls)
                       (error "Unsafe snapshot root must not be read.")))
               (dolist (destination (list saved root))
                 (han.os:run-program
                  (list (han.os:find-executable "ln") "-s" (namestring destination)
                        (string-right-trim "/" (namestring snapshot))))
                 (unwind-protect
                      (let ((diagnosis (taf.core::%hub-diagnose-entry entry)))
                        (check-equal :unknown (getf diagnosis :state))
                        (check-true (member "unsafe-path" (%taf-hub-diagnostic-codes diagnosis) :test #'equal))
                        (check-equal 0 deep-calls))
                   (delete-file (string-right-trim "/" (namestring snapshot))))))
          (setf (symbol-function 'taf.core::%hub-diagnostic-prime) prime
                (symbol-function 'taf.core::%hub-diagnostic-snapshot-fields) fields)
          (rename-file saved snapshot))))))

(defun %taf-hub-stage3-occurrences (needle text)
  (loop with start = 0 for position = (search needle text :start2 start)
        while position count t do (setf start (+ position (length needle)))))

(defun %taf-hub-stage3-inspection (name &key (version "1-r1")
                                           (code "manifest-missing") (state :unverified)
                                           (origin "hub-index") check-kind source-status)
  (list :package-name name :version-id version :origin-kind origin
        :check-kind check-kind :source-status source-status :state state
        :issues (list (taf.core::%hub-diagnostic-issue
                       code state (format nil "/synthetic/~A/~A/evidence" name version)))))

(defun %taf-hub-stage3-repeated (count)
  (loop for i below count collect
    (%taf-hub-stage3-inspection (format nil "summary-~3,'0D" i))))

(deftest test-taf-hub-stage3-summary-211-and-300-bounded ()
  (dolist (count '(211 300))
    (let* ((results (%taf-hub-stage3-repeated count))
           (before (han.json:encode-json (taf.core::%hub-diagnostic-json-value results))))
      (dolist (language '("en" "zh"))
        (taffish.i18n:with-language (language)
          (let ((text (taf.core::%hub-diagnostic-summary-text results :user)))
            (check-true (search (taf.core::%hub-message "diagnostic.summary"
                                                      :scope "user" :packages count
                                                      :versions count :issues count) text))
            (check-equal 1 (%taf-hub-stage3-occurrences "manifest-missing" text))
            (check-equal 3 (%taf-hub-stage3-occurrences "summary-" text))
            (check-true (search "summary-000" text))
            (check-false (search "summary-003" text))
            (check-true (<= (count #\Newline text) 8))
            (check-equal 1 (%taf-hub-stage3-occurrences "--repair" text))
            (check-true (search "--user --verbose" text))
            (check-true (search "--json" text))
            (check-false (search "--force" text)))))
      (check-equal before (han.json:encode-json (taf.core::%hub-diagnostic-json-value results))))))

(deftest test-taf-hub-stage3-summary-mixed-counts-and-policies ()
  (let* ((broken (%taf-hub-stage3-inspection "multi" :state :invalid :code "wrapper-digest"))
         (results (list broken
                        (%taf-hub-stage3-inspection "multi" :version "2-r1")
                        (%taf-hub-stage3-inspection "multi" :version "2-r1"
                                                   :code "alias-missing" :check-kind :command-entry)
                        (%taf-hub-stage3-inspection "unsafe" :code "unsafe-path" :state :unknown)
                        (%taf-hub-stage3-inspection "future" :code "metadata-schema" :state :unknown)
                        (%taf-hub-stage3-inspection "private" :origin "local-project")
                        (%taf-hub-stage3-inspection "conflict" :source-status :mismatch)
                        (list :package-name "healthy" :version-id "1-r1" :state :verified))))
    (push (taf.core::%hub-diagnostic-issue "manifest-missing" :unverified "/second/evidence")
          (getf broken :issues))
    (dolist (language '("en" "zh"))
      (taffish.i18n:with-language (language)
        (let ((text (taf.core::%hub-diagnostic-summary-text results :system)))
          (check-true (search (taf.core::%hub-message "diagnostic.summary" :scope "system"
                                                    :packages 5 :versions 6 :issues 8) text))
          (check-true (search (taf.core::%hub-message "diagnostic.group" :count 2
                                                    :examples "multi 1-r1, multi 2-r1") text))
          (dolist (code '("wrapper-digest" "alias-missing" "unsafe-path" "metadata-schema"))
            (check-equal 1 (%taf-hub-stage3-occurrences code text)))
          (check-equal 3 (%taf-hub-stage3-occurrences "manifest-missing" text))
          (dolist (policy '("access" "schema" "alias" "private" "inspect" "repair"))
            (check-equal 1 (%taf-hub-stage3-occurrences
                            (taf.core::%hub-message (concatenate 'string "diagnostic.summary-remedy." policy)
                                                   :scope "system") text)))
          (check-false (search "healthy" text))
          (check-false (search "--force" text)))))
    (dolist (result (nthcdr 3 results))
      (unless (eq (getf result :state) :verified)
        (let ((text (taf.core::%hub-diagnostic-summary-text (list result) :user)))
          (check-false (search "--repair" text)))))))

(deftest test-taf-hub-stage3-brief-sanitizes-and-bounds-examples ()
  (check-equal "short label" (taf.core::%hub-diagnostic-brief "short label"))
  (let* ((name (format nil "mixed中文~%~C~C~A~A" #\Tab (code-char 127)
                       (make-string 120 :initial-element #\x) "hidden-tail"))
         (brief (taf.core::%hub-diagnostic-brief name))
         (results (list (%taf-hub-stage3-inspection name))))
    (check-true (<= (length brief) 99))
    (check-false (find-if (lambda (c) (or (< (char-code c) 32) (= (char-code c) 127))) brief))
    (check-false (search "hidden-tail" brief))
    (dolist (language '("en" "zh"))
      (taffish.i18n:with-language (language)
        (let ((text (taf.core::%hub-diagnostic-summary-text results :user)))
          (check-true (<= (count #\Newline text) 8))
          (check-true (search brief text))
          (check-false (search "hidden-tail" text)))))
    (check-true (search "hidden-tail"
                        (han.json:encode-json (taf.core::%hub-diagnostic-json-value results))))))

(deftest test-taf-hub-stage3-doctor-summary-keeps-detail-and-json-complete ()
  (let* ((inspections (%taf-hub-stage3-repeated 300))
         (diagnostics (mapcar (lambda (r) (taf.core::%doctor-inspection-diagnostic r :user :hub-installation))
                              inspections))
         (result (list :check :hub :scope :user :status :warning :diagnostic-status :warning
                       :exit-code 0 :diagnostics diagnostics))
         (baseline (han.json:encode-json (taf.core::%doctor-result-json result))))
    (dolist (language '("en" "zh"))
      (taffish.i18n:with-language (language)
        (let* ((text (with-output-to-string (*standard-output*)
                       (taf.core::%doctor-print-diagnostics diagnostics :warning nil)))
               (detail (with-output-to-string (*standard-output*)
                         (taf.core::%doctor-print-diagnostics diagnostics :warning t)))
               (json (han.json:parse-json (han.json:encode-json (taf.core::%doctor-result-json result))))
               (items (han.json:get-json json "diagnostics")))
          (check-equal 1 (%taf-hub-stage3-occurrences "manifest-missing" text))
          (check-true (<= (count #\Newline text) 12))
          (check-false (search "summary-299" text))
          (check-equal 300 (length items))
          (check-equal "taffish.doctor/v1" (han.json:get-json json "schema_version"))
          (loop for inspection in inspections for item across items do
            (let* ((expected (first (getf inspection :issues)))
                   (actual (han.json:get-json item "inspection"))
                   (issue (aref (han.json:get-json actual "issues") 0)))
              (check-true (search (getf inspection :package-name) detail))
              (check-true (search (getf expected :path) detail))
              (check-equal (getf inspection :package-name) (han.json:get-json actual "package_name"))
              (check-equal "1-r1" (han.json:get-json actual "version_id"))
              (check-equal "manifest-missing" (han.json:get-json issue "code"))
              (check-equal (getf expected :path) (han.json:get-json issue "path"))))
          (check-equal baseline (han.json:encode-json (taf.core::%doctor-result-json result))))))))

(deftest test-taf-hub-stage3-maintenance-skips-are-not-repeated ()
  (let* ((inspections (%taf-hub-stage3-repeated 300))
         (items (loop for r in inspections collect
                  (list :package-name (getf r :package-name) :status :current :action :skip
                        :validation r :installed-version-id "1-r1" :latest-version-id "1-r1")))
         (changed (list :package-name "action-needed" :status :outdated :action :install-latest
                        :installed-version-id "1-r1" :latest-version-id "2-r1")))
    (push changed items)
    (let ((result (list :operation :upgrade :scope :user :home "/synthetic/" :kind :all
                        :dry-run-p t :items items :summary (taf.core::%hub-upgrade-summary items))))
      (dolist (language '("en" "zh"))
        (taffish.i18n:with-language (language)
          (let* ((text (with-output-to-string (*standard-output*)
                         (taf.core::%hub-upgrade-print-result result)))
                 (json (taf.core::%hub-upgrade-result-json result)))
            (check-equal 1 (%taf-hub-stage3-occurrences "action-needed" text))
            (check-equal 1 (%taf-hub-stage3-occurrences "manifest-missing" text))
            (check-equal 3 (%taf-hub-stage3-occurrences "summary-" text))
            (check-false (search "summary-299" text))
            (check-true (<= (count #\Newline text) 45))
            (check-equal 301 (length (han.json:get-json json "items")))
            (check-equal 300 (han.json:get-json (han.json:get-json json "summary") "skip"))
            (loop for item across (han.json:get-json json "items")
                  unless (equal "action-needed" (han.json:get-json item "package_name")) do
                    (check-equal "unverified" (han.json:get-json (han.json:get-json item "validation") "state")))))))
    (let* ((item (list :package-name "prune-group" :status :current :action :skip
                       :validation (first inspections) :validations inspections))
           (text (with-output-to-string (*standard-output*)
                   (taf.core::%hub-upgrade-print-result
                    (list :operation :prune :scope :system :items (list item)
                          :summary (taf.core::%hub-upgrade-summary (list item)))))))
      (check-equal 1 (%taf-hub-stage3-occurrences "manifest-missing" text))
      (check-true (search "300" text))
      (check-false (search "301" text)))))

(deftest test-taf-hub-stage3-blocking-summary-precedes-any-write ()
  (with-taf-hub-temp-dir (root)
    (multiple-value-bind (home index package) (%taf-hub-order-fixture root)
      (declare (ignore index package))
      (%taf-hub-order-install home "2.0.0-a.7.3-r1")
      (let* ((entry (first (taf.core::%hub-uninstall-installed-entries home)))
             (wrapper (getf entry :command-file))
             (metadata-file (getf entry :metadata-file))
             (metadata (getf entry :metadata))
             (original (symbol-function 'taf.core::%hub-upgrade-install-item))
             (writes 0))
        (unwind-protect
             (progn
               (setf (symbol-function 'taf.core::%hub-upgrade-install-item)
                     (lambda (&rest args) (declare (ignore args)) (incf writes)
                       (error "Write phase must not start.")))
               (dolist (problem '("wrapper-digest" "metadata-schema"))
                 (if (equal problem "wrapper-digest")
                     (%taf-hub-write-string wrapper "corrupt")
                     (progn (setf (gethash "schema_version" metadata) "future/v99")
                            (han.json:write-json-file metadata-file metadata)))
                 (let ((wrapper-hash (taf.core::%project-sha256-file wrapper))
                       (metadata-hash (taf.core::%project-sha256-file metadata-file)))
                   (dolist (language '("en" "zh"))
                     (taffish.i18n:with-language (language)
                       (dolist (function (list #'taf.core:hub-install-all #'taf.core:hub-upgrade))
                         (let ((message (%taf-hub-error-string
                                         (lambda () (funcall function :user-home home :system-home home
                                                                     :yes-p t :verbose nil)))))
                           (check-true message)
                           (check-true (search problem message))
                           (check-true (search "--user --verbose" message))
                           (check-false (search "--force" message))
                           (when (equal problem "metadata-schema")
                             (check-false (search "--repair" message)))))))
                   (check-equal 0 writes)
                   (check-equal '("2.0.0-a.7.3-r1") (%taf-hub-order-versions home))
                   (check-equal wrapper-hash (taf.core::%project-sha256-file wrapper))
                   (check-equal metadata-hash (taf.core::%project-sha256-file metadata-file)))))
          (setf (symbol-function 'taf.core::%hub-upgrade-install-item) original))))))

(deftest test-taf-hub-stage3-clone-advice-is-command-local ()
  (let ((original (symbol-function 'taf.core::%hub-install-run-program))
        (calls nil) (code 0))
    (unwind-protect
         (progn
           (setf (symbol-function 'taf.core::%hub-install-run-program)
                 (lambda (program args &rest options)
                   (declare (ignore program options)) (push args calls)
                   (values "" (if (zerop code) "" "clone-failure-sentinel") code)))
           (taf.core::%hub-install-run-git-clone "https://example.invalid/repo" "v1"
                                               "/synthetic/unused" :verbose nil)
           (setf code 97)
           (let ((message (%taf-hub-error-string
                           (lambda () (taf.core::%hub-install-run-git-clone
                                       "https://example.invalid/repo" "v1" "/synthetic/unused"
                                       :verbose nil)))))
             (check-true (search "clone-failure-sentinel" message)))
           (check-equal 2 (length calls))
           (dolist (args calls)
             (check-equal '("-c" "advice.detachedHead=false" "clone") (subseq args 0 3))
             (check-false (member "config" args :test #'equal))))
      (setf (symbol-function 'taf.core::%hub-install-run-program) original))))

(defun %repair-batch-index (home fixtures latest)
  (let* ((records (apply #'han.json:json-object
                         (loop for fixture in fixtures
                               collect (cons (getf fixture :version-id) (getf fixture :record)))))
         (package (han.json:json-object (cons "name" "repair-demo") (cons "latest" latest)
                                        (cons "versions" records)))
         (index (han.json:json-object
                 (cons "schema_version" "taffish.index/v1")
                 (cons "packages" (han.json:json-object (cons "repair-demo" package)))
                 (cons "commands" (han.json:make-json-object)))))
    (%taf-hub-write-string (taf.core::%hub-index-file home) (han.json:encode-json index))))

(deftest test-taf-hub-repair-batch-latest-preview-is-read-only ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home)))
      (delete-file (getf old :manifest))
      (delete-file (getf new :manifest))
      (%repair-batch-index home (list old new) "2.0.0-r1")
      (let* ((before (taf.core::%build-snapshot-digest home))
             (result (taf.core:hub-install-all :repair-p t :user-home home :verbose nil))
             (items (getf result :items)))
        (check-equal "taffish.repair-plan/v1" (getf result :schema-version))
        (check-true (getf result :dry-run-p))
        (check-equal 1 (length items))
        (check-equal "2.0.0-r1" (getf (aref items 0) :version-id))
        (check-equal :repair (getf (aref items 0) :action))
        (check-equal before (taf.core::%build-snapshot-digest home))
        (let ((explicit (taf.core:hub-install-many :targets (list (list :query "repair-demo" :version-id "1.0.0-r1")
                                                                   (list :query "repair-demo" :version-id "1.0.0-r1"))
                                                   :repair-p t :dry-run-p t :user-home home :verbose nil)))
          (check-equal 1 (length (getf explicit :items)))
          (check-equal "1.0.0-r1" (getf (aref (getf explicit :items) 0) :version-id)))
        (check-equal before (taf.core::%build-snapshot-digest home))))))

(deftest test-taf-hub-repair-installed-selects-historical-and-latest ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home)))
      (delete-file (getf old :manifest))
      (%repair-batch-index home (list old new) "2.0.0-r1")
      (let* ((before (taf.core::%build-snapshot-digest home))
             (latest (taf.core:hub-install-all :repair-p t :user-home home :verbose nil))
             (result (taf.core:hub-install-all :repair-p t :all-installed-p t :user-home home :verbose nil)))
        (check-equal :index-latest (getf latest :selection))
        (check-equal 0 (getf (getf latest :summary) :repair))
        (check-equal :installed-all-versions (getf result :selection))
        (check-true (getf result :dry-run-p))
        (check-equal 2 (getf (getf result :summary) :total))
        (check-equal 1 (getf (getf result :summary) :repair))
        (check-equal 1 (getf (getf result :summary) :skip))
        (check-equal before (taf.core::%build-snapshot-digest home))))))

(deftest test-taf-hub-repair-installed-preserves-unindexed-and-broken-records ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home)))
      (%repair-batch-index home (list new) "2.0.0-r1")
      (delete-file (getf new :metadata-file))
      (let* ((before (taf.core::%build-snapshot-digest home))
             (result (taf.core:hub-install-all :repair-p t :all-installed-p t :user-home home :verbose nil)))
        (check-equal 2 (getf (getf result :summary) :blocked))
        (check-equal '("1.0.0-r1" "2.0.0-r1")
                     (map 'list (lambda (p) (getf p :version-id)) (getf result :items)))
        (loop for item across (getf result :items) do
          (check-false (eq :verified (getf (getf item :validation) :state))))
        (check-true (%taf-hub-signal-error-p
                     (lambda () (taf.core:hub-install-all :repair-p t :all-installed-p t
                                                          :yes-p t :user-home home :verbose nil))))
        (check-equal before (taf.core::%build-snapshot-digest home))))))

(deftest test-taf-hub-repair-installed-kind-filter-keeps-unknown ()
  (with-taf-hub-temp-dir (root)
    (let* ((fixture (%repair-test-fixture root)) (home (getf fixture :home)))
      (%repair-batch-index home (list fixture) "1.0.0-r1")
      (check-equal 0 (getf (getf (taf.core:hub-install-all :repair-p t :all-installed-p t
                                                        :kind :flow :user-home home :verbose nil) :summary) :total))
      (%repair-test-metadata fixture "kind" nil t)
      (let ((result (taf.core:hub-install-all :repair-p t :all-installed-p t
                                             :kind :flow :user-home home :verbose nil)))
        (check-equal 1 (getf (getf result :summary) :blocked))
        (check-equal "kind-unknown" (getf (aref (getf result :items) 0) :reason))))))

(deftest test-taf-hub-repair-installed-output-scope-and-command ()
  (with-taf-hub-temp-dir (root)
    (let* ((fixture (%repair-test-fixture root)) (home (getf fixture :home)))
      (%repair-batch-index home (list fixture) "1.0.0-r1")
      (dolist (language '("en" "zh"))
        (taffish.i18n:with-language (language)
          (let ((text (with-output-to-string (*standard-output*)
                        (taf.core:hub-install-all :repair-p t :all-installed-p t
                                                 :kind :tool :user-home home))))
            (check-true (search "--all-installed --repair --user --kind tool --yes" text))
            (check-false (search "--all --repair --yes" text)))
          (let ((text (with-output-to-string (*standard-output*)
                        (taf.core:system-doctor :check :hub :user-home home))))
            (check-true (search (if (equal language "en") "Enumerated 1 apps, 1" "已枚举 1 个应用、1") text))))))))

(deftest test-taf-hub-repair-installed-requires-repair ()
  (check-true (%taf-hub-signal-error-p
               (lambda () (taf.core:hub-install-all :all-installed-p t :verbose nil)))))

(deftest test-taf-hub-repair-installed-batch-canonical-prefetch ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home))
           (probe (symbol-function 'taf.core::%hub-diagnostic-probe))
           (plan (symbol-function 'taf.core::%hub-repair-plan-one))
           (checking nil) (calls 0) (misses 0))
      (%repair-batch-index home (list old new) "2.0.0-r1")
      (unwind-protect
           (progn
             (setf (symbol-function 'taf.core::%hub-diagnostic-probe)
                   (lambda (mode paths)
                     (when checking (incf misses))
                     (funcall probe mode paths))
                   (symbol-function 'taf.core::%hub-repair-plan-one)
                   (lambda (&rest args)
                     (incf calls)
                     (setf checking t)
                     (unwind-protect (apply plan args) (setf checking nil))))
             (let ((result (taf.core:hub-install-all :repair-p t :all-installed-p t
                                                    :user-home home :verbose nil)))
               (check-equal 2 (getf (getf result :summary) :skip))
               (check-equal 2 calls)
               (check-equal 0 misses)))
        (setf (symbol-function 'taf.core::%hub-diagnostic-probe) probe
              (symbol-function 'taf.core::%hub-repair-plan-one) plan)))))

(deftest test-taf-hub-repair-batch-absent-not-malformed ()
  (with-taf-hub-temp-dir (root)
    (let* ((fixture (%repair-test-fixture root)) (home (getf fixture :home)))
      (%repair-batch-index home (list fixture) "1.0.0-r1")
      (delete-file (getf fixture :metadata-file))
      (let* ((result (taf.core:hub-install-all :repair-p t :user-home home :verbose nil))
             (item (aref (getf result :items) 0)))
        (check-equal 0 (getf (getf result :summary) :skipped-not-installed))
        (check-equal :blocked (getf item :action))
        (check-equal "metadata-invalid" (getf item :reason)))
      (taf.core::%hub-install-delete-dir-if-exists (getf fixture :install-root))
      (let* ((result (taf.core:hub-install-all :repair-p t :user-home home :verbose nil))
             (json (taf.core::%hub-diagnostic-json-value result)))
        (check-equal 1 (getf (getf result :summary) :skipped-not-installed))
        (check-equal 0 (length (getf result :items)))
        (check-true (vectorp (han.json:get-json json "items")))
        (check-equal 0 (length (han.json:get-json json "items")))))))

(deftest test-taf-hub-repair-batch-blocked-before-writes ()
  (with-taf-hub-temp-dir (root)
    (let* ((fixture (%repair-test-fixture root)) (home (getf fixture :home)))
      (%repair-batch-index home (list fixture) "1.0.0-r1")
      (%repair-test-metadata fixture "schema_version" "taffish.install/v99")
      (let ((before (taf.core::%build-snapshot-digest home)))
        (check-true (%taf-hub-signal-error-p
                     (lambda () (taf.core:hub-install-all :repair-p t :yes-p t :user-home home :verbose nil))))
        (check-equal before (taf.core::%build-snapshot-digest home))
        (dolist (language '("en" "zh"))
          (let ((text (taffish.i18n:with-language (language)
                        (with-output-to-string (*standard-output*)
                          (taf.core:hub-install-all :repair-p t :user-home home)))))
            (check-true (search "unknown-schema" text))
            (check-true (search "repair-demo" text))
            (check-false (search "taf.hub.repair.reason" text))))))))

(deftest test-taf-hub-mutation-entry-points-use-cooperating-locks ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home))
           (before (taf.core::%build-snapshot-digest home))
           (lock (symbol-function 'taf.core::%hub-call-with-write-locks))
           (calls nil))
      (declare (ignore new))
      (unwind-protect
           (progn
             (setf (symbol-function 'taf.core::%hub-call-with-write-locks)
                   (lambda (actual-home bins thunk)
                     (declare (ignore thunk))
                     (push (list actual-home bins) calls)
                     :locked))
             (check-equal :locked
               (taf.core:hub-install :query "repair-demo" :user-home home :force-p t
                                     :record (getf old :record) :verbose nil))
             (check-equal :locked
               (taf.core:hub-uninstall :query "repair-demo" :version-id "1.0.0-r1"
                                       :user-home home :verbose nil))
             (let ((entries (taf.core::%hub-uninstall-installed-entries home)))
               (check-equal :locked
                 (taf.core::%hub-prune-apply-item-with-home
                  (list :keep-entry (find "2.0.0-r1" entries :test #'equal :key (lambda (e) (getf e :version-id)))
                        :remove-entries (remove "2.0.0-r1" entries :test #'equal :key (lambda (e) (getf e :version-id))))
                  home nil)))
             (check-equal 3 (length calls))
             (check-equal before (taf.core::%build-snapshot-digest home))
             (taf.core:hub-install :query "repair-demo" :user-home home :force-p t :dry-run-p t
                                  :record (getf old :record) :verbose nil)
             (taf.core:hub-uninstall :query "repair-demo" :version-id "1.0.0-r1"
                                    :user-home home :dry-run-p t :verbose nil)
             (taf.core:hub-uninstall :query "absent" :user-home home :force-p t :verbose nil)
             (check-equal 3 (length calls))
             (check-equal before (taf.core::%build-snapshot-digest home)))
        (setf (symbol-function 'taf.core::%hub-call-with-write-locks) lock)))))

(deftest test-taf-hub-repair-batch-inaccessible-is-not-absent ()
  (with-taf-hub-temp-dir (root)
    (let* ((fixture (%repair-test-fixture root)) (home (getf fixture :home))
           (version (taf.core::%hub-diagnostic-path-key (getf fixture :install-root)))
           (parent (taf.core::%hub-diagnostic-path-key
                    (han.path:parent-directory-pathname (getf fixture :install-root))))
           (enumerate (symbol-function 'taf.core::%hub-uninstall-installed-entries))
           (probe (symbol-function 'taf.core::%hub-diagnostic-test))
           (issue (symbol-function 'taf.core::%hub-repair-path-issue)))
      (%repair-batch-index home (list fixture) "1.0.0-r1")
      (unwind-protect
           (progn
             (setf (symbol-function 'taf.core::%hub-uninstall-installed-entries)
                   (lambda (path) (declare (ignore path)) nil)
                   (symbol-function 'taf.core::%hub-diagnostic-test)
                   (lambda (flag path)
                     (if (and (member flag '("-e" "-L") :test #'equal)
                              (equal version (taf.core::%hub-diagnostic-path-key path)))
                         nil (funcall probe flag path)))
                   (symbol-function 'taf.core::%hub-repair-path-issue)
                   (lambda (path directory-p)
                     (if (equal parent (taf.core::%hub-diagnostic-path-key path))
                         "read-error" (funcall issue path directory-p))))
             (let ((result (taf.core:hub-install-all :repair-p t :user-home home :verbose nil)))
               (check-equal 0 (getf (getf result :summary) :skipped-not-installed))
               (check-equal 1 (getf (getf result :summary) :blocked))
               (check-equal "read-error" (getf (aref (getf result :items) 0) :reason)))
             (check-true (%taf-hub-signal-error-p
                          (lambda () (taf.core:hub-install-all :repair-p t :yes-p t :user-home home :verbose nil)))))
        (setf (symbol-function 'taf.core::%hub-uninstall-installed-entries) enumerate
              (symbol-function 'taf.core::%hub-diagnostic-test) probe
              (symbol-function 'taf.core::%hub-repair-path-issue) issue)))))

(deftest test-taf-hub-repair-batch-projection-keeps-alias-evidence ()
  (let* ((artifact (list :state :verified :issues nil))
         (alias (list :state :unknown :issues (list (list :code "read-error" :state :unknown :path "/fixture/bin/taf-demo"))))
         (result (taf.core::%hub-repair-public-result
                  (list :scope :user :home "/fixture/" :dry-run-p t :skipped-not-installed 0
                        :plans (list (list :query "demo" :action :blocked :blocked-p t
                                           :reason "read-error" :validation artifact :validations (list artifact alias))))))
         (json (taf.core::%hub-diagnostic-json-value result))
         (item (aref (han.json:get-json json "items") 0))
         (evidence (aref (han.json:get-json item "validations") 1)))
    (check-equal "verified" (han.json:get-json (han.json:get-json item "validation") "state"))
    (check-equal "unknown" (han.json:get-json evidence "state"))
    (check-equal "/fixture/bin/taf-demo" (han.json:get-json (aref (han.json:get-json evidence "issues") 0) "path"))))

(deftest test-taf-hub-repair-batch-prefetches-only-selected-identities ()
  (with-taf-hub-temp-dir (root)
    (let* ((old (%repair-test-fixture root))
           (new (%repair-test-fixture root :home (getf old :home) :version "2.0.0"))
           (home (getf old :home))
           (original (symbol-function 'taf.core::%hub-call-with-diagnostic-batch))
           (prefetched nil))
      (%repair-batch-index home (list old new) "2.0.0-r1")
      (unwind-protect
           (progn
             (setf (symbol-function 'taf.core::%hub-call-with-diagnostic-batch)
                   (lambda (entries thunk)
                     (setf prefetched (mapcar (lambda (entry) (getf entry :version-id)) entries))
                     (funcall original entries thunk)))
             (taf.core:hub-install :repair-p t :query "repair-demo" :version-id "1.0.0-r1"
                                  :user-home home :dry-run-p t :verbose nil)
             (check-equal '("1.0.0-r1") prefetched)
             (taf.core:hub-install-all :repair-p t :user-home home :verbose nil)
             (check-equal '("2.0.0-r1") prefetched))
        (setf (symbol-function 'taf.core::%hub-call-with-diagnostic-batch) original)))))

(deftest test-taf-hub-update-progress-precedes-read-and-stays-silent-for-api ()
  (with-taf-hub-temp-dir (root)
    (let ((original (symbol-function 'taf.core::%hub-read-index-source))
          (calls 0))
      (unwind-protect
           (dolist (verbose '(t nil))
             (let* ((out (make-string-output-stream))
                    (*error-output* out)
                    (taf.core::*operation-display* nil))
               (setf (symbol-function 'taf.core::%hub-read-index-source)
                     (lambda (url)
                       (check-equal "https://example.invalid/index.json" url)
                       (incf calls)
                       (let ((before (get-output-stream-string out)))
                         (check-equal (not (null verbose)) (not (null (search "Downloading index" before)))))
                       "{\"schema_version\":\"taffish.index/v1\",\"packages\":{},\"commands\":{}}"))
               (let ((*standard-output* (make-broadcast-stream)))
                 (taffish.i18n:with-language ("en")
                   (let ((result (taf.core:hub-update :index-url "https://example.invalid/index.json"
                                                    :user-home root :verbose verbose)))
                     (check-true (getf result :current-file)))))))
        (setf (symbol-function 'taf.core::%hub-read-index-source) original))
      (check-equal 2 calls))))
