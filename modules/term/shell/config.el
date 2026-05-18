;;; term/shell/config.el -*- lexical-binding: t; -*-

;;;###package shell
(add-hook 'shell-mode-hook #'mode-line-invisible-mode)
(add-hook 'shell-mode-hook #'doom-disable-line-numbers-h)
