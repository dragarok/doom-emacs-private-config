# claude-workspace redesign brief (problem spec for design agents)

## Mission

Redesign the architecture of `~/.doom.d/lisp/claude-workspace.el` (a multi-session
Claude Code grid manager for Emacs) so it is RELIABLE. The UI must stay the same;
the machinery underneath is fully negotiable.

## Required UI (non-negotiable, user's words: "The ui needs to be like now")

1. **Phone** (Android, mosh -> `emacsclient -t` into the Mac daemon): ONE live
   session fullscreen at a time; cycle between sessions; type reliably; the
   prompt must be visible while typing (soft keyboard resizes the tty frame
   constantly).
2. **Mac GUI / PC** (big displays): a GRID of LIVE terminal windows, several
   sessions visible at once (2x2 on Mac, up to 8 on PC), paging.
3. **Attention system**: sessions waiting for input tint orange + mode-line
   badge; jump-to-attention command. Driven by Claude CLI hooks (emacsclient
   events: pretooluse, permission, stop, userpromptsubmit...).
4. Expand a session into its project workspace and collapse back (persp/Doom
   workspaces).
5. All of this SIMULTANEOUSLY: Mac client open + phone connected is the primary
   failing scenario that must work.

## Environment

- Emacs 31.0.60 (development build) daemon on macOS. Frames: Mac GUI client
  (opened/closed often), phone tty over mosh (frame size flaps: 126x63 <->
  ~126x40 with soft keyboard, occasionally 91 rows portrait), PC ssh tty.
- Terminal backend: **ghostel.el** (libghostty-based), at
  `/Users/alokregmi/.config/emacs/.local/straight/build-31.0.60/ghostel/ghostel.el`.
  Sessions are `*claude:...*` buffers running the Claude Code TUI (full-screen
  redraws, DEC 2026 synchronized output, repetitive box-drawing content).
- Doom Emacs, evil-mode, persp-mode (+workspaces), emojify-mode global.
- Current implementation (read it): `/Users/alokregmi/.doom.d/lisp/claude-workspace.el`
  (~1800 lines, contains all accumulated fixes; currently DISABLED in config.el).

## The failure catalog (each item was PROVEN live; any design must survive all)

F1. **One PTY size per session.** A window SHORTER than the terminal screen puts
    the prompt below the window's bottom edge (ghostel anchors windows at the
    viewport TOP: `ghostel--anchor-window` sets window-start = viewport-start).
    A window TALLER than the screen is benign. Stock Emacs sizes the PTY to the
    SMALLEST window, which guarantees no window is ever shorter than the screen.

F2. **ghostel scroll classification is fragile for mismatched windows.** Windows
    with window-start/point behind the anchor are classified "user-scrolled" and
    restored by 3-line content keys searched FIRST-MATCH from point-min. Claude's
    TUI content repeats heavily, so restores walk windows toward the top. A clamp
    to point-min gets LAUNDERED: the captured key (welcome banner) genuinely
    matches at point-min, so ghostel's own mangle-detector sees a legitimate
    scroll position and faithfully re-pins the window to the top forever.

F3. **Never reposition ghostel windows from outside.** `recenter`/`set-window-start`
    poisons classification. The sanctioned seam: push the window onto buffer-local
    `ghostel--windows-needing-snap`, set `ghostel--force-next-redraw` t (else DEC
    2026 sync-output skips the redraw body during streaming), call
    `ghostel--invalidate`.

F4. **emojify-mode/jit-lock in terminal buffers can crash redisplay on GUI frames**
    (`args-out-of-range` during jit-lock-function -> aborted window updates).
    Observed once; severity debated; the fix (disable jit-lock in session buffers)
    is cheap and already written.

F5. **persp-mode clamps windows.** On every Mac client frame open/close it
    restores saved window-states into session windows and fails ("Window too
    small to accommodate state"), leaving windows at point-min; zombie frames
    accumulate on the phone tty (a minibuffer-only invisible frame was observed;
    only `tty-top-frame` is what the phone actually displays).

F6. **`window-adjust-process-window-size-function` is invoked PER FRAME with only
    that frame's windows.** Any size logic keyed on the passed list gives
    different answers per caller and the PTY thrashes (observed 35<->61 SIGWINCH
    storms). Size must be computed from global state.

F7. **The Android keyboard is a frame-resize storm generator.** Every show/hide
    is a tty SIGWINCH. Whatever the design, this path is hot.

F8. **Ground truth: with claude-workspace DISABLED everything works flawlessly**
    (phone + Mac simultaneously). With it enabled (any of today's variants) the
    phone clamps to the top. The unmanaged configuration is the reliability bar.

## Candidate architectures (seed list — improve, combine, or reject with reasons)

A. **Layout-only manager.** Never touch PTY sizing at all (keep stock
   smallest-window behavior, maybe not even width pinning). claude-workspace only
   arranges windows (grid), runs the attention system, and provides commands.
   Risk: smallest window = a 35-row grid cell while the phone shows the session
   -> phone is taller (benign per F1) BUT phone-with-keyboard (~30 rows) becomes
   the smallest -> all grid cells view a 30-row screen (taller, benign). Width
   reflow between displays may garble the TUI (the original reason width pinning
   exists) — evaluate whether width pinning alone is safe.

B. **Width-pin only + layout + attention.** Like A but pin width at 115 columns
   (heights stock/smallest). Evaluate F6 compliance and what happens during
   keyboard flaps.

C. **Height follows the active device** (today's design): PTY height tracks the
   frame the user last typed on; other displays view tolerantly (windows shorter
   than screen show the screen BOTTOM via a post-redraw adjustment). More moving
   parts; transition bugs were rampant today, but several had other root causes.

D. **Exclusive geometry ownership:** session live on one display at a time;
   other displays show a frozen placeholder tile until focused. UI looks the same
   at rest; tiles of phone-held sessions are stale.

## Deliverable from each design agent

1. A recommended architecture (may be a hybrid), described concretely:
   what code exists, what hooks/advice are installed, what happens on each
   event (keyboard flap, device switch, Mac client open, persp restore, agent
   output storm).
2. A table: F1..F8, how the design survives each.
3. What gets DELETED from the current claude-workspace.el.
4. Top 3 risks and how to verify them empirically before full implementation.
5. Lines-of-code estimate and a phased implementation order.
