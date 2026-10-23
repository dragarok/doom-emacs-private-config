# Emacs Home — living inside Emacs on the phone

Emacs is the phone's home screen. This directory holds the small Android
app that makes that possible; the logic lives in `../lisp/emacs-home.el`.
Read this first when picking the work back up.

## Why it exists

Goal: live inside Emacs, and make River Flow (`rts-flow`) as effortless as
possible. The productivity notes in `../reference_notes/` show the same
failure on repeat since 2021: reviews die because clocking dies, and
clocking dies because nothing is clocked while you're scrolling or working.
So the rule for this project is **remove data entry, don't add rituals**.
Everything here either removes friction or collects data with no effort.

## What's built (Oct 2026)

| Piece | Where | What it does |
|---|---|---|
| Home button | `HomeActivity` | Brings Emacs forward, runs `(emacs-home-on-home)` → dashboard |
| App catalog | `Catalog` | Writes `apps.tsv` + `icons/` on every Home press (icons only re-rendered on app update) |
| App launching | `LaunchActivity` | Opens `emacs-home://launch/PKG/ACTIVITY`, only for real app-drawer entries |
| Floating clock | `FloatService` | Pill over every app + ongoing notification; buttons for the org clock |
| Foreground log | `FloatService` | Every app that comes to the front → `foreground.tsv` (Android usage events) |
| Dashboard | `emacs-home.el` | Clock line, All apps / Pin buttons, pinned icon rows |
| Launch log | `emacs-home.el` | Every launch from Emacs → `launches.tsv` |
| Toolbar widgets | `../lisp/android-launcher.el` | Older: Termux:Widget shortcuts via `org-protocol://emacs-cmd` (still works) |

### The floating pill

| State | Collapsed | Tapped open |
|---|---|---|
| Clocked | `● 42m Task` | Pause · Done · Cancel · Lock |
| Paused (resumable) | `‖` | `‖ Task` · Resume · Flow · Lock |
| Clean (done/cancelled/nothing) | `○` | Resume · Flow · Lock |
| Locked (games) | faint dot, touches pass through | — unlocks when Emacs is back in front |

- Drag the pill up/down to move it. Tap toggles open/closed.
- **Pause** = `org-clock-out` (keeps the task for Resume).
  **Resume** = `org-clock-in-last`.
  **Done** = `rts-flow-clock-out` — prompts, so it brings Emacs forward.
  **Cancel** = `rts-flow-cancel` only if River Flow picked the clocked task,
  else `org-clock-cancel`. **Flow** = `rts-flow` (brings Emacs forward).
- Marking the task DONE anywhere, or cancelling, forgets it → clean `○`.
  (Uses `org-state` in the hook: repeating habits are back to TODO by then.)
- **Lock** unlocks on Home immediately, or within ~10s of Emacs reaching
  the front any other way.

## How it fits together

```
 Emacs (org.gnu.emacs)                        Emacs Home app (dev.alok.emacshome)
 ─────────────────────                        ───────────────────────────────────
 org clock hooks → clock.tsv  ── FileObserver ──►  pill + notification
 emacs-home-clock-action      ◄── emacsclient ───  pill / notification buttons
 emacs-home-on-home           ◄── emacsclient ───  Home button
 reads apps.tsv, icons/       ◄── writes ────────  catalog on Home
 android-browse-url ──── emacs-home://launch ───►  starts the app
                                                    usage events → foreground.tsv
```

- **No HTTP server.** The app joins `sharedUserId="com.termux"` — the same
  Linux user (UID 10422) as Termux and Emacs — so it can run Emacs's own
  `libemacsclient.so` against Emacs's socket, and write into Termux's home.
- That works because all three are signed with **GNU Emacs's published
  keystore** (`java/emacs.keystore` in the Emacs source, password `emacs1`;
  local copy `~/Downloads/emacs.keystore`). `build.sh` signs with it.
- Emacs's sandbox can't list packages (`cmd package` returns nothing);
  the app does it.
- Data lives in `/data/data/com.termux/files/home/.emacs-home/`:
  `apps.tsv`, `icons/`, `pins.eld`, `clock.tsv`, `launches.tsv`,
  `foreground.tsv`.

## Build, install, revert

```sh
./build.sh install        # no Gradle; javac + d8 + aapt2 + apksigner, then adb install
                          # also grants overlay + usage-stats app-ops and notifications
adb shell cmd role add-role-holder android.app.role.HOME dev.alok.emacshome 0   # make it Home
adb shell cmd role add-role-holder android.app.role.HOME com.android.launcher3 0 # revert
```

Elisp changes reach the phone by `git pull` in its `~/.doom.d` (branch
`termux`) and reloading `lisp/emacs-home.el`.

## Developing against the phone over adb (hard-won)

- **Never type long forms with `adb shell input text`.** They get scrambled,
  or the minibuffer closes first and the text runs as evil keys on the
  dashboard. Instead: `adb push x.el /sdcard/Download/`, open `M-:` and type
  only `(load "/sdcard/Download/x.el")` in the **same** command.
- **Don't press Home right before `M-:`** — `emacs-home-on-home` aborts the
  minibuffer a moment later.
- Fast loop: load a throwaway eval listener (`make-network-process` on
  127.0.0.1:47000 that `read`s, `eval`s, `prin1`s a reply), `adb forward
  tcp:47000 tcp:47000`, and talk to it from the Mac. **Delete it afterwards**
  — any app on the phone could reach it.
- Test the clock on a throwaway org file in Emacs's cache dir, never real
  tasks; afterwards drop it from `org-clock-history` and delete it.
- Overlay windows with WRAP_CONTENT grow but don't shrink back: compact
  states use fixed sizes (`FloatService.relayout`). Emoji glyphs clip in
  the small pill — use plain characters.

## Next, in order (agreed, not started)

1. **Pause before distraction apps.** Mark some apps guarded (Instagram,
   YouTube, games). Launching one first asks "what for, and how long?",
   logs the answer, and nudges when the time is up. The launcher is the
   natural place: `emacs-home-open` already sees every launch.
2. **Pill button: send the Firefox page to Emacs** to read there.
3. Maybe: read `foreground.tsv` + `launches.tsv` into the daily review —
   where the day's phone time went, with nothing typed.
4. Maybe: infer River Flow context from Wi-Fi (home vs out) so `rts-flow`
   only asks for energy.

Known gaps: if Emacs itself fails to start there is no fallback app list
(Settings is still in the notification shade); pins can't be reordered.

Keep to the rule above: build one item, then live with it before the next.
