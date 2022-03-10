(push (expand-file-name "~/.emacs.d/custom/emacs-jest") load-path)
(push (expand-file-name "~/.emacs.d/custom/hide-region.el") load-path)

(require 'jest)
(require 'hide-region)

(add-hook 'typescript-mode-hook #'jest-minor-mode)
(add-hook 'js2-mode-hook #'jest-minor-mode)
(add-hook 'jest-minor-mode-hook (lambda ()
                             (message "loading jest as minor")
                             (local-set-key (kbd "C-t u") 'jest-function)
                             (local-set-key (kbd "C-t f") 'jest-file)
                             (local-set-key (kbd "C-t s") 'jest-file-dwim)
                             (local-set-key (kbd "C-t a") 'jest-repeat)
                             (local-set-key (kbd "C-t r") 'jest-repeat)))

(provide 'load-files)
