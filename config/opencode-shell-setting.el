;;; opencode-shell-setting.el --- OpenCode Shell integration -*- lexical-binding: t; -*-

(defvar my/opencode-shell-prefix-map (make-sparse-keymap)
  "OpenCode Shell commands under `C-a'.")

;; Reapply bindings when this file is evaluated so an existing defvar map is
;; updated after adding commands such as `opencode-shell-find-session'.
(define-key my/opencode-shell-prefix-map (kbd "l") #'opencode-shell)
(define-key my/opencode-shell-prefix-map (kbd "s") #'opencode-shell-start)
(define-key my/opencode-shell-prefix-map (kbd "b") #'opencode-shell-switch-buffer)
(define-key my/opencode-shell-prefix-map (kbd "f") #'opencode-shell-find-session)

(global-set-key (kbd "C-a") my/opencode-shell-prefix-map)

(if opencode-shell-local-path
    (progn
      (add-to-list 'load-path opencode-shell-local-path)
      (use-package opencode-shell
        :straight nil
        :commands (opencode-shell
                   opencode-shell-status
                   opencode-shell-restart
                   opencode-shell-reload
                   opencode-shell-start
                   opencode-shell-find-session
                   opencode-shell-switch-buffer)
        :demand t))
  (use-package opencode-shell
    :straight (opencode-shell :type git :host github
                              :repo "lazyskulptor/opencode-shell"
                              :files ("*.el"))
    :commands (opencode-shell
               opencode-shell-status
               opencode-shell-restart
               opencode-shell-reload
               opencode-shell-start
               opencode-shell-find-session
               opencode-shell-switch-buffer)
    :demand t))

(provide 'opencode-shell-setting)
;;; opencode-shell-setting.el ends here
