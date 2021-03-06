;; (global-set-key (kbd "C-x O") (lambda () (interactive) (other-window -1)))

(global-set-key (kbd "s-ESC") (lambda () (interactive) (other-frame 1)))
(global-set-key (kbd "s-S-ESC") (lambda () (interactive) (other-frame -1)))
(setq default-input-method "korean-hangul")
(global-set-key (kbd "<M-f4>") 'toggle-input-method)

;; (setq tab-always-indent 'complete)
(global-set-key (kbd "C-SPC") 'company-complete)
(global-set-key (kbd "M-1") 'projectile-run-async-shell-command-in-root)
(global-set-key (kbd "M-2") 'flycheck-next-error)
(global-set-key (kbd "s-n") 'make-frame-on-monitor)
(global-set-key (kbd "C-,") 'xref-pop-marker-stack)
(global-set-key (kbd "C-.") 'xref-find-definitions)
(global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
(global-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)
(global-set-key (kbd "C-;") 'lsp-ui-peek-find-implementation)
;; (global-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)
;; (global-set-key (kbd "C-/") 'xref-find-references)
;; (global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
(global-set-key (kbd "s-z")   'undo-fu-only-undo)
(global-set-key (kbd "s-Z") 'undo-fu-only-redo)
(global-set-key (kbd "s-v") 'clipboard-yank)
(global-set-key (kbd "s-c") 'clipboard-kill-ring-save)
(global-set-key (kbd "s-/") 'comment-line)

(define-prefix-command 'treemacs-map)
(global-set-key (kbd "s-t") 'treemacs-map)
(global-set-key (kbd "s-t t") 'treemacs)
(global-set-key (kbd "s-t f") 'treemacs-find-file)

;; (setq flycheck-keymap-prefix (kbd "s-1"))
;; (global-set-key (kbd "f2") 'flycheck-next-error)
;; (global-set-key (kbd "f3") 'flycheck-previous-error)

;; (global-set-key (kbd "s-1") (lookup-key global-map (kbd "C-c !")))
;; (setq flycheck-keymap-prefix (kbd "s-1"))


;; (menu-bar-mode -1) 
(toggle-scroll-bar -1) 
(tool-bar-mode -1) 

(set-face-attribute 'default nil :font "Monoid" :height 140)
(show-paren-mode 1)
(yas-global-mode 1)

(setq tab-width 2)
(global-display-line-numbers-mode)
(setq inhibit-startup-screen t)
(setq mac-command-modifier 'super)
(setq mac-option-modifier 'meta)
(setq mac-right-command-modifier 'left)
(setq mac-right-option-modifier 'meta)
(setq typescript-indent-level 2)
(setq js-indent-level 2)
(add-hook 'prog-mode-hook #'hs-minor-mode)
(setq ivy-use-virtual-buffers t)
(setq ivy-count-format "(%d/%d) ")
(setq ivy-re-builders-alist
      '((ivy-switch-buffer . ivy--regex-fuzzy)
        (counsel-find-file . ivy--regex-fuzzy)
        (t . ivy--regex-plus)))
(setq lsp-eslint-enable nil)
(setq use-dialog-box nil)
;; (add-to-list 'company-backends 'company-yasnippet)
(ivy-mode 1)
(add-hook 'sql-interactive-mode-hook '(lambda () (toggle-truncate-lines 1)))
;; (require 'aweshell)

(global-set-key (kbd "C-s") 'swiper-isearch)
;; (global-set-key (kbd "M-x") 'counsel-M-x)
(global-set-key (kbd "C-x C-f") 'counsel-find-file)
(global-set-key (kbd "M-y") 'counsel-yank-pop)
(global-set-key (kbd "<f1> f") 'counsel-describe-function)
(global-set-key (kbd "<f1> v") 'counsel-describe-variable)
(global-set-key (kbd "<f1> l") 'counsel-find-library)
(global-set-key (kbd "<f2> i") 'counsel-info-lookup-symbol)
(global-set-key (kbd "<f2> u") 'counsel-unicode-char)
(global-set-key (kbd "<f2> j") 'counsel-set-variable)
(global-set-key (kbd "C-x b") 'ivy-switch-buffer)
(global-set-key (kbd "C-c v") 'ivy-push-view)
(global-set-key (kbd "C-c V") 'ivy-pop-view)


;;; end of files
(provide 'settings)
