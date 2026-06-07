;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; lang/org/doctor.el

(unless (executable-find "makeinfo")
  (warn! "Couldn't find makeinfo. Org Mode and Org Guide info manuals will not be available."))

(when (modulep! +gnuplot)
  (unless (executable-find "gnuplot")
    (warn! "Couldn't find gnuplot. org-plot/gnuplot will not work")))

(when (modulep! +roam2)
  (warn! "+roam2 is deprecated; use +roam instead (they install the same version)"))
(when (or (modulep! +roam)
          (modulep! +roam2))
  (unless (executable-find "dot")
    (warn! "Couldn't find the dot executable (from graphviz). org-roam will not be able to generate graph visualizations.")))

(when (modulep! +dragndrop)
  (when (featurep :system 'macos)
    (unless (executable-find "pngpaste")
      (warn! "Couldn't find the pngpaste executable. org-download-clipboard will not work.")))
  (when (featurep :system 'linux)
    (unless (or (executable-find "maim") (executable-find "scrot") (executable-find "gnome-screenshot"))
      (warn! "Couldn't find the maim, scrot or gnome-screenshot executable. org-download-clipboard will not work."))
    (if (string= "wayland" (getenv "XDG_SESSION_TYPE"))
        (unless (executable-find "wl-paste")
          (warn! "Couldn't find the wl-paste executable (from wl-clipboard). org-download-clipboard will not work."))
      (unless (executable-find "xclip")
        (warn! "Couldn't find the xclip executable. org-download-clipboard will not work."))))
  (when (featurep :system 'windows)
    (unless (executable-find "convert")
      (warn! "Couldn't find the convert program (from ImageMagick). org-download-clipboard will not work."))))
