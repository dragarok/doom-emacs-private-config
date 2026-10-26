;;; timebox.el --- Tomorrow, in blocks of time -*- lexical-binding: t -*-

;;; Commentary:
;; A day of dated tasks is still vague: twelve things "on Tuesday" and no
;; idea which comes when, or whether they fit.  So the evening review ends
;; by giving each of tomorrow's tasks a block of time:
;;
;;   - the fixed things come first: whatever already has a time that day
;;     (meetings, the morning ritual, the review -- as the agenda shows
;;     that day, habits and repeaters included);
;;   - tomorrow's tasks fill the free time around them, highest priority
;;     first, each in the earliest gap it fits: its Effort long, or
;;     `timebox-minutes', with `timebox-gap' between blocks, from
;;     `timebox-start' to `timebox-end';
;;   - tasks still open from before tomorrow come along, after tomorrow's
;;     own.  Moving one is a reschedule, and is logged as one, so
;;     org-flow's "rescheduled twice: break it down" still counts it;
;;   - what doesn't fit keeps its date, untimed, and is named.
;;
;; A block is written as the task's SCHEDULED time range, so the agenda,
;; the week calendar and the phone's reminders (reminders.el) all see it.
;; Then the week calendar (org-timegrid) opens on tomorrow: drag a block
;; to move it, its edge to resize it -- or, where it isn't installed (the
;; phone), the agenda's day.  Running it again only boxes what has no time.
;;
;; Left alone: habits and other repeating entries (a time on one would
;; stick to every repeat), projects, blocked steps, WAITING and SOMEDAY,
;; and agents' tasks (agent-time.el: an agent's work, not your time).

;;; Code:

