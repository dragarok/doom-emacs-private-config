;;; productivity_flow.el --- River Flow Productivity System -*- lexical-binding: t -*-

;;; Commentary:
;; Higher-level abstraction layer for the productivity system.
;; Implements the "River Flow" metaphor: the system channels your energy
;; rather than fighting it.
;;
;; Key features:
;; 1. CONTEXT awareness (where you are: home, public, travel, etc.)
;; 2. ENERGY level input (you tell it how you feel)
;; 3. Neglected items naturally float up (via LAST_ACCESSED tracking)
;; 4. One button to rule them all: `rts-flow`
;;
;; Context + Energy = Intelligent task selection without remembering rules
;;
;; Requires: productivity.el (for base functions and LAST_ACCESSED tracking)

;;; Code:

(require 'productivity)
(require 'cl-lib)

;;; ===================================================================
;;; Context System - Configurable Environments
;;; ===================================================================

(defgroup rts-flow nil
  "River Flow productivity system configuration."
  :group 'productivity
  :prefix "rts-flow-")

;; Current state (persists during session)
(defvar rts-flow-current-context nil
  "Current context. Set via `rts-flow-set-context' or prompted by `rts-flow'.")

(defvar rts-flow-current-energy nil
  "Current energy level. Set via `rts-flow-set-energy' or prompted by `rts-flow'.")

;; Context definitions - fully configurable
;; NOTE: Context symbols and :tag values must be valid org-mode tags (no dashes!)
(defcustom rts-flow-contexts
  '((personalroom
     :name "Personal Room"
     :tag "personalroom"
     :emoji "🏠"
     :description "Your room with all equipment"
     :allows (:music :video :books :study :tasks :notes :instruments :talk)
     :prefers (:music :instruments :deep-work)
     :groups (room))  ; Meta-groups this context belongs to

    (othersroom
     :name "Other's Room"
     :tag "othersroom"
     :emoji "🛋️"
     :description "Someone else's space, no instruments"
     :allows (:video :books :study :tasks :notes :talk)
     :blocks (:instruments)
     :prefers (:books :study)
     :groups (room))  ; Meta-groups this context belongs to

    (workleisure
     :name "Work Leisure"
     :tag "workleisure"
     :emoji "☕"
     :description "Break time at work, easy in-progress tasks only"
     :allows (:books :study :notes)
     :blocks (:instruments :video :new-tasks :talk)
     :only-in-progress t
     :prefers (:study :books))

    (public
     :name "Public Place"
     :tag "public"
     :emoji "🏛️"
     :description "Cafe, library - no audio/video"
     :allows (:books :study :tasks :notes)
     :blocks (:instruments :video :music :talk)
     :prefers (:books :study :notes))

    (travel
     :name "Travel"
     :tag "travel"
     :emoji "✈️"
     :description "Moving around, minimal focus tasks"
     :allows (:books :notes)
     :blocks (:instruments :video :music :deep-work :new-tasks)
     :prefers (:books :notes)
     :max-effort 30)

    (outdoors
     :name "Outdoors"
     :tag "outdoors"
     :emoji "🚶"
     :description "Errands, shopping, outside tasks - only :outdoors: tagged items"
     :allows (:tasks)
     :blocks (:instruments :video :music :books :study :notes :deep-work)
     :exclusive t))  ; Only show tasks explicitly tagged with this context
  "Alist of contexts with their properties.

Each context is (SYMBOL . PLIST) where PLIST contains:
  :name        - Human readable name
  :tag         - Org-mode tag name (no dashes allowed!)
  :emoji       - Icon for display
  :description - What this context means
  :allows      - List of activity types allowed
  :blocks      - List of activity types blocked (takes precedence)
  :prefers     - List of preferred activities (weighted higher)
  :only-in-progress - If t, only show tasks already started
  :max-effort  - Maximum effort in minutes for tasks
  :groups      - List of meta-groups (e.g., 'room' matches personalroom & othersroom)

Activity types:
  :music       - Music practice (guitar, piano)
  :instruments - Requires physical instruments
  :video       - YouTube, video content
  :books       - Reading books (Boox, Kindle)
  :study       - Study materials, blogs
  :tasks       - Regular tasks
  :notes       - Org-roam notes
  :talk        - Can speak aloud
  :deep-work   - Focused challenging work
  :new-tasks   - Can start new tasks (TODO->NEXT)

Meta-groups (use as tags, matches multiple contexts):
  :room        - Matches personalroom OR othersroom"
  :type '(alist :key-type symbol :value-type plist)
  :group 'rts-flow)

;; Energy levels - configurable
(defcustom rts-flow-energy-levels
  '((high
     :name "High Energy"
     :emoji "⚡"
     :description "Feeling great, ready for challenges"
     :difficulty-tags ("Challenge" "Average")
     :effort-range (nil . nil)  ; No limit
     :prefers (:deep-work :tasks))

    (medium
     :name "Medium Energy"
     :emoji "👍"
     :description "Normal day, can do most things"
     :difficulty-tags ("Average" "Easy")
     :effort-range (nil . 60)
     :prefers (:tasks :study))

    (low
     :name "Low Energy"
     :emoji "😴"
     :description "Tired, need easy wins"
     :difficulty-tags ("Easy")
     :effort-range (nil . 30)
     :prefers (:books :notes :easy-tasks))

    (minimal
     :name "Minimal Energy"
     :emoji "🛌"
     :description "Exhausted, just maintain"
     :difficulty-tags ("Easy")
     :effort-range (nil . 15)
     :only-in-progress t
     :prefers (:notes :books)))
  "Alist of energy levels with their properties.

Each energy level is (SYMBOL . PLIST) where PLIST contains:
  :name            - Human readable name
  :emoji           - Icon for display
  :description     - What this energy means
  :difficulty-tags - Allowed task difficulty tags
  :effort-range    - (MIN . MAX) effort in minutes, nil means no limit
  :only-in-progress - If t, only show tasks already in progress
  :prefers         - Activity types weighted higher"
  :type '(alist :key-type symbol :value-type plist)
  :group 'rts-flow)

;;; ===================================================================
;;; Time Configuration
;;; ===================================================================

