;; editor/evil/autoload/evil.el -*- lexical-binding: t; -*-

;; REVIEW: Remove once juliapath/evil-numbers#30 is addressed or
;;   juliapath/evil-numbers#31 is merged.
;;;###autoload
(or (fboundp 'incf) (defalias 'incf 'cl-incf))


;;;###autodef
(defun set-evil-initial-state! (modes state)
  "Set the initialize STATE of MODES using `evil-set-initial-state'."
  (declare (indent defun))
  (after! evil
    (if (listp modes)
        (dolist (mode (ensure-list modes))
          (evil-set-initial-state mode state))
      (evil-set-initial-state modes state))))


;;
;;; Interactive commands

;;;###autoload
(defun +evil/shift-right ()
  "vnoremap < <gv"
  (interactive)
  (call-interactively #'evil-shift-right)
  (evil-normal-state)
  (evil-visual-restore))

;;;###autoload
(defun +evil/shift-left ()
  "vnoremap > >gv"
  (interactive)
  (call-interactively #'evil-shift-left)
  (evil-normal-state)
  (evil-visual-restore))

;;;###autoload
(defun +evil/alt-paste ()
  "Call `evil-paste-after' but invert `evil-kill-on-visual-paste'.
By default, this replaces the selection with what's in the clipboard without
replacing its contents."
  (interactive)
  (let ((evil-kill-on-visual-paste (not evil-kill-on-visual-paste)))
    (call-interactively #'evil-paste-after)))

(defun +evil--window-swap (direction &optional invert-wrap?)
  "Move current window to the next window in DIRECTION.

If there are no windows there and there is only one window, split in that
direction and place this window there. If there are no windows and this isn't
the only window, uses evil-window-move-* (e.g. `evil-window-move-far-left').

If already at the edge of the frame and `+evil-want-move-window-to-wrap-around'
is non-nil, move the window to the other end of the frame. Inverts
`+evil-want-move-window-to-wrap-around' if INVERT-WRAP? is non-nil."
  (unless (memq direction '(left right up down))
    (user-error "Invalid direction: %s" direction))
  (when (window-dedicated-p)
    (user-error "Cannot swap a dedicated window"))
  (let* ((this-window (selected-window))
         (that-window (window-in-direction direction nil this-window))
         (that-buffer (window-buffer that-window)))
    (when (or (minibufferp that-buffer)
              (window-dedicated-p this-window))
      (setq that-buffer nil that-window nil))
    (if (not (or that-window (one-window-p t)))
        (if (and (window-at-side-p
                  this-window (pcase direction ('up 'top) ('down 'bottom) (_ direction)))
                 (not (cl-loop for dir in (if (memq direction '(left right))
                                              '(up down) '(left right))
                               if (window-in-direction dir nil this-window)
                               return t)))
            (if (funcall (if invert-wrap? #'not #'identity) +evil-want-move-window-to-wrap-around)
                (call-interactively
                 (pcase direction
                   ('left  #'evil-window-move-far-right)
                   ('right #'evil-window-move-far-left)
                   ('up    #'evil-window-move-very-bottom)
                   ('down  #'evil-window-move-very-top)))
              (user-error "Window is already at the edge"))
          (call-interactively
           (pcase direction
             ('left  #'evil-window-move-far-left)
             ('right #'evil-window-move-far-right)
             ('up    #'evil-window-move-very-top)
             ('down  #'evil-window-move-very-bottom))))
      (unless that-window
        (setq that-window (split-window this-window nil direction))
        (with-selected-window that-window
          (switch-to-buffer (doom-fallback-buffer)))
        (setq that-buffer (window-buffer that-window)))
      (window-swap-states this-window that-window)
      (select-window that-window))))

;;;###autoload
(defun +evil/window-move-left (&optional arg)
  "Swap windows to the left."
  (interactive "P")
  (+evil--window-swap 'left (or arg +evil-want-move-window-to-wrap-around)))
;;;###autoload
(defun +evil/window-move-right (&optional arg)
  "Swap windows to the right"
  (interactive "P")
  (+evil--window-swap 'right (or arg +evil-want-move-window-to-wrap-around)))
;;;###autoload
(defun +evil/window-move-up (&optional arg)
  "Swap windows upward."
  (interactive "P")
  (+evil--window-swap 'up (or arg +evil-want-move-window-to-wrap-around)))
;;;###autoload
(defun +evil/window-move-down (&optional arg)
  "Swap windows downward."
  (interactive "P")
  (+evil--window-swap 'down (or arg +evil-want-move-window-to-wrap-around)))

;;;###autoload
(defun +evil/window-split-and-follow ()
  "Split current window horizontally, then focus new window.
If `evil-split-window-below' is non-nil, the new window isn't focused."
  (interactive)
  (let ((evil-split-window-below (not evil-split-window-below)))
    (call-interactively #'evil-window-split)))

;;;###autoload
(defun +evil/window-vsplit-and-follow ()
  "Split current window vertically, then focus new window.
If `evil-vsplit-window-right' is non-nil, the new window isn't focused."
  (interactive)
  (let ((evil-vsplit-window-right (not evil-vsplit-window-right)))
    (call-interactively #'evil-window-vsplit)))

;;;###autoload (autoload '+evil:apply-macro "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil:apply-macro (beg end)
  "Apply macro to each line."
  :move-point nil
  (interactive "<r>")
  (let ((register (or evil-this-register (read-char)))
        macro)
    (cond ((or (and (eq register ?@) (eq evil-last-register ?:))
               (eq register ?:))
           (setq macro (lambda () (evil-ex-repeat nil))
                 evil-last-register ?:))
          ((eq register ?@)
           (unless evil-last-register
             (user-error "No previously executed keyboard macro."))
           (setq macro (evil-get-register evil-last-register t)))
          ((setq macro (evil-get-register register t)
                 evil-last-register register)))
    (unless macro
      (user-error "No macro recorded in %c register" register))
    (evil-change-state 'normal)
    (evil-with-single-undo
      (let ((lines (count-lines beg end)))
        (message "Applied macro in %c register %d times" register lines)
        (apply-macro-to-region-lines beg end macro)
        (message "Applied macro in %c register %d times...DONE" register lines)))))

;;;###autoload (autoload '+evil:retab "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil:retab (&optional beg end)
  "Wrapper around `doom/retab'."
  :motion nil :move-point nil :type line
  (interactive "<r>")
  (doom/retab nil beg end))

;;;###autoload (autoload '+evil:narrow-buffer "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil:narrow-buffer (beg end &optional bang)
  "Narrow the buffer to region between BEG and END.

Widens narrowed buffers first. If BANG, use indirect buffer clones instead."
  :move-point nil
  (interactive "<r><!>")
  (if (not bang)
      (if (buffer-narrowed-p)
          (widen)
        (narrow-to-region beg end))
    (when (buffer-narrowed-p)
      (doom/widen-indirectly-narrowed-buffer t))
    (doom/narrow-buffer-indirectly beg end)))

;;;###autoload (autoload '+evil:yank-unindented "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil:yank-unindented (beg end _type _register _yank-handler)
  "Saves the (reindented) characters in motion into the kill-ring."
  :move-point nil
  :repeat nil
  (interactive "<R><x><y>")
  (let ((indent (save-excursion (goto-char beg) (current-indentation)))
        (text (buffer-substring beg end)))
    (with-temp-buffer
      (insert text)
      (indent-rigidly (point-min) (point-max) (- indent))
      (evil-yank (point-min) (point-max)))))

;;;###autoload (autoload '+evil:change-whole-visual-line "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil:change-whole-visual-line (beg end register yank-handler)
  "Change whole visual line, respecting `visual-line-mode'.
Unlike `evil-change-whole-line', this operates on visual lines rather than
physical lines, preventing newline deletion in wrapped lines."
  :motion evil-line-or-visual-line
  (interactive "<r><x>")
  (let ((vbeg (save-excursion (goto-char beg) (beginning-of-visual-line) (point)))
        (vend (save-excursion (goto-char (max beg (1- end))) (end-of-visual-line) (point))))
    (cond
     ;; Full physical line(s) — use 'line type for proper open-line + indent
     ((and (= vbeg (save-excursion (goto-char vbeg) (line-beginning-position)))
           (>= vend (save-excursion (goto-char vend) (line-end-position))))
      (evil-change vbeg vend 'line register yank-handler))
     ;; Empty line — just enter insert mode
     ((<= vend vbeg)
      (evil-insert 1))
     ;; Visual line subset — use 'inclusive to preserve physical line structure
     (t
      (evil-change vbeg vend 'inclusive register yank-handler)))))


;;
;;; wgrep

;;;###autoload (autoload '+evil-delete "editor/evil/autoload/evil" nil t)
(evil-define-operator +evil-delete (beg end type register yank-handler)
  "A wrapper around `evil-delete' for `wgrep' buffers that will invoke
`wgrep-mark-deletion' on lines you try to delete."
  (interactive "<R><x><y>")
  (condition-case _ex
      (evil-delete beg end type register yank-handler)
    ('text-read-only
     (evil-apply-on-block
      (lambda (beg _)
        (goto-char beg)
        (call-interactively #'wgrep-mark-deletion))
      beg (1- end) nil))))
