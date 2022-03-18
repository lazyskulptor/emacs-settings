(push (expand-file-name "~/.emacs.d/config/lsp-config") load-path)

(define-prefix-command 'dap-mode-map)
(global-set-key (kbd "C-t") 'dap-mode-map)
(local-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
(local-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)

(condition-case nil
    (require 'java-setting)
  (error (lsp-log "Failed to init lsp java for %s: message" (error-message-string error))))
(condition-case nil
    (require 'clojure-setting)
  (error nil))
(condition-case nil
(require 'js-setting)
  (error (lsp-log "Failed to init js for %s: message" (error-message-string error))))
(condition-case nil
(require 'default-projectile)
  (error (lsp-log "Failed to init projectile for %s: message" (error-message-string error))))


(use-package yasnippet :ensure t)
(use-package counsel :ensure t)
(use-package eshell-up :ensure t)
(use-package eshell-prompt-extras :ensure t)

;; (setq company-backends
;;       '(company-bbdb company-semantic company-cmake company-capf company-clang company-files
;;                      (company-abbrev company-yasnippet company-capf)
;;                      (company-dabbrev-code company-gtags company-etags company-keywords)
;;                      company-oddmuse company-dabbrev))

(use-package lsp-mode
  :ensure t
  :hook ((lsp-mode . lsp-enable-which-key-integration)
         (python-mode . lsp-deferred)
         (html-mode . lsp-deferred)
         (yaml-mode . lsp-deferred)
         (web-mode . lsp-deferred)
         (lsp-mode . (lambda ()
                       (local-set-key (kbd "C-t d a") 'dap-delete-all-sessions)
                       (local-set-key (kbd "C-t b a") 'dap-breakpoint-add)
                       (local-set-key (kbd "C-t b d") 'dap-breakpoint-delete)
                       (local-set-key (kbd "C-t b r") 'dap-breakpoint-delete-all)
                       (local-set-key (kbd "C-t r") 'dap-debug-last)))))

(use-package company
  :ensure t
  :init
  (add-hook 'after-init-hook 'global-company-mode)
  :config
  (setq company-global-modes '(not eshell-mode))
  (setq company-idle-delay 0)
  (setq company-show-numbers "on"))

(setq gc-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 1024 1024)
      treemacs-space-between-root-nodes nil
      company-minimum-prefix-length 1
      lsp-lens-enable t
      ;; lsp-signature-auto-activate nil
      lsp-ui-doc-enable nil
      lsp-ui-doc-position 'bottom
      lsp-ui-doc-delay 0
      lsp-diagnostic-clean-after-change t
      create-lockfiles nil)

(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))
(add-to-list 'auto-mode-alist '("\\.http\\'" . restclient-mode))
;; (add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . html-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.yml\\'" . yaml-mode))

(use-package flycheck :ensure t)
(use-package hydra :ensure t)
(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode)
(use-package lsp-ivy :ensure t :commands lsp-ivy-workspace-symbol)
(use-package lsp-treemacs :ensure t :commands lsp-treemacs-errors-list)
(use-package dap-mode :ensure t)
(use-package which-key :ensure t :config (which-key-mode))
(use-package restclient :ensure t)
(use-package magit :ensure t)

;;  end of file
(provide 'lsp-setting)
