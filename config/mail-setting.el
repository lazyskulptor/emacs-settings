;;; mail-setting.el --- Email client (notmuch + smtpmail)  -*- lexical-binding: t; -*-

;;; Commentary:
;; notmuch 기반 이메일 클라이언트 + Gmail SMTP 발송 + wiki 이메일 다이제스트 자동화.
;; 계정 정보는 properties.local.el 의 mail-accounts / mail-digest-senders 에서 참조.

;;; Code:

(require 'smtpmail)

;; ── notmuch ────────────────────────────────────────────────────
;; brew 설치분(notmuch elisp) 사용 — straight 중복 설치 방지
;; 경로는 properties.local.el 의 notmuch-site-lisp-dir 참조
(use-package notmuch
  :straight nil
  :load-path notmuch-site-lisp-dir
  :defer t
  :init
  ;; brew elisp의 autoload 파일을 명시적으로 로드 (use-package :load-path는 autoloads를 처리하지 않음)
  (when notmuch-site-lisp-dir
    (load (expand-file-name "notmuch-autoloads" notmuch-site-lisp-dir) 'noerror 'nomessage))
  :custom
  (notmuch-search-oldest-first nil)
  (notmuch-show-logo nil)
  (notmuch-search-result-format
   '(("date" . "%12s ")
     ("count" . "%-7s ")
     ("authors" . "%-20s ")
     ("subject" . "%s ")))
  :config
  ;; 검색 결과에서 열기 시 read-only 및 정리
  (setq notmuch-search-hide-decoration nil))

;; ── SMTP (message-mode) ────────────────────────────────────────
(defvar my/mail-accounts nil
  "메일 계정 목록. properties.local.el 의 mail-accounts 참조.
형식: ((label \"display-name\" \"addr\") ...).")

(defun my/mail-account-labels ()
  "현재 설정된 메일 계정 라벨 목록."
  (mapcar #'car mail-accounts))

(defun my/mail-account-plist (label)
  "LABEL 계정의 (display-name . addr) plist를 반환."
  (let ((acct (assoc label mail-accounts)))
    (when acct
      (list :name (nth 1 acct) :addr (nth 2 acct)))))

(defun my/mail-set-account (label)
  "현재 message 버퍼의 계정을 LABEL로 설정 (From 헤더 + SMTP 인증)."
  (interactive
   (list (completing-read "Mail account: " (my/mail-account-labels))))
  (let* ((plist (my/mail-account-plist label))
         (name (plist-get plist :name))
         (addr (plist-get plist :addr)))
    (unless addr
      (user-error "Unknown mail account: %s" label))
    ;; From 헤더 설정 (이미 있으면 교체)
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^From:.*$" nil t)
          (replace-match (format "From: %s <%s>" name addr))
        (goto-char (point-min))
        (insert (format "From: %s <%s>\n" name addr))))
    ;; SMTP 인증 자격증명은 Keychain(auth-source)에서 조회
    (setq smtpmail-smtp-user addr)
    (message "Mail account set: %s (%s)" label addr)))

(defun my/mail-select-account ()
  "메일 계정 선택 인터페이스. 메시지 작성 시 From 을 설정."
  (interactive)
  (let ((label (completing-read "Mail account: " (my/mail-account-labels))))
    (my/mail-set-account label)))

;; smtpmail 인증 자격증명은 auth-source (macOS Keychain) 사용
(setq smtpmail-smtp-server "smtp.gmail.com"
      smtpmail-smtp-service 587
      smtpmail-stream-type 'starttls
      message-send-mail-function 'smtpmail-send-it)

;; ── 동기화 / 다이제스트 명령 ──────────────────────────────────
(defun my/mail-sync ()
  "모든 Gmail 계정을 mbsync 로 동기화하고 notmuch 인덱스를 갱신 (비동기)."
  (interactive)
  (message "mbsync -a && notmuch new (async) ...")
  (async-shell-command "mbsync -a && notmuch new" "*mail-sync*"))

(defun my/email-digest-open-report ()
  "당일 이메일 다이제스트 보고서를 org 로 연다."
  (interactive)
  (let ((file (expand-file-name
               (format "roam/newroom/email-digest-%s.org" (format-time-string "%Y-%m-%d"))
               wiki-dir)))
    (unless (string-prefix-p (expand-file-name wiki-dir) (expand-file-name file))
      (user-error "Report must be inside wiki directory"))
    (if (file-exists-p file)
        (find-file file)
      (user-error "Report not found: %s (run digest first)" file))))

(defun my/email-digest-run (&optional dry-run)
  "wiki email_digest.py 스크립트 실행 (allowlist 발신자만 요약)."
  (interactive "P")
  (let* ((script (expand-file-name "scripts/bin/email_digest.py" wiki-dir))
         (senders (mapconcat (lambda (s) (format "--sender %s" s))
                             mail-digest-senders " "))
         (dry (if dry-run "--dry-run" "")))
    (unless (file-exists-p (expand-file-name script))
      (user-error "Digest script not found: %s" script))
    (shell-command (format "python3 %s %s %s" script senders dry))))

;; ── 키바인딩 ──────────────────────────────────────────────────
(when (boundp 'evil-normal-state-map)
  (define-key evil-normal-state-map (kbd ",m") #'notmuch)
  (define-key evil-normal-state-map (kbd ",M") #'my/mail-select-account)
  (define-key evil-normal-state-map (kbd ",d") #'my/email-digest-run)
  (define-key evil-normal-state-map (kbd ",D") #'my/email-digest-open-report))

(provide 'mail-setting)
;;; mail-setting.el ends here
