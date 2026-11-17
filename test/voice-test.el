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
  (should (equal (car (voice-test--action "next" '(remote image-mode))) "next image"))
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

(ert-deftest voice-test-stale-words-are-dropped ()
  (let* ((dir (make-temp-file "voice-home" t))
         (emacs-home-dir (file-name-as-directory dir)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "voice-heard.tsv" dir)
            (insert (format "%d\tisland\tsave everything\n" (- (float-time) 120))))
          (should (eq (voice-from-app) 'quiet)))
      (delete-directory dir t))))

(provide 'voice-test)
;;; voice-test.el ends here
