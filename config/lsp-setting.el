(use-package lsp-mode
  :ensure t
  :hook ((lsp-mode . lsp-enable-which-key-integration)
         (clojure-mode . lsp-deferred)
         (clojurec-mode . lsp-deferred)
         (clojurescript-mode . lsp-deferred)
         (typescript-mode . lsp-deferred)
         (js2-mode . lsp-deferred)
         (json-mode . lsp-deferred)
         (html-mode . lsp-deferred))
  :config
  ;; add paths to your local installation of project mgmt tools, like lein
  (global-set-key (kbd "C-/") 'lsp-ui-peek-find-references)
  (global-set-key (kbd "C-i") 'lsp-ui-peek-find-implementation)
  (setq lsp-clojure-server-command '("bash" "-c" "/usr/local/Cellar/clojure-lsp-native/2021.08.24-14.41.56/bin/clojure-lsp"))
  ) ;; Optional: In case `clojure-lsp` is not in your $PATH
(use-package lsp-java :ensure t
  :config (add-hook 'java-mode-hook 'lsp-deferred)
          (add-hook 'java-mode-hook 'lsp-java-boot-lens-mode)
          (add-hook 'conf-javaprop-mode-hook 'lsp-deferred))
(require 'lsp-java-boot)
(setq lsp-java-vmargs '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90" "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms1G"
                        "-javaagent:/Users/josh/.m2/repository/org/projectlombok/lombok/1.18.20/lombok-1.18.20.jar"))

(use-package jest-test-mode
  :ensure t
  :hook ((typescript-mode . jest-test-mode)))
(use-package company
  :ensure t
  :init
  (add-hook 'after-init-hook 'global-company-mode)
  :config
  (setq company-idle-delay 0)
  (setq company-show-numbers "on"))

(add-to-list 'company-backends '(company-capf company-abbrev company-yasnippet))

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
      ;; lsp-signature-auto-activate nil
      create-lockfiles nil)

(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))
(add-to-list 'auto-mode-alist '("\\.http\\'" . restclient-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . html-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\.html\\'" . web-mode))

(use-package flycheck :ensure t)
(use-package hydra :ensure t)
(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :config
  (setq lsp-ui-doc-enable nil))
(use-package lsp-ivy :ensure t :commands lsp-ivy-workspace-symbol)
(use-package lsp-treemacs :ensure t :commands lsp-treemacs-errors-list)
(use-package dap-mode :ensure t)
(use-package which-key :ensure t :config (which-key-mode))
(use-package restclient :ensure t)
(use-package magit :ensure t)

(with-eval-after-load 'lsp-mode
  (require 'dap-chrome)
  (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)
  (yas-global-mode))


;;  end of file
(provide 'lsp-setting)
