(use-package clojure-mode :ensure t)
(use-package typescript-mode :ensure t)
(use-package js2-mode :ensure t)
(use-package json-mode :ensure t)
(use-package cider :ensure t)
;; (use-package java-mode :ensure t)

 ;;     lsp-enable-indentation nil ; uncomment to use cider indentation instead of lsp
(add-hook 'clojure-mode-hook
          (lambda ()
            (make-local-variable 'lsp-enable-completion-at-point)
            (setq lsp-enable-completion-at-point nil lsp-enable-indentation nil)))

;;  end of file
(provide 'lang-modes)
