;;; markdown-setting.el --- Markdown editing and preview configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; markdown-mode (문법 강조) + markdown-preview-mode (브라우저 실시간 미리보기)
;; pandoc 설치: brew install pandoc

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; markdown-mode — 문법 강조, 접기, 목차
;; ─────────────────────────────────────────────────────────────

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" "\\.markdown\\'")
  :config
  (setq markdown-enable-math t)
  (setq markdown-fontify-code-blocks-natively t)
  ;; pandoc GFM (GitHub Flavored Markdown) — 코드블럭/테이블 지원
  (setq markdown-command "pandoc -f gfm -t html --syntax-highlighting=pygments")
  ;; markdown-preview 대신 markdown-preview-mode 사용 — M-x에서 숨김
  (put 'markdown-preview 'completion-predicate (lambda (&rest _) nil)))

;; ─────────────────────────────────────────────────────────────
;; web-server + websocket — markdown-preview-mode 의존성
;; ─────────────────────────────────────────────────────────────

(use-package web-server
  :ensure t
  :straight (:type git :host github :repo "eschulte/emacs-web-server"
             :local-repo "eschulte-emacs-web-server"))
(use-package websocket :ensure t)

;; ─────────────────────────────────────────────────────────────
;; markdown-preview-mode — 브라우저 실시간 미리보기
;; ─────────────────────────────────────────────────────────────

(use-package markdown-preview-mode
  :ensure t
  :after markdown-mode
  :config
  (setq markdown-preview-auto-open t))

(provide 'markdown-setting)
;;; markdown-setting.el ends here
