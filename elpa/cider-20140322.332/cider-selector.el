;;; cider-selector.el --- Buffer selection command inspired by SLIME's selector -*- lexical-binding: t -*-

;; Copyright © 2012-2014 Tim King, Phil Hagelberg
;; Copyright © 2013-2014 Bozhidar Batsov, Hugo Duncan, Steve Purcell
;;
;; Author: Tim King <kingtim@gmail.com>
;;         Phil Hagelberg <technomancy@gmail.com>
;;         Bozhidar Batsov <bozhidar@batsov.com>
;;         Hugo Duncan <hugo@hugoduncan.org>
;;         Steve Purcell <steve@sanityinc.com>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Buffer selection command inspired by SLIME's selector.

;;; Code:

(require 'cider-client)
(require 'cider-interaction)
(require 'cider-repl) ; for cider-find-or-create-repl-buffer

(defconst cider-selector-help-buffer "*Selector Help*"
  "The name of the selector's help buffer.")

(defvar cider-selector-methods nil
  "List of buffer-selection methods for the `cider-selector' command.
Each element is a list (KEY DESCRIPTION FUNCTION).
DESCRIPTION is a one-line description of what the key selects.")

(defvar cider-selector-other-window nil
  "If non-nil use `switch-to-buffer-other-window'.")

(defun cider--recently-visited-buffer (mode)
  "Return the most recently visited buffer whose `major-mode' is MODE.
Only considers buffers that are not already visible."
  (loop for buffer in (buffer-list)
        when (and (with-current-buffer buffer (eq major-mode mode))
                  (not (string-match "^ " (buffer-name buffer)))
                  (null (get-buffer-window buffer 'visible)))
        return buffer
        finally (error "Can't find unshown buffer in %S" mode)))

;;;###autoload
(defun cider-selector (&optional other-window)
  "Select a new buffer by type, indicated by a single character.
The user is prompted for a single character indicating the method by
which to choose a new buffer.  The `?' character describes then
available methods.  OTHER-WINDOW provides an optional target.

See `def-cider-selector-method' for defining new methods."
  (interactive)
  (message "Select [%s]: "
           (apply #'string (mapcar #'car cider-selector-methods)))
  (let* ((cider-selector-other-window other-window)
         (ch (save-window-excursion
               (select-window (minibuffer-window))
               (read-char)))
         (method (cl-find ch cider-selector-methods :key #'car)))
    (cond (method
           (funcall (cl-caddr method)))
          (t
           (message "No method for character: ?\\%c" ch)
           (ding)
           (sleep-for 1)
           (discard-input)
           (cider-selector)))))

(defmacro def-cider-selector-method (key description &rest body)
  "Define a new `cider-select' buffer selection method.

KEY is the key the user will enter to choose this method.

DESCRIPTION is a one-line sentence describing how the method
selects a buffer.

BODY is a series of forms which are evaluated when the selector
is chosen.  The returned buffer is selected with
`switch-to-buffer'."
  (let ((method `(lambda ()
                   (let ((buffer (progn ,@body)))
                     (cond ((not (get-buffer buffer))
                            (message "No such buffer: %S" buffer)
                            (ding))
                           ((get-buffer-window buffer)
                            (select-window (get-buffer-window buffer)))
                           (cider-selector-other-window
                            (switch-to-buffer-other-window buffer))
                           (t
                            (switch-to-buffer buffer)))))))
    `(setq cider-selector-methods
           (cl-sort (cons (list ,key ,description ,method)
                          (cl-remove ,key cider-selector-methods :key #'car))
                  #'< :key #'car))))

(def-cider-selector-method ?? "Selector help buffer."
  (ignore-errors (kill-buffer cider-selector-help-buffer))
  (with-current-buffer (get-buffer-create cider-selector-help-buffer)
    (insert "CIDER Selector Methods:\n\n")
    (loop for (key line nil) in cider-selector-methods
          do (insert (format "%c:\t%s\n" key line)))
    (goto-char (point-min))
    (help-mode)
    (display-buffer (current-buffer) t))
  (cider-selector)
  (current-buffer))

(pushnew (list ?4 "Select in other window" (lambda () (cider-selector t)))
         cider-selector-methods :key #'car)

(def-cider-selector-method ?c
  "Most recently visited clojure-mode buffer."
  (cider--recently-visited-buffer 'clojure-mode))

(def-cider-selector-method ?e
  "Most recently visited emacs-lisp-mode buffer."
  (cider--recently-visited-buffer 'emacs-lisp-mode))

(def-cider-selector-method ?q "Abort."
  (top-level))

(def-cider-selector-method ?r
  "Current REPL buffer."
  (cider-find-or-create-repl-buffer))

(def-cider-selector-method ?n
  "Connections browser buffer."
  (nrepl-connection-browser)
  nrepl--connection-browser-buffer-name)

(def-cider-selector-method ?v
  "*nrepl-events* buffer."
  nrepl-event-buffer-name)

(def-cider-selector-method ?s
 "Cycle to the next CIDER connection's REPL."
 (cider-rotate-connection)
 (cider-find-or-create-repl-buffer))

(provide 'cider-selector)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; cider-selector.el ends here
