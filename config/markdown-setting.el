;;; markdown-setting.el --- Markdown editing and xwidget preview -*- lexical-binding: t; -*-

;;; Commentary:
;; markdown-mode (문법 강조) + markdown-preview-xwidget-mode (xwidget-webkit 미리보기)
;; pandoc 설치: brew install pandoc (macOS), sudo apt install pandoc (Linux)

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; markdown-mode — 문법 강조, 접기, 목차
;; ─────────────────────────────────────────────────────────────

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" "\\.markdown\\'")
  :config
  (setq markdown-enable-math t)
  (setq markdown-fontify-code-blocks-natively t)
  (setq markdown-command "pandoc -f gfm -t html --syntax-highlighting=pygments")
  (put 'markdown-preview 'completion-predicate (lambda (&rest _) nil)))

;; xwidget-webkit 버퍼는 라인넘버 off
(add-hook 'xwidget-webkit-mode-hook
          (lambda () (display-line-numbers-mode -1)))

;; ─────────────────────────────────────────────────────────────
;; markdown-preview-xwidget-mode
;; ─────────────────────────────────────────────────────────────
;; temp .md ← write-region → pandoc -s (standalone HTML) → temp .html
;; xwidget ← browse-url → reload ← after-save-hook

(defvar-local markdown-preview-xwidget--md-file nil)
(defvar-local markdown-preview-xwidget--html-file nil)
(defvar-local markdown-preview-xwidget--xwidget-buf nil)

(defun markdown-preview-xwidget--find-xwidget-buf ()
  "xwidget-webkit 버퍼 찾기. 저장된 참조가 죽었으면 이름으로 검색."
  (or markdown-preview-xwidget--xwidget-buf
      (cl-find-if (lambda (b)
                    (let ((name (buffer-name b)))
                      (or (string-prefix-p "*xwidget-webkit:" name)
                          (string-match-p "md-preview-.*\\.html" name))))
                  (buffer-list))))

(defun markdown-preview-xwidget--find-source ()
  "markdown-preview-xwidget-mode가 활성화된 버퍼 찾기."
  (cl-find-if (lambda (b)
                (buffer-local-value 'markdown-preview-xwidget-mode b))
              (buffer-list)))

(defun markdown-preview-xwidget--render-file ()
  "버퍼 → temp .md → pandoc → temp .html."
  (when (and (buffer-file-name) markdown-preview-xwidget--html-file)
    (let ((coding-system-for-write 'utf-8))
      (write-region (point-min) (point-max)
                    markdown-preview-xwidget--md-file nil nil nil nil)
      (call-process "pandoc" nil nil nil
                    "-f" "gfm" "-t" "html" "-s"
                    "--syntax-highlighting=pygments"
                    "-o" markdown-preview-xwidget--html-file
                    markdown-preview-xwidget--md-file))))

(defun markdown-preview-xwidget--render ()
  "render-file + xwidget reload. after-save-hook 용."
  (markdown-preview-xwidget--render-file)
  (let ((xbuf (markdown-preview-xwidget--find-xwidget-buf)))
    (when (buffer-live-p xbuf)
      (setq markdown-preview-xwidget--xwidget-buf xbuf)
      (with-current-buffer xbuf
        (xwidget-webkit-reload)))))

(defun markdown-preview-xwidget--on-xbuf-kill ()
  "xwidget 버퍼 kill → 모드 자동 해제."
  (let ((src (markdown-preview-xwidget--find-source)))
    (when (buffer-live-p src)
      (with-current-buffer src
        (markdown-preview-xwidget-mode -1)))))

(defun markdown-preview-xwidget--start ()
  "미리보기 시작: temp 파일 + xwidget 버퍼 + hooks."
  (let ((src-buf (current-buffer))
        (base (make-temp-file "md-preview-")))
    (setq markdown-preview-xwidget--md-file   (concat base ".md")
          markdown-preview-xwidget--html-file (concat base ".html"))
    (markdown-preview-xwidget--render-file)
    (xwidget-webkit-browse-url
     (concat "file://" markdown-preview-xwidget--html-file))
    (let ((xbuf (markdown-preview-xwidget--find-xwidget-buf)))
      (when (buffer-live-p xbuf)
        (with-current-buffer xbuf
          (add-hook 'kill-buffer-hook
                    #'markdown-preview-xwidget--on-xbuf-kill nil t)
          (setq markdown-preview-xwidget--xwidget-buf xbuf))))
    (with-current-buffer src-buf
      (add-hook 'after-save-hook #'markdown-preview-xwidget--render nil t))))

(defun markdown-preview-xwidget--stop ()
  "미리보기 종료: hook 제거, temp 파일 삭제, xwidget 버퍼 kill."
  (let ((src (markdown-preview-xwidget--find-source)))
    (when (buffer-live-p src)
      (with-current-buffer src
        (remove-hook 'after-save-hook #'markdown-preview-xwidget--render t))))
  (when (buffer-live-p markdown-preview-xwidget--xwidget-buf)
    (with-current-buffer markdown-preview-xwidget--xwidget-buf
      (remove-hook 'kill-buffer-hook #'markdown-preview-xwidget--on-xbuf-kill))
    (kill-buffer markdown-preview-xwidget--xwidget-buf))
  (dolist (f (list markdown-preview-xwidget--md-file
                   markdown-preview-xwidget--html-file))
    (when (and f (file-exists-p f)) (delete-file f)))
  (setq markdown-preview-xwidget--md-file   nil
        markdown-preview-xwidget--html-file nil
        markdown-preview-xwidget--xwidget-buf nil))

;;;###autoload
(define-minor-mode markdown-preview-xwidget-mode
  "markdown-mode 버퍼에서 xwidget-webkit 미리보기.
Emacs --with-xwidgets 필요. pandoc 설치: brew install pandoc"
  :lighter " MPrev"
  :keymap nil
  (if markdown-preview-xwidget-mode
      (markdown-preview-xwidget--start)
    (markdown-preview-xwidget--stop)))

(provide 'markdown-setting)
;;; markdown-setting.el ends here
