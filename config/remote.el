;;; remote.el --- TRAMP, SSH/RDP 서버 관리, 원격 환경변수 설정 -*- lexical-binding: t; -*-

;;; Commentary:
;; TRAMP, SSH/RDP 서버 관리, eshell 원격 환경변수 자동 로드 통합
;; - TRAMP 기본 설정 (타임아웃, 비밀번호 캐시, auth-source)
;; - SSH/RDP 서버 관리 (org-link, credentials.org)
;; - eshell TRAMP 원격 환경변수 자동 로드
;; - global-path (경로 파싱, TRAMP 자동완성)

;;; Code:

(require 'org)
(require 'org-table)

;; ─────────────────────────────────────────────────────────────
;; TRAMP 기본 설정
;; ─────────────────────────────────────────────────────────────

;; TRAMP 연결 타임아웃 증가 (5분)
(setq tramp-connection-timeout 300)

;; 비밀번호 1년 캐시 (Emacs 재시작 또는 tramp-cleanup-connection 전까지 유지)
(setq password-cache-expiry 31536000)  ; 1년 = 365일 * 24시간 * 60분 * 60초

;; auth-source 캐시 설정 (TRAMP sudo 연결용)
(setq auth-source-do-cache t
      auth-source-cache-expiry 31536000)  ; 1년

;; TRAMP auto-save 파일을 로컬 /tmp에 저장 허용 (프롬프트 제거)
(setq tramp-allow-unsafe-temporary-files t)

;; TRAMP 경로에서 VC 자동 비활성화 (hook 방식)
(add-hook 'find-file-hook
          (lambda ()
            (when (file-remote-p default-directory)
              (setq-local vc-handled-backends nil))))

;; ─────────────────────────────────────────────────────────────
;; SSH ControlMaster 설정 (연결 재사용)
;; ─────────────────────────────────────────────────────────────

(eval-after-load 'tramp
  '(progn
     (setq tramp-connection-properties
           (cons (list (regexp-quote "ssh") "login-args"
                       '(("-l" "%u") ("-p" "%p")
                         ("-o" "ControlMaster=auto")
                         ("-o" "ControlPath=/tmp/ssh-tramp-%%r@%%h:%%p")
                         ("-o" "ControlPersist=yes")
                         ("%h")))
                 (cl-remove-if (lambda (x)
                                 (and (equal (car x) (regexp-quote "ssh"))
                                      (equal (cadr x) "login-args")))
                               tramp-connection-properties)))))

;; ─────────────────────────────────────────────────────────────
;; SSH/RDP 서버 관리
;; ─────────────────────────────────────────────────────────────

