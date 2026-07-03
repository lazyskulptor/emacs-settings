;;; -*- lexical-binding: t -*-

;;; ─────────────────────────────────────────
;;; 설정
;;; ─────────────────────────────────────────

(defgroup librechat nil
  "LibreChat client for Emacs"
  :group 'tools)

(defcustom librechat-url nil
  ;; ⚠️ 서버 미세팅: properties.local.el에서 설정
  "LibreChat 서버 URL"
  :type '(choice (const nil) string))

(defcustom librechat-email ""
  "LibreChat 로그인 이메일 — properties.local.el에서 설정"
  :type 'string)

(defcustom librechat-password ""
  "LibreChat 비밀번호 — properties.local.el에서 설정"
  :type 'string)

(defvar librechat--token nil)
(defvar librechat--current-convo-id nil)

;;; ─────────────────────────────────────────
;;; 서버 상태 확인
;;; ─────────────────────────────────────────

(defun librechat--check-server ()
  (unless librechat-url
    (user-error "⚠️ 서버 미세팅: librechat-url을 설정하세요")))

(defun librechat-status ()
  "LibreChat 연결 상태 확인"
  (interactive)
  (if librechat-url
      (message "LibreChat URL: %s | 토큰: %s"
               librechat-url
               (if librechat--token "설정됨" "없음"))
    (message "⚠️ 서버 미세팅: librechat-url이 설정되지 않았습니다")))

;;; ─────────────────────────────────────────
;;; 인증
;;; ─────────────────────────────────────────

(defun librechat--login ()
  (librechat--check-server)
  (let* ((url (concat librechat-url "/api/auth/login"))
         (url-request-method "POST")
         (url-request-extra-headers '(("Content-Type" . "application/json")))
         (url-request-data
          (encode-coding-string
           (json-encode `((email    . ,librechat-email)
                          (password . ,librechat-password)))
           'utf-8)))
    (condition-case err
        (with-current-buffer (url-retrieve-synchronously url t)
          (goto-char (point-min))
          (re-search-forward "^$")
          (let* ((json  (json-read))
                 (token (alist-get 'token json)))
            (if token
                (progn (setq librechat--token token)
                       (message "LibreChat 로그인 완료"))
              (message "LibreChat 로그인 실패"))))
      (error (message "LibreChat 연결 오류: %s" err)))))

(defun librechat--ensure-auth ()
  (librechat--check-server)
  (unless librechat--token (librechat--login)))

;;; ─────────────────────────────────────────
;;; 대화 관리 (서버 세팅 후 사용)
;;; ─────────────────────────────────────────

(defun librechat-list-convos ()
  ;; ⚠️ 서버 미세팅: librechat-url 설정 후 구현 예정
  "대화 목록 표시"
  (interactive)
  (librechat--ensure-auth)
  (message "⚠️ 서버 미세팅: 서버 세팅 후 사용 가능합니다"))

(defun librechat-new-convo (title)
  ;; ⚠️ 서버 미세팅: librechat-url 설정 후 구현 예정
  "새 대화 시작"
  (interactive "s대화 제목: ")
  (librechat--check-server)
  (message "⚠️ 서버 미세팅: 서버 세팅 후 사용 가능합니다"))

;;; ─────────────────────────────────────────
;;; 상태 버퍼
;;; ─────────────────────────────────────────

(defun librechat-status-buffer ()
  "LibreChat 설정 상태 버퍼 표시"
  (interactive)
  (with-current-buffer (get-buffer-create "*librechat-status*")
    (erase-buffer)
    (insert (propertize "=== LibreChat 상태 ===\n\n" 'face 'bold))
    (if librechat-url
        (insert (format "URL: %s\n" librechat-url))
      (insert (propertize "⚠️ 서버 미세팅\n서버 세팅 후 properties.local.el에 추가:\n"
                          'face 'warning)))
    (insert "(setq librechat-url      \"http://서버IP:3080\")\n")
    (insert "(setq librechat-email    \"이메일\")\n")
    (insert "(setq librechat-password \"비밀번호\")\n")
    (display-buffer (current-buffer))))

;;; ─────────────────────────────────────────
;;; 키바인딩
;;; ─────────────────────────────────────────

;; C-c l s   상태 확인
(global-set-key (kbd "C-c l s") #'librechat-status-buffer)
;; ⚠️ 서버 미세팅: 아래 키바인딩은 서버 세팅 후 주석 해제
;; (global-set-key (kbd "C-c l l") #'librechat-list-convos)
;; (global-set-key (kbd "C-c l n") #'librechat-new-convo)

(provide 'librechat-setting)
;;; librechat-setting.el ends here
