;;; org-summary.el --- Review numbers and charts, straight from Org -*- lexical-binding: t -*-

;;; Commentary:
;; The reviews used to ask a Python package (orgsummary, over orgparse,
;; pandas and matplotlib) for their numbers and pictures, through a
;; virtualenv only the Mac had.  Org already holds every one of those
;; numbers -- the CLOCK lines, the habits' LOGBOOK, the review datetrees --
;; so this reads them in place and writes the answers into dynamic blocks,
;; with the charts drawn by svg.el.  A review refreshes with C-c C-c on any
;; machine that has Emacs, the phone included.
;;
;; The blocks.  Each takes :span (today, yesterday, thisweek, lastweek,
;; thismonth, lastmonth, or a number of days), counted from the date of the
;; datetree the block sits in -- so refreshing an old review still shows its
;; own week -- or from :date "YYYY-MM-DD", or from today.
;;
;;   period-summary    time logged, top tasks, tasks closed, habit consistency
;;   clock-score       the day's clocked tasks, scored by priority
;;   clock-chart       bars of time by :by day, tag, category or task
;;   review-days       a review datetree's answers, a column a day
;;   review-stats      averages and counts over those answers
;;   habit-calendar    the month as a grid per habit (the old july plot)
;;   project-summary   each PROJ: tasks done and open, time, deadline
;;   project-progress  tasks closed so far, a line per project
;;
;; Charts are written to `org-summary-plots-directory' and linked relative to
;; the review, so the link resolves on every machine the org tree syncs to.
;; `org-summary-dashboard' puts them all in one buffer for any span.

;;; Code:

(require 'org)
(require 'org-clock)
(require 'org-duration)
(require 'svg)
(require 'calendar)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar org-recurring-file)              ; config.el
(defvar org-projects-file)
(defvar org-dailyreview-file)
(defvar org-weeklyreview-file)
(defvar org-lookbacks-directory)
(declare-function org-capture-get "org-capture")
(defvar org-capture-last-stored-marker)

(defvar org-summary-count-score
  '((?A . 500) (?B . 150) (?C . 100) (?D . 60) (?E . 30) (?F . 0))
  "Points for each task clocked on the day, by priority.")

(defvar org-summary-clock-score
  '((?A . 8) (?B . 6) (?C . 4) (?D . 4) (?E . 2) (?F . 1))
  "Points for each minute clocked on a task, by priority.")

(defvar org-summary-tag-groups nil
  "Named groups of tags, as ((NAME TAG ...) ...): orgsummary's tags.yaml.
A task belongs to a group's first tag it carries.  `clock-chart' takes a
NAME as :by, and `period-summary' splits time by each of
`org-summary-summary-groups'.")

(defvar org-summary-summary-groups nil
  "Names in `org-summary-tag-groups' that `period-summary' splits time by.")

(defvar org-summary-plots-directory nil
  "Where charts are written; nil means plots/ in `org-lookbacks-directory'.")

(defvar org-summary-review-keys '("rw" "rl" "rm" "rq" "rd" "ry")
  "Capture templates whose blocks fill in as the capture opens.")

;; One quiet palette for every chart: a white card, GitHub-ish greys,
;; and the habit states in green, amber and a muted red.
(defconst org-summary--colors
  '((done . "#2da44e") (skipped . "#f2a65a") (missed . "#e5534b")
    (none . "#ebedf0") (pending . "#ebedf0") (future . "#f6f8fa"))
  "Habit day fills.")

(defconst org-summary--grades
  '((all . "#2da44e") (most . "#aceebb") (some . "#f2a65a") (none . "#e5534b"))
  "Day fills in the habit month: all, half or more, under half, none done.")

(defconst org-summary--levels '("#ebedf0" "#aceebb" "#4ac26b" "#2da44e" "#116329")
  "Year overview fills, from no habit done to all of them.")

(defconst org-summary--palette
  '("#4078c0" "#e07a3f" "#2da44e" "#8250df" "#d4a72c" "#1b9aaa" "#bf3989" "#6e7781")
  "Series colours for the bar and line charts.")

(defconst org-summary--ink '((text . "#1f2328") (muted . "#656d76") (faint . "#afb8c1")
                             (rule . "#d0d7de") (grid . "#eaeef2")))

(defun org-summary--ink (k) (alist-get k org-summary--ink))

(defconst org-summary--font "Helvetica Neue, Helvetica, Arial, sans-serif")

;;; Days
;; A day is its absolute day number, as `time-to-days' and the calendar count.

(defun org-summary--day (y m d)
  (calendar-absolute-from-gregorian (list m d y)))

(defun org-summary--ymd (day)
  (let ((g (calendar-gregorian-from-absolute day)))
    (list (nth 2 g) (nth 0 g) (nth 1 g))))

(defun org-summary--time (day)
  (pcase-let ((`(,y ,m ,d) (org-summary--ymd day)))
    (encode-time (list 0 0 12 d m y nil -1 nil))))

(defun org-summary--fmt (day fmt)
  (format-time-string fmt (org-summary--time day)))

(defun org-summary--iso (day) (org-summary--fmt day "%Y-%m-%d"))

(defun org-summary--parse-iso (s)
  (when (and (stringp s)
             (string-match "\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" s))
    (org-summary--day (string-to-number (match-string 1 s))
                      (string-to-number (match-string 2 s))
                      (string-to-number (match-string 3 s)))))

(defun org-summary--week (day)
  "Monday to Sunday around DAY."
  (let ((mon (- day (mod (1- (calendar-day-of-week (calendar-gregorian-from-absolute day))) 7))))
    (cons mon (+ mon 6))))

(defun org-summary--month (day)
  (pcase-let ((`(,y ,m ,_) (org-summary--ymd day)))
    (cons (org-summary--day y m 1)
          (org-summary--day y m (calendar-last-day-of-month m y)))))

(defun org-summary--anchor ()
  "The day the block at point reports from: its datetree's, else today.
A day heading (2026-10-24 Saturday) gives that day; a month heading
\(2026-10 October) gives today if it falls in that month, else its last day."
  (let ((today (org-today)))
    (or (save-restriction
          (widen)
          (save-excursion
            (catch 'found
              (unless (ignore-errors (org-back-to-heading t) t)
                (throw 'found nil))
              (while t
                (let ((h (org-get-heading t t t t)))
                  (cond
                   ((string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" h)
                    (throw 'found (org-summary--parse-iso h)))
                   ((string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)\\(?: \\|\\'\\)" h)
                    (let ((m (org-summary--month
                              (org-summary--day (string-to-number (match-string 1 h))
                                                (string-to-number (match-string 2 h)) 1))))
                      (throw 'found (min (max today (car m)) (cdr m)))))))
                (unless (org-up-heading-safe) (throw 'found nil))))))
        today)))

(defun org-summary--range (params default)
  "Inclusive (START . END) for PARAMS' :span, DEFAULT when it has none."
  (let ((a (or (org-summary--parse-iso (plist-get params :date)) (org-summary--anchor)))
        (span (format "%s" (or (plist-get params :span) default))))
    (pcase span
      ((or "today" "day") (cons a a))
      ("yesterday" (cons (1- a) (1- a)))
      ((or "thisweek" "week") (org-summary--week a))
      ("lastweek" (org-summary--week (- a 7)))
      ((or "thismonth" "month") (org-summary--month a))
      ("lastmonth" (org-summary--month (1- (car (org-summary--month a)))))
      ((pred (string-match-p "\\`[0-9]+\\'"))
       (cons (- a (1- (string-to-number span))) a))
      (_ (user-error "org-summary: unknown :span %s" span)))))

(defun org-summary--range-label (range)
  (if (= (car range) (cdr range))
      (org-summary--fmt (car range) "%a %Y-%m-%d")
    (format "%s – %s" (org-summary--iso (car range)) (org-summary--iso (cdr range)))))

