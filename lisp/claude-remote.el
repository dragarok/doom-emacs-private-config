;;; claude-remote.el --- Windows into remote Emacs machines from Android -*- lexical-binding: t -*-

;;; Commentary:
;; Full-screen ghostel terminal running mosh/ssh -> emacsclient -t into a
;; remote machine's Emacs daemon (Mac, kai, ...), with a passthrough mode
;; that hands the whole keyboard to the remote Emacs.
;;
;;   claude-remote-mac / claude-remote-kai - toggle ONE machine (toolbar)
;;   claude-remote                         - connect to the ACTIVE machine
;;   claude-remote-next-session            - remote: next Claude session
;;   claude-remote-prev-session            - remote: previous Claude session
;;   claude-remote-talk                    - dictate/type into the session
;;   C-\                                   - toggle keyboard passthrough
;;
;; MULTIPLE MACHINES AT ONCE.  Every machine in `claude-remote-machines'
;; gets its own connection buffer (*claude-remote[mac]*,
;; *claude-remote[kai]*) AND its own Doom workspace (ssh-mac, ssh-kai,
;; see `claude-remote-workspace-format').  So both connections stay
;; alive, full-screen and undisturbed in parallel: the Mac button jumps
;; straight into the Mac, the kai button straight into kai, and tapping
;; the button of the machine you are already driving releases the
;; keyboard and drops you back in the local Android workspace.  Nothing
;; is ever "switched away" -- you hop between three places.
;;
;; WHY GHOSTEL AND NOT VTERM.  The two keyboard states this needs are
;; ghostel's own input modes, so there is nothing to hand-roll:
;;
;;   passthrough on  -> `ghostel-char-mode'   every key goes to the
;;                      remote, including C-c / C-x / M-x, which is
;;                      exactly what driving a remote Emacs wants.
;;   passthrough off -> `ghostel-emacs-mode'  read-only buffer, terminal
;;                      still streaming: you watch the remote work and
;;                      can search/copy the scrollback, and no key can
;;                      reach the remote by accident.
;;
;; Under vterm this file had to forward `vterm-keymap-exceptions' by hand
;; and stub out every vterm send command to build a viewer that was worse
;; (frozen, unsearchable) than the one ghostel ships.  Only ONE key stays
;; local in char mode: `claude-remote-toggle-key'.
;;
;; Commands are passed to `ghostel-exec' as PROGRAM plus an ARGS list.
;; ghostel shell-quotes each element, so the mosh/ssh command never has
;; to survive a round of shell parsing on the way out -- the quoting bugs
;; that a single command string invites cannot happen here.
;;
;; LANG=en_US.UTF-8 is forced on the client side (Android Emacs exports
;; en_US.utf8, a spelling macOS does not have) and COLORTERM=truecolor so
;; the remote tty frame renders 24-bit colors.

;;; Code:

(require 'ghostel)
(require 'seq)

(declare-function evil-emacs-state "evil-states")
(declare-function evil-force-normal-state "evil-commands")
(defvar claude-remote-mode)             ; define-minor-mode below, used earlier

;; Doom workspace (persp-mode) API, same seam claude-workspace.el uses.
(declare-function +workspace-current-name "ignore")
(declare-function +workspace-switch "ignore")
(declare-function +workspace-list-names "ignore")
(declare-function persp-add-buffer "persp-mode")

(defgroup claude-remote nil
  "Windows into remote Emacs machines from Android."
  :group 'tools)

;;; Machines ---------------------------------------------------------------

(defcustom claude-remote-ssh-key
  "/data/data/com.termux/files/home/.ssh/mac_tailscale"
  "Private key used for every machine that does not set its own `:ssh-key'.
Defaults to the Termux key whose public half sits in ~/.ssh/authorized_keys
on each remote machine, so one key reaches the whole fleet.  Devices that
are not the phone override it in local.el, e.g. on the Mac:

  (setq claude-remote-ssh-key \"/Users/alokregmi/.ssh/id_kai\")"
  :type 'string :group 'claude-remote)

(defcustom claude-remote-default-transport 'mosh
  "Transport for machines that do not set their own `:transport'.
`mosh' survives the phone roaming between networks and sleeping, and is
what you want everywhere -- but it needs mosh-server installed on the
remote.  `ssh' is the fallback for machines that lack it."
  :type '(choice (const mosh) (const ssh)) :group 'claude-remote)

