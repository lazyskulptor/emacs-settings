(push (expand-file-name "~/.emacs.d/config") load-path)
(push (expand-file-name "~/.emacs.d/custom") load-path)
(with-temp-buffer (shell-command "docker-machine env --shell emacs default" (current-buffer)) (eval-buffer))

(require 'use-package)
(require 'lsp-setting)
(require 'evil-setting)
(require 'slack-setting)
(require 'settings)
(require 'load-files)
(require 'sql-connections)

(use-package session :ensure t :init (add-hook 'after-init-hook 'session-initialize))
(use-package exec-path-from-shell 
  :ensure t 
  :init 
  (when (memq window-system '(mac ns x))
    (exec-path-from-shell-initialize)))
(use-package undo-fu :ensure t)
(use-package undo-fu-session
  :ensure t
  :init (add-hook 'after-init-hook 'global-undo-fu-session-mode)
  :config (setq undo-fu-session-incompatible-files '("/COMMIT_EDITMSG\\'" "/git-rebase-todo\\'")))
(use-package sqlformat :ensure t)

;;  end of file
(provide 'required-packages)
