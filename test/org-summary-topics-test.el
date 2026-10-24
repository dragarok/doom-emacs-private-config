;;; org-summary-topics-test.el --- Weekly topics: the block and the planner -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/org-summary-topics-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.
;; Optionally ORG_TEMPLATES=~/org/templates checks the real review templates.

(require 'ert)
(require 'org-summary)
(require 'org-agenda)

(defconst topics-test--tags
  '("mentalmodels" "notesrevision" "mentalgym" "weeklyvideo" "booksrevision" "roomcleanup"))

(defconst topics-test--daily-tags '("essaytime" "dailywriting" "guitarpractice"))

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
SCHEDULED: <2026-10-25 Sun>
* TODO Someday: all of Munger's list :mentalmodels:
* TODO Revise Category Theory notes :notesrevision:
DEADLINE: <2026-10-26 Mon>
:LOGBOOK:
CLOCK: [2026-10-22 Thu 20:00]--[2026-10-22 Thu 20:25] =>  0:25
:END:
* CANCELED Process old highlights :booksrevision:
CLOSED: [2026-10-20 Tue 10:00]
* DONE Clean desk :roomcleanup:
CLOSED: [2026-10-24 Sat 11:00]
* DONE Scales, 15 min :guitarpractice:
CLOSED: [2026-10-20 Tue 21:00]
:LOGBOOK:
CLOCK: [2026-10-20 Tue 20:45]--[2026-10-20 Tue 21:00] =>  0:15
:END:
* DONE 300 words on the commute :dailywriting:
CLOSED: [2026-10-23 Fri 08:30]
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

;; A repertoire whose file tag is a topic: a backlog, never "planned"; its
;; clocked time counts.
(defconst topics-test--songs "#+FILETAGS: guitarpractice
* In Progress
** PRACTICING Sham
:LOGBOOK:
CLOCK: [2026-10-22 Thu 21:00]--[2026-10-22 Thu 21:20] =>  0:20
:END:
** TOPRACTICE Basanta
")

(defconst topics-test--recurring "* Habits
** TODO [#B] Stretching :Morning:
SCHEDULED: <2026-10-25 Sun .+1d>
:PROPERTIES:
:STYLE:    habit
:ICON:     nf-md-yoga
:END:
:LOGBOOK:
- State \"DONE\"       from \"TODO\"       [2026-10-22 Thu 07:00]
:END:
** TODO [#C] Sketching :personal:
SCHEDULED: <2026-10-25 Sun .+1d>
:PROPERTIES:
:STYLE:    habit
:END:
:LOGBOOK:
- State \"DONE\"       from \"TODO\"       [2026-10-21 Wed 19:00]
:END:
")

(defconst topics-test--topics-file "#+title: Topics
- Daily :: an explanation, not a topic

* Daily
- essaytime :: Time-boxed essay  nf-md-typewriter
- dailywriting :: Writing something
- guitarpractice :: Guitar practice  nf-md-guitar_acoustic

* Weekly
- mentalmodels :: Mental models
- booksrevision
")

(defvar org-tasks-file)
(defvar org-recurring-file)

(defmacro topics-test--with-org (&rest body)
  "BODY with a fresh tasks.org (and its archive) as the only agenda file."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "topics-test" t))
          (org-tasks-file (expand-file-name "tasks.org" dir))
          (org-recurring-file (expand-file-name "recurring.org" dir))
          (org-summary-topics-file (expand-file-name "topics.org" dir))
          (org-agenda-files (list org-tasks-file))
          (org-archive-location (concat dir "/archive.org::datetree/"))
          (org-todo-keywords '((sequence "TODO" "|" "DONE" "CANCELED")
                               (sequence "TOPRACTICE" "PRACTICING" "|" "PRACTICED")))
          (org-summary-tag-groups (list (cons "Topics" topics-test--tags)
                                        (cons "Daily topics" topics-test--daily-tags)))
          (org-summary-plots-directory dir)
          (org-tags-column -77)
          (org-log-done nil))
     (with-temp-file org-tasks-file (insert topics-test--tasks))
     (with-temp-file org-recurring-file (insert topics-test--recurring))
     (with-temp-file (expand-file-name "archive.org" dir) (insert topics-test--archive))
     (with-temp-file (expand-file-name "log_guitar.org" dir) (insert topics-test--songs))
     (push (expand-file-name "log_guitar.org" dir) org-agenda-files)
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

(defun topics-test--block-text (header)
  "Any block written for HEADER (\"NAME PARAMS\"), as text."
  (with-temp-buffer
    (org-mode)
    (insert "#+BEGIN: " header "\n#+END:\n")
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
  "A column a day; time, done and planned; cancelled is not done."
  (topics-test--with-org
    (let ((out (topics-test--block ":span thisweek :date \"2026-10-24\"")))
      (should (string-match-p "| Topic +| Mon | Tue | Wed | Thu | Fri | Sat | Sun | Time | Done | Planned |" out))
      ;; Clocked Mon and Wed, closed Wed; the archived habit's Friday clock
      ;; counts; the undated "Someday" task is not planned.
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
      ;; Nothing dated is nothing planned, even where something got done.
      (should (string-match-p "^Nothing planned: mentalgym, weeklyvideo, booksrevision, roomcleanup$" out)))))

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
      (should (string-match-p "| Topic +| Days | Time | Done | Planned |" out))
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
      (should (string-prefix-p "mentalmodels [planned: Second-order thinking: read chapter] — task" (nth 0 prompts)))
      (should (string-match-p "\\[planned: Inversion: 3 examples from work; Second-order" (nth 1 prompts)))
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

;;; Daily topics

(ert-deftest topics-test-daily-block ()
  "The daily topics have their own table, the same shape."
  (topics-test--with-org
    (let ((out (topics-test--block ":group \"Daily topics\" :span thisweek :date \"2026-10-24\"")))
      ;; The song practised Thursday counts; the songs are not planned.
      (should (equal (topics-test--row out "guitarpractice")
                     '("" "✓" "" "✓" "" "" "" "0:35" "1" "0")))
      (should (equal (topics-test--row out "dailywriting")
                     '("" "" "" "" "✓" "" "" "" "1" "0")))
      (should-not (topics-test--row out "mentalmodels"))
      (should (string-match-p "^Nothing planned: essaytime, dailywriting, guitarpractice$" out)))))

(ert-deftest topics-test-plan-tomorrow ()
  "Tomorrow's tasks: the three daily topics only, scheduled tomorrow."
  (topics-test--with-org
    (let* ((tomorrow (time-add nil (* 24 3600)))
           (prompts (topics-test--answering '("Essay outline: why habits fail, 25 min" ""
                                              "" "Chord changes G-C-D, 20 min" "")
                      (org-summary-plan-tomorrow))))
      (should (= (length prompts) 5))
      (should (string-match-p (format-time-string "^essaytime — task for %a %d " tomorrow) (nth 0 prompts)))
      ;; The repertoire is not listed as planned.
      (should (string-prefix-p "guitarpractice — task for" (nth 3 prompts)))
      (with-current-buffer (find-file-noselect org-tasks-file)
        (should (equal (org-map-entries (lambda () (list (org-get-heading t t t t)
                                                         (org-entry-get nil "SCHEDULED")
                                                         (org-entry-get nil "CATEGORY")))
                                        "CATEGORY=\"ToImprove\"")
                       (list (list "Essay outline: why habits fail, 25 min"
                                   (format-time-string "<%Y-%m-%d %a>" tomorrow) "ToImprove")
                             (list "Chord changes G-C-D, 20 min"
                                   (format-time-string "<%Y-%m-%d %a>" tomorrow) "ToImprove"))))))))

;;; The topics file

(defmacro topics-test--with-topics-file (&rest body)
  "BODY in `topics-test--with-org', with the topics written to their file."
  (declare (indent 0))
  `(topics-test--with-org
     (with-temp-file org-summary-topics-file (insert topics-test--topics-file))
     ,@body))

(ert-deftest topics-test-file-read ()
  "Lines under Daily and Weekly, with an optional icon; nothing else."
  (topics-test--with-topics-file
    (should (equal (org-summary-topics)
                   '(("essaytime" "Daily" "Time-boxed essay" "nf-md-typewriter")
                     ("dailywriting" "Daily" "Writing something" nil)
                     ("guitarpractice" "Daily" "Guitar practice" "nf-md-guitar_acoustic")
                     ("mentalmodels" "Weekly" "Mental models" nil)
                     ("booksrevision" "Weekly" "" nil))))
    ;; The file's groups win over `org-summary-tag-groups'.
    (should (equal (org-summary--group "Daily topics")
                   '("Daily topics" "essaytime" "dailywriting" "guitarpractice")))
    (should (equal (org-summary--group "Topics") '("Topics" "mentalmodels" "booksrevision")))))

(ert-deftest topics-test-file-plans ()
  "The planner asks for the file's topics, showing their descriptions."
  (topics-test--with-topics-file
    (let ((prompts (topics-test--answering nil (org-summary-plan-tomorrow))))
      (should (= (length prompts) 3))
      (should (string-prefix-p "essaytime (Time-boxed essay) — task for" (nth 0 prompts)))
      (should (string-prefix-p "guitarpractice (Guitar practice) — task for" (nth 2 prompts))))
    (let ((prompts (topics-test--answering nil (org-summary-plan-topics))))
      (should (equal (mapcar (lambda (p) (car (split-string p))) prompts)
                     '("mentalmodels" "booksrevision"))))))

(ert-deftest topics-test-add-topic ()
  "A new topic goes at the end of its kind's list; a used or bad tag is refused;
a missing kind's heading is made."
  (topics-test--with-topics-file
    (let ((org-tag-alist nil))
      (org-summary-add-topic "pushups" "Daily" "Push-ups  nf-md-arm_flex")
      (should (equal (assoc "pushups" (org-summary-topics))
                     '("pushups" "Daily" "Push-ups" "nf-md-arm_flex")))
      (should (equal (car (last (org-summary--group "Daily topics"))) "pushups"))
      (should (string-match-p "- guitarpractice :: Guitar practice  nf-md-guitar_acoustic\n- pushups :: Push-ups  nf-md-arm_flex\n\n\\* Weekly"
                              (with-temp-buffer (insert-file-contents org-summary-topics-file)
                                                (buffer-string))))
      (should (assoc "pushups" org-tag-alist))
      (should-error (org-summary-add-topic "guitarpractice" "Weekly" "Again") :type 'user-error)
      (should-error (org-summary-add-topic "two words" "Weekly" "No") :type 'user-error)))
  (topics-test--with-org
    (org-summary-add-topic "pushups" "Weekly" "Push-ups")
    (should (equal (org-summary-topics) '(("pushups" "Weekly" "Push-ups" nil))))))

(ert-deftest topics-test-habit-to-topic ()
  "On a habit: it gets the tag, is archived with its log, and is a topic."
  (topics-test--with-topics-file
    (let ((org-tag-alist nil))
      (with-current-buffer (find-file-noselect org-recurring-file)
        (goto-char (point-min))
        (re-search-forward "Sketching")
        (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                  ((symbol-function 'completing-read) (lambda (&rest _) "Daily"))
                  ((symbol-function 'read-string) (lambda (_p &optional init &rest _) init)))
          (call-interactively #'org-summary-add-topic)))
      (should (equal (assoc "sketching" (org-summary-topics))
                     '("sketching" "Daily" "Sketching" nil)))
      (let ((recurring (with-temp-buffer (insert-file-contents org-recurring-file) (buffer-string)))
            (archive (with-temp-buffer
                       (insert-file-contents (expand-file-name "archive.org"
                                                               (file-name-directory org-tasks-file)))
                       (buffer-string))))
        (should-not (string-match-p "Sketching" recurring))
        (should (string-match-p "Stretching" recurring))
        (should (string-match-p "TODO \\[#C\\] Sketching +:sketching:personal:" archive))
        (should (string-match-p "State \"DONE\" +from \"TODO\" +\\[2026-10-21" archive))))))

(ert-deftest topics-test-no-file ()
  "Without the topics file, a plain message saying so."
  (topics-test--with-org
    (let ((org-summary-tag-groups nil))
      (should (string-match-p "No topics file at .*topics\\.org yet"
                              (cadr (should-error (org-summary--group "Daily topics")
                                                  :type 'user-error)))))))

;;; Topics in the habit charts

(ert-deftest topics-test-topic-habits ()
  "Each topic is a habit: done on days its tasks were clocked or closed,
skipped where one was cancelled; daily or weekly; its icon."
  (topics-test--with-topics-file
    (let* ((hs (org-summary-topic-habits))
           (guitar (seq-find (lambda (h) (equal (plist-get h :tag) "guitarpractice")) hs))
           (books (seq-find (lambda (h) (equal (plist-get h :tag) "booksrevision")) hs))
           (day (lambda (iso) (org-summary--parse-iso iso))))
      (should (equal (mapcar (lambda (h) (plist-get h :title)) hs)
                     '("Time-boxed essay" "Writing something" "Guitar practice"
                       "Mental models" "booksrevision")))
      (should (eq (gethash (funcall day "2026-10-20") (plist-get guitar :log)) 'done))
      (should (eq (gethash (funcall day "2026-10-22") (plist-get guitar :log)) 'done))
      (should (= (plist-get guitar :first) (funcall day "2026-10-20")))
      (should (= (plist-get guitar :every) 1))
      (should (plist-get guitar :path))
      (should (eq (gethash (funcall day "2026-10-20") (plist-get books :log)) 'skipped))
      (should (= (plist-get books :every) 7))
      ;; Found by description or by tag, as a habit is by its heading.
      (should (equal (plist-get (org-summary-habit "Guitar practice") :tag) "guitarpractice"))
      (should (equal (plist-get (org-summary-habit "dailywriting") :title) "Writing something"))
      (should (equal (plist-get (org-summary-habit "Stretching") :every) 1)))))

(ert-deftest topics-test-habit-charts ()
  "The habit month shows the icon habits and the daily topics with an icon;
the active habits and the calendar include the topics."
  (topics-test--with-topics-file
    (should (equal (mapcar (lambda (h) (plist-get h :title)) (org-summary-icon-habits))
                   '("Stretching" "Time-boxed essay" "Guitar practice")))
    (let ((range (org-summary--month (org-summary--parse-iso "2026-10-01"))))
      (should (member "Guitar practice"
                      (mapcar (lambda (h) (plist-get h :title))
                              (org-summary--active-habits (car range) (cdr range))))))
    (let ((out (topics-test--block-text
                "habits-month :month \"2026-10\"")))
      (should (string-match-p "\\[\\[file:.*daily_habits_2026-10\\.svg\\]\\]" out)))
    (let ((out (topics-test--block-text
                "habit-calendar :month \"2026-10\" :habits (\"Guitar practice\")")))
      (should (string-match-p "Guitar_practice_2026-10\\.svg" out))
      (should (string-match-p "done 2 of" out)))))

;;; The real templates (only with ORG_TEMPLATES set)

(defun topics-test--template (file)
  "A buffer with the template FILE from ORG_TEMPLATES, in Org mode."
  (let ((b (generate-new-buffer file)))
    (with-current-buffer b
      (insert-file-contents (expand-file-name file (getenv "ORG_TEMPLATES")))
      (org-mode))
    b))

(defun topics-test--run-step (heading answers)
  "Run the first planner src block under HEADING with ANSWERS; the prompts."
  (goto-char (point-min))
  (should (re-search-forward (concat "^\\*\\* TODO " (regexp-quote heading)) nil t))
  (should (re-search-forward "^#\\+begin_src e\\(macs-\\)?lisp" nil t))
  (should (looking-at-p "[^\n]*\n(org-summary-plan-"))
  (let ((org-confirm-babel-evaluate nil))
    (topics-test--answering answers (org-babel-execute-src-block))))

(defun topics-test--tables (buffer)
  "Refresh BUFFER's topics blocks; the groups whose table came out."
  (with-current-buffer buffer
    (goto-char (point-min))
    (let (groups)
      (while (re-search-forward "^#\\+BEGIN: topics\\(.*\\)$" nil t)
        (let ((g (if (string-match-p "Daily topics" (match-string 1)) "Daily topics" "Topics")))
          (beginning-of-line)
          (org-update-dblock)
          (should (looking-at-p "#\\+BEGIN: topics.*\n| Topic "))
          (push g groups)
          (forward-line)))
      (nreverse groups))))

(defun topics-test--planned ()
  "Headings and scheduled dates of the planned tasks."
  (with-current-buffer (find-file-noselect org-tasks-file)
    (revert-buffer t t)
    (org-map-entries (lambda () (cons (org-get-heading t t t t) (org-entry-get nil "SCHEDULED")))
                     "CATEGORY=\"ToImprove\"")))

(ert-deftest topics-test-templates-weekly ()
  "Weekly and monthly reviews show both tables; the weekly planning step
plans the weekly topics, scheduled today."
  (skip-unless (getenv "ORG_TEMPLATES"))
  (dolist (f '("weeklyreviewtemplate.org" "weeklyreviewtemplate_lastweek.org"
               "monthlyreviewtemplate.org"))
    (topics-test--with-org
      (let ((b (topics-test--template f)))
        (unwind-protect
            (with-current-buffer b
              (should (equal (topics-test--tables b) '("Topics" "Daily topics")))
              (unless (string-prefix-p "monthly" f)
                (let ((prompts (topics-test--run-step "Plan this week's topics"
                                                      (list (concat "From " f) ""))))
                  (should (= (length prompts) 7))
                  (should (string-prefix-p "mentalmodels" (car prompts))))
                (should (equal (topics-test--planned)
                               (list (cons (concat "From " f) (format-time-string "<%Y-%m-%d %a>")))))))
          (kill-buffer b))))))

(ert-deftest topics-test-templates-daily ()
  "The daily reviews show the daily table and plan the daily topics: the
evening review for tomorrow, the next-morning one for today."
  (skip-unless (getenv "ORG_TEMPLATES"))
  (dolist (f '(("dailyreviewtemplate.org" "Plan for tomorrow" 1)
               ("dailyreviewtemplate_yesterday.org" "Plan for today" 0)))
    (topics-test--with-org
      (let ((b (topics-test--template (car f))))
        (unwind-protect
            (with-current-buffer b
              (should (equal (topics-test--tables b) '("Daily topics")))
              (let ((prompts (topics-test--run-step (nth 1 f) (list (concat "From " (car f)) ""))))
                (should (= (length prompts) 4))
                (should (string-prefix-p "essaytime" (car prompts))))
              (should (equal (topics-test--planned)
                             (list (cons (concat "From " (car f))
                                         (format-time-string "<%Y-%m-%d %a>"
                                                             (time-add nil (* (nth 2 f) 24 3600))))))))
          (kill-buffer b))))))

;;; org-summary-topics-test.el ends here
