;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; lang/ess/doctor.el

(assert! (or (not (modulep! +lsp))
             (modulep! :tools lsp))
         "This module requires (:tools lsp)")
