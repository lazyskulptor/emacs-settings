(use-package evil
  :ensure t ;; install the evil package if not installed
  :init ;; tweak evil's configuration before loading it
  (setq evil-search-module 'evil-search)
  (setq evil-ex-complete-emacs-commands nil)
  (setq evil-vsplit-window-right t)
  (setq evil-split-window-below t)
  (setq evil-shift-round nil)
  (setq-default evil-shift-width 2)
  (setq-default indent-tabs-mode nil)
  (setq evil-want-C-u-scroll t)
  :config
  ;; (evil-set-initial-state 'neotree-mode 'emacs)
  (evil-set-initial-state 'shel 'emacs)
  (evil-mode)
  (define-key evil-normal-state-map (kbd "C-.") nil)
  (define-key evil-normal-state-map (kbd "M-,") nil)
  (define-key evil-normal-state-map (kbd "M-.") nil)
  (define-key evil-normal-state-map (kbd "M-/") nil)
  (define-key evil-normal-state-map "u" 'undo-fu-only-undo)
  (define-key evil-normal-state-map "\C-r" 'undo-fu-only-redo)
  )

(provide 'evil-setting)
