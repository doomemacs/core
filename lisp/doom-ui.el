;;; doom-ui.el --- defaults for Doom's aesthetics -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'ring)  ; for `ring-insert', `make-ring' (not preloaded in Emacs 30+)

;;
;;; Variables

(defcustom doom-theme nil
  "What theme (or themes) to load at startup.

Is either a symbol representing the name of an Emacs theme, or a list thereof
(to enable in order).

Set to `nil' to load no theme at all. This variable is changed by `load-theme'
and `enable-theme'."
  :type '(choice symbol (repeat symbol))
  :group 'doom)

(defcustom doom-font nil
  "The default font to use.
Must be a `font-spec', a font object, an XFT font string, or an XLFD string.

This affects the `default' and `fixed-pitch' faces.

Examples:
  (setq doom-font (font-spec :family \"Fira Mono\" :size 12))
  (setq doom-font \"Terminus (TTF):pixelsize=12:antialias=off\")
  (setq doom-font \"Fira Code-14\")"
  :type '(restricted-sexp :match-alternatives (fontp stringp 'nil))
  :group 'doom)

(defcustom doom-variable-pitch-font nil
  "The default font to use for variable-pitch text.
Must be a `font-spec', a font object, an XFT font string, or an XLFD string. See
`doom-font' for examples.

An omitted font size means to inherit `doom-font''s size."
  :type '(restricted-sexp :match-alternatives (fontp stringp 'nil))
  :group 'doom)

(defcustom doom-serif-font nil
  "The default font to use for the `fixed-pitch-serif' face.
Must be a `font-spec', a font object, an XFT font string, or an XLFD string. See
`doom-font' for examples.

An omitted font size means to inherit `doom-font''s size."
  :type '(restricted-sexp :match-alternatives (fontp stringp 'nil))
  :group 'doom)

(define-obsolete-variable-alias 'doom-unicode-font 'doom-symbol-font "2.1.0")
(defcustom doom-symbol-font nil
  "Fallback font for symbols.
Must be a `font-spec', a font object, an XFT font string, or an XLFD string. See
`doom-font' for examples. Emacs defaults to Symbola.

WARNING: if you specify a size for this font it will hard-lock any usage of this
font to that size. It's rarely a good idea to do so!"
  :type '(restricted-sexp :match-alternatives (fontp stringp 'nil))
  :group 'doom)

(defcustom doom-emoji-font nil
  "Fallback font for emoji.
Must be a `font-spec', a font object, an XFT font string, or an XLFD string. See
`doom-font' for examples.

WARNING: if you specify a size for this font it will hard-lock any usage of this
font to that size. It's rarely a good idea to do so!"
  :type '(restricted-sexp :match-alternatives (fontp stringp 'nil))
  :group 'doom)

(defcustom doom-emoji-fallback-font-families
  '("Apple Color Emoji"
    "Segoe UI Emoji"
    "Noto Color Emoji"
    "Noto Emoji")
  "A list of fallback font families to use for emojis.
These are platform-specific fallbacks for internal use. If you
want to change your emoji font, use `doom-emoji-font'."
  :type '(repeat (restricted-sexp :match-alternatives (fontp stringp)))
  :group 'doom)

(defcustom doom-symbol-fallback-font-families
  '("Segoe UI Symbol"
    "Apple Symbols")
  "A list of fallback font families for general symbol glyphs.
These are platform-specific fallbacks for internal use. If you
want to change your symbol font, use `doom-symbol-font'."
  :type '(repeat (restricted-sexp :match-alternatives (fontp stringp)))
  :group 'doom)


;;
;;; Custom hooks

(defcustom doom-init-ui-hook nil
  "List of hooks to run when the UI has been initialized."
  :type 'hook
  :group 'doom)

(defcustom doom-load-theme-hook nil
  "Hook run after a color-scheme is loaded.

Triggered by `load-theme', `enable-theme', or reloaded with `doom/reload-theme',
but only for themes that declare themselves as a :kind color-scheme (which Doom
treats as the default)."
  :type 'hook
  :group 'doom)

(defcustom doom-switch-buffer-hook nil
  "A list of hooks run after changing the current buffer."
  :type 'hook
  :group 'doom)

(defcustom doom-switch-window-hook nil
  "A list of hooks run after changing the focused windows."
  :type 'hook
  :group 'doom)

(defcustom doom-switch-frame-hook nil
  "A list of hooks run after changing the focused frame.

This also serves as an analog for `focus-in-hook' or
`after-focus-change-function', but also preforms debouncing (see
`doom-switch-frame-hook-debounce-delay'). It's possible for this hook to be
triggered multiple times (because there are edge cases where Emacs can have
multiple frames focused at once)."
  :type 'hook
  :group 'doom)

(defun doom-run-switch-buffer-hooks-h (&optional _)
  "Trigger `doom-switch-buffer-hook' when selecting a new buffer."
  (let ((gc-cons-threshold most-positive-fixnum))
    (run-hooks 'doom-switch-buffer-hook)))

(defun doom-run-switch-window-hooks-h (&optional _)
  "Trigger `doom-switch-window-hook' when selecting a window in the same frame."
  (unless (or (minibufferp)
              (not (equal (old-selected-frame) (selected-frame)))
              (equal (old-selected-window) (minibuffer-window)))
    (let ((gc-cons-threshold most-positive-fixnum))
      (run-hooks 'doom-switch-window-hook))))

(defvar doom-switch-frame-hook-debounce-delay 2.0
  "The delay for which `doom-switch-frame-hook' won't trigger again.

This exists to prevent switch-frame hooks getting triggered too aggressively due
to misbehaving desktop environments, packages incorrectly frame switching in
non-interactive code, or the user accidentally (and rapidly) un-and-refocusing
the frame through some other means.")

(defun doom--run-switch-frame-hooks-fn (_)
  (remove-hook 'pre-redisplay-functions #'doom--run-switch-frame-hooks-fn)
  (let ((gc-cons-threshold most-positive-fixnum))
    (dolist (fr (visible-frame-list))
      (let ((state (frame-focus-state fr)))
        (when (and state (not (eq state 'unknown)))
          (let ((last-update (frame-parameter fr '+last-focus)))
            (when (or (null last-update)
                      (> (float-time (time-subtract (current-time) last-update))
                         doom-switch-frame-hook-debounce-delay))
              (with-selected-frame fr
                (unwind-protect
                    (let ((inhibit-redisplay t))
                      (run-hooks 'doom-switch-frame-hook))
                  (set-frame-parameter fr '+last-focus (current-time)))))))))))

(let (last-focus-state)
  (defun doom-run-switch-frame-hooks-fn ()
    "Trigger `doom-switch-frame-hook' once per frame focus change."
    (or (equal last-focus-state
               (setq last-focus-state
                     (mapcar #'frame-focus-state (frame-list))))
        ;; Defer until next redisplay
        (add-hook 'pre-redisplay-functions #'doom--run-switch-frame-hooks-fn))))

(defun doom-protect-fallback-buffer-h ()
  "Don't kill the scratch buffer. Meant for `kill-buffer-query-functions'."
  (not (eq (current-buffer) (doom-fallback-buffer))))


;;
;;; General UX

;; A simple confirmation prompt when killing Emacs. But only prompt when there
;; are real buffers open.
(setq confirm-kill-emacs #'doom-quit-p)
;; Prompt for confirmation when deleting a non-empty frame; a last line of
;; defense against accidental loss of work.
(global-set-key [remap delete-frame] #'doom/delete-frame-with-prompt)

;; Don't prompt for confirmation when we create a new file or buffer (assume the
;; user knows what they're doing).
(setq confirm-nonexistent-file-or-buffer nil)

(setq uniquify-buffer-name-style 'forward
      ;; no beeping or blinking please
      ring-bell-function #'ignore
      visible-bell nil)

;; middle-click paste at point, not at click
(setq mouse-yank-at-point t)

;; Larger column width for function name in profiler reports
(after! profiler
  (setf (caar profiler-report-cpu-line-format) 80
        (caar profiler-report-memory-line-format) 80))


;;
;;; Scrolling

(setq hscroll-margin 2
      hscroll-step 1
      ;; Emacs spends too much effort recentering the screen if you scroll the
      ;; cursor more than N lines past window edges (where N is the settings of
      ;; `scroll-conservatively'). This is especially slow in larger files
      ;; during large-scale scrolling commands. If kept over 100, the window is
      ;; never automatically recentered. The default (0) triggers this too
      ;; aggressively, so I've set it to 10 to recenter if scrolling too far
      ;; off-screen.
      scroll-conservatively 10
      scroll-margin 0
      scroll-preserve-screen-position t
      ;; Reduce cursor lag by a tiny bit by not auto-adjusting `window-vscroll'
      ;; for tall lines.
      auto-window-vscroll nil
      ;; mouse
      mouse-wheel-scroll-amount '(2 ((shift) . hscroll))
      mouse-wheel-scroll-amount-horizontal 2)


;;
;;; Cursor

;; The blinking cursor is distracting, but also interferes with cursor settings
;; in some minor modes that try to change it buffer-locally (like treemacs) and
;; can cause freezing for folks (esp on macOS) with customized & color cursors.
(blink-cursor-mode -1)

;; Don't blink the paren matching the one at point, it's too distracting.
(setq blink-matching-paren nil)

;; Don't stretch the cursor to fit wide characters, it is disorienting,
;; especially for tabs.
(setq x-stretch-cursor nil)


;;
;;; Buffers

(defadvice! doom--switch-to-fallback-buffer-maybe-a (&rest _)
  "Switch to `doom-fallback-buffer' if on last real buffer.

Advice for `kill-current-buffer'. If in a dedicated window, delete it. If there
are no real buffers left OR if all remaining buffers are visible in other
windows, switch to `doom-fallback-buffer'. Otherwise, delegate to original
`kill-current-buffer'."
  :before-until #'kill-current-buffer
  (let ((buf (current-buffer)))
    (cond ((eq buf (doom-fallback-buffer))
           (message "Can't kill the fallback buffer.")
           t)
          ((and (doom-real-buffer-p buf)
                (run-hook-with-args-until-failure 'kill-buffer-query-functions))
           (let ((visible-p (delq (selected-window) (get-buffer-window-list buf nil t))))
             (unless visible-p
               (when (and (buffer-file-name (buffer-base-buffer))
                          (buffer-modified-p buf)
                          (not (y-or-n-p
                                (format "Buffer %s is modified; kill anyway?"
                                        buf))))
                 (user-error "Aborted")))
             (let ((inhibit-redisplay t)
                   buffer-list-update-hook
                   kill-buffer-query-functions)
               (when (or
                      ;; if there aren't more real buffers than visible buffers,
                      ;; then there are no real, non-visible buffers left.
                      (not (cl-set-difference (doom-real-buffer-list)
                                              (doom-visible-buffers nil t)))
                      ;; if we end up back where we start (or previous-buffer
                      ;; returns nil), we have nowhere left to go
                      (memq (switch-to-prev-buffer nil t) (list buf 'nil)))
                 (switch-to-buffer (doom-fallback-buffer)))
               (unless visible-p
                 (with-current-buffer buf
                   (restore-buffer-modified-p nil))
                 (kill-buffer buf)))
             (run-hooks 'buffer-list-update-hook)
             t)))))


;;
;;; Fringes

;; Reduce the clutter in the fringes; we'd like to reserve that space for more
;; useful information, like diff-hl and flycheck.
(setq indicate-buffer-boundaries nil
      indicate-empty-lines nil)


;;
;;; Windows/frames

;; A simple frame title
(setq frame-title-format '("%b – Doom Emacs")
      icon-title-format frame-title-format)

;; Don't resize the frames in steps; it looks weird, especially in tiling window
;; managers, where it can leave unseemly gaps.
(setq frame-resize-pixelwise t)

;; But do not resize windows pixelwise, this can cause crashes in some cases
;; when resizing too many windows at once or rapidly.
(setq window-resize-pixelwise nil)

;; UX: GUIs are inconsistent across systems, desktop environments, and themes,
;;   but more annoying than that are the inconsistent shortcut keys tied to
;;   them, so use Emacs instead of GUI popups.
(setq use-dialog-box (featurep :system 'android)) ; Android dialogs are better UX
(when (bound-and-true-p tooltip-mode)
  (tooltip-mode -1))

;; FIX: The native border "consumes" a pixel of the fringe on righter-most
;;   splits, `window-divider' does not. Available since Emacs 25.1.
(setq window-divider-default-places t
      window-divider-default-bottom-width 1
      window-divider-default-right-width 1)
(add-hook 'doom-init-ui-hook #'window-divider-mode)

;; UX: Favor vertical splits over horizontal ones. Monitors are trending toward
;;   wide, rather than tall.
(setq split-width-threshold 160
      split-height-threshold nil)


;;
;;; Minibuffer

;; Hide irrelevant commands in M-x menu.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; Allow for minibuffer-ception. Sometimes we need another minibuffer command
;; while we're in the minibuffer.
(setq enable-recursive-minibuffers t)

;; Show current key-sequence in minibuffer ala 'set showcmd' in vim. Any
;; feedback after typing is better UX than no feedback at all.
(setq echo-keystrokes 0.02)

;; Expand the minibuffer to fit multi-line text displayed in the echo-area. This
;; doesn't look too great with direnv, however...
(setq resize-mini-windows 'grow-only
      tooltip-resize-echo-area t)

;; Typing yes/no is obnoxious when y/n will do
(if (boundp 'use-short-answers)
    (setq use-short-answers t)
  ;; DEPRECATED: Remove when we drop 27.x support
  (advice-add #'yes-or-no-p :override #'y-or-n-p))
;; HACK: By default, SPC = yes when `y-or-n-p' prompts you (and
;;   `y-or-n-p-use-read-key' is off). This seems too easy to hit by accident,
;;   especially with SPC as our default leader key.
(define-key y-or-n-p-map " " nil)

;; Try to keep the cursor out of the read-only portions of the minibuffer.
(setq minibuffer-prompt-properties '(read-only t intangible t cursor-intangible t face minibuffer-prompt))
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)


;;
;;; Built-in packages

(after! comint
  (setq-default comint-buffer-maximum-size 2048)  ; double the default

  ;; UX: Temporarily disable undo history between command executions. Otherwise,
  ;;   undo could destroy output while it's being printed or delete buffer
  ;;   contents past the boundaries of the current prompt.
  (add-hook 'comint-exec-hook #'buffer-disable-undo)
  (defadvice! doom--comint-enable-undo-a (process _string)
    :after #'comint-output-filter
    (unless buffer-read-only  ; don't affect output-only buffers like `compilation-mode'
      (with-current-buffer (process-buffer process)
        (when-let* ((start-marker comint-last-output-start))
          (when (and (< start-marker
                        (or (if process (process-mark process))
                            (point-max-marker)))
                     (eq (char-before start-marker) ?\n)) ;; Account for some of the IELM’s wilderness.
            (buffer-enable-undo)
            (setq buffer-undo-list nil))))))

  ;; Protect prompts from accidental modifications.
  (setq-default comint-prompt-read-only t)

  ;; UX: Prior output in shell and comint shells (like ielm) should be
  ;;   read-only. Otherwise, it's trivial to make edits in visual modes (like
  ;;   evil's or term's term-line-mode) and leave the buffer in a half-broken
  ;;   state (which you have to flush out with a couple RETs, which may execute
  ;;   the broken text in the buffer),
  (defadvice! doom--comint-protect-output-in-visual-modes-a (process _string)
    :after #'comint-output-filter
    ;; Adapted from https://github.com/michalrus/dotfiles/blob/c4421e361400c4184ea90a021254766372a1f301/.emacs.d/init.d/040-terminal.el.symlink#L33-L49
    (with-current-buffer (process-buffer process)
      (let ((start-marker comint-last-output-start)
            (end-marker (process-mark process)))
        (when (and start-marker (< start-marker end-marker)) ;; Account for some of the IELM’s wilderness.
          (let ((inhibit-read-only t))
            ;; Make all past output read-only (disallow buffer modifications)
            (add-text-properties comint-last-input-start (1- end-marker) '(read-only t))
            ;; Disallow interleaving.
            (remove-text-properties start-marker (1- end-marker) '(rear-nonsticky))
            ;; Make sure that at `max-point' you can always append. Important for
            ;; bad REPLs that keep writing after giving us prompt (e.g. sbt).
            (add-text-properties (1- end-marker) end-marker '(rear-nonsticky t))
            ;; Protect fence (newline of input, just before output).
            (when (eq (char-before start-marker) ?\n)
              (remove-text-properties (1- start-marker) start-marker '(rear-nonsticky))
              (add-text-properties (1- start-marker) start-marker '(read-only t))))))))

  ;; UX: If the user is anywhere but the last prompt, typing should move them
  ;;   there instead of unhelpfully spew read-only errors at them.
  (defun doom--comint-move-cursor-to-prompt-h ()
    (and (eq this-command 'self-insert-command)
         comint-last-prompt
         (> (cdr comint-last-prompt) (point))
         (goto-char (cdr comint-last-prompt))))

  (add-hook! 'comint-mode-hook
    (defun doom--comint-init-move-cursor-to-prompt-h ()
      (unless buffer-read-only  ; don't affect output-only buffers like `compilation-mode'
        (add-hook 'pre-command-hook #'doom--comint-move-cursor-to-prompt-h
                  nil t)))))


(after! compile
  (setq compilation-always-kill t       ; kill compilation process before starting another
        compilation-ask-about-save nil  ; save all buffers on `compile'
        compilation-max-output-line-length nil  ; slows down verbose processes
        compilation-scroll-output 'first-error)
  (add-hook 'compilation-filter-hook
            (if (< emacs-major-version 28)
                #'doom-apply-ansi-color-to-compilation-buffer-h
              #'ansi-color-compilation-filter))
  ;; Automatically truncate compilation buffers so they don't accumulate too
  ;; much data and grind Emacs' GC to a halt or crash. Also rate-limit expensive
  ;; calls to `comint-truncate-buffer'.
  (autoload 'comint-truncate-buffer "comint" nil t)
  (add-hook! 'compilation-filter-hook
    (defun doom-comint-truncate-buffer-h (&optional _string)
      "Rate-limit `comint-truncate-buffer' in compilation-mode buffers."
      (if (> (buffer-size)
             ;; HACK: Approximate this because counting lines is prohibitively
             ;;   expensive in longer buffers, especially in
             ;;   `compilation-filter-hook' which fires rapidly.
             (* 80 comint-buffer-maximum-size))
          (let ((gc-cons-threshold most-positive-fixnum)
                (gc-cons-percentage 1.0))
            (with-silent-modifications
              (comint-truncate-buffer)))))))


(after! ediff
  (setq ediff-diff-options "-w" ; turn off whitespace checking
        ediff-split-window-function #'split-window-horizontally
        ediff-window-setup-function #'ediff-setup-windows-plain)

  (defvar doom--ediff-saved-wconf nil)
  ;; Restore window config after quitting ediff
  (add-hook! 'ediff-before-setup-hook
    (defun doom-ediff-save-wconf-h ()
      (setq doom--ediff-saved-wconf (current-window-configuration))))
  (add-hook! '(ediff-quit-hook ediff-suspend-hook) :append
    (defun doom-ediff-restore-wconf-h ()
      (when (window-configuration-p doom--ediff-saved-wconf)
        (set-window-configuration doom--ediff-saved-wconf)))))


(use-package! hl-line
  ;; Highlights the current line
  :hook (doom-first-input . global-hl-line-mode)
  :init
  (defvar global-hl-line-modes
    '(prog-mode text-mode conf-mode special-mode
      org-agenda-mode dired-mode)
    "What modes to enable `hl-line-mode' in.")
  :config
  (with-no-warnings
    (if (boundp 'global-hl-line-buffers)
        (setq global-hl-line-buffers
              (lambda (b)
                (with-current-buffer b
                  (not (or hl-line-mode
                           (when global-hl-line-modes
                             (if (eq (car global-hl-line-modes) 'not)
                                 (derived-mode-p (cdr global-hl-line-modes))
                               (not (derived-mode-p global-hl-line-modes))))
                           (doom-region-active-p)
                           cursor-face-highlight-mode
                           (doom-temp-buffer-p b)
                           (minibufferp)))))
              ;; Don't display line highlights in non-focused windows, for
              ;; performance sake and to reduce UI clutter.
              global-hl-line-sticky-flag 'window)
      ;; HACK: `global-hl-line-buffers' wasn't introduced until 31.1, so I
      ;;   reimplement it for `global-hl-line-modes', so we have a major mode
      ;;   white/blacklist.
      (define-globalized-minor-mode global-hl-line-mode hl-line-mode
        (lambda ()
          (and (cond (hl-line-mode nil)
                     ((null global-hl-line-modes) nil)
                     ((eq global-hl-line-modes t))
                     ((eq (car global-hl-line-modes) 'not)
                      (not (apply #'derived-mode-p (cdr global-hl-line-modes))))
                     ((apply #'derived-mode-p global-hl-line-modes)))
               (hl-line-mode +1)))
        :group 'hl-line)))

  ;; Temporarily disable `hl-line-mode' when selection is active, since it
  ;; obscures the bounds of the selection, depending on the active theme.
  (defvar doom--hl-line-mode nil)
  (add-hook! 'activate-mark-hook
    (defun doom-disable-hl-line-h ()
      (when hl-line-mode
        (hl-line-mode -1)
        (setq-local doom--hl-line-mode t))))
  (add-hook! 'deactivate-mark-hook
    (defun doom-enable-hl-line-maybe-h ()
      (when doom--hl-line-mode
        (hl-line-mode +1)
        (kill-local-variable 'doom--hl-line-mode))))
  ;; Don't resurrect itself if manually disabled then a selection is disengaged.
  (add-hook! 'hl-line-mode-hook
    (defun doom-truly-disable-hl-line-h ()
      (unless hl-line-mode
        (kill-local-variable 'doom--hl-line-mode)))))


(use-package! winner
  ;; undo/redo changes to Emacs' window layout
  :preface (defvar winner-dont-bind-my-keys t) ; I'll bind keys myself
  :hook (doom-first-buffer . winner-mode)
  :config
  (cl-callf append winner-boring-buffers
    '("*Compile-Log*" "*inferior-lisp*" "*Fuzzy Completions*"
      "*Apropos*" "*Help*" "*cvs*" "*Buffer List*" "*Ibuffer*"
      "*esh command on file*")))


(use-package! paren
  ;; highlight matching delimiters
  :hook (doom-first-buffer . show-paren-mode)
  :config
  (setq show-paren-delay 0.1
        show-paren-highlight-openparen t
        show-paren-when-point-inside-paren t
        show-paren-when-point-in-periphery t))


;; Hide the mode line in completion popups and MAN pages because they serve
;; little purpose there, and is better hidden.
(add-hook 'completion-list-mode-hook #'mode-line-invisible-mode)
(add-hook 'Man-mode-hook #'mode-line-invisible-mode)

(add-hook 'completion-list-mode-hook #'doom-disable-line-numbers-h)
(add-hook 'Man-mode-hook #'doom-disable-line-numbers-h)

;;
;;; Third party packages

(use-package! nerd-icons
  :commands (nerd-icons-octicon
             nerd-icons-faicon
             nerd-icons-flicon
             nerd-icons-wicon
             nerd-icons-mdicon
             nerd-icons-codicon
             nerd-icons-devicon
             nerd-icons-ipsicon
             nerd-icons-pomicon
             nerd-icons-powerline))

;;;###package image
(setq image-animate-loop t)


;;
;;; Line numbers

;; Explicitly define a width to reduce the cost of on-the-fly computation
(setq-default display-line-numbers-width 3)

;; Show absolute line numbers for narrowed regions to make it easier to tell the
;; buffer is narrowed, and where you are, exactly.
(setq-default display-line-numbers-widen t)

;; Enable line numbers in most text-editing modes. We avoid
;; `global-display-line-numbers-mode' because there are many special and
;; temporary modes where we don't need/want them.
(add-hook! '(prog-mode-hook text-mode-hook conf-mode-hook)
           #'display-line-numbers-mode)

;; Fix #2742: cursor is off by 4 characters in `artist-mode'
;; REVIEW: Reported upstream https://debbugs.gnu.org/cgi/bugreport.cgi?bug=43811
;; DEPRECATED: Fixed in Emacs 28; remove when we drop 27 support
(unless (> emacs-major-version 27)
  (add-hook 'artist-mode-hook #'doom-disable-line-numbers-h))


;;
;;; Theme & font

;; User themes should live in $DOOMDIR/themes, not ~/.emacs.d
(setq custom-theme-directory (file-name-concat doom-user-dir "themes/"))

;; Third party themes add themselves to `custom-theme-load-path', but the themes
;; living in $DOOMDIR/themes should always have priority.
(setq custom-theme-load-path
      (cons 'custom-theme-directory
            (delq 'custom-theme-directory custom-theme-load-path)))

(defun doom-init-fonts-h (&optional reload)
  "Loads `doom-font', `doom-serif-font', and `doom-variable-pitch-font'."
  (let ((initialized-frames (unless reload (get 'doom-font 'initialized-frames))))
    (dolist (frame (if reload (frame-list) (list (selected-frame))))
      (unless (member frame initialized-frames)
        (dolist (map `((default . ,doom-font)
                       (fixed-pitch . ,doom-font)
                       (fixed-pitch-serif . ,doom-serif-font)
                       (variable-pitch . ,doom-variable-pitch-font)))
          (condition-case e
              (when-let* ((face (car map))
                          (font (cdr map)))
                (when (display-multi-font-p frame)
                  (set-face-attribute face frame
                                      :width 'normal :weight 'normal
                                      :slant 'normal :font font))
                (custom-push-theme
                 'theme-face face 'user 'set
                 (let* ((base-specs (cadr (assq 'user (get face 'theme-face))))
                        (base-specs (or base-specs '((t nil))))
                        (attrs '(:family :foundry :slant :weight :height :width))
                        (new-specs nil))
                   (dolist (spec base-specs)
                     (let ((display (car spec))
                           (plist (copy-tree (nth 1 spec))))
                       (when (or (memq display '(t default))
                                 (face-spec-set-match-display display frame))
                         (dolist (attr attrs)
                           (setq plist (plist-put plist attr (face-attribute face attr)))))
                       (push (list display plist) new-specs)))
                   (nreverse new-specs)))
                (put face 'face-modified nil))
            (error
             (if (string-prefix-p "Font not available" (error-message-string e))
                 (signal 'doom-font-error (list (font-get (cdr map) :family)))
               (signal (car e) (cdr e))))))
        (put 'doom-font 'initialized-frames
             (cons frame (cl-delete-if-not #'frame-live-p initialized-frames))))))
  ;; Only do this once per session (or on `doom/reload-fonts'); superfluous
  ;; `set-fontset-font' calls may segfault in some contexts.
  (when (or reload (not (get 'doom-font 'initialized)))
    (when (fboundp 'set-fontset-font)  ; unavailable in emacs-nox
      (let* ((fn (doom-rpartial #'member (font-family-list)))
             (symbol-font (or doom-symbol-font
                              (cl-find-if fn doom-symbol-fallback-font-families)))
             (emoji-font (or doom-emoji-font
                             (cl-find-if fn doom-emoji-fallback-font-families))))
        (when symbol-font
          (dolist (script '(symbol mathematical))
            (set-fontset-font t script symbol-font)))
        (when emoji-font
          ;; DEPRECATED: make unconditional when we drop 27 support
          (when (version<= "28.1" emacs-version)
            (set-fontset-font t 'emoji emoji-font))
          ;; some characters in the Emacs symbol script are often covered by
          ;; emoji fonts
          (set-fontset-font t 'symbol emoji-font nil 'append)))
      ;; Nerd Fonts use these Private Use Areas
      (dolist (range '((#xe000 . #xf8ff) (#xf0000 . #xfffff)))
        (set-fontset-font t range "Symbols Nerd Font Mono")))
    (run-hooks 'after-setting-font-hook))
  (put 'doom-font 'initialized t))

(defun doom-init-theme-h (&rest _)
  "Load the theme specified by `doom-theme' in FRAME."
  (dolist (th (ensure-list doom-theme))
    (unless (custom-theme-enabled-p th)
      (if (custom-theme-p th)
          (enable-theme th)
        (load-theme th t)))))

(defadvice! doom--detect-colorscheme-a (theme)
  "Add :kind \\='color-scheme to THEME if it doesn't already have one.

Themes wouldn't call `provide-theme' unless they were a color-scheme, so treat
them as such. Also intended as a helper for `doom--theme-is-colorscheme-p'."
  :after #'provide-theme
  (or (plist-get (get theme 'theme-properties) :kind)
      (cl-callf plist-put (get theme 'theme-properties) :kind
                'color-scheme)))

(defun doom--theme-is-colorscheme-p (theme)
  (unless (memq theme '(nil user changed use-package))
    (if-let* ((kind (plist-get (get theme 'theme-properties) :kind)))
        ;; Some newer themes announce that they are colorschemes. Also, we've
        ;; advised `provide-theme' (only used by colorschemes) to give these
        ;; themes this property (see `doom--detect-colorscheme-a').
        (eq kind 'color-scheme)
      ;; HACK: If by some chance a legit (probably very old) theme isn't using
      ;;   `provide-theme' (ugh), fall back to this hail mary heuristic to
      ;;   detect colorscheme themes:
      (let ((feature (get theme 'theme-feature)))
        (and
         ;; Colorschemes always have a theme-feature (possible to define them
         ;; without one with `custom-declare-theme' + a nil second argument):
         feature
         ;; ...and they always end in -theme (this is hardcoded into `deftheme'
         ;; and others in Emacs' theme API).
         (string-suffix-p "-theme" (symbol-name feature))
         ;; ...and any theme (deftheme X) will have a corresponding `X-theme'
         ;; package loaded when it's enabled.
         (featurep feature))))))

(add-hook! 'enable-theme-functions :depth -90
  (defun doom-enable-theme-h (theme)
    "Record themes and trigger `doom-load-theme-hook'."
    (when (doom--theme-is-colorscheme-p theme)
      (ring-insert (with-memoization (get 'doom-theme 'history) (make-ring 8))
                   (copy-sequence custom-enabled-themes))
      ;; Functions in `doom-load-theme-hook' may trigger face recalculations,
      ;; which can be contaminated by buffer-local face remaps (e.g. by
      ;; `mixed-pitch-mode'); this prevents that contamination:
      (with-temp-buffer
        (let ((enable-theme-functions
               (remq 'doom-enable-theme-h enable-theme-functions)))
          (doom-run-hooks 'doom-load-theme-hook))
        ;; HACK: If the user uses `load-theme' in their $DOOMDIR instead of
        ;;   setting `doom-theme', override the latter, because they shouldn't
        ;;   be using both.
        (unless (memq theme (ensure-list doom-theme))
          (setq-default doom-theme theme))))))

(add-hook! 'after-make-frame-functions :depth -90
  (defun doom-fix-frame-color-parameters-h (f)
    ;; HACK: Some window systems produce new frames (after the initial one) with
    ;;   incorrect color parameters (black).
    ;; REVIEW: What is injecting those parameters? Maybe a PGTK-only issue?
    (when (display-graphic-p f)
      (letf! (defun invalid-p (color)
               (or (equal color "black")
                   (string-prefix-p "unspecified-" color)))
        (pcase-dolist (`(,param ,fn ,face)
                       '((foreground-color face-foreground default)
                         (background-color face-background default)
                         (cursor-color face-background cursor)
                         (border-color face-background border)
                         (mouse-color face-background mouse)))
          (when-let* ((color (frame-parameter f param))
                      ((invalid-p color))
                      (color (funcall fn face nil t))
                      ((not (invalid-p color))))
            (set-frame-parameter f param color)))))))


;;
;;; Bootstrap

(defun doom-init-ui-h (&optional _)
  "Initialize Doom's user interface by applying all its advice and hooks.

These should be done as late as possible, as to avoid/minimize prematurely
triggering hooks during startup."
  (doom-run-hooks 'doom-init-ui-hook)

  (add-hook 'kill-buffer-query-functions #'doom-protect-fallback-buffer-h)

  ;; Make `next-buffer', `other-buffer', etc. ignore unreal buffers.
  (push '(buffer-predicate . doom-buffer-frame-predicate) default-frame-alist)

  ;; Initialize `doom-switch-*-hook' hooks.
  (add-function :after after-focus-change-function #'doom-run-switch-frame-hooks-fn)
  (add-hook 'window-selection-change-functions #'doom-run-switch-window-hooks-h)
  (add-hook 'window-buffer-change-functions #'doom-run-switch-buffer-hooks-h)
  ;; `window-buffer-change-functions' doesn't trigger for files visited via the server.
  (add-hook 'server-switch-hook #'doom-run-switch-buffer-hooks-h))

;; Apply fonts and theme
(let ((hook (if (daemonp)
                'server-after-make-frame-hook
              'after-init-hook)))
  (add-hook hook #'doom-init-fonts-h -100)
  (add-hook hook #'doom-init-theme-h -90))

;; PERF: Init UI late, but not too late. Its impact on startup time seems to
;;   vary wildly depending on exact placement. `window-setup-hook' appears to be
;;   the sweet spot.
(add-hook 'window-setup-hook #'doom-init-ui-h -100)


;;
;;; Fixes/hacks

;; Doom doesn't support `customize' and it never will. It's a clumsy interface
;; that sets variables at a time where it can be easily and unpredictably
;; overwritten. Configure things from your $DOOMDIR instead.
(dolist (sym '(customize-option customize-browse customize-group customize-face
               customize-rogue customize-saved customize-apropos
               customize-changed customize-unsaved customize-variable
               customize-set-value customize-customized customize-set-variable
               customize-apropos-faces customize-save-variable
               customize-apropos-groups customize-apropos-options
               customize-changed-options customize-save-customized))
  (put sym 'disabled "Doom doesn't support `customize', configure Emacs from $DOOMDIR/config.el instead"))
(put 'customize-themes 'disabled "Set `doom-theme' or use `load-theme' in $DOOMDIR/config.el instead")

(provide 'doom-ui)
;;; doom-ui.el ends here
