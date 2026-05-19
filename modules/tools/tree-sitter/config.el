;;; tools/tree-sitter/config.el -*- lexical-binding: t; -*-

;;
;;; Packages

(use-package! treesit
  :when (treesit-available-p)
  :defer t
  :preface
  (setq treesit-enabled-modes t)

  ;; At 3 (the default), too many users think syntax highlighting is broken or
  ;; simply "looks off."
  (setq treesit-font-lock-level 4)

  ;; HACK: The *-ts-mode major modes are inconsistent about how they treat
  ;;   missing language grammars (some error out, some respect
  ;;   `treesit-auto-install-grammar', some fall back to `fundamental-mode').
  ;;   I'd like to address this poor UX using `major-mode-remap-alist' entries
  ;;   created by `set-tree-sitter!' (which will fall back to the non-treesit
  ;;   modes), but most *-ts-mode's clobber `auto-mode-alist' and/or
  ;;   `interpreter-mode-alist' each time the major mode is activated, so those
  ;;   must be undone too so they don't overwrite user config.
  ;; TODO: Handle this during the 'doom sync' process instead.
  (save-match-data
    (dolist (sym '(auto-mode-alist interpreter-mode-alist))
      (set
       sym (cl-loop for (src . fn) in (symbol-value sym)
                    unless (and (functionp fn)
                                (string-match "-ts-mode\\(?:-maybe\\)?$" (symbol-name fn)))
                    collect (cons src fn)))))

  ;; HACK: These *-ts-modes change `auto-mode-alist' and/or
  ;;   `interpreter-mode-alist' every time they are activated, running the risk
  ;;   of overwriting user (or Doom) config.
  ;; REVIEW: Should be addressed upstream.
  (dolist (mode '(csharp-ts-mode
                  python-ts-mode))
    (advice-add mode :around #'+tree-sitter-ts-mode-inhibit-side-effects-a))

  ;; HACK: Intercept all ts-mode major mode remappings so grammars can be
  ;;   dynamically checked and `treesit-auto-install-grammar' can be
  ;;   consistently respected (which isn't currently the case with the majority
  ;;   of ts-modes, even the built-in ones).
  (defadvice! +tree-sitter--maybe-remap-major-mode-a (fn mode)
    :around #'major-mode-remap
    (let ((mode (funcall fn mode)))
      (if-let* ((ts (get mode '+tree-sitter))
                (fallback-mode (car ts)))
          (cond ((not (treesit-available-p))
                 (message "Treesit unavailable, falling back to `%S'" fallback-mode)
                 fallback-mode)
                ((not (fboundp mode))
                 (message "Couldn't find `%S', falling back to `%S'" mode fallback-mode)
                 fallback-mode)
                ((and (or (eq treesit-enabled-modes t)
                          (memq fallback-mode treesit-enabled-modes))
                      ;; Lazily load autoloaded `treesit-language-source-alist'
                      ;; entries.
                      (let ((fn (symbol-function mode))
                            ;; Silence "can't find grammar" warning popups from
                            ;; `treesit-ready-p' calls in Emacs <=30.1. We'll
                            ;; log it to *Messages* instead.
                            (warning-suppress-types
                             (if doom-debug-mode
                                 warning-suppress-types
                               (cons '(treesit) warning-suppress-types))))
                        (or (not (autoloadp fn))
                            ;; ts-modes usually change these alists at autoload
                            ;; *and* load time.
                            (let (auto-mode-alist interpreter-mode-alist)
                              (autoload-do-load fn mode))))
                      ;; Only prompt once, and log other times.
                      (or (null (cdr ts))  ; no grammars, no problem!
                          ;; If the base/fallback mode doesn't exist, let's
                          ;; assume we want no fallthrough for this major mode
                          ;; and push forward anyway, even if a missing grammar
                          ;; results in a broken state.
                          (not (fboundp fallback-mode))
                          ;; Ensure grammars are present (and prompt to install
                          ;; them if needed).
                          (if-let* ((grammars
                                     (cl-remove-if (doom-rpartial #'treesit-ready-p 'message)
                                                   (cdr ts))))
                              (if (or (eq treesit-auto-install-grammar 'always)
                                      (if (eq treesit-auto-install-grammar 'ask)
                                          (y-or-n-p
                                           (format "Missing tree-sitter grammars: %s\nInstall now?"
                                                   (mapconcat #'symbol-name grammars ", ")))))
                                  (mapc #'treesit-install-language-grammar grammars)
                                (message "Treesit grammars missing (%s), falling back to `%s'..."
                                         (mapconcat #'symbol-name grammars ", ")
                                         fallback-mode)
                                nil)
                            t)))
                 (put mode '+tree-sitter-ensured t)
                 mode)
                (fallback-mode))
        mode)))

  :config
  ;; HACK: Keep $EMACSDIR clean by installing grammars to central location (the
  ;;   active profile).
  (let ((data-dir (file-name-concat doom-profile-data-dir "tree-sitter")))
    (add-to-list 'treesit-extra-load-path data-dir)
    ;; Treesit's API saw major changes in 30.x.
    (if (< emacs-major-version 30)
        (defadvice! +tree-sitter--install-grammar-to-local-dir-a (fn out-dir &rest args)
          :around #'treesit--install-language-grammar-1
          (apply fn (or out-dir data-dir) args))
      (defadvice! +tree-sitter--install-grammar-to-local-dir-a (fn lang &optional out-dir &rest args)
        :around #'treesit-install-language-grammar
        :around #'treesit--build-grammar
        (apply fn lang (or out-dir data-dir) args))))

  ;; TODO: Move most of these out to modules
  (dolist (map '((awk "https://github.com/Beaglefoot/tree-sitter-awk" nil nil nil nil)
                 (bibtex "https://github.com/latex-lsp/tree-sitter-bibtex" nil nil nil nil)
                 (blueprint "https://github.com/huanie/tree-sitter-blueprint" nil nil nil nil)
                 (commonlisp "https://github.com/tree-sitter-grammars/tree-sitter-commonlisp" nil nil nil nil)
                 (latex "https://github.com/latex-lsp/tree-sitter-latex" nil nil nil
                        ;; Pinned due to latex-lsp/tree-sitter-latex#172
                        "a6c812704b3d3e1541b0853aa0d6d561301320e1")
                 (make "https://github.com/tree-sitter-grammars/tree-sitter-make" nil nil nil nil)
                 (nu "https://github.com/nushell/tree-sitter-nu" nil nil nil nil)
                 (org "https://github.com/milisims/tree-sitter-org" nil nil nil nil)
                 (perl "https://github.com/ganezdragon/tree-sitter-perl" nil nil nil nil)
                 (proto "https://github.com/mitchellh/tree-sitter-proto" nil nil nil nil)
                 (r "https://github.com/r-lib/tree-sitter-r" nil nil nil nil)
                 (sql "https://github.com/DerekStride/tree-sitter-sql" "gh-pages" nil nil nil)
                 (surface "https://github.com/connorlay/tree-sitter-surface" nil nil nil nil)
                 (toml "https://github.com/tree-sitter/tree-sitter-toml" nil nil nil nil)
                 (typst "https://github.com/uben0/tree-sitter-typst" "master" "src" nil nil)
                 (verilog "https://github.com/gmlarumbe/tree-sitter-systemverilog" nil nil nil nil)
                 (vhdl "https://github.com/alemuller/tree-sitter-vhdl" nil nil nil nil)
                 (vue "https://github.com/tree-sitter-grammars/tree-sitter-vue" nil nil nil nil)
                 (wast "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wast/src" nil nil)
                 (wat "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wat/src" nil nil)
                 (wgsl "https://github.com/mehmetoguzderin/tree-sitter-wgsl" nil nil nil nil)))
    (cl-pushnew map treesit-language-source-alist :test #'eq :key #'car)))


;; TODO: combobulate or evil-textobj-tree-sitter


;; (use-package! combobulate
;;   :commands combobulate-query-builder
;;   :hook (prog-mode . combobulate-mode))


;; (use-package! evil-textobj-tree-sitter
;;   :when (modulep! :editor evil +everywhere)
;;   :defer t
;;   :init (after! tree-sitter (require 'evil-textobj-tree-sitter))
;;   :after-call doom-first-input-hook
;;   :config
;;   (defvar +tree-sitter-inner-text-objects-map (make-sparse-keymap))
;;   (defvar +tree-sitter-outer-text-objects-map (make-sparse-keymap))
;;   (defvar +tree-sitter-goto-previous-map (make-sparse-keymap))
;;   (defvar +tree-sitter-goto-next-map (make-sparse-keymap))

;;   (evil-define-key '(visual operator) 'tree-sitter-mode
;;     "i" +tree-sitter-inner-text-objects-map
;;     "a" +tree-sitter-outer-text-objects-map)
;;   (evil-define-key 'normal 'tree-sitter-mode
;;     "[g" +tree-sitter-goto-previous-map
;;     "]g" +tree-sitter-goto-next-map)

;;   (map! (:map +tree-sitter-inner-text-objects-map
;;          "A" (+tree-sitter-get-textobj '("parameter.inner" "call.inner"))
;;          "f" (+tree-sitter-get-textobj "function.inner")
;;          "F" (+tree-sitter-get-textobj "call.inner")
;;          "C" (+tree-sitter-get-textobj "class.inner")
;;          "v" (+tree-sitter-get-textobj "conditional.inner")
;;          "l" (+tree-sitter-get-textobj "loop.inner"))
;;         (:map +tree-sitter-outer-text-objects-map
;;          "A" (+tree-sitter-get-textobj '("parameter.outer" "call.outer"))
;;          "f" (+tree-sitter-get-textobj "function.outer")
;;          "F" (+tree-sitter-get-textobj "call.outer")
;;          "C" (+tree-sitter-get-textobj "class.outer")
;;          "c" (+tree-sitter-get-textobj "comment.outer")
;;          "v" (+tree-sitter-get-textobj "conditional.outer")
;;          "l" (+tree-sitter-get-textobj "loop.outer"))

;;         (:map +tree-sitter-goto-previous-map
;;          "a" (+tree-sitter-goto-textobj "parameter.outer" t)
;;          "f" (+tree-sitter-goto-textobj "function.outer" t)
;;          "F" (+tree-sitter-goto-textobj "call.outer" t)
;;          "C" (+tree-sitter-goto-textobj "class.outer" t)
;;          "c" (+tree-sitter-goto-textobj "comment.outer" t)
;;          "v" (+tree-sitter-goto-textobj "conditional.outer" t)
;;          "l" (+tree-sitter-goto-textobj "loop.outer" t))
;;         (:map +tree-sitter-goto-next-map
;;          "a" (+tree-sitter-goto-textobj "parameter.outer")
;;          "f" (+tree-sitter-goto-textobj "function.outer")
;;          "F" (+tree-sitter-goto-textobj "call.outer")
;;          "C" (+tree-sitter-goto-textobj "class.outer")
;;          "c" (+tree-sitter-goto-textobj "comment.outer")
;;          "v" (+tree-sitter-goto-textobj "conditional.outer")
;;          "l" (+tree-sitter-goto-textobj "loop.outer")))

;;   (after! which-key
;;     (setq which-key-allow-multiple-replacements t)
;;     (pushnew!
;;      which-key-replacement-alist
;;      '(("" . "\\`+?evil-textobj-tree-sitter-function--\\(.*\\)\\(?:.inner\\|.outer\\)") . (nil . "\\1")))))
