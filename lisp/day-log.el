;;; day-log.el --- The daily review that writes itself -*- lexical-binding: t -*-

;;; Commentary:
;; Each day gets a Daily Review heading in its org-roam daily note -- the
;; day's one page, beside its logs and photos; the diary stays personal --
;; whose facts write themselves, from what is already recorded:
;;   - the org clock: what was clocked, when, for how long
;;   - what was marked DONE that day
;;   - the phone's foreground log: where screen time went, and how much of
;;     it no clock covered
;;   - the usage log (usage-log.el): which of this config's commands ran
;; Those live in a `day-log' dynamic block (C-c C-c on it refreshes).  Below
;; it are three lines for you; filling any of them is "writing" the review.
;;
;; The day turns at `day-log-day-starts' (4am), not midnight: until then a
;; review is still the evening's.  Saving it with any of your lines filled
;; closes it there and then, :written:.  Any day not written by 4am is closed
;; on its own -- on the phone, by the first Home press (or startup) after,
;; for every unclosed day of the last week -- and tagged :auto:.  Either way
;; the Daily Review habit is marked DONE for that day with the same word in
;; its logbook note, so its history says which days you reviewed and which
;; the system closed.  The morning pass also rewrites the facts of a review
;; written the evening before, to take in the rest of that day.
;;
;; `day-log-today' (the dashboard's Day button) opens today's, drafted.
;; `day-log-review' (SPC o v t, and the 8 PM prompt) is the whole review:
;; your lines asked for in turn, then every task dated, then tomorrow's
;; daily topics planned -- the old long template's only steps that change
;; tomorrow.
;;
;; Loaded on first use, never at startup: it loads org, and through it the
;; whole org setup -- 11s on the Mac, and out of memory on the phone, where
;; Doom holds off garbage collection while starting.

;;; Code:

