;;; agent-shell-setting.el --- Agent Shell configuration for OpenCode
;;; Commentary:
;; xenodium/agent-shell 패키지 설정
;; ACP (Agent Client Protocol)를 통해 OpenCode 및 다양한 LLM 에이전트 사용
;; https://github.com/xenodium/agent-shell
;;; Code:

;; 의존성: acp.el, shell-maker (MELPA에서 자동 설치)

(use-package shell-maker
  :straight (shell-maker :type git :host github :repo "xenodium/shell-maker")
  :after acp)

(use-package acp
  :straight (acp :type git :host github :repo "xenodium/acp.el"))

(use-package agent-shell
  :straight (agent-shell :type git :host github :repo "lazyskulptor/agent-shell" :branch "main")
  :after (acp shell-maker)
  :config
  ;; 기본 설정
  (setq agent-shell-preferred-agent-config 
        (agent-shell-opencode-make-agent-config))  ; OpenCode를 기본 에이전트로 설정

  ;; Transcript 저장 위치를 ~/.emacs.d/.agent-shell/transcripts/로 고정
  ;; 프로젝트별로 흩어지는 대화 기록을 한 곳에 모아 검색/추출 가능하게 함
  (defun my-agent-shell-transcript-file-path ()
    "Return a transcript file path in ~/.emacs.d/.agent-shell/transcripts/."
    (let* ((dir (expand-file-name ".agent-shell/transcripts" user-emacs-directory))
           (filename (format-time-string "%F-%H-%M-%S.md"))
           (filepath (expand-file-name filename dir)))
      (unless (file-directory-p dir)
        (make-directory dir t))
      filepath))

  (setq agent-shell-transcript-file-path-function #'my-agent-shell-transcript-file-path)
  
  ;; 버퍼 이름 형식
  (setq agent-shell-buffer-name-format "*Agent Shell: %s*")
  
  ;; 컨텍스트 사용량 표시 (헤더 및 모드라인에 표시)
  (setq agent-shell-show-context-usage-indicator 'detailed)

  ;; 각 응답 끝에 토큰 사용량 상세 박스 표시
  (setq agent-shell-show-usage-at-turn-end t)

  ;; 토큰 사용량을 상단 헤더에 추가 (input/output/total)
  (defun my-agent-shell-token-header-indicator ()
    "Return a short token usage string for the header."
    (when-let* ((state (agent-shell--state))
                (usage (map-elt state :usage))
                ((agent-shell--usage-has-data-p usage)))
      (let ((parts (delq nil
                         (list
                          (when (> (or (map-elt usage :input-tokens) 0) 0)
                            (format "%s in" (agent-shell--format-number-compact (map-elt usage :input-tokens))))
                          (when (> (or (map-elt usage :output-tokens) 0) 0)
                            (format "%s out" (agent-shell--format-number-compact (map-elt usage :output-tokens))))
                          (when (> (or (map-elt usage :total-tokens) 0) 0)
                            (format "%s tot" (agent-shell--format-number-compact (map-elt usage :total-tokens))))))))
        (when parts
          (propertize (string-join parts " · ") 'font-lock-face 'font-lock-comment-face)))))

  (defun my-agent-shell-add-token-to-header ()
    "Add token usage indicator to header line after agent-shell updates it."
    (when (derived-mode-p 'agent-shell-mode)
      (when-let ((indicator (my-agent-shell-token-header-indicator)))
        (setq header-line-format
              (concat (if (stringp header-line-format) header-line-format "")
                      (if (and header-line-format (> (length header-line-format) 0)) " ➤ " "")
                      indicator))
        (force-mode-line-update))))

  (advice-add 'agent-shell--update-header-and-mode-line :after #'my-agent-shell-add-token-to-header)

  ;; busy 인디케이터 애니메이션
  (setq agent-shell-show-busy-indicator t)
  
  ;; 하이라이트 설정
  (setq agent-shell-highlight-blocks t)
  
  ;; DWIM 컨텍스트 소스 (line 제외 — org table row 자동 삽입 방지)
  (setq agent-shell-context-sources '(files region error))
  
  ;; 파일 완성 활성화
  (setq agent-shell-file-completion-enabled t)
  
  ;; thought process 기본 확장
  (setq agent-shell-thought-process-expand-by-default nil)
  
  ;; tool use 기본 확장  
  (setq agent-shell-tool-use-expand-by-default nil)
  
  ;; 사용자 메시지 기본 확장
  (setq agent-shell-user-message-expand-by-default nil)
  
  ;; 사용 가능한 에이전트 설정 (OpenCode 중심)
  (setq agent-shell-agent-configs
        (list (agent-shell-opencode-make-agent-config)))
  
  ;; 세션 복원 시 이전 메시지 표시
  ;; 'minimal: 제목만, 'first-last: 첫 메시지+마지막 응답, 'full: 전체 리플레이
  (setq agent-shell-session-restore-verbosity 'first-last)
  
  ;; Evil 모드 설정
  (with-eval-after-load 'evil
    (evil-define-key 'insert agent-shell-mode-map 
      (kbd "RET") #'newline)
    (evil-define-key 'normal agent-shell-mode-map 
      (kbd "RET") #'comint-send-input)
    
    ;; Super + Enter로 프롬프트 전송 (Command + Enter on Mac)
    (evil-define-key 'insert agent-shell-mode-map
      (kbd "s-<return>") #'shell-maker-submit)
    
    ;; diff 버퍼는 Emacs 모드로 시작
    (add-hook 'diff-mode-hook
              (lambda ()
                (when (string-match-p "\\*agent-shell-diff\\*" (buffer-name))
                  (evil-emacs-state))))
    
    ;; Bash tool 실행 시 실제 명령어를 title에 표시
    ;; (upstream PR #636에서 permission dialog에 command 표시 기능이 추가되어 불필요해짐)
    ;; (defun my-agent-shell-bash-command-display (orig-fun state tool-call-id)
    ;;   "Show actual bash command for execute tools."
    ;;   (let ((result (funcall orig-fun state tool-call-id)))
    ;;     (when result
    ;;       (let* ((tool-call (map-nested-elt state `(:tool-calls ,tool-call-id)))
    ;;              (command (map-elt tool-call :command))
    ;;              (kind (map-elt tool-call :kind))
    ;;              (title (map-elt result :title)))
    ;;         (when (and (equal kind "execute") command)
    ;;           (let ((new-title (concat (or title "")
    ;;                                    " "
    ;;                                    (propertize command 'font-lock-face 'font-lock-doc-face))))
    ;;             (setq result (cons (cons :title new-title)
    ;;                               (assq-delete-all :title result)))))))
    ;;     result))
    ;; (advice-add 'agent-shell-make-tool-call-label :around #'my-agent-shell-bash-command-display)
    )

  :bind
  ;; 기본 명령
  ("C-c a a" . agent-shell)                          ; 에이전트 쉘 시작
  ("C-c a o" . agent-shell-opencode-start-agent)           ; OpenCode 직접 시작
  ("C-c a n" . agent-shell-new-shell)                  ; 새 세션 시작
  ("C-c a r" . agent-shell-restart)                  ; 현재 세션 재시작
  ("C-c a R" . agent-shell-resume-session)           ; 세션 재개
  ("C-c a i" . agent-shell-insert-file)              ; 파일 삽입
  ("C-c a c" . agent-shell-clear-buffer)             ; 버퍼 지우기
  ("C-c a d" . agent-shell-delete-interaction-at-point) ; 상호작용 삭제
  ("C-c a s" . agent-shell-send-clipboard-image)      ; 클립보드 이미지 전송
  ("C-c a h" . agent-shell-help-menu)                ; 도움말 메뉴
  ("C-c a l" . agent-shell-reload))                ; 세션 새로고침

;; OpenCode 환경 변수 설정 (필요시)
;; (setq agent-shell-opencode-environment
;;       (agent-shell-make-environment-variables
;;        :inherit-env t))

;; OpenCode 인증 설정 (API 키 사용시)
;; (setq agent-shell-opencode-authentication
;;       (agent-shell-opencode-make-authentication
;;        :api-key (lambda () (auth-source-pass-get 'secret "opencode-api-key"))))

;; MCP 서버 설정 (필요시)
;; (setq agent-shell-mcp-servers
;;       '(((name . "notion")
;;          (type . "http")
;;          (headers . [])
;;          (url . "https://mcp.notion.com/mcp"))))

;; 파일 쓰기 시 비활성화할 minor 모드
(setq agent-shell-write-inhibit-minor-modes '(aggressive-indent-mode))

;; ─────────────────────────────────────────────
;; 원격 OpenCode ACP 설정
;; ─────────────────────────────────────────────
;; TRAMP 버퍼에서 원격 서버의 opencode를 직접 실행
;;
;; 동작 원리:
;;   - acp.el이 make-process를 :file-handler t로 호출
;;   - TRAMP가 SSH 채널을 통해 원격에서 opencode 실행
;;   - stdin/stdout이 SSH를 통해 터널링 (JSON-RPC over SSH)

(setq agent-shell-opencode-acp-command
      '("/home/ezcaretech/.opencode/bin/opencode" "acp"))

;; 로컬/원격 구분하여 opencode 경로 설정
(defun my-agent-shell-set-opencode-command (orig-fn &rest args)
  "TRAMP 버퍼가 아니면 로컬 opencode를 사용하도록 command 설정."
  (let ((buffer (plist-get args :buffer))
        (original-command agent-shell-opencode-acp-command))
    (if (and buffer (buffer-local-value 'default-directory buffer))
        (if (file-remote-p (buffer-local-value 'default-directory buffer))
            ;; TRAMP 버퍼: 원격 경로 유지
            (apply orig-fn args)
          ;; 로컬 버퍼: 로컬 opencode 사용
          (with-current-buffer buffer
            (setq-local agent-shell-opencode-acp-command '("opencode" "acp"))
            (unwind-protect
                (apply orig-fn args)
              (setq-local agent-shell-opencode-acp-command original-command))))
      (apply orig-fn args))))
(advice-add 'agent-shell-opencode-make-client :around #'my-agent-shell-set-opencode-command)
(defun my-agent-shell-cwd-advice (orig-fun)
  "TRAMP 버퍼에서 expand-file-name된 경로를 반환."
  (if (file-remote-p default-directory)
      (expand-file-name default-directory)
    (funcall orig-fun)))
(advice-add 'agent-shell-cwd :around #'my-agent-shell-cwd-advice)

;; executable-find: TRAMP 버퍼에서 원격 파일 검색
(defun my-executable-find-remote (orig-fn command &optional remote)
  "TRAMP 버퍼에서 executable-find를 파일 존재 여부 확인으로 대체."
  (if (file-remote-p default-directory)
      (let ((remote-id (file-remote-p default-directory)))
        (if (file-name-absolute-p command)
            (let ((remote-path (concat remote-id command)))
              (when (file-exists-p remote-path)
                remote-path))
          (let ((paths exec-path) found)
            (while (and paths (not found))
              (let ((path (car paths)))
                (setq paths (cdr paths))
                (when (stringp path)
                  (let* ((local-path (if (file-remote-p path) (substring path (length remote-id)) path))
                         (full-remote (concat remote-id (expand-file-name command local-path))))
                    (when (file-exists-p full-remote)
                      (setq found full-remote))))))
            found)))
    (funcall orig-fn command remote)))
(advice-add 'executable-find :around #'my-executable-find-remote)

;; ─────────────────────────────────────────────
;; agent-shell-org-transcript (GitHub)
;; ─────────────────────────────────────────────
(use-package agent-shell-org-transcript
  :straight (agent-shell-org-transcript :type git :host github :repo "lllShamanlll/agent-shell-org-transcript")
  :demand t
  :after agent-shell
  :config
  (setq agent-shell-org-transcript-directory
        (expand-file-name "agent-shell/transcripts/" "~/Workspace/wiki/"))

  ;; ── Migration bug workaround ─────────────────────────────────────────
  ;; "Invalid use of '\\' in replacement text" 에러 우회
  ;; `agent-shell--org-transcript-convert'의 `\\1' backreference 대신
  ;; `match-string'을 사용하여 백슬래시 포함 텍스트를 안전하게 처리
  (defun my--agent-shell-org-transcript-convert (text)
    "Convert markdown transcript TEXT to org-mode format safely."
    (with-temp-buffer
      (insert text)
      ;; Convert ATX headers: ## Foo -> ** Foo
      (goto-char (point-min))
      (while (re-search-forward "^\\(#+\\) " nil t)
        (replace-match (concat (make-string (length (match-string 1)) ?*) " ")))
      ;; Convert code fences
      (goto-char (point-min))
      (while (re-search-forward "^\\(`\\{3,\\}\\)\\(.*\\)$" nil t)
        (let ((lang (string-trim (match-string 2))))
          (if (string-empty-p lang)
              (replace-match "#+end_src")
            (replace-match (concat "#+begin_src " lang)))))
      ;; Convert block quotes: > text -> #+begin_quote
      (goto-char (point-min))
      (while (re-search-forward "^> \\(.*\\)$" nil t)
        (let ((content (match-string 1)))
          (replace-match (concat "#+begin_quote\n" content "\n#+end_quote"))))
      ;; Convert **bold** to *bold*
      (goto-char (point-min))
      (while (re-search-forward "\\*\\*\\([^*\n]+\\)\\*\\*" nil t)
        (let ((content (match-string 1)))
          (replace-match (concat "*" content "*"))))
      ;; Convert horizontal rules
      (goto-char (point-min))
      (while (re-search-forward "^---+$" nil t)
        (replace-match "-----"))
      (buffer-string)))

  (advice-add 'agent-shell--org-transcript-convert
              :override #'my--agent-shell-org-transcript-convert)
  ;; ────────────────────────────────────────────────────────────────────
  )

;; ─────────────────────────────────────────────
;; ACP 디버깅 로깅
;; ─────────────────────────────────────────────
;; ACP 프로토콜 통신 로그를 활성화하여 opencode ↔ agent-shell 간
;; JSON-RPC 메시지를 버퍼에 기록한다.
;;   *acp-(opencode)-N log*    : STDERR, 파싱 에러, 핸들러 에러
;;   *acp-(opencode)-N traffic*: 모든 JSON-RPC 메시지 (in/out 구조화)
(setq acp-logging-enabled nil)

;; opencode ACP 명령어는 위에서 SSH 경유로 설정됨 (183번 라인 참조)
;; 원격 실행 시 --print-logs, --log-level 옵션은 stderr를 증가시켜
;; ACP 프로토콜 파싱을 방해할 수 있으므로 제외함

;; ─────────────────────────────────────────────
;; Buffer truncation: interaction(대화 턴) 단위 자동 정리
;; ─────────────────────────────────────────────
;; 긴 세션에서 *agent* 버퍼가 무한히 커져 undo-outer-limit 경고가
;; 발생하는 문제를 해결. 완료된 interaction을 세어 오래된 순서대로
;; 자동 삭제한다.

(defcustom agent-shell-max-interactions 20
  "Maximum number of interactions (turns) to keep per agent shell buffer.
Set to nil to disable truncation entirely.
The current (in-progress) interaction is never deleted."
  :type '(choice (integer :tag "Max interactions")
                 (const :tag "No limit" nil))
  :group 'agent-shell
  :local t)

(defun my-agent-shell-truncate-buffer (&rest _)
  "Delete oldest interactions in the current agent shell buffer.

Counts prompts (each prompt marks one interaction boundary) using
`comint-prompt-regexp'.  When the count exceeds
`agent-shell-max-interactions', removes the oldest interactions
from the beginning of the buffer while keeping the most recent
turn(s).

This function is designed to be called from an advice on
`shell-maker-finish-output', so it runs after every completed
agent response."
  (interactive)
  (when (and (derived-mode-p 'agent-shell-mode)
             (numberp agent-shell-max-interactions)
             (> agent-shell-max-interactions 0))
    (save-excursion
      (save-restriction
        (let ((inhibit-read-only t))
          (goto-char (point-min))
          (let (prompt-positions)
            ;; Collect every prompt start position
            (while (re-search-forward comint-prompt-regexp nil t)
              (push (match-beginning 0) prompt-positions))
            (setq prompt-positions (nreverse prompt-positions))
            (let* ((count (length prompt-positions))
                   (to-delete (- count agent-shell-max-interactions)))
              (when (> to-delete 0)
                ;; Delete from buffer start to the first prompt to KEEP
                ;; This removes the oldest 'to-delete' interactions
                ;; and any leading content (e.g. welcome message).
                (let ((delete-end (or (nth to-delete prompt-positions)
                                      (point-max))))
                  (delete-region (point-min) delete-end)
                  ;; Refresh comint-last-prompt markers so they stay valid.
                  (when (and comint-last-prompt
                             (markerp (car comint-last-prompt)))
                    (set-marker (car comint-last-prompt)
                                (max (marker-position (car comint-last-prompt))
                                     delete-end))
                    (set-marker (cdr comint-last-prompt)
                                (max (marker-position (cdr comint-last-prompt))
                                     delete-end))))))))))))

;; Register truncation after every completed interaction.
;; shell-maker-finish-output is called once per agent response,
;; so this fires once per turn — just after the response is fully
;; written to the buffer.
(with-eval-after-load 'shell-maker
  (advice-add 'shell-maker-finish-output :after #'my-agent-shell-truncate-buffer))

(provide 'agent-shell-setting)
;;; agent-shell-setting.el ends here