(defgroup ssh-servers nil
  "SSH/RDP server management from org files."
  :group 'tools)

(defcustom ssh-servers-file "~/.ssh/servers.org"
  "Path to servers.org file."
  :type 'file
  :group 'ssh-servers)

(defcustom ssh-servers-credentials-file "~/.ssh/credentials.org"
  "Path to credentials.org file."
  :type 'file
  :group 'ssh-servers)

;; Hash table: "host:port" → tag 매핑
(defvar ssh-servers--tag-map (make-hash-table :test 'equal)
  "서버 주소(host:port)를 태그에 매핑하는 hash table.")

;; ── 기본 유틸리티 ──────────────────────────────────────────

(defun ssh-servers--current-tag ()
  "현재 org heading의 첫 번째 태그 반환."
  (when (derived-mode-p 'org-mode)
    (car (org-get-tags nil t))))

(defun ssh-servers--current-row ()
  "현재 테이블 행을 plist로 반환 (:name :host :port :account :tag)."
  (when (and (derived-mode-p 'org-mode) (org-at-table-p))
    (let* ((tag (ssh-servers--current-tag))
           (is-cred (and buffer-file-name
                         (string-match-p "credentials\\.org$" buffer-file-name)))
           (line (buffer-substring-no-properties
                  (line-beginning-position) (line-end-position)))
           (cells (when (string-match-p "^|" line)
                    (split-string (substring line 1 -1) "|"))))
      (when (and cells (>= (length cells) 2))
        (if is-cred
            (when (not (string-match-p "^-+$\\|account" (downcase (string-trim (nth 0 cells)))))
              (list :account (string-trim (nth 0 cells))
                    :password (string-trim (nth 1 cells))
                    :tag tag))
          (when (and (>= (length cells) 4)
                     (not (string-match-p "^-+$\\|name" (downcase (string-trim (nth 0 cells))))))
            (list :name (string-trim (nth 0 cells))
                  :host (string-trim (nth 1 cells))
                  :port (string-trim (nth 2 cells))
                  :account (string-trim (nth 3 cells))
                  :tag tag)))))))

;; ── credentials.org 조회 ───────────────────────────────────

(defun ssh-servers--get-cred-table (tag)
  "credentials.org에서 TAG heading의 테이블을 org-table-to-lisp로 반환."
  (when (file-exists-p ssh-servers-credentials-file)
    (with-temp-buffer
      (insert-file-contents ssh-servers-credentials-file)
      (org-mode)
      (goto-char (point-min))
      (when (re-search-forward
             (format "^\\*+ %s\\(?:[ \t]+:\\|\\s-*$\\)" (regexp-quote tag))
             nil t)
        (forward-line 1)
        (when (org-at-table-p)
          (org-table-to-lisp))))))

(defun ssh-servers--find-password (tag account)
  "TAG와 ACCOUNT에 해당하는 비밀번호를 credentials.org에서 조회."
  (when-let ((table (ssh-servers--get-cred-table tag)))
    (cl-loop for row in (cdr table)  ; 헤더 제외
             when (and (listp row)
                       (>= (length row) 2)
                       (not (string-match-p "^-+$" (car row)))
                       (not (string= (downcase (string-trim (car row))) "account"))
                       (string= (string-trim (car row)) account))
             return (string-trim (cadr row)))))

;; ── TRAMP 비밀번호 자동 입력 ───────────────────────────────

(eval-after-load 'tramp
  '(progn
     (advice-add 'tramp-read-passwd :around
                 (lambda (orig-fun proc &optional prompt)
                   (condition-case err
                       (let* ((vec (process-get proc 'tramp-vector))
                              (method (and vec (tramp-file-name-method vec)))
                              (user (substring-no-properties (or (tramp-file-name-user vec) "")))
                              (host-raw (substring-no-properties (or (tramp-file-name-host vec) "")))
                              (host (if (and host-raw (string-match "^\\([^#]+\\)" host-raw))
                                        (match-string 1 host-raw)
                                      host-raw))
                              (port (and vec (or (tramp-file-name-port vec) 22)))
                              (key (format "%s:%s" host port))
                              (tag-info (gethash key ssh-servers--tag-map))
                              (tag (car tag-info))
                              (ssh-user (cdr tag-info)))
                         (if (or (null vec)
                                 (null method)
                                 (not (member method '("ssh" "sudo"))))
                             (funcall orig-fun proc prompt)
                           (let* ((cache-user (or ssh-user user))
                                  (spec (list :host (format "%s#%s" host port)
                                              :user cache-user
                                              :port method))
                                  (cached (auth-source-recall spec)))
                             (if cached
                                 cached
                               (if (and tag (not (string-empty-p user)))
                                   (let ((password (ssh-servers--find-password tag (or ssh-user user))))
                                     (if password
                                         (progn
                                           (auth-source-remember spec password)
                                           password)
                                       (funcall orig-fun proc prompt)))
                                 (funcall orig-fun proc prompt))))))
                     (error (funcall orig-fun proc prompt)))))))

;; ── SSH 기능 ───────────────────────────────────────────────

(defun ssh-servers--connect (server)
  "SERVER에 TRAMP로 접속 후 eshell 실행. sudo multi-hop으로 접속."
  (let* ((tag (plist-get server :tag))
         (host (plist-get server :host))
         (port (plist-get server :port))
         (user (or (and (not (string-empty-p (plist-get server :account)))
                        (plist-get server :account))
                   "USER"))
         (path (format "/ssh:%s@%s#%s|sudo:root@%s#%s:/home/%s"
                       user host port host port user))
         (key (format "%s:%s" host port)))
    (puthash key (cons tag user) ssh-servers--tag-map)
    (let ((buf (generate-new-buffer "*eshell*")))
      (with-current-buffer buf
        (eshell-mode)
        (setq default-directory path))
      (pop-to-buffer buf))))

(defun ssh-servers--copy-ssh (server)
  "SSH 명령어를 kill-ring에 복사."
  (let ((cmd (format "ssh -p %s %s@%s"
                     (plist-get server :port)
                     (plist-get server :account)
                     (plist-get server :host))))
    (kill-new cmd)
    (message "SSH command copied: %s" cmd)))

(defun ssh-servers--copy-pass (tag account)
  "TAG의 ACCOUNT 비밀번호를 kill-ring에 복사."
  (let ((password (ssh-servers--find-password tag account)))
    (cond ((string-empty-p account)
           (message "No account specified"))
          ((null password)
           (message "No password found for '%s' in '%s'" account tag))
          (t (kill-new password)
             (message "Password copied for %s" account)))))

;; ── RDP 기능 ───────────────────────────────────────────────

(defun ssh-servers--connect-rdp (server)
  "SERVER에 sdl-freerdp로 접속."
  (let* ((tag (plist-get server :tag))
         (host (plist-get server :host))
         (port (plist-get server :port))
         (account (plist-get server :account))
         (password (ssh-servers--find-password tag account)))
    (if (and host port account password)
        (progn
          (start-process "sdl-freerdp" nil
                         "sdl-freerdp"
                         (format "/v:%s:%s" host port)
                         (format "/u:%s" account)
                         (format "/p:%s" password)
                         "/proxy:socks5://localhost:1081"
                         "/dynamic-resolution"
                         "+toggle-fullscreen")
          (message "Starting sdl-freerdp: %s@%s:%s" account host port))
      (message "Missing required fields or password for RDP connection"))))

(defun ssh-servers--copy-rdp-address (server)
  "RDP 주소(host:port)를 kill-ring에 복사."
  (let ((addr (format "%s:%s" (plist-get server :host) (plist-get server :port))))
    (kill-new addr)
    (message "RDP address copied: %s" addr)))

;; ── org-link 핸들러 ────────────────────────────────────────

(defun ssh-servers--link-follow (path)
  "ssh: 링크 액션 처리."
  (let ((row (ssh-servers--current-row)))
    (cond ((null row) (message "Not in a table row"))
          ((string= path "connect")
           (if (plist-get row :host)
               (ssh-servers--connect row)
             (message "No host")))
          ((string= path "copy")
           (if (plist-get row :host)
               (ssh-servers--copy-ssh row)
             (message "No host")))
          ((string= path "pass")
           (if-let ((pwd (plist-get row :password)))
               (if (string-empty-p pwd)
                   (message "No password")
                 (kill-new pwd)
                 (message "Password copied"))
             (ssh-servers--copy-pass (plist-get row :tag)
                                     (plist-get row :account))))
          (t (message "Unknown ssh path: %s" path)))))

(defun ssh-servers--link-follow-rdp (path)
  "rdp: 링크 액션 처리."
  (let ((row (ssh-servers--current-row)))
    (cond ((null row) (message "Not in a table row"))
          ((string= path "connect")
           (if (plist-get row :host)
               (ssh-servers--connect-rdp row)
             (message "No host")))
          ((string= path "copy-address")
           (if (plist-get row :host)
               (ssh-servers--copy-rdp-address row)
             (message "No host")))
          ((string= path "pass")
           (if-let ((pwd (plist-get row :password)))
               (if (string-empty-p pwd)
                   (message "No password")
                 (kill-new pwd)
                 (message "Password copied"))
             (ssh-servers--copy-pass (plist-get row :tag)
                                     (plist-get row :account))))
          (t (message "Unknown rdp path: %s" path)))))

(org-link-set-parameters "ssh" :follow #'ssh-servers--link-follow)
(org-link-set-parameters "rdp" :follow #'ssh-servers--link-follow-rdp)

;; ─────────────────────────────────────────────────────────────
;; eshell TRAMP 원격 환경변수 자동 로드
;; ─────────────────────────────────────────────────────────────

(defcustom my/tramp-remote-env-protected-vars
  '("TERM" "INSIDE_EMACS" "PAGER" "SHELL" "EMACS" "EMACS_SERVER_FILE"
    "ENV" "TMOUT" "LC_CTYPE" "CDPATH" "HISTORY" "MAIL" "MAILCHECK"
    "MAILPATH" "autocorrect" "correct" "PWD" "SHLVL" "_"
    "PROMPT_COMMAND" "PS1" "PS2")
  "원격 .bashrc에서 읽어와도 덮어쓰지 않을 환경변수 목록."
  :type '(repeat string)
  :group 'eshell)

(defcustom my/tramp-remote-env-debug nil
  "non-nil이면 디버그 메시지를 *Messages*에 출력."
  :type 'boolean
  :group 'eshell)

;; buffer-local 변수들
(defvar-local my-original-exec-path nil
  "eshell 시작 시의 원래 exec-path를 저장.")

(defvar-local my-original-process-environment nil
  "eshell 시작 시의 원래 process-environment를 저장.")

(defvar-local my-original-eshell-variable-aliases-list nil
  "eshell 시작 시의 원래 eshell-variable-aliases-list를 저장.")

(defvar-local my-remote-path-cache nil
  "원격 서버의 PATH 값을 저장.")

(defvar-local my-remote-env-vars nil
  "원격 서버의 환경변수들을 저장 (alist 형태, PATH 제외).")

(defvar-local my--tramp-env-loaded-p nil
  "원격 환경변수를 이미 로드했는지 여부.")

;; 헬퍼 함수: 환경변수 alist를 process-environment에 적용
(defun my/tramp-apply-env-vars (env-alist base-env)
  "ENV-ALIST의 환경변수를 BASE-ENV에 적용하여 반환."
  (let ((result (copy-sequence base-env)))
    (dolist (env-pair env-alist result)
      (let ((key (car env-pair))
            (val (cdr env-pair)))
        (setq result
              (cl-remove-if (lambda (x) (string-prefix-p (concat key "=") x))
                            result))
        (push (format "%s=%s" key val) result)))))

;; 디렉토리 변경 시 환경변수 업데이트
(defun my/tramp-eshell-update-env ()
  "디렉토리 변경 시 환경변수를 적절히 업데이트."
  (if (file-remote-p default-directory)
      (when (and my-remote-env-vars my-remote-path-cache)
        ;; exec-path는 로컬 유지, tramp-remote-path만 설정
        (setq-local tramp-remote-path (split-string my-remote-path-cache ":"))
        (setq-local process-environment
                    (my/tramp-apply-env-vars my-remote-env-vars
                                             my-original-process-environment))
        (when my/tramp-remote-env-debug
          (message "[tramp-env] 원격 환경변수로 설정: %s" default-directory)))
    ;; 로컬로 돌아왔을 때 완전한 초기화
    (setq-local exec-path (or my-original-exec-path exec-path))
    (setq-local process-environment 
                (or my-original-process-environment process-environment))
    (setq-local eshell-variable-aliases-list 
                (or my-original-eshell-variable-aliases-list eshell-variable-aliases-list))
    ;; 원격 관련 변수 초기화
    (setq-local my-remote-env-vars nil)
    (setq-local my-remote-path-cache nil)
    (setq-local my--tramp-env-loaded-p nil)
    (when my/tramp-remote-env-debug
      (message "[tramp-env] 로컬 환경변수로 복원 및 초기화 완료"))))

;; eshell-search-path에 advice 추가
(defun my/tramp-eshell-search-path (orig-fun command)
  "TRAMP 환경에서 eshell-search-path를 개선.
TRAMP 환경에서는 tramp-remote-path를 사용하여 원격 명령을 검색합니다."
  (or (funcall orig-fun command)
      (when (file-remote-p default-directory)
        ;; TRAMP 환경에서는 tramp-remote-path를 사용하여 명령 검색
        (let* ((remote-id (file-remote-p default-directory))
               (remote-paths (or tramp-remote-path
                                 (split-string my-remote-path-cache ":" t)))
               (remote-cmd (locate-file command
                                        (mapcar (lambda (p) (concat remote-id p))
                                                remote-paths)
                                        exec-suffixes)))
          (when (and remote-cmd (file-executable-p remote-cmd))
            remote-cmd)))))

(advice-add 'eshell-search-path :around #'my/tramp-eshell-search-path)

(defun my/tramp-eshell-load-remote-env ()
  "TRAMP 연결 시 원격 환경변수를 자동으로 로드."
  (when (and (file-remote-p default-directory)
             (not my--tramp-env-loaded-p))
    (let* ((remote-id (file-remote-p default-directory))
           (dir default-directory)
           (buf (current-buffer)))
      (when my/tramp-remote-env-debug
        (message "[tramp-env] 환경변수 로드 시작: %s" remote-id))
      (run-at-time
       2 nil
       (lambda (b d rid)
         (when (buffer-live-p b)
           (with-current-buffer b
             (let ((default-directory d))
               (condition-case err
                   (let* ((output (with-temp-buffer
                                    (let ((default-directory d))
                                      (when my/tramp-remote-env-debug
                                        (message "[tramp-env] 원격 실행: bash -lic 'env -0'"))
                                      (process-file "bash" nil '(t nil) nil "-lic" "env -0")
                                      (buffer-string))))
                          (env-vars (split-string output "\0" t))
                          (count 0)
                          (remote-path nil))
                     (when my/tramp-remote-env-debug
                       (message "[tramp-env] 수신: %d 바이트, %d 개 변수"
                                (length output) (length env-vars)))
                     (when (> (length output) 0)
                       (setq-local my-remote-env-vars nil)
                       (dolist (env-var env-vars)
                         (when (string-match "^\\([A-Za-z_][A-Za-z0-9_]*\\)=\\(.*\\)$" env-var)
                           (let ((key (match-string 1 env-var))
                                 (val (match-string 2 env-var)))
                             (unless (member key my/tramp-remote-env-protected-vars)
                               (if (string= key "PATH")
                                   (progn
                                     (setq remote-path val)
                                     (setq-local my-remote-path-cache val))
                                 (push (cons key val) my-remote-env-vars))
                               (cl-incf count)))))
                       (setq-local process-environment
                                   (my/tramp-apply-env-vars my-remote-env-vars
                                                            my-original-process-environment))
                        (when remote-path
                          (setq-local eshell-variable-aliases-list
                                      (cons (list "PATH"
                                                  (cons (lambda () my-remote-path-cache)
                                                        (lambda (_ value)
                                                          (eshell-set-path value)
                                                          value))
                                                  t t)
                                            (cl-remove-if (lambda (x) (string= (car x) "PATH"))
                                                          eshell-variable-aliases-list)))
                          (setq-local tramp-remote-path (split-string remote-path ":"))
                          (when my/tramp-remote-env-debug
                            (message "[tramp-env] PATH 설정 완료: %s" remote-path)))
                       (setq-local my--tramp-env-loaded-p t)
                       (message "원격 환경변수 로드 완료: %d 개" count)))
                 (error
                  (message "[tramp-env] 환경변수 로드 실패: %s"
                           (error-message-string err))))))))
       buf dir remote-id))))

;; FIXME: TRAMP make-process와 충돌하여 임시 비활성화
;; (add-hook 'eshell-mode-hook #'my/tramp-eshell-load-remote-env)
;; (add-hook 'eshell-directory-change-hook #'my/tramp-eshell-load-remote-env)
(add-hook 'eshell-directory-change-hook #'my/tramp-eshell-update-env)

;; ─────────────────────────────────────────────────────────────
;; global-path (경로 파싱, TRAMP 자동완성)
;; ─────────────────────────────────────────────────────────────

;; 0단계: //로 시작하는 경로를 항상 로컬 루트로 변환
(defun my/eshell-parse-double-slash-local ()
  "//로 시작하는 경로를 항상 로컬 루트로 변환."
  (when (and (not eshell-current-argument)
             (not eshell-current-quoted)
             (looking-at "//"))
    (add-hook 'eshell-current-modifiers
              (lambda (file)
                (if (string-prefix-p "//" file)
                    (substring file 1)
                  file))
              -60)
    (forward-char 2)
    (char-to-string (char-before))))

;; 1단계: TRAMP 환경에서 절대 경로를 원격으로 변환
(defun my/eshell-parse-absolute-path-remote ()
  "TRAMP 환경에서 절대 경로를 원격으로 변환."
  (when (and (not eshell-current-argument)
             (not eshell-current-quoted)
             (eq (char-after) ?/)
             (not (looking-at "//"))
             (file-remote-p default-directory))
    (add-hook 'eshell-current-modifiers
              (lambda (file)
                (if (and (string-prefix-p "/" file)
                         (not (string-prefix-p "//" file))
                         (not (string-match-p "^/[a-z]+:" file)))
                    (concat (file-remote-p default-directory) file)
                  file))
              -50)
    (forward-char)
    (char-to-string (char-before))))

;; 2단계: TRAMP 환경에서 ~ 경로를 원격 홈으로 변환
(defun my/eshell-parse-tilde-path-remote ()
  "TRAMP 환경에서 ~ 경로를 원격 홈으로 변환."
  (when (and (not eshell-current-argument)
             (not eshell-current-quoted)
             (eq (char-after) ?~)
             (file-remote-p default-directory))
    (add-hook 'eshell-current-modifiers
              (lambda (file)
                (if (string-prefix-p "~" file)
                    (let* ((remote-prefix (file-remote-p default-directory))
                           (vec (tramp-dissect-file-name default-directory))
                           (remote-home (tramp-get-home-directory vec)))
                      (if remote-home
                          (concat remote-prefix remote-home)
                        (concat remote-prefix "/root")))
                  file))
              -50)
    (forward-char)
    (char-to-string (char-before))))

;; 3단계: // 자동완성을 위한 CAPF
(defun my/eshell-double-slash-capf ()
  "TRAMP 환경에서도 //로 시작하는 경로의 로컬 자동완성 제공."
  (let* ((beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end (point))
         (arg (buffer-substring-no-properties beg end)))
    (when (string-prefix-p "//" arg)
      (list beg end
            (lambda (string pred action)
              (let ((default-directory "/"))
                (funcall #'completion-file-name-table string pred action)))))))

;; 3.5단계: bash-completion이 //를 무시하도록 advice
(defun my/bash-completion-ignore-double-slash (orig-fn &rest args)
  "//로 시작하는 경로는 bash-completion이 무시하도록 함."
  (let* ((beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end (point))
         (arg (buffer-substring-no-properties beg end)))
    (if (string-prefix-p "//" arg)
        nil
      (apply orig-fn args))))

(with-eval-after-load 'bash-completion
  (advice-add 'bash-completion-capf-nonexclusive :around #'my/bash-completion-ignore-double-slash))

;; 4단계: SSH 호스트 목록 추출
(defun my/tramp-get-ssh-hosts ()
  "현재 연결된 SSH 호스트 목록 반환 (포트번호 포함)"
  (let ((hosts nil))
    (maphash (lambda (key value)
               (when (and (tramp-file-name-p key)
                          (string= (tramp-file-name-method key) "ssh"))
                 (let* ((user (tramp-file-name-user key))
                        (host (tramp-file-name-host key))
                        (port (tramp-file-name-port key)))
                   (push (if port
                             (format "%s@%s#%s" user host port)
                           (format "%s@%s" user host))
                         hosts))))
             tramp-cache-data)
    hosts))

;; 5단계: /ssh: 자동완성을 위한 CAPF
(defun my/tramp-ssh-capf ()
  "/ssh: 입력 시 SSH 호스트 목록으로 자동완성 (호스트 미완성 시에만)"
  (let* ((beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end (point))
         (arg (buffer-substring-no-properties beg end))
         (colon-count (cl-count ?: arg)))
    (when (and (string-prefix-p "/ssh:" arg)
               (<= colon-count 1))
      (let ((hosts (my/tramp-get-ssh-hosts)))
        (list beg end
              (lambda (string pred action)
                (let ((candidates (mapcar (lambda (h) (concat "/ssh:" h)) hosts)))
                  (complete-with-action action candidates string pred))))))))

;; 6단계: bash-completion이 /ssh: 호스트 미완성 시 무시
(defun my/bash-completion-ignore-ssh (orig-fn &rest args)
  "bash-completion이 /ssh: 호스트 미완성 시 무시."
  (let* ((beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end (point))
         (arg (buffer-substring-no-properties beg end))
         (colon-count (cl-count ?: arg)))
    (if (and (string-prefix-p "/ssh:" arg)
             (<= colon-count 1))
        nil
      (apply orig-fn args))))

(with-eval-after-load 'bash-completion
  (advice-add 'bash-completion-capf-nonexclusive :around #'my/bash-completion-ignore-ssh))

;; 7단계: bash-completion이 TRAMP 경로를 처리하도록 수정
(defun my/bash-completion-tramp-fix (orig-fn &rest args)
  "bash-completion이 TRAMP 경로를 처리하도록 수정."
  (let* ((beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end (point))
         (arg (buffer-substring-no-properties beg end)))
    (if (and (string-prefix-p "/" arg)
             (string-match "\\`/\\([^:]+\\):\\([^:]*\\):" arg))
        (let* ((remote-prefix (match-string 0 arg))
               (default-directory remote-prefix))
          (apply orig-fn args))
      (apply orig-fn args))))

(with-eval-after-load 'bash-completion
  (advice-add 'bash-completion-capf-nonexclusive :around #'my/bash-completion-tramp-fix))

;; 8단계: eshell 모드 훅에 등록
(defun my/global-path-setup ()
  "eshell 모드에서 global-path 설정."
  (add-hook 'eshell-parse-argument-hook #'my/eshell-parse-double-slash-local nil t)
  (add-hook 'eshell-parse-argument-hook #'my/eshell-parse-absolute-path-remote nil t)
  (add-hook 'eshell-parse-argument-hook #'my/eshell-parse-tilde-path-remote nil t)
  (add-hook 'completion-at-point-functions #'my/eshell-double-slash-capf nil t)
  (add-hook 'completion-at-point-functions #'my/tramp-ssh-capf nil t))

(add-hook 'eshell-mode-hook #'my/global-path-setup)

(provide 'remote)
;;; remote.el ends here
