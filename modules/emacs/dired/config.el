;;; emacs/dired/config.el -*- lexical-binding: t; -*-

;;
;;; Packages

(use-package! dired
  :commands dired-jump
  :init
  (setq dired-dwim-target t  ; suggest a target for moving/copying intelligently
        ;; don't prompt to revert, just do it
        dired-auto-revert-buffer #'dired-buffer-stale-p
        ;; Always copy/delete recursively
        dired-recursive-copies  'always
        dired-recursive-deletes 'top
        ;; Ask whether destination dirs should get created when copying/removing files.
        dired-create-destination-dirs 'ask
        ;; Where to store image caches
        image-dired-dir (file-name-concat doom-profile-cache-dir "image-dired/")
        image-dired-db-file (concat image-dired-dir "db.el")
        image-dired-gallery-dir (concat image-dired-dir "gallery/")
        image-dired-temp-image-file (concat image-dired-dir "temp-image")
        image-dired-temp-rotate-image-file (concat image-dired-dir "temp-rotate-image")
        ;; Screens are larger nowadays, we can afford slightly larger thumbnails
        image-dired-thumb-size 150)
  :config
  (set-popup-rule! "^\\*image-dired"
    :slot 20 :size 0.8 :select t :quit nil :ttl 0)
  (set-evil-initial-state! 'image-dired-display-image-mode 'emacs)

  (let ((args (list "-ahl" "-v" "--group-directories-first")))
    (when (featurep :system 'bsd)
      ;; Use GNU ls as `gls' from `coreutils' if available. Add `(setq
      ;; dired-use-ls-dired nil)' to your config to suppress the Dired warning
      ;; when not using GNU ls.
      (if-let* ((gls (executable-find "gls")))
          (setq insert-directory-program gls)
        ;; BSD ls doesn't support -v or --group-directories-first
        (setq args (list (car args)))))
    (setq dired-listing-switches (string-join args " "))

    (add-hook! 'dired-mode-hook
      (defun +dired-disable-gnu-ls-flags-maybe-h ()
        "Remove extraneous switches from `dired-actual-switches' when it's
uncertain that they are supported (e.g. over TRAMP or on Windows).

Fixes #1703: dired over TRAMP displays a blank screen.
Fixes #3939: unsortable dired entries on Windows."
        (when (or (file-remote-p default-directory)
                  (and (boundp 'ls-lisp-use-insert-directory-program)
                       (not ls-lisp-use-insert-directory-program)))
          (setq-local dired-actual-switches (car args))))))

  ;; Don't complain about this command being disabled when we use it
  (put 'dired-find-alternate-file 'disabled nil)

  (defadvice! +dired--no-revert-in-virtual-buffers-a (&rest args)
    "Don't auto-revert in dired-virtual buffers (see `dired-virtual-revert')."
    :before-while #'dired-buffer-stale-p
    (not (eq revert-buffer-function #'dired-virtual-revert)))

  ;; To be consistent with vertico/ivy/helm+wgrep integration
  (define-key dired-mode-map (kbd "C-c C-e") #'wdired-change-to-wdired-mode)

  ;; On ESC, abort `wdired-mode' (will prompt)
  (add-hook! 'doom-escape-hook
    (defun +dired-wdired-exit-h ()
      (when (eq major-mode 'wdired-mode)
        (wdired-exit)
        t))))


(use-package! dirvish
  :commands (dirvish-dired-noselect-a dirvish--find-entry)
  :general (dired-mode-map "C-c C-r" #'dirvish-rsync)
  :init
  (setq dirvish-cache-dir (file-name-concat doom-cache-dir "dirvish/"))
  ;; HACK: ...
  (advice-add #'dired--find-file :override #'dirvish--find-entry)
  (advice-add #'dired-noselect :around #'dirvish-dired-noselect-a)
  :config
  (dirvish-override-dired-mode)
  (set-popup-rule! "^ ?\\*\\(?:[Dd]irvish\\|SIDE :: \\).*" :ignore t)

  ;; HACK: `dirvish-pre-redisplay-h' is called via `pre-redisplay-functions'
  ;;   for every window that needs redisplay, but it unconditionally calls
  ;;   `dirvish--redisplay'. When dirvish is open in multiple frames, this
  ;;   creates a feedback loop: frame A's redisplay triggers frame B's, and
  ;;   vice versa, causing visible flickering. Guard it so it only fires for
  ;;   the selected window in its frame. See alexluigit/dirvish#353.
  ;; REVIEW: PR this upstream!
  (defadvice! +dired--debounce-dirvish-redisplay-a (fn window)
    :around #'dirvish-pre-redisplay-h
    (when (eq (frame-selected-window) window)
      (funcall fn window)))

  ;; Fixes #8038. This setting is for folks who expect to be able to switch back
  ;; to dired buffers where the file is opened from. Doom's cleanup hook
  ;; (`+dired--cleanup-dirvish-h') handles killing sessions on project/workspace
  ;; switches, so `t' is safe here.
  (setq dirvish-reuse-session t)

  (if (modulep! +dirvish)
      (setq dirvish-attributes '(file-size)
            dirvish-mode-line-format
            '(:left (sort file-time symlink) :right (omit yank index)))
    (setq dirvish-attributes nil
          dirvish-use-header-line nil
          dirvish-use-mode-line nil))

  ;; Match the height of `doom-modeline', if it's being used.
  ;; TODO: Make this respect user changes to these variables.
  (when (modulep! :ui modeline)
    (add-hook! 'dired-mode-hook
      (defun +dired-update-mode-line-height-h ()
        (when-let* ((height (bound-and-true-p doom-modeline-height)))
          (setq dirvish-mode-line-height height
                dirvish-header-line-height height)))))

  (when (modulep! :ui vc-gutter)
    ;; The vc-gutter module uses `diff-hl-dired-mode' + `diff-hl-margin-mode'
    ;; for diffs in dirvish buffers. `vc-state' uses overlays, so they won't be
    ;; visible in the terminal.
    (when (or (daemonp) (display-graphic-p))
      (push 'vc-state dirvish-attributes)))

  (when (modulep! +icons)
    (setq dirvish-subtree-always-show-state t)
    (cl-callf append dirvish-attributes '(nerd-icons subtree-state)))

  (setq dirvish-hide-details '(dirvish dirvish-side)
        dirvish-hide-cursor '(dirvish dirvish-side))

  (when (modulep! :ui tabs)
    (after! centaur-tabs
      (add-hook 'dired-mode-hook #'centaur-tabs-local-mode)
      (add-hook 'dirvish-directory-view-mode-hook #'centaur-tabs-local-mode)))

  ;; TODO: Needs more polished keybinds for non-Evil users
  (map! :map dirvish-mode-map
        :n  "?"   #'dirvish-dispatch
        :n  "q"   #'dirvish-quit
        :n  "b"   #'dirvish-quick-access
        :ng "f"   #'dirvish-file-info-menu
        :n  "p"   #'dirvish-yank
        :ng "S"   #'dirvish-quicksort
        :n  "F"   #'dirvish-layout-toggle
        :n  "z"   #'dirvish-history-jump
        :n  "gh"  #'dirvish-subtree-up
        :n  "gl"  #'dirvish-subtree-toggle
        :n  "h"   #'dired-up-directory
        :n  "l"   #'dired-find-file
        :gm [left]  #'dired-up-directory
        :gm [right] #'dired-find-file
        :m  "[h"  #'dirvish-history-go-backward
        :m  "]h"  #'dirvish-history-go-forward
        :m  "[e"  #'dirvish-emerge-next-group
        :m  "]e"  #'dirvish-emerge-previous-group
        :n  "TAB" #'dirvish-subtree-toggle
        :ng "M-b" #'dirvish-history-go-backward
        :ng "M-f" #'dirvish-history-go-forward
        :ng "M-n" #'dirvish-narrow
        :ng "M-m" #'dirvish-mark-menu
        :ng "M-s" #'dirvish-setup-menu
        :ng "M-e" #'dirvish-emerge-menu
        (:prefix ("y" . "yank")
         :n "l"   #'dirvish-copy-file-true-path
         :n "n"   #'dirvish-copy-file-name
         :n "p"   #'dirvish-copy-file-path
         :n "r"   #'dirvish-copy-remote-path
         :n "y"   #'dired-do-copy)
        (:prefix ("s" . "symlinks")
         :n "s"   #'dirvish-symlink
         :n "S"   #'dirvish-relative-symlink
         :n "h"   #'dirvish-hardlink))

  ;; HACK: Kill Dirvish session before switching projects/workspaces, otherwise
  ;;   it errors out on trying to delete/change dedicated windows.
  (add-hook! '(persp-before-kill-functions
               persp-before-switch-functions
               projectile-before-switch-project-hook)
    (defun +dired--cleanup-dirvish-h (&rest _)
      (when-let* ((dv (cl-loop for w in (window-list)
                               if (window-dedicated-p w)
                               if (with-current-buffer (window-buffer w) (dirvish-curr))
                               return it)))
        (let (dirvish-reuse-session)
          (with-selected-window (dv-root-window dv)
            (dirvish-quit)))))))


(use-package! diredfl
  :hook (dired-mode . diredfl-mode)
  :hook (dirvish-directory-view-mode . diredfl-mode))


(use-package! dired-x
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-omit-verbose nil
        dired-omit-files
        (concat dired-omit-files
                "\\|^\\.DS_Store\\'"
                "\\|^flycheck_.*"
                "\\|^\\.project\\(?:ile\\)?\\'"
                "\\|^\\.\\(?:svn\\|git\\)\\'"
                "\\|^\\.ccls-cache\\'"
                "\\|\\(?:\\.js\\)?\\.meta\\'"
                "\\|\\.\\(?:elc\\|o\\|pyo\\|swp\\|class\\)\\'"))
  ;; Disable the prompt about whether I want to kill the Dired buffer for a
  ;; deleted directory. Of course I do!
  (setq dired-clean-confirm-killing-deleted-buffers nil)
  ;; Let OS decide how to open certain files
  (when-let* ((cmd (cond ((featurep :system 'macos) "open")
                         ((featurep :system 'linux) "xdg-open")
                         ((featurep :system 'windows) "start"))))
    (setq dired-guess-shell-alist-user
          `(("\\.\\(?:docx\\|pdf\\|djvu\\|eps\\)\\'" ,cmd)
            ("\\.\\(?:jpe?g\\|png\\|gif\\|xpm\\)\\'" ,cmd)
            ("\\.\\(?:xcf\\)\\'" ,cmd)
            ("\\.csv\\'" ,cmd)
            ("\\.tex\\'" ,cmd)
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
            ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
            ("\\.html?\\'" ,cmd)
            ("\\.md\\'" ,cmd))))
  (map! :map dired-mode-map
        :localleader
        "h" #'dired-omit-mode))


(use-package! dired-aux
  :defer t
  :config
  (setq dired-create-destination-dirs 'ask
        dired-vc-rename-file t))
