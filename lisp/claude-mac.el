;;; claude-mac.el --- Window into remote Emacs machines from Android -*- lexical-binding: t -*-

;;; Commentary:
;; Full-screen vterm running mosh -> emacsclient -t into a remote
;; machine's Emacs daemon (Mac, PC, ...), with a passthrough mode that
;; hands the whole keyboard to the remote Emacs (like vterm's
;; emacs-mode, plus the exception keys).
;;
;;   claude-mac                - connect (or jump back) to the ACTIVE machine
;;   claude-mac-toggle         - toolbar entry: enter / release keyboard
;;   claude-mac-switch-machine - cycle active machine (C-u: pick by name)
;;   C-\                       - toggle keyboard passthrough on/off
;;
;; Machines are defined in `claude-mac-machines'; all commands target
;; `claude-mac-active-machine'.  Each machine gets its own buffer
;; (*claude-mac[mac]*, *claude-mac[pc]*, ...), so sessions can coexist.
;;
;; The connection lives in its own Doom workspace
;; (`claude-mac-workspace-name', default "ssh-claude"): `claude-mac'
;; always opens there, and releasing the keyboard hops back to the
;; workspace you came from -- the claude window stays full-screen and
;; undisturbed while you do other work.
;;
;; When `claude-mac-passthrough-mode' is on, the buffer is put in evil
;; emacs-state and the keys vterm keeps local (`vterm-keymap-exceptions':
;; C-c C-x C-u C-g C-h C-l M-x M-o C-y M-y) are forwarded to the remote.
;; Only `claude-mac-toggle-key' stays local.
;;
;; The command forces LANG=en_US.UTF-8 on the client side (Android Emacs
;; exports en_US.utf8, a spelling macOS doesn't have) and COLORTERM
;; =truecolor so the remote tty frame renders 24-bit colors (Emacs 28+).

;;; Code:

(require 'vterm)

(declare-function evil-emacs-state "evil-states")
(declare-function evil-force-normal-state "evil-commands")
(defvar claude-mac--blocked)            ; defvar-local below, used earlier
(defvar claude-mac-mode)                ; define-minor-mode below, used earlier

;; Doom workspace (persp-mode) API, same seam claude-workspace.el uses.
(declare-function +workspace-current-name "ignore")
(declare-function +workspace-switch "ignore")
(declare-function +workspace-list-names "ignore")
(declare-function persp-add-buffer "persp-mode")

(defgroup claude-mac nil
  "Window into remote Emacs machines from Android."
  :group 'tools)

(defcustom claude-mac-machines
  '((mac :user "alokregmi"
     :ssh-key "/data/data/com.termux/files/home/.ssh/mac_tailscale"
     :emacsclient "/opt/homebrew/bin/emacsclient"))
  "Remote machines reachable over mosh.
Each entry is (NAME :user USER :ssh-key KEYFILE :emacsclient PATH
[:host IP]).  To keep Tailscale IPs out of the repo, omit :host and
set the env var CLAUDE_MAC_<NAME>_HOST instead — init.el loads the
git-ignored local.el where they live, e.g.:

  (setenv \"CLAUDE_MAC_MAC_HOST\" \"100.x.y.z\")

Adding the PC later is one entry here plus its env var in local.el:

  (pc :user \"alokregmi\"
      :ssh-key \"/data/data/com.termux/files/home/.ssh/pc_tailscale\"
      :emacsclient \"emacsclient\")"
  :type '(alist :key-type symbol :value-type plist)
  :group 'claude-mac)

(defcustom claude-mac-active-machine 'mac
  "Machine in `claude-mac-machines' that the commands target."
  :type 'symbol :group 'claude-mac)

(defcustom claude-mac-toggle-key "C-\\"
  "Key that toggles keyboard passthrough (the only key kept local)."
  :type 'string :group 'claude-mac)

