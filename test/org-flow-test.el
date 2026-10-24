;;; org-flow-test.el --- Every task dated; broken down when it stalls -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/org-flow-test.el -f ert-run-tests-batch-and-exit
;; (add -L ~/.config/emacs/.local/straight/build-31.1/org-edna to check the
;; breakdown's chain blocks as configured)
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'org-flow)

(defvar org-tasks-file)
(defvar org-projects-file)
(defvar org-inbox-file)
(defvar org-mundane-tasks-file)
(defvar org-someday-file)
(defvar org-agenda-directory)

(defconst flow-test--tasks "* TODO Undated task
* TODO Dated task
SCHEDULED: <2026-10-25 Sun>
* TODO With a deadline
DEADLINE: <2026-10-30 Fri>
* DONE Finished
* PROJ A project
** NEXT Undated step
** TODO Dated step
SCHEDULED: <2026-10-26 Mon>
* PROJ An ordered project
:PROPERTIES:
:ORDERED:  t
:END:
** TODO First, dated
SCHEDULED: <2026-10-25 Sun>
** TODO Second, waits on the first
* TODO A habit
:PROPERTIES:
:STYLE:    habit
:END:
* Notes, not a task
* TODO Stalled task
SCHEDULED: <2026-10-20 Tue>
:LOGBOOK:
- Rescheduled from \"[2026-10-18 Sun]\" on [2026-10-19 Mon 08:00] \\\\
  Weekend
:END:
* TODO Fresh task
SCHEDULED: <2026-10-20 Tue>
")

(defmacro flow-test--with-org (&rest body)
  "BODY with tasks.org and inbox.org as the main files, someday.org beside."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "flow-test" t))
          (org-agenda-directory (file-name-as-directory dir))
          (org-tasks-file (expand-file-name "tasks.org" dir))
          (org-inbox-file (expand-file-name "inbox.org" dir))
          (org-projects-file (expand-file-name "projects.org" dir))
          (org-mundane-tasks-file (expand-file-name "mundane.org" dir))
          (org-someday-file (expand-file-name "someday.org" dir))
          ;; As in config.el.
          (org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")
                               (sequence "PROJ(p)" "|" "CANCELED(c@/!)")))
          (org-log-done 'time)
          (org-log-reschedule nil)
          (org-log-into-drawer t)
          (org-enforce-todo-dependencies t)
          (org-blocker-hook (cons #'org-block-todo-from-children-or-siblings-or-parent
                                  org-blocker-hook)))
     (with-temp-file org-tasks-file (insert flow-test--tasks))
     (with-temp-file org-inbox-file (insert "* TODO Captured on the go\n"))
     (with-temp-file org-mundane-tasks-file
       (insert "#+TODO: TONOTDO(t) | DONE(d!) STALLED(S/!)\n* TONOTDO Terrace\n"))
     (with-temp-file org-someday-file (insert "* TODO Already someday\n"))
     ;; Not a main file: never asked about.
     (with-temp-file (expand-file-name "log_books.org" dir) (insert "* TODO A book\n"))
     (with-temp-file (expand-file-name "ideas.org" dir) (insert "* TODO An idea\n"))
     (unwind-protect (progn ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defmacro flow-test--answering (strings dates &rest body)
  "BODY with `read-string' answering STRINGS and `org-read-date' DATES (ISO)."
  (declare (indent 2))
  `(let ((qs ,strings) (qd ,dates))
     (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (or (pop qs) "")))
               ((symbol-function 'org-read-date)
                (lambda (&rest _) (org-time-string-to-time (or (pop qd) (error "No date left"))))))
       ,@body)))

(defun flow-test--titles (markers)
  (mapcar (lambda (m) (with-current-buffer (marker-buffer m) (goto-char m) (org-flow--title))) markers))

(defun flow-test--goto (title)
  (set-buffer (find-file-noselect org-tasks-file))
  (goto-char (point-min))
  (re-search-forward (concat "^\\*+ \\(?:[A-Z]+ \\)?" (regexp-quote title) "$"))
  (beginning-of-line))

(defun flow-test--text (file)
  (with-current-buffer (find-file-noselect file) (revert-buffer t t) (buffer-string)))

;;; What counts as undated

(ert-deftest flow-test-undated ()
  "Open tasks without a date, in the main files only (not ideas.org); not
projects, habits, steps blocked by the one before, mundane's clock buckets,
done tasks, or plain headings."
  (flow-test--with-org
    (should (equal (flow-test--titles (org-flow-undated))
                   '("Undated task" "Undated step" "Captured on the go")))))

;;; Breaking down

(ert-deftest flow-test-breakdown ()
  "Goal and hard part in the body; the steps a chain (the first scheduled,
each one done schedules the next, none before the one above); the task's
schedule becomes the all-done-by deadline."
  (flow-test--with-org
    (flow-test--goto "Stalled task")
    (flow-test--answering '("A 2-page draft in essays/" "Don't know the argument yet"
                            "List 5 claims, 25 min" "Outline from the best claim" "Write it" "")
        '("2026-10-25" "2026-10-31")
      (org-flow-breakdown))
    (let ((text (flow-test--text org-tasks-file)))
      (should (string-match-p (concat "^\\* TODO Stalled task\nDEADLINE: <2026-10-31 Sat>\n"
                                      "\\(?:.*\n\\)*?Done when: A 2-page draft in essays/\n"
                                      "Hard part: Don't know the argument yet\n")
                              text))
      (should-not (string-match-p "Stalled task\nSCHEDULED" text))
      (should (string-match-p "^\\*\\* TODO List 5 claims, 25 min\nSCHEDULED: <2026-10-25 Sun>" text))
      (should (string-match-p "^\\*\\* TODO Outline from the best claim\n:PROPERTIES:" text))
      ;; The next top-level task is untouched, after the steps.
      (should (string-match-p "Write it\n\\(?:.*\n\\)*?\\* TODO Fresh task" text)))
    (with-current-buffer (find-file-noselect org-tasks-file)
      (let ((chain (org-map-entries (lambda () (list (org-get-heading t t t t)
                                                     (org-entry-get nil "BLOCKER")
                                                     (org-entry-get nil "TRIGGER")))
                                    "LEVEL=2+CREATED<>\"\"")))
        (should (equal chain
                       '(("List 5 claims, 25 min" nil "next-sibling scheduled!(\"++1d\") todo!(NEXT)")
                         ("Outline from the best claim" "previous-sibling" "next-sibling scheduled!(\"++1d\") todo!(NEXT)")
                         ("Write it" "previous-sibling" nil))))))
    ;; With org-edna (as configured), the later steps wait on the first:
    ;; not undated.  Run with -L pointing at org-edna to check it.
    (when (require 'org-edna nil t)
      (org-edna-mode 1)
      (unwind-protect
          (let ((undated (flow-test--titles (org-flow-undated))))
            (should (member "Undated task" undated))
            (should-not (member "Outline from the best claim" undated))
            (should-not (member "Write it" undated))
            ;; Done with the first step: the second is NEXT, the day after.
            (flow-test--goto "List 5 claims, 25 min")
            (org-todo "DONE")
            (when (memq 'org-add-log-note post-command-hook) (org-add-log-note))
            (flow-test--goto "Outline from the best claim")
            (should (equal (org-get-todo-state) "NEXT"))
            (should (equal (org-entry-get nil "SCHEDULED")
                           (format-time-string "<%Y-%m-%d %a>" (time-add nil (* 24 3600))))))
        (org-edna-mode -1)))))

(ert-deftest flow-test-breakdown-no-steps ()
  "Without a step nothing changes."
  (flow-test--with-org
    (flow-test--goto "Stalled task")
    (let ((before (buffer-string)))
      (should-error (flow-test--answering '("A goal" "" "") nil (org-flow-breakdown))
                    :type 'user-error)
      (should (equal (buffer-string) before)))))

;;; The second reschedule

(ert-deftest flow-test-second-reschedule ()
  "Rescheduled once already: asked, and a yes breaks it down.  First time,
or a no: just rescheduled.  Not asked when called from code."
  (flow-test--with-org
    (org-flow-mode 1)
    (unwind-protect
        (let ((asked 0))
          (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) (cl-incf asked) t)))
            ;; First reschedule: no question.
            (flow-test--goto "Fresh task")
            (let ((this-command 'org-schedule)) (org-schedule nil "2026-10-28"))
            (should (= asked 0))
            (should (string-match-p "Fresh task\nSCHEDULED: <2026-10-28" (buffer-string)))
            ;; From code: no question either.
            (flow-test--goto "Stalled task")
            (org-schedule nil "2026-10-29")
            (should (= asked 0))
            ;; By hand, the second time: asked, and broken down.
            (flow-test--goto "Stalled task")
            (flow-test--answering '("Shipped" "" "First step" "") '("2026-10-26" "2026-10-26")
              (let ((this-command 'org-schedule)) (org-schedule nil)))
            (should (= asked 1))
            (should (string-match-p "^\\*\\* TODO First step\nSCHEDULED: <2026-10-26 Mon>"
                                    (flow-test--text org-tasks-file))))
          ;; A no: rescheduled as asked.
          (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
            (flow-test--goto "Fresh task")
            (insert "")
            (save-excursion (forward-line 1) (forward-line 1)
                            (insert "- Rescheduled from \"[2026-10-20 Tue]\" on [2026-10-24 Sat 10:00]\n"))
            (let ((this-command 'org-schedule)) (org-schedule nil "2026-11-02"))
            (should (string-match-p "Fresh task\nSCHEDULED: <2026-11-02" (buffer-string)))))
      (org-flow-mode -1))))

;;; Walking the undated

(ert-deftest flow-test-walk ()
  "d dates, c cancels with the reason logged, s moves to someday; what was
skipped stays undated; files outside the main ones are not asked about."
  (flow-test--with-org
    (let ((keys (list ?d ?s ?c)) msg)
      (cl-letf (((symbol-function 'read-char-choice) (lambda (&rest _) (pop keys)))
                ((symbol-function 'pop-to-buffer-same-window) #'set-buffer)
                ((symbol-function 'recenter) #'ignore)
                ((symbol-function 'message) (lambda (f &rest a) (setq msg (apply #'format f a)))))
        (flow-test--answering '("Not mine to do") '("2026-10-26")
          (org-flow-date-undated)))
      (should (equal msg "Dated 1, broken down 0, to someday 1, cancelled 1, done 0, skipped 0; 0 left undated"))
      (let ((tasks (flow-test--text org-tasks-file)))
        (should (string-match-p "\\* TODO Undated task\nSCHEDULED: <2026-10-26 Mon>" tasks))
        (should-not (string-match-p "Undated step" tasks)))
      (should (string-match-p "\\* NEXT Undated step" (flow-test--text org-someday-file)))
      (should (string-match-p (concat "\\* CANCELED Captured on the go\n\\(?:.*\n\\)*?"
                                      "- State \"CANCELED\" +from \"TODO\" +\\[[^]]+\\] \\\\\\\\\n"
                                      " +Not mine to do")
                              (flow-test--text org-inbox-file))))))

(ert-deftest flow-test-walk-skip-and-stop ()
  "n leaves a task undated, x marks it done, q stops."
  (flow-test--with-org
    (let ((keys (list ?n ?x ?q)) msg)
      (cl-letf (((symbol-function 'read-char-choice) (lambda (&rest _) (pop keys)))
                ((symbol-function 'pop-to-buffer-same-window) #'set-buffer)
                ((symbol-function 'recenter) #'ignore)
                ((symbol-function 'message) (lambda (f &rest a) (setq msg (apply #'format f a)))))
        (org-flow-date-undated))
      (should (string-match-p "skipped 1; 2 left undated" msg))
      (should (string-match-p "done 1" msg))
      (should (string-match-p "\\* DONE Undated step\\|\\*\\* DONE Undated step" (flow-test--text org-tasks-file))))))

(ert-deftest flow-test-all-dated ()
  (flow-test--with-org
    (with-temp-file org-inbox-file (insert ""))
    (let (msg)
      (cl-letf (((symbol-function 'message) (lambda (f &rest a) (setq msg (apply #'format f a))))
                ((symbol-function 'read-char-choice) (lambda (&rest _) ?d))
                ((symbol-function 'pop-to-buffer-same-window) #'set-buffer)
                ((symbol-function 'recenter) #'ignore))
        (flow-test--answering nil '("2026-10-26" "2026-10-26") (org-flow-date-undated))
        (org-flow-date-undated))
      (should (equal msg "Every task has a date")))))

(ert-deftest flow-test-cancel-note-without-state-log ()
  "Where cancelling logs nothing, the reason is still kept, as a note."
  (flow-test--with-org
    (let ((org-todo-keywords '((sequence "TODO" "|" "DONE" "CANCELED"))))
      (with-current-buffer (find-file-noselect org-inbox-file)
        (org-mode)
        (goto-char (point-min))
        (org-flow--set-state "CANCELED" "Not mine to do")
        (should (string-match-p "\\* CANCELED Captured on the go\n\\(?:.*\n\\)*?- Note taken on \\[[^]]+\\] \\\\\\\\\n +Not mine to do"
                                (buffer-string)))))))

;;; org-flow-test.el ends here
