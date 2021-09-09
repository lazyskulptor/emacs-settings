(use-package lsp-mode
  :ensure t
  :hook ((clojure-mode . lsp)
         (clojurec-mode . lsp)
         (clojurescript-mode . lsp)
         (typescript-mode . lsp)
         (js2-mode . lsp)
         (json-mode . lsp))
  :config
  ;; add paths to your local installation of project mgmt tools, like lein
  (global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
  (global-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)
  (setq lsp-clojure-server-command '("bash" "-c" "/usr/local/Cellar/clojure-lsp-native/2021.08.24-14.41.56/bin/clojure-lsp"))
  ) ;; Optional: In case `clojure-lsp` is not in your $PATH


(use-package company
  :ensure t
  :init
  (add-hook 'after-init-hook 'global-company-mode)
  :config
  (setq company-idle-delay 0)
  (setq company-show-numbers "on"))

(use-package projectile
  :ensure t
  :init
  (projectile-mode +1)
  :bind (:map projectile-mode-map
              ("s-p" . projectile-command-map)
              ("C-c p" . projectile-command-map)))

(setq tab-always-indent 'complete)
(setq gc-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 1024 1024)
      treemacs-space-between-root-nodes nil
      company-minimum-prefix-length 1
      lsp-lens-enable t
      lsp-signature-auto-activate nil
;;      lsp-enable-indentation nil ; uncomment to use cider indentation instead of lsp
;;      lsp-enable-completion-at-point nil ; uncomment to use cider completion instead of lsp
      create-lockfiles nil)
(add-to-list 'auto-mode-alist '("\\.http\\'" . restclient-mode))

(use-package flycheck :ensure t)
(use-package lsp-ui :ensure t :commands lsp-ui-mode)
(use-package lsp-ivy :ensure t :commands lsp-ivy-workspace-symbol)
(use-package lsp-treemacs :ensure t :commands lsp-treemacs-errors-list)
(use-package dap-mode :ensure t)
(use-package which-key :ensure t :config (which-key-mode))
(use-package restclient :ensure t)
(use-package magit :ensure t)


;;  end of file
(provide 'lsp-setting)
