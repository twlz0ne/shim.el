[![Build Status](https://travis-ci.com/twlz0ne/shim.el.svg?branch=master)](https://travis-ci.com/twlz0ne/shim.el)

## shim.el

Emacs integration for Xenv.

## Installation

Clone this repository, or install from MELPA. Add the following to your `.emacs`:

```elisp
(add-to-list 'load-path (expand-file-name "~/.emacs.d/site-lisp/shim"))
(require 'shim)
(shim-init-ruby)
(shim-init-python)
(shim-init-node)
(shim-init-java)
(shim-init-go)
```

## Usage

### Basic

Invoke function manually:

- i ) `M-x shim-set` input version or select from list.
- ii) `M-x shim-auto-set` auto detect version.

Or add to major mode hook:

```elisp
(add-hook 'js-mode-hook #'shim-mode)
```

If you would like specific version by file local variable (`M-x shim-add-file-local-version`):

```javascript
...
// Local Variables:
// shim-node-version: "8.11.3"
// End:
```

Then you have to add following instead:

```diff
-(add-hook 'js-mode-hook #'shim-mode)
+(add-hook 'hack-local-variables-hook
+          (lambda ()
+            (when (ignore-errors (shim--guess-language))
+              (shim-mode 1))))
```

There is also a `shim-add-dir-local-version` function for user to set dir local variable.

### Extended

Add support for new mode:

```elisp
(shim-register-mode 'node 'js2-mode)

;; or registers all modes at initialization
(shim-init-node :major-modes
                '(js-mode
                  js2-mode
                  rjsx-mode))
```

Add support for new language:

```elisp
(cl-defun shim-init-foo (&key (major-modes '(foo-mode)) (executable "fooenv"))
  (shim-init
   (make-shim--shim
    :language 'foo
    :major-modes major-modes
    :executable executable)))
```
