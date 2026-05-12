(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / server.lisp
;;;; ============================================================

(defun %string-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun %handle-request (message)
  (unless (han.json:json-object-p message)
    (return-from %handle-request
      (%json-rpc-error :null -32600 "Invalid Request")))
  (let* ((id (%json-id message))
         (method (%json-string message "method"))
         (params (%json-object-field message "params")))
    (cond
      ((null method)
       (%json-rpc-error id -32600 "Invalid Request: missing method"))
      ((and (not (%request-p message))
            (%string-prefix-p "notifications/" method))
       nil)
      ((and (not (%request-p message))
            (not (string= method "initialize")))
       nil)
      ((string= method "initialize")
       (%json-rpc-response id (%initialize-result params)))
      ((string= method "ping")
       (%json-rpc-response id (%empty-result)))
      ((string= method "tools/list")
       (%json-rpc-response id (tools-list)))
      ((string= method "tools/call")
       (let ((name (%json-string params "name"))
             (arguments (%json-object-field params "arguments")))
         (if name
             (%json-rpc-response id (call-tool name arguments))
             (%json-rpc-error id -32602 "Invalid params: missing tool name"))))
      ((string= method "resources/list")
       (%json-rpc-response id (resources-list)))
      ((string= method "resources/read")
       (let ((uri (%json-string params "uri")))
         (if uri
             (%json-rpc-response id (read-resource uri))
             (%json-rpc-error id -32602 "Invalid params: missing resource uri"))))
      ((string= method "prompts/list")
       (%json-rpc-response id (prompts-list)))
      ((string= method "prompts/get")
       (let ((name (%json-string params "name"))
             (arguments (%json-object-field params "arguments")))
         (if name
             (%json-rpc-response id (get-prompt name arguments))
             (%json-rpc-error id -32602 "Invalid params: missing prompt name"))))
      (t
       (%json-rpc-error id -32601 (format nil "Method not found: ~A" method))))))

(defun handle-json-rpc-message (message)
  (handler-case
      (if (han.json:json-array-p message)
          (let ((responses nil))
            (loop for i from 0 below (length message)
                  for response = (%handle-request (aref message i))
                  when response do (push response responses))
            (and responses (coerce (nreverse responses) 'vector)))
          (%handle-request message))
    (han.json:json-error (c)
      (%json-rpc-error :null -32700 (format nil "Parse error: ~A" c)))
    (error (c)
      (%json-rpc-error :null -32603 (format nil "Internal error: ~A" c)))))

(defun handle-json-rpc-string (string)
  (let ((response (handler-case
                      (handle-json-rpc-message (han.json:parse-json string))
                    (han.json:json-error (c)
                      (%json-rpc-error :null -32700
                                       (format nil "Parse error: ~A" c))))))
    (and response (%compact-json response))))

(defun %server-log (format-control &rest args)
  (apply #'format *error-output* format-control args)
  (finish-output *error-output*))

(defun %write-response (response)
  (when response
    (write-string (%compact-json response) *standard-output*)
    (write-char #\Newline *standard-output*)
    (finish-output *standard-output*)))

(defun run-stdio-server ()
  (%server-log "[TAFFISH-MCP] stdio server started.~%")
  (loop for line = (read-line *standard-input* nil nil)
        while line do
          (unless (string= line "")
            (%write-response
             (handler-case
                 (handle-json-rpc-message (han.json:parse-json line))
               (han.json:json-error (c)
                 (%json-rpc-error :null -32700
                                  (format nil "Parse error: ~A" c)))
               (error (c)
                 (%json-rpc-error :null -32603
                                  (format nil "Internal error: ~A" c)))))))
  (%server-log "[TAFFISH-MCP] stdio server stopped.~%"))
