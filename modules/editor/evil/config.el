;;; editor/evil/config.el -*- lexical-binding: t; -*-

(defcustom +evil-want-o/O-to-continue-comments t
  "If non-nil, the o/O keys will continue comment lines if the point is on a
line with a linewise comment."
  :type 'boolean
  :group '+evil)

(defcustom +evil-want-move-window-to-wrap-around nil
  "If non-nil, `+evil/window-move-*' commands will wrap around."
  :type 'boolean
  :group '+evil)

(defcustom +evil-preprocessor-regexp "^\\s-*#[a-zA-Z0-9_]"
  "The regexp used by `+evil/next-preproc-directive' and
`+evil/previous-preproc-directive' on ]# and [#, to jump between preprocessor
directives. By default, this only recognizes C directives."
  :type 'regexp
  :group '+evil)


;;
;;; Packages

;; Set these defaults before `evil'; use `defvar' so they can be changed prior
;; to loading.
(defvar evil-want-keybinding (not (modulep! +everywhere)))
(defvar evil-want-C-g-bindings t)
(defvar evil-want-C-i-jump nil)  ; we do this ourselves
(defvar evil-want-C-u-scroll t)  ; moved the universal arg to <leader> u
(defvar evil-want-C-u-delete t)
(defvar evil-want-C-w-delete t)
(defvar evil-want-Y-yank-to-eol t)
(defvar evil-want-abbrev-expand-on-insert-exit nil)
(defvar evil-respect-visual-line-mode nil)

(use-package! evil
  :hook (doom-after-modules-config . evil-mode)
  :demand t
  :preface
  (setq evil-ex-search-vim-style-regexp t
        evil-ex-visual-char-range t  ; column range for ex commands
        evil-mode-line-format 'nil
        ;; More vim-like behavior
        evil-symbol-word-search t
        ;; If the current state is obvious from the cursor's color/shape, then
        ;; we won't need superfluous indicators to do it instead.
        evil-default-cursor '+evil-default-cursor-fn
        evil-normal-state-cursor 'box
        evil-emacs-state-cursor  '(box +evil-emacs-cursor-fn)
        evil-insert-state-cursor 'bar
        evil-visual-state-cursor 'hollow
        ;; Only do highlighting in selected window so that Emacs has less work
        ;; to do highlighting them all.
        evil-ex-interactive-search-highlight 'selected-window
        ;; It's infuriating that innocuous "beginning of line" or "end of line"
        ;; errors will abort macros, so suppress them:
        evil-kbd-macro-suppress-motion-error t
        evil-undo-system
        (cond ((modulep! :emacs undo +tree) 'undo-tree)
              ((modulep! :emacs undo) 'undo-fu)
              ('undo-redo)))

  ;; Fix #7141
  (defadvice! +evil--persist-state-a (fn &rest args)
    "When changing major modes, Evil's state is lost. This advice preserves it."
    :around #'set-auto-mode
    (if evil-state
        (evil-save-state (apply fn args))
      (apply fn args)))

  ;; Slow this down from 0.02 to prevent blocking in large or folded buffers
  ;; like magit while incrementally highlighting matches.
  (setq-hook! '(special-mode-hook so-long-minor-mode-hook)
    evil-ex-hl-update-delay 0.25)

  :config
  (evil-select-search-module 'evil-search-module 'evil-search)

  ;; HACK: `evil-ex-search' (used by `n'/`N') calls `isearch-range-invisible'
  ;;   which temporarily opens fold overlays, but never calls
  ;;   `isearch-clean-overlays' to restore them. This corrupts org-fold overlay
  ;;   state, making subtrees permanently unfoldable with TAB. See
  ;;   emacs-evil/evil#1630, #8625.
  ;; REVIEW: Remove when emacs-evil/evil#1630 is resolved.
  (defadvice! +evil--clean-isearch-overlays-a (&rest _)
    :after #'evil-ex-search
    (isearch-clean-overlays))

  ;; PERF: Stop copying the selection to the clipboard each time the cursor
  ;;   moves in visual mode. Why? Because on most non-X systems (and in
  ;;   terminals with clipboard plugins like xclip.el active), Emacs will spin
  ;;   up a new process to communicate with the clipboard for each movement. On
  ;;   Windows, older versions of macOS (pre-vfork), and Waylang (without pgtk),
  ;;   this is super expensive and can lead to freezing and/or zombie processes.
  ;;
  ;; UX: It also clobbers clipboard managers (see emacs-evil/evil#336).
  (setq evil-visual-update-x-selection-p nil)

  ;; Start help-with-tutorial in emacs state
  (advice-add #'help-with-tutorial :after (lambda (&rest _) (evil-emacs-state +1)))

  ;; Done in a hook to ensure the popup rules load as late as possible
  (add-hook! 'doom-after-modules-config-hook
    (defun +evil--init-popup-rules-h ()
      (set-popup-rules!
        '(("^\\*evil-registers" :size 0.3)
          ("^\\*Command Line"   :size 8)))))

  ;; We want to update the colors after a new theme has been enabled, but this
  ;; is tricky: whenever a cursor color is applied, Emacs will automatically
  ;; change the 'cursor face accordingly to keep it in sync. As a result, we
  ;; read and store the new theme colors as early as possible, and in particular
  ;; before evil performs its next cursor refresh.
  (add-hook! '(doom-load-theme-hook doom-after-modules-config-hook) :depth -100
    (defun +evil-update-cursor-color-h ()
      ;; Use a flashy color for emacs state.
      (put 'cursor 'evil-emacs-color  (face-foreground 'warning))
      (put 'cursor 'evil-normal-color (face-background 'cursor))))
  (defun +evil-default-cursor-fn ()
    (evil-set-cursor-color (get 'cursor 'evil-normal-color)))
  (defun +evil-emacs-cursor-fn ()
    (evil-set-cursor-color (get 'cursor 'evil-emacs-color)))

  ;; HACK: Ensure `evil-shift-width' always matches `tab-width'.
  (set-indent-vars! t 'evil-shift-width)


  ;; --- keybind fixes ----------------------
  (after! wgrep
    ;; A wrapper that invokes `wgrep-mark-deletion' across lines you use
    ;; `evil-delete' in wgrep buffers.
    (define-key wgrep-mode-map [remap evil-delete] #'+evil-delete))

  (add-hook! 'doom-escape-hook
    (defun +evil-disable-ex-highlights-h ()
      "Disable ex search buffer highlights."
      (when (or (evil-ex-hl-active-p 'evil-ex-search)
                (bound-and-true-p anzu--state))
        (evil-ex-nohighlight)
        t)))

  ;; REVIEW: Remove if emacs-evil/evil#1971 is addressed.
  (when evil-respect-visual-line-mode
    (evil-define-minor-mode-key 'motion 'visual-line-mode
      [up]   #'evil-previous-visual-line
      [down] #'evil-next-visual-line
      [home] #'evil-beginning-of-visual-line
      [end]  #'evil-end-of-visual-line))


  ;; --- evil hacks -------------------------
  (after! eldoc
    ;; Allow eldoc to trigger directly after changing modes
    (eldoc-add-command 'evil-normal-state
                       'evil-insert
                       'evil-change
                       'evil-delete
                       'evil-replace))

  (unless noninteractive
    (setq save-silently t)
    (add-hook! 'after-save-hook
      (defun +evil-display-vimlike-save-message-h ()
        "Shorter, vim-esque save messages."
        (message "\"%s\" %dL, %dC written"
                 (if buffer-file-name
                     (file-relative-name (file-truename buffer-file-name) (doom-project-root))
                   (buffer-name))
                 (count-lines (point-min) (point-max))
                 (buffer-size)))))

  ;; HACK: '=' moves the cursor to the beginning of selection. Disable this,
  ;;   since it's more disruptive than helpful.
  (defadvice! +evil--dont-move-cursor-a (fn &rest args)
    :around #'evil-indent
    (save-excursion (apply fn args)))

  ;; HACK: In vim, registers 2-9 are global. In Evil, they're buffer-local.  so
  ;;   I enforce vim's way.
  ;; REVIEW: PR this upstream?
  (defadvice! +evil--make-numbered-markers-global-a (char)
    :after-until #'evil-global-marker-p
    (and (>= char ?2) (<= char ?9)))

  ;; HACK: Fix joining commented lines with J (evil-join).
  (advice-add #'evil-join :around #'+evil-join-a)

  ;; HACK: Prevent gw (`evil-fill') and gq (`evil-fill-and-move') from squeezing
  ;;   spaces. It doesn't in vim, so it shouldn't in evil.
  (defadvice! +evil--no-squeeze-on-fill-a (fn &rest args)
    :around '(evil-fill evil-fill-and-move)
    (letf! (defun fill-region (from to &optional justify _nosqueeze to-eop)
             (funcall fill-region from to justify t to-eop))
      (apply fn args)))

  ;; HACK: Make Emacs registers recognize and treat Evil registers like their
  ;;   own, for consistency's sake.
  (when (modulep! +everywhere)
    (defvar +evil--use-evil-registers t)

    (defadvice! +evil--use-evil-registers-a (fn register)
      "Merge Evil's registers into Emacs' register list (when Evil is active)."
      :around #'get-register
      (if (and (characterp register)  ; prevent `evil-get-register' type error
               +evil--use-evil-registers
               (or (bound-and-true-p evil-mode)
                   (bound-and-true-p evil-local-mode)))
          (if (char-equal register ?=)   ; last expression register input
              evil-last-=-register-input
            (let (+evil--use-evil-registers)
              (evil-get-register register t)))
        (funcall fn register)))

    (defadvice! +evil--propagate-registers-a (fn &rest args)
      "Merge Evil's registers into Emacs' register list (when Evil is active)."
      :around #'register-swap-out
      :around #'register-buffer-to-file-query
      :around #'register-read-with-preview-fancy
      :around #'list-registers
      (let ((register-alist
             (if (and +evil--use-evil-registers
                      (or (bound-and-true-p evil-mode)
                          (bound-and-true-p evil-local-mode)))
                 (evil-register-list)
               register-alist)))
        (apply fn args))))

  ;; Make ESC (from normal mode) the universal escaper. See `doom-escape-hook'.
  (advice-add #'evil-force-normal-state :after #'+evil-escape-a)

  ;; HACK: Enhance `evil-ex-replace-special-filenames' to add support for
  ;;   Vim-like Ex file modifiers like %:p:h. Most vim's modifiers are
  ;;   supported, plus one custom one: %:P (expands to the project's root).
  (advice-add #'evil-ex-replace-special-filenames :override #'+evil-replace-filename-modifiers-a)

  ;; HACK: Make `try-expand-dabbrev' (from `hippie-expand') work in minibuffer
  (add-hook 'minibuffer-inactive-mode-hook #'+evil--fix-dabbrev-in-minibuffer-h)

  ;; Focus and recenter new splits
  (advice-add #'evil-window-split  :override #'+evil-window-split-a)
  (advice-add #'evil-window-vsplit :override #'+evil-window-vsplit-a)

  ;; Make o/O continue comments (see `+evil-want-o/O-to-continue-comments' to disable)
  (advice-add #'evil-open-above :around #'+evil--insert-newline-above-and-respect-comments-a)
  (advice-add #'evil-open-below :around #'+evil--insert-newline-below-and-respect-comments-a)

  ;; Lazy load evil ex commands
  (cl-callf2 delq 'evil-ex features)
  (add-transient-hook! 'evil-ex (provide 'evil-ex))
  (after! evil-ex (load! "+commands")))


(use-package! evil-collection
  :after evil
  :when (modulep! +everywhere)
  :unless noninteractive
  :unless (doom-context-p 'reload)
  :hook (doom-after-modules-config . evil-collection-init)
  :preface
  (defvar +evil-collection-disabled-list
    '(anaconda-mode
      company
      elisp-mode
      ert
      lispy)
    "A list of modules to ignore in `evil-collection-mode-list'.

The defaults disable modules that we have our own keybinds for or that (IMO)
don't offer any/enough real value to users.")
  (defvar evil-collection-repl-submit-state 'insert)
  (defvar evil-collection-company-use-tng (modulep! :completion company +tng))
  (defvar evil-collection-setup-minibuffer nil)
  (defvar evil-collection-want-unimpaired-p nil)  ; we have our own
  ;; We bind goto-reference on gD and goto-assignments on gA ourselves
  (defvar evil-collection-want-find-usages-bindings-p nil)
  ;; Reduces keybind conflicts between outline-mode and org-mode (which is
  ;; derived from outline-mode).
  (defvar evil-collection-outline-enable-in-minor-mode-p nil)
  :config
  (dolist (sym +evil-collection-disabled-list)
    (if-let* ((elt (assq sym evil-collection-mode-list)))
        (cl-callf2 delete elt evil-collection-mode-list)
      (cl-callf2 delq sym evil-collection-mode-list)))

  (setq evil-collection-key-blacklist
        (append (list doom-leader-key doom-localleader-key
                      doom-leader-alt-key)
                evil-collection-key-blacklist
                (if (modulep! :tools lookup) '("gd" "gf" "K"))
                (if (modulep! :tools eval) '("gr" "gR"))
                '("[" "]" "gz" "<escape>")))

  (defadvice! +evil-collection-disable-blacklist-a (fn)
    :around #'evil-collection-vterm-toggle-send-escape  ; allow binding to ESC
    (let (evil-collection-key-blacklist)
      (funcall-interactively fn))))


(use-package! evil-easymotion
  :after-call doom-first-input-hook
  :commands evilem-create evilem-default-keybindings
  :config
  ;; Use evil-search backend, instead of isearch
  (evilem-make-motion evilem-motion-search-next #'evil-ex-search-next
                      :bind ((evil-ex-search-highlight-all nil)))
  (evilem-make-motion evilem-motion-search-previous #'evil-ex-search-previous
                      :bind ((evil-ex-search-highlight-all nil)))
  (evilem-make-motion evilem-motion-search-word-forward #'evil-ex-search-word-forward
                      :bind ((evil-ex-search-highlight-all nil)))
  (evilem-make-motion evilem-motion-search-word-backward #'evil-ex-search-word-backward
                      :bind ((evil-ex-search-highlight-all nil)))

  ;; Rebind scope of w/W/e/E/ge/gE evil-easymotion motions to the visible
  ;; buffer, rather than just the current line.
  (put 'visible 'bounds-of-thing-at-point (lambda () (cons (window-start) (window-end))))
  (evilem-make-motion evilem-motion-forward-word-begin #'evil-forward-word-begin :scope 'visible)
  (evilem-make-motion evilem-motion-forward-WORD-begin #'evil-forward-WORD-begin :scope 'visible)
  (evilem-make-motion evilem-motion-forward-word-end #'evil-forward-word-end :scope 'visible)
  (evilem-make-motion evilem-motion-forward-WORD-end #'evil-forward-WORD-end :scope 'visible)
  (evilem-make-motion evilem-motion-backward-word-begin #'evil-backward-word-begin :scope 'visible)
  (evilem-make-motion evilem-motion-backward-WORD-begin #'evil-backward-WORD-begin :scope 'visible)
  (evilem-make-motion evilem-motion-backward-word-end #'evil-backward-word-end :scope 'visible)
  (evilem-make-motion evilem-motion-backward-WORD-end #'evil-backward-WORD-end :scope 'visible))


(use-package! evil-embrace
  :commands embrace-add-pair embrace-add-pair-regexp
  :hook (LaTeX-mode . embrace-LaTeX-mode-hook)
  :hook (LaTeX-mode . +evil-embrace-latex-mode-hook-h)
  :hook (org-mode . embrace-org-mode-hook)
  :hook ((ruby-mode ruby-ts-mode) . embrace-ruby-mode-hook)
  :hook (emacs-lisp-mode . embrace-emacs-lisp-mode-hook)
  :hook ((c++-mode c++-ts-mode) . +evil-embrace-angle-bracket-modes-hook-h)
  :hook ((csharp-mode csharp-ts-mode) . +evil-embrace-angle-bracket-modes-hook-h)
  :hook ((java-mode java-ts-mode) . +evil-embrace-angle-bracket-modes-hook-h)
  :hook ((scala-mode scala-ts-mode) . +evil-embrace-scala-mode-hook-h)
  :hook ((swift-mode typescript-mode rustic-mode) . +evil-embrace-angle-bracket-modes-hook-h)
  :init
  (after! evil-surround
    (evil-embrace-enable-evil-surround-integration))

  ;; HACK: This must be done ASAP, before embrace has a chance to
  ;;   buffer-localize `embrace--pairs-list' (which happens right after it calls
  ;;   `embrace--setup-defaults'), otherwise any new, global default pairs we
  ;;   define won't be in scope.
  (defadvice! +evil--embrace-init-escaped-pairs-a (&rest _)
    "Add escaped-sequence support to embrace."
    :after #'embrace--setup-defaults
    (embrace-add-pair-regexp ?\\ "\\[[{(]" "\\[]})]" #'+evil--embrace-escaped
                             (embrace-build-help "\\?" "\\?")))
  :config
  (setq evil-embrace-show-help-p nil)

  (defun +evil-embrace-scala-mode-hook-h ()
    (embrace-add-pair ?$ "${" "}"))

  (defun +evil-embrace-latex-mode-hook-h ()
    (dolist (pair '((?\' . ("`" . "\'"))
                    (?\" . ("``" . "\'\'"))))
      (delete (car pair) evil-embrace-evil-surround-keys)
      ;; Avoid `embrace-add-pair' because it would overwrite the default rules,
      ;; which we want for other modes
      (push (cons (car pair) (make-embrace-pair-struct
                              :key (car pair)
                              :left (cadr pair)
                              :right (cddr pair)
                              :left-regexp (regexp-quote (cadr pair))
                              :right-regexp (regexp-quote (cddr pair))))
            embrace--pairs-list))
    (embrace-add-pair-regexp ?l "\\[a-z]+{" "}" #'+evil--embrace-latex))

  (defun +evil-embrace-angle-bracket-modes-hook-h ()
    (let ((var (make-local-variable 'evil-embrace-evil-surround-keys)))
      (set var (delq ?< evil-embrace-evil-surround-keys))
      (set var (delq ?> evil-embrace-evil-surround-keys)))
    (embrace-add-pair-regexp ?< "\\_<[a-z0-9-_]+<" ">" #'+evil--embrace-angle-brackets)
    (embrace-add-pair ?> "<" ">")))


(use-package! evil-escape
  :commands evil-escape
  :hook (doom-first-input . evil-escape-mode)
  :init
  (setq evil-escape-excluded-states '(normal visual multiedit emacs motion)
        evil-escape-excluded-major-modes '(neotree-mode treemacs-mode vterm-mode)
        evil-escape-key-sequence nil
        evil-escape-delay 0.15)
  (evil-define-key* '(insert replace visual operator) 'global "\C-g" #'evil-escape)
  :config
  ;; `evil-escape' in the minibuffer is more disruptive than helpful. That is,
  ;; unless we have `evil-collection-setup-minibuffer' enabled, in which case we
  ;; want the same behavior in insert mode as we do in normal buffers.
  (add-hook! 'evil-escape-inhibit-functions
    (defun +evil-inhibit-escape-in-minibuffer-fn ()
      (and (minibufferp)
           (or (not (bound-and-true-p evil-collection-setup-minibuffer))
               (evil-normal-state-p))))))


(use-package! evil-exchange
  :commands evil-exchange
  :config
  (add-hook! 'doom-escape-hook
    (defun +evil--escape-exchange-h ()
      (when evil-exchange--overlays
        (evil-exchange-cancel)
        t))))


(use-package! evil-quick-diff
  :commands (evil-quick-diff evil-quick-diff-cancel))


(use-package! evil-nerd-commenter
  :commands (evilnc-comment-operator
             evilnc-inner-comment
             evilnc-outer-commenter)
  :general ([remap comment-line] #'evilnc-comment-or-uncomment-lines))


(use-package! evil-snipe
  :commands evil-snipe-local-mode evil-snipe-override-local-mode
  :hook (doom-first-input . evil-snipe-override-mode)
  :hook (doom-first-input . evil-snipe-mode)
  :init
  (setq evil-snipe-smart-case t
        evil-snipe-scope 'line
        evil-snipe-repeat-scope 'visible
        evil-snipe-char-fold t))


(use-package! evil-surround
  :hook (doom-first-input . global-evil-surround-mode)
  :commands (global-evil-surround-mode
             evil-surround-edit
             evil-Surround-edit
             evil-surround-region))


(use-package! evil-textobj-anyblock
  :defer t
  :config
  (setq evil-textobj-anyblock-blocks
        '(("(" . ")")
          ("{" . "}")
          ("\\[" . "\\]")
          ("<" . ">"))))


(use-package! evil-traces
  :after evil-ex
  :config
  (dolist (argtype '((+evil:align . evil-traces-global)
                     (+evil:align-right . evil-traces-global)
                     (+multiple-cursors:evil-mc . evil-traces-substitute)))
    (add-to-list 'evil-traces-argument-type-alist argtype))
  (evil-traces-mode))


;; Allows you to use the selection for * and #
(use-package! evil-visualstar
  :commands (evil-visualstar/begin-search
             evil-visualstar/begin-search-forward
             evil-visualstar/begin-search-backward)
  :init
  (evil-define-key* 'visual 'global
    "*" #'evil-visualstar/begin-search-forward
    "#" #'evil-visualstar/begin-search-backward))


;;
;;; Text object plugins

(use-package! exato
  :commands evil-outer-xml-attr evil-inner-xml-attr)


;;
;;; Keybinds

;; TODO: zu{q,w} - undo last marking

(map! :v  "@"     #'+evil:apply-macro
      :m  [C-i]   #'evil-jump-forward

      ;; implement dictionary keybinds
      ;; evil already defines 'z=' to `ispell-word' = correct word at point
      (:when (modulep! :checkers spell)
       :n  "zg"   #'+spell/add-word
       :n  "zw"   #'+spell/remove-word
       :m  "[s"   #'+spell/previous-error
       :m  "]s"   #'+spell/next-error)

      ;; ported from vim-unimpaired
      :n  "] SPC" #'+evil/insert-newline-below
      :n  "[ SPC" #'+evil/insert-newline-above
      :n  "]b"    #'next-buffer
      :n  "[b"    #'previous-buffer
      :n  "]f"    #'+evil/next-file
      :n  "[f"    #'+evil/previous-file
      :m  "[u"    #'+evil:url-encode
      :m  "]u"    #'+evil:url-decode
      :m  "[y"    #'+evil:c-string-encode
      :m  "]y"    #'+evil:c-string-decode
      (:when (modulep! :lang web)
       :m "[x"   #'+web:encode-html-entities
       :m "]x"   #'+web:decode-html-entities)
      (:when (modulep! :ui vc-gutter)
       :m "]d"   #'+vc-gutter/next-hunk
       :m "[d"   #'+vc-gutter/previous-hunk)
      (:when (modulep! :ui hl-todo)
       :m "]t"   #'hl-todo-next
       :m "[t"   #'hl-todo-previous)
      (:when (modulep! :ui workspaces)
       :n "gt"   #'+workspace:switch-next
       :n "gT"   #'+workspace:switch-previous
       :n "]w"   #'+workspace/switch-right
       :n "[w"   #'+workspace/switch-left)
      (:when (modulep! :ui tabs)
       :n "gt"   #'+tabs:next-or-goto
       :n "gT"   #'+tabs:previous-or-goto)

      ;; custom vim-unmpaired-esque keys
      :m  "]#"    #'+evil/next-preproc-directive
      :m  "[#"    #'+evil/previous-preproc-directive
      :m  "]a"    #'evil-forward-arg
      :m  "[a"    #'evil-backward-arg
      :m  "]c"    #'+evil/next-comment
      :m  "[c"    #'+evil/previous-comment
      :m  "]e"    #'next-error
      :m  "[e"    #'previous-error
      :n  "]F"    #'+evil/next-frame
      :n  "[F"    #'+evil/previous-frame
      :m  "]h"    #'outline-next-visible-heading
      :m  "[h"    #'outline-previous-visible-heading
      :m  "]m"    #'+evil/next-beginning-of-method
      :m  "[m"    #'+evil/previous-beginning-of-method
      :m  "]M"    #'+evil/next-end-of-method
      :m  "[M"    #'+evil/previous-end-of-method
      :n  "[o"    #'+evil/insert-newline-above
      :n  "]o"    #'+evil/insert-newline-below
      :n  "gp"    #'+evil/reselect-paste
      :v  "gp"    #'+evil/alt-paste
      :nv "g@"    #'+evil:apply-macro
      :nv "gc"    #'evilnc-comment-operator
      :nv "gO"    #'imenu
      :nv "gx"    #'evil-exchange
      :nv "gy"    #'+evil:yank-unindented
      :n  "g="    #'evil-numbers/inc-at-pt
      :n  "g-"    #'evil-numbers/dec-at-pt
      :v  "g="    #'evil-numbers/inc-at-pt-incremental
      :v  "g-"    #'evil-numbers/dec-at-pt-incremental
      :v  "g+"    #'evil-numbers/inc-at-pt
      (:when (modulep! :tools lookup)
       :nv "K"   #'+lookup/documentation
       :nv "gd"  #'+lookup/definition
       :nv "gD"  #'+lookup/references
       :nv "gf"  #'+lookup/file
       :nv "gI"  #'+lookup/implementations)
      (:when (modulep! :tools eval)
       :nv "gr"  #'+eval:region
       :n  "gR"  #'+eval/buffer
       :v  "gR"  #'+eval:replace-region
       ;; Restore these keybinds, since the blacklisted/overwritten gr/gR will
       ;; undo them:
       (:after compile
        :map (compilation-mode-map compilation-minor-mode-map)
        :n "gr" #'recompile)
       (:after dired
        :map dired-mode-map
        :n "gr" #'revert-buffer)
       (:after notmuch
        :map notmuch-common-keymap
        :n "gr" #'notmuch-refresh-this-buffer
        :n "gR" #'notmuch-poll-and-refresh-this-buffer)
       (:after elfeed
        :map elfeed-search-mode-map
        :n "gr" #'elfeed-search-update--force
        :n "gR" #'elfeed-search-fetch)
       (:after eglot
        :map eglot-mode-map
        :nv "gd" #'+lookup/definition
        :nv "gD" #'+lookup/references))

      ;; custom evil keybinds
      :nv "zn"    #'+evil:narrow-buffer
      :n  "zN"    #'doom/widen-indirectly-narrowed-buffer
      :n  "zx"    #'kill-current-buffer
      :n  "ZX"    #'doom/save-and-kill-buffer
      ;; don't leave visual mode after shifting
      :v  "<"     #'+evil/shift-left  ; vnoremap < <gv
      :v  ">"     #'+evil/shift-right  ; vnoremap > >gv

      ;; window management (prefix "C-w")
      (:map evil-window-map
       ;; Navigation
       "C-h"     #'evil-window-left
       "C-j"     #'evil-window-down
       "C-k"     #'evil-window-up
       "C-l"     #'evil-window-right
       "C-w"     #'other-window
       ;; Extra split commands
       "S"       #'+evil/window-split-and-follow
       "V"       #'+evil/window-vsplit-and-follow
       ;; Swapping windows
       "H"       #'+evil/window-move-left
       "J"       #'+evil/window-move-down
       "K"       #'+evil/window-move-up
       "L"       #'+evil/window-move-right
       "C-S-w"   #'ace-swap-window
       ;; Window undo/redo
       (:prefix "m"
        "m"       #'doom/window-maximize-buffer
        "v"       #'doom/window-maximize-vertically
        "s"       #'doom/window-maximize-horizontally)
       "u"       #'winner-undo
       "C-u"     #'winner-undo
       "C-r"     #'winner-redo
       "o"       #'doom/window-enlargen
       ;; Delete window
       "d"       #'evil-window-delete
       "C-C"     #'ace-delete-window
       "T"       #'tear-off-window)

      ;; text objects
      :textobj "a" #'evil-inner-arg                    #'evil-outer-arg
      :textobj "B" #'evil-textobj-anyblock-inner-block #'evil-textobj-anyblock-a-block
      :textobj "c" #'evilnc-inner-comment              #'evilnc-outer-commenter
      :textobj "f" #'+evil:defun-txtobj                #'+evil:defun-txtobj
      :textobj "g" #'+evil:whole-buffer-txtobj         #'+evil:whole-buffer-txtobj
      :textobj "i" #'evil-indent-plus-i-indent         #'evil-indent-plus-a-indent
      :textobj "j" #'evil-indent-plus-i-indent-up-down #'evil-indent-plus-a-indent-up-down
      :textobj "k" #'evil-indent-plus-i-indent-up      #'evil-indent-plus-a-indent-up
      :textobj "q" #'+evil:inner-any-quote             #'+evil:outer-any-quote
      :textobj "u" #'+evil:inner-url-txtobj            #'+evil:outer-url-txtobj
      :textobj "x" #'evil-inner-xml-attr               #'evil-outer-xml-attr

      ;; evil-easymotion
      (:after evil-easymotion
       :m "gs" evilem-map
       ;; TODO: Use named functions
       (:map evilem-map
        "a" (evilem-create #'evil-forward-arg)
        "A" (evilem-create #'evil-backward-arg)
        "s" #'evil-avy-goto-char-2
        "SPC" (cmd! (let ((current-prefix-arg t)) (evil-avy-goto-char-timer)))
        "/" #'evil-avy-goto-char-timer))

      ;; evil-snipe
      (:after evil-snipe
       :map evil-snipe-parent-transient-map
       "C-;" (cmd! (require 'evil-easymotion)
                   (call-interactively
                    (evilem-create #'evil-snipe-repeat
                                   :bind ((evil-snipe-scope 'whole-buffer)
                                          (evil-snipe-enable-highlight)
                                          (evil-snipe-enable-incremental-highlight))))))

      ;; evil-surround
      :v "S" #'evil-surround-region
      :o "s" #'evil-surround-edit
      :o "S" #'evil-Surround-edit

      ;; evil-lion
      :n "gl" #'evil-lion-left
      :n "gL" #'evil-lion-right
      :v "gl" #'evil-lion-left
      :v "gL" #'evil-lion-right

      ;; Emulation of Vim's omni-completion keybinds
      (:unless evil-disable-insert-state-bindings
        (:prefix "C-x"
          (:when (modulep! :completion company)
           :i "C-l"  #'+company/whole-lines
           :i "C-k"  #'+company/dict-or-keywords
           :i "C-f"  #'company-files
           :i "C-]"  #'company-etags
           :i "s"    #'company-ispell
           :i "C-s"  #'company-yasnippet
           :i "C-o"  #'company-capf
           :i "C-n"  #'+company/dabbrev
           :i "C-p"  #'+company/dabbrev-code-previous)
          (:when (modulep! :completion corfu)
           :i "C-l"  #'cape-line
           :i "C-k"  #'cape-keyword
           :i "C-f"  #'cape-file
           :i "C-]"  #'complete-tag
           :i "s"    #'cape-dict
           :i "C-s"  #'yasnippet-capf
           :i "C-o"  #'completion-at-point
           :i "C-n"  #'cape-dabbrev
           :i "C-p"  #'+corfu/dabbrev-this-buffer))))


(unless evil-disable-insert-state-bindings
  (when (modulep! :completion corfu)
    (define-key!
      :keymaps (append doom-minibuffer-maps
                       (when (modulep! :editor evil +everywhere)
                         '(evil-ex-completion-map)))
      "C-x C-f"  #'cape-file
      "C-x s"    #'cape-dict
      "C-x C-s"  #'yasnippet-capf
      "C-x C-o"  #'completion-at-point
      "C-x C-n"  #'cape-dabbrev
      "C-x C-p"  #'+corfu/dabbrev-this-buffer)))
