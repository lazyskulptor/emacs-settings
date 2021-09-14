(require 'package)
(package-initialize)
(setenv "PATH" (concat "/usr/local/bin" path-separator (getenv "PATH")))
(push '("melpa" . "https://melpa.org/packages/") package-archives)
(load "~/.emacs.d/required-packages")

(setq package-selected-packages '(use-package))
(when (cl-find-if-not #'package-installed-p package-selected-packages)
  (package-refresh-contents)
  (mapc #'package-install package-selected-packages))

(require 'required-packages)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(use-package))
 '(session-use-package t nil (session))
 '(sql-connection-alist
   '(("sq-dev"
      (sql-product 'mysql)
      (sql-user "sctestuser")
      (sql-password "sctestpassword")
      (sql-server "sc-dev.cluster-cbdq90ulypkj.ap-northeast-2.rds.amazonaws.com")
      (sql-database "sc_test_db")
      (sql-port 3307)))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

