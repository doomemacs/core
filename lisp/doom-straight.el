;;; lisp/doom-straight.el -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Emacs package management is opinionated, and so is Doom. Doom uses `straight'
;; to create a declarative, lazy-loaded, and (nominally) reproducible package
;; management system. We use `straight' over `package' because the latter is
;; tempermental. ELPA sources suffer downtime occasionally and often fail to
;; build packages when GNU Tar is unavailable (e.g. MacOS users start with BSD
;; tar). Known gnutls errors plague the current stable release of Emacs (26.x)
;; which bork TLS handshakes with ELPA repos (mainly gnu.elpa.org). See
;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=3434.
;;
;; What's worse, you can only get the latest version of packages through ELPA.
;; In an ecosystem that is constantly changing, this is more frustrating than
;; convenient. Straight (and Doom) can do rolling release, but it is opt-in.
;;
;; Interacting with this package management system is done through Doom's
;; bin/doom script. Find out more about it by running 'doom help' (I highly
;; recommend you add the script to your PATH). Here are some highlights:
;;
;; - `doom install`: a wizard that guides you through setting up Doom and your
;;   private config for the first time.
;; - `doom sync`: your go-to command for making sure Doom is in optimal
;;   condition. It ensures all unneeded packages are removed, all needed ones
;;   are installed, and all metadata associated with them is generated.
;; - `doom upgrade`: upgrades Doom Emacs and your packages to the latest
;;   versions. There's also 'bin/doom sync -u' for updating only your packages.
;;
;; How this works is: the system reads packages.el files located in each
;; activated module, your private config (`doom-user-dir'), and one in
;; `doom-core-dir'. These contain `package!' declarations that tell DOOM what
;; packages to install and where from.
;;
;; All that said, you can still use package.el's commands, but 'doom sync' will
;; purge ELPA packages.
;;
;;; Code:

(setq straight-base-dir (file-truename doom-local-dir)
      straight-repository-branch "develop"
      ;; Since byte-code is rarely compatible across different versions of
      ;; Emacs, it's best we build them in separate directories, per emacs
      ;; version.
      straight-build-dir (format "build-%s" emacs-version)
      straight-cache-autoloads nil ; we already do this, and better.
      ;; Doom doesn't encourage you to modify packages in place. Disabling this
      ;; makes 'doom sync' instant (once everything set up), which is much nicer
      ;; UX than the several seconds modification checks.
      straight-check-for-modifications nil
      ;; We handle package.el ourselves (and a little more comprehensively)
      straight-enable-package-integration nil
      ;; Before switching to straight, `doom-local-dir' would average out at
      ;; around 100mb with half Doom's modules at ~230 packages. Afterwards, at
      ;; around 1gb. With shallow cloning, that is reduced to ~400mb. This has
      ;; no affect on packages that are pinned, however (run 'doom sync --gc' to
      ;; compact those after-the-fact). Some packages break when shallow cloned
      ;; (like magit and org), but we'll deal with that elsewhere.
      straight-vc-git-default-clone-depth '(1 single-branch))

(with-eval-after-load 'straight
  ;; HACK: Doom relies on deferred compilation, which spares the user 20-50min
  ;;   of compilation at install time, but subjects them to ~50% CPU activity
  ;;   when starting Emacs for the first time. To complete this, straight.el
  ;;   needs to be told not to do native-compilation, but it won't obey
  ;;   `straight-disable-native-compile'.
  ;;
  ;;   It *will* obey `straight--native-comp-available', though. Trouble is:
  ;;   it's a constant; it resets itself when straight is loaded, so it must be
  ;;   changed afterwards.
  (setq straight--native-comp-available nil)
  ;; `let-alist' is built into Emacs 26 and onwards
  (add-to-list 'straight-built-in-pseudo-packages 'let-alist))

(define-advice straight--lockfile-read-all
    (:around (fn &rest args) read-pinned-packages)
  "Read `:pin's in `doom-packages' on top of straight's lockfiles."
  (append (apply fn args) ; lockfiles still take priority
          (doom-package-pinned-alist)))

;; HACK: This fixes an issue introduced in emacs-mirror/emacs@0d383b592c2f and
;;   is present in >=29: Straight.el uses `loaddefs-generate' if it is
;;   available, which activates `emacs-lisp-mode' to read autoloads files, but
;;   does so without suppressing its hooks. Some packages (like overseer) add
;;   hooks to `emacs-lisp-mode-hook' in their autoloads, and once triggered,
;;   they will try to load their dependencies (like dash or pkg-info), causing
;;   file errors.
;; REVIEW: Report this upstream.
(define-advice loaddefs-generate--parse-file
    (:around (fn &rest args) inhibit-emacs-lisp-mode)
  (let (emacs-lisp-mode-hook)
    (apply fn args)))


;;
;;; * Hacks

;; Straight was designed primarily for interactive use, in an interactive Emacs
;; session, but Doom does its package management in the terminal. Some things
;; must be modified get straight to behave and improve its UX for our users.

(defvar doom-straight--auto-options
  '(("has diverged from"
     . "^Reset [^ ]+ to ")
    ("but recipe specifies a URL of"
     . "Delete remote \"[^\"]+\", re-create it with correct URL")
    ("has a merge conflict:"
     . "^Abort merge$")
    ("has a dirty worktree:"
     . "^Discard changes$")
    ("^In repository \"[^\"]+\", [^ ]+ (on branch \"main\") is ahead of default branch \"master\""
     . "^Checkout branch \"master\"")
    ("^In repository \"[^\"]+\", [^ ]+ (on branch \"[^\"]+\") is ahead of default branch \"[^\"]+\""
     . "^Checkout branch \"")
    ("^In repository "
     . "^Reset branch \\|^Delete remote [^,]+, re-create it with correct URL\\|^Checkout \""))
  "A list of regexps, mapped to regexps.

Their CAR is tested against the prompt, and CDR is tested against the presented
option, and is used by `straight-vc-git--popup-raw' to select which option to
recommend.

It may not be obvious to users what they should do for some straight prompts,
so Doom will recommend the one that reverts a package back to its (or target)
original state.")

;; HACK: Remove dired & magit options from prompt, since they're inaccessible in
;;   noninteractive sessions.
(advice-add #'straight-vc-git--popup-raw :override #'straight--popup-raw)

;; HACK: `native-comp' only respects `native-comp-jit-compilation-deny-list'
;;   when native-compiling packages in interactive sessions. It ignores the
;;   variable when, say, straight is building packages. This advice forces it to
;;   obey it, even when used by straight (but only in the CLI).
(define-advice native-compile-async
    (:around (fn files &optional recursively load selector) skip)
  (let (file-list)
    (dolist (file-or-dir (ensure-list files))
      (cond ((file-directory-p file-or-dir)
             (dolist (file (if recursively
                               (directory-files-recursively
                                file-or-dir comp-valid-source-re)
                             (directory-files file-or-dir
                                              t comp-valid-source-re)))
               (push file file-list)))
            ((file-exists-p file-or-dir)
             (push file-or-dir file-list))
            ((signal 'native-compiler-error
                     (list "Not a file nor directory" file-or-dir)))))
    (funcall fn (seq-remove (lambda (file)
                              (seq-some (lambda (re) (string-match-p re file))
                                        native-comp-deferred-compilation-deny-list))
                            file-list)
             recursively load selector)))

(define-advice straight-are-you-sure
    (:around (fn &optional prompt noprompt?) fix-tty-prompts)
  "Replace GUI popup prompts with `y-or-n-p'.
The popups hang non-interactive Emacs sessions indefinitely."
  (or noprompt?
      (if noninteractive
          (y-or-n-p (format! "%s" (or prompt "")))
        (funcall fn prompt))))

(defun doom-straight--recommended-option-p (prompt option)
  (cl-loop for (prompt-re . opt-re) in doom-straight--auto-options
           if (string-match-p prompt-re prompt)
           return (string-match-p opt-re option)))

(define-advice straight--build-autoloads
    (:around (fn &rest args) no-compute-prefixes)
  (eval-when-compile
    (or (require 'loaddefs-gen nil 'noerror)
        (require 'autoload)))
  (let (autoload-compute-prefixes)
    (apply fn args)))

(define-advice straight-are-you-sure (:before-until (&rest _) no-confirm)
  "Obey the -!/--force option in Doom's CLI."
  (and (bound-and-true-p doom-cli--context)
       (get! :suppress-prompts?)))

(define-advice straight--popup-raw (:override (prompt actions) fix-tty-prompts)
  "Modifies straight to prompt on the terminal when in noninteractive sessions."
  (if (bound-and-true-p async-in-child-emacs)
      (error "Straight prompt: %s" prompt)
    (let ((doom-straight--auto-options doom-straight--auto-options))
      ;; We can't intercept C-g, so no point displaying any options for this key
      ;; when C-c is the proper way to abort batch Emacs.
      (cl-callf2 delq 'assoc actions)
      ;; HACK: Remove actions that don't work in noninteractive Emacs (like
      ;;   opening dired or magit).
      (setq actions
            (cl-remove-if (lambda (o)
                            (string-match-p "^\\(?:Magit\\|Dired\\)" (nth 1 o)))
                          actions))
      (if (get! :suppress-prompts?)  ; obey -!/--force from Doom's CLI
          (cl-loop for (_key desc func) in actions
                   when desc
                   when (doom-straight--recommended-option-p prompt desc)
                   return (funcall func))
        (print! (start "%s") (red prompt))
        (print-group!
          (terpri)
          (let (recommended options)
            (print-group!
              (print! " 1) Abort")
              (cl-loop for (_key desc func) in actions
                       when desc
                       do (push func options)
                       and do
                       (print! "%2s) %s" (1+ (length options))
                               (if (doom-straight--recommended-option-p prompt desc)
                                   (progn
                                     (setq doom-straight--auto-options nil
                                           recommended (length options))
                                     (green (concat desc " (Choose this if unsure)")))
                                 desc))))
            (terpri)
            (let* ((options
                    (cons (lambda ()
                            (let ((doom-output-indent 0))
                              (terpri)
                              (print! (warn "Aborted")))
                            (doom-cli--exit 1 doom-cli--context))
                          (nreverse options)))
                   (prompt
                    (format! "How to proceed? (%s%s) "
                             (mapconcat #'number-to-string
                                        (number-sequence 1 (length options))
                                        ", ")
                             (if (not recommended) ""
                               (format "; don't know? Pick %d" (1+ recommended)))))
                   answer)
              (while (null (nth (setq answer (1- (read-number prompt))) options))
                (print! (warn "%s is not a valid answer, try again.") answer))
              (funcall (nth answer options)))))))))

(setq straight-arrow " > ")
(define-advice straight--output (:override (string &rest objects) respect-indent)
  "Make output print to stdout while respecting indentation from cli/print.el."
  (let ((msg (apply #'format string objects)))
    (save-match-data
      (when (string-match (format "^%s\\(.+\\)$" (regexp-quote straight-arrow)) msg)
        (setq msg (match-string 1 msg))))
    (and (string-match-p "^\\(Cloning\\|\\(Reb\\|B\\)uilding\\) " msg)
         (not (string-suffix-p "...done" msg))
         (doom-print (concat "> " msg) :format t))))

(define-advice straight--process-call (:around (fn &rest args) ignore-gitconfig)
  "Prevent user and system git configuration from interfering with git calls."
  (with-environment-variables
      (("GIT_CONFIG" nil)
       ("GIT_CONFIG_NOSYSTEM" "1")
       ("GIT_CONFIG_GLOBAL" (or (getenv "DOOMGITCONFIG")
                                "/dev/null")))
    (apply fn args)))


;; HACK: Implement safety nets in case Straight fails to clone the repo properly
;;   (usually due to connection issues or upstream outages).

(define-advice straight--process-log (:around (fn &rest args) barf-if-failed-clone)
  "Throw a more user-friendly error if the repo wasn't cloned properly.

If the repo failed to clone correctly (usually due to a connection failure),
straight proceeds as normal until a later call produces a garbage result
\(typically, when it fails to fetch the remote branch of the empty directory).
This causes Straight to throw an otherwise cryptic type error when it tries to
sanitize the result for its log buffer.

This error is a common source of user confusion and false positive bug reports,
so this advice catches them to regurgitates a more cogent explanation."
  (letf! (defadvice shell-quote-argument (:before (&rest args))
           (unless (car args)
             (error "Package was not properly cloned due to a connection failure, please try again later")))
    (apply fn args)))

(define-advice straight-vc-git-local-repo-name (:around (fn &rest args) barf-if-failed-clone)
  "Throw a more user-friendly error if the repo wasn't cloned properly."
  (condition-case e
      (apply fn args)
    (wrong-type-argument
     (if (eq (cadr e) 'stringp)
         (error "Package was not properly cloned due to a connection failure, please try again later")
       (signal (car e) (cdr e))))))

(define-advice straight-vc-clone (:around (fn recipe) barf-if-failed-clone)
  "Throw a more user-friendly error if repo wasn't cloned properly.

In some cases, either Straight or git silently fails to clone a package without
triggering an catchable error (and thus evading the auto-retry logic in
`doom-straight--retry-a') and leaves behind an empty directory. This detects
this and forces straight to emit a catchable error."
  (prog1 (funcall fn recipe)
    (when noninteractive
      (straight--with-plist recipe (package type local-repo)
        (let* ((local-repo (or local-repo package))
               (repo-dir (straight--repos-dir local-repo))
               (build-dir (straight--build-dir local-repo)))
          (when (file-in-directory-p repo-dir straight-base-dir)
            (unless (or (file-directory-p (doom-path repo-dir ".git"))
                        (file-exists-p (doom-path repo-dir ".straight-commit")))
              (delete-directory repo-dir t)
              (delete-directory build-dir t)
              (error "Failed to clone %S..." package))))))))


;; HACK: Straight can sometimes fail to clone/update a repo, leaving behind an
;;   empty directory which, in future invocations, it will assume indicates a
;;   successful clone (causing load errors later).
(defvar +doom-straight-retries 3
  "How many times to retry VC operations.")

(defvar +doom-straight-retry-methods
  '(clone
    normalize
    fetch-from-remote
    fetch-from-upstream
    merge-from-remote
    merge-from-upstream)
  "Which `straight-vc' methods to retry, if they fail.")

(define-advice straight-vc (:around (fn method type &rest args) retry)
  "Make additional attempts if first clone fails."
  (if (or (not noninteractive)
          (memq type '(nil built-in))
          (not (memq method +doom-straight-retry-methods)))
      (apply fn method type args)
    (let ((n +doom-straight-retries)
          res)
      (while (> n 0)
        (condition-case err
            (setq res (apply fn method type args)
                  n 0)
          (error
           (cl-decf n)
           (when (= n 0)
             (signal (car err) (cdr err)))
           (print! (warn "Failed %S %S operation, retrying (attempt %d/%d)...")
                   type method (- (1+ +doom-straight-retries) n)
                   +doom-straight-retries)
           (sleep-for 1))))
      res)))

;; HACK: Line encoding issues can plague repos with dirty worktree prompts when
;;   updating packages or "Local variables entry is missing the suffix" errors
;;   when installing them (see #2637), so have git handle conversion by force.
(when doom--system-windows-p
  (add-hook! 'straight-vc-git-post-clone-hook
    (lambda! (&key repo-dir)
      (let ((default-directory repo-dir))
        (straight--process-run "git" "config" "core.autocrlf" "true")))))

(provide 'doom-straight)
;;; doom-packages.el ends here
