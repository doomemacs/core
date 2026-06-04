;;; input/layout/+bepo.el -*- lexical-binding: t; -*-

(defvar +layout-bepo-cr-rotation-style 'ergodis
  "Modify this variable in your $DOOMDIR/init.el
Style of binding rotation for the cr keys.
If 'ergodis, then the module maps the old 'c' bindings to 'l' and the old 'r' to 'h', as
the 'change' function is used more often and 'l' is easier to reach than 'h' in bépo.

If 'strict, the module does a normal swap and 'c' bindings go to 'h', 'r' bindings go to 'l'.

In all cases, 'h' functions go to 'c' and 'l' ones go to 'r' so the navigation keys still feel vim-like.")

;; Highlight non breaking spaces as error in prog modes only
;; REVIEW: `nobreak-char-display' is defined in xdisp.c; will that work in non-X
;;   builds? From early observations in sway+pgtk, it does not.
(setq nobreak-char-display t)
(set-face-attribute 'nobreak-space nil :underline t)


;;
;;; Initializers

;; TODO: Separate each package into their own hook, so users can
;;   enable/disable/add their own per-package remappings.

(defun +layout-remap-keys-for-bepo-h ()
  (setq avy-keys '(?a ?u ?i ?e ?, ?c ?t ?s ?r ?n)
        lispy-avy-keys '(?a ?u ?i ?e ?, ?c ?t ?s ?r ?n ?m ?b ?é ?p ?o ?è ?v ?d ?l ?j ?z))

  ;; :ui window-select settings, ignoring +numbers flag for now
  (after! ace-window
    (setq aw-keys '(?a ?u ?i ?e ?, ?c ?t ?s ?r ?n)))
  (after! switch-window
    (setq switch-window-shortcut-style 'qwerty
          switch-window-qwerty-shortcuts '("a" "u" "i" "e" "," "c" "t" "s" "r")))

  (map! "C-é" 'evil-window-map)
  (map! :leader
        :desc "Window"                     "é"  evil-window-map
        (:when (modulep! :ui popup)
         :desc "Toggle last popup"         "#"  #'+popup/toggle)
        (:when (modulep! :ui workspaces)
         :desc "Switch buffer"             "«"  #'switch-to-buffer)
        :desc "Switch to last buffer"      "$"  #'evil-switch-to-windows-last-buffer
        (:when (modulep! :ui workspaces)
         (:prefix-map ("TAB" . "workspace")
          :desc "Switch to last workspace" "$"  #'+workspace/other
          :desc "Next workspace"           ")"  #'+workspace/switch-right
          :desc "Previous workspace"       "("  #'+workspace/switch-left))
        (:prefix-map ("b" . "buffer")
         :desc "Previous buffer"           "("  #'previous-buffer
         :desc "Next buffer"               ")"  #'next-buffer)
        (:prefix-map ("c" . "code")
         :desc "Jump to documentation"     "S"  #'+lookup/documentation)
        (:prefix-map ("g" . "git")
         (:when (modulep! :ui vc-gutter)
          :desc "Jump to next hunk"        ")"  #'+vc-gutter/next-hunk
          :desc "Jump to previous hunk"    "("  #'+vc-gutter/previous-hunk))
        (:prefix-map ("p" . "project")
         :desc "Browse other project"      "»"  #'doom/browse-in-other-project)))

(defun +layout-remap-evil-keys-for-bepo-h ()
  ;; "ts" would be a little too common for an evil escape sequence
  (setq evil-escape-key-sequence "gq")
  (setq evil-markdown-movement-bindings '((up . "s")
                                          (down . "t")
                                          (left . "c")
                                          (right . "r"))
        evil-org-movement-bindings '((up . "s")
                                     (down . "t")
                                     (left . "c")
                                     (right . "r")))
  (+layout-bepo-rotate-ts-bare-keymap '(read-expression-map))
  (+layout-bepo-rotate-bare-keymap '(evil-window-map) +layout-bepo-cr-rotation-style)
  (+layout-bepo-rotate-evil-keymap +layout-bepo-cr-rotation-style)
  ;; Remap the visual-mode-map bindings if necessary
  ;; See https://github.com/emacs-evil/evil/blob/7d00c23496c25a66f90ac7a6a354b1c7f9498162/evil-integration.el#L478-L501
  ;; Using +layout-bepo-rotate-keymaps is impossible because `evil-define-minor-mode-key' doesn't
  ;; provide an actual symbol to design the new keymap with, and instead stuff the keymap in
  ;; an auxiliary-auxiliary `minor-mode-map-alist'-like variable.
  (after! evil-integration
    (when evil-respect-visual-line-mode
      (map! :map visual-line-mode-map
            :m "t"  #'evil-next-visual-line
            ;; _Not_ remapping gj and gk because they aren't remapped
            ;; consistently across all Emacs.
            :m "s"  #'evil-previous-visual-line
            :m "È"  #'evil-beginning-of-visual-line
            :m "gÈ" #'evil-beginning-of-line
            :m "$"  #'evil-end-of-visual-line
            :m "g$" #'evil-end-of-line
            :m "V"  #'evil-visual-screen-line)))

  (map! :i "C-t" #'+default-newline
        (:when (modulep! :editor multiple-cursors)
         :prefix "gz"
         :nv "t"   #'evil-mc-make-cursor-move-next-line
         :nv "s"   #'evil-mc-make-cursor-move-prev-line
         ;; The old toggle mapping (t) is made available both on "T" for
         ;; mnemonics and "j" as a "classic" rotation
         :nv "T"   #'+multiple-cursors/evil-mc-toggle-cursors
         :nv "j"   #'+multiple-cursors/evil-mc-toggle-cursors)
        (:when (modulep! :ui popup)
         :n "C-$"  #'+popup/toggle
         :n "C-#"  #'+popup/raise))
  (after! treemacs
    (+layout-bepo-rotate-ts-bare-keymap '(evil-treemacs-state-map)))
  (after! (:or helm ivy vertico icomplete)
    (+layout-bepo-rotate-keymaps
     '(minibuffer-local-map
       minibuffer-local-ns-map
       minibuffer-local-completion-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       read-expression-map))
    (+layout-bepo-rotate-bare-keymap
     '(minibuffer-local-map
       minibuffer-local-ns-map
       minibuffer-local-completion-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       read-expression-map)
     +layout-bepo-cr-rotation-style))
  (after! ivy
    (+layout-bepo-rotate-bare-keymap '(ivy-minibuffer-map ivy-switch-buffer-map) +layout-bepo-cr-rotation-style)
    (+layout-bepo-rotate-keymaps '(ivy-minibuffer-map ivy-switch-buffer-map)))
  (after! swiper
    (map! :map swiper-map "C-s" nil))
  (after! helm
    (+layout-bepo-rotate-bare-keymap '(helm-map) +layout-bepo-cr-rotation-style)
    (+layout-bepo-rotate-keymaps '(helm-map)))
  (after! helm-rg
    (+layout-bepo-rotate-bare-keymap '(helm-rg-map) +layout-bepo-cr-rotation-style)
    (+layout-bepo-rotate-keymaps '(helm-rg-map)))
  (after! helm-files
    (+layout-bepo-rotate-bare-keymap '(helm-read-file-map) +layout-bepo-cr-rotation-style)
    (+layout-bepo-rotate-keymaps '(helm-read-file-map)))
  (after! company
    (+layout-bepo-rotate-bare-keymap '(company-active-map company-search-map) +layout-bepo-cr-rotation-style))
  (after! evil-snipe
    (+layout-bepo-rotate-keymaps
     '(evil-snipe-local-mode-map evil-snipe-override-local-mode-map)))
  (after! eshell
    (add-hook 'eshell-first-time-mode-hook (lambda () (+layout-bepo-rotate-keymaps '(eshell-mode-map))) 99))
  (after! lispyville
    ;; <> en direct
    (general-translate-key '(normal motion) 'lispyville-mode-map
      "«" "<"
      "»" ">"))
  (after! lsp-ui
    (+layout-bepo-rotate-ts-bare-keymap '(lsp-ui-peek-mode-map)))
  (after! org-capture
    (defadvice! doom-bepo--org-completing-read (&rest args)
      "Completing-read with SPACE being a normal character, and C-c mapping left alone."
      :override #'org-completing-read
      (let ((enable-recursive-minibuffers t)
            (minibuffer-local-completion-map
             (copy-keymap minibuffer-local-completion-map)))
        (define-key minibuffer-local-completion-map " " 'self-insert-command)
        (define-key minibuffer-local-completion-map "?" 'self-insert-command)
        (define-key minibuffer-local-completion-map
          (cond
           ((eq +layout-bepo-cr-rotation-style 'ergodis)
            (kbd "C-l !"))
           (t
            (kbd "C-h !")))
          'org-time-stamp-inactive)
        (apply #'completing-read args)))
    ;; Finalizing an Org-capture become `C-l C-c` (or `C-r C-c`) on top of `ZZ`
    (+layout-bepo-rotate-bare-keymap '(org-capture-mode-map) +layout-bepo-cr-rotation-style))
  (after! (evil org evil-org)
    ;; FIXME: This map! call is being interpreted before the
    ;;   map! call in (use-package! evil-org :config) in modules/lang/org/config.el
    ;;   Therefore, this map! needs to be reevaluated to have effect.
    ;;   Need to find a way to call the code below after the :config block
    ;;   in :lang org code

    ;; Direct access for "unimpaired" like improvements
    (map! :map evil-org-mode-map
          ;; evil-org-movement bindings having "c" and "r" means
          ;; C-r gets mapped to `org-shiftright' in normal and insert state.
          ;; C-c gets mapped to `org-shiftleft' in normal and insert state.
          :ni "C-r" nil
          :ni "C-c" nil
          :ni "C-»" #'org-shiftright
          :ni "C-«" #'org-shiftleft
          :m ")" nil
          :m "(" nil
          :m "]" #'evil-org-forward-sentence
          :m "[" #'evil-org-backward-sentence
          :m ")h" #'org-forward-heading-same-level
          :m "(h" #'org-backward-heading-same-level
          :m ")l" #'org-next-link
          :m "(l" #'org-previous-link
          :m ")c" #'org-babel-next-src-block
          :m "(c" #'org-babel-previous-src-block))
  (after! (evil org evil-org-agenda)
    (+layout-bepo-rotate-bare-keymap '(org-agenda-keymap) +layout-bepo-cr-rotation-style)
    (+layout-bepo-rotate-keymaps '(evil-org-agenda-mode-map)))
  (after! notmuch
    ;; Without this, "s" is mapped to `notmuch-search' and takes precedence over
    ;; the evil command to go up one line
    (map! :map notmuch-common-keymap :n "s" nil)
    (map! :map notmuch-common-keymap "s" nil))
  (after! (evil info)
    ;; Without this, "s" stays mapped to 'Info-search (in the "global"
    ;; `Info-mode-map') and takes precedence over the evil command to go up one
    ;; line (remapped in `Info-mode-normal-state-map').  Same for "t" that is
    ;; `Info-top-node' in the "global" `Info-mode-map'
    (map! :map Info-mode-map
          "s" nil
          "t" nil))

  (after! dirvish
    ;; Without this, "s" stays mapped to 'symlinks' prefix of dirvish (in the
    ;; 'dirvish' map, configured in (:emacs dired) module
    (map! :map dirvish-mode-map "s" nil)
    ;; Manual rotation of the gh/gl bindings
    (map! :map dirvish-mode-map
          :n "gh" nil
          :n "gl" nil
          :n "gc" '#dirvish-subtree-up
          :n "gr" '#dirvish-subtree-toggle)
    (if (eq +layout-bepo-cr-rotation-style 'ergodis)
        (map! :map dirvish-mode-map
              :n "gh" '#revert-buffer)
      (map! :map dirvish-mode-map
            :n "gl" '#revert-buffer))
    (+layout-bepo-rotate-keymaps '(dirvish-mode-map)))

  
  ;; Start of the Magit zone
  ;;
  ;; The magit zone needs to be special because evil-collection and magit and
  ;; this module don't fully agree on the order with which features, keymaps,
  ;; overriding keymaps, and evil-collection-setup-hook are run.
  ;;
  ;; This is _probably_ more complex than what it needs to be, but the
  ;; interactions between all packages are so hard to track that a
  ;; trial-and-error approach has been used to arrive at this result.
  (after! (evil magit-section)
    (+layout-bepo-rotate-ts-bare-keymap
     '(magit-section-mode-map)))
  (after! (evil magit-log)
    (+layout-bepo-rotate-keymaps
     '(magit-log-read-revs-map
       magit-log-mode-map
       ;; NOTE: magit-cherry-mode could be moved of magit-log anyday, be
       ;; careful
       magit-cherry-mode-map)))
  (after! (evil magit-reflog)
    (+layout-bepo-rotate-keymaps
     '(magit-reflog-mode-map)))
  (after! (evil magit-status)
    (+layout-bepo-rotate-keymaps
     '(magit-status-mode-map
       magit-staged-section-map
       magit-unstaged-section-map
       magit-untracked-section-map)))
  (after! (evil magit-diff)
    (+layout-bepo-rotate-keymaps
     '(magit-diff-mode-map
       magit-diff-section-base-map)))
  (after! (evil magit-process)
    (+layout-bepo-rotate-keymaps
     '(magit-process-mode-map)))
  (after! (evil magit-refs)
    (+layout-bepo-rotate-keymaps
     '(magit-refs-mode-map)))
  (after! (evil magit-blob)
    (+layout-bepo-rotate-keymaps
     '(magit-blob-mode-map)))
  (after! (evil magit)
    (+layout-bepo-rotate-ts-bare-keymap
     '(magit-mode-map))
    ;; Without this, "s" is mapped to `magit-delete-thing' (the old "k" for "kill") and
    ;; takes precedence over the evil command to go up one line
    ;; :nv doesn't work on this, needs to be the bare map.
    ;; This is the output of `describe-function `magit-delete-thing' when we add :nv or :nvm
    ;; Key Bindings
    ;;   evil-collection-magit-mode-map-backup-map <normal-state> x
    ;;   evil-collection-magit-mode-map-backup-map <visual-state> x
    ;;   evil-collection-magit-mode-map-backup-map k
    ;;   evil-collection-magit-mode-map-normal-state-backup-map x
    ;;   evil-collection-magit-mode-map-visual-state-backup-map x
    ;;   magit-mode-map <normal-state> x
    ;;   magit-mode-map <visual-state> x
    ;;   magit-mode-map s
    ;; Same thing for t, which gets mapped to `magit-quick-status'
    (map! :map magit-mode-map
          "s" nil
          "t" nil)
    (+layout-bepo-rotate-keymaps
     '(magit-mode-map)))
  ;; End of the Magit zone
  

  (after! evil-easymotion
    ;; Use "gé" instead of default "gs" to avoid conflicts w/org-mode later
    (evilem-default-keybindings "gé")
    (+layout-bepo-rotate-bare-keymap '(evilem-map) +layout-bepo-cr-rotation-style)))


;;
;;; Bootstrap

(+layout-remap-keys-for-bepo-h)
(when (modulep! :editor evil)
  (+layout-remap-evil-keys-for-bepo-h)
  (add-hook! 'evil-collection-setup-hook
    (defun +layout-bepo-rotate-evil-collection-keymap (_mode mode-keymaps &rest _rest)
      (+layout-bepo-rotate-keymaps mode-keymaps))))
