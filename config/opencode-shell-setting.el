;;; opencode-shell-setting.el --- OpenCode Shell integration -*- lexical-binding: t; -*-

(if opencode-shell-local-path
    (progn
      (add-to-list 'load-path opencode-shell-local-path)
      (use-package opencode-shell
        :straight nil
        :commands (opencode-shell
                   opencode-shell-launch
                   opencode-shell-open-profile
                   opencode-shell-sessions
                   opencode-shell-reload
                   opencode-shell-start-server
                   opencode-shell-stop-server
                   opencode-shell-restart-server)))
  (use-package opencode-shell
    :straight (opencode-shell :type git :host github
                              :repo "lazyskulptor/opencode-shell"
                              :files ("*.el"))
    :commands (opencode-shell
                opencode-shell-launch
                opencode-shell-open-profile
                opencode-shell-sessions
                opencode-shell-reload
               opencode-shell-start-server
               opencode-shell-stop-server
               opencode-shell-restart-server)))

(provide 'opencode-shell-setting)
;;; opencode-shell-setting.el ends here
