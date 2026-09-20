;;; tty-clipboard.el --- Keep killing text working in tty frames -*- lexical-binding: t -*-

;;; Commentary:
;; `M-w' on a machine reached through `claude-remote' used to fail with
;;
;;     Opening output file: Permission denied, /dev/pts/1
;;
;; A wrong path, nothing deeper.  clipetty (Doom's `:os (tty +osc)') sends
;; every kill to the system clipboard as an OSC 52 escape, written to the tty
;; SSH_TTY names -- and mosh leaves SSH_TTY pointing at the pty of the ssh
;; login it bootstrapped over, which is gone by the time you have a prompt.
;; devpts lets nobody create a file there, hence "Permission denied" rather
;; than "No such file".
;;
;; `claude-remote--ssh-tty-repair' fixes that where it starts, by exporting
;; the real tty before emacsclient inherits it.  This file is only the safety
;; net for frames that came from somewhere else.

;;; Code:

(with-eval-after-load 'clipetty
  (define-advice clipetty--tty (:around (fn ssh-tty tmux) tty-clipboard-live)
    "Use the frame's own terminal when SSH_TTY names one we cannot write to.
A pty that died with its ssh session fails `file-writable-p'; the frame is
by definition sitting on a terminal that does not."
    (let ((tty (funcall fn ssh-tty tmux)))
      (if (and tty (file-writable-p tty)) tty (terminal-name))))

  (define-advice clipetty--emit (:around (fn string) tty-clipboard-demote)
    "Never let an unreachable clipboard abort the kill that triggered it.
`kill-new' calls the clipboard hook once the text is already in the kill
ring, so a failure here costs nothing but this message."
    (with-demoted-errors "tty clipboard unreachable: %S"
      (funcall fn string))))

(provide 'tty-clipboard)
;;; tty-clipboard.el ends here
