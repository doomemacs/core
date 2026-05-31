;;; input/layout/+azerty.el -*- lexical-binding: t; -*-

;; NOTE: here is roughly what the translations are:
;; previous:  [ -> é
;; next:  ] -> è
;; ` -> ²
;; @ -> à

(defun +layout-remap-keys-for-azerty-h ()
  (setq avy-keys '(?q ?s ?d ?f ?g ?h ?j ?k ?l ?m)
        lispy-avy-keys '(?q ?s ?d ?f ?g ?h ?j ?k ?l ?m ?ù ?a ?z ?e ?r ?t ?y ?u ?i ?o ?p))
  (after! ace-window
    (setq aw-keys '(?q ?s ?d ?f ?g ?h ?j ?k ?l ?m)))
  (map! "C-z" 'evil-window-map)
  (map!
   :leader
   :desc "Window" "z" 'evil-window-map
   (:when (modulep! :ui popup)
    :desc "Toggle last popup"   "é" #'+popup/toggle)
   :desc "Switch to last buffer" "²" #'evil-switch-to-windows-last-buffer
   (:when (modulep! :ui workspaces)
    (:prefix-map ("TAB" . "workspace")
     :desc "Switch to last workspace" "²" #'+workspace/other
     :desc "Previous workspace" "é" #'+workspace/switch-left
     :desc "Next workspace" "è" #'+workspace/switch-right))
   (:prefix-map ("b" . "buffer")
    :desc "Previous buffer" "é" #'previous-buffer
    :desc "Next buffer" "è" #'next-buffer)
   (:prefix-map ("g" . "git")
    (:when (modulep! :ui vc-gutter)
     :desc "Jump to previous hunk" "é" #'+vc-gutter/previous-hunk
     :desc "Jump to next hunk" "è" #'+vc-gutter/next-hunk))))

(defun +layout-remap-evil-keys-for-azerty-h ()
  (map! :nv "à" #'evil-execute-macro
        :nv "²" #'evil-goto-mark
        (:when (modulep! :checkers spell)
         :m "és" #'+spell/previous-error
         :m "ès" #'+spell/next-error)
        :n  "è SPC" #'+evil/insert-newline-below
        :n  "é SPC" #'+evil/insert-newline-above
        :n  "èb"    #'next-buffer
        :n  "éb"    #'previous-buffer
        :n  "èf"    #'+evil/next-file
        :n  "éf"    #'+evil/previous-file
        :m  "éu"    #'+evil:url-encode
        :m  "èu"    #'+evil:url-decode
        :m  "éy"    #'+evil:c-string-encode
        :m  "èy"    #'+evil:c-string-decode
        (:when (modulep! :ui vc-gutter)
         :m "èd"   #'+vc-gutter/next-hunk
         :m "éd"   #'+vc-gutter/previous-hunk)
        (:when (modulep! :ui hl-todo)
         :m "èt"   #'hl-todo-next
         :m "ét"   #'hl-todo-previous)
        (:when (modulep! :ui workspaces)
         :n "èw"   #'+workspace/switch-right
         :n "éw"   #'+workspace/switch-left)
        :m  "è#"    #'+evil/next-preproc-directive
        :m  "é#"    #'+evil/previous-preproc-directive
        :m  "èa"    #'evil-forward-arg
        :m  "éa"    #'evil-backward-arg
        :m  "èc"    #'+evil/next-comment
        :m  "éc"    #'+evil/previous-comment
        :m  "èe"    #'next-error
        :m  "ée"    #'previous-error
        :n  "èF"    #'+evil/next-frame
        :n  "éF"    #'+evil/previous-frame
        :m  "èh"    #'outline-next-visible-heading
        :m  "éh"    #'outline-previous-visible-heading
        :m  "èm"    #'+evil/next-beginning-of-method
        :m  "ém"    #'+evil/previous-beginning-of-method
        :m  "èM"    #'+evil/next-end-of-method
        :m  "éM"    #'+evil/previous-end-of-method
        :n  "éo"    #'+evil/insert-newline-above
        :n  "èo"    #'+evil/insert-newline-below
        :nv "gà"    #'+evil:apply-macro))

(+layout-remap-keys-for-azerty-h)
(when (modulep! :editor evil)
  (+layout-remap-evil-keys-for-azerty-h))
