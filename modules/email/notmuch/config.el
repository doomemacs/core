;;; email/notmuch/config.el -*- lexical-binding: t; -*-

(defcustom +notmuch-home-function #'notmuch
  "Function for customizing the landing page for doom-emacs =notmuch."
  :type 'function
  :group '+notmuch)

(defcustom +notmuch-sync-backend 'gmi
  "Which backend to use to synchrone email.

Accepts a symbol or a shell command string.

More specifically, this accepts one of the following symbols (see
`+notmuch-get-sync-command' definition for details):

  `gmi'         Use gmailieer (https://github.com/gauteh/lieer)
  `mbsync'      Use isync (https://isync.sourceforge.io)
  `offlineimap' Use offlineimap (https://www.offlineimap.org)

OR a shell command string such as

  \"path/to/some/shell-script.sh\"
  \"offlineimap && notmuch new && afew -n -t\"
  \"mbsync %s -a && notmuch new && afew -n -t\""
  :type '(choice (const :tag "gmailieer" gmi)
                 (const :tag "isync/mbsync" mbsync)
                 (const :tag "offlineimap" offlineimap)
                 (string :tag "An arbitrary shell command"))
  :group '+notmuch)

(defcustom +notmuch-mail-folder "~/.mail/account.gmail"
  "Where your email folder is located (for use with gmailieer)."
  :type 'directory
  :group '+notmuch)

(defcustom +notmuch-delete-tags '("+trash" "-inbox" "-unread")
  "Tags applied to mark email for deletion.

When replacing the +trash tag by a different tag such as +deleted, you will need
to update the notmuch-saved-searches variable accordingly."
  :type '(repeat string)
  :group '+notmuch)

(defcustom +notmuch-spam-tags '("+spam" "-inbox" "-unread")
  "Tags applied to mark email as spam."
  :type '(repeat string)
  :group '+notmuch)


;;
;;; Packages

(use-package! notmuch
  :defer t
  :config
  (set-company-backend! 'notmuch-message-mode
    'notmuch-company '(company-ispell company-yasnippet))

  (set-popup-rule! "^\\*notmuch" :ignore t)
  (set-popup-rule! "^\\*notmuch-hello" :side 'left :size 30 :ttl 0)
  (set-popup-rule! "^\\*subject:" :size 0.6 :ttl 0)

  (defadvice! +notmuch-search-show-thread-a (fn &rest args)
    "Give email buffers a sane name so they can be targeted via
`display-buffer-alist' (and the :ui popup module)."
    :around #'notmuch-search-show-thread
    (letf! (defun notmuch-show (thread-id &optional elide-toggle parent-buffer query-context buffer-name)
             (funcall notmuch-show
                      thread-id elide-toggle parent-buffer query-context
                      (format "*subject:%s*" (substring buffer-name 1 -1))))
      (apply fn args)))

  (setq notmuch-fcc-dirs nil
        message-kill-buffer-on-exit t
        message-send-mail-function 'message-send-mail-with-sendmail
        send-mail-function 'sendmail-send-it
        ;; sendmail-program "/usr/local/bin/msmtp"
        notmuch-search-result-format
        '(("date" . "%12s ")
          ("count" . "%-7s ")
          ("authors" . "%-30s ")
          ("subject" . "%-72s ")
          ("tags" . "(%s)"))
        notmuch-tag-formats
        '(("unread" (propertize tag 'face 'notmuch-tag-unread)))
        notmuch-saved-searches
        '((:name "inbox"   :query "tag:inbox not tag:trash" :key "i")
          (:name "flagged" :query "tag:flagged"             :key "f")
          (:name "sent"    :query "tag:sent"                :key "s")
          (:name "drafts"  :query "tag:draft"               :key "d"))
        notmuch-archive-tags '("-inbox" "-unread"))
  (setq-default notmuch-search-oldest-first nil)

  ;; only unfold unread messages in thread by default
  (add-hook 'notmuch-show-hook #'+notmuch-show-expand-only-unread-h)

  (add-hook 'doom-real-buffer-functions #'notmuch-interesting-buffer)

  (defadvice! +notmuch-dont-confirm-on-kill-process-a (fn &rest args)
    "Don't prompt for confirmation when killing notmuch sentinel."
    :around #'notmuch-start-notmuch-sentinel
    (let (confirm-kill-processes)
      (apply fn args)))

  ;; modeline doesn't have much use in these modes
  (add-hook! '(notmuch-show-mode-hook
               notmuch-tree-mode-hook
               notmuch-search-mode-hook)
             #'mode-line-invisible-mode
             #'doom-disable-line-numbers-h)

  (map! :localleader
        :map (notmuch-hello-mode-map notmuch-search-mode-map notmuch-tree-mode-map notmuch-show-mode-map)
        :desc "Compose email"   "c" #'+notmuch/compose
        :desc "Sync email"      "u" #'+notmuch/update
        :desc "Quit notmuch"    "q" #'+notmuch/quit
        :map notmuch-search-mode-map
        :desc "Mark as deleted" "d" #'+notmuch/search-delete
        :desc "Mark as spam"    "s" #'+notmuch/search-spam
        :map notmuch-tree-mode-map
        :desc "Mark as deleted" "d" #'+notmuch/tree-delete
        :desc "Mark as spam"    "s" #'+notmuch/tree-spam))


(use-package! org-mime
  :when (modulep! +org)
  :after (org notmuch)
  :config (setq org-mime-library 'mml))


(use-package! counsel-notmuch
  :when (modulep! :completion ivy)
  :commands counsel-notmuch
  :after notmuch)


(use-package! helm-notmuch
  :when (modulep! :completion helm)
  :commands helm-notmuch
  :after notmuch)


(use-package! consult-notmuch
  :when (modulep! :completion vertico)
  :commands consult-notmuch
  :after notmuch)
