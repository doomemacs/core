;;; tools/lookup/config.el -*- lexical-binding: t; -*-

;; "What am I looking at?" This module helps you answer this question.
;;
;;   + `+lookup/definition': a jump-to-definition that should 'just work'
;;   + `+lookup/implementations': find a symbol's implementations in the current
;;                                project
;;   + `+lookup/references': find a symbol's references in the current project
;;   + `+lookup/file': open the file referenced at point
;;   + `+lookup/online'; look up a symbol on online resources
;;   + `+lookup/in-docsets': look up in Dash docsets
;;
;; This module uses `xref', an experimental new library in Emacs. It may change
;; in the future. When xref can't be depended on it will fall back to
;; `dumb-jump' to find what you want.

(defvar +lookup-provider-url-alist
  (append '(("Doom issues"       "https://github.com/orgs/doomemacs/projects/2/views/30?filterQuery=%s")
            ("Doom discourse"    "https://discourse.doomemacs.org/search?q=%s")
            ("Google"            +lookup--online-backend-google "https://google.com/search?q=%s")
            ("Google images"     "https://www.google.com/images?q=%s")
            ("Google maps"       "https://maps.google.com/maps?q=%s")
            ("Kagi"              "https://kagi.com/search?q=%s")
            ("Project Gutenberg" "http://www.gutenberg.org/ebooks/search/?query=%s")
            ("DuckDuckGo"        +lookup--online-backend-duckduckgo "https://duckduckgo.com/?q=%s")
            ("DevDocs.io"        "https://devdocs.io/#q=%s")
            ("StackOverflow"     "https://stackoverflow.com/search?q=%s")
            ("StackExchange"     "https://stackexchange.com/search?q=%s")
            ("Github"            "https://github.com/search?ref=simplesearch&q=%s")
            ("Youtube"           "https://youtube.com/results?aq=f&oq=&search_query=%s")
            ("Wolfram alpha"     "https://wolframalpha.com/input/?i=%s")
            ("Wikipedia"         "https://wikipedia.org/search-redirect.php?language=en&go=Go&search=%s")
            ("MDN"               "https://developer.mozilla.org/en-US/search?q=%s")
            ("Internet archive"  "https://web.archive.org/web/*/%s")
            ("Sourcegraph"       "https://sourcegraph.com/search?q=context:global+%s&patternType=literal"))
          (when (modulep! +yandex)
            '(("Yandex"            "https://yandex.com/search/?text=%s")
              ("Yandex images"     "https://yandex.com/images/search?text=%s")
              ("Yandex maps"       "https://yandex.com/maps?text=%s")))
          (when (modulep! :lang racket)
            '(("Racket Manuals" "https://docs.racket-lang.org/search/index.html?q=%s")))
          (when (modulep! :lang rust)
            '(("Rust Docs" "https://doc.rust-lang.org/std/?search=%s"))))
  "An alist that maps online resources to either:

  1. A search url (needs on '%s' to substitute with an url encoded query),
  2. A non-interactive function that returns the search url in #1,
  3. An interactive command that does its own search for that provider.

Used by `+lookup/online'.")

(defvar +lookup-open-url-fn #'browse-url
  "Function to use to open search urls.")

(defvar +lookup-definition-functions
  '(+lookup-dictionary-definition-backend-fn
    +lookup-xref-definitions-backend-fn
    +lookup-dumb-jump-backend-fn
    +lookup-project-search-backend-fn
    +lookup-evil-goto-definition-backend-fn)
  "Functions for `+lookup/definition' to try, before resorting to `dumb-jump'.
Stops at the first function to return non-nil or change the current
window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-implementations-functions ()
  "Function for `+lookup/implementations' to try. Stops at the first function to
return non-nil or change the current window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-type-definition-functions ()
  "Functions for `+lookup/type-definition' to try. Stops at the first function to
return non-nil or change the current window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-references-functions
  '(+lookup-thesaurus-definition-backend-fn
    +lookup-xref-references-backend-fn
    +lookup-project-search-backend-fn)
  "Functions for `+lookup/references' to try, before resorting to `dumb-jump'.
Stops at the first function to return non-nil or change the current
window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-documentation-functions
  '(+lookup-online-backend-fn)
  "Functions for `+lookup/documentation' to try, before resorting to
`dumb-jump'. Stops at the first function to return non-nil or change the current
window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-file-functions
  '(+lookup-bug-reference-backend-fn
    +lookup-ffap-backend-fn)
  "Function for `+lookup/file' to try, before restoring to `find-file-at-point'.
Stops at the first function to return non-nil or change the current
window/point.

If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar +lookup-dictionary-prefer-offline (modulep! +offline)
  "If non-nil, look up dictionaries online.

Setting this to nil will force it to use offline backends, which may be less
than perfect, but available without an internet connection.

Used by `+lookup/dictionary-definition' and `+lookup/synonyms'.

For `+lookup/dictionary-definition', this is ignored on Mac, where Emacs users
Dictionary.app behind the scenes to get definitions.")


;;
;;; dumb-jump

(use-package! dumb-jump
  :commands dumb-jump-result-follow
  :config
  (setq dumb-jump-default-project doom-emacs-dir
        dumb-jump-prefer-searcher 'rg
        dumb-jump-aggressive nil
        dumb-jump-selector
        (cond ((modulep! :completion ivy)  'ivy)
              ((modulep! :completion helm) 'helm)
              ('popup)))
  (add-hook 'dumb-jump-after-jump-hook #'better-jumper-set-jump))


;;
;;; xref

;; The lookup commands are superior, and will consult xref if there are no
;; better backends available.
(global-set-key [remap xref-find-definitions] #'+lookup/definition)
(global-set-key [remap xref-find-references]  #'+lookup/references)

(after! xref
  ;; This integration is already built into evil
  (unless (modulep! :editor evil)
    ;; Use `better-jumper' instead of xref's marker stack
    (advice-add #'xref-push-marker-stack :around #'doom-set-jump-a))

  (use-package! ivy-xref
    :when (modulep! :completion ivy)
    :config
    (set-popup-rule! "^\\*xref\\*$" :ignore t)
    (setq xref-show-definitions-function #'ivy-xref-show-defs
          xref-show-xrefs-function       #'ivy-xref-show-xrefs)

    ;; HACK: Fix #4386: `ivy-xref-show-xrefs' calls `fetcher' twice, which has
    ;;   side effects that breaks in some cases (i.e. on
    ;;   `dired-do-find-regexp').
    (defadvice! +lookup--fix-ivy-xrefs (fn fetcher alist)
      :around #'ivy-xref-show-xrefs
      (when (functionp fetcher)
        (setf (alist-get 'fetched-xrefs alist)
              (funcall fetcher)))
      (funcall fn fetcher alist)))

  (use-package! helm-xref
    :when (modulep! :completion helm))

  (use-package! consult-xref
    :when (modulep! :completion vertico)
    :defer t
    :init
    (setq xref-show-xrefs-function       #'consult-xref
          xref-show-definitions-function #'consult-xref)))


;;
;;; Dash docset integration

(use-package! dash-docs
  :when (modulep! +docsets)
  :defer t
  :init
  (add-hook '+lookup-documentation-functions #'+lookup-dash-docsets-backend-fn)
  :config
  (setq dash-docs-enable-debugging init-file-debug
        dash-docs-docsets-path (file-name-concat doom-profile-data-dir "docsets/")
        dash-docs-min-length 2
        dash-docs-browser-func #'eww)

  (cond ((modulep! :completion helm)
         (require 'helm-dash nil t))
        ((modulep! :completion ivy)
         (require 'counsel-dash nil t))))


;;
;;; Dictionary integration

(use-package! define-word
  :when (modulep! +dictionary)
  :unless (featurep :system 'macos)
  :defer t
  :config
  (setq define-word-displayfn-alist
        (cl-loop for (service . _) in define-word-services
                 collect (cons service #'+eval-display-results-in-popup))))


;;;###package synosaurus
(setq synosaurus-choose-method 'default) ; use ivy/helm instead of ido
