;;; org-table-align.el --- Org 테이블 내 폰트 설정 (Maple Mono NF CN) -*- lexical-binding: t; -*-

;; 기존 advice 제거 (재로드 시 충돌 방지)
(when (advice-member-p #'my/org-table-apply-font 'org-table-align)
  (advice-remove 'org-table-align #'my/org-table-apply-font))

;; 기존 post-command-hook 제거 (재로드 시 충돌 방지)
(remove-hook 'post-command-hook #'my/org-table-apply-font-if-on-table)
(remove-hook 'org-mode-hook #'my/org-table-apply-font-on-entry)

;; 테이블 전용 face: Maple Mono NF CN 폰트
(defface my-org-table-face
  '((t :family "Maple Mono NF CN" :height 130))
  "Face for org table content with Maple Mono NF CN font.")

(defun my/org-table-clear-font-overlays (beg end)
  "Remove existing font overlays in region."
  (remove-overlays beg end 'my-org-table-font t))

(defun my/org-table-apply-font (&rest _)
  "Apply Maple Mono NF CN font to table region."
  (when (org-at-table-p)
    (let ((beg (org-table-begin))
          (end (org-table-end)))
      ;; 기존 오버레이 제거
      (my/org-table-clear-font-overlays beg end)
      ;; 새 오버레이 생성
      (let ((ov (make-overlay beg end)))
        (overlay-put ov 'my-org-table-font t)
        (overlay-put ov 'evaporate t)
        (overlay-put ov 'face 'my-org-table-face)))))

(defun my/org-table-apply-font-if-on-table ()
  "Apply font to table if point is on a table."
  (when (org-at-table-p)
    (my/org-table-apply-font)))

(defun my/org-table-apply-font-on-entry ()
  "Apply font when entering org-mode if table exists."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward org-table-any-line-regexp nil t)
      (when (org-at-table-p)
        (my/org-table-apply-font)
        (goto-char (org-table-end))))))

;; 1. org-mode 진입 시 테이블이 있으면 face 적용
(add-hook 'org-mode-hook #'my/org-table-apply-font-on-entry)

;; 2. 커서 이동 시 테이블 위에 있으면 face 적용
(add-hook 'post-command-hook #'my/org-table-apply-font-if-on-table)

;; 3. org-table-align 후 즉시 적용
(advice-add 'org-table-align :after #'my/org-table-apply-font)

(message "[org-table-align] Loaded. Maple Mono NF CN font active for org tables.")

(provide 'org-table-align)
