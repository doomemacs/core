;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; tools/lookup/test/test-lookup.el

(describe "tools/lookup"
  (before-all
    (load! "../autoload/lookup"))

  (describe "xref fallback behavior"
    (it "does not treat a no-op single xref result as success"
      (with-temp-buffer
        (insert "foo")
        (goto-char (point-min))
        (let ((origin (point-marker))
              (xref-after-jump-hook nil))
          (unwind-protect
              (cl-letf (((symbol-function 'xref-find-backend)
                         (lambda () 'fake))
                        ((symbol-function 'xref-backend-definitions)
                         (lambda (_backend _identifier)
                           (list (xref-make "here"
                                            (xref-make-buffer-location
                                             (current-buffer)
                                             (point))))))
                        ;; Simulate a backend that triggers jump hooks without
                        ;; changing point/buffer.
                        ((symbol-function 'xref--show-defs)
                         (lambda (_fetcher _alist)
                           (run-hooks 'xref-after-jump-hook)
                           nil)))
                (expect (+lookup--run-handlers
                         '+lookup-xref-definitions-backend-fn
                         "foo"
                         origin)
                        :to-be nil))
            (set-marker origin nil)))))))
