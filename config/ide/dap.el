;;; dap.el --- DAP (Debug Adapter Protocol) configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; DAP 디버거 설정

;;; Code:

(use-package dap-mode :ensure t
  :config
  (dap-auto-configure-mode)
  ;; DAP 백엔드 로드
  (require 'dap-codelldb)  ; Java
  (require 'dap-go)        ; Go
  (require 'dap-python)    ; Python
  (require 'dap-netcore)   ; .NET Core (C#, F#, VB)
  (setq dap-python-debugger 'debugpy))

;; Java 모드 단축키
(add-hook 'java-mode-hook
          (lambda ()
            (local-set-key (kbd "C-'") 'lsp-bridge-find-implementation)))

(provide 'dap)
;;; dap.el ends here
