;;; wiki-tools.el --- Wiki management tools  -*- lexical-binding: t; -*-
(require 'cl-lib)

;; Disable auto-ID assignment by Emacs MCP tools (opencode).
;; IDs are assigned manually via org-id-get-create when needed.
(when (boundp 'mcp-server-emacs-tools-org-auto-id)
  (setq mcp-server-emacs-tools-org-auto-id nil))

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

;; (wiki--org-subdirs and wiki--indexed-subdirs removed — replaced by wiki-build-graph)

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

;; (Index Update section removed — replaced by Graph Index, see section 8)

;; ──────────────────────────────────────────────────────────────
;; 2. Archive (AI → MD)
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
              (wiki-build-graph)
              (message "✅ Archived to: %s" md-path))
          (user-error "OpenCode Agent returned empty response"))))))

;; ──────────────────────────────────────────────────────────────
;; 3. AI Formatting
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
;; 4. Delete
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
      (wiki-build-graph)
      (message "✅ Deleted: %s" rel))))

;; ──────────────────────────────────────────────────────────────
;; 5. Org Structural Helpers (used by MCP tools in mcp-server-setting.el)
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
;; 6. Journal Monthly Archive
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
      (wiki-build-graph)
      (message "✅ Archived %s → %s" month archive-name))))

