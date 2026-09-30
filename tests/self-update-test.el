;;; self-update-test.el --- Tests for self-update.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'self-update)

;; ── Test: git fetch must be async, never blocking ──────────────

(ert-deftest my/update-check-uses-async-process ()
  "Verify that fetch is always async (never call-process)."
  ;; Stub process creation to verify async
  (let ((process-created nil))
    (cl-letf* (((symbol-function 'make-process)
                (lambda (&rest args)
                  (setq process-created t)
                  (let ((sentinel (plist-get args :sentinel)))
                    ;; Mock process object
                    (list 'process :sentinel sentinel)))))
      (my/update--fetch-async)
      (should process-created))))

(ert-deftest my/update-check-never-calls-call-process ()
  "Verify that my/update--fetch-async never calls synchronous call-process."
  ;; Make call-process throw to detect any blocking calls
  (let ((call-process-called nil))
    (cl-letf* (((symbol-function 'call-process)
                (lambda (&rest _args)
                  (setq call-process-called t)
                  (error "call-process should not be used in fetch")))
               ((symbol-function 'make-process)
                (lambda (&rest args) nil)))
      (my/update--fetch-async)
      (should-not call-process-called))))

;; ── Test: parse git output ───────────────────────────────────────

(ert-deftest my/update-behind-count-parses-number ()
  "Verify that behind-count correctly parses git output."
  (let ((git-result "5\n"))
    (cl-letf* (((symbol-function 'shell-command-to-string)
                (lambda (_) git-result)))
      (should (= (my/update--behind-count "main") 5)))))

(ert-deftest my/update-behind-count-handles-no-upstream ()
  "Return 0 when upstream branch doesn't exist."
  (let ((git-result ""))
    (cl-letf* (((symbol-function 'shell-command-to-string)
                (lambda (_) git-result)))
      (should (= (my/update--behind-count "nonexistent") 0)))))

;; ── Test: time-based check ───────────────────────────────────────

(ert-deftest my/update-check-needed-initial ()
  "On first run (no state file), check is always needed."
  (cl-letf* (((symbol-function 'my/update--last-check-time)
              (lambda () 0)))
    (should (my/update--check-needed-p))))

(ert-deftest my/update-check-respects-interval ()
  "When interval not elapsed, skip check."
  (let ((now (floor (time-to-seconds)))
        (interval my/update-check-interval))
    (cl-letf* (((symbol-function 'my/update--last-check-time)
                (lambda () (- now 1))))  ; 1 second ago
      (should-not (my/update--check-needed-p)))))

(provide 'self-update-test)
;;; self-update-test.el ends here
