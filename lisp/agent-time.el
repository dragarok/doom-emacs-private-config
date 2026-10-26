;;; agent-time.el --- Your time, your agents' time, passive time -*- lexical-binding: t -*-

;;; Commentary:
;; Org has one clock, and it stays yours: what you are doing.  Two more
;; kinds of time are kept beside it, in a :RUNS: drawer on the task, in
;; lines Org's clocktable never reads (so totals stay honest):
;;
;;   AGENT:   [start]--[end] =>  0:52  wZ:p1   an agent working on the task
;;   WAIT:    [start]--[end] =>  0:05  wZ:p1   the agent blocked, waiting on you
;;   PASSIVE: [start]--[end] =>  1:00          music, cleaning, a podcast
;;
;; An open line ([start] alone) is time still running; it survives a restart.
;;
;; Agents.  Each Herdr poll is compared with what is recorded: an agent that
;; starts working opens an AGENT line on its task, blocked switches it to
;; WAIT, idle or done closes it.  The task is the one you gave it
;; (`agent-time-assign', SPC j o), else the one the agent named through the
;; MCP layer (mcp/agent-tasks.mjs: task_start / task_finish), else one made
;; in tasks.org once it has worked `agent-time-quick-secs', titled from the
;; agent's terminal title until the agent names it.  Shorter unassigned runs
;; (a quick question) go under "Agent quick asks".  On task_finish the agent
;; retitles its own task with what was done, notes a summary, marks it DONE.
;;
;; States follow the work, so nothing needs closing by hand.  A TODO an
;; agent starts working on becomes NEXT.  An agent's own task (tagged
;; :agent:) with no run for `agent-time-close-after' is closed DONE, with a
;; note saying so -- agents forget task_finish, and sessions stay open for
;; days; later work in the same session gets a task of its own.  Your
;; task that an agent moved to NEXT goes back to TODO instead.  A second
;; task_start closes the agent's previous task the same way.
;;
;; You.  While an agent's pane is in the selected window (the Herdr TUI or
;; an attach buffer) and you have been active in the last
;; `agent-time-active-secs', the org clock runs on that agent's task -- after
;; `agent-time-dwell' seconds, so a glance doesn't count.  Leaving the agent
;; (or going idle) clocks out, and the task you were clocked into before
;; resumes.  Clocking in or out yourself always wins.
;;
;; Passive.  `agent-time-passive' (SPC o v a) toggles activities kept under
;; "Passive" in tasks.org; any number can run at once, none touch the clock.
;;
;; The reviews read all three (org-summary.el: `org-summary-runs', the
;; time-kinds block; day-log.el's facts).

;;; Code:

(require 'org)
(require 'org-clock)
(require 'org-id)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)

(defvar org-tasks-file)                 ; config.el
(defvar herdr--attached-pane)
(defvar doom-cache-dir)
(declare-function herdr--snapshot-sync "herdr")
(declare-function project-root "project")

(defgroup agent-time nil
  "Agent, attention and passive time in org."
  :group 'org-clock)

(defcustom agent-time-active-secs 180
  "You count as with an agent while idle less than this many seconds."
  :type 'integer)

(defcustom agent-time-dwell 30
  "Seconds with (or away from) an agent before the clock follows."
  :type 'integer)

(defcustom agent-time-quick-secs 120
  "Unassigned agent work longer than this gets a task of its own."
  :type 'integer)

(defcustom agent-time-close-after (* 6 3600)
  "Seconds without an agent run before its task is closed (or put back)."
  :type 'integer)

(defconst agent-time--quick-heading "Agent quick asks")
(defconst agent-time--passive-heading "Passive")

(defun agent-time--file () org-tasks-file)

(defun agent-time--state-file ()
  (expand-file-name "agent-time.eld" (if (boundp 'doom-cache-dir) doom-cache-dir
                                       user-emacs-directory)))

;;;; Lines in the :RUNS: drawer

(defun agent-time--ts (time)
  (format-time-string "[%Y-%m-%d %a %H:%M]" time))

(defun agent-time--hm (secs)
  (org-duration-from-minutes (/ (max 0 secs) 60.0) 'h:mm))

(defun agent-time--closed-line (kind start end &optional who)
  (format "%s: %s--%s => %5s%s" kind (agent-time--ts start) (agent-time--ts end)
          (agent-time--hm (- end start)) (if who (concat "  " who) "")))

(defun agent-time--open-line (kind start &optional who)
  (format "%s: %s%s" kind (agent-time--ts start) (if who (concat "  " who) "")))

(defun agent-time--goto-drawer-end ()
  "In the entry at point, move to the :END: of its :RUNS: drawer, made if need be."
  (org-back-to-heading t)
  (let ((end (save-excursion (outline-next-heading) (point))))
    (unless (re-search-forward "^[ \t]*:RUNS:[ \t]*$" end t)
      (org-end-of-meta-data t)
      (unless (bolp) (insert "\n"))
      (insert ":RUNS:\n:END:\n")
      (forward-line -2))
    (re-search-forward "^[ \t]*:END:[ \t]*$")
    (beginning-of-line)))

(defun agent-time--save-buffer ()
  (let ((save-silently t) (inhibit-message t))
    (when (buffer-modified-p) (save-buffer))))

(defmacro agent-time--at (marker &rest body)
  "Run BODY at MARKER's entry, widened, then save its buffer."
  (declare (indent 1))
  `(with-current-buffer (marker-buffer ,marker)
     (prog1 (org-with-wide-buffer (goto-char ,marker) ,@body)
       (agent-time--save-buffer))))

