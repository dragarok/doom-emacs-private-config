;;; cw-fix-live.el --- Reclaim the hijacked server socket + apply the
;;; background-aware attention update live, clearing stuck orange tints.
;;;
;;; A second (empty) Emacs daemon hijacked the default "server" socket, so
;;; every Claude hook event has been landing on the wrong Emacs -- freezing
;;; this Emacs's sessions orange and starving them of Stop/clear events.
;;; Load this IN THE EMACS THAT SHOWS THE ORANGE SESSIONS:
;;;     M-x load-file RET ~/.doom.d/lisp/cw-fix-live.el RET
;;; (or  M-: (load "~/.doom.d/lisp/cw-fix-live.el") RET )
;;; No restart; your frames and Claude sessions are untouched.

(require 'server)
(require 'cl-lib)

(let* ((pid (emacs-pid))
       (claude-bufs (cl-remove-if-not
                     (lambda (b) (string-prefix-p "*claude:" (buffer-name b)))
                     (buffer-list)))
       (n (length claude-bufs)))

  ;; 1) Reclaim the default "server" socket so Claude hooks reach THIS Emacs
  ;;    again (this does NOT restart Emacs or close your frames/buffers).
  (setq server-name "server")
  (ignore-errors (server-force-delete "server"))
  (ignore-errors (server-start nil t))   ; nil=start, t=don't prompt about clients

  ;; 2) Load the updated claude-workspace library from disk.
  (load (expand-file-name "lisp/claude-workspace.el" doom-user-dir) nil t)

  ;; 3) Hard-reset attention state on every Claude buffer -> clears the stuck
  ;;    orange (remove the tint face-remap, restore the real mode-line, zero
  ;;    the state) and re-harden against the bidi crash.
  (dolist (b claude-bufs)
    (with-current-buffer b
      (when (and (boundp 'claude-workspace--bg-cookie) claude-workspace--bg-cookie)
        (ignore-errors (face-remap-remove-relative claude-workspace--bg-cookie)))
      (setq-local claude-workspace--bg-cookie nil)
      (setq-local claude-workspace--tinted nil)
      (setq-local claude-workspace--needs-attention nil)
      (when (boundp 'claude-workspace--working-desc)
        (setq-local claude-workspace--working-desc nil))
      (when (and (boundp 'claude-workspace--saved-mode-line)
                 (not (eq claude-workspace--saved-mode-line :unset)))
        (setq-local mode-line-format claude-workspace--saved-mode-line)
        (setq-local claude-workspace--saved-mode-line :unset))
      (setq-local bidi-display-reordering nil)   ; crash hardening
      (when (fboundp 'claude-workspace--ghostel-redraw)
        (ignore-errors (claude-workspace--ghostel-redraw)))))

  ;; 4) Make sure the modes are on, adopt the sessions into the grid, refresh.
  (when (fboundp 'claude-workspace-attention-mode) (claude-workspace-attention-mode 1))
  (when (fboundp 'claude-workspace-pin-width-mode) (claude-workspace-pin-width-mode 1))
  ;; bind the new "expand session down" key live (also persisted in config.el)
  (when (and (fboundp 'map!) (fboundp 'claude-workspace-expand-down))
    (eval '(map! :leader :desc "Expand session ↓ into empty slot"
                 "v z" #'claude-workspace-expand-down)))
  (when (fboundp 'claude-workspace-adopt) (ignore-errors (claude-workspace-adopt nil)))
  (when (fboundp 'claude-workspace--refresh-attention)
    (ignore-errors (claude-workspace--refresh-attention)))

  (message "✅ claude-workspace: reclaimed server on Emacs pid %s · reset %d Claude buffer%s · new background-aware attention is live"
           pid n (if (= n 1) "" "s")))

;;; cw-fix-live.el ends here
