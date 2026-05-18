;;; term/term/config.el -*- lexical-binding: t; -*-

;;;###package term
(add-hook 'term-mode-hook #'mode-line-invisible-mode)
(add-hook 'term-mode-hook #'doom-disable-line-numbers-h)


;;;###package multi-term
(setq multi-term-dedicated-window-height 20
      multi-term-switch-after-close 'PREVIOUS
      multi-term-buffer-name "doom:terminal")

;; Remove hscroll-margin in shells, otherwise you get jumpiness when the cursor
;; comes close to the left/right edges of the window.
(setq-hook! 'term-mode-hook hscroll-margin 0)

;; HACK: Prior output in (ansi-)term shells should be read-only. Otherwise, it's
;;   trivial to make edits in visual modes (like evil's or term's
;;   term-line-mode) and leave the buffer in a half-broken state (which you must
;;   flush out with a couple RETs, which may execute the broken text in the
;;   buffer), Note that this does not protect the prompt in (ansi-)term buffers
;;   unless you set `term-prompt-regexp' buffer-locally! (e.g. with
;;   `setq-hook!').
(defadvice! +term--protect-process-output-in-visual-modes-a (&rest _)
  :before #'term-line-mode
  (when (term-in-char-mode)
    (let* ((prompt?)
           (prompt-end
            (save-excursion
              (goto-char (process-mark (get-buffer-process (current-buffer))))
              (or (and (not (equal term-prompt-regexp "^"))
                       (setq prompt? (re-search-backward term-prompt-regexp (line-beginning-position) t))
                       (match-end 0))
                  (line-beginning-position)))))
      (with-silent-modifications
        (when prompt?
          (put-text-property (1- prompt-end) prompt-end 'read-only 'fence))
        (add-text-properties (point-min) prompt-end '(read-only t))))))