(defun agent-time--append (marker line)
  (agent-time--at marker
    (agent-time--goto-drawer-end)
    (insert line "\n")))

(defun agent-time--close (marker kind start end &optional who)
  "Close MARKER's open KIND line begun at START, at END.  Non-nil if found."
  (agent-time--at marker
    (org-back-to-heading t)
    (let ((limit (save-excursion (outline-next-heading) (point))))
      (when (re-search-forward (concat "^[ \t]*" (regexp-quote (agent-time--open-line kind start))
                                       "\\(?:  .*\\)?$")
                               limit t)
        (replace-match (agent-time--closed-line kind start end who) t t)
        (org-indent-line)
        t))))

;;;; Tasks

(defun agent-time--marker (id)
  (and id (ignore-errors (org-id-find id 'marker))))

(defun agent-time--title-at (marker)
  (agent-time--at marker (substring-no-properties (org-get-heading t t t t))))

(defun agent-time--tasks-buffer ()
  (find-file-noselect (agent-time--file)))

(defun agent-time--create-task (title project)
  "A TODO named TITLE for an agent in PROJECT, at the end of tasks.org,
scheduled today (every task has a date: org-flow.el); its ID."
  (with-current-buffer (agent-time--tasks-buffer)
    (prog1 (org-with-wide-buffer
            (goto-char (point-max))
            (unless (bolp) (insert "\n"))
            (insert "* TODO " title "\n")
            (forward-line -1)
            (org-set-tags '("agent"))
            (org-schedule nil (format-time-string "%Y-%m-%d"))
            (when project (org-entry-put nil "AGENT_PROJECT" project))
            (org-entry-put nil "CREATED" (agent-time--ts nil))
            (org-id-get-create))
      (agent-time--save-buffer))))

(defun agent-time--heading (title &optional tag)
  "Marker of the top-level heading TITLE in tasks.org, made if missing."
  (with-current-buffer (agent-time--tasks-buffer)
    (prog1 (org-with-wide-buffer
            (goto-char (point-min))
            (if (re-search-forward (concat "^\\* " (regexp-quote title)
                                           "\\(?:[ \t]+:[[:alnum:]_@#%:]+:\\)?[ \t]*$")
                                   nil t)
                (progn (beginning-of-line) (point-marker))
              (goto-char (point-max))
              (unless (bolp) (insert "\n"))
              (insert "* " title "\n")
              (forward-line -1)
              (when tag (org-set-tags (list tag)))
              (point-marker)))
      (agent-time--save-buffer))))

(defun agent-time--note (marker text)
  "Add TEXT to MARKER's logbook as a note."
  (agent-time--at marker
    (goto-char (org-log-beginning t))
    (let ((beg (point)))
      (insert (format "- Note taken on %s \\\\\n  %s\n" (agent-time--ts nil)
                      (replace-regexp-in-string "\n" "\n  " (string-trim text))))
      (indent-region beg (point)))))

(defvar agent-time--focus nil "(PANE . SINCE): the agent in view, and since when.")
(defvar agent-time--away nil "When you left the agent the clock is on.")
(defvar agent-time--auto nil "Non-nil while the clock runs because of an agent.")
(defvar agent-time--resume nil "The task you were clocked into before, to go back to.")
(defvar agent-time--held nil "A pane you clocked away from yourself: leave it be.")
(defvar agent-time--self nil "Bound while this file moves the clock.")

;;;; Agents

;; One plist per Herdr pane:
;;   :task ID  :how user|agent|auto  :release t (finished; let go when idle)
;;   :kind "AGENT"/"WAIT"/nil and :since, the segment running now
;;   :pending ((KIND START END) ...) segments with no task yet
;;   :project, :title  from the agent's directory and terminal title
(defvar agent-time--panes (make-hash-table :test #'equal))
(defvar agent-time--saved-at nil
  "When the state was last saved, read back at startup: the latest a
segment left open by a stopped Emacs can be said to have run.")

(defvar agent-time--last-save 0)

(defun agent-time--save-state ()
  (setq agent-time--last-save (float-time))
  (let ((alist nil))
    (maphash (lambda (k v) (push (cons k v) alist)) agent-time--panes)
    (ignore-errors
      (with-temp-file (agent-time--state-file)
        (prin1 (list :saved (float-time) :panes alist) (current-buffer))))))

(defun agent-time--load-state ()
  (when-let* ((file (agent-time--state-file))
              (data (and (file-readable-p file)
                         (ignore-errors (with-temp-buffer (insert-file-contents file)
                                                          (read (current-buffer)))))))
    (setq agent-time--saved-at (plist-get data :saved))
    (dolist (p (plist-get data :panes))
      (puthash (car p) (cdr p) agent-time--panes))))

(defmacro agent-time--put (st &rest kvs)
  "Set KVS on the pane plist ST in place."
  `(setq ,st (thread-first ,st ,@(cl-loop for (k v) on kvs by #'cddr
                                         collect `(plist-put ,k ,v)))))

;;;; States

(defun agent-time--working (marker)
  "An agent works on MARKER's task: TODO becomes NEXT, remembered as the
agent's doing so it can be put back."
  (agent-time--at marker
    (when (equal (org-get-todo-state) "TODO")
      (org-todo "NEXT")
      (org-entry-put nil "AGENT_NEXT" "t"))))

(defun agent-time--done (marker &optional title note)
  "Mark MARKER's task DONE, retitled TITLE if given, with NOTE if given."
  ;; DONE clocks out a clock on it; that isn't you stopping by hand.
  (let ((agent-time--self t))
    (agent-time--at marker
      (when title (org-edit-headline title))
      (org-todo "DONE")
      ;; Its "State DONE" line waits for the end of a command, which an
      ;; emacsclient call or a timer never has: write it now.
      (when (memq 'org-add-log-note post-command-hook) (org-add-log-note))))
  (when note (agent-time--note marker note)))

(defun agent-time--last-run ()
  "The entry at point's latest run end in seconds, t while one runs, else
its CREATED time; nil if it has none of these."
  (save-excursion
    (org-back-to-heading t)
    (let ((limit (save-excursion (outline-next-heading) (point))) last)
      (while (and (not (eq last t))
                  (re-search-forward "^[ \t]*\\(?:AGENT\\|WAIT\\): \\[[^]]+\\]\\(?:--\\[\\([^]]+\\)\\]\\)?"
                                     limit t))
        (setq last (if (match-beginning 1)
                       (max (or last 0) (org-time-string-to-seconds (match-string 1)))
                     t)))
      (or last
          (when-let* ((created (org-entry-get nil "CREATED")))
            (org-time-string-to-seconds created))))))

(defun agent-time-close-quiet ()
  "Close agents' own tasks quiet for `agent-time-close-after'; put back to
TODO your tasks an agent moved to NEXT.  Runs by itself now and then."
  (interactive)
  (let ((now (float-time)) closed)
    (with-current-buffer (agent-time--tasks-buffer)
      (org-with-wide-buffer
       (goto-char (point-min))
       (while (re-search-forward org-heading-regexp nil t)
         (when-let* (((member (org-get-todo-state) '("TODO" "NEXT")))
                     (whose (if (member "agent" (org-get-tags nil t)) 'agent 'yours))
                     ((or (eq whose 'agent) (org-entry-get nil "AGENT_NEXT")))
                     (last (agent-time--last-run))
                     ((numberp last))
                     ((> (- now last) agent-time-close-after)))
           (let ((m (point-marker)))
             (if (eq whose 'agent)
                 (progn
                   (agent-time--done m nil (format "Closed by itself: no agent work since %s."
                                                   (agent-time--ts last)))
                   (push (org-id-get) closed))
               (agent-time--at m
                 (org-todo "TODO")
                 (org-entry-delete nil "AGENT_NEXT"))))))))
    ;; The agents on them -- or on one you closed yourself -- start a new
    ;; task with their next work.
    (maphash (lambda (pane st)
               (when (and (not (eq (plist-get st :how) 'user))
                          (or (member (plist-get st :task) closed)
                              (when-let* ((m (agent-time--marker (plist-get st :task))))
                                (agent-time--at m (org-entry-is-done-p)))))
                 (puthash pane (agent-time--put st :task nil :how nil :release nil)
                          agent-time--panes)))
             agent-time--panes)
    (when (called-interactively-p 'any)
      (message "%d agent task%s closed" (length closed) (if (= (length closed) 1) "" "s")))
    closed))

(defun agent-time--project (cwd)
  (when (and cwd (file-directory-p cwd))
    (file-name-nondirectory
     (directory-file-name (if-let* ((p (project-current nil cwd))) (project-root p) cwd)))))

(defun agent-time--auto-title (st)
  (let ((title (plist-get st :title)))
    (if (and title (not (string-match-p "\\`\\(?:Claude Code\\|claude\\|codex\\)?\\'" title)))
        title
      (format "Agent work in %s" (or (plist-get st :project) "?")))))

(defun agent-time--begin (pane st kind now)
  "Start a KIND segment for ST at NOW; the new ST."
  (let ((m (agent-time--marker (plist-get st :task))))
    (when m
      (agent-time--append m (agent-time--open-line kind now pane))
      (when (equal kind "AGENT") (agent-time--working m)))
    (agent-time--put st :kind kind :since now)))

(defun agent-time--end (pane st now)
  "End ST's running segment at NOW; the new ST."
  (when-let* ((kind (plist-get st :kind)))
    (let ((since (plist-get st :since))
          (m (agent-time--marker (plist-get st :task))))
      (if m
          (agent-time--close m kind since now pane)
        (agent-time--put st :pending (append (plist-get st :pending)
                                             (list (list kind since now)))))))
  (agent-time--put st :kind nil :since nil))

(defun agent-time--adopt (pane st id how)
  "Record ST's work from now on to task ID; write what was pending there.
The new ST."
  (let ((m (agent-time--marker id))
        (kind (plist-get st :kind)) (since (plist-get st :since)))
    ;; The running segment moves: close it where it was, reopen it here.
    (when kind
      (when-let* ((old (agent-time--marker (plist-get st :task))))
        (agent-time--close old kind since (float-time) pane)
        (setq since (float-time))))
    (dolist (seg (plist-get st :pending))
      (agent-time--append m (apply #'agent-time--closed-line (append seg (list pane)))))
    (when kind (agent-time--append m (agent-time--open-line kind since pane)))
    (when (equal kind "AGENT") (agent-time--working m))
    (agent-time--put st :task id :how how :release nil :pending nil :since since)))

(defun agent-time--pending-secs (st)
  (+ (apply #'+ (mapcar (lambda (s) (- (nth 2 s) (nth 1 s))) (plist-get st :pending)))
     (if (plist-get st :kind) (- (float-time) (plist-get st :since)) 0)))

(defun agent-time--episode-over (pane st)
  "ST's agent went quiet: settle work that never got a task, let go a finished one."
  (when-let* ((pending (plist-get st :pending)))
    (if (>= (agent-time--pending-secs st) agent-time-quick-secs)
        (setq st (agent-time--adopt pane st (agent-time--create-task (agent-time--auto-title st)
                                                                      (plist-get st :project))
                                    'auto))
      (let ((m (agent-time--heading agent-time--quick-heading "agent"))
            (who (format "%s %s" pane (or (plist-get st :project) ""))))
        (dolist (seg pending)
          (agent-time--append m (apply #'agent-time--closed-line (append seg (list who))))))
      (agent-time--put st :pending nil)))
  (when (plist-get st :release)
    (agent-time--put st :task nil :how nil :release nil))
  st)

(defun agent-time--sync (agents)
  "Bring the recorded runs in line with AGENTS, a fresh Herdr poll."
  (let ((now (float-time))
        ;; Just started: whatever changed did so while Emacs was down.
        (was (or (prog1 agent-time--saved-at (setq agent-time--saved-at nil)) (float-time)))
        (seen nil) (changed nil))
    (dolist (a agents)
      (let* ((pane (alist-get 'pane-id a))
             (st (gethash pane agent-time--panes))
             (want (pcase (alist-get 'status a) ("working" "AGENT") ("blocked" "WAIT")))
             (title (alist-get 'session a)))
        (push pane seen)
        (unless (equal title (plist-get st :title))
          (agent-time--put st :title title :project (agent-time--project (alist-get 'cwd a)))
          (setq changed t)
          ;; Its own title follows the conversation until the agent names it.
          (when-let* (((eq (plist-get st :how) 'auto))
                      (m (agent-time--marker (plist-get st :task))))
            (agent-time--at m (org-edit-headline (agent-time--auto-title st)))))
        (unless (equal want (plist-get st :kind))
          (setq changed t)
          (setq st (agent-time--end pane st (min now (max was (or (plist-get st :since) 0)))))
          (setq st (if want
                       (agent-time--begin pane st want now)
                     (agent-time--episode-over pane st))))
        (when (and (plist-get st :kind) (null (plist-get st :task))
                   (>= (agent-time--pending-secs st) agent-time-quick-secs))
          (setq changed t
                st (agent-time--adopt pane st (agent-time--create-task (agent-time--auto-title st)
                                                                        (plist-get st :project))
                                      'auto)))
        (puthash pane st agent-time--panes)))
    (when agents
      (maphash (lambda (pane st)
                 (unless (or (member pane seen) (string-prefix-p "cwd:" pane))
                   (agent-time--episode-over pane (agent-time--end pane st now))
                   (remhash pane agent-time--panes)
                   (setq changed t)))
               agent-time--panes))
    ;; Now and then regardless, so a restart knows how late a run went on.
    (when (or changed (> now (+ agent-time--last-save 60)))
      (agent-time--save-state))))

(defun agent-time--on-poll (_old new)
  (condition-case err
      (agent-time--sync new)
    (error (message "agent-time: %s" (error-message-string err)))))

;;;###autoload
(defun agent-time-assign (task-id &optional pane)
  "Record the focused agent's work (or PANE's) to TASK-ID, picked from the agenda."
  (interactive (list (agent-time--read-task) nil))
  (let* ((pane (or pane (agent-time--viewed-pane) (user-error "No agent in view")))
         (st (gethash pane agent-time--panes)))
    (puthash pane (agent-time--adopt pane st task-id 'user) agent-time--panes)
    (agent-time--save-state)
    (message "Agent %s → %s" pane (agent-time--title-at (agent-time--marker task-id)))))

(defun agent-time--read-task ()
  "An open task's ID, chosen from the agenda files (made if it has none)."
  (let ((cands nil))
    (dolist (file (org-agenda-files t))
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (goto-char (point-min))
         (while (re-search-forward org-heading-regexp nil t)
           (when (member (org-get-todo-state) org-not-done-keywords)
             (push (cons (format "%-8s %s  (%s)" (org-get-todo-state)
                                 (substring-no-properties (org-get-heading t t t t))
                                 (file-name-base file))
                         (point-marker))
                   cands))))))
    (let ((m (cdr (assoc (completing-read "Agent works on: " (nreverse cands) nil t) cands))))
      (agent-time--at m (org-id-get-create)))))

;;;; The MCP layer's verbs (mcp/agent-tasks.mjs calls these by emacsclient)

(defun agent-time--mcp-start (pane cwd title)
  (let* ((st (or (gethash pane agent-time--panes)
                 (list :project (agent-time--project cwd))))
         (m (agent-time--marker (plist-get st :task))))
    (pcase (and m (not (plist-get st :release)) (plist-get st :how))
      ('user (format "The user assigned this agent to \"%s\"; your working time is recorded there. Don't rename it."
                     (agent-time--title-at m)))
      ('agent (agent-time--done m nil "Closed by itself: the agent started other work.")
              (agent-time--put st :task nil :how nil)
              (agent-time--mcp-start-new pane st cwd title))
      ('auto (agent-time--at m (org-edit-headline title))
             (agent-time--put st :how 'agent)
             (puthash pane st agent-time--panes)
             (format "Task \"%s\" started; your working time is recorded to it." title))
      (_ (agent-time--mcp-start-new pane st cwd title)))))

(defun agent-time--mcp-start-new (pane st cwd title)
  (let ((id (agent-time--create-task title (or (plist-get st :project)
                                               (agent-time--project cwd)))))
    (puthash pane (agent-time--adopt pane st id 'agent) agent-time--panes)
    (format "Task \"%s\" created and started; your working time is recorded to it." title)))

(defun agent-time--mcp-finish (pane title summary)
  (let* ((st (gethash pane agent-time--panes))
         (m (agent-time--marker (plist-get st :task))))
    (cond
     ((null m) "No task is open for this agent; call task_start first next time.")
     ((eq (plist-get st :how) 'user)
      (agent-time--note m summary)
      (format "Summary noted on \"%s\" (the user's task; left open)." (agent-time--title-at m)))
     (t
      (agent-time--done m title summary)
      (agent-time--put st :release t)
      (puthash pane st agent-time--panes)
      (format "Task \"%s\" is DONE with your summary." title)))))

;;;###autoload
(defun agent-time-mcp (request)
  "Answer REQUEST, a JSON object from the MCP layer, as base64 JSON."
  (let* ((req (json-parse-string request :object-type 'alist))
         (pane (or (alist-get 'pane req) (concat "cwd:" (alist-get 'cwd req))))
         (text (condition-case err
                   (prog1 (pcase (alist-get 'verb req)
                            ("start" (agent-time--mcp-start pane (alist-get 'cwd req)
                                                            (alist-get 'title req)))
                            ("finish" (agent-time--mcp-finish pane (alist-get 'title req)
                                                              (alist-get 'summary req)))
                            (v (error "Unknown verb %s" v)))
                     (agent-time--save-state))
                 (error (concat "Error: " (error-message-string err))))))
    (base64-encode-string (encode-coding-string (json-encode `((text . ,text))) 'utf-8) t)))

;;;; You: the clock follows the agent you are with

(defun agent-time--viewed-pane ()
  "The agent pane in the selected window, if any."
  (let ((buf (window-buffer (selected-window))))
    (or (buffer-local-value 'herdr--attached-pane buf)
        (and (string-prefix-p "*herdr" (buffer-name buf))
             (fboundp 'herdr--snapshot-sync)
             (let* ((snap (alist-get 'snapshot (alist-get 'result (herdr--snapshot-sync))))
                    (pane (alist-get 'focused_pane_id snap)))
               (and (seq-find (lambda (a) (equal (alist-get 'pane_id a) pane))
                              (alist-get 'agents snap))
                    pane))))))

(defun agent-time--idle ()
  (if-let* ((i (current-idle-time))) (float-time i) 0))

(defun agent-time--clocked-id ()
  (and (org-clocking-p) (org-with-point-at org-clock-marker (org-id-get))))

(defun agent-time--save-clock-buffers (&rest bufs)
  "Save BUFS and the clock's buffer, whose clocks this file just moved,
so the phone sees them."
  (dolist (buf (cons (marker-buffer org-clock-marker) bufs))
    (when (buffer-live-p buf)
      (with-current-buffer buf (agent-time--save-buffer)))))

(defun agent-time--clock-in (marker start)
  (let ((agent-time--self t)
        (org-clock-auto-clock-resolution nil))
    (when (org-clocking-p)
      (unless agent-time--auto
        (setq agent-time--resume (copy-marker org-clock-marker)))
      (org-clock-out nil t (seconds-to-time (max start (float-time org-clock-start-time)))))
    (org-with-point-at marker (org-clock-in nil (seconds-to-time start)))
    (agent-time--save-clock-buffers (and agent-time--resume (marker-buffer agent-time--resume)))
    (setq agent-time--auto t)))

(defun agent-time--clock-out (at)
  ;; Gone idle before the dwell even ended: no 0:00 line.
  (let ((agent-time--self t)
        (org-clock-out-remove-zero-time-clocks t))
    (when (org-clocking-p)
      (let ((buf (marker-buffer org-clock-marker)))
        (org-clock-out nil t (seconds-to-time (max at (float-time org-clock-start-time))))
        (agent-time--save-clock-buffers buf)))
    (setq agent-time--auto nil)))

(defun agent-time--resume-now (at)
  (when-let* ((m agent-time--resume))
    (setq agent-time--resume nil)
    (when (and (marker-buffer m) (not (org-clocking-p)))
      (let ((agent-time--self t)
            (org-clock-auto-clock-resolution nil))
        (org-with-point-at m (org-clock-in nil (seconds-to-time at)))
        (agent-time--save-clock-buffers)))))

(defvar agent-time--last-sweep 0)

(defun agent-time--tick ()
  (condition-case err
      (let* ((now (float-time))
             (idle (agent-time--idle))
             (active (< idle agent-time-active-secs))
             (pane (and active (agent-time--viewed-pane))))
        (unless (equal pane (car agent-time--focus))
          (setq agent-time--focus (and pane (cons pane now))))
        (unless (equal pane agent-time--held) (setq agent-time--held nil))
        (cond
         ((and pane (not (equal pane agent-time--held)))
          (setq agent-time--away nil)
          (when-let* (((>= (- now (cdr agent-time--focus)) agent-time-dwell))
                      (st (gethash pane agent-time--panes))
                      ((not (plist-get st :release)))
                      (id (plist-get st :task))
                      ((not (equal id (agent-time--clocked-id))))
                      (m (agent-time--marker id)))
            (agent-time--clock-in m (cdr agent-time--focus))))
         (agent-time--auto
          (unless agent-time--away
            (setq agent-time--away (if active now (- now idle))))
          (when (or (not active) (>= (- now agent-time--away) agent-time-dwell))
            (agent-time--clock-out agent-time--away)
            (when active (agent-time--resume-now agent-time--away))
            (setq agent-time--away nil)))
         ((and active agent-time--resume)
          (agent-time--resume-now now)))
        (when (> now (+ agent-time--last-sweep 600))
          (setq agent-time--last-sweep now)
          (agent-time-close-quiet)))
    (error (message "agent-time: %s" (error-message-string err)))))

(defun agent-time--by-hand ()
  "You moved the clock yourself: stop following agents until you look away."
  (unless agent-time--self
    (setq agent-time--auto nil agent-time--resume nil agent-time--away nil
          agent-time--held (car agent-time--focus))))

;;;; Passive time

(defun agent-time--passive-items ()
  "(LABEL MARKER OPEN-START) for each activity under Passive."
  (let ((root (agent-time--heading agent-time--passive-heading "passive")) out)
    (with-current-buffer (marker-buffer root)
      (org-with-wide-buffer
       (goto-char root)
       (let ((level (1+ (org-current-level))))
         (org-map-entries
          (lambda ()
            (when (= (org-current-level) level)
              (let* ((title (substring-no-properties (org-get-heading t t t t)))
                     (end (save-excursion (outline-next-heading) (point)))
                     (open (save-excursion
                             (and (re-search-forward "^[ \t]*PASSIVE: \\(\\[[^]]+\\]\\)[ \t]*$" end t)
                                  (float-time (org-time-string-to-time (match-string 1)))))))
                (push (list title (point-marker) open) out))))
          nil 'tree))))
    (nreverse out)))

;;;###autoload
(defun agent-time-passive ()
  "Start or stop a passive activity (music, cleaning...); several can run."
  (interactive)
  (let* ((items (agent-time--passive-items))
         (label (lambda (it) (if (nth 2 it)
                                 (format "● %s  %s" (car it)
                                         (agent-time--hm (- (float-time) (nth 2 it))))
                               (format "  %s" (car it)))))
         (cands (mapcar (lambda (it) (cons (funcall label it) it)) items))
         (pick (completing-read "Passive (● running; new name adds one): "
                                (mapcar #'car cands)))
         (it (or (cdr (assoc pick cands))
                 (seq-find (lambda (it) (equal (car it) (string-trim pick))) items))))
    (cond
     ((and it (nth 2 it))
      (agent-time--close (nth 1 it) "PASSIVE" (nth 2 it) (float-time))
      (message "Passive: %s stopped (%s)" (car it) (agent-time--hm (- (float-time) (nth 2 it)))))
     (it
      (agent-time--append (nth 1 it) (agent-time--open-line "PASSIVE" (float-time)))
      (message "Passive: %s started" (car it)))
     ((string-empty-p (string-trim pick)) nil)
     (t
      (let ((root (agent-time--heading agent-time--passive-heading "passive")))
        (agent-time--at root
          (org-end-of-subtree t t)
          (unless (bolp) (insert "\n"))
          (insert "** " (string-trim pick) "\n")
          (forward-line -1)
          (agent-time--goto-drawer-end)
          (insert (agent-time--open-line "PASSIVE" (float-time)) "\n")))
      (message "Passive: %s added and started" (string-trim pick))))))

;;;; On

(defvar agent-time--timer nil)

;;;###autoload
(define-minor-mode agent-time-mode
  "Record agents' time from Herdr and clock yours to the agent you are with."
  :global t
  (if agent-time-mode
      (progn
        (when (zerop (hash-table-count agent-time--panes)) (agent-time--load-state))
        (advice-add 'herdr--notify-status-changes :after #'agent-time--on-poll)
        (add-hook 'org-clock-in-hook #'agent-time--by-hand)
        (add-hook 'org-clock-out-hook #'agent-time--by-hand)
        (add-hook 'kill-emacs-hook #'agent-time--save-state)
        (setq agent-time--timer (run-with-timer 10 10 #'agent-time--tick)))
    (advice-remove 'herdr--notify-status-changes #'agent-time--on-poll)
    (remove-hook 'org-clock-in-hook #'agent-time--by-hand)
    (remove-hook 'org-clock-out-hook #'agent-time--by-hand)
    (when agent-time--timer (cancel-timer agent-time--timer) (setq agent-time--timer nil))
    (agent-time--save-state)))

(provide 'agent-time)
;;; agent-time.el ends here