(defcustom claude-mac-workspace-name "ssh-claude"
  "Doom workspace that hosts the claude-mac connection buffer.
`claude-mac' always opens the connection in this workspace (creating it
if needed), and releasing the keyboard returns you to the workspace you
came from -- so the claude window sits undisturbed, full-screen, in its
own workspace while you work elsewhere."
  :type 'string :group 'claude-mac)

(defcustom claude-mac-flush-escape t
  "Flush BOTH sides on each keyboard handover (both directions).
Remote (Mac): an ESC is sent through the wire, clearing any pending
prefix key or half-delivered escape sequence there.  Local (Android):
the queued-but-unprocessed input is discarded (`discard-input') so keys
typed around the toggle cannot leak across the boundary, and on release
local evil lands fresh in normal state -- the Android-side \"ESC\".
Without this, one side stays stale and its pending keys pass to the
other after the handover.
Caveat: if the remote focus is a Claude TUI, the ESC clears its input
box / interrupts a running turn; set to nil if that ever bites."
  :type 'boolean :group 'claude-mac)

(defun claude-mac--machine ()
  "Return the active machine entry (NAME . PLIST), erroring if undefined."
  (or (assq claude-mac-active-machine claude-mac-machines)
      (user-error "No machine named `%s' in claude-mac-machines"
                  claude-mac-active-machine)))

(defun claude-mac--buffer-name (name)
  "Connection buffer name for machine NAME."
  (format "*claude-mac[%s]*" name))

(defun claude-mac--host (machine)
  "Host for MACHINE: explicit :host, else $CLAUDE_MAC_<NAME>_HOST."
  (let ((env (format "CLAUDE_MAC_%s_HOST" (upcase (symbol-name (car machine))))))
    (or (plist-get (cdr machine) :host)
        (getenv env)
        (user-error "No host for `%s': (setenv \"%s\" \"<ip>\") in local.el"
                    (car machine) env))))

(defun claude-mac--command (machine)
  "Build the mosh command attaching to MACHINE's Emacs daemon.
No locale prefix: init.el sets LANG=en_US.UTF-8 in Emacs's environment
on Android, vterm passes it to this process, mosh forwards it to the
remote.  (A bare LANG=... prefix would break anyway: vterm runs this
string via `exec', which takes a program, not shell grammar.)
COLORTERM=truecolor gives the remote tty frame 24-bit colors."
  (let ((p (cdr machine)))
    (concat
     "mosh"
     " --ssh=\"ssh -i " (plist-get p :ssh-key) "\""
     " " (plist-get p :user) "@" (claude-mac--host machine)
     " -- bash -l -c 'COLORTERM=truecolor "
     (or (plist-get p :emacsclient) "emacsclient") " -t'")))

;;; Keyboard passthrough ------------------------------------------------

(defun claude-mac--make-sender (keystr)
  "Return a command that sends KEYSTR (\"C-c\", \"M-x\", ...) to vterm."
  (let ((ctrl (string-prefix-p "C-" keystr))
        (meta (string-prefix-p "M-" keystr))
        (base (substring keystr 2)))
    (lambda ()
      (interactive)
      (vterm-send-key base nil meta ctrl))))

(defvar claude-mac-passthrough-mode-map
  (let ((map (make-sparse-keymap)))
    ;; forward the keys vterm normally keeps for itself
    (dolist (k vterm-keymap-exceptions)
      (define-key map (kbd k) (claude-mac--make-sender k)))
    ;; the one local key: release the keyboard
    (define-key map (kbd claude-mac-toggle-key) #'claude-mac-passthrough-mode)
    map)
  "Keymap forwarding vterm's exception keys to the remote.")

;; highest precedence, above evil's state maps
(add-to-list 'emulation-mode-map-alists
             `((claude-mac-passthrough-mode . ,claude-mac-passthrough-mode-map)))

(define-minor-mode claude-mac-passthrough-mode
  "Hand the whole keyboard to the remote Emacs.
Only `claude-mac-toggle-key' stays local."
  :lighter " [→REMOTE]"
  (unless (derived-mode-p 'vterm-mode)
    (setq claude-mac-passthrough-mode nil)
    (user-error "claude-mac-passthrough-mode only works in vterm buffers"))
  (if claude-mac-passthrough-mode
      (progn
        (setq claude-mac--blocked nil)
        (when (bound-and-true-p evil-local-mode)
          (evil-emacs-state))
        ;; fresh handover on BOTH sides: drop any queued local keys so they
        ;; cannot leak through to the Mac, then flush the remote of pending
        ;; prefix/partial sequences before the first forwarded key
        (when claude-mac-flush-escape
          (discard-input)
          (ignore-errors (vterm-send-escape)))
        (message "Keyboard → %s (release: %s or toolbar)"
                 claude-mac-active-machine claude-mac-toggle-key))
    ;; releasing: same both-sides flush on the way out -- remote left clean
    ;; (not mid-sequence), local queue dropped so trailing keys do not spill,
    ;; and local evil lands FRESH in normal state (the Android-side ESC)
    (when claude-mac-flush-escape
      (ignore-errors (vterm-send-escape))
      (discard-input))
    (when (bound-and-true-p evil-local-mode)
      (evil-force-normal-state))
    ;; keyboard is local now: the buffer becomes a pure VIEWER (see
    ;; `claude-mac--blocked-key') -- nothing reaches the remote
    (setq claude-mac--blocked claude-mac-mode)
    ;; ... and you are DONE here: hop back to the workspace you came from,
    ;; leaving the claude window undisturbed in its own workspace
    (let ((ws (and claude-mac-mode (claude-mac--leave-workspace))))
      (if ws
          (message "Keyboard → local · back to %s (claude-mac waits in %s)"
                   ws claude-mac-workspace-name)
        (message "Keyboard → local Android Emacs (buffer is view-only)")))))

