;;; ui/workspaces/config.el -*- lexical-binding: t; -*-

;; `persp-mode' gives me workspaces, a workspace-restricted `buffer-list', and
;; file-based session persistence. I used workgroups2 before this, but abandoned
;; it because it was unstable and slow; `persp-mode' is neither (and still
;; maintained).
;;
;; NOTE: persp-mode requires `workgroups' for file persistence in Emacs 24.4.

(defvar +workspaces-main "main"
  "The name of the primary and initial workspace, which cannot be deleted.")

(defvar +workspaces-switch-project-function #'doom-project-find-file
  "The function to run after `projectile-switch-project' or
`counsel-projectile-switch-project'. This function must take one argument: the
new project directory.")

(defvar +workspaces-on-switch-project-behavior 'non-empty
  "Controls the behavior of workspaces when switching to a new project.

Can be one of the following:

t           Always create a new workspace for the project
'non-empty  Only create a new workspace if the current one already has buffers
            associated with it.
nil         Never create a new workspace on project switch.")

;; FIXME: Actually use this for wconf bookmark system
(defvar +workspaces-data-file "_workspaces"
  "The basename of the file to store single workspace perspectives. Will be
stored in `persp-save-dir'.")

(defvar +workspace--old-uniquify-style nil)


;;
;; Packages

(use-package! persp-mode
  :unless noninteractive
  :commands persp-switch-to-buffer
  :hook (doom-init-ui . persp-mode)
  :config
  (setq persp-autokill-buffer-on-remove 'kill-weak
        persp-reset-windows-on-nil-window-conf nil
        persp-nil-hidden t
        persp-auto-save-fname "autosave"
        persp-save-dir (file-name-concat doom-profile-data-dir "workspaces/")
        persp-set-last-persp-for-new-frames t
        persp-switch-to-added-buffer nil
        persp-kill-foreign-buffer-behaviour 'kill
        persp-remove-buffers-from-nil-persp-behaviour nil
        persp-auto-resume-time -1 ; Don't auto-load on startup
        persp-auto-save-opt (if noninteractive 0 1)) ; auto-save on kill

  ;; The default perspective persp-mode creates is special and doesn't represent
  ;; a real persp object, so buffers can't really be assigned to it, among other
  ;; quirks, so I replace it with a "main" perspective.
  (add-hook! '(persp-mode-hook persp-after-load-state-functions)
    (defun +workspaces-ensure-no-nil-workspaces-h (&rest _)
      (when persp-mode
        (dolist (frame (frame-list))
          (when (string= (safe-persp-name (get-current-persp frame)) persp-nil-name)
            ;; Take extra steps to ensure no frame ends up in the nil perspective
            (persp-frame-switch (or (cadr (hash-table-keys *persp-hash*))
                                    +workspaces-main)
                                frame))))))

  (add-hook! 'persp-mode-hook
    (defun +workspaces-init-first-workspace-h (&rest _)
      "Ensure a main workspace exists."
      (when persp-mode
        (let (persp-before-switch-functions)
          (unless (or (persp-get-by-name +workspaces-main)
                      ;; Start from 2 b/c persp-mode counts the nil workspace
                      (> (hash-table-count *persp-hash*) 2))
            (persp-add-new +workspaces-main))
          ;; HACK: Fix #319: the warnings buffer gets swallowed when creating
          ;;   `+workspaces-main', so display it ourselves, if it exists.
          (when-let* ((warnings (get-buffer "*Warnings*")))
            (unless (get-buffer-window warnings)
              (save-excursion
                (display-buffer-in-side-window
                 warnings '((window-height . shrink-window-if-larger-than-buffer)))))))))
    (defun +workspaces-init-persp-mode-h ()
      (cond (persp-mode
             ;; `uniquify' breaks persp-mode. It renames old buffers, which
             ;; causes errors when switching between perspective (their buffers
             ;; are serialized by name and persp-mode expects them to have the
             ;; same name when restored).
             (when uniquify-buffer-name-style
               (setq +workspace--old-uniquify-style uniquify-buffer-name-style))
             (setq uniquify-buffer-name-style nil)
             ;; Ensure `persp-kill-buffer-query-function' is last
             (remove-hook 'kill-buffer-query-functions #'persp-kill-buffer-query-function)
             (add-hook 'kill-buffer-query-functions #'persp-kill-buffer-query-function t)
             ;; Restrict buffer list to workspace
             (advice-add #'doom-buffer-list :override #'+workspace-buffer-list))
            (t
             (when +workspace--old-uniquify-style
               (setq uniquify-buffer-name-style +workspace--old-uniquify-style))
             (advice-remove #'doom-buffer-list #'+workspace-buffer-list)))))

  ;; Per-workspace `winner-mode' history
  (add-to-list 'window-persistent-parameters '(winner-ring . t))

  (add-hook! 'persp-before-deactivate-functions
    (defun +workspaces-save-winner-data-h (&rest _)
      (when (and (bound-and-true-p winner-mode)
                 (get-current-persp))
        (set-persp-parameter
         'winner-ring (list winner-currents
                            winner-ring-alist
                            winner-pending-undo-ring)))))

  (add-hook! 'persp-activated-functions
    (defun +workspaces-load-winner-data-h (&rest _)
      (when (bound-and-true-p winner-mode)
        (cl-destructuring-bind
            (currents alist pending-undo-ring)
            (or (persp-parameter 'winner-ring) (list nil nil nil))
          (setq winner-undo-frame nil
                winner-currents currents
                winner-ring-alist alist
                winner-pending-undo-ring pending-undo-ring)))))

  ;;;; Registering buffers to perspectives
  (add-hook! 'doom-switch-buffer-hook
    (defun +workspaces-add-current-buffer-h ()
      "Add current buffer to focused perspective."
      (or (not persp-mode)
          (persp-buffer-filtered-out-p
           (or (buffer-base-buffer (current-buffer))
               (current-buffer))
           persp-add-buffer-on-after-change-major-mode-filter-functions)
          (persp-add-buffer (current-buffer) (get-current-persp) nil nil))))

  (add-hook 'persp-add-buffer-on-after-change-major-mode-filter-functions
            #'doom-unreal-buffer-p)

  (defadvice! +workspaces--evil-alternate-buffer-a (&optional window)
    "Make `evil-alternate-buffer' ignore buffers outside the current workspace."
    :override #'evil-alternate-buffer
    (let* ((prev-buffers
            (if persp-mode
                (cl-remove-if-not #'persp-contain-buffer-p (window-prev-buffers)
                                  :key #'car)
              (window-prev-buffers)))
           (head (car prev-buffers)))
      (if (eq (car head) (window-buffer window))
          (cadr prev-buffers)
        head)))

  ;; HACK: Fixes #4196, #1525: selecting deleted buffer error when quitting
  ;;   Emacs or on some buffer listing ops.
  (defadvice! +workspaces-remove-dead-buffers-a (persp)
    :before #'persp-buffers-to-savelist
    (when (perspective-p persp)
      ;; HACK: Can't use `persp-buffers' because of a race condition with its gv
      ;;   getter/setter not being defined in time.
      (setf (aref persp 2)
            (cl-delete-if-not #'persp-get-buffer-or-null (persp-buffers persp)))))

  ;; Delete the current workspace if closing the last open window
  (define-key! persp-mode-map
    [remap delete-window] #'+workspace/close-window-or-workspace
    [remap evil-window-delete] #'+workspace/close-window-or-workspace)

  ;; Per-frame workspaces
  (setq persp-init-frame-behaviour t
        persp-init-new-frame-behaviour-override nil
        persp-interactive-init-frame-behaviour-override #'+workspaces-associate-frame-fn
        persp-emacsclient-init-frame-behaviour-override #'+workspaces-associate-frame-fn)
  (add-hook 'delete-frame-functions #'+workspaces-delete-associated-workspace-h)
  (add-hook 'server-done-hook #'+workspaces-delete-associated-workspace-h)

  ;; Per-project workspaces, but reuse current workspace if empty
  ;; REVIEW: Remove when ivy module is removed
  (setq projectile-switch-project-action #'+workspaces-switch-to-project-h
        counsel-projectile-switch-project-action
        '(1 ("o" +workspaces-switch-to-project-h "open project in new workspace")
            ("O" counsel-projectile-switch-project-action "jump to a project buffer or file")
            ("f" counsel-projectile-switch-project-action-find-file "jump to a project file")
            ("d" counsel-projectile-switch-project-action-find-dir "jump to a project directory")
            ("D" counsel-projectile-switch-project-action-dired "open project in dired")
            ("b" counsel-projectile-switch-project-action-switch-to-buffer "jump to a project buffer")
            ("m" counsel-projectile-switch-project-action-find-file-manually "find file manually from project root")
            ("w" counsel-projectile-switch-project-action-save-all-buffers "save all project buffers")
            ("k" counsel-projectile-switch-project-action-kill-buffers "kill all project buffers")
            ("r" counsel-projectile-switch-project-action-remove-known-project "remove project from known projects")
            ("c" counsel-projectile-switch-project-action-compile "run project compilation command")
            ("C" counsel-projectile-switch-project-action-configure "run project configure command")
            ("e" counsel-projectile-switch-project-action-edit-dir-locals "edit project dir-locals")
            ("v" counsel-projectile-switch-project-action-vc "open project in vc-dir / magit / monky")
            ("s" (lambda (project)
                   (let ((projectile-switch-project-action
                          (lambda () (call-interactively #'+ivy/project-search))))
                     (counsel-projectile-switch-project-by-name project))) "search project")
            ("xs" counsel-projectile-switch-project-action-run-shell "invoke shell from project root")
            ("xe" counsel-projectile-switch-project-action-run-eshell "invoke eshell from project root")
            ("xt" counsel-projectile-switch-project-action-run-term "invoke term from project root")
            ("X" counsel-projectile-switch-project-action-org-capture "org-capture into project")))

  (when (modulep! :completion helm)
    (after! helm-projectile
      (setcar helm-source-projectile-projects-actions
              '("Switch to Project" . +workspaces-switch-to-project-h))))

  ;; Don't bother auto-saving the session if no real buffers are open.
  (advice-add #'persp-asave-on-exit :around #'+workspaces-autosave-real-buffers-a)

  ;; Fix #1973: visual selection surviving workspace changes
  ;; `persp-before-deactivate-functions' calls its hooks with three arguments,
  ;; but `deactivate-mark' only accepts an optional FORCE argument, so passing
  ;; it directly throws (wrong-number-of-arguments deactivate-mark 3). Wrap it.
  (add-hook! 'persp-before-deactivate-functions
    (defun +workspaces-deactivate-mark-h (&rest _)
      (deactivate-mark)))

  ;; Fix #1017: stop session persistence from restoring broken childframes.
  (add-hook 'persp-after-load-state-functions #'doom-kill-childframes-h)

  ;; Don't try to persist dead/remote buffers. They cause errors.
  (add-hook! 'persp-filter-save-buffers-functions
    (defun +workspaces-dead-buffer-p (buf)
      ;; Fix #1525: Ignore dead buffers in PERSP's buffer list
      (not (buffer-live-p buf)))
    (defun +workspaces-remote-buffer-p (buf)
      ;; And don't save TRAMP buffers; they're super slow to restore
      (let ((dir (buffer-local-value 'default-directory buf)))
        (ignore-errors (file-remote-p dir)))))

  ;; Otherwise, buffers opened via bookmarks aren't treated as "real" and are
  ;; excluded from the buffer list.
  (add-hook 'bookmark-after-jump-hook #'+workspaces-add-current-buffer-h)

  ;; `eshell'
  (persp-def-buffer-save/load
   :mode 'eshell-mode :tag-symbol 'def-eshell-buffer
   :save-vars '(major-mode default-directory))
  ;; `compile'
  (persp-def-buffer-save/load
   :mode 'compilation-mode :tag-symbol 'def-compilation-buffer
   :save-vars '(major-mode default-directory compilation-directory
                compilation-environment compilation-arguments))
  ;; `magit'
  (persp-def-buffer-save/load
   :mode 'magit-status-mode :tag-symbol 'def-magit-status-buffer
   :save-vars '(default-directory)
   :load-function (lambda (savelist &rest _)
                    (magit-status (alist-get 'default-directory (caddr savelist)))))

  ;; `tab-bar'
  (add-hook! 'tab-bar-mode-hook
    (defun +workspaces-set-up-tab-bar-integration-h ()
      (add-hook 'persp-before-deactivate-functions #'+workspaces-save-tab-bar-data-h)
      (add-hook 'persp-activated-functions #'+workspaces-load-tab-bar-data-h)
      ;; Load and save configurations for tab-bar.
      (add-hook 'persp-before-save-state-to-file-functions #'+workspaces-save-tab-bar-data-to-file-h)
      (+workspaces-load-tab-bar-data-from-file-h))))
