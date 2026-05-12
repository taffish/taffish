(in-package :han.args)

;;;; ============================================================
;;;; bind.lisp
;;;; ============================================================

(defstruct arg-binding
  name
  spec
  value
  status) ;; :input | :default | :missing | :conflict

(defstruct args-result
  spec
  input
  builtin-bindings  ;; $0 | *argv* | ...?
  bindings          ;; hash-table: name -> arg-binding
  diagnostics)

(defstruct binding-candidate
  kind          ;; :long | :short | :slot | :position
  spec
  value
  position)

(defun %make-bind-diagnostic (kind code message &optional position)
  (make-arg-diagnostic
   :kind kind
   :code code
   :message message
   :position position))

(defun %push-bind-diagnostic (diagnostic diagnostics)
  (push diagnostic diagnostics))

(defun %token-at (args-input position)
  (aref (args-input-tokens args-input) position))

(defun %segment-tokens (args-input segment)
  (mapcar (lambda (pos) (%token-at args-input pos))
          (arg-segment-positions segment)))

(defun %slot-entry-name (slot-entry)
  "Convert a slot-entry string like \"@blast:\" into the inner slot name \"blast\".
Returns NIL for invalid input or the default slot entry \"@:\"."
  (when slot-entry
    (let ((len (length slot-entry)))
      (when (and (>= len 2)
                 (char= #\@ (char slot-entry 0))
                 (char= #\: (char slot-entry (1- len))))
        (if (= len 2)
            nil
            (subseq slot-entry 1 (1- len)))))))

(defun %token-entry-string (token)
  (case (arg-token-kind token)
    (:long-option
     (format nil "--~A" (arg-token-value token)))
    (:short-option
     (format nil "-~A" (arg-token-value token)))
    (:slot-switch
     (if (arg-token-value token)
         (format nil "@~A:" (arg-token-value token))
         "@:"))
    (otherwise
     nil)))

(defun %spec-matches-long-token-p (spec token)
  (and (arg-spec-long-entry spec)
       (eql :long-option (arg-token-kind token))
       (arg-key-equal (arg-spec-long-entry spec)
                      (%token-entry-string token))))

(defun %spec-matches-short-token-p (spec token)
  (and (arg-spec-short-entry spec)
       (eql :short-option (arg-token-kind token))
       (arg-key-equal (arg-spec-short-entry spec)
                      (%token-entry-string token))))

(defun %spec-matches-slot-segment-p (spec segment)
  (and (arg-spec-slot-entry spec)
       (eql :block (arg-spec-arity spec))
       (arg-key-equal (%slot-entry-name (arg-spec-slot-entry spec))
                      (arg-segment-slot segment))))

(defun %find-spec-by-option-token (args-spec token)
  "Find the single spec matched by TOKEN as a long/short option.
Returns NIL if none matched. Signals an error if multiple specs match."
  (let ((matched nil))
    (maphash
     (lambda (name spec)
       (declare (ignore name))
       (when (or (%spec-matches-long-token-p spec token)
                 (%spec-matches-short-token-p spec token))
         (if matched
             (error "Internal spec ambiguity: token ~S matched multiple specs."
                    (arg-token-text token))
             (setf matched spec))))
     (args-spec-args-table args-spec))
    matched))

(defun %find-spec-by-slot-segment (args-spec segment)
  "Find the single block spec matched by SEGMENT.
Returns NIL if none matched. Signals an error if multiple specs match."
  (let ((matched nil))
    (maphash
     (lambda (name spec)
       (declare (ignore name))
       (when (%spec-matches-slot-segment-p spec segment)
         (if matched
             (error "Internal spec ambiguity: slot segment ~S matched multiple specs."
                    (arg-segment-slot segment))
             (setf matched spec))))
     (args-spec-args-table args-spec))
    matched))

(defun %candidate-map-push (candidate-map candidate)
  (let* ((spec (binding-candidate-spec candidate))
         (name (arg-spec-name spec))
         (old (gethash name candidate-map)))
    (setf (gethash name candidate-map) (cons candidate old)))
  candidate-map)

(defun %spec-position-base (args-spec)
  "Return the minimum positional spec index, or NIL if no positional specs exist."
  (let ((min-pos nil))
    (maphash
     (lambda (name spec)
       (when (eql :position (arg-spec-arity spec))
         (unless (numberp name)
           (error "Internal spec error: positional arg-spec name ~S is not a number."
                  name))
         (if min-pos
             (setf min-pos (min min-pos name))
             (setf min-pos name))))
     (args-spec-args-table args-spec))
    min-pos))

(defun %collect-input-candidates (args-spec args-input)
  "Phase 1:
Scan ARGS-INPUT and build:
1. candidate-map : spec-name -> list[binding-candidate]
2. positional-pool : list of top-level free value tokens
3. diagnostics : list[arg-diagnostic]

Only values in NIL-slot segments that are not consumed by options are added to
the positional pool."
  (let ((candidate-map (make-hash-table :test #'equalp))
        (positional-pool nil)
        (diagnostics (copy-list (args-input-diagnostics args-input))))
    (dolist (segment (args-input-segments args-input))
      (if (null (arg-segment-slot segment))
          ;; NIL-slot: handle long/short options and collect free values.
          (let ((positions (arg-segment-positions segment)))
            (labels ((scan (rest-positions)
                       (when rest-positions
                         (let* ((pos (car rest-positions))
                                (token (%token-at args-input pos)))
                           (case (arg-token-kind token)
                             (:long-option
                              (let ((spec (%find-spec-by-option-token args-spec token)))
                                (if spec
                                    (case (arg-spec-arity spec)
                                      (:flag
                                       (%candidate-map-push
                                        candidate-map
                                        (make-binding-candidate
                                         :kind :long
                                         :spec spec
                                         :value t
                                         :position pos))
                                       (scan (cdr rest-positions)))
                                      (:single
                                       (cond
                                         ((arg-token-extra token)
                                          (%candidate-map-push
                                           candidate-map
                                           (make-binding-candidate
                                            :kind :long
                                            :spec spec
                                            :value (arg-token-extra token)
                                            :position pos))
                                          (scan (cdr rest-positions)))
                                         ((and (cdr rest-positions)
                                               (eql :value
                                                    (arg-token-kind
                                                     (%token-at args-input
                                                                (cadr rest-positions)))))
                                          (%candidate-map-push
                                           candidate-map
                                           (make-binding-candidate
                                            :kind :long
                                            :spec spec
                                            :value (arg-token-value
                                                    (%token-at args-input
                                                               (cadr rest-positions)))
                                            :position pos))
                                          ;; consume option token + its value token
                                          (scan (cddr rest-positions)))
                                         (t
                                          (setf diagnostics
                                                (%push-bind-diagnostic
                                                 (%make-bind-diagnostic
                                                  :error
                                                  :missing-option-value
                                                  (format nil "Option ~A is missing its value."
                                                          (arg-token-text token))
                                                  pos)
                                                 diagnostics))
                                          (scan (cdr rest-positions)))))
                                      (t
                                       (error "Internal bind error: long token ~S matched non-option arity ~S."
                                              (arg-token-text token)
                                              (arg-spec-arity spec))))
                                    (progn
                                      (setf diagnostics
                                            (%push-bind-diagnostic
                                             (%make-bind-diagnostic
                                              :warning
                                              :undefined-option
                                              (format nil "Undefined option ~A will be ignored."
                                                      (arg-token-text token))
                                              pos)
                                             diagnostics))
                                      (scan (cdr rest-positions))))))
                             (:short-option
                              (let ((spec (%find-spec-by-option-token args-spec token)))
                                (if spec
                                    (case (arg-spec-arity spec)
                                      (:flag
                                       (%candidate-map-push
                                        candidate-map
                                        (make-binding-candidate
                                         :kind :short
                                         :spec spec
                                         :value t
                                         :position pos))
                                       (scan (cdr rest-positions)))
                                      (:single
                                       (cond
                                         ((arg-token-extra token)
                                          (%candidate-map-push
                                           candidate-map
                                           (make-binding-candidate
                                            :kind :short
                                            :spec spec
                                            :value (arg-token-extra token)
                                            :position pos))
                                          (scan (cdr rest-positions)))
                                         ((and (cdr rest-positions)
                                               (eql :value
                                                    (arg-token-kind
                                                     (%token-at args-input
                                                                (cadr rest-positions)))))
                                          (%candidate-map-push
                                           candidate-map
                                           (make-binding-candidate
                                            :kind :short
                                            :spec spec
                                            :value (arg-token-value
                                                    (%token-at args-input
                                                               (cadr rest-positions)))
                                            :position pos))
                                          (scan (cddr rest-positions)))
                                         (t
                                          (setf diagnostics
                                                (%push-bind-diagnostic
                                                 (%make-bind-diagnostic
                                                  :error
                                                  :missing-option-value
                                                  (format nil "Option ~A is missing its value."
                                                          (arg-token-text token))
                                                  pos)
                                                 diagnostics))
                                          (scan (cdr rest-positions)))))
                                      (t
                                       (error "Internal bind error: short token ~S matched non-option arity ~S."
                                              (arg-token-text token)
                                              (arg-spec-arity spec))))
                                    (progn
                                      (setf diagnostics
                                            (%push-bind-diagnostic
                                             (%make-bind-diagnostic
                                              :warning
                                              :undefined-option
                                              (format nil "Undefined option ~A will be ignored."
                                                      (arg-token-text token))
                                              pos)
                                             diagnostics))
                                      (scan (cdr rest-positions))))))
                             (:value
                              (push token positional-pool)
                              (scan (cdr rest-positions)))
                             (otherwise
                              (error "Internal bind error: unexpected token kind ~S in NIL-slot."
                                     (arg-token-kind token))))))))
              (scan positions)))
          ;; Non-NIL slot: treat as a block candidate.
          (let* ((slot-name (arg-segment-slot segment))
                 (spec (%find-spec-by-slot-segment args-spec segment))
                 (positions (arg-segment-positions segment))
                 (first-pos (and positions (car positions))))
            (if spec
                (%candidate-map-push
                 candidate-map
                 (make-binding-candidate
                  :kind :slot
                  :spec spec
                  :value (%segment-tokens args-input segment)
                  :position first-pos))
                (setf diagnostics
                      (%push-bind-diagnostic
                       (%make-bind-diagnostic
                        :warning
                        :undefined-option
                        (format nil "Undefined slot block @~A: will be ignored."
                                slot-name)
                        first-pos)
                       diagnostics))))))
    (values candidate-map
            (nreverse positional-pool)
            diagnostics)))

(defun %resolve-flag-binding (spec candidates diagnostics)
  (cond
    (candidates
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value t
       :status :input)
      diagnostics))
    ((not (null (arg-spec-default spec)))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value (arg-spec-default spec)
       :status :default)
      diagnostics))
    (t
     (when (arg-spec-required spec)
       (setf diagnostics
             (%push-bind-diagnostic
              (%make-bind-diagnostic
               :error
               :missing-required
               (format nil "Required flag argument ~A is missing."
                       (arg-spec-name spec)))
              diagnostics)))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value nil
       :status :missing)
      diagnostics))))

