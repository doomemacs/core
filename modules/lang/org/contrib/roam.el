;;; lang/org/contrib/roam.el -*- lexical-binding: t; -*-
;;;###if (or (modulep! +roam) (modulep! +roam2))

(defvar +org-roam-auto-backlinks-buffer nil
  "If non-nil, open and close the org-roam backlinks buffer automatically.

This ensures the backlinks buffer is always present so long as an org roam file
is visible. Once they are all closed or killed, the backlinks buffer will be
closed.")

(defvar +org-roam-link-to-org-use-id 'create-if-interactive
  "`org-roam-directory' local value for `org-id-link-to-org-use-id'.
It's not recommended to set this to nil in order for other parts
of org-mode to properly utilize ID links.")


;;
;;; Packages

(use-package! org-roam
  :hook (org-load . +org-init-roam-h)
  :preface
  ;; Set this to nil so we can later detect if the user has set custom values
  ;; for these variables. If not, default values will be set in the :config
  ;; section.
  (defvar org-roam-directory nil)

  :init
  (doom-load-packages-incrementally
   '(ansi-color compat rx seq magit-section emacsql))

  :config
  (defun +org-init-roam-h ()
    "Setup `org-roam' but don't immediately initialize its database.
Instead, initialize it when it will be actually needed."
    (letf! ((#'org-roam-db-sync #'ignore))
      (org-roam-db-autosync-enable)))

  (defadvice! +org-roam-try-init-db-a (&rest _)
    "Try to initialize org-roam database at the last possible safe moment.
In case of failure, fail gracefully."
    :before #'org-roam-db-query
    (message "Initializing org-roam database...")
    (advice-remove 'org-roam-db-query #'+org-roam-try-init-db-a)
    (org-roam-db-sync))

  (defadvice! +org-roam-node-insert-after-point-a (fn &rest args)
    "If in evil normal mode and cursor is on a whitespace character, insert the
link after the whitespace rather than before. If at EOL, add a space before
inserting the link."
    :around #'org-roam-node-insert
    (if (and (bound-and-true-p evil-local-mode)
             (not (evil-insert-state-p))
             (not (evil-visual-state-p))
             (or (looking-at-p "[[:blank:]]")
                 (evil-eolp)))
        (evil-with-state 'insert
          (unless (eolp) (forward-char))
          (if (evil-eolp) (insert " "))
          (apply fn args))
      (apply fn args)))

  (setq org-roam-directory
        (thread-first (or org-roam-directory "roam")
          (expand-file-name org-directory)
          (file-truename)
          (file-name-as-directory))
        org-roam-node-display-template
        (format "${doom-hierarchy:*} %s %s"
                (propertize "${doom-type:12}" 'face 'font-lock-keyword-face)
                (propertize "${doom-tags:42}" 'face '(:inherit org-tag :box nil)))
        org-roam-completion-everywhere t
        ;; Reverse the default to favor faster searchers over slower ones.
        org-roam-list-files-commands '(fd fdfind rg find))

  (add-to-list 'org-roam-node-template-prefixes '("doom-tags" . "#"))
  (add-to-list 'org-roam-node-template-prefixes '("doom-type" . "@"))

  ;; REVIEW: Remove when addressed upstream. See org-roam/org-roam#2066.
  (defadvice! +org--roam-fix-completion-width-for-vertico-a (fn &rest args)
    "Fixes completion candidate width for vertico users."
    :around #'org-roam-node-read--to-candidate
    (letf! (defun org-roam-node--format-entry (template node &optional width)
             (funcall org-roam-node--format-entry template node
                      (if (bound-and-true-p vertico-mode)
                          (if (minibufferp)
                              (window-width)
                            (1- (frame-width)))
                        width)))
      (apply fn args)))

  (setq-hook! 'org-roam-find-file-hook
    org-id-link-to-org-use-id +org-roam-link-to-org-use-id)

  ;; Normally, the org-roam buffer won't open until `org-roam-buffer-toggle' is
  ;; explicitly called. If `+org-roam-auto-backlinks-buffer' is non-nil, the
  ;; org-roam buffer will automatically open whenever a file in
  ;; `org-roam-directory' is visited and closed when no org-roam buffers remain.
  (add-hook! 'org-roam-find-file-hook :append
    (defun +org-roam-enable-auto-backlinks-buffer-h ()
      (add-hook 'doom-switch-buffer-hook #'+org-roam-manage-backlinks-buffer-h)))

  (set-popup-rules!
    `((,(regexp-quote org-roam-buffer) ; persistent org-roam buffer
       :side right :width 0.33 :height 0.5 :ttl nil :modeline nil :quit nil :slot 1)
      ("^\\*org-roam: " ; node dedicated org-roam buffer
       :side right :width 0.33 :height 0.5 :ttl nil :modeline nil :quit nil :slot 2)))

  ;; Soft-wrap lines in the backlinks buffer
  (add-hook 'org-roam-mode-hook #'visual-line-mode)

  ;; Use a 'roam:X' link's description if X is empty.
  ;; REVIEW: PR this upstream?
  (advice-add #'org-roam-link-follow-link :filter-args #'org-roam-link-follow-link-with-description-a)
  (advice-add #'org-roam-link-replace-at-point :override #'org-roam-link-replace-at-point-a)

  (map! :map org-mode-map
        :localleader
        :prefix ("m" . "org-roam")
        "D" #'org-roam-demote-entire-buffer
        "f" #'org-roam-node-find
        "F" #'org-roam-ref-find
        "g" #'org-roam-graph
        "i" #'org-roam-node-insert
        "I" #'org-id-get-create
        "m" #'org-roam-buffer-toggle
        "M" #'org-roam-buffer-display-dedicated
        "n" #'org-roam-capture
        "r" #'org-roam-refile
        "R" #'org-roam-link-replace-all
        (:prefix ("d" . "by date")
         :desc "Goto previous note" "b" #'org-roam-dailies-goto-previous-note
         :desc "Goto date"          "d" #'org-roam-dailies-goto-date
         :desc "Capture date"       "D" #'org-roam-dailies-capture-date
         :desc "Goto next note"     "f" #'org-roam-dailies-goto-next-note
         :desc "Goto tomorrow"      "m" #'org-roam-dailies-goto-tomorrow
         :desc "Capture tomorrow"   "M" #'org-roam-dailies-capture-tomorrow
         :desc "Capture today"      "n" #'org-roam-dailies-capture-today
         :desc "Goto today"         "t" #'org-roam-dailies-goto-today
         :desc "Capture today"      "T" #'org-roam-dailies-capture-today
         :desc "Goto yesterday"     "y" #'org-roam-dailies-goto-yesterday
         :desc "Capture yesterday"  "Y" #'org-roam-dailies-capture-yesterday
         :desc "Find directory"     "-" #'org-roam-dailies-find-directory)
        (:prefix ("o" . "node properties")
         "a" #'org-roam-alias-add
         "A" #'org-roam-alias-remove
         "t" #'org-roam-tag-add
         "T" #'org-roam-tag-remove
         "r" #'org-roam-ref-add
         "R" #'org-roam-ref-remove))

  (when (modulep! :editor evil +everywhere)
    (add-hook! 'org-roam-mode-hook
      (defun +org-roam-detach-magit-section-mode-map-h ()
        "Detach `magit-section-mode-map' from `org-roam-mode-map'.
Inheriting its keymaps introduces a lot of conflicts in
`org-roam-mode' based buffers, where Evil and leader keybindings
will become completely overridden. This is because `magit-section'
uses 'keymap text-property to attach section-unique keymaps, which
has a higher level of precedence than `emulation-mode-map-alists'.

Note: We do this each time through the hook, because otherwise
sections seems to ignore the detachment."
        (set-keymap-parent org-roam-mode-map nil)))

    (map! :map org-roam-mode-map
          :nv "]"       #'magit-section-forward-sibling
          :nv "["       #'magit-section-backward-sibling
          :nv "gj"      #'magit-section-forward-sibling
          :nv "gk"      #'magit-section-backward-sibling
          :nv "gr"      #'revert-buffer
          :nv "gR"      #'revert-buffer
          :nv "z1"      #'magit-section-show-level-1
          :nv "z2"      #'magit-section-show-level-2
          :nv "z3"      #'magit-section-show-level-3
          :nv "z4"      #'magit-section-show-level-4
          :nv "za"      #'magit-section-toggle
          :nv "zc"      #'magit-section-hide
          :nv "zC"      #'magit-section-hide-children
          :nv "zo"      #'magit-section-show
          :nv "zO"      #'magit-section-show-children
          :nv "zm"      #'magit-section-show-level-2-all
          :nv "zr"      #'magit-section-show-level-4-all
          :nv "C-j"     #'magit-section-forward
          :nv "C-k"     #'magit-section-backward
          :g  "M-p"     #'magit-section-backward-sibling
          :g  "M-n"     #'magit-section-forward-sibling
          :g  [tab]     #'magit-section-toggle
          :g  [C-tab]   #'magit-section-cycle
          :g  [backtab] #'magit-section-cycle-global)))


;; Since the org module lazy loads org-protocol (waits until an org URL is
;; detected), we can safely chain `org-roam-protocol' to it.
(use-package! org-roam-protocol
  :after org-protocol)
