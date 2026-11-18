;;; voice-home.el --- Voice: the toolbar's buttons and the homepage's tiles -*- lexical-binding: t -*-

;;; Commentary:
;; Each is an action already, by its label.

;;; Code:

(require 'voice-core)

(defun voice--toolbar-actions ()
  "The toolbar's command buttons as actions, by label, shown when the
button is."
  (when (boundp 'tool-bar-map)
    (let (out)
      (map-keymap
       (lambda (_key def)
         (when (and (eq (car-safe def) 'menu-item)
                    (stringp (nth 1 def))
                    (symbolp (nth 2 def)) (commandp (nth 2 def))
                    (not (get (nth 2 def) 'voice-skip))
                    (not (voice--denied-p (nth 2 def))))
           (let* ((props (nthcdr 3 def))
                  (visible (plist-get props :visible)))
             (push (list :name (nth 1 def) :phrases (list (nth 1 def))
                         :patterns (list (voice--pattern (nth 1 def)))
                         :run (nth 2 def) :source 'toolbar
                         :when (and visible (lambda () (eval visible t))))
                   out))))
       (default-value 'tool-bar-map))
      out)))

(defun voice--homepage-actions ()
  "The homepage's tiles as actions, by title."
  (when (fboundp 'android-homepage--sections)
    (let (out)
      (dolist (section (ignore-errors (android-homepage--sections)))
        (dolist (item (cadr section))
          (let ((cmd (plist-get item :action)) (title (plist-get item :title)))
            (when (and (symbolp cmd) (commandp cmd) (stringp title)
                       (not (voice--denied-p cmd)))
              (push (list :name title :phrases (list title)
                          :patterns (list (voice--pattern title))
                          :run cmd :source 'homepage)
                    out)))))
      out)))

(defun voice--home-vocab ()
  "The phone's apps by name, and the toolbar's and homepage's labels."
  (append (and (fboundp 'emacs-home--apps) (mapcar #'car (emacs-home--apps)))
          (mapcar (lambda (a) (plist-get a :name))
                  (append (voice--toolbar-actions) (voice--homepage-actions)))))

(defvar voice--app-index nil "(APPS . INDEX) of the phone's apps by name.")

(defun voice--app-index ()
  "The phone's apps, indexed by name as tasks are; nil without any."
  (let ((apps (and (fboundp 'emacs-home--apps) (emacs-home--apps))))
    (when apps
      (unless (equal (car voice--app-index) apps)
        (setq voice--app-index
              (cons apps (voice-match-index (mapcar (lambda (a) (list :title (car a))) apps)))))
      (cdr voice--app-index))))

(defun voice--app-slot-plan (text action slot _request)
  "The plan for ACTION, whose … names an app (\"open …\"): weighed against
the phone's apps as a task name is against the tasks.  Named clearly, it
opens; else the phrase can give way to an option nearer (\"open magit\" is
the command), and failing that the app list opens with the words typed."
  (let* ((index (and slot (not (string-empty-p slot)) (voice--app-index)))
         (ranked (and index (voice-match-rank index slot 5)))
         (decision (if ranked (voice-match-decide ranked) 'none)))
    (list :kind 'action :text text :action action
          :slot (if (eq decision 'act) (plist-get (nth 2 (car ranked)) :title) slot)
          :decision decision :found (if ranked (nth 1 (car ranked)) 0.0)
          :front (not (eq decision 'act)))))

(voice-define-domain 'home
  :doc "The toolbar's buttons and the homepage's tiles, by their labels."
  :vocab #'voice--home-vocab
  :slots '((app . voice--app-slot-plan))
  :actions (lambda (_context) (append (voice--toolbar-actions) (voice--homepage-actions))))

(provide 'voice-home)
;;; voice-home.el ends here
