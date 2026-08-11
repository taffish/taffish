(in-package :taf.core)

;;;; ============================================================
;;;; project / publish.lisp
;;;; ============================================================

(defparameter *publish-operation-adapter* nil)
(defparameter *publish-journal-user-home* nil)
(defparameter *publish-query-attempts* 3)
(defparameter *publish-query-delay-seconds* 0.05)

(define-condition publish-state-error (error)
  ((kind
    :initarg :kind
    :reader %publish-error-kind)
   (stage
    :initarg :stage
    :reader %publish-error-stage)
   (message
    :initarg :message
    :reader %publish-error-message)
   (evidence
    :initarg :evidence
    :initform nil
    :reader %publish-error-evidence))
  (:report
   (lambda (condition stream)
     (format stream "[publish:~(~A~)] ~A~@[~%~A~]"
             (%publish-error-kind condition)
             (%publish-error-message condition)
             (%publish-error-evidence condition)))))

(defun %publish-fail (kind stage format-control &rest format-arguments)
  (error 'publish-state-error
         :kind kind
         :stage stage
         :message (apply #'format nil format-control format-arguments)))

(defun %publish-state (state evidence &rest fields)
  (append (list :state state :evidence evidence) fields))

(defparameter *publish-sha256-round-constants*
  #(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5
    #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3
    #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc
    #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7
    #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13
    #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3
    #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5
    #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208
    #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

(defun %publish-u32 (value)
  (logand value #xffffffff))

(defun %publish-rotr32 (value count)
  (%publish-u32
   (logior (ash value (- count))
           (ash value (- 32 count)))))

(defun %publish-sha256-small-sigma-0 (value)
  (logxor (%publish-rotr32 value 7)
          (%publish-rotr32 value 18)
          (ash value -3)))

(defun %publish-sha256-small-sigma-1 (value)
  (logxor (%publish-rotr32 value 17)
          (%publish-rotr32 value 19)
          (ash value -10)))

(defun %publish-sha256-big-sigma-0 (value)
  (logxor (%publish-rotr32 value 2)
          (%publish-rotr32 value 13)
          (%publish-rotr32 value 22)))

(defun %publish-sha256-big-sigma-1 (value)
  (logxor (%publish-rotr32 value 6)
          (%publish-rotr32 value 11)
          (%publish-rotr32 value 25)))

(defun %publish-sha256-choice (x y z)
  (logxor (logand x y)
          (logand (lognot x) z)))

(defun %publish-sha256-majority (x y z)
  (logxor (logand x y)
          (logand x z)
          (logand y z)))

(defun %publish-string-utf8-bytes (string)
  (let ((bytes nil))
    (labels ((emit (&rest values)
               (dolist (value values)
                 (push value bytes))))
      (loop for char across string
            for code = (char-code char)
            do
               (cond
                 ((<= code #x7f)
                  (emit code))
                 ((<= code #x7ff)
                  (emit (logior #xc0 (ash code -6))
                        (logior #x80 (logand code #x3f))))
                 ((<= code #xffff)
                  (emit (logior #xe0 (ash code -12))
                        (logior #x80 (logand (ash code -6) #x3f))
                        (logior #x80 (logand code #x3f))))
                 ((<= code #x10ffff)
                  (emit (logior #xf0 (ash code -18))
                        (logior #x80 (logand (ash code -12) #x3f))
                        (logior #x80 (logand (ash code -6) #x3f))
                        (logior #x80 (logand code #x3f))))
                 (t
                  (error "[publish] can't encode character as UTF-8: ~S" char)))))
    (nreverse bytes)))

(defun %publish-sha256-padded-bytes (string)
  (let* ((bytes (%publish-string-utf8-bytes string))
         (bit-length (* 8 (length bytes)))
         (padded (append bytes (list #x80))))
    (loop until (= (mod (length padded) 64) 56) do
      (setf padded (append padded (list 0))))
    (loop for shift from 56 downto 0 by 8 do
      (setf padded
            (append padded
                    (list (logand #xff (ash bit-length (- shift)))))))
    padded))

(defun %publish-sha256-word (bytes offset)
  (%publish-u32
   (logior (ash (nth offset bytes) 24)
           (ash (nth (+ offset 1) bytes) 16)
           (ash (nth (+ offset 2) bytes) 8)
           (nth (+ offset 3) bytes))))

(defun %publish-sha256 (string)
  (let ((h0 #x6a09e667)
        (h1 #xbb67ae85)
        (h2 #x3c6ef372)
        (h3 #xa54ff53a)
        (h4 #x510e527f)
        (h5 #x9b05688c)
        (h6 #x1f83d9ab)
        (h7 #x5be0cd19)
        (bytes (%publish-sha256-padded-bytes string)))
    (loop for chunk from 0 below (length bytes) by 64 do
      (let ((words (make-array 64 :initial-element 0)))
        (dotimes (index 16)
          (setf (aref words index)
                (%publish-sha256-word bytes (+ chunk (* index 4)))))
        (loop for index from 16 below 64 do
          (setf (aref words index)
                (%publish-u32
                 (+ (%publish-sha256-small-sigma-1
                     (aref words (- index 2)))
                    (aref words (- index 7))
                    (%publish-sha256-small-sigma-0
                     (aref words (- index 15)))
                    (aref words (- index 16))))))
        (let ((a h0) (b h1) (c h2) (d h3)
              (e h4) (f h5) (g h6) (h h7))
          (dotimes (index 64)
            (let* ((temp1
                     (%publish-u32
                      (+ h
                         (%publish-sha256-big-sigma-1 e)
                         (%publish-sha256-choice e f g)
                         (aref *publish-sha256-round-constants* index)
                         (aref words index))))
                   (temp2
                     (%publish-u32
                      (+ (%publish-sha256-big-sigma-0 a)
                         (%publish-sha256-majority a b c)))))
              (setf h g
                    g f
                    f e
                    e (%publish-u32 (+ d temp1))
                    d c
                    c b
                    b a
                    a (%publish-u32 (+ temp1 temp2)))))
          (setf h0 (%publish-u32 (+ h0 a))
                h1 (%publish-u32 (+ h1 b))
                h2 (%publish-u32 (+ h2 c))
                h3 (%publish-u32 (+ h3 d))
                h4 (%publish-u32 (+ h4 e))
                h5 (%publish-u32 (+ h5 f))
                h6 (%publish-u32 (+ h6 g))
                h7 (%publish-u32 (+ h7 h))))))
    (string-downcase
     (format nil "~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X~8,'0X"
             h0 h1 h2 h3 h4 h5 h6 h7))))

(defun %publish-timestamp ()
  (multiple-value-bind (second minute hour date month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month date hour minute second)))

(defun %publish-path-safe-component (string)
  (with-output-to-string (out)
    (loop for char across string do
      (write-char (if (or (alphanumericp char)
                          (member char '(#\- #\_ #\.) :test #'char=))
                      char
                      #\-)
                  out))))

(defun %publish-journal-file (repository-url tag)
  (let ((slug (%publish-github-slug repository-url)))
    (unless slug
      (error "[publish] can't derive journal key from repository URL: ~A"
             repository-url))
    (han.path:join-path
     (%taffish-user-home *publish-journal-user-home*)
     "history"
     "publish"
     (format nil "~A--~A"
             (%publish-path-safe-component (first (%publish-split-string slug #\/)))
             (%publish-path-safe-component (second (%publish-split-string slug #\/))))
     (format nil "~A.json" (%publish-path-safe-component tag)))))

(defun %publish-temp-journal-file (path)
  (pathname
   (format nil "~A.tmp-~36R-~36R"
           (han.path:->namestring path)
           (get-universal-time)
           (get-internal-real-time))))

(defun %publish-write-json-atomically (path object)
  (let ((temp (%publish-temp-journal-file path)))
    (ensure-directories-exist path)
    (unwind-protect
         (progn
           (han.json:write-json-file temp object :indent 2)
           (handler-case
               (rename-file temp path)
             (file-error ()
               (when (han.path:file-exists-p path)
                 (delete-file path))
               (rename-file temp path))))
      (%publish-delete-file-safely temp)))
  path)

(defun %publish-read-journal (path)
  (if (han.path:file-exists-p path)
      (handler-case
          (values (han.json:read-json-file path) nil)
        (error (condition)
          (values nil condition)))
      (values nil nil)))

(defun %publish-journal-value (journal key &optional default)
  (if journal
      (han.json:get-json journal key default)
      default))

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

(defun %publish-network-output-p (out err)
  (some (lambda (needle)
          (%publish-output-contains-p needle out err))
        '("connection reset"
          "connection timed out"
          "operation timed out"
          "could not resolve host"
          "failed to connect"
          "network is unreachable"
          "temporary failure"
          "tls connection"
          "http 502"
          "http 503"
          "http 504")))

(defun %publish-release-not-found-output-p (out err)
  (or (%publish-output-contains-p "release not found" out err)
      (%publish-output-contains-p "not found" out err)))

(defun %publish-query-run-program
    (program args &key (noninteractive t) prompt)
  (let ((last-out nil)
        (last-err nil)
        (last-code nil))
    (loop for attempt from 1 to *publish-query-attempts* do
      (multiple-value-setq (last-out last-err last-code)
        (%publish-run-program program args
                              :noninteractive noninteractive
                              :prompt prompt))
      (when (or (and (integerp last-code) (= last-code 0))
                (not (%publish-network-output-p last-out last-err))
                (= attempt *publish-query-attempts*))
        (return))
      (sleep *publish-query-delay-seconds*))
    (values last-out last-err last-code)))

(defun %publish-ls-remote-ref-from-line (line)
  (let ((tab (position #\Tab line)))
    (when tab
      (cons (%publish-trim-output (subseq line 0 tab))
            (%publish-trim-output (subseq line (1+ tab)))))))

(defun %publish-ls-remote-refs (repository-url args prompt-p)
  (multiple-value-bind (out err code)
      (%publish-query-run-program
       (%publish-git-program)
       (append (list "ls-remote" (first args) repository-url)
               (rest args))
       :noninteractive (not prompt-p)
       :prompt prompt-p)
    (cond
      ((and (integerp code) (= code 0))
       (values
        (remove nil
                (mapcar #'%publish-ls-remote-ref-from-line
                        (%publish-string-lines out)))
        :ok
        nil))
      ((%publish-repository-not-found-output-p out err)
       (values nil :missing (format nil "~A~A" out err)))
      (t
       (values nil :unavailable (format nil "~A~A" out err))))))

(defun %publish-find-ref (ref refs)
  (find ref refs :test #'string= :key #'cdr))

(defun %publish-remote-tag-commit-from-refs (refs tag)
  (let* ((base (format nil "refs/tags/~A" tag))
         (peeled (format nil "~A^{}" base))
         (peeled-entry (%publish-find-ref peeled refs))
         (base-entry (%publish-find-ref base refs)))
    (or (and peeled-entry (car peeled-entry))
        (and base-entry (car base-entry)))))

(defun %publish-remote-tag-commit (repository-url tag prompt-p)
  (multiple-value-bind (refs state evidence)
      (%publish-ls-remote-refs
       repository-url
       (list "--tags"
             (format nil "refs/tags/~A" tag)
             (format nil "refs/tags/~A^{}" tag))
       prompt-p)
    (case state
      (:ok
       (let ((commit (%publish-remote-tag-commit-from-refs refs tag)))
         (if commit
             (%publish-state :matching
                             (format nil "remote tag ~A -> ~A" tag commit)
                             :commit commit)
             (%publish-state :missing
                             (format nil "remote tag ~A is missing" tag)))))
      (:missing
       (%publish-state :missing "GitHub repository is missing"))
      (otherwise
       (%publish-state :unavailable
                       "remote tag inspection failed"
                       :details evidence)))))

(defun %publish-remote-branch-commit (repository-url branch prompt-p)
  (multiple-value-bind (refs state evidence)
      (%publish-ls-remote-refs
       repository-url
       (list "--heads" (format nil "refs/heads/~A" branch))
       prompt-p)
    (case state
      (:ok
       (let ((entry (%publish-find-ref
                     (format nil "refs/heads/~A" branch)
                     refs)))
         (if entry
             (%publish-state :matching
                             (format nil "remote branch ~A -> ~A"
                                     branch (car entry))
                             :commit (car entry))
             (%publish-state :missing
                             (format nil "remote branch ~A is missing" branch)))))
      (:missing
       (%publish-state :missing "GitHub repository is missing"))
      (otherwise
       (%publish-state :unavailable
                       "remote branch inspection failed"
                       :details evidence)))))

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

(defun %publish-head-commit (root)
  (multiple-value-bind (out err code)
      (%publish-run-git root '("rev-parse" "--verify" "HEAD"))
    (declare (ignore err))
    (when (and (integerp code) (= code 0))
      (%publish-trim-output out))))

(defun %publish-local-tag-commit (root tag)
  (multiple-value-bind (out err code)
      (%publish-run-git root
                        (list "rev-parse" "--verify"
                              (format nil "~A^{commit}" tag)))
    (cond
      ((and (integerp code) (= code 0))
       (%publish-state :matching
                       (format nil "local tag ~A -> ~A"
                               tag (%publish-trim-output out))
                       :commit (%publish-trim-output out)))
      ((or (%publish-output-contains-p "unknown revision" out err)
           (%publish-output-contains-p "needed a single revision" out err)
           (%publish-output-contains-p "ambiguous argument" out err))
       (%publish-state :missing (format nil "local tag ~A is missing" tag)))
      (t
       (%publish-state :unavailable
                       (format nil "failed to inspect local tag ~A" tag)
                       :details (format nil "~A~A" out err))))))

(defun %publish-normalize-notes (notes)
  (with-output-to-string (out)
    (loop with string = (or notes "")
          for index from 0 below (length string)
          for char = (char string index)
          do (cond
               ((char= char #\Return)
                (write-char #\Newline out)
                (when (and (< (1+ index) (length string))
                           (char= (char string (1+ index)) #\Newline))
                  (incf index)))
               (t
                (write-char char out))))))

(defun %publish-json-object-from-output (out)
  (handler-case
      (han.json:parse-json (%publish-trim-output out))
    (error () nil)))

(defun %publish-json-string (object key)
  (let ((value (and object (han.json:get-json object key))))
    (and (stringp value) value)))

(defun %publish-json-true-p (object key)
  (eq t (and object (han.json:get-json object key))))

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

(defun %publish-default-release-summary-p (message)
  (let ((trimmed (%publish-trim-output message)))
    (or (string-equal trimmed "TODO")
        (string-equal trimmed "TODO: release summary"))))

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
      (when (%publish-default-release-summary-p message)
        (error "[publish] first line of release.md is still the default TODO release summary. Replace it before publishing."))
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

(defun %print-project-publish-summary (context build-p commands outcome)
  (let ((project (getf context :project))
        (tag (getf context :tag))
        (channel (getf context :channel))
        (dry-run (getf context :dry-run))
        (prompt-p (getf context :prompt-p))
        (create-repo-p (getf context :create-repo-p))
        (repo-visibility (getf context :repo-visibility))
        (remote-checked-p (getf context :remote-checked-p))
        (remote-missing-p (getf context :remote-missing-p))
        (latest-info (getf context :remote-latest))
        (remote-error (getf context :remote-error))
        (release-info (getf context :release-info))
        (lock-repo-p (getf context :lock-repo-p))
        (phases (nreverse (copy-list (getf context :phases)))))
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
  (format t "  outcome : ~A~%" (string-downcase (string outcome)))
  (format t "  phases  :~%")
  (dolist (phase phases)
    (format t "    ~A: ~A~@[ (~A)~]~%"
            (string-downcase (string (getf phase :id)))
            (string-downcase (string (getf phase :status)))
            (getf phase :evidence)))
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
      (format t "    ~A~%" (%publish-format-command command))))))

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

(defun %publish-make-context
    (project tag channel dry-run prompt-p create-repo-p repo-visibility
     lock-repo-p release-info commit-message remote-tags verbose)
  (list :project project
        :root (getf project :root-dir)
        :repository-url (getf project :repository-url)
        :tag tag
        :channel channel
        :dry-run dry-run
        :prompt-p prompt-p
        :create-repo-p create-repo-p
        :repo-visibility repo-visibility
        :lock-repo-p lock-repo-p
        :release-info release-info
        :release-requested-p (not (null release-info))
        :release-title (and release-info (getf release-info :title))
        :release-notes-sha256
        (and release-info
             (%publish-sha256
              (%publish-normalize-notes (getf release-info :notes))))
        :commit-message commit-message
        :remote-tags-override remote-tags
        :remote-tags nil
        :remote-checked-p nil
        :remote-missing-p nil
        :remote-error nil
        :remote-latest nil
        :target-commit nil
        :branch nil
        :initialized-p nil
        :repository-create-started-p nil
        :repository-created-p nil
        :policy-required-p nil
        :policy-inspection nil
        :journal nil
        :journal-file nil
        :journal-error nil
        :created-at nil
        :last-stage nil
        :last-confirmed-stage nil
        :failed-stage nil
        :phases nil
        :mutation-count 0
        :journal-resume-p nil
        :resume-evidence-p nil
        :warnings nil
        :verbose verbose))

(defun %publish-bool-json (value)
  (not (null value)))

(defun %publish-journal-object (context status)
  (han.json:json-object
   (cons "schema" "taffish.publish-transaction/v1")
   (cons "repository" (getf context :repository-url))
   (cons "tag" (getf context :tag))
   (cons "commit" (or (getf context :target-commit) :null))
   (cons "release_requested"
         (%publish-bool-json (getf context :release-requested-p)))
   (cons "release_title" (or (getf context :release-title) :null))
   (cons "release_notes_sha256"
         (or (getf context :release-notes-sha256) :null))
   (cons "create_repository"
         (%publish-bool-json (getf context :create-repo-p)))
   (cons "repository_create_started"
         (%publish-bool-json (getf context :repository-create-started-p)))
   (cons "repository_created"
         (%publish-bool-json (getf context :repository-created-p)))
   (cons "lock_repository"
         (%publish-bool-json (getf context :lock-repo-p)))
   (cons "visibility"
         (string-downcase (string (getf context :repo-visibility))))
   (cons "branch" (or (getf context :branch) :null))
   (cons "last_known_stage"
         (or (and (getf context :last-stage)
                  (string-downcase
                   (symbol-name (getf context :last-stage))))
             :null))
   (cons "last_confirmed_stage"
         (or (and (getf context :last-confirmed-stage)
                  (string-downcase
                   (symbol-name (getf context :last-confirmed-stage))))
             :null))
   (cons "status" (string-downcase (string status)))
   (cons "created_at" (or (getf context :created-at)
                           (%publish-timestamp)))
   (cons "updated_at" (%publish-timestamp))))

(defun %publish-write-journal (context status)
  (unless (getf context :dry-run)
    (let ((file (or (getf context :journal-file)
                    (%publish-journal-file
                     (getf context :repository-url)
                     (getf context :tag)))))
      (setf (getf context :journal-file) file)
      (%publish-write-json-atomically
       file (%publish-journal-object context status)))))

(defun %publish-journal-string-equal (journal key expected)
  (let ((actual (%publish-journal-value journal key :missing)))
    (cond
      ((null expected)
       (or (eq actual :missing) (eq actual :null) (null actual)))
      ((stringp expected)
       (and (stringp actual) (string= actual expected)))
      (t
       (equal actual expected)))))

(defun %publish-load-journal (context)
  (let ((file (%publish-journal-file
               (getf context :repository-url)
               (getf context :tag))))
    (setf (getf context :journal-file) file)
    (multiple-value-bind (journal read-error)
        (%publish-read-journal file)
      (when read-error
        (setf (getf context :journal-error) (princ-to-string read-error))
        (push "ignored corrupt publish journal; Git/GitHub facts remain authoritative"
              (getf context :warnings)))
      (when (and journal
                 (string= "taffish.publish-transaction/v1"
                          (or (%publish-journal-value journal "schema") "")))
        (dolist (check
                 (list
                  (list "repository" (getf context :repository-url))
                  (list "tag" (getf context :tag))
                  (list "release_requested"
                        (%publish-bool-json
                         (getf context :release-requested-p)))
                  (list "release_title" (getf context :release-title))
                  (list "release_notes_sha256"
                        (getf context :release-notes-sha256))
                  (list "create_repository"
                        (%publish-bool-json (getf context :create-repo-p)))
                  (list "lock_repository"
                        (%publish-bool-json (getf context :lock-repo-p)))
                  (list "visibility"
                        (string-downcase
                         (string (getf context :repo-visibility))))))
          (unless (%publish-journal-string-equal
                   journal (first check) (second check))
            (%publish-fail
             :conflict :project-validated
             "publish intent conflicts with the existing transaction journal (~A). Use the same publish options and release.md, or inspect ~A manually."
             (first check) (han.path:->namestring file))))
        (let ((commit (%publish-journal-value journal "commit")))
          (when (stringp commit)
            (setf (getf context :target-commit) commit)))
        (setf (getf context :journal) journal
              (getf context :created-at)
              (%publish-journal-value journal "created_at")
              (getf context :repository-create-started-p)
              (%publish-journal-value journal "repository_create_started" nil)
              (getf context :repository-created-p)
              (%publish-journal-value journal "repository_created" nil))
        (let ((last-stage (%publish-journal-value journal "last_known_stage")))
          (when (and (stringp last-stage)
                     (not (member last-stage
                                  '("project-validated" "publish-complete")
                                  :test #'string=)))
            (setf (getf context :journal-resume-p) t
                  (getf context :resume-evidence-p) t))))
      journal)))

(defun %publish-record-phase
    (context id status evidence &optional next-action)
  (let ((phase (list :id id
                     :status status
                     :evidence evidence
                     :next-action next-action)))
    (push phase (getf context :phases))
    (setf (getf context :last-stage) id)
    (when (member status '(:ready :created :resumed :skipped) :test #'eql)
      (setf (getf context :last-confirmed-stage) id))
    (when (member status '(:created :resumed) :test #'eql)
      (incf (getf context :mutation-count)))
    (when (eql status :resumed)
      (setf (getf context :resume-evidence-p) t))
    (%publish-write-journal context status)
    phase))

(defun %publish-accept-state-fields (context result stage)
  (let ((commit (getf result :commit)))
    (when commit
      (let ((expected (getf context :target-commit)))
        (when (and expected (not (string= expected commit)))
          (%publish-fail
           :conflict stage
           "commit identity differs: expected ~A, observed ~A"
           expected commit))
        (setf (getf context :target-commit) commit))))
  (let ((branch (getf result :branch)))
    (when branch
      (setf (getf context :branch) branch)))
  result)

(defun %publish-default-inspect-repository (context)
  (let ((override (getf context :remote-tags-override)))
    (if override
        (progn
          (setf (getf context :remote-tags) (%publish-release-infos override)
                (getf context :remote-checked-p) t
                (getf context :remote-missing-p) nil)
          (%publish-state :matching "repository supplied by remote-tags test fixture"))
        (multiple-value-bind (refs state evidence)
            (%publish-ls-remote-refs
             (getf context :repository-url) '("--tags")
             (getf context :prompt-p))
          (case state
            (:ok
             (let ((tags (%publish-unique-strings (mapcar #'cdr refs))))
               (setf (getf context :remote-tags)
                     (%publish-release-infos tags)
                     (getf context :remote-checked-p) t
                     (getf context :remote-missing-p) nil)
               (%publish-state :matching "GitHub repository is reachable")))
            (:missing
             (setf (getf context :remote-checked-p) t
                   (getf context :remote-missing-p) t)
             (%publish-state :missing "GitHub repository is missing"))
            (otherwise
             (setf (getf context :remote-error) evidence)
             (%publish-state :unavailable
                             "GitHub repository inspection is unavailable"
                             :details evidence)))))))

(defun %publish-default-create-repository (context)
  (%publish-create-remote-repository
   (getf context :repository-url)
   (getf context :repo-visibility)
   (getf context :prompt-p)
   (getf context :verbose)))

(defun %publish-gh-query (context args)
  (%publish-query-run-program
   (%publish-gh-program) args
   :noninteractive (not (getf context :prompt-p))
   :prompt (getf context :prompt-p)))

(defun %publish-inspect-repository-visibility (context)
  (let ((slug (%publish-github-slug (getf context :repository-url))))
    (multiple-value-bind (out err code)
        (%publish-gh-query context
                           (list "repo" "view" slug
                                 "--json" "nameWithOwner,visibility,url"))
      (if (and (integerp code) (= code 0))
          (let* ((object (%publish-json-object-from-output out))
                 (actual-slug (%publish-json-string object "nameWithOwner"))
                 (visibility (%publish-json-string object "visibility"))
                 (expected (string-upcase
                            (string (getf context :repo-visibility)))))
            (cond
              ((null object)
               (%publish-state :unavailable
                               "GitHub repository metadata is not valid JSON"))
              ((not (string-equal (or actual-slug "") slug))
               (%publish-state :conflicting
                               (format nil "GitHub repository slug is ~A, expected ~A"
                                       actual-slug slug)))
              ((not (string-equal (or visibility "") expected))
               (%publish-state :conflicting
                               (format nil "GitHub repository visibility is ~A, expected ~A"
                                       visibility expected)))
              (t
               (%publish-state :matching
                               (format nil "repository visibility is ~A" visibility)))))
          (%publish-state :unavailable
                          "failed to inspect GitHub repository metadata"
                          :details (format nil "~A~A" out err))))))

(defun %publish-inspect-immutable-releases (context)
  (let ((slug (%publish-github-slug (getf context :repository-url))))
    (multiple-value-bind (out err code)
        (%publish-gh-query
         context (list "api" (format nil "repos/~A/immutable-releases" slug)))
      (cond
        ((and (integerp code) (= code 0))
         (let ((object (%publish-json-object-from-output out)))
           (if (and object (%publish-json-true-p object "enabled"))
               (%publish-state :matching "immutable GitHub Releases are enabled")
               (%publish-state :missing "immutable GitHub Releases are disabled"))))
        ((%publish-release-not-found-output-p out err)
         (%publish-state :missing "immutable GitHub Releases are not enabled"))
        (t
         (%publish-state :unavailable
                         "failed to inspect immutable GitHub Releases"
                         :details (format nil "~A~A" out err)))))))

(defun %publish-json-vector-contains-string-p (vector string)
  (and (vectorp vector)
       (loop for index from 0 below (length vector)
             thereis (let ((value (aref vector index)))
                       (and (stringp value) (string= value string))))))

(defun %publish-ruleset-has-rule-p (rules type)
  (and (vectorp rules)
       (loop for index from 0 below (length rules)
             for rule = (aref rules index)
             thereis (string= (or (%publish-json-string rule "type") "")
                              type))))

(defun %publish-release-ruleset-matches-p (ruleset)
  (let* ((conditions (and ruleset
                          (han.json:get-json ruleset "conditions")))
         (ref-name (and conditions
                        (han.json:get-json conditions "ref_name")))
         (include (and ref-name (han.json:get-json ref-name "include")))
         (rules (and ruleset (han.json:get-json ruleset "rules"))))
    (and ruleset
         (string= (or (%publish-json-string ruleset "name") "")
                  "TAFFISH release tag lock")
         (string= (or (%publish-json-string ruleset "target") "") "tag")
         (string= (or (%publish-json-string ruleset "enforcement") "") "active")
         (%publish-json-vector-contains-string-p include "refs/tags/v*")
         (%publish-ruleset-has-rule-p rules "update")
         (%publish-ruleset-has-rule-p rules "deletion"))))

(defun %publish-inspect-release-tag-ruleset (context)
  (let ((slug (%publish-github-slug (getf context :repository-url))))
    (multiple-value-bind (out err code)
        (%publish-gh-query
         context (list "api" (format nil "repos/~A/rulesets" slug)
                       "--paginate"))
      (cond
        ((and (integerp code) (= code 0))
         (let ((rulesets (%publish-json-object-from-output out)))
           (if (not (vectorp rulesets))
               (%publish-state :unavailable
                               "GitHub ruleset list is not valid JSON")
               (let ((summary
                       (loop for index from 0 below (length rulesets)
                             for item = (aref rulesets index)
                             when (string= (or (%publish-json-string item "name") "")
                                           "TAFFISH release tag lock")
                               return item)))
                 (if (null summary)
                     (%publish-state :missing
                                     "TAFFISH release tag ruleset is missing")
                     (let ((id (han.json:get-json summary "id")))
                       (if (null id)
                           (%publish-state :unavailable
                                           "TAFFISH release tag ruleset has no id")
                           (multiple-value-bind (detail-out detail-err detail-code)
                               (%publish-gh-query
                                context
                                (list "api"
                                      (format nil "repos/~A/rulesets/~A" slug id)))
                             (cond
                               ((and (integerp detail-code) (= detail-code 0))
                                (let ((detail
                                        (%publish-json-object-from-output detail-out)))
                                  (if (%publish-release-ruleset-matches-p detail)
                                      (%publish-state
                                       :matching "TAFFISH release tag ruleset matches")
                                      (%publish-state
                                       :conflicting
                                       "TAFFISH release tag ruleset exists but differs"))))
                               (t
                                (%publish-state
                                 :unavailable
                                 "failed to inspect TAFFISH release tag ruleset"
                                 :details (format nil "~A~A"
                                                  detail-out detail-err))))))))))))
        ((%publish-release-not-found-output-p out err)
         (%publish-state :missing "TAFFISH release tag ruleset is missing"))
        (t
         (%publish-state :unavailable
                         "failed to list GitHub repository rulesets"
                         :details (format nil "~A~A" out err)))))))

(defun %publish-default-inspect-policy (context)
  (if (not (getf context :policy-required-p))
      (%publish-state :not-applicable
                      "repository was not created by this publish transaction")
      (let ((visibility (%publish-inspect-repository-visibility context)))
        (unless (eql (getf visibility :state) :matching)
          (return-from %publish-default-inspect-policy visibility))
        (let ((immutable (%publish-inspect-immutable-releases context))
              (ruleset (%publish-inspect-release-tag-ruleset context)))
          (setf (getf context :policy-inspection)
                (list :immutable immutable :ruleset ruleset))
          (cond
            ((or (eql (getf immutable :state) :conflicting)
                 (eql (getf ruleset :state) :conflicting))
             (%publish-state :conflicting
                             "repository release policy conflicts with TAFFISH intent"))
            ((or (eql (getf immutable :state) :unavailable)
                 (eql (getf ruleset :state) :unavailable))
             (%publish-state :unavailable
                             "repository release policy inspection is unavailable"))
            ((and (eql (getf immutable :state) :matching)
                  (eql (getf ruleset :state) :matching))
             (%publish-state :matching
                             "immutable Releases and release tag ruleset match"))
            (t
             (%publish-state :missing
                             "repository release policy is incomplete")))))))

(defun %publish-default-create-policy (context)
  (let* ((inspection (getf context :policy-inspection))
         (immutable (getf inspection :immutable))
         (ruleset (getf inspection :ruleset))
         (slug (%publish-github-slug (getf context :repository-url))))
    (when (eql (getf immutable :state) :missing)
      (%publish-enable-immutable-releases
       slug (getf context :prompt-p) (getf context :verbose)))
    (when (eql (getf ruleset :state) :missing)
      (%publish-create-release-tag-ruleset
       slug (getf context :prompt-p) (getf context :verbose)))))

(defun %publish-default-inspect-remote-tag (context)
  (let ((override (getf context :remote-tags-override))
        (tag (getf context :tag)))
    (if override
        (if (member tag (%publish-release-infos override)
                    :key (lambda (info) (getf info :tag))
                    :test #'string=)
            (%publish-state
             :conflicting
             "remote-tags fixture reports the target tag but cannot prove its commit identity")
            (%publish-state :missing (format nil "remote tag ~A is missing" tag)))
        (%publish-remote-tag-commit
         (getf context :repository-url) tag (getf context :prompt-p)))))

(defun %publish-commit-candidates (context local-tag remote-tag)
  (remove nil
          (list (getf context :target-commit)
                (getf local-tag :commit)
                (getf remote-tag :commit))))

(defun %publish-identical-strings-p (strings)
  (or (null strings)
      (every (lambda (value) (string= value (first strings)))
             (rest strings))))

(defun %publish-default-inspect-commit (context)
  (let ((root (getf context :root)))
    (unless (%publish-git-worktree-p root)
      (return-from %publish-default-inspect-commit
        (%publish-state :missing "git repository and release commit are not ready")))
    (let ((origin (%publish-git-origin-url root)))
      (cond
        ((or (null origin) (%blank-string-p origin))
         (return-from %publish-default-inspect-commit
           (%publish-state :missing
                           "git origin is not configured for this project")))
        ((not (%publish-same-repository-p
               origin (getf context :repository-url)))
         (return-from %publish-default-inspect-commit
           (%publish-state
            :conflicting
            (format nil "git origin ~A differs from ~A"
                    origin (getf context :repository-url)))))))
    (let* ((local-tag (%publish-local-tag-commit root (getf context :tag)))
           (remote-tag (%publish-default-inspect-remote-tag context)))
      (when (member :unavailable
                    (list (getf local-tag :state) (getf remote-tag :state)))
        (return-from %publish-default-inspect-commit
          (%publish-state :unavailable
                          "tag identity inspection is unavailable")))
      (when (member :conflicting
                    (list (getf local-tag :state) (getf remote-tag :state)))
        (return-from %publish-default-inspect-commit remote-tag))
      (let* ((candidates (%publish-commit-candidates
                          context local-tag remote-tag))
             (head (%publish-head-commit root))
             (status (%publish-git-status-lines root)))
        (unless (%publish-identical-strings-p candidates)
          (return-from %publish-default-inspect-commit
            (%publish-state
             :conflicting
             (format nil "journal/local/remote tag commits disagree: ~{~A~^, ~}"
                     candidates))))
        (let ((expected (first candidates)))
          (cond
            ((and expected
                  (or (null head) (not (string= expected head))))
             (%publish-state
              :conflicting
              (format nil "current HEAD ~A differs from release commit ~A"
                      head expected)))
            ((and expected status)
             (%publish-state
              :conflicting
              "project changed after the release commit was established"))
            (expected
             (%publish-state :matching
                             (format nil "release commit is ~A" expected)
                             :commit expected))
            ((and head (null status))
             (%publish-state :matching
                             (format nil "clean project HEAD is ~A" head)
                             :commit head))
            (t
             (%publish-state :missing
                             "project changes must be committed for release"))))))))

(defun %publish-default-create-commit (context)
  (let* ((root (getf context :root))
         (initialized-p (%publish-ensure-git-worktree
                         root (getf context :verbose))))
    (setf (getf context :initialized-p) initialized-p)
    (%publish-ensure-origin root (getf context :repository-url)
                            (getf context :verbose))
    (%publish-run-git/checked root '("add" "-A"))
    (when (getf context :release-info)
      (%publish-run-git/checked
       root '("rm" "--cached" "--ignore-unmatch" "release.md")))
    (when (%publish-git-status-lines root)
      (when (getf context :verbose)
        (format t "[TAF] committing project changes.~%"))
      (%publish-run-git/checked
       root (list "commit" "-m" (getf context :commit-message))))
    (unless (%publish-head-exists-p root)
      (error "[publish] git repository has no commit to tag."))
    (when initialized-p
      (%publish-run-git/checked root '("branch" "-M" "main")))
    (setf (getf context :branch) (%publish-current-branch root)
          (getf context :target-commit) (%publish-head-commit root))))

(defun %publish-default-inspect-branch (context)
  (let ((target (getf context :target-commit)))
    (unless target
      (return-from %publish-default-inspect-branch
        (%publish-state :pending "release commit is not known yet")))
    (let ((branch (or (getf context :branch)
                      (%publish-current-branch (getf context :root)))))
      (unless branch
        (return-from %publish-default-inspect-branch
          (%publish-state :conflicting
                          "detached HEAD cannot define a publish branch")))
      (setf (getf context :branch) branch)
      (let ((remote (%publish-remote-branch-commit
                     (getf context :repository-url) branch
                     (getf context :prompt-p))))
        (case (getf remote :state)
          (:matching
           (if (string= target (getf remote :commit))
               (%publish-state :matching
                               (getf remote :evidence)
                               :commit target :branch branch)
               (%publish-state
                :missing
                (format nil "remote branch ~A is at ~A, target is ~A"
                        branch (getf remote :commit) target)
                :actual (getf remote :commit)
                :commit target
                :branch branch)))
          (otherwise remote))))))

(defun %publish-default-create-branch (context)
  (%publish-run-git/checked
   (getf context :root)
   (list "push" "-u" "origin" (getf context :branch))
   :noninteractive (not (getf context :prompt-p))
   :prompt (getf context :prompt-p)
   :interactive-output (getf context :prompt-p)))

(defun %publish-default-inspect-local-tag (context)
  (let ((result (%publish-local-tag-commit
                 (getf context :root) (getf context :tag))))
    (if (and (eql (getf result :state) :matching)
             (not (string= (getf result :commit)
                           (getf context :target-commit))))
        (%publish-state
         :conflicting
         (format nil "local tag ~A points to ~A, expected ~A"
                 (getf context :tag) (getf result :commit)
                 (getf context :target-commit)))
        result)))

(defun %publish-default-create-local-tag (context)
  (%publish-run-git/checked
   (getf context :root)
   (list "tag" (getf context :tag) (getf context :target-commit))))

(defun %publish-default-inspect-remote-tag-phase (context)
  (let ((result (%publish-default-inspect-remote-tag context)))
    (if (and (eql (getf result :state) :matching)
             (not (string= (getf result :commit)
                           (getf context :target-commit))))
        (%publish-state
         :conflicting
         (format nil "remote tag ~A points to ~A, expected ~A"
                 (getf context :tag) (getf result :commit)
                 (getf context :target-commit)))
        result)))

(defun %publish-default-create-remote-tag (context)
  (%publish-run-git/checked
   (getf context :root)
   (list "push" "origin" (getf context :tag))
   :noninteractive (not (getf context :prompt-p))
   :prompt (getf context :prompt-p)
   :interactive-output (getf context :prompt-p)))

(defun %publish-default-inspect-release (context)
  (if (not (getf context :release-requested-p))
      (%publish-state :not-applicable "GitHub Release was not requested")
      (let ((slug (%publish-github-slug (getf context :repository-url))))
        (multiple-value-bind (out err code)
            (%publish-gh-query
             context
             (list "release" "view" (getf context :tag)
                   "--repo" slug
                   "--json" "tagName,name,body,isDraft,isPrerelease,targetCommitish"))
          (cond
            ((and (integerp code) (= code 0))
             (let* ((object (%publish-json-object-from-output out))
                    (tag (%publish-json-string object "tagName"))
                    (title (%publish-json-string object "name"))
                    (body (%publish-json-string object "body"))
                    (digest (and body
                                 (%publish-sha256
                                  (%publish-normalize-notes body)))))
               (cond
                 ((null object)
                  (%publish-state :unavailable
                                  "GitHub Release response is not valid JSON"))
                 ((or (%publish-json-true-p object "isDraft")
                      (not (string= (or tag "") (getf context :tag)))
                      (not (string= (or title "")
                                    (getf context :release-title)))
                      (not (string= (or digest "")
                                    (getf context :release-notes-sha256))))
                  (%publish-state
                   :conflicting
                   "GitHub Release exists but tag/title/notes intent differs"))
                 (t
                  (%publish-state :matching
                                  "GitHub Release tag/title/notes match")))))
            ((%publish-release-not-found-output-p out err)
             (%publish-state :missing "GitHub Release is missing"))
            (t
             (%publish-state :unavailable
                             "GitHub Release inspection is unavailable"
                             :details (format nil "~A~A" out err))))))))

(defun %publish-default-create-release (context)
  (%publish-create-github-release
   (getf context :repository-url)
   (getf context :tag)
   (getf context :release-info)
   (getf context :prompt-p)
   (getf context :verbose)))

(defun %publish-default-operation (operation context)
  (case operation
    (:inspect-repository (%publish-default-inspect-repository context))
    (:create-repository (%publish-default-create-repository context))
    (:inspect-policy (%publish-default-inspect-policy context))
    (:create-policy (%publish-default-create-policy context))
    (:inspect-commit (%publish-default-inspect-commit context))
    (:create-commit (%publish-default-create-commit context))
    (:inspect-branch (%publish-default-inspect-branch context))
    (:create-branch (%publish-default-create-branch context))
    (:inspect-local-tag (%publish-default-inspect-local-tag context))
    (:create-local-tag (%publish-default-create-local-tag context))
    (:inspect-remote-tag (%publish-default-inspect-remote-tag-phase context))
    (:create-remote-tag (%publish-default-create-remote-tag context))
    (:inspect-release (%publish-default-inspect-release context))
    (:create-release (%publish-default-create-release context))
    (otherwise
     (error "[publish] unknown operation: ~S" operation))))

(defun %publish-operation (operation context)
  (if *publish-operation-adapter*
      (funcall *publish-operation-adapter* operation context)
      (%publish-default-operation operation context)))

(defun %publish-reconcile-mutation
    (context phase-id inspect-operation create-operation)
  (let ((mutation-error nil)
        (last-confirmed-stage (getf context :last-confirmed-stage)))
    (handler-case
        (%publish-operation create-operation context)
      (error (condition)
        (setf mutation-error condition)))
    (let ((after (%publish-operation inspect-operation context)))
      (%publish-accept-state-fields context after phase-id)
      (case (getf after :state)
        (:matching
         (%publish-record-phase
          context phase-id (if mutation-error :resumed :created)
          (if mutation-error
              (format nil "operation reported failure, but reconciliation proved success: ~A"
                      (getf after :evidence))
              (getf after :evidence))))
        (:not-applicable
         (%publish-record-phase context phase-id :skipped
                                (getf after :evidence)))
        (:conflicting
         (%publish-record-phase context phase-id :conflict
                                (getf after :evidence))
         (%publish-fail :conflict phase-id "~A" (getf after :evidence)))
        (:unavailable
         (%publish-record-phase context phase-id :unavailable
                                (getf after :evidence))
         (%publish-fail
          :unavailable phase-id
          "could not confirm whether ~A completed; rerun the same taf publish command after connectivity is restored. Last confirmed stage: ~A"
          create-operation (or last-confirmed-stage :none)))
        (:missing
         (if (getf after :actual)
             (progn
               (%publish-record-phase context phase-id :conflict
                                      (getf after :evidence))
               (%publish-fail
                :conflict phase-id
                "~A did not reach the required commit after ~A; refusing to overwrite the remote ref"
                (getf after :evidence) create-operation))
             (progn
               (%publish-record-phase context phase-id :failed
                                      (getf after :evidence))
               (%publish-fail
                :failed phase-id
                "~A did not reach the required state.~@[ Cause: ~A~]"
                create-operation mutation-error))))
        (otherwise
         (%publish-record-phase context phase-id :failed
                                (getf after :evidence))
         (%publish-fail
          :failed phase-id
          "~A did not reach the required state.~@[ Cause: ~A~]"
          create-operation mutation-error))))))

(defun %publish-ensure-phase
    (context phase-id inspect-operation create-operation
     &key (matching-status :skipped) missing-error)
  (let ((before (%publish-operation inspect-operation context)))
    (%publish-accept-state-fields context before phase-id)
    (case (getf before :state)
      (:matching
       (when (member phase-id
                     '(:commit-ready :branch-pushed :local-tag-ready
                       :remote-tag-ready :github-release-ready)
                     :test #'eql)
         (setf (getf context :resume-evidence-p) t))
       (%publish-record-phase context phase-id matching-status
                              (getf before :evidence)))
      (:not-applicable
       (%publish-record-phase context phase-id :skipped
                              (getf before :evidence)))
      (:pending
       (%publish-record-phase context phase-id :pending
                              (getf before :evidence)))
      (:conflicting
       (%publish-record-phase context phase-id :conflict
                              (getf before :evidence))
       (%publish-fail :conflict phase-id "~A" (getf before :evidence)))
      (:unavailable
       (%publish-record-phase context phase-id :unavailable
                              (getf before :evidence))
       (unless (getf context :dry-run)
         (%publish-fail
          :unavailable phase-id
          "~A; rerun the same taf publish command after connectivity is restored. Last confirmed stage: ~A"
          (getf before :evidence)
          (or (getf context :last-confirmed-stage) :none))))
      (:missing
       (cond
         ((getf context :dry-run)
          (%publish-record-phase context phase-id :pending
                                 (getf before :evidence)
                                 create-operation))
         (missing-error
          (%publish-record-phase context phase-id :failed
                                 (getf before :evidence))
          (%publish-fail :failed phase-id "~A" missing-error))
         (t
          (%publish-reconcile-mutation
           context phase-id inspect-operation create-operation))))
      (otherwise
       (%publish-fail :failed phase-id
                      "unknown inspection state: ~S" (getf before :state))))))

(defun %publish-mark-repository-create-intent (context)
  (setf (getf context :repository-create-started-p) t
        (getf context :policy-required-p) (getf context :lock-repo-p))
  (%publish-write-journal context :repository-create-started))

(defun %publish-ensure-repository-phase (context)
  (let ((before (%publish-operation :inspect-repository context)))
    (case (getf before :state)
      (:matching
       (setf (getf context :policy-required-p)
             (and (getf context :lock-repo-p)
                  (or (getf context :repository-create-started-p)
                      (getf context :repository-created-p))))
       (%publish-record-phase context :repository-ready :ready
                              (getf before :evidence)))
      (:missing
       (cond
         ((not (getf context :create-repo-p))
          (if (getf context :dry-run)
              (%publish-record-phase
               context :repository-ready :pending
               "repository must be created manually or with --create-repo")
              (%publish-fail
               :failed :repository-ready "~A"
               (%publish-repository-missing-hint
                (getf context :repository-url)))))
         ((getf context :dry-run)
          (setf (getf context :policy-required-p)
                (getf context :lock-repo-p))
          (%publish-record-phase context :repository-ready :pending
                                 "missing repository will be created"))
         (t
          (%publish-mark-repository-create-intent context)
          (%publish-reconcile-mutation
           context :repository-ready
           :inspect-repository :create-repository)
          (setf (getf context :repository-created-p) t
                (getf context :policy-required-p)
                (getf context :lock-repo-p))
          (%publish-write-journal context :repository-ready))))
      (:unavailable
       (%publish-record-phase context :repository-ready :unavailable
                              (getf before :evidence))
       (unless (getf context :dry-run)
         (%publish-fail
          :unavailable :repository-ready
          "~A; rerun the same taf publish command after connectivity is restored. Last confirmed stage: ~A"
          (getf before :evidence)
          (or (getf context :last-confirmed-stage) :none))))
      (otherwise
       (%publish-fail :conflict :repository-ready "~A"
                      (getf before :evidence))))))

(defun %publish-validate-version-order (context)
  (when (getf context :remote-checked-p)
    (let* ((tag (getf context :tag))
           (other-infos
             (remove tag (getf context :remote-tags)
                     :key (lambda (info) (getf info :tag))
                     :test #'string=))
           (latest (%publish-latest-info other-infos))
           (project (getf context :project)))
      (setf (getf context :remote-latest) latest)
      (when (and (eql (getf context :channel) :latest)
                 latest
                 (<= (%publish-compare-version-release
                      (getf project :version)
                      (getf project :release)
                      (getf latest :version)
                      (getf latest :release))
                     0))
        (%publish-fail
         :conflict :repository-ready
         "current version is not newer than remote latest tag ~A. Use --pre for a pre-release publish."
         (getf latest :tag))))))

(defun %publish-run-state-machine (context)
  (%publish-load-journal context)
  (%publish-record-phase context :project-validated :ready
                         "project, repository URL and LICENSE are valid")
  (%publish-ensure-repository-phase context)
  (%publish-validate-version-order context)
  (%publish-ensure-phase context :repository-policy-ready
                         :inspect-policy :create-policy)
  (%publish-ensure-phase context :commit-ready
                         :inspect-commit :create-commit)
  (%publish-ensure-phase context :branch-pushed
                         :inspect-branch :create-branch)
  (%publish-ensure-phase context :local-tag-ready
                         :inspect-local-tag :create-local-tag)
  (%publish-ensure-phase context :remote-tag-ready
                         :inspect-remote-tag :create-remote-tag)
  (%publish-ensure-phase context :github-release-ready
                         :inspect-release :create-release)
  (%publish-record-phase context :publish-complete :ready
                         "Git tag and requested GitHub Release are complete")
  (cond
    ((getf context :dry-run) :planned)
    ((= (getf context :mutation-count) 0)
     (if (getf context :journal-resume-p) :resumed :skipped))
    ((getf context :resume-evidence-p) :resumed)
    (t :created)))

(defun %publish-phase-history-fields (phases)
  (mapcar (lambda (phase)
            (list :id (getf phase :id)
                  :status (getf phase :status)))
          phases))

(defun %publish-record-history (context status &optional condition)
  (unless (or (null context) (getf context :dry-run))
    (system-record-history-event
     :event "publish"
     :status (string-downcase (string status))
     :project (getf context :project)
     :cwd (getf context :root)
     :user-home *publish-journal-user-home*
     :extra
     (list :tag (getf context :tag)
           :channel (getf context :channel)
           :repository-url (getf context :repository-url)
           :last-confirmed-stage (getf context :last-confirmed-stage)
           :failed-stage (and condition
                              (typep condition 'publish-state-error)
                              (%publish-error-stage condition))
           :error-kind (and condition
                            (typep condition 'publish-state-error)
                            (%publish-error-kind condition))
           :phases (%publish-phase-history-fields
                    (nreverse (copy-list (getf context :phases))))))))

(defun %publish-execute (context)
  (handler-case
      (let ((outcome (%publish-run-state-machine context)))
        (%publish-record-history context outcome)
        outcome)
    (publish-state-error (condition)
      (setf (getf context :failed-stage) (%publish-error-stage condition))
      (%publish-write-journal context (%publish-error-kind condition))
      (%publish-record-history
       context
       (if (eql (%publish-error-kind condition) :conflict)
           :conflict
           :failed)
       condition)
      (error condition))
    (error (condition)
      (%publish-write-journal context :failed)
      (%publish-record-history context :failed condition)
      (error condition))))

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
         (commands (%publish-plan-commands
                    repository-url tag message
                    create-repo-p normalized-visibility
                    release-info lock-repo-p))
         (context nil)
         (outcome nil)
         (phases nil)
         (execute-result nil))
    (%ensure-github-repository-url repository-url "[publish] [repository].url")
    (%publish-ensure-license-ready project)
    (when (and build-p (not dry-run))
      (setf build-result
            (project-build :command-p t
                           :image-p nil
                           :start-dir start-dir
                           :verbose verbose)))
    (setf context
          (%publish-make-context
           project tag normalized-channel dry-run prompt-p create-repo-p
           normalized-visibility lock-repo-p release-info message remote-tags
           verbose)
          outcome (%publish-execute context)
          phases (nreverse (copy-list (getf context :phases)))
          execute-result
          (list :outcome outcome
                :phases phases
                :created-repo (getf context :repository-created-p)
                :target-commit (getf context :target-commit)
                :branch (getf context :branch)))
    (when verbose
      (%print-project-publish-summary context build-p commands outcome))
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
          :remote-checked-p (getf context :remote-checked-p)
          :remote-missing-p (getf context :remote-missing-p)
          :remote-error (getf context :remote-error)
          :remote-tags (getf context :remote-tags)
          :remote-latest (getf context :remote-latest)
          :build build-result
          :commands commands
          :execute execute-result
          :outcome outcome
          :phases phases
          :resumed-p (eql outcome :resumed)
          :complete-p (and (not dry-run)
                           (not (null
                                 (member outcome '(:created :resumed :skipped)
                                         :test #'eql))))
          :journal-file (and (not dry-run)
                             (getf context :journal-file))
          :warnings (nreverse (copy-list (getf context :warnings)))
          :published-p (not dry-run))))
