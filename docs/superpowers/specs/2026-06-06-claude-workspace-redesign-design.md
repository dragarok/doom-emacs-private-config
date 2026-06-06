# claude-workspace v2 — "Isolation-First, Stock-Smallest, Force-Aware"

Design approved by adversarial panel (3 designers × 2 critics × synthesis judge,
all claims verified against window.el / ghostel.el / persp-mode.el source).
Companion problem brief: `2026-06-06-claude-workspace-redesign-brief.md`
(failure catalog F1–F8 referenced throughout).

## User decisions (resolved)

1. **Width: pinned at 115 always.** Never reflows; phone (126 cols) fits it.
2. **Blank rows below the prompt on a too-tall window: acceptable** (matches the
   proven-good baseline behavior).
3. **Session buffers live ONLY in the master-claude persp** — never auto-join
   `main`. Required for the F5 root fix.

## Core thesis

The unmanaged baseline works flawlessly (F8) because of stock Emacs geometry:
the PTY follows the smallest window, so **no window is ever shorter than the
terminal screen** (F1 eliminated at the source). v2 keeps that geometry
untouched and layers grid / attention / commands on top. All per-device
height logic is deleted.

## PTY model

- Width: `claude-workspace-fixed-width` (115), constant, global, always on
  (no minor-mode toggle). Justification: stock `-smallest` minimizes width AND
  height independently (window.el:11343–11345); a narrow display would reflow
  the TUI destructively everywhere.
- Height: smallest **`window-screen-lines`** across all windows showing the
  buffer, computed from `(get-buffer-window-list buf 'nomini t)`, **ignoring
  the WINDOWS argument** (the arg is per-call; global state keeps the answer
  caller-independent — the F6 lesson).
  - **NOT `window-body-height`**: ghostel sizes via `window-screen-lines`
    (honors face-remap `:height`); mixing metrics re-introduces
    window-shorter-than-screen through the attention tint's face-remap.
    Metric: `(with-selected-window w (floor (window-screen-lines)))`, `min`
    reducer.
- Minibuffer guard: if height changed only because a minibuffer/transient is
  active on the requesting frame (width unchanged), return the last-applied
  size. (ghostel's own rows-only guard is disabled for alt-screen apps —
  ghostel.el:6786–6789 — and Claude is alt-screen, so without this guard every
  vertico/M-x/transient open+close on the phone is a full TUI SIGWINCH.)
- Installed via `setq-default window-adjust-process-window-size-function`;
  ghostel's wrapper chains to the default value (ghostel.el:6763).
- No hysteresis, no debounce, no repin: sizing is reactive, stock-driven.

## Isolation layer (the F5 root fix)

- Set frame parameter `persp-ignore-wconf` on every grid-hosting frame —
  persp's stock window-conf restore honors it (no advice, no new hook).
- Session buffers join the master-claude persp ONLY: spawn/adopt call
  `persp-add-buffer` targeting master-claude explicitly and must counteract
  `persp-add-buffer-on-after-change-major-mode t` (config.el:366) so `main`'s
  saved wconf never contains session windows. This closes the
  "Window too small to accommodate state" clamp on Mac client open/close.
- Frame reaper: an idle-timer (never synchronous inside
  `delete-frame-functions`, which persp also occupies) deletes frames whose
  tty device is dead OR which are minibuffer-only AND not their terminal's
  live top frame. Conservative by design: must never race a mosh reconnect.
- `--harden-session-buffer` (jit-lock/emojify kill, bidi off, F4) moves to
  `ghostel-mode-hook` so it lands before first GUI redisplay; consolidate with
  the existing bidi hook in config.el to avoid duplicates.

## Surviving ghostel seams (exactly two window-start writers, both prompt-ward)

1. **Relayout-tail force-snap.** `ghostel--reshow-snap` auto-anchors on
   `set-window-buffer` but schedules a plain invalidate whose redraw body is
   skipped during DEC 2026 sync (ghostel.el:6606–6607). After relayout's
   `set-window-buffer` calls, for each managed cell:
   `cl-pushnew win ghostel--windows-needing-snap`,
   `assq-delete-all win ghostel--scroll-positions`,
   `setq ghostel--force-next-redraw t`, `ghostel--invalidate`. (~5 lines.)
2. **Point-min clamp rescue** (`:before ghostel--delayed-redraw`): unchanged
   guard — char/semi-char input mode, `(> (point-max) 2000)`,
   `(= (window-start w) (point-min))` — push through the snap seam with
   force-next-redraw. Needed because ghostel's mangle-corrector only iterates
   windows present at the PRIOR redraw (ghostel.el:6551): a freshly
   persp-restored window cannot self-heal, and a laundered banner clamp
   (F2) passes ghostel's own mangled test. Candidate for deletion after the
   Phase 5 soak proves zero firings.

No `recenter`, no raw `set-window-start`, no `:after` redraw advice, anywhere.

