;; (push (expand-file-name "./emacs-jest") load-path)
;; (use-package jest
;;   :ensure t

;;   :after
;;   (js2-mode)

;;   :hook
;;   (js2-minor-mode . jest-minor-mode)
;;   (js2-mode . jest-minor-mode)

;;   :config
;;   (local-set-key (kbd "C-t u") 'jest-function)
;;   (local-set-key (kbd "C-t f") 'jest-file)
;;   (local-set-key (kbd "C-t s") 'jest-file-dwim)
;;   (local-set-key (kbd "C-t a") 'jest-repeat)
;;   (local-set-key (kbd "C-t r") 'jest-repeat))

;; (require 'jest)

(provide 'load-files)
