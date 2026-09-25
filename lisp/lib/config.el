;;; lisp/lib/config.el -*- lexical-binding: t; -*-

;;;###autoload
(defvar doom-after-reload-hook '(doom-kill-childframes-h)
  "A list of hooks to run after `doom/reload' has reloaded Doom.")

;;;###autoload
(defvar doom-before-reload-hook nil
  "A list of hooks to run before `doom/reload' has reloaded Doom.")

;;;###autoload
(defun doom/open-private-config ()
  "Browse your `doom-user-dir'."
  (interactive)
  (unless (file-directory-p doom-user-dir)
    (user-error "$DOOMDIR doesn't exist (%s)" (abbreviate-file-name doom-user-dir)))
  (doom-project-browse doom-user-dir))

;;;###autoload
(defun doom/find-file-in-private-config ()
  "Search for a file in `doom-user-dir'."
  (interactive)
  (doom-project-find-file doom-user-dir))


;;
;;; * Config reloading

(defmacro doom--if-compile (command on-success &optional on-failure)
  (declare (indent 2))
  `(let* ((default-directory doom-emacs-dir)
          (doom-bin "doom")
          (doom-bin-dir (expand-file-name "bin/"))
          (emacs-bin (doom-path invocation-directory invocation-name))
          (exec-path (cons doom-bin-dir exec-path))
          (shell-file-name shell-file-name))
     (when (and (featurep :system 'windows)
                (string-match-p "cmdproxy.exe$" shell-file-name))
       (if-let* ((pwsh (or (executable-find "pwsh")
                           (executable-find "powershell"))))
           (setq doom-bin "doom.ps1"
                 shell-file-name pwsh)
         (user-error "Powershell 3.0+ is required for `doom/reload', but no pwsh.exe or powershell.exe found in your $PATH")))
     ;; Ensure the bin/doom operates with the same environment as this running
     ;; session.
     (with-current-buffer
         (with-environment-variables
             (("PATH" (string-join exec-path path-separator))
              ("EMACS"
               (if (featurep :system 'windows)
                   (replace-regexp-in-string " " "\\ " emacs-bin t t)
                 (shell-quote-argument emacs-bin)))
              ("EMACSDIR" doom-emacs-dir)
              ("DOOMDIR" doom-user-dir)
              ("DOOMLOCALDIR" doom-local-dir)
              ("DEBUG" (if doom-debug-mode (number-to-string doom-log-level))))
           (compile (format ,command (file-name-concat "bin" doom-bin)) t))
       (let ((w (get-buffer-window (current-buffer))))
         (select-window w)
         (add-hook
          'compilation-finish-functions
          (lambda (_buf status)
            (if (equal status "finished\n")
                (progn
                  (use-local-map (make-composed-keymap nil (current-local-map)))
                  (local-set-key "q" #'quit-window)
                  (with-current-buffer "*scratch*" ,on-success))
              ,on-failure))
          nil 'local)))))

(defvar doom-reload-command
  (format "%s sync -B -e"
          ;; /usr/bin/env doesn't exist on Android
          (if (featurep :system 'android)
              "sh %s"
            "%s"))
  "Command that `doom/reload' runs.")
;;;###autoload
(defun doom/reload ()
  "Reloads your private config.

WARNING: This command is experimental, and likely always will be! It executes
\\='doom sync', reloads the active profile, re-evaluates all modules, then your
config, but this isn't a perfect replication of the startup process (which is
impossible in Emacs without a hard restart), so any misconfiguration on your
part can have compounding, deleterious effects that may result in slowness,
missing keybinds, or breakage. This is the best you can (or should) ever expect
from a command like this (in any Emacs starter kit, for that matter).

Otherwise, save yourself the headache and simply run \\='doom sync' outside of
Emacs and restart. That will always work.

Runs `doom-before-reload-hook' first, then `doom-after-reload-hook' afterwards."
  (interactive)
  (mapc #'require (cdr doom-incremental-packages))
  (doom--if-compile doom-reload-command
      (with-doom-context 'reload
        (doom-run-hooks 'doom-before-reload-hook)
        (with-demoted-errors "PRIVATE CONFIG ERROR: %s"
          (general-auto-unbind-keys)
          (unwind-protect
              (startup--load-user-init-file nil)
            (general-auto-unbind-keys t)
            (doom-run-hooks 'doom-after-reload-hook)))
        (message "Config successfully reloaded!"))
    (user-error "Failed to reload your config")))

;; DEPRECATED: Replaced in v3
;;;###autoload
(defun doom/reload-env ()
  "Reloads your envvar file.

DOES NOT REGENERATE IT. You must run \\='doom sync --env' in your shell OUTSIDE
of Emacs. Doing so from within Emacs will taint your shell environment.

An envvar file contains a snapshot of your shell environment, which can be
imported into Emacs."
  (interactive)
  (with-doom-context 'reload
    (require 'doom-profiles)
    (let ((env-file (doom-profile-dir t doom-profile-init-dir-name "05-doom-env.load.el")))
      (if (file-exists-p env-file)
          (load-file env-file)
        (user-error "No envvar file found! Run 'doom sync --env' in your shell to generate one!")))))

(provide 'doom-lib '(config))
;;; config.el ends here
