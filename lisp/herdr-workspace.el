;;; herdr-workspace.el --- Herdr agents in their own Doom workspace -*- lexical-binding: t; -*-

;;; Commentary:
;; claude-workspace's shape, with Herdr (herdr.dev) owning the agents.
;;
;; The agents live in the Herdr server, not in Emacs, so they survive an
;; Emacs restart and are the same ones the terminal's `herdr' client shows.
;; Emacs gets one Doom workspace, "herdr", holding the Herdr TUI full-frame
;; (emacs-herdr runs it in a ghostel buffer), plus the claude-workspace verbs
;; around it:
;;
;;   open      SPC j j   switch to the herdr workspace (start the TUI if needed)
;;   expand    SPC j e   focused agent → its project's own Doom workspace
;;   collapse  SPC j m   back to the herdr workspace
;;   magit/dired, ESC and clipboard paste aimed at the focused agent
;;
;; "The focused agent" is the one Herdr has focused, or the agent of the
;; attach buffer you are in (`herdr-attach-agent').  Status, the ● N blocked
;; count and notifications come from `herdr-mode'; this adds the same chime
;; the Claude grid plays.

;;; Code:

(require 'herdr)
(require 'subr-x)

(declare-function +workspace-switch "ext:workspaces" (name &optional auto-create-p))
(declare-function +workspace-current-name "ext:workspaces" ())
(declare-function +workspace-exists-p "ext:workspaces" (name))
(declare-function claude-workspace--open-project-entry "claude-workspace" (root))
(declare-function claude-workspace--chime "claude-workspace" ())
(declare-function magit-status-setup-buffer "magit-status" (&optional directory))
(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-normalize-keymaps "evil-core" (&optional state))
(declare-function evil-insert-state "evil-states" (&optional arg))
(defvar evil-ghostel--escape-mode)

(defgroup herdr-workspace nil
  "Herdr agents in their own Doom workspace."
  :group 'herdr)

(defcustom herdr-workspace-name "herdr"
  "Name of the Doom workspace that holds the Herdr TUI."
  :type 'string)

(defcustom herdr-workspace-chime t
  "Play the Claude grid's chime when an agent blocks or finishes."
  :type 'boolean)


;;;; Not inside a pane

;; A daemon (re)started from a shell inside a Herdr pane inherits that
;; pane's HERDR_* variables, and then every `herdr' it runs refuses as
;; nested ("nested herdr is disabled") and every agent it starts claims
;; the old pane.  Emacs is never itself in a pane: drop them.
(dolist (var '("HERDR_ENV" "HERDR_PANE_ID" "HERDR_TAB_ID" "HERDR_WORKSPACE_ID"))
  (setenv var nil))


;;;; Workspace

(defun herdr-workspace--in-workspace-p ()
  "Non-nil if the current Doom workspace is the herdr one."
  (and (fboundp '+workspace-current-name)
       (equal (+workspace-current-name) herdr-workspace-name)))

(defun herdr-workspace--ensure ()
  "Switch to the herdr workspace, creating it if needed."
  (require 'persp-mode nil t)
  (unless (herdr-workspace--in-workspace-p)
    (when (fboundp '+workspace-switch)
      (+workspace-switch herdr-workspace-name t))))

;; One ghostel buffer is one PTY with one size.  The phone reaches this
;; Emacs through claude-remote, in an `emacsclient -t' frame a third the
;; width of the Mac's, and a *herdr* shown in both would reflow the Mac's
;; TUI every time the phone looked.  So a terminal frame gets a Herdr client
;; of its own, sized to it; the Herdr server is fine with clients of
;; different sizes (the terminal's `herdr' is one already).
(defun herdr-workspace--tui-buffer-name ()
  "The TUI buffer for the selected frame: *herdr*, or *herdr:tty* on a tty."
  (if (display-graphic-p) "*herdr*" "*herdr:tty*"))

(defun herdr-workspace--per-frame (orig &rest args)
  "Run ORIG with ARGS on the selected frame's own TUI buffer."
  (let ((herdr--buffer-name (herdr-workspace--tui-buffer-name)))
    (apply orig args)))

;; Opening Herdr is not the only way a frame comes to show it: a new
;; `emacsclient -t' frame restores the herdr workspace's saved layout,
;; which holds the Mac's *herdr*.  So any window showing the other kind of
;; frame's TUI gets this frame's own, started on the spot if need be.
(defun herdr-workspace--swap-foreign-tui (frame)
  "In FRAME, replace a Herdr TUI buffer that belongs to the other frame kind."
  (let* ((own (with-selected-frame frame (herdr-workspace--tui-buffer-name)))
         (foreign (if (equal own "*herdr*") "*herdr:tty*" "*herdr*")))
    (dolist (win (window-list frame 'nomini))
      (when (equal (buffer-name (window-buffer win)) foreign)
        (let ((buf (get-buffer own)))
          (if (and buf (process-live-p (buffer-local-value 'ghostel--process buf)))
              (set-window-buffer win buf)
            (with-selected-frame frame
              (with-selected-window win
                (let ((herdr--buffer-name own))
                  (herdr--create-buffer))))))))))

(add-hook 'window-buffer-change-functions #'herdr-workspace--swap-foreign-tui)

(advice-add 'herdr-hide :around #'herdr-workspace--per-frame)
(advice-add 'herdr-toggle :around #'herdr-workspace--per-frame)

(defun herdr-workspace--around-herdr (orig &rest args)
  "Show *herdr* in the herdr workspace, wherever ORIG (`herdr') was called from.
`herdr-switch-agent', `herdr-goto-blocked', `herdr-new-agent' and a
notification click all end in `herdr'; this sends every one of them to
the workspace, and reuses the TUI's window there instead of stacking it.
A child frame (vertico-posframe's minibuffer, say) is never the target:
the TUI goes to the frame it floats over."
  (when-let* ((parent (frame-parameter nil 'parent-frame)))
    (select-frame-set-input-focus parent))
  (herdr-workspace--ensure)
  (let* ((herdr--buffer-name (herdr-workspace--tui-buffer-name))
         (win (get-buffer-window herdr--buffer-name)))
    (if (and win (herdr--buffer-live-p))
        (progn (select-window win) (herdr--ensure-timer))
      (apply orig args)
      (delete-other-windows))))

(advice-add 'herdr :around #'herdr-workspace--around-herdr)

;;;###autoload
(defun herdr-workspace-open ()
  "Switch to the herdr workspace, starting the Herdr TUI there if needed."
  (interactive)
  (herdr))

;;;###autoload
(defun herdr-workspace-collapse ()
  "Collapse: return to the herdr workspace from a project workspace."
  (interactive)
  (herdr-workspace-open))

(declare-function +workspace/kill "ext:workspaces" (name))
(declare-function +workspace-kill "ext:workspaces" (workspace &optional inhibit-kill-p))

;;;###autoload
(defun herdr-workspace-close ()
  "Close Herdr in Emacs; the agents keep running in the Herdr server.
In an agent's own buffer (`herdr-attach-agent'), close just that buffer.
Otherwise detach the TUI and remove the herdr workspace, landing in the
workspace you were in before.  From a terminal frame (the phone), only
that frame's TUI goes; the workspace stays for the Mac's."
  (interactive)
  (let ((kill-buffer-query-functions nil))
    (if herdr--attached-pane
        (kill-buffer)
      (when-let* ((buf (get-buffer (herdr-workspace--tui-buffer-name))))
        (kill-buffer buf))
      (cond
       ((not (display-graphic-p))
        (when (and (herdr-workspace--in-workspace-p) (fboundp '+workspace/other))
          (+workspace/other)))
       ((and (fboundp '+workspace-exists-p)
             (+workspace-exists-p herdr-workspace-name))
        (if (herdr-workspace--in-workspace-p)
            (+workspace/kill herdr-workspace-name)
          (+workspace-kill herdr-workspace-name))))
      (message "Herdr closed (agents still running; SPC j j to reopen)"))))


;;;; The focused agent

(defun herdr-workspace--focused-agent ()
  "The agent of the current attach buffer, else the one Herdr has focused."
  (let* ((json (herdr--snapshot-sync))
         (agents (herdr--extract-agents json))
         (pane (or herdr--attached-pane
                   (alist-get 'focused_pane_id
                              (alist-get 'snapshot (alist-get 'result json))))))
    (or (seq-find (lambda (a) (equal (alist-get 'pane-id a) pane)) agents)
        (user-error "Herdr has no focused agent"))))

(defun herdr-workspace--agent-root (agent)
  "Project root of AGENT's working directory, else the directory itself."
  (let ((cwd (or (alist-get 'cwd agent) (user-error "Agent has no directory"))))
    (file-name-as-directory
     (expand-file-name
      (if-let* ((proj (project-current nil cwd))) (project-root proj) cwd)))))

;;;###autoload
(defun herdr-workspace-expand-to-project ()
  "Expand: jump from the focused agent to its project's own Doom workspace.
The first time, the project is opened there; collapse back with SPC j m."
  (interactive)
  (let* ((root (herdr-workspace--agent-root (herdr-workspace--focused-agent)))
         (name (file-name-nondirectory (directory-file-name root)))
         (existed (and (fboundp '+workspace-exists-p) (+workspace-exists-p name))))
    (if (fboundp '+workspace-switch)
        (+workspace-switch name t)
      (find-file root))
    (unless existed
      (let ((default-directory root))
        (if (fboundp 'claude-workspace--open-project-entry)
            (claude-workspace--open-project-entry root)
          (dired root))))
    (message "Expanded → %s workspace (collapse back: SPC j m)" name)))

;;;###autoload
(defun herdr-workspace-magit ()
  "Open Magit for the focused agent's project."
  (interactive)
  (require 'magit)
  (magit-status-setup-buffer
   (herdr-workspace--agent-root (herdr-workspace--focused-agent))))

;;;###autoload
(defun herdr-workspace-dired ()
  "Open Dired on the focused agent's project."
  (interactive)
  (dired (herdr-workspace--agent-root (herdr-workspace--focused-agent))))

;;;###autoload
(defun herdr-workspace-send-escape ()
  "Send ESC to the focused agent: interrupt it, or back out of a prompt."
  (interactive)
  (let ((agent (herdr-workspace--focused-agent)))
    (herdr--call-json-sync "agent" "send-keys" (alist-get 'pane-id agent) "esc")
    (message "ESC → %s" (herdr--agent-display-name agent))))

;;;###autoload
(defun herdr-workspace-send-clipboard (&optional submit)
  "Type the clipboard into the focused agent's prompt.
With prefix arg SUBMIT, submit it too."
  (interactive "P")
  (herdr-workspace-send-text (or (current-kill 0 t) "") submit))

(defun herdr-workspace-send-text (text &optional submit)
  "Type TEXT into the focused agent's prompt, submitting it when SUBMIT.
The phone's `SPC j v' lands here with the phone's clipboard (see
`claude-remote--paste-form')."
  (let ((agent (herdr-workspace--focused-agent))
        (text (string-trim-right text)))
    (when (string-empty-p text) (user-error "Nothing to paste"))
    (if submit
        (herdr--call-json-sync "agent" "prompt" (alist-get 'pane-id agent) text)
      (herdr--call-json-sync "pane" "send-text" (alist-get 'pane-id agent) text))
    (message "Pasted %d chars → %s%s" (length text)
             (herdr--agent-display-name agent) (if submit " + RET" ""))))


;;;; Driven from the phone
;;
;; The phone's Prev / Next / Refresh buttons (claude-remote.el) land here.

(defun herdr-workspace-cycle-agent (&optional backward)
  "Focus the next agent, in the sidebar's order; the previous with BACKWARD."
  (interactive "P")
  (let* ((json (herdr--snapshot-sync))
         (agents (or (herdr--extract-agents json) (user-error "Herdr has no agents")))
         (focused (alist-get 'focused_pane_id (alist-get 'snapshot (alist-get 'result json))))
         (i (seq-position agents focused
                          (lambda (a pane) (equal (alist-get 'pane-id a) pane))))
         ;; From a plain shell pane: the first agent, or the last going back.
         (next (nth (mod (if i (+ i (if backward -1 1)) (if backward -1 0)) (length agents))
                    agents)))
    (herdr--call-json-sync "agent" "focus" (alist-get 'target next))
    (message "Herdr → %s" (herdr--agent-display-name next))))

(defun herdr-workspace-redraw ()
  "Start this frame's Herdr view afresh: the fix for a garbled display.
Only the view goes; the agents run on in the server."
  (interactive)
  (let ((kill-buffer-query-functions nil))
    (when-let* ((buf (get-buffer (herdr-workspace--tui-buffer-name))))
      (kill-buffer buf)))
  (herdr-workspace-open))

;;;; Projects, tabs and plain terminals
;;
;; A Herdr workspace ("space" in its sidebar) is a project; its tabs hold
;; agents or plain shells.  These pick by name from Emacs, act through the
;; CLI, then show the TUI.  Closing asks first: it kills what runs there.

(defun herdr-workspace--snapshot ()
  "The live snapshot alist (offers to start the server when it is down)."
  (alist-get 'snapshot (alist-get 'result (herdr--snapshot-sync))))

(defun herdr-workspace--focused-pane (snap)
  "The pane alist SNAP has focused, or nil."
  (let ((id (alist-get 'focused_pane_id snap)))
    (seq-find (lambda (p) (equal (alist-get 'pane_id p) id))
              (alist-get 'panes snap))))

(defun herdr-workspace--read-workspace (prompt snap)
  "Read a Herdr workspace from SNAP with PROMPT, the focused one by default.
Return its alist."
  (let* ((spaces (alist-get 'workspaces snap))
         (cands (mapcar (lambda (w)
                          (cons (format "%s  %s" (alist-get 'label w)
                                        (propertize
                                         (format "%s · %d tab(s)"
                                                 (or (alist-get 'agent_status w) "")
                                                 (or (alist-get 'tab_count w) 0))
                                         'face 'shadow))
                                w))
                        spaces))
         (focused (car (seq-find (lambda (c) (eq (alist-get 'focused (cdr c)) t))
                                 cands))))
    (unless cands (user-error "Herdr has no workspaces"))
    (cdr (assoc (completing-read prompt cands nil t nil nil focused) cands))))

(defun herdr-workspace--read-project ()
  "Read a project root: projectile's known projects, else a directory."
  (let ((cands (and (fboundp 'claude-workspace--project-candidates)
                    (claude-workspace--project-candidates))))
    (file-name-as-directory
     (expand-file-name
      (if cands
          (let ((pick (completing-read "Herdr project: " cands)))
            (or (cdr (assoc pick cands)) pick))
        (read-directory-name "Herdr project: "))))))

(defun herdr-workspace--pane-of (result)
  "Pane id of a `workspace create' / `tab create' RESULT."
  (or (alist-get 'pane_id (alist-get 'root_pane (alist-get 'result result)))
      (user-error "Herdr did not create it")))

(defun herdr-workspace--start-agent (pane root)
  "Start `herdr-default-agent-kind' in PANE, named after project ROOT."
  (let* ((kind herdr-default-agent-kind)
         (name (herdr--unique-agent-name
                (herdr--sanitize-name (concat (herdr--project-name root) "-" kind))
                herdr--agents-cache)))
    (herdr--call-async
     (lambda (result)
       (message "herdr: %s %s" (if result "started" "FAILED to start") name))
     "agent" "start" name "--kind" kind "--pane" pane)))

;;;###autoload
(defun herdr-workspace-add-project (root &optional shell-only)
  "Open project ROOT in Herdr with an agent in it.
A project Herdr already has gets a new tab; otherwise a new workspace.
With prefix arg SHELL-ONLY, a plain shell instead of an agent."
  (interactive (list (herdr-workspace--read-project) current-prefix-arg))
  (let* ((json (herdr--snapshot-sync))
         (ws (herdr--workspace-for-root root json))
         (pane (herdr-workspace--pane-of
                (if ws
                    (herdr--call-json-sync "tab" "create" "--workspace" ws "--cwd" root
                                           "--label" (if shell-only "shell"
                                                       herdr-default-agent-kind)
                                           "--focus")
                  (herdr--call-json-sync "workspace" "create" "--cwd" root
                                         "--label" (herdr--project-name root)
                                         "--focus")))))
    (unless shell-only
      (herdr-workspace--start-agent pane root))
    (herdr)))

;;;###autoload
(defun herdr-workspace-new-terminal (&optional split)
  "A plain shell, no agent, in the focused Herdr workspace's directory.
A new tab; with prefix arg SPLIT, split the focused pane to the right."
  (interactive "P")
  (let* ((snap (herdr-workspace--snapshot))
         (pane (or (herdr-workspace--focused-pane snap)
                   (user-error "Herdr has no focused pane")))
         (cwd (or (alist-get 'foreground_cwd pane) (alist-get 'cwd pane)
                  default-directory)))
    (unless (if split
                (herdr--call-json-sync "pane" "split" (alist-get 'pane_id pane)
                                       "--direction" "right" "--cwd" cwd)
              (herdr--call-json-sync "tab" "create"
                                     "--workspace" (alist-get 'workspace_id pane)
                                     "--cwd" cwd "--label" "shell" "--focus"))
      (user-error "Herdr could not open a terminal"))
    (herdr)))

;;;###autoload
(defun herdr-workspace-switch-project ()
  "Focus a Herdr workspace, picked by name, and show it."
  (interactive)
  (let ((ws (herdr-workspace--read-workspace "Herdr project: "
                                             (herdr-workspace--snapshot))))
    (herdr--call-json-sync "workspace" "focus" (alist-get 'workspace_id ws))
    (herdr)))

;;;###autoload
(defun herdr-workspace-close-project ()
  "Close a Herdr workspace, the focused one by default, with all it runs."
  (interactive)
  (let* ((ws (herdr-workspace--read-workspace "Close Herdr project: "
                                              (herdr-workspace--snapshot)))
         (label (alist-get 'label ws)))
    (when (yes-or-no-p (format "Close %s and kill its %d pane(s)? "
                               label (or (alist-get 'pane_count ws) 0)))
      (herdr--call-json-sync "workspace" "close" (alist-get 'workspace_id ws))
      (message "herdr: closed %s" label))))

;;;###autoload
(defun herdr-workspace-close-tab ()
  "Close the focused Herdr tab and what runs in it."
  (interactive)
  (let* ((snap (herdr-workspace--snapshot))
         (tab (or (alist-get 'focused_tab_id snap)
                  (user-error "Herdr has no focused tab"))))
    (when (y-or-n-p (format "Close Herdr tab %s? " tab))
      (herdr--call-json-sync "tab" "close" tab)
      (message "herdr: closed tab %s" tab))))


;;;; Chime

(defun herdr-workspace-chime (agent old new)
  "Chime when AGENT goes from OLD to a status `herdr-notify' would announce.
Rides `herdr-status-change-functions' next to the desktop notification."
  (when (and herdr-workspace-chime
             (fboundp 'claude-workspace--chime)
             (herdr--notify-transition-p old new)
             (not (herdr--agent-in-view-p agent)))
    (claude-workspace--chime)))

(add-hook 'herdr-status-change-functions #'herdr-workspace-chime)


;;;; Evil in Herdr buffers

;; The Herdr TUI runs on the terminal's alternate screen, where evil-ghostel's
;; `auto' ESC goes to the terminal -- so insert state is a trap.  In Herdr
;; buffers ESC goes to evil instead (normal state: SPC leader, motions, yank
;; off the screen; i/a back in), the same deal as the Claude buffers, and:
;;
;;   C-g   a real ESC for the agent (interrupt, back out of a Herdr popup)
;;   C-b   Herdr's prefix, from normal state too: the next key is Herdr's
;;         (C-b w workspaces, C-b ? help ...); you land in insert state
;;   q     (normal) close it -- detach, agents keep running in the server
;;
;; Herdr's own keys are otherwise out of the way: everything you type in
;; insert state goes to the focused agent.

(defun herdr-workspace-send-esc-to-terminal ()
  "Send a real ESC to the terminal, not to evil."
  (interactive)
  (ghostel-send-key "escape"))

(defun herdr-workspace-herdr-prefix ()
  "Send Herdr's prefix (C-b) and enter insert state for the key after it."
  (interactive)
  (ghostel-send-key "b" "ctrl")
  (evil-insert-state)
  (message "herdr prefix: next key goes to Herdr (C-b ? for help)"))

(defvar-keymap herdr-workspace-evil-mode-map)

(define-minor-mode herdr-workspace-evil-mode
  "Evil-friendly keys in a Herdr ghostel buffer."
  :keymap herdr-workspace-evil-mode-map
  (when herdr-workspace-evil-mode
    (setq-local evil-ghostel--escape-mode 'evil)
    (evil-normalize-keymaps)))

(with-eval-after-load 'evil
  (evil-define-key* 'insert herdr-workspace-evil-mode-map
    (kbd "C-g") #'herdr-workspace-send-esc-to-terminal)
  (evil-define-key* '(normal insert) herdr-workspace-evil-mode-map
    (kbd "C-b") #'herdr-workspace-herdr-prefix)
  (evil-define-key* 'normal herdr-workspace-evil-mode-map
    (kbd "q") #'herdr-workspace-close))

(defun herdr-workspace--evilify (buf)
  "Turn on `herdr-workspace-evil-mode' in BUF and return BUF."
  (when (buffer-live-p buf)
    (with-current-buffer buf (herdr-workspace-evil-mode 1)))
  buf)

;; Both creators return the new buffer; the TUI and the per-agent attaches.
(advice-add 'herdr--create-buffer :filter-return #'herdr-workspace--evilify)
(advice-add 'herdr--create-attach-buffer :filter-return #'herdr-workspace--evilify)

;;;; Menu

;; Everything on SPC j in one place, like `claude-workspace-transient';
;; `?' in a Herdr buffer's normal state opens it too.
(transient-define-prefix herdr-workspace-transient ()
  "Herdr — projects, agents and terminals living in the Herdr server."
  [:description
   (lambda ()
     (format "Herdr   [%d agent(s)%s]" (length herdr--agents-cache)
             (if (> herdr--blocked-count 0)
                 (format " · %d ● blocked" herdr--blocked-count) "")))
   ["Projects"
    ("n" "Add project (C-u: shell only)" herdr-workspace-add-project)
    ("p" "Switch project" herdr-workspace-switch-project)
    ("k" "Close project" herdr-workspace-close-project)]
   ["Agents / terminals"
    ("a" "New agent, this project" herdr-new-agent)
    ("t" "New terminal (C-u: split)" herdr-workspace-new-terminal)
    ("K" "Close tab" herdr-workspace-close-tab)
    ("x" "Switch agent" herdr-switch-agent)
    ("u" "Jump to blocked" herdr-goto-blocked)
    ("l" "Agent list" herdr-agents)]
   ["Focused agent"
    ("v" "Paste clipboard (C-u: submit)" herdr-workspace-send-clipboard)
    ("i" "Send ESC" herdr-workspace-send-escape)
    ("g" "Magit" herdr-workspace-magit)
    ("d" "Dired" herdr-workspace-dired)
    ("e" "Expand → project workspace" herdr-workspace-expand-to-project)]
   ["Herdr"
    ("j" "Open herdr workspace" herdr-workspace-open)
    ("m" "Collapse → herdr workspace" herdr-workspace-collapse)
    ("q" "Close (agents keep running)" herdr-workspace-close)
    ("h" "emacs-herdr's own menu" herdr-menu)]])

(with-eval-after-load 'evil
  (evil-define-key* 'normal herdr-workspace-evil-mode-map
    (kbd "?") #'herdr-workspace-transient))

(provide 'herdr-workspace)
;;; herdr-workspace.el ends here
