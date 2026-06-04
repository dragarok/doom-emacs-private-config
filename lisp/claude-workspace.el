;;; claude-workspace.el --- Multi-project Claude session workspace -*- lexical-binding: t; -*-

;; Author: Roger Parkinson
;; Keywords: tools, processes, convenience
;; Package-Requires: ((emacs "28.1") (claude-code "0") (transient "0.4"))

;;; Commentary:

;; A "master Claude" Doom workspace that hosts many `claude-code.el'
;; terminal sessions in a single on-screen grid, across one or more
;; projectile projects, and never lets a session sit waiting unnoticed.
;;
;; Highlights:
;;   - One dedicated workspace ("master-claude") with a tiled grid of
;;     live Claude sessions.  Sessions are an ordered list (capacity
;;     `claude-workspace-max-sessions', default 6); the grid shows as many
;;     as the *current display* sensibly fits and pages through the rest.
;;   - ADAPTIVE layout: big external monitor -> 3x2 (6); laptop screen ->
;;     2 side-by-side; SSH/tty/Android -> 2 stacked.  Re-adapts on the fly
;;     when you move the frame between displays.
;;   - ADD sessions by picking projectile project(s) (vertico /
;;     completing-read-multiple), N at a time, multiple instances per
;;     project.  Start with 2 today, add 4 more later -- empty cells stay
;;     reserved as placeholders.
;;   - ADOPT already-running sessions (started elsewhere) into the grid.
;;   - From any session: jump to THAT project's Magit/Dired.
;;   - ATTENTION: when a session finishes and awaits input it chimes, shows
;;     a big popup, and (optionally) yanks you to that session.
;;   - REFRESH: if a terminal gets garbled by a resize, kill it and restart
;;     `claude --continue' in place, same slot, same conversation.
;;
;; Built on public-ish seams of claude-code.el: sessions are placed by
;; binding `claude-code-display-window-fn' to a no-op while spawning, then
;; laying out the grid ourselves; instance names are assigned without
;; prompting by overriding `claude-code--prompt-for-instance-name'; a
;; session's project root is recovered from its `*claude:/path/:instance*'
;; buffer name.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'transient)

;; claude-code.el internals we lean on (loaded lazily before use).
(declare-function claude-code--start "claude-code")
(declare-function claude-code--buffer-name "claude-code")
(declare-function claude-code--find-all-claude-buffers "claude-code")
(declare-function claude-code--find-claude-buffers-for-directory "claude-code")
(declare-function claude-code--extract-instance-name-from-buffer-name "claude-code")
(declare-function claude-code--extract-directory-from-buffer-name "claude-code")
(declare-function claude-code--prompt-for-instance-name "claude-code")
(declare-function claude-code-default-notification "claude-code")
(declare-function claude-code--pulse-modeline "claude-code")
(defvar claude-code-display-window-fn)
(defvar claude-code-toggle-auto-select)
(defvar claude-code-confirm-kill)
(defvar claude-code-notification-function)
(defvar claude-code-enable-notifications)
(defvar ghostel-full-redraw)
(defvar ghostel--process)
(defvar ghostel--force-next-redraw)
(declare-function ghostel--window-adjust-process-window-size "ghostel")
(declare-function ghostel--delayed-redraw "ghostel")

;; Doom workspace (persp-mode) API.
(declare-function +workspace-current-name "ignore")
(declare-function +workspace-switch "ignore")
(declare-function persp-add-buffer "persp-mode")

;; projectile / magit.
(declare-function projectile-relevant-known-projects "projectile")
(declare-function magit-status-setup-buffer "magit-status")


;;;; Customization

(defgroup claude-workspace nil
  "A dedicated workspace hosting many Claude sessions in an adaptive grid."
  :group 'tools
  :prefix "claude-workspace-")

