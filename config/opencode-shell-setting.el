;;; opencode-shell-setting.el --- OpenCode Shell integration -*- lexical-binding: t; -*-

(if opencode-shell-local-path
    (progn
      (add-to-list 'load-path opencode-shell-local-path)
      (use-package opencode-shell
        :straight nil
        :commands (opencode-shell
                   opencode-shell-status
                   opencode-shell-restart
                   opencode-shell-reload)
        :bind (("C-c a" . opencode-shell))
        :demand t))
  (use-package opencode-shell
    :straight (opencode-shell :type git :host github
                              :repo "lazyskulptor/opencode-shell"
                              :files ("*.el"))
    :commands (opencode-shell
               opencode-shell-status
               opencode-shell-restart
               opencode-shell-reload)
    :bind (("C-c a" . opencode-shell))
    :demand t))

(provide 'opencode-shell-setting)
;;; opencode-shell-setting.el ends here
