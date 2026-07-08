;;; org-setting.el --- Org-mode configuration -*- lexical-binding: t; -*-

(use-package org :ensure t
  :mode ("\\.org\\'" . org-mode)
  :config
  (setq org-adapt-indentation t)
  (setq org-todo-keywords '((type "TODO" "|" "DONE")))
  (setq org-latex-pdf-process
        (list "latexmk -pdflatex='%latex -shell-escape -interaction nonstopmode' -pdf -output-directory=%o %f"))
  (setq org-directory (file-truename "~/Workspace/wiki/"))
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory))
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
      (python . t)
      (clojure . t)
      (ditaa . t)
       (plantuml . t)))
    (setq org-babel-python-command "uv run python")
    (setq org-babel-clojure-backend 'babashka)
   (setq org-ditaa-jar-path "/opt/homebrew/Cellar/ditaa/0.11.0_1/libexec/ditaa-0.11.0-standalone.jar")
   (setq org-ditaa-exec "/opt/homebrew/bin/ditaa")
   (setq org-ditaa-default-exec-mode 'ditaa))

(use-package org-pomodoro :ensure t
  :config (setq org-pomodoro-manual-break t))

(use-package org-roam :ensure t
  :init (setq org-roam-v2-ack t)
  :custom
  (org-roam-directory (file-truename "~/Workspace/wiki/roam/"))
  (org-roam-dailies-directory "daily/")
  (org-roam-completion-everywhere t)
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n j" . org-roam-dailies-capture-today))
  :config
  (org-roam-setup)
  (with-eval-after-load 'org-roam-dailies
    (add-to-list 'org-roam-dailies-capture-templates
                 '("d" "default" entry "%?"
                   :if-new (file+head "%<%Y-%m-%d>.org"
                                      "#+title: %<%Y-%m-%d>\n#+roam_key: %<%Y-%m-%d>\n\n* Log\n")))))

(setq org-archive-location "~/Workspace/wiki-archive/%s_archive::")
(setq org-log-done 'time)

(require 'org-id)
(setq org-id-method 'uuid)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-,") 'lsp-bridge-return-from-def))

;; Org 테이블 내 폰트 설정 (Maple Mono NF CN 사용)
(require 'org-table-align)

(provide 'org-setting)
