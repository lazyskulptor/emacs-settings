;;; ejc.el --- EJC SQL client configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; EJC SQL 클라이언트 설정

;;; Code:

(use-package ejc-sql :ensure t
  :init
  (setq ejc-set-fetch-size 100
        ejc-set-max-rows 100
        ejc-complete-on-dot t
        ejc-use-flx t
        clomacs-httpd-default-port 8091)

  ;; SQL 연결 정보는 config/sql-connections.el에서 관리 (optional, gitignored)
  (when (locate-library "sql-connections")
    (require 'sql-connections)))

(use-package sqlformat :ensure t)

(add-hook 'sql-interactive-mode-hook '(lambda () (toggle-truncate-lines 1)))

(provide 'ejc)
;;; ejc.el ends here
