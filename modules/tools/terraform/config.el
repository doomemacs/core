;;; tools/terraform/config.el -*- lexical-binding: t; -*-

(defcustom +terraform-runner
  (if (executable-find "terragrunt") "terragrunt" "terraform")
  "The default runner - terraform or terragrunt."
  :safe #'stringp
  :type 'string
  :group '+terraform)


;;
;;; Packages

(use-package! terraform-mode
  :mode "\\.tofu\\'"
  :config
  (set-docsets! 'terraform-mode "Terraform")
  (set-eglot-client! 'terraform-mode '("tofu-ls" "serve") '("terraform-ls" "serve"))

  (setq-hook! 'terraform-mode-hook compile-command +terraform-runner)

  (when (modulep! +lsp)
    (add-hook 'terraform-mode-local-vars-hook #'lsp! 'append))

  (map! :map terraform-mode-map
        :localleader
        :desc "apply"    "a" (cmd! (compile (format "%s apply" +terraform-runner) t))
        :desc "init"     "i" (cmd! (compile (format "%s init" +terraform-runner)))
        :desc "plan"     "p" (cmd! (compile (format "%s plan" +terraform-runner)))
        :desc "validate" "v" (cmd! (compile (format "%s validate" +terraform-runner)))
        :desc "fmt"      "f" (cmd! (compile (format "%s fmt" +terraform-runner)))
        :desc "destroy"  "d" (cmd! (compile (format "%s destroy" +terraform-runner)))))


(use-package! company-terraform
  :when (modulep! :completion company)
  :after terraform-mode
  :config
  (set-company-backend! 'terraform-mode 'company-terraform))

(use-package! terraform-docs
  :when (modulep! +docs)
  :defer t
  :after terraform-mode
  :config
  (map! :map terraform-mode-map
        :localleader
        :desc "docs" "d" #'terraform-docs
        (:prefix ("D" . "docs submenu")
         :desc "to buffer"        "D" #'terraform-docs-to-buffer
         :desc "to file"          "d" (cmd! (terraform-docs-to-file nil (read-file-name "Output file: ")))
         :desc "to file and open" "o" (cmd! (terraform-docs-to-file-and-open nil (read-file-name "Output file: "))))))
