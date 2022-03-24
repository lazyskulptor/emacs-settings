(use-package evil-collection
  :ensure t
  :init (setq evil-want-keybinding nil))

(use-package evil-numbers :ensure t)

(use-package evil
  :ensure t ;; install the evil package if not installed
  :requires (evil-collection evil-numbers)
  :init ;; tweak evil's configuration before loading it
  (setq evil-search-module 'evil-search)
  (setq evil-ex-complete-emacs-commands nil)
  (setq evil-vsplit-window-right t)
  (setq evil-split-window-below t)
  (setq evil-shift-round nil)
  (setq-default evil-shift-width 2)
  (setq-default indent-tabs-mode nil)
  (setq evil-want-C-u-scroll t)
  (evil-collection-init)
  :config
  ;; (evil-set-initial-state 'neotree-mode 'emacs)
  (global-set-key (kbd "C-w") 'evil-window-map)

  (define-key evil-normal-state-map (kbd "C-.") nil)

  (define-key evil-window-map "f" 'other-frame)
  (define-key evil-window-map "o" 'delete-other-windows)
  (define-key evil-window-map "O" 'delete-other-frames)
  (define-key evil-window-map "q" nil)
  
  (evil-set-initial-state 'calendar-mode 'insert)
  (evil-mode)

  (define-key evil-insert-state-map (kbd "C-w") evil-window-map)
  (define-key evil-insert-state-map (kbd "C-t") nil)
  (define-key evil-normal-state-map (kbd "C-w C-h") nil)
  (define-key evil-normal-state-map (kbd "Z Q") nil)
  (define-key evil-normal-state-map (kbd "C-.") nil)
  (define-key evil-normal-state-map (kbd "M-,") nil)
  (define-key evil-normal-state-map (kbd "M-.") nil)
  (define-key evil-normal-state-map (kbd "M-/") nil)
  (define-key evil-normal-state-map (kbd "C-i") nil)
  (define-key evil-normal-state-map (kbd "C-t") nil)
  (define-key evil-normal-state-map "u" 'undo-fu-only-undo)
  (define-key evil-normal-state-map (kbd "C-r") 'undo-fu-only-redo)
  (define-key evil-normal-state-map (kbd "C-c +") 'evil-numbers/inc-at-pt)
  (define-key evil-normal-state-map (kbd "C-c -") 'evil-numbers/dec-at-pt)
  (evil-select-search-module 'evil-search-module 'evil-search)
  )

(provide 'evil-setting)
