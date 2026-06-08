;; -*- no-byte-compile: t; -*-
;;; config/default/test/test-evil-bindings.el

(require 'buttercup)
(require 'evil)
(require 'comint)

(describe "config/default/+evil-bindings"
  (describe "comint C-p/C-n dispatch"
    (before-each
      (with-current-buffer (get-buffer-create "*test-comint*")
        (comint-mode)
        (evil-local-mode +1)
        (evil-normal-state)))

    (after-each
      (when (get-buffer "*test-comint*")
        (kill-buffer "*test-comint*")))

    (it "dispatches C-p to comint-previous-input after non-paste commands"
      (with-current-buffer "*test-comint*"
        (let ((last-command 'evil-next-line))
          (expect (memq last-command
                        '(evil-paste-after evil-paste-before
                          evil-paste-pop evil-paste-pop-next))
                  :to-be nil))))

    (it "dispatches C-p to evil-paste-pop after evil-paste-after"
      (with-current-buffer "*test-comint*"
        (let ((last-command 'evil-paste-after))
          (expect (memq last-command
                        '(evil-paste-after evil-paste-before
                          evil-paste-pop evil-paste-pop-next))
                  :to-be-truthy))))

    (it "dispatches C-p to evil-paste-pop after evil-paste-before"
      (with-current-buffer "*test-comint*"
        (let ((last-command 'evil-paste-before))
          (expect (memq last-command
                        '(evil-paste-after evil-paste-before
                          evil-paste-pop evil-paste-pop-next))
                  :to-be-truthy))))

    (it "dispatches C-p to evil-paste-pop after evil-paste-pop"
      (with-current-buffer "*test-comint*"
        (let ((last-command 'evil-paste-pop))
          (expect (memq last-command
                        '(evil-paste-after evil-paste-before
                          evil-paste-pop evil-paste-pop-next))
                  :to-be-truthy))))

    (it "binds C-p in normal state to a conditional dispatch (not raw comint-previous-input)"
      (with-current-buffer "*test-comint*"
        (evil-normal-state)
        (let ((binding (key-binding (kbd "C-p"))))
          (expect binding :not :to-equal 'comint-previous-input)
          (expect binding :not :to-equal 'evil-paste-pop))))))
