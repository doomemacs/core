;;; tools/debugger/config.el -*- lexical-binding: t; -*-

;;
;;; Packages

(use-package! dape
  :defer t
  :preface
  (setq dape-adapter-dir (file-name-concat doom-user-dir "debug-adapters/"))
  :config
  (set-debug-var! 'dape-debug t)
  (setq dape-buffer-window-arrangement 'right
        dape-inlay-hints t
        dape-cwd-function #'+debugger-dape-cwd-function-fn)

  ;; REVIEW: Remove when projectile is replaced with project.el
  (defun +debugger-dape-cwd-function-fn ()
    (or (let (projectile-require-project-root)
          (projectile-project-root))
        (dape--default-cwd)))

  ;; Mode-line serves no purpose in REPL window.
  (add-hook 'dape-repl-mode-hook #'mode-line-invisible-mode)
  (add-hook 'dape-repl-mode-hook #'doom-disable-line-numbers-h)

  ;; Persist breakpoints after closing DAPE.
  (dape-breakpoint-global-mode +1)

  ;; HACK: Otherwise, if `dape-default-breakpoints-file's parent directory
  ;;   doesn't exist, `dape-breakpoint-save' will throw an error.
  ;; REVIEW: This should be upstreamed.
  (defadvice! +debugger--make-directory-a (&optional file)
    :before #'dape-breakpoint-save
    (make-directory (file-name-directory (or file dape-default-breakpoints-file)) t)))
