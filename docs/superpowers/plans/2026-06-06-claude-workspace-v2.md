# claude-workspace v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite claude-workspace.el's machinery to "Isolation-First, Stock-Smallest, Force-Aware" per `docs/superpowers/specs/2026-06-06-claude-workspace-redesign-design.md`, keeping the UI identical.

**Architecture:** Stock smallest-window PTY geometry with width pinned at 115 (metric: `window-screen-lines`); persp isolation via master-claude-only buffer membership (NOT `persp-ignore-wconf` — it would break Doom workspace switching); two prompt-ward ghostel seams (relayout-tail force-snap, point-min clamp rescue); delete the device-ownership, resize-adaptation, and screen-bottom layers.

**Tech Stack:** Emacs Lisp, ghostel, persp-mode/Doom workspaces. Verification = byte-compile + live-daemon probes (no test framework exists for this window-management code; the spec's Phase gates are the tests).

**Deviation from spec:** `persp-ignore-wconf` frame parameter dropped (disables ALL workspace wconf restore on the frame — breaks SPC TAB / expand-to-project). F5 is covered by buffer-membership isolation + relayout-on-activate + tail snap + rescue net instead.

---

### Task 1: Rewrite the PTY owner (kill device-ownership sizing)

**Files:** Modify `lisp/claude-workspace.el` (the "Pinned terminal width" section)

- [ ] Replace `--user-frame`/`--track-user-frame`/`--adjust-window-size`/`--repin`/`--after-pty-resize`/`--last-pty-size`/`claude-workspace-pin-width-mode`/`pin-to-current-width`/`set-fixed-width`/`--saved-adjust-fn` with:

```elisp
(defvar-local claude-workspace--pty-size nil
  "(COLS . ROWS) last size this session's PTY was given, for logging/guard.")

(defun claude-workspace--window-screen-lines (w)
  "Rows W can actually display -- ghostel's own metric.
`window-screen-lines' (NOT `window-body-height') honors face-remap
`:height'; mixing metrics re-introduces window-shorter-than-screen
through the attention tint's face-remap."
  (with-selected-window w (floor (window-screen-lines))))

(defun claude-workspace--adjust-window-size (process windows)
  "Stock smallest-window sizing with the WIDTH pinned for Claude sessions.
Width: always `claude-workspace-fixed-width' -- width changes reflow the
TUI destructively. Height: smallest `window-screen-lines' across ALL
windows currently showing the buffer on ANY frame -- computed from
global state, never from the per-call WINDOWS argument, so the answer
is caller-independent (the F6 thrash lesson). Guard: while a
minibuffer is active, keep the previous size (ghostel's own rows-only
guard is bypassed for alt-screen apps like Claude)."
  (let ((buf (process-buffer process)))
    (if (and (buffer-live-p buf)
             (string-prefix-p "*claude:" (buffer-name buf))
             (integerp claude-workspace-fixed-width))
        (let* ((wins (get-buffer-window-list buf 'nomini t))
               (rows (and wins
                          (apply #'min (mapcar #'claude-workspace--window-screen-lines
                                               wins))))
               (cur (buffer-local-value 'claude-workspace--pty-size buf))
               (size (and rows (cons claude-workspace-fixed-width (max 1 rows)))))
          (cond
           ((null size) cur)                       ; not displayed: keep
           ((and cur (active-minibuffer-window)) cur)
           (t
            (unless (equal size cur)
              (claude-workspace--log "pty %s %s -> %s" (buffer-name buf) cur size)
              (with-current-buffer buf (setq claude-workspace--pty-size size)))
            size)))
      (window-adjust-process-window-size-smallest process windows))))

;; Always on -- no minor mode. ghostel's wrapper chains to the default value.
(setq-default window-adjust-process-window-size-function
              #'claude-workspace--adjust-window-size)
```

- [ ] Remove `claude-workspace--pinned` and every reference (harden-session-buffer, add-session); pinning is name-based now.
- [ ] Byte-compile gate: only the 3 known pre-existing warnings.

### Task 2: Delete the adaptation/screen-bottom layers, fix callers

**Files:** Modify `lisp/claude-workspace.el`

- [ ] Delete whole functions + their hook/advice registrations: `--show-screen-bottom` (+ `:after` advice), `--resnap-on-frame-resize` (+ `window-size-change-functions` hook), `--maybe-adapt` (+ hook), `--frame-mislaid-p`, `--adapt-frame`, `--track-user-frame` pre-command hook (done in Task 1).
- [ ] `--on-activate`: call `(claude-workspace--relayout)` directly when `--in-workspace-p` (was `--adapt-frame`).
- [ ] `--on-focus-change`: keep only `(claude-workspace--refresh-attention)` (drop the adapt call).
- [ ] `--snap-to-bottom`: delete the `recenter` fallback branch — ghostel seam only.
- [ ] Keep: `--rescue-clamped-windows` + `:before` advice; relayout's existing `--snap-to-bottom` tail calls.
- [ ] Byte-compile gate; grep-assert zero `recenter` and zero raw `set-window-start` in the file.

