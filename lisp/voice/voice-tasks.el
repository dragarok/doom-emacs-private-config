;;; voice-tasks.el --- Voice domain: tasks and the clock -*- lexical-binding: t -*-

;;; Commentary:
;; Clock in by naming a task, add one, mark one done, schedule it.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--fill)

;;;; Tasks

(defvar voice--file-cache (make-hash-table :test 'equal)
  "File -> (STAMP . CANDIDATES).")

(defvar voice--index nil "(STAMPS . INDEX), rebuilt when a file changes.")

(defun voice--keywords ()
  "(OPEN . DONE) keywords from `org-todo-keywords'."
  (let (open done)
    (dolist (seq (bound-and-true-p org-todo-keywords))
      (let* ((words (mapcar (lambda (w) (replace-regexp-in-string "(.*" "" w)) (cdr seq)))
             (bar (cl-position "|" words :test #'equal)))
        (if bar
            (progn (setq open (append open (seq-take words bar)))
                   (setq done (append done (nthcdr (1+ bar) words))))
          (setq open (append open (butlast words)) done (append done (last words))))))
    (cons (delete-dups (or open (list "TODO"))) (delete-dups (or done (list "DONE"))))))

(defun voice--file-keywords (kw)
  "The current buffer's keywords: its #+TODO lines if it has any, as Org
reads them, else KW."
  (let ((open nil) (done nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\(?:SEQ_\\|TYP_\\)?TODO:[ \t]*\\(.*\\)$" nil t)
        (let* ((words (mapcar (lambda (w) (replace-regexp-in-string "(.*" "" w))
                              (split-string (match-string 1))))
               (bar (cl-position "|" words :test #'equal)))
          (if bar
              (setq open (append open (seq-take words bar)) done (append done (nthcdr (1+ bar) words)))
            (setq open (append open (butlast words)) done (append done (last words)))))))
    (if (or open done) (cons open done) kw)))

(defun voice--date-days (stamp)
  "Days from today to STAMP, a YYYY-MM-DD string."
  (/ (float-time (time-subtract (date-to-time (concat stamp " 00:00"))
                                (date-to-time (format-time-string "%F 00:00"))))
     86400))

(defun voice--scan-buffer (file)
  "Candidates in the current buffer, from FILE: its open headings, and in
meetings.org its people."
  (let* ((kw (voice--file-keywords (voice--keywords)))
         (open (car kw)) (all (append (car kw) (cdr kw)))
         (meetings (and (bound-and-true-p org-meetings-file)
                        (equal (file-truename file) (file-truename org-meetings-file))))
         (stack nil) out)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward "^\\(\\*+\\)[ \t]+\\(.*?\\)[ \t]*$" nil t)
          (let* ((level (length (match-string 1)))
                 (rest (match-string-no-properties 2))
                 (pos (match-beginning 0))
                 keyword priority tags title)
            (when (string-match "\\`\\([A-Z]+\\)\\(?:[ \t]+\\|\\'\\)" rest)
              (when (member (match-string 1 rest) all)
                (setq keyword (match-string 1 rest) rest (substring rest (match-end 0)))))
            (when (string-match "\\`\\[#\\([A-Z0-9]\\)\\][ \t]*" rest)
              (setq priority (match-string 1 rest) rest (substring rest (match-end 0))))
            (when (string-match "[ \t]+\\(:[[:alnum:]_@#%:]+:\\)\\'" rest)
              (setq tags (match-string 1 rest) rest (substring rest 0 (match-beginning 0))))
            ;; A link counts by what it shows, not its id.
            (setq title (string-trim
                         (replace-regexp-in-string
                          "\\[\\[\\([^]]*\\)\\]\\]" "\\1"
                          (replace-regexp-in-string "\\[\\[[^]]*\\]\\[\\([^]]*\\)\\]\\]" "\\1" rest))))
            (while (and stack (>= (caar stack) level)) (pop stack))
            (let ((parent (cdar stack)))
              (push (cons level title) stack)
              (when (and (not (string-empty-p title))
                         (or (member keyword open)
                             (and meetings (= level 1) (null keyword) tags
                                  (string-match-p ":meeting:" tags))))
                (let ((end (save-excursion (or (and (re-search-forward "^\\*+[ \t]" nil t)
                                                    (match-beginning 0))
                                               (point-max))))
                      (prior 0.0) sched last)
                  (save-excursion
                    (forward-line 1)
                    (let ((lim (min end (save-excursion (forward-line 20) (point)))))
                      (when (re-search-forward "\\(?:SCHEDULED\\|DEADLINE\\): *<\\([0-9-]\\{10\\}\\)" lim t)
                        (setq sched (match-string 1)))
                      (goto-char (line-beginning-position 1))
                      (when (re-search-forward ":LAST_ACCESSED: *\\[\\([0-9-]\\{10\\}\\)" lim t)
                        (setq last (match-string 1)))))
                  (when (and sched (<= (voice--date-days sched) 7)) (cl-incf prior 0.06))
                  (when (member keyword '("NEXT" "ACTIVE" "READING" "WATCHING" "STARTED"))
                    (cl-incf prior 0.04))
                  (when (and last (>= (voice--date-days last) -7)) (cl-incf prior 0.03))
                  (when (member priority '("A" "B")) (cl-incf prior 0.02))
                  (push (list :title title :file file :pos pos :keyword keyword
                              :meeting (and meetings (null keyword))
                              :extra (concat (or parent "") " "
                                             (replace-regexp-in-string ":" " " (or tags "")))
                              :parent parent :prior prior)
                        out))))))))
    (nreverse out)))

(defun voice--stamp (file)
  (let ((buf (find-buffer-visiting file)))
    (if buf (list 'buf (buffer-chars-modified-tick buf))
      (let ((a (file-attributes file)))
        (list 'file (file-attribute-modification-time a) (file-attribute-size a))))))

(defun voice--task-files ()
  (seq-remove (lambda (f) (member (file-name-nondirectory f) voice-excluded-files))
              (append (and (fboundp 'org-agenda-files) (org-agenda-files t))
                      (and (bound-and-true-p org-meetings-file)
                           (file-exists-p org-meetings-file)
                           (list org-meetings-file)))))

(defun voice--file-candidates (file)
  (let ((stamp (voice--stamp file)) (hit (gethash file voice--file-cache)))
    (if (and hit (equal (car hit) stamp)) (cdr hit)
      (let ((c (let ((buf (find-buffer-visiting file)))
                 (if buf (with-current-buffer buf (voice--scan-buffer file))
                   (with-temp-buffer
                     (insert-file-contents file)
                     (voice--scan-buffer file))))))
        (puthash file (cons stamp c) voice--file-cache)
        c))))

(defun voice--task-index ()
  "The index of every task and person, rebuilt when a file changed."
  (let* ((files (delete-dups (mapcar #'file-truename (voice--task-files))))
         (stamps (mapcar (lambda (f) (cons f (voice--stamp f))) files))
         (names (car (voice--rules))))
    (if (and voice--index (equal (car voice--index) (cons names stamps)))
        (cdr voice--index)
      (let* ((cands (mapcar #'copy-sequence
                            (apply #'append (mapcar #'voice--file-candidates files))))
             (by-title (make-hash-table :test 'equal)))
        (dolist (c cands) (push c (gethash (voice-match-normalize (plist-get c :title)) by-title)))
        (dolist (n names)
          (dolist (c (gethash (voice-match-normalize (cdr n)) by-title))
            (plist-put c :aliases (cons (car n) (plist-get c :aliases)))))
        (let ((index (voice-match-index cands)))
          (setq voice--index (cons (cons names stamps) index))
          index)))))

(defun voice--verb-prior (verb)
  "Priors for the words used: \"read\" leans to books, \"watch\" to videos,
and the last few clocked tasks lean in."
  (let ((recent (seq-take (delq nil (mapcar (lambda (m) (and (markerp m) (marker-buffer m)
                                                             (cons (buffer-file-name (marker-buffer m))
                                                                   (marker-position m))))
                                            (bound-and-true-p org-clock-history)))
                          5)))
    (lambda (e)
      (+ (if (seq-some (lambda (r) (and (equal (car r) (plist-get e :file))
                                        (<= (abs (- (cdr r) (plist-get e :pos))) 200)))
                       recent)
             0.08 0.0)
         (let ((k (or (plist-get e :keyword) "")))
           (cond ((and (equal verb "read") (string-match-p "READ" k)) 0.05)
                 ((and (equal verb "watch") (string-match-p "WATCH" k)) 0.05)
                 ((and (member verb (quote ("meet" "meeting"))) (plist-get e :meeting)) 0.05)
                 (t 0.0)))))))

(defun voice-rank-tasks (text &optional verb)
  "Tasks and people for TEXT, best first, as `voice-match-rank' gives them."
  (voice-match-rank (voice--task-index) text 5 (voice--verb-prior verb)))

(defun voice--goto (c)
  "Visit candidate C's heading; point at it."
  (let ((buf (or (find-buffer-visiting (plist-get c :file))
                 (find-file-noselect (plist-get c :file) t)))
        (re (concat "^\\*+[ \t]+\\(?:[A-Z]+[ \t]+\\)?\\(?:\\[#.\\][ \t]*\\)?"
                    (regexp-quote (plist-get c :title)))))
    (set-buffer buf)
    (widen)
    (goto-char (min (plist-get c :pos) (point-max)))
    (unless (and (bolp) (looking-at re))
      (goto-char (point-min))
      (unless (re-search-forward re nil t)
        (user-error "Voice: \"%s\" is not in %s any more" (plist-get c :title)
                    (file-name-nondirectory (plist-get c :file))))
      (goto-char (line-beginning-position)))))

(defvar voice--last nil "(:what STRING :undo FUNCTION) for `voice-undo'.")

(defun voice-clock-in (c)
  "Clock in to candidate C, a task or a person; `voice-undo' takes it back."
  (let ((prev (and (fboundp 'org-clocking-p) (org-clocking-p) (copy-marker org-clock-marker))))
    (save-excursion
      (save-window-excursion
        (voice--goto c)
        (if (or (plist-get c :meeting) (not (fboundp 'rts-flow--clock-in-at-point)))
            (progn (org-clock-in) (org-save-all-org-buffers))
          (rts-flow--clock-in-at-point))))
    (setq voice--last
          (list :what (format "clock-in to %s" (plist-get c :title))
                :undo (lambda ()
                        (org-clock-cancel)
                        (when (and prev (marker-buffer prev))
                          (with-current-buffer (marker-buffer prev)
                            (save-excursion (goto-char prev) (org-clock-in))))
                        (org-save-all-org-buffers))))
    (format "Clocked in: %s%s" (if (plist-get c :meeting) "meeting with " "") (plist-get c :title))))

(defun voice--sorted-table (strings)
  (lambda (s pred action)
    (if (eq action 'metadata) '(metadata (display-sort-function . identity)
                                         (cycle-sort-function . identity))
      (complete-with-action action strings s pred))))

(defun voice--pick-task (said ranked verb &optional run)
  "Offer RANKED tasks for SAID, the best first; then a new task, then any.
RUN does it to the one picked: clock in, unless given."
  (let* ((items (append
                 (mapcar (lambda (r)
                           (let ((e (nth 2 r)))
                             (cons (format "%s%s%s" (if (plist-get e :meeting) "Meeting: " "")
                                           (plist-get e :title)
                                           (if (plist-get e :parent)
                                               (propertize (format "  · %s" (plist-get e :parent))
                                                           'face 'shadow)
                                             ""))
                                   e)))
                         ranked)
                 (list (cons (format "New task: %s" said) 'new)
                       (cons "Something else…" 'other))))
         (choice (let ((voice--fill nil))
                   (completing-read (format "Voice heard \"%s\": " said)
                                    (voice--sorted-table (mapcar #'car items)) nil t nil nil
                                    (caar items))))
         (picked (cdr (assoc choice items))))
    (pcase picked
      ('new (voice--add-task said nil))
      ('other (call-interactively (if (fboundp 'rts-flow-manual) #'rts-flow-manual #'org-clock-in)))
      ('nil "Nothing picked")
      (_ (let ((msg (funcall (or run #'voice-clock-in) picked)))
           (when (and (not (equal verb "meeting")) (not (string-empty-p said)))
             (let ((learned (voice--learn-name said (plist-get picked :title))))
               (when learned (setq msg (concat msg "; " learned)))))
           msg)))))

(defun voice--add-task (title answers)
  "Add a task TITLE through Add > Task, its questions answered from ANSWERS
where said, asked otherwise."
  (let ((voice--fill (list :pool nil :answers answers
                           :owned (mapcar (lambda (a) (plist-get a :prompt)) (voice--add-task-asks)))))
    (if (fboundp 'rts-flow--add-task-dispatch)
        (rts-flow--add-task-dispatch title)
      (user-error "Voice: Add > Task is not loaded"))
    (format "Added: %s" title)))

(defun voice--add-task-asks ()
  "What adding a task may ask that a sentence can answer."
  (list (list :prompt "\\`Add to: " :type 'choice
              :choices (lambda () (bound-and-true-p rts-flow-add-destinations)))
        (list :prompt "\\`Priority: " :key "priority" :type 'letter)
        (list :prompt "\\`Effort" :key "effort" :type 'duration)
        (list :prompt "\\`Category: " :key "category" :type 'choice
              :choices (lambda () (bound-and-true-p rts-instant-task-categories)))))

(defun voice-add-task (text)
  "Add the task TEXT names; \"to mundane\", \"priority b\", \"effort one
hour\", \"category hobby\" in it answer those questions."
  (let* ((claim (voice--claim (voice--add-task-asks) (voice--words text)))
         (title (voice--join (car claim))))
    (when (string-empty-p title) (setq title (read-string "Task title: ")))
    (voice--add-task title (cdr claim))))

(defun voice-undo ()
  "Take back the last voice action, when it can be."
  (interactive)
  (if-let* ((last voice--last))
      (progn (setq voice--last nil) (funcall (plist-get last :undo))
             (format "Undone: %s" (plist-get last :what)))
    "Nothing to undo"))

;;;; More things to say

(defun voice--date (text)
  "TEXT (\"tomorrow\", \"friday\", \"in 3 days\", \"next week\") as
`org-read-date' input, or nil."
  (let ((w (voice-match-words (or text ""))))
    (cond ((member "today" w) ".")
          ((or (member "tomorrow" w) (member "tmrw" w)) "+1d")
          ((and (member "next" w) (member "week" w)) "+1w")
          ((and (member "next" w) (member "month" w)) "+1m")
          ((let ((n (seq-find (lambda (x) (string-match-p "\\`[0-9]+\\'" x)) w)))
             (and n (or (member "day" w) (member "days" w)) (format "+%sd" n))))
          ((let ((n (seq-find (lambda (x) (string-match-p "\\`[0-9]+\\'" x)) w)))
             (and n (or (member "week" w) (member "weeks" w)) (format "+%sw" n))))
          ((seq-some (lambda (x)
                       (car (seq-find (lambda (d) (string-prefix-p (cdr d) x))
                                      '(("mon" . "mon") ("tue" . "tue") ("wed" . "wed") ("thu" . "thu")
                                        ("fri" . "fri") ("sat" . "sat") ("sun" . "sun")))))
                     w)))))

(defun voice-schedule (text)
  "Schedule the task here (in the agenda, the line's task) for TEXT."
  (let ((date (or (voice--date text) (user-error "Voice: when?  Say today, tomorrow, friday or in 3 days"))))
    (if (derived-mode-p 'org-agenda-mode)
        (org-agenda-schedule nil date)
      (org-schedule nil date))
    (format "Scheduled: %s" text)))

(defun voice-mark-done ()
  "Mark the task here done (in the agenda, the line's task); elsewhere the
one clocked in to."
  (cond ((derived-mode-p 'org-agenda-mode) (org-agenda-todo 'done) "Marked done")
        ((derived-mode-p 'org-mode) (org-todo 'done) "Marked done")
        ((and (fboundp 'org-clocking-p) (org-clocking-p))
         (let ((title (bound-and-true-p org-clock-current-task)))
           (voice--mark-done-at (copy-marker org-clock-marker) title)))
        (t (user-error "Voice: which task?  Say \"mark … done\""))))

(defun voice--org-here-p () (derived-mode-p 'org-mode 'org-agenda-mode))

(defun voice--done-here-p ()
  "A task to mark done: here, or clocked."
  (or (voice--org-here-p) (and (fboundp 'org-clocking-p) (org-clocking-p))))

(defun voice--mark-done-at (marker title)
  "Mark the task at MARKER done (clocking out of it, if clocked); undoable."
  (let (before)
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (setq before (org-get-todo-state))
        (org-todo 'done)))
    (org-save-all-org-buffers)
    (setq voice--last
          (list :what (format "done on %s" title)
                :undo (lambda ()
                        (with-current-buffer (marker-buffer marker)
                          (save-excursion (goto-char marker) (org-todo (or before ""))))
                        (org-save-all-org-buffers))))
    (format "Marked done: %s" title)))

(defun voice-mark-task-done (c)
  "Mark task C done, as `voice-clock-in' takes a task."
  (when (plist-get c :meeting) (user-error "Voice: %s is a person, not a task" (plist-get c :title)))
  (save-window-excursion
    (voice--goto c)
    (voice--mark-done-at (point-marker) (plist-get c :title))))

;;;; What to say

(defun voice-status ()
  "What the clock is on, and for how long."
  (if (and (fboundp 'org-clocking-p) (org-clocking-p))
      (format "Clocked in: %s, %s" org-clock-current-task
              (org-duration-from-minutes
               (floor (float-time (time-since org-clock-start-time)) 60)))
    "Not clocked in"))

(voice-action '("clock in to …" "clock into …" "clock in …" "start …" "work on …"
                "working on …" "start working on …" "switch to …" "time for …"
                "read …" "watch …" "practice …" "study …" "meeting with …" "meeting …")
              #'voice-clock-in :slot 'task :quiet t :name "clock in")

(voice-action '("add task …" "new task …" "add a task …" "create task …"
                "start new task …" "start a new task …")
              #'voice-add-task :slot 'text :name "add task")

(voice-action '("done …" "finished …" "not done …") #'rts-flow-clock-out
              :when 'clocking :quiet t :name "clock out")

(voice-action '("pause" "stop" "clock out" "stop the clock" "stop clock" "pause the clock")
              #'org-clock-out :when 'clocking :quiet t :name "pause")

(voice-action '("resume" "continue" "clock in again" "back to it")
              #'org-clock-in-last :quiet t :name "resume")

(voice-action '("cancel the clock" "cancel clock" "cancel")
              (lambda () (if (fboundp 'emacs-home--cancel) (emacs-home--cancel) (org-clock-cancel)))
              :when 'clocking :confirm t :name "cancel the clock")

(voice-action '("undo" "undo that" "take that back") #'voice-undo :quiet t :name "undo")

(voice-action '("schedule …" "schedule it …" "schedule for …") #'voice-schedule :slot 'text
              :when #'voice--org-here-p :where "on a task" :name "schedule")

(voice-action '("mark done" "mark as done" "mark it done" "complete it" "mark this done") #'voice-mark-done
              :when #'voice--done-here-p :where "on a task, or clocked in" :quiet t :name "mark done")

(voice-action '("mark … done" "mark … as done" "mark done …" "mark as done …" "complete …"
                "complete task …" "finish task …" "close task …")
              #'voice-mark-task-done :slot 'task :quiet t :name "mark task done")

(voice-action '("status" "what am i doing" "what am i on" "what's running" "how long"
                "what's the status" "what am i working on" "clock status")
              #'voice-status :quiet t :name "status")

;;;; The domain

(defun voice--tasks-for (u)
  "The tasks what U says names, best first; worked out once."
  (voice--once u :tasks (lambda () (voice-rank-tasks (plist-get u :request)))))

(defun voice--clock-in-action (u)
  (seq-find (lambda (a) (eq (plist-get a :run) #'voice-clock-in)) (plist-get u :actions)))

(defun voice--task-slot-plan (text action slot request)
  "The plan for ACTION, whose … names a task: SLOT (\"clock in to …\")."
  (let* ((verb (car (voice-match-words (car (plist-get action :phrases)))))
         (verb (let ((first (car (voice-match-tokens request t))))
                 (if (member first '("read" "watch" "meet")) first verb)))
         (ranked (and slot (not (string-empty-p slot)) (voice-rank-tasks slot verb)))
         (decision (if ranked (voice-match-decide ranked) 'none)))
    (list :kind 'task :text text :action action :slot slot :verb verb
          :ranked ranked :decision decision :found (if ranked (nth 1 (car ranked)) 0.0)
          :front (not (eq decision 'act)))))

(defun voice--task-claim (u best)
  "A task named clearly, as near as BEST at least: clock in to it."
  (let ((ranked (voice--tasks-for u)))
    (when (and ranked (eq (voice-match-decide ranked) 'act) (>= (nth 1 (car ranked)) best))
      (list :kind 'task :text (plist-get u :text) :slot (plist-get u :request) :ranked ranked
            :decision 'act :action (voice--clock-in-action u) :near (nth 1 (car ranked))))))

(defun voice--task-fallback (u strict)
  "The tasks nearest what U says, to pick one; STRICT: only if there are."
  (let* ((ranked (voice--tasks-for u))
         (decision (if ranked (voice-match-decide ranked) 'none)))
    (unless (and strict (null ranked))
      (cons (if (eq decision 'none) 0.0 (nth 1 (car ranked)))
            (list :kind 'task :text (plist-get u :text) :slot (plist-get u :request) :ranked ranked
                  :decision (if ranked 'pick 'none) :front t :action (voice--clock-in-action u))))))

(defun voice--execute-task (plan)
  "Do a task PLAN: to the task named clearly, else to one picked."
  (let ((ranked (plist-get plan :ranked)) (slot (plist-get plan :slot))
        (run (or (plist-get (plist-get plan :action) :run) #'voice-clock-in)))
    (cond ((eq (plist-get plan :decision) 'act) (funcall run (nth 2 (car ranked))))
          ((and (or (null slot) (string-empty-p slot)) (eq run #'voice-clock-in))
           (call-interactively (if (fboundp 'rts-flow-manual) #'rts-flow-manual #'org-clock-in))
           nil)
          ((or (null slot) (string-empty-p slot)) (user-error "Voice: which task?"))
          (t (voice--pick-task slot ranked (plist-get plan :verb) run)))))

(defun voice--task-vocab ()
  "The names of tasks and people, and the other names voice.org gives them."
  (let (out)
    (dolist (f (delete-dups (mapcar #'file-truename (voice--task-files))))
      (dolist (c (ignore-errors (voice--file-candidates f)))
        (push (plist-get c :title) out)
        (setq out (append (plist-get c :aliases) out))))
    out))

(voice-define-domain 'tasks
  :doc "Tasks and the clock: clock in by naming a task, add, mark done, schedule."
  :vocab #'voice--task-vocab
  :context (lambda (_source) (and (fboundp 'org-clocking-p) (org-clocking-p) '(clocking)))
  :claim #'voice--task-claim
  :fallback #'voice--task-fallback
  :slots '((task . voice--task-slot-plan))
  :kinds '((task . voice--execute-task)))

(provide 'voice-tasks)
;;; voice-tasks.el ends here
