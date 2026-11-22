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

(require 'backtrace)
(require 'seq)
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

(defvar morning-ritual-errors
  (expand-file-name (format "morning_ritual_errors_%s.txt" (system-name))
                    (or (bound-and-true-p org-logs-directory) temporary-file-directory))
  "Where a failed ritual command is described, with its backtrace.")

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
      (morning-ritual--run-command command))))

(defvar morning-ritual--trace nil
  "Where the last error was raised, as `morning-ritual--keep-trace' kept it.")

(defun morning-ritual--keep-trace (_err)
  "Keep the backtrace from here down: the first line under this one is
where the error was raised.  Long lines and deep stacks are cut short."
  (setq morning-ritual--trace
        (mapconcat (lambda (line) (truncate-string-to-width line 300))
                   (seq-take (split-string (backtrace-to-string
                                            (backtrace-get-frames #'morning-ritual--keep-trace))
                                           "\n" t)
                             40)
                   "\n")))

(defun morning-ritual--run-command (command)
  "Run COMMAND; if it fails, say so and keep why in `morning-ritual-errors'.
It runs with nobody watching, so what went wrong is kept, backtrace and all."
  (setq morning-ritual--trace nil)
  (condition-case err
      (handler-bind ((error #'morning-ritual--keep-trace))
        (usage-log-call "morning" command))
    (error
     (message "Morning ritual: %s failed: %s" command (error-message-string err))
     (with-demoted-errors "morning ritual log: %S"
       (write-region (format "%s\t%s\t%S\n%s\n" (format-time-string "%F %T") command err
                             (or morning-ritual--trace ""))
                     nil morning-ritual-errors t 'silent)))))

;;;; hackernews

;; hackernews merges the visited links it saved into its tables the first
;; time it runs in a session.  An entry it can't merge -- one without its
;; table, `((hackernews-link) ...)' -- fails that first run, which is the
;; morning's, with "hash-table-p, nil"; the tables are made by then, so a
;; second run skips the file and works.  The file is only saved again after
;; a run that got past it, so it stays as it is.  Merge only what can be.

(defvar hackernews--visited-ids)

(defun morning-ritual--mergeable-visited-links (links)
  "LINKS, read from hackernews's file, without what it can't merge:
each entry must be (TYPE . TABLE) for a TYPE it keeps."
  (seq-filter (lambda (entry)
                (and (consp entry)
                     (assq (car entry) hackernews--visited-ids)
                     (hash-table-p (cdr entry))))
              (and (proper-list-p links) links)))

(with-eval-after-load 'hackernews
  (advice-add 'hackernews--read-visited-links :filter-return
              #'morning-ritual--mergeable-visited-links))

(provide 'morning-ritual)
;;; morning-ritual.el ends here
