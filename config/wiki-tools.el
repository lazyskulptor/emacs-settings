;;; wiki-tools.el --- Wiki management tools  -*- lexical-binding: t; -*-
(require 'cl-lib)

;; ox-md is loaded lazily — only needed for archive export
(with-eval-after-load 'org
  (require 'ox-md))

;; ──────────────────────────────────────────────────────────────
;; 0. Internal Helpers
;; ──────────────────────────────────────────────────────────────
(defun wiki-extract-title (file)
  "Extract title from FILE (org or md)."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (cond
     ((re-search-forward "^#\\+title:\\s-*\\(.*\\)" nil t) (match-string 1))
     ((re-search-forward "^title:\\s-*\"?\\(.*?\\)\"?$" nil t) (match-string 1))
     ((re-search-forward "^# \\(.*\\)" nil t) (match-string 1))
     (t (file-name-sans-extension (file-name-nondirectory file))))))

(defun wiki--org-subdirs (dir)
  "Return subdirectory names under DIR that contain .org files."
  (let (result)
    (dolist (d (directory-files dir t))
      (when (and (file-directory-p d)
                 (not (string-match "/\\.\\($\\|git\\)" d))
                 (directory-files d t "\\.org$"))
        (push (file-relative-name d dir) result)))
    (nreverse result)))

;; ──────────────────────────────────────────────────────────────
;; 1. Validation
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
;; 2. Index Update
;; ──────────────────────────────────────────────────────────────
(defun wiki-update-indices ()
  "wiki/ 및 하위 디렉토리의 index 파일들 재생성."
  (interactive)
  (dolist (subdir (wiki--org-subdirs wiki-dir))
    (wiki-generate-org-index (expand-file-name subdir wiki-dir)))
  (wiki-generate-org-index wiki-dir)
  (wiki-generate-md-index wiki-archive-dir))

(defun wiki-generate-org-index (dir)
  "DIR 내 .org 파일을 스캔해 index.org 생성."
  (let* ((files (directory-files dir t "\\.org$"))
         (date (format-time-string "%Y-%m-%d"))
         (content (format "#+title: Wiki Index\n#+date: %s\n\n* Files\n" date)))
    (dolist (f (sort files #'string<))
      (when (and (file-regular-p f) (not (string-match "index\\." (file-name-nondirectory f))))
        (let ((rel (file-relative-name f dir)))
          (setq content (concat content
                                (format "- [[file:%s][%s]]\n" rel (wiki-extract-title f)))))))
    ;; Directory links (only for root)
    (when (string-equal (expand-file-name dir) (expand-file-name wiki-dir))
      (let ((subdirs (wiki--org-subdirs dir)))
        (when subdirs
          (setq content (concat content "\n* Directories\n"))
          (dolist (d subdirs)
            (setq content (concat content
                                  (format "- [[file:%s/index.org][%s/]]\n" d d)))))))
    (with-temp-file (expand-file-name "index.org" dir)
      (insert content))
    (message "📑 Updated org index: %s" (expand-file-name "index.org" dir))))

(defun wiki-generate-md-index (dir)
  "DIR 내 .md 파일을 스캔해 index.md 생성."
  (let* ((files (directory-files dir t "\\.md$"))
         (date (format-time-string "%Y-%m-%d"))
         (content (format "---\ntitle: \"Wiki Archive Index\"\ndate: \"%s\"\n---\n\n# Wiki Archive Index\n\n" date)))
    (dolist (f (sort files #'string<))
      (when (and (file-regular-p f) (not (string-match "index\\." (file-name-nondirectory f))))
        (let ((rel (file-relative-name f dir)))
          (setq content (concat content (format "- [%s](%s)\n" (wiki-extract-title f) rel))))))
    (with-temp-file (expand-file-name "index.md" dir)
      (insert content))
    (message "📑 Updated md index: %s" (expand-file-name "index.md" dir))))

;; ──────────────────────────────────────────────────────────────
;; 3. Archive (AI → MD)
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
         (md-path (expand-file-name (concat base ".md") wiki-archive-dir))
         (tmp-file (make-temp-file "wiki-archive-" nil ".org")))

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
        (delete-file tmp-file)
        (if (and resp (> (length resp) 0))
            (progn
              (make-directory wiki-archive-dir t)
              (with-temp-file md-path (insert resp))
              (wiki-update-indices)
              (message "✅ Archived to: %s" md-path))
          (user-error "OpenCode Agent returned empty response"))))))

;; ──────────────────────────────────────────────────────────────
;; 4. AI Formatting
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
          (progn (delete-region start end) (insert resp)
                 (message "✅ AI formatting applied via OpenCode"))
        (user-error "OpenCode Agent 가 빈 응답을 반환했습니다.")))))

