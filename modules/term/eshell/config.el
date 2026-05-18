;;; term/eshell/config.el -*- lexical-binding: t; -*-

;; see:
;;   + `+eshell/here': open eshell in the current window
;;   + `+eshell/toggle': toggles an eshell popup
;;   + `+eshell/frame': converts the current frame into an eshell-dedicated
;;   frame. Once the last eshell process is killed, the old frame configuration
;;   is restored.

(defvar +eshell-config-dir
  (expand-file-name "eshell/" doom-user-dir)
  "Where to store eshell configuration files, as opposed to
`eshell-directory-name', which is where Doom will store temporary/data files.")

(defvar eshell-directory-name (file-name-concat doom-profile-data-dir "eshell")
  "Where to store temporary/data files, as opposed to `eshell-config-dir',
which is where Doom will store eshell configuration files.")

(defvar +eshell-enable-new-shell-on-split t
  "If non-nil, spawn a new eshell session after splitting from an eshell
buffer.")

(defvar +eshell-kill-window-on-exit nil
  "If non-nil, eshell will close windows along with its eshell buffers.")

(defvar +eshell-aliases
  '(("q"  "exit")           ; built-in
    ("f"  "find-file $1")
    ("ff" "find-file-other-window $1")
    ("d"  "dired $1")
    ("bd" "eshell-up $1")
    ("rg" "rg --color=always $*")
    ("l"  "ls -lh $*")
    ("ll" "ls -lah $*")
    ("git" "git --no-pager $*")
    ("gg" "magit-status")
    ("cdp" "cd-to-project")
    ("clear" "clear-scrollback")) ; more sensible than default
  "An alist of default eshell aliases, meant to emulate useful shell utilities,
like fasd and bd. Note that you may overwrite these in your
`eshell-aliases-file'. This is here to provide an alternative, elisp-centric way
to define your aliases.

You should use `set-eshell-alias!' to change this.")

;; These files are exceptions, because they may contain configuration
(defvar eshell-aliases-file (concat +eshell-config-dir "aliases"))
(defvar eshell-rc-script    (concat +eshell-config-dir "profile"))
(defvar eshell-login-script (concat +eshell-config-dir "login"))

(defvar +eshell--default-aliases nil)


;;
;;; Packages

(after! eshell ; built-in
  (set-lookup-handlers! 'eshell-mode
    :documentation #'+eshell-lookup-documentation)

  (setq eshell-banner-message
        '(format "%s %s\n"
                 (propertize (format " %s " (string-trim (buffer-name)))
                             'face 'mode-line-highlight)
                 (propertize (current-time-string)
                             'face 'font-lock-keyword-face))
        eshell-scroll-to-bottom-on-input 'all
        eshell-scroll-to-bottom-on-output 'all
        eshell-kill-processes-on-exit t
        eshell-hist-ignoredups t
        ;; Don't record command in history if prefixed with whitespace
        ;; TODO: Use `eshell-input-filter-initial-space' when Emacs 25 support is dropped
        eshell-input-filter (lambda (input) (not (string-match-p "\\`\\s-+" input)))
        ;; em-prompt
        eshell-prompt-regexp "^[^#$\n]* [#$λ] "
        eshell-prompt-function #'+eshell-default-prompt-fn
        ;; em-glob
        eshell-glob-case-insensitive t
        eshell-error-if-no-glob t)

  ;; Keep track of open eshell buffers
  (add-hook 'eshell-mode-hook #'+eshell-init-h)
  (add-hook 'eshell-exit-hook #'+eshell-cleanup-h)

  ;; UX: Temporarily disable undo history between command executions. Otherwise,
  ;;   undo could destroy output while it's being printed or delete buffer
  ;;   contents past the boundaries of the current prompt.
  (add-hook 'eshell-pre-command-hook #'buffer-disable-undo)
  (add-hook! 'eshell-post-command-hook
    (defun +eshell--enable-undo-h ()
      (buffer-enable-undo (current-buffer))
      (setq buffer-undo-list nil)))

  ;; UX: Prior output in eshell buffers should be read-only. Otherwise, it's
  ;;   trivial to make edits in visual modes (like evil's or term's
  ;;   term-line-mode) and leave the buffer in a half-broken state (which you
  ;;   must flush out with a couple RETs, which may execute the broken text in
  ;;   the buffer),
  (add-hook! 'eshell-pre-command-hook
    (defun +eshell-protect-input-in-visual-modes-h ()
      (when (and eshell-last-input-start
                 eshell-last-input-end)
        (add-text-properties eshell-last-input-start
                             (1- eshell-last-input-end)
                             '(read-only t)))))
  (add-hook! 'eshell-post-command-hook
    (defun +eshell-protect-output-in-visual-modes-h ()
      (when (and eshell-last-input-end
                 eshell-last-output-start)
        (add-text-properties eshell-last-input-end
                             eshell-last-output-start
                             '(read-only t)))))

  ;; Enable autopairing in eshell
  (add-hook 'eshell-mode-hook #'electric-pair-local-mode)

  ;; Persp-mode/workspaces integration
  (when (modulep! :ui workspaces)
    (add-hook 'persp-activated-functions #'+eshell-switch-workspace-fn)
    (add-hook 'persp-before-switch-functions #'+eshell-save-workspace-fn))

  ;; UI enhancements
  (add-hook! 'eshell-mode-hook
    (defun +eshell-enable-text-wrapping-h ()
      (visual-line-mode +1)
      (set-display-table-slot standard-display-table 0 ?\ )))

  (add-hook 'eshell-mode-hook #'mode-line-invisible-mode)
  (add-hook 'eshell-mode-hook #'doom-disable-line-numbers-h)

  ;; Remove hscroll-margin in shells, otherwise you get jumpiness when the
  ;; cursor comes close to the left/right edges of the window.
  (setq-hook! 'eshell-mode-hook hscroll-margin 0)

  ;; Recognize prompts as Imenu entries.
  (setq-hook! 'eshell-mode-hook
    imenu-generic-expression
    `((,(propertize "λ" 'face 'eshell-prompt)
       ,(concat eshell-prompt-regexp "\\(.*\\)") 1)))

  ;; Don't auto-write our aliases! Let us manage our own `eshell-aliases-file'
  ;; or configure `+eshell-aliases' via elisp.
  (advice-add #'eshell-write-aliases-list :override #'ignore)

  (add-to-list 'eshell-modules-list 'eshell-tramp)

  ;; Visual commands require a proper terminal. Eshell can't handle that, so
  ;; it delegates these commands to a term buffer.
  (after! em-term
    (dolist (cmd '("tmux" "htop" "vim" "nvim" "ncmpcpp"))
      (add-to-list 'eshell-visual-commands cmd)))

  (after! em-alias
    (setq +eshell--default-aliases eshell-command-aliases-list
          eshell-command-aliases-list
          (append eshell-command-aliases-list
                  +eshell-aliases))))


(after! esh-mode
  (map! :map eshell-mode-map
        :n  "RET"    #'+eshell/goto-end-of-prompt
        :n  [return] #'+eshell/goto-end-of-prompt
        :ni "C-j"    #'eshell-next-matching-input-from-input
        :ni "C-k"    #'eshell-previous-matching-input-from-input
        :ig "C-d"    #'+eshell/quit-or-delete-char
        :i  "C-c h"  #'evil-window-left
        :i  "C-c j"  #'evil-window-down
        :i  "C-c k"  #'evil-window-up
        :i  "C-c l"  #'evil-window-right
        "C-s"   #'+eshell/search-history
        ;; Emacs bindings
        "C-e"   #'end-of-line
        ;; Tmux-esque prefix keybinds
        "C-c s" #'+eshell/split-below
        "C-c v" #'+eshell/split-right
        "C-c x" #'+eshell/kill-and-close
        [remap split-window-below]  #'+eshell/split-below
        [remap split-window-right]  #'+eshell/split-right
        [remap doom/backward-to-bol-or-indent] #'eshell-bol
        [remap doom/backward-kill-to-bol-and-indent] #'eshell-kill-input
        [remap evil-delete-back-to-indentation] #'eshell-kill-input
        [remap evil-window-split]   #'+eshell/split-below
        [remap evil-window-vsplit]  #'+eshell/split-right
        ;; To emulate terminal keybinds
        "C-l"   (cmd! (eshell/clear-scrollback) (eshell-emit-prompt))
        (:localleader
         "b" #'eshell-insert-buffer-name
         "e" #'eshell-insert-envvar
         "s" #'+eshell/search-history)))


(use-package! eshell-up
  :commands eshell-up eshell-up-peek)


(use-package! eshell-z
  :after eshell
  :config
  ;; Use zsh's db if it exists, otherwise, store it in `doom-cache-dir'
  (unless (file-exists-p eshell-z-freq-dir-hash-table-file-name)
    (setq eshell-z-freq-dir-hash-table-file-name
          (expand-file-name "z" eshell-directory-name))))


(use-package! esh-help
  :after eshell
  :config
  (setup-esh-help-eldoc)
  ;; HACK: Fixes tom-tan/esh-help#7.
  (defadvice! +eshell-esh-help-eldoc-man-minibuffer-string-a (cmd)
    "Return minibuffer help string for the shell command CMD.
Return nil if there is none."
    :override #'esh-help-eldoc-man-minibuffer-string
    (if-let* ((cache-result (gethash cmd esh-help-man-cache)))
        (unless (eql 'none cache-result)
          cache-result)
      (let ((str (split-string (esh-help-man-string cmd) "\n")))
        (if (equal (concat "No manual entry for " cmd) (car str))
            (ignore (puthash cmd 'none esh-help-man-cache))
          (puthash
           cmd (when-let* ((str (seq-drop-while (fn! (not (string-match-p "^SYNOPSIS$" %))) str))
                           (str (nth 1 str)))
                 (substring str (string-match-p "[^\s\t]" str)))
           esh-help-man-cache))))))


(use-package! eshell-did-you-mean
  :after esh-mode ; Specifically esh-mode, not eshell
  :config (eshell-did-you-mean-setup)

  ;; HACK: `pcomplete-completions' returns a function, but
  ;;   `eshell-did-you-mean--get-all-commands' unconditionally expects it to
  ;;   return a list of strings, causing wrong-type-arg errors in many cases.
  ;;   `all-completions' handles all these cases.
  (defadvice! +eshell--fix-eshell-did-you-mean-a (&rest _)
    :override #'eshell-did-you-mean--get-all-commands
    (unless eshell-did-you-mean--all-commands
      (setq eshell-did-you-mean--all-commands
            (all-completions "" (pcomplete-completions))))))


(use-package! eshell-syntax-highlighting
  :hook (eshell-mode . eshell-syntax-highlighting-mode)
  :config
  (defadvice! +eshell-filter-history-from-highlighting-a (&rest _)
    "Selectively inhibit `eshell-syntax-highlighting-mode'.
So that mathces from history show up with highlighting."
    :before-until #'eshell-syntax-highlighting--enable-highlighting
    (memq this-command '(eshell-previous-matching-input-from-input
                         eshell-next-matching-input-from-input)))

  (defun +eshell-syntax-highlight-maybe-h ()
    "Hook added to `pre-command-hook' to restore syntax highlighting
when inhibited to show history matches."
    (when (and eshell-syntax-highlighting-mode
               (memq last-command '(eshell-previous-matching-input-from-input
                                    eshell-next-matching-input-from-input)))
      (eshell-syntax-highlighting--enable-highlighting)))

  (add-hook! 'eshell-syntax-highlighting-elisp-buffer-setup-hook
    (defun +eshell-syntax-highlighting-mode-h ()
      "Hook to enable `+eshell-syntax-highlight-maybe-h'."
      (if eshell-syntax-highlighting-mode
          (add-hook 'pre-command-hook #'+eshell-syntax-highlight-maybe-h nil t)
        (remove-hook 'pre-command-hook #'+eshell-syntax-highlight-maybe-h t))))

  (when (fboundp 'highlight-quoted-mode)
    (add-hook 'eshell-syntax-highlighting-elisp-buffer-setup-hook #'highlight-quoted-mode)))


(use-package! pcmpl-args
  :after eshell
  :config
  (dolist (cmd '("doom" "nix-shell"))
    (defalias (intern (concat "pcomplete/" cmd))
      #'pcmpl-args-pcomplete-on-help))
  (dolist (cmd '("fd" "rg" "exa" "emacsclient"))
    (defalias (intern (concat "pcomplete/" cmd))
      #'pcmpl-args-pcomplete-on-man)))
