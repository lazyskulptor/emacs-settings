;;; git-workspace.el --- Commands for sibling Git repositories -*- lexical-binding: t; -*-

(require 'magit)
(require 'projectile)
(require 'seq)
(require 'subr-x)

(defun git-workspace--root ()
  "Prompt for a workspace root."
  (read-directory-name "Git workspace: "
                       (or (projectile-project-root) default-directory)))

(defun git-workspace--repos (root)
  "Return immediate child Git repositories of ROOT."
  (seq-filter
   (lambda (dir) (file-directory-p (expand-file-name ".git" dir)))
   (directory-<PII type="CASE_ID" id="31"/> root t directory-<PII type="CASE_ID" id="32"/>-regexp)))

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

(defun git-workspace-list (root)
  "List repositories immediately below ROOT with Magit."
  (interactive (list (git-workspace--root)))
  (let ((magit-repository-directories (list (cons root 1))))
    (magit-list-repositories)))

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
