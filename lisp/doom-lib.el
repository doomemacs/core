;;; doom-lib.el --- Doom's core standard library -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;;
;;; * Autoload the unautoloaded

;; DEPRECATED: For backwards compatibility
(autoload 'print! "cli/print")
(autoload 'print-group! "cli/print")
(autoload 'insert! "cli/print")
(autoload 'doom-print "cli/print")

;; Is never autoloaded
(autoload 'map-nested-elt "map")


;;
;;; * Emacs forwards compatibility

;;; ** From Emacs >= 28
;; Introduced in 28.1
(unless (fboundp 'ensure-list)
  (defun ensure-list (object)
    "Return OBJECT as a list.
If OBJECT is already a list, return OBJECT itself. If it's not a list, return a
one-element list containing OBJECT."
    (declare (pure t) (side-effect-free t))
    (if (listp object) object (list object))))

;; Introduced in 28.1
(unless (fboundp 'always)
  (defun always (&rest _args)
    "Do nothing and return t.
This function accepts any number of ARGUMENTS, but ignores them.  Also see
`ignore'."
    t))

;; Introduced in 28.1
(unless (fboundp 'file-name-concat)
  (defun file-name-concat (directory &rest components)
    "Append COMPONENTS to DIRECTORY and return the resulting string.

Elements in COMPONENTS must be a string or nil.
DIRECTORY or the non-final elements in COMPONENTS may or may not end
with a slash -- if they don't end with a slash, a slash will be
inserted before contatenating."
    (mapconcat
     #'identity
     (cl-loop for str in (cons directory components)
              if (and str (/= 0 (length str))
                      (if (string-suffix-p "/" str)
                          (substring str 0 -1)
                        str))
              collect it)
     "/")))

;; Introduced in 28.1
(unless (fboundp 'with-environment-variables)
  (defmacro with-environment-variables (variables &rest body)
    "Set VARIABLES in the environment and execute BODY.
VARIABLES is a list of variable settings of the form (VAR VALUE),
where VAR is the name of the variable (a string) and VALUE
is its value (also a string).

The previous values will be restored upon exit."
    (declare (indent 1) (debug (sexp body)))
    (unless (consp variables)
      (error "Invalid VARIABLES: %s" variables))
    `(let ((process-environment (copy-sequence process-environment)))
       ,@(cl-loop for var in variables
                  collect `(setenv ,(car var) ,(cadr var)))
       ,@body)))

;; Introduced in 28.1
(unless (fboundp 'file-name-with-extension)
  (defun file-name-with-extension (filename extension)
    "Return FILENAME modified to have the specified EXTENSION.
The extension (in a file name) is the part that begins with the last \".\".
This function removes any existing extension from FILENAME, and then
appends EXTENSION to it.

EXTENSION may include the leading dot; if it doesn't, this function
will provide it.

It is an error if FILENAME or EXTENSION is empty, or if FILENAME
is in the form of a directory name according to `directory-name-p'.

See also `file-name-sans-extension'."
    (let ((extn (string-trim-left extension "[.]")))
      (cond ((string-empty-p filename)
             (error "Empty filename"))
            ((string-empty-p extn)
             (error "Malformed extension: %s" extension))
            ((directory-name-p filename)
             (error "Filename is a directory: %s" filename))
            ((concat (file-name-sans-extension filename) "." extn))))))

;; Introduced in Emacs 28.1
(unless (fboundp 'dlet)
  (defmacro dlet (binders &rest body)
    "Like `let' but using dynamic scoping."
    (declare (indent 1) (debug let))
    `(let (_)
       ,@(cl-loop for binder in binders
                  collect `(defvar ,(if (consp binder) (car binder) binder)))
       (let ,binders ,@body))))


;;; ** From Emacs >= 29
;; Introduced in Emacs 29.1
(unless (fboundp 'with-memoization)
  (defmacro with-memoization (place &rest code)
    "Return the value of CODE and stash it in PLACE.
If PLACE's value is non-nil, then don't bother evaluating CODE
and return the value found in PLACE instead."
    (declare (indent 1) (debug (gv-place body)))
    (gv-letplace (getter setter) place
      `(or ,getter
           ,(macroexp-let2 nil val (macroexp-progn code)
              `(progn
                 ,(funcall setter val)
                 ,val))))))

;; Introduced in 29.1
(unless (fboundp 'pos-bol) (defalias 'pos-bol #'line-beginning-position))
(unless (fboundp 'pos-eol) (defalias 'pos-eol #'line-end-position))


;;; ** From Emacs >= 30
;; Introduced in 30.1
(unless (fboundp 'static-if)
  (defmacro static-if (condition then-form &rest else-forms)
    "A conditional compilation macro.
Evaluate CONDITION at macro-expansion time.  If it is non-nil,
expand the macro to THEN-FORM.  Otherwise expand it to ELSE-FORMS
enclosed in a `progn' form.  ELSE-FORMS may be empty."
    (declare (indent 2)
             (debug (sexp sexp &rest sexp)))
    (if (eval condition lexical-binding)
        then-form
      (cons 'progn else-forms))))


;;; ** From Emacs >= 31
(unless (fboundp 'static-when)
  (defmacro static-when (condition &rest body)
    "A conditional compilation macro.
Evaluate CONDITION at macro-expansion time.  If it is non-nil,
expand the macro to evaluate all BODY forms sequentially and return
the value of the last one, or nil if there are none."
    (declare (indent 1) (debug t))
    (if body
        (if (eval condition lexical-binding)
            (cons 'progn body)
          nil)
      (macroexp-warn-and-return (format-message "`static-when' with empty body")
                                (list 'progn nil nil) '(empty-body static-when) t))))

(unless (fboundp 'static-unless)
  (defmacro static-unless (condition &rest body)
    "A conditional compilation macro.
Evaluate CONDITION at macro-expansion time.  If it is nil,
expand the macro to evaluate all BODY forms sequentially and return
the value of the last one, or nil if there are none."
    (declare (indent 1) (debug t))
    (if body
        (if (eval condition lexical-binding)
            nil
          (cons 'progn body))
      (macroexp-warn-and-return (format-message "`static-unless' with empty body")
                                (list 'progn nil nil) '(empty-body static-unless) t))))


;;
;;; * Errors

(define-error 'doom-error "An unexpected Doom error")
(define-error 'doom-font-error "Could not find a font on your system" 'doom-error)
(define-error 'doom-nosync-error "Doom hasn't been initialized yet; did you remember to run 'doom sync' in the shell?" 'doom-error)
(define-error 'doom-core-error "Unexpected error in Doom's core" 'doom-error)
(define-error 'doom-compat-error "Can't resolve incompatibilities between Doom versions" 'doom-error)
(define-error 'doom-cli-error "Unexpected error in Doom's CLI" 'doom-error)
(define-error 'doom-context-error "Incorrect context error" 'doom-error)
(define-error 'doom-hook-error "Error in a Doom startup hook" 'doom-error)
(define-error 'doom-autoload-error "Error in Doom's autoloads file" 'doom-error)
(define-error 'doom-user-error "Error caused by user's config or system" 'doom-error)
(define-error 'doom-profile-error "Error while processing profiles" 'doom-error)
(define-error 'doom-module-error "Error in a Doom module" 'doom-profile-error)
(define-error 'doom-source-error "Error in a Doom source" 'doom-profile-error)
(define-error 'doom-package-error "Error with packages" 'doom-profile-error)


;;
;;; * Logging

(defvar doom-inhibit-log (not (or noninteractive init-file-debug))
  "If non-nil, suppress `doom-log' output completely.")

(defvar doom-log-level
  (if noninteractive
      ;; Without debug mode, logs won't be emitted to stdout, but will be
      ;; written to log files.
      3
    (if init-file-debug
        (if-let* ((level (getenv-internal "DEBUG"))
                  (level (if (string-empty-p level) 1 (string-to-number level)))
                  ((not (zerop level))))
            level
          2)
      0))
  "How verbosely to log from `doom-log' calls.

0 -- No logging at all.
1 -- Only warnings.
2 -- Warnings and notices.
3 -- Debug info, warnings, and notices.")

(defun doom--log (level text &rest args)
  (let ((inhibit-message (if noninteractive
                             (not init-file-debug)
                           (> level doom-log-level)))
        (absolute? (string-prefix-p ":" text)))
    (apply #'message
           (propertize (concat "* %d:%.06f:%s" (if (not absolute?) ":") text)
                       'face 'font-lock-doc-face)
           level
           (float-time (time-subtract (current-time) before-init-time))
           (mapconcat
            (lambda (x) (format "%s" x))
            (unless absolute?
              (append (cons '* (remq t (reverse doom-context)))
                      (if (bound-and-true-p doom-module-context)
                          (let ((key (doom-module-context-key doom-module-context)))
                            (delq nil (list (car key) (cdr key)))))))
            ":")
           args)))

;; This is a macro instead of a function to prevent the potentially expensive
;; evaluation of its arguments when debug mode is off. Return non-nil.
(defmacro doom-log (message &rest args)
  "Log MESSAGE formatted with ARGS to stderr or *Messages* (but not echo area)."
  (declare (debug t))
  (let ((level (if (integerp message)
                   (prog1 message
                     (setq message (pop args)))
                 2)))
    `(when (and (not doom-inhibit-log)
                (<= ,level doom-log-level))
       (doom--log ,level ,message ,@args))))


;;
;;; * Helpers

(defun doom--resolve-hook-forms (hooks)
  "Converts a list of modes into a list of hook symbols.

If a mode is quoted, it is left as is. If the entire HOOKS list is quoted, the
list is returned as-is."
  (declare (pure t) (side-effect-free t))
  (let ((hook-list (ensure-list (doom-unquote hooks))))
    (if (eq (car-safe hooks) 'quote)
        hook-list
      (cl-loop for hook in hook-list
               if (eq (car-safe hook) 'quote)
               collect (cadr hook)
               else collect (intern (format "%s-hook" (symbol-name hook)))))))

(defun doom--setq-hook-fns (hooks rest &optional singles)
  (unless (or singles (= 0 (% (length rest) 2)))
    (signal 'wrong-number-of-arguments (list #'evenp (length rest))))
  (cl-loop with vars = (let ((args rest)
                             vars)
                         (while args
                           (push (if singles
                                     (list (pop args))
                                   (cons (pop args) (pop args)))
                                 vars))
                         (nreverse vars))
           for hook in (doom--resolve-hook-forms hooks)
           for mode = (string-remove-suffix "-hook" (symbol-name hook))
           append
           (cl-loop for (var . val) in vars
                    collect
                    (list var val hook
                          (intern (format "doom--setq-%s-for-%s-h"
                                          var mode))))))


;;
;;; * pcase extensions

(pcase-defmacro doom-struct (type &rest fields)
  `(and (pred (cl-struct-p))
        ;; TODO: Support `&rest', `&key', and `&optional' in FIELDS
        ,@(mapcar
           (lambda (field)
             (let ((offset (cl-struct-slot-offset type field)))
               `(app (lambda (it)
                       ,(if offset
                            `(aref it ,offset)
                          `(,(intern (format "%s-%s" ',type ',field)) it)))
                     ,field)))
           fields)))


;;
;;; * Public library

(defun doom-unquote (exp)
  "Return EXP unquoted."
  (declare (pure t) (side-effect-free t))
  (while (memq (car-safe exp) '(quote function))
    (setq exp (cadr exp)))
  exp)

(defun doom-keyword-intern (str)
  "Converts STR (a string) into a keyword (`keywordp')."
  (declare (pure t) (side-effect-free t))
  (cl-check-type str string)
  (intern (concat ":" str)))

(defun doom-keyword-name (keyword)
  "Returns the string name of KEYWORD (`keywordp') minus the leading colon."
  (declare (pure t) (side-effect-free t))
  (cl-check-type keyword keyword)
  (substring (symbol-name keyword) 1))

(defalias 'doom-partial #'apply-partially)

(defun doom-rpartial (fn &rest args)
  "Return a partial application of FUN to right-hand ARGS.

ARGS is a list of the last N arguments to pass to FUN. The result is a new
function which does the same as FUN, except that the last N arguments are fixed
at the values with which this function was called."
  (declare (side-effect-free t))
  (lambda (&rest pre-args)
    (apply fn (append pre-args args))))

(defun doom-lookup-key (keys &rest keymaps)
  "Like `lookup-key', but search active keymaps if KEYMAP is omitted."
  (if keymaps
      (cl-some (doom-rpartial #'lookup-key keys) keymaps)
    (cl-loop for keymap
             in (append (cl-loop for alist in emulation-mode-map-alists
                                 append (mapcar #'cdr
                                                (if (symbolp alist)
                                                    (if (boundp alist) (symbol-value alist))
                                                  alist)))
                        (list (current-local-map))
                        (mapcar #'cdr minor-mode-overriding-map-alist)
                        (mapcar #'cdr minor-mode-map-alist)
                        (list (current-global-map)))
             if (keymapp keymap)
             if (lookup-key keymap keys)
             return it)))

(defun doom-load (path &optional noerror)
  "Load PATH and handle any Doom errors that arise from it.

If NOERROR, don't throw an error if PATH doesn't exist.
Return non-nil if loading the file succeeds."
  (doom-log 2 "load: %s %s" (abbreviate-file-name path) noerror)
  (condition-case-unless-debug e
      (load path noerror 'nomessage)
    (doom-error
     (signal (car e) (cdr e)))
    (error
     (setq path (locate-file path load-path (get-load-suffixes)))
     (if (not (and path (featurep 'doom)))
         (signal (car e) (cdr e))
       (cl-loop for (err . dirs)
                in `((doom-cli-error     ,(expand-file-name "cli" doom-core-dir))
                     (doom-core-error    ,doom-core-dir)
                     (doom-user-error    ,doom-user-dir)
                     (doom-profile-error ,doom-profile-dir)
                     (doom-module-error  ,@(cdr doom-module-load-path)))
                if (cl-find-if (lambda (dir) (file-in-directory-p path dir)) dirs)
                do (signal err (list (file-relative-name path (expand-file-name "../" it))
                                     e))
                finally (signal (car e) (cdr e)))))))

(defun doom-require (feature &optional filename noerror)
  "Like `require', but handles and enhances Doom errors.

Can also load Doom's subfeatures, e.g. (doom-require \\='doom-lib \\='files)"
  (let ((subfeature (if (symbolp filename) filename)))
    (or (featurep feature subfeature)
        (doom-load
         (if subfeature
             (file-name-concat doom-core-dir
                               (string-remove-prefix "doom-" (symbol-name feature))
                               (symbol-name filename))
           (symbol-name feature))
         noerror))))

(defvar doom--hook nil)
(defun doom-run-hook (hook)
  "Run HOOK (a hook function) with better error handling.
Meant to be used with `run-hook-wrapped'."
  (doom-log 3 "hook:%s: run %S in %S" (or doom--hook '*) hook (current-buffer))
  (condition-case-unless-debug e
      (funcall hook)
    (error
     (signal 'doom-hook-error (list hook e))))
  ;; return nil so `run-hook-wrapped' won't short circuit
  nil)

(defun doom-run-hooks (&rest hooks)
  "Run HOOKS (a list of hook variable symbols) with better error handling."
  (dolist (hook hooks)
    (condition-case-unless-debug e
        (let ((doom--hook hook))
          (run-hook-wrapped hook #'doom-run-hook))
      (doom-hook-error
       (unless debug-on-error
         (lwarn hook :error "Error running hook %S because: %s"
                (if (symbolp (cadr e))
                    (symbol-name (cadr e))
                  (cadr e))
                (caddr e)))
       (signal 'doom-hook-error (cons hook (cdr e)))))))

(defun doom-run-hook-on (hook-var trigger-hooks &optional predicate)
  "Configure HOOK-VAR to be invoked exactly once when any of the TRIGGER-HOOKS
are invoked *after* Emacs has initialized (to reduce false positives). Once
HOOK-VAR is triggered, it is reset to nil.

HOOK-VAR is a quoted hook.
TRIGGER-HOOK is a list of quoted hooks and/or sharp-quoted functions."
  (dolist (hook trigger-hooks)
    (let ((fn (make-symbol (format "chain-%s-to-%s-h" hook-var hook)))
          running?)
      (fset
       fn (lambda (&rest _)
            ;; Only trigger this after Emacs has initialized.
            (when (and (not running?)
                       (not (doom-context-p 'startup))
                       (or (daemonp)
                           ;; In some cases, hooks may be lexically unset to
                           ;; inhibit them during expensive batch operations on
                           ;; buffers (such as when processing buffers
                           ;; internally). In that case assume this hook was
                           ;; invoked non-interactively.
                           (and (boundp hook)
                                (symbol-value hook))))
              ;; The predicate or hooks could change the active buffer, breaking
              ;; `after-find-file' (doomemacs/core#8884).
              (save-current-buffer
                (when (or (null predicate)
                          (funcall predicate))
                  (setq running? t)  ; prevent infinite recursion
                  (doom-run-hooks hook-var)
                  (set hook-var nil))))))
      (when (daemonp)
        ;; In a daemon session we don't need all these lazy loading shenanigans.
        ;; Just load everything immediately.
        (add-hook 'server-after-make-frame-hook fn 'append))
      (if (eq hook 'find-file-hook)
          ;; Advise `after-find-file' instead of using `find-file-hook' because
          ;; the latter is triggered too late (after the file has opened and
          ;; modes are all set up).
          (advice-add 'after-find-file :before fn '((depth . -101)))
        (add-hook hook fn -101))
      fn)))


;;; ** Directory helpers

;; These are intentional facsimiles of their final implementations, meant solely
;; for forward-compatibility with v3.

(defsubst doom--profile (profile)
  (if-let* ((p (if (eq profile t) doom-profile profile)))
      ;; NOTE: Can't use `doom-profile-key' this early during startup. No
      ;;   guarantee the `doom-profile' struct+API will be available yet in
      ;;   interactive sessions.
      (if (cl-struct-p p)
          (cons (doom-profile-name p) (doom-profile-ref p))
        p)
    (signal 'doom-profile-error '(no-profile))))

(defsubst doom--dir (dir segments)
  (let ((segments (delq nil segments))
        file-name-handler-alist)
    (if segments
        (expand-file-name
         (if (cdr segments)
             (apply #'file-name-concat segments)
           (car segments))
         dir)
      (expand-file-name dir))))

(dolist (var '(doom-emacs-dir
               doom-core-dir
               doom-user-dir
               doom-data-dir
               doom-state-dir
               doom-cache-dir))
  (defalias var
    (lambda (&rest segments)
      (doom--dir (symbol-value var) segments))
    (format "Return a path from SEGMENTS after `%s'." var)))

(dolist (var '((doom-profile-data-dir  . doom-data-dir)
               (doom-profile-cache-dir . doom-cache-dir)
               (doom-profile-state-dir . doom-state-dir)))
  (defalias (car var)
    (lambda (profile &rest segments)
      (setq profile (doom--profile profile))
      (doom--dir (file-name-concat
                  (symbol-value (cdr var))
                  ;; DEPRECATED: Temporary backwards compatibility cludge.
                  (unless (and doom--noprofile
                               (equal profile doom--profile-default))
                    (car profile)))
                 segments))
    (format "Return a local PROFILE path from SEGMENTS after `%s'.

See `doom-profile-dir' for possible values of PROFILE."
            (cdr var))))

(defun doom-profile-dir (profile &rest segments)
  "Return a path from SEGMENTS after a PROFILE's root data directory.

PROFILE can either be a profile key (cons cell), a `doom-profile' struct, or `t'
(meaning the active profile). A `nil' profile will throw `doom-profile-error'."
  (setq profile (doom--profile profile))
  (doom--dir (file-name-concat
              doom-data-dir
              ;; DEPRECATED: Temporary backwards compatibility cludge.
              (unless (and doom--noprofile
                           (equal profile doom--profile-default))
                (car profile)))
             segments))

(defun doom-profile-init-dir (profile &rest segments)
  "Return a path from SEGMENTS after a PROFILE's init files directory.

See `doom-profile-dir' for possible values for PROFILE."
  (setq profile (doom--profile profile))
  (apply #'doom-profile-dir profile "@"
         ;; DEPRECATED: Temporary backwards compatibility cludge.
         (unless (and doom--noprofile
                      (equal profile doom--profile-default))
           (cdr profile))
         segments))

(defun doom-profile-init-file (profile &optional filename)
  "Return a path to a PROFILE's FILENAME (or its init.%d.%d.el file).

See `doom-profile-dir' for possible values for PROFILE."
  (doom-profile-init-dir
   profile (or filename (format "init.%d.%d.el"
                                emacs-major-version
                                emacs-minor-version))))


;;; ** Deep copying

(cl-defgeneric doom-copy (val &optional deep?)
  "Return a (optionally deep) copy of VAL."
  (if (recordp val)  ; `record' specializer not supported until Emacs 30
      (if deep?
          (cl-loop with newval = (copy-sequence val)
                   for idx from 1 to (length (cdr (cl-struct-slot-info (type-of val))))
                   do (aset newval idx (doom-copy (aref newval idx) t))
                   finally return newval)
        (copy-sequence val))
    val))

(cl-defmethod doom-copy ((val sequence) &optional deep?)
  "Return a (optionally deep) copy of sequence VAL."
  (if (stringp val)
      (if deep? val (purecopy val))
    (if deep?
        (when-let* ((newval (mapcar (doom-rpartial #'doom-copy t) val)))
          (if (vectorp val)
              (apply #'vector newval)
            newval))
      (copy-sequence val))))

(cl-defmethod doom-copy ((val cons) &optional deep?)
  "Return a (optionally deep) copy of cons cell/list VAL."
  (cons (doom-copy (car val) deep?)
        (doom-copy (cdr val) deep?)))

(cl-defmethod doom-copy ((val hash-table) &optional deep?)
  "Return a (optionally deep) copy of hash table VAL."
  (let ((table (copy-hash-table val)))
    (when deep?
      (maphash (lambda (key val)
                 (puthash key (doom-copy val t) table))
               table))
    table))


;;; ** Sugars

(defmacro file! ()
  "Return the file of the file this macro was called."
  (or (bound-and-true-p byte-compile-current-file)
      load-file-name
      (buffer-file-name (buffer-base-buffer))  ; for `eval'
      ;; REVIEW: Use `macroexp-file-name' once 27 support is dropped.
      (let ((file (car (last current-load-list))))
        (if (stringp file) file))
      (error "file!: cannot deduce the current file path")))

(defmacro dir! (&rest segments)
  "Return the directory of the file in which this macro was called.

Appends SEGMENTS to the path, relative to the call site."
  (let* ((file-name-handler-alist nil)
         (dir (file-name-directory (macroexpand '(file!)))))
    (if segments
        `(doom--dir ,dir (list ,@segments))
      dir)))

(put 'defun* 'lisp-indent-function 'defun)
(put 'defun! 'lisp-indent-function 'defun)
(defmacro letf! (bindings &rest body)
  "Temporarily bind functions, macros, and advice in BODY.

Intended as syntax sugar for `cl-flet', `cl-letf', `cl-labels', `cl-macrolet',
and (temporary) `define-advice'.

BINDINGS is either:

  A list of (PLACE VALUE) bindings as `cl-letf*' would accept. If PLACE is a
    sharp-quoted symbol, it is implicitly wrapped in (symbol-function ...).
  A list of, or a single, `defun', `defun*', `defun!', `defmacro', or
    `defadvice' forms.

The def* forms accepted are:

  (defun NAME (ARGS...) &rest BODY)
    Defines a temporary, lexical function with `cl-flet'.
  (defun* NAME (ARGS...) &rest BODY)
    Defines a temporary, lexical function with `cl-labels' (allows recursive
    definitions).
  (defun! NAME (ARGS...) &rest BODY)
    Defines a temporary, global function with `cl-letf*'. Will (temporarily)
    override functions of the same name. Use `defadvice' instead if you want to
    reference/call the original function.
  (defmacro NAME (ARGS...) &rest BODY)
    Uses `cl-macrolet' to define lexical macros.
  (defadvice FUNCTION WHERE ADVICE)
    Uses `advice-add' to advise FUNCTION over the duration of its execution,
    then undoes the advice with `advice-remove' afterwards. No relation to the
    `defadvice' macro.
  (defadvice FUNCTION (HOW LAMBDA-LIST &optional NAME DEPTH) &rest BODY)
    Defines temporary advice with `define-advice'. No relation to the
    `defadvice' macro."
  (declare (indent defun))
  (setq body (macroexp-progn body))
  (when (memq (car bindings) '(defun defun* defun! defmacro defadvice))
    (setq bindings (list bindings)))
  (dolist (binding (reverse bindings) body)
    (setq
     body (pcase binding
            (`(defmacro . ,rest) `(cl-macrolet (,rest) ,body))
            (`(defun    . ,rest) `(cl-flet     (,rest) ,body))
            (`(defun*   . ,rest) `(cl-labels   (,rest) ,body))
            (`(defun! ,name . ,rest)
             `(cl-letf (((symbol-function #',name)
                         (cl-function (lambda ,@rest))))
                ,body))
            (`(defadvice ,target ,first . ,rest)
             (if (keywordp first)
                 (let ((sym (gensym "fn")))
                   `(when-let* ((,sym ,target))
                      (advice-add ,target ,first ,sym ,@rest)
                      (unwind-protect ,body (advice-remove ,target ,sym))))
               (when (< (length first) 3)
                 (setq first
                       (list (nth 0 first)
                             (nth 1 first)
                             (gensym "doom-letf-"))))
               (let ((sym (intern (format "%s@%s" target (nth 2 first)))))
                 `(progn
                    (define-advice ,target ,first ,@rest)
                    (unwind-protect ,body
                      (advice-remove #',target #',sym)
                      (fmakunbound ',sym))))))
            (`((function ,fn) ,value)
             `(cl-letf (((symbol-function #',fn) ,value)) ,body))
            (_ `(let (,binding) ,body))))))

(defmacro quiet!! (&rest forms)
  "Run FORMS without generating any output (for real).

Unlike `quiet!', which will only suppress output in the echo area in interactive
sessions, this truly suppress all output from FORMS."
  (declare (indent 0))
  `(if init-file-debug
       (progn ,@forms)
     (letf! ((standard-output (lambda (&rest _)))
             (defadvice message (:override (msg &rest _)) msg)
             (defadvice load (:around (fn file &optional noerror _nomessage nosuffix must-suffix))
               (funcall fn file noerror t nosuffix must-suffix))
             (defadvice write-region (:around (fn start end filename &optional append visit lockname mustbenew))
               (unless visit (setq visit 'no-message))
               (funcall fn start end filename append visit lockname mustbenew)))
       ,@forms)))

(defmacro quiet! (&rest forms)
  "Run FORMS without generating any output.

This silences calls to `message', `load', `write-region' and anything that
writes to `standard-output'. In interactive sessions this inhibits output to the
echo-area, but not to *Messages*."
  (declare (indent 0))
  `(if init-file-debug
       (progn ,@forms)
     ,(if noninteractive
          `(quiet!! ,@forms)
        `(let ((inhibit-message t)
               (save-silently t))
           (prog1 ,@forms (message ""))))))

(defmacro versionp! (v1 comp v2 &rest comps)
  "Perform compound version checks.

Compares V1 and V2 with COMP (a math comparison operator: <, <=, =, /=, >=, >).
Can chain these comparisons by adding more (COMPn Vn) pairs afterwards.

\(fn V1 COMP V2 [COMPn Vn]...)"
  (let ((forms t))
    (push v2 comps)
    (push comp comps)
    `(let ((v2 (version-to-list ,v1)))
       ,(progn
          (cl-loop for (v op) on (nreverse comps) by #'cddr
                   for not? = (not (memq op '(> >= /=)))
                   for fn = (or (get 'versionp! op)
                                (error "Invalid comparator %s" op))
                   for form = `(,fn v1 v2)
                   do (if not? (setq form `(not ,form)))
                   do (setq v1 'v2
                            v2 `(version-to-list ,v)
                            forms `(let ((v1 ,v1)
                                         (v2 ,v2))
                                     (and (not ,form) ,forms))))
          forms))))
;; PERF: Store in symbol plist for ultra-fast lookups at this scale.
(setplist 'versionp! '(>  version-list-<
                       >= version-list-<=
                       <  version-list-<
                       <= version-list-<=
                       =  version-list-=
                       /= version-list-=))

(defmacro with-delayed-gc! (&rest body)
  "Evaluate BODY with GC deferred."
  (declare (indent defun))
  (if (featurep 'igc)
      (macroexp-progn body)
    `(let ((gc-cons-threshold most-positive-fixnum)
           (gc-cons-percentage 1.0))
       ,@body)))


;;; ** Closure factories

(defun doom--lambda-allow-other-keys (args)
  (let ((add (and (memq '&key args)
                  (not (memq '&allow-other-keys args))))
        out)
    (dolist (arg args)
      (when (and add (eq arg '&aux))
        (push '&allow-other-keys out))
      (push (if (proper-list-p arg)
                (doom--lambda-allow-other-keys arg)
              arg)
            out))
    (setq out (nreverse out))
    (if (and add (not (memq '&aux args)))
        (nconc out (list '&allow-other-keys))
      out)))

(defmacro lambda! (arglist &rest body)
  "Returns (cl-function (lambda ARGLIST BODY...))

The closure is wrapped in `cl-function', meaning ARGLIST will accept anything
`cl-defun' will. Implicitly adds `&allow-other-keys' if `&key' is present in
ARGLIST."
  (declare (indent defun) (doc-string 1) (side-effect-free t))
  `(cl-function (lambda ,(doom--lambda-allow-other-keys arglist) ,@body)))

(defun doom--fn-arglist (args)
  (let ((argv (make-vector 10 nil))
        (stack (list args)))
    (while stack
      (let ((data (pop stack)))
        (cond ((symbolp data)
               (when-let*
                   ((pos (cond ((eq data '%*) 0)
                               ((eq data '%) 1)
                               ((memq data '(%1 %2 %3 %4 %5 %6 %7 %8 %9))
                                (- (aref (symbol-name data) 1) ?0)))))
                 (when (and (= pos 1) (aref argv 1) (not (eq data (aref argv 1))))
                   (error "%% and %%1 are mutually exclusive"))
                 (aset argv pos data)))
              ((and (not (eq (car-safe data) 'fn!))
                    (or (consp data) (vectorp data)))
               (setq stack (append data stack))))))
    (nconc
     (cl-loop with seen for i downfrom 9 to 1
              for sym = (aref argv i)
              if (or seen sym) do (setq seen t)
              and collect (or sym (intern (format "_%%%d" i))) into arglist
              finally return (nreverse arglist))
     (and (aref argv 0) '(&rest %*)))))

(defmacro fn! (&rest args)
  "Return a lambda with implicit, positional arguments.

Each symbol `%1' through `%9' appearing anywhere in ARGS becomes a positional
argument. Missing intermediate arguments are named `_%N' to keep the
byte-compiler quiet. `%' is shorthand for `%1' (only one of the two may appear).
`%*' collects extra `&rest' arguments.

Loosely inspired from llama.el (https://git.sr.ht/~tarsius/llama), minus
font-locking and the outer function call."
  (declare (doc-string 1) (side-effect-free t))
  `(lambda ,(doom--fn-arglist args) ,@args))

(defmacro cmd! (&rest body)
  "Returns (lambda () (interactive) ,@body)
A factory for quickly producing interaction commands, particularly for keybinds
or aliases."
  (declare (doc-string 1) (side-effect-free t))
  `(lambda (&rest _) (interactive) ,@body))

(defmacro cmd!! (command &optional arg &rest args)
  "Returns a closure that interactively calls COMMAND with ARGS and PREFIX-ARG.

Like `cmd!', but allows you to change `current-prefix-arg' or pass arguments to
COMMAND. This macro is meant to be used as a target for keybinds (e.g. with
`define-key' or `map!')."
  (declare (doc-string 1) (side-effect-free t))
  `(lambda (arg &rest _) (interactive "P")
     (let ((current-prefix-arg (or ,arg arg)))
       (,(if args
             #'funcall-interactively
           #'call-interactively)
        (let ((command ,command))
          (or (command-remapping command)
              command))
        ,@args))))

(defmacro cmds! (&rest branches)
  "Returns a dispatcher that runs the a command in BRANCHES.
Meant to be used as a target for keybinds (e.g. with `define-key' or `map!').

BRANCHES is a flat list of CONDITION COMMAND pairs. CONDITION is a lisp form
that is evaluated when (and each time) the dispatcher is invoked. If it returns
non-nil, COMMAND is invoked, otherwise it falls through to the next pair.

The last element of BRANCHES can be a COMMANd with no CONDITION. This acts as
the fallback if all other conditions fail.

Otherwise, Emacs will fall through the keybind and search the next keymap for a
keybind (as if this keybind never existed).

See `general-key-dispatch' for what other arguments it accepts in BRANCHES."
  (declare (doc-string 1))
  (let ((docstring (if (stringp (car branches)) (pop branches) ""))
        fallback)
    (when (cl-oddp (length branches))
      (setq fallback (car (last branches))
            branches (butlast branches)))
    (let ((defs (cl-loop for (key value) on branches by 'cddr
                         unless (keywordp key)
                         collect (list key value))))
      `'(menu-item
         ,(or docstring "") nil
         :filter (lambda (&optional _)
                   (let (it)
                     (cond ,@(mapcar (lambda (pred-def)
                                       `((setq it ,(car pred-def))
                                         ,(cadr pred-def)))
                                     defs)
                           (t ,fallback))))))))

;; For backwards compatibility
(defalias 'λ!  #'cmd!)
(defalias 'λ!! #'cmd!!)


;;; ** `doom-config'

(defvar doom-config-read-functions
  `(;;,(lambda (type version alist) (list version body))
    ,(lambda (type version alist)
       (pcase type
         ('profiles
          (setq alist
                (mapcar (lambda (p)
                          (cons (car p)
                                (doom-config--normalize 'profile version (cdr p))))
                        (alist-get 'profiles alist))))
         ('project
          (setf (alist-get 'profiles alist)
                (mapcar (lambda (p)
                          (cons (car p)
                                (doom-config--normalize 'profile version (cdr p))))
                        (alist-get 'profiles alist))
                (alist-get 'modules alist)
                (mapcar (lambda (m)
                          (cons (car m)
                                (doom-config--normalize 'module version (cdr m))))
                        (alist-get 'modules alist)))))
       (list version alist)))
  "A list of functions to transform files read by `doom-config'.

Each function takes three arguments: TYPE VERSION ALIST, and must return
(VERSION ALIST) to pass to the next function or t/nil (which are ignored). TYPE
is one of `project', `module', `modules', `profile', or `profiles',
corresponding to each rcfile that Doom recognizes (e.g. .doom, .doommodule,
.doommodules, etc).

The primary purpose of functions in this list is to resolve inter-version
incompatibilities introduced in future versions of Doom.")

(defun doom-config--normalize (type compat alist)
  "Process ALIST through `doom-config-read-functions'.

This ensures any changes to ALIST's spec (according to TYPE) between different
versions of Doom are resolved before it is used. COMPAT is the `doom-version'
that the current ALIST was formatted for."
  (cl-loop for fn in doom-config-read-functions
           if (funcall fn type compat (doom-copy alist t))
           do (if (consp it)
                  (setq compat (car it)
                        alist  (cadr it)))
           finally return alist))

(defun doom-config-file (type)
  "Return the filename of the Doom dotfile of TYPE.

TYPE is a symbol representing one of Doom's dotfiles. It must be one of:

  `project'  = .doom
  `module'   = .doommodule
  `modules'  = .doommodules
  `profile'  = .doomprofile
  `profiles' = .doomprofiles

Throws `doom-core-error' if TYPE is not a valid type. See `doom-config--alist'
for possible values of TYPE."
  (or (plist-get '(project  ".doom"
                   module   ".doommodule"
                   modules  ".doommodules"
                   profile  ".doomprofile"
                   profiles ".doomprofiles")
                 type)
      (signal 'doom-core-error `(invalid-config-type ,type))))

(defun doom-config-locate (type path &optional dir?)
  "Search for and return the path to a Doom dotfile of TYPE, starting from PATH.

Like `locate-dominating-file', but returns the full path including the filename.
If DIR? is non-nil, only return its parent directory. Returns nil if not found."
  (when-let*
      ((file (doom-config-file type))
       (dir  (locate-dominating-file path file)))
    (if dir? dir
      (file-name-concat dir file))))

(let ((cache (make-hash-table :test 'equal)))
  (defun doom-config (keys &optional nocache?)
    "Return the alist contained in a Doom dotfile.

TYPE is a symbol representing the type of Doom dotfile to look for; see
`doom-config-file' for valid values for TYPE. If KEYS are omitted, the entire
file's alist is returned, otherwise KEYS is a list of symbols representing the
path to the nested field to fetch from that config file. INIT-DIR is the path (a
string) to a directory from which the search for the dotfile will begin;
defaulting to `default-directory'.

All of Doom's dotfiles must be in the same format: a version string
\\=(signifying the version of Doom it was generated from) followed by an
unquoted alist which may contain comma-interpolated elisp forms which this
function will evaluate (and cache) before returning it. The first element of
KEYS can be a string path to a directory, which will set the `default-directory'
for the rest of the function. If NOCACHE? is non-nil, the cached alist will be
ignored and the target FILE will be reread (and re-cached).

Consults `doom-config-read-functions' to resolve any inter-version
incompatibilities in the alist format.

\(fn \\='([INIT-DIR] TYPE [KEYS...]) &optional NOCACHE?)"
    (declare (side-effect-free t))
    (cl-check-type keys (or list symbol))
    (when-let*
        ((keys (if (symbolp keys) (list keys) (copy-sequence keys)))
         (dir  (if (stringp (car keys)) (pop keys) default-directory))
         (type (pop keys))
         (path (doom-config-locate type dir))
         (rc (or (if (not nocache?) (gethash path cache))
                 (when-let* ((forms (doom-file-read path :by `(read . 2))))
                   (puthash
                    path (let ((v (pop forms)) (f (car forms)))
                           (when (and v (not (stringp v)))
                             (if f
                                 (signal 'doom-core-error
                                         `(config missing-version ,path))
                               (setq v (doom-version))))
                           (cons
                            v (doom-config--normalize
                               type v (if (listp f) (eval `(backquote ,f) t)))))
                    cache)))))
      (cond ((null keys) (cdr rc))
            ((symbolp keys) (alist-get keys (cdr rc)))
            ((listp keys) (map-nested-elt (cdr rc) keys))))))


;;; ** Loading

(defmacro add-load-path! (&rest dirs)
  "Add DIRS to `load-path', relative to the current file.
The current file is the file from which `add-to-load-path!' is used."
  `(let ((default-directory (dir!))
         file-name-handler-alist)
     (dolist (dir (list ,@dirs))
       (cl-pushnew (expand-file-name dir) load-path :test #'string=))))

(defmacro after! (package &rest body)
  "Evaluate BODY after PACKAGE have loaded.

PACKAGE is a symbol (or list of them) referring to Emacs features (aka
packages). PACKAGE may use :or/:any and :and/:all operators. The precise format
is:

- An unquoted package symbol (the name of a package)
    (after! helm BODY...)
- An unquoted, nested list of compound package lists, using any combination of
  :or/:any and :and/:all
    (after! (:or package-a package-b ...)  BODY...)
    (after! (:and package-a package-b ...) BODY...)
    (after! (:and package-a (:or package-b package-c) ...) BODY...)
- An unquoted list of package symbols (i.e. BODY is evaluated once both magit
  and diff-hl have loaded)
    (after! (magit diff-hl) BODY...)
  If :or/:any/:and/:all are omitted, :and/:all are implied.

This emulates `eval-after-load' with a few key differences:

1. No-ops for package that are disabled by the user (via `package!') or not
   installed yet.
2. Supports compound package statements (see :or/:any and :and/:all above).

Since the contents of these blocks will never by byte-compiled, avoid putting
things you want byte-compiled in them! Like function/macro definitions."
  (declare (indent defun) (debug t))
  (if (symbolp package)
      (unless (memq package (bound-and-true-p doom-disabled-packages))
        (list (if (or (not (bound-and-true-p byte-compile-current-file))
                      (require package nil 'noerror))
                  #'progn
                #'with-no-warnings)
              `(with-eval-after-load ',package ,@body)))
    (let ((p (car package)))
      (cond ((memq p '(:or :any))
             (macroexp-progn
              (cl-loop for next in (cdr package)
                       collect `(after! ,next ,@body))))
            ((memq p '(:and :all))
             (dolist (next (reverse (cdr package)) (car body))
               (setq body `((after! ,next ,@body)))))
            (`(after! (:and ,@package) ,@body))))))

(defmacro load! (filename &optional path noerror)
  "Load a file relative to the current executing file (`load-file-name').

FILENAME is either a file path string or a form that should evaluate to such a
string at run time. PATH is where to look for the file (a string representing a
directory path). If omitted, the lookup is relative to either `load-file-name',
`byte-compile-current-file' or `buffer-file-name' (checked in that order).

If NOERROR is non-nil, don't throw an error if the file doesn't exist."
  `(doom-load
    (file-name-concat ,(or path `(dir!)) ,filename)
    ,noerror))

(defmacro defer-until! (condition &rest body)
  "Run BODY when CONDITION is true (checks on `after-load-functions'). Meant to
serve as a predicated alternative to `after!'."
  (declare (indent defun) (debug t))
  `(if ,condition
       (progn ,@body)
     ,(let ((fn (intern (format "doom--delay-form-%s-h" (sxhash (cons condition body))))))
        `(progn
           (fset ',fn (lambda (&rest args)
                        (when ,(or condition t)
                          (remove-hook 'after-load-functions #',fn)
                          (unintern ',fn nil)
                          (ignore args)
                          ,@body)))
           (put ',fn 'permanent-local-hook t)
           (add-hook 'after-load-functions #',fn)))))

(defmacro defer-feature! (feature &rest fns)
  "Pretend FEATURE hasn't been loaded yet, until FEATURE-hook or FNS run.

Some packages (like `elisp-mode' and `lisp-mode') are loaded immediately at
startup, which will prematurely trigger `after!' (and `with-eval-after-load')
blocks. To get around this we make Emacs believe FEATURE hasn't been loaded yet,
then wait until FEATURE-hook (or any of FNS, if FNS are provided) is triggered
to reverse this and trigger `after!' blocks at a more reasonable time."
  (let ((advice-fn (intern (format "doom--defer-feature-%s-a" feature)))
        (fns (or fns (list feature))))
    `(progn
       (cl-callf2 delq ',feature features)
       (defadvice! ,advice-fn (&rest _)
         ,(format (concat "Defers `%s' until on of these functions are called:\n\n"
                          "%s\n\n"
                          "Created by `defer-feature!'.")
                  ',feature ',fns)
         :before ',fns
         ;; Some plugins (like yasnippet) will invoke a fn early to parse code,
         ;; which would prematurely trigger this. In those cases, well behaved
         ;; plugins will use `delay-mode-hooks', which we can check for:
         (unless delay-mode-hooks
           (unwind-protect
               (unless (featurep ',feature)
                 ;; If anything in `after-load-functions' or `after-load-alist'
                 ;; changes the current buffer, it could break the function
                 ;; being advised and cause unexpected errors.
                 (save-current-buffer
                   ;; ...Otherwise, announce to the world this package has been
                   ;; loaded, so `after!' handlers can react.
                   (provide ',feature)))
             (dolist (fn ',fns)
               (advice-remove fn #',advice-fn))))))))


;;; ** Hooks

(defmacro add-transient-hook! (hook-or-function &rest forms)
  "Attaches a self-removing function to HOOK-OR-FUNCTION.

FORMS are evaluated once, when that function/hook is first invoked, then never
again.

HOOK-OR-FUNCTION can be a quoted hook or a sharp-quoted function (which will be
advised)."
  (declare (indent 1))
  (let ((append? (if (eq (car forms) :after) (pop forms)))
        (fn (gensym "doom-transient-hook")))
    `(let ((sym ,hook-or-function))
       (defun ,fn (&rest _)
         ,(format "Transient hook for %S" (doom-unquote hook-or-function))
         ,@forms
         (let ((sym ,hook-or-function))
           (cond ((functionp sym) (advice-remove sym #',fn))
                 ((symbolp sym)   (remove-hook sym #',fn))))
         (unintern ',fn nil))
       (cond ((functionp sym)
              (advice-add ,hook-or-function ,(if append? :after :before) #',fn))
             ((symbolp sym)
              (put ',fn 'permanent-local-hook t)
              (add-hook sym #',fn ,append?))))))

(defmacro add-hook! (hooks &rest rest)
  "A convenience macro for adding N functions to M hooks.

This macro accepts, in order:

  1. The hook(s) to add to. This is either a quoted hook variable or a quoted
     list of hook variables.
  2. Optional properties :local, :append, and/or :depth [N], which will make the
     hook buffer-local or append to the list of hooks (respectively),
  3. The function(s) to be added: this can be a quoted function, a quoted list
     thereof, a list of `defun' or `cl-defun' forms, or arbitrary forms (will
     implicitly be wrapped in a lambda).

\(fn HOOKS [:append :local [:depth N]] FUNCTIONS-OR-FORMS...)"
  (declare (indent (lambda (indent-point state)
                     (goto-char indent-point)
                     (when (looking-at-p "\\s-*(")
                       (lisp-indent-defform state indent-point))))
           (debug t))
  (let* ((hook-forms (doom--resolve-hook-forms hooks))
         (func-forms ())
         (defn-forms ())
         append-p local-p remove-p depth)
    (while (keywordp (car rest))
      (pcase (pop rest)
        (:append (setq append-p t))
        (:depth  (setq depth (pop rest)))
        (:local  (setq local-p t))
        (:remove (setq remove-p t))))
    (while rest
      (let* ((next (pop rest))
             (first (car-safe next)))
        (push (cond ((memq first '(function nil lambda lambda!))
                     next)
                    ((eq first 'quote)
                     (let ((quoted (cadr next)))
                       (if (atom quoted)
                           next
                         (when (cdr quoted)
                           (setq rest (cons (list first (cdr quoted)) rest)))
                         (list first (car quoted)))))
                    ((memq first '(defun cl-defun))
                     (push next defn-forms)
                     (list 'function (cadr next)))
                    ((prog1 `(lambda (&rest _) ,@(cons next rest))
                       (setq rest nil))))
              func-forms)))
    `(progn
       ,@defn-forms
       (dolist (hook ',(nreverse hook-forms))
         (dolist (func (list ,@func-forms))
           ,(if remove-p
                `(remove-hook hook func ,local-p)
              `(add-hook hook func ,(or depth append-p) ,local-p)))))))

(defmacro remove-hook! (hooks &rest rest)
  "A convenience macro for removing N functions from M hooks.

Takes the same arguments as `add-hook!'.

If N and M = 1, there's no benefit to using this macro over `remove-hook'.

\(fn HOOKS [:append :local] FUNCTIONS)"
  (declare (indent defun) (debug t))
  `(add-hook! ,hooks :remove ,@rest))

(defmacro setq-hook! (hooks &rest var-vals)
  "Sets buffer-local variables on HOOKS.

\(fn HOOKS &rest [SYM VAL]...)"
  (declare (indent 1))
  (macroexp-progn
   (cl-loop for (var val hook fn) in (doom--setq-hook-fns hooks var-vals)
            collect `(defun ,fn (&rest _) (setq-local ,var ,val))
            collect `(add-hook ',hook #',fn -90))))

(defmacro unsetq-hook! (hooks &rest vars)
  "Unbind setq hooks on HOOKS for VARS.

\(fn HOOKS &rest [SYM VAL]...)"
  (declare (indent 1))
  (macroexp-progn
   (cl-loop for (_var _val hook fn)
            in (doom--setq-hook-fns hooks vars 'singles)
            collect `(remove-hook ',hook #',fn))))


;;; ** Definers

(defmacro defadvice! (symbol arglist &optional docstring &rest body)
  "Define an advice called SYMBOL and add it to PLACES.

ARGLIST is as in `defun'. WHERE is a keyword as passed to `advice-add', and
PLACE is the function to which to add the advice, like in `advice-add'.
DOCSTRING and BODY are as in `defun'.

\(fn SYMBOL ARGLIST &optional DOCSTRING &rest [WHERE PLACES...] BODY\)"
  (declare (doc-string 3) (indent defun))
  (unless (stringp docstring)
    (push docstring body)
    (setq docstring nil))
  (let (where-alist)
    (while (keywordp (car body))
      (push `(cons ,(pop body) (ensure-list ,(pop body)))
            where-alist))
    `(progn
       (defun ,symbol ,arglist ,docstring ,@body)
       (dolist (targets (list ,@(nreverse where-alist)))
         (dolist (target (cdr targets))
           (advice-add target (car targets) #',symbol))))))

(defmacro undefadvice! (symbol _arglist &optional docstring &rest body)
  "Undefine an advice called SYMBOL.

This has the same signature as `defadvice!' and exists as an easy undefiner when
interactively testing (and toggling) advice.

\(fn SYMBOL ARGLIST &optional DOCSTRING &rest [WHERE PLACES...] BODY\)"
  (declare (doc-string 3) (indent defun))
  (let (where-alist)
    (unless (stringp docstring)
      (push docstring body))
    (while (keywordp (car body))
      (push `(cons ,(pop body) (ensure-list ,(pop body)))
            where-alist))
    `(dolist (targets (list ,@(nreverse where-alist)))
       (dolist (target (cdr targets))
         (advice-remove target #',symbol)))))


;;; ** `doom-context'

(defvar doom-context '(t)
  "A list of symbols identifying all active Doom execution contexts.

This should never be directly changed, only let-bound, and should never be
empty. Each context describes what phase Doom is in, and may respond to.

Use `with-doom-context' instead of let-binding or setting this variable
directly.

All valid contexts:
  cli        -- executing a Doom CLI or doomscript
  emacs      -- in an interactive doom session
  module     -- loading any modules' elisp files

  Universal sub-contexts:
    compile    -- byte-compiling elisp
    startup    -- while doom is starting up, before any user config
    error      -- while Doom is in an error state

  `emacs' sub-contexts:
    docs       -- while rendering docs in `doom-docs-mode'
    reload     -- while reloading doom with `doom/reload'
    sandbox    -- this session was launched from Doom's sandbox
    eval       -- while interactively evaluating elisp

  `module' sub-contexts:
    external   -- loading packages or modules outside of $EMACSDIR or $DOOMDIR
    config     -- loading a module's config.el or cli.el
    doctor     -- loading a module's doctor.el
    init       -- loading a module's init.el
    package    -- loading a module's packages.el or managing packages
    source     -- while initializing a module source
    test       -- preparing for or running Doom's unit tests

  `cli' sub-contexts:
    run        -- running a CLI command")
(put 'doom-context 'valid
     '(compile error startup emacs docs reload sandbox eval module external
       config doctor init package test cli run))
(put 'doom-context 'risky-local-variable t)

(defun doom-context-p (contexts)
  "Return non-nil if all CONTEXTS are active.

See `doom-context' for possible values for CONTEXT."
  (declare (side-effect-free t))
  (catch 'result
    (let (result)
      (dolist (context (ensure-list contexts) result)
        (if (memq context doom-context)
            (push context result)
          (throw 'result nil))))))

(defun doom-context-valid-p (context)
  "Return non-nil if CONTEXT (a symbol) is a valid `doom-context'."
  (declare (pure t) (side-effect-free error-free))
  (memq context (get 'doom-context 'valid)))

(defun doom-context-push (contexts)
  "Add CONTEXTS (a symbol or list thereof) to `doom-context', if not present.

Return list of successfully added contexts. Throws a `doom-context-error' if
CONTEXTS contains invalid contexts."
  (let ((contexts (ensure-list contexts)))
    (if (cl-loop for context in contexts
                 unless (doom-context-valid-p context)
                 return t)
        (signal 'doom-context-error
                (list (cl-remove-if #'doom-context-valid-p contexts)
                      "Unrecognized context(s)"))
      (let (added)
        (dolist (context contexts)
          (unless (memq context doom-context)
            (push context added)))
        (when added
          (setq doom-context (nconc added doom-context))
          (doom-log 3 ":context: +%s %s" added doom-context)
          added)))))

(defun doom-context-pop (contexts)
  "Remove CONTEXTS (a symbol or list thereof) from `doom-context'.

Return list of removed contexts if successful. Throws `doom-context-error' if
one of CONTEXTS isn't active."
  (if (not (doom-context-p contexts))
      (signal 'doom-context-error
              (list "Attempt to pop missing context"
                    contexts doom-context))
    (let ((current-context (copy-sequence doom-context))
          removed)
      (dolist (context (ensure-list contexts))
        (setq current-context (delq context current-context))
        (push context removed))
      (when removed
        (setq doom-context current-context)
        (doom-log 3 ":context: -%s %s" removed doom-context)
        removed))))

(defmacro with-doom-context (contexts &rest body)
  "Evaluate BODY with CONTEXTS added to `doom-context'."
  (declare (indent 1))
  `(let ((doom-context doom-context))
     (doom-context-push ,contexts)
     ,@body))

(provide 'doom-lib)
;;; doom-lib.el ends here
