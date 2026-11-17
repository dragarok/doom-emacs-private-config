;;; archive-done.el --- Done tasks leave the agenda files -*- lexical-binding: t -*-

;;; Commentary:
;; A finished task stays where it is for the rest of the day it was closed,
;; then goes to the archive.  When the daily review is written (day-log.el),
;; every DONE or CANCELED task closed before that day moves out of
;; `archive-done-files' into archive/archive.org, under the day it was
;; closed.  agents.org is the Mac's to write (agent-time.el): the Mac does
;; the same there, into archive/archive_agents.org, once it sees the review
;; written.  Two writers never share a file, so Syncthing has nothing to
;; conflict on.
;;
;; A task stays put while anything under it is still open, while a clock
;; runs in it, or while it holds a timestamp of today or later (a clock, a
;; note, an agent's run): today's facts and the agents block read today
;; from these files.  Reports over past days read the archives too
;; (clocktables with agenda-with-archives, `org-summary--files').
;;
;; A file changed on disk is reread first.  One that changed on disk while
;; it also has unsaved edits here is left alone: never save over a sync.
;;
;; `archive-done' runs it by hand, for the files and any day.

;;; Code:

(require 'org)
(require 'org-archive)
(require 'cl-lib)
(require 'subr-x)

(defvar day-log-day-starts)

(defvar archive-done-files '("tasks.org" "projects.org" "inbox.org" "ideas.org")
  "Agenda files, by name, whose done tasks are archived after the review.
Not the logs (books read and things watched are records), not
recurring.org, and not agents.org, which agent-time.el archives itself.")

(defun archive-done-today ()
  "Today, YYYY-MM-DD, turning when the day log's day does (4am)."
  (format-time-string "%F" (time-subtract nil (* 3600 (or (bound-and-true-p day-log-day-starts) 4)))))

(defun archive-done--fresh ()
  "Bring the current buffer up to date with its file.  Nil if it can't be:
it has unsaved edits and the file changed on disk too."
  (cond ((or (not buffer-file-name) (verify-visited-file-modtime)
             (not (file-exists-p buffer-file-name)))
         t)
        ((buffer-modified-p) nil)
        (t (revert-buffer t t t) t)))

(defun archive-done--closed ()
  "The heading at point's CLOSED date, YYYY-MM-DD, or nil."
  (save-excursion
    (forward-line)
    (and (looking-at org-planning-line-re)
         (re-search-forward (concat org-closed-string
                                    " *\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)")
                            (line-end-position) t)
         (match-string-no-properties 1))))

(defun archive-done--archivable-p (before)
  "Non-nil if the heading at point is done, was closed before BEFORE
\(YYYY-MM-DD), and nothing under it is open, clocking, or dated BEFORE or later."
  (when-let* (((member (org-get-todo-state) org-done-keywords))
              (closed (archive-done--closed))
              ((string< closed before)))
    (let ((end (save-excursion (org-end-of-subtree t t))) (ok t))
      (save-excursion
        (end-of-line)
        (while (and ok (re-search-forward org-outline-regexp-bol end t))
          (when (member (org-get-todo-state) org-not-done-keywords) (setq ok nil))
          (end-of-line)))
      (save-excursion
        (when (re-search-forward "^[ \t]*CLOCK: \\[[^]\n]+\\][ \t]*$" end t)
          (setq ok nil)))
      (save-excursion
        (while (and ok (re-search-forward "\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)[] ]" end t))
          (unless (string< (match-string 1) before) (setq ok nil))))
      ok)))

(defun archive-done--collect (before keep)
  "Markers of the topmost archivable headings in the buffer, last first.
KEEP, if non-nil, is called on each and keeps it where it is if non-nil."
  (let (out)
    (org-with-wide-buffer
     (goto-char (point-min))
     (while (re-search-forward org-outline-regexp-bol nil t)
       (beginning-of-line)
       (if (and (archive-done--archivable-p before)
                (not (and keep (funcall keep))))
           (progn (push (point-marker) out)
                  (org-end-of-subtree t t))
         (end-of-line))))
    out))

(defun archive-done--archive-buffers ()
  "Buffers of the current buffer's archive files that are open."
  (delq nil (mapcar #'find-buffer-visiting
                    (cons (car (org-archive--compute-location org-archive-location))
                          (ignore-errors (org-all-archive-files))))))

(defun archive-done--save (buffers)
  (let ((save-silently t) (inhibit-message t))
    (dolist (b (delete-dups buffers))
      (when (and (buffer-live-p b) (buffer-modified-p b))
        (with-current-buffer b (save-buffer))))))

(defun archive-done-buffer (before &optional keep)
  "Archive the current buffer's done tasks closed before BEFORE and save.
KEEP is as for `archive-done--collect'.  Return how many went, or nil if
the buffer or its archive changed on disk under unsaved edits."
  (let ((archives (archive-done--archive-buffers)))
    (when (and (archive-done--fresh)
               (cl-every (lambda (b) (with-current-buffer b (archive-done--fresh))) archives))
      (let ((markers (archive-done--collect before keep)) (n 0))
        (when markers
          ;; Archiving copies and cuts each tree through the kill ring: keep
          ;; it, and the system clipboard, out of it.
          (let ((kill-ring nil) (kill-ring-yank-pointer nil)
                (interprogram-cut-function nil) (interprogram-paste-function nil)
                (org-loop-over-headlines-in-active-region nil)
                (org-archive-subtree-save-file-p nil)
                (inhibit-message t))
            (org-with-wide-buffer
             (dolist (m markers)          ; last first: the rest stay put
               (goto-char m)
               (set-marker m nil)
               (org-archive-subtree)
               (cl-incf n))))
          (archive-done--save (cons (current-buffer) (archive-done--archive-buffers))))
        n))))

(defun archive-done-file (file before &optional keep)
  "Archive FILE's done tasks closed before BEFORE; how many, nil if left alone."
  (with-current-buffer (or (find-buffer-visiting file) (find-file-noselect file t))
    (archive-done-buffer before keep)))

;;;###autoload
(defun archive-done (&optional before)
  "Archive the done tasks closed before today in `archive-done-files'.
With \\[universal-argument], ask for the day instead of today."
  (interactive (list (when current-prefix-arg (org-read-date nil nil nil "Closed before: "))))
  (let ((before (or before (archive-done-today))) counts skipped)
    (dolist (file (org-agenda-files t))
      (when (member (file-name-nondirectory file) archive-done-files)
        (let ((n (archive-done-file file before)))
          (cond ((null n) (push (file-name-base file) skipped))
                ((> n 0) (push (format "%s %d" (file-name-base file) n) counts))))))
    (setq counts (nreverse counts))
    (message "%s%s"
             (if counts
                 (format "Archived done tasks closed before %s: %s" before
                         (string-join counts ", "))
               (format "No done tasks closed before %s to archive" before))
             (if skipped
                 (format " (left alone, changed on disk with unsaved edits: %s)"
                         (string-join skipped ", "))
               ""))
    counts))

(provide 'archive-done)
;;; archive-done.el ends here
