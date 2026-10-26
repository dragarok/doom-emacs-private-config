;;; reminders-test.el --- A task's reminder, rung by the Emacs Home app -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/reminders-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'reminders)

(defconst reminders-test--now (encode-time (parse-time-string "2026-10-27 06:00:00")))

(defconst reminders-test--tasks "* TODO Scales
SCHEDULED: <2026-10-27 Tue 09:00-09:45>
* TODO Call the bank
:PROPERTIES:
:REMIND:   1h
:END:
SCHEDULED: <2026-10-27 Tue 14:00>
* TODO Buy milk
:PROPERTIES:
:REMIND:   [2026-10-27 Tue 17:30]
:END:
SCHEDULED: <2026-10-27 Tue>
* TODO Quiet one
:PROPERTIES:
:REMIND:   none
:END:
SCHEDULED: <2026-10-27 Tue 10:00>
* DONE Finished
SCHEDULED: <2026-10-27 Tue 11:00>
* TODO No time
SCHEDULED: <2026-10-27 Tue>
* TODO Already past
SCHEDULED: <2026-10-27 Tue 05:00>
* TODO Next month
SCHEDULED: <2026-11-30 Mon 09:00>
* Dentist
<2026-10-28 Wed 10:00-11:00>
* TODO Standup :work:
SCHEDULED: <2026-10-27 Tue 06:50 .+1d>
")

(defmacro reminders-test--with (&rest body)
  (declare (indent 0))
  `(let* ((dir (file-name-as-directory (make-temp-file "reminders-test" t)))
          (file (expand-file-name "tasks.org" dir))
          (emacs-home-dir (expand-file-name "home/" dir))
          (org-agenda-files (list file)))
     (with-temp-file file (insert reminders-test--tasks))
     (unwind-protect (progn ,@body) (delete-directory dir t))))

(ert-deftest reminders-test-offset ()
  (should (= (reminders--offset "10") 10))
  (should (= (reminders--offset "30m") 30))
  (should (= (reminders--offset "2h") 120))
  (should (= (reminders--offset " 1d ") 1440))
  (should-not (reminders--offset "none"))
  (should-not (reminders--offset "[2026-10-27 Tue 17:30]")))

(ert-deftest reminders-test-collect ()
  "A time reminds 10 minutes before; :REMIND: before by its own amount, at
a time of its own, or not at all; an event's timestamp too.  Not done,
not untimed, not past, not past the week."
  (reminders-test--with
    (let ((rows (reminders-collect (list file) reminders-test--now)))
      (should (equal (mapcar (lambda (r) (list (format-time-string "%m-%d %H:%M" (nth 0 r)) (nth 1 r) (nth 2 r))) rows)
                     '(("10-27 06:40" "Standup" "06:50")
                       ("10-27 08:50" "Scales" "09:00")
                       ("10-27 13:00" "Call the bank" "14:00")
                       ("10-27 17:30" "Buy milk" "")
                       ("10-28 09:50" "Dentist" "10:00")))))))

(ert-deftest reminders-test-write ()
  "One line each, TIME-MS TAB TITLE TAB AT TAB FILE TAB HEADING, moved into
place; nothing written where the app's folder isn't."
  (reminders-test--with
    (should-not (reminders-write reminders-test--now))
    (make-directory emacs-home-dir t)
    (reminders-write reminders-test--now)
    (let ((lines (with-temp-buffer
                   (insert-file-contents (expand-file-name "reminders.tsv" emacs-home-dir))
                   (split-string (buffer-string) "\n" t))))
      (should (= (length lines) 5))
      (should (equal (split-string (nth 1 lines) "\t")
                     (list (number-to-string (truncate (* 1000 (float-time (encode-time (parse-time-string "2026-10-27 08:50:00"))))))
                           "Scales" "09:00" file "Scales")))
      (should-not (file-exists-p (expand-file-name ".reminders.tsv.tmp" emacs-home-dir))))))

(ert-deftest reminders-test-set ()
  "Set: an amount before, a time of its own, none; empty is the default."
  (reminders-test--with
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "30m")))
        (reminders-set))
      (should (equal (org-entry-get nil "REMIND") "30m"))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "2026-10-27 08:15")))
        (reminders-set))
      (should (equal (org-entry-get nil "REMIND") "[2026-10-27 Tue 08:15]"))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "")))
        (reminders-set))
      (should-not (org-entry-get nil "REMIND"))
      (set-buffer-modified-p nil)
      (kill-buffer))))

(ert-deftest reminders-test-goto ()
  "The app's Open finds the task by its heading."
  (reminders-test--with
    (reminders-open file "Call the bank")
    (should (equal (org-get-heading t t t t) "Call the bank"))
    (kill-buffer)))

;;; reminders-test.el ends here
