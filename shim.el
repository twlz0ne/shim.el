;;; shim.el --- Emacs integration for Xenv -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Gong Qijian <gongqijian@gmail.com>

;; Author: Gong Qijian <gongqijian@gmail.com>
;; Created: 2018/12/25
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.4"))
;; URL: https://github.com/twlz0ne/shim
;; Keywords: environment, tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Emacs integration for Xenv.
;; See more at README.md

;;; Change Log:

;;  0.1.0  2018/12/25  Initial version.

;;; Code:

(require 'cl)

(define-error 'shim-error "Shim error" 'error)

(cl-defstruct shim--shim ()
              language
              major-modes
              executable
              (built-in-version "system" :read-only t))

(defvar shim--shims '()
  "Alist id -> shim--shim.
It contains all of the shim--shim instances that are currently regitered.")

(defun shim--guess-language ()
  "Guess language of current buffer."
  (catch 'found
    (mapc (lambda (pair)
            (when (memq major-mode (shim--shim-major-modes (cdr pair)))
              (throw 'found (car pair))))
          shim--shims)
    (signal 'shim-error (list (format "Not support `%s'" major-mode)))))

(defun shim-version (&optional language)
  "Show currently active version of LANGUAGE."
  (let* ((language (or language (shim--guess-language)))
         (entity (cdr (assq language shim--shims)))
         (basename (file-name-base (shim--shim-executable entity))))
    (getenv (upcase (concat basename  "_version")))))

(defun shim-versions (&optional language)
  "List installed versions of LANGUAGE."
  (let ((language (or language (shim--guess-language))))
    (cons "system"
          (split-string
           (shell-command-to-string
            (format "%s versions --bare"
                    (shim--shim-executable (cdr (assq language shim--shims)))))))))

(defun shim-read-version (&optional language)
  "Read virtual environment from user input for LANGUAGE."
  (completing-read
   "Version: "
   (shim-versions (or language (shim--guess-language)))))

(defun shim-version-file (&optional language dir)
  "Lookup `.<LANGUAGE>-version' from DIR or current folder."
  (let* ((language (or language (shim--guess-language)))
         (ver-file (downcase (format ".%s-version" language)))
         (file-dir (locate-dominating-file (or dir default-directory) ver-file)))
    (when file-dir
      (concat file-dir ver-file))))

(defun shim-local-variable (&optional language)
  "Return file local shim variable for LANGUAGE."
  (let* ((language (or language (shim--guess-language)))
         (symbol (intern (downcase (format "shim-%s-version" language)))))
    symbol))

;;;###autoload
(defun shim-unset (&optional language)
  "Unset version of LANGUAGE."
  (interactive)
  (let* ((language (or language (shim--guess-language)))
         (entity (cdr (assq language shim--shims)))
         (basename (file-name-base (shim--shim-executable entity))))
    (setenv (upcase (concat basename  "_version")))
    (force-mode-line-update)))

;;;###autoload
(defun shim-set (version &optional language)
  "Set VERSION of LANGUAGE."
  (interactive (list (shim-read-version)))
  (let* ((language (or language (shim--guess-language)))
         (entity (cdr (assq language shim--shims)))
         (basename (file-name-base (shim--shim-executable entity))))
    (setenv (upcase (concat basename  "_version")) version)
    (force-mode-line-update)))

;;;###autoload
(defun shim-auto-set (&optional language)
  "Auto set VERSION of LANGUAGE."
  (interactive)
  (let* ((language (or language (shim--guess-language)))
         (file-local-version (symbol-value (shim-local-variable language))))
    (shim-set
     (or file-local-version
         (let ((ver-file (shim-version-file language)))
           (if ver-file
               (replace-regexp-in-string
                "\\(?:\n\\)\\'" "" (shell-command-to-string (format "head -n 1 %s" ver-file)))
             (car (reverse (shim-versions language))))))
     language)))

(defmacro shim-register-mode (language mode)
  "Registers major MODE to LANGUAGE.

\(fn 'example-lang 'example-mode)"
  (gv-letplace (getter setter) `(shim--shim-major-modes (cdr (assq ,language shim--shims)))
    `(unless (memq ,mode ,getter)
       (funcall ,setter (push ,mode ,getter)))))

(defun shim-init (shim)
  "Registers shim--shim instance SHIM."
  (let ((language (shim--shim-language shim)))
    (unless (cdr (assq language shim--shims))
      (let* ((abs-path (executable-find (shim--shim-executable shim)))
             (exe-name (file-name-base abs-path)))
        (eval
         `(defvar ,(intern (format "shim-%s-version" language)) nil))
        (add-to-list 'exec-path (expand-file-name (format "~/.%s/shims" exe-name)))
        (add-to-list 'shim--shims (cons language shim))))))

(defcustom shim-mode-line
  '(:eval
    (let ((language (shim--guess-language)))
      (when (shim-version language)
        (format " %s:%s"
                (capitalize
                 (file-name-base
                  (shim--shim-executable (cdr (assq language shim--shims)))))
                (shim-version language)))))
  "How ‘shim’ will indicate the current language version in the mode line."
  :group 'shim
  :type 'sexp
  :risky t
  :package-version '(shim . "0.1.0"))

(defvar shim-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-s") 'shim-set)
    (define-key map (kbd "C-c C-u") 'shim-unset)
    map))

(define-minor-mode shim-mode ""
  :global nil
  :lighter shim-mode-line
  :keymap shim-mode-map
  (if shim-mode
      (shim-auto-set)
    (shim-unset)))

(cl-defun shim-init-java (&key (major-modes '(java-mode)) (executable "jenv"))
  (shim-init
   (make-shim--shim
    :language 'java
    :major-modes major-modes
    :executable executable)))

(cl-defun shim-init-node (&key (major-modes '(js-mode)) (executable "nodenv"))
  (shim-init
   (make-shim--shim
    :language 'node
    :major-modes major-modes
    :executable executable)))

(cl-defun shim-init-python (&key (major-modes '(python-mode)) (executable "pyenv"))
  (shim-init
   (make-shim--shim
    :language 'python
    :major-modes major-modes
    :executable executable)))

(cl-defun shim-init-ruby (&key (major-modes '(ruby-mode)) (executable "rbenv"))
  (shim-init
   (make-shim--shim
    :language 'ruby
    :major-modes major-modes
    :executable executable)))

(provide 'shim)

;;; shim.el ends here
