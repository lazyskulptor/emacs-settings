(global-set-key (kbd "C-x O") (lambda ()
  (interactive)
  (other-window -1)))

(setq default-input-method "korean-hangul")
(global-set-key (kbd "S-SPC") 'toggle-input-method)

(global-set-key (kbd "C-,") 'xref-pop-marker-stack)
(global-set-key (kbd "C-.") 'xref-find-definitions)
(global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
(global-set-key (kbd "M-.") 'lsp-ui-peek-find-implementation)
;; (global-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)
;; (global-set-key (kbd "C-/") 'xref-find-references)
;; (global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
(global-set-key (kbd "s-z")   'Undo-Fu-Only-Undo)
(global-set-key (kbd "s-Z") 'undo-fu-only-redo)
(global-set-key (kbd "s-v") 'clipboard-yank)
(global-set-key (kbd "s-c") 'clipboard-kill-ring-save)
(global-set-key (kbd "s-/") 'comment-line)

;; (setq flycheck-keymap-prefix (kbd "s-1"))
;; (global-set-key (kbd "f2") 'flycheck-next-error)
;; (global-set-key (kbd "f3") 'flycheck-previous-error)

;; (global-set-key (kbd "s-1") (lookup-key global-map (kbd "C-c !")))
;; (setq flycheck-keymap-prefix (kbd "s-1"))


;; (menu-bar-mode -1) 
(toggle-scroll-bar -1) 
(tool-bar-mode -1) 

(set-face-attribute 'default nil :height 150)
(show-paren-mode 1)
(setq tab-width 2)
(global-display-line-numbers-mode)
(setq tab-width 2)
(setq inhibit-startup-screen t)
(setq mac-command-modifier 'super)
(setq mac-option-modifier 'meta)
(setq mac-right-command-modifier 'left)
(setq mac-right-option-modifier 'meta)
(setq typescript-indent-level 2)
(setq lsp-eslint-unzipped-path (f-join "~/.emacs.d/lsp/eslint/unzipped"))
(setq ivy-use-virtual-buffers t)
(setq ivy-count-format "(%d/%d) ")
;; (add-to-list 'company-backends 'company-yasnippet)
(ivy-mode 1)


(use-package yasnippet
  :ensure t
  :init (yas-reload-all)
  :hook
  (lsp-mode . yas-minor-mode)
  (org-mode . yas-minor-mode))

;;; end of files
(provide 'settings)
