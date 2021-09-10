(use-package clojure-mode :ensure t)
(use-package typescript-mode
  :ensure t)
(use-package js2-mode :ensure t)
(use-package json-mode :ensure t)
(use-package cider :ensure t)
(setq major-test '())

;; (add-hook change-major-mode-hook (push '(eval major-mode) major-test))
;; (add-hook change-major-mode-hook (lambda (let mode-name major-mode) (push mode-name major-test)))


;;  end of file
(provide 'lang-modes)