(defcustom claude-remote-machines
  '((mac :user "alokregmi"
     :emacsclient "/opt/homebrew/bin/emacsclient"
     :transport mosh
     :label "Mac")
    (kai :user "alokregmi"
     :emacsclient "/usr/bin/emacsclient"
     :transport mosh
     :label "Kai"))
  "Remote machines reachable over mosh or ssh.
Each entry is (NAME :user USER [:host IP] [:ssh-key FILE]
[:emacsclient PATH] [:transport mosh|ssh] [:label STRING]
[:next-form FORM] [:prev-form FORM]).

`:ssh-key' defaults to `claude-remote-ssh-key', `:transport' to
`claude-remote-default-transport'.

To keep Tailscale IPs out of the repo, omit `:host' and set the env var
CLAUDE_REMOTE_<NAME>_HOST instead -- init.el loads the git-ignored
local.el where they live, e.g.:

  (setenv \"CLAUDE_REMOTE_MAC_HOST\" \"100.x.y.z\")
  (setenv \"CLAUDE_REMOTE_KAI_HOST\" \"100.x.y.z\")

Adding a machine is one entry here plus its env var in local.el.  Each
machine automatically gets a `claude-remote-NAME' toggle command (see
`claude-remote--define-machine-commands') you can put on the toolbar."
  :type '(alist :key-type symbol :value-type plist)
  :group 'claude-remote
  :set (lambda (sym val)
         (set-default sym val)
         (when (fboundp 'claude-remote--define-machine-commands)
           (claude-remote--define-machine-commands))))

(defcustom claude-remote-active-machine 'mac
  "Machine the machine-less commands (`claude-remote', `SPC o C') target.
Follows the machine you last jumped into, so it is simply \"the one I am
working on\"."
  :type 'symbol :group 'claude-remote)

(defcustom claude-remote-toggle-key "C-\\"
  "Key that toggles keyboard passthrough (the only key kept local)."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-workspace-format "ssh-%s"
  "Format string building each machine's own Doom workspace name.
Every machine lives in its OWN workspace (ssh-mac, ssh-kai, ...), which
is what lets several connections sit full-screen and undisturbed at the
same time.  Releasing the keyboard returns you to the local workspace
you came from."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-flush-escape t
  "Flush BOTH sides on each keyboard handover (both directions).
Remote: an ESC is sent through the wire, clearing any pending prefix key
or half-delivered escape sequence there.  Local (Android): the
queued-but-unprocessed input is discarded (`discard-input') so keys typed
around the toggle cannot leak across the boundary, and on release local
evil lands fresh in normal state -- the Android-side \"ESC\".
Without this, one side stays stale and its pending keys pass to the
other after the handover.
Caveat: if the remote focus is a Claude TUI, the ESC clears its input
box / interrupts a running turn; set to nil if that ever bites."
  :type 'boolean :group 'claude-remote)

;;; Driving the remote Claude workspace ------------------------------------

(defcustom claude-remote-next-form "(claude-workspace-cycle-session)"
  "Elisp evaluated ON THE REMOTE to move to the next Claude session.
Sent as `M-:' FORM RET rather than as the local chord (SPC v x): `M-:'
is in `ghostel-keymap-exceptions', so it reaches the remote Emacs even
when the focus sits inside a Claude terminal, and evaluating a form
needs no completion round-trip.  Override per machine with `:next-form'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-prev-form "(claude-workspace-cycle-session t)"
  "Elisp evaluated ON THE REMOTE to move to the previous Claude session.
See `claude-remote-next-form'.  Override per machine with `:prev-form'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-escape-form "(claude-workspace-send-escape)"
  "Elisp evaluated ON THE REMOTE to send ESC to its current Claude session.
ESC is how you interrupt a running turn or back out of a Claude prompt.
Sent as an eval rather than as a bare ESC through the wire because the
remote focus is not always inside the TUI -- from a placeholder cell a
raw ESC would land in evil instead.  Override per machine with
`:escape-form'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-add-form "(claude-workspace-add)"
  "Elisp evaluated ON THE REMOTE to add Claude session(s) to its grid.
This one prompts on the remote (which project?), so the button that
sends it also jumps you into the connection first -- your typing has to
reach the remote minibuffer.  Override per machine with `:add-form'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-refresh-form "(claude-workspace-refresh-session)"
  "Elisp evaluated ON THE REMOTE to restart its current session with --continue.
The repair for a session whose display has gone garbled -- the same
conversation comes back.  Override per machine with `:refresh-form'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-talk-submit t
  "When non-nil, `claude-remote-talk' presses RET after the dictated text.
Set to nil (or call with a prefix argument) to drop the text into the
remote Claude prompt and leave sending to you."
  :type 'boolean :group 'claude-remote)

;;; Machine lookup ---------------------------------------------------------

(defvar-local claude-remote--machine-name nil
  "Machine this connection buffer talks to.")

(defvar claude-remote--last-buffer nil
  "Last connection buffer entered; the default target off-buffer.")

(defun claude-remote--machine (&optional name)
  "Return the entry (NAME . PLIST) for NAME, or the active machine."
  (let ((name (or name claude-remote-active-machine)))
    (or (assq name claude-remote-machines)
        (user-error "No machine named `%s' in claude-remote-machines" name))))

(defun claude-remote--label (name)
  "Human label for machine NAME."
  (or (plist-get (cdr (assq name claude-remote-machines)) :label)
      (and name (symbol-name name))
      "remote"))

(defun claude-remote--buffer-name (name)
  "Connection buffer name for machine NAME."
  (format "*claude-remote[%s]*" name))

(defun claude-remote--host (machine)
  "Host for MACHINE: explicit :host, else $CLAUDE_REMOTE_<NAME>_HOST."
  (let* ((up (upcase (symbol-name (car machine))))
         (env (format "CLAUDE_REMOTE_%s_HOST" up)))
    (or (plist-get (cdr machine) :host)
        (getenv env)
        ;; pre-rename local.el files still say CLAUDE_MAC_<NAME>_HOST
        (getenv (format "CLAUDE_MAC_%s_HOST" up))
        (user-error "No host for `%s': (setenv \"%s\" \"<ip>\") in local.el"
                    (car machine) env))))

(defun claude-remote--program+args (machine)
  "Return (PROGRAM . ARGS) attaching to MACHINE's Emacs daemon.
An argv list, not a command string: `ghostel-exec' shell-quotes every
element, so nothing here is re-parsed by a shell on the way out and the
remote command cannot be mangled by quoting.  The one place a shell IS
involved is the far end -- ssh concatenates its command arguments and
hands them to the remote login shell -- hence the single quotes inside
that one argument, and only there."
  (let* ((p (cdr machine))
         (key (or (plist-get p :ssh-key) claude-remote-ssh-key))
         (target (format "%s@%s" (plist-get p :user) (claude-remote--host machine)))
         (ec (or (plist-get p :emacsclient) "emacsclient"))
         (remote (format "COLORTERM=truecolor %s -t" ec)))
    (pcase (or (plist-get p :transport) claude-remote-default-transport)
      ('mosh (cons "mosh"
                   (list (format "--ssh=ssh -i %s" key) target
                         "--" "bash" "-l" "-c" remote)))
      ('ssh  (cons "ssh"
                   (list "-t" "-i" key
                         "-o" "ServerAliveInterval=30"
                         "-o" "ServerAliveCountMax=6"
                         target
                         (format "bash -l -c '%s'" remote))))
      (other (user-error "Unknown :transport `%s' for machine `%s'"
                         other (car machine))))))

