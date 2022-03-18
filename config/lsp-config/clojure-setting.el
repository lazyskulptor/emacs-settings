(use-package clojure-mode
  :ensure t
  :hook
  ((clojure-mode . lsp-deferred)
   (clojurec-mode . lsp-deferred)
   (clojurescript-mode . lsp-deferred))
  :config
  (setq lsp-clojure-server-command '("bash" "-c" "/usr/local/Cellar/clojure-lsp-native/2021.12.20-00.36.56/bin/clojure-lsp")))
(use-package cider :ensure t)
(add-hook 'clojure-mode-hook
          (lambda ()
            (autopair-mode)
            (make-local-variable 'lsp-enable-completion-at-point)
            (setq lsp-enable-completion-at-point nil
                  lsp-enable-indentation nil
                  cider-save-file-on-load t)))

(provide 'clojure-setting)
