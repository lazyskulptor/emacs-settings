(require 'jest-test-mode)

(defun jest-test-run-unit ()
  "Run thes closest test or it block."
  (interactive)
  (let ((filename (jest-test-find-file))
        (example (concat  (jest-test-example-at-point) " " (jest-test-unit-at-point))))
    (if (and filename example)
        (jest-test-from-project-directory filename
          (let ((jest-test-options (seq-concatenate 'list jest-test-options (list "-t" example))))
            (jest-test-run-command (jest-test-command filename))))
      (message jest-test-not-found-message))))



(defun jest-test-unit-at-point ()
  "Find the topmost it or test block from where the cursor is and extract the name."
  (save-excursion
    (re-search-backward "it\(\'")
    (let ((text (thing-at-point 'line t)))
      (string-match "it\(\\(.*\\)," text)
      (when-let ((example (match-string 1 text)))
        (substring example 1 -1)))))

(define-key jest-test-mode-map (kbd "C-c C-t u") 'jest-test-run-unit)
