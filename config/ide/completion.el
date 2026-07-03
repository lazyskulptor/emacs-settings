;;; completion.el --- Completion UI configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Completion UI 설정 (vertico, corfu, consult, orderless, recentf)

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; Vertico - 커서 아래 inline completion
;; ─────────────────────────────────────────────────────────────

(use-package vertico
  :ensure t
  :init
  (vertico-mode)
  :config
  (setq vertico-count 10)
  (setq vertico-cycle t))

;; ─────────────────────────────────────────────────────────────
;; Corfu - inline popup completion
;; ─────────────────────────────────────────────────────────────

(use-package corfu
  :ensure t
  :custom
  (corfu-cycle t)
  (corfu-auto nil)
  :config
  (global-corfu-mode))

;; ─────────────────────────────────────────────────────────────
;; Recent files
;; ─────────────────────────────────────────────────────────────

(use-package recentf
  :ensure nil
  :config
  (recentf-mode 1)
  (setq recentf-max-menu-items 50
        recentf-max-saved-items 100)
  :custom
  (recentf-auto-save-timer (run-with-idle-timer 30 t 'recentf-save-list)))

;; ─────────────────────────────────────────────────────────────
;; Consult - Counsel 대체 명령어
;; ─────────────────────────────────────────────────────────────

(use-package consult
  :ensure t
  :custom
  (consult-preview-key nil)
  (consult-buffer-sources
   '(consult-source-buffer
     consult-source-hidden-buffer
     consult-source-modified-buffer
     consult-source-other-buffer
     consult-source-recent-file
     consult-source-buffer-register
     consult-source-file-register))
  :config
  ;; :bind 대신 :config에서 global-set-key 사용 (Evil ESC prefix와 충돌 방지)
  (global-set-key (kbd "C-s") 'consult-line)
  (global-set-key (kbd "<f1> f") 'consult-describe-function)
  (global-set-key (kbd "<f1> v") 'consult-describe-variable)
  (global-set-key (kbd "<f1> l") 'consult-find-library)
  (global-set-key (kbd "C-x b") 'consult-buffer))

;; ─────────────────────────────────────────────────────────────
;; Orderless - fuzzy matching
;; ─────────────────────────────────────────────────────────────

(use-package orderless
  :ensure t
  :config
  (setq completion-styles '(orderless basic)))

(provide 'completion)
;;; completion.el ends here
