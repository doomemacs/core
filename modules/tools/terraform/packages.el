;; -*- no-byte-compile: t; -*-
;;; tools/terraform/packages.el

(package! terraform-mode :pin "01635df3625c0cec2bb4613a6f920b8569d41009")
(when (modulep! :completion company)
  (package! company-terraform :pin "8d5a16d1bbeeb18ca49a8fd57b5d8cd30c8b8dc7"))

(when (modulep! +docs)
  (package! terraform-docs
    :recipe (:host github :repo "loispostula/terraform-docs.el" :branch "main")
    :pin "94a78999ec03e66ce49f7343cc8705354e195c3a"))
