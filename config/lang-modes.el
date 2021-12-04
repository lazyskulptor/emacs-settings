(use-package clojure-mode :ensure t)
(use-package typescript-mode
  :ensure t
  :hook ((typescript-mode . js2-minor-mode)))
(use-package js2-mode :ensure t)
(use-package json-mode :ensure t)
(use-package cider :ensure t)
(use-package yaml-mode
  :ensure t
  :hook ((yaml-mode . (lambda () define-key yaml-mode-map "\C-m" 'newline-and-indent))))
(use-package flycheck-yamllint
  :ensure t
  :defer t
  :init
  (progn
    (eval-after-load 'flycheck
      '(add-hook 'flycheck-mode-hook 'flycheck-yamllint-setup))))

;; (add-hook change-major-mode-hook (push '(eval major-mode) major-test))
;; (add-hook change-major-mode-hook (lambda (let mode-name major-mode) (push mode-name major-test)))

(add-hook 'clojure-mode-hook
          (lambda ()
            (make-local-variable 'lsp-enable-completion-at-point)
            (setq lsp-enable-completion-at-point nil lsp-enable-indentation nil)))

;;  end of file
(provide 'lang-modes)
