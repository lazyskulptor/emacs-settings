;;; eshell.el --- Eshell configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; eshell 기본 설정 (프롬프트, bash-completion, 단축명령, pcomplete, 히스토리)
;; TRAMP 원격 환경변수는 remote.el에 있음

;;; Code:

;; ─────────────────────────────────────────────────────────────
;; eshell 기본 설정
;; ─────────────────────────────────────────────────────────────

;; 프롬프트 함수: 축약된 경로 표시
(defun abbreviate-propt (p-list)
  "경로 리스트를 축약하여 표시."
  (if (cdr p-list)
      (abbreviate-propt (cdr p-list))
    (car p-list)))

(setq eshell-prompt-function
      (lambda ()
        (concat " "
                (abbreviate-propt (split-string (abbreviate-file-name (eshell/pwd)) "/"))
                (if (= (user-uid) 0) " # " " ✗ "))))

(setq eshell-prompt-regexp "^[^#$✗\n]* [#$✗] ")

;; ─────────────────────────────────────────────────────────────
;; bash-completion 로드
;; ─────────────────────────────────────────────────────────────

(use-package bash-completion
  :ensure nil  ;; 이미 설치됨
  :config
  ;; eshell 모드에서 bash-completion 활성화
  (add-hook 'eshell-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions
                        #'bash-completion-capf-nonexclusive nil t)
              (setq-local bash-completion-nospace t))))

;; ─────────────────────────────────────────────────────────────
;; bash-completion 각주(annotation) 처리
;; ─────────────────────────────────────────────────────────────
;; kubectl 등이 "value\tdescription" 형식으로 completion을 반환할 때,
;; 탭 문자 뒤의 설명을 분리하여 hash table에 저장

(defvar my/bash-completion-annotations (make-hash-table :test 'equal)
  "Hash table mapping completion candidates to their descriptions.")

(defun my/bash-completion-fix (orig-fn str comp single)
  "Strip description from STR before processing.
kubectl completion generates 'value  (description)' format.
This advice extracts the description and stores it in `my/bash-completion-annotations'."
  ;; Match "value  (description)" format
  (when (string-match "\\`\\([^ ]+\\)\\s-+(\\([^)]+\\))\\'" str)
    (let ((value (match-string 1 str))
          (desc (match-string 2 str)))
      (puthash value desc my/bash-completion-annotations)
      (setq str value)))
  (funcall orig-fn str comp single))

(defun my/bash-completion-annotation-function (candidate)
  "Return annotation for CANDIDATE from stored descriptions."
  (gethash candidate my/bash-completion-annotations))

