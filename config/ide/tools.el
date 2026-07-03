;;; tools.el --- Miscellaneous packages and utility functions -*- lexical-binding: t; -*-

;;; Commentary:
;; misc 패키지 (magit, restclient, which-key, hydra, eshell-up, eshell-prompt-extras)
;; 유틸리티 함수

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; misc 패키지
;; ─────────────────────────────────────────────────────────────

(use-package eshell-up :ensure t)
(use-package eshell-prompt-extras :ensure t)
(use-package hydra :ensure t)
(use-package which-key :ensure t :config (which-key-mode))
(use-package restclient :ensure t)

(require 'compat-31)  ; Ensure set-local/n functions are available for magit

(use-package magit :ensure t
  :straight (:type git :host github :repo "magit/magit" :tag "v4.4.2"))

(provide 'tools)
;;; tools.el ends here
