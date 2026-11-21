;;; morning-ritual.el --- What the first unlock of the day opens -*- lexical-binding: t -*-

;;; Commentary:
;; The phone's first unlock from 3am on runs `morning-ritual-commands', in
;; order: for now Hacker News.  The Emacs Home app asks
;; `morning-ritual-due-p' on every unlock and, when the answer is t, brings
;; Emacs forward and calls `morning-ritual-run'.  A Home press counts too,
;; for an unlock the app missed (while it was restarting, say).
;;
;; Once a day: the day it last ran is kept in `morning-ritual-file', so an
;; Emacs restarted later that day does not run it again.

;;; Code:

(require 'subr-x)
(require 'usage-log)

(defvar morning-ritual-commands '(hackernews)
  "Commands the first unlock of the day runs, in order.")

(defvar morning-ritual-from 3
  "Hour the morning starts: the first unlock from then on runs the ritual.")

(defvar morning-ritual-file
  (expand-file-name "morning-ritual"
                    (or (bound-and-true-p doom-data-dir) user-emacs-directory))
  "Holds the day the ritual last ran, as YYYY-MM-DD.")

(defun morning-ritual--day (&optional time)
  "The day at TIME (default now), turning at `morning-ritual-from'."
  (format-time-string "%F" (time-subtract (or time (current-time))
                                          (* 3600 morning-ritual-from))))

(defun morning-ritual--last ()
  "The day the ritual last ran, or nil."
  (when (file-readable-p morning-ritual-file)
    (with-temp-buffer
      (insert-file-contents morning-ritual-file)
      (string-trim (buffer-string)))))

(defun morning-ritual-due-p ()
  "Non-nil when today's ritual has not run yet."
  (not (equal (morning-ritual--last) (morning-ritual--day))))

(defun morning-ritual-run (&optional force)
  "Run today's ritual unless it has already run; with FORCE, run it anyway.
Interactively, it always runs."
  (interactive (list t))
  (when (or force (morning-ritual-due-p))
    ;; Marked first: an unlock and a Home press a moment apart run it once.
    (make-directory (file-name-directory morning-ritual-file) t)
    (with-temp-file morning-ritual-file (insert (morning-ritual--day) "\n"))
    ;; The app calls in through emacsclient's process filter: get out of it.
    (run-at-time 0 nil #'morning-ritual--open)
    t))

(defun morning-ritual--open (&optional tries)
  "Run each of `morning-ritual-commands', once a question left open is closed.
TRIES counts the questions closed so far."
  (if (and (active-minibuffer-window) (< (or tries 0) 3))
      ;; As a Home press does.  The abort throws out of this timer, so the
      ;; commands come in one of their own, after it.
      (progn (run-at-time 0 nil #'morning-ritual--open (1+ (or tries 0)))
             (abort-recursive-edit))
    (dolist (command morning-ritual-commands)
      (with-demoted-errors "morning ritual: %S"
        (usage-log-call "morning" command)))))

(provide 'morning-ritual)
;;; morning-ritual.el ends here
