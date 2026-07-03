;;; utils.el --- General utility functions -*- lexical-binding: t; -*-

;;; Commentary:
;; IDE와 무관한 일반 유틸리티 함수들

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; 버퍼 관련 유틸리티
;; ─────────────────────────────────────────────────────────────

(defun scratch-keep-unique-lines ()
  "Remove duplicate lines in current buffer, keeping only unique ones."
  (interactive)
  (let ((seen (make-hash-table :test 'equal))
        (kept 0) (removed 0))
    (goto-char (point-min))
    (while (not (eobp))
      (let ((line (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
        (if (gethash line seen)
            (progn
              (delete-region (line-beginning-position)
                             (min (1+ (line-end-position)) (point-max)))
              (cl-incf removed))
          (puthash line t seen)
          (forward-line 1)
          (cl-incf kept))))
    (message "Kept %d unique lines, removed %d duplicates" kept removed)))

(defun copy-current-buffer-name ()
  "Copy the current buffer's name to the kill ring."
  (interactive)
  (let ((name (buffer-name)))
    (kill-new name)
    (message "Copied buffer name: %s" name)))

(defun copy-current-buffer-path ()
  "Copy the current buffer's file path to the kill ring."
  (interactive)
  (let ((path (buffer-file-name)))
    (if path
        (progn
          (kill-new path)
          (message "Copied buffer path: %s" path))
      (message "Buffer is not visiting a file"))))

(defun open-new-scratch-buffer ()
  "Create and switch to a new *scratch* buffer."
  (interactive)
  (switch-to-buffer (generate-new-buffer "*scratch*")))

;; ─────────────────────────────────────────────────────────────
;; TRAMP 관련 유틸리티
;; ─────────────────────────────────────────────────────────────

(defun tramp-copy-connection-path ()
  "현재 열린 TRAMP 연결 목록에서 선택하여 전체 경로를 kill-ring에 복사."
  (interactive)
  (let* ((all-remote-dirs
          (delete-dups
           (cl-loop for buf in (buffer-list)
                    for dir = (with-current-buffer buf default-directory)
                    when (file-remote-p dir)
                    collect dir)))
         (choice (when all-remote-dirs
                   (completing-read
                    "TRAMP connection: " all-remote-dirs nil t
                    (try-completion "" all-remote-dirs)))))
    (when (and choice (not (string-empty-p choice)))
      (kill-new choice))))

(provide 'utils)
;;; utils.el ends here
