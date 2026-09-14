;;; git-workspace.el --- Commands for sibling Git repositories -*- lexical-binding: t; -*-

(require 'magit)
(require 'transient)
(require 'projectile)
(require 'seq)
(require 'subr-x)

(defvar-local git-workspace-root nil
  "Workspace root displayed by the current repository-list buffer.")

(defvar-local git-workspace-status-root nil
  "Workspace root this status buffer was opened from via `git-workspace-list'.")

(defun git-workspace--root ()
  "Prompt for a workspace root."
  (read-directory-name "Git workspace: "
                       (or (projectile-project-root) default-directory)))

(defun git-workspace--repos (root)
  "Return immediate child Git repositories of ROOT."
  (seq-filter
   (lambda (dir) (file-directory-p (expand-file-name ".git" dir)))
   (directory-files root t directory-files-no-dot-files-regexp)))

(defun git-workspace--git (dir &rest args)
  "Run Git ARGS in DIR and return (STATUS . OUTPUT)."
  (with-temp-buffer
    (let ((default-directory dir))
      (cons (apply #'process-file "git" nil t nil args)
            (string-trim (buffer-string))))))

(defun git-workspace--run (root operation)
  "Run OPERATION for each repository below ROOT and display its result."
  (with-current-buffer (get-buffer-create "*Git Workspace*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (dolist (dir (git-workspace--repos root))
        (insert (format "%-28s %s\n"
                        (file-name-nondirectory (directory-file-name dir))
                        (funcall operation dir))))
      (special-mode))
    (display-buffer (current-buffer))))

;;; Repository list

(defun git-workspace--display-buffer-same-window (buffer)
  "Display BUFFER by replacing the selected window's buffer.
Used as `magit-display-buffer-function' for Git Workspace's own status
transitions, so opening a repository or switching to a sibling always
replaces the current view instead of popping a new window (magit's
default `magit-display-buffer-traditional' opens another window both
when coming from the repolist and when going from one status buffer
to another)."
  (set-window-buffer (selected-window) buffer)
  (selected-window))

(defvar git-workspace-repolist-columns
  `(("Name"    25 ,#'magit-repolist-column-ident  ())
    ("Branch"  20 ,#'magit-repolist-column-branch ())
    ("Version" 25 ,#'magit-repolist-column-version
     ((:sort magit-repolist-version<)))
    ("Behind"   6 ,#'magit-repolist-column-unpulled-from-upstream
     ((:right-align t) (:sort <)))
    ("Ahead"    6 ,#'magit-repolist-column-unpushed-to-upstream
     ((:right-align t) (:sort <))))
  "Columns used by `git-workspace-list' (Name/Branch/Version/Behind/Ahead).
\"Behind\"/\"Ahead\" count commits relative to the upstream branch.")

(defun git-workspace-repolist-status ()
  "Open the status buffer for the repository at point.
Unlike `magit-repolist-status', this also enables
`git-workspace-status-nav-mode' so sibling repositories can be
reached without returning to the list."
  (interactive)
  (let ((root git-workspace-root)
        (magit-display-buffer-function #'git-workspace--display-buffer-same-window))
    (if-let ((id (tabulated-list-get-id)))
        (with-current-buffer (magit-status-setup-buffer (expand-file-name id))
          (setq-local git-workspace-status-root root)
          (git-workspace-status-nav-mode 1))
      (user-error "There is no repository at point"))))

(defun git-workspace-repolist-refresh ()
  "Refresh the Git Workspace repository list.
Rebuilds it via `git-workspace-list' instead of the plain
`magit-list-repositories'/`magit-repolist-refresh', so the custom
columns and RET/evil overrides survive the refresh."
  (interactive)
  (git-workspace-list git-workspace-root))

(defun git-workspace-list (root)
  "List repositories immediately below ROOT with Magit.
RET on a repository opens its status with sibling navigation enabled."
  (interactive (list (git-workspace--root)))
  (let* ((repo-dirs (mapcar (lambda (repo) (cons repo 0))
                            (git-workspace--repos root)))
         (magit-repository-directories repo-dirs))
    (magit-repolist-setup git-workspace-repolist-columns)
    ;; `magit-repolist-setup' wraps its body in `with-current-buffer', which
    ;; restores the caller's buffer on exit even though it switched the
    ;; window's display via `switch-to-buffer'.  Re-enter the list buffer by
    ;; name so the customizations below land on the right buffer.
    (with-current-buffer "*Magit Repositories*"
      (setq-local git-workspace-root root)
      ;; Route every refresh path through `git-workspace-repolist-refresh'
      ;; instead of the stock revert/refresh machinery: evil-collection's
      ;; "g r" ("refresh") calls plain `magit-list-repositories', which would
      ;; reset the columns and keymap overrides below.  (Buffer-locally
      ;; pinning `magit-repository-directories' here instead, so plain
      ;; `revert-buffer' would also pick it up, turned out to break this very
      ;; call on the *second* refresh — `let'-binding a variable that already
      ;; has a buffer-local value in the current buffer interacts badly with
      ;; the `kill-all-local-variables' that `magit-repolist-mode' runs a few
      ;; lines above — so it deliberately stays a plain dynamic `let' instead.)
      (setq-local revert-buffer-function
                  (lambda (&rest _) (git-workspace-repolist-refresh)))
      ;; evil-collection binds its "action" key for `magit-repolist-mode' under
      ;; both "RET" and "<return>" (GUI frames resolve a physical Enter press to
      ;; the more specific "<return>" event first), directly into Evil's
      ;; normal-state keymap, which is looked up before the buffer's local map.
      ;; Both key forms need overriding in both layers, or a real keypress
      ;; still finds evil-collection's original binding via whichever form we
      ;; missed.  Same story for "g r" (its "refresh" key).
      (let ((map (make-sparse-keymap)))
        (set-keymap-parent map (current-local-map))
        (keymap-set map "RET" #'git-workspace-repolist-status)
        (keymap-set map "<return>" #'git-workspace-repolist-status)
        (keymap-set map "g r" #'git-workspace-repolist-refresh)
        (use-local-map map))
      (when (fboundp 'evil-local-set-key)
        (evil-local-set-key 'normal (kbd "RET") #'git-workspace-repolist-status)
        (evil-local-set-key 'normal (kbd "<return>") #'git-workspace-repolist-status)
        (evil-local-set-key 'normal (kbd "g r") #'git-workspace-repolist-refresh))
      (current-buffer))))

;;; Sibling navigation from a status buffer

(defface git-workspace-status-current-face
  '((t :inherit bold))
  "Face for the current repository name in the Git Workspace header line.")

(defun git-workspace--sibling (dir step)
  "Return the sibling of DIR that is STEP repositories away, cyclically.
Siblings are computed from `git-workspace-status-root'."
  (when-let* ((root git-workspace-status-root)
              (repos (mapcar #'directory-file-name (git-workspace--repos root)))
              (pos (seq-position repos (directory-file-name dir) #'string-equal)))
    (nth (mod (+ pos step) (length repos)) repos)))

(defun git-workspace--header-line ()
  "Build the \"< prev  current  next >\" header line for a status buffer."
  (let ((prev (git-workspace--sibling default-directory -1))
        (next (git-workspace--sibling default-directory 1))
        (current (file-name-nondirectory (directory-file-name default-directory))))
    (concat "< "
            (if prev (propertize (file-name-nondirectory prev) 'face 'shadow) "")
            "   "
            (propertize current 'face 'git-workspace-status-current-face)
            "   "
            (if next (propertize (file-name-nondirectory next) 'face 'shadow) "")
            " >")))

(defun git-workspace--status-goto (target)
  "Open the status buffer for TARGET, keeping sibling navigation enabled."
  (unless target
    (user-error "No sibling repository found"))
  (let ((root git-workspace-status-root)
        (magit-display-buffer-function #'git-workspace--display-buffer-same-window))
    (with-current-buffer (magit-status-setup-buffer target)
      (setq-local git-workspace-status-root root)
      (git-workspace-status-nav-mode 1))))

(defun git-workspace-status-next ()
  "Show the status of the next sibling repository."
  (interactive)
  (git-workspace--status-goto (git-workspace--sibling default-directory 1)))

(defun git-workspace-status-previous ()
  "Show the status of the previous sibling repository."
  (interactive)
  (git-workspace--status-goto (git-workspace--sibling default-directory -1)))

(defun git-workspace-status-back-to-list ()
  "Return to the Git Workspace repository list."
  (interactive)
  (if-let ((buf (get-buffer "*Magit Repositories*")))
      (switch-to-buffer buf)
    (user-error "No Git Workspace list buffer found")))

(defvar-keymap git-workspace-status-nav-mode-map
  :doc "Keymap for `git-workspace-status-nav-mode'."
  "C-c C-f" #'git-workspace-status-next
  "C-c C-b" #'git-workspace-status-previous
  "C-c C-k" #'git-workspace-status-back-to-list
  "q"       #'git-workspace-status-back-to-list)

(define-minor-mode git-workspace-status-nav-mode
  "Navigate between sibling repositories opened via `git-workspace-list'."
  :lighter " GW-Nav"
  (setq header-line-format
        (when git-workspace-status-nav-mode
          '(:eval (git-workspace--header-line))))
  ;; evil-collection binds "q" for all magit buffers directly into Evil's
  ;; normal-state keymap (`magit-mode-bury-buffer'), which outranks the
  ;; plain keymap binding above, so it needs the same buffer-local override.
  (when (and git-workspace-status-nav-mode (fboundp 'evil-local-set-key))
    (evil-local-set-key 'normal (kbd "q") #'git-workspace-status-back-to-list)))

;; Surface the same three commands in magit's own `?' menu, but only
;; while browsing a status buffer opened via `git-workspace-list'.
;; `defvar' leaves an already-bound value alone, so this guard makes the
;; append idempotent across `eval-buffer'/`load-file' reloads within the
;; same session — otherwise every reload appends another "Git Workspace"
;; group and it piles up in the `?' menu.
(defvar git-workspace--dispatch-suffix-installed nil
  "Non-nil once the Git Workspace group has been added to `magit-dispatch'.")

(unless git-workspace--dispatch-suffix-installed
  (transient-append-suffix 'magit-dispatch '(2)
    ["Git Workspace"
     :if (lambda () (bound-and-true-p git-workspace-status-nav-mode))
     ("n" "다음 저장소 (C-c C-f)"     git-workspace-status-next)
     ("p" "이전 저장소 (C-c C-b)"     git-workspace-status-previous)
     ("0" "목록으로 복귀 (C-c C-k)"   git-workspace-status-back-to-list)])
  (setq git-workspace--dispatch-suffix-installed t))

;;; Bulk operations

(defun git-workspace-pull (root)
  "Pull clean repositories immediately below ROOT using fast-forward only."
  (interactive (list (git-workspace--root)))
  (git-workspace--run
   root (lambda (dir)
          (if (not (string-empty-p (cdr (git-workspace--git dir "status" "--porcelain"))))
              "SKIP dirty"
            (pcase-let ((`(,status . ,output)
                         (git-workspace--git dir "pull" "--ff-only")))
              (format "%s %s" (if (zerop status) "OK" "FAIL") output))))))

(defun git-workspace-switch (root branch)
  "Switch clean repositories below ROOT to existing local BRANCH."
  (interactive (list (git-workspace--root) (read-string "Branch: ")))
  (git-workspace--run
   root (lambda (dir)
          (cond
           ((not (string-empty-p (cdr (git-workspace--git dir "status" "--porcelain"))))
            "SKIP dirty")
           ((not (zerop (car (git-workspace--git
                              dir "show-ref" "--verify" "--quiet"
                              (concat "refs/heads/" branch)))))
            "SKIP branch missing")
           (t (pcase-let ((`(,status . ,output)
                            (git-workspace--git dir "switch" branch)))
                (format "%s %s" (if (zerop status) "OK" "FAIL") output)))))))

(defvar-keymap git-workspace-command-map
  :doc "Git workspace commands."
  "l" #'git-workspace-list
  "p" #'git-workspace-pull
  "s" #'git-workspace-switch)

(global-set-key (kbd "C-c w") git-workspace-command-map)

(provide 'git-workspace)
;;; git-workspace.el ends here