(defun wiki-ai-format-buffer ()
  "현재 버퍼 전체를 로컬 OpenCode Agent 로 포맷팅."
  (interactive)
  (wiki-ai-format-region (point-min) (point-max)))

;; ──────────────────────────────────────────────────────────────
;; 5. Delete
;; ──────────────────────────────────────────────────────────────
(defun wiki-delete-file (&optional file)
  "Wiki 디렉토리 내 FILE을 삭제. FILE이 nil이면 현재 버퍼 파일 삭제."
  (interactive)
  (let* ((target (or file (when buffer-file-name buffer-file-name)
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
;; 6. Org Structural Helpers
;; ──────────────────────────────────────────────────────────────
(defun wiki-org-find-heading (file heading-title)
  "FILE에서 HEADING-TITLE heading의 위치를 (start . end)로 반환."
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (when (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)
      (let ((start (line-beginning-position)))
        (org-end-of-subtree t t)
        (cons start (point))))))

(defun wiki-org-heading-exists-p (file heading-title)
  "FILE에 HEADING-TITLE heading이 있는지 확인."
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)))

(defun wiki-org-insert-heading-after (file after-heading new-heading &optional body)
  "FILE의 AFTER-HEADING 뒤에 NEW-HEADING을 삽입."
  (unless (wiki-org-heading-exists-p file after-heading)
    (user-error "Heading '%s' not found in %s" after-heading file))
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (format "^\\*+ %s$" (regexp-quote after-heading)) nil t)
    (org-end-of-subtree t t)
    (insert "\n" new-heading)
    (when body (insert "\n" body))
    (write-region (point-min) (point-max) file nil 'silent)
    (message "✅ Inserted heading '%s' after '%s'" new-heading after-heading)))

(defun wiki-org-append-to-heading (file heading-title &optional text)
  "FILE의 HEADING-TITLE body 끝에 TEXT를 추가."
  (if (wiki-org-heading-exists-p file heading-title)
      (with-temp-buffer
        (insert-file-contents file)
        (org-mode)
        (goto-char (point-min))
        (re-search-forward (format "^\\*+ %s$" (regexp-quote heading-title)) nil t)
        (org-end-of-subtree t t)
        (backward-char)
        (unless (looking-back "\n\n" (max (- (point) 2) (point-min)))
          (insert "\n"))
        (when text (insert text "\n"))
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
    (let ((parent-end (progn (org-end-of-subtree t t) (point)))
          (child-prefix (make-string (1+ (org-current-level)) ?*)))
      (goto-char parent-end)
      (insert "\n" (format "%s %s" child-prefix child-heading))
      (when body (insert "\n" body))
      (write-region (point-min) (point-max) file nil 'silent)
      (message "✅ Inserted child heading '%s' under '%s'" child-heading parent-heading))))

;; ──────────────────────────────────────────────────────────────
;; 7. Journal Monthly Archive
;; ──────────────────────────────────────────────────────────────
(defun wiki--extract-done-logs (section-regex month)
  "Extract DONE log timestamps for MONTH from section matching SECTION-REGEX.
Returns (timestamps . positions) cons."
  (let (timestamps positions)
    (when (re-search-forward section-regex nil t)
      (let ((sec-start (line-beginning-position)))
        (org-end-of-subtree t t)
        (goto-char sec-start)
        (while (re-search-forward
                (format "^\\s-*- State \"DONE\".*\\[%s-\\([0-9]\\{2\\} [A-Za-z]\\{3\\} [0-9]\\{2\\}:[0-9]\\{2\\}\\)\\]"
                        (regexp-quote month))
                (save-excursion (org-end-of-subtree t t) (point)) t)
          (let ((start (line-beginning-position)))
            (forward-line 1)
            (push (match-string 1) timestamps)
            (push (cons start (point)) positions)))
        ;; Ensure deletion doesn't interfere with outer code by recording positions
        (dolist (p positions) (delete-region (car p) (cdr p)))))
    (cons (nreverse timestamps) (nreverse positions))))

(defun wiki-archive-journal-month (month)
  "Archive YYYY-MM tasks from journal.org to roam/monthly/."
  (interactive "sArchive month (YYYY-MM): ")
  (unless (string-match-p "^[0-9]\\{4\\}-[0-9]\\{2\\}$" month)
    (user-error "Month must be in YYYY-MM format (e.g. 2026-06)"))

  (let* ((journal-path (expand-file-name "journal.org" wiki-dir))
         (monthly-dir (expand-file-name "roam/monthly/" wiki-dir))
         (section-text nil) (daily-logs nil) (weekly-logs nil))

    ;; Guard: journal.org must not have unsaved changes
    (let ((buf (find-buffer-visiting journal-path)))
      (when (and buf (buffer-modified-p buf))
        (user-error "journal.org is open and modified in Emacs. Save it first.")))

    (with-temp-buffer
      (insert-file-contents journal-path)
      (org-mode)

      ;; 1. Extract & delete YYYY-MM Tasks section
      (goto-char (point-min))
      (unless (re-search-forward (format "^\\* %s " (regexp-quote month)) nil t)
        (user-error "Month '%s' section not found in journal.org" month))
      (let ((sec-start (line-beginning-position)))
        (org-end-of-subtree t t)
        (let ((sec-end (point)))
          ;; HOLD check
          (save-excursion
            (goto-char sec-start)
            (let (hold-items)
              (while (re-search-forward "^\\*\\{2,\\} HOLD " sec-end t)
                (push (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position)) hold-items))
              (when hold-items
                (user-error "HOLD items in %s:\n%s" month
                           (string-join (nreverse hold-items) "\n")))))
          (setq section-text (buffer-substring-no-properties sec-start sec-end))
          (delete-region sec-start sec-end)))

      ;; 2. Extract recurring task DONE logs
      (goto-char (point-min))
      (let ((result (wiki--extract-done-logs
                     "^\\*+ TODO Daily Recurring Tasks" month)))
        (setq daily-logs (car result)))
      (goto-char (point-min))
      (let ((result (wiki--extract-done-logs
                     "^\\*\\{2,\\} TODO 주간일지 작성" month)))
        (setq weekly-logs (car result)))

      (write-region (point-min) (point-max) journal-path nil 'silent))

    ;; 3. Write archive file
    (make-directory monthly-dir t)
    (let* ((timestamp (format-time-string "%Y%m%d%H%M%S"))
           (archive-name (format "%s-monthly_%s.org" timestamp month))
           (archive-path (expand-file-name archive-name monthly-dir)))
      (with-temp-file archive-path
        (insert section-text)
        (when (or daily-logs weekly-logs)
          (insert (format "\n* %s Recurring Task Logs\n" month))
          (when daily-logs
            (insert "** Daily Recurring Tasks\n")
            (dolist (ts daily-logs)
              (insert (format "*** DONE [%s-%s]\n    CLOSED: [%s-%s]\n" month ts month ts))))
          (when weekly-logs
            (insert "** Weekly Reccurring Tasks\n*** 주간일지 작성\n")
            (dolist (ts weekly-logs)
              (insert (format "**** DONE [%s-%s]\n     CLOSED: [%s-%s]\n" month ts month ts))))))
      (ignore-errors
        (when (fboundp 'org-roam-db-sync) (org-roam-db-sync)))
      (message "✅ Archived %s → %s" month archive-name))))

;; ──────────────────────────────────────────────────────────────
;; 8. Auto-update on Save
;; ──────────────────────────────────────────────────────────────
(defun wiki-after-save-update-indices ()
  "wiki/ 또는 .archive/ 디렉토리 내 파일 저장 시 인덱스 자동 갱신."
  (when (and buffer-file-name
             (or (string-prefix-p (expand-file-name wiki-dir) buffer-file-name)
                 (string-prefix-p (expand-file-name wiki-archive-dir) buffer-file-name))
             (string-match-p "\\.\\(org\\|md\\)$" buffer-file-name))
    (wiki-update-indices)))

(add-hook 'after-save-hook #'wiki-after-save-update-indices)

;; ──────────────────────────────────────────────────────────────
;; Keybindings & Hooks
;; ──────────────────────────────────────────────────────────────
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c w v") #'wiki-validate-buffer)
  (define-key org-mode-map (kbd "C-c w a") #'wiki-archive-current-file)
  (define-key org-mode-map (kbd "C-c w f") #'wiki-ai-format-region)
  (define-key org-mode-map (kbd "C-c w F") #'wiki-ai-format-buffer)
  (define-key org-mode-map (kbd "C-c w i") #'wiki-update-indices)
  (define-key org-mode-map (kbd "C-c w d") #'wiki-delete-file))

(with-eval-after-load 'magit
  (add-hook 'magit-pre-commit-hook #'wiki-pre-commit-validate))

(provide 'wiki-tools)
;;; wiki-tools.el ends here