;;; remote-winrm-test.el --- Tests for remote WinRM integration -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defvar my/emacs-dir
  (file-name-directory (directory-file-name
                        (file-name-directory (or load-file-name buffer-file-name)))))
(load (expand-file-name "config/remote.el" my/emacs-dir) nil t)

(defconst remote-winrm-test--server
  '(:name "test" :host "server.example.com" :port "3389"
    :account "Administrator" :tag "windows"))

(ert-deftest remote-winrm-start-keeps-password-out-of-command ()
  (let ((winrm-python-command "/usr/bin/python3")
        (winrm-client-script (expand-file-name "scripts/winrm_client.py" my/emacs-dir))
        captured-command
        captured-environment)
    (cl-letf (((symbol-function 'ssh-servers--find-password)
               (lambda (_tag _account) "top-secret"))
              ((symbol-function 'make-process)
               (lambda (&rest args)
                 (setq captured-command (plist-get args :command)
                       captured-environment (copy-sequence process-environment))
                 'fake-process))
              ((symbol-function 'display-buffer) #'ignore))
      (winrm--start 'upload remote-winrm-test--server
                    (expand-file-name "scripts/winrm_client.py" my/emacs-dir)))
    (should (member "EMACS_WINRM_PASSWORD=top-secret" captured-environment))
    (should-not (member "top-secret" captured-command))
    (should (member "5985" captured-command))
    (should (member "--no-ssl" captured-command))
    (should (member "--no-cert-validation" captured-command))))

(ert-deftest remote-winrms-start-uses-https-options ()
  (let ((winrm-python-command "/usr/bin/python3")
        (winrm-client-script (expand-file-name "scripts/winrm_client.py" my/emacs-dir))
        captured-command)
    (cl-letf (((symbol-function 'ssh-servers--find-password)
               (lambda (_tag _account) "top-secret"))
              ((symbol-function 'make-process)
               (lambda (&rest args)
                 (setq captured-command (plist-get args :command))
                 'fake-process))
              ((symbol-function 'display-buffer) #'ignore))
      (winrm--start 'upload remote-winrm-test--server
                    (expand-file-name "scripts/winrm_client.py" my/emacs-dir)
                    nil nil t))
    (should (member "5986" captured-command))
    (should (member "--ssl" captured-command))
    (should (member "--cert-validation" captured-command))))

(ert-deftest remote-winrm-cli-is-separate-from-rdp-and-omits-password ()
  (let (cli-program cli-args rdp-program)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (when (equal program "evil-winrm") "/opt/bin/evil-winrm")))
              ((symbol-function 'call-process)
               (lambda (&rest _args) 0))
              ((symbol-function 'start-process)
               (lambda (_name _buffer program &rest args)
                 (if (equal program "osascript")
                     (setq cli-program program cli-args args)
                   (setq rdp-program program))
                 'fake-process))
              ((symbol-function 'ssh-servers--find-password)
               (lambda (_tag _account) "top-secret")))
      (winrm--open-cli remote-winrm-test--server)
      (ssh-servers--connect-rdp remote-winrm-test--server))
    (should (equal cli-program "osascript"))
    (should (equal rdp-program "sdl-freerdp"))
    (should (seq-some (lambda (arg) (string-match-p "evil-winrm" arg)) cli-args))
    (should (seq-some (lambda (arg) (string-match-p "5985" arg)) cli-args))
    (should-not (seq-some (lambda (arg) (string-match-p " -S" arg)) cli-args))
    (should-not (seq-some (lambda (arg) (string-match-p "top-secret" arg)) cli-args))))

(ert-deftest remote-winrms-cli-adds-ssl-option ()
  (let (cli-args)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (_program) "/opt/bin/evil-winrm"))
              ((symbol-function 'call-process)
               (lambda (&rest _args) 0))
              ((symbol-function 'start-process)
               (lambda (_name _buffer _program &rest args)
                 (setq cli-args args)
                 'fake-process)))
      (winrm--open-cli remote-winrm-test--server t))
    (should (seq-some (lambda (arg) (string-match-p "5986" arg)) cli-args))
    (should (seq-some (lambda (arg) (string-match-p " -S" arg)) cli-args))))

(ert-deftest remote-winrm-current-file-uses-selected-server ()
  (let ((winrm-selected-server remote-winrm-test--server)
        (winrm-selected-secure t)
        captured-server
        captured-file
        captured-secure)
    (with-temp-buffer
      (setq buffer-file-name "/tmp/sample.ps1")
      (set-buffer-modified-p nil)
      (cl-letf (((symbol-function 'winrm-upload-file)
                 (lambda (server file &optional _remote-path secure)
                   (setq captured-server server
                         captured-file file
                         captured-secure secure))))
        (winrm-upload-current-file)))
    (should (equal captured-server remote-winrm-test--server))
    (should (equal captured-file "/tmp/sample.ps1"))
    (should captured-secure)))

(ert-deftest remote-winrm-modified-buffer-must-be-saved ()
  (let ((winrm-selected-server remote-winrm-test--server))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/sample.ps1")
      (insert "Write-Output changed")
      (should-error (winrm-run-current-file) :type 'user-error))))

(provide 'remote-winrm-test)
;;; remote-winrm-test.el ends here
