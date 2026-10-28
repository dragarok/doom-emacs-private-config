;;; agent-time-test.el --- States follow agents' work -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/agent-time-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'agent-time)

(defvar org-tasks-file)

(defmacro agent-time-test--with (text &rest body)
  "BODY with agents.org holding TEXT in a temporary agenda, an empty
tasks.org beside it, and no pane state."
  (declare (indent 1))
  `(let* ((dir (file-truename (make-temp-file "agent-time-test" t)))
          (org-tasks-file (expand-file-name "tasks.org" dir))
          (org-agenda-files (list dir))
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-locations nil)
          (org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")))
          (org-log-done 'time)
          (org-log-into-drawer t)
          (agent-time--panes (make-hash-table :test #'equal))
          (doom-cache-dir dir))
     (with-temp-file (agent-time--file) (insert ,text))
     (with-temp-file org-tasks-file)
     (unwind-protect (progn ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defun agent-time-test--text (&optional file)
  (with-current-buffer (find-file-noselect (or file (agent-time--file)))
    (save-buffer)
    (buffer-substring-no-properties (point-min) (point-max))))

(defun agent-time-test--ts (hours-ago)
  (agent-time--ts (- (float-time) (* hours-ago 3600))))

(defmacro agent-time-test--at-heading (title &rest body)
  "BODY at TITLE's heading in agents.org, saved after."
  (declare (indent 1))
  `(with-current-buffer (find-file-noselect (agent-time--file))
     (goto-char (point-min))
     (re-search-forward (concat "^\\*.* " (regexp-quote ,title)))
     ,@body
     (save-buffer)))

(defun agent-time-test--entry (title)
  "TITLE's entry text, heading to the next heading."
  (let ((text (agent-time-test--text)))
    (string-match (concat "^\\*.* " (regexp-quote title) "[^\n]*\n\\(?:[^*].*\n\\|\n\\)*") text)
    (match-string 0 text)))

(ert-deftest agent-time-test-next-while-working ()
  "An agent starting work moves its TODO to NEXT; waiting doesn't, nor does
work on a task in another state."
  (agent-time-test--with "* TODO Fix sink\n:PROPERTIES:\n:ID: a\n:END:\n* TODO Read\n:PROPERTIES:\n:ID: b\n:END:\n"
    (agent-time--begin "p1" (list :task "b") "WAIT" (float-time))
    (should (string-match-p "^\\* TODO Read" (agent-time-test--text)))
    (agent-time--begin "p1" (list :task "a") "AGENT" (float-time))
    (should (string-match-p "^\\* NEXT Fix sink" (agent-time-test--text)))
    (agent-time--begin "p1" (list :task "a") "AGENT" (float-time))
    (should (string-match-p "^\\* NEXT Fix sink" (agent-time-test--text)))))

