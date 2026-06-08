;;; lang/org/config.el -*- lexical-binding: t; -*-

(defvar +org-babel-native-async-langs '(python)
  "Languages that will use `ob-comint' instead of `ob-async' for `:async'.")

(defvar +org-babel-mode-alist
  '((c . C)
    (cpp . C)
    (C++ . C)
    (D . C)
    (elisp . emacs-lisp)
    (sh . shell)
    (bash . shell)
    (matlab . octave)
    (rust . rustic-babel)
    (amm . ammonite))
  "An alist mapping languages to babel libraries. This is necessary for babel
libraries (ob-*.el) that don't match the name of the language.

For example, (fish . shell) will cause #+begin_src fish blocks to load
ob-shell.el when executed.")

(defvar +org-babel-load-functions ()
  "A list of functions executed to load the current executing src block. They
take one argument (the language specified in the src block, as a string). Stops
at the first function to return non-nil.")

(defvar +org-capture-todo-file "todo.org"
  "Default target for todo entries.

Is relative to `org-directory', unless it is absolute. Is used in Doom's default
`org-capture-templates'.")

(defvar +org-capture-changelog-file "changelog.org"
  "Default target for changelog entries.

Is relative to `org-directory' unless it is absolute. Is used in Doom's default
`org-capture-templates'.")

(defvar +org-capture-notes-file "notes.org"
  "Default target for storing notes.

Used as a fall back file for org-capture.el, for templates that do not specify a
target file.

Is relative to `org-directory', unless it is absolute. Is used in Doom's default
`org-capture-templates'.")

(defvar +org-capture-journal-file "journal.org"
  "Default target for storing timestamped journal entries.

Is relative to `org-directory', unless it is absolute. Is used in Doom's default
`org-capture-templates'.")

(defvar +org-capture-projects-file "projects.org"
  "Default, centralized target for org-capture templates.")

(defvar +org-habit-graph-padding 2
  "The padding added to the end of the consistency graph.")

(defvar +org-habit-min-width 30
  "Hide the consistency graph if `org-habit-graph-column' is less than this.")

(defvar +org-habit-graph-window-ratio 0.3
  "The ratio of the consistency graphs relative to the window width.")

(defvar +org-preview-dir (doom-path doom-profile-cache-dir "org/previews/")
  "Where link preview images are cached.")

(defvar +org-startup-with-animated-gifs nil
  "If non-nil, and the cursor is over a gif inline-image preview, animate it!")


;;
;;; `org-load' hooks

(defun +org-init-org-directory-h ()
  (unless org-directory
    (setq-default org-directory "~/org"))
  (unless org-id-locations-file
    (setq org-id-locations-file (expand-file-name ".orgids" org-directory))))


(defun +org-init-agenda-h ()
  (unless org-agenda-files
    (setq-default org-agenda-files (list org-directory)))
  (setq-default
   ;; Different colors for different priority levels
   org-agenda-deadline-faces
   '((1.001 . error)
     (1.0 . org-warning)
     (0.5 . org-upcoming-deadline)
     (0.0 . org-upcoming-distant-deadline))
   ;; Don't monopolize the whole frame just for the agenda
   org-agenda-window-setup 'current-window
   org-agenda-skip-unavailable-files t
   ;; Shift the agenda to show the previous 3 days and the next 7 days for
   ;; better context on your week. The past is less important than the future.
   org-agenda-span 10
   org-agenda-start-on-weekday nil
   org-agenda-start-day "-3d"
   ;; Optimize `org-agenda' by inhibiting extra work while opening agenda
   ;; buffers in the background. They'll be "restarted" if the user switches to
   ;; them anyway (see `+org-exclude-agenda-buffers-from-workspace-h')
   org-agenda-inhibit-startup t))


(defun +org-init-appearance-h ()
  "Configures the UI for `org-mode'."
  (setq org-indirect-buffer-display 'current-window
        org-enforce-todo-dependencies t
        org-entities-user
        '(("flat"  "\\flat" nil "" "" "266D" "♭")
          ("sharp" "\\sharp" nil "" "" "266F" "♯"))
        org-fontify-done-headline t
        org-fontify-quote-and-verse-blocks t
        org-fontify-whole-heading-line t
        org-hide-leading-stars t
        org-image-actual-width nil
        org-imenu-depth 6
        org-priority-faces
        '((?A . error)
          (?B . warning)
          (?C . shadow))
        org-startup-indented t
        org-tags-column 0
        org-use-sub-superscripts '{}
        ;; `showeverything' is org's default, but it doesn't respect
        ;; `org-hide-block-startup' (#+startup: hideblocks), archive trees,
        ;; hidden drawers, or VISIBILITY properties. `nil' is equivalent, but
        ;; respects these settings.
        org-startup-folded nil)

  (setq org-refile-targets
        '((nil :maxlevel . 3)
          (org-agenda-files :maxlevel . 3))
        ;; Without this, completers like ivy/helm are only given the first level of
        ;; each outline candidates. i.e. all the candidates under the "Tasks" heading
        ;; are just "Tasks/". This is unhelpful. We want the full path to each refile
        ;; target! e.g. FILE/Tasks/heading/subheading
        org-refile-use-outline-path 'file
        org-outline-path-complete-in-steps nil)

  (plist-put org-format-latex-options :scale 1.5) ; larger previews

  ;; HACK: Face specs fed directly to `org-todo-keyword-faces' don't respect
  ;;   underlying faces like the `org-todo' face does, so we define our own
  ;;   intermediary faces that extend from org-todo.
  ;; REVIEW: On one hand, this config is too opinionated, on the other, these
  ;;   are the most commonly reconfigured variables in Org so they don't step on
  ;;   many toes. Consider either removing or simplifying this!
  (with-no-warnings
    (custom-declare-face '+org-todo-active  '((t (:inherit (bold font-lock-constant-face org-todo)))) "")
    (custom-declare-face '+org-todo-project '((t (:inherit (bold font-lock-doc-face org-todo)))) "")
    (custom-declare-face '+org-todo-onhold  '((t (:inherit (bold warning org-todo)))) "")
    (custom-declare-face '+org-todo-cancel  '((t (:inherit (bold error org-todo)))) ""))
  (setq org-todo-keywords
        '((sequence
           "TODO(t)"  ; A task that needs doing & is ready to do
           "PROJ(p)"  ; A project, which usually contains other tasks
           "LOOP(r)"  ; A recurring task
           "STRT(s)"  ; A task that is in progress
           "WAIT(w)"  ; Something external is holding up this task
           "HOLD(h)"  ; This task is paused/on hold because of me
           "IDEA(i)"  ; An unconfirmed and unapproved task or notion
           "|"
           "DONE(d)"  ; Task successfully completed
           "KILL(k)") ; Task was cancelled, aborted, or is no longer applicable
          (sequence
           "[ ](T)"   ; A task that needs doing
           "[-](S)"   ; Task is in progress
           "[?](W)"   ; Task is being held up or paused
           "|"
           "[X](D)")  ; Task was completed
          (sequence
           "|"
           "OKAY(o)"
           "YES(y)"
           "NO(n)"))
        org-todo-keyword-faces
        '(("[-]"  . +org-todo-active)
          ("STRT" . +org-todo-active)
          ("[?]"  . +org-todo-onhold)
          ("WAIT" . +org-todo-onhold)
          ("HOLD" . +org-todo-onhold)
          ("PROJ" . +org-todo-project)
          ("NO"   . +org-todo-cancel)
          ("KILL" . +org-todo-cancel)))

  (set-ligatures! 'org-mode
    :name "#+NAME:"
    :name "#+name:"
    :src_block "#+BEGIN_SRC"
    :src_block "#+begin_src"
    :src_block_end "#+END_SRC"
    :src_block_end "#+end_src"
    :quote "#+BEGIN_QUOTE"
    :quote "#+begin_quote"
    :quote_end "#+END_QUOTE"
    :quote_end "#+end_quote"))


(defun +org-init-babel-h ()
  (setq org-src-preserve-indentation t  ; use native major-mode indentation
        org-src-tab-acts-natively t     ; we do this ourselves
        ;; You don't need my permission (just be careful, mkay?)
        org-confirm-babel-evaluate nil
        org-link-elisp-confirm-function nil
        ;; Show src buffer in popup, and don't monopolize the frame
        org-src-window-setup 'other-window
        ;; Our :lang common-lisp module uses sly, so...
        org-babel-lisp-eval-fn #'sly-eval)

  ;; A shorter alias for markdown code blocks.
  (add-to-list 'org-src-lang-modes '("md" . markdown))

  ;; I prefer C-c C-c over C-c ' (more consistent)
  (define-key org-src-mode-map (kbd "C-c C-c") #'org-edit-src-exit)

  (defadvice! +org--fix-table-edit-hint-a (&rest _)
    "Show correct exit key hint for table.el editing.
table.el uses `table-cell-map' (a text property keymap) which captures C-c C-c
as a prefix for table operations, so the actual exit key is C-c '."
    :after #'org-edit-table.el
    (message "Edit, then exit with `C-c '' or abort with `C-c C-k'"))

  ;; Don't process babel results asynchronously when exporting org, as they
  ;; won't likely complete in time, and will instead output an ob-async hash
  ;; instead of the wanted evaluation results.
  (after! ob
    (add-to-list 'org-babel-default-lob-header-args '(:sync)))

  (defadvice! +org--exclude-expand-noweb-references-a (fn &rest args)
    :around #'ob-async-org-babel-execute-src-block
    (let ((async-inject-variables-exclude-regexps
           (cons "\\`org-babel-expand-noweb-references--cache-buffer\\'"
                 async-inject-variables-exclude-regexps)))
      (apply fn args)))

  (defadvice! +org-babel-disable-async-maybe-a (fn &optional orig-fn arg info params)
    "Use ob-comint where supported, disable async altogether where it isn't.

We have access to two async backends: ob-comint or ob-async, which have
different requirements. This advice tries to pick the best option between them,
falling back to synchronous execution otherwise. Without this advice, they die
with an error; terrible UX!

Note: ob-comint support will only kick in for languages listed in
`+org-babel-native-async-langs'.

Also adds support for a `:sync' parameter to override `:async'."
    :around #'ob-async-org-babel-execute-src-block
    (if (null orig-fn)
        (funcall fn orig-fn arg info params)
      (let* ((info (or info (org-babel-get-src-block-info)))
             (params (org-babel-merge-params (nth 2 info) params)))
        (if (or (assq :sync params)
                (not (assq :async params))
                (member (car info) ob-async-no-async-languages-alist)
                ;; ob-comint requires a :session, ob-async does not, so fall
                ;; back to ob-async if no :session is provided.
                (unless (member (alist-get :session params) '("none" nil))
                  (unless (memq (let* ((lang (nth 0 info))
                                       (lang (cond ((symbolp lang) lang)
                                                   ((stringp lang) (intern lang)))))
                                  (or (alist-get lang +org-babel-mode-alist)
                                      lang))
                                +org-babel-native-async-langs)
                    (message "Org babel: %s :session is incompatible with :async. Executing synchronously!"
                             (car info))
                    (sleep-for 0.2))
                  t))
            (funcall orig-fn arg info params)
          (funcall fn orig-fn arg info params)))))

  (defadvice! +org-inhibit-mode-hooks-a (fn datum name &optional initialize &rest args)
    "Prevent potentially expensive mode hooks in `org-babel-do-in-edit-buffer' ops."
    :around #'org-src--edit-element
    (apply fn datum name
           (if (and (eq org-src-window-setup 'switch-invisibly)
                    (functionp initialize))
               ;; org-babel-do-in-edit-buffer is used to execute quick, one-off
               ;; logic in the context of another major mode, but initializing a
               ;; major mode with expensive hooks can be terribly expensive.
               ;; Since Doom adds its most expensive hooks to
               ;; MAJOR-MODE-local-vars-hook, we can savely inhibit those.
               (lambda ()
                 (let ((doom-inhibit-local-var-hooks t))
                   (funcall initialize)))
             initialize)
           args))

  ;; Refresh inline images after executing src blocks (useful for plantuml,
  ;; where the result could be an image)
  (add-hook! 'org-babel-after-execute-hook
    (defun +org-redisplay-inline-images-in-babel-result-h ()
      (unless (or
               ;; ...but not while Emacs is exporting an org buffer (where
               ;; `org-display-inline-images' can be awfully slow).
               (bound-and-true-p org-export-current-backend)
               ;; ...and not while tangling org buffers (which happens in a temp
               ;; buffer where `buffer-file-name' is nil).
               (string-match-p "^ \\*temp" (buffer-name)))
        (save-excursion
          (when-let* ((beg (org-babel-where-is-src-block-result))
                      (end (progn (goto-char beg) (forward-line) (org-babel-result-end))))
            (org-display-inline-images nil nil (min beg end) (max beg end))))))))


(defun +org-init-babel-lazy-loader-h ()
  "Load babel libraries lazily when babel blocks are executed."
  (defun +org--babel-lazy-load (lang &optional async)
    (cl-check-type lang (or symbol null))
    ;; ob-async has its own agenda for lazy loading packages (in the child
    ;; process), so we only need to make sure it's loaded.
    (when async
      (require 'ob-async nil t))
    (unless (cdr (assq lang org-babel-load-languages))
      (prog1 (or (run-hook-with-args-until-success '+org-babel-load-functions lang)
                 (require (intern (format "ob-%s" lang)) nil t)
                 (require lang nil t))
        (add-to-list 'org-babel-load-languages (cons lang t)))))

  (defadvice! +org--export-lazy-load-library-h (&optional element)
    "Lazy load a babel package when a block is executed during exporting."
    :before #'org-babel-exp-src-block
    (+org--babel-lazy-load-library-a (org-babel-get-src-block-info nil element)))

  (defadvice! +org--src-lazy-load-library-a (lang)
    "Lazy load a babel package to ensure syntax highlighting."
    :before #'org-src--get-lang-mode
    (or (cdr (assoc lang org-src-lang-modes))
        (+org--babel-lazy-load lang)))

  ;; This also works for tangling
  (defadvice! +org--babel-lazy-load-library-a (info)
    "Load babel libraries lazily when babel blocks are executed."
    :after-while #'org-babel-confirm-evaluate
    (let* ((lang (nth 0 info))
           (lang (cond ((symbolp lang) lang)
                       ((stringp lang) (intern lang))))
           (lang (or (cdr (assq lang +org-babel-mode-alist))
                     lang)))
      (+org--babel-lazy-load
       lang (and (not (assq :sync (nth 2 info)))
                 (assq :async (nth 2 info))))
      t))

  (advice-add #'org-babel-do-load-languages :override #'ignore))


(defun +org-init-capture-defaults-h ()
  "Sets up some reasonable defaults, as well as two `org-capture' workflows that
I like:

1. The traditional way: invoking `org-capture' directly, via SPC X, or through
   the :cap ex command.
2. Through a org-capture popup frame that is invoked from outside Emacs (the
   ~/.emacs.d/bin/org-capture script). This can be invoked from qutebrowser,
   vimperator, dmenu or a global keybinding."
  (setq org-default-notes-file
        (expand-file-name +org-capture-notes-file org-directory)
        +org-capture-journal-file
        (expand-file-name +org-capture-journal-file org-directory)
        org-capture-templates
        '(("t" "Personal todo" entry
           (file+headline +org-capture-todo-file "Inbox")
           "* [ ] %?\n%i\n%a" :prepend t)
          ("n" "Personal notes" entry
           (file+headline +org-capture-notes-file "Inbox")
           "* %u %?\n%i\n%a" :prepend t)
          ("j" "Journal" entry
           (file+olp+datetree +org-capture-journal-file)
           "* %U %?\n%i\n%a" :prepend t)

          ;; Will use {project-root}/{todo,notes,changelog}.org, unless a
          ;; {todo,notes,changelog}.org file is found in a parent directory.
          ;; Uses the basename from `+org-capture-todo-file',
          ;; `+org-capture-changelog-file' and `+org-capture-notes-file'.
          ("p" "Templates for projects")
          ("pt" "Project-local todo" entry  ; {project-root}/todo.org
           (file+headline +org-capture-project-todo-file "Inbox")
           "* TODO %?\n%i\n%a" :prepend t)
          ("pn" "Project-local notes" entry  ; {project-root}/notes.org
           (file+headline +org-capture-project-notes-file "Inbox")
           "* %U %?\n%i\n%a" :prepend t)
          ("pc" "Project-local changelog" entry  ; {project-root}/changelog.org
           (file+headline +org-capture-project-changelog-file "Unreleased")
           "* %U %?\n%i\n%a" :prepend t)

          ;; Will use {org-directory}/{+org-capture-projects-file} and store
          ;; these under {ProjectName}/{Tasks,Notes,Changelog} headings. They
          ;; support `:parents' to specify what headings to put them under, e.g.
          ;; :parents ("Projects")
          ("o" "Centralized templates for projects")
          ("ot" "Project todo" entry
           (function +org-capture-central-project-todo-file)
           "* TODO %?\n %i\n %a"
           :heading "Tasks"
           :prepend nil)
          ("on" "Project notes" entry
           (function +org-capture-central-project-notes-file)
           "* %U %?\n %i\n %a"
           :heading "Notes"
           :prepend t)
          ("oc" "Project changelog" entry
           (function +org-capture-central-project-changelog-file)
           "* %U %?\n %i\n %a"
           :heading "Changelog"
           :prepend t)))

  ;; Kill capture buffers by default (unless they've been visited)
  (after! org-capture
    (org-capture-put :kill-buffer t))

  ;; Fix #462: when refiling from org-capture, Emacs prompts to kill the
  ;; underlying, modified buffer. This fixes that.
  (add-hook! 'org-after-refile-insert-hook
    (defun +org-save-buffer-after-capture-h ()
      (when (bound-and-true-p org-capture-is-refiling)
        (save-buffer))))

  ;; HACK: Doom doesn't support `customize'. Best not to advertise it as an
  ;;   option in `org-capture's menu.
  (defadvice! +org--remove-customize-option-a (fn table title &optional prompt specials)
    :around #'org-mks
    (funcall fn table title prompt
             (remove '("C" "Customize org-capture-templates")
                     specials)))

  (defadvice! +org--capture-expand-variable-file-a (file)
    "If a variable is used for a file path in `org-capture-template', it is used
as is, and expanded relative to `default-directory'. This changes it to be
relative to `org-directory', unless it is an absolute path."
    :filter-args #'org-capture-expand-file
    (if (and (symbolp file) (boundp file))
        (expand-file-name (symbol-value file) org-directory)
      file))

  (add-hook! 'org-capture-mode-hook
    (defun +org-show-target-in-capture-header-h ()
      (setq header-line-format
            (format "%s%s%s"
                    (propertize (abbreviate-file-name (buffer-file-name (buffer-base-buffer)))
                                'face 'font-lock-string-face)
                    org-eldoc-breadcrumb-separator
                    header-line-format)))))


(defun +org-init-capture-frame-h ()
  (add-hook 'org-capture-after-finalize-hook #'+org-capture-cleanup-frame-h)

  (defadvice! +org-capture-refile-cleanup-frame-a (&rest _)
    :after #'org-capture-refile
    (+org-capture-cleanup-frame-h))

  (when (modulep! :ui doom-dashboard)
    (add-hook '+doom-dashboard-inhibit-functions #'+org-capture-frame-p)))


(defun +org-init-attachments-h ()
  "Sets up org's attachment system."
  (setq org-attach-store-link-p 'attached     ; store link after attaching files
        org-attach-use-inheritance t) ; inherit properties from parent nodes

  ;; Autoload all these commands that org-attach doesn't autoload itself
  (use-package! org-attach
    :commands (org-attach-delete-one
               org-attach-delete-all
               org-attach-new
               org-attach-open
               org-attach-open-in-emacs
               org-attach-reveal-in-emacs
               org-attach-url
               org-attach-set-directory
               org-attach-sync)
    :config
    (unless org-attach-id-dir
      ;; Centralized attachments directory by default
      (setq-default org-attach-id-dir (expand-file-name ".attach/" org-directory)))
    (after! projectile
      (add-to-list 'projectile-globally-ignored-directories org-attach-id-dir)))

  ;; Add inline image previews for attachment links
  (org-link-set-parameters "attachment" :preview #'+org-preview-image-file-fn))


(defun +org-init-custom-links-h ()
  ;; Modify default file: links to colorize broken file links red
  (org-link-set-parameters
   "file" :face (lambda (path)
                  (if (or
                       ;; file uris is not a valid path on windows
                       ;; ref https://lists.gnu.org/archive/html/bug-gnu-emacs/2024-05/threads.html#00729
                       ;; emacs <= 29 crashes for (file-exists-p "file://whatever")
                       (if (featurep :system 'windows) (string-prefix-p "//" path))
                       (file-remote-p path)
                       ;; filter out network shares on windows (slow)
                       (if (featurep :system 'windows) (string-prefix-p "\\\\" path))
                       (file-exists-p path))
                      'org-link
                    '(warning org-link))))

  ;; Additional custom links for convenience
  (dolist (abbrev `(("github"      . "https://github.com/%s")
                    ("youtube"     . "https://youtube.com/watch?v=%s")
                    ("google"      . "https://google.com/search?q=")
                    ("gimages"     . "https://google.com/images?q=%s")
                    ("gmap"        . "https://maps.google.com/maps?q=%s")
                    ("kagi"        . "https://kagi.com/search?q=%s")
                    ("duckduckgo"  . "https://duckduckgo.com/?q=%s")
                    ("wikipedia"   . "https://en.wikipedia.org/wiki/%s")
                    ("wolfram"     . "https://wolframalpha.com/input/?i=%s")
                    ("doom-repo"   . "https://github.com/doomemacs/doomemacs/%s")
                    ("emacsdir"    . ,(doom-path doom-emacs-dir "%s"))
                    ("doomdir"     . ,(doom-path doom-user-dir "%s"))))
    (add-to-list 'org-link-abbrev-alist abbrev))

  (+org-define-basic-link "org" 'org-directory)
  (+org-define-basic-link "doom" 'doom-emacs-dir)
  (+org-define-basic-link "doom-docs" 'doom-docs-dir)
  (+org-define-basic-link "doom-modules" 'doom-modules-dir)

  ;; Add "lookup" links for packages and keystrings; useful for Emacs
  ;; documentation -- especially Doom's!
  (letf! ((defun -call-interactively (fn)
            (lambda (path _prefixarg)
              (funcall (or (command-remapping fn) fn)
                       (or (intern-soft path)
                           (user-error "Can't find documentation for %S" path))))))
    (org-link-set-parameters
     "kbd"
     :follow (lambda (ev)
               (interactive "e")
               (minibuffer-message "%s" (+org-link-doom--help-echo-from-textprop
                                         nil (current-buffer) (posn-point (event-start ev)))))
     :help-echo #'+org-link-doom--help-echo-from-textprop
     :face 'help-key-binding)
    (org-link-set-parameters
     "var"
     :follow (-call-interactively #'describe-variable)
     :activate-func #'+org-link--var-link-activate-fn
     :face '(font-lock-variable-name-face underline))
    (org-link-set-parameters
     "fn"
     :follow (-call-interactively #'describe-function)
     :activate-func #'+org-link--fn-link-activate-fn
     :face '(font-lock-function-name-face underline))
    (org-link-set-parameters
     "face"
     :follow (-call-interactively #'describe-face)
     :activate-func #'+org-link--face-link-activate-fn
     :face '(font-lock-type-face underline))
    (org-link-set-parameters
     "cmd"
     :follow (-call-interactively #'describe-command)
     :activate-func #'+org-link--command-link-activate-fn
     :face 'help-key-binding
     :help-echo #'+org-link-doom--help-echo-from-textprop)
    (org-link-set-parameters
     "doom-package"
     :follow #'+org-link--doom-package-link-follow-fn
     :activate-func #'+org-link--doom-package-link-activate-fn
     :help-echo #'+org-link-doom--help-echo-from-textprop)
    (org-link-set-parameters
     "doom-module"
     :follow #'+org-link--doom-module-link-follow-fn
     :activate-func #'+org-link--doom-module-link-activate-fn
     :help-echo #'+org-link-doom--help-echo-from-textprop)
    (org-link-set-parameters
     "doom-executable"
     :activate-func #'+org-link--doom-executable-link-activate-fn
     :help-echo #'+org-link-doom--help-echo-from-textprop
     :face 'org-verbatim)
    (org-link-set-parameters
     "doom-ref"
     :follow (lambda (link)
               (let ((link (+org-link-read-desc-at-point link))
                     (url "https://github.com")
                     (doom-repo "doomemacs/doomemacs"))
                 (save-match-data
                   (browse-url
                    (cond ((string-match "^\\([^/]+\\(?:/[^/]+\\)?\\)?#\\([0-9]+\\(?:#.*\\)?\\)" link)
                           (format "%s/%s/issues/%s" url
                                   (or (match-string 1 link)
                                       doom-repo)
                                   (match-string 2 link)))
                          ((string-match "^\\([^/]+\\(?:/[^/]+\\)?@\\)?\\([a-z0-9]\\{7,\\}\\(?:#.*\\)?\\)" link)
                           (format "%s/%s/commit/%s" url
                                   (or (match-string 1 link)
                                       doom-repo)
                                   (match-string 2 link)))
                          ((user-error "Invalid doom-ref link: %S" link)))))))
     :face (lambda (link)
             (let ((link (+org-link-read-desc-at-point link)))
               (if (or (string-match "^\\([^/]+\\(?:/[^/]+\\)?\\)?#\\([0-9]+\\(?:#.*\\)?\\)" link)
                       (string-match "^\\([^/]+\\(?:/[^/]+\\)?@\\)?\\([a-z0-9]\\{7,\\}\\(?:#.*\\)?\\)" link))
                   'org-link
                 'error))))
    (org-link-set-parameters
     "doom-user"
     :follow (lambda (link)
               (browse-url
                (format "https://github.com/%s"
                        (string-remove-prefix
                         "@" (+org-link-read-desc-at-point link)))))
     :face (lambda (_)
             ;; Avoid confusion with function `org-priority'
             'org-priority))
    (org-link-set-parameters
     "doom-changelog"
     :follow (lambda (link)
               (find-file (doom-path doom-docs-dir "changelog.org"))
               (org-match-sparse-tree nil link))))

  ;; Add "lookup" links for packages and keystrings; useful for Emacs
  ;; documentation -- especially Doom's!

  ;; Allow inline image previews of http(s)? urls or data uris.
  ;; `+org-link-preview-image-url-fn' will respect
  ;; `org-display-remote-inline-images'.
  (setq org-display-remote-inline-images 'download) ; TRAMP urls
  (org-link-set-parameters "http"  :preview #'+org-link-preview-image-url-fn)
  (org-link-set-parameters "https" :preview #'+org-link-preview-image-url-fn)
  (org-link-set-parameters "data"  :preview #'+org-link-preview-image-data-fn))


(defun +org-init-export-h ()
  "TODO"
  (setq org-export-with-smart-quotes t
        org-html-validation-link nil
        org-latex-prefer-user-labels t)

  (when (modulep! :lang markdown)
    (add-to-list 'org-export-backends 'md))

  (use-package! ox-pandoc
    :when (modulep! +pandoc)
    :when (executable-find "pandoc")
    :after ox
    :init
    (add-to-list 'org-export-backends 'pandoc)
    (setq org-pandoc-options
          '((standalone . t)
            (mathjax . t)
            (variable . "revealjs-url=https://revealjs.com"))))

  (defadvice! +org--dont-trigger-save-hooks-a (fn &rest args)
    "Exporting and tangling trigger save hooks; inadvertantly triggering
mutating hooks on exported output, like formatters."
    :around '(org-export-to-file org-babel-tangle)
    (let (before-save-hook after-save-hook)
      (apply fn args)))

  (defadvice! +org--fix-async-export-a (fn &rest args)
    :around '(org-export-to-file org-export-as)
    (let ((old-async-init-file org-export-async-init-file)
          (org-export-async-init-file (make-temp-file "doom-org-async-export")))
      (doom-file-write
       org-export-async-init-file
       `((setq org-export-async-debug ,(or org-export-async-debug debug-on-error)
               load-path ',load-path)
         (unwind-protect
             (let ((init-file ,old-async-init-file))
               (if init-file
                   (load init-file nil t)
                 (load ,early-init-file nil t)
                 (require 'doom-start)))
           (delete-file load-file-name))))
      (apply fn args))))


(defun +org-init-habit-h ()
  (add-hook! 'org-agenda-mode-hook
    (defun +org-habit-resize-graph-h ()
      "Right align and resize the consistency graphs based on
`+org-habit-graph-window-ratio'"
      (when (featurep 'org-habit)
        (let* ((total-days (float (+ org-habit-preceding-days org-habit-following-days)))
               (preceding-days-ratio (/ org-habit-preceding-days total-days))
               (graph-width (floor (* (window-width) +org-habit-graph-window-ratio)))
               (preceding-days (floor (* graph-width preceding-days-ratio)))
               (following-days (- graph-width preceding-days))
               (graph-column (- (window-width) (+ preceding-days following-days)))
               (graph-column-adjusted (if (> graph-column +org-habit-min-width)
                                          (- graph-column +org-habit-graph-padding)
                                        nil)))
          (setq-local org-habit-preceding-days preceding-days)
          (setq-local org-habit-following-days following-days)
          (setq-local org-habit-graph-column graph-column-adjusted))))))


(defun +org-init-hacks-h ()
  "Getting org to behave."
  ;; Open file links in current window, rather than new ones
  (setf (alist-get 'file org-link-frame-setup) #'find-file)
  ;; Open directory links in dired
  (add-to-list 'org-file-apps '(directory . emacs))
  (add-to-list 'org-file-apps '(remote . emacs))

  (defadvice! +org--strip-properties-from-outline-a (fn &rest args)
    "Fix variable height faces in eldoc breadcrumbs."
    :around #'org-format-outline-path
    (let ((org-level-faces
           (cl-loop for face in org-level-faces
                    collect `(:foreground ,(face-foreground face nil t)
                              :weight bold))))
      (apply fn args)))

  (defun +org--restart-mode-h ()
    "Restart `org-mode', but only once."
    (remove-hook 'doom-switch-buffer-hook #'+org--restart-mode-h 'local)
    (quiet! (org-mode-restart))
    (cl-callf2 delq (current-buffer) org-agenda-new-buffers)
    (run-hooks 'find-file-hook))

  (add-hook! 'org-agenda-finalize-hook
    (defun +org-exclude-agenda-buffers-from-workspace-h ()
      "Don't associate temporary agenda buffers with current workspace."
      (when (and org-agenda-new-buffers
                 (bound-and-true-p persp-mode)
                 (not org-agenda-sticky))
        (let (persp-autokill-buffer-on-remove)
          (persp-remove-buffer org-agenda-new-buffers
                               (get-current-persp)
                               nil)))))

  (defadvice! +org--restart-mode-before-indirect-buffer-a (&optional buffer _)
    "Restart `org-mode' in buffers in which the mode has been deferred (see
`+org-defer-mode-in-agenda-buffers-h') before they become the base buffer for an
indirect org-cpature buffer. This ensures that the buffer is fully functional
not only when the *user* visits it, but also when org-capture interacts with it
via an indirect buffer."
    :before #'org-capture-get-indirect-buffer
    (with-current-buffer (or buffer (current-buffer))
      (when (memq #'+org--restart-mode-h doom-switch-buffer-hook)
        (+org--restart-mode-h))))

  (defvar recentf-exclude)
  (defvar so-long-target-modes)
  (defadvice! +org--optimize-backgrounded-agenda-buffers-a (fn file)
    "Disable `org-mode's startup processes for temporary agenda buffers.

Prevents recentf pollution as well. However, if the user tries to visit one of
these buffers they'll see a gimped, half-broken org buffer, so to avoid that,
install a hook to restart `org-mode' when they're switched to so they can grow
up to be fully-fledged org-mode buffers."
    :around #'org-get-agenda-file-buffer
    (if-let* ((buf (org-find-base-buffer-visiting file)))
        buf
      (let ((recentf-exclude '(always))
            (doom-inhibit-local-var-hooks t)
            (org-inhibit-startup t)
            so-long-target-modes
            vc-handled-backends
            enable-local-variables
            find-file-hook)
        (when-let* ((buf (delay-mode-hooks (funcall fn file))))
          (with-current-buffer buf
            (add-hook 'doom-switch-buffer-hook #'+org--restart-mode-h
                      nil 'local))
          buf))))

  (defadvice! +org--fix-inconsistent-uuidgen-case-a (uuid)
    "Ensure uuidgen is always lowercase (consistent) regardless of system.
See https://lists.gnu.org/archive/html/emacs-orgmode/2019-07/msg00081.html."
    :filter-return #'org-id-new
    (if (eq org-id-method 'uuid)
        (downcase uuid)
      uuid)))


(defun +org-init-keybinds-h ()
  "Sets up org-mode and evil keybindings. Tries to fix the idiosyncrasies
between the two."
  (add-hook 'doom-escape-hook #'+org-remove-occur-highlights-h)

  ;; C-a & C-e act like `doom/backward-to-bol-or-indent' and
  ;; `doom/forward-to-last-non-comment-or-eol', but with more org awareness.
  (setq org-special-ctrl-a/e t)

  (setq org-M-RET-may-split-line nil
        ;; insert new headings after current subtree rather than inside it
        org-insert-heading-respect-content t)

  (add-hook! 'org-tab-first-hook
             #'+org-yas-expand-maybe-h
             #'+org-indent-maybe-h)

  (add-hook 'doom-delete-backward-functions
            #'+org-delete-backward-char-and-realign-table-maybe-h)

  (map! :map org-mode-map
        "C-c C-S-l"  #'+org/remove-link
        "C-c <C-i>"  #'org-link-preview-refresh
        ;; textmate-esque newline insertion
        "S-RET"      #'+org/shift-return
        "C-RET"      #'+org/insert-item-below
        "C-S-RET"    #'+org/insert-item-above
        "C-M-RET"    #'org-insert-subheading
        [C-return]   #'+org/insert-item-below
        [C-S-return] #'+org/insert-item-above
        [C-M-return] #'org-insert-subheading
        (:when (featurep :system 'macos)
         [s-return]   #'+org/insert-item-below
         [s-S-return] #'+org/insert-item-above
         [s-M-return] #'org-insert-subheading)
        ;; Org-aware C-a/C-e
        [remap doom/backward-to-bol-or-indent]          #'org-beginning-of-line
        [remap doom/forward-to-last-non-comment-or-eol] #'org-end-of-line

        :localleader
        "#" #'org-update-statistics-cookies
        "'" #'org-edit-special
        "*" #'org-ctrl-c-star
        "-" #'org-ctrl-c-minus
        "," #'org-switchb
        "." #'org-goto
        "@" #'org-cite-insert
        (:when (modulep! :completion ivy)
         "." #'counsel-org-goto
         "/" #'counsel-org-goto-all)
        (:when (modulep! :completion helm)
         "." #'helm-org-in-buffer-headings
         "/" #'helm-org-agenda-files-headings)
        (:when (modulep! :completion vertico)
         "." #'consult-org-heading
         "/" #'consult-org-agenda)
        "A" #'org-archive-subtree-default
        "e" #'org-export-dispatch
        "f" #'org-footnote-action
        "h" #'org-toggle-heading
        "i" #'org-toggle-item
        "I" #'org-id-get-create
        "k" #'org-babel-remove-result
        "K" #'+org/remove-result-blocks
        "n" #'org-store-link
        "o" #'org-set-property
        "q" #'org-set-tags-command
        "t" #'org-todo
        "T" #'org-todo-list
        "x" #'org-toggle-checkbox
        (:prefix ("a" . "attachments")
         "a" #'org-attach
         "d" #'org-attach-delete-one
         "D" #'org-attach-delete-all
         "f" #'+org/find-file-in-attachments
         "l" #'+org/attach-file-and-insert-link
         "n" #'org-attach-new
         "o" #'org-attach-open
         "O" #'org-attach-open-in-emacs
         "r" #'org-attach-reveal
         "R" #'org-attach-reveal-in-emacs
         "u" #'org-attach-url
         "s" #'org-attach-set-directory
         "S" #'org-attach-sync
         (:when (modulep! +dragndrop)
          "c" #'org-download-screenshot
          "p" #'org-download-clipboard
          "P" #'org-download-yank))
        (:prefix ("b" . "tables")
         "-" #'org-table-insert-hline
         "a" #'org-table-align
         "b" #'org-table-blank-field
         "c" #'org-table-create-or-convert-from-region
         "e" #'org-table-edit-field
         "f" #'org-table-edit-formulas
         "h" #'org-table-field-info
         "s" #'org-table-sort-lines
         "r" #'org-table-recalculate
         "R" #'org-table-recalculate-buffer-tables
         (:prefix ("d" . "delete")
          "c" #'org-table-delete-column
          "r" #'org-table-kill-row)
         (:prefix ("i" . "insert")
          "c" #'org-table-insert-column
          "h" #'org-table-insert-hline
          "r" #'org-table-insert-row
          "H" #'org-table-hline-and-move)
         (:prefix ("t" . "toggle")
          "f" #'org-table-toggle-formula-debugger
          "o" #'org-table-toggle-coordinate-overlays)
         (:when (modulep! +gnuplot)
          "p" #'org-plot/gnuplot))
        (:prefix ("c" . "clock")
         "c" #'org-clock-cancel
         "d" #'org-clock-mark-default-task
         "e" #'org-clock-modify-effort-estimate
         "E" #'org-set-effort
         "g" #'org-clock-goto
         "G" (cmd! (org-clock-goto 'select))
         "l" #'+org/toggle-last-clock
         "i" #'org-clock-in
         "I" #'org-clock-in-last
         "o" #'org-clock-out
         "r" #'org-resolve-clocks
         "R" #'org-clock-report
         "t" #'org-evaluate-time-range
         "=" #'org-clock-timestamps-up
         "-" #'org-clock-timestamps-down)
        (:prefix ("d" . "date/deadline")
         "d" #'org-deadline
         "s" #'org-schedule
         "t" #'org-time-stamp
         "T" #'org-time-stamp-inactive)
        (:prefix ("g" . "goto")
         "g" #'org-goto
         (:when (modulep! :completion ivy)
          "g" #'counsel-org-goto
          "G" #'counsel-org-goto-all)
         (:when (modulep! :completion helm)
          "g" #'helm-org-in-buffer-headings
          "G" #'helm-org-agenda-files-headings)
         (:when (modulep! :completion vertico)
          "g" #'consult-org-heading
          "G" #'consult-org-agenda)
         "c" #'org-clock-goto
         "C" (cmd! (org-clock-goto 'select))
         "i" #'org-id-goto
         "r" #'org-refile-goto-last-stored
         "v" #'+org/goto-visible
         "x" #'org-capture-goto-last-stored)
        (:prefix ("l" . "links")
         "c" #'org-cliplink
         "d" #'+org/remove-link
         "i" #'org-id-store-link
         "l" #'org-insert-link
         "L" #'org-insert-all-links
         "s" #'org-store-link
         "S" #'org-insert-last-stored-link
         "t" #'org-toggle-link-display
         "y" #'+org/yank-link
         (:when (modulep! :os macos)
          "g" #'org-mac-link-get-link))
        (:prefix ("P" . "publish")
         "a" #'org-publish-all
         "f" #'org-publish-current-file
         "p" #'org-publish
         "P" #'org-publish-current-project
         "s" #'org-publish-sitemap)
        (:prefix ("r" . "refile")
         "." #'+org/refile-to-current-file
         "c" #'+org/refile-to-running-clock
         "l" #'+org/refile-to-last-location
         "f" #'+org/refile-to-file
         "o" #'+org/refile-to-other-window
         "O" #'+org/refile-to-other-buffer
         "v" #'+org/refile-to-visible
         "r" #'org-refile
         "R" #'org-refile-reverse) ; to all `org-refile-targets'
        (:prefix ("s" . "tree/subtree")
         "a" #'org-toggle-archive-tag
         "b" #'org-tree-to-indirect-buffer
         "c" #'org-clone-subtree-with-time-shift
         "d" #'org-cut-subtree
         "h" #'org-promote-subtree
         "j" #'org-move-subtree-down
         "k" #'org-move-subtree-up
         "l" #'org-demote-subtree
         "n" #'org-narrow-to-subtree
         "r" #'org-refile
         "s" #'org-sparse-tree
         "A" #'org-archive-subtree-default
         "N" #'widen
         "S" #'org-sort)
        (:prefix ("p" . "priority")
         "d" #'org-priority-down
         "p" #'org-priority
         "u" #'org-priority-up))

  (map! :after org-agenda
        :map org-agenda-mode-map
        :m "C-SPC" #'org-agenda-show-and-scroll-up
        :localleader
        (:prefix ("d" . "date/deadline")
         "d" #'org-agenda-deadline
         "s" #'org-agenda-schedule)
        (:prefix ("c" . "clock")
         "c" #'org-agenda-clock-cancel
         "g" #'org-agenda-clock-goto
         "i" #'org-agenda-clock-in
         "o" #'org-agenda-clock-out
         "r" #'org-agenda-clockreport-mode
         "s" #'org-agenda-show-clocking-issues)
        (:prefix ("p" . "priority")
         "d" #'org-agenda-priority-down
         "p" #'org-agenda-priority
         "u" #'org-agenda-priority-up)
        "q" #'org-agenda-set-tags
        "r" #'org-agenda-refile
        "t" #'org-agenda-todo))


(defun +org-init-popup-rules-h ()
  (set-popup-rules!
    '(("^\\*Org Links" :slot -1 :vslot -1 :size 2 :ttl 0)
      ("^ ?\\*\\(?:Agenda Com\\|Calendar\\|Org Export Dispatcher\\)"
       :slot -1 :vslot -1 :size #'+popup-shrink-to-fit :ttl 0)
      ("^\\*Org \\(?:Select\\|Attach\\|Table Edit\\)" :slot -1 :vslot -2 :ttl 0 :size 0.25)
      ("^\\*Edit Formulas\\*$" :slot -1 :vslot -2 :ttl 0 :size 0.25)
      ("^\\*Org Agenda"     :ignore t)
      ("^\\*Org Src"        :size 0.42  :quit nil :select t :autosave t :modeline t :ttl nil)
      ("^\\*Org-Babel")
      ("^\\*Capture\\*$\\|CAPTURE-.*$" :size 0.42 :quit nil :select t :autosave ignore))))


(defun +org-init-smartparens-h ()
  ;; Disable the slow defaults
  (provide 'smartparens-org))


;;
;;; Packages

(use-package! toc-org ; auto-table of contents
  :hook (org-mode . toc-org-enable)
  :config
  (setq toc-org-hrefify-default "gh")

  (defadvice! +org-inhibit-scrolling-a (fn &rest args)
    "Prevent the jarring scrolling that occurs when the-ToC is regenerated."
    :around #'toc-org-insert-toc
    (let ((p (set-marker (make-marker) (point)))
          (s (window-start)))
      (prog1 (apply fn args)
        (goto-char p)
        (set-window-start nil s t)
        (set-marker p nil)))))


(use-package! org-crypt ; built-in
  :when (modulep! +crypt)
  :commands org-encrypt-entries org-encrypt-entry org-decrypt-entries org-decrypt-entry
  :hook (org-load . org-crypt-use-before-save-magic)
  :preface
  ;; org-crypt falls back to CRYPTKEY property then `epa-file-encrypt-to', which
  ;; is a better default than the empty string `org-crypt-key' defaults to.
  (defvar org-crypt-key nil)
  (after! org (add-to-list 'org-tags-exclude-from-inheritance "crypt")))


(use-package! org-clock ; built-in
  :commands org-clock-save
  :init
  (setq org-clock-persist-file (file-name-concat doom-profile-data-dir "org-clock-save.el"))
  (defadvice! +org--clock-load-a (&rest _)
    "Lazy load org-clock until its commands are used."
    :before '(org-clock-in
              org-clock-out
              org-clock-in-last
              org-clock-goto
              org-clock-cancel)
    (org-clock-load))
  :config
  (setq org-clock-persist 'history
        ;; Resume when clocking into task with open clock
        org-clock-in-resume t
        ;; Remove log if task was clocked for 0:00 (accidental clocking)
        org-clock-out-remove-zero-time-clocks t
        ;; The default value (5) is too conservative.
        org-clock-history-length 20)
  (add-hook 'kill-emacs-hook #'org-clock-save))


(use-package! org-eldoc
  ;; HACK: Fix #7633: this hook is no longer autoloaded by org-eldoc (in
  ;;   org-contrib), so we have to add it ourselves.
  :hook (org-mode . org-eldoc-load)
  :init (setq org-eldoc-breadcrumb-separator " → ")
  :config
  (defadvice! +org-eldoc--display-link-at-point-a (&rest _)
    "Display help for doom-*: links in minibuffer when cursor/mouse is over it."
    :before-until #'org-eldoc-documentation-function
    (if-let* ((url (thing-at-point 'url t)))
        (format "LINK: %s" url)
      (and (eq (get-text-property (point) 'help-echo)
               #'+org-link-doom--help-echo-from-textprop)
           (+org-link-doom--help-echo-from-textprop nil (current-buffer) (point)))))

  ;; HACK: Fix #2972: infinite recursion when eldoc kicks in 'org' or 'python'
  ;;   src blocks.
  ;; REVIEW: Should be reported upstream!
  (puthash "org" #'ignore org-eldoc-local-functions-cache)
  (puthash "plantuml" #'ignore org-eldoc-local-functions-cache)
  (puthash "python" #'python-eldoc-function org-eldoc-local-functions-cache))


(use-package! evil-org
  :when (modulep! :editor evil +everywhere)
  :hook (org-mode . evil-org-mode)
  :hook (org-capture-mode . evil-insert-state)
  :hook (doom-docs-org-mode . evil-org-mode)
  :init
  (defvar evil-org-retain-visual-state-on-shift t)
  (defvar evil-org-special-o/O '(table-row))
  (defvar evil-org-use-additional-insert t)
  :config
  (setq org-cycle-emulate-tab nil) ; don't insert TAB in non-insert modes
  (add-hook 'evil-org-mode-hook #'evil-normalize-keymaps)
  (evil-org-set-key-theme)
  (add-hook! 'org-tab-first-hook :append
             ;; Only fold the current tree, rather than recursively
             #'+org-cycle-only-current-subtree-h
             ;; Clear babel results if point is inside a src block
             #'+org-clear-babel-results-h)
  (let-alist evil-org-movement-bindings
    (let ((Cright  (concat "C-" .right))
          (Cleft   (concat "C-" .left))
          (Cup     (concat "C-" .up))
          (Cdown   (concat "C-" .down))
          (CSright (concat "C-S-" .right))
          (CSleft  (concat "C-S-" .left))
          (CSup    (concat "C-S-" .up))
          (CSdown  (concat "C-S-" .down)))
      (map! :map evil-org-mode-map
            :ni [C-return]   #'+org/insert-item-below
            :ni [C-S-return] #'+org/insert-item-above
            (:unless evil-disable-insert-state-bindings
             :i Cright (cmds! (org-at-table-p) #'org-table-next-field
                              #'org-end-of-line)
             :i Cleft  (cmds! (org-at-table-p) #'org-table-previous-field
                              #'org-beginning-of-line)
             :i Cup    (cmds! (org-at-table-p) #'+org/table-previous-row
                              #'org-up-element)
             :i Cdown  (cmds! (org-at-table-p) #'org-table-next-row
                              #'org-down-element)
             :i CSright   #'org-shiftright
             :i CSleft    #'org-shiftleft
             :i CSup      #'org-shiftup
             :i CSdown    #'org-shiftdown)
            :n CSright    #'org-shiftright
            :n CSleft     #'org-shiftleft
            :n CSup       #'org-shiftup
            :n CSdown     #'org-shiftdown
            ;; more intuitive RET keybinds
            :m "RET"      #'+org/dwim-at-point
            :i "RET"      #'+org/return
            :i [S-return] #'+org/shift-return
            :i "S-RET"    #'+org/shift-return
            ;; more vim-esque org motion keys (not covered by evil-org-mode)
            :m "]h"  #'org-forward-heading-same-level
            :m "[h"  #'org-backward-heading-same-level
            :m "]l"  #'org-next-link
            :m "[l"  #'org-previous-link
            :m "]c"  #'org-babel-next-src-block
            :m "[c"  #'org-babel-previous-src-block
            :n "gQ"  #'+org/reformat-at-point
            ;; sensible vim-esque folding keybinds
            :n "za"  #'+org/toggle-fold
            :n "zA"  #'org-shifttab
            :n "zc"  #'+org/close-fold
            :n "zC"  #'outline-hide-subtree
            :n "zm"  #'+org/hide-next-fold-level
            :n "zM"  #'+org/close-all-folds
            :n "zn"  #'org-tree-to-indirect-buffer
            :n "zo"  #'+org/open-fold
            :n "zO"  #'outline-show-subtree
            :n "zr"  #'+org/show-next-fold-level
            :n "zR"  #'+org/open-all-folds
            :n "zi"  #'org-toggle-inline-images

            :map org-read-date-minibuffer-local-map
            Cleft    (cmd! (org-eval-in-calendar '(calendar-backward-day 1)))
            Cright   (cmd! (org-eval-in-calendar '(calendar-forward-day 1)))
            Cup      (cmd! (org-eval-in-calendar '(calendar-backward-week 1)))
            Cdown    (cmd! (org-eval-in-calendar '(calendar-forward-week 1)))
            CSleft   (cmd! (org-eval-in-calendar '(calendar-backward-month 1)))
            CSright  (cmd! (org-eval-in-calendar '(calendar-forward-month 1)))
            CSup     (cmd! (org-eval-in-calendar '(calendar-backward-year 1)))
            CSdown   (cmd! (org-eval-in-calendar '(calendar-forward-year 1)))))))


(use-package! evil-org-agenda
  :when (modulep! :editor evil +everywhere)
  :hook (org-agenda-mode . evil-org-agenda-mode)
  :config
  (evil-org-agenda-set-keys)
  (evil-define-key* 'motion evil-org-agenda-mode-map
    (kbd doom-leader-key) nil))


;;
;;; Bootstrap

(use-package! org
  :defer-incrementally
  calendar find-func format-spec org-macs org-compat org-faces org-entities
  org-list org-pcomplete org-src org-footnote org-macro ob org org-agenda
  org-capture
  :preface
  ;; Set to nil so we can detect user changes to them later (and fall back on
  ;; defaults otherwise).
  (defvar org-directory nil)
  (defvar org-id-locations-file nil)
  (defvar org-attach-id-dir nil)
  (defvar org-babel-python-command nil)

  (setq org-persist-directory (file-name-concat doom-profile-cache-dir "org" "persist/")
        org-publish-timestamp-directory (file-name-concat doom-profile-cache-dir "org" "timestamps/")
        org-preview-latex-image-directory (file-name-concat doom-profile-cache-dir "org" "latex/")
        ;; Recognize a), A), a., A., etc -- must be set before org is loaded.
        org-list-allow-alphabetical t)

  ;; Make all default modules opt-in to lighten org's first-time load delay. I
  ;; sincerely doubt users use them all.
  (defvar org-modules nil)
  ;; Autoload common or module-specific link types from ol-* libs, so they're
  ;; available without needlessly loading them up front.
  (after! org
    (dolist (spec `((ol-info "info"
                     :follow org-info-open
                     :export org-info-export
                     :store org-info-store-link
                     :insert-description org-info-description-as-command)
                    ,@(when (modulep! :emacs eww)
                        '((ol-eww "eww"
                           :follow org-eww-open
                           :store org-eww-store-link)))
                    ,@(when (modulep! :tools biblo)
                        '((ol-bibtex "bibtex"
                           :follow org-bibtex-open
                           :store org-bibtex-store-link)))))
      (apply #'org-link-set-parameters (cadr spec) (cddr spec))
      (mapc (doom-rpartial #'autoload (symbol-name (car spec)))
            (cl-delete-if #'keywordp (cddr spec)))))

  ;;; Custom org modules
  (dolist (flag (doom-module :lang 'org :flags))
    (when (eq flag '+roam2)  ; REVIEW: remove in v3
      (setq flag '+roam))
    (load! (concat "contrib/" (substring (symbol-name flag) 1)) nil t))

  ;; Add our general hooks after the submodules, so that any hooks the
  ;; submodules add run after them, and can overwrite any defaults if necessary.
  (add-hook! 'org-mode-hook
             ;; `show-paren-mode' causes flickering with indent overlays made by
             ;; `org-indent-mode', so we turn off show-paren-mode altogether
             #'doom-disable-show-paren-mode-h
             ;; disable `show-trailing-whitespace'; shows a lot of false positives
             #'doom-disable-show-trailing-whitespace-h)

  (add-hook! 'org-load-hook
             #'+org-init-org-directory-h
             #'+org-init-appearance-h
             #'+org-init-agenda-h
             #'+org-init-attachments-h
             #'+org-init-babel-h
             #'+org-init-babel-lazy-loader-h
             #'+org-init-capture-defaults-h
             #'+org-init-capture-frame-h
             #'+org-init-custom-links-h
             #'+org-init-export-h
             #'+org-init-habit-h
             #'+org-init-hacks-h
             #'+org-init-keybinds-h
             #'+org-init-popup-rules-h
             #'+org-init-smartparens-h)

  ;; HACK: Since 9.8, org-agenda fails to properly initialize on first
  ;;   invokation for some reason. Until this is sorted out, this will
  ;;   automatically reload it.
  (add-hook! 'org-agenda-finalize-hook
    (defun +org--reload-org-agenda-h ()
      (when (get-buffer-window nil t) ; make sure it's visible
        (remove-hook 'org-agenda-finalize-hook #'+org--reload-org-agenda-h)
        (org-agenda-redo nil))))

  ;; Wait until an org-protocol link is opened via emacsclient to load
  ;; `org-protocol'. Normally you'd simply require `org-protocol' and use it,
  ;; but the package loads all of org for no compelling reason, so...
  (defadvice! +org--server-visit-files-a (fn files &rest args)
    "Advise `server-visit-files' to load `org-protocol' lazily."
    :around #'server-visit-files
    (if (not (cl-loop with protocol =
                      (if (featurep :system 'windows)
                          ;; On Windows, the file arguments for `emacsclient'
                          ;; get funnelled through `expand-file-path' by
                          ;; `server-process-filter'. This substitutes
                          ;; backslashes with forward slashes and converts each
                          ;; path to an absolute one. However, *all* absolute
                          ;; paths on Windows will match the regexp ":/+", so we
                          ;; need a more discerning regexp.
                          (regexp-quote
                           (or (bound-and-true-p org-protocol-the-protocol)
                               "org-protocol"))
                        ;; ...but since there is a miniscule possibility users
                        ;; have changed `org-protocol-the-protocol' I don't want
                        ;; this behavior for macOS/Linux users.
                        "")
                      for var in files
                      if (string-match-p (format "%s:/+" protocol) (car var))
                      return t))
        (apply fn files args)
      (require 'org-protocol)
      (apply #'org--protocol-detect-protocol-server fn files args)))
  (after! org-protocol
    (advice-remove 'server-visit-files #'org--protocol-detect-protocol-server))

  ;; In case the user has eagerly loaded org from their configs
  (when (and (featurep 'org)
             (not byte-compile-current-file))
    (unless (doom-context-p 'reload)
      (message "`org' was already loaded by the time lang/org loaded, this may cause issues"))
    (run-hooks 'org-load-hook))

  :config
  (set-debug-var! 'org-export-async-debug)

  (set-company-backend! 'org-mode 'company-capf)
  (set-eval-handler! 'org-mode #'+org-eval-handler)
  (set-lookup-handlers! 'org-mode
    :definition #'+org-lookup-definition-handler
    :references #'+org-lookup-references-handler
    :documentation #'+org-lookup-documentation-handler)

  (add-hook! 'org-mode-hook
    ;; HACK: `save-place' can position the cursor in an invisible region. This
    ;;   makes it visible unless `org-inhibit-startup' or
    ;;   `org-inhibit-startup-visibility-stuff' is non-nil.
    (add-hook 'save-place-after-find-file-hook #'+org-make-last-point-visible-h nil t))

  ;; Save target buffer after archiving a node.
  (setq org-archive-subtree-save-file-p t)

  ;; Don't number headings with these tags
  (setq org-num-face '(:inherit org-special-keyword :underline nil :weight bold)
        org-num-skip-tags '("noexport" "nonum"))

  ;; Other org properties are all-caps. Be consistent.
  (setq org-effort-property "EFFORT")

  ;; HACK: `org-id' doesn't check if `org-id-locations-file' exists or is
  ;;   writeable before trying to read/write to it, potentially throwing a
  ;;   file-error if it doesn't, which can leave Org in a broken state.
  (defadvice! +org--fail-gracefully-a (fn &rest args)
    :around '(org-id-locations-save org-id-locations-load)
    (with-demoted-errors "org-id-locations: %s"
      (apply fn args)))

  (add-hook 'org-open-at-point-functions #'doom-set-jump-h)
  ;; HACK: For functions that dodge `org-open-at-point-functions', like
  ;;   `org-id-open', `org-goto', or roam: links.
  (advice-add #'org-mark-ring-push :around #'doom-set-jump-a)

  ;; Add the ability to play gifs, at point or throughout the buffer. However,
  ;; 'playgifs' is stupid slow and there's not much I can do to fix it; use at
  ;; your own risk.
  (add-to-list 'org-startup-options '("inlinegifs" +org-startup-with-animated-gifs at-point))
  (add-to-list 'org-startup-options '("playgifs"   +org-startup-with-animated-gifs t))
  (add-hook! 'org-mode-local-vars-hook
    (defun +org-init-gifs-h ()
      (remove-hook 'post-command-hook #'+org-play-gif-at-point-h t)
      (remove-hook 'post-command-hook #'+org-play-all-gifs-h t)
      (pcase +org-startup-with-animated-gifs
        (`at-point (add-hook 'post-command-hook #'+org-play-gif-at-point-h nil t))
        (`t (add-hook 'post-command-hook #'+org-play-all-gifs-h nil t))))))
