;;; mcp-server-setting.el --- Emacs MCP server + custom tools  -*- lexical-binding: t -*-

;; Load wiki-tools for org structural editing helpers
(require 'wiki-tools)

;;; ── Helpers ──────────────────────────────────────────────────────────

(defvar mcp-server--pending-edit-info nil
  "Pending edit state for edit_buffer_with_preview: alist with symbol keys.")

(defun mcp--buf-ensure-open (file)
  "Return a live buffer for FILE; open silently if not already visiting."
  (or (find-buffer-visiting file)
      (find-file-noselect file t)))

(defun mcp--git-run (dir &rest args)
  "Run git ARGS in DIR and return trimmed stdout."
  (string-trim
   (shell-command-to-string
    (concat "git -C " (shell-quote-argument dir) " "
            (mapconcat #'shell-quote-argument args " ")
            " 2>/dev/null"))))

(defun mcp--imenu-format (alist prefix)
  "Recursively format imenu ALIST into a string with PREFIX indentation."
  (mapconcat
   (lambda (item)
     (cond
      ((imenu--subalist-p item)
       (concat prefix (car item) "\n"
               (mcp--imenu-format (cdr item) (concat prefix "  "))))
      ((markerp (cdr item))
       (format "%s%s (line %d)" prefix (car item)
               (with-current-buffer (marker-buffer (cdr item))
                 (line-number-at-pos (marker-position (cdr item))))))
      ((numberp (cdr item))
       (format "%s%s (line %d)" prefix (car item)
               (line-number-at-pos (cdr item))))
      (t (format "%s%s" prefix (car item)))))
   alist "\n"))

;;; ── Tool: get_project_context ────────────────────────────────────────

(defun mcp--handler-get-project-context (_args)
  (let* ((proj  (project-current))
         (root  (expand-file-name (if proj (project-root proj) default-directory)))
         (fbufs (seq-filter #'buffer-file-name (buffer-list)))
         (branch      (mcp--git-run root "rev-parse" "--abbrev-ref" "HEAD"))
         (last-commit (mcp--git-run root "log" "-1" "--format=%s")))
    (with-current-buffer (current-buffer)
      (format
       "Project root : %s\nGit branch   : %s\nLast commit  : %s\nCurrent file : %s\nCursor       : line %d, col %d\n\nOpen buffers (%d):\n%s"
       root branch last-commit
       (or (buffer-file-name) "(no file)")
       (line-number-at-pos) (current-column)
       (length fbufs)
       (mapconcat (lambda (b)
                    (format "  %s [%s]"
                            (buffer-file-name b)
                            (with-current-buffer b (symbol-name major-mode))))
                  fbufs "\n")))))

;;; ── Tool: get_project_structure ──────────────────────────────────────

(defun mcp--handler-get-project-structure (args)
  (let* ((depth (or (cdr (assoc "max_depth" args)) 3))
         (proj  (project-current))
         (root  (expand-file-name (if proj (project-root proj) default-directory))))
    (shell-command-to-string
     (format
      (concat "find %s -maxdepth %d"
              " \\( -name '.git' -o -name 'node_modules'"
              " -o -name '.venv' -o -name '__pycache__'"
              " -o -name 'target' -o -name '.gradle' \\)"
              " -prune -o -print"
              " | sort | sed 's|%s/||' | head -500")
      (shell-quote-argument root) depth
      (shell-quote-argument root)))))

;;; ── Tool: get_open_buffers_with_symbols ──────────────────────────────

(defun mcp--handler-get-open-buffers-with-symbols (_args)
  (let ((fbufs (seq-filter #'buffer-file-name (buffer-list))))
    (if (null fbufs)
        "No file buffers open."
      (mapconcat
       (lambda (buf)
         (let ((file (buffer-file-name buf))
               (mode (with-current-buffer buf (symbol-name major-mode)))
               (syms (condition-case nil
                         (with-current-buffer buf
                           (let* ((raw (imenu--make-index-alist t))
                                  (idx (seq-remove (lambda (i) (equal (cdr i) -99)) raw)))
                             (if idx (mcp--imenu-format idx "    ") "    (none)")))
                       (error "    (imenu error)"))))
           (format "── %s [%s]\n%s" file mode syms)))
       fbufs "\n\n"))))

;;; ── Tool: get_diagnostics_all ────────────────────────────────────────

(defun mcp--handler-get-diagnostics-all (_args)
  (let ((fbufs (seq-filter #'buffer-file-name (buffer-list)))
        results)
    (dolist (buf fbufs)
      (with-current-buffer buf
        (let ((file (buffer-file-name))
              errs)
          ;; Flycheck
          (when (and (bound-and-true-p flycheck-mode)
                     (boundp 'flycheck-current-errors))
            (dolist (e flycheck-current-errors)
              (push (format "  [%s] line %d: %s"
                            (flycheck-error-level e)
                            (flycheck-error-line e)
                            (flycheck-error-message e))
                    errs)))
          ;; Flymake
          (when (and (bound-and-true-p flymake-mode)
                     (fboundp 'flymake-diagnostics))
            (dolist (d (flymake-diagnostics))
              (push (format "  [%s] line %d: %s"
                            (flymake-diagnostic-type d)
                            (line-number-at-pos (flymake-diagnostic-beg d))
                            (flymake-diagnostic-text d))
                    errs)))
          (when errs
            (push (concat file ":\n"
                          (mapconcat #'identity (nreverse errs) "\n"))
                  results)))))
    (if results
        (mapconcat #'identity (nreverse results) "\n\n")
      "No diagnostics found.")))

;;; ── Tool: find_definition ────────────────────────────────────────────

(defun mcp--xref-location-string (loc)
  (cond
   ((xref-file-location-p loc)
    (format "%s:%d" (xref-file-location-file loc) (xref-file-location-line loc)))
   (t (format "%s" loc))))

(defun mcp--handler-find-definition (args)
  (let* ((file (cdr (assoc "file" args)))
         (line (or (cdr (assoc "line" args)) 1))
         (col  (or (cdr (assoc "column" args)) 0))
         (buf  (mcp--buf-ensure-open file)))
    (with-current-buffer buf
      (save-excursion
        (goto-char (point-min))
        (forward-line (1- line))
        (forward-char (min col (- (line-end-position) (point))))
        (let* ((id      (thing-at-point 'symbol t))
               (backend (xref-find-backend))
               (defs    (and id backend
                             (condition-case nil
                                 (xref-backend-definitions backend id)
                               (error nil)))))
          (cond
           ((null id)    "No symbol at position.")
           ((null defs)  (format "No definition found for '%s'." id))
           (t (mapconcat (lambda (x)
                           (mcp--xref-location-string (xref-item-location x)))
                         defs "\n"))))))))

;;; ── Tool: find_references ────────────────────────────────────────────

(defun mcp--handler-find-references (args)
  (let* ((file (cdr (assoc "file" args)))
         (line (or (cdr (assoc "line" args)) 1))
         (col  (or (cdr (assoc "column" args)) 0))
         (buf  (mcp--buf-ensure-open file)))
    (with-current-buffer buf
      (save-excursion
        (goto-char (point-min))
        (forward-line (1- line))
        (forward-char (min col (- (line-end-position) (point))))
        (let* ((id      (thing-at-point 'symbol t))
               (backend (xref-find-backend))
               (refs    (and id backend
                             (condition-case nil
                                 (xref-backend-references backend id)
                               (error nil)))))
          (cond
           ((null id)   "No symbol at position.")
           ((null refs) (format "No references found for '%s'." id))
           (t (mapconcat (lambda (x)
                           (mcp--xref-location-string (xref-item-location x)))
                         refs "\n"))))))))

;;; ── Tool: get_imenu_symbols ──────────────────────────────────────────

(defun mcp--handler-get-imenu-symbols (args)
  (let* ((file (cdr (assoc "file" args)))
         (buf  (mcp--buf-ensure-open file)))
    (with-current-buffer buf
      (condition-case err
          (let* ((raw (imenu--make-index-alist t))
                 (idx (seq-remove (lambda (i) (equal (cdr i) -99)) raw)))
            (if idx
                (mcp--imenu-format idx "")
              "No symbols found."))
        (error (format "imenu error: %s" err))))))

;;; ── Tool: get_tree_sitter_node ───────────────────────────────────────

(defun mcp--handler-get-tree-sitter-node (args)
  (let* ((file (cdr (assoc "file" args)))
         (line (or (cdr (assoc "line" args)) 1))
         (col  (or (cdr (assoc "column" args)) 0))
         (buf  (mcp--buf-ensure-open file)))
    (with-current-buffer buf
      (cond
       ((not (fboundp 'treesit-available-p))
        "Tree-sitter not compiled into this Emacs.")
       ((not (treesit-available-p))
        "Tree-sitter not available in this buffer.")
       (t
        (save-excursion
          (goto-char (point-min))
          (forward-line (1- line))
          (forward-char (min col (- (line-end-position) (point))))
          (let ((node (treesit-node-at (point))))
            (if node
                (format "type : %s\ntext : %s\nrange: %d-%d"
                        (treesit-node-type node)
                        (treesit-node-text node t)
                        (treesit-node-start node)
                        (treesit-node-end node))
              "No tree-sitter node at position."))))))))

;;; ── Tool: agent_shell_org_report ────────────────────────────────────

(defvar mcp-server--report-buffers nil
  "List of dynamically created report buffer names.")

(defun mcp--handler-agent-shell-org-report (args)
  "Create a temporary org-mode report buffer.
ARGS should contain 'topic' and 'content' keys.
Returns the buffer name and visibility status."
  (let* ((topic (cdr (assoc "topic" args)))
         (content (cdr (assoc "content" args)))
         (buf-name (if topic
                       (format "*Agent Report: %s*" topic)
                     (format "*Agent Report: %s*"
                             (format-time-string "%Y-%m-%d %H:%M")))))
    (unless content
      (error "Content is required for org report"))
    ;; Kill existing buffer with same name if present
    (when (get-buffer buf-name)
      (kill-buffer buf-name))
    ;; Create new org buffer
    (let ((buf (get-buffer-create buf-name)))
      (with-current-buffer buf
        (org-mode)
        (insert "#+title: " (or topic "Agent Report") "\n")
        (insert "#+date: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n")
        (insert "#+startup: overview\n\n")
        (insert content)
        (goto-char (point-min))
        (setq buffer-read-only t))
      (add-to-list 'mcp-server--report-buffers buf-name)
      ;; Display buffer in a window
      (switch-to-buffer buf)
      (format "Report buffer created: %s\nBuffer is read-only. Use C-x C-q to edit if needed." buf-name))))

;;; ── Tool: edit_buffer_with_preview ──────────────────────────────────

(defun mcp--ediff-accept-and-quit ()
  "Apply pending MCP edit to the target buffer and quit ediff."
  (interactive)
  (if (null mcp-server--pending-edit-info)
      (message "No pending MCP edit.")
    (let-alist mcp-server--pending-edit-info
      (with-current-buffer .target-buf
        (erase-buffer)
        (insert .new-content))
      (let ((old-b .old-buf)
            (new-b .new-buf)
            (tgt   (buffer-name .target-buf)))
        (setq mcp-server--pending-edit-info nil)
        (ignore-errors (ediff-quit nil))
        (dolist (b (list old-b new-b))
          (when (buffer-live-p b) (kill-buffer b)))
        (message "MCP edit applied to %s" tgt)))))

(defun mcp--ediff-setup-keys ()
  "Bind C-c C-c in the ediff control panel to accept the MCP edit."
  (define-key ediff-mode-map (kbd "C-c C-c") #'mcp--ediff-accept-and-quit))

(defun mcp--handler-edit-buffer-with-preview (args)
  (let* ((buf-name    (cdr (assoc "buffer_name" args)))
         (new-content (cdr (assoc "new_content" args)))
         (target-buf  (get-buffer buf-name)))
    (unless target-buf
      (error "Buffer not found: %s" buf-name))
    (let* ((mode    (with-current-buffer target-buf major-mode))
           (old-buf (generate-new-buffer (format " *mcp-old:%s*" buf-name)))
           (new-buf (generate-new-buffer (format " *mcp-new:%s*" buf-name))))
      (with-current-buffer old-buf
        (insert (with-current-buffer target-buf (buffer-string)))
        (ignore-errors (funcall mode)))
      (with-current-buffer new-buf
        (insert new-content)
        (ignore-errors (funcall mode)))
      (setq mcp-server--pending-edit-info
            `((target-buf  . ,target-buf)
              (old-buf     . ,old-buf)
              (new-buf     . ,new-buf)
              (new-content . ,new-content)))
      (ediff-buffers old-buf new-buf '(mcp--ediff-setup-keys))
      "ediff opened — C-c C-c: apply, q: cancel")))

;;; ── Helpers ──────────────────────────────────────────────────────────

(defun mcp--suppress-process-queries ()
  "Prevent MCP server processes from prompting on Emacs exit."
  (dolist (proc (process-list))
    (when (string-match-p "mcp" (process-name proc))
      (set-process-query-on-exit-flag proc nil))))

;;; ── Dependency check ─────────────────────────────────────────────────

;; exec-path-from-shell이 startup hook에서 초기화되므로 같은 시점에 확인
(add-hook 'emacs-startup-hook
          (lambda ()
            (unless (executable-find "socat")
              (display-warning
               'mcp-server
               "socat가 설치되어 있지 않습니다.
Claude Code에서 emacs MCP 서버에 연결하려면 socat이 필요합니다.

설치 방법: brew install socat"
               :warning))))

;;; ── Package + server configuration ──────────────────────────────────

(use-package mcp-server
  :straight (mcp-server :type git :host github :repo "rhblind/emacs-mcp-server"
                        :files (:defaults "tools/*.el"))
  :vc (:url "https://github.com/rhblind/emacs-mcp-server" :rev :newest)
  :config
  ;; Socket lives inside ~/.emacs.d/.local/cache/
  (make-directory (expand-file-name ".local/cache/" user-emacs-directory) t)
  (setq mcp-server-socket-directory
        (expand-file-name ".local/cache/" user-emacs-directory))

  ;; Dangerous operations are blocked without prompting.
  ;; agent-shell permission UI가 1차 필터 역할을 하므로
  ;; MCP 보안 레이어의 minibuffer 프롬프트는 비활성화 (이중 프롬프트 방지)
  (setq mcp-server-security-prompt-for-permissions nil)

  ;; Block access to credentials / secrets
  (setq mcp-server-security-sensitive-file-patterns
        '("~/.authinfo*" "~/.netrc*" "~/.ssh/" "~/.gnupg/"
          "~/.aws/" "~/.docker/config.json" "~/.kube/config"
          "~/.npmrc" "~/.pypirc" "*.env" "*.pem" "*.key"
          "*secret*" "*password*" "*credential*" "*token*"
          "~/.config/opencode/opencode.json" "~/Keys/"))

  ;; Enable all built-in Emacs tools (eval-elisp included)
  (setq mcp-server-emacs-tools-enabled 'all)

  ;; ── Register custom tools ──────────────────────────────────────────

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_project_context"
    :title "Get Project Context"
    :description "세션 시작 시 첫 호출 툴. 프로젝트 루트, 열린 버퍼, 커서 위치, git branch/commit 반환."
    :input-schema '((type . "object"))
    :function #'mcp--handler-get-project-context))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_project_structure"
    :title "Get Project Structure"
    :description "프로젝트 디렉토리 트리 반환. .git/node_modules/.venv 등 제외. LS/Glob 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((max_depth . ((type . "integer")
                                     (description . "최대 탐색 깊이 (기본 3)"))))))
    :function #'mcp--handler-get-project-structure))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_open_buffers_with_symbols"
    :title "Get Open Buffers with Symbols"
    :description "열린 모든 파일 버퍼의 경로+major-mode+imenu 심볼 계층을 한 번에 반환. Read 대체."
    :input-schema '((type . "object"))
    :function #'mcp--handler-get-open-buffers-with-symbols))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_diagnostics_all"
    :title "Get All Diagnostics"
    :description "열린 모든 버퍼의 Flycheck/Flymake 에러·경고 파일별 집계. Bash build 대체."
    :input-schema '((type . "object"))
    :function #'mcp--handler-get-diagnostics-all))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "find_definition"
    :title "Find Definition"
    :description "파일의 line/col 위치 심볼을 xref로 정의 탐색. Grep 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((file   . ((type . "string")  (description . "절대 파일 경로")))
                        (line   . ((type . "integer") (description . "줄 번호 (1-based)")))
                        (column . ((type . "integer") (description . "열 번호 (0-based)")))))
                    (required . ["file" "line" "column"]))
    :function #'mcp--handler-find-definition))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "find_references"
    :title "Find References"
    :description "파일의 line/col 위치 심볼을 xref로 참조 탐색. Grep 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((file   . ((type . "string")  (description . "절대 파일 경로")))
                        (line   . ((type . "integer") (description . "줄 번호 (1-based)")))
                        (column . ((type . "integer") (description . "열 번호 (0-based)")))))
                    (required . ["file" "line" "column"]))
    :function #'mcp--handler-find-references))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_imenu_symbols"
    :title "Get Imenu Symbols"
    :description "파일의 함수/클래스/변수 심볼 계층을 imenu로 반환. 전체 Read 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))))
                    (required . ["file"]))
    :function #'mcp--handler-get-imenu-symbols))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "get_tree_sitter_node"
    :title "Get Tree-sitter Node"
    :description "파일 line/col의 Tree-sitter AST 노드 타입·텍스트 반환. Read 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((file   . ((type . "string")  (description . "절대 파일 경로")))
                        (line   . ((type . "integer") (description . "줄 번호 (1-based)")))
                        (column . ((type . "integer") (description . "열 번호 (0-based)")))))
                    (required . ["file" "line" "column"]))
    :function #'mcp--handler-get-tree-sitter-node))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "edit_buffer_with_preview"
    :title "Edit Buffer with Preview"
    :description "버퍼 수정을 ediff로 미리 보여준 뒤 사용자 승인(C-c C-c) 후 적용. eval-elisp 직접 수정 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((buffer_name . ((type . "string") (description . "수정할 버퍼 이름")))
                        (new_content . ((type . "string") (description . "새 전체 내용")))))
                    (required . ["buffer_name" "new_content"]))
    :function #'mcp--handler-edit-buffer-with-preview))

  ;; ── Org structural editing helpers (wiki-tools.el) ─────────────────

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_find_heading"
    :title "Find Org Heading"
    :description "Org 파일에서 특정 heading의 위치 범위를 반환. heading 존재 확인용."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (heading_title . ((type . "string") (description . "검색할 heading 제목")))))
                    (required . ["file" "heading_title"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (title (cdr (assoc "heading_title" args)))
                       (result (wiki-org-find-heading file title)))
                  (if result
                      (format "Found: start=%d, end=%d" (car result) (cdr result))
                    (format "Heading '%s' not found in %s" title file))))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_heading_exists_p"
    :title "Check Org Heading Exists"
    :description "Org 파일에 특정 heading이 있는지 확인."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (heading_title . ((type . "string") (description . "검색할 heading 제목")))))
                    (required . ["file" "heading_title"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (title (cdr (assoc "heading_title" args)))
                       (exists (wiki-org-heading-exists-p file title)))
                  (if exists "true" "false")))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_insert_heading_after"
    :title "Insert Org Heading After"
    :description "특정 heading 바로 뒤에 새 heading을 삽입. eval-elisp fallback 대체."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (after_heading . ((type . "string") (description . "이 heading 뒤에 삽입")))
                        (new_heading . ((type . "string") (description . "새 heading 제목")))
                        (body . ((type . "string") (description . "heading 아래 본문 (선택사항)")))))
                    (required . ["file" "after_heading" "new_heading"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (after (cdr (assoc "after_heading" args)))
                       (new (cdr (assoc "new_heading" args)))
                       (body (cdr (assoc "body" args))))
                  (wiki-org-insert-heading-after file after new body)
                  "OK"))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_append_to_heading"
    :title "Append to Org Heading"
    :description "기존 heading body 끝에 텍스트 추가."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (heading_title . ((type . "string") (description . "대상 heading 제목")))
                        (text . ((type . "string") (description . "추가할 텍스트")))))
                    (required . ["file" "heading_title" "text"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (title (cdr (assoc "heading_title" args)))
                       (text (cdr (assoc "text" args))))
                  (wiki-org-append-to-heading file title text)
                  "OK"))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_replace_heading_body"
    :title "Replace Org Heading Body"
    :description "heading body 전체를 새 내용으로 교체."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (heading_title . ((type . "string") (description . "대상 heading 제목")))
                        (new_body . ((type . "string") (description . "새 body 내용")))))
                    (required . ["file" "heading_title" "new_body"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (title (cdr (assoc "heading_title" args)))
                       (body (cdr (assoc "new_body" args))))
                  (wiki-org-replace-heading-body file title body)
                  "OK"))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "org_insert_child_heading"
    :title "Insert Child Org Heading"
    :description "부모 heading 아래 자식 heading을 적절한 들여쓰기로 삽입."
    :input-schema '((type . "object")
                    (properties
                     . ((file . ((type . "string") (description . "절대 파일 경로")))
                        (parent_heading . ((type . "string") (description . "부모 heading 제목")))
                        (child_heading . ((type . "string") (description . "자식 heading 제목")))
                        (body . ((type . "string") (description . "자식 heading 본문 (선택사항)")))))
                    (required . ["file" "parent_heading" "child_heading"]))
    :function (lambda (args)
                (let* ((file (cdr (assoc "file" args)))
                       (parent (cdr (assoc "parent_heading" args)))
                       (child (cdr (assoc "child_heading" args)))
                       (body (cdr (assoc "body" args))))
                  (wiki-org-insert-child-heading file parent child body)
                  "OK"))))

  (mcp-server-register-tool
   (make-mcp-server-tool
    :name "agent_shell_org_report"
    :title "Agent Shell Org Report"
    :description "AI가 동적으로 org 보고서를 임시 버퍼에 생성. Plan/viewport 컨텍스트에서 사용."
    :input-schema '((type . "object")
                    (properties
                     . ((topic . ((type . "string") (description . "보고서 주제")))
                        (content . ((type . "string") (description . "org 형식 본문")))))
                    (required . ["topic" "content"]))
    :function #'mcp--handler-agent-shell-org-report))


  ;; Start the Unix socket server after Emacs is fully loaded.
  (add-hook 'emacs-startup-hook
            (lambda ()
              (condition-case err
                  (progn
                    (mcp-server-start-unix)
                    (mcp--suppress-process-queries))
                (error (message "emacs-mcp-server start failed: %s" err)))))

  ;; Also suppress query flag on client processes created after connection.
  (advice-add 'mcp-server-transport-unix--server-filter :after
              (lambda (&rest _) (mcp--suppress-process-queries))))

(provide 'mcp-server-setting)
