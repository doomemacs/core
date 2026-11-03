;;; doom.el --- the heart of the beast -*- lexical-binding: t; -*-
;;
;; Author:  Henrik Lissner <contact@henrik.io>
;; URL:     https://github.com/doomemacs/core
;;
;;   =================     ===============     ===============   ========  ========
;;   \\ . . . . . . .\\   //. . . . . . .\\   //. . . . . . .\\  \\. . .\\// . . //
;;   ||. . ._____. . .|| ||. . ._____. . .|| ||. . ._____. . .|| || . . .\/ . . .||
;;   || . .||   ||. . || || . .||   ||. . || || . .||   ||. . || ||. . . . . . . ||
;;   ||. . ||   || . .|| ||. . ||   || . .|| ||. . ||   || . .|| || . | . . . . .||
;;   || . .||   ||. _-|| ||-_ .||   ||. . || || . .||   ||. _-|| ||-_.|\ . . . . ||
;;   ||. . ||   ||-'  || ||  `-||   || . .|| ||. . ||   ||-'  || ||  `|\_ . .|. .||
;;   || . _||   ||    || ||    ||   ||_ . || || . _||   ||    || ||   |\ `-_/| . ||
;;   ||_-' ||  .|/    || ||    \|.  || `-_|| ||_-' ||  .|/    || ||   | \  / |-_.||
;;   ||    ||_-'      || ||      `-_||    || ||    ||_-'      || ||   | \  / |  `||
;;   ||    `'         || ||         `'    || ||    `'         || ||   | \  / |   ||
;;   ||            .===' `===.         .==='.`===.         .===' /==. |  \/  |   ||
;;   ||         .=='   \_|-_ `===. .==='   _|_   `===. .===' _-|/   `==  \/  |   ||
;;   ||      .=='    _-'    `-_  `='    _-'   `-_    `='  _-'   `-_  /|  \/  |   ||
;;   ||   .=='    _-'          '-__\._-'         '-_./__-'         `' |. /|  |   ||
;;   ||.=='    _-'                                                     `' |  /==.||
;;   =='    _-'                                                            \/   `==
;;   \   _-'                                                                `-_   /
;;    `''                                                                      ``'
;;
;; These demons are not part of GNU Emacs.
;;
;;; Commentary:
;;
;; This file is Doom's heart, minus most of its startup optimizations (which are
;; in early-init.el), which loads what's needed for all Doom sessions,
;; interactive or otherwise.
;;
;; See modules/doom/init.el for initialization intended solely for interactive
;; sessions and doom-cli.el for non-interactive sessions.
;;
;; The overall load order of Doom is as follows:
;;
;;   > $EMACSDIR/early-init.el
;;     > $EMACSDIR/lisp/doom.el
;;       - $EMACSDIR/lisp/doom-lib.el
;;       - $DOOMDIR/init.el
;;       - hook: `doom-before-init-hook'
;;   - $EMACSDIR/user-lisp/.user-lisp-autoloads.el  (see `user-lisp-directory')
;;   - hook: `before-init-hook'
;;   > $XDG_DATA_HOME/doom/$PROFILE/@/$VERSION/init.el   (replaces $EMACSDIR/init.el)
;;     - $EMACSDIR/doom-emacs.el
;;     - hook: `doom-before-modules-init-hook'
;;     - {$DOOMDIR,$EMACSDIR}/{,sources/*/}modules/*/*/init.el
;;     - hook: `doom-after-modules-init-hook'
;;     - hook: `doom-before-modules-config-hook'
;;     - {$DOOMDIR,$EMACSDIR}/{,sources/*/}modules/*/*/config.el
;;     - hook: `doom-after-modules-config-hook'
;;     - $DOOMDIR/config.el
;;     - `custom-file' or $DOOMDIR/custom.el
;;   - hook: `after-init-hook'
;;   - hook: `emacs-startup-hook'
;;   - hook: `window-setup-hook'
;;   - hook: `doom-init-ui-hook'
;;   - hook: `doom-after-init-hook'
;;   > After startup is complete (if file(s) have been opened from the command
;;     line, these will trigger much earlier):
;;     - On first input:              `doom-first-input-hook'
;;     - On first switched-to buffer: `doom-first-buffer-hook'
;;     - On first opened file:        `doom-first-file-hook'
;;
;;; Code:

(eval-when-compile (require 'subr-x))

(eval-and-compile
  (add-to-list 'load-path
               (file-name-directory
                (or (bound-and-true-p byte-compile-current-file)
                    load-file-name)))
  nil)

;; Doom's CLI supports Emacs 27.1+ for the long haul, but lisp/doom-emacs.el and
;; module libraries require 29.1+.
(let ((supported (if noninteractive 27 29)))
  (when (< emacs-major-version supported)
    (user-error "Detected Emacs %s, but %sinteractive Doom needs >=%d.1"
                emacs-version
                (if noninteractive "non-" "")
                supported)))


;;
;;; * Custom features & global constants

;; Doom has its own features that its modules, CLI, and user extensions can
;; announce, and don't belong in `features', so they are stored here, which can
;; include information about the external system environment.
(defconst doom-system
  (cond ((eq system-type 'darwin)                         '(macos bsd))
        ((memq system-type '(cygwin windows-nt ms-dos))   '(windows))
        ((memq system-type '(gnu gnu/linux))              '(linux))
        ((memq system-type '(gnu/kfreebsd berkeley-unix)) '(linux bsd))
        ((eq system-type 'android)                        '(android)))
  "A list of symbols indicating the features in the active Doom profile.

The first element should always be one of `macos', `windows', `linux', or
`android'.")

;; Convenience aliases for internal use only (may be removed later).
(defconst doom--system-windows-p (eq 'windows (car doom-system)))
(defconst doom--system-macos-p   (eq 'macos   (car doom-system)))
(defconst doom--system-linux-p   (eq 'linux   (car doom-system)))

;; Announce WSL if it is detected.
(when (and doom--system-linux-p
           (if (boundp 'operating-system-release) ; is deprecated since 28.x
               (string-match-p "-[Mm]icrosoft" operating-system-release)
             (getenv-internal "WSLENV")))
  (add-to-list 'doom-system 'wsl 'append))

;; `system-type' is esoteric and imprecise, so I create a pseudo feature as a
;; more consistent alternative, for use with `featurep'.
(push :system features)
(put :system 'subfeatures doom-system)

;; DEPRECATED: Remove in v3
(with-no-warnings
  (defconst IS-MAC      doom--system-macos-p)
  (defconst IS-LINUX    doom--system-linux-p)
  (defconst IS-WINDOWS  doom--system-windows-p)
  (defconst IS-BSD      (memq 'bsd doom-system))

  (make-obsolete-variable 'IS-MAC     "Use (featurep :system 'macos) instead" "2.1.0")
  (make-obsolete-variable 'IS-LINUX   "Use (featurep :system 'linux) instead" "2.1.0")
  (make-obsolete-variable 'IS-WINDOWS "Use (featurep :system 'windows) instead" "2.1.0")
  (make-obsolete-variable 'IS-BSD     "Use (featurep :system 'bsd) instead" "2.1.0"))


;;
;;; * Load Doom's stdlib

(require 'doom-lib)


;;
;;; * Core globals

(defgroup doom nil
  "A development framework for Emacs configurations and Emacs Lisp projects."
  :link '(url-link :tag "Website" "https://doomemacs.org")
  :group 'emacs)

(defvar doom-init-time nil
  "The time it took, in seconds (as a float), for Doom Emacs to start up.")

;; DEPRECATED: Will be removed in v3
(defconst doom--noprofile (not (getenv-internal "DOOMPROFILE")))
(defconst doom--profile-default (cons "_default" "0"))

(defvar doom-profile nil
  "The active profile as a `doom-profile' struct.")


;;; ** Data directory variables

(defvar doom-emacs-dir user-emacs-directory
  "The path to the currently loaded .emacs.d directory. Must end with a slash.")

(defconst doom-core-dir (file-name-directory load-file-name)
  "The root directory of Doom's core files. Must end with a slash.")

(defvar doom-user-dir
  (expand-file-name
   (if-let* ((doomdir (getenv-internal "DOOMDIR")))
       (file-name-as-directory doomdir)
     (or (let ((xdgdir
                (file-name-concat
                 (or (getenv-internal "XDG_CONFIG_HOME")
                     "~/.config")
                 "doom/")))
           (if (file-directory-p xdgdir) xdgdir))
         "~/.doom.d/")))
  "Where your private configuration is placed.

Defaults to ~/.config/doom, ~/.doom.d or the value of the DOOMDIR envvar;
whichever is found first. Must end in a slash.")

;; DEPRECATED: Will be replaced in v3
(defvar doom-module-load-path
  (list (file-name-concat doom-user-dir "modules")
        (file-name-concat doom-emacs-dir "modules")
        (file-name-concat doom-emacs-dir "sources/doom+/modules"))
  "A list of paths where Doom should search for modules.

Order determines priority (from highest to lowest). The first entry should
always be the user's module directory (under `doom-user-dir').

Each entry is a string; an absolute path to the root directory of a module tree.
In other words, they should contain a two-level nested directory structure,
where the module's group and name was deduced from the first and second level of
directories. For example: if $DOOMDIR/modules/ is an entry, a
$DOOMDIR/modules/lang/ruby/ directory represents a ':lang ruby' module.")

;; DEPRECATED: .local will be removed entirely in 3.0
(defvar doom-local-dir
  (if-let* ((localdir (getenv-internal "DOOMLOCALDIR")))
      (expand-file-name (file-name-as-directory localdir))
    (expand-file-name ".local/" doom-emacs-dir))
  "Root directory for local storage.

Use this as a storage location for this system's installation of Doom Emacs.

These files should not be shared across systems. By default, it is used by
`doom-data-dir' and `doom-cache-dir'. Must end with a slash.")

(defvar doom-data-dir
  (if doom--noprofile
      ;; DEPRECATED: .local will be removed entirely in 3.0
      (file-name-concat doom-local-dir "etc/")
    (if doom--system-windows-p
        (expand-file-name "doomemacs/data/" (getenv-internal "LOCALAPPDATA"))
      (expand-file-name "doom/" (or (getenv-internal "XDG_DATA_HOME") "~/.local/share"))))
  "Where Doom stores its global data files.

Data files contain shared and long-lived data that Doom, Emacs, and their
packages require to function correctly or at all. Deleting them by hand will
cause breakage, and require user intervention (e.g. a `doom sync`) to restore.

Use this for: server binaries, package source, pulled module libraries,
generated files for profiles, profiles themselves, autoloads/loaddefs, etc.

For profile-local data files, use `doom-profile-data-dir' instead.")

(defvar doom-cache-dir
  (if doom--noprofile
      ;; DEPRECATED: .local will be removed entirely in 3.0
      (file-name-concat doom-local-dir "cache/")
    (if doom--system-windows-p
        (expand-file-name "doomemacs/cache/" (getenv-internal "LOCALAPPDATA"))
      (expand-file-name "doom/" (or (getenv-internal "XDG_CACHE_HOME") "~/.cache"))))
  "Where Doom stores its global cache files.

Cache files represent unessential data that shouldn't be problematic when
deleted (besides, perhaps, a one-time performance hit), lack portability (and so
shouldn't be copied to other systems/configs), and are regenerated when needed,
without user input (e.g. a `doom sync`).

Some examples: images/data caches, elisp bytecode, natively compiled elisp,
session files, ELPA archives, authinfo files, org-persist, etc.

For profile-local cache files, use `doom-profile-cache-dir' instead.")

(defvar doom-state-dir
  (if doom--noprofile
      ;; DEPRECATED: .local will be removed entirely in 3.0
      (file-name-concat doom-local-dir "state/")
    (if doom--system-windows-p
        (expand-file-name "doomemacs/state/" (getenv-internal "LOCALAPPDATA"))
      (expand-file-name "doom/" (or (getenv-internal "XDG_STATE_HOME") "~/.local/state"))))
  "Where Doom stores its global state files.

State files contain unessential, non-portable, but persistent data which, if
lost won't cause breakage, but may be inconvenient as they cannot be
automatically regenerated or restored. For example, a recently-opened file list
is not essential, but losing it means losing this record, and restoring it
requires revisiting all those files.

Use this for: history, logs, user-saved data, autosaves/backup files, known
projects, recent files, bookmarks.

For profile-local state files, use `doom-profile-state-dir' instead.")


;;; ** Profile file/directory variables

;; DEPRECATED: To be replaced with `doom-profile-cache-dir' function in v3
(defvar doom-profile-cache-dir nil
  "For profile-local cache files under `doom-cache-dir'.")

;; DEPRECATED: To be replaced with `doom-profile-data-dir' function in v3
(defvar doom-profile-data-dir nil
  "For profile-local data files under `doom-data-dir'.")

;; DEPRECATED: To be replaced with `doom-profile-state-dir' function in v3
(defvar doom-profile-state-dir nil
  "For profile-local state files under `doom-state-dir'.")

;; DEPRECATED: To be replaced with `doom-profile-dir' function in v3
(defconst doom-profile-dir nil
  "Where generated files for the active profile (for Doom's core) are kept.")


;;
;;; * Custom hooks

(defcustom doom-before-init-hook ()
  "A hook run after Doom's core has initialized; before user configuration.

This is triggered right before $DOOMDIR/init.el is loaded, in the context of
early-init.el. Use this for configuration at the latest opportunity before the
session becomes unpredictably complicated by user config, packages, etc. This
runs in both interactive and non-interactive contexts, so guard hooks
appropriately against `noninteractive' or the `cli' context (see
`doom-context').

In contrast, `before-init-hook' is run just after $DOOMDIR/init.el is loaded,
but long before your modules and $DOOMDIR/config.el are loaded."
  :type 'hook)

(defcustom doom-after-init-hook ()
  "A hook run once Doom's core and modules, and the user's config are loaded.

This triggers at the absolute latest point in the eager startup process, and
runs in both interactive and non-interactive sessions, so guard hooks
appropriately against `noninteractive' or the `cli' context."
  :type 'hook)

(defcustom doom-before-modules-init-hook nil
  "Hooks run before module init.el files are loaded."
  :type 'hook)

(defcustom doom-after-modules-init-hook nil
  "Hooks run after module init.el files are loaded."
  :type 'hook)

(defcustom doom-before-modules-config-hook nil
  "Hooks run before module config.el files are loaded."
  :type 'hook)

(defcustom doom-after-modules-config-hook nil
  "Hooks run after module config.el files are loaded (but before the user's)."
  :type 'hook)

(defcustom doom-startup-functions nil
  "Functions run to start up an interactive session of Doom.

Each function is passed one argument: the doom-profile being started up."
  :type 'hook)


;;
;;; * Initializers

(defun doom-version ()
  "Return the running version of Doom core."
  (declare (side-effect-free t))
  (or (get 'doom 'version)
      (put 'doom 'version
           (with-temp-buffer
             (insert-file-contents (file-name-concat doom-emacs-dir ".doom")
                                   nil 0 96)
             (read (current-buffer))))))

(defun doom-initialize (profile-id &optional interactive?)
  "Bootstrap the Doom session ahead."
  (when (and (not doom-profile)
             (doom-context-push 'startup))
    ;; Since Emacs 27, package initialization occurs before `user-init-file' is
    ;; loaded, but after `early-init-file'. Doom handles package initialization,
    ;; so we must prevent Emacs from doing it again.
    (setq package-enable-at-startup nil)

    (if interactive?
        (when (doom-context-push 'emacs)
          (add-hook 'doom-after-init-hook #'doom-display-benchmark-h 110)
          (doom-run-hook-on 'doom-first-file-hook   '(find-file-hook dired-initial-position-hook))
          (doom-run-hook-on 'doom-first-input-hook  '(pre-command-hook))
          (doom-run-hook-on 'doom-first-buffer-hook '(find-file-hook doom-switch-buffer-hook)
                            (lambda ()
                              (not (member (buffer-name)
                                           `("*scratch*" ,doom-fallback-buffer-name)))))
          ;; As late in the Emacs' startup process as possible.
          (advice-add #'command-line-1 :after #'doom-finalize '((depth . 100))))

      (when (doom-context-push 'cli)
        ;; Don't generate superfluous files when writing temp buffers.
        (setq make-backup-files nil)
        ;; Stop user config from interfering with elisp shell scripts.
        (setq enable-dir-local-variables nil)
        ;; Reduce ambiguity, embrace specificity, enjoy predictability.
        (setq case-fold-search nil)
        ;; Don't clog the user's trash with our CLI refuse.
        (setq delete-by-moving-to-trash nil)

        ;; REVIEW: Remove later. The endpoints should be responsibile for
        ;;   ensuring they exist. For now, they exist to quell file errors.
        (with-file-modes #o700
          (mapc (doom-rpartial #'make-directory 'parents)
                (list doom-local-dir
                      doom-data-dir
                      doom-cache-dir
                      doom-state-dir)))

        (doom-require 'doom-lib 'debug)
        (if init-file-debug (doom-debug-mode +1))

        ;; Ensure the CLI framework is ready.
        (require 'doom-cli)
        (add-hook 'doom-before-init-hook #'doom-cli-initialize -90)
        (add-hook 'doom-cli-initialize-hook #'doom-finalize 100)

        ;; HACK: site-lisp files can be obnoxiously noisy (emitting output that
        ;;   can pollute logs and isn't useful to (and may even alarm)
        ;;   end-users, like file load messages, deprecation notices, and linter
        ;;   warnings). bin/doom suppresses site-lisp in its shebang line so we
        ;;   can load it here with output suppressed (unless debug mode is on).
        (quiet!!
          (require 'cl nil t)   ; "Package cl is deprecated"
          (unless site-run-file
            (let ((inhibit-startup-screen inhibit-startup-screen))
              (load "site-start" t))))))

    ;; Set and load `doom-profile'.
    (let* ((key
            ;; Can't use `doom-profile-key' this early. Interactive sessions
            ;; won't have the profiles API available yet.
            (if profile-id
                (save-match-data
                  (let (case-fold-search)
                    (if (string-match "^\\([^@]+\\)?\\(?:@\\(.+\\)\\)?$" profile-id)
                        (cons (match-string 1 profile-id)
                              (or (match-string 2 profile-id) (cdr doom--profile-default)))
                      (cons profile-id (cdr doom--profile-default)))))
              doom--profile-default))
           (init-file (doom-profile-init-file key)))
      (if (file-exists-p init-file)
          (condition-case-unless-debug e
              (load init-file nil (not init-file-debug))
            (error
             (if interactive?
                 (signal 'doom-profile-error (cons 'doom-initialize e))
               (message "Error loading profile: %s" (error-message-string e))
               (message "Run 'doom sync' to regenerate it!"))))
        (if interactive?
            (signal 'doom-nosync-error `(doom-initialize ,profile-id))))
      (unless doom-profile
        (setq doom-profile
              (make-doom-profile :name (car key)
                                 :ref "0" ; refs are ornamental until v3
                                 :root doom-emacs-dir)))
      ;; DEPRECATED: For backwards compatibility. Remove in v3
      (let ((name (unless doom--noprofile (doom-profile-name doom-profile)))
            (ref  (unless doom--noprofile (doom-profile-ref doom-profile))))
        (setq doom-profile-cache-dir (doom-cache-dir name)
              doom-profile-data-dir  (doom-data-dir name)
              doom-profile-state-dir (doom-state-dir name)
              doom-profile-dir       (doom-profile-data-dir t "@" ref))))

    ;; HACK: Many packages (even built-in ones) abuse `user-emacs-directory' to
    ;;   build paths for storage/cache files instead of correctly using
    ;;   `locate-user-emacs-file'. Changing `user-emacs-directory' saves us the
    ;;   trouble of setting a million directory/file variables.
    (setq user-emacs-directory (doom-profile-cache-dir t))
    ;; ...However, this can surprise packages (and users) that read
    ;; `user-emacs-directory' expecting to find the location of your Emacs
    ;; config, such as server.el!
    (setq server-auth-dir (doom-emacs-dir "server/"))

    ;; Native compilation support (see http://akrl.sdf.org/gccemacs.html)
    (when (boundp 'native-comp-eln-load-path)
      ;; Don't store eln files in ~/.emacs.d/eln-cache (where they can easily be
      ;; deleted by 'doom upgrade').
      (setq native-comp-eln-load-path
            (cons (doom-profile-cache-dir t "eln/")
                  (cdr native-comp-eln-load-path)))

      (unless (boundp 'native-comp-deferred-compilation-deny-list)
        (defvaralias 'native-comp-deferred-compilation-deny-list 'native-comp-jit-compilation-deny-list))

      (define-advice comp-run-async-workers (:around (fn &rest args) dont-litter-tmpdir)
        "Normally, native-comp writes a ton to /tmp. This advice redirects this
IO to `doom-profile-cache-dir' instead, so it doesn't OOM tmpfs users and can be
safely cleaned up with \\='doom sync' or \\='doom gc'."
        (let ((temporary-file-directory (doom-profile-cache-dir t "comp/")))
          (make-directory temporary-file-directory t)
          (apply fn args)))
      (when (fboundp 'comp--run-async-workers)
        ;; This is renamed in newer versions of Emacs.
        (advice-add #'comp--run-async-workers :around #'comp-run-async-workers@dont-litter-tmpdir))

      (with-eval-after-load 'comp
        ;; HACK: On Emacs 30.0.92, `native-comp-jit-compilation-deny-list' was
        ;;   moved to comp-run. See emacsmirror/emacs@e6a955d24268. Doom forces
        ;;   straight to consult this variable when building packages.
        (require 'comp-run nil t)
        ;; HACK: Disable native-compilation for some troublesome packages
        (mapc (apply-partially #'add-to-list 'native-comp-deferred-compilation-deny-list)
              (list "/seq-tests\\.el\\'"
                    "/emacs-jupyter.*\\.el\\'"
                    "/evil-collection-vterm\\.el\\'"
                    "/vterm\\.el\\'"
                    "/with-editor\\.el\\'"))))

    (when interactive?
      (require 'doom-emacs))  ; Doom's reasonable defaults

    ;; A last ditch opportunity to undo hacks or do extra configuration before
    ;; the session is complicated by user config and packages.
    (doom-run-hooks 'doom-before-init-hook)

    ;; HACK: Ensure OS checks are as fast as possible (given their ubiquity).
    (setq features (cons :system (delq :system features)))

    ;; Remember these variables' initial values, so they can be safely reset
    ;; later (e.g. by `doom/reload'), or compared against for change heuristics.
    (dolist (var '(exec-path load-path process-environment))
      (put var 'initial-value (copy-sequence (default-toplevel-value var))))

    doom-profile))

(defun doom-finalize (&rest _)
  "Finalize the current Doom session, marking the end of its startup process.

Triggers `doom-after-init-hook' and sets `doom-init-time.'"
  (when (doom-context-p 'startup)
    ;; If the user's already opened something (e.g. with command-line
    ;; arguments), then we should assume nothing about the user's intentions and
    ;; simply treat this session as fully initialized.
    (when (and file-name-history (doom-context-p 'emacs))
      (doom-run-hooks 'doom-first-file-hook 'doom-first-buffer-hook))

    (setq doom-init-time (float-time (time-subtract (current-time) before-init-time)))
    (doom-run-hooks 'doom-after-init-hook)

    (when (display-graphic-p)
      (require 'server)
      (unless (server-running-p)
        ;; Allow users to override `server-name' via envvar.
        (when-let* ((name (getenv "EMACS_SERVER_NAME")))
          (setq server-name name))
        (server-start)))

    ;; If `gc-cons-threshold' and `gc-cons-percentage' haven't been reset at
    ;; this point, do it now (without overwriting `gcmh' or the user's config).
    ;; If not done, the session may see freezing and crashes. Also handles the
    ;; case where the user has `gcmh' disabled (e.g. users on the IGC branch).
    (if (= (default-value 'gc-cons-threshold) most-positive-fixnum)
        (setq-default gc-cons-threshold (* 16 1024 1024)))
    (if (= (default-value 'gc-cons-percentage) 1.0)
        (setq-default gc-cons-percentage 0.1))
    (doom-context-pop 'startup)))

(defun doom-startup ()
  "Fully load enabled modules and $DOOMDIR/config.el."
  (require 'doom-emacs)  ; if called from CLI
  (run-hook-with-args 'doom-startup-functions doom-profile))

(defun doom-display-benchmark-h (&optional return-p)
  "Display a benchmark including number of packages and modules loaded.

If RETURN-P, return the message as a string instead of displaying it."
  (funcall (if return-p #'format #'message)
           "Doom loaded %d packages across %d modules in %.03fs"
           (- (length load-path) (length (get 'load-path 'initial-value)))
           (if doom-modules (hash-table-count doom-modules) -1)
           doom-init-time))

(provide 'doom)
;;; doom.el ends here
