(use-package lsp-java :ensure t
  :hook
  (java-mode . (lambda ()
                        (local-set-key (kbd "C-'") 'lsp-java-open-super-implementation)
                        (local-set-key (kbd "C-t x r") 'dap-java-run-last-test)
                        (local-set-key (kbd "C-t x u") 'dap-java-run-test-method)
                        (local-set-key (kbd "C-t x c") 'dap-java-run-test-class)
                        (local-set-key (kbd "C-t u") 'dap-java-debug-test-method)
                        (local-set-key (kbd "C-t c") 'dap-java-debug-test-class)))
  :config
  (add-hook 'java-mode-hook 'lsp-deferred)
  (add-hook 'java-mode-hook 'lsp-java-boot-lens-mode)
  (add-hook 'conf-javaprop-mode-hook 'lsp-deferred))
(require 'lsp-java-boot)
;; (setq lsp-java-vmargs '("-noverify" "-XX:+UseG1GC" "-XX:+UseStringDeduplication" "-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90" "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms1G"
(setq lsp-java-vmargs '("-noverify" "-Xmx2G" "-XX:+UseG1GC" "-XX:+UseStringDeduplication" "-javaagent:/Users/josh/.emacs.d/lsp/lombok-1.18.20.jar"))


(provide 'java-setting)
