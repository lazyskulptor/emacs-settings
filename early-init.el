;; Disable package.el — straight.el manages everything
(setq package-enable-at-startup nil)

;; Configure native-compilation with Homebrew GCC (from properties.local.el)
(when (eq system-type 'darwin)
  ;; Load GCC version from properties.local.el
  (let ((gcc-version "16"))  ; default fallback
    (condition-case nil
        (progn
          (load "~/.emacs.d/properties" t)  ; load properties.el silently
          (load "~/.emacs.d/properties.local" t))  ; load local overrides silently
      (error nil))

    ;; Set up libgccjit and GCC compiler paths
    (when (boundp 'gcc-version)
      (setq gcc-version gcc-version))

    (setenv "LIBRARY_PATH"
            (concat (format "/opt/homebrew/lib/gcc/%s" gcc-version)
                    ":/opt/homebrew/lib/gcc/current"
                    ":/opt/homebrew/lib"))

    (setenv "CC" (format "/opt/homebrew/bin/gcc-%s" gcc-version))
    (setenv "CXX" (format "/opt/homebrew/bin/g++-%s" gcc-version))))