(defcustom claude-workspace-name "master-claude"
  "Name of the dedicated Doom workspace that holds the Claude grid."
  :type 'string)

(defcustom claude-workspace-max-sessions 12
  "Maximum number of Claude sessions the grid manages at once.
With a narrow fixed width a big monitor can show many sessions, so this is
higher than the classic 6."
  :type 'integer)

(defcustom claude-workspace-grid-max-cols 6
  "Maximum number of grid columns (on the widest display)."
  :type 'integer)

(defcustom claude-workspace-grid-max-rows 2
  "Maximum number of grid rows (on the tallest display).
Capped at 2 because 3 stacked terminals are too short to be usable."
  :type 'integer)

(defcustom claude-workspace-fixed-width 115
  "Fixed column width every managed Claude terminal is pinned to.

This is the heart of the multi-display strategy: Claude's TUI corrupts when
its width changes (each SIGWINCH forces a full, uncleared redraw).  Emacs
normally sizes a terminal to the SMALLEST window showing it, so opening the
same session on a narrow phone shrinks it everywhere.  By pinning the width
\(see `claude-workspace-pin-width-mode'), the terminal renders identically
on every display and never reflows.

Also used as the per-cell column budget when choosing how many grid columns
fit: a wide monitor fits several fixed-width sessions side by side, a phone
fits one.  Set this to your narrowest display's width (run
`claude-workspace-pin-to-current-width' on your phone) so it is readable
everywhere."
  :type 'integer)

(defcustom claude-workspace-min-cell-height 22
  "Minimum lines each Claude session needs to be usable.
The grid never makes a cell shorter than this; a short screen gets fewer
rows."
  :type 'integer)

(defcustom claude-workspace-single-on-tty t
  "When non-nil, text-terminal frames (SSH from a phone, Termux, -nw) show a
single full-screen session instead of a grid.  Page between sessions with
`claude-workspace-next-page' / `claude-workspace-prev-page'.  This is what
you want on a phone: one Claude, full width, never a cramped grid."
  :type 'boolean)

(defcustom claude-workspace-force-dims nil
  "When non-nil, override automatic display detection with (COLS . ROWS)."
  :type '(choice (const :tag "Automatic" nil)
                 (cons integer integer)))

(defcustom claude-workspace-adopt-on-open t
  "When non-nil, `claude-workspace-open' pulls any already-running Claude
sessions that are not yet on the grid into free slots."
  :type 'boolean)

(defcustom claude-workspace-auto-relayout-on-resize t
  "When non-nil, re-tile the grid when the frame moves to a display whose
size class differs (e.g. laptop <-> external monitor)."
  :type 'boolean)

(defcustom claude-workspace-robust-redraw t
  "When non-nil, force ghostel full redraws in managed sessions.
This is documented as more robust with TUI apps like Claude Code and
helps avoid the resize/overflow corruption, at some CPU cost."
  :type 'boolean)


;;;; Session state

(defvar claude-workspace--sessions nil
  "Ordered list of live Claude buffers managed by the grid.
Position in this list maps to grid position (row-major, paged).")

(defvar claude-workspace--page 0
  "Current page index when there are more sessions than visible cells.")

(defvar claude-workspace--last-session nil
  "The most recently selected managed session buffer.
The grid pages so this session is always visible -- so a phone (one cell)
shows the active session, never an empty placeholder.")

(defvar claude-workspace--last-applied-dims nil
  "The (COLS . ROWS) most recently laid out, used to avoid needless rebuilds.")

(defvar claude-workspace--adapt-pending nil
  "Non-nil while a deferred auto-relayout is already scheduled.")

(defvar-local claude-workspace--pinned nil
  "Non-nil in a managed Claude buffer whose terminal width is pinned.")

(defvar claude-workspace--saved-adjust-fn nil
  "Saved global `window-adjust-process-window-size-function'.")

(defun claude-workspace--capacity ()
  "Maximum number of sessions the grid will hold."
  (min claude-workspace-max-sessions
       (* claude-workspace-grid-max-cols claude-workspace-grid-max-rows)))

(defun claude-workspace--prune ()
  "Drop dead buffers from the session list; keep `--page' an integer."
  (setq claude-workspace--sessions
        (cl-remove-if-not #'buffer-live-p claude-workspace--sessions))
  (unless (integerp claude-workspace--page)
    (setq claude-workspace--page 0)))

(defun claude-workspace--free-count ()
  "How many more sessions can be added before reaching capacity."
  (claude-workspace--prune)
  (max 0 (- (claude-workspace--capacity)
            (length claude-workspace--sessions))))

(defun claude-workspace--harden-session-buffer (buf)
  "Apply robustness settings to managed session buffer BUF."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (when (and claude-workspace-robust-redraw (boundp 'ghostel-full-redraw))
        (setq-local ghostel-full-redraw t))
      ;; Stop the bidi reordering engine from ABORTING Emacs while it draws
      ;; the TUI.  Every recorded crash here is `emacs_abort' inside the bidi
      ;; resolver during redisplay of streaming terminal output -- and it
      ;; persisted with `bidi-inhibit-bpa' and a left-to-right base already on
      ;; (Doom sets both globally).  Turning reordering off keeps redisplay out
      ;; of the resolver entirely; terminal text is grid-positioned and
      ;; left-to-right, so logical order == visual order and nothing is lost.
      ;; (Also set via `ghostel-mode-hook'; mirrored here so already-open
      ;; sessions are hardened the moment the grid re-hardens them.)
      (setq-local bidi-display-reordering nil)
      ;; mark for width pinning so the adjust function recognises it
      (when (bound-and-true-p claude-workspace-pin-width-mode)
        (setq claude-workspace--pinned t)))))

(defun claude-workspace--add-session (buf)
  "Append BUF to the managed session list if room and not already present.
Returns non-nil if added."
  (when (and (buffer-live-p buf)
             (not (memq buf claude-workspace--sessions))
             (< (length claude-workspace--sessions) (claude-workspace--capacity)))
    (setq claude-workspace--sessions
          (append claude-workspace--sessions (list buf)))
    (claude-workspace--harden-session-buffer buf)
    (when (fboundp 'persp-add-buffer)
      (ignore-errors (persp-add-buffer buf)))
    t))


;;;; Adaptive grid dimensions

(defun claude-workspace--auto-dims ()
  "Return the (COLS . ROWS) grid for the current frame.
Columns are how many `claude-workspace-fixed-width' sessions fit across the
frame (a phone fits one, a monitor several); rows are how many
`claude-workspace-min-cell-height' tall cells fit.  Both are clamped to the
configured maxima.  Works for graphical and text-terminal frames alike."
  (cond
   (claude-workspace-force-dims claude-workspace-force-dims)
   ;; phone / SSH / -nw: one full-screen session, page through the rest
   ((and claude-workspace-single-on-tty (not (display-graphic-p)))
    '(1 . 1))
   (t (let* ((fw (frame-width))
             (fh (frame-height))
             (cols (max 1 (min claude-workspace-grid-max-cols
                               (/ fw (max 1 claude-workspace-fixed-width)))))
             (rows (max 1 (min claude-workspace-grid-max-rows
                               (/ fh (max 1 claude-workspace-min-cell-height))))))
        (cons cols rows)))))

(defun claude-workspace--visible-cells ()
  "Number of grid cells visible on the current display."
  (let ((d (claude-workspace--auto-dims)))
    (max 1 (* (car d) (cdr d)))))


;;;; Placeholders for empty cells

(defun claude-workspace--placeholder (i)
  "Return the placeholder buffer for empty cell I (0-based global index)."
  (let ((buf (get-buffer-create (format " *claude-slot-%d*" (1+ i)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "\n")
        (insert (propertize (format "    Claude slot %d\n" (1+ i)) 'face 'bold))
        (insert "\n")
        (insert (propertize "    · empty ·\n\n" 'face 'shadow))
        (insert (propertize "    Add a session with the workspace menu.\n"
                            'face 'shadow)))
      (setq buffer-read-only t)
      (setq-local mode-line-format
                  (list (format "  ☐ claude slot %d — empty" (1+ i)))))
    buf))


;;;; Grid layout

(defun claude-workspace--grid-windows (cols rows)
  "Split the selected frame into a COLS x ROWS grid.
Return the windows as a flat list in row-major order (top-left first).
Built COLUMNS-FIRST -- each column is an independent vertical stack -- so a
single cell can be grown taller than its row-mates (the foundation for
`claude-workspace-expand-down').  The balanced visual result is the usual
uniform grid; only the internal window tree differs from a rows-first split.
Starts from a real (non-minibuffer) window so it is safe to call when the
minibuffer is selected, e.g. `emacsclient -e'."
  ;; undedicate first: a leftover posframe/popup window makes
  ;; `delete-other-windows' error ("Window is dedicated to ...").
  (dolist (w (window-list nil 'no-minibuf))
    (set-window-dedicated-p w nil))
  (let ((base (if (window-minibuffer-p (selected-window))
                  (frame-first-window)
                (selected-window))))
    (select-window base)
    (delete-other-windows base))
  ;; split into COLUMNS (left -> right)
  (let ((coltops (list (selected-window))))
    (let ((w (selected-window)))
      (dotimes (_ (1- cols))
        (setq w (split-window w nil 'right))
        (push w coltops)))
    (setq coltops (nreverse coltops))
    ;; split each column into ROWS (top -> bottom); keep a per-column cell list
    (let ((columns '()))
      (dolist (cw coltops)
        (let ((cells (list cw))
              (w cw))
          (dotimes (_ (1- rows))
            (setq w (split-window w nil 'below))
            (push w cells))
          (push (nreverse cells) columns)))   ; column cells, top -> bottom
      (setq columns (nreverse columns))        ; columns, left -> right
      (balance-windows)
      ;; flatten to ROW-MAJOR (row 0 across all columns, then row 1, ...)
      (let ((row-major '()))
        (dotimes (r rows)
          (dolist (col columns)
            (push (nth r col) row-major)))
        (nreverse row-major)))))

(defun claude-workspace--snap-to-bottom (win)
  "Anchor the Claude session in WIN at its live prompt (bottom of buffer).
A plain `set-window-point' is not enough: rebuilding the grid splits
windows, and ghostel's own window-start heuristic explicitly \"misfires ...
window split layouts\" (see ghostel.el), leaving the cell scrolled to the
TOP.  `recenter' is a hard `window-start' primitive that ghostel accepts as
a deliberate viewport position, so `point-max' (the prompt) becomes the last
visible line and the cell then keeps following the live output.  Verified
live: a window forced to `point-min' lands back at the prompt after this."
  (when (window-live-p win)
    (let ((buf (window-buffer win)))
      (when (and (bufferp buf) (buffer-live-p buf)
                 (string-prefix-p "*claude:" (buffer-name buf)))
        (with-selected-window win
          (goto-char (point-max))
          (set-window-point win (point-max))
          (ignore-errors (recenter -1 t)))))))

(defun claude-workspace--select-session-window (win)
  "Select WIN and anchor its Claude session at the BOTTOM (the live prompt)
so focusing always lands where you type, not at the top."
  (when (window-live-p win)
    (select-window win)
    (claude-workspace--snap-to-bottom win)))

(defun claude-workspace--placeholder-window-p (win)
  "Non-nil if WIN shows an empty grid placeholder slot."
  (and (window-live-p win)
       (let ((name (buffer-name (window-buffer win))))
         (and name (string-prefix-p " *claude-slot-" name)))))

;;;###autoload
(defun claude-workspace-expand-down ()
  "Grow the current session DOWN into the empty slot(s) directly below it so
you can read its full context, then toggle back.
Only absorbs EMPTY placeholder slots in the same column -- never hides another
session.  Because the grid is built columns-first, the other columns keep
their layout.  Call again (or open/relayout the grid) to restore the uniform
grid; auto-relayout leaves an expanded grid alone until then."
  (interactive)
  (if (frame-parameter nil 'claude-workspace-expanded)
      ;; already expanded -> restore the uniform grid (relayout clears the flag)
      (progn (claude-workspace--relayout)
             (message "Grid restored"))
    (let ((win (selected-window))
          (absorbed 0))
      (unless (memq (window-buffer win) claude-workspace--sessions)
        (user-error "Not on a Claude session"))
      ;; set the flag BEFORE deleting windows so the debounced auto-relayout
      ;; (window-size-change) leaves the expansion alone
      (set-frame-parameter nil 'claude-workspace-expanded t)
      (catch 'done
        (while t
          (let ((below (window-in-direction 'below win)))
            (if (and below
                     (window-live-p below)
                     (claude-workspace--placeholder-window-p below))
                (progn (delete-window below) (setq absorbed (1+ absorbed)))
              (throw 'done nil)))))
      (if (> absorbed 0)
          (progn
            (select-window win)
            (claude-workspace--snap-to-bottom win)
            (message "Expanded into %d empty slot%s below — repeat to restore"
                     absorbed (if (= absorbed 1) "" "s")))
        ;; nothing absorbed -> undo the flag
        (set-frame-parameter nil 'claude-workspace-expanded nil)
        (message "No empty slot directly below to expand into")))))

(defun claude-workspace--relayout ()
  "Redraw the grid in the current workspace from the session list.
Picks dimensions from the current display, pages if there are more
sessions than cells, fills cells with sessions and the rest with
placeholders, and selects the first live session window."
  (claude-workspace--prune)
  (let* ((dims (claude-workspace--auto-dims))
         (cols (car dims))
         (rows (cdr dims))
         (cells (max 1 (* cols rows)))
         (sessions claude-workspace--sessions)
         (count (length sessions))
         (npages (max 1 (ceiling (max count 1) cells)))
         ;; page so the active session stays visible; never an all-empty page
         (anchor (or (and (buffer-live-p claude-workspace--last-session)
                          (cl-position claude-workspace--last-session sessions
                                       :test #'eq))
                     0))
         (page (max 0 (min (/ anchor cells) (1- npages))))
         (start (* page cells))
         (wins (claude-workspace--grid-windows cols rows))
         (focus nil))
    (setq claude-workspace--page page
          claude-workspace--last-applied-dims dims)
    ;; remember what this frame is laid out for, so auto-relayout fires only
    ;; on a real display change -- not when you open magit / a transient / a popup
    (set-frame-parameter nil 'claude-workspace-dims dims)
    ;; a fresh uniform grid is, by definition, no longer expanded
    (set-frame-parameter nil 'claude-workspace-expanded nil)
    (dotimes (i (length wins))
      (let* ((win (nth i wins))
             (gidx (+ start i))
             (buf (nth gidx sessions)))
        (when (window-live-p win)
          (if (buffer-live-p buf)
              (progn (set-window-buffer win buf)
                     (unless focus (setq focus win)))
            (set-window-buffer win (claude-workspace--placeholder gidx))))))
    ;; anchor EVERY session cell at its live prompt.  The grid rebuild above
    ;; splits fresh windows, which makes ghostel's window-start heuristic
    ;; misfire to the top; snap them all back to the bottom (not just the
    ;; focused one) so no session ever shows scrolled to the top.
    (dolist (w wins)
      (when (and (window-live-p w)
                 (memq (window-buffer w) claude-workspace--sessions))
        (claude-workspace--snap-to-bottom w)))
    ;; focus the active (last-selected) session if it's visible, so collapsing
    ;; back from a project workspace lands on that project's session
    (let ((target (or (and (buffer-live-p claude-workspace--last-session)
                           (get-buffer-window claude-workspace--last-session))
                      focus
                      (car (cl-remove-if-not #'window-live-p wins)))))
      (when (window-live-p target)
        (claude-workspace--select-session-window target)))
    ;; pin newly-displayed sessions to the current fixed width
    (when (bound-and-true-p claude-workspace-pin-width-mode)
      (claude-workspace--repin))
    ;; tint idle unfocused sessions, untint the focused one
    (claude-workspace--refresh-attention)))


;;;; Workspace plumbing

(defun claude-workspace--in-workspace-p ()
  "Non-nil if the current Doom workspace is the master Claude one."
  (and (fboundp '+workspace-current-name)
       (equal (+workspace-current-name) claude-workspace-name)))

(defun claude-workspace--ensure-workspace ()
  "Switch to the master Claude workspace, creating it if needed."
  (require 'persp-mode nil t)
  (unless (claude-workspace--in-workspace-p)
    (when (fboundp '+workspace-switch)
      (+workspace-switch claude-workspace-name t))))


;;;; Spawning sessions

(defun claude-workspace--instance-name (project-root)
  "Pick an unused Claude instance name for PROJECT-ROOT.
Uses the project directory name, then NAME-2, NAME-3, ... on collision."
  (let* ((base (file-name-nondirectory (directory-file-name project-root)))
         (existing (delq nil
                         (mapcar (lambda (buf)
                                   (claude-code--extract-instance-name-from-buffer-name
                                    (buffer-name buf)))
                                 (claude-code--find-claude-buffers-for-directory
                                  project-root)))))
    (if (not (member base existing))
        base
      (cl-loop for k from 2
               for name = (format "%s-%d" base k)
               unless (member name existing) return name))))

(defun claude-workspace--spawn (project-root &optional extra-switches)
  "Start one Claude session rooted at PROJECT-ROOT.
EXTRA-SWITCHES is an optional list of CLI switches (e.g. (\"--continue\")).
No instance-name prompt, no window display (we lay out the grid ourselves).
Return the new Claude buffer, or nil on failure."
  (require 'claude-code)
  (let* ((root (file-name-as-directory (expand-file-name project-root)))
         (default-directory root)
         (iname (claude-workspace--instance-name root)))
    (cl-letf (((symbol-function 'claude-code--prompt-for-instance-name)
               (lambda (&rest _) iname)))
      (let ((claude-code-display-window-fn #'ignore)
            (claude-code-toggle-auto-select nil))
        ;; force-prompt=t routes through our overridden name function.
        (claude-code--start nil extra-switches t)))
    (let ((buf (get-buffer (claude-code--buffer-name iname))))
      (when buf
        (claude-workspace--harden-session-buffer buf)
        ;; Give the fresh PTY a sane size immediately.  Spawned buffers have
        ;; no window until the grid is laid out; on a degenerate 0x0 / 1-col
        ;; terminal Claude can exit before we place it.  Pin it now.
        (with-current-buffer buf
          (let ((proc (and (boundp 'ghostel--process) ghostel--process)))
            (when (process-live-p proc)
              (ignore-errors
                (set-process-window-size
                 proc 40 (max 20 claude-workspace-fixed-width)))))))
      buf)))


;;;; Project picker

(defun claude-workspace--project-candidates ()
  "Alist of (DISPLAY . ROOT) for projectile's known projects."
  (require 'projectile)
  (mapcar (lambda (root)
            (cons (format "%-24s %s"
                          (file-name-nondirectory (directory-file-name root))
                          (propertize (abbreviate-file-name root) 'face 'shadow))
                  root))
          (projectile-relevant-known-projects)))

(defun claude-workspace--read-plan (free)
  "Interactively build a spawn plan: a list of (ROOT . COUNT).
FREE is the number of free slots; the plan never exceeds it."
  (let* ((cands (claude-workspace--project-candidates))
         (chosen (completing-read-multiple
                  (format "Add Claude in project(s) [%d free slot%s]: "
                          free (if (= free 1) "" "s"))
                  cands nil t))
         (remaining free)
         (plan '()))
    (dolist (disp chosen)
      (when (> remaining 0)
        (let* ((root (or (cdr (assoc disp cands))
                         (and (file-directory-p (expand-file-name disp))
                              (expand-file-name disp))))
               (count (cond
                       ((null root) 0)
                       ((<= remaining 1) 1)
                       (t (max 1 (min remaining
                                      (read-number
                                       (format "How many sessions of %s? "
                                               (file-name-nondirectory
                                                (directory-file-name root)))
                                       1)))))))
          (when (and root (> count 0))
            (push (cons root count) plan)
            (setq remaining (- remaining count))))))
    (nreverse plan)))


;;;; Commands: open / add / adopt

;;;###autoload
(defun claude-workspace-open ()
  "Switch to the master Claude workspace and (re)draw the session grid.
If `claude-workspace-adopt-on-open' is non-nil, also pull in any running
Claude sessions that are not already on the grid."
  (interactive)
  (claude-workspace--ensure-workspace)
  (when claude-workspace-adopt-on-open
    (claude-workspace-adopt nil))
  (claude-workspace--relayout))

;;;###autoload
(defun claude-workspace-add (&optional plan)
  "Add Claude sessions to the next free slots.
Interactively prompts for projectile project(s) and how many sessions of
each.  PLAN, when given non-interactively, is a list of (ROOT . COUNT)."
  (interactive)
  (claude-workspace--ensure-workspace)
  (let ((free (claude-workspace--free-count)))
    (when (zerop free)
      (user-error "Already holding the maximum of %d Claude sessions"
                  (claude-workspace--capacity)))
    (let ((plan (or plan (claude-workspace--read-plan free)))
          (remaining free)
          (started 0))
      (cl-block done
        (dolist (entry plan)
          (let ((root (car entry))
                (count (cdr entry)))
            (dotimes (_ count)
              (when (<= remaining 0) (cl-return-from done))
              (let ((buf (claude-workspace--spawn root)))
                (when (claude-workspace--add-session buf)
                  (setq started (1+ started)
                        remaining (1- remaining))))))))
      (claude-workspace--relayout)
      (message "Started %d session%s — %d slot%s free"
               started (if (= started 1) "" "s")
               (claude-workspace--free-count)
               (if (= (claude-workspace--free-count) 1) "" "s")))))

;;;###autoload
(defun claude-workspace-adopt (&optional relayout)
  "Pull every running Claude session not already on the grid into free slots.
Sessions fill free slots in buffer order until capacity; leftover sessions
are reported but left running where they are.  RELAYOUT non-nil (the
default when called interactively) redraws the grid.  Returns the count."
  (interactive (list t))
  (require 'claude-code)
  (claude-workspace--prune)
  (let* ((orphans (cl-remove-if
                   (lambda (b) (memq b claude-workspace--sessions))
                   (claude-code--find-all-claude-buffers)))
         (adopted 0))
    (dolist (buf orphans)
      (when (claude-workspace--add-session buf)
        (setq adopted (1+ adopted))))
    (when relayout (claude-workspace--relayout))
    (when (called-interactively-p 'any)
      (let ((leftover (max 0 (- (length orphans) adopted))))
        (message "Adopted %d session%s%s"
                 adopted (if (= adopted 1) "" "s")
                 (if (> leftover 0)
                     (format " — %d more running but grid is full" leftover)
                   ""))))
    adopted))


;;;; Commands: paging / layout

(defun claude-workspace--page-by (delta)
  "Move the active session DELTA cells forward/backward and relayout.
The grid pages so the active session is visible, so this scrolls the grid
by a page (DELTA = +/- cells); on a phone (one cell) it steps one session."
  (let* ((sessions claude-workspace--sessions)
         (n (length sessions)))
    (when (> n 0)
      (let* ((cells (claude-workspace--visible-cells))
             (cur (or (and (buffer-live-p claude-workspace--last-session)
                           (cl-position claude-workspace--last-session sessions
                                        :test #'eq))
                      0))
             (next (max 0 (min (+ cur (* delta cells)) (1- n)))))
        (setq claude-workspace--last-session (nth next sessions))
        (claude-workspace--relayout)
        (let ((win (get-buffer-window claude-workspace--last-session)))
          (when (window-live-p win) (select-window win)))))))

;;;###autoload
(defun claude-workspace-cycle-session (&optional backward)
  "Switch to the next managed Claude session, wrapping around.
With prefix arg BACKWARD, go to the previous one.  Bound to a quick chord
\(SPC v x) this is the easy way to flip between sessions, especially on a
phone where a single session fills the screen."
  (interactive "P")
  (let* ((sessions claude-workspace--sessions)
         (n (length sessions)))
    (if (zerop n)
        (user-error "No Claude sessions running")
      (let* ((cur (or (and (buffer-live-p claude-workspace--last-session)
                           (cl-position claude-workspace--last-session sessions
                                        :test #'eq))
                      0))
             (next (mod (+ cur (if backward -1 1)) n))
             (buf (nth next sessions))
             (win (get-buffer-window buf)))   ; already visible on this frame?
        (setq claude-workspace--last-session buf)
        (if (window-live-p win)
            ;; grid (monitor/Mac): just move focus to the next cell in sequence
            (claude-workspace--select-session-window win)
          ;; not visible (phone, paged out): re-tile to bring it on screen
          (claude-workspace--relayout)
          (setq win (get-buffer-window buf))
          (when (window-live-p win) (claude-workspace--select-session-window win)))
        (message "Claude → %s (%d/%d)"
                 (claude-workspace--session-project buf) (1+ next) n)))))

;;;###autoload
(defun claude-workspace-next-page ()
  "Page forward (step to the next session/page); keeps it visible."
  (interactive)
  (claude-workspace--page-by 1))

;;;###autoload
(defun claude-workspace-prev-page ()
  "Page backward (step to the previous session/page)."
  (interactive)
  (claude-workspace--page-by -1))

;;;###autoload
(defun claude-workspace-set-layout (cols rows)
  "Force the grid to COLS x ROWS until set back to automatic.
Called interactively, offers a couple of presets."
  (interactive
   (let* ((choice (completing-read
                   "Layout: "
                   '("auto" "2 (1x2 stacked)" "2 (2x1 side by side)"
                     "4 (2x2)" "6 (3x2)")
                   nil t)))
     (pcase choice
       ("auto" (list nil nil))
       ("2 (1x2 stacked)" (list 1 2))
       ("2 (2x1 side by side)" (list 2 1))
       ("4 (2x2)" (list 2 2))
       ("6 (3x2)" (list 3 2))
       (_ (list nil nil)))))
  (setq claude-workspace-force-dims (and cols rows (cons cols rows)))
  (claude-workspace--relayout)
  (message "Layout: %s" (if claude-workspace-force-dims
                            (format "%dx%d (forced)" cols rows)
                          "automatic")))


;;;; Commands: teardown / refresh

;;;###autoload
(defun claude-workspace-kill-slot ()
  "Kill the Claude session in the current window and remove it from the grid."
  (interactive)
  (let ((cur (current-buffer)))
    (if (not (memq cur claude-workspace--sessions))
        (user-error "This window is not a managed Claude session")
      (setq claude-workspace--sessions
            (delq cur claude-workspace--sessions))
      (let ((claude-code-confirm-kill nil)
            (kill-buffer-query-functions nil))
        (when (buffer-live-p cur) (kill-buffer cur)))
      (claude-workspace--relayout)
      (message "Session killed"))))

;;;###autoload
(defun claude-workspace-reset ()
  "Kill ALL managed Claude sessions and clear the grid."
  (interactive)
  (when (yes-or-no-p "Kill all managed Claude sessions? ")
    (let ((claude-code-confirm-kill nil)
          (kill-buffer-query-functions nil))
      (dolist (b claude-workspace--sessions)
        (when (buffer-live-p b) (kill-buffer b))))
    (setq claude-workspace--sessions nil
          claude-workspace--page 0)
    (claude-workspace--relayout)
    (message "All sessions cleared")))

;;;###autoload
(defun claude-workspace-refresh-session ()
  "Recover a garbled session: kill it and restart `claude --continue' in place.
Use this if a window resize corrupts the terminal display.  The session is
restarted in the same project directory and restored to the same grid
position; `--continue' resumes the most recent conversation there."
  (interactive)
  (let* ((cur (current-buffer))
         (pos (cl-position cur claude-workspace--sessions :test #'eq))
         (dir (claude-workspace--current-dir)))
    (unless (and pos dir)
      (user-error "Not on a managed Claude session"))
    (when (yes-or-no-p (format "Restart this session with --continue in %s? "
                               (file-name-nondirectory
                                (directory-file-name dir))))
      (let ((claude-code-confirm-kill nil)
            (kill-buffer-query-functions nil))
        (when (buffer-live-p cur) (kill-buffer cur)))
      (let ((new (claude-workspace--spawn dir '("--continue"))))
        (if (buffer-live-p new)
            (progn
              (setf (nth pos claude-workspace--sessions) new)
              (claude-workspace--harden-session-buffer new)
              ;; focus the RESTARTED session, not the first one
              (setq claude-workspace--last-session new)
              (when (fboundp 'persp-add-buffer)
                (ignore-errors (persp-add-buffer new))))
          ;; spawn failed: just drop the dead entry
          (setq claude-workspace--sessions
                (cl-remove-if-not #'buffer-live-p claude-workspace--sessions))))
      (claude-workspace--relayout)
      (message "Session restarted with --continue"))))


;;;; From inside a session: jump to its project

(defun claude-workspace--current-dir ()
  "Project root of the Claude session in the current buffer, or nil.
Recovered from the buffer name, falling back to `default-directory'."
  (let ((dir (claude-code--extract-directory-from-buffer-name (buffer-name))))
    (cond
     (dir (expand-file-name dir))
     ((memq (current-buffer) claude-workspace--sessions)
      (expand-file-name default-directory))
     (t nil))))

;;;###autoload
(defun claude-workspace-magit ()
  "Open Magit for the project of the Claude session in the current window."
  (interactive)
  (require 'magit)
  (let ((dir (claude-workspace--current-dir)))
    (if dir
        (magit-status-setup-buffer dir)
      (call-interactively #'magit-status))))

;;;###autoload
(defun claude-workspace-dired ()
  "Open Dired for the project of the Claude session in the current window."
  (interactive)
  (let ((dir (claude-workspace--current-dir)))
    (dired (or dir default-directory))))


;;;; Expand / collapse: master-claude grid <-> a project's own workspace

(defun claude-workspace--open-project-entry (root)
  "Open a sensible entry buffer for project ROOT: a known file, else Dired."
  (let* ((cands '("CLAUDE.md" "README.md" "README.org" "AGENTS.md"))
         (file (cl-some (lambda (f)
                          (let ((p (expand-file-name f root)))
                            (and (file-exists-p p) p)))
                        cands)))
    (if file (find-file file) (dired root))))

;;;###autoload
(defun claude-workspace-expand-to-project ()
  "Expand: jump from the current Claude session to that project's own Doom
workspace, creating it (with the project opened) the first time.
Remembers the session so `claude-workspace-collapse' returns focused on it.
Do your file/magit/dired work in that workspace, then collapse back."
  (interactive)
  (let ((dir (claude-workspace--current-dir))
        (cur (current-buffer)))
    (unless dir (user-error "Not on a Claude session"))
    (when (memq cur claude-workspace--sessions)
      (setq claude-workspace--last-session cur))
    (let* ((root (file-name-as-directory (expand-file-name dir)))
           (name (file-name-nondirectory (directory-file-name root)))
           (existed (and (fboundp '+workspace-exists-p) (+workspace-exists-p name))))
      (if (fboundp '+workspace-switch)
          (+workspace-switch name t)
        (find-file root))
      (unless existed
        (let ((default-directory root))
          (claude-workspace--open-project-entry root)))
      (message "Expanded → %s workspace (collapse back: SPC v m)" name))))

;;;###autoload
(defun claude-workspace-collapse ()
  "Collapse: return to the master Claude grid, focused on the session you
last worked from (the expand/collapse counterpart)."
  (interactive)
  (claude-workspace-open))


;;;; Adaptive relayout on display change

;; Robustness across phone / Mac / monitor: persp-mode stores ONE window
;; configuration per workspace, so switching to master-claude on the phone
;; restores the monitor's many-window grid.  We re-tile per FRAME whenever a
;; frame switches into, focuses, or resizes the workspace -- sizing to that
;; frame's display (a phone gets a single full-screen session).

(defun claude-workspace--grid-buffer-p (buf)
  "Non-nil if BUF is a managed session or a grid placeholder."
  (or (memq buf claude-workspace--sessions)
      (and (bufferp buf)
           (string-prefix-p " *claude-slot-" (buffer-name buf)))))

(defun claude-workspace--pure-grid-p (frame)
  "Non-nil if every window in FRAME shows a session or a placeholder.
If anything else is up (magit, dired, a file, a transient, a popup) the
frame is NOT a pure grid and we must leave it completely alone."
  (cl-every (lambda (w) (claude-workspace--grid-buffer-p (window-buffer w)))
            (window-list frame 'no-minibuf)))

(defun claude-workspace--child-or-mini-frame-p (frame)
  "Non-nil if FRAME is a child frame or has the minibuffer selected.
Vertico runs with `+childframe' (a posframe child frame) and M-x selects the
minibuffer; in either case re-tiling or force-redrawing the grid would yank
the sessions around (the M-x \"everything jumps to the top\" bug) or delete
the popup, so callers must leave the grid completely alone."
  (or (not (frame-live-p frame))
      (frame-parameter frame 'parent-frame)
      (window-minibuffer-p (frame-selected-window frame))))

(defun claude-workspace--suppress-relayout-p ()
  "Non-nil when a transient, the minibuffer, or a child frame is active.
Re-tiling then would call `delete-other-windows' and kill the popup, or
churn the grid every time you press \\[execute-extended-command]."
  (or (bound-and-true-p transient--prefix)
      (> (minibuffer-depth) 0)
      (claude-workspace--child-or-mini-frame-p (selected-frame))))

(defun claude-workspace--frame-mislaid-p (frame)
  "Non-nil only when FRAME's master-claude grid should be auto-re-tiled:
the display size changed, or it IS a pure grid that is wrongly filled.
Never true while a file / magit / dired / popup is open -- so opening those
in the workspace is left untouched.  Also never true while the grid is
deliberately expanded (`claude-workspace-expand-down'), so the expansion is
left alone until you toggle back."
  (and (frame-live-p frame)
       (not (frame-parameter frame 'claude-workspace-expanded))
       (with-selected-frame frame
         (and (claude-workspace--in-workspace-p)
              (let* ((d (claude-workspace--auto-dims))
                     (applied (frame-parameter frame 'claude-workspace-dims)))
                (cond
                 ;; display (size class) changed -> re-tile for the new display
                 ((not (equal d applied)) t)
                 ;; user has opened something non-grid -> hands off
                 ((not (claude-workspace--pure-grid-p frame)) nil)
                 ;; pure grid on an unchanged display: fix only if mis-filled
                 (t (let* ((cells (max 1 (* (car d) (cdr d))))
                           (wins (window-list frame 'no-minibuf))
                           (shown (mapcar #'window-buffer wins))
                           (n (length claude-workspace--sessions))
                           (shown-sessions (cl-count-if
                                            (lambda (b) (memq b claude-workspace--sessions))
                                            shown))
                           (anchor (and (buffer-live-p claude-workspace--last-session)
                                        claude-workspace--last-session)))
                      (or (/= (length wins) cells)
                          (< shown-sessions (min cells n))
                          (and anchor (> n 0) (not (memq anchor shown))))))))))))

(defun claude-workspace--adapt-frame (frame &optional force)
  "Relayout FRAME for its display if it shows master-claude and needs it.
With FORCE, relayout even if the window count already matches.  Never fires
while a transient/minibuffer is up (would kill the popup)."
  (when (and claude-workspace-auto-relayout-on-resize
             (frame-live-p frame)
             (not (claude-workspace--suppress-relayout-p)))
    (with-selected-frame frame
      (when (and (claude-workspace--in-workspace-p)
                 (or force (claude-workspace--frame-mislaid-p frame)))
        (claude-workspace--relayout)))))

(defun claude-workspace--maybe-adapt (&optional frame)
  "`window-size-change-functions' entry: adapt FRAME (debounced).
Wrapped so an error here can never break frame creation/resize."
  (with-demoted-errors "claude-workspace maybe-adapt: %S"
    (let ((frame (if (framep frame) frame (selected-frame))))
      (when (and claude-workspace-auto-relayout-on-resize
                 (not claude-workspace--adapt-pending)
                 (not (claude-workspace--suppress-relayout-p))
                 (claude-workspace--frame-mislaid-p frame))
        (setq claude-workspace--adapt-pending t)
        (run-at-time 0.1 nil
                     (lambda ()
                       (setq claude-workspace--adapt-pending nil)
                       (claude-workspace--adapt-frame frame)))))))

(defun claude-workspace--on-activate (&optional _)
  "Force a relayout for the current frame when master-claude is activated.
persp may have restored another frame's window config, so we always re-tile."
  (when claude-workspace-auto-relayout-on-resize
    (let ((frame (selected-frame)))
      (run-at-time 0 nil
                   (lambda ()
                     (with-demoted-errors "claude-workspace on-activate: %S"
                       (claude-workspace--adapt-frame frame t)))))))

(defun claude-workspace--on-focus-change ()
  "Adapt the newly-focused frame and refresh attention tints.
Wrapped so an error can never break frame focus / creation."
  (with-demoted-errors "claude-workspace on-focus: %S"
    (when (and (frame-focus-state)
               (not (claude-workspace--child-or-mini-frame-p (selected-frame))))
      (claude-workspace--adapt-frame (selected-frame))
      (claude-workspace--refresh-attention))))

(defun claude-workspace--note-selection (&optional frame)
  "Remember the active session and refresh tints when focus changes.
Focusing an idle session hides its tint (you're looking at it) but does NOT
clear its needs-attention state -- so if you look away without giving it
work, it tints again.  Only handing it work (UserPromptSubmit) clears it.
Added to `window-selection-change-functions'; wrapped so a stray error can
never break a window selection / frame creation."
  (with-demoted-errors "claude-workspace note-selection: %S"
    (let ((frame (if (framep frame) frame (selected-frame))))
      ;; ignore the minibuffer / vertico child frame (M-x): touching the grid
      ;; there is what yanked every session to the top
      (unless (claude-workspace--child-or-mini-frame-p frame)
        (let ((buf (window-buffer (frame-selected-window frame))))
          (when (memq buf claude-workspace--sessions)
            (setq claude-workspace--last-session buf))
          (claude-workspace--refresh-attention))))))

(add-hook 'window-size-change-functions #'claude-workspace--maybe-adapt)
(add-hook 'window-selection-change-functions #'claude-workspace--note-selection)
(add-hook 'persp-activated-functions #'claude-workspace--on-activate)
(remove-function after-focus-change-function #'claude-workspace--on-focus-change)
(add-function :after after-focus-change-function #'claude-workspace--on-focus-change)


;;;; Pinned terminal width (multi-display safety)

;; Emacs sizes a terminal process to the SMALLEST window displaying it
;; (`window-adjust-process-window-size-function' -> ...-smallest).  ghostel
;; honours that.  So opening a session on a narrow phone shrinks the PTY
;; everywhere, and Claude's TUI -- which redraws destructively on every
;; width change -- garbles.  We wrap that function: for pinned Claude
;; buffers we always report `claude-workspace-fixed-width' columns (height
;; still follows the window), so the width never changes no matter how many
;; displays show the session.  Non-Claude terminals are unaffected.

(defun claude-workspace--adjust-window-size (process windows)
  "Like the smallest-window default, but pin width for Claude buffers."
  (let ((buf (process-buffer process)))
    (if (and (buffer-live-p buf)
             (buffer-local-value 'claude-workspace--pinned buf)
             (integerp claude-workspace-fixed-width))
        (let* ((base (window-adjust-process-window-size-smallest process windows))
               (rows (if (consp base) (cdr base) 24)))
          (cons claude-workspace-fixed-width (max 1 rows)))
      (window-adjust-process-window-size-smallest process windows))))

(defun claude-workspace--repin ()
  "Push the pinned size to every managed session's terminal right now.
Calls the backend's window-size-adjust directly (ghostel skips no-op
window changes, so merely re-showing the buffer is not enough)."
  (dolist (b claude-workspace--sessions)
    (when (buffer-live-p b)
      (with-current-buffer b
        (let ((proc (and (boundp 'ghostel--process) ghostel--process))
              (wins (get-buffer-window-list b nil t)))
          (when (and (process-live-p proc) wins
                     (fboundp 'ghostel--window-adjust-process-window-size))
            (ignore-errors
              (ghostel--window-adjust-process-window-size proc wins))))))))

;;;###autoload
(define-minor-mode claude-workspace-pin-width-mode
  "Pin managed Claude terminals to `claude-workspace-fixed-width' columns.
Stops a session from reflowing to the smallest window when shown on
multiple displays at once (phone + monitor), which is what corrupts the
Claude TUI.  Recommended on."
  :global t
  :group 'claude-workspace
  (if claude-workspace-pin-width-mode
      (progn
        (unless (eq (default-value 'window-adjust-process-window-size-function)
                    #'claude-workspace--adjust-window-size)
          (setq claude-workspace--saved-adjust-fn
                (default-value 'window-adjust-process-window-size-function)))
        (setq-default window-adjust-process-window-size-function
                      #'claude-workspace--adjust-window-size)
        (dolist (b claude-workspace--sessions)
          (when (buffer-live-p b)
            (with-current-buffer b (setq claude-workspace--pinned t))))
        (claude-workspace--repin)
        (message "Claude width pinned to %d columns" claude-workspace-fixed-width))
    (setq-default window-adjust-process-window-size-function
                  (or claude-workspace--saved-adjust-fn
                      #'window-adjust-process-window-size-smallest))
    (claude-workspace--repin)
    (message "Claude width unpinned")))

;;;###autoload
(defun claude-workspace-pin-to-current-width ()
  "Pin Claude's fixed width to the current window's body width.
Run this on your narrowest display (e.g. your phone) so sessions stay
readable everywhere and never reflow."
  (interactive)
  (let ((w (max 20 (window-body-width))))
    (setq claude-workspace-fixed-width w)
    (unless claude-workspace-pin-width-mode
      (claude-workspace-pin-width-mode 1))
    (claude-workspace--repin)
    (message "Pinned Claude width to %d columns" w)))

;;;###autoload
(defun claude-workspace-set-fixed-width (width)
  "Set the pinned Claude terminal WIDTH (columns) and re-apply."
  (interactive (list (read-number "Fixed Claude width (columns): "
                                  claude-workspace-fixed-width)))
  (setq claude-workspace-fixed-width (max 20 width))
  (unless claude-workspace-pin-width-mode
    (claude-workspace-pin-width-mode 1))
  (claude-workspace--repin)
  (claude-workspace--relayout)
  (message "Fixed Claude width set to %d columns" claude-workspace-fixed-width))


;;;; Attention: never leave a session waiting for input

;; Claude rings the terminal bell when it finishes and is waiting for the
;; user.  claude-code.el routes that through `claude-code-notification-function'.
;; `claude-workspace-attention-mode' installs a function there that chimes,
;; shows a big on-screen popup, and (optionally) yanks you straight to the
;; session that needs you -- so no session sits idle/blocked.

(defcustom claude-workspace-attention-auto-switch nil
  "When non-nil, attention events immediately switch to and focus the waiting
session.  Off by default: the calmer cmux-style flow is the attention RING
\(the cell lights up + a badge) plus `claude-workspace-jump-to-attention'
\(SPC v u) to jump there on your terms."
  :type 'boolean)

(defcustom claude-workspace-attention-ring t
  "When non-nil, a session that needs input is COLORED (background tint +
mode-line) so the cell is unmistakable, instead of grabbing focus."
  :type 'boolean)

(defcustom claude-workspace-attention-background "#ffdca8"
  "Background tint for a waiting session on a LIGHT theme (soft orange)."
  :type 'color)

(defcustom claude-workspace-attention-background-dark "#4a3a1c"
  "Background tint for a waiting session on a DARK theme (deep amber).
A light orange washes out on dark backgrounds, so dark mode uses this."
  :type 'color)

(defun claude-workspace--dark-theme-p ()
  "Non-nil if the current frame has a dark background."
  (or (eq (frame-parameter nil 'background-mode) 'dark)
      (let ((bg (face-attribute 'default :background nil 'default)))
        (and (stringp bg)
             (ignore-errors
               (let ((rgb (color-name-to-rgb bg)))
                 (and rgb (< (+ (* 0.299 (nth 0 rgb))
                                (* 0.587 (nth 1 rgb))
                                (* 0.114 (nth 2 rgb)))
                             0.5))))))))

(defun claude-workspace--attention-bg ()
  "The attention background tint appropriate for the current theme."
  (if (claude-workspace--dark-theme-p)
      claude-workspace-attention-background-dark
    claude-workspace-attention-background))

(defface claude-workspace-attention-face
  '((t :inherit mode-line :background "#ff8c00" :foreground "#1a1a1a"
       :weight bold))
  "Mode-line face for a session that is waiting for your input (the ring).")

(defface claude-workspace-working-face
  '((t :inherit mode-line :foreground "#5c7aa8" :slant italic))
  "Calm mode-line face for a session still running its OWN background work
\(a workflow/agents/shell/monitor).  Deliberately understated next to
`claude-workspace-attention-face': it is information, not a demand -- if
something is running we are waiting on IT, not on you.")

(defcustom claude-workspace-attention-chime t
  "When non-nil, play a chime when a session needs attention."
  :type 'boolean)

(defcustom claude-workspace-attention-chime-sound
  "/System/Library/Sounds/Glass.aiff"
  "Sound file played on an attention event (played via the system player)."
  :type 'string)

(defcustom claude-workspace-attention-popup t
  "When non-nil, show a big centered popup when a session needs attention.
Requires `posframe'; falls back to a loud `message' otherwise."
  :type 'boolean)

(defcustom claude-workspace-attention-popup-seconds 6
  "How long the attention popup stays on screen, in seconds."
  :type 'number)

(defvar claude-workspace--saved-notify-fn nil
  "Saved `claude-code-notification-function' before the mode took over.")

(defvar-local claude-workspace--needs-attention nil
  "Logical state: a REASON string when the session is idle/awaiting you,
nil while it is working or you have handed it work.  This drives the tint;
the tint itself shows only when the session is also NOT focused.")

(defvar-local claude-workspace--tinted nil
  "Non-nil when the attention tint is currently applied to this buffer.")

(defvar-local claude-workspace--bg-cookie nil
  "Face-remap cookie for the attention background tint, or nil.")

(defvar-local claude-workspace--saved-mode-line :unset
  "Saved `mode-line-format' while the attention banner / working badge shows.")

(defvar-local claude-workspace--working-desc nil
  "When non-nil, a short string naming the background work this STOPPED
session is still running (e.g. \"2 working · workflow, shell\").  A running
workflow/agent/shell/monitor means the session is waiting on ITS OWN work,
not on you, so it shows a calm badge instead of the orange needs-you tint.")

(defun claude-workspace--banner (buf reason)
  "Mode-line banner string for BUF with REASON (orange needs-you state)."
  (list (propertize (format "  ⚑ %s — %s "
                            (claude-workspace--session-project buf)
                            (if (stringp reason) reason "needs you"))
                    'face 'claude-workspace-attention-face)))

(defun claude-workspace--working-badge (buf desc)
  "Calm mode-line badge for a session still running background work (DESC)."
  (list (propertize (format "  ⏳ %s — %s "
                            (claude-workspace--session-project buf)
                            (if (stringp desc) desc "working…"))
                    'face 'claude-workspace-working-face)))

(defun claude-workspace--ghostel-redraw ()
  "Force ghostel to repaint the current buffer, so the font/colors are clean
after a tint is added or removed (a plain face-remap leaves stale glyphs)."
  (when (and (boundp 'ghostel--force-next-redraw)
             (fboundp 'ghostel--delayed-redraw))
    (setq ghostel--force-next-redraw t)
    (ignore-errors (ghostel--delayed-redraw (current-buffer)))))

(defun claude-workspace--apply-status (buf)
  "Reconcile BUF's tint + mode-line with its logical state.  Idempotent;
cheap when already in the right state (so heavy PreToolUse traffic from
running subagents stays light).  Three states, in priority order:
  - NEEDS YOU: `claude-workspace--needs-attention' set and BUF is not the
    focused window -> orange background tint + ⚑ banner.
  - WORKING:   `claude-workspace--working-desc' set (a workflow/agent/shell
    still running) -> a calm ⏳ badge, NO tint (running means we wait on it,
    not on you).
  - NORMAL:    neither -> no tint, original mode-line restored.
Idempotency is keyed on the ACTUAL applied state (`--tinted',
`--saved-mode-line', the current `mode-line-format'), never a cached flag, so
a code reload or an external mode-line change can never leave a session stuck
tinted.  Forces a ghostel redraw whenever the tint is added or removed."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let* ((focused (eq buf (window-buffer (selected-window))))
             (reason (and (stringp claude-workspace--needs-attention)
                          claude-workspace--needs-attention))
             (want (cond
                    ((and claude-workspace--needs-attention (not focused)
                          claude-workspace-attention-ring)
                     'orange)
                    (claude-workspace--working-desc 'badge)
                    (t nil))))
        (pcase want
          ('orange
           (unless claude-workspace--tinted
             (when (eq claude-workspace--saved-mode-line :unset)
               (setq claude-workspace--saved-mode-line mode-line-format))
             (setq claude-workspace--bg-cookie
                   (face-remap-add-relative
                    'default :background (claude-workspace--attention-bg)))
             (setq claude-workspace--tinted t)
             (claude-workspace--ghostel-redraw))
           (let ((ml (claude-workspace--banner buf (or reason "needs you"))))
             (unless (equal mode-line-format ml)
               (setq mode-line-format ml)
               (force-mode-line-update t))))
          ('badge
           (when claude-workspace--tinted          ; a badge never tints
             (when claude-workspace--bg-cookie
               (face-remap-remove-relative claude-workspace--bg-cookie)
               (setq claude-workspace--bg-cookie nil))
             (setq claude-workspace--tinted nil)
             (claude-workspace--ghostel-redraw))
           (when (eq claude-workspace--saved-mode-line :unset)
             (setq claude-workspace--saved-mode-line mode-line-format))
           (let ((ml (claude-workspace--working-badge buf claude-workspace--working-desc)))
             (unless (equal mode-line-format ml)
               (setq mode-line-format ml)
               (force-mode-line-update t))))
          (_
           ;; NORMAL: tear down anything applied.  Cheap no-op if already clean
           ;; (not tinted and no saved mode-line) -- the common storm case.
           (unless (and (not claude-workspace--tinted)
                        (eq claude-workspace--saved-mode-line :unset))
             (when claude-workspace--tinted
               (when claude-workspace--bg-cookie
                 (face-remap-remove-relative claude-workspace--bg-cookie)
                 (setq claude-workspace--bg-cookie nil))
               (setq claude-workspace--tinted nil)
               (claude-workspace--ghostel-redraw))
             (unless (eq claude-workspace--saved-mode-line :unset)
               (setq mode-line-format claude-workspace--saved-mode-line)
               (setq claude-workspace--saved-mode-line :unset))
             (force-mode-line-update t))))))))

(defun claude-workspace--refresh-attention ()
  "Reconcile tint + working badge across all sessions from their logical
state.  Idempotent and cheap, so safe to call on every focus/selection
change and on heavy PreToolUse traffic."
  (dolist (b claude-workspace--sessions)
    (when (buffer-live-p b)
      (claude-workspace--apply-status b))))

(defun claude-workspace--retint (&rest _)
  "Re-apply the tint COLOR to currently-tinted sessions, e.g. after a
light/dark theme or system-appearance switch.  Deferred so the new theme's
colors are in effect before we read them."
  (run-at-time
   0.1 nil
   (lambda ()
     (let ((bg (claude-workspace--attention-bg)))
       (dolist (b claude-workspace--sessions)
         (when (and (buffer-live-p b)
                    (buffer-local-value 'claude-workspace--tinted b))
           (with-current-buffer b
             (when claude-workspace--bg-cookie
               (face-remap-remove-relative claude-workspace--bg-cookie)
               (setq claude-workspace--bg-cookie
                     (face-remap-add-relative 'default :background bg)))
             (claude-workspace--ghostel-redraw))))))))

;; Re-color tints live when the theme / macOS appearance changes.
(when (boundp 'ns-system-appearance-change-functions)
  (add-hook 'ns-system-appearance-change-functions #'claude-workspace--retint))
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'claude-workspace--retint))

(defun claude-workspace--set-attention (buf on &optional reason)
  "Set the logical needs-attention state of BUF (ON with optional REASON),
then refresh the tints across the grid."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq claude-workspace--needs-attention (and on (or reason t))))
    (claude-workspace--refresh-attention)))

(defun claude-workspace--set-working (buf desc)
  "Set BUF's background-work descriptor to DESC (a string) or nil, then
refresh.  A non-nil DESC shows the calm working badge; nil removes it."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq claude-workspace--working-desc desc))
    (claude-workspace--refresh-attention)))

(defun claude-workspace--attention-reason (buf)
  "The reason string a session is waiting, or nil."
  (let ((v (buffer-local-value 'claude-workspace--needs-attention buf)))
    (and (stringp v) v)))

(defun claude-workspace--attention-count ()
  "How many managed sessions are currently showing the orange tint."
  (cl-count-if (lambda (b)
                 (and (buffer-live-p b)
                      (buffer-local-value 'claude-workspace--tinted b)))
               claude-workspace--sessions))

;;;###autoload
(defun claude-workspace-jump-to-attention ()
  "Jump to the next idle session that needs you (orange).  Cycles forward
and wraps.  Focusing it hides its tint, but does not mark it handled --
give it work (or it will tint again when you look away)."
  (interactive)
  (let* ((sessions claude-workspace--sessions)
         (waiting (cl-remove-if-not
                   (lambda (b) (buffer-local-value 'claude-workspace--needs-attention b))
                   sessions)))
    (if (null waiting)
        (message "No Claude session is waiting")
      (let* ((cur (or (and (buffer-live-p claude-workspace--last-session)
                           (cl-position claude-workspace--last-session sessions
                                        :test #'eq))
                      -1))
             (target (or (cl-find-if
                          (lambda (b) (> (cl-position b sessions :test #'eq) cur))
                          waiting)
                         (car waiting))))
        (setq claude-workspace--last-session target)
        (claude-workspace--focus-session target)   ; refresh untints the focused one
        (message "→ %s  (%d waiting)"
                 (claude-workspace--session-project target)
                 (claude-workspace--attention-count))))))

(defun claude-workspace--session-project (buf)
  "Human-readable project label for Claude buffer BUF."
  (let ((dir (and (buffer-live-p buf)
                  (claude-code--extract-directory-from-buffer-name
                   (buffer-name buf))))
        (inst (and (buffer-live-p buf)
                   (claude-code--extract-instance-name-from-buffer-name
                    (buffer-name buf)))))
    (cond
     ((and dir inst (not (equal inst "default")))
      (format "%s · %s" (file-name-nondirectory (directory-file-name dir)) inst))
     (dir (file-name-nondirectory (directory-file-name dir)))
     (t (buffer-name buf)))))

(defun claude-workspace--chime ()
  "Play the attention chime, if configured and available."
  (when (and claude-workspace-attention-chime
             claude-workspace-attention-chime-sound
             (file-exists-p claude-workspace-attention-chime-sound))
    (let ((player (or (executable-find "afplay")    ; macOS
                      (executable-find "paplay")    ; PulseAudio
                      (executable-find "aplay"))))   ; ALSA
      (when player
        (ignore-errors
          (start-process "claude-chime" nil player
                         claude-workspace-attention-chime-sound))))))

(defun claude-workspace--popup (project message)
  "Show a big centered popup naming PROJECT with MESSAGE."
  (if (and claude-workspace-attention-popup (require 'posframe nil t))
      (let ((buf (get-buffer-create " *claude-attention*")))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (propertize (format "  ⚑  %s\n" project)
                                'face '(:height 1.8 :weight bold)))
            (insert (propertize (format "  %s\n" message)
                                'face '(:height 1.2)))))
        (with-no-warnings
          (posframe-show buf
                         :poshandler #'posframe-poshandler-frame-center
                         :internal-border-width 24
                         :internal-border-color "#ff5f87"
                         :background-color "#11111b"
                         :foreground-color "#f5f5f5"
                         :timeout claude-workspace-attention-popup-seconds
                         :min-width 40)))
    (message "⚑ Claude needs you — %s: %s" project message)))

(defun claude-workspace--focus-session (buf)
  "Bring Claude session BUF to the foreground in the master workspace.
Adopts BUF into a free slot first if it is not already on the grid."
  (when (buffer-live-p buf)
    (claude-workspace--ensure-workspace)
    (let ((win (get-buffer-window buf)))
      (unless (and (window-live-p win) (claude-workspace--in-workspace-p))
        (unless (memq buf claude-workspace--sessions)
          (claude-workspace--add-session buf))
        (claude-workspace--relayout)
        (setq win (get-buffer-window buf)))
      (if (window-live-p win)
          (progn
            (claude-workspace--select-session-window win)
            (ignore-errors (select-frame-set-input-focus (window-frame win))))
        ;; on the grid but not visible (paged out): bring it on screen
        (pop-to-buffer buf)
        (goto-char (point-max))))))

(defun claude-workspace--attention (title message)
  "Notification handler: a Claude session is waiting for input.
TITLE and MESSAGE come from claude-code.el.  Identifies the waiting session
from the current buffer (the bell fires in that buffer), lights its ring,
chimes, and -- only if `claude-workspace-attention-auto-switch' -- jumps to
it.  Otherwise use `claude-workspace-jump-to-attention' (SPC v u)."
  (let* ((buf (let ((b (current-buffer)))
                (and (buffer-live-p b)
                     (string-prefix-p "*claude:" (buffer-name b))
                     b)))
         (project (if buf (claude-workspace--session-project buf) "Claude"))
         ;; don't ring if you're already looking at this session
         (already-here (and buf (eq buf (window-buffer (selected-window))))))
    (ignore project)
    (when (and buf (not already-here))
      (claude-workspace--set-attention buf t (or message title))  ; color + banner
      (claude-workspace--chime))
    (when (and claude-workspace-attention-auto-switch buf (not already-here))
      (claude-workspace--focus-session buf))))

(defun claude-workspace--event-reason (type event)
  "A short reason string (why it stopped / what it wants) for a Claude
event of TYPE, parsed from the hook JSON in plist EVENT."
  (let* ((json (plist-get event :json-data))
         (data (and (stringp json)
                    (ignore-errors
                      (json-parse-string json :object-type 'alist :null-object nil)))))
    (cond
     ((string= type "permission")
      (let* ((tool (or (alist-get 'tool_name data) "tool"))
             (inp (alist-get 'tool_input data))
             (detail (and (listp inp)
                          (or (alist-get 'command inp)
                              (alist-get 'file_path inp)
                              (alist-get 'pattern inp)))))
        (format "permission: %s%s" tool
                (if detail
                    (format " — %s" (truncate-string-to-width (format "%s" detail) 60))
                  ""))))
     ((string= type "notification")
      (let ((msg (alist-get 'message data)))
        (if (and msg (> (length (format "%s" msg)) 0)) (format "%s" msg)
          "waiting for you")))
     ((string= type "stop") "finished — your turn")
     (t "needs you"))))

(defun claude-workspace--event-json (event)
  "Parse the hook JSON in plist EVENT to an alist (arrays as lists), or nil."
  (let ((json (plist-get event :json-data)))
    (and (stringp json)
         (ignore-errors
           (json-parse-string json :object-type 'alist
                              :array-type 'list :null-object nil)))))

(defun claude-workspace--bg-summary (event)
  "Short description of still-running background work in a Stop EVENT, or nil
when none is running.  Reads the `background_tasks' array Claude Code (>=
2.1.145) puts in the Stop payload: each entry has a `type'
\(shell/workflow/monitor/subagent) and a `status'.  Anything not in a
terminal status counts as running -- the session is waiting on ITS OWN work,
not on you, so we must not show the orange needs-you tint."
  (let* ((data (claude-workspace--event-json event))
         (tasks (alist-get 'background_tasks data))
         (active (cl-remove-if
                  (lambda (tk)
                    (let ((st (and (listp tk) (alist-get 'status tk))))
                      (member (and (stringp st) (downcase st))
                              '("completed" "complete" "done" "finished"
                                "failed" "error" "killed" "cancelled"
                                "canceled" "exited" "stopped"))))
                  (and (listp tasks) tasks))))
    (when active
      (let ((types (delete-dups
                    (mapcar (lambda (tk) (format "%s" (or (alist-get 'type tk) "task")))
                            active))))
        (format "%d working · %s" (length active) (string-join types ", "))))))

(defun claude-workspace--main-agent-event-p (event)
  "Non-nil if EVENT comes from the MAIN agent, not a subagent.
Subagent tool events carry a non-null `agent_type' (e.g. workflow-subagent,
general-purpose); the main agent's is null/absent.  Used so a SUBAGENT
firing tools (background work still going) does not clear the working badge,
while the MAIN agent resuming does."
  (let* ((data (claude-workspace--event-json event))
         (atype (alist-get 'agent_type data)))
    (or (null atype)
        (member (and (stringp atype) (downcase atype)) '("main" "primary" "")))))

(defun claude-workspace--on-claude-event (event)
  "Color the right session from a Claude Code CLI hook EVENT.
EVENT is the plist from `claude-code-event-hook' (carries :type, :buffer-name,
:json-data).  This is the reliable trigger -- it fires on Stop / Notification /
permission with the exact session name even when that session is not focused,
unlike the terminal bell.  Returns nil so other event-hook functions still run."
  (let* ((type (downcase (format "%s" (plist-get event :type))))
         (bufname (plist-get event :buffer-name))
         (buf (and bufname (get-buffer bufname))))
    (when (and buf (memq buf claude-workspace--sessions))
      (cond
       ;; it is working again (you gave it work, OR it auto-resumed and is
       ;; running tools) -> clear the orange.  Clear the working badge too,
       ;; but ONLY when the MAIN agent is acting -- a SUBAGENT firing tools
       ;; means the background work is still going, so keep the badge.
       ((member type '("userpromptsubmit" "userprompt" "submit"
                       "pretooluse" "posttooluse"))
        (with-current-buffer buf
          (setq claude-workspace--needs-attention nil)
          (when (and claude-workspace--working-desc
                     (claude-workspace--main-agent-event-p event))
            (setq claude-workspace--working-desc nil)))
        (claude-workspace--refresh-attention))
       ;; it is BLOCKED on a permission dialog -> waiting for your choice -> tint
       ((member type '("permission" "permissionrequest"))
        (with-current-buffer buf (setq claude-workspace--working-desc nil))
        (claude-workspace--set-attention buf t (claude-workspace--event-reason "permission" event))
        (unless (eq buf (window-buffer (selected-window)))
          (claude-workspace--chime)))
       ;; it FINISHED its turn.  If it is still running its OWN background work
       ;; (a workflow/agents/shell/monitor), we are waiting on THAT, not on
       ;; you: show a calm badge, NO orange, no chime.  Only a genuinely idle
       ;; stop is your turn.
       ((string= type "stop")
        (let ((bg (claude-workspace--bg-summary event)))
          (with-current-buffer buf
            (setq claude-workspace--needs-attention (unless bg "finished — your turn"))
            (setq claude-workspace--working-desc bg))
          (claude-workspace--refresh-attention)
          (when (and (not bg)
                     (not (eq buf (window-buffer (selected-window)))))
            (claude-workspace--chime))))))
    nil))

(defvar claude-workspace--submit-fns
  '(claude-code--ghostel-send-return
    claude-code--vterm-send-return
    claude-code--eat-send-return)
  "Backend functions that SUBMIT input to a Claude session (the RET key).
Advised to clear a session's tint the instant you hand it input.")

(defun claude-workspace--clear-on-submit (&rest _)
  "Clear the current session's tint -- you just submitted input to it.
This is the Emacs side of the model: COLORING comes from Claude Code hooks
\(Stop / PermissionRequest); CLEARING happens here, instantly, when you hit
RET in the session (no hook, no latency)."
  (when (memq (current-buffer) claude-workspace--sessions)
    (with-current-buffer (current-buffer)
      (setq claude-workspace--needs-attention nil
            claude-workspace--working-desc nil))
    (claude-workspace--refresh-attention)))

;;;###autoload
(define-minor-mode claude-workspace-attention-mode
  "Color a Claude session orange when it needs you, clear it when you reply.
COLORING comes from Claude Code hooks: `Stop' (finished -> your turn) and
`PermissionRequest' (blocked on a choice).  CLEARING happens in Emacs the
moment you submit input (RET) to the session.  No tinting while it works."
  :global t
  :group 'claude-workspace
  (if claude-workspace-attention-mode
      (progn
        (require 'claude-code)
        (add-hook 'claude-code-event-hook #'claude-workspace--on-claude-event)
        (dolist (fn claude-workspace--submit-fns)
          (when (fboundp fn)
            (advice-add fn :after #'claude-workspace--clear-on-submit)))
        (message "Claude attention on — sessions glow orange when they need you"))
    (remove-hook 'claude-code-event-hook #'claude-workspace--on-claude-event)
    (dolist (fn claude-workspace--submit-fns)
      (when (fboundp fn)
        (advice-remove fn #'claude-workspace--clear-on-submit)))
    (message "Claude attention off")))


;;;; Menu

;;;###autoload (autoload 'claude-workspace-transient "claude-workspace" nil t)
(transient-define-prefix claude-workspace-transient ()
  "Master Claude — manage many sessions across projects in one grid."
  [:description
   (lambda ()
     (claude-workspace--prune)
     (let* ((cap (claude-workspace--capacity))
            (used (length claude-workspace--sessions))
            (waiting (claude-workspace--attention-count))
            (d (claude-workspace--auto-dims)))
       (format "Master Claude   [%d/%d sessions%s · %dx%d grid%s · width %d%s]"
               used cap
               (if (> waiting 0) (format " · %d ⚑ waiting" waiting) "")
               (car d) (cdr d)
               (if claude-workspace-force-dims " forced" "")
               claude-workspace-fixed-width
               (if (bound-and-true-p claude-workspace-pin-width-mode)
                   " pinned" ""))))
   ["Workspace"
    ("o" "Open / relayout grid" claude-workspace-open)
    ("a" "Add session(s)…" claude-workspace-add)
    ("A" "Adopt running sessions" claude-workspace-adopt)]
   ["Layout / width"
    ("l" "Set layout (force/auto)" claude-workspace-set-layout)
    ("w" "Pin width to this window" claude-workspace-pin-to-current-width)
    ("W" "Set fixed width…" claude-workspace-set-fixed-width)
    ("n" "Next page" claude-workspace-next-page)
    ("p" "Previous page" claude-workspace-prev-page)
    ("z" "Expand session ↓ into empty slot (toggle)" claude-workspace-expand-down)]
   ["Session"
    ("u" "Jump to next ⚑ waiting" claude-workspace-jump-to-attention)
    ("x" "Switch to next session" claude-workspace-cycle-session)
    ("e" "Expand → project workspace" claude-workspace-expand-to-project)
    ("m" "Collapse → master grid" claude-workspace-collapse)
    ("g" "Magit (this project)" claude-workspace-magit)
    ("d" "Dired (this project)" claude-workspace-dired)
    ("r" "Refresh (--continue)" claude-workspace-refresh-session)]
   ["Teardown / modes"
    ("k" "Kill this slot" claude-workspace-kill-slot)
    ("R" "Reset (kill all)" claude-workspace-reset)
    ("t" "Toggle attention mode" claude-workspace-attention-mode)
    ("P" "Toggle width pinning" claude-workspace-pin-width-mode)]])

(provide 'claude-workspace)
;;; claude-workspace.el ends here
