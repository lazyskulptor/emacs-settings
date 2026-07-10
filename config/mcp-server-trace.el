;;; mcp-server-trace.el --- MCP server call tracing to file  -*- lexical-binding: t; -*-

;;; Commentary:
;; 모든 MCP tool 호출을 로그 파일에 기록한다.
;; 등록 시점에 handler 함수를 자동 감싸서(advice-add :filter-return on
;; mcp-server-register-tool) 에러와 성공 여부를 투명하게 추적한다.

;;; Code:

(require 'mcp-server-tools)

;; ── Settings ──────────────────────────────────────────────────────────

(defcustom mcp-trace-log-file
  (expand-file-name ".local/cache/mcp-server-trace.log" user-emacs-directory)
  "MCP server trace log file path."
  :type 'string
  :group 'mcp-server)

(defcustom mcp-trace-max-size (* 1024 1024)
  "Maximum log file size in bytes before truncation (default 1MB)."
  :type 'integer
  :group 'mcp-server)

;; ── Core ──────────────────────────────────────────────────────────────

(defun mcp-trace--rotate-if-needed ()
  "Truncate log to last half of lines when over `mcp-trace-max-size'."
  (when (and (file-exists-p mcp-trace-log-file)
             (> (file-attribute-size (file-attributes mcp-trace-log-file))
                mcp-trace-max-size))
    (let* ((content (with-temp-buffer
                      (insert-file-contents mcp-trace-log-file)
                      (buffer-string)))
           (lines (split-string content "\n" t))
           (keep (nthcdr (max 1 (/ (length lines) 2)) lines)))
      (with-temp-file mcp-trace-log-file
        (insert (mapconcat #'identity keep "\n"))
        (insert "\n")))))

(defun mcp-trace--log (tool-name start elapsed &optional error-msg)
  "Append one trace line to log file.
TOOL-NAME: string, START: current-time value, ELAPSED: float seconds.
ERROR-MSG: nil on success, string on failure."
  (let* ((timestamp (format-time-string "%Y-%m-%dT%H:%M:%S.%3N" start))
         (status (if error-msg "ERROR" "OK"))
         (line (format "%s | %-22s | %.3fs | %s\n"
                       timestamp tool-name elapsed status)))
    (with-temp-buffer
      (insert line)
      (when error-msg
        (insert (format "  Error: %s\n" error-msg)))
      (append-to-file (point-min) (point-max) mcp-trace-log-file))
    (mcp-trace--rotate-if-needed)))

(defun mcp-trace--wrap-handler (tool-name fn)
  "Return wrapped version of FN logging timing and errors.
On error, logs the error message and re-signals so MCP server's own
error handler still works normally."
  (lambda (args)
    (let* ((start (current-time))
           result done)
      (condition-case err
          (setq result (funcall fn args)
                done t)
        (error
         (mcp-trace--log tool-name start
                         (float-time (time-subtract (current-time) start))
                         (error-message-string err))
         (signal (car err) (cdr err))))
      (when done
        (mcp-trace--log tool-name start
                        (float-time (time-subtract (current-time) start))
                        nil))
      result)))

(defun mcp-trace--on-register (tool)
  ":filter-return advice for `mcp-server-register-tool'.
Wraps each tool's :function with tracing."
  (let ((fn (mcp-server-tool-function tool)))
    (when fn
      (let ((name (mcp-server-tool-name tool)))
        (setf (mcp-server-tool-function tool)
              (mcp-trace--wrap-handler name fn)))))
  tool)

;; ── Activation ────────────────────────────────────────────────────────

;;;###autoload
(defun mcp-trace-enable ()
  "Enable MCP server call tracing.
Every registered tool call will be logged to `mcp-trace-log-file'."
  (interactive)
  (advice-add 'mcp-server-register-tool :filter-return
              #'mcp-trace--on-register)
  (message "MCP trace enabled — logging to %s" mcp-trace-log-file))

;;;###autoload
(defun mcp-trace-disable ()
  "Disable MCP server call tracing."
  (interactive)
  (advice-remove 'mcp-server-register-tool
                 #'mcp-trace--on-register)
  (message "MCP trace disabled."))

(defun mcp-trace--wrap-existing-tools ()
  "Wrap handler functions of tools already registered before this module loaded.
Needed because `mcp-server-setting' registers tools during its :config block,
which runs before this module is loaded."
  (dolist (name (mcp-server-tools-list-names))
    (let* ((tool (mcp-server-tools-get name))
           (fn (mcp-server-tool-function tool)))
      (when fn
        (setf (mcp-server-tool-function tool)
              (mcp-trace--wrap-handler name fn))))))

;; Enable by default when this file is loaded
(mcp-trace-enable)
(mcp-trace--wrap-existing-tools)

(provide 'mcp-server-trace)
;;; mcp-server-trace.el ends here
