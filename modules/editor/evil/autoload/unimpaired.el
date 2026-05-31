;;; editor/evil/autoload/unimpaired.el -*- lexical-binding: t; -*-

;; These are ported from vim-unimpaired https://github.com/tpope/vim-unimpaired
;; and bound in the :config default module (in +evil-bindings.el).

;;
;;; Next/Previous commands

;;;###autoload
(defun +evil/next-beginning-of-method (count)
  "Jump to the beginning of the COUNT-th method/function after point."
  (interactive "p")
  (beginning-of-defun (- count)))

;;;###autoload
(defun +evil/previous-beginning-of-method (count)
  "Jump to the beginning of the COUNT-th method/function before point."
  (interactive "p")
  (beginning-of-defun count))

;;;###autoload
(defalias #'+evil/next-end-of-method #'end-of-defun
  "Jump to the end of the COUNT-th method/function after point.")

;;;###autoload
(defun +evil/previous-end-of-method (count)
  "Jump to the end of the COUNT-th method/function before point."
  (interactive "p")
  (end-of-defun (- count)))

;;;###autoload
(defun +evil/next-preproc-directive (count)
  "Jump to the COUNT-th preprocessor directive after point.

By default, this only recognizes C preproc directives. To change this see
`+evil-preprocessor-regexp'."
  (interactive "p")
  ;; TODO: More generalized search, to support directives in other languages?
  (if (re-search-forward +evil-preprocessor-regexp nil t count)
      (goto-char (match-beginning 0))
    (user-error "No preprocessor directives %s point"
                (if (> count 0) "after" "before"))))

;;;###autoload
(defun +evil/previous-preproc-directive (count)
  "Jump to the COUNT-th preprocessor directive before point.

See `+evil/next-preproc-directive' for details."
  (interactive "p")
  (+evil/next-preproc-directive (- count)))

;;;###autoload
(defun +evil/next-comment (count)
  "Jump to the beginning of the COUNT-th commented region after point."
  (interactive "p")
  (let ((orig-pt (point)))
    (require 'newcomment)
    (dotimes (_ (abs count))
      (cond ((> count 0)
             (while (and (not (eobp)) (doom-point-in-comment-p))
               (forward-line 1))
             (unless (comment-search-forward (point-max) 'noerror)
               (goto-char orig-pt)
               (user-error "No comment after point")))
            (t
             (while (and (not (bobp)) (doom-point-in-comment-p))
               (forward-line -1))
             (unless (comment-search-backward nil 'noerror)
               (goto-char orig-pt)
               (user-error "No comment before point")))))))

;;;###autoload
(defun +evil/previous-comment (count)
  "Jump to the beginning of the COUNT-th commented region before point."
  (interactive "p")
  (+evil/next-comment (- count)))

;;; ] SPC / [ SPC
;;;###autoload
(defun +evil/insert-newline-below (count)
  "Insert COUNT blank line(s) below current line. Does not change modes."
  (interactive "p")
  (dotimes (_ count)
    (save-excursion (evil-insert-newline-below))))

;;;###autoload
(defun +evil/insert-newline-above (count)
  "Insert COUNT blank line(s) above current line. Does not change modes."
  (interactive "p")
  (dotimes (_ count)
    (save-excursion (evil-insert-newline-above))))

;;; ]t / [t
;;;###autoload
(defun +evil/next-frame (count)
  "Focus next frame."
  (interactive "p")
  (dotimes (_ (abs count))
    (let ((frame (if (> count 0) (next-frame) (previous-frame))))
      (if (eq frame (selected-frame))
          (user-error "No other frame")
        (select-frame-set-input-focus frame)))))

;;;###autoload
(defun +evil/previous-frame (count)
  "Focus previous frame."
  (interactive "p")
  (+evil/next-frame (- count)))

;;; ]f / [f
(defun +evil--next-file (n)
  (unless buffer-file-name
    (user-error "Must be called from a file-visiting buffer"))
  (let* ((directory (file-name-directory buffer-file-name))
         (filename (file-name-nondirectory buffer-file-name))
         (files (cl-remove-if-not #'file-regular-p (doom-glob (file-name-directory buffer-file-name) "[!.]*")))
         (index (cl-position filename files :test #'file-equal-p)))
    (when (null index)
      (user-error "Couldn't find this file in current directory"))
    (let ((index (+ index n)))
      (cond ((>= index (length files))
             (user-error "No files after this one"))
            ((< index 0)
             (user-error "No files before this one"))
            ((expand-file-name (nth index files) directory))))))

;;;###autoload
(defun +evil/next-file (count)
  "Open file following this one, alphabetically, in the same directory."
  (interactive "p")
  (find-file (+evil--next-file count)))

;;;###autoload
(defun +evil/previous-file (count)
  "Open file preceding this one, alphabetically, in the same directory."
  (interactive "p")
  (find-file (+evil--next-file (- count))))


;;
;;; Encoding/Decoding

;; NOTE: For [x / ]x see :lang web
;; - `+web:encode-html-entities'
;; - `+web:decode-html-entities'

(defun +evil--encode (beg end fn)
  (save-excursion
    (goto-char beg)
    (let* ((end (if (eq evil-this-type 'line) (1- end) end))
           (text (buffer-substring-no-properties beg end)))
      (delete-region beg end)
      (insert (funcall fn text)))))

(defun +evil--url-decode (text)
  "Percent-decode URL-encoded TEXT as UTF-8."
  (decode-coding-string (url-unhex-string text t) 'utf-8))

;;; [u / ]u
;;;###autoload (autoload '+evil:url-encode "editor/evil/autoload/unimpaired" nil t)
(evil-define-operator +evil:url-encode (_count &optional beg end)
  "URL-encode text selected by the operator."
  (interactive "<c><r>")
  (+evil--encode beg end #'url-encode-url))

;;;###autoload (autoload '+evil:url-decode "editor/evil/autoload/unimpaired" nil t)
(evil-define-operator +evil:url-decode (_count &optional beg end)
  "URL-decode text selected by the operator as UTF-8."
  (interactive "<c><r>")
  (+evil--encode beg end #'+evil--url-decode))

;;; [y / ]y
;;;###autoload (autoload '+evil:c-string-encode "editor/evil/autoload/unimpaired" nil t)
(evil-define-operator +evil:c-string-encode (_count &optional beg end)
  "TODO"
  (interactive "<c><r>")
  (+evil--encode
   beg end
   (lambda (text)
     (replace-regexp-in-string "[\"\\]" (lambda (ch) (concat "\\" ch)) text))))

;;;###autoload (autoload '+evil:c-string-decode "editor/evil/autoload/unimpaired" nil t)
(evil-define-operator +evil:c-string-decode (_count &optional beg end)
  "TODO"
  (interactive "<c><r>")
  (+evil--encode
   beg end
   (lambda (text)
     (replace-regexp-in-string "\\\\[\"\\]" (lambda (str) (substring str 1)) text))))


;;
;;; Standalone

;;; gp
;;;###autoload
(defun +evil/reselect-paste ()
  "Return to visual mode and reselect the last pasted region."
  (interactive)
  (cl-destructuring-bind (_ _ _ beg end &optional _)
      evil-last-paste
    (evil-visual-make-selection
     (save-excursion (goto-char beg) (point-marker))
     end)))