(require 'org)
(require 'org-clock)
(require 'org-datetree)
(require 'org-id)
(require 'meetings)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'usage-log)
(declare-function org-summary-habits-month-file "org-summary")
(declare-function org-summary-runs "org-summary")
(declare-function org-summary--most-at-once "org-summary")
(declare-function org-summary--parse-iso "org-summary")
(declare-function org-summary--link "org-summary")

(defvar org-dailyreview-file)            ; config.el: the reviews before 2026-10-25
(defvar org-roam-directory)
(defvar org-roam-dailies-directory)

(defvar day-log-habit-id "9851aecd-54c9-47cd-b0a6-570b43800cf4"
  "ID of the Daily Review habit, marked DONE as each day closes.")

(defvar day-log-day-starts 4
  "Hour a day ends and the next begins: until then, it is still yesterday.")

(defvar day-log-catch-up-days 7
  "How far back unclosed days are closed.")

(defvar day-log-foreground-files
  (list (expand-file-name "foreground_localhost.tsv" org-logs-directory)
        ;; Where the app wrote before the log moved into org.
        "/data/data/com.termux/files/home/.emacs-home/foreground.tsv")
  "The phone's foreground logs: TIME TAB PACKAGE TAB LABEL.
Package \"-\" is the screen going off, \"+\" coming on.")

(defvar day-log-prompts
  '("One line about today" "Energy, 1-10" "First thing tomorrow")
  "Your lines under the facts.  Filling any of them writes the review.")

;;; Days

(defun day-log--today ()
  "Today's date, YYYY-MM-DD, with the day turning at `day-log-day-starts'."
  (format-time-string "%F" (time-subtract nil (* day-log-day-starts 3600))))

(defun day-log--shift (date n)
  "DATE moved by N days."
  (format-time-string "%F" (time-add (date-to-time (concat date " 12:00")) (days-to-time n))))

(defun day-log--secs (time)
  "Seconds into the day of TIME, \"YYYY-MM-DD HH:MM[:SS]\"."
  (pcase-let ((`(,h ,m ,s) (mapcar #'string-to-number
                                   (split-string (substring time 11) ":"))))
    (+ (* h 3600) (* m 60) (or s 0))))

(defun day-log--dur (secs)
  (let ((m (round secs 60)))
    (if (< m 60) (format "%dm" m) (format "%dh%02d" (/ m 60) (% m 60)))))

(defun day-log--now-secs (date)
  "How far DATE has run: the whole day if it's past, up to now if it's today."
  (if (equal date (format-time-string "%F"))
      (day-log--secs (format-time-string "%F %T"))
    86400))

;;; Facts: the clock

(defun day-log--clocks (date)
  "Clocked intervals starting on DATE: (START-SECS END-SECS HEADING), in order."
  (let ((re (concat "^[ \t]*CLOCK: \\[" (regexp-quote date)
                    " [^ ]+ \\([0-9:]+\\)\\]--\\[\\([0-9-]+\\) [^ ]+ \\([0-9:]+\\)\\]"))
        clocks)
    (dolist (file (org-agenda-files t))
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (goto-char (point-min))
         (while (re-search-forward re nil t)
           (let* ((from (match-string 1)) (to-date (match-string 2)) (to (match-string 3))
                  (start (day-log--secs (concat date " " from)))
                  (end (if (equal to-date date) (day-log--secs (concat date " " to)) 86400)))
             (push (list start end (save-excursion
                                     (org-back-to-heading t)
                                     (concat (if (meetings-file-p file)
                                                 meetings-prefix "")
                                             (org-get-heading t t t t))))
                   clocks))))))
    (when (and (org-clocking-p)
               (equal (format-time-string "%F" org-clock-start-time) date))
      (push (list (day-log--secs (format-time-string "%F %T" org-clock-start-time))
                  (day-log--now-secs date)
                  (substring-no-properties org-clock-current-task))
            clocks))
    (sort clocks (lambda (a b) (< (car a) (car b))))))

(defun day-log--done (date)
  "Headings marked DONE on DATE."
  (let ((re (concat "\\(?:CLOSED: \\[\\|- State \"DONE\" +from [^[]*\\[\\)"
                    (regexp-quote date)))
        done)
    (dolist (file (org-agenda-files t))
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (goto-char (point-min))
         (while (re-search-forward re nil t)
           (save-excursion
             (org-back-to-heading t)
             (cl-pushnew (org-get-heading t t t t) done :test #'equal))))))
    (nreverse done)))

;;; Facts: the phone

(defun day-log--foreground (date)
  "DATE's foreground log lines as (SECS PACKAGE LABEL), in order."
  (let (lines)
    (dolist (file day-log-foreground-files)
      (when (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (search-forward (concat "\n" date " ") nil t)
            (pcase (split-string (buffer-substring (1+ (match-beginning 0)) (line-end-position))
                                 "\t")
              (`(,time ,pkg ,label) (push (list (day-log--secs time) pkg label) lines))))
          ;; The first line has no newline before it.
          (goto-char (point-min))
          (when (looking-at (concat (regexp-quote date) " "))
            (pcase (split-string (buffer-substring (point) (line-end-position)) "\t")
              (`(,time ,pkg ,label)
               (push (list (day-log--secs time) pkg label) lines)))))))
    (sort lines (lambda (a b) (< (car a) (car b))))))

(defun day-log--sessions (date)
  "Phone sessions on DATE: (START END LABEL).  Second value: any estimated?
A session runs until the next switch or the screen going off.  Before the
first screen event of the day (logs from before the app recorded them) an
app in use can't be told from a phone in a pocket, so those sessions are
cut at 20 minutes and the total marked estimated."
  (let* ((lines (day-log--foreground date))
         (first-screen (car (seq-find (lambda (l) (member (nth 1 l) '("-" "+"))) lines)))
         (end-of-day (day-log--now-secs date))
         app last sessions estimated)
    (cl-loop for (line . rest) on lines
             for (secs pkg label) = line
             for next = (if rest (car (car rest)) end-of-day)
             for blind = (or (null first-screen) (< secs first-screen))
             do (pcase pkg
                  ("-" (setq app nil))
                  ("+" (setq app last))
                  (_ (setq app label last label)))
             when (and app (> next secs))
             do (let ((end (if blind (min next (+ secs 1200)) next)))
                  (when (< end next) (setq estimated t))
                  (push (list secs end app) sessions)))
    (list (nreverse sessions) estimated)))

(defun day-log--merge (intervals)
  "INTERVALS, (START END ...) each, merged where they overlap, as (START END)."
  (let (merged)
    (dolist (i (sort (copy-sequence intervals) (lambda (a b) (< (car a) (car b)))))
      (if (and merged (<= (car i) (cadr (car merged))))
          (setcar merged (list (caar merged) (max (cadr (car merged)) (cadr i))))
        (push (list (car i) (cadr i)) merged)))
    (nreverse merged)))

(defun day-log--overlap (start end intervals)
  "Seconds of START..END covered by INTERVALS, (START END ...), disjoint."
  (let ((total 0))
    (dolist (i intervals total)
      (let ((s (max start (car i))) (e (min end (cadr i))))
        (when (> e s) (cl-incf total (- e s)))))))

(defun day-log--sum (items key)
  "Sum ITEMS' (LABEL . SECS) by LABEL, from KEY; most first."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (i items)
      (pcase-let ((`(,label . ,secs) (funcall key i)))
        (cl-incf (gethash label table 0) secs)))
    (sort (mapcar (lambda (k) (cons k (gethash k table))) (hash-table-keys table))
          (lambda (a b) (> (cdr a) (cdr b))))))

(defun day-log--top (pairs n &optional fmt)
  (mapconcat (lambda (p) (format "%s %s" (car p) (funcall (or fmt #'day-log--dur) (cdr p))))
             (seq-take (seq-filter (lambda (p) (> (cdr p) 0)) pairs) n)
             " · "))

;;; Facts: agents and passive time

(defun day-log--runs (runs clocks)
  "Lines for the day's agent, waiting and passive RUNS (`org-summary-runs'),
each agent task beside the time CLOCKS give it."
  (let* ((of (lambda (k) (seq-filter (lambda (r) (equal (plist-get r :kind) k)) runs)))
         (agent (funcall of "AGENT")) (wait (funcall of "WAIT")) (passive (funcall of "PASSIVE"))
         (len (lambda (r) (- (plist-get r :to) (plist-get r :from))))
         (secs (lambda (items) (apply #'+ (mapcar len items))))
         (by-title (lambda (items) (day-log--sum items (lambda (r) (cons (plist-get r :title)
                                                                         (funcall len r))))))
         (tasks (funcall by-title (append agent wait))))
    (insert (format "Agents %s on %d task%s, up to %d at once · waited on you %s · passive %s\n"
                    (day-log--dur (funcall secs agent)) (length tasks) (if (= 1 (length tasks)) "" "s")
                    (org-summary--most-at-once agent)
                    (day-log--dur (funcall secs wait)) (day-log--dur (funcall secs passive))))
    (when tasks
      (let ((you (day-log--sum clocks (lambda (c) (cons (nth 2 c) (- (cadr c) (car c))))))
            (agents (funcall by-title agent))
            (waits (funcall by-title wait)))
        (insert "\nAgents\n")
        (dolist (p tasks)
          (let ((w (alist-get (car p) waits 0 nil #'equal)))
            (insert (format "- %5s agent · %5s you%s  %s\n"
                            (day-log--dur (alist-get (car p) agents 0 nil #'equal))
                            (day-log--dur (alist-get (car p) you 0 nil #'equal))
                            (if (> w 0) (format " · %s waiting" (day-log--dur w)) "")
                            (car p)))))))
    (when passive
      (insert "\nPassive: " (day-log--top (funcall by-title passive) 6) "\n"))))

;;; The block

(defun org-dblock-write:day-log (params)
  "Write the facts of the day named by PARAMS' :date."
  (let* ((date (plist-get params :date))
         (clocks (day-log--clocks date))
         (covered (day-log--merge clocks))
         (clocked (apply #'+ (mapcar (lambda (c) (- (cadr c) (car c))) covered)))
         (phone (day-log--sessions date))
         (sessions (car phone))
         (screen (apply #'+ (mapcar (lambda (s) (- (cadr s) (car s))) sessions)))
         (unclocked (day-log--sum sessions
                                  (lambda (s) (cons (nth 2 s)
                                                    (- (cadr s) (car s)
                                                       (day-log--overlap (car s) (cadr s) covered))))))
         (done (day-log--done date))
         (used (usage-log-entries date date)))
    (insert (format "Clocked %s on %d task%s · phone %s%s, %s of it under no clock\n"
                    (day-log--dur clocked) (length clocks) (if (= 1 (length clocks)) "" "s")
                    (day-log--dur screen) (if (and sessions (cadr phone)) " (estimated)" "")
                    (day-log--dur (apply #'+ (mapcar #'cdr unclocked)))))
    ;; Agents' and passive time (agent-time.el), beside the clock's.
    (when-let* (((require 'org-summary nil t))
                (day (org-summary--parse-iso date))
                (runs (org-summary-runs day day)))
      (day-log--runs runs clocks))
    (when clocks
      (insert "\nClocked\n")
      (dolist (c clocks)
        (insert (format "- %s–%s %5s  %s\n"
                        (format-seconds "%02h:%02m" (car c)) (format-seconds "%02h:%02m" (cadr c))
                        (day-log--dur (- (cadr c) (car c))) (nth 2 c)))))
    (when done
      (insert (format "\nDone (%d)\n" (length done)))
      (dolist (d done) (insert "- " d "\n")))
    (when sessions
      (insert "\nPhone, under no clock: " (day-log--top unclocked 6) "\n")
      (insert "Phone, all: "
              (day-log--top (day-log--sum sessions (lambda (s) (cons (nth 2 s) (- (cadr s) (car s)))))
                            6)
              "\n")
      (insert "\nHours\n")
      (dotimes (h 24)
        (let* ((hs (* h 3600)) (he (+ hs 3600))
               (in-hour (delq nil (mapcar (lambda (s)
                                            (let ((o (day-log--overlap hs he (list s))))
                                              (and (> o 0) (cons (nth 2 s) o))))
                                          sessions)))
               (phone-secs (apply #'+ (mapcar #'cdr in-hour)))
               (clock-secs (day-log--overlap hs he covered)))
          (when (or (>= phone-secs 300) (>= clock-secs 300))
            (insert (format "- %02d  %-6s %s%s\n" h
                            (make-string (min 6 (round phone-secs 600)) ?▇)
                            (if (< phone-secs 60) ""
                              (format "phone %s: %s" (day-log--dur phone-secs)
                                      (day-log--top (day-log--sum in-hour #'identity) 2)))
                            (if (>= clock-secs 60)
                                (format "  [clocked %s]" (day-log--dur clock-secs))
                              "")))))))
    (when used
      (insert (format "\nUsed (%d runs): " (length used))
              (day-log--top (usage-log--count used (lambda (e) (nth 3 e))) 10 #'number-to-string)
              "\n"))
    ;; The habits' month so far as a picture (org-summary.el), drawn each
    ;; time the facts are, so a review closed on its own still has one.
    (when-let* ((file (and (require 'org-summary nil t)
                           (org-summary-habits-month-file (org-summary--parse-iso date)))))
      (insert "\n" (org-summary--link file) "\n"))
    ;; The block's last newline is the #+END line's.
    (delete-char -1)))

;;; The entry
;;
;; A day's review is the "* Daily Review" heading of its org-roam daily
;; note, the day's one page: the review, the logs, the photos.  Reviews
;; from before the move stay in `org-dailyreview-file''s datetree, and are
;; found there when the day's note has none.

(defun day-log-daily-file (date)
  "DATE's org-roam daily note."
  (expand-file-name (concat date ".org")
                    (expand-file-name (or (bound-and-true-p org-roam-dailies-directory) "daily/")
                                      org-roam-directory)))

(defun day-log-daily-buffer (date &optional create)
  "DATE's daily note's buffer; the note made first if CREATE and it isn't there."
  (let ((file (day-log-daily-file date)))
    (when (or (file-exists-p file) (find-buffer-visiting file) create)
      (or (find-buffer-visiting file)
          (with-current-buffer (progn (make-directory (file-name-directory file) t)
                                      (find-file-noselect file))
            (when (= (buffer-size) 0)
              (insert ":PROPERTIES:\n:ID:       " (org-id-uuid) "\n"
                      ":CREATED:  " (format-time-string "[%F %a %H:%M]") "\n:END:\n"
                      "#+title: " date "\n"))
            (current-buffer))))))

(defun day-log--find (date &optional create)
  "Where DATE's review is, as (BUFFER . POS): its daily note's, else an old
one in `org-dailyreview-file'.  With CREATE, one is added to the daily
note when there is none."
  (or (when-let* ((buf (day-log-daily-buffer date)))
        (with-current-buffer buf
          (org-with-wide-buffer
           (goto-char (point-min))
           (when (re-search-forward "^\\* Daily Review\\b" nil t)
             (cons buf (line-beginning-position))))))
      (when (and (bound-and-true-p org-dailyreview-file) (file-exists-p org-dailyreview-file))
        (let ((buf (find-file-noselect org-dailyreview-file)))
          (with-current-buffer buf
            (save-excursion
              (and (day-log--goto-day date)
                   (day-log--goto-review)
                   (cons buf (point)))))))
      (when create
        (let ((buf (day-log-daily-buffer date t)))
          (with-current-buffer buf
            (widen)
            (goto-char (point-max))
            (unless (bolp) (insert "\n"))
            (let ((pos (point)))
              (insert "* Daily Review :daylog:\n"
                      ":PROPERTIES:\n:DAY_LOG:  open\n:END:\n"
                      (format "#+BEGIN: day-log :date \"%s\"\n#+END:\n" date)
                      (mapconcat (lambda (p) (format "- %s :: \n" p)) day-log-prompts ""))
              (cons buf pos)))))))

(defmacro day-log--at (date &rest body)
  "BODY at DATE's review, if there is one; point and buffer kept."
  (declare (indent 1))
  `(when-let* ((at (day-log--find ,date)))
     (with-current-buffer (car at)
       (save-excursion
         (save-restriction
           (widen)
           (goto-char (cdr at))
           ,@body)))))

(defun day-log--goto-day (date &optional create)
  "Move to DATE's datetree heading in the current buffer; create it if CREATE.
Return non-nil if it is there."
  (widen)
  (goto-char (point-min))
  (if (re-search-forward (format "^\\*+ %s " (regexp-quote date)) nil t)
      (progn (org-back-to-heading t) t)
    (when create
      (pcase-let ((`(,y ,m ,d) (mapcar #'string-to-number (split-string date "-"))))
        (org-datetree-find-date-create (list m d y)))
      t)))

(defun day-log--goto-review ()
  "From a day heading, move to its Daily Review child.  Non-nil if found."
  (let ((end (save-excursion (org-end-of-subtree t t))))
    (when (re-search-forward "^\\*+ Daily Review\\b" end t)
      (org-back-to-heading t)
      t)))

(defun day-log--entry (date)
  "Move to DATE's review, creating it in its daily note, and return point."
  (let ((at (day-log--find date t)))
    (set-buffer (car at))
    (widen)
    (goto-char (cdr at))))

(defun day-log--refresh ()
  "Rewrite the day-log block in the review at point."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t t))))
      (when (re-search-forward "^#\\+BEGIN: day-log" end t)
        (goto-char (match-beginning 0))
        (org-update-dblock)))))

(defun day-log--written-p ()
  "Non-nil if any of your lines in the review at point has text."
  (save-excursion
    (let ((start (point)) (end (save-excursion (org-end-of-subtree t t))))
      (cl-some (lambda (p)
                 (goto-char start)
                 (and (re-search-forward (format "^- %s ::[ \t]*\\(.*\\)$" (regexp-quote p)) end t)
                      (not (string-blank-p (match-string 1)))))
               day-log-prompts))))

(defun day-log-written-p (&optional date)
  "Non-nil if DATE's (today's) review exists and has something of yours in it.
A review from before the day log, made by the old template, counts."
  (day-log--at (or date (day-log--today))
    (or (null (org-entry-get nil "DAY_LOG"))
        (day-log--written-p))))

;;;###autoload
(defun day-log-first-thing ()
  "Last night's \"First thing tomorrow\", or nil if it wasn't written."
  (let ((line (day-log--at (day-log--shift (day-log--today) -1)
                (day-log--line "First thing tomorrow"))))
    (and line (not (string-empty-p line)) line)))

;;;###autoload
(defun day-log-today ()
  "Open today's review, its facts brought up to now."
  (interactive)
  (day-log-open (day-log--today)))

(defun day-log-open (date)
  "Open DATE's review, its facts brought up to date."
  (interactive (list (org-read-date nil nil nil "Day: ")))
  (let ((pos (day-log--entry date)))
    (day-log--refresh)
    (pop-to-buffer-same-window (current-buffer))
    (goto-char pos)
    (org-fold-show-subtree)
    (recenter 0)
    ;; Leave point on your first empty line.
    (let ((end (save-excursion (org-end-of-subtree t t))))
      (when (re-search-forward "^- .* :: *$" end t)
        (goto-char (match-end 0))))))

;;; The review

(defun day-log--line (prompt)
  "Your line for PROMPT in the review at point, or \"\"."
  (save-excursion
    (if (re-search-forward (format "^- %s ::[ \t]*\\(.*\\)$" (regexp-quote prompt))
                           (save-excursion (org-end-of-subtree t t)) t)
        (string-trim (match-string-no-properties 1))
      "")))

(defun day-log--set-line (prompt text)
  "Set your line for PROMPT in the review at point to TEXT."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t t))))
      (if (re-search-forward (format "^- %s ::.*$" (regexp-quote prompt)) end t)
          (replace-match (format "- %s :: %s" prompt text) t t)
        (goto-char end)
        (unless (bolp) (insert "\n"))
        (insert (format "- %s :: %s\n" prompt text))))))

;;;###autoload
(defun day-log-review (&optional date)
  "The daily review, start to end, with no navigating: the day's facts on
screen, your three lines asked for one by one, then every undated task
given a date (`org-flow-date-undated'), then the next day's task for each
daily topic (`org-summary-plan-topics').  An empty answer skips a line or
a topic; q stops the walk.  DATE is today's review (the day turns at
`day-log-day-starts'); with \\[universal-argument], yesterday's."
  (interactive (list (when current-prefix-arg (day-log--shift (day-log--today) -1))))
  (let ((date (or date (day-log--today))))
    (day-log-open date)
    (let ((review (current-buffer)) (pos (day-log--entry date)))
      (dolist (prompt day-log-prompts)
        (let ((answer (string-trim
                       (read-string (format "%s: " prompt)
                                    (with-current-buffer review (goto-char pos) (day-log--line prompt))))))
          (with-current-buffer review
            (goto-char pos)
            (day-log--set-line prompt answer))))
      ;; Saving it written closes it, :written: (`day-log--close-if-written').
      (with-current-buffer review (save-buffer))
      (when (and (require 'org-flow nil t) (org-flow-undated))
        (org-flow-date-undated))
      (when (require 'org-summary nil t)
        (org-summary-plan-topics "Daily topics" (day-log--shift date 1)))
      (pop-to-buffer-same-window review)
      (goto-char pos)
      (org-fold-show-subtree)
      (recenter 0)
      (message "Review of %s done%s" date
               (if (day-log-written-p date) "" " (nothing written: it closes on its own at 4am)")))))

;;; Closing

(defun day-log--mark-habit (date how)
  "Mark the Daily Review habit DONE on DATE, noting HOW it was closed."
  (when-let* ((marker (org-id-find day-log-habit-id 'marker)))
    (with-current-buffer (marker-buffer marker)
      (org-with-wide-buffer
       (goto-char marker)
       (let* ((done-at (date-to-time (concat date " 23:59")))
              (state (org-get-todo-state))
              (sched (org-entry-get nil "SCHEDULED")))
         ;; A habit left for months is scheduled long ago, and each DONE
         ;; only moves a +1d habit one day on.  Bring it to this day first.
         (when (and sched (string< (substring sched 1 11) date))
           (org-entry-put nil "SCHEDULED"
                          (concat "<" date (format-time-string " %a" done-at)
                                  (substring sched 15))))
         ;; Org would log this on the next command -- from a timer, closing
         ;; several days, only the last would land.  Log it here instead.
         (let ((org-inhibit-logging t) (org-log-done nil) (org-log-repeat nil))
           (cl-letf (((symbol-function 'org-current-effective-time) (lambda () done-at)))
             (org-todo 'done)))
         (goto-char (org-log-beginning t))
         (insert (format "- State %-12s from %-12s %s \\\\\n  %s\n"
                         "\"DONE\"" (format "\"%s\"" state)
                         (format-time-string (org-time-stamp-format t t) done-at)
                         (if (eq how 'auto)
                             "auto: closed by the day log, nothing written"
                           "written: closed by the day log")))
         (org-entry-put nil "LAST_REPEAT" (format-time-string (org-time-stamp-format t t) done-at)))
       (save-buffer)))))

(defun day-log-close (date)
  "Finalise DATE's review: facts, :auto: or :written:, and the habit."
  (save-excursion
    (day-log--entry date)
    (day-log--refresh)
    (let ((how (if (day-log--written-p) 'written 'auto)))
      (org-entry-put nil "DAY_LOG" (symbol-name how))
      (org-entry-put nil "CLOSED_AT" (format-time-string "[%F %a %H:%M]"))
      (org-set-tags (list "daylog" (symbol-name how)))
      (save-buffer)
      (day-log--mark-habit date how)
      how)))

(defun day-log--closed-p (date)
  "Non-nil if DATE's review is closed, or predates the day log."
  (day-log--at date
    (not (equal (org-entry-get nil "DAY_LOG") "open"))))

(defun day-log-close-pending ()
  "Close every unclosed day of the last `day-log-catch-up-days', oldest first."
  (interactive)
  (let ((today (day-log--today)) closed)
    (dolist (n (number-sequence day-log-catch-up-days 1 -1))
      (let ((date (day-log--shift today (- n))))
        (unless (day-log--closed-p date)
          (push (format "%s %s" date (day-log-close date)) closed))))
    (day-log--finish (day-log--shift today -1))
    (when closed
      (message "Day log closed: %s" (string-join (nreverse closed) ", ")))))

(defun day-log--finish (date)
  "Rewrite the facts of DATE's review if it was written before the day ended."
  (day-log--at date
    (when (and (equal (org-entry-get nil "DAY_LOG") "written")
               (not (org-entry-get nil "FINAL")))
      (day-log--refresh)
      (org-entry-put nil "FINAL" (format-time-string "[%F %a %H:%M]"))
      (save-buffer))))

(defun day-log--close-if-written ()
  "After saving today's review: close it if you've now written in it."
  (when (and buffer-file-name (derived-mode-p 'org-mode))
    (let ((today (day-log--today)))
      (when (and (seq-some (lambda (f) (and f (file-exists-p f) (file-equal-p buffer-file-name f)))
                           (list (day-log-daily-file today) (bound-and-true-p org-dailyreview-file)))
                 (day-log--at today
                   (and (equal (org-entry-get nil "DAY_LOG") "open")
                        (day-log--written-p))))
        (day-log-close today)
        (message "Today's review closed: written")))))

(add-hook 'after-save-hook #'day-log--close-if-written)

(defun day-log-yesterday ()
  "Open yesterday's review."
  (interactive)
  (day-log-open (day-log--shift (day-log--today) -1)))

(provide 'day-log)
;;; day-log.el ends here
