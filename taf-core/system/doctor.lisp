(in-package :taf.core)

;;;; ============================================================
;;;; system / doctor.lisp
;;;; ============================================================

(defparameter *taffish-doctor-executables*
  '(("git"       :required)
    ("gh"        :optional)
    ("docker"    :optional)
    ("podman"    :optional)
    ("apptainer" :optional)
    ("mksquashfs" :optional)
    ("squashfuse" :optional)
    ("fuse2fs" :optional)
    ("gocryptfs" :optional)
    ("taffish"   :optional)))

(defun %doctor-dir-result (relative-dir path init-p)
  (let ((exists-p (%directory-exists-p path)))
    (cond
      (exists-p
       (list :kind :directory
             :name relative-dir
             :path (%directory-namestring path)
             :status (if (%path-writable-p path) :ok :not-writable)))
      (init-p
       (handler-case
           (progn
             (%ensure-directory path)
             (list :kind :directory
                   :name relative-dir
                   :path (%directory-namestring path)
                   :status :created))
         (error (c)
           (list :kind :directory
                 :name relative-dir
                 :path (%directory-namestring path)
                 :status :error
                 :message (format nil "~A" c)))))
      (t
       (list :kind :directory
             :name relative-dir
             :path (%directory-namestring path)
             :status :missing)))))

(defun %doctor-executable-result (program requirement)
  (let ((path (han.os:find-executable program)))
    (list :kind :executable
          :name program
          :requirement requirement
          :path path
          :status (if path :ok :missing))))

(defun %doctor-bin-path-result (scope home system-bin-dir)
  (let ((bin-dir (%taffish-command-bin-dir scope home system-bin-dir)))
    (list :kind :path
          :name "command bin"
          :path (%directory-namestring bin-dir)
          :status
          (cond
            ((not (%directory-exists-p bin-dir)) :missing)
            ((not (%path-writable-p bin-dir)) :not-writable)
            ((not (%taffish-command-bin-dir-in-path-p bin-dir)) :not-in-path)
            (t :ok)))))

(defun %doctor-status (dir-results executable-results path-results)
  (cond
    ((find :error dir-results :key (lambda (item) (getf item :status)))
     :error)
    ((find :missing dir-results :key (lambda (item) (getf item :status)))
     :needs-init)
    ((find :missing path-results :key (lambda (item) (getf item :status)))
     :needs-init)
    ((find :not-writable dir-results :key (lambda (item) (getf item :status)))
     :permission-warning)
    ((find :not-writable path-results :key (lambda (item) (getf item :status)))
     :permission-warning)
    ((find-if (lambda (item)
                (and (eql (getf item :requirement) :required)
                     (eql (getf item :status) :missing)))
              executable-results)
     :missing-tools)
    ((find :not-in-path path-results :key (lambda (item) (getf item :status)))
     :path-warning)
    (t :ok)))

(defun %doctor-status-string (status)
  (string-downcase (string status)))

(defun %doctor-print-paths (scope user-home system-home)
  (format t "[TAF] doctor~%")
  (format t "  scope       : ~A~%" (string-downcase (string scope)))
  (format t "  user home   : ~A~%" (%directory-namestring user-home))
  (format t "  system home : ~A~%" (%directory-namestring system-home)))

(defun %doctor-print-dir-results (dir-results)
  (format t "~%Directories:~%")
  (dolist (item dir-results)
    (format t "  ~A : ~A~%"
            (getf item :name)
            (%doctor-status-string (getf item :status))))
  nil)

(defun %doctor-print-executable-results (executable-results)
  (format t "~%Executables:~%")
  (dolist (item executable-results)
    (format t "  ~A : ~A~%"
            (getf item :name)
            (or (getf item :path)
                (format nil "missing (~A)"
                        (string-downcase
                         (string (getf item :requirement)))))))
  nil)

(defun %doctor-print-path-results (path-results)
  (format t "~%Shell PATH:~%")
  (dolist (item path-results)
    (format t "  ~A : ~A~%"
            (getf item :path)
            (%doctor-status-string (getf item :status))))
  nil)

(defun %doctor-print-summary (status init-p scope)
  (format t "~%Status: ~A~%" (%doctor-status-string status))
  (when (and (not init-p) (eql status :needs-init))
    (format t "Hint: taf doctor --init --~A~%"
            (string-downcase (string scope)))))

(defun %doctor-print-path-hints (path-results)
  (let ((missing (find :not-in-path path-results
                       :key (lambda (item) (getf item :status)))))
    (when missing
      (format t "Hint: add TAFFISH bin to your shell PATH:~%  ~A~%"
              (%taffish-bin-path-export-command (getf missing :path))))))

(defun system-doctor (&key (init-p nil)
                        (scope :user)
                        user-home
                        system-home
                        system-bin-dir
                        (verbose t))
  (let* ((normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (system-bin-path (%taffish-system-bin-dir system-bin-dir))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (when (and init-p
               (eql normalized-scope :system)
               (not (%root-user-p)))
      (error "[doctor] --init --system requires root permission."))
    (let* ((dir-results
             (mapcar (lambda (item)
                       (%doctor-dir-result (car item) (cdr item) init-p))
                     (%taffish-home-required-dir-paths home)))
           (executable-results
             (mapcar (lambda (item)
                       (%doctor-executable-result (first item) (second item)))
                     *taffish-doctor-executables*))
           (path-results
             (list (%doctor-bin-path-result normalized-scope
                                            home
                                            system-bin-path)))
           (status (%doctor-status dir-results executable-results path-results))
           (result (list :scope normalized-scope
                         :init-p init-p
                         :user-home (%directory-namestring user-home-path)
                         :system-home (%directory-namestring system-home-path)
                         :system-bin-dir (%directory-namestring system-bin-path)
                         :home (%directory-namestring home)
                         :directories dir-results
                         :executables executable-results
                         :paths path-results
                         :status status)))
      (when verbose
        (%doctor-print-paths normalized-scope user-home-path system-home-path)
        (%doctor-print-dir-results dir-results)
        (%doctor-print-executable-results executable-results)
        (%doctor-print-path-results path-results)
        (%doctor-print-summary status init-p normalized-scope)
        (%doctor-print-path-hints path-results))
      result)))