;;; Blocked state: passthrough off => NOTHING reaches the remote ----------

(defvar-local claude-mac--blocked nil
  "Non-nil while the keyboard is local in a claude-mac buffer.
Activates `claude-mac--blocked-map' so no key reaches the remote.")

(defun claude-mac--blocked-key ()
  "Swallow a key that would have gone to the remote; say how to type.
With passthrough off, HALF a keyboard is worse than none: plain keys
\(i, SPC, letters) would reach the remote through vterm's insert
bindings while the exception keys (ESC, C-x, M-x ...) stay local --
so you can poke the remote Emacs by accident but cannot send the ESC
to fix it.  Blocked means blocked: the buffer is a pure viewer until
you hand the keyboard over."
  (interactive)
  (message "Keys are LOCAL — %s (or toolbar) hands the keyboard to %s"
           claude-mac-toggle-key claude-mac-active-machine))

(defvar claude-mac--blocked-map
  (let ((map (make-sparse-keymap)))
    ;; stub by COMMAND REMAP, not by key: whatever key or evil state routes
    ;; to a vterm send command, the stub catches it -- robust against
    ;; evil-collection's rebinds and future vterm bindings
    (dolist (cmd '(vterm--self-insert vterm-send-return vterm-send-tab
                   vterm-send-space vterm-send-backspace vterm-send-delete
                   vterm-send-escape vterm-send-up vterm-send-down
                   vterm-send-left vterm-send-right vterm-yank
                   vterm-yank-primary vterm-yank-pop vterm-send-next
                   vterm-send-prior vterm-clear vterm-undo))
      (define-key map (vector 'remap cmd) #'claude-mac--blocked-key))
    map)
  "Command remaps stubbing every vterm send command while blocked.")

(add-to-list 'emulation-mode-map-alists
             `((claude-mac--blocked . ,claude-mac--blocked-map)))

