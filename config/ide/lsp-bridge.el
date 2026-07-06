;;; lsp-bridge.el --- LSP Bridge core configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; lsp-bridge 핵심 설정 (서버 명령어, 단축키, peek)
;; 언어별 설정은 languages.el에 있음

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; Tree-sitter grammar 로드 경로
;; ─────────────────────────────────────────────────────────────

(add-to-list 'treesit-extra-load-path (expand-file-name "~/.emacs.d/tree-sitter/"))

;; ─────────────────────────────────────────────────────────────
;; lsp-bridge 설치
;; ─────────────────────────────────────────────────────────────

(use-package lsp-bridge
  :straight (lsp-bridge
             :type git
             :host github
             :repo "lazyskulptor/lsp-bridge"
             :branch "fix/org-babel-virtual-file"
             :files (:defaults "acm" "*.py" "langserver")
             :build (:not native-compile))
  :init
  (setq lsp-bridge-enable-with-tramp t)  ; TRAMP 지원 활성화
  (setq lsp-bridge-python-command (expand-file-name "~/.emacs.d/.venv/lsp-bridge/bin/python"))
  (setq lsp-bridge-user-langserver-dir (expand-file-name "~/.emacs.d/lsp-user-config"))
  :hook ((python-mode . lsp-bridge-mode)
         (python-ts-mode . lsp-bridge-mode)
         (go-mode . lsp-bridge-mode)
         (go-ts-mode . lsp-bridge-mode)
         (java-mode . lsp-bridge-mode)
         (java-ts-mode . lsp-bridge-mode)
         (js-mode . lsp-bridge-mode)
         (js-ts-mode . lsp-bridge-mode)
         (js2-mode . lsp-bridge-mode)
         (typescript-mode . lsp-bridge-mode)
         (typescript-ts-mode . lsp-bridge-mode)
         (json-mode . lsp-bridge-mode)
         (json-ts-mode . lsp-bridge-mode)
         (rjsx-mode . lsp-bridge-mode)
         (clojure-mode . lsp-bridge-mode)
         (clojure-ts-mode . lsp-bridge-mode)
         (clojurec-mode . lsp-bridge-mode)
         (clojurescript-mode . lsp-bridge-mode)
         (dart-mode . lsp-bridge-mode)
         (html-mode . lsp-bridge-mode)
          (yaml-ts-mode . lsp-bridge-mode)
          (bash-mode . lsp-bridge-mode)
          (bash-ts-mode . lsp-bridge-mode)
          (sh-mode . lsp-bridge-mode)
          (web-mode . lsp-bridge-mode)
          (emacs-lisp-mode . lsp-bridge-mode)
           (groovy-mode . lsp-bridge-mode)
           (lisp-interaction-mode . lsp-bridge-mode)
           (csharp-mode . lsp-bridge-mode)
           (csharp-ts-mode . lsp-bridge-mode))
  :config
  ;; Completion UI: corfu 사용
  (setq lsp-bridge-completion-ui 'corfu)

  ;; LSP 서버 준비 후 breadcrumb mode 재활성화
  (add-hook 'lsp-bridge-mode-hook
            (lambda ()
              (run-with-idle-timer 1 nil
                (lambda ()
                  (when (and lsp-bridge-mode
                             (not lsp-bridge-breadcrumb-mode)
                             (lsp-bridge-call-file-api-p))
                    (lsp-bridge-breadcrumb-mode 1))))))

  ;; ── Python (Pyright) ──────────────────────────────────────
  (setq lsp-bridge-python-multi-server-command
        '("pyright-langserver" "--stdio"))

  ;; ── Go (gopls) ────────────────────────────────────────────
  ;; 기본값 사용 (gopls)

  ;; ── Java (Eclipse JDT.LS) ─────────────────────────────────
  (setq lsp-bridge-java-multi-server-command
        (list "java"
              "-Declipse.application=org.eclipse.jdt.ls.core.id1"
              "-Dosgi.bundles.defaultStartLevel=4"
              "-Declipse.product=org.eclipse.jdt.ls.core.product"
              "-Dlog.level=ALL"
              "-Xmx2G"
              "-XX:+UseG1GC"
              "-XX:+UseStringDeduplication"
              (concat "-javaagent:" java-lombok-path)
              "-jar"
              (car (file-expand-wildcards
                    (expand-file-name
                     "~/.emacs.d/.cache/lsp/eclipse.jdt.ls/plugins/org.eclipse.equinox.launcher_*.jar")))
              "-configuration"
              (expand-file-name
               "~/.emacs.d/.cache/lsp/eclipse.jdt.ls/config_mac")))

  ;; ── Clojure (clojure-lsp) ─────────────────────────────────
  (setq lsp-bridge-clojure-lsp-server-command (list "bash" "-c" clojure-lsp-path))

  ;; ── Dart/Flutter ──────────────────────────────────────────
  (setq lsp-bridge-dart-analysis-server-command
        (list (expand-file-name "bin/dart" global-dart-sdk-dir)
              "language-server" "--client-id=emacs.lsp-bridge"))

  ;; ── C# / OmniSharp ────────────────────────────────────────
  ;; LSP 서버 (기본값 "omnisharp-dotnet") — 다른 선택지:
  ;;   "omnisharp-mono" (Mono 기반), "csharp-ls" (경량)
  (setq lsp-bridge-csharp-lsp-server "omnisharp-dotnet")

  ;; OmniSharp 실행 경로 (lsp-bridge-install-omnisharp 설치 시)
  ;; ~/.emacs.d/.cache/omnisharp/OmniSharp
  ;; Homebrew로 설치한 경우 대체 가능:
  ;;   (setq lsp-bridge-omnisharp-server-command
  ;;         (list (expand-file-name "~/.local/bin/omnisharp") "-lsp"))
  )

;; ─────────────────────────────────────────────────────────────
;; lsp-bridge-peek 자동 종료
;; ─────────────────────────────────────────────────────────────

(defvar my/lsp-bridge-peek-auto-abort-installed nil
  "Whether the auto-abort hook is installed.")

(defun my/lsp-bridge-peek-auto-abort ()
  "Abort lsp-bridge-peek if current command is not peek-related."
  (when (and (bound-and-true-p lsp-bridge-peek-mode)
             (not (string-prefix-p "lsp-bridge-peek" (symbol-name this-command)))
             (not (eq this-command 'lsp-bridge-peek-abort))
             (not (eq this-command 'lsp-bridge-peek-restore)))
    (lsp-bridge-peek-abort)
    (remove-hook 'pre-command-hook #'my/lsp-bridge-peek-auto-abort t)
    (setq my/lsp-bridge-peek-auto-abort-installed nil)))

(advice-add 'lsp-bridge-peek :after
            (lambda (&rest _)
              (add-hook 'pre-command-hook #'my/lsp-bridge-peek-auto-abort nil t)
              (setq my/lsp-bridge-peek-auto-abort-installed t)))

;; peek 팝업에서 RET로 정의 이동
(add-hook 'lsp-bridge-peek-mode-hook
          (lambda ()
            (when (boundp 'lsp-bridge-peek-mode-map)
              (define-key lsp-bridge-peek-mode-map (kbd "RET") 'lsp-bridge-peek-jump))))

;; ─────────────────────────────────────────────────────────────
;; Java Spring Boot 설정
;; ─────────────────────────────────────────────────────────────

(let ((boot-server-dir (expand-file-name "~/.emacs.d/.cache/lsp/eclipse.jdt.ls/boot-server")))
  (when (file-directory-p boot-server-dir)
    (setq lsp-bridge-java-jars (directory-files boot-server-dir t "\\.jar$"))))

(setq lsp-bridge-java-workspace-dir
      (expand-file-name "~/.emacs.d/.cache/lsp/eclipse.jdt.ls/workspace"))

;; ── 디버깅 ON/OFF ────────────────────────────────────────
(defvar my/dbg-lsp nil "디버깅: M-x my/dbg-toggle")
(defun my/dbg-toggle () (interactive) (setq my/dbg-lsp (not my/dbg-lsp))
  (message "[dbg] %s" (if my/dbg-lsp "ON" "OFF")))
(defmacro my/dbg (fmt &rest args) `(when my/dbg-lsp (message (concat "[dbg] " ,fmt) ,@args)))

;; ── C-c ' buffer: org-src-source-file-name 기반 ───────
;; org-mode가 C-c ' buffer에 자동 설정하는 org-src-source-file-name을
;; lsp-bridge의 LSP 연동에 활용. disk temp file 불필요.

(defvar my/peek-src-buffer nil
  "C-c ' buffer ref for lsp-bridge-peek virtual file fallback.")

(defun my/org-edit-lsp-init ()
  "Initialize lsp-bridge for C-c ' buffers.
org-src-source-file-name is already set by org-mode to the .org
file path (see org-src.el). lsp-bridge uses this via
lsp-bridge-get-buffer-file-name-text's fallback.
No disk files are created."
  (my/dbg "init: buf=%s mode=%s org-src=%s src-fn=%s"
          (buffer-name) major-mode (bound-and-true-p org-src-mode)
          (bound-and-true-p org-src-source-file-name))
  (when (and (bound-and-true-p org-src-mode)
             (not (eq major-mode 'org-mode))
             (bound-and-true-p org-src-source-file-name))
    ;; Restart lsp-bridge so it picks up org-src-source-file-name
    (when (bound-and-true-p lsp-bridge-mode)
      (lsp-bridge-mode -1) (lsp-bridge-mode 1))
    ;; Send current content to LSP server via update_file (didChange)
    (my/dbg "init: syncing C-c' buffer content (%d bytes)" (buffer-size))
    (lsp-bridge-call-file-api "update_file" (buffer-name))))

;; C-c ' buffer 진입 시 hook
(add-hook 'org-src-mode-hook #'my/org-edit-lsp-init)

;; Before LSP operations: content sync + peek buffer ref 저장
(defun my/lsp-bridge--trace-init (orig-fun &rest args)
  (my/dbg "trace-init: %s" this-command)
  (ignore-errors
    (my/org-edit-lsp-init)
    ;; peek 호출 전 C-c ' buffer 참조 저장 (lsp-bridge-peek--file-content fallback용)
    (when (and (bound-and-true-p org-src-mode)
               (eq this-command 'lsp-bridge-peek))
      (setq my/peek-src-buffer (current-buffer))))
  (apply orig-fun args))

(dolist (fn '(lsp-bridge-find-def lsp-bridge-find-references lsp-bridge-peek))
  (advice-add fn :around #'my/lsp-bridge--trace-init))

;; ── peek-jump redirect: virtual file → C-c ' buffer ──
;; LSP가 virtual file 경로(src/main.groovy)를 반환하면
;; disk 파일을 여는 대신 C-c ' 버퍼 내에서 위치 이동.
(defun my/lsp-bridge-jump-advice (orig-fun file position)
  "Redirect jump from virtual file to current C-c ' buffer."
  (if (and my/peek-src-buffer
           (buffer-live-p my/peek-src-buffer)
           (with-current-buffer my/peek-src-buffer
             (bound-and-true-p org-src-mode)))
      (with-current-buffer my/peek-src-buffer
        (my/dbg "jump: redirect to C-c ' buffer, pos=%s" position)
        (switch-to-buffer (current-buffer))
        (goto-char (acm-backend-lsp-position-to-point position)))
    (funcall orig-fun file position)))
(advice-add 'lsp-bridge-jump-to-file :around #'my/lsp-bridge-jump-advice)



;; ── acm-mode-map에 C-s 바인딩 추가 ─────────────────────
;; lsp-bridge completion 팝업에서 C-s로 minibuffer 검색 모드 진입
(with-eval-after-load 'acm
  (define-key acm-mode-map (kbd "C-s") 'consult-completion-in-region))

(provide 'lsp-bridge)
;;; lsp-bridge.el ends here
