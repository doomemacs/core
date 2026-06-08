;;; config/literate/autoload.el -*- lexical-binding: t; -*-

;;;###autoload (add-hook 'org-mode-hook #'+literate-enable-recompile-h)

(defvar +literate-config-file (file-name-concat doom-user-dir "config.org")
  "The file path of your literate config file.")

(defvar +literate-tangle--async-proc nil)
(defvar +literate-tangle--async-proc-start-time nil)

(defvar org-mode-hook)
(defvar org-inhibit-startup)

(defun +literate-tangle (target dest &optional dir)
  "Tangle TARGET org file to DEST."
  (and (require 'ox nil t)
       (require 'ob-tangle nil t)
       (let* ((default-directory (or dir default-directory))
              (target (expand-file-name target))
              (dest   (expand-file-name dest)))
         (print! (start "Tangling your literate config..."))
         (print-group!
           (let (;; Do as little unnecessary work as possible in these org files.
                 (org-startup-indented nil)
                 (org-startup-folded nil)
                 (vc-handled-backends nil)
                 ;; Prevent unwanted entries in recentf, or formatters, or
                 ;; anything that could be on these hooks, really. Nothing else
                 ;; should be touching these files (particularly in interactive
                 ;; sessions).
                 (write-file-functions nil)
                 (before-save-hook nil)
                 (after-save-hook nil)
                 ;; Prevent infinite recursion due to recompile-on-save hooks
                 ;; later, and speed up `org-mode' init.
                 (org-mode-hook nil)
                 (org-inhibit-startup t)
                 ;; Allow evaluation of src blocks at tangle-time (would abort
                 ;; them otherwise). This is a security hazard, but Doom will
                 ;; trust that you know what you're doing!
                 (org-confirm-babel-evaluate nil)
                 ;; Say a little more
                 (doom-print-message-level 'info))
             (cond ((not (file-exists-p target))
                    (print! (warn "No org file at %s. Skipping...") (path target))
                    nil)
                   ((with-temp-buffer
                      (insert-file-contents target)
                      (let ((case-fold-search t))
                        (not (re-search-forward "^ *#\\+begin_src e\\(?:macs-\\)?lisp" nil t))))
                    (print! (warn "No src blocks to tangle in %s. Skipping...") (path target))
                    nil)
                   ((if-let* ((files (org-babel-tangle-file target dest)))
                        (always (print! (success "Done tangling %d file(s)!" (length files))))
                      (print! (error "Failed to tangle any blocks from your config."))
                      nil))))))))

(defun +literate-tangle--sync ()
  "Tangles `+literate-config-file' if it has changed."
  (or (getenv "__NOTANGLE")
      (and (+literate-tangle +literate-config-file
                             doom-module-config-file
                             doom-user-dir)
           (when (modulep! +pretty)
             (+literate-auto-indent))
           (or (not noninteractive)
               (exit! "__NOTANGLE=1 $@")))))

(defun +literate-tangle--async ()
  "Tangles `+literate-config-file' using an async Emacs process."
  (unless (getenv "__NOTANGLE")
    (when +literate-tangle--async-proc
      (message "Killing outdated tangle process...")
      (set-process-sentinel +literate-tangle--async-proc #'ignore)
      (kill-process +literate-tangle--async-proc)
      (sit-for 0.3)) ; ensure the message is seen for a bit
    (setq +literate-tangle--async-proc-start-time (float-time)
          +literate-tangle--async-proc
          ;; See `+literate-tangle--sync' for an explanation of the (progn ...) below.
          (start-process "tangle-config"
                         (with-current-buffer
                             (get-buffer-create " *tangle config*")
                           (erase-buffer)
                           (current-buffer))
                         "emacs" "--batch"
                         "-L" (file-name-directory (locate-library "org"))
                         "--load" (doom-path doom-core-dir "doom")
                         "--load" (doom-path doom-core-dir "lib/print")
                         "--eval"
                         (prin1-to-string
                          `(funcall #',(symbol-function #'+literate-tangle)
                                    ,+literate-config-file
                                    ,doom-module-config-file
                                    ,doom-user-dir))))
    (add-hook 'kill-emacs-hook #'+literate-tangle-check-finished-h)
    (set-process-sentinel +literate-tangle--async-proc #'+literate-tangle--async-sentinel)
    (run-at-time nil nil (lambda () (message "Tangling config.org"))) ; ensure shown after a save message
    "Tangling config.org..."))

(defun +literate-tangle--async-sentinel (process signal)
  (cond
   ((and (eq 'exit (process-status process))
         (= 0 (process-exit-status process)))
    (message "Tangled config.org sucessfully (took %.1fs)"
             (- (float-time) +literate-tangle--async-proc-start-time))
    (setq +literate-tangle--async-proc nil)
    (when (modulep! +pretty)
      (+literate-auto-indent)))
   ((memq (process-status process) '(exit signal))
    (pop-to-buffer (get-buffer " *tangle config*"))
    (message "Failed to tangle config.org (after %.1fs)"
             (- (float-time) +literate-tangle--async-proc-start-time))
    (setq +literate-tangle--async-proc nil))))


;;
;;; Commands

;;;###autoload
(defalias '+literate/reload #'doom/reload)

(defun +literate--flatten-imenu-index (index &optional prefix)
  "Flatten an org-mode imenu index."
  (let ((flattened '()))
    (dolist (item index flattened)
      (let* ((name (propertize (car item) 'face (intern (format "org-level-%d" (if prefix (+ 2 (cl-count ?/ prefix)) 1)))))
             (prefix (if prefix (concat prefix "/" name) name)))
        (if (imenu--subalist-p item)
            (setq flattened (append flattened (+literate--flatten-imenu-index (cdr item) prefix)))
          (push (cons prefix (cdr item)) flattened))))
    (nreverse flattened)))

(defvar imenu-auto-rescan)
;;;###autoload
(defun +literate/find-heading (&optional level)
  "Jump to a heading in your literate org config file."
  (interactive "P")
  (let* ((buffer (or (find-buffer-visiting +literate-config-file)
                     (find-file-noselect +literate-config-file t))))
    (with-current-buffer buffer
      (let* ((imenu-auto-rescan t)
             (org-imenu-depth (or level 8))
             (index (+literate--flatten-imenu-index (imenu--make-index-alist))))
        (let ((c (current-window-configuration))
              (result nil))
          (unwind-protect
              (progn
                (switch-to-buffer buffer)
                (if (modulep! :completion vertico)
                    (setq result (consult-outline level))
                  (let ((entry (assoc (completing-read "Go to heading: " index nil t) index)))
                    (setq result entry)
                    (imenu entry))))
            (unless result
              (set-window-configuration c))))))))

;;;###autoload
(defun +literate-auto-indent ()
  "Indent the tangled config.el file according to lisp indenting rules."
  (let ((dest-file (concat (file-name-sans-extension +literate-config-file) ".el")))
    (when (file-exists-p dest-file)
      (with-current-buffer (find-file-noselect dest-file)
        (widen)
        ;; Set explicitly so indenting rules are correctly applied.
        (emacs-lisp-mode)
        (indent-region (point-min) (point-max))
        (save-buffer)))))

;;;###autoload
(defun +literate-indent-elisp-src-blocks ()
  "Indent all emacs-lisp src blocks in the current Org buffer, then save."
  (interactive)
  (save-excursion
    (org-babel-map-src-blocks nil
      (when (string= lang "emacs-lisp")
        (org-babel-do-in-edit-buffer
          (emacs-lisp-mode)
          (indent-region (point-min) (point-max)))))
    (save-buffer)))

;;
;;; Hooks

;;;###autoload
(defun +literate-tangle-h ()
  "Tangles `+literate-config-file' if it has changed.
This is performed with an asyncronous Emacs process, except when
`noninteractive' is nil."
  (if noninteractive
      (unless (+literate-tangle--sync)
        (kill-emacs 3))
    (+literate-tangle--async)))

;;;###autoload
(defun +literate-tangle-check-finished-h ()
  "When a tangle is still in progress, ask the user if they want to wait for it."
  (when (and (process-live-p +literate-tangle--async-proc)
             (yes-or-no-p "Config is currently retangling, would you please wait a few seconds?"))
    (switch-to-buffer " *tangle config*")
    (signal 'quit nil)))

;;;###autoload
(defun +literate-enable-recompile-h ()
  "Enable literate-compiling-on-save in the current buffer."
  (add-hook 'after-save-hook #'+literate-recompile-maybe-h nil 'local))

;;;###autoload
(defun +literate-recompile-maybe-h ()
  "Recompile literate config to `doom-user-dir'.

We assume any org file in `doom-user-dir' is connected to your literate config,
and should trigger a recompile if changed."
  (and (file-in-directory-p
        (buffer-file-name (buffer-base-buffer))
        (file-name-directory (file-truename +literate-config-file)))
       (+literate-tangle-h)))

;;; autoload.el ends here
