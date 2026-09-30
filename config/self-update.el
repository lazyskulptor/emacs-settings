;;; self-update.el --- Auto-check and manual update for Emacs config -*- lexical-binding: t; -*-

;;; Commentary:
;; Automatic background fetch to check if ~/.emacs.d is out of date.
;; Manual M-x my/emacs-update to pull, update Python/npm, and rebuild packages.

;;; Code:

(require 'subr-x)  ; string-trim
(require 'straight)

(defcustom my/update-check-interval 86400
  "Seconds between auto-fetch checks (default: 24 hours).
Set to 0 to disable auto-check; use M-x my/emacs-update to update manually."
  :type 'integer
  :group 'emacs)

(defvar my/update-last-check-file
  (expand-file-name ".cache/self-update-state.el" my/emacs-dir)
  "File storing timestamp of last successful fetch.")

(defun my/update--last-check-time ()
  "Return timestamp of last check, or 0 if never checked."
  (condition-case nil
      (with-temp-buffer
        (insert-file-contents my/update-last-check-file)
        (read (current-buffer)))
    (error 0)))

(defun my/update--save-check-time ()
  "Record current time as last check."
  (make-directory (file-name-directory my/update-last-check-file) t)
  (with-temp-file my/update-last-check-file
    (insert (format "%d\n" (floor (time-to-seconds))))))

(defun my/update--check-needed-p ()
  "Return t if check interval has elapsed since last check."
  (let ((last (my/update--last-check-time))
        (now (floor (time-to-seconds))))
    (>= (- now last) my/update-check-interval)))

(defun my/update--current-branch ()
  "Return current branch name in ~/.emacs.d."
  (string-trim
   (shell-command-to-string
    (format "git -C %s rev-parse --abbrev-ref HEAD 2>/dev/null"
            (shell-quote-argument my/emacs-dir)))))

(defun my/update--latest-tag ()
  "Return latest Release tag (e.g., v1.0.1), or nil if none exists."
  (let ((result (string-trim
                 (shell-command-to-string
                  (format "git -C %s describe --tags --abbrev=0 2>/dev/null"
                          (shell-quote-argument my/emacs-dir))))))
    (unless (string-empty-p result)
      result)))

(defun my/update--behind-count (branch)
  "Return number of commits behind origin/BRANCH."
  (let ((result (shell-command-to-string
                 (format "git -C %s rev-list --count HEAD..origin/%s 2>/dev/null"
                         (shell-quote-argument my/emacs-dir)
                         (shell-quote-argument branch)))))
    (if (string-match "^[0-9]+$" (string-trim result))
        (string-to-number (string-trim result))
      0)))

(defun my/update--commits-since-tag (tag)
  "Return number of commits since TAG (e.g., v1.0.1)."
  (let ((result (string-trim
                 (shell-command-to-string
                  (format "git -C %s rev-list --count %s..HEAD 2>/dev/null"
                          (shell-quote-argument my/emacs-dir)
                          (shell-quote-argument tag))))))
    (if (string-match "^[0-9]+$" result)
        (string-to-number result)
      0)))

(defun my/update--fetch-async ()
  "Fetch origin asynchronously in ~/.emacs.d; print result when done."
  (let ((process (make-process
                  :name "emacs-update-fetch"
                  :command (list "git" "-C" my/emacs-dir "fetch" "origin")
                  :noquery t
                  :sentinel (lambda (proc _event)
                              (when (eq (process-status proc) 'exit)
                                (let* ((branch (my/update--current-branch))
                                       (behind-branch (my/update--behind-count branch))
                                       (latest-tag (my/update--latest-tag))
                                       (since-tag (and latest-tag (my/update--commits-since-tag latest-tag)))
                                       (msg (cond
                                             ((> behind-branch 0)
                                              (format "[Emacs] Config: %d commits behind origin/%s%s. Run M-x my/emacs-update to pull."
                                                      behind-branch branch
                                                      (if (and latest-tag (> since-tag 0))
                                                          (format " (Release: %s, %d commits after)" latest-tag since-tag)
                                                        "")))
                                             ((and latest-tag (> since-tag 0))
                                              (format "[Emacs] Config: %d commits after Release %s. Development version active."
                                                      since-tag latest-tag))
                                             (t
                                              (format "[Emacs] Config: up to date%s"
                                                      (if latest-tag (format " (Release %s)" latest-tag) ""))))))
                                  (my/update--save-check-time)
                                  (message "%s" msg)))))))
    process))

(defun my/emacs-update ()
  "Manually update: git pull + uv sync + npm update + straight-pull-all."
  (interactive)
  (let ((inhibit-read-only t)
        (buf (get-buffer-create "*emacs-update*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "=== Emacs Configuration Update ===\n\n")
      (insert "Running: scripts/update.sh\n")
      (insert "This may take a few minutes...\n\n"))
    (display-buffer buf)

    (let ((process (make-process
                    :name "emacs-update"
                    :command (list "bash" (expand-file-name "scripts/update.sh" my/emacs-dir))
                    :buffer buf
                    :stderr buf
                    :noquery t
                    :sentinel (lambda (proc _event)
                                (when (eq (process-status proc) 'exit)
                                  (with-current-buffer buf
                                    (insert "\n--- Rebuilding packages ---\n")
                                    (straight-pull-all)
                                    (insert "Done! Packages updated.\n")))))))
      process)))

(defun my/emacs-update-check ()
  "Check if update available (runs auto-check if interval elapsed)."
  (interactive)
  (if (and my/update-check-interval
           (my/update--check-needed-p))
      (my/update--fetch-async)
    (message "[Emacs] Skipping check (interval not elapsed)")))

;; ── Auto-check on idle ──────────────────────────────────────────

(when (and my/update-check-interval (> my/update-check-interval 0))
  (run-with-idle-timer 10 nil #'my/emacs-update-check))

(provide 'self-update)
;;; self-update.el ends here
