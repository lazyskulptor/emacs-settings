(push (expand-file-name "~/.emacs.d/config/lsp") load-path)

(use-package yasnippet :ensure t)
(use-package counsel :ensure t)
(use-package eshell-up :ensure t)
(use-package eshell-prompt-extras :ensure t)

;; (setq company-backends
;;       '(company-bbdb company-semantic company-cmake company-capf company-clang company-files
;;                      (company-abbrev company-yasnippet company-capf)
;;                      (company-dabbrev-code company-gtags company-etags company-keywords)
;;                      company-oddmuse company-dabbrev))

  (define-prefix-command 'dap-mode-map)
  (global-set-key (kbd "C-t") 'dap-mode-map)
  (local-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
  (local-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)

(use-package lsp-mode
  :ensure t
  :hook ((lsp-mode . lsp-enable-which-key-integration)
         (clojure-mode . lsp-deferred)
         (clojurec-mode . lsp-deferred)
         (clojurescript-mode . lsp-deferred)
         (python-mode . lsp-deferred)
         (typescript-mode . lsp-deferred)
         (js2-mode . lsp-deferred)
         (json-mode . lsp-deferred)
         (html-mode . lsp-deferred)
         (lsp-mode . (lambda ()
                       (local-set-key (kbd "C-t d a") 'dap-delete-all-sessions)
                       (local-set-key (kbd "C-t b a") 'dap-breakpoint-add)
                       (local-set-key (kbd "C-t b d") 'dap-breakpoint-delete)
                       (local-set-key (kbd "C-t b r") 'dap-breakpoint-delete-all)
                       (local-set-key (kbd "C-t r") 'dap-debug-last)))
         (java-mode . (lambda ()
                        (local-set-key (kbd "C-t x r") 'dap-java-run-last-test)
                        (local-set-key (kbd "C-t x u") 'dap-java-run-test-method)
                        (local-set-key (kbd "C-t x c") 'dap-java-run-test-class)
                        (local-set-key (kbd "C-t u") 'dap-java-debug-test-method)
                        (local-set-key (kbd "C-t c") 'dap-java-debug-test-class))))

  :config
  ;; add paths to your local installation of project mgmt tools, like lein
  
  (setq lsp-clojure-server-command '("bash" "-c" "/usr/local/Cellar/clojure-lsp-native/2021.08.24-14.41.56/bin/clojure-lsp"))
  ) ;; Optional: In case `clojure-lsp` is not in your $PATH
(use-package lsp-java :ensure t
  :config
  (add-hook 'java-mode-hook 'lsp-deferred)
  (add-hook 'java-mode-hook
            (lambda ()
              (local-set-key (kbd "C-t u") 'dap-java-debug-test-method)
              (local-set-key (kbd "C-t c") 'dap-java-debug-test-class)))
  (add-hook 'java-mode-hook 'lsp-java-boot-lens-mode)
  (add-hook 'conf-javaprop-mode-hook 'lsp-deferred))
(require 'lsp-java-boot)
;; (setq lsp-java-vmargs '("-noverify" "-XX:+UseG1GC" "-XX:+UseStringDeduplication" "-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90" "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms1G"
(setq lsp-java-vmargs '("-noverify" "-Xmx2G" "-XX:+UseG1GC" "-XX:+UseStringDeduplication" "-javaagent:/Users/josh/.emacs.d/lsp/lombok-1.18.20.jar"))

(use-package lsp-jedi
  :ensure t
  :config
  (with-eval-after-load "python-mode"
    (add-to-list 'lsp-disabled-clients 'pyls)
    (add-to-list 'lsp-enabled-clients 'jedi)))

(use-package jest
  :ensure t

  :after
  (js2-mode)

  :hook
  (typescript-mode . jest-minor-mode)
  (js2-mode . jest-minor-mode)

  :config
  (local-set-key (kbd "C-t u") 'jest-function)
  (local-set-key (kbd "C-t f") 'jest-file)
  (local-set-key (kbd "C-t s") 'jest-file-dwim)
  (local-set-key (kbd "C-t r") 'jest-repeat))
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
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . html-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . web-mode))

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
(require 'default-projectile)

;;  end of file
(provide 'lsp-setting)
