;;; ui/neotree/autoload.el -*- lexical-binding: t; -*-

;; `neotree-show' and `neotree-find' don't respect the current project, and open
;; neotree in `default-directory'. `+neotree/open' and `neotree/find-this-file'
;; will ensure the neotree pane is always rooted in the project root.

;;;###autoload
(defun +neotree/open ()
  "Open the neotree window in the current project."
  (interactive)
  (require 'neotree)
  (if (neo-global--window-exists-p)
      (neotree-hide)
    (neotree-dir (or (doom-project-root)
                     default-directory))))

;;;###autoload
(defun +neotree/find-this-file ()
  "Open the neotree window in the current project, and find the current file."
  (interactive)
  (let ((path buffer-file-name)
        (project-root (or (doom-project-root)
                          default-directory)))
    (require 'neotree)
    (cond ((and (neo-global--window-exists-p)
                (get-buffer-window neo-buffer-name t))
           (neotree-find path project-root)
           (neotree-refresh))
          ((not (and (neo-global--window-exists-p)
                     (equal (file-truename (neo-global--with-buffer neo-buffer--start-node))
                            (file-truename project-root))))
           (neotree-dir project-root)
           (neotree-find path project-root))
          (t
           (neotree-find path project-root)))))

;;;###autoload
(defun +neotree/collapse-or-up ()
  "Collapse an expanded directory node or go to the parent node."
  (interactive)
  (when-let* ((node (neo-buffer--get-filename-current-line)))
    (if (and (file-directory-p node)
             (neo-buffer--expanded-node-p node))
        (+neotree/collapse)
      (neotree-select-up-node))))

;;;###autoload
(defun +neotree/collapse ()
  "Collapse a neotree node."
  (interactive)
  (when-let* ((node (neo-buffer--get-filename-current-line)))
    (when (file-directory-p node)
      (neo-buffer--set-expand node nil)
      (neo-buffer--refresh t))
    (when neo-auto-indent-point
      (neo-point-auto-indent))))

;;;###autoload
(defun +neotree/expand-or-open ()
  "Expand or open a neotree node."
  (interactive)
  (when-let* ((node (neo-buffer--get-filename-current-line)))
    (cond ((file-directory-p node)
           (neo-buffer--set-expand node t)
           (neo-buffer--refresh t)
           (when neo-auto-indent-point
             (forward-line)
             (neo-point-auto-indent)))
          (t
           (call-interactively #'neotree-enter)))))

;;;###autoload
(defun +neotree/refresh ()
  "Refresh neotree to show the current file's project if
  neotree is open, the current buffer belongs to a file,
  that file belongs to a project, and neotree is not
  already showing that project."
 (interactive)
 (let* ((cur-buffer      (current-buffer))
        (cur-buffer-file (buffer-file-name cur-buffer)))
   ;; We refresh neotree only when all of the following conditions are met.
   ;; 1. The current buffer belongs to a file. This condition avoids updates
   ;;    when switching to buffers such as *doom* or *scratch*.
   ;; 2. Neotree is open.
   ;; 3. The current buffer is in a project that neotree can show.
   ;; 4. Neotree is not already showing that buffer's project.
   (when (and cur-buffer-file
              (neo-global--window-exists-p)
              (projectile-project-root)
              (not (neo-global--file-in-root-p cur-buffer-file)))
     ;; Refresh neotree by:
     ;; 1. Explicitly changing the directory to the current project root because
     ;;    neotree sometimes picks the wrong root (e.g., chooses a subdirectory).
     (neotree-dir (doom-project-root))
     ;; 2. Opening our current file in neotree. This is the actual refresh.
     (+neotree/find-this-file)
     ;; 3. Focusing the current buffer because +neotree/find-this-file switches
     ;;    focus to the neotree window.
     (select-window (get-buffer-window cur-buffer)))))
