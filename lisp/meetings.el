;;; meetings.el --- Time with people, clocked like tasks -*- lexical-binding: t -*-

;;; Commentary:
;; A meeting is not a task: nothing gets done, nothing needs a date.  So
;; `org-meetings-file' has one heading per person, "* Ram :meeting:", with
;; no TODO keyword -- never on the agenda, never in the undated walk -- and
;; every meeting with them is a clock line under it.
;;
;; There is no separate entry point.  The task pickers -- Clock in on the
;; dashboard (`rts-flow-manual') and Add > Clock Time -- list everyone as
;; "Meeting: Ram".  A name that matches nobody and no task asks "Task, or
;; a meeting with NAME?"; "meeting Ram" skips the question.
;; Clocking out of a meeting (Done on the floating clock) asks for one
;; optional line of notes, kept under the person with the date, instead of
;; whether it is done.
;;
;; The day log shows meetings as "Meeting: Ram"; the reviews' time-kinds
;; block adds up meeting time by person.

;;; Code:

(require 'org)
(require 'subr-x)

(defvar org-agenda-directory)

(defvar org-meetings-file
  (expand-file-name "meetings.org" (bound-and-true-p org-agenda-directory))
  "One heading per person; each meeting is a clock line under them.")

(defconst meetings-prefix "Meeting: "
  "How a person shows in the task pickers and the day log.")

(defun meetings-file-p (file)
  "Whether FILE is `org-meetings-file'."
  (and file (equal (file-truename file) (file-truename org-meetings-file))))

(defun meetings--buffer ()
  "`org-meetings-file''s buffer, the file made if it isn't there yet."
  (unless (file-exists-p org-meetings-file)
    (make-directory (file-name-directory org-meetings-file) t)
    (with-temp-file org-meetings-file
      (insert "#+title: Meetings\n\n"
              "One heading per person.  Each meeting is a clock line under them;\n"
              "notes from clocking out are the dated lines.\n\n")))
  (find-file-noselect org-meetings-file))

(defun meetings-people ()
  "Everyone met, as (\"Meeting: NAME\" . MARKER), in file order."
  (when (file-exists-p org-meetings-file)
    (with-current-buffer (meetings--buffer)
      (org-with-wide-buffer
       (goto-char (point-min))
       (let (out)
         (while (re-search-forward org-outline-regexp-bol nil t)
           (when (= (org-current-level) 1)
             (push (cons (concat meetings-prefix (org-get-heading t t t t))
                         (copy-marker (line-beginning-position)))
                   out)))
         (nreverse out))))))

(defun meetings-person (name)
  "NAME's heading in `org-meetings-file' as a marker, added if new."
  (let ((name (string-trim name)))
    (or (cdr (assoc-string (concat meetings-prefix name) (meetings-people) t))
        (with-current-buffer (meetings--buffer)
          (org-with-wide-buffer
           (goto-char (point-max))
           (unless (bolp) (insert "\n"))
           (insert "* " name "\n")
           (forward-line -1)
           (org-set-tags '("meeting"))
           (org-entry-put nil "CREATED" (format-time-string "[%Y-%m-%d %a]"))
           (save-buffer)
           (copy-marker (line-beginning-position)))))))

(defun meetings-new-name (name)
  "For NAME, which matches nothing in a task picker: the person's marker
when it is a meeting, nil when it is a new task.  \"meeting Ram\" or
\"Meeting: Ram\" is a meeting without asking.  Otherwise it asks, a
meeting by default for a name of one or two words (a person, or two),
a task for longer (a task is rarely that short)."
  (let ((case-fold-search t))
    (if (string-match "\\`meeting\\(?: with\\)?:?[ \t]+\\(.+\\)" name)
        (meetings-person (match-string 1 name))
      (let* ((meeting (format "a meeting with %s" name))
             (answer (completing-read (format "\"%s\" is new.  It is: " name)
                                      (list "a task" meeting) nil t nil nil
                                      (if (<= (length (split-string name)) 2) meeting "a task"))))
        (unless (equal answer "a task")
          (meetings-person name))))))

(defun meetings-add-note (marker note)
  "Under MARKER's person, NOTE as a line with today's date."
  (unless (string-empty-p (string-trim note))
    (with-current-buffer (marker-buffer marker)
      (org-with-wide-buffer
       (goto-char marker)
       (org-end-of-subtree t t)
       (unless (bolp) (insert "\n"))
       (insert (format-time-string "- [%Y-%m-%d %a] ") (string-trim note) "\n")
       (save-buffer)))))

(defun meetings-clock-out ()
  "Clock out of a meeting: one optional line of notes, nothing marked done."
  (let ((marker (copy-marker org-clock-marker))
        (who (substring-no-properties org-clock-current-task)))
    (org-clock-out)
    (meetings-add-note marker (read-string (format "Notes from %s (RET: none): " who)))
    (org-save-all-org-buffers)
    (message "Meeting with %s clocked out" who)))

(provide 'meetings)
;;; meetings.el ends here
