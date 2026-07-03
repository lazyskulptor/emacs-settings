;;; wiki-tools.el --- Wiki management tools (Org → MD archive, validation, AI formatting) -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'json)

;; ox-md is loaded lazily — only needed for archive export
(with-eval-after-load 'org
  (require 'ox-md))

(defcustom wiki-dir "~/Workspace/wiki/"
  "활성 Wiki 파일 루트 디렉토리."
  :type 'directory)

(defcustom wiki-archive-dir "~/Workspace/wiki/.archive/"
  "아카이브된 MD 파일 디렉토리."
  :type 'directory)

(defcustom wiki-meta-dir "~/Workspace/wiki/meta/"
  "Wiki 메타 문서 디렉토리."
  :type 'directory)

;; ──────────────────────────────────────────────────────────────
;; 1. 검증 (Validation)
;; ──────────────────────────────────────────────────────────────
(defun wiki-validate-buffer ()
  "현재 Org 버퍼의 필수 메타데이터 (#+title, #+tags, #+date) 검증."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let ((errors '()))
    (save-excursion
      (goto-char (point-min))
      (unless (re-search-forward "^#\\+title:" nil t) (push "#+title" errors))
      (unless (re-search-forward "^#\\+tags:" nil t) (push "#+tags" errors))
      (unless (re-search-forward "^#\\+date:" nil t) (push "#+date" errors)))
    (when errors
      (user-error "Wiki validation failed: %s" (string-join errors ", ")))
    (message "✅ Validation passed")))

(defun wiki-pre-commit-validate ()
  "Git 커밋 전 스테이징된 .org 파일들 검증."
  (interactive)
  (let ((files (split-string (shell-command-to-string
                              "git diff --cached --name-only --diff-filter=ACM | grep '\\.org$'") "\n" t)))
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (org-mode)
        (wiki-validate-buffer)))
    (message "✅ All staged .org files validated")))

;; ──────────────────────────────────────────────────────────────
;; 2. 인덱스 자동 갱신 (Index Updater)
;; ──────────────────────────────────────────────────────────────
(defun wiki-update-indices ()
  "wiki/ 의 index.org, wiki/meta/ 의 index.org, wiki/.archive/ 의 index.md 재생성."
  (interactive)
  (wiki-generate-org-index wiki-dir)
  (wiki-generate-org-index wiki-meta-dir)
  (wiki-generate-md-index wiki-archive-dir))

(defun wiki-generate-org-index (dir)
  "DIR 내 .org/.md 파일을 스캔해 Org 형식 index.org 생성."
  (let* ((index-path (concat dir "index.org"))
         (files (directory-files dir t "\\.\(org\|md\)$"))
         (content (format "#+title: Wiki Index\n#+date: %s\n\n* Files\n"
                          (format-time-string "%Y-%m-%d"))))
    (dolist (f (sort files #'string<))
      (when (and (file-regular-p f) (not (string-match "index\\." (file-name-nondirectory f))))
        (let* ((rel (file-relative-name f dir))
               (title (with-temp-buffer
                        (insert-file-contents f)
                        (goto-char (point-min))
                        (cond
                         ((re-search-forward "^#\\+title:\\s-*\\(.*\\)" nil t)
                          (match-string 1))
                         ((re-search-forward "^title:\\s-*\"?\\(.*?\\)\"?$" nil t)
                          (match-string 1))
                         ((re-search-forward "^# \\(.*\\)" nil t)
                          (match-string 1))
                         (t (file-name-sans-extension rel))))))
          (setq content (concat content "- [[file:" rel "][" title "]]\n")))))
    (with-temp-file index-path
      (insert content))
    (message "📑 Updated org index: %s" index-path)))

(defun wiki-generate-md-index (dir)
  "DIR 내 .md 파일을 스캔해 Markdown 형식 index.md 생성."
  (let* ((index-path (concat dir "index.md"))
         (files (directory-files dir t "\\.md$"))
         (content (format "---\ntitle: \"Wiki Archive Index\"\ndate: \"%s\"\n---\n\n# Wiki Archive Index\n\n"
                          (format-time-string "%Y-%m-%d"))))
    (dolist (f (sort files #'string<))
      (when (and (file-regular-p f) (not (string-match "index\\." (file-name-nondirectory f))))
        (let* ((rel (file-relative-name f dir))
               (title (with-temp-buffer
                        (insert-file-contents f)
                        (goto-char (point-min))
                        (cond
                         ((re-search-forward "^title:\\s-*\"?\\(.*?\\)\"?$" nil t)
                          (match-string 1))
                         ((re-search-forward "^# \\(.*\\)" nil t)
                          (match-string 1))
                         (t (file-name-sans-extension rel))))))
          (setq content (concat content "- [" title "](" rel ")\n")))))
    (with-temp-file index-path
      (insert content))
    (message "📑 Updated md index: %s" index-path)))

;; ──────────────────────────────────────────────────────────────
;; 3. 아카이빙 (AI 압축 요약 → MD 저장 + 인덱스 갱신)
;; ──────────────────────────────────────────────────────────────
(defun wiki-archive-current-file ()
  "현재 .org 파일을 AI를 통해 압축 요약하여 MD로 변환해 wiki/.archive/ 에 저장."
  (interactive)
  (unless buffer-file-name
    (user-error "Buffer not visiting a file"))
  (unless (string-match "\\.org$" buffer-file-name)
    (user-error "Only .org files can be archived"))

  (wiki-validate-buffer)

  (let* ((org-path buffer-file-name)
         (base (file-name-sans-extension (file-name-nondirectory org-path)))
         (md-path (concat wiki-archive-dir base ".md"))
         (tmp-file (make-temp-file "wiki-archive-" nil ".org")))

    ;; Org 내용을 임시 파일에 저장 (명령행 길이 제한 회피)
    (with-temp-file tmp-file
      (insert-file-contents org-path))

    (let ((prompt (format "Read the file at %s and summarize it into a clean, AI-friendly Markdown archive.
Rules:
1. Extract metadata (#+title, #+tags, #+date) into YAML frontmatter.
2. Use Q&A format for Problems & Solutions.
3. List Key Decisions, Lessons Learned, and Achievements concisely.
4. Include References using relative links (e.g. [](../wiki/projects/%s)).
5. Output ONLY the Markdown content, no conversational text.

File path: %s" tmp-file base tmp-file)))
      (message "🤖 Archiving via OpenCode Agent (this may take a moment)...")
      (let ((resp (shell-command-to-string (format "opencode run %s" (shell-quote-argument prompt)))))
        (delete-file tmp-file) ;; 임시 파일 정리
        (if (and resp (> (length resp) 0))
            (progn
              (make-directory wiki-archive-dir t)
              (with-temp-file md-path
                (insert resp))
              (wiki-update-indices)
              (message "✅ Archived to: %s" md-path))
           (user-error "OpenCode Agent returned empty response"))))))

;; ──────────────────────────────────────────────────────────────
;; 4. AI 포맷팅 (로컬 OpenCode Agent 사용)
;; ──────────────────────────────────────────────────────────────
(defun wiki-ai-format-region (start end &optional instructions)
  "선택 영역을 로컬 OpenCode Agent (opencode run) 로 포맷팅."
  (interactive "r\nsInstructions (default: format as clean Org): ")
  (unless (executable-find "opencode")
    (user-error "'opencode' 명령어를 찾을 수 없습니다. PATH 를 확인하세요."))

  (let* ((text (buffer-substring-no-properties start end))
         (prompt (format "%s\n\n---\n%s\n---"
                         (or instructions "Format the following text as clean, well-structured Org-mode content. Preserve meaning but improve readability.")
                         text))
         (cmd (format "opencode run %s" (shell-quote-argument prompt))))

    (message "🤖 Sending to local OpenCode Agent...")
    (let ((resp (shell-command-to-string cmd)))
      (if (and resp (> (length resp) 0))
          (progn
            (delete-region start end)
            (insert resp)
            (message "✅ AI formatting applied via OpenCode"))
        (user-error "OpenCode Agent 가 빈 응답을 반환했습니다.")))))

(defun wiki-ai-format-buffer ()
  "현재 버퍼 전체를 로컬 OpenCode Agent 로 포맷팅."
  (interactive)
  (wiki-ai-format-region (point-min) (point-max)))

;; ──────────────────────────────────────────────────────────────
;; 5. 파일 삭제 (Delete)
;; ──────────────────────────────────────────────────────────────
(defun wiki-delete-file (&optional file)
  "Wiki 디렉토리 내 FILE을 삭제. FILE이 nil이면 현재 버퍼 파일 삭제."
  (interactive)
  (let* ((target (or file
                     (when buffer-file-name buffer-file-name)
                     (read-file-name "Delete file: " wiki-dir)))
         (target-abs (expand-file-name target))
         (wiki-abs (expand-file-name wiki-dir))
         (rel (file-relative-name target-abs wiki-abs)))
    (unless (string-prefix-p wiki-abs target-abs)
      (user-error "파일은 wiki 디렉토리(%s) 내에 있어야 합니다" wiki-dir))
    (unless (file-exists-p target-abs)
      (user-error "파일이 존재하지 않습니다: %s" target))
    (when (yes-or-no-p (format "%s 을(를) 삭제하시겠습니까? " rel))
      (when (get-file-buffer target-abs)
        (kill-buffer (get-file-buffer target-abs)))
      (delete-file target-abs)
      (wiki-update-indices)
      (message "✅ Deleted: %s" rel))))

;; ──────────────────────────────────────────────────────────────
;; 6. Org 구조적 수정 헬퍼 (Structural Org Editing)
;; ──────────────────────────────────────────────────────────────
;; eval-elisp fallback 없이 전용 툴 패턴으로 org 파일 수정을 지원

(defun wiki-org-find-heading (file heading-title)
  "FILE에서 HEADING-TITLE과 정확히 일치하는 heading의 위치를 반환.
결과: (point-min . point-max) 컨스 셀, 없으면 nil."
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (when (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)
      (let ((start (line-beginning-position)))
        (org-end-of-subtree t t)
        (cons start (point))))))

(defun wiki-org-heading-exists-p (file heading-title)
  "FILE에 HEADING-TITLE이라는 heading이 있는지 확인."
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)))

(defun wiki-org-insert-heading-after (file after-heading new-heading &optional body)
  "FILE의 AFTER-HEADING 바로 뒤에 NEW-HEADING을 삽입.
BODY가 제공되면 heading 아래에 추가."
  (unless (wiki-org-heading-exists-p file after-heading)
    (user-error "Heading '%s' not found in %s" after-heading file))
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote after-heading)) nil t)
    (org-end-of-subtree t t)
    (insert "\n")
    (insert new-heading)
    (when body
      (insert "\n" body))
    (write-region (point-min) (point-max) file nil 'silent)
    (message "✅ Inserted heading '%s' after '%s'" new-heading after-heading)))

(defun wiki-org-append-to-heading (file heading-title &optional text)
  "FILE의 HEADING-TITLE body 끝에 TEXT를 추가.
heading이 없으면 새로 생성."
  (if (wiki-org-heading-exists-p file heading-title)
      (with-temp-buffer
        (insert-file-contents file)
        (org-mode)
        (goto-char (point-min))
        (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)
        (org-end-of-subtree t t)
        (backward-char)
        ;; 마지막 newline 앞에 삽입
        (unless (looking-back "\n\n" (max (- (point) 2) (point-min)))
          (insert "\n"))
        (when text
          (insert text "\n"))
        (write-region (point-min) (point-max) file nil 'silent)
        (message "✅ Appended to heading '%s'" heading-title))
    (user-error "Heading '%s' not found — use wiki-org-insert-heading-after instead" heading-title)))

(defun wiki-org-replace-heading-body (file heading-title new-body)
  "FILE의 HEADING-TITLE body 전체를 NEW-BODY로 교체."
  (unless (wiki-org-heading-exists-p file heading-title)
    (user-error "Heading '%s' not found in %s" heading-title file))
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)
    (let ((heading-start (line-beginning-position)))
      (org-end-of-subtree t t)
      (delete-region heading-start (point))
      (goto-char heading-start)
      (insert (format "* %s\n%s\n" heading-title new-body))
      (write-region (point-min) (point-max) file nil 'silent)
      (message "✅ Replaced body of heading '%s'" heading-title))))

(defun wiki-org-insert-child-heading (file parent-heading child-heading &optional body)
  "FILE의 PARENT-HEADING 아래에 CHILD-HEADING을 자식으로 삽입."
  (unless (wiki-org-heading-exists-p file parent-heading)
    (user-error "Parent heading '%s' not found in %s" parent-heading file))
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote parent-heading)) nil t)
    (let ((level (org-current-level))
          (parent-end (progn (org-end-of-subtree t t) (point))))
      ;; 자식은 부모 레벨 + 1의 heading이어야 함
      (let ((child-level (1+ level))
            (prefix (make-string child-level ?*)))
        (goto-char parent-end)
        (insert "\n")
        (insert (format "%s %s" prefix child-heading))
        (when body
          (insert "\n" body))
        (write-region (point-min) (point-max) file nil 'silent)
        (message "✅ Inserted child heading '%s' under '%s'" child-heading parent-heading)))))

;; ──────────────────────────────────────────────────────────────
;; 편의 키바인딩 (org 로드 후 적용)
;; ──────────────────────────────────────────────────────────────
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c w v") #'wiki-validate-buffer)
  (define-key org-mode-map (kbd "C-c w a") #'wiki-archive-current-file)
  (define-key org-mode-map (kbd "C-c w f") #'wiki-ai-format-region)
  (define-key org-mode-map (kbd "C-c w F") #'wiki-ai-format-buffer)
  (define-key org-mode-map (kbd "C-c w i") #'wiki-update-indices)
  (define-key org-mode-map (kbd "C-c w d") #'wiki-delete-file))

;; Magit 커밋 전 자동 검증 훅
(with-eval-after-load 'magit
  (add-hook 'magit-pre-commit-hook #'wiki-pre-commit-validate))

(provide 'wiki-tools)
;;; wiki-tools.el ends here