(defun %resolve-single-binding (spec candidates diagnostics)
  (cond
    ((null candidates)
     (if (not (null (arg-spec-default spec)))
         (values
          (make-arg-binding
           :name (arg-spec-name spec)
           :spec spec
           :value (arg-spec-default spec)
           :status :default)
          diagnostics)
         (progn
           (when (arg-spec-required spec)
             (setf diagnostics
                   (%push-bind-diagnostic
                    (%make-bind-diagnostic
                     :error
                     :missing-required
                     (format nil "Required argument ~A is missing."
                             (arg-spec-name spec)))
                    diagnostics)))
           (values
            (make-arg-binding
             :name (arg-spec-name spec)
             :spec spec
             :value nil
             :status :missing)
            diagnostics))))
    ((null (cdr candidates))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value (binding-candidate-value (car candidates))
       :status :input)
      diagnostics))
    (t
     (setf diagnostics
           (%push-bind-diagnostic
            (%make-bind-diagnostic
             :error
             :conflict
             (format nil "Single argument ~A was provided multiple times."
                     (arg-spec-name spec))
             (binding-candidate-position (car candidates)))
            diagnostics))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value nil
       :status :conflict)
      diagnostics))))

(defun %resolve-block-binding (spec candidates diagnostics)
  (cond
    ((null candidates)
     (if (not (null (arg-spec-default spec)))
         (values
          (make-arg-binding
           :name (arg-spec-name spec)
           :spec spec
           :value (arg-spec-default spec)
           :status :default)
          diagnostics)
         (progn
           (when (arg-spec-required spec)
             (setf diagnostics
                   (%push-bind-diagnostic
                    (%make-bind-diagnostic
                     :error
                     :missing-required
                     (format nil "Required block argument ~A is missing."
                             (arg-spec-name spec)))
                    diagnostics)))
           (values
            (make-arg-binding
             :name (arg-spec-name spec)
             :spec spec
             :value nil
             :status :missing)
            diagnostics))))
    ((null (cdr candidates))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value (binding-candidate-value (car candidates))
       :status :input)
      diagnostics))
    (t
     (setf diagnostics
           (%push-bind-diagnostic
            (%make-bind-diagnostic
             :error
             :conflict
             (format nil "Block argument ~A was provided multiple times."
                     (arg-spec-name spec))
             (binding-candidate-position (car candidates)))
            diagnostics))
     (values
      (make-arg-binding
       :name (arg-spec-name spec)
       :spec spec
       :value nil
       :status :conflict)
      diagnostics))))

