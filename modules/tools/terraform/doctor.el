;;; tools/terraform/doctor.el -*- lexical-binding: t; -*-

(unless (executable-find "terraform")
  (warn! "Couldn't find terraform."))

(when (modulep! +lsp)
  (unless (executable-find "terraform-docs")
    (warn! "Couldn't find terraform-docs")))
