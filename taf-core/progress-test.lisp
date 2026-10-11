(in-package :han.test)

(defun %operation-test-display (thunk &key terminal-p (language "en"))
  (taffish.i18n:with-language (language)
    (han.host:with-character-output-to-string (out)
      (let ((taf.core::*operation-display*
              (taf.core::%make-operation-display :stream out :terminal-p terminal-p)))
        (unwind-protect (funcall thunk) (taf.core::%operation-progress-yield))))))

(deftest test-operation-progress-pipe-and-localization ()
  (dolist (language '("en" "zh"))
    (let ((text (%operation-test-display
                 (lambda () (taf.core::%operation-stage "download")) :language language)))
      (check-true (search (if (equal language "en") "Downloading index" "正在下载索引") text))
      (check-equal nil (find (code-char 27) text))
      (check-equal 1 (count #\Newline text)))))

(deftest test-operation-progress-terminal-and-yield ()
  (let ((text (%operation-test-display
               (lambda ()
                 (taf.core::%operation-stage "fetch" :target "demo")
                 (taf.core::%operation-stage "verify" :target "demo")
                 (taf.core::%operation-progress-yield)
                 (taf.core::%operation-progress-yield)) :terminal-p t)))
    (check-equal 2 (count (code-char 27) text))
    (check-equal 1 (count #\Newline text))))

(deftest test-operation-progress-log-throttle-and-target ()
  (let ((text (%operation-test-display
               (lambda ()
                 (loop repeat 30 do
                   (taf.core::%operation-stage "fetch" :target "one")
                   (taf.core::%operation-stage "verify" :target "one"))
                 (taf.core::%operation-stage "fetch" :target "two")
                 (taf.core::%operation-stage "retry" :force-p t)))))
    (check-equal 3 (count #\Newline text))))

(deftest test-operation-progress-unsafe-and-long-text ()
  (let ((text (%operation-test-display
               (lambda () (taf.core::%operation-stage "fetch"
                            :target (format nil "~C~C~A" (code-char 27) #\Newline (make-string 200 :initial-element #\a))))
               :terminal-p t)))
    (check-equal nil (find (code-char 27) text))
    (check-equal nil (find #\Return text))
    (check-equal 1 (count #\Newline text))
    (check-true (search "..." text))))

(deftest test-operation-progress-count-and-silent ()
  (check-true (search "2/3" (%operation-test-display
                             (lambda ()
                               (let ((taf.core::*operation-item* 2) (taf.core::*operation-total* 3))
                                 (taf.core::%operation-stage "fetch" :target "demo"))))))
  (check-equal "" (han.host:with-character-output-to-string (*error-output*)
                    (let ((taf.core::*operation-display* nil))
                      (taf.core::%with-operation-progress (nil)
                        (taf.core::%operation-stage "fetch"))))))

(deftest test-operation-progress-return-values-and-error ()
  (let ((taf.core::*operation-display* nil))
    (check-equal '(1 nil "three")
                 (multiple-value-list (taf.core::%with-operation-progress (nil) (values 1 nil "three"))))
    (let ((expected (make-condition 'simple-error :format-control "sentinel")))
      (check-true (eq expected (handler-case
                                  (taf.core::%with-operation-progress (nil) (error expected))
                                (error (c) c)))))))

(deftest test-operation-progress-nesting-and-failure-cleanup ()
  (let ((text (%operation-test-display
               (lambda ()
                 (let ((outer taf.core::*operation-display*)
                       (inner nil)
                       (expected (make-condition 'simple-error :format-control "failure"))
                       (caught nil))
                   (handler-case
                       (taf.core::%with-operation-progress (nil)
                         (setf inner taf.core::*operation-display*)
                         (taf.core::%operation-stage "fetch")
                         (error expected))
                     (error (condition) (setf caught condition)))
                   (check-true (eq outer inner))
                   (check-true (eq expected caught))
                   (check-equal nil (taf.core::%operation-display-active-p outer)))) :terminal-p t)))
    (check-equal 1 (count #\Newline text))))

(deftest test-operation-progress-closed-stream-does-not-fail ()
  (let* ((out (make-string-output-stream))
         (taf.core::*operation-display* (taf.core::%make-operation-display :stream out :terminal-p t)))
    (close out)
    (check-equal :success
                 (taf.core::%with-operation-progress (nil)
                   (taf.core::%operation-stage "download")
                   :success))
    (check-true (taf.core::%operation-display-disabled-p taf.core::*operation-display*))))

(deftest test-operation-progress-deferred-fast-build ()
  (check-equal "" (%operation-test-display
                    (lambda () (taf.core::%operation-stage "snapshot" :defer-p t))))
  (check-true (search "snapshot" (%operation-test-display
                                  (lambda ()
                                    (decf (taf.core::%operation-display-started taf.core::*operation-display*)
                                          (* 2 internal-time-units-per-second))
                                    (taf.core::%operation-stage "snapshot" :defer-p t))))))