(defcustom rts-flow-morning-end-hour 12
  "Hour when morning ends (24h format)."
  :type 'integer
  :group 'rts-flow)

(defcustom rts-flow-evening-start-hour 18
  "Hour when evening begins (24h format)."
  :type 'integer
  :group 'rts-flow)

(defcustom rts-flow-weekend-leisure-weight 0.6
  "Weight for leisure activities on weekends (0.0-1.0)."
  :type 'float
  :group 'rts-flow)

(defcustom rts-flow-note-review-probability 0.15
  "Probability of surfacing an old note for review."
  :type 'float
  :group 'rts-flow)

(defcustom rts-flow-deep-neglect-threshold-days 30
  "Days after which an item is deeply neglected."
  :type 'integer
  :group 'rts-flow)

;;; ===================================================================
;;; Context & Energy Helpers
;;; ===================================================================

(defun rts-flow--get-context-prop (context prop)
  "Get PROP from CONTEXT definition."
  (plist-get (cdr (assq context rts-flow-contexts)) prop))

(defun rts-flow--get-energy-prop (energy prop)
  "Get PROP from ENERGY level definition."
  (plist-get (cdr (assq energy rts-flow-energy-levels)) prop))

(defun rts-flow--context-allows-p (context activity)
  "Check if CONTEXT allows ACTIVITY."
  (let ((allows (rts-flow--get-context-prop context :allows))
        (blocks (rts-flow--get-context-prop context :blocks)))
    (and (memq activity allows)
         (not (memq activity blocks)))))

(defun rts-flow--context-prefers-p (context activity)
  "Check if CONTEXT prefers ACTIVITY."
  (memq activity (rts-flow--get-context-prop context :prefers)))

(defun rts-flow--energy-prefers-p (energy activity)
  "Check if ENERGY level prefers ACTIVITY."
  (memq activity (rts-flow--get-energy-prop energy :prefers)))

(defun rts-flow--only-in-progress-p ()
  "Check if current state requires only in-progress items."
  (or (rts-flow--get-context-prop rts-flow-current-context :only-in-progress)
      (rts-flow--get-energy-prop rts-flow-current-energy :only-in-progress)))

(defun rts-flow--get-max-effort ()
  "Get maximum effort allowed by current context and energy."
  (let ((context-max (rts-flow--get-context-prop rts-flow-current-context :max-effort))
        (energy-range (rts-flow--get-energy-prop rts-flow-current-energy :effort-range)))
    (let ((energy-max (cdr energy-range)))
      (cond
       ((and context-max energy-max) (min context-max energy-max))
       (context-max context-max)
       (energy-max energy-max)
       (t nil)))))

(defun rts-flow--get-difficulty-tags ()
  "Get allowed difficulty tags from current energy level."
  (rts-flow--get-energy-prop rts-flow-current-energy :difficulty-tags))

;;; ===================================================================
;;; Context & Energy Selection UI
;;; ===================================================================

(defun rts-flow-set-context (context)
  "Set current CONTEXT interactively."
  (interactive
   (list (intern
          (completing-read
           "Context: "
           (mapcar (lambda (ctx)
                     (let ((sym (car ctx))
                           (name (plist-get (cdr ctx) :name))
                           (emoji (plist-get (cdr ctx) :emoji)))
                       (cons (format "%s %s" emoji name) sym)))
                   rts-flow-contexts)
           nil t nil nil
           (when rts-flow-current-context
             (symbol-name rts-flow-current-context))))))
  ;; Handle the cons cell from completing-read
  (when (consp context)
    (setq context (cdr context)))
  (setq rts-flow-current-context context)
  (message "Context set to: %s %s"
           (rts-flow--get-context-prop context :emoji)
           (rts-flow--get-context-prop context :name)))

(defun rts-flow-set-energy (energy)
  "Set current ENERGY level interactively."
  (interactive
   (list (intern
          (completing-read
           "Energy level: "
           (mapcar (lambda (eng)
                     (let ((sym (car eng))
                           (name (plist-get (cdr eng) :name))
                           (emoji (plist-get (cdr eng) :emoji)))
                       (cons (format "%s %s" emoji name) sym)))
                   rts-flow-energy-levels)
           nil t nil nil
           (when rts-flow-current-energy
             (symbol-name rts-flow-current-energy))))))
  ;; Handle the cons cell from completing-read
  (when (consp energy)
    (setq energy (cdr energy)))
  (setq rts-flow-current-energy energy)
  (message "Energy set to: %s %s"
           (rts-flow--get-energy-prop energy :emoji)
           (rts-flow--get-energy-prop energy :name)))

(defun rts-flow--prompt-context-and-energy ()
  "Prompt for context and energy if not set. Returns t if both are set."
  (unless rts-flow-current-context
    (call-interactively #'rts-flow-set-context))
  (unless rts-flow-current-energy
    (call-interactively #'rts-flow-set-energy))
  (and rts-flow-current-context rts-flow-current-energy))

(defun rts-flow-reset-state ()
  "Reset context and energy (will prompt on next flow)."
  (interactive)
  (setq rts-flow-current-context nil
        rts-flow-current-energy nil)
  (message "Flow state reset. Will prompt on next rts-flow."))

(defun rts-flow-set-state ()
  "Set both context AND energy in one go.
Single button to configure your current state."
  (interactive)
  (call-interactively #'rts-flow-set-context)
  (call-interactively #'rts-flow-set-energy)
  (message "State: %s %s | %s %s"
           (rts-flow--get-context-prop rts-flow-current-context :emoji)
           (rts-flow--get-context-prop rts-flow-current-context :name)
           (rts-flow--get-energy-prop rts-flow-current-energy :emoji)
           (rts-flow--get-energy-prop rts-flow-current-energy :name)))

(defun rts-flow-show-state ()
  "Display current flow state."
  (interactive)
  (let ((ctx rts-flow-current-context)
        (eng rts-flow-current-energy))
    (if (and ctx eng)
        (message "Flow State: %s %s | %s %s | Time: %s | %s"
                 (rts-flow--get-context-prop ctx :emoji)
                 (rts-flow--get-context-prop ctx :name)
                 (rts-flow--get-energy-prop eng :emoji)
                 (rts-flow--get-energy-prop eng :name)
                 (rts-flow--get-time-block)
                 (if (rts-flow--is-weekend-p) "Weekend" "Weekday"))
      (message "Flow state not set. Run rts-flow to configure."))))

;;; ===================================================================
;;; Time Detection
;;; ===================================================================

(defun rts-flow--get-time-block ()
  "Return current time block: morning, afternoon, or evening."
  (let ((hour (string-to-number (format-time-string "%H"))))
    (cond
     ((< hour rts-flow-morning-end-hour) 'morning)
     ((< hour rts-flow-evening-start-hour) 'afternoon)
     (t 'evening))))

(defun rts-flow--is-weekend-p ()
  "Return t if today is weekend."
  (> (string-to-number (format-time-string "%u")) 5))

;;; ===================================================================
;;; Task Filtering Based on Context & Energy
;;; ===================================================================

(defun rts-flow--filter-by-effort (items)
  "Filter ITEMS by maximum effort allowed."
  (let ((max-effort (rts-flow--get-max-effort)))
    (if (null max-effort)
        items
      (seq-filter
       (lambda (item)
         (let* ((marker (org-element-property :org-marker item))
                (effort (when (and marker (markerp marker))
                          (with-current-buffer (marker-buffer marker)
                            (save-excursion
                              (goto-char marker)
                              (org-entry-get nil "EFFORT"))))))
           (or (null effort)
               (<= (org-duration-to-minutes effort) max-effort))))
       items))))

(defun rts-flow--filter-by-difficulty (items)
  "Filter ITEMS by allowed difficulty tags."
  (let ((allowed-tags (rts-flow--get-difficulty-tags)))
    (if (null allowed-tags)
        items
      (seq-filter
       (lambda (item)
         (let ((tags (rts--get-task-tags item)))
           ;; Include if no difficulty tag OR has an allowed difficulty tag
           (or (not (seq-some (lambda (tag)
                                (member tag '("Challenge" "Average" "Easy")))
                              tags))
               (seq-some (lambda (tag) (member tag allowed-tags)) tags))))
       items))))

(defun rts-flow--filter-in-progress-only (items)
  "Filter ITEMS to only those already in progress (not TODO)."
  (if (not (rts-flow--only-in-progress-p))
      items
    (seq-filter
     (lambda (item)
       (let ((status (rts--get-task-todo-keyword item)))
         (not (member status '("TODO" "TOREAD" "TOSTUDY" "TOPRACTICE" "TOWATCH")))))
     items)))

(defun rts-flow--filter-no-video (items)
  "Filter out items with video/youtube tags if video not allowed."
  (if (rts-flow--context-allows-p rts-flow-current-context :video)
      items
    (seq-filter
     (lambda (item)
       (let ((tags (rts--get-task-tags item)))
         (not (seq-some (lambda (tag)
                          (member (downcase tag) '("youtube" "video" "watchlist")))
                        tags))))
     items)))

(defun rts-flow--get-context-tag (context)
  "Get the org tag name for CONTEXT."
  (rts-flow--get-context-prop context :tag))

(defun rts-flow--get-context-groups (context)
  "Get the meta-groups that CONTEXT belongs to."
  (rts-flow--get-context-prop context :groups))

(defun rts-flow--get-all-context-tags ()
  "Get list of all valid context tag names."
  (mapcar (lambda (ctx)
            (plist-get (cdr ctx) :tag))
          rts-flow-contexts))

(defun rts-flow--get-all-group-names ()
  "Get list of all meta-group names (e.g., room)."
  (delete-dups
   (apply #'append
          (mapcar (lambda (ctx)
                    (mapcar #'symbol-name
                            (plist-get (cdr ctx) :groups)))
                  rts-flow-contexts))))

(defun rts-flow--context-matches-group-p (context group-name)
  "Check if CONTEXT belongs to GROUP-NAME meta-group."
  (let ((groups (rts-flow--get-context-groups context)))
    (memq (intern group-name) groups)))

(defun rts-flow--context-exclusive-p (context)
  "Check if CONTEXT is exclusive (only shows explicitly tagged tasks)."
  (rts-flow--get-context-prop context :exclusive))

(defun rts-flow--filter-by-location-tags (items)
  "Filter out tasks tagged with context-specific tags.
Tasks tagged :personalroom: only show in personalroom context.
Tasks tagged :room: show in ANY room context (personalroom OR othersroom).
Tasks with multiple context tags show in ANY of those contexts.
Tasks with NO context tags show everywhere UNLESS context is :exclusive.

For :exclusive contexts (like outdoors), ONLY tasks with that context tag appear.

Example tags: :personalroom: :othersroom: :workleisure: :public: :travel: :outdoors:
Meta-group tags: :room: (matches personalroom and othersroom)"
  (let ((context-tags (rts-flow--get-all-context-tags))
        (group-names (rts-flow--get-all-group-names))
        (current-tag (rts-flow--get-context-tag rts-flow-current-context))
        (is-exclusive (rts-flow--context-exclusive-p rts-flow-current-context)))
    (seq-filter
     (lambda (item)
       (let* ((tags (mapcar #'downcase (rts--get-task-tags item)))
              ;; Find specific context tags on this task
              (task-context-tags (seq-filter (lambda (tag)
                                               (member tag context-tags))
                                             tags))
              ;; Find meta-group tags on this task (e.g., "room")
              (task-group-tags (seq-filter (lambda (tag)
                                             (member tag group-names))
                                           tags))
              ;; Does task have the current context tag?
              (has-current-tag (member current-tag task-context-tags))
              ;; Does task match via a meta-group?
              (matches-group (seq-some (lambda (group-tag)
                                         (rts-flow--context-matches-group-p
                                          rts-flow-current-context group-tag))
                                       task-group-tags)))
         (if is-exclusive
             ;; EXCLUSIVE context: task MUST have this context's tag
             has-current-tag
           ;; Normal context: standard filtering rules
           (cond
            ;; No location tags at all = show everywhere
            ((and (null task-context-tags) (null task-group-tags))
             t)
            ;; Has specific context tag that matches current context
            (has-current-tag t)
            ;; Has a meta-group tag and current context is in that group
            (matches-group t)
            ;; Has location tags but none match
            (t nil)))))
     items)))

(defun rts-flow--apply-all-filters (items)
  "Apply all context and energy filters to ITEMS."
  (thread-last items
               (rts-flow--filter-by-effort)
               (rts-flow--filter-by-difficulty)
               (rts-flow--filter-in-progress-only)
               (rts-flow--filter-no-video)
               (rts-flow--filter-by-location-tags)))

;;; ===================================================================
;;; Selection with Neglect Awareness
;;; ===================================================================

(defun rts-flow--calculate-points-with-neglect (task selector-type)
  "Calculate points for TASK including neglect bonus."
  (let ((base-points (rts--calculate-points task selector-type))
        (neglect-bonus (rts--calculate-neglect-bonus task)))
    (+ base-points neglect-bonus)))

(defun rts-flow--select-with-neglect-awareness (items selector-type)
  "Select an item from ITEMS with neglect-aware probability."
  (if (null items)
      nil
    (if (= (length items) 1)
        (car items)
      (let* ((item-points (mapcar (lambda (item)
                                    (cons item (rts-flow--calculate-points-with-neglect
                                                item selector-type)))
                                  items))
             (total-points (apply #'+ (mapcar #'cdr item-points)))
             (random-point (random (max 1 total-points)))
             (current-sum 0))

        (when rts-debug-mode
          (rts--debug-log "=== FLOW SELECTION ===")
          (rts--debug-log "Context: %s | Energy: %s"
                          rts-flow-current-context rts-flow-current-energy)
          (rts--debug-log "Candidates: %d | Total points: %d"
                          (length items) total-points))

        (catch 'selected
          (dolist (item-point item-points)
            (setq current-sum (+ current-sum (cdr item-point)))
            (when (>= current-sum random-point)
              (throw 'selected (car item-point))))
          (caar item-points))))))

;;; ===================================================================
;;; Activity-Specific Selectors
;;; ===================================================================

(defun rts-flow--display-and-remember (selected selector-type)
  "Display SELECTED item and remember it with old status for potential cancel.
This wraps `rts--display-selected-item' to track status changes."
  (let* ((current-status (rts--get-task-todo-keyword selected))
         (new-status (rts--determine-next-status current-status selected))
         ;; Did status actually change?
         (old-status (unless (string= current-status new-status)
                       current-status)))
    ;; Remember task WITH old status (nil if no change)
    (rts-flow--remember-task selected old-status)
    ;; Now do the actual display/clock-in/status-change
    (rts--display-selected-item selected selector-type)
    ;; Save all org buffers
    (org-save-all-org-buffers)))

(defun rts-flow-select-task ()
  "Select a task respecting context and energy filters."
  (interactive)
  (let* ((base-tasks (rts--get-base-tasks 'tasks))
         (time-filtered (rts--filter-out-future-today-tasks base-tasks))
         (filtered (rts-flow--apply-all-filters time-filtered)))
    (if filtered
        (let ((selected (rts-flow--select-with-neglect-awareness filtered 'tasks)))
          (rts-flow--display-and-remember selected 'tasks))
      (message "No tasks available for current context/energy"))))

(defun rts-flow-select-book ()
  "Select a book respecting filters."
  (interactive)
  (let* ((items (rts--get-base-tasks 'books))
         (filtered (rts-flow--apply-all-filters items)))
    (if filtered
        (let ((selected (rts-flow--select-with-neglect-awareness filtered 'books)))
          (rts-flow--display-and-remember selected 'books))
      (message "No books available for current context/energy"))))

(defun rts-flow-select-study ()
  "Select a study item respecting filters (excludes video if blocked)."
  (interactive)
  (let* ((items (rts--get-base-tasks 'study))
         (filtered (rts-flow--apply-all-filters items)))
    (if filtered
        (let ((selected (rts-flow--select-with-neglect-awareness filtered 'study)))
          (rts-flow--display-and-remember selected 'study))
      (message "No study items available for current context/energy"))))

(defun rts-flow-select-music ()
  "Select a music practice item (only if instruments allowed)."
  (interactive)
  (if (not (rts-flow--context-allows-p rts-flow-current-context :instruments))
      (message "Instruments not available in %s context"
               (rts-flow--get-context-prop rts-flow-current-context :name))
    (let* ((items (rts--get-base-tasks 'music))
           (filtered (rts-flow--apply-all-filters items)))
      (if filtered
          (let ((selected (rts-flow--select-with-neglect-awareness filtered 'music)))
            (rts-flow--display-and-remember selected 'music))
        (message "No music items available")))))

(defun rts-flow-select-leisure ()
  "Select a leisure item respecting all filters."
  (interactive)
  (let* ((items (rts--get-base-tasks 'leisure))
         ;; Filter out music if instruments not allowed
         (no-music (if (rts-flow--context-allows-p rts-flow-current-context :instruments)
                       items
                     (seq-filter
                      (lambda (item)
                        (let ((tags (rts--get-task-tags item)))
                          (not (or (member "guitaractive" tags)
                                   (member "pianoactive" tags)
                                   (member "musicactive" tags)))))
                      items)))
         (filtered (rts-flow--apply-all-filters no-music)))
    (if filtered
        (let ((selected (rts-flow--select-with-neglect-awareness filtered 'leisure)))
          (rts-flow--display-and-remember selected 'leisure))
      (message "No leisure items available for current context/energy"))))

(defun rts-flow-select-notes ()
  "Surface an old org-roam note for review."
  (interactive)
  ;; Notes don't get remembered as tasks (different flow)
  (rts-flow-surface-forgotten-note))

;;; ===================================================================
;;; Note Surfacing
;;; ===================================================================

(defun rts-flow--get-neglected-notes (days-threshold &optional limit)
  "Get org-roam notes not modified in DAYS-THRESHOLD days."
  (when (fboundp 'org-roam-node-list)
    (let* ((all-nodes (org-roam-node-list))
           (threshold-time (time-subtract (current-time)
                                          (days-to-time days-threshold)))
           (neglected (seq-filter
                       (lambda (node)
                         (let ((mtime (org-roam-node-file-mtime node)))
                           (and mtime (time-less-p mtime threshold-time))))
                       all-nodes)))
      (seq-take (seq-sort-by
                 (lambda (node) (org-roam-node-file-mtime node))
                 #'time-less-p
                 neglected)
                (or limit 10)))))

(defun rts-flow-surface-forgotten-note ()
  "Surface a note you haven't touched in a while."
  (interactive)
  (if (not (fboundp 'org-roam-node-list))
      (message "org-roam not available")
    (let ((neglected (rts-flow--get-neglected-notes
                      rts-flow-deep-neglect-threshold-days 20)))
      (if (null neglected)
          (message "No neglected notes found")
        (let ((selected (nth (random (length neglected)) neglected)))
          (org-roam-node-visit selected)
          (message "Surfaced: %s (last: %s)"
                   (org-roam-node-title selected)
                   (format-time-string "%Y-%m-%d"
                                       (org-roam-node-file-mtime selected))))))))

;;; ===================================================================
;;; Cancel - Undo Last Selection
;;; ===================================================================

(defun rts-flow-cancel ()
  "Cancel the last task selection - undo status change and clock out.

This will:
1. Clock out and DISCARD the clocked time
2. Revert status change if one was made (e.g., NEXT → TODO, STUDYING → TOSTUDY)
3. Add a LOGBOOK note indicating cancellation
4. Keep the task in last-task-marker (you can still continue it later)

Use this when rts-flow picked something you don't want to do right now."
  (interactive)
  (if (not (rts-flow--has-last-task-p))
      (message "No task to cancel")
    (let ((old-status rts-flow-last-task-old-status)
          (actual-heading nil))
      (with-current-buffer (marker-buffer rts-flow-last-task-marker)
        (save-excursion
          (goto-char rts-flow-last-task-marker)
          (org-back-to-heading t)

          ;; Get the actual heading from the task
          (setq actual-heading (org-get-heading t t t t))

          ;; 1. Clock out and discard time
          (when (org-clocking-p)
            (org-clock-cancel))  ; This discards the clock entry entirely

          ;; 2. Revert status if it was changed
          (when old-status
            (let ((current-status (org-get-todo-state)))
              (org-todo old-status)
              ;; 3. Add LOGBOOK entry for the revert
              (rts--add-state-change-logbook-entry
               current-status old-status "Cancelled via rts-flow-cancel")))

          ;; If no status change was made, still add a cancel note
          (unless old-status
            (rts-flow--add-cancel-note))))

      ;; Clear the old-status so cancel can't be called twice
      (setq rts-flow-last-task-old-status nil)

      ;; Save all org buffers
      (org-save-all-org-buffers)

      (message "Cancelled: %s%s"
               actual-heading
               (if old-status
                   (format " (reverted to %s)" old-status)
                 "")))))

(defun rts-flow--add-cancel-note ()
  "Add a simple cancellation note to the current task's LOGBOOK."
  (let ((timestamp (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (org-back-to-heading t)
    (let* ((heading-end (save-excursion (org-end-of-subtree t t) (point)))
           (logbook-start (save-excursion
                            (when (re-search-forward "^[ \t]*:LOGBOOK:" heading-end t)
                              (line-beginning-position)))))
      (if logbook-start
          ;; LOGBOOK exists, add note after :LOGBOOK: line
          (progn
            (goto-char logbook-start)
            (forward-line 1)
            (insert (format "- Cancelled via rts-flow-cancel %s\n" timestamp)))
        ;; No LOGBOOK, create one
        (progn
          (org-end-of-meta-data)
          (insert ":LOGBOOK:\n")
          (insert (format "- Cancelled via rts-flow-cancel %s\n" timestamp))
          (insert ":END:\n"))))))

;;; ===================================================================
;;; Manual Clock-In with Flow Tracking
;;; ===================================================================

(defun rts-flow-clock-in ()
  "Clock into current task with full rts-flow tracking.
Works in both org buffers and org-agenda.
Updates LAST_ACCESSED, remembers task for cancel, etc."
  (interactive)
  (cond
   ;; In org-agenda
   ((derived-mode-p 'org-agenda-mode)
    (let* ((marker (or (org-get-at-bol 'org-marker)
                       (org-agenda-error)))
           (buffer (marker-buffer marker)))
      (when (and marker buffer)
        (with-current-buffer buffer
          (save-excursion
            (goto-char marker)
            (rts-flow--clock-in-at-point))))))

   ;; In org buffer
   ((derived-mode-p 'org-mode)
    (save-excursion
      (org-back-to-heading t)
      (rts-flow--clock-in-at-point)))

   ;; Not in org context
   (t
    (message "Not in an org buffer or agenda"))))

(defun rts-flow--clock-in-at-point ()
  "Clock in at current heading with full rts-flow tracking.
Assumes point is at or before an org heading."
  (org-back-to-heading t)
  (let* ((heading (org-get-heading t t t t))
         (current-status (org-get-todo-state))
         (marker (copy-marker (point))))

    ;; Update LAST_ACCESSED
    (org-set-property "LAST_ACCESSED" (format-time-string "[%Y-%m-%d %a]"))

    ;; Remember for rts-flow-cancel (no status change on manual clock-in)
    (setq rts-flow-last-task-marker marker
          rts-flow-last-task-heading heading
          rts-flow-last-task-old-status nil)

    ;; Clock in
    (org-clock-in)

    ;; Save all org buffers
    (org-save-all-org-buffers)

    (message "Clocked in: %s" heading)))

;;; ===================================================================
;;; Manual Clock-In via Consult (Any Task)
;;; ===================================================================

(defun rts-flow-manual ()
  "Manually clock into ANY task via consult selection.
Uses rts-flow tracking so cancel/continue work properly.

This is for when you're already doing something and want to
clock in without navigating to the task. Shows all tasks
(regular, mundane, study, music, etc.) in one list."
  (interactive)
  (let* ((candidates (rts--get-all-task-candidates))
         (selected (when candidates
                     (consult--read candidates
                                    :prompt "Clock into task: "
                                    :require-match t
                                    :sort nil
                                    :category 'org-task))))
    (if (not selected)
        (message "No task selected")
      (let ((marker (cdr (assoc selected candidates))))
        (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
          (with-current-buffer (marker-buffer marker)
            (save-excursion
              (goto-char marker)
              (org-back-to-heading t)

              (let ((heading (org-get-heading t t t t)))
                ;; Update LAST_ACCESSED
                (org-set-property "LAST_ACCESSED" (format-time-string "[%Y-%m-%d %a]"))

                ;; Remember for rts-flow-cancel (no status change on manual clock-in)
                (setq rts-flow-last-task-marker (copy-marker (point))
                      rts-flow-last-task-heading heading
                      rts-flow-last-task-old-status nil)

                ;; Clock in
                (org-clock-in)

                ;; Save all org buffers
                (org-save-all-org-buffers)

                (message "Clocked in: %s" heading)))))))))

;;; ===================================================================
;;; Clock Goto - Smart Navigation
;;; ===================================================================

(defun rts-flow--has-beancount-marker-p ()
  "Check if there's a valid beancount marker to jump to."
  (and (boundp 'beancount-helper-last-marker)
       beancount-helper-last-marker
       (markerp beancount-helper-last-marker)
       (buffer-live-p (marker-buffer beancount-helper-last-marker))))

(defun rts-flow-clock-goto ()
  "Go to the last task/transaction we interacted with.

Priority order:
1. If org-clock is running, go to clocked task (like org-clock-goto)
2. Otherwise, go to rts-last-task-marker (set by add-clock-time-* functions)
3. Otherwise, go to rts-flow-last-task-marker (set by rts-flow commands)
4. Otherwise, go to beancount-helper-last-marker (set by beancount functions)

This ensures you can always navigate to what you just worked on,
whether it's a clocked task, added time, or a beancount transaction."
  (interactive)
  (cond
   ;; Active clock - use org-clock-goto
   ((org-clocking-p)
    (org-clock-goto)
    (message "Jumped to clocked task: %s" (org-get-heading t t t t)))

   ;; Last task from add-clock-time functions
   ((and rts-last-task-marker
         (markerp rts-last-task-marker)
         (buffer-live-p (marker-buffer rts-last-task-marker)))
    (switch-to-buffer (marker-buffer rts-last-task-marker))
    (goto-char rts-last-task-marker)
    (org-back-to-heading t)
    (org-show-entry)
    (org-show-children)
    (recenter)
    (message "Jumped to last task: %s" (or rts-last-task-heading
                                           (org-get-heading t t t t))))

   ;; Last task from rts-flow commands
   ((rts-flow--has-last-task-p)
    (switch-to-buffer (marker-buffer rts-flow-last-task-marker))
    (goto-char rts-flow-last-task-marker)
    (org-back-to-heading t)
    (org-show-entry)
    (org-show-children)
    (recenter)
    (message "Jumped to flow task: %s" (or rts-flow-last-task-heading
                                           (org-get-heading t t t t))))

   ;; Last beancount transaction
   ((rts-flow--has-beancount-marker-p)
    (switch-to-buffer (marker-buffer beancount-helper-last-marker))
    (goto-char beancount-helper-last-marker)
    (recenter)
    (message "Jumped to beancount transaction: %s"
             (or (bound-and-true-p beancount-helper-last-description)
                 "last transaction")))

   ;; Nothing to go to
   (t
    (message "No task/transaction to jump to"))))

;;; ===================================================================
;;; Clock Out - Smart Completion
;;; ===================================================================

(defun rts-flow-clock-out ()
  "Clock out with smart behavior based on file type.

For habits in recurring.org:
  - Automatically marks as DONE
  - No prompts at all

For tasks in other files:
  - Asks whether to mark done (default: no)
  - Asks for work mode tag: normal, focus, or deepwork"
  (interactive)
  (if (not (org-clocking-p))
      (message "No active clock to clock out")
    (let* ((marker org-clock-marker)
           (buffer (marker-buffer marker))
           (position (marker-position marker))
           (file-name (when buffer (buffer-file-name buffer)))
           (is-habit (and file-name
                          (string-match-p "recurring\\.org$" file-name))))

      (if is-habit
          ;; Habit in recurring.org: auto-DONE, no prompts
          (progn
            (org-clock-out)
            (when (and buffer position)
              (with-current-buffer buffer
                (save-excursion
                  (goto-char position)
                  (org-back-to-heading t)
                  (org-todo "DONE"))))
            (org-save-all-org-buffers)
            (message "Habit completed and marked DONE"))

        ;; Non-habit: ask about done and work mode
        (let ((mark-done (y-or-n-p "Mark as DONE? "))
              (work-mode (completing-read
                          "Work mode (default: normal): "
                          '("normal" "focus" "deepwork")
                          nil t nil nil "normal")))

          ;; Clock out first
          (org-clock-out)

          ;; Apply changes to the task
          (when (and buffer position)
            (with-current-buffer buffer
              (save-excursion
                (goto-char position)
                (org-back-to-heading t)

                ;; Mark done if requested
                (when mark-done
                  (org-todo "DONE"))

                ;; Add work mode tag if not normal
                (unless (string= work-mode "normal")
                  (org-toggle-tag work-mode 'on)))))

          (org-save-all-org-buffers)

          ;; Build informative message
          (message "Clocked out%s%s"
                   (if mark-done " and marked DONE" "")
                   (if (string= work-mode "normal")
                       ""
                     (format ", added :%s: tag" work-mode))))))))

;;; ===================================================================
;;; Last Task Tracking
;;; ===================================================================

(defvar rts-flow-last-task-marker nil
  "Marker to the last task selected by rts-flow.")

(defvar rts-flow-last-task-heading nil
  "Heading of the last task selected by rts-flow.")

(defvar rts-flow-last-task-old-status nil
  "The status BEFORE rts-flow changed it, or nil if no change was made.
Used by `rts-flow-cancel' to revert status changes.")

(defun rts-flow--remember-task (task &optional old-status)
  "Remember TASK as the last selected task.
OLD-STATUS is the status before any change, nil if no change was made."
  (let ((marker (org-element-property :org-marker task))
        (heading (org-element-property :raw-value task)))
    (setq rts-flow-last-task-marker marker
          rts-flow-last-task-heading heading
          rts-flow-last-task-old-status old-status)))

(defun rts-flow--has-last-task-p ()
  "Check if there's a valid last task to continue."
  (and rts-flow-last-task-marker
       (markerp rts-flow-last-task-marker)
       (buffer-live-p (marker-buffer rts-flow-last-task-marker))))

(defun rts-flow-continue ()
  "Continue working on the last task.
Clocks back into the previous task without selecting a new one."
  (interactive)
  (if (not (rts-flow--has-last-task-p))
      (progn
        (message "No previous task to continue. Running rts-flow...")
        (rts-flow))
    (with-current-buffer (marker-buffer rts-flow-last-task-marker)
      (save-excursion
        (goto-char rts-flow-last-task-marker)
        (org-back-to-heading t)
        ;; Update LAST_ACCESSED
        (org-set-property "LAST_ACCESSED" (format-time-string "[%Y-%m-%d %a]"))
        (org-clock-in)))
    ;; Save all org buffers
    (org-save-all-org-buffers)
    (message "Continuing: %s" rts-flow-last-task-heading)))

;;; ===================================================================
;;; THE FLOW - Main Entry Point
;;; ===================================================================

(defun rts-flow--pick-new-task ()
  "Internal function to pick a new task based on context/energy/time."
  (let* ((context rts-flow-current-context)
         (energy rts-flow-current-energy)
         (time-block (rts-flow--get-time-block))
         (is-weekend (rts-flow--is-weekend-p))
         (roll (/ (random 100) 100.0)))

    (when rts-debug-mode
      (rts--debug-log "=== RTS FLOW ===")
      (rts--debug-log "Context: %s | Energy: %s | Time: %s | Weekend: %s"
                      context energy time-block is-weekend))

    ;; Decision tree based on context capabilities
    (cond
     ;; Outdoors: ONLY tasks tagged :outdoors: (exclusive context)
     ((eq context 'outdoors)
      (rts-flow-select-task))

     ;; Travel: very limited options
     ((eq context 'travel)
      (if (< roll 0.5)
          (rts-flow-select-book)
        (rts-flow-select-notes)))

     ;; Public: no audio/video
     ((eq context 'public)
      (let ((choice (random 4)))
        (cond
         ((= choice 0) (rts-flow-select-book))
         ((= choice 1) (rts-flow-select-study))
         ((= choice 2) (rts-flow-select-notes))
         (t (rts-flow-select-task)))))

     ;; Work leisure: in-progress easy things only
     ((eq context 'workleisure)
      (if (< roll 0.5)
          (rts-flow-select-study)
        (rts-flow-select-book)))

     ;; Others room: no instruments
     ((eq context 'othersroom)
      (cond
       ;; Evening/weekend: leisure weighted
       ((or is-weekend (eq time-block 'evening))
        (let ((choice (random 4)))
          (cond
           ((= choice 0) (rts-flow-select-book))
           ((= choice 1) (rts-flow-select-study))
           ((= choice 2) (rts-flow-select-leisure))
           (t (rts-flow-select-task)))))
       ;; Work time
       (t
        (if (< roll 0.3)
            (rts-flow-select-study)
          (rts-flow-select-task)))))

     ;; Personal room: full access
     ((eq context 'personalroom)
      (cond
       ;; Low/minimal energy: easy stuff
       ((memq energy '(low minimal))
        (let ((choice (random 3)))
          (cond
           ((= choice 0) (rts-flow-select-book))
           ((= choice 1) (rts-flow-select-notes))
           (t (rts-flow-select-leisure)))))

       ;; Evening: leisure time
       ((eq time-block 'evening)
        (let ((choice (random 5)))
          (cond
           ((= choice 0) (rts-flow-select-book))
           ((= choice 1) (rts-flow-select-music))
           ((= choice 2) (rts-flow-select-study))
           ((= choice 3) (rts-flow-select-leisure))
           (t (rts-flow-select-task)))))

       ;; Weekend: mixed leisure and tasks
       (is-weekend
        (if (< roll rts-flow-weekend-leisure-weight)
            (let ((choice (random 4)))
              (cond
               ((= choice 0) (rts-flow-select-book))
               ((= choice 1) (rts-flow-select-music))
               ((= choice 2) (rts-flow-select-study))
               (t (rts-flow-select-leisure))))
          (rts-flow-select-task)))

       ;; Morning: focus time
       ((eq time-block 'morning)
        (if (< roll 0.15)
            (rts-flow-select-notes)
          (rts-flow-select-task)))

       ;; Afternoon: mixed with study breaks
       (t
        (cond
         ((< roll 0.15) (rts-flow-select-notes))
         ((< roll 0.35) (rts-flow-select-study))
         (t (rts-flow-select-task))))))

     ;; Fallback for any new contexts
     (t
      (rts-flow-select-task)))))

(defun rts-flow ()
  "THE zero-decision entry point. Let the river carry you.

Picks a new activity based on:
- What's allowed in your current context
- Your current energy level
- Time of day
- What's been neglected

Use `rts-flow-continue' to resume the last task.
Use `rts-flow-cancel' to undo the last selection."
  (interactive)

  ;; Prompt for context and energy if needed
  (unless (and rts-flow-current-context rts-flow-current-energy)
    (rts-flow--prompt-context-and-energy))

  ;; Always pick a new task
  (rts-flow--pick-new-task))

;;; ===================================================================
;;; Weekly Report
;;; ===================================================================

(defun rts-flow--find-neglected-items (selector-type days-threshold)
  "Find items of SELECTOR-TYPE not accessed in DAYS-THRESHOLD days."
  (let ((items (rts--get-base-tasks selector-type)))
    (seq-filter
     (lambda (item)
       (let ((days (rts--get-days-since-accessed item)))
         (or (null days) (> days days-threshold))))
     items)))

(defun rts-flow-weekly-neglect-report ()
  "Generate a report of neglected items."
  (interactive)
  (let ((neglected-books (rts-flow--find-neglected-items 'books 14))
        (neglected-study (rts-flow--find-neglected-items 'study 7))
        (neglected-leisure (rts-flow--find-neglected-items 'leisure 14))
        (stale-notes (when (fboundp 'org-roam-node-list)
                       (rts-flow--get-neglected-notes 30 15))))

    (with-current-buffer (get-buffer-create "*Weekly Neglect Report*")
      (read-only-mode -1)
      (erase-buffer)
      (org-mode)

      (insert "#+TITLE: Weekly Neglect Report\n")
      (insert "#+DATE: " (format-time-string "[%Y-%m-%d %a]") "\n\n")

      (insert "* Summary\n\n")
      (insert (format "| Category | Neglected | Threshold |\n"))
      (insert "|----------+-----------+-----------|\n")
      (insert (format "| Books    | %d        | 14 days   |\n" (length neglected-books)))
      (insert (format "| Study    | %d        | 7 days    |\n" (length neglected-study)))
      (insert (format "| Leisure  | %d        | 14 days   |\n" (length neglected-leisure)))
      (when stale-notes
        (insert (format "| Notes    | %d        | 30 days   |\n" (length stale-notes))))

      (insert "\n* Details\n")

      (when neglected-books
        (insert "\n** Books (14+ days)\n")
        (dolist (book neglected-books)
          (insert (format "- %s\n" (org-element-property :raw-value book)))))

      (when neglected-study
        (insert "\n** Study (7+ days)\n")
        (dolist (item neglected-study)
          (insert (format "- %s\n" (org-element-property :raw-value item)))))

      (goto-char (point-min))
      (read-only-mode 1)
      (pop-to-buffer (current-buffer)))))

;;; ===================================================================
;;; Unified Task Addition - rts-flow-add-task
;;; ===================================================================

;; File paths (derived from org-agenda-directory)
(defvar rts-flow-study-file nil
  "Path to study/blogs file. Set from org-agenda-directory.")

(defvar rts-flow-guitar-file nil
  "Path to guitar practice file. Set from org-agenda-directory.")

(defvar rts-flow-piano-file nil
  "Path to piano practice file. Set from org-agenda-directory.")

(defvar rts-flow-mundane-file nil
  "Path to mundane tasks file. Set from org-agenda-directory.")

(defun rts-flow--init-file-paths ()
  "Initialize file paths from org-agenda-directory."
  (when (and (boundp 'org-agenda-directory) org-agenda-directory)
    (setq rts-flow-study-file (expand-file-name "log_blogsnvideos.org" org-agenda-directory)
          rts-flow-guitar-file (expand-file-name "log_guitar.org" org-agenda-directory)
          rts-flow-piano-file (expand-file-name "log_piano.org" org-agenda-directory)
          rts-flow-mundane-file (expand-file-name "mundane.org" org-agenda-directory))))

;; Initialize when loaded (will also work if org-agenda-directory is set later)
(with-eval-after-load 'org
  (rts-flow--init-file-paths))

(defun rts-flow--find-heading (file-path heading-pattern)
  "Find heading matching HEADING-PATTERN in FILE-PATH and return marker after it.
HEADING-PATTERN is a regex like 'In Progress' or 'Proximity To Study'."
  (with-current-buffer (find-file-noselect file-path)
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward (format "^\\*+ %s" heading-pattern) nil t)
          (progn
            (org-end-of-subtree t t)
            (copy-marker (point)))
        ;; Fallback to end of file if heading not found
        (goto-char (point-max))
        (copy-marker (point))))))

(defun rts-flow--add-study-task (title)
  "Add a study task with TITLE to the study file under In Progress.
Creates as STUDYING (active). Cancel reverts to TOSTUDY."
  (rts-flow--init-file-paths)
  (let* ((tags-input (completing-read-multiple
                      "Tags (comma-separated, TAB to complete): "
                      '("technical" "blog" "video" "tutorial" "documentation" "article")))
         (tags-str (if tags-input
                       (concat ":" (mapconcat #'identity tags-input ":") ":")
                     ""))
         (url (read-string "URL: "))
         ;; Find "In Progress" heading with studyactive tag
         (marker (rts-flow--find-heading rts-flow-study-file "In Progress.*:studyactive:")))

    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (unless (bolp) (insert "\n"))
        ;; Create as STUDYING (active state)
        (insert (format "** STUDYING %s %s\n" title tags-str))
        (when (and url (not (string-empty-p url)))
          (insert "\n" url "\n"))

        ;; Move back to the heading we just created
        (forward-line -2)
        (when (and url (not (string-empty-p url)))
          (forward-line -1))
        (org-back-to-heading t)

        ;; Remember for rts-flow-cancel (revert STUDYING → TOSTUDY)
        (setq rts-flow-last-task-marker (copy-marker (point))
              rts-flow-last-task-heading title
              rts-flow-last-task-old-status "TOSTUDY")

        ;; Clock in
        (org-clock-in)

        (org-save-all-org-buffers)
        (message "Added study task: %s" title)))))

(defun rts-flow--add-practice-task (title instrument)
  "Add a practice task with TITLE for INSTRUMENT (guitar or piano).
Creates as PRACTICING (active). Cancel reverts to TOPRACTICE."
  (rts-flow--init-file-paths)
  (let* ((file-path (if (eq instrument 'guitar)
                        rts-flow-guitar-file
                      rts-flow-piano-file))
         ;; Find "In Progress" heading with appropriate tag
         (tag-pattern (if (eq instrument 'guitar)
                          "In Progress.*:guitaractive:"
                        "In Progress.*:pianoactive:"))
         (marker (rts-flow--find-heading file-path tag-pattern)))

    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (unless (bolp) (insert "\n"))
        ;; Create as PRACTICING (active state)
        (insert (format "** PRACTICING %s\n" title))
        (insert ":PROPERTIES:\n")
        (insert (format ":CREATED: [%s]\n" (format-time-string "%Y-%m-%d %a")))
        (insert ":END:\n")

        ;; Move back to the heading we just created
        (forward-line -4)
        (org-back-to-heading t)

        ;; Remember for rts-flow-cancel (revert PRACTICING → TOPRACTICE)
        (setq rts-flow-last-task-marker (copy-marker (point))
              rts-flow-last-task-heading title
              rts-flow-last-task-old-status "TOPRACTICE")

        ;; Clock in
        (org-clock-in)

        (org-save-all-org-buffers)
        (message "Added %s practice: %s" instrument title)))))

(defun rts-flow--add-mundane-task (title)
  "Add a mundane task with TITLE to the mundane file."
  (rts-flow--init-file-paths)
  (let* ((tags-input (completing-read-multiple
                      "Tags (comma-separated, TAB to complete): "
                      '("Active" "Energetic" "ModeratelyLazy" "Lazy"
                        "Morning" "Day" "Evening"
                        "home" "personal" "health" "errand")))
         (tags-str (if tags-input
                       (concat ":" (mapconcat #'identity tags-input ":") ":")
                     ":Active:Energetic:")))

    (with-current-buffer (find-file-noselect rts-flow-mundane-file)
      (save-excursion
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert (format "* TONOTDO [#F] %s %s\n" title tags-str))
        (insert ":PROPERTIES:\n")
        (insert (format ":CREATED:  [%s]\n" (format-time-string "%Y-%m-%d %a %H:%M")))
        (insert ":END:\n")

        ;; Move back to the heading we just created
        (forward-line -4)
        (org-back-to-heading t)

        ;; Remember for rts-flow-cancel (no status change since newly created)
        (setq rts-flow-last-task-marker (copy-marker (point))
              rts-flow-last-task-heading title
              rts-flow-last-task-old-status nil)

        ;; Clock in
        (org-clock-in)

        (org-save-all-org-buffers)
        (message "Added mundane task: %s" title)))))

(defun rts-flow-add ()
  "Unified add command - tasks, beancount, clock time.
One entry point for all additions."
  (interactive)
  (let ((choice (completing-read
                 "Add: "
                 '("Task" "Beancount Income" "Beancount Expense"
                   "Clock Time by Offset" "Clock Time Direct")
                 nil t)))
    (cond
     ((string= choice "Task")
      (rts-flow--add-task-dispatch))
     ((string= choice "Beancount Income")
      (beancount-helper-add-income))
     ((string= choice "Beancount Expense")
      (beancount-helper-add-expense))
     ((string= choice "Clock Time by Offset")
      (add-clock-time-by-offset))
     ((string= choice "Clock Time Direct")
      (add-clock-time-direct)))))

(defun rts-flow--add-task-dispatch ()
  "Dispatch to appropriate task addition based on destination."
  (let* ((title (read-string "Task title: "))
         (destination (completing-read
                       "Add to: "
                       '("Tasks" "Project" "Study" "Guitar" "Piano" "Mundane")
                       nil t)))
    (cond
     ;; Tasks - use existing instant task logic
     ((string= destination "Tasks")
      (let* ((priority (completing-read "Priority: " '("A" "B" "C" "D" "E" "F") nil t nil nil "C"))
             (effort (read-string "Effort (e.g., 1:00): " "1:00"))
             (category (completing-read "Category: "
                                        rts-instant-task-categories
                                        nil nil nil nil
                                        (or rts-instant-task-last-category
                                            (car rts-instant-task-categories))))
             (time-tag (rts--suggest-time-of-day-tag))
             (tags-input (completing-read-multiple
                          "Tags (comma-separated, TAB to complete): "
                          rts-instant-task-common-tags))
             (all-tags (append tags-input (list time-tag "Active"))))

        (setq rts-instant-task-last-category category)

        (let ((task-marker (rts--create-instant-task title priority effort category all-tags)))
          (when task-marker
            (with-current-buffer (marker-buffer task-marker)
              (save-excursion
                (goto-char task-marker)
                (org-todo "NEXT")
                (rts--add-state-change-logbook-entry "TODO" "NEXT" "Added via rts-flow-add-task")

                ;; Remember for rts-flow-cancel (status changed from TODO to NEXT)
                (setq rts-flow-last-task-marker (copy-marker (point))
                      rts-flow-last-task-heading title
                      rts-flow-last-task-old-status "TODO")

                (org-clock-in)))
            (message "Created and clocked in: %s" title)))))

     ;; Project - use existing project task logic
     ((string= destination "Project")
      (let* ((projects (rts--get-all-projects))
             (project-names (mapcar #'car projects))
             (selected-project-name (completing-read "Add to project: " project-names nil t))
             (project-marker (cdr (assoc selected-project-name projects)))
             (priority (completing-read "Priority: " '("A" "B" "C" "D" "E" "F") nil t nil nil "C")))

        (when project-marker
          (with-current-buffer (marker-buffer project-marker)
            (save-excursion
              (goto-char project-marker)
              (let ((template-marker nil))
                (org-map-entries
                 (lambda ()
                   (unless template-marker
                     (when (member (org-get-todo-state) '("NEXT" "TODO"))
                       (setq template-marker (copy-marker (point))))))
                 nil 'tree)

                (if template-marker
                    (let ((new-marker (rts--clone-task-structure template-marker title priority)))
                      ;; rts--activate-project-task does: TODO->NEXT, schedule, clock-in
                      (rts--activate-project-task new-marker)
                      (rts--ensure-only-last-has-blocker project-marker)

                      ;; Remember for rts-flow-cancel - go back to heading and get fresh marker
                      (goto-char new-marker)
                      (org-back-to-heading t)
                      (setq rts-flow-last-task-marker (copy-marker (point))
                            rts-flow-last-task-heading title
                            rts-flow-last-task-old-status "TODO")

                      (message "Created project task: %s" title))
                  (message "No template task found in project %s" selected-project-name))))))))

     ;; Study
     ((string= destination "Study")
      (rts-flow--add-study-task title))

     ;; Guitar
     ((string= destination "Guitar")
      (rts-flow--add-practice-task title 'guitar))

     ;; Piano
     ((string= destination "Piano")
      (rts-flow--add-practice-task title 'piano))

     ;; Mundane
     ((string= destination "Mundane")
      (rts-flow--add-mundane-task title)))))

(provide 'productivity_flow)
;;; productivity_flow.el ends here
