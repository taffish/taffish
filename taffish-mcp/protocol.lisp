(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / protocol.lisp
;;;; ============================================================

(defparameter *taffish-mcp-version*
  "taffish-mcp 0.9.0 (2026-05, Kaiyuan Han)")

(defparameter *mcp-default-protocol-version* "2025-11-25")

(defun help (&optional (stream *standard-output*))
  (let ((text
          "taffish-mcp 0.9.0

Purpose:
  MCP stdio server for TAFFISH. It exposes conservative TAFFISH tools,
  compiler helpers, taf-app inspection helpers, project inspection helpers,
  smoke/trust metadata, resources, and prompts to MCP-compatible AI clients.

Transport:
  stdio JSON-RPC. stdout is reserved for MCP messages; logs go to stderr.

Safety:
  It does not expose run, publish, or container image build tools.
  Source/file compiler tools are read-only and never execute shell code.
  App invocation compile validates arguments and returns shell code, but never
  runs taf-apps.
  Smoke metadata is exposed as data only; MCP never runs smoke tests.
"))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (when stream
    (format stream "~A~%" *taffish-mcp-version*))
  *taffish-mcp-version*)

(defun %json-object (&rest pairs)
  (apply #'han.json:json-object pairs))

(defun %json-array (&rest values)
  (apply #'han.json:json-array values))

(defun %keyword-json-string (value)
  (string-downcase
   (substitute #\_ #\-
               (etypecase value
                 (keyword (symbol-name value))
                 (symbol (symbol-name value))))))

(defun %plist-p (value)
  (and (consp value)
       (evenp (length value))
       (loop for key in value by #'cddr
             always (or (keywordp key) (symbolp key)))))

(defun %plist-key-json-string (key)
  (etypecase key
    (string key)
    ((or keyword symbol) (%keyword-json-string key))))

(defun %mcp-json-value (value)
  (cond
    ((han.json:json-object-p value)
     value)
    ((han.json:json-array-p value)
     (coerce (loop for i from 0 below (length value)
                   collect (%mcp-json-value (aref value i)))
             'vector))
    ((null value)
     nil)
    ((%plist-p value)
     (let ((object (han.json:make-json-object)))
       (loop for (key val) on value by #'cddr do
         (han.json:set-json object
                            (%plist-key-json-string key)
                            (%mcp-json-value val)))
       object))
    ((listp value)
     (coerce (mapcar #'%mcp-json-value value) 'vector))
    ((pathnamep value)
     (han.path:->namestring value))
    ((or (stringp value)
         (numberp value)
         (eq value t)
         (eq value nil)
         (eq value :null))
     value)
    ((or (keywordp value) (symbolp value))
     (%keyword-json-string value))
    (t
     (princ-to-string value))))

(defun %compact-json (value)
  (han.json:encode-json (%mcp-json-value value) :indent nil))

(defun %json-get (object key &optional default)
  (han.json:get-json object key default))

(defun %json-string (object key &optional default)
  (let ((value (%json-get object key default)))
    (cond
      ((eq value :null) nil)
      ((null value) nil)
      ((stringp value) value)
      (t (princ-to-string value)))))

(defun %json-bool (object key &optional default)
  (multiple-value-bind (value present-p)
      (%json-get object key)
    (if present-p value default)))

(defun %json-int (object key &optional default)
  (let ((value (%json-get object key default)))
    (cond
      ((integerp value) value)
      ((and (stringp value)
            (ignore-errors (parse-integer value :junk-allowed nil)))
       (parse-integer value :junk-allowed nil))
      (t default))))

(defun %json-object-field (object key)
  (let ((value (%json-get object key (han.json:make-json-object))))
    (if (han.json:json-object-p value)
        value
        (han.json:make-json-object))))

(defun %json-string-array-or-single (object key)
  (multiple-value-bind (value present-p)
      (%json-get object key)
    (cond
      ((not present-p) nil)
      ((and (han.json:json-array-p value))
       (loop for i from 0 below (length value)
             for item = (aref value i)
             collect (if (stringp item) item (princ-to-string item))))
      ((stringp value) (list value))
      ((eq value :null) nil)
      ((null value) nil)
      (t (list (princ-to-string value))))))

(defun %json-id (message)
  (multiple-value-bind (id present-p)
      (%json-get message "id")
    (if present-p id :null)))

(defun %request-p (message)
  (multiple-value-bind (id present-p)
      (%json-get message "id")
    (declare (ignore id))
    present-p))

(defun %json-rpc-response (id result)
  (%json-object
   (cons "jsonrpc" "2.0")
   (cons "id" id)
   (cons "result" (%mcp-json-value result))))

(defun %json-rpc-error (id code message &optional data)
  (%json-object
   (cons "jsonrpc" "2.0")
   (cons "id" id)
   (cons "error"
         (%json-object
          (cons "code" code)
          (cons "message" message)
          (cons "data" (or data :null))))))

(defun %text-content (text)
  (%json-object
   (cons "type" "text")
   (cons "text" (or text ""))))

(defun %tool-result (text structured &key is-error)
  (%json-object
   (cons "content" (%json-array (%text-content text)))
   (cons "structuredContent" (%mcp-json-value structured))
   (cons "isError" (not (null is-error)))))

(defun %tool-success (text structured)
  (%tool-result text structured :is-error nil))

(defun %mcp-error-message (condition)
  (format nil "~A" condition))

(defun %mcp-error-kind (message &optional (default "error"))
  (cond
    ((or (search "already installed" message :test #'char-equal)
         (search "command already exists" message :test #'char-equal))
     "already-installed")
    ((or (search "No available container backend" message :test #'char-equal)
         (search "Forced container backend" message :test #'char-equal))
     "container-backend-unavailable")
    (t default)))

(defun %mcp-error-object (condition &optional (default-kind "error"))
  (let ((message (%mcp-error-message condition)))
    (list :kind (%mcp-error-kind message default-kind)
          :message message)))

(defun %tool-error (message &optional structured)
  (%tool-result (format nil "[TAFFISH-MCP-ERROR] ~A" message)
                (or structured
                    (list :ok nil
                          :error (%mcp-error-object message "mcp-error")))
                :is-error t))

(defun %business-error-result (condition)
  (%tool-error (%mcp-error-message condition)
               (list :ok nil
                     :error (%mcp-error-object condition "business-error"))))

(defun %initialize-result (params)
  (let ((client-version (%json-string params "protocolVersion")))
    (%json-object
     (cons "protocolVersion"
           (or client-version *mcp-default-protocol-version*))
     (cons "capabilities"
           (%json-object
            (cons "tools" (%json-object (cons "listChanged" nil)))
            (cons "resources" (%json-object (cons "listChanged" nil)))
            (cons "prompts" (%json-object (cons "listChanged" nil)))))
     (cons "serverInfo"
           (%json-object
            (cons "name" "taffish-mcp")
            (cons "title" "TAFFISH MCP Server")
            (cons "version" *taffish-mcp-version*)))
     (cons "instructions"
      "TAFFISH MCP exposes conservative local TAFFISH tools, including read-only TAF source/file validation, compilation, summarization, taf-app inspection, project inspection, and safe app invocation compilation. It does not expose run, publish, or container image build."))))

(defun %empty-result ()
  (han.json:make-json-object))
