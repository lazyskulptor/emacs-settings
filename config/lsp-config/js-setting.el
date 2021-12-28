(use-package js2-mode :ensure t :hook ((js2-mode . lsp-deferred)))
(use-package json-mode :ensure t :hook ((json-mode . lsp-deferred)))
(use-package typescript-mode
  :ensure t
  :hook ((typescript-mode . lsp-deferred)
         (typescript-mode . js2-minor-mode)
         ))
(use-package jest
  :ensure t

  :after
  (js2-mode)

  :hook
  (js2-minor-mode . jest-minor-mode)
  (js2-mode . jest-minor-mode)

  :config
  (local-set-key (kbd "C-t u") 'jest-function)
  (local-set-key (kbd "C-t f") 'jest-file)
  (local-set-key (kbd "C-t s") 'jest-file-dwim)
  (local-set-key (kbd "C-t a") 'jest-repeat)
  (local-set-key (kbd "C-t r") 'jest-repeat))

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

(provide 'js-setting)
