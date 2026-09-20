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
;;   claude-remote-paste                   - Android clipboard -> the session
;;   claude-remote-paste-raw               - Android clipboard -> remote cursor
;;   claude-remote-paste-image             - screenshot/clipboard image -> session
;;   C-\                                   - toggle keyboard passthrough
;;   C-v                                   - attach an image (kept local)
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
;; (frozen, unsearchable) than the one ghostel ships.  Only TWO keys stay
;; local in char mode, and both have to: `claude-remote-toggle-key' (C-\),
;; because a key that hands the keyboard back cannot itself be forwarded,
;; and `claude-remote-image-key' (C-v), because the screenshot and the
;; clipboard image it attaches live on THIS machine -- the remote has no
;; way to reach them, so the key that picks them up has to run here.
;;
;; Commands are passed to `ghostel-exec' as PROGRAM plus an ARGS list.
;; ghostel shell-quotes each element, so the mosh/ssh command never has
;; to survive a round of shell parsing on the way out -- the quoting bugs
;; that a single command string invites cannot happen here.
;;
;; LANG=en_US.UTF-8 is forced on the client side (Android Emacs exports
;; en_US.utf8, a spelling macOS does not have) and COLORTERM=truecolor so
;; the remote tty frame renders 24-bit colors.
;;
;; SSH_TTY IS REPAIRED ON THE WAY IN (`claude-remote--ssh-tty-repair'),
;; which is what makes killing text work on the far side.  See that
;; constant for the mosh detail; lisp/tty-clipboard.el repairs the frames
;; this file did not open.

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
  "Key that toggles keyboard passthrough.
One of the two keys kept local while the remote has the keyboard; the
other is `claude-remote-image-key'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-image-key "C-v"
  "Key that attaches an image to the Claude session you are driving.
The second of the two keys kept local while the remote has the keyboard
(see `claude-remote-toggle-key'), and it has to be local: the screenshot
you just took and the image on the clipboard are on THIS machine, and
the remote Emacs has no way to reach either of them.  Everything else
you type in passthrough mode still goes straight to the remote.

C-v is the same key Claude Code itself uses to attach a pasted image, so
the habit carries over -- it just has to be caught one hop earlier here.
See `claude-remote-paste-image'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-image-dirs nil
  "Directories searched for the newest screenshot, newest file anywhere wins.
nil means work them out per platform, which is what you want -- see
`claude-remote--image-dirs': the Android screenshot folders on the phone,
and on macOS the folder `screencapture' is actually configured to write
to (its `location' default, ~/Desktop when unset)."
  :type '(choice (const :tag "Per platform" nil) (repeat directory))
  :group 'claude-remote)

(defcustom claude-remote-image-extensions
  '("png" "jpg" "jpeg" "gif" "webp")
  "Extensions `claude-remote-paste-image' considers to be images.
Matched case-insensitively.  Claude reads all of these; HEIC is left out
because it cannot."
  :type '(repeat string) :group 'claude-remote)

(defcustom claude-remote-image-remote-dir "/tmp"
  "Directory on the REMOTE machine that attached images are copied into.
/tmp because it is the one directory guaranteed to exist and be writable
on every machine in `claude-remote-machines', so the copy needs no `ssh
mkdir' round trip before the `scp'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-image-submit nil
  "When non-nil, `claude-remote-paste-image' presses RET after the path.
Off by default, and off is almost always right: an image on its own says
nothing, and the point of leaving the prompt open is to type the
question you attached it for."
  :type 'boolean :group 'claude-remote)

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

(defcustom claude-remote-paste-function "claude-workspace-send-text"
  "Function PREFERRED on the remote for pasting into its Claude session.
`claude-remote-paste' sends a form that calls it when the remote has it
and drives the session's ghostel buffer itself when it does not, so a
machine that has not pulled this repo's `claude-workspace-send-text' --
or has pulled it into a daemon that has not re-read the file -- still
takes the paste.  That is deliberately unlike `claude-remote-escape-form'
and friends, which simply assume their remote half exists: those lose a
keystroke when they are wrong, this would lose your clipboard.  Override
per machine with `:paste-function'."
  :type 'string :group 'claude-remote)

(defcustom claude-remote-paste-submit nil
  "When non-nil, `claude-remote-paste' presses RET after the pasted text.
Off by default: what you paste from the phone is usually the first half
of a message you still want to type onto.  A prefix argument flips
whichever way this is set."
  :type 'boolean :group 'claude-remote)