(defun %resolve-position-binding (spec positional-pool position-base diagnostics)
  (let* ((spec-index (arg-spec-name spec))
         (offset (- spec-index position-base)))
    (cond
      ((minusp offset)
       (error "Internal bind error: positional index ~S is below base ~S."
              spec-index position-base))
      ((< offset (length positional-pool))
       (values
        (make-arg-binding
         :name spec-index
         :spec spec
         :value (arg-token-value (nth offset positional-pool))
         :status :input)
        diagnostics))
      ((not (null (arg-spec-default spec)))
       (values
        (make-arg-binding
         :name spec-index
         :spec spec
         :value (arg-spec-default spec)
         :status :default)
        diagnostics))
      (t
       (when (arg-spec-required spec)
         (setf diagnostics
               (%push-bind-diagnostic
                (%make-bind-diagnostic
                 :error
                 :missing-required
                 (format nil "Required positional argument $~A is missing."
                         spec-index))
                diagnostics)))
       (values
        (make-arg-binding
         :name spec-index
         :spec spec
         :value nil
         :status :missing)
        diagnostics)))))

(defun %sure-string (obj)
  (format nil "~A" obj))

(defun %first-value (args)
  (dolist (arg args)
    (unless (ignore-errors (member (char (string-trim " " arg) 0) (list #\-)))
      (return-from %first-value arg))))

(defun %build-builtin-bindings (builtin-bindings args-input)
  (labels ((bbb (name value)
             (setf (gethash name builtin-bindings)
                   (make-arg-binding :name name
                                     :value value
                                     :status :input))))
    (let ((raw-argv (args-input-raw-argv args-input)))
      (bbb 0 (args-input-raw-cmd args-input))
      (bbb "*ARGV*" (format nil "~{~A~^ ~}" raw-argv))
      (bbb "*USER*" (han.os:current-user))
      (bbb "*WORKDIR*" (%sure-string (truename ".")))
	      (bbb "*LOADDIR*" (%sure-string (ignore-errors
	                                      (let ((file
	                                              (han.host:file-exists-p
	                                               (han.path:absolute-pathname
	                                                (%first-value raw-argv)))))
                                        (and file
                                             (han.path:parent-directory-pathname
                                              file)))))))))

(defun bind-args (args-spec args-input &optional (builtin-table nil builtin-table-p))
  "Bind ARGS-INPUT against ARGS-SPEC and return an ARGS-RESULT."
  (multiple-value-bind (candidate-map positional-pool diagnostics)
      (%collect-input-candidates args-spec args-input)
    (let* ((builtin-bindings
             (if builtin-table-p
                 builtin-table
                 (make-hash-table :test #'equalp)))
           (bindings (make-hash-table :test #'equalp))
           (position-base (%spec-position-base args-spec))
           (max-pos-seen nil))
      ;; Resolve every spec into one final binding.
      (maphash
       (lambda (name spec)
         (let ((candidates (nreverse (copy-list (gethash name candidate-map))))
               (binding nil))
           (multiple-value-setq (binding diagnostics)
             (case (arg-spec-arity spec)
               (:flag
                (%resolve-flag-binding spec candidates diagnostics))
               (:single
                (%resolve-single-binding spec candidates diagnostics))
               (:block
                   (%resolve-block-binding spec candidates diagnostics))
               (:position
                (progn
                  (unless position-base
                    (error "Internal bind error: positional spec exists but no position base found."))
                  (setf max-pos-seen
                        (if max-pos-seen
                            (max max-pos-seen name)
                            name))
                  (%resolve-position-binding
                   spec positional-pool position-base diagnostics)))
               (otherwise
                (error "Internal bind error: unsupported arity ~S."
                       (arg-spec-arity spec)))))
           (setf (gethash name bindings) binding)))
       (args-spec-args-table args-spec))
      ;; Warn about extra positional inputs that are not covered by positional specs.
      (when positional-pool
        (let* ((used-count
                 (if (and position-base max-pos-seen)
                     (1+ (- max-pos-seen position-base))
                     0))
               (pool-len (length positional-pool)))
          (when (> pool-len used-count)
            (loop for i from used-count below pool-len
                  for token = (nth i positional-pool)
                  do (setf diagnostics
                           (%push-bind-diagnostic
                            (%make-bind-diagnostic
                             :warning
                             :unused-option
                             (format nil "Unused positional input ~A will be ignored."
                                     (arg-token-text token))
                             (arg-token-position token))
                            diagnostics))))))
      ;; 不自动构建但是保留接口，建议用户根据 context 上下文手动设置
      (make-args-result
       :spec args-spec
       :input args-input
       :builtin-bindings builtin-bindings
       :bindings bindings
       :diagnostics (nreverse diagnostics)))))