(defun my/bash-completion-add-metadata (orig-fn &rest args)
  "Add metadata to bash-completion completion table.
This wraps the completion table to include annotation-function metadata."
  (let ((result (apply orig-fn args)))
    (if (and result (listp result) (>= (length result) 3))
        (let ((stub-start (nth 0 result))
              (stub-end (nth 1 result))
              (table (nth 2 result)))
          (if (functionp table)
              ;; dynamic table - wrap it to add metadata
              (list stub-start stub-end
                    (lambda (str predicate action)
                      (cond
                       ((eq action 'metadata)
                        '(metadata (annotation-function . my/bash-completion-annotation-function)))
                       (t (funcall table str predicate action)))))
            result))
      result)))

(with-eval-after-load 'bash-completion
  (advice-add 'bash-completion-fix :around #'my/bash-completion-fix)
  (advice-add 'bash-completion-capf-nonexclusive :around
              #'my/bash-completion-add-metadata))

;; Corfu에서 annotation을 표시하도록 설정
(with-eval-after-load 'corfu
  (setq corfu-echo-delay 0.5)
  ;; completion metadata에서 annotation-function을 자동으로 사용함
  )

;; ─────────────────────────────────────────────────────────────
;; eshell 단축 명령어
;; ─────────────────────────────────────────────────────────────

(defun eshell/ll (&rest args)
  "ls -la 단축 명령."
  (apply #'eshell/ls (append '("-la") args)))

(defun eshell/la (&rest args)
  "ls -a 단축 명령."
  (apply #'eshell/ls (append '("-a") args)))

(defun eshell/el (&rest args)
  "Evaluate Emacs Lisp expression.
Usage: el (expression) or el expression"
  (when args
    (let* ((expr-str (mapconcat 'identity args " "))
           (expr (read expr-str)))
      (eval expr))))

;; ─────────────────────────────────────────────────────────────
;; eshell 모드 훅
;; ─────────────────────────────────────────────────────────────

;; vc-mode가 프롬프트 렌더링 시 git 호출로 인한 멈춤 방지 + 원래 환경변수 저장
(add-hook 'eshell-mode-hook
          (lambda ()
            ;; Corfu 활성화 (공식 권장 설정)
            (setq-local corfu-auto nil)
            (corfu-mode)
            ;; eshell은 insert 모드로 시작
            (evil-insert-state)
            ;; evil 키바인딩 설정 (로드 순서 문제 해결)
            (evil-define-key 'insert eshell-mode-map (kbd "RET") 'eshell-send-input)
            (evil-define-key 'insert eshell-mode-map (kbd "S-RET") 'newline)
            (evil-define-key 'insert eshell-mode-map (kbd "M-RET") 'newline)))

;; ─────────────────────────────────────────────────────────────
;; pcomplete 규칙: eshell alias 자동완성
;; ─────────────────────────────────────────────────────────────
;; bash-completion은 eshell alias를 인식하지 못하므로 pcomplete 규칙이 필요

;; k alias → kubectl completion fallback
(defun pcomplete/k ()
  "Completion for k (kubectl alias)."
  (pcomplete-here
   '("get" "describe" "create" "apply" "delete" "edit"
     "logs" "exec" "port-forward" "proxy" "top"
     "config" "cluster-info" "api-resources" "api-versions"
     "rollout" "scale" "autoscale" "expose" "run" "set"
     "attach" "cp" "auth" "annotate" "label" "taint"
     "drain" "cordon" "uncordon" "wait" "diff"
     "alpha" "kustomize" "plugin" "version")))

;; ff alias → 파일 경로 completion (TRAMP 지원)
(defun pcomplete/ff ()
  "Completion for ff (find-file alias)."
  (while (pcomplete-here (pcomplete-entries))))

;; find-file → 파일 경로 completion (TRAMP 지원)
(defun pcomplete/find-file ()
  "Completion for find-file."
  (while (pcomplete-here (pcomplete-entries))))

;; ─────────────────────────────────────────────────────────────
;; Emacs Lisp 자동완성 (eshell에서)
;; ─────────────────────────────────────────────────────────────

(defun my/eshell-elisp-capf ()
  "Emacs Lisp completion for eshell when input starts with '('.
Supports both '(' directly and 'el ' prefix."
  (let ((input (buffer-substring-no-properties
                (save-excursion (eshell-bol) (point))
                (point))))
    (when (or (string-match-p "^\\s-*(\\S-*$" input)
              (string-match-p "^\\s-*\\(el\\|e\\|eval\\)\\s-+\\S-*$" input))
      (let* ((start (if (string-match "^\\s-*\\(el\\|e\\|eval\\)\\s-+" input)
                        (save-excursion
                          (eshell-bol)
                          (forward-char (match-end 0))
                          (point))
                      (save-excursion
                        (eshell-bol)
                        (search-forward "(" (line-end-position) t)
                        (backward-char 1)
                        (point))))
             (end (point)))
        (when (<= start end)
          (list start end
                (completion-table-dynamic
                 (lambda (str)
                   (all-completions str obarray 'functionp)))
                :exclusive 'no
                :annotation-function
                (lambda (candidate)
                  (let ((doc (ignore-errors
                              (documentation (intern candidate)))))
                    (when doc
                      (concat " - " (car (split-string doc "\n"))))))))))))

(add-hook 'eshell-mode-hook
          (lambda ()
            ;; Emacs Lisp completion 추가
            (add-hook 'completion-at-point-functions #'my/eshell-elisp-capf nil t)))

;; ─────────────────────────────────────────────────────────────
;; 히스토리 보관 설정 (한 달치)
;; ─────────────────────────────────────────────────────────────

(setq eshell-history-size 5000)
(setq eshell-hist-ignoredups t)

(defun my/eshell-archive-monthly-history ()
  "한 달 지난 eshell 히스토리를 아카이브하고 초기화."
  (let* ((history-file eshell-history-file-name)
         (archive-dir (expand-file-name "archive/" (file-name-directory history-file)))
         (archive-file (expand-file-name
                        (format-time-string "history-%Y%m.txt")
                        archive-dir)))
    (make-directory archive-dir t)
    (when (file-exists-p history-file)
      (copy-file history-file archive-file t)
      (write-region "" nil history-file nil 'silent)
      (message "[eshell] 히스토리 아카이브: %s" archive-file))))

(defun my/eshell-check-monthly-archive ()
  "Emacs 시작 시 한 달에 한 번씩 히스토리 아카이브 실행."
  (let ((marker (expand-file-name ".last-archive"
                                  (file-name-directory eshell-history-file-name))))
    (when (or (not (file-exists-p marker))
              (> (float-time (time-subtract (current-time)
                                            (nth 5 (file-attributes marker))))
                 (* 30 24 60 60)))
      (my/eshell-archive-monthly-history)
      (with-temp-file marker
        (insert (format-time-string "%Y-%m-%d %H:%M:%S"))))))

(add-hook 'emacs-startup-hook #'my/eshell-check-monthly-archive)

(provide 'eshell-config)
;;; eshell.el ends here
