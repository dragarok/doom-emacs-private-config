;;; timebox-test.el --- Tomorrow, in blocks of time -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L $ORG -L lisp -l test/timebox-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'timebox)

(defvar org-tasks-file)
(defvar org-projects-file)
(defvar org-inbox-file)
(defvar org-mundane-tasks-file)

(defconst timebox-test--tasks "* TODO [#A] Write essay
SCHEDULED: <2026-10-27 Tue>
* TODO Read chapter
SCHEDULED: <2026-10-27 Tue>
:PROPERTIES:
:EFFORT:   1:30
:END:
* TODO Due tomorrow
DEADLINE: <2026-10-27 Tue>
* TODO Left from Sunday
SCHEDULED: <2026-10-25 Sun>
* TODO Already timed
SCHEDULED: <2026-10-27 Tue 09:00>
* TODO Stretch
SCHEDULED: <2026-10-27 Tue .+1d>
* WAITING On someone
SCHEDULED: <2026-10-27 Tue>
* TODO Thursday's
SCHEDULED: <2026-10-29 Thu>
* DONE Finished
SCHEDULED: <2026-10-27 Tue>
* NEXT Agent work :agent:
SCHEDULED: <2026-10-26 Mon>
:PROPERTIES:
:AGENT_PROJECT: .doom.d
:END:
")

(defmacro timebox-test--with (&rest body)
  (declare (indent 0))
  `(let* ((dir (file-name-as-directory (make-temp-file "timebox-test" t)))
          (file (expand-file-name "tasks.org" dir))
          (org-tasks-file file) (org-projects-file nil) (org-inbox-file nil)
          (org-mundane-tasks-file nil)
          (org-todo-keywords '((sequence "TODO" "NEXT" "WAITING" "PROJ" "|" "DONE")))
          (org-log-into-drawer t)
          (day (org-time-string-to-absolute "2026-10-27"))
          ;; The morning stretch, 05:00-05:30, is the only fixed thing.
          (timebox-busy-function (lambda (_day) '((300 . 330))))
          (timebox-start "05:00") (timebox-end "23:00")
          (timebox-minutes 45) (timebox-gap 15) (timebox-snap 15))
     (with-temp-file file (insert timebox-test--tasks))
     (unwind-protect
         (cl-letf (((symbol-function 'org-today) (lambda () (1- day))))
           ,@body)
       (when (find-buffer-visiting file) (kill-buffer (find-buffer-visiting file)))
       (delete-directory dir t))))

(defun timebox-test--file (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(ert-deftest timebox-test-pack ()
  (let ((timebox-gap 15) (timebox-snap 15))
    ;; Around 05:00-05:30 and 06:50-07:20, 15 minutes after each, on the quarter hour.
    (should (equal (timebox-pack '(45 45 45) '((300 . 330) (410 . 440)) 300 1380)
                   '(345 465 525)))
    ;; A short block takes the gap a long one skipped.
    (should (equal (timebox-pack '(120 30) '((300 . 330) (450 . 480)) 300 1380)
                   '(495 345)))
    (should (equal (timebox-pack '(45 60) nil 300 400) '(300 nil)))))

(ert-deftest timebox-test-which-tasks ()
  (timebox-test--with
    (should (equal (mapcar (lambda (task) (nth 4 task)) (timebox-tasks day))
                   '("Write essay" "Read chapter" "Due tomorrow" "Left from Sunday")))
    (should (equal (mapcar (lambda (task) (nth 3 task)) (timebox-tasks day)) '(45 90 45 45)))))

(ert-deftest timebox-test-plan ()
  (timebox-test--with
    (let ((result (timebox-plan day)))
      (should (equal (car result)
                     '((345 "Write essay") (405 "Read chapter") (510 "Due tomorrow")
                       (570 "Left from Sunday"))))
      (should-not (cadr result)))
    (let ((text (timebox-test--file file)))
      (should (string-match-p "Write essay\nSCHEDULED: <2026-10-27 Tue 05:45-06:30>" text))
      (should (string-match-p "Read chapter\nSCHEDULED: <2026-10-27 Tue 06:45-08:15>" text))
      ;; A deadline-only task gets a SCHEDULED block and keeps its deadline.
      (should (string-match-p "SCHEDULED: <2026-10-27 Tue 08:30-09:15> DEADLINE: <2026-10-27 Tue>\\|DEADLINE: <2026-10-27 Tue> SCHEDULED: <2026-10-27 Tue 08:30-09:15>" text))
      ;; Carried from Sunday: moved, and logged as a reschedule.
      (should (string-match-p "Left from Sunday\nSCHEDULED: <2026-10-27 Tue 09:30-10:15>\n:LOGBOOK:\n- Rescheduled from \"\\[2026-10-25 Sun\\]\" on " text))
      ;; Untouched.
      (should (string-match-p "Already timed\nSCHEDULED: <2026-10-27 Tue 09:00>\n" text))
      (should (string-match-p "Stretch\nSCHEDULED: <2026-10-27 Tue .\\+1d>\n" text))
      (should (string-match-p "On someone\nSCHEDULED: <2026-10-27 Tue>\n" text))
      (should (string-match-p "Thursday's\nSCHEDULED: <2026-10-29 Thu>\n" text))
      (should (string-match-p "Agent work :agent:\nSCHEDULED: <2026-10-26 Mon>\n" text)))
    ;; Again: everything has its time now.
    (should (equal (timebox-plan day) '(nil nil)))))

(ert-deftest timebox-test-unfit ()
  (timebox-test--with
    (let ((timebox-end "07:00"))
      (should (equal (timebox-plan day)
                     '(((345 "Write essay")) ("Read chapter" "Due tomorrow" "Left from Sunday"))))
      (should (string-match-p "Read chapter\nSCHEDULED: <2026-10-27 Tue>\n" (timebox-test--file file)))
      (should (string-match-p "Left from Sunday\nSCHEDULED: <2026-10-25 Sun>\n" (timebox-test--file file))))))

(ert-deftest timebox-test-today-from-now ()
  (timebox-test--with
    (cl-letf (((symbol-function 'org-today) (lambda () day))
              ((symbol-function 'decode-time)
               (lambda (&rest _) (list 0 10 8 27 10 2026 2 nil 0))))
      ;; 08:10 now: the first block at 08:15.
      (should (= (car (car (car (timebox-plan day)))) 495)))))

(ert-deftest timebox-test-agenda-busy ()
  "What is fixed comes from the agenda's day: a daily habit with a time,
a timed range, an entry with no end (30 minutes); not a done one, not an
untimed one."
  (let* ((dir (file-name-as-directory (make-temp-file "timebox-test" t)))
         (file (expand-file-name "fixed.org" dir))
         (org-agenda-files (list file))
         (org-todo-keywords '((sequence "TODO" "|" "DONE")))
         (day (org-time-string-to-absolute "2026-10-27")))
    (with-temp-file file
      (insert "* TODO Stretching
SCHEDULED: <2026-10-26 Mon 05:00 .+1d>
:PROPERTIES:
:STYLE:    habit
:END:
* Dentist
<2026-10-27 Tue 10:00-11:00>
* TODO Call
SCHEDULED: <2026-10-27 Tue 14:00>
* DONE Finished
SCHEDULED: <2026-10-27 Tue 16:00>
* TODO Untimed
SCHEDULED: <2026-10-27 Tue>
"))
    (unwind-protect
        (should (equal (sort (timebox--agenda-busy day) (lambda (a b) (< (car a) (car b))))
                       '((300 . 330) (600 . 660) (840 . 870))))
      (when (find-buffer-visiting file) (kill-buffer (find-buffer-visiting file)))
      (delete-directory dir t))))

;;; timebox-test.el ends here