## Components

**KEEP verbatim** (orthogonal to sizing): session registry
(`--sessions/--add-session/--prune/--capacity/--set-frame-session/--frame-session`),
spawn/adopt/picker, grid math (`--auto-dims/--grid-windows/--visible-cells/
--placeholder`), paging & commands (`--page-by`, `cycle-session`, pages,
`set-layout`, `kill-slot`, `reset`, `refresh-session`, `expand-down`,
`expand-to-project`, `collapse`, magit/dired helpers), the entire attention
system (events, tints, badges, jump, chime, popup, submit-clear), transient
menu, debug logging.

**REWRITE:**
- `--adjust-window-size`: width-pin + global smallest via `window-screen-lines`
  + minibuffer guard; ignore WINDOWS arg.
- `--snap-to-bottom`: ghostel seam only (drop the `recenter` fallback);
  used at the relayout tail.
- `--relayout` / `--on-activate`: relayout fires from
  `persp-activated-functions` and explicit commands ONLY; tail force-snap.
- persp isolation + frame reaper: new, as above.

**DELETE** (with the proven reason):
- `--user-frame`, `--track-user-frame`, `pre-command-hook` entry — caused the
  PTY thrash (F6).
- `--show-screen-bottom` + `:after` advice — dead code under smallest sizing
  (its predicate `window < term-rows` is unsatisfiable when term-rows is the
  min), and the only raw `set-window-start` (F3 violation).
- `--resnap-on-frame-resize` + `window-size-change` hook — keyboard resizes
  now flow through ghostel's native resize handler (F7).
- `--maybe-adapt`, `--frame-mislaid-p`, `--adapt-frame`, resize-triggered
  relayout — relayout is persp/command-driven only.
- `--repin`, `--after-pty-resize`, `--last-pty-size` — sizing is reactive.
- `claude-workspace-pin-width-mode` toggle + `pin-to-current-width` +
  `set-fixed-width` + `--saved-adjust-fn` + `--pinned` — pinning is
  unconditional.
- `--on-focus-change` relayout path (attention refresh stays in
  `--note-selection`).
- `--keep-managed-anchored` / always-anchor variants — already removed; never
  reintroduce (breaks scrollback reading).

**Size:** ~750–850 lines (from 2051).

## Hot-event walkthroughs

- **Phone keyboard flap:** tty SIGWINCH → stock adjust path → owner returns
  (115 . new-min-screen-lines) → ghostel's native resize redraw re-anchors all
  windows. Zero claude-workspace code beyond the size computation. Identical
  to the baseline.
- **Device switch:** nothing happens (no ownership). Paging anchor and tints
  update via `--note-selection` bookkeeping only.
- **Mac client open:** frame lands in `main`; `persp-ignore-wconf` suppresses
  the window-state restore; `main` contains no session buffers (decision 3) so
  nothing can clamp. Switching to master-claude fires relayout + tail
  force-snap. Idle reaper clears any dead-tty zombie later.
- **14-agent storm:** streaming never fires the adjust path; tints are
  face-remap flips; the only window-start writers are the two seams, both of
  which only move windows toward the prompt.

## Phased implementation (each phase gated by live-daemon measurement)

- **Phase 0 — prove the spine (claude-workspace still disabled).** ~40-line
  prototype: the new adjust fn + `persp-ignore-wconf` on the Mac frame.
  Gates: (a) Mac+phone, keyboard ×20 — prompt visible both sides, no clamp;
  (b) with a face-remap tint active, PTY rows == what the window shows
  (validates the screen-lines metric); (c) Mac client open/close ×10 — zero
  "too small" clamps, no leaked frames; (d) no PTY thrash in the log.
  **Failure of (a) or (c) stops the project.**
- **Phase 1 — isolation layer.** persp param + buffer ownership + reaper +
  mode-hook hardening. Gate: mosh reconnect ×10 and Mac open/close ×10 with a
  transient open on the phone — live frames never reaped, no clamps.
- **Phase 2 — PTY owner final.** Gate: vertico/transient ×20 on the phone with
  no TUI repaint; keyboard ×20 native-smooth.
- **Phase 3 — grid + relayout + tail snap.** Gate: relayout DURING an active
  DEC-2026 streaming storm anchors every cell to the live prompt (idle-only
  testing is a known false pass).
- **Phase 4 — attention port.** Gate: 14-agent storm + phone + Mac; rescue log
  fires only on genuine point-min clamps.
- **Phase 5 — soak.** A full day, debug log on. Zero rescue firings → consider
  deleting the rescue net. Grep-assert: no `recenter`/raw `set-window-start`
  outside the seams.

## Out of scope

Per-display geometry (candidate D), live tiles freezing, tmux-style
multi-size mirroring — revisit only if the soak surfaces the cosmetic
blank-rows issue as a real annoyance.
