;;; lisp/doom-docs.el -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; This file defines `doom-docs-mode', a major mode derived from `org-mode'
;; intended to make Doom's documentation more readable, visually appealing, and
;; allow for dynamic content that adjusts according to the user's Doom
;; environment. It defines custom links, permits conditional (even dynamically
;; generated) elements, hides internal syntax/tags, and adds a navigation bar to
;; the top of these buffers.
;;
;; You might think: why not use Info at this point? Because Org is much more
;; capable and serves as a far more beginner-proof foundation: I don't want to
;; impose a messy build/CI/CD step (that'd require external dependencies that
;; Windows users can't easily get) on users, and I want context-sensitive and
;; dynamic content that can adjust to the user's environment and Doom config.
;; Org also presents a lower the barrier of entry for contributions to docs.
;;
;;; Code:

(defgroup doom-docs nil
  "Org-derived views for Doom's core and module documentation."
  :link '(url-link :tag "Online Documentation" "https://docs.doomemacs.org")
  :link '(url-link :tag "Community Wiki" "https://wiki.doomemacs.org")
  :group 'doom)


;;
;;; * Variables

;;;###autoload
(defvar doom-docs-dir (doom-emacs-dir "docs/")
  "Where Doom's documentation files are stored. Must end with a slash.")

(defvar doom-docs-link-alist
  `(("pkg" . "package:")

    ("github" . "https://github.com/")
    ("gitlab" . "https://gitlab.com/")
    ("sourcehut" . "https://git.sr.ht/~")
    ("codeberg" . "https://codeberg.org/")

    ("emacsdir" . doom-emacs-dir)
    ("doomdir" . doom-user-dir)

    ("doom-index" . "id:3051d3b6-83e2-4afa-b8fe-1956c62ec096")
    ("doom-faq" . "id:5fa8967a-532f-4e0c-8ae8-25cd802bf9a9")

    ("doom-help"    . doom-docs--link-help)
    ("doom-history" . doom-docs--link-history)
    ("doom-issues"  . doom-docs--link-issues)
    ("doom-report"  . doom-docs--link-report)
    ("doom-root"    . doom-docs--link-root)
    ("doom-up"      . doom-docs--link-up)

    ("doom-home" . "https://doomemacs.org/")
    ("doom-wiki" . "https://wiki.doomemacs.org/")
    ("doom-docs" . "https://docs.doomemacs.org/")
    ("doom-git" . "https://git.doomemacs.org/")
    ("doom-discuss" . "https://discuss.doomemacs.org/")
    ("doom-discord" . "https://discord.doomemacs.org/")

    ("doom-contrib-edit"       . "id:31f5a61d-d505-4ee8-9adb-97678250f4e2")
    ("doom-contrib-faq"        . "id:aa28b732-0512-49ed-a47b-f20586c0f051")
    ("doom-contrib-core"       . "id:9ac0c15c-29e7-43f8-8926-5f0edb1098f0")
    ("doom-contrib-docs"       . "id:31f5a61d-d505-4ee8-9adb-97678250f4e2")
    ("doom-contrib-maintainer" . "id:e71e9595-a297-4c49-bd11-f238329372db")
    ("doom-contrib-module"     . "id:b461a050-8702-4e63-9995-c2ef3a78f35d")))

(defvar doom-docs-notice-types
  '(("wip"     . "󱌣")   ; to indicate incomplete documentation
    ("tip"     . "󰐃")   ; a tip to avoid issues
    ("excerpt" . "󰝗")   ; for verbatim quotations
    ("kudos"   . "󰔓")   ; to give thanks or credit
    ("aside"   . "󰟶")   ; a tangent or personal opinion/workflow
    ("notice"  . "󰥔")   ; a temporary notice
    ("warning" . ""))  ; a tip to avoid fatal issues
  "An alist mapping Doom notice types to icons.")

(defvar doom-docs-use-nerd-icons t
  "If non-nil, use nerd-icons if it's available.

Falls back to unicode icons, where specified, omitting icons otherwise.")

(defvar doom-docs-enable-view-mode t
  "If non-nil, activate `doom-docs-view-mode' when entering `doom-docs-mode'.")

(defvar doom-docs--id-locations nil)
(defvar doom-docs--id-files nil)
(defvar doom-docs--id-location-file (doom-profile-cache-dir t "doom-docs-org-ids"))
(defvar doom-docs--link-parameters nil)
(defconst doom-docs--hidden-spec 'doom-docs-hidden)


;;
;;; * Faces

(defface doom-docs-header-link
  '((((background light)) :foreground "black" :weight bold)
    (((background dark))  :foreground "white" :weight bold))
  "Face used for buttons in the header line.")

(defface doom-docs-link '((t :inherit org-link :underline nil))
  "Face used for doom:* links.")

(defface doom-docs-title '((t :inherit org-document-title :weight bold :height 1.4))
  "Face used for #+TITLEs in `doom-docs-view-mode'.")

(defface doom-docs-info '((t :inherit org-document-info :weight normal :height 1.15))
  "Face used for #+SUBTITLE, #+DATE, #+AUTHOR, #+EMAIL in `doom-docs-view-mode'.")

(defface doom-docs-symbol
  '((t :inherit font-lock-keyword-face
       :box (:line-width (-1 . -1) :color "grey35")))
  "Face used for all symbol links (var, func, cmd, face) in `doom-docs-mode'.")

(defface doom-docs-variable '((t :inherit doom-docs-symbol))
  "Face used for links to elisp variables in `doom-docs-mode'.")

(defface doom-docs-function '((t :inherit doom-docs-symbol))
  "Face used for links to elisp functions in `doom-docs-mode'.")

(defface doom-docs-face '((t :inherit doom-docs-symbol))
  "Face used for links to elisp face symbols in `doom-docs-mode'.")

(defface doom-docs-command '((t :inherit doom-docs-symbol))
  "Face used for links to interactive elisp commands in `doom-docs-mode'.")

(defface doom-docs-kbd '((t :inherit help-key-binding))
  "Face used for links to Emacs key sequences in `doom-docs-mode'.")

(defface doom-docs-repo '((t :inherit doom-docs-link :weight bold))
  "Face used for repo: links in `doom-docs-mode'.")

(defface doom-docs-package '((t :inherit package-name :weight bold :underline nil))
  "Face used for links to Emacs packages in `doom-docs-mode'.")

(defface doom-docs-module '((t :inherit doom-docs-header-link :weight bold :underline nil))
  "Face used for links to enabled Doom modules in `doom-docs-mode'.")

(defface doom-docs-shell-command
  '((t :inherit (org-code org-block fixed-pitch) :weight bold))
  "Face used to highlight shell commands in `doom-docs-mode'.")

(defface doom-docs-abbr
  '((((background light)) :underline (:line-width 1 :color "grey65"))
    (((background dark))  :underline (:line-width 1 :color "grey35")))
  "Face used for abbreviations and definition lookup links.")


;;
;;; * Helpers

