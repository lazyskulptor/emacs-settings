;;; org-setting.el --- Org-mode configuration -*- lexical-binding: t; -*-

(use-package org :ensure t
  :mode ("\\.org\\'" . org-mode)
  :config
  (setq org-adapt-indentation t)
  (setq org-agenda-show-future-repeats 'next)
  (setq org-todo-keywords '((type "TODO" "|" "DONE")))
  (setq org-latex-pdf-process
        (list "latexmk -pdflatex='%latex -shell-escape -interaction nonstopmode' -pdf -output-directory=%o %f"))
  (setq org-directory (file-truename "~/Workspace/wiki/"))
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory))
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
      (python . t)
      (clojure . t)
      (ditaa . t)
       (plantuml . t)))
    (setq org-babel-python-command "uv run python")
    (setq org-babel-clojure-backend 'babashka)
   (setq org-ditaa-jar-path "/opt/homebrew/Cellar/ditaa/0.11.0_1/libexec/ditaa-0.11.0-standalone.jar")
   (setq org-ditaa-exec "/opt/homebrew/bin/ditaa")
   (setq org-ditaa-default-exec-mode 'ditaa))

(use-package org-pomodoro :ensure t
  :config (setq org-pomodoro-manual-break t))

(use-package org-roam :ensure t
  :init (setq org-roam-v2-ack t)
  :custom
  (org-roam-directory (file-truename "~/Workspace/wiki/"))
  (org-roam-file-exclude-regexp '("^\\(?:agent-shell\\|spiritual\\|study\\|scripts\\|projects\\|\\.\\(?:git\\|archive\\|graph\\)\\)/"))
  (org-roam-dailies-directory "daily/")
  (org-roam-completion-everywhere t)
  (org-roam-graph-viewer "open")
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n j" . org-roam-dailies-capture-today))
  :config
  (org-roam-setup)
  (with-eval-after-load 'org-roam-dailies
    (add-to-list 'org-roam-dailies-capture-templates
                 '("d" "default" entry "%?"
                   :if-new (file+head "%<%Y-%m-%d>.org"
                                      "#+title: %<%Y-%m-%d>\n#+roam_key: %<%Y-%m-%d>\n\n* Log\n")))))

(setq org-archive-location "~/Workspace/wiki-archive/%s_archive::")
(setq org-log-done 'time)

(require 'org-id)
(setq org-id-method 'uuid)

;;; 일일 반복 작업: DONE → 새 TODO 세대 생성 (SPAWN_INTERVAL 마커 기반)
;;;
;;; 사용법: 반복하고 싶은 항목의 property drawer에 마커를 추가한다.
;;;   :PROPERTIES:
;;;   :SPAWN_INTERVAL: +1d
;;;   :END:
;;; SCHEDULED 타임스탬프에는 org 리피터(+1d 등)를 붙이지 않는다.
;;; DONE으로 전환하면 원본은 DONE 기록으로 그대로 남고, 전체 내용을
;;; 복사한 TODO 항목이 다음 반복 날짜로 생성된다 (복제본에도 마커 복사).
(defconst my-org-spawn-interval-re "\\`\\+\\([1-9][0-9]*\\)\\([dwmy]\\)\\'"
  "SPAWN_INTERVAL 마커의 엄격한 형식: +N[dwm] (N은 1 이상).")

(defun my-org-spawn-parse-interval (interval)
  "INTERVAL이 `+N[dwm]'(N>=1) 형식이면 (일수 . 단위문자) cons, 아니면 nil."
  (when (and interval (string-match my-org-spawn-interval-re interval))
    (cons (string-to-number (match-string 1 interval))
          (match-string 2 interval))))

(defun my-org-next-spawn-date (interval base)
  "BASE(절대일수)로부터 INTERVAL(+1d/+2w 등)만큼 지난 절대일수를 반환.
INTERVAL이 형식에 맞지 않으면 nil."
  (let ((parsed (my-org-spawn-parse-interval interval)))
    (when parsed
      (+ base (* (car parsed)
                 (pcase (cdr parsed)
                   ("d" 1) ("w" 7) ("m" 30) ("y" 365)))))))

(defun my-org-spawn-repeat-generation ()
  "DONE 전환 시 :SPAWN_INTERVAL: 마커가 있으면 새 TODO 세대를 생성한다.

원본은 CLOSED가 추가될 뿐 그대로 DONE으로 남고, 서브트리 전체를
복사한 TODO 항목이 다음 반복 날짜로 생성된다. 복제본에는 마커가
복사되지만 ID와 LAST_REPEAT는 제거된다 (원본만 ID를 유지).
실제 checkbox가 있으면 초기화된다. 변경은 atomic-change-group으로
감싸 중간 오류 시 부분 복제본이 남지 않는다."
  (condition-case err
      (atomic-change-group
        (when (org-entry-is-done-p)
          (let ((interval (org-entry-get (point) "SPAWN_INTERVAL"))
                (scheduled (org-entry-get (point) "SCHEDULED")))
            (when (and (my-org-spawn-parse-interval interval) scheduled)
              (org-back-to-heading)
              (let* ((sched-date (org-time-string-to-absolute scheduled))
                     (base (max (org-today) (or sched-date 0)))
                     (next (my-org-next-spawn-date interval base))
                     (greg (calendar-gregorian-from-absolute next))
                     (next-ts (format "<%s>"
                                      (format-time-string "%Y-%m-%d %a"
                                        (encode-time 0 0 0 (nth 1 greg) (nth 0 greg) (nth 2 greg)))))
                     (beg (point))
                     (end (org-end-of-subtree nil t))
                     (text (buffer-substring-no-properties beg end))
                     (text (if (string-suffix-p "\n" text) text (concat text "\n")))
                     (copy-beg end))
                (goto-char end)
                (insert text)
                ;; 복제본 수정: TODO 전환 (훅 재귀 방지)
                (goto-char copy-beg)
                (let ((org-after-todo-state-change-hook nil))
                  (org-todo "TODO"))
                ;; 복제본은 id: 링크 대상이 아니므로 ID/LAST_REPEAT 제거 (원본만 유지)
                (goto-char copy-beg)
                (org-entry-delete (point) "ID")
                (org-entry-delete (point) "LAST_REPEAT")
                ;; SCHEDULED를 다음 반복 날짜로 교체 (org-scheduled-string은 "SCHEDULED:" 콜론 포함)
                (goto-char copy-beg)
                (let ((subtree-end (save-excursion (org-end-of-subtree nil t))))
                  (when (re-search-forward org-scheduled-time-regexp subtree-end t)
                    (replace-match (concat org-scheduled-string " " next-ts))))
                ;; 실제 checkbox marker가 있을 때만 초기화 (없으면 cookie 보존)
                (goto-char copy-beg)
                (let ((subtree-end (save-excursion (org-end-of-subtree nil t))))
                  (when (save-excursion
                          (re-search-forward "^[ \t]*[-+*][ \t]+\\[[ Xx-]\\]" subtree-end t))
                    (org-reset-checkbox-state-subtree)))
                (goto-char beg))))))
    (error (message "my-org-spawn-repeat-generation 실패: %s" (error-message-string err)))))

(add-hook 'org-after-todo-state-change-hook #'my-org-spawn-repeat-generation)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-,") 'lsp-bridge-return-from-def))

;; Org 테이블 내 폰트 설정 (Maple Mono NF CN 사용)
(require 'org-table-align)

(provide 'org-setting)
