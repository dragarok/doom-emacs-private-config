;;; day-log-review-test.el --- The daily review, start to end -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/day-log-review-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)

(defvar org-logs-directory (make-temp-file "day-log-test-logs" t))
(defvar org-dailyreview-file)
(defvar org-recurring-file)
(defvar org-summary-plots-directory)
(defvar org-summary-topics-file)
(defvar org-roam-directory)
(require 'day-log)
;; Loaded now, so loading them mid-test can't undo the stand-ins below.
(require 'org-summary)
(require 'org-flow)

(defmacro day-log-test--with (&rest body)
  "BODY with an empty review file and no agenda; `planned' collects the
planner's calls, `walked' whether the undated walk ran."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "day-log-test" t))
          (org-dailyreview-file (expand-file-name "dailyreview.org" dir))
          (org-roam-directory (expand-file-name "notes/" dir))
          (org-recurring-file (expand-file-name "recurring.org" dir))
          (org-agenda-files nil)
          (org-summary-plots-directory dir)
          (org-summary-topics-file (expand-file-name "topics.org" dir))
          (planned nil) (walked nil) (asked nil))
     (with-temp-file org-dailyreview-file (insert "#+title: Daily reviews\n"))
     (with-temp-file org-recurring-file (insert ""))
     (cl-letf (((symbol-function 'org-flow-undated) (lambda () '(undated)))
               ((symbol-function 'org-flow-date-undated) (lambda () (setq walked t)))
               ((symbol-function 'org-summary-plan-topics)
                (lambda (&rest args) (push args planned))))
       (unwind-protect (progn ,@body)
         (dolist (b (buffer-list))
           (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
             (with-current-buffer b (set-buffer-modified-p nil))
             (kill-buffer b)))
         (delete-directory dir t)))))

(defun day-log-test--answering (answers thunk)
  "Call THUNK with `read-string' answering ANSWERS in turn; the prompts."
  (let ((queue answers) prompts)
    (cl-letf (((symbol-function 'read-string)
               (lambda (p &optional initial &rest _) (push (cons p initial) prompts) (or (pop queue) ""))))
      (funcall thunk))
    (nreverse prompts)))

(defun day-log-test--review-text (date)
  (day-log--at date
    (buffer-substring-no-properties (point) (org-end-of-subtree t t))))

(ert-deftest day-log-test-review ()
  "Three lines asked in turn and written; written, so closed; every task
dated; tomorrow's daily topics planned for the day after the review's."
  (day-log-test--with
    (let* ((today (day-log--today))
           (prompts (day-log-test--answering '("Long day, got the essay out" "6" "Guitar scales")
                                             #'day-log-review))
           (text (day-log-test--review-text today)))
      (should (equal (mapcar #'car prompts)
                     '("One line about today: " "Energy, 1-10: " "First thing tomorrow: ")))
      (should (string-match-p "^- One line about today :: Long day, got the essay out$" text))
      (should (string-match-p "^- Energy, 1-10 :: 6$" text))
      (should (string-match-p "^- First thing tomorrow :: Guitar scales$" text))
      (should (string-match-p ":DAY_LOG: +written" text))
      (should (day-log-written-p today))
      (should walked)
      (should (equal planned (list (list "Daily topics" (day-log--shift today 1))))))))

(ert-deftest day-log-test-review-again ()
  "Run again, it offers what you wrote to edit, and an empty answer keeps
the line empty: nothing is forced."
  (day-log-test--with
    (let ((today (day-log--today)))
      (day-log-test--answering '("First pass" "" "") #'day-log-review)
      (let ((prompts (day-log-test--answering '("Second pass" "" "") #'day-log-review)))
        (should (equal (cdr (car prompts)) "First pass")))
      (let ((text (day-log-test--review-text today)))
        (should (string-match-p "^- One line about today :: Second pass$" text))
        (should (string-match-p "^- Energy, 1-10 :: $" text))))))

(ert-deftest day-log-test-review-yesterday ()
  "With C-u, yesterday's review, planning today."
  (day-log-test--with
    (let ((yesterday (day-log--shift (day-log--today) -1)))
      (day-log-test--answering '("Caught up in the morning" "" "")
                               (lambda () (day-log-review yesterday)))
      (should (string-match-p "Caught up in the morning" (day-log-test--review-text yesterday)))
      (should (equal planned (list (list "Daily topics" (day-log--today))))))))

;;; Where reviews live

(ert-deftest day-log-test-daily-note ()
  "The review is a heading in the day's org-roam daily note, made with an
ID and title when the note isn't there, and added after what a note
already holds; nothing goes to the old reviews file."
  (day-log-test--with
    (let* ((today (day-log--today)) (yesterday (day-log--shift today -1))
           (old (with-temp-buffer (insert-file-contents org-dailyreview-file) (buffer-string))))
      (make-directory (file-name-directory (day-log-daily-file yesterday)) t)
      (with-temp-file (day-log-daily-file yesterday)
        (insert "#+title: " yesterday "\n\n* Logs\n- =09:56= Political strategy\n"))
      (day-log-test--answering '("Today's line" "" "") #'day-log-review)
      (day-log-test--answering '("Yesterday's line" "" "") (lambda () (day-log-review yesterday)))
      (let ((note (with-temp-buffer (insert-file-contents (day-log-daily-file today)) (buffer-string))))
        (should (string-match-p "\\`:PROPERTIES:\n:ID: +[0-9a-f-]+\n" note))
        (should (string-match-p (format "^#\\+title: %s$" today) note))
        (should (string-match-p "^\\* Daily Review +:daylog:written:$" note))
        (should (string-match-p "^- One line about today :: Today's line$" note)))
      (should (string-match-p "\\* Logs\n- =09:56= Political strategy\n\\* Daily Review"
                              (with-temp-buffer (insert-file-contents (day-log-daily-file yesterday))
                                                (buffer-string))))
      (should (equal old (with-temp-buffer (insert-file-contents org-dailyreview-file) (buffer-string)))))))

(ert-deftest day-log-test-old-reviews ()
  "A day reviewed before the move is found in the old file: it counts as
written and closed, it is opened there, and the weekly blocks read it
beside the daily notes' reviews."
  (day-log-test--with
    (let* ((today (day-log--today)) (before (day-log--shift today -2)))
      (with-temp-file org-dailyreview-file
        (insert "#+title: Daily reviews\n* 2026\n** 2026-10 October\n"
                (format "*** %s %s\n" before (format-time-string "%A" (date-to-time (concat before " 12:00"))))
                "**** Daily Review :daylog:written:\n:PROPERTIES:\n:DAY_LOG:  written\n:END:\n"
                "- One line about today :: From the old file\n- Energy, 1-10 :: 4\n"))
      (should (day-log-written-p before))
      (should (day-log--closed-p before))
      (should (equal (car (day-log--find before)) (find-file-noselect org-dailyreview-file)))
      (day-log-test--answering '("New" "7" "") #'day-log-review)
      (let ((days (org-summary-reviews org-dailyreview-file
                                       (org-summary--parse-iso before) (org-summary--parse-iso today))))
        (should (equal (mapcar (lambda (d) (cdr (assoc "Energy, 1-10" (cdr d)))) days) '("4" "7")))))))

;;; day-log-review-test.el ends here
