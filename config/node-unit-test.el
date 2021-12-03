(defun node-test-run-unit ()
  "Run thes closest test or it block."
  (interactive)
  (let ((filename (buffer-file-name))
        (example (node-test-unit-at-point)))
      (message (concat filename "::" example))))



(defun node-test-unit-at-point ()
  "Find the topmost it or test block from where the cursor is and extract the name."
  (save-excursion
   ; (re-search-backward "it\(\'")
   ; (let ((text (thing-at-point 'line t)))
   ; (let ((text (string (char-after 1))))
      (string-match "it\(\\(.*\\)," text)
      (when-let ((example (match-string 1 text)))
        (substring example 1 -1)))))
      ; (substring test 0 1))))


(provide 'node-unit-test)
