;;; org-summary-topics-test.el --- Weekly topics: the block and the planner -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/org-summary-topics-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.
;; Optionally ORG_TEMPLATES=~/org/templates checks the real review templates.

(require 'ert)
(require 'org-summary)
(require 'org-agenda)

(defconst topics-test--tags
  '("mentalmodels" "notesrevision" "mentalgym" "weeklyvideo" "booksrevision" "roomcleanup"))

;; The week of Sat 2026-10-24 (Mon 19 .. Sun 25), and the week before it.
(defconst topics-test--tasks "#+title: Tasks

* TODO [#F] Something else entirely :plain:personal:
SCHEDULED: <2026-05-07 Thu>
* DONE Inversion: write 3 examples from work :mentalmodels:
CLOSED: [2026-10-21 Wed 19:00]
:LOGBOOK:
CLOCK: [2026-10-19 Mon 18:00]--[2026-10-19 Mon 18:40] =>  0:40
CLOCK: [2026-10-21 Wed 18:30]--[2026-10-21 Wed 19:00] =>  0:30
:END:
* TODO Second-order thinking: read chapter :mentalmodels:
* TODO Revise Category Theory notes :notesrevision:
:LOGBOOK:
CLOCK: [2026-10-22 Thu 20:00]--[2026-10-22 Thu 20:25] =>  0:25
:END:
* CANCELED Process old highlights :booksrevision:
CLOSED: [2026-10-20 Tue 10:00]
* DONE Clean desk :roomcleanup:
CLOSED: [2026-10-24 Sat 11:00]
* DONE Last week's video :weeklyvideo:
CLOSED: [2026-10-15 Thu 21:00]
:LOGBOOK:
CLOCK: [2026-10-15 Thu 20:00]--[2026-10-15 Thu 21:00] =>  1:00
:END:
")

;; A retired habit, archived with its tag (as in ~/org/archive/archive.org):
;; its clocks count, it is not open.
(defconst topics-test--archive "* TODO [#D] Mental Models :mentalmodels:
SCHEDULED: <2026-10-28 Wed ++1w>
:PROPERTIES:
:STYLE:    habit
:END:
:LOGBOOK:
CLOCK: [2026-10-23 Fri 09:00]--[2026-10-23 Fri 09:15] =>  0:15
:END:
")

(defvar org-tasks-file)

(defmacro topics-test--with-org (&rest body)
  "BODY with a fresh tasks.org (and its archive) as the only agenda file."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "topics-test" t))
          (org-tasks-file (expand-file-name "tasks.org" dir))
          (org-agenda-files (list org-tasks-file))
          (org-archive-location (concat dir "/archive.org::datetree/"))
          (org-todo-keywords '((sequence "TODO" "|" "DONE" "CANCELED")))
          (org-summary-tag-groups (list (cons "Topics" topics-test--tags)))
          (org-summary-plots-directory dir)
          (org-tags-column -77)
          (org-log-done nil))
     (with-temp-file org-tasks-file (insert topics-test--tasks))
     (with-temp-file (expand-file-name "archive.org" dir) (insert topics-test--archive))
     (unwind-protect (progn ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defun topics-test--block (params)
  "The topics block written for PARAMS (a string), as text."
  (with-temp-buffer
    (org-mode)
    (insert "#+BEGIN: topics " params "\n#+END:\n")
    (org-update-all-dblocks)
    (buffer-substring-no-properties (point-min) (point-max))))

(defun topics-test--row (text tag)
  "TAG's table row in TEXT, as a list of trimmed cells."
  (when (string-match (format "^| %s +|\\(.*\\)|$" tag) text)
    (mapcar #'string-trim (split-string (match-string 1 text) "|"))))

(defmacro topics-test--answering (answers &rest body)
  "BODY with `read-string' answering ANSWERS in turn; the prompts are in `prompts'."
  (declare (indent 1))
  `(let ((queue ,answers) (prompts nil))
     (cl-letf (((symbol-function 'read-string)
                (lambda (p &rest _) (push p prompts) (or (pop queue) ""))))
       ,@body
       (setq prompts (nreverse prompts)))
     prompts))

;;; The block

(ert-deftest topics-test-week ()
  "A column a day; time, done and open; cancelled is not done; nothing planned."
  (topics-test--with-org
    (let ((out (topics-test--block ":span thisweek :date \"2026-10-24\"")))
      (should (string-match-p "| Topic +| Mon | Tue | Wed | Thu | Fri | Sat | Sun | Time | Done | Open |" out))
      ;; Clocked Mon and Wed, closed Wed; the archived habit's Friday clock counts.
      (should (equal (topics-test--row out "mentalmodels")
                     '("✓" "" "✓" "" "✓" "" "" "1:25" "1" "1")))
      (should (equal (topics-test--row out "notesrevision")
                     '("" "" "" "✓" "" "" "" "0:25" "0" "1")))
      ;; Cancelled: no tick, not done, and nothing open, so nothing planned.
      (should (equal (topics-test--row out "booksrevision")
                     '("" "" "" "" "" "" "" "" "0" "0")))
      (should (equal (topics-test--row out "roomcleanup")
                     '("" "" "" "" "" "✓" "" "" "1" "0")))
      ;; Last week's video is outside this week.
      (should (equal (topics-test--row out "weeklyvideo")
                     '("" "" "" "" "" "" "" "" "0" "0")))
      (should (string-match-p "^Nothing planned: mentalgym, weeklyvideo, booksrevision$" out)))))

(ert-deftest topics-test-last-week ()
  "lastweek is the week before the date."
  (topics-test--with-org
    (let ((out (topics-test--block ":span lastweek :date \"2026-10-24\"")))
      (should (equal (topics-test--row out "weeklyvideo")
                     '("" "" "" "✓" "" "" "" "1:00" "1" "0")))
      (should (equal (topics-test--row out "mentalmodels")
                     '("" "" "" "" "" "" "" "" "0" "1"))))))

(ert-deftest topics-test-month ()
  "Longer than a week: days worked are counted, not drawn."
  (topics-test--with-org
    (let ((out (topics-test--block ":span thismonth :date \"2026-10-24\"")))
      (should (string-match-p "| Topic +| Days | Time | Done | Open |" out))
      (should (equal (topics-test--row out "mentalmodels") '("3" "1:25" "1" "1")))
      (should (equal (topics-test--row out "weeklyvideo") '("1" "1:00" "1" "0"))))))

;;; The planner

(ert-deftest topics-test-plan-writes-tasks ()
  "Each answer is a TODO at the end of tasks.org: the tag, scheduled today,
CREATED, CATEGORY ToImprove; no STYLE, no ID; the rest of the file untouched."
  (topics-test--with-org
    (let ((prompts (topics-test--answering
                       '("Inversion: 3 examples from work" ""
                         "" "Two Project Euler problems, 30 min each" "Mental arithmetic drills" "")
                     (org-summary-plan-topics)))
          (text (with-temp-buffer (insert-file-contents org-tasks-file) (buffer-string))))
      ;; One question per topic, again after each answer, with what is open.
      (should (= (length prompts) 9))
      (should (string-prefix-p "mentalmodels [open: Second-order thinking: read chapter] — task" (nth 0 prompts)))
      (should (string-match-p "\\[open: Inversion: 3 examples from work; Second-order" (nth 1 prompts)))
      (should (string-prefix-p "mentalgym — task" (nth 3 prompts)))
      (should (string-prefix-p "roomcleanup — task" (nth 8 prompts)))
      (should (string-prefix-p topics-test--tasks text))
      (with-current-buffer (find-file-noselect org-tasks-file)
        (let ((made (org-map-entries
                     (lambda () (list (org-get-heading t t t t) (org-get-tags nil t)
                                      (org-entry-get nil "SCHEDULED")
                                      (org-entry-get nil "CATEGORY")
                                      (org-entry-get nil "CREATED")
                                      (org-entry-get nil "STYLE") (org-entry-get nil "ID")))
                     "CATEGORY=\"ToImprove\"")))
          (should (equal (mapcar #'car made)
                         '("Inversion: 3 examples from work"
                           "Two Project Euler problems, 30 min each" "Mental arithmetic drills")))
          (should (equal (mapcar #'cadr made) '(("mentalmodels") ("mentalgym") ("mentalgym"))))
          (dolist (m made)
            (should (equal (nth 2 m) (format-time-string "<%Y-%m-%d %a>")))
            (should (string-match-p (format-time-string "^\\[%Y-%m-%d %a [0-9:]+\\]$") (nth 4 m)))
            (should-not (nth 5 m))
            (should-not (nth 6 m))))))))

(ert-deftest topics-test-plan-nothing ()
  "Empty answers everywhere: six questions, tasks.org unchanged."
  (topics-test--with-org
    (let ((prompts (topics-test--answering nil (org-summary-plan-topics))))
      (should (= (length prompts) 6))
      (should (equal (with-temp-buffer (insert-file-contents org-tasks-file) (buffer-string))
                     topics-test--tasks)))))

(ert-deftest topics-test-plan-refreshes-block ()
  "Planned from a review, its topics block counts the new tasks right away;
other blocks there are left as they were."
  (topics-test--with-org
    (with-temp-buffer
      (org-mode)
      (insert "* Topics\n#+BEGIN: topics :span thisweek\n#+END:\n"
              "* Other\n#+BEGIN: clock-chart :span thisweek\nleft alone\n#+END:\n")
      (topics-test--answering '("" "" "Daily puzzle, 20 min" "") (org-summary-plan-topics))
      (let ((out (buffer-substring-no-properties (point-min) (point-max))))
        (should (equal (car (last (topics-test--row out "mentalgym"))) "1"))
        (should (string-match-p "^Nothing planned: weeklyvideo, booksrevision" out))
        (should (string-match-p "^left alone$" out))))))

(ert-deftest topics-test-plan-in-agenda ()
  "The planned tasks are in today's agenda, under ToImprove."
  (topics-test--with-org
    (topics-test--answering '("" "" "Daily puzzle, 20 min" "") (org-summary-plan-topics))
    (let ((org-agenda-sticky nil) (org-agenda-span 'day))
      (org-agenda-list nil (format-time-string "%Y-%m-%d") 'day)
      (let ((out (with-current-buffer org-agenda-buffer-name (buffer-string))))
        (should (string-match-p "ToImprove: +Scheduled: +TODO Daily puzzle, 20 min" out))))))

;;; The real templates (only with ORG_TEMPLATES set)

(ert-deftest topics-test-templates ()
  "The weekly templates' planning step runs the planner; every template's
topics block renders."
  (let ((templates (getenv "ORG_TEMPLATES")))
    (skip-unless templates)
    (topics-test--with-org
      (dolist (f '("weeklyreviewtemplate.org" "weeklyreviewtemplate_lastweek.org"
                   "monthlyreviewtemplate.org"))
        (with-temp-buffer
          (insert-file-contents (expand-file-name f templates))
          (org-mode)
          (goto-char (point-min))
          (should (re-search-forward "^#\\+BEGIN: topics :span \\(this\\|last\\)\\(week\\|month\\)$" nil t))
          (beginning-of-line)
          (org-update-dblock)
          (should (string-match-p "| Topic " (buffer-string)))
          (goto-char (point-min))
          (when (string-prefix-p "weekly" f)
            (should (re-search-forward "^\\*\\* TODO Plan this week's topics" nil t))
            (should (re-search-forward "^#\\+BEGIN_SRC emacs-lisp" nil t))
            (let ((org-confirm-babel-evaluate nil))
              (topics-test--answering (list (concat "From " f) "") (org-babel-execute-src-block)))
            (should (string-match-p (concat "TODO From " (regexp-quote f))
                                    (with-temp-buffer (insert-file-contents org-tasks-file)
                                                      (buffer-string))))))))))

;;; org-summary-topics-test.el ends here
