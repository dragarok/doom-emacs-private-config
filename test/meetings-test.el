;;; meetings-test.el --- Meetings: people, clocking, notes, reviews -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/meetings-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'meetings)
(require 'org-summary)

(defmacro meetings-test--with (&rest body)
  "BODY with an empty meetings file in a temporary agenda."
  (declare (indent 0))
  `(let* ((dir (file-truename (make-temp-file "meetings-test" t)))
          (org-meetings-file (expand-file-name "meetings.org" dir))
          (org-agenda-files (list dir))
          (org-summary-plots-directory dir))
     (unwind-protect (progn ,@body)
       (when (org-clocking-p) (org-clock-out nil t))
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defun meetings-test--text ()
  (with-temp-buffer (insert-file-contents org-meetings-file) (buffer-string)))

(ert-deftest meetings-test-person ()
  "A new name adds the person once, tagged, with no TODO and no date;
the pickers' candidates list them."
  (meetings-test--with
    (let ((a (meetings-person "Ram")) (b (meetings-person " ram ")))
      (should (equal (marker-position a) (marker-position b)))
      (meetings-person "Sita")
      (should (equal (mapcar #'car (meetings-people)) '("Meeting: Ram" "Meeting: Sita")))
      (should (string-match-p "^\\* Ram +:meeting:$" (meetings-test--text)))
      (should-not (string-match-p "TODO\\|SCHEDULED" (meetings-test--text))))))

(ert-deftest meetings-test-new-name ()
  "\"meeting X\" is a meeting without asking; otherwise asked, a task by default."
  (meetings-test--with
    (let ((asked 0) (answer "a task"))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) (cl-incf asked) answer)))
        (should (meetings-new-name "Meeting with Hari"))
        (should (meetings-new-name "meeting: Gita"))
        (should (= asked 0))
        (should-not (meetings-new-name "Fix the sink"))
        (setq answer "a meeting with Sangeet")
        (should (meetings-new-name "Sangeet"))
        (should (= asked 2))
        (should (equal (mapcar #'car (meetings-people))
                       '("Meeting: Hari" "Meeting: Gita" "Meeting: Sangeet")))))))

(ert-deftest meetings-test-clock-out ()
  "Clocking out of a meeting keeps a dated note under the person, asks
nothing about done, and leaves the heading without a TODO."
  (meetings-test--with
    (let ((ram (meetings-person "Ram")))
      (meetings-person "Sita")
      (with-current-buffer (marker-buffer ram)
        (goto-char ram)
        (org-clock-in))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "Agreed on the budget")))
        (meetings-clock-out))
      (let ((text (meetings-test--text)))
        (should (string-match-p (format-time-string "^\\* Ram +:meeting:\n\\(.*\n\\)*CLOCK: \\[%Y-%m-%d")
                                text))
        (should (string-match-p (format-time-string "^- \\[%Y-%m-%d %a\\] Agreed on the budget\n\\* Sita")
                                text))
        (should-not (string-match-p "DONE\\|TODO" text))))))

(ert-deftest meetings-test-review ()
  "The time-kinds block adds meeting time up by person."
  (meetings-test--with
    (with-temp-file org-meetings-file
      (insert "* Ram :meeting:\n:LOGBOOK:\n"
              (format-time-string "CLOCK: [%Y-%m-%d %a 10:00]--[%Y-%m-%d %a 10:45] =>  0:45\n")
              ":END:\n* Sita :meeting:\n:LOGBOOK:\n"
              (format-time-string "CLOCK: [%Y-%m-%d %a 12:00]--[%Y-%m-%d %a 12:30] =>  0:30\n")
              ":END:\n"))
    (with-temp-buffer
      (org-mode)
      (insert "#+BEGIN: time-kinds :span today\n#+END:\n")
      (goto-char (point-min))
      (org-update-dblock)
      (should (string-match-p "^- Meetings :: 1:15 — Ram 0:45 · Sita 0:30$" (buffer-string))))))

;;; meetings-test.el ends here
