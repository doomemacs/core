;;; ui/minimap/config.el -*- lexical-binding: t; -*-

(use-package! demap
  :hook ((demap-minimap-window-set-hook . mode-line-invisible-mode)
         (demap-minimap-window-set-hook . doom-disable-line-numbers-h)))
