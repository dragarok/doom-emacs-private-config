;;; tty-clipboard.el --- Keep killing text working in tty frames -*- lexical-binding: t -*-

;;; Commentary:
;; Every kill in a terminal frame goes to the system clipboard through
;; clipetty (Doom's `:os (tty +osc)'), which writes an OSC 52 escape to
;; the tty named by SSH_TTY -- falling back to the frame's own terminal
;; only when SSH_TTY is unset.
;;
;; Under mosh that variable is a lie, and it is why `M-w' on a machine
;; reached through `claude-remote' answered with
;;
;;     Opening output file: Permission denied, /dev/pts/1
;;
;; mosh bootstraps over a REAL ssh login, so the shell mosh-server starts
;; inherits SSH_TTY from that login -- and then ssh exits, taking its pty
;; with it, while mosh-server carries on with a pty of its own.
;; `emacsclient -t' hands the stale value to the daemon as the frame's
;; environment, so clipetty spent every kill writing to a pty that no
;; longer existed.  devpts lets nobody create a file there, which is why
;; the error said "Permission denied" rather than "No such file".
;;
;; `claude-remote' now exports the truth on the way in (see
;; `claude-remote--ssh-tty-repair'), which fixes the connections it makes
;; itself.  This file is the other half, and covers the frames it did
;; not: a hand-rolled `mosh host -- emacsclient -t', a frame that was
;; already open when the fix landed, a tmux pane whose SSH_TTY outlived
;; its ssh session.  It points such a frame's SSH_TTY at the terminal the
;; frame is ACTUALLY on -- and, belt and braces, demotes a failed
;; clipboard write to a message, because a clipboard you cannot reach is
;; no reason for `M-w' to fail.
;;
;; Everything here is a no-op on a machine without clipetty (Android) and
;; on graphical frames.

;;; Code:

(require 'seq)

(defun tty-clipboard--live-tty-p (file)
  "Non-nil when FILE names a terminal device this process can write to.
A pty that has been closed fails the `file-exists-p' half; one belonging
to another login fails the `file-writable-p' half.  Either way it is not
somewhere to send an escape sequence."
  (and (stringp file)
       (not (string-empty-p file))
       (file-exists-p file)
       (file-writable-p file)))

(defun tty-clipboard-repair-ssh-tty (&optional frame)
  "Point FRAME's SSH_TTY at the terminal FRAME is really on.
Does nothing unless FRAME is a tty frame whose recorded SSH_TTY is dead,
so it is safe to call as often as you like -- and it is called on every
kill, for the frames that existed before this file was loaded.

Only a frame with an `environment' parameter of its own is touched, that
is, one made by `emacsclient'.  Without that parameter `getenv' never
reports an SSH_TTY for the frame in the first place (clipetty then uses
the frame's own terminal, which is the right answer already), and
inventing the parameter here would hide the whole of the daemon's
environment from everything else that reads it per-frame.

Returns the value it left SSH_TTY at, or nil when it changed nothing."
  (let ((frame (or frame (selected-frame))))
    (when (and (frame-live-p frame)
               (not (display-graphic-p frame)))
      (let ((env (frame-parameter frame 'environment)))
        (when (consp env)
          (let ((recorded (getenv "SSH_TTY" frame))
                (real (ignore-errors (terminal-name (frame-terminal frame)))))
            (when (and recorded
                       (not (equal recorded real))
                       (not (tty-clipboard--live-tty-p recorded)))
              (let* ((clean (seq-remove
                             (lambda (entry)
                               (and (stringp entry)
                                    (string-prefix-p "SSH_TTY=" entry)))
                             env))
                     ;; A terminal we cannot write to either (a detached
                     ;; frame, an odd terminal name) is no better than the
                     ;; stale one: drop SSH_TTY entirely and let clipetty
                     ;; fall back to the frame's terminal on its own.
                     (fixed (and (tty-clipboard--live-tty-p real) real)))
                (set-frame-parameter frame 'environment
                                     (if fixed
                                         (cons (concat "SSH_TTY=" fixed) clean)
                                       clean))
                fixed))))))))

(defun tty-clipboard--emit-a (fn string)
  "Repair SSH_TTY, then emit STRING with FN, and never signal.
FN is `clipetty--emit'.  `kill-new' calls the clipboard hook AFTER the
text is already in the kill ring, so an unreachable clipboard costs
nothing but this message -- while letting the error through aborts the
command that did the killing."
  (tty-clipboard-repair-ssh-tty)
  (with-demoted-errors "tty clipboard unreachable: %S"
    (funcall fn string)))

(with-eval-after-load 'clipetty
  (advice-add 'clipetty--emit :around #'tty-clipboard--emit-a))

;; New frames, both routes: `server-after-make-frame-hook' for the
;; emacsclient frames this is actually about, `tty-setup-hook' for a
;; terminal Emacs started directly.
(add-hook 'server-after-make-frame-hook #'tty-clipboard-repair-ssh-tty)
(add-hook 'tty-setup-hook #'tty-clipboard-repair-ssh-tty)

;; ...and the frames that are already open, so a config reload is enough
;; to fix a connection without dropping it.
(mapc #'tty-clipboard-repair-ssh-tty (frame-list))

(provide 'tty-clipboard)
;;; tty-clipboard.el ends here
