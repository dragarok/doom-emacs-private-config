;;; voice-test.el --- Voice commands: matching, phrases, filling, clocking -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/voice-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.
;; Examples are hobbies only: this repository is public.

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'org-clock)
(require 'voice-command)
(defvar emacs-home-dir)                 ; emacs-home.el's, bound in a test

(defconst voice-test--books "\
#+TODO: TOREAD READING | READ
* TOREAD Atomic Habits
* READ A book already read
")

(defconst voice-test--tasks "\
* TODO Practice guitar scales :music:
* NEXT Piano practice: Hanon exercises :music:
* TODO Write the paper review
SCHEDULED: <2020-01-01 Wed>
* TODO Call the landlord about rent
* DONE Old finished thing
* TODO Workout at the fitness centre
* Projects
** TODO Fix the bicycle brakes
** TODO Learn a new song on guitar
")

(defconst voice-test--agents "* TODO Agent run that must never be clocked by voice\n")

(defmacro voice-test--with (&rest body)
  "BODY with a temporary agenda: tasks.org and agents.org."
  (declare (indent 0))
  `(let* ((dir (file-truename (make-temp-file "voice-test" t)))
          (org-agenda-files (list dir))
          (org-directory dir)
          (org-logs-directory dir)
          (org-meetings-file (expand-file-name "meetings.org" dir))
          (voice-file (expand-file-name "voice.org" dir))
          (voice-log-file (expand-file-name "voice.tsv" dir))
          (voice--index nil)
          (voice--rules-cache nil)
          (voice--file-cache (make-hash-table :test 'equal))
          (voice-learn nil)
          (org-clock-persist nil)
          (org-todo-keywords '((sequence "TODO" "NEXT" "|" "DONE" "CANCELED"))))
     (with-temp-file (expand-file-name "tasks.org" dir) (insert voice-test--tasks))
     (with-temp-file (expand-file-name "agents.org" dir) (insert voice-test--agents))
     (with-temp-file (expand-file-name "log_books.org" dir) (insert voice-test--books))
     (unwind-protect (progn ,@body)
       (when (org-clocking-p) (org-clock-out nil t))
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defun voice-test--top (text &optional verb)
  (plist-get (nth 2 (car (voice-rank-tasks text verb))) :title))

;;;; Words and similarity

(ert-deftest voice-test-tokens ()
  (should (equal (voice-match-tokens "Clock in to the Guitar practicing!")
                 '("clock" "guitar" "practic")))
  (should (equal (voice-match-words "two hours") '("2" "hours")))
  (should (equal (voice-match-stem "notes") "note"))
  (should (equal (voice-match-stem "studies") "study")))

(ert-deftest voice-test-sim ()
  (should (= (voice-match-sim "guitar" "guitar") 1.0))
  (should (= (voice-match-sim "gitar" "guitar") 0.9))       ; same consonants
  (should (= (voice-match-sim "gui" "guitar") 0.85))        ; prefix
  (should (= (voice-match-sim "cat" "dog") 0.0)))

;;;; Ranking tasks

(ert-deftest voice-test-rank-picks-the-distinctive-word ()
  (voice-test--with
    (should (equal (voice-test--top "guitar scales") "Practice guitar scales"))
    (should (equal (voice-test--top "piano") "Piano practice: Hanon exercises"))
    (should (equal (voice-test--top "paper review") "Write the paper review"))
    (should (equal (voice-test--top "bicycle") "Fix the bicycle brakes"))
    (should (equal (voice-test--top "landlord") "Call the landlord about rent"))))

(ert-deftest voice-test-rank-forgives-small-mishearings ()
  (voice-test--with
    (should (equal (voice-test--top "gitar scales") "Practice guitar scales"))
    (should (equal (voice-test--top "atomic habit") "Atomic Habits"))))

(ert-deftest voice-test-decide ()
  (voice-test--with
    (should (eq (voice-match-decide (voice-rank-tasks "fix the bicycle brakes")) 'act))
    ;; Two guitar tasks: "guitar" alone is not enough to act.
    (should (memq (voice-match-decide (voice-rank-tasks "guitar")) '(pick)))
    (should (eq (voice-match-decide (voice-rank-tasks "quantum chromodynamics")) 'none))))

(ert-deftest voice-test-done-and-agents-are-never-candidates ()
  (voice-test--with
    (let ((titles (mapcar (lambda (e) (plist-get e :title))
                          (append (voice-match-index-entries (voice--task-index)) nil))))
      (should (member "Practice guitar scales" titles))
      (should (member "Atomic Habits" titles))          ; a file's own #+TODO
      (should-not (member "Old finished thing" titles))
      (should-not (member "A book already read" titles))
      (should-not (member "Projects" titles))
      (should-not (seq-some (lambda (s) (string-match-p "Agent run" s)) titles)))))

(ert-deftest voice-test-read-leans-to-books ()
  (voice-test--with
    (let ((r (voice-rank-tasks "atomic habits" "read")))
      (should (> (car (car r)) (nth 1 (car r)))))))     ; a prior was added

;;;; Phrases

(defun voice-test--action (text &optional context)
  (let ((hit (voice--best-action (voice--words text)
                                 (voice--all-actions (or context '(android))))))
    (and hit (list (plist-get (car hit) :name) (voice--join (nth 1 hit))))))

(ert-deftest voice-test-phrases ()
  (should (equal (voice-test--action "clock in to the guitar scales") '("clock in" "guitar scales")))
  (should (equal (voice-test--action "Clock in guitar scales.") '("clock in" "guitar scales")))
  (should (equal (voice-test--action "work on paper review") '("clock in" "paper review")))
  (should (equal (voice-test--action "add task buy strings to guitar")
                 '("add task" "buy strings to guitar")))
  (should (equal (voice-test--action "start new task tune the piano")
                 '("add task" "tune the piano")))
  (should (equal (voice-test--action "save everything") '("save everything" "")))
  ;; Only while clocking.
  (should-not (equal (car (voice-test--action "done deep work")) "clock out"))
  (should (equal (car (voice-test--action "done deep work" '(clocking))) "clock out"))
  ;; "next": the image in an image buffer, the agent in a remote session.
  (should (equal (car (voice-test--action "next" '(remote image image-mode))) "next image"))
  (should (equal (car (voice-test--action "next" '(remote))) "next agent")))

(ert-deftest voice-test-rewrites-from-voice-org ()
  (voice-test--with
    (with-temp-file voice-file (insert "* Names\n* Phrases\n- wrap it up :: pause\n"))
    (should (equal (voice--rewrite "Wrap it up.") "pause"))
    (should (equal (voice--rewrite "something else") "something else"))))

;;;; Answering a command's questions from the sentence

(ert-deftest voice-test-fill-completing-read ()
  (let ((voice--fill (list :pool (voice-match-tokens "done deep work" t))))
    (should (equal (completing-read "Clock out: " '("not done" "done" "done, focus" "done, deep work"))
                   "done, deep work")))
  (let ((voice--fill (list :pool (voice-match-tokens "done" t))))
    (should (equal (completing-read "Clock out: " '("not done" "done" "done, focus" "done, deep work"))
                   "done")))
  (let ((voice--fill (list :pool (voice-match-tokens "not done" t))))
    (should (equal (completing-read "Clock out: " '("not done" "done" "done, focus" "done, deep work"))
                   "not done"))))

(ert-deftest voice-test-fill-read-char-choice ()
  (let ((voice--fill (list :pool (voice-match-tokens "attach camera photo" t))))
    (should (eq (read-char-choice "Attach: [c]amera or [l]atest? " '(?c ?l)) ?c)))
  (let ((voice--fill (list :pool (voice-match-tokens "attach the latest" t))))
    (should (eq (read-char-choice "Attach: [c]amera or [l]atest? " '(?c ?l)) ?l)))
  (let ((voice--fill (list :pool (voice-match-tokens "break down" t))))
    (should (eq (read-char-choice "[1/9] Task — d date  b break down  s someday  q stop: "
                                  '(?d ?b ?s ?q))
                ?b))))

(ert-deftest voice-test-fill-tags ()
  (let ((voice--fill (list :pool (voice-match-tokens "tag it food and travel" t))))
    (should (equal (sort (completing-read-multiple "Select tags: " '("food" "travel" "nature" "art"))
                         #'string<)
                   '("food" "travel")))))

(ert-deftest voice-test-claim-add-task ()
  (cl-letf (((symbol-function 'voice--choices)
             (lambda (s) (if (functionp s) '("Tasks" "Project" "Study" "Guitar" "Piano" "Mundane"
                                              "Hobby" "Normal")
                           s))))
    (let ((c (voice--claim (voice--add-task-asks)
                           (voice--words "buy strings to guitar priority b effort one hour"))))
      (should (equal (voice--join (car c)) "buy strings"))
      (should (equal (cdr (assoc "\\`Add to: " (cdr c))) "Guitar"))
      (should (equal (cdr (assoc "\\`Priority: " (cdr c))) "B"))
      (should (equal (cdr (assoc "\\`Effort" (cdr c))) "1:00")))
    ;; No preposition: "guitar" stays in the title.
    (let ((c (voice--claim (voice--add-task-asks) (voice--words "practice guitar"))))
      (should (equal (voice--join (car c)) "practice guitar"))
      (should-not (cdr c)))))

(ert-deftest voice-test-duration ()
  (should (equal (voice--duration '("1" "hour")) "1:00"))
  (should (equal (voice--duration '("half" "an" "hour")) "0:30"))
  (should (equal (voice--duration '("45" "minutes")) "0:45"))
  (should (equal (voice--duration '("2" "hours" "30" "minutes")) "2:30"))
  (should (equal (voice--duration '("90")) "1:30"))
  (should-not (voice--duration '("soon"))))

(ert-deftest voice-test-owned-prompts-are-asked-not-guessed ()
  ;; "add task" says "task", but the destination question belongs to the
  ;; action: unanswered, it is asked, never guessed from the verb.
  (let ((voice--fill (list :pool (voice-match-tokens "add task" t) :answers nil
                           :owned '("\\`Add to: "))))
    (cl-letf (((symbol-function 'voice-test--orig-asked) (lambda () t)))
      (let ((asked nil))
        (advice-add 'completing-read :override (lambda (&rest _) (setq asked t) "Tasks")
                    '((name . voice-test) (depth . 100)))
        (unwind-protect
            (progn (completing-read "Add to: " '("Tasks" "Mundane")) (should asked))
          (advice-remove 'completing-read 'voice-test))))))

;;;; Doing it

(ert-deftest voice-test-clock-in-end-to-end ()
  (voice-test--with
    (let ((plan (voice-dispatch "clock in to the bicycle brakes" :source "test")))
      (should (eq (plist-get plan :decision) 'act))
      (should (org-clocking-p))
      (should (equal org-clock-current-task "Fix the bicycle brakes"))
      (should (string-prefix-p "Clocked in" (plist-get plan :result)))
      ;; Undo takes it back.
      (voice-dispatch "undo" :source "test")
      (should-not (org-clocking-p)))
    ;; One line per utterance in the log.
    (with-temp-buffer
      (insert-file-contents voice-log-file)
      (should (= 2 (count-lines (point-min) (point-max))))
      (should (string-match-p "clock in to the bicycle brakes" (buffer-string))))))

(ert-deftest voice-test-dry-run-does-nothing ()
  (voice-test--with
    (let ((plan (voice-dispatch "clock in to the bicycle brakes" :source "test" :dry-run t)))
      (should (string-prefix-p "Would" (plist-get plan :result)))
      (should-not (org-clocking-p)))))

(ert-deftest voice-test-learned-name ()
  (voice-test--with
    (let ((voice-learn t))
      (voice--learn-name "gym" "Workout at the fitness centre")
      (with-temp-buffer
        (insert-file-contents voice-file)
        (should (string-match-p "^- gym :: Workout at the fitness centre$" (buffer-string))))
      ;; Said once more, it is not added twice.
      (should-not (voice--learn-name "Gym" "Workout at the fitness centre"))
      (let ((r (voice-rank-tasks "gym")))
        (should (equal (plist-get (nth 2 (car r)) :title) "Workout at the fitness centre"))
        (should (eq (voice-match-decide r) 'act))))))

(ert-deftest voice-test-spoken-text-is-never-lisp ()
  (voice-test--with
    (defvar voice-test--pwned nil)
    (dolist (text '("(setq voice-test--pwned t)" "\"); (setq voice-test--pwned t)"
                    "eval (setq voice-test--pwned t)"))
      (voice-dispatch text :source "test" :dry-run t))
    (should-not voice-test--pwned)))

(ert-deftest voice-test-toolbar-source ()
  (let ((map (make-sparse-keymap)) (shown nil))
    (defalias 'voice-test-zen (lambda () (interactive) 'zen))
    (defalias 'voice-test-kill-thing (lambda () (interactive) 'boom))
    (defalias 'voice-test-hidden (lambda () (interactive) 'hidden))
    (define-key map [zen] '(menu-item "Zen Test" voice-test-zen))
    (define-key map [kill] '(menu-item "Kill Test" voice-test-kill-thing))
    (define-key map [hid] `(menu-item "Hidden Test" voice-test-hidden :visible voice-test--shown))
    (define-key map [voice] '(menu-item "Voice" voice-listen))
    (defvar voice-test--shown nil)
    (let ((tool-bar-map map))
      (let ((names (mapcar (lambda (a) (plist-get a :name)) (voice--toolbar-actions))))
        (should (member "Zen Test" names))
        (should-not (member "Kill Test" names))  ; denied by name
        (should-not (member "Voice" names)))     ; never itself
      (let ((hidden (seq-find (lambda (a) (equal (plist-get a :name) "Hidden Test"))
                              (voice--toolbar-actions))))
        (should-not (funcall (plist-get hidden :when)))
        (setq voice-test--shown t)
        (should (funcall (plist-get hidden :when)))))))

(ert-deftest voice-test-link-refuses-voice-listen ()
  (should (get 'voice-listen 'no-link)))

(ert-deftest voice-test-answer-key-question ()
  (let ((voice--choice (cons "Attach: [c]amera or [l]atest? " '(?c ?l)))
        (unread-command-events nil))
    (voice--answer-prompt "camera")
    (should (equal unread-command-events '(?c)))))

(ert-deftest voice-test-never-answers-dangerous-questions ()
  (let ((voice--choice (cons "Really exit Emacs? [y]es [n]o " '(?y ?n)))
        (unread-command-events nil))
    (should (string-match-p "doesn't answer" (voice--answer-prompt "yes")))
    (should-not unread-command-events)))

;;;; Questions answered by the rest of the sentence

(ert-deftest voice-test-rest-answers-the-question ()
  (let ((got nil))
    (voice-test--with
      (let ((voice-actions nil))
        (voice-action '("diary …") (lambda () (setq got (completing-read "Diary entry: " nil)) "ok")
                      :asks '((:prompt "diary entry" :type rest)) :name "diary")
        (voice-dispatch "Diary: went running by the river." :source "test")
        (should (equal got "went running by the river"))
        ;; "Diary" alone names the tile, not an empty diary line.
        (voice-action '("diary") #'ignore :name "Diary tile")
        (should (equal (plist-get (plist-get (voice-plan "Diary." "test") :action) :name) "Diary tile"))
        (should (equal (plist-get (plist-get (voice-plan "diary a quiet day" "test") :action) :name) "diary"))))))

(ert-deftest voice-test-help-and-status ()
  (voice-test--with
    (should (equal (plist-get (voice-plan "what can I say" "test") :kind) 'action))
    (should (equal (plist-get (plist-get (voice-plan "what am I doing" "test") :action) :name) "status"))
    (should (equal (voice-status) "Not clocked in"))
    (should (equal (voice-help t) "What you can say"))
    (with-current-buffer "*Voice commands*"
      (should (string-match-p "\\*clock in\\*" (buffer-string)))
      (should (string-match-p "while clocked in" (buffer-string))))))

(ert-deftest voice-test-wav-header ()
  (let ((h (voice--wav-header 32000)))
    (should (= (length h) 44))
    (should (string-prefix-p "RIFF" h))
    (should (equal (substring h 40 44) (unibyte-string 0 125 0 0)))))

(ert-deftest voice-test-test-mode-only-plans ()
  (voice-test--with
    (let* ((dir (file-name-directory voice-log-file))
           (voice-test-marker (expand-file-name "TEST" dir))
           (voice-audio-directory dir)
           (emacs-home-dir dir)
           (voice--android nil))
      (with-temp-file voice-test-marker)
      (with-temp-file (expand-file-name "voice-heard.tsv" dir)
        (insert (format "%d\tisland\tclock in to the bicycle brakes\n" (float-time))))
      (should (eq (voice-from-app) 'quiet))
      (accept-process-output nil 0.3)
      (should-not (org-clocking-p))
      (with-temp-buffer
        (insert-file-contents (expand-file-name "test-log.tsv" dir))
        (should (string-match-p "Fix the bicycle brakes.*Would task" (buffer-string)))))))

(ert-deftest voice-test-exact-title-wins-by-less ()
  ;; Said word for word, a title wins by a smaller lead than a near match.
  (should (eq (voice-match-decide '((1.09 1.00 a) (0.93 0.88 b))) 'act))
  ;; Two full matches are still a pick.
  (should (eq (voice-match-decide '((1.05 1.00 a) (0.95 1.00 b))) 'pick))
  ;; A near match still needs the full lead.
  (should (eq (voice-match-decide '((0.95 0.90 a) (0.80 0.80 b))) 'pick)))

;;;; Lists answered by name, dates, near words

(ert-deftest voice-test-settle-on-the-named-entry ()
  (let ((apps '("Spotify" "Telegram" "Camera" "Firefox" "Files")))
    (should (equal (voice--settle "spotify" apps t) "Spotify"))
    (should (equal (voice--settle "the telegram" apps t) "Telegram"))
    ;; Free text allowed: only a word for word match is taken.
    (should (equal (voice--settle "camera" apps nil) "Camera"))
    (should-not (voice--settle "camera roll pictures" apps nil))))

(ert-deftest voice-test-unclear-answer-opens-the-list-nearest-first ()
  ;; "habits book" names no one entry: the list opens with the nearest
  ;; first, nothing typed (both words typed would empty it).
  (let (seen typed)
    (cl-letf (((symbol-function 'voice--orig-cr)
               (lambda (_p c &optional _pr _rm initial &rest _)
                 (setq seen (all-completions "" c) typed initial) "Atomic Habits")))
      (let ((voice--fill (list :pool nil :answers '(("\\`Node" . "habits book")) :owned '("\\`Node"))))
        (should (equal (voice--completing-read-a #'voice--orig-cr "Node: "
                                                 '("Garden plan" "Atomic Habits" "Habit tracker ideas" "Book list"))
                       "Atomic Habits"))
        (should (equal (car (last seen)) "Garden plan"))
        (should-not typed)))))

(ert-deftest voice-test-unclear-answer-types-only-words-the-list-has ()
  (let (typed)
    (cl-letf (((symbol-function 'voice--orig-cr)
               (lambda (_p _c &optional _pr _rm initial &rest _) (setq typed initial) "x"))
              ((symbol-function 'voice-emacs-order) (lambda (&rest _) nil)))
      (let ((voice--fill (list :pool nil :answers '(("\\`Node" . "garden zebra")) :owned '("\\`Node"))))
        (voice--completing-read-a #'voice--orig-cr "Node: " '("Garden plan" "Book list"))
        (should (equal typed "garden"))))))

(ert-deftest voice-test-dates ()
  (should (equal (voice--date "tomorrow") "+1d"))
  (should (equal (voice--date "for today") "."))
  (should (equal (voice--date "in three days") "+3d"))
  (should (equal (voice--date "next week") "+1w"))
  (should (equal (voice--date "on Friday") "fri"))
  (should-not (voice--date "whenever")))

(ert-deftest voice-test-exact-word-beats-near-word ()
  (voice-test--with
    (should (equal (plist-get (plist-get (voice-plan "Time." "test") :action) :name) "time"))
    (should (equal (plist-get (plist-get (voice-plan "set a timer for 25 minutes" "test") :action) :name) "timer"))
    (should (equal (plist-get (plist-get (voice-plan "timebox" "test") :action) :name) "plan tomorrow"))))

(ert-deftest voice-test-chatter-is-ignored ()
  (voice-test--with
    (should (equal (plist-get (plist-get (voice-plan "Okay, can you save everything, please?" "test") :action) :name)
                   "save everything"))
    (should (equal (plist-get (plist-get (voice-plan "Let's work on the bicycle brakes." "test") :action) :name)
                   "clock in"))
    (should (equal (plist-get (nth 2 (car (plist-get (voice-plan "I'm reading atomic habits" "test") :ranked))) :title)
                   "Atomic Habits"))))

(ert-deftest voice-test-schedule-and-mark-done-here ()
  (voice-test--with
    (with-current-buffer (find-file-noselect (expand-file-name "tasks.org" org-directory))
      (goto-char (point-min))
      (search-forward "Call the landlord")
      (save-window-excursion
        (switch-to-buffer (current-buffer))
        (voice-dispatch "schedule it for tomorrow" :source "test")
        (should (string-match-p (format-time-string "SCHEDULED: <%Y-%m-%d" (time-add nil 86400))
                                (buffer-substring (line-beginning-position) (save-excursion (forward-line 2) (point)))))
        (voice-dispatch "mark it done" :source "test")
        (should (equal (org-get-todo-state) "DONE"))))))

(defvar voice-test--ran nil)
(defun voice-test-water-the-plants () (interactive) (setq voice-test--ran 'plants))
(defun voice-test-delete-the-plants () (interactive) (setq voice-test--ran 'deleted))

(ert-deftest voice-test-run-any-command ()
  (voice-test--with
    (let ((voice-test--ran nil))
      ;; Said by its exact name, it runs.
      (voice-dispatch "run voice test water the plants" :source "test")
      (should (eq voice-test--ran 'plants))
      ;; A dangerous one asks first, and no is no.
      (setq voice-test--ran nil)
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (_) nil)))
        (voice-dispatch "run voice test delete the plants" :source "test"))
      (should-not voice-test--ran)
      ;; Voice never answers that question itself.
      (let ((voice--choice (cons "Run voice-test-delete-the-plants?  Answer by hand " '(?y ?n))))
        (should (string-match-p "doesn't answer" (voice--answer-prompt "yes"))))
      ;; Not exact but clear: it runs.
      (setq voice-test--ran nil)
      (voice-dispatch "run water plants" :source "test")
      (should (eq voice-test--ran 'plants))
      ;; Unclear: the list opens, the closest first.
      (let (first)
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_p table &rest _)
                     (setq first (seq-take (all-completions "" table) 2))
                     "voice-test-water-the-plants")))
          (voice-dispatch "run the plants" :source "test"))
        (should (member "voice-test-water-the-plants" first))))))

;;;; Tagging photos

(ert-deftest voice-test-spoken-tags ()
  (let ((tags '("food" "travel" "learningnote" "art" "memory" "money")))
    (should (equal (voice--spoken-tags "travel and food" tags) '("travel" "food")))
    (should (equal (voice--spoken-tags "learning note memories" tags) '("learningnote" "memory")))
    (should-not (voice--spoken-tags "the weather today" tags))))

(ert-deftest voice-test-one-tag-per-word ()
  (let ((tags '("apps" "app" "screenshot" "learningnote" "learning" "note")))
    ;; The closest tag, not every tag the word is near.
    (should (equal (voice--spoken-tags "app screenshot" tags) '("app" "screenshot")))
    (should (equal (voice--spoken-tags "apps" tags) '("apps")))
    ;; Two words run together win over each alone.
    (should (equal (voice--spoken-tags "learning note" tags) '("learningnote")))
    ;; Words that are no tag are told.
    (should (equal (voice--spoken-tags "cave app exploration" '("cave" "app") t)
                   '(("cave" "app") "exploration")))))

(ert-deftest voice-test-voiced-and-unvoiced-sound-alike ()
  (should (>= (voice-match-sim "dagging" "tagging") 0.9))
  (should (>= (voice-match-sim "bizza" "pissa") 0.9))
  (should (< (voice-match-sim "dog" "tok") 0.9)))   ; short words stay apart

(ert-deftest voice-test-stop-sentences-are-never-learned ()
  (let ((voice-learn t) wrote)
    (cl-letf (((symbol-function 'voice--rules) (lambda () '(nil)))
              ((symbol-function 'find-file-noselect) (lambda (&rest _) (setq wrote t) (generate-new-buffer "v"))))
      (should-not (voice--learn-name "Stop him is tagging" "Image Tagging"))
      (should-not (voice--learn-name "clock out on image tagging" "Image Tagging"))
      (should-not wrote))))

;;;; Near, not word for word

(ert-deftest voice-test-pattern-with-a-tail ()
  (should (equal (voice--pattern "mark … done") '(("mark") "done")))
  (should (equal (voice--pattern "clock in …") '(("clock" "in") . t)))
  (should (equal (voice--pattern "pause") '(("pause")))))

(ert-deftest voice-test-yes-or-no ()
  (should (eq (voice--yes-or-no "Yes.") 'yes))
  (should (eq (voice--yes-or-no "Yeah, do it") 'yes))
  (should (eq (voice--yes-or-no "No.") 'no))
  (should (eq (voice--yes-or-no "nope") 'no))
  (should-not (voice--yes-or-no "next image"))
  (should-not (voice--yes-or-no "yes I want to clock in to the guitar practice now")))

(ert-deftest voice-test-near-commands-act-or-ask ()
  (cl-letf (((symbol-function 'voice-context) (lambda (&optional _) '(android clocking))))
    (voice-test--with
      ;; Every word one of pause's own: done.
      (let ((p (voice-plan "pause clocking" "island")))
        (should (eq (plist-get p :kind) 'action))
        (should (equal (plist-get (plist-get p :action) :name) "pause")))
      ;; A stray word: asked about, not clocked in to a task.
      (let ((p (voice-plan "Stop him is tagging." "island")))
        (should (eq (plist-get p :kind) 'ask))
        (should (equal (plist-get (nth 1 (car (plist-get p :options))) :name) "stop tagging")))
      ;; A task's name is still a task.
      (should (eq (plist-get (voice-plan "guitar scales" "island") :kind) 'task)))))

(ert-deftest voice-test-yes-does-it-and-learns ()
  (let (did)
    (cl-letf (((symbol-function 'voice-context) (lambda (&optional _) '(android clocking)))
              ((symbol-function 'voice-stop-tagging) (lambda () (setq did t) "Tagging done")))
      (voice-test--with
        (let ((voice-learn t))
          (voice-dispatch "Stop him is tagging." :source "test")
          (should voice--confirm)
          (should-not did)
          (voice-dispatch "yes" :source "test")
          (should did)
          (should-not voice--confirm)
          ;; Taught: the same sentence is done straight away now.
          (setq did nil)
          (should (eq (plist-get (voice-dispatch "stop him is tagging" :source "test") :kind) 'action))
          (should did))))))

(ert-deftest voice-test-question-names-the-command ()
  (let ((pause (list :name "pause")) (tag (list :name "stop tagging")))
    (should (equal (voice--option-label (list 0.6 pause "stop" nil)) "\"stop\" (pause)"))
    (should (equal (voice--option-label (list 0.6 tag "stop tagging" nil)) "\"stop tagging\""))
    (should (equal (voice--option-label (list 0.6 (list :name "add task") "add task …" '(("milk" . "milk"))))
                   "\"add task milk\""))))

(ert-deftest voice-test-no-does-nothing ()
  (let (did)
    (cl-letf (((symbol-function 'voice-context) (lambda (&optional _) '(android clocking)))
              ((symbol-function 'voice-stop-tagging) (lambda () (setq did t) "Tagging done"))
              ((symbol-function 'org-clock-out) (lambda (&rest _) (setq did t))))
      (voice-test--with
        (voice-dispatch "Stop him is tagging." :source "test")
        (voice-dispatch "no" :source "test")
        (when voice--confirm (voice-dispatch "no" :source "test"))
        (should-not did)
        ;; Anything else said drops the question.
        (voice-dispatch "Stop him is tagging." :source "test")
        (voice-dispatch "what time is it" :source "test")
        (should-not voice--confirm)))))

(ert-deftest voice-test-mark-a-task-done-by-name ()
  (voice-test--with
    (let ((p (voice-dispatch "mark the bicycle brakes done" :source "test"))
          (tasks (expand-file-name "tasks.org" dir)))
      (should (equal (plist-get (plist-get p :action) :name) "mark task done"))
      (with-current-buffer (find-file-noselect tasks)
        (goto-char (point-min))
        (should (re-search-forward "^\\*\\* DONE Fix the bicycle brakes" nil t)))
      (voice-dispatch "undo" :source "test")
      (with-current-buffer (find-file-noselect tasks)
        (goto-char (point-min))
        (should (re-search-forward "^\\*\\* TODO Fix the bicycle brakes" nil t))))))

(ert-deftest voice-test-mark-done-while-clocked ()
  (voice-test--with
    (voice-dispatch "clock in to the bicycle brakes" :source "test")
    (should (org-clocking-p))
    (with-temp-buffer                   ; not on an Org heading
      (voice-dispatch "mark done" :source "test"))
    (should-not (org-clocking-p))
    (with-current-buffer (find-file-noselect (expand-file-name "tasks.org" dir))
      (goto-char (point-min))
      (should (re-search-forward "^\\*\\* DONE Fix the bicycle brakes" nil t)))))

(defmacro voice-test--with-photos (&rest body)
  "BODY with three photos waiting in a temporary inbox, the first shown."
  (declare (indent 0))
  `(let* ((inbox (file-name-as-directory (make-temp-file "voice-photos" t)))
          (voice-photo-inbox inbox)
          (voice-photo-session nil)
          (voice--photo-tags-cache (cons nil '("food" "travel" "art"))))
     (dolist (n '("a.png" "b.png" "c.png")) (with-temp-file (expand-file-name n inbox) (insert "x")))
     (unwind-protect
         (let ((buf (generate-new-buffer "photo")))
           (with-current-buffer buf
             (setq buffer-file-name (expand-file-name "a.png" inbox))
             (setq major-mode 'image-mode))
           (save-window-excursion
             (switch-to-buffer buf)
             ,@body))
       (delete-directory inbox t))))

(ert-deftest voice-test-say-the-tags ()
  (voice-test--with-photos
    (let (asked)
      (cl-letf (((symbol-function 'set-image-tags-and-rename-and-next)
                 (lambda () (setq asked (completing-read-multiple "Select tags: " '("food" "travel" "art"))))))
        ;; Tags alone, on a photo, tag it.
        (voice-dispatch "food and travel" :source "test")
        (should (equal asked '("food" "travel")))
        ;; From the clock island too, while a session runs.
        (setq asked nil voice-photo-session (list :tagged 0))
        (voice-dispatch "art" :source "island")
        (should (equal asked '("art")))))))

(ert-deftest voice-test-delete-photo-and-undo ()
  (voice-test--with-photos
    (cl-letf (((symbol-function 'image-next-file) #'ignore)
              ((symbol-function 'find-file) #'ignore))
      (voice-dispatch "delete it" :source "test")
      (should (file-exists-p (expand-file-name "Trash/a.png" inbox)))
      (should-not (file-exists-p (expand-file-name "a.png" inbox)))
      (voice-dispatch "undo" :source "test")
      (should (file-exists-p (expand-file-name "a.png" inbox))))))

(ert-deftest voice-test-stale-words-are-dropped ()
  (let* ((dir (make-temp-file "voice-home" t))
         (emacs-home-dir (file-name-as-directory dir)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "voice-heard.tsv" dir)
            (insert (format "%d\tisland\tsave everything\n" (- (float-time) 120))))
          (should (eq (voice-from-app) 'quiet)))
      (delete-directory dir t))))

;;;; Any command, by what it is called

(defun voice-test-paint-theme (theme)
  "A command that asks for a theme, as load-theme does."
  (interactive (list (intern (completing-read "Theme: " (mapcar #'symbol-name (custom-available-themes)) nil t))))
  (setq voice-test--ran theme))

(ert-deftest voice-test-words-that-mean-the-same ()
  (should (member "load" (voice-emacs-related "change")))
  (should (member "mode" (voice-emacs-related "toggle")))
  (should-not (member "mode" (voice-emacs-related "switch"))))

(ert-deftest voice-test-words-said-apart ()
  ;; "a car io dark" for doom-acario-dark: words run together count.
  (should (equal (plist-get (nth 2 (car (voice-match-strings '("doom-acario-dark" "doom-acario-light" "doom-one")
                                                             "a car io dark")))
                            :title)
                 "doom-acario-dark"))
  ;; ...but one word the start of a run is no match: switch is not switchdark.
  (should (< (voice-match--whole-sim "switch" "switchdark") 0.8)))

(ert-deftest voice-test-theme-describes-itself ()
  (should (string-match-p "dark" (or (voice-emacs--theme-doc 'tango-dark) ""))))

(ert-deftest voice-test-what-a-command-asks ()
  (should (eq (car (voice-emacs-asks 'voice-test-paint-theme)) 'theme))
  (should (eq (car (voice-emacs-asks 'switch-to-buffer)) 'buffer))
  (should (null (cdr (voice-emacs-asks 'forward-char)))))

(ert-deftest voice-test-command-by-its-name-runs ()
  (voice-test--with
    (should (voice-expect-ok "cmd:describe-function" (voice-plan "describe function" "test")))))

(ert-deftest voice-test-command-then-what-it-asks ()
  (voice-test--with
    (let ((voice-emacs--catalog nil) (voice-test--ran nil))
      ;; The command, then a value of its kind: run with it, no list.
      (let ((plan (voice-plan "paint theme to tango dark" "test")))
        (should (voice-expect-ok "cmd:voice-test-paint-theme" plan))
        (should (equal (plist-get (plist-get plan :action) :value) "tango-dark")))
      (voice-dispatch "paint theme to tango dark" :source "test")
      (should (eq voice-test--ran 'tango-dark)))))

(ert-deftest voice-test-a-value-its-command-unsaid-asks-then-learns ()
  ;; "switch to dark mode": no command says dark, themes do.  Asked; on a
  ;; yes the themes open, the dark ones first; the pick is learned.
  (voice-test--with
    (let* ((voice-emacs--catalog nil) (voice-test--ran nil) (voice-learn t) (voice--confirm nil)
           (plan (voice-plan "switch to dark mode" "test"))
           (first (nth 1 (car (plist-get plan :options))))
           seen)
      (should (eq (plist-get plan :kind) 'ask))
      (should (eq (car (voice-emacs-asks (plist-get first :run))) 'theme))
      (let ((completing-read-function (lambda (_p coll &rest _) (setq seen (all-completions "" coll)) (car seen)))
            (custom-safe-themes t))
        (cl-letf (((symbol-function 'voice--run-command)
                   (lambda (_cmd answer &optional _source)
                     ;; The same as the real one, on the test's command.
                     (let ((voice--fill (list :pool nil :answers (list (cons "" answer)) :owned nil))
                           (voice--recording t) (voice--answers nil))
                       (call-interactively #'voice-test-paint-theme)
                       (setq voice--last-run (list :cmd 'voice-test-paint-theme
                                                   :answer (seq-find #'stringp voice--answers)))
                       "ran"))))
          (voice-dispatch "switch to dark mode" :source "test")
          (should voice--confirm)
          (voice-dispatch "yes" :source "test")))
      (should voice-test--ran)
      (should (string-match-p "dark" (or (voice-emacs--theme-doc (intern (car seen))) (car seen))))
      (should (string-match-p (format "switch to dark mode :: run voice-test-paint-theme %s" (car seen))
                              (with-temp-buffer (insert-file-contents voice-file) (buffer-string)))))))

(ert-deftest voice-test-learned-command-sentence-runs ()
  (voice-test--with
    (let ((voice-test--ran nil))
      (with-temp-file voice-file (insert "* Phrases\n- night colours :: run voice-test-paint-theme tango-dark\n"))
      (voice-dispatch "night colours" :source "test")
      (should (eq voice-test--ran 'tango-dark)))))

(ert-deftest voice-test-press-in-a-list ()
  (let ((unread-command-events nil))
    (voice--press "<down>")
    (should (equal unread-command-events '(down)))))
(ert-deftest voice-test-a-domain-plugs-in ()
  "A new domain is one form: its claim is weighed with everything else,
its kind of plan done by it; defined again, the old one is taken down."
  (let ((voice-domains voice-domains) (down 0) done)
    (voice-test--with
      (voice-define-domain 'test-weather
        :claim (lambda (u _best)
                 (when (string-match-p "weather" (plist-get u :request))
                   (list :kind 'weather :text (plist-get u :text) :near 1.0)))
        :kinds `((weather . ,(lambda (_plan) (setq done t) "Sunny")))
        :disable (lambda () (cl-incf down)))
      (should (eq (plist-get (voice-plan "how is the weather" "test") :kind) 'weather))
      (should (equal (plist-get (voice-dispatch "how is the weather" :source "test") :result) "Sunny"))
      (should done)
      (voice-define-domain 'test-weather :doc "Nothing now.")
      (should (= down 1))
      (should-not (eq (plist-get (voice-plan "how is the weather" "test") :kind) 'weather)))))

(provide 'voice-test)
;;; voice-test.el ends here

;;;; The engine: its readings, a text field, your words

(ert-deftest voice-test-the-reading-that-makes-sense-wins ()
  ;; The engine's best guess means nothing here; its second names a task.
  (voice-test--with
    (let ((best (voice--best-reading '("glorp the wibble fnord" "clock in to the bicycle brakes")
                                     "island")))
      (should (equal (car best) "clock in to the bicycle brakes"))
      (should (voice--decisive-p (cddr best))))))

(ert-deftest voice-test-a-field-gets-words-typed ()
  ;; From another app's text field, what is no command is typed there.
  (voice-test--with
    (let* ((dir (file-name-directory voice-log-file))
           (emacs-home-dir dir)
           (voice-test-marker nil))
      (with-temp-file (expand-file-name "voice-heard.tsv" dir)
        (insert (format "%d\tfield\tthanks for the update see you soon\n" (float-time))))
      (should (eq (voice-from-app) 'type))
      (accept-process-output nil 0.3)
      (should-not (org-clocking-p)))))

(ert-deftest voice-test-a-field-still-takes-a-clear-command ()
  (voice-test--with
    (let* ((dir (file-name-directory voice-log-file))
           (emacs-home-dir dir)
           (voice-test-marker nil))
      (with-temp-file (expand-file-name "voice-heard.tsv" dir)
        (insert (format "%d\tfield\tclock in to the bicycle brakes\tclock in to the bicycle breaks\n"
                        (float-time))))
      (should (memq (voice-from-app) '(quiet front)))
      (accept-process-output nil 0.5)
      (should (org-clocking-p))
      (should (string-match-p "bicycle brakes" org-clock-current-task)))))

(ert-deftest voice-test-the-engine-hears-task-names ()
  (voice-test--with
    (let ((words (voice-engine-vocabulary)))
      (should (member "Fix the bicycle brakes" words))
      (should-not (member "Old finished thing" words))
      (should-not (seq-some (lambda (w) (string-match-p "[\t\n]" w)) words)))))
