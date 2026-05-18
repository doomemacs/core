;;; app/calendar/config.el -*- lexical-binding: t; -*-

(defvar +calendar-open-function #'+calendar/open-calendar
  "TODO")


;;
;; Packages

(use-package! calfw
  :commands calfw-open-calendar-buffer
  :config
  ;; better frame for calendar
  (setq calfw-face-item-separator-color nil
        calfw-render-line-breaker 'calfw-render-line-breaker-none
        calfw-fchar-junction ?╋
        calfw-fchar-vertical-line ?┃
        calfw-fchar-horizontal-line ?━
        calfw-fchar-left-junction ?┣
        calfw-fchar-right-junction ?┫
        calfw-fchar-top-junction ?┯
        calfw-fchar-top-left-corner ?┏
        calfw-fchar-top-right-corner ?┓)

  (set-popup-rule! "^\\*calfw-details" :quit t :ttl 0 :select t :size 0.4)

  (define-key calfw-calendar-mode-map "q" #'+calendar/quit)
  (when (modulep! :editor evil +everywhere)
    (set-evil-initial-state! '(calfw-calendar-mode calfw-details-mode) 'motion)
    (add-hook! '(calfw-calendar-mode-hook calfw-details-mode-hook) #'evil-normalize-keymaps)
    (map! (:map calfw-calendar-mode-map
           :m "q"   #'+calendar/quit
           :m "SPC" #'calfw-show-details-command
           :m "RET" #'calfw-show-details-command
           :m "TAB"     #'calfw-navi-prev-item-command
           :m [tab]     #'calfw-navi-prev-item-command
           :m [backtab] #'calfw-navi-next-item-command
           :m "$"   #'calfw-navi-goto-week-end-command
           :m "."   #'calfw-navi-goto-today-command
           :m "<"   #'calfw-navi-previous-month-command
           :m ">"   #'calfw-navi-next-month-command
           :m "C-h" #'calfw-navi-previous-month-command
           :m "C-l" #'calfw-navi-next-month-command
           :m "D"   #'calfw-change-view-day
           :m "M"   #'calfw-change-view-month
           :m "T"   #'calfw-change-view-two-weeks
           :m "W"   #'calfw-change-view-week
           :m "^"   #'calfw-navi-goto-week-begin-command
           :m "gr"  #'calfw-refresh-calendar-buffer
           :m "h"   #'calfw-navi-previous-day-command
           :m "H"   #'calfw-navi-goto-first-date-command
           :m "j"   #'calfw-navi-next-week-command
           :m "k"   #'calfw-navi-previous-week-command
           :m "l"   #'calfw-navi-next-day-command
           :m "L"   #'calfw-navi-goto-last-date-command
           :m "t"   #'calfw-navi-goto-today-command)
          (:map calfw-details-mode-map
           :m "SPC" #'calfw-details-kill-buffer-command
           :m "RET" #'calfw-details-kill-buffer-command
           :m "TAB"     #'calfw-details-navi-prev-item-command
           :m [tab]     #'calfw-details-navi-prev-item-command
           :m [backtab] #'calfw-details-navi-next-item-command
           :m "q"   #'calfw-details-kill-buffer-command
           :m "C-h" #'calfw-details-navi-prev-command
           :m "C-l" #'calfw-details-navi-next-command
           :m "C-k" #'calfw-details-navi-prev-item-command
           :m "C-j" #'calfw-details-navi-next-item-command)))

  (add-hook 'calfw-calendar-mode-hook #'doom-mark-buffer-as-real-h)
  (add-hook 'calfw-calendar-mode-hook #'mode-line-invisible-mode)
  (add-hook 'calfw-calendar-mode-hook #'doom-disable-line-numbers-h)

  (advice-add #'calfw-render-button :override #'+calendar-calfw-render-button-a))


(use-package! calfw-org
  :commands (calfw-org-open-calendar
             calfw-org-create-source
             calfw-org-create-file-source
             calfw-open-org-calendar-withkevin))


(use-package! calfw-cal
  :commands (calfw-cal-create-source))


(use-package! calfw-ical
  :commands (calfw-ical-create-source))


(use-package! org-gcal
  :defer t
  :init
  (defvar org-gcal-dir (file-name-concat doom-profile-cache-dir "org-gcal/"))
  (defvar org-gcal-token-file (concat org-gcal-dir "token.gpg")))
