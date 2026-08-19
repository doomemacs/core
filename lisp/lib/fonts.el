;;; lisp/lib/fonts.el -*- lexical-binding: t; -*-

;;;###autoload
(defvar doom-font-increment 2
  "How many steps to increase the font size each time `doom/increase-font-size'
or `doom/decrease-font-size' are invoked.")

;;;###autoload
(defvar doom-big-font nil
  "The font to use for `doom-big-font-mode'.
If nil, `doom-font' will be used, scaled up by `doom-big-font-increment'. See
`doom-font' for details on acceptable values for this variable.")

;;;###autoload
(defvar doom-big-font-increment 4
  "How many steps to increase the font size (with `doom-font' as the base) when
`doom-big-font-mode' is enabled and `doom-big-font' is nil.")


;;
;;; * Library

;;;###autoload
(defun doom-normalize-font (font)
  "Return FONT as a normalized font spec.

The font will be normalized (i.e. :weight, :slant, and :width will set to
\\='normal if not specified) before it is converted.

FONT can be a `font-spec', a font object, an XFT font string, or an XLFD font
string."
  (when (and (stringp font)
             (string-prefix-p "-" font))
    (setq font (x-decompose-font-name font)))
  (let* ((font
          (cond ((stringp font)
                 (dolist (prop '("weight" "slant" "width") (aref (font-info font) 0))
                   (unless (string-match-p (format ":%s=" prop) font)
                     (setq font (concat font ":" prop "=normal")))))
                ((fontp font)
                 (dolist (prop '(:weight :slant :width) (font-xlfd-name font))
                   (unless (font-get font prop)
                     (font-put font prop 'normal))))
                ((vectorp font)
                 (dolist (i '(1 2 3) (x-compose-font-name font))
                   (unless (aref font i)
                     (aset font i "normal"))))
                ((signal 'wrong-type-of-argument (list '(font string vectorp) font)))))
         (font (x-resolve-font-name font))
         (font (font-spec :name font)))
    (unless (font-get font :size)
      (font-put font :size
                (font-get (font-spec :name (face-font 'default))
                          :size)))
    font))

;;;###autoload
(defun doom-adjust-font-size (increment &optional fixed-size-p font-alist)
  "Increase size of font in FRAME by INCREMENT.

If FIXED-SIZE-P is non-nil, treat INCREMENT as a font size, rather than a
scaling factor.

FONT-ALIST is an alist give temporary values to certain Doom font variables,
like `doom-font' or `doom-variable-pitch-font'. e.g.

  `((doom-font . ,(font-spec :family \"Sans Serif\" :size 12)))

Doesn't work in terminal Emacs."
  (unless (display-multi-font-p)
    (user-error "Cannot resize fonts in terminal Emacs"))
  (condition-case-unless-debug e
      (let (changed)
        (dolist (sym '((doom-font . default)
                       (doom-serif-font . fixed-pitch-serif)
                       (doom-variable-pitch-font . variable-pitch))
                     (when changed
                       (doom-init-fonts-h 'reload)
                       t))
          (cl-destructuring-bind (var . face) sym
            (if (null increment)
                (when (get var 'initial-value)
                  (set var (get var 'initial-value))
                  (put var 'initial-value nil)
                  (setq changed t))
              (let* ((original-font (or (symbol-value var)
                                        (face-font face t)
                                        (with-temp-buffer (face-font face))))
                     (font (doom-normalize-font original-font))
                     (dfont
                      (or (if-let* ((remap-font (alist-get var font-alist))
                                    (remap-xlfd (doom-normalize-font remap-font)))
                              remap-xlfd
                            (purecopy font))
                          (error "Could not decompose %s font" var))))
                (let* ((step      (if fixed-size-p 0 increment))
                       (orig-size (font-get font :size))
                       (new-size  (if fixed-size-p increment (+ orig-size step))))
                  (cond ((<= new-size 0)
                         (error "`%s' font is too small to be resized (%d)" var new-size))
                        ((= orig-size new-size)
                         (user-error "Could not resize `%s' for some reason" var))
                        ((setq changed t)
                         (unless (get var 'initial-value)
                           (put var 'initial-value original-font))
                         (font-put dfont :size new-size)
                         (set var dfont)))))))))
    (error
     (ignore-errors (doom-adjust-font-size nil))
     (signal (car e) (cdr e)))))

;;;###autoload
(defun doom-font-exists-p (font)
  "Return non-nil if FONT exists on this system."
  (declare (pure t) (side-effect-free t))
  (ignore-errors (find-font (doom-normalize-font font))))


;;
;;; * Commands

;;;###autoload
(defun doom/reload-font ()
  "Reload your fonts, if they're set.
See `doom-init-fonts-h'."
  (interactive)
  (doom-init-fonts-h 'reload))

;;;###autoload
(defun doom/increase-font-size (count &optional increment)
  "Enlargens the font size across the current and child frames."
  (interactive "p")
  (doom-adjust-font-size (* count (or increment doom-font-increment))))

;;;###autoload
(defun doom/decrease-font-size (count &optional increment)
  "Shrinks the font size across the current and child frames."
  (interactive "p")
  (doom-adjust-font-size (* (- count) (or increment doom-font-increment))))

;;;###autoload
(defun doom/reset-font-size ()
  "Reset font size and `text-scale'.

Assuming it has been adjusted via `doom/increase-font-size' and
`doom/decrease-font-size', or `text-scale-*' commands."
  (interactive)
  (let (success)
    (when (and (boundp 'text-scale-mode-amount)
               (/= text-scale-mode-amount 0))
      (text-scale-set 0)
      (setq success t))
    (cond (doom-big-font-mode
           (message "Disabling `doom-big-font-mode'")
           (doom-big-font-mode -1)
           (setq success t))
          ((doom-adjust-font-size nil)
           (setq success t)))
    (unless success
      (user-error "The font hasn't been resized"))))

;;;###autoload
(define-minor-mode doom-big-font-mode
  "Globally resizes your fonts for streams, screen-sharing or presentations.

Uses `doom-big-font' if its set, otherwise uses `doom-font' (falling back to
your system font).

Also resizees `doom-variable-pitch-font' and `doom-serif-font'."
  :init-value nil
  :lighter " BIG"
  :global t
  :group 'doom
  (if doom-big-font
      ;; Use `doom-big-font' in lieu of `doom-font'
      (doom-adjust-font-size
       (when doom-big-font-mode
         (font-get (doom-normalize-font doom-big-font) :size))
       t `((doom-font . ,doom-big-font)))
    ;; Resize the current font
    (doom-adjust-font-size nil)
    (when doom-big-font-mode
      (doom-adjust-font-size doom-big-font-increment))))

(provide 'doom-lib '(fonts))
;;; fonts.el ends here
