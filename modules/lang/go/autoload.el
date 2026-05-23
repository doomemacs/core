;;; lang/go/autoload.el -*- lexical-binding: t; -*-

(defun +go--spawn (cmd)
  (save-selected-window
    (compile cmd)))

(defun +go--assert-buffer-visiting ()
  (unless buffer-file-name
    (user-error "Not in a file-visiting buffer")))


;;; go test ...

(defvar +go-test-last nil
  "The last test run.")

(defun +go--run-tests (args)
  (let ((cmd (concat "go test -test.v " args " " (getenv "GOFLAGS"))))
    (setq +go-test-last (concat "cd " default-directory ";" cmd))
    (+go--spawn cmd)))

;;;###autoload
(defun +go/test-rerun ()
  "Rerun last run test."
  (interactive)
  (if +go-test-last
      (+go--spawn +go-test-last)
    (+go/test-all)))

;;;###autoload
(defun +go/test-all ()
  "Run all tests for this project."
  (interactive)
  (+go--run-tests ""))

;;;###autoload
(defun +go/test-nested ()
  "Run all tests in current directory and below, recursively."
  (interactive)
  (+go--run-tests "./..."))

;;;###autoload
(defun +go/test-single ()
  "Run single test at point."
  (interactive)
  (+go--assert-buffer-visiting)
  (unless (string-match-p "_test\\.go$" buffer-file-name)
    (user-error "Must be in a *_test.go file"))
  (save-excursion
    (save-match-data
      (unless (re-search-backward "^func[ ]+\\(([[:alnum:]]*?[ ]?[*]?[[:alnum:]]+)[ ]+\\)?\\(Test[[:alnum:]_]+\\)(.*)" nil t)
        (user-error "No detectable test at or after point"))
      (+go--run-tests (concat "-run" "='^\\Q" (match-string-no-properties 2) "\\E$'")))))

;;;###autoload
(defun +go/test-file ()
  "Run all tests in current file."
  (interactive)
  (+go--assert-buffer-visiting)
  (unless (string-match-p "_test\\.go$" buffer-file-name)
    (user-error "Must be in a *_test.go file"))
  (save-excursion
    (save-match-data
      (goto-char (point-min))
      (let (func-list)
        (while (re-search-forward "^func[ ]+\\(([[:alnum:]]*?[ ]?[*]?[[:alnum:]]+)[ ]+\\)?\\(Test[[:alnum:]_]+\\)(.*)" nil t)
          (push (match-string-no-properties 2) func-list))
        (unless func-list
          (user-error "No detectable tests in this file"))
        (+go--run-tests (concat "-run" "='^(" (string-join func-list "|")  ")$'"))))))

;;;###autoload
(defun +go/bench-all ()
  "Run all benchmarks in project."
  (interactive)
  (+go--run-tests "-test.run=NONE -test.bench=\".*\""))

;;;###autoload
(defun +go/bench-single ()
  "Run benchmark at point."
  (interactive)
  (if (string-match "_test\\.go" buffer-file-name)
      (save-excursion
        (re-search-backward "^func[ ]+\\(([[:alnum:]]*?[ ]?[*]?[[:alnum:]]+)[ ]+\\)?\\(Benchmark[[:alnum:]_]+\\)(.*)")
        (+go--run-tests (concat "-test.run=NONE -test.bench" "='^\\Q" (match-string-no-properties 2) "\\E$'")))
    (error "Must be in a _test.go file")))


;;; go generate ...

(defun +go--generate (dir args)
  (unless (file-directory-p dir)
    (user-error "Directory does not exist: %s" dir))
  (+go--spawn
   (format "cd %s && go generate %s"
           (shell-quote-argument dir)
           args)))

;;;###autoload
(defun +go/generate-file ()
  "Run \\='go generate' for the current file."
  (interactive)
  (+go--assert-buffer-visiting)
  (+go--generate default-directory
                 (file-name-nondirectory buffer-file-name)))

;;;###autoload
(defun +go/generate-dir ()
  "Run \\='go generate' for the current directory, recursively."
  (interactive)
  (+go--generate default-directory "./..."))

;;;###autoload
(defun +go/generate-all (&optional arg)
  "Run \\='go generate' for the entire project.

Will prompt for the project if you're not in one or if the prefix ARG is
non-nil."
  (interactive "P")
  (if-let*
      ((proot
        (let ((projectile-require-project-root 'prompt))
          (projectile-ensure-project (unless arg (doom-project-root))))))
      (+go--generate (file-truename proot) "./...")
    (user-error "Not in a valid project")))


;;;###autoload
(defun +go/play-buffer-or-region (&optional beg end)
  "Evaluate active selection or buffer in the Go playground."
  (interactive "r")
  (if (use-region-p)
      (go-play-region beg end)
    (go-play-buffer)))
