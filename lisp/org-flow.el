;;; org-flow.el --- Every task dated, and broken down when it stalls -*- lexical-binding: t -*-

;;; Commentary:
;; Three years of task history said what kept work from flowing: a task
;; with a date got done 88% of the time, one without 45%; a task
;; rescheduled twice or more 38%; one tagged Challenge 32%.  And the
;; cancellation notes said "too vague" again and again.  So:
;;
;;   - every open task in the main agenda files (`org-flow-files') has a
;;     date.  Capturing stays quick; `org-flow-date-undated' (the daily
;;     review's first step, SPC o v u) walks whatever has none and asks:
;;     a date, break it down, someday, cancel, done, or skip.
;;   - the second time a task is rescheduled, it is offered a breakdown
;;     instead (`org-flow-breakdown', SPC o v b), on the lines of Flow
;;     (Csikszentmihalyi) as in notes/how_to_make_tasks_optimal_for_flow:
;;     a clear goal (what is there to show when it is done), the finer
;;     analysis of what makes it hard, and feasible sub-goals, each one
;;     sitting with a visible result -- the feedback -- and each dated.
;;     The task keeps the goal and gets a deadline, the last step's date.
;;
;; Someday, ideas and the archives are left alone: only the main files count.

;;; Code:

(require 'org)
(require 'org-refile)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar org-tasks-file)
(defvar org-projects-file)
(defvar org-inbox-file)
(defvar org-mundane-tasks-file)
(defvar org-someday-file)

(defun org-flow-files ()
  "The main agenda files, where every open task has a date.  Not ideas.org:
ideas are not tasks."
  (seq-filter (lambda (f) (and f (file-exists-p f)))
              (list (bound-and-true-p org-tasks-file)
                    (bound-and-true-p org-projects-file)
                    (bound-and-true-p org-inbox-file)
                    (bound-and-true-p org-mundane-tasks-file))))

(defun org-flow--undated-p ()
  "Is the entry at point an open task with no date?  Projects, habits and
mundane.org's TONOTDO clock buckets are not: a project is dated by its
steps, a habit by its repeater, and a bucket is only clocked into."
  (and (org-entry-is-todo-p)
       (not (member (org-get-todo-state) '("PROJ" "SOMEDAY" "WAITING" "TONOTDO")))
       (not (equal (org-entry-get nil "STYLE") "habit"))
       (not (org-get-scheduled-time (point)))
       (not (org-get-deadline-time (point)))))

(defun org-flow-undated ()
  "Markers of the undated open tasks in `org-flow-files', in file order."
  (let (out)
    (dolist (file (org-flow-files) (nreverse out))
      (with-current-buffer (or (find-buffer-visiting file) (find-file-noselect file t))
        (org-with-wide-buffer
         (org-map-entries (lambda () (when (org-flow--undated-p) (push (point-marker) out)))
                          nil nil))))))

;;; Breaking a task down

(defun org-flow--title ()
  (substring-no-properties (org-get-heading t t t t)))

(defun org-flow--date (prompt default)
  "A day read with PROMPT, DEFAULT (a time) offered; \"YYYY-MM-DD\"."
  (format-time-string "%Y-%m-%d" (org-read-date nil t nil prompt default)))

;;;###autoload
(defun org-flow-breakdown ()
  "Break the task at point down into dated steps, the way Flow would:
a clear goal, what makes it hard, and steps of one sitting each with a
visible result.  The task gets the goal in its body and a deadline (the
last step's day) instead of its schedule.  Nothing changes without a step."
  (interactive)
  (org-back-to-heading t)
  (let* ((title (org-flow--title))
         (goal (string-trim (read-string (format "\"%s\" is done when there is (to show): " title))))
         (hard (string-trim (read-string "What makes it hard (empty: nothing in particular): ")))
         (day (current-time))
         steps)
    (cl-loop for n from 1
             for step = (string-trim
                         (read-string
                          (format "Step %d — one sitting, with a result you can see (empty: done): " n)))
             until (string-empty-p step)
             do (let ((date (org-flow--date (format "\"%s\" on: " step) day)))
                  (setq day (time-add (org-time-string-to-time date) (* 24 3600)))
                  (push (cons step date) steps)))
    (setq steps (nreverse steps))
    (unless steps (user-error "No steps: %s is as it was" title))
    (let ((org-log-reschedule nil) (org-log-redeadline nil))
      (org-schedule '(4))
      (org-deadline nil (cdar (last steps))))
    (save-excursion
      (org-end-of-meta-data t)
      (insert (if (string-empty-p goal) "" (format "Done when: %s\n" goal))
              (if (string-empty-p hard) "" (format "Hard part: %s\n" hard))))
    (let ((level (1+ (org-outline-level))))
      (save-excursion
        (org-end-of-subtree t t)
        (unless (bolp) (insert "\n"))
        (dolist (s steps)
          (insert (make-string level ?*) " TODO " (car s) "\n")
          (forward-line -1)
          (org-schedule nil (cdr s))
          (org-entry-put nil "CREATED" (format-time-string "[%Y-%m-%d %a %H:%M]"))
          (org-end-of-subtree t t))))
    (save-buffer)
    (message "%s: %d step%s, the last on %s" title (length steps)
             (if (cdr steps) "s" "") (cdar (last steps)))))

(defun org-flow--reschedules ()
  "How many times the entry at point has been rescheduled, by its log."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point))) (n 0))
      (while (re-search-forward "^[ \t]*- Rescheduled from " end t) (cl-incf n))
      n)))

