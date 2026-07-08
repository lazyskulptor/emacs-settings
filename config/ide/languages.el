;;; languages.el --- Language-specific settings -*- lexical-binding: t; -*-

;;; Commentary:
;; 언어별 모드 설정 (Python, Go, Java, Clojure, Dart, JS/TS, YAML)
;; LSP 코어 설정은 lsp-bridge.el에 있음

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; pyvenv 패키지 (Python venv 관리)
;; ─────────────────────────────────────────────────────────────

(use-package pyvenv :ensure t)

;; ─────────────────────────────────────────────────────────────
;; Python venv 자동 활성화 (lsp-bridge용)
;; ─────────────────────────────────────────────────────────────

(defun my/python-ensure-venv-lsp-bridge ()
  "Ensure .venv exists before lsp-bridge starts."
  (when (and (derived-mode-p 'python-mode)
             (fboundp 'projectile-project-root))
    (let* ((root (or (ignore-errors (projectile-project-root))
                     default-directory))
           (venv-dir (expand-file-name ".venv" root)))
      (unless (file-directory-p venv-dir)
        (message "uv: creating .venv in %s..." root)
        (call-process "uv" nil nil nil "venv" venv-dir)
        (when (file-exists-p (expand-file-name "pyproject.toml" root))
          (let ((default-directory root))
            (call-process "uv" nil nil nil "sync"))
          (message "uv: created .venv and synced dependencies")))
      (when (file-directory-p venv-dir)
        (pyvenv-activate venv-dir)))))

(add-hook 'python-mode-hook #'my/python-ensure-venv-lsp-bridge)
(add-hook 'python-ts-mode-hook #'my/python-ensure-venv-lsp-bridge)

;; ─────────────────────────────────────────────────────────────
;; Go 저장 시 포맷팅
;; ─────────────────────────────────────────────────────────────

(add-hook 'go-mode-hook
          (lambda ()
            (setq-local tab-width 4
                        indent-tabs-mode t)
            (add-hook 'before-save-hook #'lsp-bridge-code-format nil t)))

;; ─────────────────────────────────────────────────────────────
;; Java 모드 추가 설정
;; ─────────────────────────────────────────────────────────────

(add-hook 'java-mode-hook
          (lambda ()
            (setq-local tab-width 4)
            (toggle-truncate-lines nil)))

;; ─────────────────────────────────────────────────────────────
;; Groovy
;; ─────────────────────────────────────────────────────────────

(use-package groovy-mode
  :ensure t
  :config
  (defun groovy-run-file ()
    "Run current Groovy file with `groovy' command.
Output goes to *groovy-run* buffer.
Works with TRAMP remote files via `compile'."
    (interactive)
    (let* ((file (or (buffer-file-name)
                     (error "Buffer is not visiting a file")))
           (cmd (format "groovy \"%s\"" file)))
      (compilation-start cmd nil
                         (lambda (_) "*groovy-run*")))))

(add-hook 'groovy-mode-hook
          (lambda ()
            (local-set-key (kbd "C-c C-c") 'groovy-run-file)))

;; ─────────────────────────────────────────────────────────────
;; Clojure (CIDER REPL)
;; ─────────────────────────────────────────────────────────────

(use-package cider
  :ensure t
  :hook (clojure-mode . cider-mode))

;; ─────────────────────────────────────────────────────────────
;; Dart/Flutter 추가 설정
;; ─────────────────────────────────────────────────────────────

(use-package flutter :ensure t :after dart-mode
  :custom (flutter-sdk-path global-flutter-sdk-dir))

(use-package hover :ensure t)

(add-hook 'dart-mode-hook #'flutter-test-mode)

;; ─────────────────────────────────────────────────────────────
;; JS/TS 추가 설정
;; ─────────────────────────────────────────────────────────────

(setq typescript-indent-level 2
      js-indent-level 2)

(use-package js2-mode :ensure t)
(use-package json-mode :ensure t)
(use-package rjsx-mode :ensure t)

(use-package typescript-mode
  :ensure t
  :config (setq js2-mode-show-parse-errors 2))

(add-to-list 'auto-mode-alist '("\\.js\\'" . js-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . js-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . typescript-mode))
(add-to-list 'auto-mode-alist '("\\.svelte\\'" . typescript-mode))
(add-to-list 'auto-mode-alist '("\\.vue\\'" . typescript-mode))

;; ─────────────────────────────────────────────────────────────
;; YAML 설정
;; ─────────────────────────────────────────────────────────────

;; YAML 스키마 함수 (lsp-bridge용)
(defun my/yaml-select-schema ()
  "Select a YAML schema by name."
  (interactive)
  (message "YAML schema selection: use .yaml-language-server config in project root"))

;; treesit-fold 설치 및 설정
(use-package treesit-fold
  :ensure t)

(add-hook 'yaml-ts-mode-hook
          (lambda ()
            (treesit-fold-mode 1)
            (define-key yaml-ts-mode-map "\C-m" 'newline-and-indent)
            (local-set-key (kbd "C-c y s") 'my/yaml-select-schema)))

;; ─────────────────────────────────────────────────────────────
;; auto-mode-alist 설정
;; ─────────────────────────────────────────────────────────────

(add-to-list 'auto-mode-alist '("\\.yml\\'" . yaml-ts-mode))
(add-to-list 'auto-mode-alist '("\\.yaml\\'" . yaml-ts-mode))
(add-to-list 'auto-mode-alist '("\\.http\\'" . restclient-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . web-mode))

;; ─────────────────────────────────────────────────────────────
;; C# (.NET) 설정
;; ─────────────────────────────────────────────────────────────

(use-package csharp-mode
  ;; :ensure t — Emacs 29부터 내장되어 있으므로 불필요 (중복 설치 경고 발생)
  :mode "\\.cs\\'"
  :config
  (setq csharp-format-on-save t
        csharp-default-indentation 4))

;; csharp-ts-mode (Emacs 29+ built-in) indent 설정
(when (fboundp 'csharp-ts-mode)
  (add-hook 'csharp-ts-mode-hook
            (lambda ()
              (setq-local csharp-ts-mode-indent-offset 4))))

(provide 'languages)
;;; languages.el ends here