(require 'org)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function org-flow-files "org-flow")
(declare-function org-timegrid-week "org-timegrid-org")

(defgroup timebox nil
  "Tomorrow, in blocks of time."
  :group 'org)

(defcustom timebox-start "05:00"
  "The first block starts no earlier than this."
  :type 'string)

(defcustom timebox-end "23:00"
  "The last block ends no later than this."
  :type 'string)

(defcustom timebox-minutes 45
  "A block's length, for a task with no Effort."
  :type 'integer)

(defcustom timebox-gap 15
  "Minutes kept free after each block and each fixed event."
  :type 'integer)

(defcustom timebox-snap 15
  "Blocks start on a multiple of this many minutes."
  :type 'integer)

(defvar timebox-busy-function #'timebox--agenda-busy
  "Called with an absolute day; returns that day's fixed times, as a list
of (START . END) minutes from midnight.")

;;; The day

(defun timebox--minutes (hh-mm)
  "\"HH:MM\" as minutes from midnight."
  (let ((parts (split-string hh-mm ":")))
    (+ (* 60 (string-to-number (car parts))) (string-to-number (cadr parts)))))

(defun timebox--hh-mm (minutes)
  (format "%02d:%02d" (/ minutes 60) (% minutes 60)))

(defvar org-habit-show-habits-only-for-today)

(defun timebox--agenda-busy (day)
  "DAY's timed, not-done entries, as the agenda shows that day: habits
and other repeaters included, an entry with no end taking 30 minutes."
  (require 'org-agenda)
  (require 'org-habit nil t)
  (let ((date (calendar-gregorian-from-absolute day))
        ;; Else a habit shows on today only, and tomorrow looks free.
        (org-habit-show-habits-only-for-today nil)
        (org-agenda-skip-scheduled-if-done t)
        (org-agenda-skip-deadline-if-done t)
        (org-agenda-skip-timestamp-if-done t)
        out)
    (dolist (file (org-agenda-files t) out)
      (dolist (e (org-agenda-get-day-entries file date :scheduled :timestamp :deadline))
        (let ((tod (get-text-property 0 'time-of-day e)))
          (when tod
            (let ((from (+ (* 60 (/ tod 100)) (% tod 100))))
              (push (cons from (min 1440 (+ from (round (or (get-text-property 0 'duration e) 30)))))
                    out))))))))

;;; Which tasks

(defun timebox--files ()
  (if (require 'org-flow nil t)
      (org-flow-files)
    (seq-filter #'file-regular-p (org-agenda-files t))))

(defun timebox--untimed-day (stamp)
  "STAMP's absolute day when it has no time of day and no repeater; else nil."
  (when (and stamp
             (not (string-match-p "[0-9]\\{1,2\\}:[0-9]\\{2\\}" stamp))
             (not (string-match-p "[.+]?\\+[0-9]+[hdwmy]" stamp)))
    (org-time-string-to-absolute stamp)))

(defun timebox--candidate (day)
  "The entry at point as (MARKER PRIORITY CARRIED MINUTES TITLE) when it
belongs in DAY's blocks; else nil.  CARRIED: it was scheduled before DAY."
  (when (and (org-entry-is-todo-p)
             (not (org-entry-blocked-p))
             (not (member (org-get-todo-state) '("PROJ" "SOMEDAY" "WAITING" "TONOTDO")))
             (not (equal (org-entry-get nil "STYLE") "habit"))
             (not (org-entry-get nil "AGENT_PROJECT")))
    (let* ((sched (org-entry-get nil "SCHEDULED"))
           (deadline (org-entry-get nil "DEADLINE"))
           (s-day (timebox--untimed-day sched))
           (d-day (and (not sched) (timebox--untimed-day deadline))))
      (when (or (and s-day (<= s-day day)) (eql d-day day))
        (list (point-marker)
              (save-excursion (org-back-to-heading t) (org-get-priority (org-get-heading t t nil t)))
              (and s-day (< s-day day))
              (let ((effort (org-entry-get nil "EFFORT")))
                (max timebox-snap
                     (or (and effort (ignore-errors (round (org-duration-to-minutes effort))))
                         timebox-minutes)))
              (substring-no-properties (org-get-heading t t t t)))))))

(defun timebox-tasks (day)
  "DAY's tasks to box, in the order they get first pick of the time:
priority, then DAY's own before those carried, then file order."
  (let (out (n 0))
    (dolist (file (timebox--files))
      (with-current-buffer (or (find-buffer-visiting file) (find-file-noselect file t))
        (org-with-wide-buffer
         (org-map-entries
          (lambda ()
            (when-let* ((c (timebox--candidate day)))
              (push (append c (list (cl-incf n))) out)))))))
    (mapcar #'butlast
            (sort out (lambda (a b)
                        (cond ((/= (nth 1 a) (nth 1 b)) (> (nth 1 a) (nth 1 b)))
                              ((not (eq (nth 2 a) (nth 2 b))) (not (nth 2 a)))
                              (t (< (nth 5 a) (nth 5 b)))))))))

;;; Packing

(defun timebox--snap-up (m)
  (* timebox-snap (ceiling m (float timebox-snap))))

(defun timebox-pack (lengths busy start end)
  "Starts for blocks of LENGTHS minutes, in order, each in the earliest
free time from START to END: around BUSY ((START . END) ...) and the blocks
before it, `timebox-gap' after each.  A start is nil where it didn't fit."
  (let ((taken (mapcar (lambda (b) (cons (car b) (+ (cdr b) timebox-gap))) busy)))
    (mapcar
     (lambda (len)
       (let ((at (seq-find
                  (lambda (x)
                    (and (<= (+ x len) end)
                         (seq-every-p (lambda (b) (or (<= (+ x len timebox-gap) (car b))
                                                      (>= x (cdr b))))
                                      taken)))
                  (sort (delete-dups
                         (seq-filter (lambda (x) (>= x start))
                                     (cons (timebox--snap-up start)
                                           (mapcar (lambda (b) (timebox--snap-up (cdr b))) taken))))
                        #'<))))
         (when at (push (cons at (+ at len timebox-gap)) taken))
         at))
     lengths)))

;;; Writing a block

(defun timebox--write (marker day from to carried)
  "Schedule the task at MARKER on DAY, FROM to TO (minutes).  CARRIED:
it moves from an earlier day, logged as a reschedule."
  (with-current-buffer (marker-buffer marker)
    (org-with-wide-buffer
     (goto-char marker)
     (org-back-to-heading t)
     (let* ((date (format-time-string "%Y-%m-%d %a" (org-time-from-absolute day)))
            (old (org-entry-get nil "SCHEDULED"))
            (org-log-reschedule nil))
       (unless old (org-add-planning-info 'scheduled (org-time-from-absolute day)))
       (save-excursion
         (when (re-search-forward org-scheduled-time-regexp (save-excursion (outline-next-heading) (point)) t)
           (replace-match (format "%s %s-%s" date (timebox--hh-mm from) (timebox--hh-mm to)) t t nil 1)))
       (when carried
         (goto-char (org-log-beginning t))
         (insert (format "- Rescheduled from \"[%s]\" on %s\n"
                         (substring old 1 (1- (length old)))
                         (format-time-string (org-time-stamp-format t t))))))
     (save-buffer))))

;;;###autoload
(defun timebox-plan (day)
  "Box DAY's tasks (an absolute day): see the Commentary.  Returns
\(BOXED UNFIT): BOXED as (FROM TITLE) a block, UNFIT as titles."
  (let* ((tasks (timebox-tasks day))
         (start (max (timebox--minutes timebox-start)
                     ;; Today: from now on.
                     (if (= day (org-today))
                         (let ((now (decode-time))) (+ (* 60 (nth 2 now)) (nth 1 now)))
                       0)))
         (starts (timebox-pack (mapcar (lambda (task) (nth 3 task)) tasks)
                               (funcall timebox-busy-function day)
                               start (timebox--minutes timebox-end)))
         boxed unfit)
    (cl-loop for task in tasks for at in starts
             do (if at
                    (progn (timebox--write (nth 0 task) day at (+ at (nth 3 task)) (nth 2 task))
                           (push (list at (nth 4 task)) boxed))
                  (push (nth 4 task) unfit)))
    (list (sort boxed (lambda (a b) (< (car a) (car b)))) (nreverse unfit))))

(defun timebox--tomorrow ()
  "Tomorrow, as the day log counts days (it turns at 4am), as an absolute day."
  (1+ (if (require 'day-log nil t)
          (org-time-string-to-absolute (day-log--today))
        (org-today))))

(declare-function day-log--today "day-log")

;;;###autoload
(defun timebox-tomorrow (&optional day)
  "Box tomorrow's tasks (DAY, an absolute day; with \\[universal-argument],
today's, from now), say where they went, and open the week calendar on it
to move them by dragging (the agenda's day, without org-timegrid)."
  (interactive (list (if current-prefix-arg (org-today) (timebox--tomorrow))))
  (let* ((day (or day (timebox--tomorrow)))
         (result (timebox-plan day))
         (boxed (car result)) (unfit (cadr result)))
    (if (fboundp 'org-timegrid-week)
        (org-timegrid-week day)
      (org-agenda-list nil day 1))
    (message "%s%s"
             (if boxed
                 (format "Boxed %d: %s" (length boxed)
                         (mapconcat (lambda (b) (format "%s %s" (timebox--hh-mm (car b)) (cadr b)))
                                    boxed ", "))
               "Nothing new to box")
             (if unfit
                 (format ".  Didn't fit (still dated, no time): %s" (string-join unfit ", "))
               ""))
    result))

(provide 'timebox)
;;; timebox.el ends here