(ert-deftest agent-time-test-your-task ()
  "An agent on a task of yours leaves your file as it is: the runs go on a
heading in agents.org linking to it, the same one each time."
  (agent-time-test--with ""
    (with-temp-file org-tasks-file
      (insert "* TODO Plan the trip\n:PROPERTIES:\n:ID: y\n:END:\n"))
    (let ((before (agent-time-test--text org-tasks-file))
          (st (list :task "y" :how 'user)))
      (setq st (agent-time--begin "p1" st "AGENT" (- (float-time) 600)))
      (setq st (agent-time--end "p1" st (- (float-time) 300)))
      (agent-time--begin "p1" st "WAIT" (float-time))
      (should (equal (agent-time-test--text org-tasks-file) before))
      (let ((text (agent-time-test--text)))
        (should (= 1 (with-temp-buffer (insert text) (goto-char (point-min))
                                       (how-many "^\\* \\[\\[id:y\\]\\[Plan the trip\\]\\]"))))
        (should (string-match-p ":TASK_ID: +y$" text))
        (should (string-match-p "AGENT: \\[[^]]+\\]--\\[[^]]+\\] =>  0:05  p1" text))
        (should (string-match-p "WAIT: \\[[^]]+\\]  p1" text))))))

(ert-deftest agent-time-test-close-quiet ()
  "An agent's task quiet past `agent-time-close-after' is DONE with a note;
one running or recently worked on is left, and yours are never touched;
the pane on a closed task lets it go."
  (agent-time-test--with
      (concat "* NEXT Old research :agent:\n:PROPERTIES:\n:ID: old\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p1\n:END:\n"
              "* NEXT Running :agent:\n:PROPERTIES:\n:ID: run\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p2\n"
              "WAIT: " (agent-time-test--ts 7) "  p2\n:END:\n"
              "* TODO Recent :agent:\n:PROPERTIES:\n:ID: recent\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 11) "--" (agent-time-test--ts 10) " =>  1:00  p3\n:END:\n"
              "* TODO Never ran :agent:\n:PROPERTIES:\n:ID: never\n:CREATED: " (agent-time-test--ts 40) "\n:END:\n"
              "* [[id:yours][Yours]]\n:PROPERTIES:\n:TASK_ID: yours\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p4\n:END:\n"
              "* Agent quick asks :agent:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p6\n:END:\n")
    (with-temp-file org-tasks-file
      (insert "* NEXT Yours\n:PROPERTIES:\n:ID: yours\n:END:\n"))
    (puthash "p1" (list :task "old" :how 'auto) agent-time--panes)
    (puthash "p4" (list :task "yours" :how 'user) agent-time--panes)
    (with-current-buffer (find-file-noselect (agent-time--file))
      (goto-char (point-max))
      (insert "* DONE Closed by hand :agent:\n:PROPERTIES:\n:ID: hand\n:END:\n")
      (save-buffer))
    (puthash "p7" (list :task "hand" :how 'auto) agent-time--panes)
    (should (equal (sort (agent-time-close-quiet) #'string<) '("never" "old")))
    (let ((text (agent-time-test--text)))
      (should (string-match-p "^\\* DONE Old research" text))
      (should (string-match-p "^\\* DONE Never ran" text))
      (should (string-match-p "^\\* NEXT Running" text))
      (should (string-match-p "^\\* TODO Recent" text))
      (should (string-match-p "^\\* Agent quick asks" text)))
    (should (string-match-p "CLOSED: \\[" (agent-time-test--entry "Old research")))
    (should (string-match-p "Closed by itself: no agent work since" (agent-time-test--entry "Old research")))
    (should (string-match-p "^\\* NEXT Yours" (agent-time-test--text org-tasks-file)))
    (should (null (plist-get (gethash "p1" agent-time--panes) :task)))
    (should (null (plist-get (gethash "p7" agent-time--panes) :task)))
    (should (equal (plist-get (gethash "p4" agent-time--panes) :task) "yours"))))

(ert-deftest agent-time-test-second-start ()
  "A second task_start closes the agent's previous task and opens a new one."
  (agent-time-test--with ""
    (cl-letf (((symbol-function 'agent-time--project) (lambda (_) "proj")))
      (agent-time--mcp-start "p1" "/tmp" "Research wards")
      (agent-time--mcp-start "p1" "/tmp" "Research tourism"))
    (let ((text (agent-time-test--text)))
      (should (string-match-p "^\\* DONE Research wards" text))
      (should (string-match-p "the agent started other work" text))
      (should (string-match-p "^\\* TODO Research tourism" text)))
    (should (equal (agent-time--title-at (agent-time--marker (plist-get (gethash "p1" agent-time--panes) :task)))
                   "Research tourism"))))

(ert-deftest agent-time-test-running-moves ()
  "A running line never stays open on a task the agent has left: a second
task_start closes it there and reopens it on the new task, and so does
closing the task by hand while the agent works."
  (agent-time-test--with ""
    (cl-letf (((symbol-function 'agent-time--project) (lambda (_) "proj")))
      (agent-time--mcp-start "p1" "/tmp" "First")
      (let ((st (gethash "p1" agent-time--panes)))
        (puthash "p1" (agent-time--begin "p1" st "AGENT" (- (float-time) 600)) agent-time--panes))
      (agent-time--mcp-start "p1" "/tmp" "Second"))
    (should (string-match-p "AGENT: \\[[^]]+\\]--\\[[^]]+\\] =>  0:10  p1" (agent-time-test--entry "First")))
    (should (string-match-p "AGENT: \\[[^]]+\\]  p1$" (agent-time-test--entry "Second")))
    (agent-time-test--at-heading "Second" (org-todo "DONE"))
    (agent-time-close-quiet)
    (should-not (string-match-p "AGENT: \\[[^]]+\\]  p1$" (agent-time-test--entry "Second")))
    (let ((st (gethash "p1" agent-time--panes)))
      (should (null (plist-get st :task)))
      (should (equal (plist-get st :kind) "AGENT")))))

(defmacro agent-time-test--typing (viewed &rest body)
  "BODY with every agent buffer showing pane p1 and VIEWED (a pane or nil)
in the selected window, and nobody with an agent yet."
  (declare (indent 1))
  `(let ((agent-time--keys nil) (agent-time--you nil)
         (buf (get-buffer-create "*herdr*")))
     (cl-letf (((symbol-function 'agent-time--buffer-pane) (lambda (_) "p1"))
               ((symbol-function 'agent-time--viewed-pane) (lambda () ,viewed)))
       (unwind-protect (progn ,@body) (kill-buffer buf)))))

(defun agent-time-test--you-line (title)
  (let ((entry (agent-time-test--entry title)))
    (and (string-match "^[ \t]*YOU: \\[[^]]+ \\([0-9:]+\\)\\]--\\[[^]]+ \\([0-9:]+\\)\\] => +\\([0-9:]+\\)  p1$" entry)
         (list (match-string 1 entry) (match-string 2 entry) (match-string 3 entry)))))

(ert-deftest agent-time-test-you-typing ()
  "Typing to an agent writes a YOU line from the first key to a minute past
the last, and leaves the clock on the book you are reading."
  (agent-time-test--with "* TODO Fix sink\n:PROPERTIES:\n:ID: a\n:END:\n"
    (puthash "p1" (list :task "a") agent-time--panes)
    (with-current-buffer (find-file-noselect org-tasks-file)
      (insert "* TODO Read a book\n")
      (goto-char (point-min))
      (re-search-forward "Read a book")
      (org-clock-in))
    (let ((t0 (float-time (encode-time '(0 0 10 28 10 2026 nil -1 nil)))))
      (agent-time-test--typing "p1"
        (setq agent-time--keys (cons buf (cons t0 (+ t0 5))))
        (agent-time--you-tick (+ t0 10))
        (setq agent-time--keys (cons buf (cons (+ t0 12) (+ t0 125))))
        (agent-time--you-tick (+ t0 130))
        (agent-time--you-tick (+ t0 180))    ; still within the minute
        (should agent-time--you)
        (agent-time--you-tick (+ t0 190))))  ; past it
    (should-not agent-time--you)
    (should (equal (agent-time-test--you-line "Fix sink") '("10:00" "10:03" "0:03")))
    (should (org-clocking-p))
    (should (equal org-clock-current-task "Read a book"))
    (org-clock-cancel)))

(ert-deftest agent-time-test-you-leave ()
  "Going back to something else ends your time with the agent then, but a
minute at least; with no task yet it waits with the agent's own work."
  (agent-time-test--with "* TODO Fix sink\n:PROPERTIES:\n:ID: a\n:END:\n"
    (puthash "p1" (list :task "a") agent-time--panes)
    (let ((t0 (float-time (encode-time '(0 0 10 28 10 2026 nil -1 nil)))))
      (agent-time-test--typing nil
        (setq agent-time--keys (cons buf (cons t0 (+ t0 5))))
        (agent-time--you-tick (+ t0 10))   ; typed, then left at once
        (should agent-time--you)
        (agent-time--you-tick (+ t0 20)))
      (should (equal (agent-time-test--you-line "Fix sink") '("10:00" "10:01" "0:01")))
      (puthash "p1" (list :kind "AGENT" :since t0) agent-time--panes)
      (agent-time-test--typing nil
        (setq agent-time--keys (cons buf (cons t0 (+ t0 200))))
        (agent-time--you-tick (+ t0 210))
        (agent-time--you-tick (+ t0 220)))
      (let ((st (gethash "p1" agent-time--panes)))
        (should (equal (plist-get st :pending) (list (list "YOU" t0 (+ t0 220)))))
        ;; Your time doesn't count toward the agent's own task.
        (cl-letf (((symbol-function 'float-time) (lambda (&rest _) (+ t0 30))))
          (should (= (agent-time--pending-secs st) 30)))))))

;;; agent-time-test.el ends here
