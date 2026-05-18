;;; email/mu4e/config.el -*- lexical-binding: t; -*-

(defvar +mu4e-backend 'mbsync
  "Which backend to use. Can either be offlineimap, mbsync or nil (manual).")
(make-obsolete-variable '+mu4e-backend "Use the :email mu4e module's +mbsync or +offlineimap flags instead" "24.09")

(defvar +mu4e-personal-addresses 'nil
  "Alternative to mu4e-personal-addresses that can be set for each account (mu4e context).")


;;
;;; Packages

(use-package! mu4e
  :commands mu4e mu4e-compose-new
  :init
  (provide 'html2text) ; disable obsolete package
  (when (or (not (or (require 'mu4e-config nil t)
                     (require 'mu4e-meta nil t)))
            (version< mu4e-mu-version "1.4"))
    (setq mu4e-maildir "~/.mail"
          mu4e-user-mail-address-list nil))
  :config
  (set-debug-var! 'mu4e-debug)
  ;; mu4e now uses `display-buffer-alist' so we need to add some rules of our own
  (set-popup-rule! "^\\*mu4e-\\(main\\|headers\\)\\*" :ignore t)
  (set-popup-rule! "^\\*mu4e-log\\*" :select nil)

  ;; Treat mu4e main menu buffer as real, so it can be switched to or fallen
  ;; back to when killing other buffers.
  (add-hook 'mu4e-main-mode-hook #'doom-mark-buffer-as-real-h)

  ;; Line numbers add nothing to mu4e's read-only views (excluding compose).
  (add-hook! '(mu4e-main-mode-hook
               mu4e-headers-mode-hook
               mu4e-view-mode-hook)
             #'doom-disable-line-numbers-h)

  ;; Ensures backward/forward compatibility for mu4e, which is prone to breaking
  ;; updates, and also cannot be pinned, because it's bundled with mu (which you
  ;; must install via your OS package manager).
  (with-demoted-errors "%s" (require 'mu4e-compat nil t))
  ;; For users on older mu4e.
  (unless (boundp 'mu4e-headers-buffer-name)
    (defvar mu4e-headers-buffer-name "*mu4e-headers*"))

  (cond ((or (modulep! +mbsync)
             (eq +mu4e-backend 'mbsync))
         (setq mu4e-get-mail-command
               (concat "mbsync --all"
                       ;; XDG support was added to isync 1.5, but this lets
                       ;; users on older benefit from it sooner.
                       (when-let* ((file (file-exists-p! "isyncrc" (or (getenv "XDG_CONFIG_HOME") "~/.config"))))
                         (format " --config %S" file)))
               mu4e-change-filenames-when-moving t))
        ((or (modulep! +offlineimap)
             (eq +mu4e-backend 'offlineimap))
         (setq mu4e-get-mail-command "offlineimap -o -q")))

  (when (version< mu4e-mu-version "1.8")
    ;; Define aliases to maintain backwards compatibility. The list of suffixes
    ;; were obtained by comparing mu4e~ and mu4e-- functions in `obarray'.
    (dolist (transferable-suffix
             '("check-requirements" "contains-line-matching" "context-ask-user"
               "context-autoswitch" "default-handler" "get-folder" "get-log-buffer"
               "get-mail-process-filter" "guess-maildir" "key-val"
               "longest-of-maildirs-and-bookmarks" "maildirs-with-query"
               "main-action-str" "main-bookmarks" "main-maildirs" "main-menu"
               "main-queue-size" "main-redraw-buffer"
               "main-toggle-mail-sending-mode" "main-view" "main-view-queue"
               "main-view-real" "main-view-real-1" "mark-ask-target"
               "mark-check-target" "mark-clear" "mark-find-headers-buffer"
               "mark-get-dyn-target" "mark-get-markpair" "mark-get-move-target"
               "mark-in-context" "mark-initialize" "org-store-link-message"
               "org-store-link-query" "pong-handler" "read-char-choice"
               "read-patch-directory" "replace-first-line-matching"
               "request-contacts-maybe" "rfc822-phrase-type" "start" "stop"
               "temp-window" "update-contacts" "update-mail-and-index-real"
               "update-mail-mode" "update-sentinel-func" "view-gather-mime-parts"
               "view-open-file" "view-mime-part-to-temp-file"))
      (defalias (intern (concat "mu4e--" transferable-suffix))
        (intern (concat "mu4e~" transferable-suffix))
        "Alias to provide the API of mu4e 1.8 (mu4e~ ⟶ mu4e--).")
      (dolist (transferable-proc-suffixes
               '("add" "compose" "contacts" "eat-sexp-from-buf" "filter"
                 "find" "index" "kill" "mkdir" "move" "ping" "remove"
                 "sent" "sentinel" "start" "view"))
        (defalias (intern (concat "mu4e--server-" transferable-proc-suffixes))
          (intern (concat "mu4e~proc-" transferable-proc-suffixes))
          "Alias to provide the API of mu4e 1.8 (mu4e~proc ⟶ mu4e--server)."))
      (defalias 'mu4e-search-rerun #'mu4e-headers-rerun-search
        "Alias to provide the API of mu4e 1.8.")
      (defun mu4e (&optional background)
        "If mu4e is not running yet, start it.
Then, show the main window, unless BACKGROUND (prefix-argument)
is non-nil."
        (interactive "P")
        (mu4e--start (and (not background) #'mu4e--main-view))))
    (setq mu4e-view-show-addresses t
          mu4e-view-show-images t
          mu4e-view-image-max-width 800
          mu4e-view-use-gnus t))

  (setq mu4e-update-interval nil
        mu4e-notification-support t
        mu4e-sent-messages-behavior 'sent
        mu4e-hide-index-messages t
        ;; configuration for sending mail
        message-send-mail-function #'smtpmail-send-it
        smtpmail-stream-type 'starttls
        message-kill-buffer-on-exit t ; close after sending
        ;; start with the first (default) context;
        mu4e-context-policy 'pick-first
        ;; compose with the current context, or ask
        mu4e-compose-context-policy 'ask-if-none
        ;; use helm/ivy/vertico
        mu4e-completing-read-function
        (cond ((modulep! :completion ivy)     #'ivy-completing-read)
              ((modulep! :completion helm)    #'completing-read)
              ((modulep! :completion vertico) #'completing-read)
              (t #'ido-completing-read))
        mu4e-attachment-dir
        (concat
         (if-let* ((xdg-download-query (and (executable-find "xdg-user-dir")
                                            (doom-call-process "xdg-user-dir" "DOWNLOAD")))
                   (xdg-download-dir (and (= 0 (car xdg-download-query)) (cdr xdg-download-query))))
             xdg-download-dir
           (expand-file-name (or (getenv "XDG_DOWNLOAD_DIR")
                                 "Downloads")
                             "~"))
         "/") ; a trailing / makes it easier to change directory in `read-file-name'
        ;; no need to ask
        mu4e-confirm-quit nil
        mu4e-headers-thread-single-orphan-prefix '("─>" . "─▶")
        mu4e-headers-thread-orphan-prefix        '("┬>" . "┬▶ ")
        mu4e-headers-thread-connection-prefix    '("│ " . "│ ")
        mu4e-headers-thread-first-child-prefix   '("├>" . "├▶")
        mu4e-headers-thread-child-prefix         '("├>" . "├▶")
        mu4e-headers-thread-last-child-prefix    '("└>" . "╰▶")
        ;; remove 'lists' column
        mu4e-headers-fields
        '((:account-stripe . 1)
          (:human-date . 12)
          (:flags . 6) ; 3 icon flags
          (:from-or-to . 25)
          (:subject)))

  ;; Better search symbols
  (letf! ((defun make-help-button (text help-echo)
            (with-temp-buffer
              (insert " ")
              (insert-text-button text
                                  'help-echo help-echo
                                  'mouse-face nil)
              (buffer-string)))
          (defun make-help-button-cons (text1 text2 help-echo)
            (cons (make-help-button text1 help-echo)
                  (make-help-button text2 help-echo))))
    (setq mu4e-headers-threaded-label
          (make-help-button-cons "T" (nerd-icons-octicon "nf-oct-git_branch" :v-adjust 0.05)
                                 "Thread view")
          mu4e-headers-related-label
          (make-help-button-cons "R" (nerd-icons-mdicon "nf-md-link" :v-adjust -0.1)
                                 "Showing related emails")
          mu4e-headers-full-label
          (make-help-button-cons "F" (nerd-icons-mdicon "nf-md-disc")
                                 "Search is full!")))

  ;; set mail user agent
  (setq mail-user-agent 'mu4e-user-agent
        message-mail-user-agent 'mu4e-user-agent)

  ;; Set the icons only when a graphical frame has been created
  (if (display-graphic-p)
      (+mu4e-initialise-icons)
    ;; When it's the server, wait till the first graphical frame
    (add-hook!
     'server-after-make-frame-hook
     (defun +mu4e-initialise-icons-hook ()
       (when (display-graphic-p)
         (+mu4e-initialise-icons)
         (remove-hook 'server-after-make-frame-hook
                      #'+mu4e-initialise-icons-hook)))))

  (plist-put (cdr (assoc :flags mu4e-header-info)) :shortname " Flags") ; default=Flgs
  (add-to-list 'mu4e-bookmarks
               '("flag:flagged" "Flagged messages" ?f) t)

  ;; TODO: avoid assuming that nerd-icons is present
  (defvar +mu4e-header-colorized-faces
    '(nerd-icons-green
      nerd-icons-lblue
      nerd-icons-purple-alt
      nerd-icons-blue-alt
      nerd-icons-purple
      nerd-icons-yellow)
    "Faces to use when coloring folders and account stripes.")

  ;; Add a column to display what email account the email belongs to,
  ;; and an account color stripe column
  (defvar +mu4e-header--maildir-colors nil)
  (setq mu4e-header-info-custom
        '((:account .
           (:name "Account"
            :shortname "Account"
            :help "which account/maildir this email belongs to"
            :function
            (lambda (msg)
              (let ((maildir (replace-regexp-in-string
                              "\\`/?\\([^/]+\\)/.*\\'" "\\1"
                              (mu4e-message-field msg :maildir))))
                (+mu4e-colorize-str
                 (replace-regexp-in-string
                  "^gmail"
                  (propertize "g" 'face 'bold-italic)
                  maildir)
                 '+mu4e-header--maildir-colors
                 maildir)))))
          (:account-stripe .
           (:name "Account"
            :shortname "▐"
            :help "Which account/maildir this email belongs to"
            :function
            (lambda (msg)
              (let ((account
                     (replace-regexp-in-string
                      "\\`/?\\([^/]+\\)/.*\\'" "\\1"
                      (mu4e-message-field msg :maildir))))
                (propertize
                 (+mu4e-colorize-str "▌" '+mu4e-header--maildir-colors account)
                 'help-echo account)))))
          (:recipnum .
           (:name "Number of recipients"
            :shortname " ⭷"
            :help "Number of recipients for this message"
            :function
            (lambda (msg)
              (propertize (format "%2d"
                                  (+ (length (mu4e-message-field msg :to))
                                     (length (mu4e-message-field msg :cc))))
                          'face 'mu4e-footer-face))))))

  ;; Marks usually affect the current view
  (defadvice! +mu4e--refresh-current-view-a (&rest _)
    :after #'mu4e-mark-execute-all (mu4e-search-rerun))

  ;; Wrap text in messages
  (setq-hook! 'mu4e-view-mode-hook truncate-lines nil)

  ;; Html mails might be better rendered in a browser
  (add-to-list 'mu4e-view-actions '("view in browser" . mu4e-action-view-in-browser))
  (when (fboundp 'xwidget-webkit-browse-url)
    (add-to-list 'mu4e-view-actions '("xview in xwidget" . mu4e-action-view-in-xwidget)))

  ;; Detect empty subjects, and give users an opotunity to fill something in
  (add-hook! 'message-send-hook
    (defun +mu4e-check-for-subject ()
      "Check that a subject is present, and prompt for a subject if not."
      (save-excursion
        (goto-char (point-min))
        (search-forward "--text follows this line--")
        (re-search-backward "^Subject:") ; this should be present no matter what
        (let ((subject (string-trim (substring (thing-at-point 'line) 8))))
          (when (string-empty-p subject)
            (end-of-line)
            (insert (read-string "Subject (optional): "))
            (message "Sending..."))))))

  ;; Fix columns misalignment in Headers buffers
  (add-hook! 'mu4e-headers-mode-hook
    (defun +mu4e-headers-fix-alignment-h ()
      "Header line face inherits from the default face"
      (header-line-indent-mode 1)
      (push (propertize " " 'display '(space :align-to header-line-indent-width)) header-line-format)
      (face-remap-add-relative 'header-line '(:inherit (mu4e-header-face default)))))

  (when (fboundp 'imagemagick-register-types)
    (imagemagick-register-types))

  (map! (:when (modulep! :ui workspaces)
         :map mu4e-main-mode-map
         :ne "h" #'+workspace/other)
        :map mu4e-headers-mode-map
        :vne "l" #'+mu4e/capture-msg-to-agenda)

  ;; Functionality otherwise obscured in mu4e 1.6
  (when (version<= "1.6" mu4e-mu-version)
    (defun +mu4e-view-select-attachment ()
      "Use completing-read to select a single attachment.
Acts like a singular `mu4e-view-save-attachments', without the saving."
      (if-let* ((parts (delq nil (mapcar
                                  (lambda (part)
                                    (when (assoc "attachment" (cdr part))
                                      part))
                                  (mu4e--view-gather-mime-parts))))
                (files (+mu4e-part-selectors parts)))
          (cdr (assoc (completing-read "Select attachment: " (mapcar #'car files)) files))
        (user-error (mu4e-format "No attached files found"))))

    (defun +mu4e-view-open-attachment ()
      "Select an attachment, and open it."
      (interactive)
      (mu4e--view-open-file
       (mu4e--view-mime-part-to-temp-file (cdr (+mu4e-view-select-attachment)))))

    (defun +mu4e-view-select-mime-part-action ()
      "Select a MIME part, and perform an action on it."
      (interactive)
      (let ((labeledparts (+mu4e-part-selectors (mu4e--view-gather-mime-parts))))
        (if labeledparts
            (mu4e-view-mime-part-action
             (cadr (assoc (completing-read "Select part: " (mapcar #'car labeledparts))
                          labeledparts)))
          (user-error (mu4e-format "No parts found")))))

    (map! :map mu4e-view-mode-map
          :ne "A" #'+mu4e-view-select-mime-part-action
          :ne "p" #'mu4e-view-save-attachments
          :ne "o" #'+mu4e-view-open-attachment)

    (defun +mu4e-part-selectors (parts)
      "Generate selection strings for PARTS."
      (if parts
          (let (partinfo labeledparts maxfnamelen fnamefmt maxsizelen sizefmt)
            (dolist (part parts)
              (push (list :index (car part)
                          :mimetype (if (and (string= "text/plain" (caaddr part))
                                             (alist-get 'charset (cdaddr part)))
                                        (format "%s (%s)"
                                                (caaddr part)
                                                (alist-get 'charset (cdaddr part)))
                                      (caaddr part))
                          :type (car (nth 5 part))
                          :filename (cdr (assoc 'filename (assoc "attachment" (cdr part))))
                          :size (file-size-human-readable (with-current-buffer (cadr part) (buffer-size)))
                          :part part)
                    partinfo))
            (setq maxfnamelen (apply #'max 7 (mapcar (lambda (i) (length (plist-get i :filename))) partinfo))
                  fnamefmt (format " %%-%ds  " maxfnamelen)
                  maxsizelen (apply #'max (mapcar (lambda (i) (length (plist-get i :size))) partinfo))
                  sizefmt (format "%%-%ds " maxsizelen))
            (dolist (pinfo partinfo)
              (push (cons (concat (propertize (format "%-2s " (plist-get pinfo :index)) 'face '(bold font-lock-type-face))
                                  (when (featurep 'nerd-icons)
                                    (nerd-icons-icon-for-file (or (plist-get pinfo :filename) "")))
                                  (format fnamefmt (or (plist-get pinfo :filename)
                                                       (propertize (plist-get pinfo :type) 'face '(italic font-lock-doc-face))))
                                  (format sizefmt (propertize (plist-get pinfo :size) 'face 'font-lock-builtin-face))
                                  (propertize (plist-get pinfo :mimetype) 'face 'font-lock-constant-face))
                          (plist-get pinfo :part))
                    labeledparts))
            labeledparts))))

  (map! :localleader
        :map mu4e-compose-mode-map
        :desc "send and exit" "s" #'message-send-and-exit
        :desc "kill buffer"   "d" #'message-kill-buffer
        :desc "save draft"    "S" #'message-dont-send
        :desc "attach"        "a" #'+mu4e/attach-files)

  ;; Due to evil, none of the marking commands work when making a visual
  ;; selection in the headers view of mu4e. Without overriding any evil commands
  ;; we may actually want to use in and evil selection, this can be easily
  ;; fixed.
  (map! :map mu4e-headers-mode-map
        :v "*" #'mu4e-headers-mark-for-something
        :v "!" #'mu4e-headers-mark-for-read
        :v "?" #'mu4e-headers-mark-for-unread
        :v "u" #'mu4e-headers-mark-for-unmark)

  (add-hook 'mu4e-compose-pre-hook #'+mu4e-set-from-address-h)

  ;; HACK
  (defadvice! +mu4e-ensure-compose-writeable-a (&rest _)
    "Ensure that compose buffers are writable.
This should already be the case yet it does not always seem to be."
    :before #'mu4e-compose-new
    :before #'mu4e-compose-reply
    :before #'mu4e-compose-forward
    :before #'mu4e-compose-resend
    (read-only-mode -1))

  ;; HACK: process lock control
  (when (featurep :system 'windows)
    (setq +mu4e-lock-file (expand-file-name "~/AppData/Local/Temp/mu4e_lock")
          +mu4e-lock-request-file (expand-file-name "~/AppData/Local/Temp/mu4e_lock_request")))

  (add-hook 'kill-emacs-hook #'+mu4e-lock-file-delete-maybe)
  (advice-add #'mu4e--start :around #'+mu4e-lock-start)
  (advice-add #'mu4e-quit :after #'+mu4e-lock-file-delete-maybe))


(use-package! org-msg
  :when (modulep! +org)
  :defer t
  :init
  ;; Avoid using `:after' because it ties the :config below to when `mu4e'
  ;; loads, rather than when `org-msg' loads.
  (after! mu4e (require 'org-msg))
  :config
  (setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil tex:dvipng"
        org-msg-startup "hidestars indent inlineimages"
        org-msg-greeting-name-limit 3
        org-msg-default-alternatives '((new . (utf-8 html))
                                       (reply-to-text . (utf-8))
                                       (reply-to-html . (utf-8 html)))
        org-msg-convert-citation t
        ;; The default attachment matcher gives too many false positives,
        ;; it's better to be more conservative. See https://regex101.com/r/EtaiSP/4.
        org-msg-attached-file-reference
        "see[ \t\n]\\(?:the[ \t\n]\\)?\\(?:\\w+[ \t\n]\\)\\{0,3\\}\\(?:attached\\|enclosed\\)\\|\
(\\(?:attached\\|enclosed\\))\\|\
\\(?:attached\\|enclosed\\)[ \t\n]\\(?:for\\|is\\)[ \t\n]")

  (map! :map org-msg-edit-mode-map
        "TAB" #'org-msg-tab   ; To mirror the binding on <tab>
        :desc "attach" "C-c C-a" #'+mu4e/attach-files
        :localleader
        :desc "attach" "a" #'+mu4e/attach-files)

  ;; HACK: ...
  (defvar +org-msg-currently-exporting nil
    "Non-nil if org-msg is currently exporting the org buffer to HTML.")
  (defadvice! +org-msg--now-exporting-a (fn &rest args)
    :around #'org-msg-org-to-xml
    (let ((+org-msg-currently-exporting t))
      (apply fn args)))

  ;; HACK: ...
  (advice-add #'org-html-latex-fragment    :override #'+org-html-latex-fragment-scaled-a)
  (advice-add #'org-html-latex-environment :override #'+org-html-latex-environment-scaled-a)

  ;; HACK: Ensure files are attached in the order they were attached.
  (defadvice! +org-msg-attach-attach-in-order-a (file &rest _args)
    "Link FILE into the list of attachment."
    :override #'org-msg-attach-attach
    (interactive (list (read-file-name "File to attach: ")))
    (let ((files (org-msg-get-prop "attachment")))
      (org-msg-set-prop "attachment" (nconc files (list file)))))

  ;; HACK: Toggle `org-msg' where sensible.
  (defvar +mu4e-compose-org-msg-toggle-next t)
  (defadvice! +mu4e-maybe-toggle-org-msg-a (&rest _)
    :before #'+mu4e/attach-files
    :before #'mu4e-compose-new
    :before #'mu4e-compose-reply
    :before #'mu4e-compose-forward
    :before #'mu4e-compose-resend
    (when (xor (/= 1 (prefix-numeric-value current-prefix-arg))
               +mu4e-compose-org-msg-toggle-next)
      (org-msg-mode (if org-msg-mode -1 1))
      (cl-callf not +mu4e-compose-org-msg-toggle-next)))

  ;; HACK: ...
  (defadvice! +mu4e-draft-open-signature-a (fn &rest args)
    "Prevent `mu4e-compose-signature' from being used with `org-msg-mode'."
    :around #'mu4e-draft-open
    (let ((mu4e-compose-signature (unless org-msg-mode mu4e-compose-signature)))
      (apply fn args)))

  (defvar +org-msg-accent-color "#c01c28"
    "Accent color to use in org-msg's generated CSS.
Must be set before org-msg is loaded to take effect.")
  (setq org-msg-enforce-css
        (let* ((font-family '(font-family . "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell,\
        \"Fira Sans\", \"Droid Sans\", \"Helvetica Neue\", Arial, sans-serif, \"Apple Color Emoji\", \"Segoe UI Emoji\", \"Segoe UI Symbol\";"))
               (monospace-font '(font-family . "SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace;"))
               (font-size '(font-size . "11pt"))
               (font `(,font-family ,font-size))
               (line-height '(line-height . "1.2"))
               (theme-color +org-msg-accent-color)
               (bold '(font-weight . "bold"))
               (color `(color . ,theme-color))
               (table `((margin-top . "6px") (margin-bottom . "6px")
                        (border-left . "none") (border-right . "none")
                        (border-top . "2px solid #222222")
                        (border-bottom . "2px solid #222222")))
               (ftl-number `(,color ,bold (text-align . "left")))
               (inline-modes '(asl c c++ conf cpp csv diff ditaa emacs-lisp
                               fundamental ini json makefile man org plantuml
                               python sh xml))
               (inline-src `((background-color . "rgba(27,31,35,.05)")
                             (border-radius . "3px")
                             (padding . ".2em .4em")
                             (font-size . "90%") ,monospace-font
                             (margin . 0)))
               (code-src
                (mapcar (lambda (mode)
                          `(code ,(intern (concat "src src-" (symbol-name mode)))
                                 ,inline-src))
                        inline-modes))
               (base-quote '((padding-left . "5px") (margin-left . "10px")
                             (margin-top . "20px") (margin-bottom . "0")
                             (font-style . "italic") (background . "#f9f9f9")))
               (quote-palette '("#6A8FBF" "#bf8f6a" "#6abf8a" "#906abf"
                                "#6aaebf" "#bf736a" "#bfb66a" "#bf6a94"
                                "#6abf9b" "#bf6a7d" "#acbf6a" "#6a74bf"))
               (quotes
                (mapcar (lambda (x)
                          (let ((c (nth x quote-palette)))
                            `(div ,(intern (format "quote%d" (1+ x)))
                                  (,@base-quote
                                   (color . ,c)
                                   (border-left . ,(concat "3px solid "
                                                           (org-msg-lighten c)))))))
                        (number-sequence 0 (1- (length quote-palette))))))
          `((del nil ((color . "grey") (border-left . "none")
                      (text-decoration . "line-through") (margin-bottom . "0px")
                      (margin-top . "10px") (line-height . "11pt")))
            (a nil (,color))
            (a reply-header ((color . "black") (text-decoration . "none")))
            (div reply-header ((padding . "3.0pt 0in 0in 0in")
                               (border-top . "solid #e1e1e1 1.0pt")
                               (margin-bottom . "20px")))
            (span underline ((text-decoration . "underline")))
            (li nil (,line-height (margin-bottom . "0px")
                                  (margin-top . "2px")
                                  (max-width . "47em")))
            (nil org-ul ((list-style-type . "disc")))
            (nil org-ol (,@font ,line-height (margin-bottom . "0px")
                                (margin-top . "0px") (margin-left . "30px")
                                (padding-top . "0px") (padding-left . "5px")))
            (nil signature (,@font (margin-bottom . "20px")))
            (blockquote nil ((padding . "2px 12px") (margin-left . "10px")
                             (margin-top . "10px") (margin-bottom . "0")
                             (border-left . "3px solid #ccc")
                             (font-style . "italic")
                             (background . "#f9f9f9")))
            (p blockquote  ((margin . "0") (padding . "4px 0")))
            ,@quotes
            (code nil (,font-size ,monospace-font (background . "#f9f9f9")))
            ,@code-src
            (nil linenr ((padding-right . "1em")
                         (color . "black")
                         (background-color . "#aaaaaa")))
            (pre nil ((line-height . "1.2")
                      (color . ,(face-foreground 'default))
                      (background-color . ,(face-background 'default))
                      (margin . "4px 0px 8px 0px")
                      (padding . "8px 12px")
                      (width . "max-content")
                      (min-width . "50em")
                      (border-radius . "5px")
                      (font-size . "0.9em")
                      (font-weight . "500")
                      ,monospace-font))
            (div org-src-container ((margin-top . "10px")))
            (nil figure-number ,ftl-number)
            (nil table-number)
            (caption nil ((text-align . "left")
                          (background . ,theme-color)
                          (color . "white")
                          ,bold))
            (nil t-above ((caption-side . "top")))
            (nil t-bottom ((caption-side . "bottom")))
            (nil listing-number ,ftl-number)
            (nil figure ,ftl-number)
            (nil org-src-name ,ftl-number)
            (img nil ((vertical-align . "middle")
                      (max-width . "100%")))
            (img latex-fragment-inline ((margin . "0 0.1em")))
            (table nil (,@table ,line-height (border-collapse . "collapse")))
            (th nil ((border . "none") (border-bottom . "1px solid #222222")
                     (background-color . "#EDEDED") (font-weight . "500")
                     (padding . "3px 10px")))
            (td nil (,@table (padding . "1px 10px")
                             (background-color . "#f9f9f9") (border . "none")))
            (td org-left ((text-align . "left")))
            (td org-right ((text-align . "right")))
            (td org-center ((text-align . "center")))
            (kbd nil ((border . "1px solid #d1d5da") (border-radius . "3px")
                      (box-shadow . "inset 0 -1px 0 #d1d5da")
                      (background-color . "#fafbfc") (color . "#444d56")
                      (font-size . "0.85em")
                      (padding . "1px 4px") (display . "inline-block")))
            (div outline-text-4 ((margin-left . "15px")))
            (div outline-4 ((margin-left . "10px")))
            (h4 nil ((margin-bottom . "0px") (font-size . "11pt")))
            (h3 nil ((margin-bottom . "0px")
                     ,color (font-size . "14pt")))
            (h2 nil ((margin-top . "20px") (margin-bottom . "20px")
                     ,color (font-size . "18pt")))
            (h1 nil ((margin-top . "20px") (margin-bottom . "0px")
                     ,color (font-size . "24pt")))
            (p nil ((text-decoration . "none") (line-height . "1.4")
                    (margin-top . "10px") (margin-bottom . "0px")
                    ,font-size (max-width . "50em")))
            (b nil ((font-weight . "500") (color . ,theme-color)))
            (div nil (,@font (line-height . "12pt")))))))


;;
;;; Gmail integration

(when (modulep! +gmail)
  (after! mu4e
    (defvar +mu4e-gmail-accounts nil
      "Gmail accounts that do not contain \"gmail\" in address and maildir.

An alist of Gmail addresses of the format \((\"username@domain.com\" . \"account-maildir\"))
to which Gmail integrations (behind the `+gmail' flag of the `mu4e' module) should be applied.

See `+mu4e-msg-gmail-p' and `mu4e-sent-messages-behavior'.")

    ;; don't save message to Sent Messages, Gmail/IMAP takes care of this
    (setq mu4e-sent-messages-behavior
          (lambda () ;; TODO: make use +mu4e-msg-gmail-p
            (if (or (string-match-p "@gmail.com\\'" (message-sendmail-envelope-from))
                    (member (message-sendmail-envelope-from)
                            (mapcar #'car +mu4e-gmail-accounts)))
                'delete 'sent)))

    (defun +mu4e-msg-gmail-p (msg)
      (let ((root-maildir
             (replace-regexp-in-string "/.*" ""
                                       (substring (mu4e-message-field msg :maildir) 1))))
        (or (string-match-p "gmail" root-maildir)
            (member root-maildir (mapcar #'cdr +mu4e-gmail-accounts)))))

    ;; In my workflow, emails won't be moved at all. Only their flags/labels are
    ;; changed. Se we redefine the trash and refile marks not to do any moving.
    ;; However, the real magic happens in `+mu4e-gmail-fix-flags-h'.
    ;;
    ;; Gmail will handle the rest.
    (defun +mu4e--mark-seen (docid _msg target)
      (mu4e--server-move docid (mu4e--mark-check-target target) "+S-u-N"))

    (defvar +mu4e--last-invalid-gmail-action 0)

    (setf (alist-get 'delete mu4e-marks)
          (list
           :char '("D" . "✘")
           :prompt "Delete"
           :show-target (lambda (_target) "delete")
           :action (lambda (docid msg target)
                     (if (+mu4e-msg-gmail-p msg)
                         (progn (message "The delete operation is invalid for Gmail accounts. Trashing instead.")
                                (+mu4e--mark-seen docid msg target)
                                (when (< 2 (- (float-time) +mu4e--last-invalid-gmail-action))
                                  (sit-for 1))
                                (setq +mu4e--last-invalid-gmail-action (float-time)))
                       (mu4e--server-remove docid))))
          (alist-get 'trash mu4e-marks)
          (list :char '("d" . "▼")
                :prompt "dtrash"
                :dyn-target (lambda (_target msg) (mu4e-get-trash-folder msg))
                :action (lambda (docid msg target)
                          (if (+mu4e-msg-gmail-p msg)
                              (+mu4e--mark-seen docid msg target)
                            (mu4e--server-move docid (mu4e--mark-check-target target) "+T-N"))))
          ;; Refile will be my "archive" function.
          (alist-get 'refile mu4e-marks)
          (list :char '("r" . "▼")
                :prompt "rrefile"
                :dyn-target (lambda (_target msg) (mu4e-get-refile-folder msg))
                :action (lambda (docid msg target)
                          (if (+mu4e-msg-gmail-p msg)
                              (+mu4e--mark-seen docid msg target)
                            (mu4e--server-move docid (mu4e--mark-check-target target) "-N")))
                #'+mu4e--mark-seen))

    ;; This hook correctly modifies gmail flags on emails when they are marked.
    ;; Without it, refiling (archiving), trashing, and flagging (starring) email
    ;; won't properly result in the corresponding gmail action, since the marks
    ;; are ineffectual otherwise.
    (add-hook! 'mu4e-mark-execute-pre-hook
      (defun +mu4e-gmail-fix-flags-h (mark msg)
        (when (+mu4e-msg-gmail-p msg)
          (pcase mark
            (`trash  (mu4e-action-retag-message msg "-\\Inbox,+\\Trash,-\\Draft"))
            (`delete (mu4e-action-retag-message msg "-\\Inbox,+\\Trash,-\\Draft"))
            (`refile (mu4e-action-retag-message msg "-\\Inbox"))
            (`flag   (mu4e-action-retag-message msg "+\\Starred"))
            (`unflag (mu4e-action-retag-message msg "-\\Starred"))))))))
