;;; tools/lookup/autoload/lookup.el -*- lexical-binding: t; -*-

;;;###autodef
(defun set-lookup-handlers! (modes &rest plist)
  "Define jump handlers for major or minor MODES.

A handler is either an interactive command that changes the current buffer
and/or location of the cursor, or a function that takes one argument: the
identifier being looked up, and returns either nil (failed to find it), t
(succeeded at changing the buffer/moving the cursor), or 'deferred (assume this
handler has succeeded, but expect changes not to be visible yet).

There are several kinds of handlers, which can be defined with the following
properties:

:definition FN
  Run when jumping to a symbol's definition. Used by `+lookup/definition'.
:implementations FN
  Run when looking for implementations of a symbol in the current project. Used
  by `+lookup/implementations'.
:type-definition FN
  Run when jumping to a symbol's type definition. Used by
  `+lookup/type-definition'.
:references FN
  Run when looking for usage references of a symbol in the current project. Used
  by `+lookup/references'.
:documentation FN
  Run when looking up documentation for a symbol. Used by
  `+lookup/documentation'.
:file FN
  Run when looking up the file for a symbol/string. Typically a file path. Used
  by `+lookup/file'.
:xref-backend FN
  Defines an xref backend for a major-mode. A :definition and :references
  handler isn't necessary with a :xref-backend, but will have higher precedence
  if they exist.
:async BOOL
  Indicates that *all* supplied FNs are asynchronous. Note: lookups will not try
  any handlers after async ones, due to their nature. To get around this, you
  must write a specialized wrapper to await the async response, or use a
  different heuristic to determine, ahead of time, whether the async call will
  succeed or not.

  If you only want to specify one FN is async, declare it inline instead:

    (set-lookup-handlers! 'rust-mode
      :definition '(racer-find-definition :async t))

Handlers can either be interactive or non-interactive. Non-interactive handlers
must take one argument: the identifier being looked up. This function must
change the current buffer or window or return non-nil when it succeeds.

If it doesn't change the current buffer, or it returns nil, the lookup module
will fall back to the next handler in `+lookup-definition-functions',
`+lookup-implementations-functions', `+lookup-type-definition-functions',
`+lookup-references-functions', `+lookup-file-functions' or
`+lookup-documentation-functions'.

Consecutive `set-lookup-handlers!' calls will overwrite previously defined
handlers for MODES. If used on minor modes, they are stacked onto handlers
defined for other minor modes or the major mode it's activated in.

