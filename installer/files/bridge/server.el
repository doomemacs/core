;;; server.el --- Windows-local server for the optional WSL client -*- lexical-binding: t; -*-

(require 'server)
(let* ((bridge-dir (file-name-directory (or load-file-name buffer-file-name)))
       (root (file-name-directory (directory-file-name bridge-dir))))
  (setq server-name "doom-windows"
        ;; The bundled client uses UTF-8 argv, independent of Windows ANSI CP.
        ;; This controls filename transport, not the encoding of file contents.
        file-name-coding-system 'utf-8
        server-use-tcp t
        server-host "127.0.0.1"
        server-auth-dir (expand-file-name "bridge-state/server/" root))
  (make-directory server-auth-dir t)
  (unless (server-running-p server-name)
    (server-start)))

;;; server.el ends here
