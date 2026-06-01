;;; lang/python/doctor.el -*- lexical-binding: t; -*-

(assert! (or (not (modulep! +lsp))
             (modulep! :tools lsp))
         "This module requires (:tools lsp)")

(assert! (or (not (modulep! +tree-sitter))
             (modulep! :tools tree-sitter))
         "This module requires (:tools tree-sitter)")

(assert! (or (not (modulep! +tree-sitter))
             (fboundp 'python-ts-mode))
         "Can't find `python-ts-mode'; Emacs 29.1+ is required")

(assert! (not (and (modulep! +pyenv) (modulep! +uv)))
         "The +pyenv and +uv flags cannot be used together")

(unless (or (executable-find "python")
            (executable-find "python3"))
  (error! "Couldn't find python in your PATH"))

(when (modulep! +pyenv)
  (if (not (executable-find "pyenv"))
      (warn! "Couldn't find pyenv in your PATH")
    (unless (split-string (shell-command-to-string "pyenv versions --bare") "\n" t)
      (warn! "No versions of python are available via pyenv, did you forget to install one?"))))

(when (modulep! +uv)
  (unless (executable-find "uv")
    (warn! "Couldn't find uv in your PATH")))

(when (modulep! +conda)
  (unless (executable-find "conda")
    (warn! "Couldn't find conda in your PATH")))

(when (modulep! +poetry)
  (if (not (executable-find "poetry"))
      (warn! "Couldn't find poetry in your PATH")))

(when (modulep! +cython)
  (unless (executable-find "cython")
    (warn! "Couldn't find cython. cython-mode will not work.")))

(unless (executable-find "pytest")
  (warn! "Couldn't find pytest. Running tests through pytest will not work."))

(unless (executable-find "nosetests")
  (warn! "Couldn't find nosetests. Running tests through nose will not work."))

(unless (executable-find "pipenv")
  (warn! "Couldn't find pipenv. pipenv support will not work."))

(unless (executable-find "isort")
  (warn! "Couldn't find isort. Import sorting will not work."))

(when (modulep! :editor format)
  (unless (executable-find "pyflakes")
    (warn! "Couldn't find pyflakes. Import management will not work."))
  (unless (executable-find "black")
    (warn! "Couldn't find black. Code formatting will not work.")))