This can be passed nil as its second argument to unset handlers for MODES. e.g.

  (set-lookup-handlers! 'python-mode nil)

\(fn MODES &key DEFINITION IMPLEMENTATIONS TYPE-DEFINITION REFERENCES DOCUMENTATION FILE XREF-BACKEND ASYNC)"
  (declare (indent defun))
  (dolist (mode (ensure-list modes))
    (let ((hook (intern (format "%s-hook" mode)))
          (fn   (intern (format "+lookup--init-%s-handlers-h" mode))))
      (if (null (car plist))
          (progn
            (remove-hook hook fn)
            (unintern fn nil))
        (fset
         fn
         (lambda ()
           (cl-destructuring-bind (&key definition implementations type-definition references documentation file xref-backend async)
               plist
             (cl-mapc #'+lookup--set-handler
                      (list definition
                            implementations
                            type-definition
                            references
                            documentation
                            file
                            xref-backend)
                      (list '+lookup-definition-functions
                            '+lookup-implementations-functions
                            '+lookup-type-definition-functions
                            '+lookup-references-functions
                            '+lookup-documentation-functions
                            '+lookup-file-functions
                            'xref-backend-functions)
                      (make-list 5 async)
                      (make-list 5 (or (eq major-mode mode)
                                       (memq mode (get major-mode 'derived-mode-extra-parents))
                                       (and (boundp mode)
                                            (symbol-value mode))))))))
        (add-hook hook fn)))))


;;
;;; Helpers

(defun +lookup--set-handler (spec functions-var &optional async enable)
  (when spec
    (cl-destructuring-bind (fn . plist)
        (ensure-list spec)
      (if (not enable)
          (remove-hook functions-var fn 'local)
        (put fn '+lookup-async (or (plist-get plist :async) async))
        (add-hook functions-var fn nil 'local)))))

(defun +lookup--run-handler (handler identifier)
  (if (commandp handler)
      (call-interactively handler)
    (funcall handler identifier)))

(defun +lookup--run-handlers (handler identifier origin)
  (doom-log "Looking up '%s' with '%s'" identifier handler)
  (condition-case-unless-debug e
      (let ((wconf (current-window-configuration))
            (result (condition-case-unless-debug e
                        (+lookup--run-handler handler identifier)
                      (error
                       (doom-log "Lookup handler %S threw an error: %s" handler e)
                       'fail))))
        (cond ((eq result 'fail)
               (set-window-configuration wconf)
               nil)
              ((or (get handler '+lookup-async)
                   (eq result 'deferred)))
              ((or result
                   (null origin)
                   (/= (point-marker) origin))
               (prog1 (point-marker)
                 (set-window-configuration wconf)))))
    ((error user-error)
     (message "Lookup handler %S: %s" handler e)
     nil)))

(defun +lookup--jump-to (prop identifier &optional display-fn arg)
  (let* ((origin (point-marker))
         (handlers
          (plist-get (list :definition '+lookup-definition-functions
                           :implementations '+lookup-implementations-functions
                           :type-definition '+lookup-type-definition-functions
                           :references '+lookup-references-functions
                           :documentation '+lookup-documentation-functions
                           :file '+lookup-file-functions)
                     prop))
         (result
          (if arg
              (if-let
                  (handler
                   (intern-soft
                    (completing-read "Select lookup handler: "
                                     (delete-dups
                                      (remq t (append (symbol-value handlers)
                                                      (default-value handlers))))
                                     nil t)))
                  (+lookup--run-handlers handler identifier origin)
                (user-error "No lookup handler selected"))
            (run-hook-wrapped handlers #'+lookup--run-handlers identifier origin))))
    (unwind-protect
        (when (cond ((null result)
                     (message "No lookup handler could find %S" identifier)
                     nil)
                    ((markerp result)
                     (funcall (or display-fn #'switch-to-buffer)
                              (marker-buffer result))
                     (goto-char result)
                     result)
                    (result))
          (with-current-buffer (marker-buffer origin)
            (better-jumper-set-jump (marker-position origin)))
          result)
      (set-marker origin nil))))


;;
;;; Lookup backends

(autoload 'xref--show-defs "xref")
(defun +lookup--xref-show (fn identifier &optional show-fn)
  (let ((origin (point-marker))
        (xrefs (funcall fn
                        (xref-find-backend)
                        identifier)))
    (unwind-protect
        (when xrefs
          (funcall (or show-fn #'xref--show-defs)
                   (lambda () xrefs)
                   nil)
          ;; Some xref backends may report "success" without moving point (e.g.
          ;; returning the current location). In that case, allow fallback
          ;; backends to run.
          (if (cdr xrefs)
              'deferred
            (or (not (eq (marker-buffer origin) (current-buffer)))
                (/= (marker-position origin) (point)))))
      (set-marker origin nil))))

(defun +lookup-dictionary-definition-backend-fn (identifier)
  "Look up dictionary definition for IDENTIFIER."
  (when (derived-mode-p 'text-mode)
    (+lookup/dictionary-definition identifier)
    'deferred))

(defun +lookup-thesaurus-definition-backend-fn (identifier)
  "Look up synonyms for IDENTIFIER."
  (when (derived-mode-p 'text-mode)
    (+lookup/synonyms identifier)
    'deferred))

(defun +lookup-xref-definitions-backend-fn (identifier)
  "Non-interactive wrapper for `xref-find-definitions'"
  (condition-case _
      (+lookup--xref-show 'xref-backend-definitions identifier #'xref--show-defs)
    (cl-no-applicable-method nil)))

(defun +lookup-xref-references-backend-fn (identifier)
  "Non-interactive wrapper for `xref-find-references'"
  (condition-case _
      (+lookup--xref-show 'xref-backend-references identifier #'xref--show-xrefs)
    (cl-no-applicable-method nil)))

(defun +lookup-dumb-jump-backend-fn (identifier)
  "Look up the symbol at point (or selection) with `dumb-jump', which conducts a
project search with ag, rg, pt, or git-grep, combined with extra heuristics to
reduce false positives.

This backend prefers \"just working\" over accuracy."
  (and (require 'dumb-jump nil t)
       ;; See: https://github.com/jacktasia/dumb-jump/issues/353
       ;; This is a workaround for a workaround to actually both fall back to dumb-jump and use the xref integration for it.
       (let ((xref-backend-functions '(dumb-jump-xref-activate))
             (stop-infinite-dumb-jump-recursion t))
         (+lookup-xref-definitions-backend-fn identifier))))

(defun +lookup-project-search-backend-fn (identifier)
  "Conducts a simple project text search for IDENTIFIER.

Uses and requires `+ivy-file-search', `+helm-file-search', or `+vertico-file-search'.
Will return nil if neither is available. These require ripgrep to be installed."
  (when identifier
    (let ((query (doom-pcre-quote identifier)))
      (ignore-errors
        (cond ((modulep! :completion ivy)
               (+ivy-file-search :query query)
               t)
              ((modulep! :completion helm)
               (+helm-file-search :query query)
               t)
              ((modulep! :completion vertico)
               (+vertico-file-search :query query)
               t))))))

(defun +lookup-evil-goto-definition-backend-fn (_identifier)
  "Uses `evil-goto-definition' to conduct a text search for IDENTIFIER in the
current buffer."
  (when (fboundp 'evil-goto-definition)
    (ignore-errors
      (cl-destructuring-bind (beg . end)
          (bounds-of-thing-at-point 'symbol)
        (evil-goto-definition)
        (let ((pt (point)))
          (not (and (>= pt beg)
                    (<  pt end))))))))

(defun +lookup-ffap-backend-fn (identifier)
  "Tries to locate the file or URL at point (or in active selection).

See `ffap-alist' for ways to tweak how files are resolved. Falls back to
whatever find-in-project functionality is available in your active completion
framework (ivy, helm, vertico, etc), otherwise falling back to
`find-file-at-point''s file prompt."
  (let ((initial-buffer (current-buffer))
        (guess
         (cond (identifier)
               ((doom-region-active-p)
                (buffer-substring-no-properties
                 (doom-region-beginning)
                 (doom-region-end)))
               ((if (require 'ffap) (ffap-guesser))) ; Powerful! See `ffap-alist'
               ((thing-at-point 'filename t)))))
    (cond ((and (stringp guess)
                (or (file-exists-p guess)
                    (ffap-url-p guess)))
           (find-file-at-point guess))
          ;; Walk the file tree up to the project's root for relative paths.
          ((and (stringp guess)
                ;; Only do this with paths that contain segments, to reduce
                ;; false positives.
                (string-match-p "/" guess)
                (when-let* ((dir (locate-dominating-file default-directory guess)))
                  (when (file-in-directory-p dir (doom-project-root))
                    (find-file (doom-path dir guess))
                    t))))
          ;; Fallback prompters
          ((and (modulep! :completion ivy) (doom-project-p))
           (counsel-file-jump guess (doom-project-root)))
          ((and (modulep! :completion vertico) (doom-project-p))
           (+vertico/consult-fd-or-find (doom-project-root) guess))
          ((find-file-at-point (ffap-prompter guess))))
    (not (eq initial-buffer (current-buffer)))))

(defun +lookup-bug-reference-backend-fn (_identifier)
  "Searches for a bug reference in user/repo#123 or #123 format and opens it in
the browser."
  (require 'bug-reference)
  (when (fboundp 'bug-reference-try-setup-from-vc)
    (let ((old-bug-reference-mode bug-reference-mode)
          (old-bug-reference-prog-mode bug-reference-prog-mode)
          (bug-reference-url-format bug-reference-url-format)
          (bug-reference-bug-regexp bug-reference-bug-regexp))
      (bug-reference-try-setup-from-vc)
      (unwind-protect
          (let ((bug-reference-mode t)
                (bug-reference-prog-mode nil))
            (catch 'found
              (bug-reference-fontify (line-beginning-position) (line-end-position))
              (dolist (o (overlays-at (point)))
                ;; It should only be possible to have one URL overlay.
                (when-let* ((url (overlay-get o 'bug-reference-url)))
                  (browse-url url)

                  (throw 'found t)))))
        ;; Restore any messed up fontification as a result of this.
        (bug-reference-unfontify (line-beginning-position) (line-end-position))
        (if (or old-bug-reference-mode
                old-bug-reference-prog-mode)
            (bug-reference-fontify (line-beginning-position) (line-end-position)))))))


;;
;;; Main commands

;;;###autoload
(defun +lookup/definition (identifier &optional arg)
  "Jump to the definition of IDENTIFIER (defaults to the symbol at point).

Each function in `+lookup-definition-functions' is tried until one changes the
point or current buffer. Falls back to dumb-jump, naive
ripgrep/the_silver_searcher text search, then `evil-goto-definition' if
evil-mode is active."
  (interactive (list (doom-thing-at-point-or-region)
                     current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
        ((+lookup--jump-to :definition identifier nil arg))
        ((user-error "Couldn't find the definition of %S" (substring-no-properties identifier)))))

;;;###autoload
(defun +lookup/implementations (identifier &optional arg)
  "Jump to the implementations of IDENTIFIER (defaults to the symbol at point).

Each function in `+lookup-implementations-functions' is tried until one changes
the point or current buffer."
  (interactive (list (doom-thing-at-point-or-region)
                     current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
        ((+lookup--jump-to :implementations identifier nil arg))
        ((user-error "Couldn't find the implementations of %S" (substring-no-properties identifier)))))

;;;###autoload
(defun +lookup/type-definition (identifier &optional arg)
  "Jump to the type definition of IDENTIFIER (defaults to the symbol at point).

Each function in `+lookup-type-definition-functions' is tried until one changes
the point or current buffer."
  (interactive (list (doom-thing-at-point-or-region)
                     current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
        ((+lookup--jump-to :type-definition identifier nil arg))
        ((user-error "Couldn't find the definition of %S" (substring-no-properties identifier)))))

;;;###autoload
(defun +lookup/references (identifier &optional arg)
  "Show a list of usages of IDENTIFIER (defaults to the symbol at point)

Tries each function in `+lookup-references-functions' until one changes the
point and/or current buffer. Falls back to a naive ripgrep/the_silver_searcher
search otherwise."
  (interactive (list (doom-thing-at-point-or-region)
                     current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
        ((+lookup--jump-to :references identifier nil arg))
        ((user-error "Couldn't find references of %S" (substring-no-properties identifier)))))

;;;###autoload
(defun +lookup/documentation (identifier &optional arg)
  "Show documentation for IDENTIFIER (defaults to symbol at point or selection.

First attempts the :documentation handler specified with `set-lookup-handlers!'
for the current mode/buffer (if any), then falls back to the backends in
`+lookup-documentation-functions'."
  (interactive (list (doom-thing-at-point-or-region)
                     current-prefix-arg))
  (cond ((+lookup--jump-to :documentation identifier #'pop-to-buffer arg))
        ((user-error "Couldn't find documentation for %S" (substring-no-properties identifier)))))

;;;###autoload
(defun +lookup/file (&optional path)
  "Figure out PATH from whatever is at point and open it.

Each function in `+lookup-file-functions' is tried until one changes the point
or the current buffer.

Otherwise, falls back on `find-file-at-point'."
  (interactive)
  (cond ((and path
              buffer-file-name
              (file-equal-p path buffer-file-name)
              (user-error "Already here")))

        ((+lookup--jump-to :file path))

        ((user-error "Couldn't find any files here"))))


;;
;;; Dictionary

;;;###autoload
(defun +lookup/dictionary-definition (identifier &optional arg)
  "Look up the definition of the word at point (or selection)."
  (interactive
   (list (or (doom-thing-at-point-or-region 'word)
             (if (equal major-mode 'pdf-view-mode)
                 (car (pdf-view-active-region-text)))
             (read-string "Look up in dictionary: "))
         current-prefix-arg))
  (message "Looking up dictionary definition for %S" identifier)
  (cond ((and (featurep :system 'macos) (require 'osx-dictionary nil t))
         (osx-dictionary--view-result identifier))
        ((and +lookup-dictionary-prefer-offline
              (require 'wordnut nil t))
         (unless (executable-find wordnut-cmd)
           (user-error "Couldn't find %S installed on your system"
                       wordnut-cmd))
         (wordnut-search identifier))
        ((require 'define-word nil t)
         (define-word identifier nil arg))
        ((user-error "No dictionary backend is available"))))

;;;###autoload
(defun +lookup/synonyms (identifier &optional _arg)
  "Look up and insert a synonym for the word at point (or selection)."
  (interactive
   (list (doom-thing-at-point-or-region 'word) ; TODO: actually use this
         current-prefix-arg))
  (message "Looking up synonyms for %S" identifier)
  (cond ((and +lookup-dictionary-prefer-offline
              (require 'synosaurus-wordnet nil t))
         (unless (executable-find synosaurus-wordnet--command)
           (user-error "Couldn't find %S installed on your system"
                       synosaurus-wordnet--command))
         (synosaurus-choose-and-replace))
        ((require 'powerthesaurus nil t)
         (powerthesaurus-lookup-word-dwim))
        ((user-error "No thesaurus backend is available"))))