(defun org-summary--dur (minutes)
  (org-duration-from-minutes (or minutes 0) 'h:mm))

;;; Reading org

(defmacro org-summary--in-file (file &rest body)
  "Run BODY widened in FILE's buffer, visiting it if need be."
  (declare (indent 1))
  `(with-current-buffer (or (find-buffer-visiting ,file) (find-file-noselect ,file t))
     (org-with-wide-buffer ,@body)))

(defun org-summary--files ()
  "Agenda files and their archives, the clocktable's agenda-with-archives."
  (seq-filter #'file-exists-p (org-add-archive-files (org-agenda-files t))))

(defun org-summary--title ()
  (substring-no-properties (org-link-display-format (org-get-heading t t t t))))

(defun org-summary--heading-info (file)
  (let ((c (org-heading-components)))
    (list :title (org-summary--title) :file file :pos (point)
          :todo (nth 2 c) :priority (or (nth 3 c) org-priority-default)
          :tags (org-get-tags) :category (org-get-category))))

(defconst org-summary--clock-re
  "^[ \t]*CLOCK: \\[\\([^]]+\\)\\]--\\[\\([^]]+\\)\\]")

(defun org-summary-clocks (start end &optional files)
  "Clocks begun on days START..END in FILES, as plists with :day and :minutes."
  (let (out)
    (dolist (file (or files (org-summary--files)) out)
      (org-summary--in-file file
        (let ((info (make-hash-table)))
          (goto-char (point-min))
          (while (re-search-forward org-summary--clock-re nil t)
            (let* ((s0 (match-string 1)) (s1 (match-string 2))
                   (t0 (org-time-string-to-time s0))
                   (t1 (org-time-string-to-time s1))
                   (day (time-to-days t0))
                   (h (and (<= start day end)
                           (save-excursion (and (ignore-errors (org-back-to-heading t) t)
                                                (point))))))
              (when h
                (push (append (list :day day
                                    :minutes (/ (round (float-time (time-subtract t1 t0))) 60))
                              (or (gethash h info)
                                  (puthash h (save-excursion (goto-char h)
                                                             (org-summary--heading-info file))
                                           info)))
                      out)))))))))

(defun org-summary-closed (start end &optional files)
  "Entries CLOSED on days START..END in FILES, as plists with :day."
  (let (out)
    (dolist (file (or files (org-summary--files)) out)
      (org-summary--in-file file
        (goto-char (point-min))
        (while (re-search-forward "CLOSED: *\\[\\([^]]+\\)\\]" nil t)
          (let ((day (time-to-days (org-time-string-to-time (match-string 1)))))
            (when (and (<= start day end)
                       (save-excursion (beginning-of-line) (org-at-planning-p)))
              (save-excursion
                (org-back-to-heading t)
                (push (append (list :day day) (org-summary--heading-info file)) out)))))))))

;; Agent, waiting and passive time (agent-time.el), in :RUNS: drawers.  An
;; open line is still running: it counts up to now.
(defconst org-summary--run-re
  "^[ \t]*\\(AGENT\\|WAIT\\|PASSIVE\\): \\[\\([^]]+\\)\\]\\(?:--\\[\\([^]]+\\)\\]\\)?")

(defun org-summary-runs (start end &optional files)
  "Runs begun on days START..END in FILES, as plists: :kind (\"AGENT\", \"WAIT\"
or \"PASSIVE\"), :from and :to (float times), :day, :minutes, :open, and
the entry's heading info."
  (let (out)
    (dolist (file (or files (org-summary--files)) out)
      (org-summary--in-file file
        (let ((info (make-hash-table)))
          (goto-char (point-min))
          (while (re-search-forward org-summary--run-re nil t)
            (let* ((kind (match-string 1)) (s0 (match-string 2)) (s1 (match-string 3))
                   (t0 (float-time (org-time-string-to-time s0)))
                   (t1 (if s1 (float-time (org-time-string-to-time s1)) (float-time)))
                   (day (time-to-days t0))
                   (h (and (<= start day end) (> t1 t0)
                           (save-excursion (and (ignore-errors (org-back-to-heading t) t)
                                                (point))))))
              (when h
                (push (append (list :kind kind :from t0 :to t1 :day day :open (null s1)
                                    :minutes (/ (round (- t1 t0)) 60))
                              (or (gethash h info)
                                  (puthash h (save-excursion
                                               (goto-char h)
                                               (append (list :project (org-entry-get nil "AGENT_PROJECT"))
                                                       (org-summary--heading-info file)))
                                           info)))
                      out)))))))))

(defun org-summary--merged-minutes (items)
  "Wall-clock minutes ITEMS (:from/:to) cover, overlaps counted once."
  (let ((total 0) cur)
    (dolist (i (sort (mapcar (lambda (i) (cons (plist-get i :from) (plist-get i :to))) items)
                     (lambda (a b) (< (car a) (car b)))))
      (if (and cur (<= (car i) (cdr cur)))
          (setcdr cur (max (cdr cur) (cdr i)))
        (when cur (cl-incf total (- (cdr cur) (car cur))))
        (setq cur (cons (car i) (cdr i)))))
    (when cur (cl-incf total (- (cdr cur) (car cur))))
    (/ (round total) 60)))

(defun org-summary--most-at-once (items)
  "The most ITEMS (:from/:to) running at the same moment."
  (let ((edges (sort (mapcan (lambda (i) (list (cons (plist-get i :from) 1)
                                               (cons (plist-get i :to) -1)))
                             items)
                     (lambda (a b) (or (< (car a) (car b))
                                       (and (= (car a) (car b)) (< (cdr a) (cdr b)))))))
        (n 0) (most 0))
    (dolist (e edges most)
      (setq most (max most (cl-incf n (cdr e)))))))

(defun org-summary--sum (items key)
  "Minutes of ITEMS summed under KEY's value, largest first, as (K . MINUTES)."
  (let ((h (make-hash-table :test 'equal)) out)
    (dolist (it items)
      (let ((k (funcall key it)))
        (dolist (k (if (listp k) (or k '("(untagged)")) (list k)))
          (puthash k (+ (gethash k h 0) (plist-get it :minutes)) h))))
    (maphash (lambda (k v) (push (cons k v) out)) h)
    (sort out (lambda (a b) (> (cdr a) (cdr b))))))

;;; Tag groups

(defun org-summary--group (name)
  (or (assoc name org-summary-tag-groups)
      (user-error "org-summary: no tag group %s in `org-summary-tag-groups'" name)))

(defun org-summary--in-group (group)
  "A key function: the first of GROUP's tags an item carries, or \"(none)\"."
  (lambda (it) (or (seq-find (lambda (tag) (member tag (plist-get it :tags))) (cdr group))
                   "(none)")))

;;; Habits

(defconst org-summary--state-re
  "^[ \t]*- State \"\\([^\"]+\\)\"[ \t]+from[ \t]+\"[^\"]*\"[ \t]+\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)")

(defun org-summary-habits ()
  "Titles of the habits in `org-recurring-file'."
  (org-summary--in-file org-recurring-file
    (org-map-entries #'org-summary--title "STYLE=\"habit\"")))

(defun org-summary-habit (title)
  "TITLE's history: plist of :title, :log (day -> done or skipped), :first, :every.
Nil when `org-recurring-file' has no such heading."
  (org-summary--in-file org-recurring-file
    (when-let* ((pos (org-find-exact-headline-in-buffer title nil t)))
      (goto-char pos)
      (let ((end (save-excursion (org-end-of-subtree t t)))
            (sched (or (org-entry-get nil "SCHEDULED") ""))
            (log (make-hash-table))
            first)
        (while (re-search-forward org-summary--state-re end t)
          (let* ((state (match-string 1))
                 (day (org-summary--parse-iso (match-string 2))))
            (setq first (if first (min first day) day))
            (unless (eq (gethash day log) 'done)
              (puthash day (if (equal state "DONE") 'done 'skipped) log))))
        (list :title title :log log :first first
              :every (if (string-match "[.+]?\\+\\([0-9]+\\)\\([hdwmy]\\)" sched)
                         (max 1 (* (string-to-number (match-string 1 sched))
                                   (pcase (match-string 2 sched)
                                     ("w" 7) ("m" 30) ("y" 365) (_ 1))))
                       1))))))

(defun org-summary--status (habit day)
  "HABIT's state on DAY: done, skipped, missed, pending, future or none.
Only a daily habit misses days; a weekly one is judged by its count."
  (let ((today (org-today))
        (first (plist-get habit :first)))
    (or (gethash day (plist-get habit :log))
        (cond ((> day today) 'future)
              ((= day today) 'pending)
              ((or (null first) (< day first) (> (plist-get habit :every) 1)) 'none)
              (t 'missed)))))

(defun org-summary--habit-stats (habit start end)
  "HABIT over START..END: plist of :done :skipped :expected :rate :streak."
  (let* ((today (org-today))
         (log (plist-get habit :log))
         (last (min end (if (gethash today log) today (1- today))))
         (from (max start (or (plist-get habit :first) start)))
         (done 0) (skipped 0) (streak 0))
    (cl-loop for d from start to end
             do (pcase (gethash d log)
                  ('done (cl-incf done))
                  ('skipped (cl-incf skipped))))
    (let ((d (if (gethash today log) today (1- today))))
      (while (memq (gethash d log) '(done skipped))
        (when (eq (gethash d log) 'done) (cl-incf streak))
        (cl-decf d)))
    (let ((expected (if (< last from) 0
                      (ceiling (/ (float (1+ (- last from))) (plist-get habit :every))))))
      (list :done done :skipped skipped :expected expected :streak streak
            :rate (if (> expected 0) (min 1.0 (/ (float done) expected)) nil)))))

(defun org-summary--active-habits (start end)
  "Habits with any logbook entry from 30 days before START to END."
  (seq-filter (lambda (h)
                (let (hit)
                  (maphash (lambda (d _) (when (<= (- start 30) d end) (setq hit t)))
                           (plist-get h :log))
                  hit))
              (delq nil (mapcar #'org-summary-habit (org-summary-habits)))))

;;; Reviews

(defun org-summary--review-file (which)
  (pcase (format "%s" (or which "daily"))
    ("daily" org-dailyreview-file)
    ("weekly" org-weeklyreview-file)
    (f (expand-file-name f org-lookbacks-directory))))

(defun org-summary--answers (limit)
  "The answers between point and LIMIT, as (QUESTION . VALUE), in order.
A checkbox or a TODO heading answers t or :no; a \"Question (hint) :: answer\"
item answers its text.  Blocks are skipped: they hold facts, not answers."
  (let (out in-block)
    (while (< (point) limit)
      (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
        (cond
         ((string-match-p "\\`[ \t]*#\\+begin" (downcase line)) (setq in-block t))
         ((string-match-p "\\`[ \t]*#\\+end" (downcase line)) (setq in-block nil))
         (in-block)
         ((org-at-heading-p)
          (when-let* ((todo (org-get-todo-state)))
            (push (cons (org-summary--title) (if (member todo org-done-keywords) t :no)) out)))
         ((string-match "\\`[ \t]*[-+] \\[\\([ Xx-]\\)\\] \\(.+?\\)[ \t]*\\'" line)
          (push (cons (match-string 2 line)
                      (if (member (match-string 1 line) '("X" "x")) t :no))
                out))
         ((string-match "\\`[ \t]*[-+] \\(.+?\\) ::\\(?:[ \t]+\\(.*?\\)\\)?[ \t]*\\'" line)
          (let ((q (string-trim (replace-regexp-in-string " *(.*\\'" "" (match-string 1 line))))
                (a (match-string 2 line)))
            (when (and a (not (string-empty-p a)) (not (assoc q out)))
              (push (cons q a) out))))))
      (forward-line 1))
    (nreverse out)))

(defun org-summary-reviews (file start end)
  "Answers in FILE's datetree for days START..END, oldest first.
Each is (DAY . ANSWERS)."
  (org-summary--in-file file
    (let (out)
      (goto-char (point-min))
      (while (re-search-forward
              "^\\*+ \\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\) [[:alpha:]]+[ \t]*$" nil t)
        (let ((day (org-summary--parse-iso (match-string 1))))
          (when (<= start day end)
            (let ((limit (save-excursion (org-end-of-subtree t t))))
              (forward-line 1)
              (when-let* ((answers (org-summary--answers limit)))
                (push (cons day answers) out))))))
      (sort out (lambda (a b) (< (car a) (car b)))))))

(defun org-summary--number (s)
  "The number S starts with; a range like 6-7 gives its middle."
  (when (and (stringp s)
             (string-match "\\`[ \t]*\\([0-9]+\\(?:\\.[0-9]+\\)?\\)\\(?:[ \t]*[-–][ \t]*\\([0-9]+\\(?:\\.[0-9]+\\)?\\)\\)?" s))
    (let ((a (string-to-number (match-string 1 s)))
          (b (and (match-string 2 s) (string-to-number (match-string 2 s)))))
      (if b (/ (+ a b) 2.0) a))))

;;; Writing

(defun org-summary--cell (s &optional width)
  (let ((s (replace-regexp-in-string "|" "¦" (format "%s" s))))
    (if width (truncate-string-to-width s width nil nil "…") s)))

(defun org-summary--table (header rows)
  "Insert an aligned table of HEADER over ROWS, leaving point after it."
  (let ((beg (point)) (end (make-marker)))
    (insert "| " (mapconcat #'org-summary--cell header " | ") " |\n|-\n")
    (dolist (r rows)
      (insert "| " (mapconcat #'org-summary--cell r " | ") " |\n"))
    (set-marker end (point))
    (save-excursion (goto-char beg) (org-table-align))
    (goto-char end)
    (set-marker end nil)
    (unless (bolp) (insert "\n"))))

(defun org-summary--end-block ()
  "Drop the last newline: it is the #+END line's."
  (when (eq (char-before) ?\n) (delete-char -1)))

(defun org-summary--plot-file (name)
  (expand-file-name
   (concat (replace-regexp-in-string "[^[:alnum:]-]+" "_" name) ".svg")
   (or org-summary-plots-directory (expand-file-name "plots" org-lookbacks-directory))))

(defun org-summary--link (file)
  "A link to FILE from this buffer's file, so it resolves on every machine."
  (let ((here (buffer-file-name (buffer-base-buffer))))
    (format "[[file:%s]]"
            (if here (file-relative-name file (file-name-directory here))
              (abbreviate-file-name file)))))

(defun org-summary--write-svg (svg file)
  (make-directory (file-name-directory file) t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file file (svg-print svg)))
  (clear-image-cache (expand-file-name file))
  (org-summary--show-images-soon)
  file)

(defun org-summary--show-images-soon ()
  "Show the charts once the block is written, where images can show."
  (let ((buf (current-buffer)))
    (run-at-time 0 nil
                 (lambda ()
                   (when (and (buffer-live-p buf) (display-images-p))
                     (with-current-buffer buf
                       (if (fboundp 'org-link-preview-region)
                           (org-link-preview-region nil t (point-min) (point-max))
                         (with-no-warnings (org-display-inline-images nil t)))))))))

;;; Charts

(defun org-summary--svg (w h)
  "A W by H card: white, rounded, a hairline border."
  ;; As a style, not an attribute: Emacs gives every SVG a stylesheet naming
  ;; the frame's font, and a stylesheet beats a presentation attribute.
  (let ((svg (svg-create w h :style (format "font-family: %s" org-summary--font))))
    (svg-rectangle svg 0.5 0.5 (- w 1) (- h 1) :rx 10 :fill "#ffffff"
                   :stroke (org-summary--ink 'rule) :stroke-width 1)
    svg))

(defun org-summary--title-text (svg title sub x)
  (svg-text svg title :x x :y 28 :font-size 16 :font-weight "600" :fill (org-summary--ink 'text))
  (when sub
    (svg-text svg sub :x x :y 47 :font-size 11.5 :fill (org-summary--ink 'muted))))

(defun org-summary--legend (svg x y keys)
  "Swatches for KEYS of `org-summary--colors' from X along Y."
  (dolist (k keys)
    (svg-rectangle svg x (- y 9) 10 10 :rx 2.5 :fill (alist-get k org-summary--colors))
    (svg-text svg (symbol-name k) :x (+ x 14) :y y :font-size 10.5 :fill (org-summary--ink 'muted))
    (setq x (+ x 22 (* 6.2 (length (symbol-name k))))))
  x)

(defun org-summary-habit-svg (habit y m file)
  "Draw HABIT's month M of Y as a grid, the july plot, into FILE."
  (let* ((cell 40) (gap 4) (pitch (+ cell gap)) (left 42) (top 86)
         (first (org-summary--day y m 1))
         (ndays (calendar-last-day-of-month m y))
         (lead (mod (1- (calendar-day-of-week (list m 1 y))) 7))
         (rows (ceiling (+ lead ndays) 7.0))
         (range (org-summary--month first))
         (st (org-summary--habit-stats habit (car range) (cdr range)))
         (w (+ left (* 7 pitch) 18))
         (h (+ top (* rows pitch) 34))
         (svg (org-summary--svg w h)))
    (org-summary--title-text
     svg (plist-get habit :title)
     (format "%s %d  ·  %d of %d done%s" (calendar-month-name m) y
             (plist-get st :done) (plist-get st :expected)
             (if (plist-get st :rate) (format "  ·  %d%%" (round (* 100 (plist-get st :rate)))) ""))
     left)
    (seq-do-indexed (lambda (d i)
                      (svg-text svg d :x (+ left (* i pitch) (/ cell 2)) :y (- top 9) :font-size 10.5
                                :text-anchor "middle" :fill (org-summary--ink 'muted)))
                    '("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"))
    (dotimes (r rows)
      (svg-text svg (format "W%s" (org-summary--fmt (+ first (- lead) (* 7 r)) "%V"))
                :x (- left 8) :y (+ top (* r pitch) (/ cell 2) 4) :font-size 9.5
                :text-anchor "end" :fill (org-summary--ink 'faint)))
    (dotimes (i ndays)
      (let* ((day (+ first i)) (pos (+ lead i))
             (x (+ left (* (mod pos 7) pitch))) (yy (+ top (* (/ pos 7) pitch)))
             (s (org-summary--status habit day)))
        (svg-rectangle svg x yy cell cell :rx 7 :fill (alist-get s org-summary--colors))
        (when (eq s 'pending)
          (svg-rectangle svg (+ x 1) (+ yy 1) (- cell 2) (- cell 2) :rx 6.5 :fill "none"
                         :stroke (org-summary--ink 'text) :stroke-width 1.5 :stroke-dasharray "4,3"))
        (svg-text svg (number-to-string (1+ i)) :x (+ x (/ cell 2)) :y (+ yy (/ cell 2) 4.5)
                  :font-size 12.5 :font-weight (if (memq s '(done missed skipped)) "600" "400")
                  :text-anchor "middle"
                  :fill (pcase s
                          ((or 'done 'missed) "#ffffff")
                          ('future (org-summary--ink 'faint))
                          (_ (org-summary--ink 'text))))))
    (org-summary--legend svg left (+ top (* rows pitch) 16) '(done skipped missed none))
    (org-summary--write-svg svg file)))

(defun org-summary--longest-streak (habit start end)
  (let ((log (plist-get habit :log)) (best 0) (run 0))
    (cl-loop for d from start to end
             do (pcase (gethash d log)
                  ('done (setq run (1+ run) best (max best run)))
                  ('skipped)
                  (_ (unless (= d (org-today)) (setq run 0)))))
    best))

(defun org-summary-year-svg (habits year file)
  "Draw YEAR for HABITS as day strips, an overview strip on top, into FILE.
The overview shades each day by the share of HABITS done on it."
  (let* ((cell 11) (gap 3) (pitch (+ cell gap)) (left 58) (top 70)
         (first (org-summary--day year 1 1))
         (last (org-summary--day year 12 31))
         (lead (mod (1- (calendar-day-of-week (list 1 1 year))) 7))
         (weeks (ceiling (+ lead (1+ (- last first))) 7.0))
         (strip (+ (* 7 pitch) 30))
         (rows (cons nil habits))
         (w (+ left (* weeks pitch) 20))
         (h (+ top (* (length rows) strip) 26))
         (today (org-today))
         (svg (org-summary--svg w h)))
    (org-summary--title-text
     svg (format "Habits · %d" year)
     (format "%d habit%s  ·  each square a day, weeks run left to right"
             (length habits) (if (= 1 (length habits)) "" "s"))
     left)
    (dotimes (mm 12)
      (let* ((d (org-summary--day year (1+ mm) 1))
             (col (/ (+ lead (- d first)) 7)))
        (svg-text svg (calendar-month-name (1+ mm) t) :x (+ left (* col pitch)) :y (- top 8)
                  :font-size 10 :fill (org-summary--ink 'muted))))
    (seq-do-indexed
     (lambda (h i)
       (let* ((y0 (+ top (* i strip)))
              (title (if h (plist-get h :title) "All habits"))
              (st (and h (org-summary--habit-stats h first (min last today)))))
         (svg-text svg title :x left :y (+ y0 11) :font-size 11.5 :font-weight "600"
                   :fill (org-summary--ink 'text))
         (svg-text svg (if h
                           (format "%d done  ·  %s  ·  longest run %d" (plist-get st :done)
                                   (if (plist-get st :rate)
                                       (format "%d%%" (round (* 100 (plist-get st :rate)))) "–")
                                   (org-summary--longest-streak h first (min last today)))
                         "darker = more of them done")
                   :x (- (+ left (* weeks pitch)) 2) :y (+ y0 11) :font-size 10 :text-anchor "end"
                   :fill (org-summary--ink 'muted))
         (dolist (wd '((0 . "Mon") (2 . "Wed") (4 . "Fri")))
           (svg-text svg (cdr wd) :x (- left 8) :y (+ y0 18 (* (car wd) pitch) 9) :font-size 9
                     :text-anchor "end" :fill (org-summary--ink 'faint)))
         (cl-loop
          for d from first to last
          do (let* ((pos (+ lead (- d first)))
                    (x (+ left (* (/ pos 7) pitch)))
                    (y (+ y0 18 (* (mod pos 7) pitch)))
                    (fill
                     (if h
                         ;; A year of red squares shouts; there a missed day is just empty.
                         (alist-get (pcase (org-summary--status h d) ('missed 'none) (s s))
                                    org-summary--colors)
                       (if (> d today) (alist-get 'future org-summary--colors)
                         (let ((n (seq-count (lambda (hh) (eq (gethash d (plist-get hh :log)) 'done))
                                             habits)))
                           (nth (if (zerop n) 0
                                  (min 4 (1+ (floor (* 4 (/ (float n) (max 1 (length habits))))))))
                                org-summary--levels))))))
               (svg-rectangle svg x y cell cell :rx 2.5 :fill fill)
               (when (= d today)
                 (svg-rectangle svg (- x 1) (- y 1) (+ cell 2) (+ cell 2) :rx 3 :fill "none"
                                :stroke (org-summary--ink 'text) :stroke-width 1.2))))))
     rows)
    (let ((x (org-summary--legend svg left (- h 12) '(done skipped none))))
      (svg-text svg "overview:" :x (+ x 10) :y (- h 12) :font-size 10.5 :fill (org-summary--ink 'muted))
      (seq-do-indexed (lambda (c i)
                        (svg-rectangle svg (+ x 64 (* i 14)) (- h 21) 10 10 :rx 2.5 :fill c))
                      org-summary--levels))
    (org-summary--write-svg svg file)))

(defun org-summary-bars-svg (title items file &optional fmt)
  "Draw ITEMS, ((LABEL . VALUE) ...), as horizontal bars under TITLE into FILE.
FMT turns a value into its label (default `org-summary--dur')."
  (let* ((fmt (or fmt #'org-summary--dur))
         (lw (+ 24 (* 7 (apply #'max 6 (mapcar (lambda (it) (min 24 (length (format "%s" (car it)))))
                                                 items)))))
         (bw 320) (row 26) (top 48)
         (w (+ lw bw 64)) (h (+ top (* (max 1 (length items)) row) 14))
         (mx (max 1 (apply #'max 0 (mapcar #'cdr items))))
         (svg (org-summary--svg w h)))
    (org-summary--title-text svg title nil 16)
    (seq-do-indexed
     (lambda (it i)
       (let ((y (+ top (* i row)))
             (len (* bw (/ (float (cdr it)) mx))))
         (svg-text svg (truncate-string-to-width (format "%s" (car it)) 24 nil nil "…")
                   :x (- lw 10) :y (+ y 17) :font-size 12 :text-anchor "end" :fill (org-summary--ink 'text))
         (svg-rectangle svg lw (+ y 5) bw (- row 10) :rx 4 :fill (org-summary--ink 'grid))
         (svg-rectangle svg lw (+ y 5) (max 2 len) (- row 10) :rx 4
                        :fill (car org-summary--palette))
         (svg-text svg (funcall fmt (cdr it)) :x (+ lw bw 8) :y (+ y 17)
                   :font-size 11 :fill (org-summary--ink 'muted))))
     items)
    (org-summary--write-svg svg file)))

(defun org-summary-lines-svg (title series start end file)
  "Draw SERIES as steps over START..END into FILE.
SERIES is ((NAME . ((DAY . VALUE) ...)) ...)."
  (let* ((w 720) (h 350) (l 46) (r 190) (top 52) (bot 36)
         (pw (- w l r)) (ph (- h top bot))
         (ymax (* 4 (ceiling (apply #'max 1 (mapcan (lambda (s) (mapcar #'cdr (cdr s)))
                                                    (copy-tree series)))
                             4.0)))
         (span (max 1 (- end start)))
         (xof (lambda (d) (+ l (* pw (/ (float (- (min (max d start) end) start)) span)))))
         (yof (lambda (v) (- (+ top ph) (* ph (/ (float v) ymax)))))
         (svg (org-summary--svg w h)))
    (org-summary--title-text svg title nil 16)
    (svg-line svg l (+ top ph) (+ l pw) (+ top ph) :stroke (org-summary--ink 'rule))
    (svg-line svg l top l (+ top ph) :stroke (org-summary--ink 'rule))
    (dotimes (i 5)
      (let* ((v (round (* ymax (/ i 4.0)))) (y (funcall yof v)))
        (svg-line svg l y (+ l pw) y :stroke (org-summary--ink 'grid))
        (svg-text svg (number-to-string v) :x (- l 6) :y (+ y 4) :font-size 10
                  :text-anchor "end" :fill (org-summary--ink 'muted))))
    (let ((d start))
      (while (<= d end)
        (pcase-let ((`(,_ ,_ ,dd) (org-summary--ymd d)))
          (when (= dd 1)
            (svg-text svg (org-summary--fmt d "%b") :x (funcall xof d) :y (+ top ph 16)
                      :font-size 10 :text-anchor "middle" :fill (org-summary--ink 'muted))))
        (setq d (1+ d))))
    (seq-do-indexed
     (lambda (s i)
       (let ((color (nth (mod i (length org-summary--palette)) org-summary--palette))
             (pts nil) (prev nil))
         (dolist (p (cdr s))
           (let ((x (funcall xof (car p))) (y (funcall yof (cdr p))))
             (when prev (push (cons x (cdr prev)) pts))
             (push (cons x y) pts)
             (setq prev (cons x y))))
         (when prev (push (cons (funcall xof end) (cdr prev)) pts))
         (svg-polyline svg (nreverse pts) :fill "none" :stroke color :stroke-width 2.2
                       :stroke-linejoin "round")
         (svg-rectangle svg (+ l pw 14) (+ top (* i 18)) 10 10 :rx 2.5 :fill color)
         (svg-text svg (truncate-string-to-width (format "%s (%d)" (car s) (cdar (last (cdr s))))
                                                 24 nil nil "…")
                   :x (+ l pw 28) :y (+ top (* i 18) 9) :font-size 11 :fill (org-summary--ink 'text))))
     series)
    (org-summary--write-svg svg file)))

;;; Blocks

(defun org-dblock-write:period-summary (params)
  "Time logged, top tasks, tasks closed and habit consistency over :span."
  (let* ((range (org-summary--range params "thisweek"))
         (clocks (org-summary-clocks (car range) (cdr range)))
         (closed (org-summary-closed (car range) (cdr range)))
         (total (apply #'+ (mapcar (lambda (c) (plist-get c :minutes)) clocks)))
         (by-task (org-summary--sum clocks (lambda (c) (plist-get c :title))))
         (by-day (org-summary--sum clocks (lambda (c) (plist-get c :day))))
         (done (seq-remove (lambda (c) (member (plist-get c :todo) '("CANCELED" "CANCELLED")))
                           closed))
         (hard (seq-filter (lambda (c) (memq (plist-get c :priority) '(?A ?B))) done))
         (habits (delq nil
                       (mapcar (lambda (h)
                                 (let ((s (org-summary--habit-stats h (car range) (cdr range))))
                                   (and (plist-get s :rate) (cons (plist-get h :title) s))))
                               (org-summary--active-habits (car range) (cdr range)))))
         (habits (sort habits (lambda (a b) (> (plist-get (cdr a) :rate) (plist-get (cdr b) :rate)))))
         (show (lambda (h) (format "%s (%d/%d)" (car h) (plist-get (cdr h) :done)
                                   (plist-get (cdr h) :expected)))))
    (insert (format "- Period :: %s\n" (org-summary--range-label range)))
    (insert (format "- Total logged time :: %s over %d day%s\n" (org-summary--dur total)
                    (length by-day) (if (= 1 (length by-day)) "" "s")))
    (when by-task
      (insert "- Top tasks :: "
              (mapconcat (lambda (p) (format "%s (%s)" (car p) (org-summary--dur (cdr p))))
                         (seq-take by-task 3) " · ")
              "\n"))
    (when by-day
      (insert (format "- Busiest day :: %s (%s)\n" (org-summary--fmt (caar by-day) "%a %d")
                      (org-summary--dur (cdar by-day)))))
    (dolist (name org-summary-summary-groups)
      (when-let* ((sums (seq-remove (lambda (p) (equal (car p) "(none)"))
                                    (org-summary--sum clocks (org-summary--in-group
                                                              (org-summary--group name))))))
        (insert (format "- Time by %s :: %s\n" name
                        (mapconcat (lambda (p) (format "%s %s" (car p) (org-summary--dur (cdr p))))
                                   sums " · ")))))
    (insert (format "- Tasks closed :: %d, %d of them A or B priority\n" (length done) (length hard)))
    (when habits
      (insert "- Most consistent habit :: " (funcall show (car habits)) "\n")
      (when (cdr habits)
        (insert "- Least consistent habit :: " (funcall show (car (last habits))) "\n"))
      (insert "- Habits :: "
              (mapconcat (lambda (h) (format "%s %d%%" (car h) (round (* 100 (plist-get (cdr h) :rate)))))
                         habits " · ")
              "\n"))
    (org-summary--end-block)))

;; The review questions, answered.  A weekly or monthly review used to end
;; in a list of questions to fill by hand from the daily reviews; every one
;; of them is a count or an average of something already written down.

(defun org-summary--numbers (days key-re)
  "The numeric answers to questions matching KEY-RE in DAYS, as (DAY . N)."
  (delq nil (mapcar (lambda (d)
                      (when-let* ((qa (seq-find (lambda (qa) (and (stringp (cdr qa))
                                                                   (string-match-p key-re (car qa))))
                                                (cdr d)))
                                  (n (org-summary--number (cdr qa))))
                        (cons (car d) n)))
                    days)))

(defun org-summary--not-done (days)
  "Checklist items and TODOs of DAYS left undone, most often first, as text."
  (let ((h (make-hash-table :test 'equal)) out)
    (dolist (d days)
      (dolist (qa (cdr d))
        (when (memq (cdr qa) '(t :no))
          (let ((c (gethash (car qa) h (cons 0 0))))
            (puthash (car qa) (cons (+ (car c) (if (eq (cdr qa) :no) 1 0)) (1+ (cdr c))) h)))))
    (maphash (lambda (k c) (when (> (car c) 0) (push (cons k c) out))) h)
    (mapconcat (lambda (x) (format "%s (%d of %d)" (car x) (cadr x) (cddr x)))
               (seq-take (sort out (lambda (a b) (> (cadr a) (cadr b)))) 4)
               " · ")))

;; Three kinds of time: yours (the org clock), your agents' (and how long
;; they waited on you), and passive (music, cleaning).  See agent-time.el.

(defconst org-summary--kinds
  '(("You" . "#4078c0") ("Agents" . "#8250df") ("Passive" . "#1b9aaa"))
  "The kinds of time and their colours, in the order they are drawn.")

(defun org-summary-kinds-svg (title groups file)
  "Draw GROUPS as grouped bars into FILE.
GROUPS is ((LABEL YOU AGENTS PASSIVE) ...), in minutes."
  (let* ((n (max 1 (length groups))) (l 44) (top 70) (bot 30) (h 300)
         (gw (if (> n 10) 40 66)) (w (max 440 (+ l 16 (* n gw))))
         (ph (- h top bot))
         (hours (max 1 (ceiling (apply #'max 1 (mapcan (lambda (g) (copy-sequence (cdr g))) groups))
                                60.0)))
         (step (max 1 (ceiling hours 4.0)))
         (ymax (* 60 step (ceiling hours (float step))))
         (bw (/ (- gw 14) 3.0))
         (yof (lambda (v) (- (+ top ph) (* ph (/ (float v) ymax)))))
         (svg (org-summary--svg w h)))
    (org-summary--title-text svg title nil 16)
    (let ((x 16))
      (dolist (k org-summary--kinds)
        (svg-rectangle svg x 41 10 10 :rx 2.5 :fill (cdr k))
        (svg-text svg (car k) :x (+ x 14) :y 50 :font-size 11 :fill (org-summary--ink 'muted))
        (setq x (+ x 30 (* 6.5 (length (car k)))))))
    (cl-loop for v from 0 to ymax by (* 60 step)
             do (let ((y (funcall yof v)))
                  (svg-line svg l y (- w 12) y :stroke (org-summary--ink (if (zerop v) 'rule 'grid)))
                  (svg-text svg (format "%dh" (/ v 60)) :x (- l 6) :y (+ y 4) :font-size 10
                            :text-anchor "end" :fill (org-summary--ink 'muted))))
    (seq-do-indexed
     (lambda (g i)
       (let ((x0 (+ l (* i gw) 7)))
         (seq-do-indexed
          (lambda (k j)
            (let ((v (nth (1+ j) g)))
              (when (> v 0)
                (let ((y (funcall yof v)))
                  (svg-rectangle svg (+ x0 (* j bw)) y (- bw 1.5) (max 1.5 (- (+ top ph) y))
                                 :rx 2 :fill (cdr k))))))
          org-summary--kinds)
         (svg-text svg (car g) :x (+ x0 (/ (* 3 bw) 2)) :y (+ top ph 17) :font-size 10
                   :text-anchor "middle" :fill (org-summary--ink 'muted))))
     groups)
    (org-summary--write-svg svg file)))

(defun org-dblock-write:time-kinds (params)
  "Your time, your agents' time and passive time over :span (default this week)."
  (let* ((range (org-summary--range params "thisweek"))
         (clocks (org-summary-clocks (car range) (cdr range)))
         (runs (org-summary-runs (car range) (cdr range)))
         (kind (lambda (k) (seq-filter (lambda (r) (equal (plist-get r :kind) k)) runs)))
         (agent (funcall kind "AGENT")) (wait (funcall kind "WAIT")) (passive (funcall kind "PASSIVE"))
         (mins (lambda (items) (apply #'+ (mapcar (lambda (i) (plist-get i :minutes)) items))))
         (title (lambda (i) (plist-get i :title)))
         (tasks (org-summary--sum (append agent wait) title))
         (done (seq-count (lambda (p) (seq-find (lambda (r) (and (equal (funcall title r) (car p))
                                                                 (member (plist-get r :todo)
                                                                         org-done-keywords)))
                                                agent))
                          tasks))
         (dur #'org-summary--dur)
         (weekly (> (- (cdr range) (car range)) 13)))
    (insert (format "- You :: %s clocked\n" (funcall dur (funcall mins clocks))))
    (insert (format "- Agents :: %s"
                    (if (null agent) "none"
                      (format "%s of agent time on %d task%s (%d done); %s with at least one running, up to %d at once"
                              (funcall dur (funcall mins agent)) (length tasks)
                              (if (= 1 (length tasks)) "" "s") done
                              (funcall dur (org-summary--merged-minutes agent))
                              (org-summary--most-at-once agent))))
            "\n")
    (when wait
      (insert (format "- Agents waiting on you :: %s over %d wait%s, longest %s\n"
                      (funcall dur (funcall mins wait)) (length wait) (if (= 1 (length wait)) "" "s")
                      (funcall dur (apply #'max (mapcar (lambda (w) (plist-get w :minutes)) wait))))))
    (insert (format "- Passive :: %s\n"
                    (if (null passive) "none"
                      (concat (funcall dur (funcall mins passive)) " — "
                              (mapconcat (lambda (p) (format "%s %s" (car p) (funcall dur (cdr p))))
                                         (org-summary--sum passive title) " · ")))))
    (when agent
      (insert "- Agent time by project :: "
              (mapconcat (lambda (p) (format "%s %s" (car p) (funcall dur (cdr p))))
                         (org-summary--sum agent (lambda (r) (or (plist-get r :project)
                                                                 (plist-get r :category))))
                         " · ")
              "\n\n")
      (let ((you (org-summary--sum clocks title))
            (waits (org-summary--sum wait title))
            (agents (org-summary--sum agent title)))
        (org-summary--table
         '("Agent task" "Agents" "You" "Waiting")
         (mapcar (lambda (p) (list (org-summary--cell (car p) 48)
                                   (funcall dur (alist-get (car p) agents 0 nil #'equal))
                                   (funcall dur (alist-get (car p) you 0 nil #'equal))
                                   (funcall dur (alist-get (car p) waits 0 nil #'equal))))
                 (seq-take tasks (or (plist-get params :top) 8))))))
    (when (> (cdr range) (car range))
      (let* ((key (lambda (d) (if weekly (org-summary--fmt d "W%V") (org-summary--fmt d "%a %d"))))
             (labels (delete-dups (cl-loop for d from (car range) to (cdr range)
                                           collect (funcall key d))))
             (by (lambda (items) (org-summary--sum items (lambda (i) (funcall key (plist-get i :day)))))))
        (let ((y (funcall by clocks)) (a (funcall by agent)) (p (funcall by passive)))
          (insert "\n"
                  (org-summary--link
                   (org-summary-kinds-svg
                    (format "Your time, agents', passive · %s" (org-summary--range-label range))
                    (mapcar (lambda (k) (list k (alist-get k y 0 nil #'equal) (alist-get k a 0 nil #'equal)
                                              (alist-get k p 0 nil #'equal)))
                            labels)
                    (org-summary--plot-file (format "time_kinds_%s_%s" (org-summary--iso (car range))
                                                    (org-summary--iso (cdr range))))))
                  "\n"))))
    (org-summary--end-block)))

(defun org-dblock-write:review-answers (params)
  "Answer a weekly or monthly review's questions for :span (default this week)
from the clock, the closed tasks, the habits and the daily reviews; a month
also reads the weekly reviews."
  (let* ((range (org-summary--range params "thisweek"))
         (month (> (- (cdr range) (car range)) 7))
         (period (if month "month" "week"))
         (clocks (org-summary-clocks (car range) (cdr range)))
         (top (car (org-summary--sum clocks (lambda (c) (plist-get c :title)))))
         (closed (seq-remove (lambda (c) (member (plist-get c :todo) '("CANCELED" "CANCELLED")))
                             (org-summary-closed (car range) (cdr range))))
         (hard (seq-filter (lambda (c) (or (memq (plist-get c :priority) '(?A ?B))
                                           (member "Challenge" (plist-get c :tags))))
                           closed))
         (days (org-summary-reviews org-dailyreview-file (car range) (cdr range)))
         (energy (org-summary--numbers days "\\`Energy"))
         (quality (org-summary--numbers days "\\`Quality"))
         (avg (lambda (ns) (and ns (/ (apply #'+ (mapcar #'cdr ns)) (float (length ns))))))
         (best (lambda (ns) (car (seq-sort-by #'cdr #'> ns))))
         (habits (delq nil (mapcar (lambda (h)
                                     (let ((st (org-summary--habit-stats h (car range) (cdr range))))
                                       (and (plist-get st :rate) (cons (plist-get h :title) st))))
                                   (org-summary--active-habits (car range) (cdr range)))))
         (habits (seq-sort-by (lambda (h) (plist-get (cdr h) :rate)) #'> habits))
         (habit (lambda (h) (and h (format "%s (%d of %d)" (car h) (plist-get (cdr h) :done)
                                           (plist-get (cdr h) :expected)))))
         (none "–")
         (line (lambda (q a) (insert (format "- %s :: %s\n" q (or a none))))))
    (funcall line (format "Top task of the %s" period)
             (and top (format "%s (%s)" (car top) (org-summary--dur (cdr top)))))
    (funcall line "Total logged in time"
             (let ((n (length (delete-dups (mapcar (lambda (c) (plist-get c :day)) clocks)))))
               (format "%s over %d day%s"
                       (org-summary--dur (apply #'+ (mapcar (lambda (c) (plist-get c :minutes)) clocks)))
                       n (if (= n 1) "" "s"))))
    (funcall line (format "Number of challenging tasks done in the %s" period)
             (format "%d of %d closed (A/B priority or :Challenge:)" (length hard) (length closed)))
    (funcall line "Most energetic day"
             (when-let* ((b (funcall best energy)))
               (format "%s (%s)" (org-summary--fmt (car b) "%a %d %b") (cdr b))))
    (when month
      (let ((weeks (seq-group-by (lambda (e) (org-summary--fmt (car e) "%V")) energy)))
        (funcall line "Most energetic week"
                 (when-let* ((w (car (seq-sort-by (lambda (w) (funcall avg (cdr w))) #'> weeks))))
                   (format "Week %s (avg %.1f)" (car w) (funcall avg (cdr w)))))))
    (funcall line (format "Average energy through the %s" period)
             (when-let* ((a (funcall avg energy)))
               (format "%.1f over %d days" a (length energy))))
    (funcall line "Number of good days"
             (and quality (format "%d (quality 6 or more)" (seq-count (lambda (q) (>= (cdr q) 6)) quality))))
    (funcall line "Number of normal days"
             (and quality (format "%d (quality 4–5)" (seq-count (lambda (q) (<= 4 (cdr q) 5.9)) quality))))
    (funcall line "Number of bad days"
             (and quality (format "%d (quality under 4)" (seq-count (lambda (q) (< (cdr q) 4)) quality))))
    (funcall line "Days reviewed"
             (format "%d of %d" (length days) (1+ (- (min (cdr range) (org-today)) (car range)))))
    (funcall line "Task not done in daily review"
             (let ((s (org-summary--not-done days))) (and (not (string-empty-p s)) s)))
    (when month
      (let ((weekly (org-summary-reviews org-weeklyreview-file (car range) (cdr range))))
        (funcall line "Task not done in weekly review"
                 (let ((s (org-summary--not-done weekly))) (and (not (string-empty-p s)) s)))
        (funcall line "Mistakes noted in weekly reviews"
                 (let ((ms (delq nil (mapcar (lambda (d) (alist-get "Mistake" (cdr d) nil nil #'equal))
                                             weekly))))
                   (and ms (string-join ms " · "))))))
    (funcall line (format "Most consistent habit of the %s" period) (funcall habit (car habits)))
    (funcall line (format "Most inconsistent habit of the %s" period)
             (and (cdr habits) (funcall habit (car (last habits)))))
    (funcall line (format "Overall %sly rating" period)
             (when-let* ((a (funcall avg quality)))
               (format "%.1f / 10 (average quality of day)" a)))
    (org-summary--end-block)))

(defun org-dblock-write:clock-score (params)
  "The tasks clocked over :span (default today), scored by priority."
  (let* ((range (org-summary--range params "today"))
         (tasks (make-hash-table :test 'equal))
         rows (total 0))
    (dolist (c (org-summary-clocks (car range) (cdr range)))
      (let ((k (list (plist-get c :file) (plist-get c :pos))))
        (puthash k (cons c (+ (plist-get c :minutes) (or (cdr (gethash k tasks)) 0))) tasks)))
    (maphash (lambda (_ v)
               (let* ((p (plist-get (car v) :priority))
                      (score (+ (alist-get p org-summary-count-score 0)
                                (* (cdr v) (alist-get p org-summary-clock-score 0)))))
                 (setq total (+ total score))
                 (push (list (plist-get (car v) :title) (char-to-string p)
                             (org-summary--dur (cdr v)) score)
                       rows)))
             tasks)
    (if (null rows)
        (insert (format "Nothing clocked on %s.\n" (org-summary--range-label range)))
      (org-summary--table '("Task" "P" "Time" "Score")
                          (sort rows (lambda (a b) (> (nth 3 a) (nth 3 b)))))
      (insert (format "\nFinal score: %d\n" total)))
    (org-summary--end-block)))

(defun org-dblock-write:clock-chart (params)
  "Bars of the time clocked over :span, :by day (default), tag, category or task."
  (let* ((range (org-summary--range params "thisweek"))
         (by (format "%s" (or (plist-get params :by) "day")))
         (clocks (org-summary-clocks (car range) (cdr range)))
         (items (pcase by
                  ("day" (let ((sums (org-summary--sum clocks (lambda (c) (plist-get c :day)))))
                           (cl-loop for d from (car range) to (cdr range)
                                    collect (cons (org-summary--fmt d "%a %d")
                                                  (alist-get d sums 0)))))
                  ("tag" (org-summary--sum clocks (lambda (c) (plist-get c :tags))))
                  ("category" (org-summary--sum clocks (lambda (c) (plist-get c :category))))
                  ("task" (org-summary--sum clocks (lambda (c) (plist-get c :title))))
                  (_ (org-summary--sum clocks (org-summary--in-group (org-summary--group by))))))
         (items (if (equal by "day") items (seq-take items (or (plist-get params :top) 10))))
         (total (apply #'+ (mapcar (lambda (c) (plist-get c :minutes)) clocks))))
    (if (null clocks)
        (insert (format "Nothing clocked in %s.\n" (org-summary--range-label range)))
      (insert (org-summary--link
               (org-summary-bars-svg
                (format "Time by %s · %s · %s" by (org-summary--range-label range)
                        (org-summary--dur total))
                items
                (org-summary--plot-file (format "clock_%s_%s_%s" by (org-summary--iso (car range))
                                                (org-summary--iso (cdr range))))))
              "\n"))
    (org-summary--end-block)))

(defun org-dblock-write:review-days (params)
  "The answers of :file's reviews (daily or weekly) over :span, a column a day.
Rows answered yes every day are left out unless :all is t."
  (let* ((range (org-summary--range params "thisweek"))
         (days (org-summary-reviews (org-summary--review-file (plist-get params :file))
                                    (car range) (cdr range)))
         (width (or (plist-get params :width) 28))
         (keys (delete-dups (mapcan (lambda (d) (mapcar #'car (cdr d))) days)))
         rows)
    (dolist (k keys)
      (let ((cells (mapcar (lambda (d)
                             (pcase (alist-get k (cdr d) nil nil #'equal)
                               ('nil "") ('t "✓") (:no "✗") (v v)))
                           days)))
        (unless (or (seq-every-p #'string-empty-p cells)
                    (and (not (plist-get params :all)) (seq-every-p (lambda (c) (equal c "✓")) cells)))
          (push (cons (truncate-string-to-width k 34 nil nil "…")
                      (mapcar (lambda (c) (org-summary--cell c width)) cells))
                rows))))
    (if (null rows)
        (insert (format "No reviews in %s.\n" (org-summary--range-label range)))
      (org-summary--table (cons "" (mapcar (lambda (d) (org-summary--fmt (car d) "%a %d")) days))
                          (nreverse rows)))
    (org-summary--end-block)))

(defun org-dblock-write:review-stats (params)
  "Averages and counts over the answers of :file's reviews.
:span defaults to this month."
  (let* ((range (org-summary--range params "thismonth"))
         (days (org-summary-reviews (org-summary--review-file (plist-get params :file))
                                    (car range) (cdr range)))
         (keys (delete-dups (mapcan (lambda (d) (mapcar #'car (cdr d))) days)))
         (label (lambda (day) (org-summary--fmt day (if (> (- (cdr range) (car range)) 31)
                                                        "%Y-%m-%d" "%a %d")))))
    (insert (format "- Reviewed :: %d of %d days so far (%s)\n" (length days)
                    (1+ (- (min (cdr range) (org-today)) (car range)))
                    (org-summary--range-label range)))
    (dolist (k keys)
      (let* ((vals (delq nil (mapcar (lambda (d)
                                       (when-let* ((v (alist-get k (cdr d) nil nil #'equal)))
                                         (cons (car d) v)))
                                     days)))
             (texts (seq-filter (lambda (v) (stringp (cdr v))) vals))
             (nums (delq nil (mapcar (lambda (v) (when-let* ((n (org-summary--number (cdr v))))
                                                   (cons (car v) n)))
                                     texts))))
        (cond
         ((and nums (>= (* 2 (length nums)) (length texts)))
          (let ((lo (car (seq-sort-by #'cdr #'< nums)))
                (hi (car (seq-sort-by #'cdr #'> nums))))
            (insert (format "- %s :: avg %.1f · low %s (%s) · high %s (%s) · %d answers\n" k
                            (/ (apply #'+ (mapcar #'cdr nums)) (float (length nums)))
                            (cdr lo) (funcall label (car lo)) (cdr hi) (funcall label (car hi))
                            (length nums)))))
         (texts
          (let ((counts (seq-sort-by #'cdr #'> (mapcar (lambda (g) (cons (car g) (length (cdr g))))
                                                         (seq-group-by #'cdr texts)))))
            (when (and (> (cdar counts) 1) (seq-every-p (lambda (c) (<= (length (car c)) 24)) counts))
              (insert (format "- %s :: %s\n" k
                              (mapconcat (lambda (c) (format "%s ×%d" (car c) (cdr c)))
                                         (seq-take counts 5) " · "))))))
         (vals
          (insert (format "- %s :: done %d of %d\n" k
                          (seq-count (lambda (v) (eq (cdr v) t)) vals) (length vals)))))))
    (org-summary--end-block)))

(defun org-summary--month-of (params)
  "The (YEAR . MONTH) PARAMS' :month names: this (default), last or YYYY-MM."
  (let* ((a (or (org-summary--parse-iso (plist-get params :date)) (org-summary--anchor)))
         (m (format "%s" (or (plist-get params :month) "this")))
         (day (pcase m
                ("this" a)
                ("last" (1- (car (org-summary--month a))))
                ((pred (string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)\\'"))
                 (org-summary--day (string-to-number (match-string 1 m))
                                   (string-to-number (match-string 2 m)) 1))
                (_ (user-error "org-summary: unknown :month %s" m)))))
    (pcase-let ((`(,y ,mm ,_) (org-summary--ymd day))) (cons y mm))))

(defun org-dblock-write:habit-calendar (params)
  "A month grid per habit: :habits (\"Title\" ...), or every habit active then.
:month is this (default), last or YYYY-MM."
  (pcase-let* ((`(,y . ,m) (org-summary--month-of params))
               (range (org-summary--month (org-summary--day y m 1)))
               (habits (if-let* ((names (plist-get params :habits)))
                           (mapcar (lambda (n) (or (org-summary-habit n) n)) names)
                         (org-summary--active-habits (car range) (cdr range)))))
    (dolist (h habits)
      (if (stringp h)
          (insert (format "- %s :: no such habit in %s\n\n" h
                          (file-name-nondirectory org-recurring-file)))
        (let ((s (org-summary--habit-stats h (car range) (cdr range))))
          (insert (org-summary--link
                   (org-summary-habit-svg h y m (org-summary--plot-file
                                                 (format "%s_%04d-%02d" (plist-get h :title) y m))))
                  "\n"
                  (format "done %d of %d%s%s\n\n" (plist-get s :done) (plist-get s :expected)
                          (if (> (plist-get s :skipped) 0)
                              (format " · skipped %d" (plist-get s :skipped)) "")
                          (if (and (= 1 (plist-get h :every)) (> (plist-get s :streak) 0)
                                   (<= (car range) (org-today) (cdr range)))
                              (format " · streak %d" (plist-get s :streak)) ""))))))
    (unless habits (insert (format "No habit logged in %s.\n" (calendar-month-name m))))
    (org-summary--end-block)))

(defun org-summary--year-habits (habits start end)
  "HABITS done at least once in START..END, most done first."
  (let ((count (lambda (h) (plist-get (org-summary--habit-stats h start end) :done))))
    (seq-sort-by count #'> (seq-filter (lambda (h) (> (funcall count h) 0)) habits))))

(defconst org-summary--icon-font "Symbols Nerd Font Mono"
  "The font the habit icons are drawn in: Doom's nerd-icons font.")

(defun org-summary--icon-glyph (icon)
  "The glyph for ICON, a nerd-icons name such as nf-md-yoga, or ICON itself."
  (or (and (string-prefix-p "nf-" icon) (require 'nerd-icons nil t)
           (seq-some (lambda (alist) (cdr (assoc icon (symbol-value alist))))
                     (seq-filter #'boundp
                                 '(nerd-icons/mdicon-alist nerd-icons/faicon-alist
                                   nerd-icons/codicon-alist nerd-icons/octicon-alist
                                   nerd-icons/wicon-alist nerd-icons/devicon-alist))))
      icon))

(defun org-summary-icon-habits ()
  "The habits given an ICON property, in file order, each with :icon (a glyph).
Giving a habit an icon is what puts it in the daily habit month."
  (delq nil
        (mapcar (lambda (ti) (when-let* ((h (org-summary-habit (car ti))))
                               (plist-put h :icon (org-summary--icon-glyph (cdr ti)))))
                (org-summary--in-file org-recurring-file
                  (org-map-entries (lambda () (cons (org-summary--title) (org-entry-get nil "ICON")))
                                   "ICON<>\"\"")))))

;;;###autoload
(defun org-summary-set-habit-icon ()
  "Give the habit at point an icon, picked from the Material Design set."
  (interactive)
  (require 'nerd-icons)
  (let* ((alist (symbol-value 'nerd-icons/mdicon-alist))
         (name (completing-read
                (format "Icon for %s: " (org-get-heading t t t t))
                (lambda (str pred action)
                  (if (eq action 'metadata)
                      `(metadata (annotation-function
                                  . ,(lambda (c) (when-let* ((g (cdr (assoc c alist))))
                                                   (concat "  " (propertize g 'face `(:family ,org-summary--icon-font
                                                                                                :height 1.3)))))))
                    (complete-with-action action alist str pred)))
                nil t nil nil (org-entry-get nil "ICON"))))
    (org-entry-put nil "ICON" name)))

(defun org-summary--grade (habits day)
  "DAY over HABITS: (GRADE DONE DUE), GRADE one of `org-summary--grades',
or future, pending (today, not all done yet) or idle (nothing due)."
  (let* ((states (mapcar (lambda (h) (org-summary--status h day)) habits))
         (due (seq-count (lambda (s) (memq s '(done skipped missed pending))) states))
         (done (seq-count (lambda (s) (eq s 'done)) states)))
    (list (cond ((> day (org-today)) 'future)
                ((zerop due) 'idle)
                ((= done due) 'all)
                ((= day (org-today)) 'pending)
                ((>= (* 2 done) due) 'most)
                ((> done 0) 'some)
                (t 'none))
          done due)))

(defconst org-summary--grade-tints
  '((all . "#b4e8c0") (most . "#e1f6e5") (some . "#ffdcb8") (none . "#ffcdc9"))
  "Day box fills, a tint of each grade's colour in `org-summary--grades'.")

(defun org-summary-habits-month-svg (habits y m file)
  "Month M of Y for the icon HABITS into FILE: a column a week, a box a day.
A day's box is tinted by how many were done; inside it each habit's icon
sits on a tile coloured by its own state, four to a row."
  (let* ((first (org-summary--day y m 1))
         (last (org-summary--day y m (calendar-last-day-of-month m y)))
         (monday (car (org-summary--week first)))
         (weeks (1+ (/ (- last monday) 7)))
         (per-row 4) (tile 26) (tgap 4)
         (box-w (+ 16 (* per-row tile) (* (1- per-row) tgap)))
         (box-h (+ 30 (* (ceiling (max 1 (length habits)) (float per-row)) (+ tile tgap))))
         (gap 10) (pad 22) (left (+ pad 34)) (top 104)
         (w (+ left (* weeks (+ box-w gap)) (- gap) pad))
         (legend-y (+ top (* 7 (+ box-h gap)) 14))
         (h (+ legend-y 34 (* 22 (ceiling (length habits) 2.0)) 8))
         (grades (cl-loop for d from first to last collect (cons d (org-summary--grade habits d))))
         (count (lambda (g) (seq-count (lambda (x) (eq (cadr x) g)) grades)))
         (svg (org-summary--svg w h)))
    (org-summary--title-text
     svg (format "Habits · %s %d" (calendar-month-name m) y)
     (format "all done %d  ·  half or more %d  ·  under half %d  ·  none %d"
             (funcall count 'all) (funcall count 'most) (funcall count 'some) (funcall count 'none))
     pad)
    (dotimes (wk weeks)
      (svg-text svg (format "Week %s" (org-summary--fmt (+ monday (* 7 wk)) "%V"))
                :x (+ left (* wk (+ box-w gap)) (/ box-w 2)) :y (- top 12) :font-size 11
                :font-weight "600" :text-anchor "middle" :fill (org-summary--ink 'muted)))
    (seq-do-indexed (lambda (d i)
                      (svg-text svg d :x (- left 8) :y (+ top (* i (+ box-h gap)) 20) :font-size 10.5
                                :text-anchor "end" :fill (org-summary--ink 'muted)))
                    '("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"))
    (dolist (g grades)
      (pcase-let* ((`(,day ,grade ,done ,due) g)
                   (pos (- day monday))
                   (x (+ left (* (/ pos 7) (+ box-w gap))))
                   (yy (+ top (* (mod pos 7) (+ box-h gap))))
                   (later (eq grade 'future)))
        (svg-rectangle svg x yy box-w box-h :rx 10
                       :fill (or (alist-get grade org-summary--grade-tints)
                                 (alist-get 'future org-summary--colors))
                       :stroke (or (alist-get grade org-summary--grades) (org-summary--ink 'rule))
                       :stroke-width (if (memq grade '(future idle)) 1 2)
                       :stroke-dasharray (if (eq grade 'pending) "5,3" "none"))
        (svg-text svg (number-to-string (- day first -1)) :x (+ x 9) :y (+ yy 19) :font-size 13
                  :font-weight "700" :fill (org-summary--ink (if later 'faint 'text)))
        (unless (memq grade '(future idle))
          (svg-text svg (format "%d/%d" done due) :x (- (+ x box-w) 9) :y (+ yy 18) :font-size 10.5
                    :font-weight "600" :text-anchor "end"
                    :fill (or (alist-get grade '((all . "#1a7f37") (none . "#cf222e") (some . "#bc4c00")))
                              (org-summary--ink 'muted))))
        (seq-do-indexed
         (lambda (hb j)
           (let* ((st (org-summary--status hb day))
                  (tx (+ x 8 (* (mod j per-row) (+ tile tgap))))
                  (ty (+ yy 26 (* (/ j per-row) (+ tile tgap))))
                  (solid (memq st '(done skipped missed))))
             (svg-rectangle svg tx ty tile tile :rx 6
                            :fill (if solid (alist-get st org-summary--colors) "#ffffff")
                            :stroke (if solid "none" (org-summary--ink 'rule)) :stroke-width 1)
             (svg-text svg (plist-get hb :icon) :x (+ tx (/ tile 2)) :y (+ ty 19) :font-size 17
                       :text-anchor "middle" :style (format "font-family: %s" org-summary--icon-font)
                       :fill (if solid "#ffffff" (org-summary--ink (if later 'grid 'faint))))))
         habits)))
    (let ((x pad))
      (dolist (g '((all . "all done") (most . "half or more") (some . "under half") (none . "none")))
        (svg-rectangle svg x (- legend-y 10) 18 12 :rx 4 :fill (alist-get (car g) org-summary--grade-tints)
                       :stroke (alist-get (car g) org-summary--grades) :stroke-width 1.5)
        (svg-text svg (cdr g) :x (+ x 23) :y legend-y :font-size 10.5 :fill (org-summary--ink 'muted))
        (setq x (+ x 36 (* 5.6 (length (cdr g))))))
      (setq x (+ x 14))
      (dolist (k '(done skipped missed))
        (svg-rectangle svg x (- legend-y 10) 12 12 :rx 3 :fill (alist-get k org-summary--colors))
        (svg-text svg (symbol-name k) :x (+ x 16) :y legend-y :font-size 10.5 :fill (org-summary--ink 'muted))
        (setq x (+ x 30 (* 5.6 (length (symbol-name k)))))))
    (seq-do-indexed
     (lambda (hb i)
       (let ((x (+ pad (* (mod i 2) (/ (- w (* 2 pad)) 2))))
             (yy (+ legend-y 30 (* 22 (/ i 2)))))
         (svg-rectangle svg x (- yy 15) 20 20 :rx 5 :fill (org-summary--ink 'text))
         (svg-text svg (plist-get hb :icon) :x (+ x 10) :y (- yy 0.5) :font-size 14 :text-anchor "middle"
                   :style (format "font-family: %s" org-summary--icon-font) :fill "#ffffff")
         (svg-text svg (plist-get hb :title) :x (+ x 27) :y (- yy 1) :font-size 12
                   :fill (org-summary--ink 'text))))
     habits)
    (org-summary--write-svg svg file)))

(defun org-summary-habits-month-file (day)
  "Draw the icon habits' month around DAY to its file; nil without icon habits."
  (when-let* ((habits (org-summary-icon-habits)))
    (pcase-let ((`(,y ,m ,_) (org-summary--ymd day)))
      (org-summary-habits-month-svg habits y m (org-summary--plot-file
                                                (format "daily_habits_%04d-%02d" y m))))))

(defun org-dblock-write:habits-month (params)
  "Every icon habit in one vertical month: :month this (default), last or YYYY-MM."
  (pcase-let* ((`(,y . ,m) (org-summary--month-of params))
               (file (org-summary-habits-month-file (org-summary--day y m 1))))
    (insert (if file (concat (org-summary--link file) "\n")
              "No habit has an :ICON: property in recurring.org yet.\n"))
    (org-summary--end-block)))

(defun org-dblock-write:habit-year (params)
  "The year as day strips, one per habit and an overview on top.
:year is this (default), last or YYYY; :habits as for habit-calendar."
  (let* ((a (or (org-summary--parse-iso (plist-get params :date)) (org-summary--anchor)))
         (this (car (org-summary--ymd a)))
         (yr (pcase (format "%s" (or (plist-get params :year) "this"))
               ("this" this) ("last" (1- this)) (n (string-to-number n))))
         (start (org-summary--day yr 1 1)) (end (org-summary--day yr 12 31))
         (habits (org-summary--year-habits
                  (org-summary--view-habits (plist-get params :habits) start end) start end)))
    (insert (org-summary--link (org-summary-year-svg habits yr (org-summary--plot-file
                                                                (format "habits_%d" yr))))
            "\n")
    (org-summary--end-block)))

(defun org-summary-projects (start end)
  "Each PROJ in `org-projects-file': plist of :title :done :open :closed :minutes
:span-minutes (clocked START..END) and :deadline."
  (org-summary--in-file org-projects-file
    (org-map-entries
     (lambda ()
       (let ((limit (save-excursion (org-end-of-subtree t t)))
             (deadline (org-entry-get nil "DEADLINE"))
             (title (org-summary--title))
             (done 0) (open 0) closed (minutes 0) (span 0))
         (save-excursion
           (while (re-search-forward org-summary--clock-re limit t)
             (let* ((s1 (match-string 2))
                    (t0 (org-time-string-to-time (match-string 1)))
                    (mins (/ (round (float-time (time-subtract (org-time-string-to-time s1) t0)))
                             60)))
               (cl-incf minutes mins)
               (when (<= start (time-to-days t0) end) (cl-incf span mins)))))
         (save-excursion
           (while (and (outline-next-heading) (< (point) limit))
             (when-let* ((todo (org-get-todo-state)))
               (if (not (member todo org-done-keywords))
                   (cl-incf open)
                 (cl-incf done)
                 (when-let* ((c (org-entry-get nil "CLOSED")))
                   (push (time-to-days (org-time-string-to-time c)) closed))))))
         (list :title title :done done :open open :closed (sort closed #'<)
               :minutes minutes :span-minutes span :deadline deadline)))
     "TODO=\"PROJ\"")))

(defun org-dblock-write:project-summary (params)
  "Each open project: tasks done and open, time all told and in :span, deadline."
  (let* ((range (org-summary--range params "thismonth"))
         (today (org-today))
         (rows (mapcar (lambda (p)
                         (let ((dl (and (plist-get p :deadline)
                                        (time-to-days (org-time-string-to-time (plist-get p :deadline))))))
                           (list (plist-get p :title) (plist-get p :done) (plist-get p :open)
                                 (format "%d%%" (round (* 100 (/ (float (plist-get p :done))
                                                                 (max 1 (+ (plist-get p :done) (plist-get p :open)))))))
                                 (org-summary--dur (plist-get p :span-minutes))
                                 (org-summary--dur (plist-get p :minutes))
                                 (if dl (org-summary--iso dl) "")
                                 (if dl (- dl today) ""))))
                       (org-summary-projects (car range) (cdr range)))))
    (org-summary--table '("Project" "Done" "Open" "%" "Time (span)" "Time" "Deadline" "Days left")
                        (sort rows (lambda (a b) (string< (nth 4 b) (nth 4 a)))))
    (org-summary--end-block)))

(defun org-dblock-write:project-progress (params)
  "Tasks closed so far per project, as lines over :span (default 180 days)."
  (let* ((range (org-summary--range params 180))
         (series
          (delq nil
                (mapcar (lambda (p)
                          (let* ((closed (plist-get p :closed))
                                 (before (seq-count (lambda (d) (< d (car range))) closed))
                                 (in (seq-filter (lambda (d) (<= (car range) d (cdr range))) closed))
                                 (n before))
                            (when in
                              (cons (plist-get p :title)
                                    (cons (cons (car range) before)
                                          (mapcar (lambda (d) (cons d (cl-incf n))) in))))))
                        (org-summary-projects (car range) (cdr range))))))
    (if (null series)
        (insert (format "No project task closed in %s.\n" (org-summary--range-label range)))
      (insert (org-summary--link
               (org-summary-lines-svg (format "Project tasks closed · %s"
                                              (org-summary--range-label range))
                                      (seq-take (seq-sort-by (lambda (s) (cdar (last (cdr s)))) #'> series) 8)
                                      (car range) (cdr range)
                                      (org-summary--plot-file
                                       (format "projects_%s" (org-summary--iso (cdr range))))))
              "\n"))
    (org-summary--end-block)))

;;; Commands

(defun org-summary--entry-top ()
  "Move to the review entry around point: the heading just under its date."
  (when (ignore-errors (org-back-to-heading t) t)
    (let ((date-re "\\`[0-9]\\{4\\}-\\([0-9]\\{2\\}\\|W[0-9]\\{2\\}\\)"))
      (while (and (not (string-match-p date-re (org-get-heading t t t t)))
                  (save-excursion
                    (and (org-up-heading-safe)
                         (not (string-match-p date-re (org-get-heading t t t t))))))
        (org-up-heading-safe))
      t)))

;;;###autoload
(defun org-summary-refresh ()
  "Refresh the blocks of the review entry at point.
Outside one, refresh the whole buffer."
  (interactive)
  (save-excursion
    (save-restriction
      (when (org-summary--entry-top) (org-narrow-to-subtree))
      (org-update-all-dblocks)))
  (org-summary--show-images-soon))

(defun org-summary--capture-fill ()
  "Fill a review's blocks as its capture opens."
  (when (member (org-capture-get :key) org-summary-review-keys)
    (org-update-all-dblocks)
    (org-summary--show-images-soon)))

(add-hook 'org-capture-mode-hook #'org-summary--capture-fill)

(defun org-summary--capture-show ()
  "Show a filed review's charts in the file it went to."
  (when-let* (((member (org-capture-get :key) org-summary-review-keys))
              (buf (marker-buffer org-capture-last-stored-marker)))
    (with-current-buffer buf (org-summary--show-images-soon))))

(add-hook 'org-capture-after-finalize-hook #'org-summary--capture-show)

;;; The habit views

(defvar-local org-summary--view nil
  "What this view shows: (month YEAR MONTH TITLES) or (year YEAR TITLES).
TITLES nil means every habit active then.")

(defvar org-summary-view-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "[") #'org-summary-view-previous)
    (define-key map (kbd "]") #'org-summary-view-next)
    (define-key map (kbd "t") #'org-summary-view-toggle)
    (define-key map (kbd "g") #'org-summary-view-redraw)
    (define-key map (kbd "d") #'org-summary-plots)
    map)
  "Keys of the habit views.")

(define-derived-mode org-summary-view-mode special-mode "Habits"
  "Month and year habit grids.
\\<org-summary-view-mode-map>\\[org-summary-view-previous] and \\[org-summary-view-next] step through months or years;
\\[org-summary-view-toggle] switches month and year; \\[org-summary-view-redraw] redraws;
\\[org-summary-plots] opens the charts' folder."
  (setq-local cursor-type nil))

(declare-function evil-set-initial-state "evil-core")
(with-eval-after-load 'evil
  (evil-set-initial-state 'org-summary-view-mode 'emacs))

(defun org-summary--view-habits (titles start end)
  (if titles (delq nil (mapcar #'org-summary-habit titles))
    (org-summary--active-habits start end)))

(defun org-summary-view-redraw ()
  "Draw the view's grids again from the org files."
  (interactive)
  (let ((inhibit-read-only t)
        (v org-summary--view))
    (erase-buffer)
    (pcase v
      (`(month ,y ,m ,titles)
       (let* ((range (org-summary--month (org-summary--day y m 1)))
              (habits (org-summary--view-habits titles (car range) (cdr range)))
              (win (get-buffer-window))
              (per-row (if win (max 1 (/ (window-body-width win t) 390)) 3)))
         (rename-buffer (format "*Habits · %s %d*" (calendar-month-name m) y) t)
         (insert (propertize (format "%s %d" (calendar-month-name m) y) 'face '(:height 1.4 :weight bold))
                 (propertize "    [ previous   ] next   t year   g redraw   d plots folder   q quit\n\n"
                             'face 'shadow))
         (unless habits (insert "No habit was logged that month.\n"))
         (when-let* (((display-images-p))
                     (file (org-summary-habits-month-file (org-summary--day y m 1))))
           (insert-image (create-image file 'svg))
           (insert "\n\n"))
         (seq-do-indexed
          (lambda (h i)
            (let ((file (org-summary-habit-svg
                         h y m (org-summary--plot-file (format "%s_%04d-%02d" (plist-get h :title) y m)))))
              (if (display-images-p)
                  (insert-image (create-image file 'svg nil :ascent 'center))
                (org-summary--text-grid h y m))
              (insert (if (= (mod i per-row) (1- per-row)) "\n\n" "  "))))
          habits)))
      (`(year ,y ,titles)
       (let* ((start (org-summary--day y 1 1)) (end (org-summary--day y 12 31))
              (habits (org-summary--year-habits (org-summary--view-habits titles start end) start end))
              (file (org-summary-year-svg habits y (org-summary--plot-file (format "habits_%d" y)))))
         (rename-buffer (format "*Habits · %d*" y) t)
         (insert (propertize (number-to-string y) 'face '(:height 1.4 :weight bold))
                 (propertize "    [ previous   ] next   t month   g redraw   d plots folder   q quit\n\n"
                             'face 'shadow))
         (if (display-images-p)
             (insert-image (create-image file 'svg))
           (insert "The year grid needs a graphical frame; it is saved at "
                   (abbreviate-file-name file))))))
    (insert "\n")
    (goto-char (point-min))))

(defun org-summary--view-show (view)
  (let ((buf (generate-new-buffer "*Habits*")))
    (pop-to-buffer-same-window buf)
    ;; Drawn once shown, so the month grids wrap to the window.
    (org-summary-view-mode)
    (setq org-summary--view view)
    (org-summary-view-redraw)))

(defun org-summary-view-next (&optional n)
  "The next month or year; N steps, backwards when negative."
  (interactive "p")
  (setq org-summary--view
        (pcase org-summary--view
          (`(month ,y ,m ,titles)
           (let ((i (+ (* 12 y) (1- m) n))) (list 'month (/ i 12) (1+ (mod i 12)) titles)))
          (`(year ,y ,titles) (list 'year (+ y n) titles))))
  (org-summary-view-redraw))

(defun org-summary-view-previous (&optional n)
  "The previous month or year."
  (interactive "p")
  (org-summary-view-next (- n)))

(defun org-summary-view-toggle ()
  "Switch between the month and the year."
  (interactive)
  (setq org-summary--view
        (pcase org-summary--view
          (`(month ,y ,_ ,titles) (list 'year y titles))
          (`(year ,y ,titles)
           (pcase-let ((`(,ty ,tm ,_) (org-summary--ymd (org-today))))
             (list 'month y (if (= y ty) tm 12) titles)))))
  (org-summary-view-redraw))

(defun org-summary--read-habits ()
  "Habits to show: every active one, or the one picked."
  (let ((pick (completing-read "Habit (empty for all active): "
                               (cons "" (org-summary-habits)) nil t)))
    (unless (string-empty-p pick) (list pick))))

;;;###autoload
(defun org-summary-habit-calendar (&optional titles)
  "This month's grid for each of TITLES, or every habit active this month."
  (interactive (list (org-summary--read-habits)))
  (pcase-let ((`(,y ,m ,_) (org-summary--ymd (org-today))))
    (org-summary--view-show (list 'month y m titles))))

;;;###autoload
(defun org-summary-habit-year (&optional titles)
  "This year for TITLES, or every habit active this year, one strip each."
  (interactive (list (org-summary--read-habits)))
  (org-summary--view-show (list 'year (car (org-summary--ymd (org-today))) titles)))

;;;###autoload
(defun org-summary-plots ()
  "Open the folder the charts are saved in."
  (interactive)
  (dired (or org-summary-plots-directory (expand-file-name "plots" org-lookbacks-directory))))

(defun org-summary--text-grid (habit y m)
  "HABIT's month as text, for a frame that cannot show the SVG."
  (let* ((first (org-summary--day y m 1))
         (lead (mod (1- (calendar-day-of-week (list m 1 y))) 7))
         (faces (mapcar (lambda (k) (cons k (list :background (alist-get k org-summary--colors)
                                                  :foreground (if (eq k 'skipped) "black" "white"))))
                        '(done skipped missed))))
    (insert (plist-get habit :title) " — " (calendar-month-name m) (format " %d\n\n" y))
    (insert "    M  T  W  T  F  S  S\n" (format "%2s " (org-summary--fmt first "%V"))
            (make-string (* 3 lead) ?\s))
    (dotimes (i (calendar-last-day-of-month m y))
      (let* ((day (+ first i)) (col (mod (+ lead i) 7)))
        (when (and (= col 0) (> i 0))
          (insert (format "\n%2s " (org-summary--fmt day "%V"))))
        (insert (propertize (format "%2d" (1+ i))
                            'face (alist-get (org-summary--status habit day) faces))
                " ")))
    (insert "\n")))

(defvar org-summary-dashboard-spans
  '("thisweek" "lastweek" "thismonth" "lastmonth" "today" "yesterday" "30" "90"))

;;;###autoload
(defun org-summary-dashboard (span)
  "Every summary and chart for SPAN in one buffer."
  (interactive (list (completing-read "Span: " org-summary-dashboard-spans nil nil nil nil
                                      "thisweek")))
  (let ((buf (get-buffer-create "*Org Summary*"))
        (b (lambda (name &rest more)
             (format "#+BEGIN: %s :span %s%s\n#+END:\n\n" name span
                     (if more (concat " " (string-join more " ")) "")))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert "#+TITLE: Summary · " span "\n\n"
                "* Time\n" (funcall b "period-summary")
                (funcall b "clock-chart" ":by day") (funcall b "clock-chart" ":by tag")
                (funcall b "clock-chart" ":by task")
                "* Daily reviews\n" (funcall b "review-stats" ":file daily")
                (funcall b "review-days" ":file daily")
                "* Habits\n#+BEGIN: habit-calendar\n#+END:\n\n"
                "* Projects\n" (funcall b "project-summary")
                "#+BEGIN: project-progress\n#+END:\n")
        (org-update-all-dblocks)
        (goto-char (point-min))
        (org-summary--show-images-soon)))
    (pop-to-buffer-same-window buf)))

(provide 'org-summary)
;;; org-summary.el ends here