;; ──────────────────────────────────────────────────────────────
;; 7. Wiki Commit (opencode subagent)
;; ──────────────────────────────────────────────────────────────
(defun wiki-commit ()
  "wiki-commit 서브에이전트 실행. 어디서든 wiki 커밋 가능."
  (interactive)
  (let* ((wiki-root (expand-file-name wiki-dir))
         (cmd (format "cd %s && exec opencode run .opencode/agent/wiki-commit.md"
                      (shell-quote-argument wiki-root))))
    (async-shell-command cmd "*wiki-commit*")
    (message "🚀 wiki-commit subagent started (see *wiki-commit* buffer)"))

;; ──────────────────────────────────────────────────────────────
;; 8. Graph Index
;; ──────────────────────────────────────────────────────────────

(require 'json)

(defsubst aget (key alist)
  "Get KEY from ALIST using `equal' comparison.
Wrapper around `alist-get' to avoid verbose `nil nil 'equal' anti-pattern."
  (alist-get key alist nil nil 'equal))

(defun wiki--json-normalize (obj)
  "Recursively convert symbol keys to strings and vectors to lists.
Needed because `json-read-file' returns symbol keys and vector arrays."
  (cond
   ((and (listp obj) (consp (car-safe obj)))
    (mapcar (lambda (p)
              (cons (if (symbolp (car p)) (symbol-name (car p)) (car p))
                    (wiki--json-normalize (cdr p))))
            obj))
   ((vectorp obj)
    (mapcar #'wiki--json-normalize (append obj nil)))
   (t obj)))

(defun wiki--read-graph ()
  "Read graph.json, normalizing symbol keys to strings and vectors to lists."
  (let ((d (ignore-errors (json-read-file (expand-file-name wiki-graph-file)))))
    (wiki--json-normalize d)))

(defun wiki--read-hashes ()
  "Read hashes from plain text alist file (written by `prin1')."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (expand-file-name wiki-graph-hash-file))
      (read (current-buffer)))))

(defun wiki--write-hashes (alist)
  "Write hashes as plain text alist using `prin1'.
Returns ALIST for convenience."
  (with-temp-file (expand-file-name wiki-graph-hash-file)
    (prin1 alist (current-buffer)))
  alist)

(defvar wiki-graph-dir (concat wiki-dir ".graph/")
  "Wiki graph directory.")

(defvar wiki-graph-file (concat wiki-dir ".graph/graph.json")
  "Wiki graph JSON file.")

(defvar wiki-graph-hash-file (concat wiki-dir ".graph/hashes.json")
  "File hash cache for incremental graph rebuild.")

(defvar wiki-graph-max-headings 30
  "Maximum number of headings to include per file in graph.")

(defvar wiki-graph-stale-seconds 3600
  "Graph older than this (seconds) is considered stale on startup.")

(defun wiki--file-hash (file)
  "Return SHA-1 hash of FILE content as hex string, or nil on error."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents-literally file)
      (secure-hash 'sha1 (current-buffer)))))

(defun wiki--parse-org-metadata (file)
  "Parse org FILE metadata. Return plist (:title :tags :date :headings :links)
or nil if file is not an org file or unreadable.
Extracts: #+TITLE, #+tags:/#+FILETAGS:, #+DATE:,
1-level headings (up to `wiki-graph-max-headings'), [[file:REL_PATH][...]] links.
Does NOT return body content."
  (when (and (string-suffix-p ".org" file) (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (title tags date headings links)
        ;; Extract title
        (when (re-search-forward "^#\\+TITLE:\\s-*\\(.+\\)" nil t)
          (setq title (string-trim (match-string 1))))
        (goto-char (point-min))
        ;; Extract tags: #+tags or #+FILETAGS (colon/comma/newline separated, then space-split)
        (when (re-search-forward "^#\\+\\(?:tags\\|FILETAGS\\):\\s-*\\(.+\\)" nil t)
          (let ((raw (match-string 1)))
            ;; Format 1: :tag1:tag2:tag3: — strip leading/trailing colons
            (when (string-match-p "^:" raw)
              (setq raw (replace-regexp-in-string "^[:\\s-]+\\|[:\\s-]+$" "" raw)))
            ;; Split by colon/comma/newline, then by space, flatten, trim
            (setq tags
                  (seq-filter
                   (lambda (s) (not (string-empty-p s)))
                   (mapcar #'string-trim
                           (cl-loop for part in (split-string raw "[:,\n]")
                                    append (split-string part " " t)))))))
        (goto-char (point-min))
        ;; Extract date
        (when (re-search-forward "^#\\+DATE:\\s-*\\(.+\\)" nil t)
          (setq date (string-trim (match-string 1))))
        (goto-char (point-min))
        ;; Extract 1-level headings (starts with single *)
        (let ((count 0))
          (while (and (< count wiki-graph-max-headings)
                      (re-search-forward "^\\* \\(.+\\)$" nil t))
            (push (string-trim (match-string 1)) headings)
            (cl-incf count)))
        (setq headings (nreverse headings))
        (goto-char (point-min))
        ;; Extract [[file:REL_PATH][...]] links (wiki-internal only)
        (while (re-search-forward "\\[\\[file:\\([^]]+\\)\\]\\[" nil t)
          (let ((target (match-string 1)))
            ;; Only include wiki-internal relative paths (no absolute, no http)
            (unless (or (string-match-p "^\\(/\\|https?:\\)" target))
              ;; Strip org-search trailing ::*Heading suffix
              (setq target (replace-regexp-in-string "::.*\\'" "" target))
              (push target links))))
        ;; Return plist
        (list :title title :tags tags :date date
              :headings headings
               :links (delete-dups (nreverse links)))))))


(defun wiki--parse-md-frontmatter (file)
  "Parse YAML frontmatter from MD FILE. Return plist (:title :tags :date)
or nil if no frontmatter found."
  (when (and (string-suffix-p ".md" file) (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (when (re-search-forward "^---\\s-*$" nil t)
        (let (title tags date)
          (when (re-search-forward "^title:\\s-*\"?\\(.+?\\)\"?\\s-*$" nil t)
            (setq title (string-trim (match-string 1))))
          (goto-char (point-min))
          (when (re-search-forward "^tags:\\s-*\\[\\(.*\\)\\]\\s-*$" nil t)
            (setq tags (mapcar #'string-trim
                               (split-string (match-string 1) ","))))
          (goto-char (point-min))
          (when (re-search-forward "^date:\\s-*\"?\\(.+?\\)\"?\\s-*$" nil t)
            (setq date (string-trim (match-string 1))))
          (list :title title :tags tags :date date))))))

(defun wiki--roam-nodes ()
  "Query org-roam DB for all nodes. Return list of (id . plist) or nil.
plist keys: :title :tags :backlinks (list of IDs)."
  (when (fboundp 'org-roam-db-query)
    (condition-case nil
      (progn
        ;; Don't call org-roam-db-sync here — it modifies files (assigning IDs)
        ;; and breaks incremental hash comparison. Let org-roam-db-autosync-mode
        ;; handle syncing on its own schedule.
        (let* ((rows (org-roam-db-query
                       [:select [id title properties] :from nodes]))
               (link-rows (org-roam-db-query
                            [:select [source dest] :from links
                             :where (= type "id")]))
               (backlink-map (make-hash-table :test 'equal))
               result)
          (dolist (link link-rows)
            (let ((dest (nth 1 link))
                  (src  (nth 0 link)))
              (push src (gethash dest backlink-map))))
          (dolist (row rows)
            (let* ((id    (nth 0 row))
                   (title (nth 1 row))
                   (props (nth 2 row))
                   ;; ALLTAGS in properties is like ":tag1:tag2:tag3:"
                   (tags  (when props
                            (let ((at (cdr (assoc "ALLTAGS" props))))
                              (when at
                                (seq-filter (lambda (s) (not (string-empty-p s)))
                                            (split-string at ":" t))))))
                   (backlinks (gethash id backlink-map)))
              (push (cons id (list :title title
                                   :tags tags
                                   :backlinks backlinks))
                    result)))
          (nreverse result)))
    (error nil))))

(defun wiki-build-graph ()
  "Build or incrementally update the wiki graph (graph.json + hashes.json).

Uses file hash comparison for incremental updates: only re-scans files
whose SHA-1 hash changed since last build.
Returns the path to graph.json, or nil on failure."
  (interactive)
  (let* ((graph-dir (expand-file-name wiki-graph-dir))
         (graph-file (expand-file-name wiki-graph-file))
         (hash-file (expand-file-name wiki-graph-hash-file))
         (wiki-root (expand-file-name wiki-dir))
         ;; Load old hashes
          (old-hashes (ignore-errors
                        (wiki--read-hashes)))
          ;; Load old graph for incremental merge
          (old-graph (ignore-errors
                       (wiki--read-graph)))
          (old-files (aget "files" old-graph))

         (new-hashes nil)
         (files-data (make-hash-table :test 'equal))
         ;; Collect all org files under wiki
         (all-org-files (directory-files-recursively wiki-root "\\.org$" t))
         ;; Exclude .git, .graph, .archive, agent-shell/transcripts
         (org-files (seq-filter
                     (lambda (f)
                       (let ((rel (file-relative-name f wiki-root)))
                         (not (or (string-match-p "^\\.\\(git\\|graph\\|archive\\)/" rel)
                                  (string-match-p "^agent-shell/transcripts/" rel)))))
                     all-org-files))
         ;; Collect .archive/*.md files
         (md-files (directory-files-recursively
                    (expand-file-name ".archive" wiki-root) "\\.md$" t))
         (changed-count 0)
         (skipped-count 0))

    ;; ── Process org files (incremental) ──
    (dolist (f org-files)
      (let* ((rel (file-relative-name f wiki-root))
             (hash (wiki--file-hash f))
             (old-hash (cdr (assoc rel old-hashes))))
        (push (cons rel hash) new-hashes)
        (if (and hash old-hash (string= hash old-hash) old-files)
            ;; Hash unchanged → reuse old entry
            (let ((old-entry (aget rel old-files)))
              (when old-entry
                (puthash rel
                         (list :title (aget "t" old-entry)
                               :tags (aget "g" old-entry)
                               :date (aget "d" old-entry)
                               :headings (aget "h" old-entry)
                               :links (aget "l" old-entry))
                         files-data))
              (cl-incf skipped-count))
          ;; Hash changed or new file → re-parse
          (cl-incf changed-count)
          (let ((meta (wiki--parse-org-metadata f)))
            (when meta
              (puthash rel meta files-data))))))

    ;; ── Process .archive MD files (incremental) ──
    (dolist (f md-files)
        (let* ((rel (file-relative-name f wiki-root))
               (hash (wiki--file-hash f))
               (old-hash (cdr (assoc rel old-hashes))))
          (push (cons rel hash) new-hashes)
          (if (and hash old-hash (string= hash old-hash) old-files)
              (let ((old-entry (aget rel old-files)))
                (when old-entry
                  (puthash rel
                           (list :title (aget "t" old-entry)
                                 :tags (aget "g" old-entry)
                                 :date (aget "d" old-entry))
                           files-data))
                (cl-incf skipped-count))
            (cl-incf changed-count)
            (let ((meta (wiki--parse-md-frontmatter f)))
              (when meta
                 (puthash rel meta files-data))))))


    ;; ── Build JSON structure ──
    (make-directory graph-dir t)
    (let ((files-json (make-hash-table :test 'equal))
          (archive-json (make-hash-table :test 'equal))
          (tags-index (make-hash-table :test 'equal))
          (total 0))

      ;; Collect files and archive entries
      (maphash
       (lambda (rel meta)
         (let* ((title    (plist-get meta :title))
                (tags     (plist-get meta :tags))
                (date     (plist-get meta :date))
                (headings (plist-get meta :headings))
                (links    (plist-get meta :links))
                (is-archive (string-prefix-p ".archive/" rel)))
           (let ((entry (make-hash-table :test 'equal)))
             (when title    (puthash "t" title entry))
             (when tags     (puthash "g" (vconcat tags) entry))
             (when date     (puthash "d" date entry))
             (when headings (puthash "h" (vconcat headings) entry))
             (when links    (puthash "l" (vconcat links) entry))
             (if is-archive
                 (puthash (substring rel 9) entry archive-json)
               (puthash rel entry files-json)))
           ;; Build tags index
           (dolist (tag tags)
             (let* ((existing (gethash tag tags-index))
                    (new-list (cons rel existing)))
               (puthash tag new-list tags-index)))
           (cl-incf total)))
       files-data)

      ;; Query org-roam DB for roam nodes
      (let ((roam-nodes (wiki--roam-nodes))
            (roam-json (make-hash-table :test 'equal)))
        (dolist (node roam-nodes)
          (let* ((id    (car node))
                 (meta  (cdr node))
                 (title (plist-get meta :title))
                 (tags  (plist-get meta :tags))
                 (blinks (plist-get meta :backlinks))
                 (entry (make-hash-table :test 'equal)))
            (when title  (puthash "t" title entry))
            (when tags   (puthash "g" (vconcat tags) entry))
            (when blinks (puthash "l" (vconcat blinks) entry))
            (puthash id entry roam-json)))
        ;; Assemble root
        (let ((root (make-hash-table :test 'equal))
              (tags-final (make-hash-table :test 'equal)))
          (puthash "v" 1 root)
          (puthash "ts" (format-time-string "%Y-%m-%dT%H:%M:%S%z") root)
          (puthash "n" total root)
          (puthash "files" files-json root)
          (when (> (hash-table-count archive-json) 0)
            (puthash "archive" archive-json root))
          (when (> (hash-table-count roam-json) 0)
            (puthash "roam" roam-json root))
          ;; Tags index: deduplicate
          (maphash (lambda (tag files)
                     (puthash tag (vconcat (delete-dups files)) tags-final))
                   tags-index)
          (puthash "tags" tags-final root)
          ;; Write graph.json
          (with-temp-file graph-file
            (insert (json-encode root))))))

    ;; ── Write hash cache (plain text, no JSON) ──
    (wiki--write-hashes new-hashes)

    (message "📊 Graph built: %d/%d changed, %d skipped → %s"
             changed-count (+ changed-count skipped-count)
             skipped-count graph-file)
    graph-file))

(defun wiki-graph-stale-p ()
  "Return non-nil if graph.json is missing or stale."
  (let ((f (expand-file-name wiki-graph-file)))
    (or (not (file-exists-p f))
        (> (- (float-time)
              (float-time (file-attribute-modification-time
                           (file-attributes f))))
           wiki-graph-stale-seconds))))

;; ── Startup auto-build (5s idle, stale check) ──
(run-with-idle-timer 5 nil
  (lambda ()
    (when (and (boundp 'wiki-dir) wiki-dir
               (file-directory-p (expand-file-name wiki-dir))
               (wiki-graph-stale-p))
      (message "📊 Wiki graph stale or missing, building...")
      (wiki-build-graph))))

;; ── Save debounce (30s idle after last save) ──
(defvar wiki-graph--debounce-timer nil
  "Timer for debounced graph rebuild on save.")

(defun wiki-graph-after-save ()
  "Debounced graph rebuild after saving wiki files."
  (when (and buffer-file-name
             (string-prefix-p (expand-file-name wiki-dir) buffer-file-name)
             (string-match-p "\\.\\(org\\|md\\)$" buffer-file-name))
    (when (timerp wiki-graph--debounce-timer)
      (cancel-timer wiki-graph--debounce-timer))
    (setq wiki-graph--debounce-timer
          (run-with-idle-timer 30 nil #'wiki-build-graph))))

(add-hook 'after-save-hook #'wiki-graph-after-save)

;; ──────────────────────────────────────────────────────────────
;; Keybindings & Hooks
;; ──────────────────────────────────────────────────────────────
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c w v") #'wiki-validate-buffer)
  (define-key org-mode-map (kbd "C-c w a") #'wiki-archive-current-file)
  (define-key org-mode-map (kbd "C-c w f") #'wiki-ai-format-region)
  (define-key org-mode-map (kbd "C-c w F") #'wiki-ai-format-buffer)
  (define-key org-mode-map (kbd "C-c w d") #'wiki-delete-file)
  (define-key org-mode-map (kbd "C-c w c") #'wiki-commit))

(provide 'wiki-tools)
;;; wiki-tools.el ends here