### Task 3: persp isolation (master-claude-only sessions)

**Files:** Modify `lisp/claude-workspace.el`

- [ ] Add and wire into `--add-session` (replacing the bare `persp-add-buffer`) and the refresh-session new-buffer site:

```elisp
(defun claude-workspace--claim-buffer (buf)
  "Make BUF a member of the master-claude persp ONLY (F5 root fix).
`persp-add-buffer-on-after-change-major-mode' auto-joins buffers to
whatever persp is current; a session leaked into another persp ends up
inside that persp's saved window-config, and persp's window-state-put
on Mac client open/close clamps it (\"Window too small to accommodate
state\")."
  (when (and (buffer-live-p buf) (fboundp 'persp-add-buffer))
    (ignore-errors
      (let ((target (and (fboundp 'persp-get-by-name)
                         (persp-get-by-name claude-workspace-name))))
        (when (and target (not (eq target :nil)))
          (persp-add-buffer buf target nil))
        (when (fboundp 'persp-persps)
          (dolist (p (persp-persps))
            (when (and p (not (equal (persp-name p) claude-workspace-name))
                       (memq buf (persp-buffers p)))
              (persp-remove-buffer buf p t t))))))))
```

- [ ] Byte-compile gate (add `declare-function`/`defvar` shims for persp symbols as needed).

### Task 4: zombie frame reaper + mode-hook hardening

**Files:** Modify `lisp/claude-workspace.el`

- [ ] Add (idle timer, never inside `delete-frame-functions`; conservative — minibuffer-only AND not the terminal's top frame):

```elisp
(defun claude-workspace--reap-zombie-frames ()
  "Delete minibuffer-only tty frames that are not their terminal's top frame.
persp's failed frame deactivations leave these behind (observed live);
their stranded windows feed `window--adjust-process-windows' and can
poison sizing. Conservative on purpose: a real frame always has a
non-minibuffer window."
  (dolist (f (frame-list))
    (when (and (frame-live-p f)
               (frame-parameter f 'tty)
               (not (eq f (ignore-errors (tty-top-frame (frame-terminal f)))))
               (= 1 (length (window-list f t)))
               (window-minibuffer-p (frame-root-window f)))
      (claude-workspace--log "reap zombie frame %s" (claude-workspace--frame-desc f))
      (ignore-errors (delete-frame f t)))))

(defvar claude-workspace--reaper-timer
  (run-with-idle-timer 30 t #'claude-workspace--reap-zombie-frames))
```

- [ ] Register hardening on mode hook so it lands before first GUI redisplay:

```elisp
(defun claude-workspace--harden-on-ghostel-mode ()
  (when (string-prefix-p "*claude:" (buffer-name))
    (claude-workspace--harden-session-buffer (current-buffer))))
(add-hook 'ghostel-mode-hook #'claude-workspace--harden-on-ghostel-mode)
```

- [ ] Byte-compile gate.

### Task 5: re-enable in config.el

**Files:** Modify `config.el:247-258`

- [ ] Replace the commented block with (no pin-width-mode — sizing is always-on at require):

```elisp
(unless IS-ANDROID
  (require 'claude-workspace)               ; v2: stock-smallest + width pin, always on
  (with-eval-after-load 'claude-code        ; chime/popup/auto-switch on input-wait
    (claude-workspace-attention-mode 1))
  (map! :leader :desc "Master Claude workspace" "o C" #'claude-workspace-transient)
  (map! :leader :desc "Switch Claude session"    "v x" #'claude-workspace-cycle-session)
  (map! :leader :desc "Jump to waiting Claude"    "v u" #'claude-workspace-jump-to-attention)
  (map! :leader :desc "Expand → project workspace" "v e" #'claude-workspace-expand-to-project)
  (map! :leader :desc "Collapse → master-claude"   "v m" #'claude-workspace-collapse)
  (map! :leader :desc "Expand session ↓ into empty slot" "v z" #'claude-workspace-expand-down))
```

### Task 6: load + Phase-0 gates in the live daemon

- [ ] Load into daemon; adopt the running session; verify with probes:
  (a) adjust fn installed as default; PTY = (115 . min-screen-lines) and matches the phone window;
  (b) apply a face-remap tint, confirm PTY rows still == `window-screen-lines` (metric gate);
  (c) `M-x`/transient: no pty-resize log entries (minibuffer guard gate);
  (d) no `pty` log churn with both frames open (F6 gate).
- [ ] Commit lisp/claude-workspace.el + config.el + plan.
- [ ] Hand off to user: keyboard flap ×20 on phone, Mac client open/close, grid + typing + scrolling.
