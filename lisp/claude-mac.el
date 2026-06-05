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
(declare-function evil-change-state "evil-core")
(defvar evil-state)

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

(defvar-local claude-mac--prev-evil-state nil
  "Evil state to restore when passthrough is turned off.")

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
        (when (bound-and-true-p evil-local-mode)
          (setq claude-mac--prev-evil-state evil-state)
          (evil-emacs-state))
        (message "Keyboard → %s (release: %s or toolbar)"
                 claude-mac-active-machine claude-mac-toggle-key))
    (when (bound-and-true-p evil-local-mode)
      (evil-change-state (or claude-mac--prev-evil-state 'normal)))
    (message "Keyboard → local Android Emacs")))

(defvar claude-mac-mode-map
  (let ((map (make-sparse-keymap)))
    ;; re-enter passthrough with the same key when it's off
    (define-key map (kbd claude-mac-toggle-key) #'claude-mac-passthrough-mode)
    map)
  "Keymap active in claude-mac buffers regardless of passthrough.")

(define-minor-mode claude-mac-mode
  "Marker mode for claude-mac connection buffers."
  :keymap claude-mac-mode-map)

;;; Entry points ---------------------------------------------------------

;;;###autoload
(defun claude-mac ()
  "Open (or jump back to) the mosh window into the active machine.
Recreates the connection if it died.  Keyboard is handed over."
  (interactive)
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
