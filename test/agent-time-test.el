;;; agent-time-test.el --- States follow agents' work -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/agent-time-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'agent-time)

(defvar org-tasks-file)

(defmacro agent-time-test--with (text &rest body)
  "BODY with tasks.org holding TEXT in a temporary agenda, and no pane state."
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
     (with-temp-file org-tasks-file (insert ,text))
     (unwind-protect (progn ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(defun agent-time-test--text ()
  (with-current-buffer (find-file-noselect org-tasks-file)
    (save-buffer)
    (buffer-substring-no-properties (point-min) (point-max))))

(defun agent-time-test--ts (hours-ago)
  (agent-time--ts (- (float-time) (* hours-ago 3600))))

(defun agent-time-test--entry (title)
  "TITLE's entry text, heading to the next heading."
  (let ((text (agent-time-test--text)))
    (string-match (concat "^\\*.* " (regexp-quote title) "[^\n]*\n\\(?:[^*].*\n\\|\n\\)*") text)
    (match-string 0 text)))

(ert-deftest agent-time-test-next-while-working ()
  "An agent starting work moves TODO to NEXT; waiting doesn't, nor does
work on a task in another state."
  (agent-time-test--with "* TODO Fix sink\n:PROPERTIES:\n:ID: a\n:END:\n* TODO Read\n:PROPERTIES:\n:ID: b\n:END:\n"
    (agent-time--begin "p1" (list :task "b") "WAIT" (float-time))
    (should (string-match-p "^\\* TODO Read" (agent-time-test--text)))
    (agent-time--begin "p1" (list :task "a") "AGENT" (float-time))
    (should (string-match-p "^\\* NEXT Fix sink" (agent-time-test--text)))
    (should (string-match-p ":AGENT_NEXT: t" (agent-time-test--entry "Fix sink")))
    (agent-time--begin "p1" (list :task "a") "AGENT" (float-time))
    (should (string-match-p "^\\* NEXT Fix sink" (agent-time-test--text)))))

(ert-deftest agent-time-test-close-quiet ()
  "An agent's task quiet past `agent-time-close-after' is DONE with a note;
one running or recently worked on is left; yours goes back to TODO only if
an agent put it in NEXT; the pane on a closed task lets it go."
  (agent-time-test--with
      (concat "* NEXT Old research :agent:\n:PROPERTIES:\n:ID: old\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p1\n:END:\n"
              "* NEXT Running :agent:\n:PROPERTIES:\n:ID: run\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p2\n"
              "WAIT: " (agent-time-test--ts 7) "  p2\n:END:\n"
              "* TODO Recent :agent:\n:PROPERTIES:\n:ID: recent\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 11) "--" (agent-time-test--ts 10) " =>  1:00  p3\n:END:\n"
              "* TODO Never ran :agent:\n:PROPERTIES:\n:ID: never\n:CREATED: " (agent-time-test--ts 40) "\n:END:\n"
              "* NEXT Yours, by an agent\n:PROPERTIES:\n:ID: yours\n:AGENT_NEXT: t\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p4\n:END:\n"
              "* NEXT Yours, by you\n:PROPERTIES:\n:ID: you\n:END:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p5\n:END:\n"
              "* Agent quick asks :agent:\n:RUNS:\n"
              "AGENT: " (agent-time-test--ts 31) "--" (agent-time-test--ts 30) " =>  1:00  p6\n:END:\n")
    (puthash "p1" (list :task "old" :how 'auto) agent-time--panes)
    (puthash "p4" (list :task "yours" :how 'user) agent-time--panes)
    (with-current-buffer (find-file-noselect org-tasks-file)
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
      (should (string-match-p "^\\* TODO Yours, by an agent" text))
      (should (string-match-p "^\\* NEXT Yours, by you" text))
      (should (string-match-p "^\\* Agent quick asks" text)))
    (should (string-match-p "CLOSED: \\[" (agent-time-test--entry "Old research")))
    (should (string-match-p "Closed by itself: no agent work since" (agent-time-test--entry "Old research")))
    (should-not (string-match-p "AGENT_NEXT" (agent-time-test--entry "Yours, by an agent")))
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

;;; agent-time-test.el ends here