(defcustom claude-remote-paste-confirm-above 4000
  "Ask before pasting more than this many characters, nil to never ask.
The text crosses the wire as keystrokes into the remote's `M-:' prompt,
so a novel-sized clipboard is a long time with the connection tied up."
  :type '(choice (const :tag "Never ask" nil) integer)
  :group 'claude-remote)

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

(defconst claude-remote--ssh-tty-repair
  "T=$(tty 2>/dev/null); \
case \"$T\" in /dev/*) SSH_TTY=$T; export SSH_TTY;; *) unset SSH_TTY;; esac; "
  "Shell prologue pointing SSH_TTY at the tty the remote frame really gets.

Without it, killing text on the far side fails with

    Opening output file: Permission denied, /dev/pts/1

and the reason is mosh.  `mosh' bootstraps over a REAL ssh login, so the
shell mosh-server starts inherits SSH_TTY from that login -- and then ssh
exits, taking its pty with it, while mosh-server carries on with a pty of
its own (/dev/pts/2, /dev/pts/3, ...).  `emacsclient -t' passes the stale
value to the daemon as the frame's environment, and clipetty (Doom's
`:os (tty +osc)', which sends every kill to the system clipboard as an
OSC 52 escape) writes that escape to the tty SSH_TTY names.  So every
kill tried to write to a pty that no longer exists -- and devpts lets
nobody create a file there, which is why the error says \"Permission
denied\" rather than \"No such file\".

Running `tty' in the shell mosh-server just started names the pty the
frame will actually be on, so this exports the truth before emacsclient
inherits it.  When there is no tty at all (\"not a tty\"), SSH_TTY is
unset instead of set to that phrase: clipetty then falls back to the
frame's own terminal, which is the right answer, where a bogus value
would have it create a FILE called \"not a tty\".

Contains no single quotes on purpose -- the `ssh' transport below wraps
the whole remote command in them.  lisp/tty-clipboard.el is the other
half of this fix, for frames this file did not open.")

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
         (remote (concat claude-remote--ssh-tty-repair
                         "export COLORTERM=truecolor; "
                         (format "exec %s -t" ec))))
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

;;; The keys kept local ----------------------------------------------------
;;
;; ONE map, on `claude-remote-mode', so it is live in a connection buffer
;; whoever has the keyboard.  There is no second map and no second rule to
;; remember: C-\ toggles passthrough and C-v attaches an image, in char
;; mode and in the viewer alike.
;;
;; It has to sit in `emulation-mode-map-alists' -- a minor-mode map is not
;; enough -- because BOTH of the things it has to outrank live there too:
;; ghostel char mode, which would otherwise send these two keys to the
;; remote along with everything else, and evil, whose normal-state C-v is
;; visual-block.  `add-to-list' pushes to the front, so this wins over both.
;;
;; The keys are bound OUTSIDE the `defvar' on purpose.  `defvar' does not
;; re-evaluate its value once the variable is bound, so a key added here
;; would never reach an Emacs that had already loaded this file: you would
;; reload, press C-v, and still get visual-block.  Top-level `define-key'
;; calls re-run on every load while the map object stays the same, which
;; also keeps the `add-to-list' below idempotent.

(defvar claude-remote-mode-map (make-sparse-keymap)
  "The keys kept local in a claude-remote connection buffer.")

(define-key claude-remote-mode-map (kbd claude-remote-toggle-key)
            #'claude-remote-passthrough-mode)
(define-key claude-remote-mode-map (kbd claude-remote-image-key)
            #'claude-remote-paste-image)

(add-to-list 'emulation-mode-map-alists
             `((claude-remote-mode . ,claude-remote-mode-map)))

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

(define-minor-mode claude-remote-mode
  "Marker mode for claude-remote connection buffers.
Carries `claude-remote-mode-map' (see above), which is registered in
`emulation-mode-map-alists' rather than passed as `:keymap\=' here -- it
has to outrank ghostel char mode and evil, and a plain minor-mode map
outranks neither.")

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
        (setq-local ghostel-readonly-fast-exit nil)
        ;; Let a kill on the REMOTE land in THIS machine\='s clipboard.  The
        ;; remote Emacs sends every kill out as an OSC 52 escape (clipetty,
        ;; Doom\='s `:os (tty +osc)\='), mosh 1.4 passes OSC 52 through, and
        ;; ghostel turns it into `kill-new\=' + the CLIPBOARD selection -- but
        ;; only when this is on, and it ships off for a good reason: any
        ;; program in a terminal could then overwrite your clipboard.
        ;; Buffer-local, so that trust is granted to the machines in
        ;; `claude-remote-machines\=' and to nothing else.
        (setq-local ghostel-enable-osc52 t)))
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

;;; Clipboard -> remote session ---------------------------------------------

(defun claude-remote--clipboard ()
  "Text to paste: the Android system clipboard, else the latest kill.
Emacs on Android exposes the system clipboard as the CLIPBOARD selection,
so whatever you copied in Chrome, Termux or any other app is reachable
here without a round trip through termux-api.  The kill ring is both the
fallback for the desktops this file also loads on and the answer when the
selection owner has gone away.  Returns nil when there is nothing to
paste."
  (let ((text (or (ignore-errors (gui-get-selection 'CLIPBOARD 'UTF8_STRING))
                  (ignore-errors (gui-get-selection 'CLIPBOARD))
                  (ignore-errors (current-kill 0 t)))))
    (and (stringp text)
         (not (string-empty-p (string-trim text)))
         (substring-no-properties text))))

(defun claude-remote--paste-form (fn text submit)
  "Build the form that pastes TEXT on the remote, RET too when SUBMIT.
FN names the remote helper to prefer, but the form does NOT depend on it
existing.  It has to not: the helper ships in this repo, and a machine
that has not pulled it -- or has pulled it into a daemon that has not
re-read the file -- would otherwise answer a paste with `void-function\='
and drop the clipboard on the floor.  So the form asks, and falls back to
driving the session\='s ghostel buffer itself, which is stock.

TEXT rides across as BASE64, and it has to.  The form is not sent to the
remote, it is TYPED into its `M-:\=' minibuffer, where smartparens is live
and a literal RET submits: a lone quote or paren anywhere in your
clipboard would be auto-paired into the form, a newline would send it
half-typed and scatter the rest of the clipboard into whatever had
focus.  The base64 alphabet has none of those, so the form keeps its own
parens and its quotes balanced no matter what you copied."
  (let ((b64 (base64-encode-string (encode-coding-string text 'utf-8) t))
        (sub (if submit "t" "nil")))
    (concat
     "(let ((s (decode-coding-string (base64-decode-string \"" b64 "\") 'utf-8)))"
     " (if (fboundp '" fn ")"
     " (" fn " s " sub ")"
     " (with-current-buffer"
     " (or (ignore-errors (claude-workspace-target-session)) (current-buffer))"
     " (ghostel-paste-string s)"
     " (when " sub " (ghostel-send-string \"\\r\")))))")))

(defun claude-remote--paste-ok-p (text)
  "Return non-nil when TEXT is short enough to paste, or you say so."
  (or (null claude-remote-paste-confirm-above)
      (<= (length text) claude-remote-paste-confirm-above)
      (yes-or-no-p (format "Paste %d characters over the wire? "
                           (length text)))))

;;;###autoload
(defun claude-remote-paste (&optional flip-submit)
  "Paste the Android clipboard into the Claude session you are driving.
This is the missing half of `claude-remote-talk': that one dictates or
types a fresh message, this one hands over text you copied somewhere
else on the phone -- a link, an error, a paragraph from a browser.

The text is delivered as ONE bracketed paste (see
`claude-workspace-send-text' on the remote), so a multi-line clipboard
lands in the prompt as a block rather than submitting a message per
line.  RET is left to you unless `claude-remote-paste-submit' is on;
FLIP-SUBMIT (a prefix argument) reverses that either way.

Sent over the same `M-:' eval channel as the other grid buttons, so it
lands whether or not the remote focus is inside the TUI, and without you
having to take the keyboard first.  With no connection live it pastes
into the local grid instead, which is what makes the same key work on
the machine that hosts the sessions."
  (interactive "P")
  (let* ((text (or (claude-remote--clipboard)
                   (user-error "Clipboard and kill ring are both empty")))
         (submit (if flip-submit
                     (not claude-remote-paste-submit)
                   claude-remote-paste-submit))
         (buf (ignore-errors (claude-remote--target-buffer))))
    (unless (claude-remote--paste-ok-p text)
      (user-error "Paste cancelled"))
    (cond
     (buf
      (let* ((name (buffer-local-value 'claude-remote--machine-name buf))
             (fn (or (plist-get (cdr (assq name claude-remote-machines))
                                :paste-function)
                     claude-remote-paste-function)))
        (claude-remote--send-eval buf (claude-remote--paste-form fn text submit))
        (message "→ %s: pasted %d chars%s" (claude-remote--label name)
                 (length text) (if submit " + RET" ""))))
     ((fboundp 'claude-workspace-send-text)
      (claude-workspace-send-text text submit))
     (t (user-error "No claude-remote connection — tap Mac or Kai first")))))

;;;###autoload
(defun claude-remote-paste-raw ()
  "Type the Android clipboard straight into the connection, as a paste.
The escape hatch for everything `claude-remote-paste' does not target:
a shell on the remote, its minibuffer, a file you have open there.  The
text goes down the wire as a bracketed paste to whatever currently has
the remote's focus, so nothing needs `claude-workspace' on the far end --
but nothing steers it into the Claude session either."
  (interactive)
  (let ((text (or (claude-remote--clipboard)
                  (user-error "Clipboard and kill ring are both empty")))
        (buf (claude-remote--target-buffer)))
    (unless (claude-remote--paste-ok-p text)
      (user-error "Paste cancelled"))
    (with-current-buffer buf
      (if (fboundp 'ghostel-paste-string)
          (ghostel-paste-string text)
        (claude-remote--send text)))
    (message "→ %s: typed %d chars at the cursor"
             (claude-remote--label
              (buffer-local-value 'claude-remote--machine-name buf))
             (length text))))

;;; Screenshots and clipboard images -> remote session ---------------------
;;
;; The one thing `claude-remote-paste' cannot carry.  Text crosses the wire
;; as keystrokes; an image cannot, and the machine running Claude cannot
;; reach the clipboard or the photo roll of the machine you are sitting at.
;; So the image itself is copied over with `scp' -- the same key, user and
;; host the connection already uses -- and its path on the far side is typed
;; into the prompt, which is how you hand Claude Code a picture: it reads
;; any image file you name.
;;
;; That makes ONE command serve both directions this is needed in:
;;
;;   Mac -> kai     C-v in the connection buffer.  Takes the image off the
;;                  macOS clipboard (Cmd-Ctrl-Shift-4), or the newest file
;;                  in the screenshot folder (Cmd-Shift-4) when the
;;                  clipboard has none.
;;   Android -> *   the toolbar's Image button.  Android has no image
;;                  clipboard to read, so it is always the newest
;;                  screenshot -- take one, tap the button.
;;
;; With nothing connected the same command pastes into the LOCAL grid, so
;; the key does the obvious thing on the machine that hosts the sessions.

(defvar claude-remote--macos-shot-dir-cache 'unset
  "Cached `screencapture' location, or `unset' before the first lookup.
The lookup shells out to `defaults', so it is done once and not on every
attach -- and not at load time either, where it would tax startup on
every machine for a value only macOS has.")

(defun claude-remote--macos-screenshot-dir ()
  "Folder macOS is configured to save screenshots into, or nil.
Unset in `defaults' means ~/Desktop, which is what the caller falls back
to; this returns nil in that case rather than guessing here."
  (when (eq claude-remote--macos-shot-dir-cache 'unset)
    (setq claude-remote--macos-shot-dir-cache
          (and (eq system-type 'darwin)
               (let ((dir (string-trim
                           (with-output-to-string
                             (with-current-buffer standard-output
                               (ignore-errors
                                 (call-process "defaults" nil '(t nil) nil
                                               "read" "com.apple.screencapture"
                                               "location")))))))
                 (and (not (string-empty-p dir))
                      (file-directory-p (expand-file-name dir))
                      (expand-file-name dir))))))
  claude-remote--macos-shot-dir-cache)

(defun claude-remote--image-dirs ()
  "Directories to search for the newest screenshot on THIS machine."
  (mapcar #'expand-file-name
          (or claude-remote-image-dirs
              (pcase system-type
                ('android '("/sdcard/Pictures/Screenshots"
                            "/sdcard/DCIM/Screenshots"))
                ('darwin (delq nil (list (claude-remote--macos-screenshot-dir)
                                         "~/Desktop"
                                         "~/Pictures/Screenshots")))
                (_ '("~/Pictures/Screenshots" "~/Desktop"))))))

(defun claude-remote--image-file-p (file)
  "Non-nil when FILE's extension is in `claude-remote-image-extensions'."
  (let ((ext (file-name-extension file)))
    (and ext (member (downcase ext) claude-remote-image-extensions) t)))

(defun claude-remote--newest-image (dirs)
  "Newest image file across DIRS, or nil when there is none.
Compared by modification time across ALL of DIRS, not first-directory
wins: the phone writes screenshots to whichever folder the ROM feels
like, and the newest one is the one you just took."
  (let (best best-time)
    (dolist (dir dirs)
      (when (file-directory-p dir)
        (dolist (entry (ignore-errors
                         (directory-files-and-attributes dir t nil t)))
          (let ((file (car entry))
                (attrs (cdr entry)))
            (when (and (null (file-attribute-type attrs)) ; regular file
                       (> (or (file-attribute-size attrs) 0) 0)
                       (claude-remote--image-file-p file))
              (let ((time (file-attribute-modification-time attrs)))
                (when (or (null best-time) (time-less-p best-time time))
                  (setq best file best-time time))))))))
    best))

(defun claude-remote--clipboard-image (file)
  "Write the macOS clipboard image to FILE.  Return FILE, or nil.
`pngpaste' when it is installed, otherwise AppleScript, which coerces
the clipboard to PNG and errors out when it holds no image -- that error
is the answer \"nothing to attach\", so it is simply a nil return."
  (and (eq system-type 'darwin)
       (or (and (executable-find "pngpaste")
                (eq 0 (call-process "pngpaste" nil nil nil file)))
           (eq 0 (call-process
                  "osascript" nil nil nil "-e"
                  (format "set f to (open for access POSIX file %S with write permission)
try
  set eof f to 0
  write (the clipboard as «class PNGf») to f
  close access f
on error e number n
  close access f
  error e number n
end try" file))))
       (> (or (file-attribute-size (file-attributes file)) 0) 0)
       file))

(defun claude-remote--source-image (&optional pick)
  "Return (FILE . SOURCE) for the image to attach, or nil for none.
SOURCE names where it came from, for the echo area.  PICK non-nil asks
for a file instead.  Otherwise the macOS clipboard wins when it holds an
image -- you copied it a moment ago, that is the one you mean -- and the
newest screenshot on disk is the answer everywhere else, which on
Android is the only answer there is."
  (cond
   (pick (let ((file (expand-file-name
                      (read-file-name "Image to attach: " nil nil t))))
           (cons file "chosen")))
   (t
    (or
     ;; Only macOS has an image clipboard to read here at all: Android
     ;; keeps images out of the clipboard Emacs can see, which is why the
     ;; phone is always "the screenshot you just took".
     (and (eq system-type 'darwin)
          (let* ((tmp (make-temp-file "claude-remote-image-" nil ".png"))
                 (clip (claude-remote--clipboard-image tmp)))
            (or (and clip (cons clip "clipboard"))
                (progn (ignore-errors (delete-file tmp)) nil))))
     (let ((shot (claude-remote--newest-image (claude-remote--image-dirs))))
       (and shot (cons shot "newest screenshot")))))))

(defun claude-remote--remote-image-path (local)
  "Path LOCAL will be copied to on the remote machine.
Timestamped rather than kept under its own name: two screenshots taken a
minute apart are both called Screenshot_something on Android, and the
second would overwrite the first while Claude was still reading it."
  (format "%s/claude-remote-%s.%s"
          (directory-file-name (expand-file-name claude-remote-image-remote-dir))
          (format-time-string "%Y%m%d-%H%M%S")
          (or (file-name-extension local) "png")))

(defun claude-remote--scp (machine local remote callback)
  "Copy LOCAL to MACHINE:REMOTE in the background, then call CALLBACK.
CALLBACK gets (OK OUTPUT): OK non-nil when scp exited 0, OUTPUT whatever
it had to say when it did not.  Asynchronous because this runs off a
keystroke on a phone over Tailscale -- a couple of seconds of frozen
Emacs per screenshot is not a thing to ship."
  (unless (executable-find "scp")
    (user-error "No `scp' on PATH — cannot send images to %s" (car machine)))
  (let* ((p (cdr machine))
         (key (expand-file-name (or (plist-get p :ssh-key) claude-remote-ssh-key)))
         (dest (format "%s@%s:%s" (plist-get p :user)
                       (claude-remote--host machine) remote))
         (out (generate-new-buffer " *claude-remote-scp*")))
    (make-process
     :name "claude-remote-scp"
     :buffer out
     :noquery t
     :connection-type 'pipe
     :command (list "scp" "-q" "-i" key
                    "-o" "BatchMode=yes"
                    "-o" "ConnectTimeout=10"
                    "-o" "StrictHostKeyChecking=accept-new"
                    local dest)
     :sentinel
     (lambda (proc _event)
       (unless (process-live-p proc)
         (let ((ok (and (eq (process-status proc) 'exit)
                        (eq (process-exit-status proc) 0)))
               (output (with-current-buffer out
                         (string-trim (buffer-string)))))
           (kill-buffer out)
           (funcall callback ok output)))))))

(defun claude-remote--send-image-path (path buf)
  "Type PATH into the Claude session, through connection BUF or locally.
Goes down the same `M-:' eval channel as `claude-remote-paste', so it
lands whether or not the remote focus is inside the TUI, and with the
same fallback for a machine whose `claude-workspace-send-text' is
missing.  A trailing space is included so the question you attached the
image for can be typed straight on."
  (let ((text (concat path " ")))
    (if buf
        (let* ((name (buffer-local-value 'claude-remote--machine-name buf))
               (fn (or (plist-get (cdr (assq name claude-remote-machines))
                                  :paste-function)
                       claude-remote-paste-function)))
          (claude-remote--send-eval
           buf (claude-remote--paste-form fn text claude-remote-image-submit)))
      (if (fboundp 'claude-workspace-send-text)
          (claude-workspace-send-text text claude-remote-image-submit)
        (user-error "No claude-remote connection and no local Claude grid")))))

;;;###autoload
(defun claude-remote-paste-image (&optional pick)
  "Attach a screenshot (or the clipboard image) to the Claude session.
The image half of `claude-remote-paste': that one carries text you
copied, this one carries a picture, which cannot travel as keystrokes.

With a connection live the file is `scp'-ed to that machine\='s
`claude-remote-image-remote-dir' and its path there is typed into the
Claude prompt, which is how Claude Code takes an image -- it reads any
file you name.  The copy runs in the background; the path is sent when
it lands.  With nothing connected the local path goes into the local
grid instead, so the same key works on the machine hosting the sessions.

Where the image comes from, in order: the macOS clipboard when it holds
one (Cmd-Ctrl-Shift-4), else the newest file in
`claude-remote--image-dirs' (Cmd-Shift-4 on the Mac, any screenshot on
Android).  PICK (a prefix argument) asks for a file instead.

Bound to `claude-remote-image-key' (C-v) inside a connection you are
driving, and on the Android toolbar\='s Image button."
  (interactive "P")
  (let* ((src (or (claude-remote--source-image pick)
                  (user-error
                   "No image to attach: nothing on the clipboard, no screenshot in %s"
                   (string-join (claude-remote--image-dirs) ", "))))
         (file (car src))
         (from (cdr src))
         (temp (equal from "clipboard"))
         (buf (ignore-errors (claude-remote--target-buffer))))
    (unless (file-readable-p file)
      (user-error "Cannot read %s" file))
    (if (null buf)
        ;; Nothing connected: the sessions are on this machine, so the
        ;; local path IS the path Claude needs.  Nothing to copy.
        (progn (claude-remote--send-image-path file nil)
               (message "Attached %s (%s)" (file-name-nondirectory file) from))
      (let* ((name (buffer-local-value 'claude-remote--machine-name buf))
             (label (claude-remote--label name))
             (machine (claude-remote--machine name))
             (remote (claude-remote--remote-image-path file))
             (size (file-attribute-size (file-attributes file))))
        (message "→ %s: sending %s (%s, %s)…" label
                 (file-name-nondirectory file) from
                 (file-size-human-readable (or size 0)))
        (claude-remote--scp
         machine file remote
         (lambda (ok output)
           ;; The clipboard grab wrote a temp file purely to have something
           ;; to copy; it has served its purpose either way.
           (when temp (ignore-errors (delete-file file)))
           (if (not ok)
               (message "claude-remote → %s: scp failed%s" label
                        (if (string-empty-p output) "" (concat ": " output)))
             (claude-remote--send-image-path remote buf)
             (message "→ %s: attached %s" label remote))))))))

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
