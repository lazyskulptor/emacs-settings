;;; required-packages.el --- Main loader for Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 모든 설정 모듈을 로드하는 메인 로더

;;; Code:

;; ── Configure native-compilation with GCC 16 ────────────────────────
(when (eq system-type 'darwin)
  (let ((gcc-ver "16")
        (gcc-lib-path "/opt/homebrew/lib/gcc/16"))
    ;; Set up libgccjit and GCC compiler paths
    (setenv "LIBRARY_PATH"
            (concat gcc-lib-path
                    ":/opt/homebrew/lib"
                    ":" (or (getenv "LIBRARY_PATH") "")))
    (setenv "CC" (format "/opt/homebrew/bin/gcc-%s" gcc-ver))
    (setenv "CXX" (format "/opt/homebrew/bin/g++-%s" gcc-ver))))

;; Enable native-compilation
(setq native-comp-jit-compilation t)
(setq native-comp-async-report-warnings-errors 'silent)

;; Disable session saving (clean installation experience)
(setq desktop-save-mode nil)

;; ────────────────────────────────────────────────────────────────────

(load "~/.emacs.d/properties")
(push (expand-file-name "~/.emacs.d/config") load-path)
(push (expand-file-name "~/.emacs.d/config/ide") load-path)

;; ── straight.el bootstrap ────────────────────────────────────────────
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(setq straight-use-package-by-default t)
(require 'seq)  ;; straight.el이 ELPA seq를 덮어쓰기 전에 cl-defmethod 등록 보장

;; Org를 다른 패키지보다 먼저 설치하여 version mismatch 방지
(straight-use-package 'org)

;; TRAMP 최신 버전 (GNU ELPA 2.8.2, 내장 2.7.3 대체)
(straight-use-package 'tramp)

;; ── 모듈 로드 (의존성 순서) ──────────────────────────────────────────

;; 1. 일반 유틸리티 (의존성 없음)
(require 'utils)

;; 2. UI + Evil (기초)
(require 'interface)

;; 3. TRAMP + SSH + 원격 환경변수
(require 'remote)
(require 'self-update)

;; 4. Completion UI (vertico, corfu, consult)
(require 'completion)

;; 5. eshell (completion에 의존)
(require 'eshell-config)

;; 6. LSP
(require 'lsp-bridge)

;; 7. Projectile (프로젝트 관리)
(require 'projectile)

;; 8. 언어별 설정
(require 'languages)

;; 9. 디버거
(require 'dap)

;; 10. SQL 클라이언트
(require 'ejc)

;; 11. misc 패키지
(require 'tools)
(require 'git-workspace)

;; 12. Org 모드
(require 'org-setting)

;; 13. 이메일 클라이언트 (notmuch + smtpmail + wiki 다이제스트)
(require 'mail-setting)

;; 14. Markdown (문법 강조 + 브라우저 미리보기)
(require 'markdown-setting)

;; 15. OpenCode Shell
(require 'opencode-shell-setting)

;; 16. Wiki 도구 (mcp-server가 의존)
(require 'wiki-tools)

;; 17. MCP 서버
(require 'mcp-server-setting)

;; 18. MCP 서버 호출 로깅
(require 'mcp-server-trace)

;;  end of file
(provide 'required-packages)
;;; required-packages.el ends here