(defun doom-docs-load-path ()
  "Return all active documentation sources."
  `(,doom-docs-dir
    ,@(cl-remove (doom-user-dir "modules/") doom-module-load-path
                 :test #'file-equal-p)))

(defun doom-docs-find-file (file &optional message)
  "Visit FILE while displaying MESSAGE.

If MESSAGE is omitted/nil, no message is displayed. Also defers GC to ensure
FILE loads as fast as possible (most beneficial for first-time load)."
  (with-temp-message message
    (with-delayed-gc! (quiet! (find-file file)))))

(defun doom-docs--icon (icon label &rest plist)
  "Prefix LABEL with ICON (from nerd-icons).

Passes PLIST to appropriate nerd-icons-* function."
  (cl-loop with nerd? = (and (fboundp 'nerd-icons-install-fonts)  ; autoloaded
                             doom-docs-use-nerd-icons)
           for i in (ensure-list icon)
           if (not (string-prefix-p "nf-" i))
           return (setq icon i)
           else if nerd?
           return (setq icon i))
  (concat
   (when (stringp icon)
     (let ((ws (if (or (null label) (string-empty-p label))
                   ""
                 (if-let* ((face (plist-get plist :face)))
                     (propertize " " 'face face)
                   " "))))
       (if (string-prefix-p "nf-" icon)
           (concat (apply (intern (format "nerd-icons-%sicon"
                                          (nth 1 (split-string icon "-"))))
                          icon plist)
                   ws)
         (concat icon ws))))
   label))

(defun doom-docs--show-region (beg end hide?)
  (funcall (if (fboundp 'org-fold-core-region)  ; Org 9.6+
               #'org-fold-core-region
             #'org-flag-region)
           beg end hide?
           doom-docs--hidden-spec))

(defun doom-docs--invisible-p (pt)
  (if (fboundp 'org-fold-folded-p)  ; Org 9.6+
      (org-fold-folded-p pt doom-docs--hidden-spec)
    (memq (org-invisible-p pt)
          '(org-hide-block outline doom-docs-hidden))))

(defun doom-docs--get-link-description (&optional context nopath?)
  (when (derived-mode-p 'org-mode)
    (when-let* ((link (or context (org-element-context))))
      (or (and (string-empty-p (org-element-property :path link))
               (if-let* ((beg (org-element-property :contents-begin link))
                         (end (org-element-property :contents-end link)))
                   (buffer-substring-no-properties
                    (org-element-property :contents-begin link)
                    (org-element-property :contents-end link))))
          (unless nopath?
            (org-element-property :path link))))))

(defun doom-docs--repo-url (user repo &optional suffix)
  (letf! (defun project-repo ()
           (symbol-name (doom-config `(project name))))
    (when (cdr-safe user)
      (setq repo (cadr user)
            user (car user)))
    (format "https://github.com/%s/%s/%s"
            (or user (car  (split-string (project-repo) "/")))
            (or repo (cadr (split-string (project-repo) "/")))
            suffix)))

