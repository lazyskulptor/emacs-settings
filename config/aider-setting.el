;;; aider-setting.el --- Aider Integration configuration -*- lexical-binding: t; -*-

;; ─────────────────────────────────────────────
;; Aider Integration via Smart Unified Launcher
;; ─────────────────────────────────────────────
(use-package aider
  :straight (:host github :repo "tninja/aider.el")
  :config
  (setq aider-program (expand-file-name "~/.local/bin/saider"))

  ;; 히스토리 파일 지정하여 Aider 실행 함수
  (defun my/aider-run-with-history-file (history-file)
    "Run Aider with a specific chat history file."
    (interactive "fSelect Aider history file: ")
    (let ((aider-args (list "--chat-history-file" (expand-file-name history-file))))
      (aider-run-aider)))

  ;; 기본 히스토리 복원하여 Aider 실행 함수
  (defun my/aider-run-restore-history ()
    "Run Aider restoring previous chat history."
    (interactive)
    (let ((aider-args '("--restore-chat-history")))
      (aider-run-aider)))

  :bind
  ("C-c a A" . aider-transient-menu)
  ("C-c a D" . aider-run-aider)
  ("C-c a H" . my/aider-run-with-history-file)
  ("C-c a R" . my/aider-run-restore-history))

(provide 'aider-setting)
;;; aider-setting.el ends here
