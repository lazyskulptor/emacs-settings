(require 'package)
(package-initialize)
(setenv "PATH" (concat "/usr/local/bin" path-separator (getenv "PATH")))
(push '("melpa" . "https://melpa.org/packages/") package-archives)
(push (expand-file-name "~/.emacs.d/config") load-path)

(setq package-selected-packages '(use-package yasnippet hydra))
(when (cl-find-if-not #'package-installed-p package-selected-packages)
  (package-refresh-contents)
  (mapc #'package-install package-selected-packages))

(require 'lang-modes)
(require 'use-package)
(require 'lsp-setting)
(require 'evil-setting)
(require 'swagger-mode)
(require 'settings)

(use-package session :ensure t :init (add-hook 'after-init-hook 'session-initialize))
(use-package exec-path-from-shell 
  :ensure t 
  :init 
  (when (memq window-system '(mac ns x))
    (exec-path-from-shell-initialize)))
(use-package undo-fu :ensure t)
(use-package undo-fu-session
  :ensure t
  :init (add-hook 'after-init-hook 'global-undo-fu-session-mode)
  :config (setq undo-fu-session-incompatible-files '("/COMMIT_EDITMSG\\'" "/git-rebase-todo\\'")))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(auto-save-visited-mode t)
 '(inhibit-startup-screen t)
 '(mac-command-modifier 'super)
 '(mac-option-modifier 'meta)
 '(mac-right-command-modifier 'left)
 '(mac-right-option-modifier 'meta)
 '(package-selected-packages '(use-package yasnippet hydra))
 '(session-use-package t nil (session))
 '(typescript-indent-level 2))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

