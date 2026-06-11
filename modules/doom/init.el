;;; modules/doom/init.el -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; These files will be merged in doom-start in v3 and use-package is no longer
;; used internally.
;;
;;; Code:

;;; * Variables

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

(defcustom doom-file-lines-threshold-alist
  `(("." . ,(cond ((fboundp 'igc-info) 25000)
                  ((featurep 'native-compile) 20000)
                  (15000))))
  "An alist mapping regexps (like `auto-mode-alist') to line number thresholds.

If a file is opened and discovered to have more lines than this, Doom enables
`so-long-minor-mode' to prevent Emacs from hanging, crashing, or becoming
unusably slow, by disabling non-essential functionality.

Used by `doom-so-long-p'."
  :type '(repeat (cons regexp integer))
  :group 'doom)


;;; ** Keybinds

(defcustom doom-leader-key "SPC"
  "The leader prefix key for Evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-leader-alt-key "M-SPC"
  "An alternative leader prefix key, used for Insert and Emacs states, and for
non-evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-localleader-key "SPC m"
  "The localleader prefix key, for major-mode specific commands."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-localleader-alt-key "M-SPC m"
  "The localleader prefix key, for major-mode specific commands. Used for Insert
and Emacs states, and for non-evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-leader-key-states '(normal visual motion)
  "which evil modes to activate the leader key for"
  :type '(repeat symbol)
  :group 'doom)

(defcustom doom-leader-alt-key-states '(emacs insert)
  "which evil modes to activate the alternative leader key for"
  :type '(repeat symbol)
  :group 'doom)

(defvar doom-leader-map (make-sparse-keymap)
  "An overriding keymap for <leader> keys.")


;;; ** Hooks

(defcustom doom-first-input-hook ()
  "Transient hooks run before the first user input."
  :type 'hook
  :group 'doom)

(defcustom doom-first-file-hook ()
  "Transient hooks run before the first interactively opened file."
  :type 'hook
  :group 'doom)

(defcustom doom-first-buffer-hook ()
  "Transient hooks run before the first interactively opened buffer."
  :type 'hook
  :group 'doom)

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


;;; * Reasonable defaults

;; Background native compilation consumes several CPU cores and takes minutes to
;; complete. Not worth the extra stress when on battery power.
(setq native-comp-async-on-battery-power nil)  ; introduced in Emacs 31.1

;;; ** Stricter security defaults
;; Emacs is essentially one huge security vulnerability, what with all the
;; dependencies it pulls in from all corners of the globe. Let's try to be a
;; *little* more discerning.
(setq gnutls-verify-error noninteractive
      gnutls-algorithm-priority
      (when (boundp 'libgnutls-version)
        (concat "SECURE128:+SECURE192:-VERS-ALL"
                (if (and (not doom--system-windows-p)
                         (>= libgnutls-version 30605))
                    ":+VERS-TLS1.3")
                ":+VERS-TLS1.2"))
      ;; `gnutls-min-prime-bits' is set based on recommendations from
      ;; https://www.keylength.com/en/4/
      gnutls-min-prime-bits 3072
      tls-checktrust gnutls-verify-error
      ;; Emacs is built with gnutls.el by default, so `tls-program' won't
      ;; typically be used, but in the odd case that it does, we ensure a more
      ;; secure default for it (falling back to `openssl' if absolutely
      ;; necessary). See https://redd.it/8sykl1 for details.
      tls-program '("openssl s_client -connect %h:%p -CAfile %t -nbio -no_ssl3 -no_tls1 -no_tls1_1 -ign_eof"
                    "gnutls-cli -p %p --dh-bits=3072 --ocsp --x509cafile=%t \
--strict-tofu --priority='SECURE192:+SECURE128:-VERS-ALL:+VERS-TLS1.2:+VERS-TLS1.3' %h"
                    ;; compatibility fallbacks
                    "gnutls-cli -p %p %h"))


;;; ** File/directory settings

;; If a packages doesn't use `user-emacs-directory' or `locate-user-emacs-file'
;; to set their file/dir variables, then we need to set them ourselves to avoid
;; littering in ~/.emacs.d/.
(setq desktop-dirname  (file-name-concat doom-profile-state-dir "desktop")
      pcache-directory (file-name-concat doom-profile-cache-dir "pcache/"))

;; Write custom.el settings to $DOOMDIR/custom.el instead of $EMACSDIR/init.el,
;; allowing users to version control them and not interfere with Doom init.
(setq custom-file (file-name-concat doom-user-dir "custom.el"))

(define-advice en/disable-command (:around (fn &rest args) write-to-data-dir)
  "Save safe-local-variables to `custom-file' instead of `user-init-file'.

Otherwise, `en/disable-command' (in novice.el.gz) is hardcoded to write them to
`user-init-file')."
  (let ((user-init-file custom-file))
    (apply fn args)))

;; Ensure that, if the user does want package.el, it is configured correctly.
;; You really shouldn't be using it, though...
(with-eval-after-load 'package
  (setq package-user-dir (file-name-concat doom-local-dir "elpa/")
        package-gnupghome-dir (expand-file-name "gpg" package-user-dir))
  (let ((s (if (gnutls-available-p) "s" "")))
    ;; I omit Marmalade because its packages are manually submitted rather than
    ;; pulled, and so often out of date.
    (add-to-list 'package-archives `("melpa" . ,(format "http%s://melpa.org/packages/" s)))
    (add-to-list 'package-archives `("org"   . ,(format "http%s://orgmode.org/elpa/"   s))))
  ;; Refresh package.el the first time you call `package-install', so it's still
  ;; trivially usable. Remember to run 'doom sync' to purge them; they can
  ;; conflict with packages installed via straight!
  (add-transient-hook! 'package-install (package-refresh-contents)))


;;; ** Runtime optimizations

;; PERF: Disable bidirectional text scanning for a modest performance boost.
;;   I've set this to `nil' in the past, but the `bidi-display-reordering's docs
;;   say that is an undefined state and suggest this to be just as good:
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

;; PERF: Disabling BPA makes redisplay faster, but might produce incorrect
;;   reordering of bidirectional text with embedded parentheses (and other
;;   bracket characters whose 'paired-bracket' Unicode property is non-nil).
(setq bidi-inhibit-bpa t)  ; Emacs 27+ only

;; Reduce rendering/line scan work for Emacs by not rendering cursors or regions
;; in non-focused windows.
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; More performant rapid scrolling over unfontified regions. May cause brief
;; spells of inaccurate syntax highlighting right after scrolling, which should
;; quickly self-correct.
(setq fast-but-imprecise-scrolling t)

;; Font compacting can be terribly expensive, especially for rendering icon
;; fonts on Windows. Whether disabling it has a notable affect on Linux and Mac
;; hasn't been determined, but do it anyway, just in case. This increases memory
;; usage, however!
(setq inhibit-compacting-font-caches t)

;; Introduced in Emacs HEAD (b2f8c9f), this inhibits fontification while
;; receiving input, which should help a little with scrolling performance.
(setq redisplay-skip-fontification-on-input t)

;; The GC introduces annoying pauses and stuttering into our Emacs experience,
;; so we use `gcmh' to stave off the GC while we're using Emacs, and provoke it
;; when it's idle. However, if the idle delay is too long, we run the risk of
;; runaway memory usage in busy sessions. And if it's too low, then we may as
;; well not be using gcmh at all.
(unless (fboundp 'igc-info)
  (setq gcmh-idle-delay 'auto  ; default is 15s
        gcmh-auto-idle-delay-factor 10
        gcmh-high-cons-threshold (* 64 1024 1024))  ; 64mb
  (add-hook 'doom-first-buffer-hook #'gcmh-mode))


;;; ** Trust & Safety
;; Trust the contents of $EMACSDIR and $DOOMDIR, because the user will likely be
;; working with either/both.
(when (boundp 'trusted-content)
  (add-to-list 'trusted-content (file-truename doom-emacs-dir))
  (add-to-list 'trusted-content (file-truename doom-user-dir)))

;; Ensure .dir-locals.el in $EMACSDIR and $DOOMDIR are always respected
(add-to-list 'safe-local-variable-directories doom-emacs-dir)
(add-to-list 'safe-local-variable-directories doom-user-dir)


;;; ** Support for Doom-specific dotfiles
(add-to-list 'auto-mode-alist '("/\\.doom\\(?:module\\|profile\\)?\\'" . lisp-data-mode))


;;; ** Disable {menu,tool,scroll}-bar UI
;; PERF,UI: Doom strives to be keyboard-centric, so I consider these UI elements
;;   clutter. Initializing them also costs a morsel of startup time. What's
;;   more, the menu bar exposes functionality that Doom doesn't endorse or
;;   police. Perhaps one day Doom will support these, but today is not that day.
;;   By disabling them early, we save Emacs some time.

;; HACK: I intentionally avoid calling `menu-bar-mode', `tool-bar-mode', and
;;   `scroll-bar-mode' because their manipulation of frame parameters can
;;   trigger/queue a superfluous (and expensive, depending on the window system)
;;   frame redraw at startup. The variables must be set to `nil' as well so
;;   users don't have to call the functions twice to re-enable them.
(push '(menu-bar-lines . 0)   default-frame-alist)
(push '(tool-bar-lines . 0)   default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil)

;; HACK: The menu-bar needs special treatment on MacOS. On Linux and Windows
;;   (and TTY frames in MacOS), the menu-bar takes up valuable in-frame real
;;   estate -- so we disable it -- but on MacOS (GUI frames only) the menu bar
;;   lives outside of the frame, on the MacOS menu bar, which is acceptable, but
;;   disabling Emacs' menu-bar also makes MacOS treat Emacs GUI frames like
;;   non-application windows (e.g. it won't capture focus on activation, among
;;   other things), so the menu-bar should be preserved there.
(when doom--system-macos-p
  ;; NOTE: Don't try to undo the hack below, as it may change without warning.
  ;;   Instead, toggle `menu-bar-mode' (or put it on a hook) as normal. This
  ;;   hack will always try to respect the state of `menu-bar-mode'.
  (setcdr (assq 'menu-bar-lines default-frame-alist) 'tty)
  (add-hook! 'after-make-frame-functions
    (defun doom--init-menu-bar-on-macos-h (&optional frame)
      (if (eq (frame-parameter frame 'menu-bar-lines) 'tty)
          (set-frame-parameter frame 'menu-bar-lines
                               (if (display-graphic-p frame) 1 0))))))


;;; ** Line numbers

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


;;; ** Encodings
;; Contrary to what many Emacs users have in their configs, you don't need more
;; than this to make UTF-8 the default coding system:
(set-language-environment "UTF-8")
;; ...but `set-language-environment' also sets `default-input-method', which is
;; a step too opinionated.
(setq default-input-method nil)
;; ...And the clipboard on Windows is often a wider encoding (UTF-16), so leave
;; Emacs to its own devices there.
(unless (or doom--system-windows-p (featurep :system 'wsl))
  (setq selection-coding-system 'utf-8))


;;; ** UX
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


;;; ** Scrolling
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


;;; ** Cursor
;; The blinking cursor is distracting, but also interferes with cursor settings
;; in some minor modes that try to change it buffer-locally (like treemacs) and
;; can cause freezing for folks (esp on macOS) with customized & color cursors.
(blink-cursor-mode -1)

;; Don't blink the paren matching the one at point, it's too distracting.
(setq blink-matching-paren nil)

;; Don't stretch the cursor to fit wide characters, it is disorienting,
;; especially for tabs.
(setq x-stretch-cursor nil)


;;; ** Fringes
;; Reduce the clutter in the fringes; we'd like to reserve that space for more
;; useful information, like diff-hl and flycheck.
(setq indicate-buffer-boundaries nil
      indicate-empty-lines nil)


;;; ** Windows/frames

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


;;; ** Minibuffer

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


;;; ** Global keybind settings

(cond
 (doom--system-macos-p
  ;; mac-* variables are used by the special emacs-mac build of Emacs by
  ;; Yamamoto Mitsuharu, while other builds use ns-*.
  (setq mac-command-modifier      'super
        ns-command-modifier       'super
        mac-option-modifier       'meta
        ns-option-modifier        'meta
        ;; Free up the right option for character composition
        mac-right-option-modifier 'none
        ns-right-option-modifier  'none))
 (doom--system-windows-p
  (setq w32-lwindow-modifier 'super
        w32-rwindow-modifier 'super)))

;; HACK: Emacs can't distinguish C-i from TAB, or C-m from RET, in either GUI or
;;   TTY frames. This is a byproduct of its history with the terminal, which
;;   can't distinguish them either, however, Emacs has separate input events for
;;   many contentious keys like TAB and RET (like [tab] and [return], aka
;;   "<tab>" and "<return>"), which are only triggered in GUI frames, so here, I
;;   create one for C-i. Won't work in TTY frames, though. Doom's :os tty module
;;   has a workaround for that though.
(defun doom-init-input-decode-map-h ()
  (pcase-dolist (`(,key ,fallback . ,events)
                 '(([C-i] [?\C-i] tab kp-tab)
                   ([C-m] [?\C-m] return kp-return)))
    (define-key
     input-decode-map fallback
     (cmd! (if (when-let* ((keys (this-single-command-raw-keys)))
                 (and (display-graphic-p)
                      (not (cl-loop for event in events
                                    if (cl-position event keys)
                                    return t))
                      ;; Use FALLBACK if nothing is bound to KEY, otherwise
                      ;; we've broken all pre-existing FALLBACK keybinds.
                      (key-binding
                       (vconcat (if (= 0 (length keys)) [] (cl-subseq keys 0 -1))
                                key) nil t)))
               key fallback)))))

;; `input-decode-map' bindings are resolved on first invokation, and are
;; frame-local, so they must be rebound on every new frame.
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'doom-init-input-decode-map-h)
  (doom-init-input-decode-map-h))


;;; * Custom features

;;; ** MODE-local-vars-hook
;; File+dir local variables are initialized after the major mode and its hooks
;; have run. If you want hook functions to be aware of these customizations, add
;; them to MODE-local-vars-hook instead.
(defvar doom-inhibit-local-var-hooks nil)

(defun doom-run-local-var-hooks-h ()
  "Run MODE-local-vars-hook after local variables are initialized."
  (unless (or doom-inhibit-local-var-hooks
              delay-mode-hooks
              ;; Don't trigger local-vars hooks in temporary (internal) buffers
              (string-prefix-p
               " " (buffer-name (or (buffer-base-buffer)
                                    (current-buffer)))))
    (setq-local doom-inhibit-local-var-hooks t)
    ;; Show some rudimentary documentation for anyone wanting to understand
    ;; where these hooks came from.
    (let* ((hook-var (intern (format "%s-local-vars-hook" major-mode))))
      (unless (boundp hook-var)
        (set hook-var nil))
      (unless (get hook-var 'variable-documentation)
        (put hook-var 'variable-documentation
             (format (concat "Hooks to run after file/dir local variables are set in `%s', well after `%s-hook'.\n\n"
                             "These hooks are defined and executed by `doom-run-local-var-hooks-h'.")
                     major-mode major-mode)))
      (doom-run-hooks hook-var))))

;; If the user has disabled `enable-local-variables', then
;; `hack-local-variables-hook' is never triggered, so we trigger it at the end
;; of `after-change-major-mode-hook':
(defun doom-run-local-var-hooks-maybe-h ()
  "Run `doom-run-local-var-hooks-h' if `enable-local-variables' is disabled."
  (unless enable-local-variables
    (doom-run-local-var-hooks-h)))


;;; ** Incremental lazy-loading

(defvar doom-incremental-packages '(t)
  "A list of packages to load incrementally after startup. Any large packages
here may cause noticeable pauses, so it's recommended you break them up into
sub-packages. For example, `org' is comprised of many packages, and might be
broken up into:

  (doom-load-packages-incrementally
   \\='(calendar find-func format-spec org-macs org-compat
     org-faces org-entities org-list org-pcomplete org-src
     org-footnote org-macro ob org org-clock org-agenda
     org-capture))

This is already done by the lang/org module, however.

If you want to disable incremental loading altogether, either remove
`doom-load-packages-incrementally-h' from `doom-after-init-hook' or set
`doom-incremental-first-idle-timer' to nil. Incremental loading does not occur
in daemon sessions (they are loaded immediately at startup).")

(defvar doom-incremental-first-idle-timer (if (daemonp) 0 2.0)
  "How long (in idle seconds) until incremental loading starts.

Set this to nil to disable incremental loading at startup.
Set this to 0 to load all incrementally deferred packages immediately at
`doom-after-init-hook'.")

(defvar doom-incremental-idle-timer 0.75
  "How long (in idle seconds) in between incrementally loading packages.")

(defun doom-load-packages-incrementally (packages &optional now)
  "Registers PACKAGES to be loaded incrementally.

If NOW is non-nil, PACKAGES will be marked for incremental loading next time
Emacs is idle for `doom-incremental-first-idle-timer' seconds (falls back to
`doom-incremental-idle-timer'), then in `doom-incremental-idle-timer' intervals
afterwards."
  (let* ((gc-cons-threshold most-positive-fixnum)
         (first-idle-timer (or doom-incremental-first-idle-timer
                               doom-incremental-idle-timer)))
    (if (not now)
        (cl-callf append doom-incremental-packages packages)
      (while packages
        (let ((req (pop packages))
              idle-time)
          (if (featurep req)
              (doom-log 2 "start:iloader: Already loaded %s (%d left)" req (length packages))
            (condition-case-unless-debug e
                (and
                 (or (null (setq idle-time (current-idle-time)))
                     (< (float-time idle-time) first-idle-timer)
                     (not
                      (while-no-input
                        (doom-log 2 "start:iloader: Loading %s (%d left)" req (length packages))
                        ;; If `default-directory' doesn't exist or is
                        ;; unreadable, Emacs throws file errors.
                        (let ((default-directory doom-emacs-dir)
                              (inhibit-message t)
                              (file-name-handler-alist
                               (list (rassq 'jka-compr-handler file-name-handler-alist))))
                          (require req nil t)
                          t))))
                 (push req packages))
              (error
               (message "Error: failed to incrementally load %S because: %s" req e)
               (setq packages nil)))
            (if (null packages)
                (doom-log 2 "start:iloader: Finished!")
              (run-at-time (if idle-time
                               doom-incremental-idle-timer
                             first-idle-timer)
                           nil #'doom-load-packages-incrementally
                           packages t)
              (setq packages nil))))))))

(defun doom-load-packages-incrementally-h ()
  "Begin incrementally loading packages in `doom-incremental-packages'.

If this is a daemon session, load them all immediately instead."
  (when (numberp doom-incremental-first-idle-timer)
    (if (zerop doom-incremental-first-idle-timer)
        (mapc #'require (cdr doom-incremental-packages))
      (run-with-idle-timer doom-incremental-first-idle-timer
                           nil #'doom-load-packages-incrementally
                           (cdr doom-incremental-packages) t))))


(defun doom-display-benchmark-h (&optional return-p)
  "Display a benchmark including number of packages and modules loaded.

If RETURN-P, return the message as a string instead of displaying it."
  (funcall (if return-p #'format #'message)
           "Doom loaded %d packages across %d modules in %.03fs"
           (- (length load-path) (length (get 'load-path 'initial-value)))
           (if doom-modules (hash-table-count doom-modules) -1)
           doom-init-time))


;;; ** Universal, non-nuclear escape

;; `keyboard-quit' is too much of a nuclear option. I wanted an ESC/C-g to
;; do-what-I-mean. It serves four purposes (in order):
;;
;; 1. Quit active states; e.g. highlights, searches, snippets, iedit,
;;    multiple-cursors, recording macros, etc.
;; 2. Close popup windows remotely (if it is allowed to)
;; 3. Refresh buffer indicators, like diff-hl and flycheck
;; 4. Or fall back to `keyboard-quit'
;;
;; And it should do these things incrementally, rather than all at once. And it
;; shouldn't interfere with recording macros or the minibuffer. This may require
;; you press ESC/C-g two or three times on some occasions to reach
;; `keyboard-quit', but this is much more intuitive.

(defcustom doom-escape-hook nil
  "A hook run when C-g is pressed (or ESC in normal mode, for evil users).

More specifically, when `doom/escape' is pressed. If any hook returns non-nil,
all hooks after it are ignored."
  :type 'hook
  :group 'doom)

(defun doom/escape (&optional interactive)
  "Run `doom-escape-hook'."
  (interactive (list 'interactive))
  (let ((inhibit-quit t))
    (cond ((minibuffer-window-active-p (minibuffer-window))
           ;; quit the minibuffer if open.
           (when interactive
             (setq this-command 'abort-recursive-edit))
           (abort-recursive-edit))
          ;; Run all escape hooks. If any returns non-nil, then stop there.
          ((run-hook-with-args-until-success 'doom-escape-hook))
          ;; don't abort macros
          ((or defining-kbd-macro executing-kbd-macro) nil)
          ;; Back to the default
          ((unwind-protect (keyboard-quit)
             (when interactive
               (setq this-command 'keyboard-quit)))))))

(global-set-key [remap keyboard-quit] #'doom/escape)

(with-eval-after-load 'eldoc
  (eldoc-add-command 'doom/escape))


;;; ** General + leader/localleader keys

(require 'general)
;; Convenience aliases
(defalias 'define-key! #'general-def)
(defalias 'undefine-key! #'general-unbind)
;; Prevent "X starts with non-prefix key Y" errors except at startup.
(add-hook 'doom-after-modules-init-hook #'general-auto-unbind-keys)

;; HACK: `map!' uses this instead of `define-leader-key!' because it consumes
;;   20-30% more startup time, so we reimplement it ourselves.
(defmacro doom--define-leader-key (&rest keys)
  (let (prefix forms wkforms)
    (while keys
      (let ((key (pop keys))
            (def (pop keys)))
        (if (keywordp key)
            (when (memq key '(:prefix :infix))
              (setq prefix def))
          (when prefix
            (setq key `(general--concat t ,prefix ,key)))
          (let* ((udef (cdr-safe (doom-unquote def)))
                 (bdef (if (general--extended-def-p udef)
                           (general--extract-def (general--normalize-extended-def udef))
                         def)))
            (unless (eq bdef :ignore)
              (push `(define-key doom-leader-map (general--kbd ,key)
                       ,bdef)
                    forms))
            (when-let* ((desc (cadr (memq :which-key udef))))
              (cl-callf2 append
                  `((which-key-add-key-based-replacements
                      (general--concat t doom-leader-alt-key ,key)
                      ,desc)
                    (which-key-add-key-based-replacements
                      (general--concat t doom-leader-key ,key)
                      ,desc))
                  wkforms))))))
    (macroexp-progn
     (append (and wkforms `((after! which-key ,@(nreverse wkforms))))
             (nreverse forms)))))

(defmacro define-leader-key! (&rest args)
  "Define <leader> keys.

Uses `general-define-key' under the hood, but does not support :states,
:wk-full-keys or :keymaps. Use `map!' for a more convenient interface.

See `doom-leader-key' and `doom-leader-alt-key' to change the leader prefix."
  `(general-define-key
    :states nil
    :wk-full-keys nil
    :keymaps 'doom-leader-map
    ,@args))

(defmacro define-localleader-key! (&rest args)
  "Define <localleader> key.

Uses `general-define-key' under the hood, but does not support :major-modes,
:states, :prefix or :non-normal-prefix. Use `map!' for a more convenient
interface.

See `doom-localleader-key' and `doom-localleader-alt-key' to change the
localleader prefix."
  (if (modulep! :editor evil)
      ;; :non-normal-prefix doesn't apply to non-evil sessions (only evil's
      ;; emacs state)
      `(general-define-key
        :states '(normal visual motion emacs insert)
        :major-modes t
        :prefix doom-localleader-key
        :non-normal-prefix doom-localleader-alt-key
        ,@args)
    `(general-define-key
      :major-modes t
      :prefix doom-localleader-alt-key
      ,@args)))

;; PERF: We use a prefix commands instead of general's
;;   :prefix/:non-normal-prefix properties because general is incredibly slow
;;   binding keys en mass with them in conjunction with :states -- an effective
;;   doubling of Doom's startup time!
(define-prefix-command 'doom/leader 'doom-leader-map)
(define-key doom-leader-map [override-state] 'all)

;; Bind `doom-leader-key' and `doom-leader-alt-key' as late as possible to give
;; the user a chance to modify them.
(add-hook! 'doom-after-init-hook
  (defun doom-init-leader-keys-h ()
    "Bind `doom-leader-key' and `doom-leader-alt-key'."
    (let ((map general-override-mode-map))
      (if (not (featurep 'evil))
          (progn
            (cond ((equal doom-leader-alt-key "C-c")
                   (set-keymap-parent doom-leader-map mode-specific-map))
                  ((equal doom-leader-alt-key "C-x")
                   (set-keymap-parent doom-leader-map ctl-x-map)))
            (define-key map (kbd doom-leader-alt-key) 'doom/leader))
        (evil-define-key* doom-leader-key-states map (kbd doom-leader-key) 'doom/leader)
        (evil-define-key* doom-leader-alt-key-states map (kbd doom-leader-alt-key) 'doom/leader))
      (general-override-mode +1))))

(use-package! which-key
  :hook (doom-first-input . which-key-mode)
  :init
  (setq which-key-sort-order #'which-key-key-order-alpha
        which-key-sort-uppercase-first nil
        which-key-add-column-padding 1
        which-key-max-display-columns nil
        which-key-min-display-lines 6
        which-key-side-window-slot -10)
  :config
  (put 'which-key-replacement-alist 'initial-value which-key-replacement-alist)
  (add-hook! 'doom-before-reload-hook
    (defun doom-reset-which-key-replacements-h ()
      (setq which-key-replacement-alist (get 'which-key-replacement-alist 'initial-value))))
  ;; general improvements to which-key readability
  (which-key-setup-side-window-bottom)
  (setq-hook! 'which-key-init-buffer-hook line-spacing 3)

  (which-key-add-key-based-replacements doom-leader-key "<leader>")
  (which-key-add-key-based-replacements doom-localleader-key "<localleader>"))


;;; ** `map!' macro

(defvar doom-evil-state-alist
  '((?n . normal)
    (?v . visual)
    (?i . insert)
    (?e . emacs)
    (?o . operator)
    (?m . motion)
    (?r . replace)
    (?g . global))
  "A list of cons cells that map a letter to a evil state symbol.")

(defun doom--map-keyword-to-states (keyword)
  "Convert a KEYWORD into a list of evil state symbols.

For example, :nvi will map to (list \\='normal \\='visual \\='insert). See
`doom-evil-state-alist' to customize this."
  (cl-loop for l across (doom-keyword-name keyword)
           if (assq l doom-evil-state-alist) collect (cdr it)
           else do (error "not a valid state: %s" l)))


;; specials
(defvar doom--map-forms nil)
(defvar doom--map-fn nil)
(defvar doom--map-batch-forms nil)
(defvar doom--map-state '(:dummy t))
(defvar doom--map-parent-state nil)
(defvar doom--map-evil-p nil)
(after! evil (setq doom--map-evil-p t))

(defun doom--map-process (rest)
  (let ((doom--map-fn doom--map-fn)
        doom--map-state
        doom--map-forms
        desc)
    (while rest
      (let ((key (pop rest)))
        (cond ((listp key)
               (doom--map-nested nil key))

              ((keywordp key)
               (pcase key
                 (:leader
                  (doom--map-commit)
                  (setq doom--map-fn 'doom--define-leader-key))
                 (:localleader
                  (doom--map-commit)
                  (setq doom--map-fn 'define-localleader-key!))
                 (:after
                  (doom--map-nested (list 'after! (pop rest)) rest)
                  (setq rest nil))
                 (:desc
                  (setq desc (pop rest)))
                 (:map
                  (doom--map-set :keymaps `(backquote ,(ensure-list (pop rest)))))
                 (:mode
                  (push (cl-loop for m in (ensure-list (pop rest))
                                 collect (intern (concat (symbol-name m) "-map")))
                        rest)
                  (push :map rest))
                 ((or :when :unless)
                  (doom--map-nested (list (intern (doom-keyword-name key)) (pop rest)) rest)
                  (setq rest nil))
                 (:prefix-map
                  (cl-destructuring-bind (prefix . desc)
                      (let ((arg (pop rest)))
                        (if (consp arg) arg (list arg)))
                    (let ((keymap (intern (format "doom-leader-%s-map" desc))))
                      (setq rest
                            (append (list :desc desc prefix keymap
                                          :prefix prefix)
                                    rest))
                      (push `(defvar ,keymap (make-sparse-keymap))
                            doom--map-forms))))
                 (:prefix
                  (cl-destructuring-bind (prefix . desc)
                      (let ((arg (pop rest)))
                        (if (consp arg) arg (list arg)))
                    (doom--map-set (if doom--map-fn :infix :prefix)
                                   prefix)
                    (when (stringp desc)
                      (setq rest (append (list :desc desc "" nil) rest)))))
                 (:textobj
                  (let* ((key (pop rest))
                         (inner (pop rest))
                         (outer (pop rest)))
                    (push `(map! (:map evil-inner-text-objects-map ,key ,inner)
                                 (:map evil-outer-text-objects-map ,key ,outer))
                          doom--map-forms)))
                 (_
                  (condition-case _
                      (doom--map-def (pop rest) (pop rest)
                                     (doom--map-keyword-to-states key)
                                     desc)
                    (error
                     (error "Not a valid `map!' property: %s" key)))
                  (setq desc nil))))

              ((doom--map-def key (pop rest) nil desc)
               (setq desc nil)))))

    (doom--map-commit)
    (macroexp-progn (nreverse (delq nil doom--map-forms)))))

(defun doom--map-append-keys (prop)
  (let ((a (plist-get doom--map-parent-state prop))
        (b (plist-get doom--map-state prop)))
    (if (and a b)
        `(general--concat t ,a ,b)
      (or a b))))

(defun doom--map-nested (wrapper rest)
  (doom--map-commit)
  (let ((doom--map-parent-state (doom--map-state)))
    (push (if wrapper
              (append wrapper (list (doom--map-process rest)))
            (doom--map-process rest))
          doom--map-forms)))

(defun doom--map-set (prop &optional value)
  (unless (equal (plist-get doom--map-state prop) value)
    (doom--map-commit))
  (setq doom--map-state (plist-put doom--map-state prop value)))

(defun doom--map-def (key def &optional states desc)
  (when (or (memq 'global states)
            (null states))
    (setq states (cons 'nil (delq 'global states))))
  (when desc
    (let (unquoted)
      (cond ((and (listp def)
                  (keywordp (car-safe (setq unquoted (doom-unquote def)))))
             (setq def (list 'quote (plist-put unquoted :which-key desc))))
            ((setq def (cons 'list
                             (if (and (equal key "")
                                      (null def))
                                 `(:ignore t :which-key ,desc)
                               (plist-put (general--normalize-extended-def def)
                                          :which-key desc))))))))
  (dolist (state states)
    (push (list key def)
          (alist-get state doom--map-batch-forms)))
  t)

(defun doom--map-commit ()
  (when doom--map-batch-forms
    (cl-loop with attrs = (doom--map-state)
             for (state . defs) in doom--map-batch-forms
             if (or doom--map-evil-p (not state))
             collect `(,(or doom--map-fn 'general-define-key)
                       ,@(if state `(:states ',state)) ,@attrs
                       ,@(mapcan #'identity (nreverse defs)))
             into forms
             finally do (push (macroexp-progn forms) doom--map-forms))
    (setq doom--map-batch-forms nil)))

(defun doom--map-state ()
  (let ((plist
         (append (list :prefix (doom--map-append-keys :prefix)
                       :infix  (doom--map-append-keys :infix)
                       :keymaps
                       (append (plist-get doom--map-parent-state :keymaps)
                               (plist-get doom--map-state :keymaps)))
                 doom--map-state
                 nil))
        newplist)
    (while plist
      (let ((key (pop plist))
            (val (pop plist)))
        (when (and val (not (plist-member newplist key)))
          (push val newplist)
          (push key newplist))))
    newplist))

(defmacro map! (&rest rest)
  "A convenience macro for defining keybinds, powered by `general'.

If evil isn't loaded, evil-specific bindings are ignored.

Properties
  :leader [...]                   an alias for (:prefix doom-leader-key ...)
  :localleader [...]              bind to localleader; requires a keymap
  :mode [MODE(s)] [...]           inner keybinds are applied to major MODE(s)
  :map [KEYMAP(s)] [...]          inner keybinds are applied to KEYMAP(S)
  :prefix [PREFIX] [...]          set keybind prefix for following keys. PREFIX
                                  can be a cons cell: (PREFIX . DESCRIPTION)
  :prefix-map [PREFIX] [...]      same as :prefix, but defines a prefix keymap
                                  where the following keys will be bound. DO NOT
                                  USE THIS IN YOUR PRIVATE CONFIG.
  :after [FEATURE] [...]          apply keybinds when [FEATURE] loads
  :textobj KEY INNER-FN OUTER-FN  define a text object keybind pair
  :when [CONDITION] [...]
  :unless [CONDITION] [...]

  Any of the above properties may be nested, so that they only apply to a
  certain group of keybinds.

States
  :n  normal
  :v  visual
  :i  insert
  :e  emacs
  :o  operator
  :m  motion
  :r  replace
  :g  global  (binds the key without evil `current-global-map')

  These can be combined in any order, e.g. :nvi will apply to normal, visual and
  insert mode. The state resets after the following key=>def pair. If states are
  omitted the keybind will be global (no emacs state; this is different from
  evil's Emacs state and will work in the absence of `evil-mode').

  These must be placed right before the key string.

  Do
    (map! :leader :desc \"Description\" :n \"C-c\" \\=#'dosomething)
  Don't
    (map! :n :leader :desc \"Description\" \"C-c\" \\=#'dosomething)
    (map! :leader :n :desc \"Description\" \"C-c\" \\=#'dosomething)"
  (when (or (bound-and-true-p byte-compile-current-file)
            (not noninteractive))
    (doom--map-process rest)))


;;; ** Switch {buffer,frame,window} hooks

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
;;; ** kill-current-buffer advice

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
;;; * Built-in packages

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


;; Hide mode-line and line numbers in completion popups and MAN pages because
;; they serve little purpose there and only take up space.
(add-hook! '(Man-mode-hook completion-list-mode-hook) #'mode-line-invisible-mode)
(add-hook! '(Man-mode-hook completion-list-mode-hook) #'doom-disable-line-numbers-h)


;;; ** Theme & font loaders

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
      (push (copy-sequence custom-enabled-themes) (get 'doom-theme 'history))
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


;;; doom-projects

(define-obsolete-variable-alias 'doom-projectile-fd-binary 'doom-fd-executable "2.1.0")
(defvar doom-fd-executable (cl-find-if #'executable-find (list "fdfind" "fd"))
  "The filename of the fd executable.

On some distros it's fdfind (ubuntu, debian, and derivatives). On most it's fd.
Is nil if no executable is found in your PATH during startup.")

(defvar doom-ripgrep-executable (executable-find "rg")
  "The filename of the Ripgrep executable.

Is nil if no executable is found in your PATH during startup.")

(defvar doom-project-cache-dir (file-name-concat doom-profile-cache-dir "projectile/")
  "The directory where per-project projectile file index caches are stored.

Must end with a slash.")


;;
;;; Packages

(use-package! project
  :defer t
  :init
  (setq project-list-file (file-name-concat doom-profile-state-dir "projects"))
  :config
  ;; Not valid vc backends, but I use it to inform (global) file index
  ;; exclusions below and elsewhere.
  (add-to-list 'project-vc-backend-markers-alist '(Jujutsu . ".jj"))
  (add-to-list 'project-vc-backend-markers-alist '(Sapling . ".sl"))
  (add-to-list 'project-vc-extra-root-markers ".jj")

  ;; TODO: Advice or add command for project-wide `find-sibling-file'.
  )


;; DEPRECATED: Will be replaced with project.el
(use-package! projectile
  :commands (projectile-project-root
             projectile-project-name
             projectile-project-p
             projectile-locate-dominating-file
             projectile-relevant-known-projects)
  :init
  (setq projectile-enable-caching (if noninteractive t 'persistent)
        projectile-globally-ignored-files '(".DS_Store" "TAGS")
        projectile-globally-ignored-file-suffixes '(".elc" ".pyc" ".o")
        projectile-kill-buffers-filter 'kill-only-files
        projectile-ignored-projects '("~/")
        projectile-known-projects-file (file-name-concat doom-project-cache-dir "projects.eld")
        projectile-ignored-project-function #'doom-project-ignored-p
        projectile-fd-executable doom-fd-executable)

  (global-set-key [remap evil-jump-to-tag] #'projectile-find-tag)
  (global-set-key [remap find-tag]         #'projectile-find-tag)

  :config
  (make-directory doom-project-cache-dir t)

  ;; Projectile runs four functions to determine the root (in this order):
  ;;
  ;; + `projectile-root-local' -> checks the `projectile-project-root' variable
  ;;    for an explicit path.
  ;; + `projectile-root-bottom-up' -> searches from / to your current directory
  ;;   for the paths listed in `projectile-project-root-files-bottom-up'. This
  ;;   includes .git and .project
  ;; + `projectile-root-top-down' -> searches from the current directory down to
  ;;   / the paths listed in `projectile-root-files', like package.json,
  ;;   setup.py, or Cargo.toml
  ;; + `projectile-root-top-down-recurring' -> searches from the current
  ;;   directory down to / for a directory that has one of
  ;;   `projectile-project-root-files-top-down-recurring' but doesn't have a
  ;;   parent directory with the same file.
  ;;
  ;; In the interest of performance, we reduce the number of project root marker
  ;; files/directories projectile searches for when resolving the project root.
  ;;
  ;; These will be filled by other modules. We build this list manually so
  ;; projectile doesn't perform so many file checks every time it resolves a
  ;; project's root -- particularly when a file has no project.
  (setq projectile-project-root-files '()
        projectile-project-root-files-top-down-recurring '("Makefile"))

  ;; Adds a more editor/plugin-agnostic project marker.
  (add-to-list 'projectile-project-root-files-bottom-up ".project")

  (push (abbreviate-file-name doom-local-dir) projectile-globally-ignored-directories)

  ;; Per-project compilation buffers
  (setq compilation-buffer-name-function #'projectile-compilation-buffer-name
        compilation-save-buffers-predicate #'projectile-current-project-buffer-p)

  ;; HACK: Centralize Projectile's per-project cache files, so they don't litter
  ;;   projects with dotfiles.
  (defadvice! doom--projectile-centralized-cache-files-a (fn &optional proot)
    :around #'projectile-project-cache-file
    (let* ((proot (or proot (doom-project-root) default-directory))
           (projectile-cache-file
            (expand-file-name
             (format "%s-%s" (doom-project-name proot) (sha1 proot))
             doom-project-cache-dir)))
      (funcall fn proot)))

  ;; HACK: `projectile-ensure-project' operates on the current value of
  ;;   `projectile-known-projects' when prompting the using for a project, which
  ;;   may not have been initialized yet, so do so the first time it is called.
  ;; REVIEW: PR this upstream
  (defadvice! doom--projectile-update-known-projects-a (dir)
    :before #'projectile-ensure-project
    (unless dir
      (when (and (eq projectile-require-project-root 'prompt)
                 (not projectile-known-projects))
        (projectile-known-projects))
      (advice-remove 'projectile-ensure-project #'doom--projectile-update-known-projects-a)))

  ;; Support the more generic .project files as an alternative to .projectile
  (defadvice! doom--projectile-dirconfig-file-a ()
    :override #'projectile-dirconfig-file
    (let ((proot (projectile-project-root)))
      (cond ((file-exists-p! (or projectile-dirconfig-file ".project") proot))
            ((expand-file-name ".project" proot)))))

  ;; HACK: `projectile-files-to-ensure' binds `default-directory' to the result
  ;;   of `projectile-project-root', which returns nil when called from a buffer
  ;;   outside of a project, poisoning the entire downstream call chain with a
  ;;   wrong-type-argument error.
  ;; REVIEW: Remove if/when resolved upstream.
  (defadvice! doom--projectile-files-to-ensure-a ()
    :override #'projectile-files-to-ensure
    (let ((default-directory (or (projectile-project-root) default-directory)))
      (flatten-tree (mapcar #'file-expand-wildcards
                            (projectile-patterns-to-ensure)))))

  ;; Disable commands that won't work, as is, and that Doom already provides a
  ;; better alternative for.
  (put 'projectile-ag 'disabled "Use +default/search-project instead")
  (put 'projectile-ripgrep 'disabled "Use +default/search-project instead")
  (put 'projectile-grep 'disabled "Use +default/search-project instead")

  ;; HACK: Some MSYS utilities auto expanded the `/' path separator, so we need
  ;;   to prevent it.
  (when doom--system-windows-p
    (setenv "MSYS_NO_PATHCONV" "1") ; Fix path in Git Bash
    (setenv "MSYS2_ARG_CONV_EXCL" "--path-separator")) ; Fix path in MSYS2

  ;; HACK: Don't rely on VCS-specific commands to generate our file lists.
  ;;   That's 7 commands to maintain, versus the more generic, reliable, and
  ;;   performant `fd' or `ripgrep'.
  (defadvice! doom--only-use-generic-command-a (fn vcs &optional directory)
    "Only use `projectile-generic-command' for indexing project files.
And if it's a function, evaluate it."
    :around #'projectile-get-ext-command
    (let ((default-directory (or directory default-directory)))
      (if (and (functionp projectile-generic-command)
               (not (file-remote-p default-directory)))
          (funcall projectile-generic-command vcs)
        (let ((projectile-git-submodule-command
               (or projectile-git-submodule-command
                   (get 'projectile-git-submodule-command 'initial-value))))
          (funcall fn vcs)))))

  ;; HACK: `projectile-generic-command' doesn't typically support a function,
  ;;   but my `doom--only-use-generic-command-a' advice allows this. I do it
  ;;   this way to make it easier for folks to undo the change (if not set to a
  ;;   function, projectile will revert to default behavior).
  (put 'projectile-git-submodule-command 'initial-value projectile-git-submodule-command)
  (setq projectile-git-submodule-command nil
        ;; Include and follow symlinks in file listings.
        projectile-git-fd-args (concat "-tl " projectile-git-fd-args)
        projectile-indexing-method 'hybrid
        projectile-generic-command
        (lambda (_)
          ;; If fd or ripgrep exists, use it to produce file listings for
          ;; projectile commands. fd is a rust program that is significantly
          ;; faster than git ls-files, find, or the various VCS commands
          ;; projectile is configured to use. Plus, it respects .gitignore.
          (cond
           ((when-let*
                ((doom-fd-executable)
                 (projectile-git-use-fd)
                 ;; REVIEW: Temporary fix for #6618. Improve me later.
                 (version (with-memoization (get 'doom-fd-executable 'version)
                            (cadr (split-string (cdr (doom-call-process doom-fd-executable "--version"))
                                                " " t))))
                 ((ignore-errors (version-to-list version))))
              (string-join
               (delq
                nil (list doom-fd-executable "."
                          (if (version< version "8.3.0")
                              (replace-regexp-in-string "--strip-cwd-prefix" "" projectile-git-fd-args t t)
                            projectile-git-fd-args)
                          (when project-vc-backend-markers-alist
                            (mapconcat (fn! (format "-E %s" (shell-quote-argument (cdr %))))
                                       project-vc-backend-markers-alist
                                       " "))
                          (if doom--system-windows-p " --path-separator=/" "")))
               " ")))
           ;; Otherwise, resort to ripgrep, which is also faster than find
           (doom-ripgrep-executable
            (string-join
             (delq
              nil (list doom-ripgrep-executable
                        "-0 --files --follow --color=never --hidden"
                        (when project-vc-backend-markers-alist
                          (mapconcat (fn! (format "-g!%s" (shell-quote-argument (cdr %))))
                                     project-vc-backend-markers-alist
                                     " "))
                        (if doom--system-windows-p " --path-separator=/")))
             " "))
           ((not doom--system-windows-p) "find . -type f | cut -c3- | tr '\\n' '\\0'")
           ("find . -type f -print0"))))

  (defadvice! doom--projectile-default-generic-command-a (fn &rest args)
    "If projectile can't tell what kind of project you're in, it issues an error
when using many of projectile's command, e.g. `projectile-compile-command',
`projectile-run-project', `projectile-test-project', and
`projectile-configure-project', for instance.

This suppresses the error so these commands will still run, but prompt you for
the command instead."
    :around #'projectile-default-generic-command
    (ignore-errors (apply fn args)))

  (projectile-mode +1))


;;
;;; Project-based minor modes

(defvar doom-project-hook nil
  "Hook run when a project is enabled. The name of the project's mode and its
state are passed in.")

(cl-defmacro def-project-mode! (name &key
                                     modes
                                     files
                                     when
                                     match
                                     add-hooks
                                     on-load
                                     on-enter
                                     on-exit)
  "Define a project minor mode named NAME and where/how it is activated.

Project modes allow you to configure \\='sub-modes' for major-modes that are
specific to a folder, project structure, framework or whatever arbitrary context
you define. These project modes can have their own settings, keymaps, hooks,
snippets, etc.

This creates NAME-hook and NAME-map as well.

PLIST may contain any of these properties, which are all checked to see if NAME
should be activated. If they are *all* true, NAME is activated.

  :modes MODES -- if buffers are derived from MODES (one or a list of symbols).

  :files FILES -- if project contains FILES; takes a string or a form comprised
    of nested (and ...) and/or (or ...) forms. Each path is relative to the
    project root, however, if prefixed with a '.' or '..', it is relative to the
    current buffer.

  :match REGEXP -- if file name matches REGEXP

  :when PREDICATE -- if PREDICATE returns true (can be a form or the symbol of a
    function)

  :add-hooks HOOKS -- HOOKS is a list of hooks to add this mode's hook.

  :on-load FORM -- FORM to run the first time this project mode is enabled.

  :on-enter FORM -- FORM is run each time the mode is activated.

  :on-exit FORM -- FORM is run each time the mode is disabled.

Relevant: `doom-project-hook'."
  (declare (indent 1))
  (let ((init-var (intern (format "%s-init" name))))
    (macroexp-progn
     (append
      (when on-load
        `((defvar ,init-var nil)))
      `((define-minor-mode ,name
          "A project minor mode generated by `def-project-mode!'."
          :init-value nil
          :lighter ""
          :keymap (make-sparse-keymap)
          (if (not ,name)
              ,on-exit
            (run-hook-with-args 'doom-project-hook ',name ,name)
            ,(when on-load
               `(unless ,init-var
                  ,on-load
                  (setq ,init-var t)))
            ,on-enter))
        (dolist (hook ,add-hooks)
          (add-hook ',(intern (format "%s-hook" name)) hook)))
      (cond ((or files modes when)
             (cl-check-type files (or null list string))
             (let ((fn
                    `(lambda ()
                       (and (not (bound-and-true-p ,name))
                            (and buffer-file-name (not (file-remote-p buffer-file-name nil t)))
                            ,(or (null match)
                                 `(if buffer-file-name (string-match-p ,match buffer-file-name)))
                            ,(or (null files)
                                 ;; Wrap this in `eval' to prevent eager expansion
                                 ;; of `project-file-exists-p!' from pulling in
                                 ;; autoloaded files prematurely.
                                 `(eval
                                   '(project-file-exists-p!
                                     ,(if (stringp (car files)) (cons 'and files) files))))
                            ,(or when t)
                            (,name 1)))))
               (if modes
                   `((dolist (mode ,modes)
                       (let ((hook-name
                              (intern (format "doom--enable-%s%s-h" ',name
                                              (if (eq mode t) "" (format "-in-%s" mode))))))
                         (fset hook-name #',fn)
                         (if (eq mode t)
                             (add-to-list 'auto-minor-mode-magic-alist (cons hook-name #',name))
                           (add-hook (intern (format "%s-hook" mode)) hook-name)))))
                 `((add-hook 'change-major-mode-after-body-hook #',fn)))))
            (match
             `((add-to-list 'auto-minor-mode-alist (cons ,match #',name)))))))))


;;; doom-editor


;;
;;; File handling

;; Resolve symlinks when opening files, so that any operations are conducted
;; from the file's true directory (like `find-file').
(setq find-file-visit-truename t
      vc-follow-symlinks t)

;; Disable the warning "X and Y are the same file". It's fine to ignore this
;; warning as it will redirect you to the existing buffer anyway.
(setq find-file-suppress-same-file-warnings t)

;; Create missing directories when we open a file that doesn't exist under a
;; directory tree that may not exist.
(add-hook! 'find-file-not-found-functions
  (defun doom-create-missing-directories-h ()
    "Automatically create missing directories when creating new files."
    (unless (file-remote-p buffer-file-name)
      (let ((parent-directory (file-name-directory buffer-file-name)))
        (and (not (file-directory-p parent-directory))
             (y-or-n-p (format "Directory `%s' does not exist! Create it?"
                               parent-directory))
             (progn (make-directory parent-directory 'parents)
                    t))))))

;; Don't generate backups or lockfiles. While auto-save maintains a copy so long
;; as a buffer is unsaved, backups create copies once, when the file is first
;; written, and never again until it is killed and reopened. This is better
;; suited to version control, and I don't want world-readable copies of
;; potentially sensitive material floating around our filesystem.
(setq create-lockfiles nil
      make-backup-files nil
      ;; But in case the user does enable it, some sensible defaults:
      version-control t     ; number each backup file
      backup-by-copying t   ; instead of renaming current file (clobbers links)
      delete-old-versions t ; clean up after itself
      kept-old-versions 5
      kept-new-versions 5
      backup-directory-alist `(("." . ,(file-name-concat doom-profile-cache-dir "backup/")))
      tramp-backup-directory-alist backup-directory-alist)

;; But turn on auto-save, so we have a fallback in case of crashes or lost data.
;; Use `recover-file' or `recover-session' to recover them.
(setq auto-save-default t
      ;; Don't auto-disable auto-save after deleting big chunks. This defeats
      ;; the purpose of a failsafe. This adds the risk of losing the data we
      ;; just deleted, but I believe that's VCS's jurisdiction, not ours.
      auto-save-include-big-deletions t
      ;; Keep it out of `doom-emacs-dir' or the local directory.
      auto-save-list-file-prefix (file-name-concat doom-profile-cache-dir "autosave/")
      ;; This resolves two issue while ensuring auto-save files are still
      ;; reasonably recognizable at a glance:
      ;;
      ;; 1. Emacs generates long file paths for its auto-save files; long =
      ;;    `auto-save-list-file-prefix' + `buffer-file-name'. If too long, some
      ;;    filesystems (*cough*Windows) will murder your family. `sha1'
      ;;    compresses the path into a ~40 character hash (Emacs 28+ only)!
      ;; 2. The default transform rule writes TRAMP auto-save files to
      ;;    `temporary-file-directory', which TRAMP doesn't like! It'll prompt
      ;;    you about it every time an auto-save file is written, unless
      ;;    `tramp-allow-unsafe-temporary-files' is set. A more sensible default
      ;;    transform is better:
      auto-save-file-name-transforms
      `(("\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
         ,(file-name-concat auto-save-list-file-prefix "tramp-\\2-") sha1)
        ("\\`/\\([^/]+/\\)*\\([^/]+\\)\\'"
         ,(file-name-concat auto-save-list-file-prefix "\\2-") sha1)))

(add-hook! 'auto-save-hook
  (defun doom-ensure-auto-save-prefix-exists-h ()
    (with-file-modes #o700
      (make-directory auto-save-list-file-prefix t))))

(add-hook! 'after-save-hook
  (defun doom-guess-mode-h ()
    "Guess major mode when saving a file in `fundamental-mode'.

Likely, something has changed since the buffer was opened. e.g. A shebang line
or file path may exist now."
    (when (eq major-mode 'fundamental-mode)
      (let ((buffer (or (buffer-base-buffer) (current-buffer))))
        (and (buffer-file-name buffer)
             (eq buffer (window-buffer (selected-window))) ; only visible buffers
             (set-auto-mode)
             (not (eq major-mode 'fundamental-mode)))))))

(defadvice! doom--shut-up-autosave-a (fn &rest args)
  "If a file has autosaved data, `after-find-file' will pause for 1 second to
tell you about it. Very annoying. This prevents that."
  :around #'after-find-file
  (letf! ((#'sit-for #'ignore))
    (apply fn args)))

;; HACK: Make sure backup files (like undo-tree's) don't have ridiculously long
;;   file names that some filesystems will refuse.
;; REVIEW: PR this upstream, like they have with the UNIQUIFY argument in
;;   `auto-save-file-name-transforms' entries.
(defadvice! doom-make-hashed-backup-file-name-a (fn file)
  "A few places use the backup file name so paths don't get too long."
  :around #'make-backup-file-name-1
  (let ((alist backup-directory-alist)
        backup-directory)
    (while alist
      (let ((elt (car alist)))
        (if (string-match (car elt) file)
            (setq backup-directory (cdr elt)
                  alist nil)
          (setq alist (cdr alist)))))
    (let ((file (funcall fn file)))
      (if (or (null backup-directory)
              (not (file-name-absolute-p backup-directory)))
          file
        (expand-file-name (sha1 (file-name-nondirectory file))
                          (file-name-directory file))))))


;;
;;; Formatting

;; Favor spaces over tabs. Pls dun h8, but I think spaces (and 4 of them) is a
;; more consistent default than 8-space tabs. It can be changed on a per-mode
;; basis anyway (and is, where tabs are the canonical style, like `go-mode').
(setq-default indent-tabs-mode nil
              tab-width 4)

;; Only indent the line when at BOL or in a line's indentation. Anywhere else,
;; insert literal indentation.
(setq-default tab-always-indent nil)

;; Make `tabify' and `untabify' only affect indentation. Not tabs/spaces in the
;; middle of a line.
(setq tabify-regexp "^\t* [ \t]+")

;; An archaic default in the age of widescreen 4k displays? I disagree. We still
;; frequently split our terminals and editor frames, or have them side-by-side,
;; using up more of that newly available horizontal real-estate.
(setq-default fill-column 80)

;; Continue wrapped words at whitespace, rather than in the middle of a word.
(setq-default word-wrap t)
;; ...but don't do any wrapping by default. It's expensive. Enable
;; `visual-line-mode' if you want soft line-wrapping. `auto-fill-mode' for hard
;; line-wrapping.
(setq-default truncate-lines t)
;; If enabled (and `truncate-lines' was disabled), soft wrapping no longer
;; occurs when that window is less than `truncate-partial-width-windows'
;; characters wide. We don't need this, and it's extra work for Emacs otherwise,
;; so off it goes.
(setq truncate-partial-width-windows nil)

;; This was a widespread practice in the days of typewriters. I actually prefer
;; it when writing prose with monospace fonts, but it is obsolete otherwise.
(setq sentence-end-double-space nil)

;; The POSIX standard defines a line is "a sequence of zero or more non-newline
;; characters followed by a terminating newline", so files should end in a
;; newline. Windows doesn't respect this (because it's Windows), but we should,
;; since programmers' tools tend to be POSIX compliant (and no big deal if not).
(setq require-final-newline t)

;; Default to soft line-wrapping in text modes. It is more sensibile for text
;; modes, even if hard wrapping is more performant.
(add-hook 'text-mode-hook #'visual-line-mode)


;;; ** Clipboard / kill-ring

;; Cull duplicates in the kill ring to reduce bloat and make the kill ring
;; easier to peruse (with `counsel-yank-pop' or `helm-show-kill-ring'.
(setq kill-do-not-save-duplicates t)


;;; ** Extra file extensions to support

(add-to-list 'auto-mode-alist '("/LICENSE\\'" . text-mode))
(add-to-list 'auto-mode-alist '("rc\\'" . conf-mode) 'append)


;;; * Built-in packages

(use-package! autorevert
  ;; revert buffers when their files/state have changed
  :hook (doom-first-file . doom-auto-revert-mode)
  :config
  (setq auto-revert-verbose t ; let us know when it happens
        auto-revert-use-notify nil
        auto-revert-stop-on-user-input nil
        ;; Only prompts for confirmation when buffer is unsaved.
        revert-without-query (list "."))

  ;; PERF: `auto-revert-mode' and `global-auto-revert-mode' would, normally,
  ;;   abuse the heck out of file watchers _or_ aggressively poll your buffer
  ;;   list every X seconds. Too many watchers can grind Emacs to a halt if you
  ;;   preform expensive or batch processes on files outside of Emacs (e.g.
  ;;   their mtime changes), and polling your buffer list is terribly
  ;;   inefficient as your buffer list grows into the hundreds.
  ;;
  ;;   Doom does this lazily instead. i.e. All visible buffers are reverted
  ;;   immediately when a) a file is saved or b) Emacs is refocused (after using
  ;;   another app). Meanwhile, buried buffers are reverted only when they are
  ;;   switched to. This way, Emacs only ever has to operate on, at minimum, a
  ;;   single buffer and, at maximum, ~10 x F buffers, where F = number of open
  ;;   frames (after all, when do you ever have more than 10 windows in any
  ;;   single frame?).
  (define-minor-mode doom-auto-revert-mode
    "A more performant alternative to `global-auto-revert-mode'."
    :global t
    :group 'doom
    (when global-auto-revert-mode
      (setq doom-auto-revert-mode nil))
    (let ((fn (if doom-auto-revert-mode #'add-hook #'remove-hook)))
      (funcall fn 'doom-switch-buffer-hook #'doom-auto-revert-buffer-h)
      (funcall fn 'doom-switch-window-hook #'doom-auto-revert-buffer-h)
      (funcall fn 'doom-switch-frame-hook #'doom-auto-revert-buffers-h)
      (funcall fn 'after-save-hook #'doom-auto-revert-buffers-h)))

  (defun doom-auto-revert-buffer-h ()
    "Auto revert current buffer, if necessary."
    (unless (or auto-revert-mode
                (active-minibuffer-window)
                (and buffer-file-name
                     auto-revert-remote-files
                     (file-remote-p buffer-file-name nil t)))
      (let ((auto-revert-mode t))
        (auto-revert-handler))))

  (defun doom-auto-revert-buffers-h ()
    "Auto revert stale buffers in visible windows, if necessary."
    (dolist (buf (doom-visible-buffers))
      (with-current-buffer buf
        (doom-auto-revert-buffer-h)))))


;;;###package bookmark
(setq bookmark-default-file (file-name-concat doom-profile-data-dir "bookmarks"))


;;;###package ffap
;; REVIEW: This is already the default as of 30.2, but it defaults to `ping' on
;;   older versions of Emacs.
(setq ffap-machine-p-known 'accept) ; don't ping domains


(use-package! recentf
  ;; Keep track of recently opened files
  :defer-incrementally easymenu tree-widget timer
  :hook (doom-first-file . recentf-mode)
  :commands recentf-open-files
  :custom (recentf-save-file (file-name-concat doom-profile-cache-dir "recentf"))
  :config
  (setq recentf-max-saved-items 200) ; default is 20

  ;; Anything in runtime folders
  (add-to-list 'recentf-exclude
               (concat "^" (regexp-quote (or (getenv "XDG_RUNTIME_DIR")
                                             "/run"))))

  ;; PERF: Text properties inflate the size of recentf's files, and there is no
  ;;   reason to persist them (must be first in `recentf-filename-handlers'!)
  (add-to-list 'recentf-filename-handlers #'substring-no-properties)

  ;; UX: Reorder the recent files list by frecency (i.e. every time you touch a
  ;;   buffer, bump it to the top of the list).
  (add-hook! '(doom-switch-window-hook write-file-functions)
    (defun doom--recentf-touch-buffer-h ()
      "Bump file in recent file list when it is switched or written to."
      (when buffer-file-name
        (recentf-add-file buffer-file-name))
      ;; Return nil for `write-file-functions'
      nil))
  (add-hook! 'dired-mode-hook
    (defun doom--recentf-add-dired-directory-h ()
      "Add dired directories to recentf file list."
      (recentf-add-file default-directory)))

  ;; The most sensible time to clean and save your recent files list is when you
  ;; quit Emacs (unless this is a long-running daemon session).
  (setq recentf-auto-cleanup 'never)
  (when (daemonp)
    (setq recentf-auto-cleanup 600
          recentf-autosave-interval 1200))
  ;; Use a negative depth value because we need `recentf-cleanup' to run before
  ;; `recentf-save-list' to be effective, which `recentf-mode' will only add to
  ;; `kill-emacs-hook' once it is enabled.
  (add-hook 'kill-emacs-hook #'recentf-cleanup -50)

  ;; Otherwise `load-file' calls in `recentf-load-list' pollute *Messages*
  (advice-add #'recentf-load-list :around #'doom-shut-up-a))


(use-package! savehist
  ;; persist variables across sessions
  :defer-incrementally custom
  :hook (doom-first-input . savehist-mode)
  :custom (savehist-file (file-name-concat doom-profile-cache-dir "savehist"))
  :config
  (setq savehist-save-minibuffer-history t
        savehist-autosave-interval nil     ; save on kill only
        savehist-additional-variables
        '(kill-ring                        ; persist clipboard
          register-alist                   ; persist macros
          mark-ring global-mark-ring       ; persist marks
          search-ring regexp-search-ring)) ; persist searches
  (add-hook! 'savehist-save-hook
    (defun doom-savehist-unpropertize-variables-h ()
      "Remove text properties from `kill-ring' to reduce savehist cache size."
      (setq kill-ring
            (mapcar #'substring-no-properties
                    (cl-remove-if-not #'stringp kill-ring))
            register-alist
            (cl-loop for (reg . item) in register-alist
                     if (stringp item)
                     collect (cons reg (substring-no-properties item))
                     else collect (cons reg item))))
    (defun doom-savehist-remove-unprintable-registers-h ()
      "Remove unwriteable registers (e.g. containing window configurations).
Otherwise, `savehist' would discard `register-alist' entirely if we don't omit
the unwritable tidbits."
      ;; Save new value in the temp buffer savehist is running
      ;; `savehist-save-hook' in. We don't want to actually remove the
      ;; unserializable registers in the current session!
      (setq-local register-alist
                  (cl-remove-if-not #'savehist-printable register-alist)))))


(use-package! saveplace
  ;; persistent point location in buffers
  :hook (doom-first-file . save-place-mode)
  :custom (save-place-file (file-name-concat doom-profile-cache-dir "saveplace"))
  :config
  (defadvice! doom--recenter-on-load-saveplace-a (&rest _)
    "Recenter on cursor when loading a saved place."
    :after-while #'save-place-find-file-hook
    (if buffer-file-name (ignore-errors (recenter))))

  (defadvice! doom--inhibit-saveplace-in-long-files-a (fn &rest args)
    :around #'save-place-to-alist
    (unless (bound-and-true-p so-long-minor-mode)
      (apply fn args)))

  (defadvice! doom--inhibit-saveplace-if-point-not-at-bol-a (&rest _)
    "If something else has moved point, don't try to move it again."
    :before-while #'save-place-find-file-hook
    (bobp))

  (defadvice! doom--dont-prettify-saveplace-cache-a (fn)
    "`save-place-alist-to-file' uses `pp' to prettify the contents of its cache.
`pp' can be expensive for longer lists, and there's no reason to prettify cache
files, so this replace calls to `pp' with the much faster `prin1'."
    :around #'save-place-alist-to-file
    (letf! ((#'pp #'prin1)) (funcall fn))))


(use-package! server
  :when (display-graphic-p)
  :after-call doom-first-input-hook doom-first-file-hook
  :defer 1
  :config
  (when-let* ((name (getenv "EMACS_SERVER_NAME")))
    (setq server-name name))
  (unless (server-running-p)
    (server-start)))


(use-package! so-long
  :when (fboundp 'buffer-line-statistics)  ; only 29+
  :hook (doom-first-file . global-so-long-mode)
  :config
  (unless (featurep 'native-compile)
    (setq so-long-threshold 5000))

  ;; HACK: I exploit so-long to implement a "large file" minor mode that
  ;;   activates if a file is too large or has lines whose width exceed
  ;;   `so-long-threshold' (particularly minified files), and disables
  ;;   non-essential functionality to speed Emacs up.
  (defun doom-so-long-p ()
    "A `so-long-predicate' to determine if the current buffer is too large.

This is determined by the longest line (whether it exceeds `so-long-threshold')
and whether the line count of the buffer exceeds that matching entry in
`doom-file-lines-threshold-alist' (defaulting to 20k lines)."
    (unless
        ;; HACK: Prevent so-long in places where we don't want it, like special
        ;;   buffers (e.g. magit status) or temp buffers.
        (or (doom-temp-buffer-p (current-buffer))
            (doom-special-buffer-p (current-buffer) t))
      (let ((stats (buffer-line-statistics)))
        (or (> (cadr stats) so-long-threshold)
            (and buffer-file-name
                 (when-let* ((maxlines
                              (assoc-default buffer-file-name doom-file-lines-threshold-alist
                                             #'string-match-p)))
                   (> (car stats) maxlines)))))))
  (setq so-long-predicate #'doom-so-long-p
        so-long-function #'turn-on-so-long-minor-mode
        so-long-revert-function #'turn-off-so-long-minor-mode)

  (add-to-list 'so-long-target-modes 'conf-mode)
  (add-to-list 'so-long-target-modes 'text-mode)

  ;; Don't disable syntax highlighting and line numbers, or make the buffer
  ;; read-only, in `so-long-minor-mode', so we can have a basic editing
  ;; experience in them, at least. It will remain off in `so-long-mode',
  ;; however, because long files have a far bigger impact on Emacs performance.
  (cl-callf2 delq 'font-lock-mode so-long-minor-modes)
  (cl-callf2 delq 'display-line-numbers-mode so-long-minor-modes)
  (setf (alist-get 'buffer-read-only so-long-variable-overrides nil t) nil)
  ;; ...but at least reduce the level of syntax highlighting
  (add-to-list 'so-long-variable-overrides '(font-lock-maximum-decoration . 1))
  ;; ...and insist that save-place not operate in large/long files
  (add-to-list 'so-long-variable-overrides '(save-place-alist . nil))
  ;; But disable everything else that may be unnecessary/expensive for large or
  ;; wide buffers.
  (cl-callf append so-long-minor-modes
    '(spell-fu-mode
      eldoc-mode
      better-jumper-local-mode
      ws-butler-mode
      auto-composition-mode
      undo-tree-mode
      highlight-indent-guides-mode
      hl-fill-column-mode
      ;; These are redundant on Emacs 29+
      flycheck-mode
      smartparens-mode
      smartparens-strict-mode)))


;;; * 3rd Party Packages

(use-package! better-jumper
  :hook (doom-first-input . better-jumper-mode)
  :commands doom-set-jump-a doom-set-jump-maybe-a doom-set-jump-h
  :init
  (global-set-key [remap evil-jump-forward]  #'better-jumper-jump-forward)
  (global-set-key [remap evil-jump-backward] #'better-jumper-jump-backward)
  (global-set-key [remap xref-pop-marker-stack] #'better-jumper-jump-backward)
  (global-set-key [remap xref-go-back] #'better-jumper-jump-backward)
  (global-set-key [remap xref-go-forward] #'better-jumper-jump-forward)
  :config
  (defun doom-set-jump-a (fn &rest args)
    "Set a jump point and ensure fn doesn't set any new jump points."
    (better-jumper-set-jump (if (markerp (car args)) (car args)))
    (let ((evil--jumps-jumping t)
          (better-jumper--jumping t))
      (apply fn args)))

  (defun doom-set-jump-maybe-a (fn &rest args)
    "Set a jump point if fn actually moves the point."
    (let ((origin (point-marker))
          (result
           (let* ((evil--jumps-jumping t)
                  (better-jumper--jumping t))
             (apply fn args)))
          (dest (point-marker)))
      (unless (equal origin dest)
        (with-current-buffer (marker-buffer origin)
          (better-jumper-set-jump
           (if (markerp (car args))
               (car args)
             origin))))
      (set-marker origin nil)
      (set-marker dest nil)
      result))

  (defun doom-set-jump-h ()
    "Run `better-jumper-set-jump' but return nil, for short-circuiting hooks."
    (when (get-buffer-window)
      (better-jumper-set-jump))
    nil)

  ;; Creates a jump point before killing a buffer. This allows you to undo
  ;; killing a buffer easily (only works with file buffers though; it's not
  ;; possible to resurrect special buffers).
  ;;
  ;; I'm not advising `kill-buffer' because I only want this to affect
  ;; interactively killed buffers.
  (add-hook 'kill-buffer-hook #'doom-set-jump-h)

  ;; Manual support for specific commands:
  (advice-add #'outline-up-heading :around #'doom-set-jump-a)
  (advice-add #'imenu :around #'doom-set-jump-a))


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

;;; init.el ends here
