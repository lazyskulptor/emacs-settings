;; Disable package.el — straight.el manages everything
(setq package-enable-at-startup nil)

;; Fix native-comp on macOS + Homebrew: point Emacs to libgccjit + libgcc.a
(when (eq system-type 'darwin)
  (setenv "LIBRARY_PATH"
          (concat "/opt/homebrew/lib/gcc/current"
                  ":/opt/homebrew/lib/gcc/current/gcc/aarch64-apple-darwin24/14"
                  ":/opt/homebrew/lib")))