(defvar claude-mac-mode-map
  (let ((map (make-sparse-keymap)))
    ;; re-enter passthrough with the same key when it's off
    (define-key map (kbd claude-mac-toggle-key) #'claude-mac-passthrough-mode)
    map)
  "Keymap active in claude-mac buffers regardless of passthrough.")

(define-minor-mode claude-mac-mode
  "Marker mode for claude-mac connection buffers."
  :keymap claude-mac-mode-map
  ;; entering the mode with passthrough off starts blocked (viewer);
  ;; leaving the mode always unblocks
  (setq claude-mac--blocked
        (and claude-mac-mode (not claude-mac-passthrough-mode))))

;;; Dedicated workspace ---------------------------------------------------

(defvar claude-mac--previous-workspace nil
  "Workspace you were in before `claude-mac', to return to on release.")

(defun claude-mac--ensure-workspace ()
  "Switch to `claude-mac-workspace-name', remembering where you came from.
Creates the workspace on first use.  No-op without Doom workspaces."
  (when (and (fboundp '+workspace-current-name)
             (fboundp '+workspace-switch))
    (let ((cur (+workspace-current-name)))
      (unless (equal cur claude-mac-workspace-name)
        (setq claude-mac--previous-workspace cur)
        (+workspace-switch claude-mac-workspace-name t)))))

(defun claude-mac--leave-workspace ()
  "Return to the workspace you were in before `claude-mac'.
Falls back to the first other workspace if that one is gone.  Returns
the workspace name switched to, or nil when there is nowhere to go
\(ssh-claude is the only workspace, or no Doom workspaces) -- the
caller keeps its usual message then."
  (when (and (fboundp '+workspace-current-name)
             (fboundp '+workspace-switch)
             (equal (+workspace-current-name) claude-mac-workspace-name))
    (let* ((names (and (fboundp '+workspace-list-names)
                       (+workspace-list-names)))
           (target (if (member claude-mac--previous-workspace names)
                       claude-mac--previous-workspace
                     (seq-find (lambda (n)
                                 (not (equal n claude-mac-workspace-name)))
                               names))))
      (when target
        (+workspace-switch target)
        target))))

;;; Entry points ---------------------------------------------------------

;;;###autoload
(defun claude-mac ()
  "Open (or jump back to) the mosh window into the active machine.
Recreates the connection if it died.  Keyboard is handed over."
  (interactive)
  (claude-mac--ensure-workspace)
  (let* ((machine (claude-mac--machine))
         (bufname (claude-mac--buffer-name (car machine)))
         (buf (get-buffer bufname)))
    ;; dead connection -> start fresh
    (when (and buf (not (process-live-p (get-buffer-process buf))))
      (kill-buffer buf)
      (setq buf nil))
    (if buf
        (switch-to-buffer buf)
      (let* ((cmd (claude-mac--command machine))
             (vterm-shell cmd)
             (vterm-kill-buffer-on-exit nil)
             ;; same effect as typing "LANG=... LC_ALL=... mosh" in a shell,
             ;; injected at the env layer because vterm execs the command
             ;; (a bare LANG= prefix would die with "exec: LANG=...: not found")
             (vterm-environment (append '("LANG=en_US.UTF-8" "LC_ALL=en_US.UTF-8")
                                        vterm-environment)))
        (message "claude-mac[%s]: %s" (car machine) cmd)
        (setq buf (vterm bufname))))
    (when (fboundp 'persp-add-buffer)        ; buffer belongs to ssh-claude
      (ignore-errors (persp-add-buffer buf)))
    (delete-other-windows)
    (with-current-buffer buf
      (claude-mac-mode 1)
      (claude-mac-passthrough-mode 1))))

;;;###autoload
(defun claude-mac-toggle ()
  "Toolbar entry: jump into the active machine, or release the keyboard.
In a claude-mac buffer with passthrough on, turn passthrough off;
otherwise connect/jump to the active machine and turn it on."
  (interactive)
  (if (and claude-mac-mode claude-mac-passthrough-mode)
      (claude-mac-passthrough-mode -1)
    (claude-mac)))

;;;###autoload
(defun claude-mac-switch-machine (&optional name)
  "Make NAME the active machine; interactively, cycle to the next one.
With a prefix argument, pick the machine by name instead of cycling.
The connect/toggle buttons then target that machine."
  (interactive)
  (let* ((names (mapcar #'car claude-mac-machines))
         (next (cond (name name)
                     ((or current-prefix-arg (> (length names) 2))
                      (intern (completing-read
                               "Machine: " (mapcar #'symbol-name names) nil t)))
                     (t (or (cadr (memq claude-mac-active-machine names))
                            (car names))))))
    (unless (assq next claude-mac-machines)
      (user-error "No machine named `%s' in claude-mac-machines" next))
    (setq claude-mac-active-machine next)
    (message "claude-mac → %s (%s)"
             next (or (ignore-errors (claude-mac--host (assq next claude-mac-machines)))
                      "host unset — see local.el"))))

(provide 'claude-mac)
;;; claude-mac.el ends here
