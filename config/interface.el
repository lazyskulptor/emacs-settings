;;; interface.el --- UI and Evil keybinding configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; UI 설정과 Evil 키바인딩을 통합한 파일
;; - 화면/UI 설정 (라인번호, 폰트, Mac 키 등)
;; - 글로벌 키바인딩 (xref, undo, clipboard 등)
;; - Evil 모드 설정
;; - 세션 관리, undo, exec-path-from-shell

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; 기본 UI 설정
;; ─────────────────────────────────────────────────────────────

(setq native-comp-async-report-warnings-errors 'silent)

(global-display-line-numbers-mode)
(setq comint-buffer-maximum-size 10240)
(setq inhibit-startup-screen t)
(setq line-number-mode nil)
(setq column-number-mode t)
(add-hook 'artist-mode-hook
          (lambda ()
            (setq-local next-line-add-newlines t)))


;; Mac 키 설정
(setq mac-command-modifier 'super)
(setq mac-option-modifier 'meta)
(setq mac-right-command-modifier 'left)
(setq mac-right-option-modifier 'meta)

(setq use-dialog-box nil)
(setq default-input-method "korean-hangul")
(setq tab-always-indent 'complete)

;; 스크롤바, 툴바 비활성화
(toggle-scroll-bar -1)
(tool-bar-mode -1)

;; 폰트 설정
(set-face-attribute 'default nil :font "Monoid" :height 130)

;; 괄호 짝 강조
(show-paren-mode 1)

;; ─────────────────────────────────────────────────────────────
;; 글로벌 키바인딩
;; ─────────────────────────────────────────────────────────────

;; 프레임 전환
(global-set-key (kbd "s-ESC") (lambda () (interactive) (other-frame 1)))
(global-set-key (kbd "s-S-ESC") (lambda () (interactive) (other-frame -1)))
(global-set-key (kbd "s-n") 'make-frame-on-monitor)

;; 입력기 전환
(global-set-key (kbd "<M-f4>") 'toggle-input-method)

;; xref 네비게이션
(global-set-key (kbd "C-,") 'xref-go-back)
(global-set-key (kbd "C-.") 'lsp-bridge-find-def)
(global-set-key (kbd "C-/") 'lsp-bridge-peek)
(global-set-key (kbd "C-;") 'xref-find-implementation)
(global-set-key (kbd "C-[") 'xref-go-back)
(global-set-key (kbd "C-]") 'xref-go-forward)

;; undo/redo (Mac 스타일)
(global-set-key (kbd "s-z") 'undo-fu-only-undo)
(global-set-key (kbd "s-Z") 'undo-fu-only-redo)

;; 클립보드
(global-set-key (kbd "s-v") 'clipboard-yank)
(global-set-key (kbd "s-c") 'clipboard-kill-ring-save)

;; 주석
(global-set-key (kbd "s-/") 'comment-line)

;; 파일 찾기
(global-set-key (kbd "C-x C-f") 'find-file)

;; 텍스트 크기 조절
(global-set-key (kbd "C-x C-=") 'text-scale-increase)
(global-set-key (kbd "C-x C--") 'text-scale-decrease)

;; ─────────────────────────────────────────────────────────────
;; Evil 모드 설정
;; ─────────────────────────────────────────────────────────────

(use-package evil-collection
  :ensure t
  :init (setq evil-want-keybinding nil))

(use-package evil-numbers :ensure t)

(use-package evil
  :ensure t
  :requires (evil-collection evil-numbers)
  :init
  (setq evil-mode-line-format nil)
  (setq evil-search-module 'evil-search)
  (setq evil-ex-complete-emacs-commands nil)
  (setq evil-vsplit-window-right t)
  (setq evil-split-window-below t)
  (setq evil-shift-round nil)
  (setq-default evil-shift-width 2)
  (setq-default indent-tabs-mode nil)
  (setq evil-want-C-u-scroll t)
  :config
  ;; evil-collection이 outline에 바인딩하지 않도록 제외 (z l 스크롤 우선)
  (setq evil-collection-mode-list (delq 'outline evil-collection-mode-list))
  (evil-collection-init)

  (evil-set-initial-state 'calendar-mode 'insert)
  (evil-mode)

  ;; evil-esc-mode 비활성화 (Meta 키와 ESC 분리)
  (evil-esc-mode -1)

  ;; 각 state에서 ESC를 명시적으로 바인딩
  (define-key evil-insert-state-map [escape] 'evil-force-normal-state)
  (define-key evil-visual-state-map [escape] 'evil-exit-visual-state)
  (define-key evil-emacs-state-map [escape] 'evil-normal-state)

  (evil-select-search-module 'evil-search-module 'evil-search))

;; ─────────────────────────────────────────────────────────────
;; Evil 키맵 (통합)
;; ─────────────────────────────────────────────────────────────

;; evil-window-map
(global-set-key (kbd "C-w") 'evil-window-map)
(define-key evil-window-map "f" 'other-frame)
(define-key evil-window-map "o" 'delete-other-windows)
(define-key evil-window-map "O" 'delete-other-frames)
(define-key evil-window-map "q" nil)

;; evil-normal-state-map
(define-key evil-normal-state-map (kbd "M-x") 'execute-extended-command)
(define-key evil-normal-state-map (kbd "M-:") 'eval-expression)
(define-key evil-normal-state-map (kbd "C-w C-h") nil)
(define-key evil-normal-state-map (kbd "Z Q") nil)
(define-key evil-normal-state-map (kbd "M-,") nil)
(define-key evil-normal-state-map (kbd "M-.") nil)
(define-key evil-normal-state-map (kbd "M-/") nil)
(define-key evil-normal-state-map (kbd "C-i") nil)
(define-key evil-normal-state-map (kbd "C-t") nil)
(define-key evil-normal-state-map (kbd "C-.") nil)
(define-key evil-normal-state-map "u" 'undo-fu-only-undo)
(define-key evil-normal-state-map (kbd "C-r") 'undo-fu-only-redo)
(define-key evil-normal-state-map (kbd "C-c +") 'evil-numbers/inc-at-pt)
(define-key evil-normal-state-map (kbd "C-c -") 'evil-numbers/dec-at-pt)
(define-key evil-normal-state-map (kbd "M-1") 'projectile-run-async-shell-command-in-root)
(define-key evil-normal-state-map (kbd "M-2") 'lsp-bridge-diagnostic-jump-next)

;; evil-insert-state-map
(define-key evil-insert-state-map (kbd "M-x") 'execute-extended-command)
(define-key evil-insert-state-map (kbd "M-:") 'eval-expression)
(define-key evil-insert-state-map (kbd "C-w") evil-window-map)
(define-key evil-insert-state-map (kbd "C-t") nil)
(define-key evil-insert-state-map (kbd "M-1") 'projectile-run-async-shell-command-in-root)
(define-key evil-insert-state-map (kbd "M-2") 'lsp-bridge-diagnostic-jump-next)

;; ─────────────────────────────────────────────────────────────
;; LSP 키맵
;; ─────────────────────────────────────────────────────────────

;; prefix map 정의
(defvar lsp-bridge-prefix-map
  (let ((map (make-sparse-keymap)))
    ;; 탐색
    (define-key map (kbd "d") 'lsp-bridge-find-def)
    (define-key map (kbd "D") 'lsp-bridge-find-def-other-window)
    (define-key map (kbd "r") 'lsp-bridge-find-references)
    (define-key map (kbd "i") 'lsp-bridge-find-impl)
    (define-key map (kbd "I") 'lsp-bridge-find-impl-other-window)
    (define-key map (kbd "t") 'lsp-bridge-find-type-def)
    (define-key map (kbd "T") 'lsp-bridge-find-type-def-other-window)
    (define-key map (kbd "p") 'lsp-bridge-peek)
    (define-key map (kbd "P") 'lsp-bridge-peek-through)
    ;; 리팩토링
    (define-key map (kbd "R") 'lsp-bridge-rename)
    (define-key map (kbd "a") 'lsp-bridge-code-action)
    (define-key map (kbd "f") 'lsp-bridge-code-format)
    (define-key map (kbd "c") 'lsp-bridge-incoming-call-hierarchy)
    (define-key map (kbd "C") 'lsp-bridge-outgoing-call-hierarchy)
    ;; 문서
    (define-key map (kbd "h") 'lsp-bridge-popup-documentation)
    (define-key map (kbd "H") 'lsp-bridge-show-documentation)
    (define-key map (kbd "s") 'lsp-bridge-signature-help-fetch)
    ;; 진단
    (define-key map (kbd "n") 'lsp-bridge-diagnostic-jump-next)
    (define-key map (kbd "N") 'lsp-bridge-diagnostic-jump-prev)
    (define-key map (kbd "l") 'lsp-bridge-diagnostic-list)
    (define-key map (kbd "L") 'lsp-bridge-workspace-diagnostic-list)
    map)
  "LSP Bridge prefix keymap (s-l).")

;; 전역 키 설정
(global-set-key (kbd "s-l") 'lsp-bridge-prefix-map)

;; lsp-bridge-mode 활성화 시 mode-map에 prefix 추가
(add-hook 'lsp-bridge-mode-hook
          (lambda ()
            (define-key lsp-bridge-mode-map (kbd "s-l") 'lsp-bridge-prefix-map)))

;; lsp-bridge-peek evil 키 override
(add-hook 'lsp-bridge-peek-mode-hook
          (lambda ()
            (when (bound-and-true-p evil-local-mode)
              (define-key evil-normal-state-local-map (kbd "n") 'lsp-bridge-peek-file-content-next-line)
              (define-key evil-normal-state-local-map (kbd "p") 'lsp-bridge-peek-file-content-prev-line)
              (define-key evil-normal-state-local-map (kbd "N") 'lsp-bridge-peek-list-next-line)
              (define-key evil-normal-state-local-map (kbd "P") 'lsp-bridge-peek-list-prev-line)
              (define-key evil-normal-state-local-map (kbd "RET") 'lsp-bridge-peek-jump))))

;; ─────────────────────────────────────────────────────────────
;; DAP 키맵
;; ─────────────────────────────────────────────────────────────

;; prefix map 정의
(defvar dap-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "d a") 'dap-delete-all-sessions)
    (define-key map (kbd "b a") 'dap-breakpoint-add)
    (define-key map (kbd "b d") 'dap-breakpoint-delete)
    (define-key map (kbd "b r") 'dap-breakpoint-delete-all)
    (define-key map (kbd "r") 'dap-debug-last)
    map)
  "DAP prefix keymap (C-t).")

;; 전역 키 설정
(global-set-key (kbd "C-t") 'dap-prefix-map)

;; ─────────────────────────────────────────────────────────────
;; Completion 키맵
;; ─────────────────────────────────────────────────────────────

;; 디렉토리 단위 삭제 함수 (파일 경로 입력용)
(defun my-backward-kill-directory ()
  "Delete backward to the previous directory (keep trailing /)."
  (interactive)
  (let* ((prompt-end (minibuffer-prompt-end))
         (end (point))
         (start (max prompt-end (1- end))))
    (goto-char start)
    (skip-chars-backward "^/" prompt-end)
    (condition-case err
        (delete-region (point) end)
      (error nil))))

;; 2단계 TAB 완성: 첫 TAB은 공통 접두사 확장, 두 번째 TAB은 후보 삽입
(defun my/corfu-expand-or-complete ()
  "Try to expand common prefix first, then complete candidate.
First TAB expands common prefix across all candidates.
Second TAB inserts the selected candidate."
  (interactive)
  (if (corfu--preview-current-p)
      ;; 후보가 선택된 상태면 바로 삽입
      (corfu-complete)
    ;; 공통 접두사 확장을 시도
    (if (corfu-expand)
        ;; 확장이 성공했으면 팝업 유지 (확장됨)
        nil
      ;; 확장이 실패했으면 (더 이상 확장할 공통 접두사가 없음) 후보 삽입
      (corfu-complete))))

;; Completion wrapper 함수
(defun my/corfu-complete-or-start ()
  "Start completion if not active, otherwise expand-or-complete."
  (interactive)
  (if (bound-and-true-p completion-in-region-mode)
      ;; Completion이 활성화되어 있으면 expand-or-complete
      (my/corfu-expand-or-complete)
    ;; Completion이 비활성화되어 있으면
    (if (bound-and-true-p lsp-bridge-mode)
        ;; lsp-bridge 모드이면 predicate 우회하여 직접 API 호출
        (progn
          ;; delete 명령 플래그 리셋
          (setq lsp-bridge-last-change-is-delete-command-p nil)
          ;; 수동 completion 플래그 설정
          (setq lsp-bridge-manual-complete-flag t)
          (lsp-bridge-record-last-change-position)
          (lsp-bridge-call-file-api "try_completion"
                                    (lsp-bridge--position)
                                    (acm-char-before)
                                    (acm-get-input-prefix))
          (lsp-bridge-complete-other-backends))
      ;; lsp-bridge 모드가 아니면 표준 completion
      (completion-at-point))))

;; Completion 글로벌 키
(global-set-key (kbd "C-SPC") 'my/corfu-complete-or-start)
(global-set-key (kbd "C-@") 'set-mark-command)
(global-set-key (kbd "<f2> u") 'consult-unicode-char)
(global-set-key (kbd "<f2> j") 'consult-set-variable)

;; lsp-bridge 수동 completion 시 공백에서도 popup 허용
(with-eval-after-load 'lsp-bridge
  (defadvice lsp-bridge--not-only-blank-before-cursor (around my-override-manual-complete activate)
    "Allow completion on blank when manually triggered."
    (if lsp-bridge-manual-complete-flag
        (setq ad-return-value t)
      ad-do-it))

  (defadvice lsp-bridge--is-evil-state (around my-override-evil-state activate)
    "Allow completion in any evil state when manually triggered."
    (if lsp-bridge-manual-complete-flag
        (setq ad-return-value t)
      ad-do-it)))

;; Vertico 키맵
(with-eval-after-load 'vertico
  (define-key vertico-map (kbd "DEL") nil)
  (define-key vertico-map (kbd "<delete>") nil)
  (define-key vertico-map (kbd "M-DEL") nil))

;; Corfu 키맵
(with-eval-after-load 'corfu
  (define-key corfu-map (kbd "TAB") 'my/corfu-expand-or-complete)
  (define-key corfu-map (kbd "S-TAB") 'corfu-previous)
  (define-key corfu-map (kbd "RET") 'corfu-send)
  (define-key corfu-map (kbd "C-n") 'corfu-next)
  (define-key corfu-map (kbd "C-p") 'corfu-previous))

;; ── eshell corfu 우회: corfu-map 우선순위 문제 대응 ──────
;; corfu-map이 eshell에서 RET 우선순위를 못 얻는 문제를 우회.
;; eshell-send-input 실행 전 corfu-complete를 먼저 호출.
(defun my/before-eshell-send (&rest _)
  "Complete corfu candidate before sending eshell input.
Fixes corfu-map priority issue in eshell."
  (when (and (bound-and-true-p corfu-mode) completion-in-region--data)
    (corfu-complete)))

(advice-add 'eshell-send-input :before #'my/before-eshell-send)
;; ──────────────────────────────────────────────────────────

;; 미니버퍼에서 명령어별 Delete 키 동작 설정
(add-hook 'minibuffer-setup-hook
          (lambda ()
            (cond
             ;; 파일 경로 관련 명령어: Delete=경로단위, M-DEL=문자단위
             ((memq this-command '(find-file find-file-other-window find-file-other-frame
                                         write-file copy-file dired-do-copy dired-do-rename))
              (local-set-key (kbd "<delete>") #'my-backward-kill-directory)
              (local-set-key (kbd "DEL") #'my-backward-kill-directory)
              (local-set-key (kbd "M-DEL") #'backward-delete-char))
             ;; M-x: Delete=문자단위(기본), M-DEL=단어단위
             ((eq this-command 'execute-extended-command)
              (local-set-key (kbd "M-DEL") #'backward-kill-word)))))

(use-package evil-mc :ensure t
  :init
  (global-evil-mc-mode 1))

;; ─────────────────────────────────────────────────────────────
;; 세션 관리 및 undo
;; ─────────────────────────────────────────────────────────────

(use-package session :ensure t
  :init (add-hook 'after-init-hook 'session-initialize))

(use-package undo-fu :ensure t)

(use-package undo-fu-session
  :ensure t
  :init (add-hook 'after-init-hook 'global-undo-fu-session-mode)
  :config (setq undo-fu-session-incompatible-files '("/COMMIT_EDITMSG\\'" "/git-rebase-todo\\'")))

(use-package outline-indent :ensure t)

;; ─────────────────────────────────────────────────────────────
;; exec-path-from-shell (환경변수 동기화)
;; ─────────────────────────────────────────────────────────────

(use-package exec-path-from-shell
  :ensure t
  :init
  (setq exec-path-from-shell-shell-name "/bin/zsh"
        exec-path-from-shell-arguments '("-l" "-i"))
  (exec-path-from-shell-initialize)
  :config
  ;; 프록시 환경변수를 zsh에서 가져오기 (소문자 + 대문자)
  (dolist (var '("http_proxy" "https_proxy" "all_proxy" "no_proxy"
                 "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY" "NO_PROXY"))
    (add-to-list 'exec-path-from-shell-variables var)))

;; ─────────────────────────────────────────────────────────────
;; Emacs server (emacsclient 지원)
;; ─────────────────────────────────────────────────────────────

(require 'server)
(server-force-delete)
(unless (and (boundp 'server-process)
             (processp server-process)
             (process-live-p server-process))
  (server-start))

;; ─────────────────────────────────────────────────────────────
;; 기타 패키지
;; ─────────────────────────────────────────────────────────────

(use-package vterm :ensure t)

(use-package yasnippet :ensure t
  :config (yas-global-mode 1))

(add-hook 'prog-mode-hook #'hs-minor-mode)

(provide 'interface)
;;; interface.el ends here
