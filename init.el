(require 'package)
(package-initialize)
(setenv "PATH" (concat "/usr/local/bin" path-separator (getenv "PATH")))
(push '("melpa" . "https://melpa.org/packages/") package-archives)
(setq package-selected-packages '(use-package))
(when (cl-find-if-not #'package-installed-p package-selected-packages)
  (package-refresh-contents)
  (mapc #'package-install package-selected-packages))

(load "~/.emacs.d/required-packages")

(require 'required-packages)
(require 'sql-connection)
(require 'aweshell)
(require 'custom-function)


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("3b8284e207ff93dfc5e5ada8b7b00a3305351a3fb222782d8033a400a48eca48" default))
 '(package-selected-packages
   '(sqlformat zenburn-theme undo-fu-session undo-fu exec-path-from-shell session use-package))
 '(session-use-package t nil (session)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(setq backup-directory-alist 
  '(("." . "~/.emacs.d/file-backups")))

(load-theme 'zenburn)