(defun org-flow--reschedule-a (fn &rest args)
  "Around `org-schedule': the second time a task is rescheduled by hand,
offer to break it down instead."
  (if (and (memq this-command '(org-schedule org-agenda-schedule))
           (null (car args))
           (org-get-scheduled-time (point))
           (>= (org-flow--reschedules) 1)
           (y-or-n-p (format "\"%s\" was rescheduled %d time%s already.  Break it down into steps instead? "
                             (org-flow--title) (org-flow--reschedules)
                             (if (= 1 (org-flow--reschedules)) "" "s"))))
      (org-flow-breakdown)
    (apply fn args)))

;;; Dating the undated

(defun org-flow--someday ()
  "Move the entry at point to the end of `org-someday-file'."
  (let ((org-refile-keep nil) (org-log-refile nil))
    (org-refile nil nil (list (file-name-nondirectory org-someday-file) org-someday-file nil nil)))
  (with-current-buffer (find-file-noselect org-someday-file) (save-buffer)))

(defun org-flow--set-state (state &optional note)
  "Set the entry at point to STATE, logged now, with NOTE (if any) on the
log line.  Org would ask for a note after the command; a walk through
many tasks is one command, so the note is asked for here instead."
  (let ((org-inhibit-logging 'note))
    (org-todo state))
  ;; Org writes the state's log line after the command; it is only a time
  ;; now, so write it here.
  (when (memq 'org-add-log-note post-command-hook)
    (org-add-log-note))
  (when (org-string-nw-p note)
    (save-excursion
      (org-back-to-heading t)
      (let ((end (save-excursion (outline-next-heading) (point))))
        (if (re-search-forward (format "^\\([ \t]*\\)- State \"%s\" .*$" (regexp-quote state)) end t)
            (insert " \\\\\n" (match-string 1) "  " note)
          ;; STATE logs nothing here: the reason goes in as a note.
          (goto-char (org-log-beginning t))
          (insert "- Note taken on " (format-time-string (org-time-stamp-format t t))
                  " \\\\\n  " note "\n"))))))

;;;###autoload
(defun org-flow-date-undated ()
  "Walk the undated tasks of `org-flow-files', one at a time:
d a date, b break it down, s someday, c cancel, x done, n skip, q stop."
  (interactive)
  (let ((todo (org-flow-undated)) (n 0) (counts (make-hash-table)))
    (save-window-excursion
      (catch 'stop
        (dolist (m todo)
          (cl-incf n)
          (when (and (marker-buffer m)
                     (with-current-buffer (marker-buffer m) (goto-char m) (org-flow--undated-p)))
            (pop-to-buffer-same-window (marker-buffer m))
            (widen) (goto-char m) (org-fold-show-context) (org-fold-show-entry) (recenter 3)
            (let ((key (read-char-choice
                        (format "[%d/%d] %s — d date  b break down  s someday  c cancel  x done  n skip  q stop: "
                                n (length todo) (org-flow--title))
                        '(?d ?b ?s ?c ?x ?n ?q))))
              (pcase key
                (?d (org-schedule nil))
                (?b (org-flow-breakdown))
                (?s (org-flow--someday))
                (?c (org-flow--set-state "CANCELED" (read-string "Why cancel it: ")))
                (?x (org-flow--set-state "DONE"))
                (?q (throw 'stop nil)))
              (unless (eq key ?n) (save-buffer))
              (cl-incf (gethash key counts 0)))))))
    (message (if (null todo) "Every task has a date"
               (format "Dated %d, broken down %d, to someday %d, cancelled %d, done %d, skipped %d; %d left undated"
                       (gethash ?d counts 0) (gethash ?b counts 0) (gethash ?s counts 0)
                       (gethash ?c counts 0) (gethash ?x counts 0) (gethash ?n counts 0)
                       (length (org-flow-undated)))))))

;;;###autoload
(define-minor-mode org-flow-mode
  "Offer a breakdown the second time a task is rescheduled."
  :global t :group 'org
  (if org-flow-mode
      (advice-add 'org-schedule :around #'org-flow--reschedule-a)
    (advice-remove 'org-schedule #'org-flow--reschedule-a)))

(provide 'org-flow)
;;; org-flow.el ends here