(defun doom-docs-context-at-pos (pos &optional buffer prop)
  "Return the `org-element-context' at POS in BUFFER.

Returns PROP if specified, the context otherwise."
  (when-let*
      ((ctxt (with-current-buffer (if (bufferp buffer) buffer (current-buffer))
               (when (eq major-mode 'doom-docs-mode)
                 (save-excursion
                   (goto-char pos)
                   (org-element-context))))))
    (if prop
        (org-element-property prop ctxt)
      ctxt)))

;;;###autoload
(defun doom-docs-generate-id (&optional force?)
  "Generate an ID for a `doom-docs-org-mode' buffer."
  (dlet ((org-id-link-to-org-use-id t)
         (org-id-method 'uuid)
         (org-id-track-globally t)
         (org-id-locations-file doom-docs--id-location-file)
         (org-id-locations doom-docs--id-locations)
         (org-id-files doom-docs--id-files))
    (doom/reload-docs force?)
    (when-let* ((fname (buffer-file-name (buffer-base-buffer))))
      (let ((id (org-id-new)))
        (org-id-add-location id fname)
        id))))


;;; ** Navbar

(defun doom-docs--file-type (&optional dir)
  (let ((dir (or dir default-directory))
        key)
    (cond ((setq key (doom-module-from-path dir))
           (cons (if (cdr key) 'module 'group) key))
          ;; ((setq key (doom-source-from-path dir))
          ;;  (cons 'source key))
          ((setq key (doom-config-locate 'project (file-name-directory dir)))
           (cons 'project key)))))

(defun doom-docs--make-header-link (link)
  (cl-destructuring-bind (label target . icons) link
    (let ((map (make-sparse-keymap)))
      (define-key map [header-line mouse-2] #'doom-docs--open-header-link)
      (define-key map [mouse-2] #'doom-docs--open-header-link)
      (define-key map [follow-link] 'mouse-face)
      (propertize
       (doom-docs--icon icons label :height 0.6)
       'face 'doom-docs-header-link
       'doom-docs-link target
       'keymap map
       'help-echo target
       'mouse-face 'highlight))))

(defun doom-docs--make-header (type)
  "Create a header string for the current buffer."
  (let (lhs rhs)
    (let* ((file (buffer-file-name (buffer-base-buffer)))
           (fname (file-name-nondirectory file)))
      (push (list "" "elisp:(call-interactively #'imenu)" "nf-md-table_of_contents" "☰") lhs)
      (if (equal fname "index.org")
          (unless (equal fname "faq.org")
            (push (list "FAQ" "doom-faq:") lhs))
        (if (eq (car type) 'project)
            (push (list "Root" "doom-root:" "nf-md-arrow_left" "←") lhs)
          (push (list "Up" "doom-up:" "nf-md-arrow_up" "↑") lhs)))
      (when (memq (car type) '(module group))
        (push (list "Issues" "doom-issues:" "nf-md-flag") rhs)
        (push (list "History" "doom-history:" "nf-md-history") rhs))
      (push (list "Suggest edits" "doom-contrib-edit:" "nf-md-account_edit" "✎") rhs)
      (push (list "Help" "doom-help:" "nf-md-timeline_help_outline" "🗎") rhs))
    (let ((left  (mapconcat #'doom-docs--make-header-link (reverse lhs) "  "))
          (right (mapconcat #'doom-docs--make-header-link (reverse rhs) "  ")))
      (if rhs
          (concat " " left
                  (make-string (max (- fill-column
                                       (length left)
                                       (length right))
                                    1)
                               ?\s)
                  right)
        (concat " " left)))))

(defun doom-docs--open-header-link (ev)
  "Open the header link which is the target of the event EV."
  (interactive "e")
  (with-delayed-gc!
    (let* ((string-and-pos (posn-string (event-start ev)))
           (window (posn-window (event-start ev)))
           (buffer (window-buffer (posn-window (event-start ev))))
           (linkstr (concat "[[" (get-pos-property (cdr string-and-pos)
                                                   'doom-docs-link
                                                   (car string-and-pos))
                            "]]")))
      (pcase (with-temp-buffer
               (setq buffer-file-name (buffer-file-name buffer))
               (with-silent-modifications
                 (let ((org-inhibit-startup t)
                       org-mode-hook
                       doom-docs-mode-hook)
                   (doom-docs-mode))
                 (save-excursion (insert linkstr))
                 (org-element-link-parser)))
        (`nil (user-error "No valid link in %S" link))
        ((and link (guard (not (equal (org-element-end link) (1+ (length linkstr))))))
         (user-error "Garbage after link in %S (%S)"
                     linkstr (substring linkstr (1- (org-element-end link)))))
        (link (with-selected-window window
                (org-link-open link)
                (org-show-entry)
                (org-show-children)))))))

(defvar doom-docs--type nil)
(defun doom-docs--display-menu-h ()
  "Toggle virtual menu line at top of buffer."
  (setq header-line-format
        (and doom-docs-view-mode
             (doom-docs--make-header
              (or doom-docs--type
                  (setq-local doom-docs--type
                              (doom-docs--file-type default-directory))))))
  (if doom-docs-view-mode
      (add-hook 'window-state-change-hook #'doom-docs--display-menu-h nil 'local)
    (remove-hook 'window-state-change-hook #'doom-docs--display-menu-h 'local)))


;;; ** Transformer functions

(defmacro doom-docs--with-buffer (&rest body)
  `(with-delayed-gc! (org-with-wide-buffer ,@body)))

(defun doom-docs--hide-meta-h ()
  "Hide all meta or comment lines."
  (doom-docs--with-buffer
   (goto-char (point-min))
   (save-match-data
     (let ((case-fold-search t))
       (while (re-search-forward "^[ \t]*\\#" nil t)
         (unless (org-in-src-block-p t)
           (catch 'abort
             (doom-docs--show-region
              (line-beginning-position)
              (cond ((looking-at "+\\(?:title\\|subtitle\\): +")
                     (match-end 0))
                    ((looking-at "+\\(?:created\\|since\\|author\\|email\\|date\\): +")
                     (throw 'abort nil))
                    ((or (eq (char-after) ?\s)
                         (looking-at "+\\(begin\\|end\\)_comment"))
                     (line-beginning-position 2))
                    ((looking-at "+\\(?:begin\\|end\\)_\\([^ \n]+\\)")
                     (line-end-position))
                    ((line-beginning-position 2)))
              doom-docs-view-mode))))))))

(defun doom-docs--hide-drawers-h ()
  "Hide all property drawers."
  (let (pt)
    (doom-docs--with-buffer
     (goto-char (point-min))
     (when (looking-at-p org-drawer-regexp)
       (setq pt (org-element-property :end (org-element-at-point))))
     (while (re-search-forward org-drawer-regexp nil t)
       (when-let* ((el (org-element-at-point))
                   (beg (max (point-min) (1- (org-element-property :begin el))))
                   (end (org-element-property :end el))
                   ((memq (org-element-type el) '(drawer property-drawer))))
         (when (fboundp 'org-element-property-inherited)  ; Org 9.7+
           (when (org-element-property-inherited :level el)
             (cl-decf end)))
         (doom-docs--show-region beg end doom-docs-view-mode))))
    ;; FIX: If the cursor remains within a newly folded region, that folk will
    ;;   come undone, so we move it.
    (if pt (goto-char pt))))

(defun doom-docs--hide-tags-h ()
  "Hide tags in org headings."
  (doom-docs--with-buffer
   (goto-char (point-min))
   (while (re-search-forward org-heading-regexp nil t)
     (when-let* ((tags (org-get-tags nil t)))
       (when (or (member "noorg" tags)
                 (member "unfold" tags))
         ;; prevent `org-ellipsis' around hidden regions
         (org-show-entry))
       (if (member "noorg" tags)
           (doom-docs--show-region (line-end-position 0)
                                   (save-excursion
                                     (org-end-of-subtree t)
                                     (forward-line 1)
                                     (if (and (bolp) (eolp))
                                         (line-beginning-position)
                                       (line-end-position 0)))
                                   doom-docs-view-mode)
         (doom-docs--show-region (save-excursion
                                   (goto-char (line-beginning-position))
                                   (re-search-forward " +:[^ ]" (line-end-position))
                                   (match-beginning 0))
                                 (line-end-position)
                                 doom-docs-view-mode))))))

(defvar doom-docs--block-cache nil)
(defun doom-docs--hide-blocks-h ()
  "Hide blocks (and/or their results) depending on their :exports arg."
  (doom-docs--with-buffer
   (let ((inhibit-read-only t))
     (goto-char (point-min))
     (make-local-variable 'doom-docs--block-cache)
     (while (re-search-forward org-block-regexp nil t)
       (let* ((beg (match-beginning 0))
              (end (save-excursion (goto-char (match-end 0))
                                   (skip-chars-forward "\n")
                                   (point)))
              (exports
               (save-excursion
                 (goto-char beg)
                 (if (and (re-search-forward " :hide \\([^ \n]+\\)" (point-at-eol) t)
                          (equal (match-string-no-properties 1) "yes"))
                     "none"
                   (and (re-search-forward " :exports \\([^ \n]+\\)" (point-at-eol) t)
                        (match-string-no-properties 1)))))
              (src? (org-in-src-block-p))
              (results (if src? (org-babel-where-is-src-block-result))))
         (save-excursion
           (when (and src?
                      (member exports '("results" "both"))
                      (not results)
                      doom-docs-view-mode)
             (cl-pushnew beg doom-docs--block-cache :test #'=)
             (let (org-confirm-babel-evaluate)
               (when (and (org-babel-check-confirm-evaluate
                           (org-babel-get-src-block-info))
                          (org-babel-execute-src-block))
                 (setq results (org-babel-where-is-src-block-result))
                 (when (fboundp 'org-element-cache-refresh)
                   (org-element-cache-refresh beg))
                 (restore-buffer-modified-p nil)))))
         (save-excursion
           (when results
             (when (member exports '("code" "both" "t"))
               (setq beg results))
             (when (member exports '("none" "code"))
               (setq end (progn (goto-char results)
                                (goto-char (if src? (org-babel-result-end) end))
                                (skip-chars-forward "\n")
                                (point))))))
         ;; none = no export, no org
         ;; only = export, no org
         ;; both = export, org
         ;; docs = no export, org
         (when (if src?
                   (not (member exports '(nil "both" "code" "t")))
                 (member exports '("none" "only")))
           (doom-docs--show-region beg end doom-docs-view-mode))))
     (unless doom-docs-view-mode
       (save-excursion
         (dolist (pos doom-docs--block-cache)
           (goto-char pos)
           (org-babel-remove-result)
           (when (fboundp 'org-element-cache-refresh)
             (org-element-cache-refresh pos)))
         (kill-local-variable 'doom-docs--block-cache)
         (restore-buffer-modified-p nil))))))

(defun doom-docs--prettify-notices-h ()
  "Render notices with an icon and indentation."
  (doom-docs--with-buffer
   (goto-char (point-min))
   (remove-overlays (point-min) (point-max) 'doom-docs-notice t)
   (when doom-docs-view-mode
     (let ((re (format "^\\( *\\)#\\+begin_quote +%s"
                       (regexp-opt (mapcar #'car doom-docs-notice-types)
                                   t))))
       (while (re-search-forward re nil t)
         (unless (doom-docs--invisible-p (point))
           (let* ((icon (propertize (format " %s "
                                            (cdr (assoc (match-string 2)
                                                        doom-docs-notice-types)))
                                    'face '(:inherit (org-quote default) :underline nil)))
                  (prefix (propertize " " 'display
                                      `(space :width ,(if (fboundp 'string-pixel-width)  ; Emacs 29+
                                                          (list (string-pixel-width icon))
                                                        (1+ (string-width icon))))
                                      'face '(:inherit org-quote :underline nil)))
                  (indent (match-string-no-properties 1))
                  (begoff (length indent))
                  (beg (save-excursion (goto-char (match-end 1))
                                       (point-at-bol 2)))
                  (end (save-excursion
                         (save-match-data
                           (search-forward (concat indent "#+end_quote") nil)
                           (point-at-bol)))))
             ;; Using `before-string' instead of `line-prefix' because
             ;; `org-indent-mode' will highjack the latter.
             (goto-char beg)
             (while (and (< (point) end)
                         (not (eobp)))
               (let ((ov (make-overlay (point-at-bol) (+ (point-at-bol) begoff))))
                 (overlay-put ov 'after-string (if (= (point) beg) icon prefix))
                 (overlay-put ov 'doom-docs-notice t))
               (forward-line 1)))))))))


;;
;;; * `doom-docs-view-mode'

(defvar doom-docs-view-mode-alist
  '((flyspell-mode . -1)
    (flymake-mode . -1)
    (flycheck-mode . -1)
    (spell-fu-mode . -1)
    (mixed-pitch-mode . -1)
    (variable-pitch-mode . -1)
    (indent-bars-mode . -1)
    (org-appear-mode . -1)
    (diff-hl-mode . -1))
  "An alist of minor modes to toggle with `doom-docs-view-mode'.

The CAR is the minor mode symbol, and CDR should be +1 to enable the mode during
`doom-docs-view-mode' or -1 to disable it instead.")

(defvar doom-docs-view-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap read-only-mode] #'doom-docs-view-mode)
    map))

(defvar-local doom-docs--initial-values nil)
(defvar-local doom-docs--cookies nil)
(defvar-local doom-docs--last-state nil)
(put 'doom-docs--last-state 'permanent-local t)
;;;###autoload
(define-minor-mode doom-docs-view-mode
  "Hides metadata, tags, & drawers and activates all org-mode prettifications.
This primes `org-mode' for reading."
  :keymap doom-docs-view-mode-map
  :after-hook (progn
                (org-restart-font-lock)
                (if (doom-docs--invisible-p (point))
                    (goto-char (org-find-visible))))
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an org mode buffer"))
  (setq buffer-read-only doom-docs-view-mode)
  (when (fboundp 'org-fold-add-folding-spec)  ; Org 9.6+
    (org-fold-add-folding-spec
     doom-docs--hidden-spec '(:visible nil
                              :ellipsis nil
                              :isearch-ignore t)))
  (mapc (lambda! ((face . newface))
          (if doom-docs-view-mode
              (push (face-remap-add-relative face newface) doom-docs--cookies)
            (mapc #'face-remap-remove-relative doom-docs--cookies)))
        '((org-document-title . doom-docs-title)
          (org-document-info  . doom-docs-info)))
  (mapc (lambda! ((mode . state))
          (if doom-docs-view-mode
              (if (boundp mode)
                  (when (and (< state 0) (symbol-value mode))
                    (setf (alist-get mode doom-docs--initial-values) t)
                    (funcall mode -1))
                (when (and (> state 0) (not (symbol-value mode)))
                  (setf (alist-get mode doom-docs--initial-values) nil)
                  (funcall mode +1)))
            (when-let* ((old-val (assq mode doom-docs--initial-values)))
              (funcall mode (if old-val +1 -1)))))
        doom-docs-view-mode-alist)
  (mapc (lambda (sym)
          (if doom-docs-view-mode
              (set (make-local-variable sym) t)
            (kill-local-variable sym)))
        '(org-pretty-entities
          org-descriptive-links
          org-hide-emphasis-markers
          org-hide-macro-markers
          ;; Don't prompt to "create headings" on broken links
          org-link-search-must-match-exact-headline))
  (if doom-docs-view-mode
      (add-hook 'read-only-mode-hook #'doom-docs--turn-off-view-mode-h nil 'local)
    (remove-hook 'read-only-mode-hook #'doom-docs--turn-off-view-mode-h 'local)))

(defun doom-docs--turn-off-view-mode-h ()
  (when (and doom-docs-view-mode (not buffer-read-only))
    (doom-docs-view-mode -1)))


;;; ** Hooks

(add-hook! 'doom-docs-view-mode-hook
           #'doom-docs--display-menu-h
           #'doom-docs--hide-meta-h
           #'doom-docs--hide-tags-h
           #'doom-docs--hide-drawers-h
           #'doom-docs--hide-blocks-h
           #'doom-docs--prettify-notices-h)


;;
;;; * `doom-docs-mode'

(defvar doom-docs-mode-map
  (let ((map (make-sparse-keymap))
        (cmd (cmds! buffer-read-only #'kill-current-buffer)))
    (define-key map "q" cmd)
    (define-key map [remap evil-record-macro] cmd)
    (define-key map [remap read-only-mode] #'doom-docs-view-mode)
    (define-key map "\C-c\C-e" #'doom-docs-view-mode)
    map))

;;;###autoload
(define-derived-mode doom-docs-mode org-mode "Doom Docs"
  "A derivative of `org-mode' for Doom's documentation files."
  :after-hook (doom-docs-mode--post-hook)
  (with-delayed-gc!
    (require 'org-id)
    (require 'ob)
    (setq-local org-id-link-to-org-use-id t
                org-id-method 'uuid
                org-id-track-globally t
                org-id-locations-file doom-docs--id-location-file
                org-id-locations doom-docs--id-locations
                org-id-files doom-docs--id-files
                org-num-max-level 3
                org-footnote-define-inline nil
                org-footnote-auto-label t
                org-footnote-auto-adjust t
                org-footnote-section nil
                wgrep-change-readonly-file t
                org-link-abbrev-alist-local (append doom-docs-link-alist org-link-abbrev-alist-local)
                org-babel-default-header-args
                (append '((:eval . "no") (:tangle . "no"))
                        org-babel-default-header-args)
                save-place-ignore-files-regexp "."
                org-todo-keyword-faces
                '(("TODO" . (bold default))
                  ("DONE" . shadow))
                org-startup-numerated t
                org-startup-indented t
                org-startup-with-inline-images t
                org-startup-folded 'show3levels
                org-hide-block-startup nil
                org-display-remote-inline-images 'cache
                ;; Don't highlight LaTeX in Doom docs. We won't need it and it
                ;; interferes with shell command snippets that may contain a $.
                org-highlight-latex-and-related nil
                org-auto-align-tags t
                org-tags-column -77)

    ;; HACK: Due to some backwards compatibility cludge in
    ;;   `org-set-regexps-and-options', it tries to read the default value of
    ;;   `org-todo-keywords', which requires this effort to temporarily change
    ;;   its value (to use a simpler value in doom-docs-mode buffers).
    (let ((old-value (copy-sequence (default-value 'org-todo-keywords))))
      (setq-default org-todo-keywords '((sequence "TODO" "DONE")))
      ;; ...and-parse buffer options so the above vars can be overridden by
      ;; #+STARTUP et co.
      (unwind-protect (org-set-regexps-and-options)
        (setq-default org-todo-keywords old-value)))

    ;; Ensure links are fully localized to doom-docs-mode buffers.
    (mapc #'make-local-variable '(org-link-types-re
                                  org-link-angle-re
                                  org-link-plain-re
                                  org-link-bracket-re
                                  org-link-any-re))
    (setq-local org-link-parameters (mapcar #'copy-sequence doom-docs--link-parameters))
    (org-link-make-regexps)
    (if (featurep 'org-element) (org-element-update-syntax))

    (unless org-inhibit-startup
      (org-unmodified
       (when org-startup-with-inline-images
         (quiet!  ; silence image downloading messages
           (if (fboundp 'org-link-preview)
               (org-link-preview '(16))
             (org-display-inline-images))))
       (when org-startup-indented
         (org-indent-mode +1))
       (when org-startup-numerated
         (when (bound-and-true-p org-num-mode)
           (org-num-mode -1))
         (org-num-mode +1))
       (unless (or (bound-and-true-p org-inhibit-startup-visibility-stuff)
                   (not org-startup-folded))
         (dlet (org-cycle-hide-drawer-startup)
           (org-set-startup-visibility)))))))

(defun doom-docs-mode--post-hook ()
  "Last-minute cleanup after `doom-docs-mode' initializes (and after hooks)."
  (unless org-inhibit-startup
    (with-delayed-gc!
      (visual-line-mode -1)  ; doom-docs use hard line wrapping
      ;; Redundant with `doom-docs-view-mode' and interferes with editing. Doom
      ;; docs with read-only mode off don't need to be pretty.
      (when (bound-and-true-p org-modern-mode)
        (org-modern-mode -1))
      (when (bound-and-true-p spell-fu-faces-exclude)
        (setq-local spell-fu-faces-exclude
                    (append spell-fu-faces-exclude
                            '(doom-docs-shell-command doom-docs-variable
                              doom-docs-function doom-docs-face
                              doom-docs-command doom-docs-kbd doom-docs-repo
                              doom-docs-package doom-docs-module))))
      (doom-docs--locations-load nil (list (current-buffer)))
      (when doom-docs-enable-view-mode
        (let ((file-name (buffer-file-name (buffer-base-buffer))))
          ;; The rationale: if it's empty or non-existant, you want to write an
          ;; org file, not read it.
          (when (and file-name
                     (> (buffer-size) 0)
                     (not (string-prefix-p "." (file-name-base file-name)))
                     (file-exists-p file-name))
            (doom-docs-view-mode +1)))))))


;;
;;; * Custom links

(defun doom-docs-link-help-echo (window object pos)
  (with-selected-window window
    (when-let* ((context (doom-docs-context-at-pos pos object))
                (target (doom-docs--get-link-description context))
                (type (org-element-property :type context)))
      (string-join
       (delq
        nil `(,(propertize
                (if-let* ((name (org-link-get-parameter type :help-name)))
                    (format "%s" (if (functionp name)
                                     (funcall name target)
                                   name))
                  "")
                'face 'bold)
              ,target
              ,(when-let* ((label (org-link-get-parameter type :help-desc)))
                 (concat
                  ":: " (or (ignore-errors
                              (car (split-string (if (functionp label)
                                                     (funcall label target)
                                                   label)
                                                 "\n")))
                            (propertize "<unknown>" 'face 'font-lock-doc-face))))))
       " "))))

(defun doom-docs-link-activate-func (beg end target bracket?)
  (when org-descriptive-links
    (let* ((context (org-element-context (org-element-at-point-no-context beg)))
           (desc (doom-docs--get-link-description context t)))
      (when-let* ((link (or (if (string-empty-p target) desc) target)))
        (if-let* ((buffer-read-only)
                  (type (org-element-property :type context))
                  (icon (org-link-get-parameter type :activate-icon))
                  (icon (if (functionp icon) (funcall icon link) icon)))
            (add-text-properties beg (1+ beg) `(display ,(concat icon " ")))
          (remove-text-properties beg (1+ beg) '(display t)))
        (unless desc
          (let ((offset (if bracket? 2 0))
                tagend)
            (add-text-properties
             (+ beg offset)
             (save-excursion
               (goto-char (+ beg offset))
               ;; Can't use :type because it could be aliased
               (skip-chars-forward "^:" end)
               (setq tagend (1+ (point))))
             '(invisible t intangible t cursor-intangible t))
            (save-match-data
              (and (equal (org-element-property :type context) "repo")
                   (string-match "^\\(.+@\\)?\\([a-z0-9]\\{8,40\\}\\)$" target)
                   (add-text-properties
                    (+ tagend (length (match-string 1 target)) 7)
                    (+ tagend (length target) offset)
                    `(invisible t intangible t cursor-intangible t))))))))))


;;; ** kbd:*

(defun doom-docs-link--kbd (keystr &optional user-friendly?)
  (dolist (key `(("<leader>" . ,doom-leader-key)
                 ("<localleader>" . ,doom-localleader-key)
                 ("<prefix>" . ,(if (bound-and-true-p evil-mode)
                                    (concat doom-leader-key " u")
                                  "C-u"))
                 ("<help>" . "C-h")
                 ,@(when user-friendly?
                     '(("RET" . "Return")
                       ("SPC" . "Space")
                       ("\\<M-" . "Meta-")
                       ("\\<S-" . "Shift-")
                       ("\\<s-" . "super-")
                       ("\\<C-" . "Ctrl-"))))
               keystr)
    (setq keystr
          (replace-regexp-in-string (car key) (cdr key)
                                    keystr t t))))

(defun doom-docs-link--kbd-follow (key)
  (message "%s %s"
           (propertize "Key sequence:" 'face 'bold)
           (doom-docs-link--kbd key t)))

(defun doom-docs-link--kbd-activate-func (beg end _path _bracketed?)
  (if (not org-descriptive-links)
      (remove-text-properties beg end '(display nil))
    (let* ((context (doom-docs-context-at-pos beg))
           (key (doom-docs--get-link-description context))
           (keystr (doom-docs-link--kbd key))
           (total (max 0 (- (string-width key)
                            (string-width keystr))))
           (keybeg (save-excursion
                     (goto-char beg)
                     (skip-chars-forward "^:" end)
                     (1+ (point)))))
      ;; Hide kbd:
      (add-text-properties
       beg keybeg `(invisible t intangible t cursor-intangible t))
      ;; Resolve keybinds in str:
      (when buffer-read-only
        (add-text-properties
         beg end `(display
                   ,(propertize (concat keystr (make-string total ?\s))
                                'face 'doom-docs-kbd)))))))

(defun doom-docs-link--kbd-help-echo (window object pos)
  (with-selected-window window
    (when-let* ((key (doom-docs--get-link-description
                      (doom-docs-context-at-pos pos object))))
      (concat "Key sequence: "
              (propertize (doom-docs-link--kbd key t)
                          'face 'help-key-binding)))))


;;; ** M-x:*

(defun doom-docs-link--M-x-activate-func (beg end _target _bracketed?)
  (let ((pt (save-excursion (goto-char beg)
                            (skip-chars-forward "^:" end)
                            (point))))
    (if (or (not org-descriptive-links)
            (doom-docs--get-link-description
             (org-element-context (org-element-at-point-no-context beg))
             t))
        (remove-text-properties pt (1+ pt) '(display nil))
      (add-text-properties pt (1+ pt) '(display " ")))))


;;; ** repo:*

(defun doom-docs-link--repo-follow (link)
  (browse-url
   (letf! (defun repo (link &rest suffix)
            (doom-docs--repo-url
             (save-match-data
               (if (and (stringp link) (string-match-p "/" link))
                   (split-string link "/")
                 (list nil link)))
             nil (if suffix (apply #'file-name-concat suffix))))
     (save-match-data
       (cond
        ;; ^[[user/]repo]#123[#issuecomment-4701619356]$
        ((string-match "^\\([^/]+\\(?:/[^/]+\\)?\\)?#\\([0-9]+\\(?:#.*\\)?\\)" link)
         (repo (match-string 1 link) "issues" (match-string 2 link)))
        ;; ^[user/]repo[@rev]:path/to/file[#L303]$
        ((string-match "^\\([^/]+\\(?:/[^/@]+\\)?\\)\\(?:@\\([^:]+\\)\\)?:\\(.+\\)$" link)
         (repo (match-string 1 link) "blob"
               (or (match-string 2 link)
                   (let ((ref (doom-call-process "git" "describe" "--tags" "--abbrev=0")))
                     (if (zerop (car ref)) (cdr ref) "HEAD")))
               (match-string 3 link)))
        ;; ^[[user/]repo@]v0.24$
        ((string-match "^\\(?:\\([^/]+\\(?:/[^/]+\\)?\\)@\\)?\\(v[0-9][0-9.]*\\)" link)
         ;; TODO: Redirect to changelog later
         (repo (match-string 1 link) "releases/tag" (match-string 2 link)))
        ;; ^[[user/]repo@]a1b2c3d4e$
        ((string-match "^\\(?:\\([^/]+\\(?:/[^/]+\\)?\\)@\\)?\\([a-f0-9]\\{7,\\}\\)" link)
         (repo (match-string 1 link) "commit" (match-string 2 link)))
        ;; ^[user/]repo[[#?]...]$
        ((string-match "^\\([^/]+\\(?:/[^/]+\\)?\\)\\([#?].+\\)?$" link)
         (repo (match-string 1 link) (match-string 2 link)))
        ((user-error "Invalid repo link: %S" link)))))))


;;; ** package:*

(defun doom-docs-link--package-help-desc (package)
  (cond ((featurep (intern-soft package))
         (propertize "installed and loaded" 'face 'success))
        ((locate-library package)
         (propertize "installed but not loaded" 'face 'warning))
        ((propertize "not installed" 'face 'error))))


;;; ** module:*

;; (defvar doom-docs--source nil)
(defun doom-docs--read-module-spec (module-spec-str)
  (let (source)
    (save-match-data
      (if (string-match "^(\\([^)]+\\)) " module-spec-str)
          (setq source (match-string 1 module-spec-str)
                module-spec-str (substring
                                 module-spec-str (length (match-string 0 module-spec-str))))
        ;; (or doom-docs--source
        ;;     (setq-local doom-docs--source (doom-source-from-path)))
        ))
    (if (string-match-p "^[-+]" (string-trim-left module-spec-str))
        (let ((title (cadar (org-collect-keywords '("TITLE")))))
          (if (and title (string-match-p "\\`:[a-z]+\\s-+[A-Za-z0-9]+\\'" title))
              (doom-docs--read-module-spec (concat title " " module-spec-str))
            (cl-destructuring-bind (group . module) (doom-module-from-path default-directory)
              (list :source source
                    :group group
                    :module module
                    :flag (intern module-spec-str)))))
      (cl-destructuring-bind (group &optional module flag)
          (mapcar #'intern (split-string
                            (if (string-prefix-p ":" module-spec-str)
                                module-spec-str
                              (concat ":" module-spec-str))
                            "[ \n][-+]" nil))
        (list :source source
              :group group
              :module module
              :flag flag)))))

(defun doom-docs-link--module-help-desc (link)
  (cl-destructuring-bind (&key _source group module flag)
      (doom-docs--read-module-spec link)
    (cond ((doom-module-active-p group module)
           (propertize "enabled" 'face 'success))
          ((and group (doom-module-locate-path (cons group module)))
           (propertize "disabled" 'face 'error))
          ((propertize "unknown" 'face '(bold error))))))

(defun doom-docs-link--module-follow (module-path _arg)
  (cl-destructuring-bind (&key _source group module flag)
      (doom-docs--read-module-spec module-path)
    (when group
      (if-let* ((path (doom-module-locate-path (cons group module)))
                (path (or (car (doom-glob path "README.org"))
                          path)))
          (find-file path)
        (user-error "Can't find Doom module '%s'" module-path)))
    (when flag
      (goto-char (point-min))
      (when (and (re-search-forward "^\\*+ \\(?:TODO \\)?Module flags")
                 (re-search-forward (format "^\\s-*- [-+]%s ::[ \n]"
                                            (substring (symbol-name flag) 1))
                                    (save-excursion (org-get-next-sibling)
                                                    (point))))
        (org-show-subtree)
        (recenter)))))


;;; ** abbr:*

(defvar doom-docs--abbr-cache nil
  "Hash table mapping words to definitions and location.")

(defun doom-docs--abbr-file ()
  (doom-path doom-docs-dir "appendix.org"))

(defun doom-docs--abbr-populate (&optional force?)
  (or (and (not force?)
           (hash-table-p doom-docs--abbr-cache))
      (with-temp-buffer
        (setq doom-docs--abbr-cache (make-hash-table :test 'equal))
        (insert-file-contents (doom-docs--abbr-file))
        (dlet ((org-inhibit-startup t))
          (delay-mode-hooks (org-mode)))
        (while (re-search-forward "^\\(- +\\)\\([^:]+\\):: *" nil t)
          (let ((indent (string-width (match-string 1)))
                (beg (match-beginning 1))
                (words (match-string-no-properties 2))
                (def (string-trim
                      (buffer-substring-no-properties
                       (match-end 0) (save-excursion (org-end-of-item) (point)))
                      "\n" "\n")))
            (unless (eolp)
              (with-temp-buffer
                (insert def)
                (indent-rigidly (point-min) (point-max) (- indent))
                (setq def (buffer-string))))
            (dolist (word (split-string words ", "))
              (puthash (downcase (string-trim word)) (cons def beg) doom-docs--abbr-cache))))
        t)))

(defun doom-docs-link--abbr-follow (target)
  (doom-docs--abbr-populate)
  (if-let* ((def (gethash (downcase target) doom-docs--abbr-cache)))
      (let ((file (doom-docs--abbr-file)))
        (with-current-buffer
            (switch-to-buffer (or (get-file-buffer file)
                                  (find-file-noselect file)))
          (goto-char (cdr def))
          (when (org-invisible-p (cdr def))
            (org-reveal '(4)))))
    (user-error "No appendix definition for %S" target)))

(defun doom-docs-link--abbr-help-desc (target)
  (doom-docs--abbr-populate)
  (if-let* ((def (gethash (downcase target) doom-docs--abbr-cache)))
      (replace-regexp-in-string org-link-any-re "\\3" (car def))
    (propertize "<No appendix definition for %S>" 'face 'warning)))


;;; ** filter:*

(defun doom-docs-link--filter-follow (match)
  (and (org-tags-sparse-tree nil match)
       (message "Filtered to: %s" target)))


;;; ** Link abbrevs

(defun doom-docs--link-help (_link)
  (cond ((eq (car doom-docs--type) 'module)
         "id:1ee0b650-f09b-4454-8690-cc145aadef6e")
        ((file-in-directory-p buffer-file-name (doom-path doom-docs-dir "news/"))
         "id:7c56cc08-b54b-4f4b-b106-a76e2650addd")
        ("id:9bb17259-0b07-45a8-ae7a-fc5e0b16244e")))

(defun doom-docs--link-history (_link)
  (cond ((require 'magit nil t)
         (format
          "elisp:%S" '(magit-log-setup-buffer
                       (list (or (magit-get-current-branch) "HEAD"))
                       (car (magit-log-arguments))
                       (list default-directory)
                       nil)))
        ((and (bound-and-true-p vc-mode) (vc-backend buffer-file-name))
         (format
          "elisp:%S" '(switch-to-buffer
                       (save-window-excursion
                         (vc-print-log-internal (vc-backend buffer-file-name)
                                                (list default-directory)
                                                nil)
                         (current-buffer)))))
        ((doom-docs--repo-url
          nil nil
          (if-let* ((key (doom-module-from-path default-directory)))
              (format "commits/main/modules/%s/%s"
                      (doom-keyword-name (car key)) (cdr key))
            (format "commits/main/%s"
                    (file-relative-name default-directory (doom-project-root))))))))

(defun doom-docs--link-issues (_link)
  (doom-docs--repo-url
   nil nil (if-let* ((key (doom-module-from-path default-directory)))
               (format "labels/%s %s" (car key) (cdr key))
             "issues")))

(defun doom-docs--link-report (_link)
  (if-let* ((repo (doom-config '(project name))))
      (doom-docs--repo-url (split-string (symbol-name repo) "/") nil "issues/new/choose")
    "https://github.com/orgs/doomemacs/discussions/new?category=issues"))

(defun doom-docs--link-root (link)
  (concat "file:"
          (file-relative-name (expand-file-name
                               (if (string-empty-p link)
                                   "docs/index.org"
                                 (format "docs/%s" link))
                               (doom-config-locate 'project default-directory t))
                              default-directory)))

(defun doom-docs--link-up (_link)
  (let ((module-root (doom-config-locate 'module default-directory))
        (source-root (doom-config-locate 'modules default-directory)))
    (cond (module-root
           (concat "file:" (file-relative-name source-root default-directory)))
          (source-root
           (when-let*
               ((file (or (file-exists-p! "index.org" source-root)
                          (file-exists-p!
                           "docs/index.org" (doom-config-locate 'project default-directory)))))
             (concat "file:" (file-relative-name file default-directory))))
          ("doom-index:"))))


;;
;;; * Org config

(with-eval-after-load 'org
  ;; Ensure these links are restricted to `doom-docs-mode' buffers.
  (let ((org-link-parameters (mapcar #'copy-sequence org-link-parameters)))
    (letf! ((#'org-link-make-regexps #'ignore)
            (#'org-element-update-syntax #'ignore)
            (defun call (fn &optional map)
              (lambda (path _prefixarg)
                (funcall (or (command-remapping fn) fn)
                         (or (intern-soft path)
                             (user-error "Can't find documentation for %S" path))))))

      ;; This is repeated from the :lang org module in case the module is
      ;; disabled.
      (org-link-set-parameters
       "file" :face (lambda (path)
                      (if (or
                           ;; file uris is not a valid path on windows
                           ;; ref https://lists.gnu.org/archive/html/bug-gnu-emacs/2024-05/threads.html#00729
                           ;; emacs <= 29 crashes for (file-exists-p "file://whatever")
                           (if (featurep :system 'windows)
                               (or (string-prefix-p "//" path)
                                   ;; filter out network shares on windows (slow)
                                   (string-prefix-p "\\\\" path)))
                           (file-exists-p path))
                          'org-link
                        '(:inherit (error org-link) :underline nil))))
      (org-link-set-parameters "elisp" :face 'link-visited)
      (org-link-set-parameters
       "filter"
       :follow #'doom-docs-link--filter-follow
       :activate-func #'doom-docs-link-activate-func
       :face 'link-visited)

      (org-link-set-parameters
       "sh"
       :activate-func #'doom-docs-link-activate-func
       :face 'doom-docs-shell-command)

      (org-link-set-parameters
       "var"
       :follow (call #'describe-variable)
       :face 'doom-docs-variable
       :help-echo #'doom-docs-link-help-echo
       :help-name "Variable:"
       :help-desc (fn! (documentation-property (intern-soft %) 'variable-documentation t)))
      (dolist (key '("fns" "mode" "major" "minor"))
        (org-link-set-parameters
         key
         :follow (call #'describe-function)
         :face 'doom-docs-function
         :help-echo #'doom-docs-link-help-echo
         :help-name (lambda (sym)
                      (pcase key
                        ("fns" "Function:")
                        ("mode" "Mode:")
                        ("minor" "Minor mode:")
                        ("major" "Major mode:")))
         :help-desc (fn! (function-documentation (intern-soft %)))))
      (dolist (key '("mode" "major" "minor"))
        (org-link-set-parameters key :activate-func #'doom-docs-link-activate-func))
      (org-link-set-parameters
       "face"
       :follow (call #'describe-face)
       :face 'doom-docs-face
       :help-echo #'doom-docs-link-help-echo
       :help-name "Face:"
       :help-desc (fn! (face-documentation (intern-soft %))))
      (org-link-set-parameters
       "cmd"
       :follow (call #'describe-command)
       :face 'doom-docs-command
       :help-echo #'doom-docs-link-help-echo
       :help-name "Command:"
       :help-desc (fn! (function-documentation (intern-soft %))))
      (org-link-set-parameters
       "M-x"
       :follow (call #'describe-command)
       :face 'doom-docs-command
       :activate-func #'doom-docs-link--M-x-activate-func
       :help-echo #'doom-docs-link-help-echo
       :help-name "M-x"
       :help-desc (fn! (function-documentation (intern-soft %))))
      (org-link-set-parameters
       "kbd"
       :follow #'doom-docs-link--kbd-follow
       :face 'doom-docs-kbd
       :activate-func #'doom-docs-link--kbd-activate-func
       :help-echo #'doom-docs-link--kbd-help-echo)
      (org-link-set-parameters
       "repo"
       :follow #'doom-docs-link--repo-follow
       :face 'doom-docs-repo
       :activate-func #'doom-docs-link-activate-func)
      (org-link-set-parameters
       "package"
       :follow (lambda (path _)
                 (doom/describe-package
                  (or (intern path)
                      (user-error "Can't look up package %S" path))))
       :face 'doom-docs-package
       :activate-func #'doom-docs-link-activate-func
       :activate-icon (fn! (when (org-at-item-p)
                             (doom-docs--icon
                              "nf-oct-package" nil  ; ""
                              :face (cond ((featurep (intern %)) 'success)
                                          ((locate-library %) 'warning)
                                          ('error)))))
       :help-echo #'doom-docs-link-help-echo
       :help-name "Emacs package:"
       :help-desc #'doom-docs-link--package-help-desc)
      (org-link-set-parameters
       "module"
       :follow #'doom-docs-link--module-follow
       :face 'doom-docs-module
       :activate-func #'doom-docs-link-activate-func
       :help-echo #'doom-docs-link-help-echo
       :help-name "Doom module:"
       :help-desc #'doom-docs-link--module-help-desc)
      (org-link-set-parameters
       "abbr"
       :follow #'doom-docs-link--abbr-follow
       :face 'doom-docs-abbr
       :activate-func #'doom-docs-link-activate-func
       :help-echo #'doom-docs-link-help-echo
       :help-name "Abbreviation:"
       :help-desc #'doom-docs-link--abbr-help-desc)

      (setq doom-docs--link-parameters org-link-parameters))))


;;
;;; * Commands

(defun doom-docs--locations-load (&optional force? buffers)
  (with-delayed-gc!
    (when (or force? (null doom-docs--id-files))
      (with-temp-buffer
        (delay-mode-hooks
          (dlet ((org-inhibit-startup t)
                 (org-id-locations-file doom-docs--id-location-file)
                 (org-id-track-globally t)
                 org-id--locations-checksum
                 org-id-locations-file-relative
                 org-id-extra-files
                 org-id-files
                 org-id-locations
                 org-id-extra-files
                 org-agenda-files)
            (if (or force? (not (file-exists-p org-id-locations-file)))
                (letf! (defun! org-buffer-list (&rest _) nil)
                  (org-id-update-id-locations
                   (doom-files-in (doom-docs-load-path) :match "/[^_.][^./]+\\.org\\'")))
              (org-id-locations-load))
            (setq doom-docs--id-files (copy-sequence org-id-files)
                  doom-docs--id-locations (copy-hash-table org-id-locations))))))
    (let ((files (copy-sequence doom-docs--id-files))
          (locations (copy-hash-table doom-docs--id-locations)))
      (dolist (buffer (ensure-list buffers))
        (with-current-buffer buffer
          (when (eq major-mode 'doom-docs-mode)
            (setq-local org-id-files files
                        org-id-locations locations)))))))

;;;###autoload
(defun doom/reload-docs (&optional force?)
  "Reload org ID locations & appendix terms in `doom-docs-mode' buffers.

If FORCE? is non-nil, do it even if they're already loaded."
  (interactive (list 'interactive))
  (doom-docs--locations-load force? (doom-buffers-in-mode 'doom-docs-mode))
  (doom-docs--abbr-populate force?))

;;;###autoload
(defun doom/docs (&optional file)
  "View Doom's documentation FILE.

If the prefix arg is set, open docs.doomemacs.org instead.

\(fn &optional FILE)"
  (interactive)
  (doom-docs-find-file (or file (doom-path doom-docs-dir "index.org"))
                       "Loading Doom manual..."))

;;;###autoload
(defun doom/docs-find-file (&optional file)
  "Browse `doom-docs-dir'."
  (interactive (list (read-file-name "Find docs file: " doom-docs-dir "index.org" t)))
  (doom-docs-find-file file "Loading Doom docs file..."))

;;;###autoload
(defun doom/docs-module (key &optional visit-dir?)
  "Open the documentation for a Doom module by KEY.

See `doom-module-key' for details on SOURCE, GROUP, and MODULE. Automatically
selects the module at point (in `doom!'), the module derived from a `modulep!'
call, or the module that contains the current file.

If VISIT-DIR? is non-nil, visit the module's directory rather than its
documentation.

\(fn (SOURCE GROUP MODULE [FLAGS...]) &optional VISIT-DIR?)"
  (interactive
   (list (doom-module-completing-read "Describe module: ")
         current-prefix-arg))
  (cl-destructuring-bind (_source group module . flags) key
    (let* ((dir (doom-module-locate-path (cons group module)))
           (readme (doom-path dir "README.org")))
      (unless (file-directory-p dir)
        (user-error "Can't find module: %s %s" group module))
      (if (and (not visit-dir?) (file-exists-p readme))
          (let ((case-fold-search t))
            (doom-docs-find-file readme "Loading module documentation...")
            (when (derived-mode-p 'org-mode)
              (goto-char (point-min))
              (with-demoted-errors "%s"
                (re-search-forward
                 (if flags "^\\*+ Module flags" "^\\* Description"))
                (when flags
                  (re-search-forward (format "=\\%s=" (car flags)) nil t))
                (when (memq (get-char-property (line-end-position) 'invisible)
                            '(outline org-fold-outline))
                  (org-show-hidden-entry)))))
        (doom-project-browse (file-name-as-directory dir))))))

;;;###autoload
(defun doom/docs-news (&optional interactive?)
  "Visit Doom's news file.
\(fn &optional INTERACTIVE?)"
  (interactive '(interactive))
  (doom/docs (read-file-name
              "Select version: " (doom-path doom-docs-dir "news/")
              (apply #'format "v%d.%d.org" (seq-take (version-to-list (doom-version)) 2))
              t)
             interactive?))

;;;###autoload
(defun doom/docs-search (&optional initial-input)
  "Perform a text search on all of Doom's documentation"
  (interactive)
  (funcall (cond ((fboundp '+ivy-file-search) #'+ivy-file-search)
                 ((fboundp '+helm-file-search) #'+helm-file-search)
                 ((fboundp '+vertico-file-search) #'+vertico-file-search)
                 ((and (fboundp 'consult-grep) (executable-find "grep"))
                  (consult-grep doom-docs-dir initial-input)
                  #'ignore)
                 ((rgrep
                   (read-regexp
                    "Search for" (or initial-input 'grep-tag-default)
                    'grep-regexp-history)
                   "*.org" doom-docs-dir)
                  #'ignore))
           :query initial-input
           :args '("-t" "org")
           :in doom-emacs-dir
           :prompt "Search documentation for: "))

(cl-defun doom-docs--headings (files &key depth mindepth include-files &allow-other-keys)
  (let ((default-directory doom-docs-dir)
        (depth (if (integerp depth) depth 999))
        (mindepth (if (integerp mindepth) mindepth 0)))
    (dlet ((org-agenda-files (mapcar #'expand-file-name (ensure-list files)))
           (org-inhibit-startup t))
      (require 'org)
      (unwind-protect
          (delq
           nil
           (org-map-entries
            (lambda ()
              (let ((level (org-current-level))
                    tags)
                (when (and (<= level depth)
                           (>= level mindepth)
                           (not (cl-loop for tag in (setq tags (org-get-tags))
                                         if (or (member tag '("hide" "nosearch" "noorg"))
                                                (string-prefix-p "TOC" tag))
                                         return t)))
                  `(:level ,level
                    :title ,(cdr (assoc "TITLE" (org-collect-keywords '("TITLE") '("TITLE"))))
                    :path ,(org-get-outline-path)
                    :heading ,(replace-regexp-in-string org-link-any-re "\\4" (substring-no-properties (org-get-heading t t t t)))
                    :tags ,tags
                    :file ,(buffer-file-name)
                    :pos  ,(point)))))
            t 'agenda))
        (mapc #'kill-buffer org-agenda-new-buffers)
        (setq org-agenda-new-buffers nil)))))

;;;###autoload
(defun doom/docs-headings (files &optional initial-input)
  "Jump to an org heading in org FILES."
  (interactive (list (doom-glob doom-docs-dir "*.org")))
  (with-delayed-gc!
    (when-let*
        ((headings
          (with-temp-message "Loading search results..."
            (doom-docs--headings files :depth 3 :include-files t)))
         (cands
          (cl-loop for cand in headings
                   collect
                   (cons (format "%s  %s"
                                 (string-join `(,(propertize (plist-get cand :title) 'face 'org-document-title)
                                                ,@(plist-get cand :path)
                                                ,(plist-get cand :heading))
                                              (propertize " > " 'face 'shadow))
                                 (propertize (string-join (plist-get cand :tags) ":") 'face 'shadow))
                         cand)))
         (choice
          (completing-read
           "Find in Doom docs: "
           (lambda (str pred action)
             (if (eq action 'metadata)
                 `(metadata
                   (category . org-heading)
                   (display-sort-function . identity))
               (complete-with-action action cands str pred)))
           nil t initial-input))
         (choice (cdr (assoc choice cands)))
         (file (plist-get choice :file))
         (pos (plist-get choice :pos)))
      (doom-docs-find-file file "Loading doom-docs file...")
      (when pos
        (goto-char pos)
        (when (doom-docs--invisible-p (point))
          (org-show-entry)
          (org-show-children))))))

(provide 'doom-docs)
;;; doom-docs.el ends here