;;; Keyboard passthrough ---------------------------------------------------
;;
;; ghostel char mode already sends every key to the remote, so the only
;; thing this map exists for is to keep ONE key local.  It is registered in
;; `emulation-mode-map-alists' AFTER ghostel's own char-mode entry, and
;; `add-to-list' pushes to the front, so it outranks char mode -- which is
;; the whole point: in char mode ghostel would otherwise send C-\ too.

(defvar claude-remote-passthrough-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd claude-remote-toggle-key)
                #'claude-remote-passthrough-mode)
    map)
  "The one key kept local while the remote has the keyboard.")

(add-to-list 'emulation-mode-map-alists
             `((claude-remote-passthrough-mode
                . ,claude-remote-passthrough-mode-map)))

(defun claude-remote--send (string)
  "Send STRING to the remote through the current connection buffer."
  (when (derived-mode-p 'ghostel-mode)
    (ghostel-send-string string)))

(define-minor-mode claude-remote-passthrough-mode
  "Hand the whole keyboard to the remote Emacs (ghostel char mode).
Only `claude-remote-toggle-key' stays local.  Turning it off puts the
buffer in ghostel Emacs mode: read-only, but the terminal keeps
streaming, so you go on watching the remote work."
  :lighter " [→REMOTE]"
  (unless (derived-mode-p 'ghostel-mode)
    (setq claude-remote-passthrough-mode nil)
    (user-error "claude-remote-passthrough-mode only works in ghostel buffers"))
  (let ((label (claude-remote--label
                (or claude-remote--machine-name claude-remote-active-machine))))
    (if claude-remote-passthrough-mode
        (progn
          (unless (eq ghostel--input-mode 'char)
            (ghostel-char-mode))
          (when (bound-and-true-p evil-local-mode)
            (evil-emacs-state))
          ;; fresh handover on BOTH sides: drop any queued local keys so they
          ;; cannot leak through to the remote, then flush the remote of
          ;; pending prefix/partial sequences before the first forwarded key
          (when claude-remote-flush-escape
            (discard-input)
            (ignore-errors (claude-remote--send "\e")))
          (message "Keyboard → %s (release: %s or its toolbar button)"
                   label claude-remote-toggle-key))
      ;; releasing: same both-sides flush on the way out -- remote left clean
      ;; (not mid-sequence), local queue dropped so trailing keys do not spill,
      ;; and local evil lands FRESH in normal state (the Android-side ESC)
      (when claude-remote-flush-escape
        (ignore-errors (claude-remote--send "\e"))
        (discard-input))
      ;; keyboard is local now: read-only viewer, still streaming.  Blocked
      ;; means blocked -- `ghostel-readonly-fast-exit' is off in these buffers
      ;; (see `claude-remote-connect'), so a stray letter cannot drop you back
      ;; into a mode where keys reach the remote.
      (unless (eq ghostel--input-mode 'emacs)
        (ghostel-emacs-mode))
      (when (bound-and-true-p evil-local-mode)
        (evil-force-normal-state))
      ;; ... and you are DONE here: hop back to the local workspace you came
      ;; from, leaving this connection undisturbed in its own workspace
      (let ((ws (and claude-remote-mode (claude-remote--leave-workspace))))
        (if ws
            (message "Keyboard → local · back to %s (%s waits in %s)"
                     ws label (claude-remote--workspace-name
                               claude-remote--machine-name))
          (message "Keyboard → local Android Emacs (buffer is read-only)"))))))

(defvar claude-remote-mode-map
  (let ((map (make-sparse-keymap)))
    ;; re-enter passthrough with the same key when it's off.  A minor-mode
    ;; map outranks the read-only mode's local map, so this works from the
    ;; viewer too.
    (define-key map (kbd claude-remote-toggle-key)
                #'claude-remote-passthrough-mode)
    map)
  "Keymap active in claude-remote buffers regardless of passthrough.")

(define-minor-mode claude-remote-mode
  "Marker mode for claude-remote connection buffers."
  :keymap claude-remote-mode-map)

;;; One workspace per machine ----------------------------------------------

(defvar claude-remote--previous-workspace nil
  "Last LOCAL workspace you came from, to return to on release.
Never a claude-remote workspace: hopping mac -> kai must not make the
release button drop you into the machine you just left.")

(defun claude-remote--workspace-name (name)
  "Doom workspace hosting machine NAME's connection."
  (format claude-remote-workspace-format
          (or name claude-remote-active-machine)))

(defun claude-remote--workspace-p (ws)
  "Non-nil when WS is the workspace of some claude-remote machine."
  (and ws (seq-some (lambda (m)
                      (equal ws (claude-remote--workspace-name (car m))))
                    claude-remote-machines)))

(defun claude-remote--ensure-workspace (name)
  "Switch to machine NAME's workspace, remembering where you came from.
Creates the workspace on first use.  No-op without Doom workspaces."
  (when (and (fboundp '+workspace-current-name)
             (fboundp '+workspace-switch))
    (let ((cur (+workspace-current-name))
          (ws (claude-remote--workspace-name name)))
      (unless (equal cur ws)
        (unless (claude-remote--workspace-p cur)
          (setq claude-remote--previous-workspace cur))
        (+workspace-switch ws t)))))

(defun claude-remote--leave-workspace ()
  "Return to the local workspace you were in before connecting.
Falls back to the first workspace that is not a machine's.  Returns the
workspace name switched to, or nil when there is nowhere to go -- the
caller keeps its usual message then."
  (when (and (fboundp '+workspace-current-name)
             (fboundp '+workspace-switch)
             (claude-remote--workspace-p (+workspace-current-name)))
    (let* ((names (and (fboundp '+workspace-list-names)
                       (+workspace-list-names)))
           (prev claude-remote--previous-workspace)
           (target (if (and (member prev names)
                            (not (claude-remote--workspace-p prev)))
                       prev
                     (seq-find (lambda (n) (not (claude-remote--workspace-p n)))
                               names))))
      (when target
        (+workspace-switch target)
        target))))

;;; Entry points -----------------------------------------------------------

(defun claude-remote--live-p (buf)
  "Non-nil when BUF holds a running connection."
  (and (buffer-live-p buf)
       (let ((proc (or (buffer-local-value 'ghostel--process buf)
                       (get-buffer-process buf))))
         (and proc (process-live-p proc)))))

;;;###autoload
(defun claude-remote-connect (&optional name)
  "Open (or jump back to) the connection into machine NAME.
NAME defaults to `claude-remote-active-machine'.  Lands in that
machine's own workspace, recreates the connection if it died, and hands
the keyboard over."
  (interactive (list (claude-remote--read-machine)))
  (let* ((name (or name claude-remote-active-machine))
         (machine (claude-remote--machine name))
         (bufname (claude-remote--buffer-name name))
         (buf (get-buffer bufname))
         (fresh nil))
    (setq claude-remote-active-machine name)
    (claude-remote--ensure-workspace name)
    ;; dead connection -> start fresh
    (when (and buf (not (claude-remote--live-p buf)))
      (kill-buffer buf)
      (setq buf nil))
    (unless buf
      (setq buf (get-buffer-create bufname) fresh t))
    (switch-to-buffer buf)
    (delete-other-windows)              ; also sizes the pty to a full window
    (when fresh
      (let* ((cmd (claude-remote--program+args machine))
             ;; Android Emacs exports en_US.utf8, a spelling macOS lacks
             (ghostel-environment (append '("LANG=en_US.UTF-8" "LC_ALL=en_US.UTF-8")
                                          ghostel-environment)))
        (message "claude-remote[%s]: %s %s" name (car cmd)
                 (string-join (cdr cmd) " "))
        (ghostel-exec buf (car cmd) (cdr cmd)))
      (with-current-buffer buf
        ;; ghostel-mode has just been set, which killed local variables --
        ;; so these two have to come after `ghostel-exec', not before.
        ;; Keep OUR buffer name: ghostel renames buffers from the terminal's
        ;; title report (OSC 2), and the remote Emacs reports one.  The
        ;; per-machine name is how every other command finds this buffer.
        (setq-local ghostel-buffer-name-function nil)
        ;; Blocked means blocked: without this, any self-inserting key would
        ;; bounce the read-only viewer back into a mode that types at the
        ;; remote -- exactly the half-a-keyboard state this avoids.
        (setq-local ghostel-readonly-fast-exit nil)))
    (when (fboundp 'persp-add-buffer)      ; buffer belongs to this workspace
      (ignore-errors (persp-add-buffer buf)))
    (with-current-buffer buf
      (setq claude-remote--machine-name name)
      (claude-remote-mode 1)
      (claude-remote-passthrough-mode 1))
    (setq claude-remote--last-buffer buf)
    buf))

;;;###autoload
(defalias 'claude-remote #'claude-remote-connect)

(defun claude-remote--read-machine ()
  "Read a machine name; cycling instead is `claude-remote-switch-machine'."
  (intern (completing-read
           "Machine: "
           (mapcar (lambda (m) (symbol-name (car m))) claude-remote-machines)
           nil t)))

;;;###autoload
(defun claude-remote-toggle-machine (name)
  "Toolbar entry for ONE machine: jump into NAME, or release the keyboard.
Tapping the button of the machine you are already driving hands the
keyboard back to Android and returns you to your local workspace;
tapping any other machine's button takes you straight there, without
disturbing the connection you left behind."
  (interactive (list (claude-remote--read-machine)))
  (if (and claude-remote-mode
           claude-remote-passthrough-mode
           (eq claude-remote--machine-name name))
      (claude-remote-passthrough-mode -1)
    (claude-remote-connect name)))

;;;###autoload
(defun claude-remote-toggle ()
  "Toggle the ACTIVE machine (see `claude-remote-toggle-machine')."
  (interactive)
  (claude-remote-toggle-machine
   (or (and claude-remote-mode claude-remote--machine-name)
       claude-remote-active-machine)))

;;;###autoload
(defun claude-remote-switch-machine (&optional name)
  "Make NAME the active machine; interactively, cycle to the next one.
With a prefix argument, pick the machine by name instead of cycling.
Only affects the machine-less commands -- the per-machine toolbar
buttons always target their own machine."
  (interactive)
  (let* ((names (mapcar #'car claude-remote-machines))
         (next (cond (name name)
                     ((or current-prefix-arg (> (length names) 2))
                      (claude-remote--read-machine))
                     (t (or (cadr (memq claude-remote-active-machine names))
                            (car names))))))
    (unless (assq next claude-remote-machines)
      (user-error "No machine named `%s' in claude-remote-machines" next))
    (setq claude-remote-active-machine next)
    (message "claude-remote → %s (%s)"
             next (or (ignore-errors
                        (claude-remote--host (assq next claude-remote-machines)))
                      "host unset — see local.el"))))

;;; Per-machine commands (one toolbar button each) -------------------------

(defun claude-remote--define-machine-commands ()
  "Define a `claude-remote-NAME' toggle command for every machine.
That is the command a toolbar button names, so adding a machine to
`claude-remote-machines' is enough to give it its own button."
  (dolist (m claude-remote-machines)
    (let ((name (car m)))
      (defalias (intern (format "claude-remote-%s" name))
        (lambda ()
          (interactive)
          (claude-remote-toggle-machine name))
        (format "Jump into `%s', or release the keyboard if already there.
See `claude-remote-toggle-machine'." name)))))

(claude-remote--define-machine-commands)

;;; Driving the remote from the Android toolbar ----------------------------

(defun claude-remote--target-buffer ()
  "The connection buffer the remote-control buttons act on.
This buffer when it is one, else the last one you entered, else any live
connection -- so the buttons keep working from anywhere on the phone."
  (or (and claude-remote-mode (current-buffer))
      (and (claude-remote--live-p claude-remote--last-buffer)
           claude-remote--last-buffer)
      (seq-find #'claude-remote--live-p
                (delq nil
                      (mapcar (lambda (m)
                                (get-buffer (claude-remote--buffer-name (car m))))
                              claude-remote-machines)))
      (user-error "No live claude-remote connection — tap Mac or Kai first")))

(defun claude-remote--send-eval (buf form)
  "Evaluate FORM (a string) in the Emacs on the other end of BUF.
Sent as `M-:' FORM RET (ESC is the terminal's meta prefix).  `M-:' is
one of the keys ghostel hands back to Emacs instead of to the terminal
\(`ghostel-keymap-exceptions'), so this reaches the remote Emacs even
while the focus sits inside a running Claude session -- and evaluating a
form needs no completion round-trip, unlike `M-x'."
  (with-current-buffer buf
    (claude-remote--send (concat "\e:" form "\r"))))

(defun claude-remote--session-form (buf key fallback)
  "Per-machine KEY (`:next-form'/`:prev-form') for BUF, else FALLBACK."
  (let ((name (buffer-local-value 'claude-remote--machine-name buf)))
    (or (plist-get (cdr (assq name claude-remote-machines)) key) fallback)))

;;;###autoload
(defun claude-remote-next-session ()
  "Move the remote machine to its NEXT Claude session.
Works from anywhere on the phone, in or out of the connection buffer."
  (interactive)
  (let ((buf (claude-remote--target-buffer)))
    (claude-remote--send-eval
     buf (claude-remote--session-form buf :next-form claude-remote-next-form))
    (message "%s → next Claude session"
             (claude-remote--label
              (buffer-local-value 'claude-remote--machine-name buf)))))

;;;###autoload
(defun claude-remote-prev-session ()
  "Move the remote machine to its PREVIOUS Claude session.
Works from anywhere on the phone, in or out of the connection buffer."
  (interactive)
  (let ((buf (claude-remote--target-buffer)))
    (claude-remote--send-eval
     buf (claude-remote--session-form buf :prev-form claude-remote-prev-form))
    (message "%s → previous Claude session"
             (claude-remote--label
              (buffer-local-value 'claude-remote--machine-name buf)))))

;;;###autoload
(defun claude-remote-talk (&optional no-submit)
  "Dictate (or type) a message into the remote machine's current session.
Opens a local prompt -- on Android that is the soft keyboard, so the
keyboard's microphone key turns speech into the text -- then types it
into whatever the remote Emacs has focused, which is the Claude session
you are watching.  Sends RET too unless `claude-remote-talk-submit' is
nil or NO-SUBMIT (a prefix argument) is given, so you can review first."
  (interactive "P")
  (let* ((buf (claude-remote--target-buffer))
         (label (claude-remote--label
                 (buffer-local-value 'claude-remote--machine-name buf)))
         (text (read-string (format "Say to %s: " label))))
    (if (string-empty-p (string-trim text))
        (message "Nothing to say — cancelled")
      (with-current-buffer buf
        (claude-remote--send
         (if (or no-submit (not claude-remote-talk-submit))
             text
           (concat text "\r"))))
      (message "→ %s: %s" label
               (truncate-string-to-width text 40 nil nil "…")))))

(defun claude-remote--drive (key fallback local label &optional enter)
  "Run one Claude-grid action on whichever machine you are driving.
KEY is the per-machine plist override (`:escape-form' and friends) and
FALLBACK the default form string; LABEL names the action in the echo
area.  When a connection is live the form is evaluated ON THE REMOTE --
that is what makes these work while you are watching an SSH session from
the phone -- and when none is, LOCAL (a command symbol) runs here
instead, so the same button serves the machine that hosts the grid.
ENTER non-nil first jumps into the connection and takes the keyboard,
for actions that go on to prompt on the remote.

The forms travel as `M-:', not as the local chord: see
`claude-remote--send-eval' for why a leader chord would be typed into
the Claude TUI instead of reaching the remote Emacs."
  (let ((buf (ignore-errors (claude-remote--target-buffer))))
    (cond
     (buf
      (when enter
        (claude-remote-connect (buffer-local-value 'claude-remote--machine-name buf))
        (setq buf (claude-remote--target-buffer)))
      (claude-remote--send-eval
       buf (claude-remote--session-form buf key fallback))
      (message "%s → %s"
               (claude-remote--label
                (buffer-local-value 'claude-remote--machine-name buf))
               label))
     ((fboundp local) (call-interactively local))
     (t (user-error "No claude-remote connection — tap Mac or Kai first")))))

;;;###autoload
(defun claude-remote-escape ()
  "Send ESC to the Claude session on the machine you are driving.
Interrupts a running turn, or backs out of a permission prompt, without
you having to grab the keyboard first."
  (interactive)
  (claude-remote--drive :escape-form claude-remote-escape-form
                        'claude-workspace-send-escape "ESC"))

;;;###autoload
(defun claude-remote-add-session ()
  "Add Claude session(s) to the grid on the machine you are driving.
Jumps into the connection on the way, because the remote then asks which
project and your keystrokes have to reach it."
  (interactive)
  (claude-remote--drive :add-form claude-remote-add-form
                        'claude-workspace-add "add session(s)" t))

;;;###autoload
(defun claude-remote-refresh-session ()
  "Restart the remote machine\='s current session with `--continue'.
The fix for a session whose terminal display has gone garbled: the same
conversation comes back in the same grid slot."
  (interactive)
  (claude-remote--drive :refresh-form claude-remote-refresh-form
                        'claude-workspace-refresh-session "refresh (--continue)"))

;;; Backwards compatibility (pre-rename names) -----------------------------

(defalias 'claude-mac #'claude-remote-connect)
(defalias 'claude-mac-toggle #'claude-remote-toggle)
(defalias 'claude-mac-switch-machine #'claude-remote-switch-machine)

(provide 'claude-remote)
;;; claude-remote.el ends here
