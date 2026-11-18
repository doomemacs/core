;;; early-init.el --- Doom's universal bootstrapper -*- lexical-binding: t; no-byte-compile: t -*-
;;; Commentary:
;;
;; This is Doom's "universal bootstrapper" for both interactive and
;; non-interactive sessions. No matter what environment you want Doom in, load
;; this file first.
;;
;; This file, in summary:
;; - Determines where `user-emacs-directory' is by:
;;   - Processing `--init-directory DIR' (backported from Emacs 29),
;;   - Processing `--profile NAME' (see
;;     `https://docs.doomemacs.org/-/developers' or docs/developers.org),
;;   - Or assume that it's the directory this file lives in.
;; - Deploy all of Doom's hackiest startup optimizations.
;; - Bootstraps Doom and prepares it for interactive or non-interactive
;;   sessions.
;; - If Doom isn't present, then we assume that Doom is being used as a
;;   bootloader and the user wants to load a non-Doom config, so we undo all our
;;   global side-effects, load `user-emacs-directory'/early-init.el, and carry
;;   on as normal (without Doom).
;; - Do all this without breaking compatibility with Chemacs.
;;
;; early-init.el was introduced in Emacs 27.1. It is loaded before init.el,
;; before Emacs initializes its UI or package.el, and before site files are
;; loaded (NOTE: as of Emacs 31, site files are loaded *before* early-init).
;; This is great place for startup optimizing, because only here can you
;; *prevent* things from loading, rather than turn them off after-the-fact.
;;
;;; Code:

;; PERF: Garbage collection is a big contributor to startup times in both
;;   interactive and CLI sessions, so I defer it.
(setq gc-cons-percentage 1.0)
(if noninteractive  ; in CLI sessions
    ;; PERF: GC deferral is less important in the CLI, but still helps script
    ;;   startup times. Just don't set it too high to avoid runaway memory usage
    ;;   in long-running elisp shell scripts.
    (setq gc-cons-threshold 134217728)  ; 128mb
  ;; PERF: Doom relies on `gcmh-mode' to reset this while the user is idle, so I
  ;;   effectively disable GC during startup. DON'T COPY THIS BLINDLY! If it's
  ;;   not reset later there will be stuttering, freezes, and crashes.
  (setq gc-cons-threshold most-positive-fixnum)
  ;; PERF: Don't waste precious startup time checking mtimes on elisp bytecode.
  ;;   Ensuring correctness is 'doom sync's job.
  (setq load-prefer-newer nil))

;; Increase how much is read from processes in a single chunk (default is 4kb).
;; This is further increased elsewhere, where needed (like our LSP module).
(setq read-process-output-max (* 64 1024))  ; 64kb

