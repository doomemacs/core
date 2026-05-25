;; -*- no-byte-compile: t; -*-
;;; term/vterm/test/test-vterm.el

(require 'buttercup)

(describe "term/vterm"
  (describe "split commands"
    (it "defines +vterm/split-below"
      (expect (fboundp '+vterm/split-below) :to-be t))

    (it "defines +vterm/split-right"
      (expect (fboundp '+vterm/split-right) :to-be t))

    (it "remaps split-window-below in vterm-mode-map"
      (expect (lookup-key vterm-mode-map [remap split-window-below])
              :to-equal '+vterm/split-below))

    (it "remaps split-window-right in vterm-mode-map"
      (expect (lookup-key vterm-mode-map [remap split-window-right])
              :to-equal '+vterm/split-right))

    (it "remaps evil-window-split in vterm-mode-map"
      (expect (lookup-key vterm-mode-map [remap evil-window-split])
              :to-equal '+vterm/split-below))

    (it "remaps evil-window-vsplit in vterm-mode-map"
      (expect (lookup-key vterm-mode-map [remap evil-window-vsplit])
              :to-equal '+vterm/split-right))))
