;;; test-nodeshim.el --- Test nodeshim -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Gong QiJian <gongqijian@gmail.com>

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

;;; Code:

(require 'cl)
(require 'ert)
(require 'shim)

(setq debug-on-error t)
(shim-init-node :major-modes '())
(shim-register-mode 'node 'js-mode)
(assert (boundp 'shim-node-version))
(assert (equal '(js-mode) (shim--shim-major-modes (cdr (assq 'node shim--shims)))))

(defun test-nodeshim--make-project (specs)
  "Make empty project and create directory & files specified by SPECS.
Example of SPECS:

        '(\"src/\"
          (\"src/.node-version\" . \"6.0.0\"))

Return project root."
  (let ((root (make-temp-file "test-nodeshim--" 'root "/")))
    (dolist (spec specs)
      (cond
       ((consp spec)
        (let ((file-path (concat root (car spec)))
              (file-content (cdr spec)))
          (make-directory (file-name-directory file-path) t)
          (with-temp-buffer
            (insert file-content)
            (write-region (point-min) (point-max) file-path))))
       (t
        (let ((folder-path (concat root spec)))
          (make-directory (file-name-directory folder-path) t)))))
    root))

(defun test-nodeshim--global-version (mode)
  "Get global version of node."
  (let ((major-mode mode))
    (or (shim--version-from-file (shim-version-file 'node))
        (car (reverse (shim-versions 'node))))))

(defun test-nodeshim--open-file (file-name &optional defer-p)
  "Open file `FILE-NAME', return node version if `DEFER-P' is nil (the default)."
  (setq enable-local-variables :all)
  (find-file file-name)
  (js-mode)
  (unless defer-p
    (shim-auto-set)
    (getenv "NODENV_VERSION")))

(defun test-nodeshim--file-buffer (file-name)
  "Open file `FILE-NAME', retun buffer."
  (setq enable-local-variables :all)
  (save-excursion
    (find-file file-name)
    (current-buffer)))

(defmacro test-nodeshim--with-shim-on (buf &rest body)
  (declare (indent defun) (debug t))
  `(with-current-buffer ,buf
     (shim-mode 1)
     ,@body))

(defmacro test-nodeshim--with-shim-off (buf &rest body)
  (declare (indent defun) (debug t))
  `(with-current-buffer ,buf
     (shim-mode -1)
     ,@body))

(ert-deftest test-nodeshim-node-version-file-0 ()
  (let ((root (test-nodeshim--make-project '(("test.js" . "\n")))))
    (should (equal (test-nodeshim--global-version 'js-mode)
                   (test-nodeshim--open-file (concat root "test.js"))))))

(ert-deftest test-nodeshim-node-version-file-1 ()
  (let ((root (test-nodeshim--make-project '(("test.js" . "\n")
                                           (".node-version" . "6.0.0")))))
    (should (equal "6.0.0"
                   (test-nodeshim--open-file (concat root "test.js"))))))

(ert-deftest test-nodeshim-node-version-file-2 ()
  (let ((root (test-nodeshim--make-project '(("test1.js" . "\n")
                                           (".node-version" . "6.0.0")
                                           ("src/test2.js" . "\n")
                                           ("src/.node-version" . "7.0.0")))))
    (should (equal "6.0.0" (test-nodeshim--open-file (concat root "test1.js"))))
    (should (equal "7.0.0" (test-nodeshim--open-file (concat root "src/test2.js"))))))

(ert-deftest test-nodeshim-node-version-file-3 ()
  (let ((root (test-nodeshim--make-project '(("foo/test1.js" . "\n")
                                           ("foo/.node-version" . "6.0.0")
                                           ("bar/test2.js" . "\n")
                                           ("bar/.node-version" . "7.0.0")))))
    (should (equal "6.0.0" (test-nodeshim--open-file (concat root "foo/test1.js"))))
    (should (equal "7.0.0" (test-nodeshim--open-file (concat root "bar/test2.js"))))))

(ert-deftest test-nodeshim/make-process-environment ()
  (let* ((root (test-nodeshim--make-project '(("foo/test1.js" . "\n")
                                              ("foo/.node-version" . "6.0.0")
                                              ("bar/test2.js" . "\n")
                                              ("bar/.node-version" . "7.0.0")))))
    (test-nodeshim--with-shim-on (test-nodeshim--file-buffer (concat root "foo/test1.js"))
      (test-nodeshim--with-shim-on (test-nodeshim--file-buffer (concat root "bar/test2.js"))
        (should (equal "7.0.0" (getenv "NODENV_VERSION"))))
      (should (equal "6.0.0" (getenv "NODENV_VERSION"))))))

(ert-deftest test-nodeshim/kill-process-environment ()
  (let* ((root (test-nodeshim--make-project '(("foo/test1.js" . "\n")
                                              ("foo/.node-version" . "6.0.0")
                                              ("bar/test2.js" . "\n")
                                              ("bar/.node-version" . "7.0.0"))))
         (buf1 (test-nodeshim--file-buffer (concat root "foo/test1.js")))
         (buf2 (test-nodeshim--file-buffer (concat root "bar/test2.js"))))
    (with-current-buffer buf1
      (let ((global-env (getenv "NODENV_VERSION")))
        (should (equal "6.0.0"    (test-nodeshim--with-shim-on  buf1 (getenv "NODENV_VERSION"))))
        (should (equal global-env (test-nodeshim--with-shim-off buf1 (getenv "NODENV_VERSION"))))))
    (with-current-buffer buf2
      (let ((global-env (getenv "NODENV_VERSION")))
        (should (equal "7.0.0"    (test-nodeshim--with-shim-on  buf2 (getenv "NODENV_VERSION"))))
        (should (equal global-env (test-nodeshim--with-shim-off buf2 (getenv "NODENV_VERSION"))))))))

(ert-deftest test-nodeshim-local-version ()
  (let ((root (test-nodeshim--make-project
               (list (cons ".node-version" "6.0.0")
                     (cons "test-without-local-variable.js" "\n")
                     (cons "test-with-local-variable.js" (concat
                                                          "// Local Variables:\n"
                                                          "// shim-node-version: \"7.0.0\"\n"
                                                          "// End:\n"))))))
    ;; Use node version specified in .node-version
    (should (equal "6.0.0" (test-nodeshim--open-file (concat root "test-without-local-variable.js"))))

    ;; Use node version specified by local variable
    (add-hook 'hack-local-variables-hook
              (lambda ()
                (when shim-node-version
                  (shim-auto-set)
                  (should (equal "7.0.0" (shim-version))))))
    (test-nodeshim--open-file (concat root "test-with-local-variable.js") t)
    ))

(defun test-nodeshim--read-version-from-file (file)
  "Read version from FILE."
  (when (file-exists-p file)
    (replace-regexp-in-string
     "\\(?:\n\\)\\'" "" (shell-command-to-string (format "head -n 1 %s" file)))))

(ert-deftest test-nodeshim-get-version-in-temp-buffer ()
  (let ((global-ver (or (test-nodeshim--read-version-from-file "~/.node-version")
                        (test-nodeshim--global-version 'js-mode))))
    (should
     (equal
      global-ver
      (with-temp-buffer
        (js-mode)
        (shim-auto-set)
        (shim-version)
        )))
    ))

(ert-deftest test-init-error ()
  (should (equal '(shim-error "foo: command not found")
                 (condition-case err
                     (shim-init
                      (make-shim--shim
                       :language 'foo
                       :major-modes '(foo-mode)
                       :executable "foo"))
                   (shim-error err)))))

(provide 'test-nodeshim)

;;; test-nodeshim.el ends here