;; Performance on Windows is considerably worse than elsewhere. We'll need
;; everything we can get.
(when (boundp 'w32-get-true-file-attributes)
  (setq w32-get-true-file-attributes nil    ; reduce IO ops
        w32-pipe-read-delay 0               ; faster IPC
        w32-pipe-buffer-size (* 64 1024)))  ; read more at a time (was 4K)


;;; Emacs Fixes

;; The `native-compile' feature exists whether or not it is functional (e.g.
;; libgcc is available or not). This seems silly, as some packages will blindly
;; use the native-comp API if it's present but non-functional, so let's pretend
;; it doesn't exist if that's the case.
(if (featurep 'native-compile)
    (if (not (native-comp-available-p))
        (delq 'native-compile features)))

;; HACK: Silence obnoxious and unactionable obsoletion warnings about
;;   (if|when)-let in >=31. These warnings are unhelpful to end-users, and many
;;   packages use these macros. Not to mention, Emacs doesn't respect
;;   `warning-suppress-types' when it comes to obsoletion warnings. Since
;;   flycheck/flymake uses external processes to lint elisp, these settings
;;   won't affect those.
(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)

;; Ignore warnings about "existing variables being aliased". Otherwise the user
;; gets very intrusive popup warnings about our (intentional) uses of
;; defvaralias, which are done because ensuring aliases are created before
;; packages are loaded is an unneeded and unhelpful maintenance burden. Emacs
;; still aliases them fine regardless.
(setq warning-suppress-types '((defvaralias) (lexical-binding)))

;; As some point in 31+, Emacs began spamming the user with warnings about
;; missing `lexical-binding' cookies in elisp files that you are unlikely to
;; have any direct control over (e.g. package files, data lisp files, and elisp
;; shell scripts). This shuts it up.
(setq warning-inhibit-types '((files missing-lexbind-cookie)))

;; $HOME isn't normally defined on Windows, but many unix tools expect it.
(let (realhome)
  (when (and (memq system-type '(cygwin windows-nt ms-dos))
             (null (getenv-internal "HOME"))
             (setq realhome (getenv "USERPROFILE")))
    (setenv "HOME" realhome)
    (setq abbreviated-home-dir nil)))


;; HACK: Here are Doom's hackiest (and least offensive) startup optimizations.
;;   They exploit implementation details and unintended side-effects in Emacs'
;;   startup process, and will change often between major Emacs releases.
;;   However, I disable them if this is a daemon session (where startup time
;;   matters less).
;;
;;   Most of these have been tested on Linux and on fairly fast machines (with
;;   SSDs), so your mileage may vary depending on slower hardware and
;;   `window-system's.
(defun doom--startup-optimizations ()
  ;; A second, case-insensitive pass over `auto-mode-alist' is time wasted,
  ;; especially for non-interactively opened buffers. The cavaet: your
  ;; `auto-mode-alist' rules (or files) must be properly cased, which I think is
  ;; a reasonable expectation.
  (setq auto-mode-case-fold nil)

  ;; Disable warnings from the legacy advice API. They aren't actionable or
  ;; useful, and often come from third party packages. They also trigger
  ;; redisplays, affecting startup time.
  (setq ad-redefinition-action 'accept)

  (unless (daemonp)
    ;; PERF: `file-name-handler-alist' is consulted on every call to `require',
    ;;   `load', or various file/io functions (like `expand-file-name' or
    ;;   `file-remote-p'). You get a noteable boost to startup time by unsetting
    ;;   or simplifying its value when its functionality is rarely needed.
    (let ((old-value (default-toplevel-value 'file-name-handler-alist)))
      (set-default-toplevel-value
       'file-name-handler-alist
       ;; HACK: The elisp libraries bundled with Emacs are either compressed or
       ;;   not, never both. So if calc-loaddefs.el.gz exists, calc-loaddefs.el
       ;;   won't, and vice versa. This heuristic is used to guess the state of
       ;;   all other built-in (or site); if they're compressed, we must leave the
       ;;   gzip file handler in `file-name-handler-alist' so Emacs knows how to
       ;;   load them. Otherwise, we can omit it (at least during startup) for a
       ;;   boost in package load time.
       (if (eval-when-compile
             (locate-file-internal "calc-loaddefs.el" load-path))
           nil
         (list (rassq 'jka-compr-handler old-value))))
      ;; Remember it so it can be reset where needed.
      (put 'file-name-handler-alist 'initial-value (copy-sequence old-value))
      ;; COMPAT: Eventually, Emacs will process any files passed to it via the
      ;;   command line, and will do so *really* early in the startup process.
      ;;   These might contain special file paths like TRAMP paths, so restore
      ;;   `file-name-handler-alist' just for this portion of startup.
      (define-advice command-line-1 (:around (fn args-left) restore-file-name-handlers)
        (let ((file-name-handler-alist
               (if args-left (copy-sequence old-value) file-name-handler-alist)))
          (funcall fn args-left)))
      ;; COMPAT: ...but restore `file-name-handler-alist' later, because it is
      ;;   needed for handling encrypted or compressed files, among other things.
      (add-hook 'emacs-startup-hook
                (lambda ()
                  (set-default-toplevel-value
                   'file-name-handler-alist
                   ;; Merge instead of overwrite because there may have been
                   ;; changes to `file-name-handler-alist' since startup we want
                   ;; to preserve.
                   (delete-dups
                    (append (default-toplevel-value 'file-name-handler-alist)
                            old-value))))
                101))

    (unless noninteractive
      ;; PERF: Resizing the Emacs frame (to accommodate fonts that are smaller or
      ;;   larger than the default system font) can impact startup time
      ;;   dramatically. The larger the delta, the greater the delay. Even trivial
      ;;   deltas can yield up to a ~1000ms loss, depending also on
      ;;   `window-system' (PGTK builds seem least affected and NS/MAC the most).
      (setq frame-inhibit-implied-resize t)

      ;; PERF: A fair bit of startup time goes into initializing the splash and
      ;;   scratch buffers in the typical Emacs session (b/c they activate a
      ;;   non-trivial major mode, generate the splash buffer, and trigger
      ;;   premature frame redraws by writing to *Messages*). These hacks prevent
      ;;   most of this work from happening for some decent savings in startup
      ;;   time. Our dashboard and `doom/open-scratch-buffer' provide a faster
      ;;   (and more useful) alternative anyway.
      (setq inhibit-startup-screen t
            inhibit-startup-echo-area-message user-login-name
            initial-major-mode 'fundamental-mode
            initial-scratch-message nil)
      ;; PERF,UX: Prevent "For information about GNU Emacs..." line in *Messages*.
      (advice-add #'display-startup-echo-area-message :override #'ignore)
      ;; PERF: Suppress the vanilla startup screen completely. We've disabled it
      ;;   with `inhibit-startup-screen', but it would still initialize anyway.
      ;;   This involves file IO and/or bitmap work (depending on the frame type)
      ;;   that we can no-op for a free 50-100ms saving in startup time.
      (advice-add #'display-startup-screen :override #'ignore)

      (unless initial-window-system
        ;; PERF: `tty-run-terminal-initialization' can take 2-3s when starting up
        ;;   TTY Emacs (non-daemon sessions), depending on your TERM, TERMINFO,
        ;;   and TERMCAP, but this work isn't very useful on modern systems (the
        ;;   type I expect Doom's users to be using). The function seems less
        ;;   expensive if run later in the startup process, so I defer it.
        ;; REVIEW: This may no longer be needed in 29+. Needs testing!
        (define-advice tty-run-terminal-initialization (:override (&rest _) defer)
          (advice-remove #'tty-run-terminal-initialization #'tty-run-terminal-initialization@defer)
          (add-hook 'window-setup-hook
                    (apply-partially #'tty-run-terminal-initialization
                                     (selected-frame) nil t))))

      ;; These optimizations make impede debugging other issues, so bow out when
      ;; debug mode is on.
      (unless init-file-debug
        ;; PERF: The mode-line procs a couple dozen times during startup, before
        ;;   the user even sees the first mode-line. This is normally fast, but we
        ;;   can't predict what the user (or packages) will put into the
        ;;   mode-line. Also, mode-line packages have a bad habit of throwing
        ;;   performance to the wind, so best just disable it until we can see
        ;;   one.
        (put 'mode-line-format 'initial-value (default-toplevel-value 'mode-line-format))
        (setq-default mode-line-format nil)
        (dolist (buf (buffer-list))
          (with-current-buffer buf (setq mode-line-format nil)))
        ;; PERF,UX: Premature redisplays/redraws can substantially affect startup
        ;;   times and/or flash a white/unstyled Emacs frame during startup, so I
        ;;   try real hard to suppress them until we're sure the session is ready.
        (setq-default inhibit-message t)
        ;; COMPAT: If the above vars aren't reset, Emacs could appear frozen or
        ;;   garbled after startup (or in case of an startup error).
        (defun doom--reset-inhibited-vars-h ()
          (remove-hook 'post-command-hook #'doom--reset-inhibited-vars-h)
          (setq-default inhibit-message nil))
        (add-hook 'post-command-hook #'doom--reset-inhibited-vars-h -100))

      ;; PERF: Doom disables the UI elements by default, so that there's less for
      ;;   the frame to initialize. However, `tool-bar-setup' is still called and
      ;;   it does some non-trivial work to set up the toolbar before we can
      ;;   disable it. To side-step this work, I disable the function and call it
      ;;   later (see `startup--load-user-init-file@undo-hacks').
      (advice-add #'tool-bar-setup :override #'ignore)

      (define-advice startup--load-user-init-file (:around (fn &rest args) undo-hacks 95)
        "Undo Doom's startup optimizations to prep for the user's session."
        (unwind-protect (apply fn args)
          ;; Now it's safe to be verbose.
          (setq-default inhibit-message nil)
          ;; COMPAT: Once startup is sufficiently complete, undo our earlier
          ;;   optimizations to reduce the scope of potential edge cases.
          (advice-remove #'tool-bar-setup #'ignore)
          (define-advice tool-bar-mode (:after (&rest _) setup)
            (advice-remove #'tool-bar-mode #'tool-bar-mode@setup)
            (tool-bar-setup))
          (unless (default-toplevel-value 'mode-line-format)
            (setq-default mode-line-format (get 'mode-line-format 'initial-value)))))

      ;; PERF: Unset a non-trivial list of command line options that aren't
      ;;   relevant to this session, but `command-line-1' still processes.
      (unless (eq system-type 'darwin)
        (setq command-line-ns-option-alist nil))
      (unless (memq initial-window-system '(x pgtk))
        (setq command-line-x-option-alist nil)))))


;; PERF: Many elisp file API calls consult `file-name-handler-alist' (like
;;   `expand-file-name'). Emacs makes thousands of these calls, and can be sped
;;   up by setting it to nil (its functionality is unneeded this early, anyway).
(let (file-name-handler-alist)
  ;; UX: Respect DEBUG envvar as an alternative to --debug-init, and to make
  ;;   startup more verbose sooner.
  (let ((debug (getenv-internal "DEBUG")))
    (when (stringp debug)
      (if (string= debug "")
          (setenv "DEBUG" nil)
        (setq init-file-debug t
              debug-on-error t)))
    ;; Reduce debug output unless we've asked for it.
    (setq debug-on-error init-file-debug
          jka-compr-verbose init-file-debug)
    ;; Suppress compiler warnings and don't inundate users with their popups.
    ;; They are rarely more than warnings, so are safe to ignore.
    (setq native-comp-async-report-warnings-errors init-file-debug
          native-comp-warning-on-missing-source init-file-debug))

  (let (;; Unset `command-line-args' in interactive sessions, to ensure upstream
        ;; switches aren't misinterpreted.
        (command-line-args (unless noninteractive command-line-args))
        ;; Avoid using `command-switch-alist' to process --profile (and
        ;; --init-directory) because it is processed too late to change
        ;; `user-emacs-directory' in time.
        (profile (or (cadr (member "--profile" command-line-args))
                     (getenv-internal "DOOMPROFILE")))
        ;; Backports --init-directory from Emacs 29.
        (init-dir (or (cadr (member "--init-directory" command-line-args))
                      (getenv-internal "EMACSDIR"))))

    (if (not init-dir)
        ;; FIX: If we're loaded directly (via 'emacs -batch -l early-init.el')
        ;;   or by a doomscript, and Doom is in a non-standard location (and/or
        ;;   Chemacs is used), then `user-emacs-directory' will be wrong.
        (when noninteractive
          (setq user-emacs-directory
                ;; FIX: Don't resolve this file's own symlink if it already
                ;;   lives in a Doom install, in case $EMACSDIR's files are
                ;;   individually symlinked from elsewhere (e.g. the Nix store).
                (let ((dir (file-truename (file-name-directory load-file-name))))
                  (if (file-exists-p (expand-file-name "lisp/doom.el" dir))
                      dir
                    (file-name-directory (file-truename load-file-name))))))
      (setq user-emacs-directory (expand-file-name init-dir))
      ;; Prevent "invalid option" errors later.
      (push (cons "--init-directory" (lambda (_) (pop argv))) command-switch-alist))

    (when profile
      ;; Running 'doom sync' or 'doom profile sync --all' (re)generates a light
      ;; profile loader in $XDG_DATA_HOME/doom/profiles.el (or
      ;; $DOOMPROFILELOADFILE), after reading `doom-profile-load-path'. This
      ;; loader requires `$DOOMPROFILE' be set.
      (setenv "DOOMPROFILE" profile)
      (or (load (let ((windows? (memq system-type '(ms-dos windows-nt cygwin))))
                  (expand-file-name
                   (or (getenv-internal "DOOMPROFILELOADFILE")
                       (concat (if windows? "doomemacs/data/" "doom/")
                               "profiles.el"))
                   (or (if windows? (getenv-internal "LOCALAPPDATA"))
                       (getenv-internal "XDG_DATA_HOME")
                       "~/.local/share")))
                'noerror (not init-file-debug))
          (user-error "Profiles not initialized yet; run 'doom sync' first"))

      ;; Prevent "invalid option" errors later.
      (push (cons "--profile" (lambda (_) (pop argv))) command-switch-alist)))

  ;; PERF: When `load'ing or `require'ing files, each permutation of
  ;;   `load-suffixes' and `load-file-rep-suffixes' (then `load-suffixes' +
  ;;   `load-file-rep-suffixes') is used to locate the file. Each permutation
  ;;   amounts to at least one file op, which is normally very fast, but can add
  ;;   up over the hundreds/thousands of files Emacs loads.
  ;;
  ;;   Doom doesn't load dynamic modules this early, so ".so" is removed from
  ;;   `load-suffixes' to reduce the burden (and MUST-SUFFIX is passed to `load'
  ;;   where possible).
  (if (let ((load-suffixes '(".elc" ".el"))
            (doom (expand-file-name "lisp/doom" user-emacs-directory)))
        (if (file-exists-p (concat doom ".el"))
            (progn
              (doom--startup-optimizations)
              ;; Don't use `load's NOERROR argument because it suppresses other,
              ;; legitimate errors (like permission or IO errors), which should
              ;; not be interpreted as "this is not a Doom config".
              (load doom nil (not init-file-debug) nil 'must-suffix))
          ;; Failing that, assume we're loading a non-Doom config...
          ;; HACK: `startup--load-user-init-file' resolves $EMACSDIR from a
          ;;   lexical (and so, not-trivially-modifiable)
          ;;   `startup-init-directory', so Emacs will fail to locate the
          ;;   correct $EMACSDIR/init.el without help.
          (define-advice startup--load-user-init-file (:filter-args (args) reroute-to-profile)
            (list (lambda () (expand-file-name "init.el" user-emacs-directory))
                  nil (nth 2 args)))
          ;; (Re)set `user-init-file' for the `load' call further below, and do
          ;; so here while our `file-name-handler-alist' optimization is still
          ;; effective (benefits `expand-file-name'). BTW: Emacs resets
          ;; `user-init-file' and `early-init-file' after this file is loaded.
          (setq user-init-file (expand-file-name "early-init" user-emacs-directory))
          ;; COMPAT: I make no assumptions about the config we're going to load,
          ;;   so undo this file's global side-effects.
          (setq load-prefer-newer t)
          ;; PERF: But make an exception for our GC settings (and
          ;;   `read-process-output-max'), which I think all Emacs users and
          ;;   configs will benefit from. Still, setting it to
          ;;   `most-positive-fixnum' is dangerous if downstream does not reset
          ;;   it later to something reasonable, so I use 16mb as a best fit
          ;;   guess. It's better than Emacs' 80kb default.
          (setq gc-cons-threshold (* 16 1024 1024)
                gc-cons-percentage 0.1)
          nil))
      ;; Sets up Doom (particularly `doom-profile') for the session ahead. This
      ;; loads the profile's init file, if it's available. In interactive
      ;; session, a missing profile is an error state, in a non-interactive one,
      ;; it's not (and left to the consumer to deal with).
      (doom-initialize (getenv "DOOMPROFILE") (not noninteractive))
    ;; If we're here, the user wants to load another config/profile (that may or
    ;; may not be a Doom config).
    (load user-init-file 'noerror (not init-file-debug) nil 'must-suffix)))

;;; early-init.el ends here
