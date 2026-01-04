;;; productivity.el --- Task productivity and clock management functions -*- lexical-binding: t -*-

;;; Commentary:
;; Comprehensive productivity functions for org-mode task management
;; including universal clock time functions that work in both agenda and org mode.

;;; Code:

;;; Last Interacted Task Tracking (shared with productivity_flow.el)
(defvar rts-last-task-marker nil
  "Marker to the last task we interacted with (clock-in, add time, etc.).
This is updated by clock time functions and used by rts-flow-clock-goto.")

(defvar rts-last-task-heading nil
  "Heading of the last task we interacted with.")

;;; Unified Selector Configuration
(defvar rts-debug-mode t
  "When non-nil, show debug information about task selection and scoring.")

(defvar rts-difficulty-tags '("Challenge" "Average" "Easy")
  "List of difficulty tags.")

(defvar rts-energy-tags '("Lazy" "ModeratelyLazy" "Energetic")
  "List of energy level tags.")

(defvar rts-time-tags '("Morning" "Day" "Evening")
  "List of time of day tags.")

(defvar rts-priority-points
  '(("A" . 15) ("B" . 8) ("C" . 4) ("D" . 3) ("E" . 2) ("F" . 1))
  "Points assigned to each priority level for probability calculation.")

(defvar rts-leisure-status-points
  '(("SUMMARIZING" . 10) ("READING" . 8) ("REREADING" . 2) ("TOREAD" . 1)
    ("PRACTICING" . 10) ("REPRACTICING" . 3) ("TOPRACTICE" . 1)
    ("STUDYING" . 10) ("REVISING" . 3) ("TOSTUDY" . 1))
  "Points assigned to each leisure status for probability calculation.")

;;; Core Helper Functions

(defun rts--get-current-time-of-day ()
  "Return current time of day tag based on current time."
  (let ((hour (string-to-number (format-time-string "%H"))))
    (cond
     ((<= hour 11) "Morning")
     ((<= hour 17) "Day")
     (t "Evening"))))

(defun rts--get-task-priority (element)
  "Get priority from org element."
  (let ((priority (org-element-property :priority element)))
    (when priority
      (char-to-string priority))))

(defun rts--get-task-tags (element)
  "Get tags from org element."
  (org-element-property :tags element))

(defun rts--get-task-todo-keyword (task)
  "Get the TODO keyword from a task element."
  (org-element-property :todo-keyword task))

(defun rts--has-tag-p (tags target-tag)
  "Check if TAGS list contains TARGET-TAG."
  (member target-tag tags))

(defun rts--has-any-tag-p (tags tag-list)
  "Check if TAGS contains any tag from TAG-LIST."
  (seq-some (lambda (tag) (member tag tags)) tag-list))

(defun rts--debug-log (format-string &rest args)
  "Log debug message if debug mode is enabled."
  (when rts-debug-mode
    (let ((debug-buffer (get-buffer-create "*RTS Debug*"))
          (message (apply #'format format-string args)))
      (with-current-buffer debug-buffer
        (goto-char (point-max))
        (insert (format "%s [RTS DEBUG] %s\n"
                        (format-time-string "%H:%M:%S") message))
        (goto-char (point-max)))
      ;; Also send to messages for backup
      (message "[RTS DEBUG] %s" message))))

;;; Task-specific Helper Functions (for scheduled/deadline tasks)

(defun rts--is-future-time-today-p (task-tags current-time)
  "Check if task has a future time tag for today."
  (let ((has-time-tag (rts--has-any-tag-p task-tags rts-time-tags)))
    (when has-time-tag
      (cond
       ((string= current-time "Morning")
        (or (rts--has-tag-p task-tags "Day")
            (rts--has-tag-p task-tags "Evening")))
       ((string= current-time "Day")
        (rts--has-tag-p task-tags "Evening"))
       (t nil)))))

(defun rts--filter-out-future-today-tasks (tasks)
  "Filter out tasks scheduled for later today."
  (let ((current-time (rts--get-current-time-of-day)))
    (seq-filter
     (lambda (task)
       (let ((tags (rts--get-task-tags task)))
         (not (rts--is-future-time-today-p tags current-time))))
     tasks)))

(defun rts--filter-by-difficulty-energy (tasks difficulty energy)
  "Filter TASKS by DIFFICULTY and ENERGY tags."
  (seq-filter
   (lambda (task)
     (let ((tags (rts--get-task-tags task)))
       (and (rts--has-tag-p tags difficulty)
            (rts--has-tag-p tags energy))))
   tasks))

(defun rts--filter-by-time-of-day (tasks time-tag)
  "Filter TASKS by TIME-TAG."
  (seq-filter
   (lambda (task)
     (rts--has-tag-p (rts--get-task-tags task) time-tag))
   tasks))

(defun rts--sort-by-time-priority (tasks)
  "Sort tasks by time of day priority (Morning -> Day -> Evening)."
  (sort tasks
        (lambda (a b)
          (let ((tags-a (rts--get-task-tags a))
                (tags-b (rts--get-task-tags b)))
            (cond
             ((and (rts--has-tag-p tags-a "Morning")
                   (not (rts--has-tag-p tags-b "Morning"))) t)
             ((and (rts--has-tag-p tags-a "Day")
                   (rts--has-tag-p tags-b "Evening")) t)
             (t nil))))))

(defun rts--get-priority-tasks (tasks)
  "Get tasks with priority A."
  (seq-filter
   (lambda (task)
     (string= (rts--get-task-priority task) "A"))
   tasks))

(defun rts--get-lower-priority-tasks (tasks)
  "Get tasks with priority B and below."
  (seq-filter
   (lambda (task)
     (let ((priority (rts--get-task-priority task)))
       (and priority (not (string= priority "A")))))
   tasks))

(defun rts--calculate-task-points (task)
  "Calculate points for a task based on its priority."
  (let* ((priority (rts--get-task-priority task))
         (points (cdr (assoc priority rts-priority-points))))
    (or points 1)))

(defun rts--is-habit-p (task)
  "Check if TASK is a habit by looking for style: habit property."
  (let ((style (org-element-property :STYLE task)))
    (and style (string= (downcase style) "habit"))))

(defun rts--is-project-p (task)
  "Check if TASK is a project by looking for 'proj' tag."
  (let ((tags (rts--get-task-tags task)))
    (rts--has-tag-p tags "proj")))

(defun rts--should-change-status-p (task)
  "Determine if we should change the TODO status of TASK."
  (not (or (rts--is-habit-p task)
           (rts--is-project-p task))))

;;; Status Transition Functions

(defun rts--determine-next-status (current-todo task)
  "Determine the next status based on current TODO keyword and task type."
  ;; Don't change status for habits and projects
  (if (not (rts--should-change-status-p task))
      current-todo
    ;; Normal status progression for other tasks
    (cond
     ((string= current-todo "TODO") "NEXT")
     ((string= current-todo "TOREAD") "READING")
     ((string= current-todo "TOWATCH") "WATCHING")
     ((string= current-todo "TOSTUDY") "STUDYING")
     ((string= current-todo "TOPRACTICE") "PRACTICING")
     ;; Default case - keep current status
     (t current-todo))))

(defun rts--should-refile-to-in-progress-p (old-status new-status)
  "Check if task should be refiled to In Progress based on status change."
  (and (not (string= old-status new-status))
       (or (and (string= old-status "TOREAD") (string= new-status "READING"))
           (and (string= old-status "TOSTUDY") (string= new-status "STUDYING"))
           (and (string= old-status "TOPRACTICE") (string= new-status "PRACTICING")))))

(defun rts--find-in-progress-heading (buffer)
  "Find the 'In Progress' heading in BUFFER. Returns marker or nil."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^\\*+ In Progress" nil t)
        (point-marker)))))

(defun rts--add-state-change-logbook-entry (old-state new-state &optional reason)
  "Add a state change entry to the current task's LOGBOOK.
If REASON is provided, it will be added as an indented line below the state change."
  (let ((timestamp (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (org-back-to-heading t)
    (let* ((heading-start (point))
           (heading-end (save-excursion 
                          (org-end-of-subtree t t)
                          (point)))
           ;; Search for existing LOGBOOK drawer after the heading line
           (logbook-region (save-excursion
                             (goto-char heading-start)
                             (forward-line 1) ; Skip the heading line itself
                             (when (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" heading-end t)
                               (let ((lb-start (line-beginning-position)))
                                 (when (re-search-forward "^[ \t]*:END:[ \t]*$" heading-end t)
                                   (cons lb-start (line-beginning-position))))))))
      
      (if logbook-region
          ;; LOGBOOK exists, add entry after :LOGBOOK: line
          (progn
            (goto-char (car logbook-region))
            (forward-line 1)
            (insert (format "- State \"%s\" from \"%s\" %s \\\\\n" new-state old-state timestamp))
            (when reason
              (insert (format "  REASON: %s\n" reason))))
        ;; No LOGBOOK, create one after metadata
        (progn
          (goto-char heading-start)
          (org-end-of-meta-data)
          (insert ":LOGBOOK:\n")
          (insert (format "- State \"%s\" from \"%s\" %s \\\\\n" new-state old-state timestamp))
          (when reason
            (insert (format "  REASON: %s\n" reason)))
          (insert ":END:\n")))))
  
  (when rts-debug-mode
    (rts--debug-log "Added LOGBOOK entry: %s -> %s%s" old-state new-state 
                    (if reason (format " (Reason: %s)" reason) ""))))

(defun rts--refile-to-in-progress (task-marker)
  "Refile task at TASK-MARKER to 'In Progress' heading in same file."
  (when task-marker
    (let* ((task-buffer (marker-buffer task-marker))
           (in-progress-marker (rts--find-in-progress-heading task-buffer)))

      (if in-progress-marker
          (with-current-buffer task-buffer
            (save-excursion
              ;; Get the full task subtree
              (goto-char task-marker)
              (org-back-to-heading t)
              (let* ((task-start (point))
                     (task-end (save-excursion (org-end-of-subtree t t) (point)))
                     (task-content (buffer-substring task-start task-end)))

                ;; Delete the task from current location
                (delete-region task-start task-end)

                ;; Insert under In Progress heading
                (goto-char in-progress-marker)
                (org-end-of-subtree t t)
                (unless (bolp) (insert "\n"))
                (insert task-content)

                (when rts-debug-mode
                  (rts--debug-log "Refiled task to 'In Progress' heading")))))

        (when rts-debug-mode
          (rts--debug-log "⚠️  WARNING: 'In Progress' heading not found in file"))))))


;;; Unified Base Task Retrieval

(defun rts--get-base-tasks (selector-type &optional extra-tag)
  "Get base tasks based on SELECTOR-TYPE and optional EXTRA-TAG.
SELECTOR-TYPE can be:
- 'tasks' (scheduled/deadline tasks)
- 'books' (book + Booxactive tags)
- 'guitar' (musicactive + guitaractive)
- 'piano' (musicactive + pianoactive)
- 'study' (studyactive)
- 'music' (musicactive - guitar OR piano)
- 'leisure' (musicactive OR studyactive)
EXTRA-TAG can be used to filter further (e.g., 'blog' for blog posts)."
  (let ((query (cond
                ;; Regular scheduled/deadline tasks
                ((eq selector-type 'tasks)
                 '(and (todo)
                       (or (scheduled :to today)
                           (deadline :to 7))))

                ;; Books
                ((eq selector-type 'books)
                 (if extra-tag
                     `(and (todo) (tags "book") (tags "Booxactive") (tags ,extra-tag))
                   '(and (todo) (tags "book") (tags "Booxactive"))))

                ;; Individual instruments
                ((eq selector-type 'guitar)
                 (if extra-tag
                     `(and (todo) (tags "musicactive") (tags "guitaractive") (tags ,extra-tag))
                   '(and (todo) (tags "musicactive") (tags "guitaractive"))))

                ((eq selector-type 'piano)
                 (if extra-tag
                     `(and (todo) (tags "musicactive") (tags "pianoactive") (tags ,extra-tag))
                   '(and (todo) (tags "musicactive") (tags "pianoactive"))))

                ;; Study tasks
                ((eq selector-type 'study)
                 (if extra-tag
                     `(and (todo) (tags "studyactive") (tags ,extra-tag))
                   '(and (todo) (tags "studyactive"))))

                ;; Combined music selector (guitar OR piano)
                ((eq selector-type 'music)
                 (if extra-tag
                     `(and (todo) (tags "musicactive")
                           (or (tags "guitaractive") (tags "pianoactive"))
                           (tags ,extra-tag))
                   '(and (todo) (tags "musicactive")
                         (or (tags "guitaractive") (tags "pianoactive")))))

                ;; Combined leisure selector (music OR study)
                ((eq selector-type 'leisure)
                 (if extra-tag
                     `(and (todo)
                           (or (tags "musicactive") (tags "studyactive"))
                           (tags ,extra-tag))
                   '(and (todo)
                         (or (tags "musicactive") (tags "studyactive")))))

                (t (error "Unknown selector type: %s" selector-type)))))

    (org-ql-select
      (org-agenda-files)
      query
      :action 'element-with-markers
      :sort '(priority))))

;;; Unified Point Calculation

(defun rts--calculate-points (item selector-type)
  "Calculate points for ITEM based on SELECTOR-TYPE."
  (cond
   ((eq selector-type 'tasks)
    (rts--calculate-task-points item))
   ((memq selector-type '(books guitar piano study music leisure))
    (let* ((status (rts--get-task-todo-keyword item))
           (points (cdr (assoc status rts-leisure-status-points))))
      (or points 1)))
   (t 1)))

;;; Unified Selection Functions

(defun rts--select-by-probability (items selector-type)
  "Select an item from ITEMS based on probability weights for SELECTOR-TYPE."
  (if (= (length items) 1)
      (progn
        (when rts-debug-mode
          (let* ((item (car items))
                 (heading (org-element-property :raw-value item))
                 (points (rts--calculate-points item selector-type)))
            (rts--debug-log "Single %s selected: '%s' (Score: %d)"
                            selector-type heading points)))
        (car items))
    (let* ((item-points (mapcar (lambda (item)
                                  (cons item (rts--calculate-points item selector-type)))
                                items))
           (total-points (apply #'+ (mapcar #'cdr item-points)))
           (random-point (random total-points))
           (current-sum 0))

      ;; Debug log all candidates and their scores
      (when rts-debug-mode
        (rts--debug-log "=== %s PROBABILITY SELECTION ===" (upcase (symbol-name selector-type)))
        (rts--debug-log "Candidates: %d items | Total points: %d | Random point: %d"
                        (length items) total-points random-point)
        (dolist (item-point item-points)
          (let* ((item (car item-point))
                 (points (cdr item-point))
                 (heading (org-element-property :raw-value item))
                 (status (rts--get-task-todo-keyword item)))
            (rts--debug-log "  • '%s' [%s] = %d points"
                            heading status points))))

      (catch 'selected
        (dolist (item-point item-points)
          (setq current-sum (+ current-sum (cdr item-point)))
          (when (>= current-sum random-point)
            (when rts-debug-mode
              (let* ((selected-item (car item-point))
                     (heading (org-element-property :raw-value selected-item))
                     (status (rts--get-task-todo-keyword selected-item))
                     (points (cdr item-point)))
                (rts--debug-log "🎯 %s WINNER: '%s' [%s] (Score: %d)"
                                (upcase (symbol-name selector-type)) heading status points)))
            (throw 'selected (car item-point))))
        ;; Fallback
        (when rts-debug-mode
          (rts--debug-log "⚠️  WARNING: %s fallback selection used" selector-type))
        (caar item-points)))))

;;; Unified Display Functions
(defun rts--get-activity-info (tags selector-type)
  "Get activity information (name, emoji, color) based on tags and selector-type."
  (cond
   ((eq selector-type 'tasks) (list "Task" "🎯" "gray"))
   ((eq selector-type 'books) (list "Book" "📚" "blue"))
   ((or (eq selector-type 'guitar) (rts--has-tag-p tags "guitaractive"))
    (list "Guitar" "🎸" "orange"))
   ((or (eq selector-type 'piano) (rts--has-tag-p tags "pianoactive"))
    (list "Piano" "🎹" "purple"))
   ((or (eq selector-type 'study) (rts--has-tag-p tags "studyactive"))
    (list "Study" "📚" "blue"))
   ((eq selector-type 'music) (list "Music" "🎵" "green"))
   ((eq selector-type 'leisure) (list "Leisure" "🎯" "gold"))
   ((eq selector-type 'lazy-low-effort) (list "Lazy Task" "😴" "teal"))
   (t (list "Activity" "📝" "gray"))))

(defun rts--show-unified-posframe (heading priority tags status selector-type)
  "Show selected item in a posframe with appropriate styling."
  (require 'posframe)
  (let* ((buffer (get-buffer-create "*Item Selected*"))
         (parent-frame (selected-frame))
         (activity-info (rts--get-activity-info tags selector-type))
         (activity-name (nth 0 activity-info))
         (emoji (nth 1 activity-info))
         (border-color (nth 2 activity-info))
         (childframe-pixel-width (* 80 (frame-char-width parent-frame)))
         (childframe-pixel-height (* 6 (frame-char-height parent-frame)))
         (center-x (/ (- (frame-pixel-width parent-frame) childframe-pixel-width) 2))
         (center-y (/ (- (frame-pixel-height parent-frame) childframe-pixel-height) 2))
         (center-position (cons center-x center-y)))

    (with-current-buffer buffer
      (erase-buffer)
      (insert (propertize (format "%s %s SELECTED" emoji (upcase activity-name))
                          'face 'font-lock-keyword-face))
      (center-line)
      (insert "\n\n")
      (insert (propertize (format "%s" heading) 'face 'font-lock-function-name-face))
      (center-line)
      (insert "\n")
      (insert (propertize (format "Status: %s | Priority: %s"
                                  (or status "No status")
                                  (or priority "No priority"))
                          'face 'font-lock-variable-name-face))
      (center-line)
      (insert "\n")
      (insert (propertize (format "%s" (if tags (format " :%s:" (string-join tags ":")) ""))
                          'face 'font-lock-comment-face))
      (center-line)
      (setq buffer-read-only t)
      (set (make-local-variable 'face-remapping-alist)
           '((default (:height 200) default))))

    (posframe-show buffer
                   :position center-position
                   :width 80
                   :height 10
                   :border-width 2
                   :border-color border-color
                   :accept-focus nil)

    (run-with-timer 5 nil
                    (lambda (buf)
                      (posframe-delete buf))
                    buffer)))

(defun rts--display-selected-item (item selector-type)
  "Process the selected ITEM: change status, clock in, and announce."
  (if item
      (let* ((heading (org-element-property :raw-value item))
             (priority (rts--get-task-priority item))
             (tags (rts--get-task-tags item))
             (marker (org-element-property :org-marker item))
             (current-todo (rts--get-task-todo-keyword item))
             (new-status (if (eq selector-type 'tasks)
                             (rts--determine-next-status current-todo item)
                           (rts--determine-next-status current-todo item)))
             (should-refile (rts--should-refile-to-in-progress-p current-todo new-status)))

        (when marker
          (with-current-buffer (marker-buffer marker)
            (save-excursion
              (goto-char marker)

              ;; Change status for tasks or leisure items that should change
              (when (and (or (eq selector-type 'tasks)
                             (memq selector-type '(books guitar piano study music leisure)))
                         (not (string= current-todo new-status))
                         (if (eq selector-type 'tasks)
                             (rts--should-change-status-p item)
                           t)) ; Leisure items can always change status

                ;; Change the TODO state
                (org-todo new-status)

                ;; Add LOGBOOK entry for the state change
                (rts--add-state-change-logbook-entry current-todo new-status)

                (when rts-debug-mode
                  (rts--debug-log "Changed status: '%s' -> '%s'" current-todo new-status))

                ;; Refile to In Progress if needed (after status change and logbook entry)
                (when should-refile
                  (rts--refile-to-in-progress marker)
                  (when rts-debug-mode
                    (rts--debug-log "Refiling '%s' to In Progress due to %s -> %s transition"
                                    heading current-todo new-status))))

              ;; Always clock in (note: marker might be invalid after refiling, so we find the task again)
              (if should-refile
                  ;; After refiling, find the task in In Progress and clock in there
                  (let ((in-progress-marker (rts--find-in-progress-heading (current-buffer))))
                    (when in-progress-marker
                      (goto-char in-progress-marker)
                      (when (re-search-forward (regexp-quote heading) nil t)
                        (org-back-to-heading t)
                        (org-clock-in))))
                ;; Normal case - task wasn't moved
                (org-clock-in)))))

        ;; Show item in posframe
        (rts--show-unified-posframe heading priority tags (or new-status current-todo) selector-type))

    (message "No %s found matching criteria." selector-type)))

;;; Main Selection Functions

;; Task selectors (existing functionality)
(defun random-task-select (&optional prefix-arg)
  "Select a random task from filtered list."
  (interactive "P")
  (let* ((base-tasks (rts--get-base-tasks 'tasks))
         (time-filtered-tasks (rts--filter-out-future-today-tasks base-tasks))
         (filtered-tasks
          (if prefix-arg
              (let* ((difficulty (consult--read "Difficulty: " rts-difficulty-tags))
                     (energy (consult--read "Energy: " rts-energy-tags)))
                (rts--filter-by-difficulty-energy time-filtered-tasks difficulty energy))
            time-filtered-tasks)))
    (when filtered-tasks
      (let ((selected-task (nth (random (length filtered-tasks)) filtered-tasks)))
        (when rts-debug-mode
          (rts--debug-log "=== RANDOM TASK SELECTION ===")
          (rts--debug-log "Selected from %d filtered tasks" (length filtered-tasks)))
        (rts--display-selected-item selected-task 'tasks)))))

(defun priority-time-task-select (&optional prefix-arg)
  "Select a task based on priority and time of day logic."
  (interactive "P")
  (let* ((base-tasks (rts--get-base-tasks 'tasks))
         (time-filtered-base (rts--filter-out-future-today-tasks base-tasks))
         (priority-a-tasks (rts--get-priority-tasks time-filtered-base))
         (current-time (rts--get-current-time-of-day)))

    (if priority-a-tasks
        (let* ((sorted-tasks (rts--sort-by-time-priority priority-a-tasks))
               (first-task (car sorted-tasks))
               (first-time-tags (rts--get-task-tags first-task))
               (current-time-group
                (cond
                 ((rts--has-tag-p first-time-tags "Morning") "Morning")
                 ((rts--has-tag-p first-time-tags "Day") "Day")
                 (t "Evening")))
               (same-time-tasks
                (seq-filter
                 (lambda (task)
                   (rts--has-tag-p (rts--get-task-tags task) current-time-group))
                 sorted-tasks)))
          (if same-time-tasks
              (let ((selected-task (nth (random (length same-time-tasks)) same-time-tasks)))
                (when rts-debug-mode
                  (rts--debug-log "=== PRIORITY A SELECTION ===")
                  (rts--debug-log "Selected from %d tasks in %s group" (length same-time-tasks) current-time-group))
                (rts--display-selected-item selected-task 'tasks))
            ;; Fallback to all Priority A tasks if no time-specific matches
            (let ((selected-task (nth (random (length priority-a-tasks)) priority-a-tasks)))
              (when rts-debug-mode
                (rts--debug-log "=== PRIORITY A SELECTION (FALLBACK) ===")
                (rts--debug-log "No time-specific matches, selected from %d total Priority A tasks" (length priority-a-tasks)))
              (rts--display-selected-item selected-task 'tasks))))

      (let* ((lower-tasks (rts--get-lower-priority-tasks time-filtered-base))
             (time-filtered (rts--filter-by-time-of-day lower-tasks current-time))
             (final-tasks (if (null time-filtered) lower-tasks time-filtered))
             (final-filtered
              (if prefix-arg
                  (let* ((difficulty (consult--read "Difficulty: " rts-difficulty-tags))
                         (energy (consult--read "Energy: " rts-energy-tags)))
                    (rts--filter-by-difficulty-energy final-tasks difficulty energy))
                final-tasks)))
        (when final-filtered
          (rts--display-selected-item
           (rts--select-by-probability final-filtered 'tasks) 'tasks))))))

;; Leisure selectors
(defun random-book-select ()
  "Select a random book from Booxactive books based on status probability."
  (interactive)
  (let ((items (rts--get-base-tasks 'books)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'books)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM BOOK SELECTION ===")
            (rts--debug-log "Selected from %d books" (length items)))
          (rts--display-selected-item selected-item 'books))
      (message "No active books found with 'book' and 'Booxactive' tags."))))

(defun random-guitar-select ()
  "Select a random guitar practice task."
  (interactive)
  (let ((items (rts--get-base-tasks 'guitar)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'guitar)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM GUITAR SELECTION ===")
            (rts--debug-log "Selected from %d guitar tasks" (length items)))
          (rts--display-selected-item selected-item 'guitar))
      (message "No active guitar practice tasks found."))))

(defun random-piano-select ()
  "Select a random piano practice task."
  (interactive)
  (let ((items (rts--get-base-tasks 'piano)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'piano)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM PIANO SELECTION ===")
            (rts--debug-log "Selected from %d piano tasks" (length items)))
          (rts--display-selected-item selected-item 'piano))
      (message "No active piano practice tasks found."))))

(defun random-study-select ()
  "Select a random study task."
  (interactive)
  (let ((items (rts--get-base-tasks 'study)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'study)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM STUDY SELECTION ===")
            (rts--debug-log "Selected from %d study tasks" (length items)))
          (rts--display-selected-item selected-item 'study))
      (message "No active study tasks found."))))

(defun random-blog-study-select ()
  "Select a random blog study task."
  (interactive)
  (let ((items (rts--get-base-tasks 'study "blog")))
    (if items
        (let ((selected-item (rts--select-by-probability items 'study)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM BLOG STUDY SELECTION ===")
            (rts--debug-log "Selected from %d blog study tasks" (length items)))
          (rts--display-selected-item selected-item 'study))
      (message "No active blog study tasks found."))))

(defun random-music-select ()
  "Select a random music practice task (guitar or piano)."
  (interactive)
  (let ((items (rts--get-base-tasks 'music)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'music)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM MUSIC SELECTION ===")
            (rts--debug-log "Selected from %d music tasks" (length items)))
          (rts--display-selected-item selected-item 'music))
      (message "No active music practice tasks found."))))

(defun random-leisure-select ()
  "Select a random leisure task (music or study)."
  (interactive)
  (let ((items (rts--get-base-tasks 'leisure)))
    (if items
        (let ((selected-item (rts--select-by-probability items 'leisure)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM LEISURE SELECTION ===")
            (rts--debug-log "Selected from %d leisure tasks" (length items)))
          (rts--display-selected-item selected-item 'leisure))
      (message "No active leisure tasks found."))))

;;; Additional Configuration for Lazy Low-Effort Selection
(defvar rts-effort-points
  '((:under-15 . 10) (:15-to-30 . 5) (:over-30 . 2))
  "Points assigned to effort time ranges for probability calculation.")

(defun rts--parse-effort-time (task)
  "Parse the EFFORT property of TASK into minutes."
  (let ((effort (org-element-property :EFFORT task)))
    (when effort
      (org-duration-to-minutes effort))))

(defun rts--get-effort-category (minutes)
  "Categorize MINUTES into effort time ranges."
  (cond
   ((and minutes (< minutes 15)) :under-15)
   ((and minutes (<= minutes 30)) :15-to-30)
   (t :over-30)))

(defun rts--calculate-lazy-effort-points (task)
  "Calculate points for TASK based on its effort time."
  (let* ((minutes (rts--parse-effort-time task))
         (category (rts--get-effort-category minutes))
         (points (cdr (assoc category rts-effort-points))))
    (or points 2))) ; Default to 2 points if no effort or invalid

;;; Lazy Low-Effort Task Selection
(defun random-lazy-low-effort-select ()
  "Select a random lazy task with probability weighted by effort time."
  (interactive)
  (let* ((items (org-ql-select
                  (org-agenda-files)
                  '(and (todo) (tags "Lazy"))
                  :action 'element-with-markers
                  :sort '(priority))))
    (if items
        (let ((selected-item (rts--select-by-probability items 'lazy-low-effort)))
          (when rts-debug-mode
            (rts--debug-log "=== RANDOM LAZY LOW-EFFORT SELECTION ===")
            (rts--debug-log "Selected from %d lazy tasks" (length items))
            (dolist (item items)
              (let* ((heading (org-element-property :raw-value item))
                     (effort (org-element-property :EFFORT item))
                     (points (rts--calculate-lazy-effort-points item)))
                (rts--debug-log "  • '%s' [Effort: %s] = %d points"
                                heading (or effort "None") points))))
          (rts--display-selected-item selected-item 'lazy-low-effort))
      (message "No active lazy tasks found with 'Lazy' tag."))))


;;; ===================================================================
;;; GTD System Enforcement & Cleanup
;;; ===================================================================

;;; Configuration Variables
(defvar rts-gtd-priority-limits
  '(("B" . 2) ("C" . 4) ("D" . 8) ("E" . 8))
  "Priority limits for GTD cleanup enforcement.")

(defvar rts-gtd-timeout-rules
  '(("NEXT" . 2) ("A" . 2) ("B" . 2) ("C" . 4) ("D" . 7))
  "Days before status/priority times out.")

(defvar rts-gtd-max-next-tasks 5
  "Maximum number of NEXT tasks allowed.")

(defvar org-tasks-file nil
  "Path to main tasks org file.")

(defvar org-projects-file nil
  "Path to projects org file.")

(defvar org-recurring-file nil
  "Path to recurring/habits org file.")

;;; GTD Helper Functions

(defun rts--gtd-get-activated-date (task)
  "Parse :ACTIVATED: property from TASK element."
  (let ((activated (org-element-property :ACTIVATED task)))
    (when activated
      (org-time-string-to-time activated))))

(defun rts--gtd-days-since-activation (task)
  "Calculate days since TASK was activated."
  (let ((activated-time (rts--gtd-get-activated-date task)))
    (when activated-time
      (/ (float-time (time-subtract (current-time) activated-time)) 86400))))

(defun rts--gtd-is-habit-extended (task)
  "Extended habit check: style property OR in recurring file."
  (or (rts--is-habit-p task)
      (let ((marker (org-element-property :org-marker task)))
        (when marker
          (string= (buffer-file-name (marker-buffer marker)) org-recurring-file)))))

(defun rts--gtd-has-clock-time (task)
  "Check if TASK has any clocked time in history."
  (let ((marker (org-element-property :org-marker task)))
    (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          (let ((clock-sum (org-clock-sum-current-item)))
            (> clock-sum 0)))))))

(defun rts--gtd-get-priority-change-date (task priority)
  "Get date when TASK was changed to PRIORITY from LOGBOOK."
  (let ((marker (org-element-property :org-marker task)))
    (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          (when (re-search-forward ":LOGBOOK:" (org-end-of-subtree t t) t)
            (let ((logbook-end (save-excursion
                                 (re-search-forward ":END:" nil t))))
              (when logbook-end
                (while (re-search-forward (format "State \".*\" from \".*\" \\[\\([^]]+\\)\\]") logbook-end t)
                  (let ((timestamp-str (match-string 1)))
                    (when timestamp-str
                      (condition-case nil
                          (org-time-string-to-time timestamp-str)
                        (error nil)))))))))))))

(defun rts--gtd-days-since-priority-change (task priority)
  "Calculate days since TASK priority was set to PRIORITY."
  (let ((change-time (rts--gtd-get-priority-change-date task priority)))
    (when change-time
      (/ (float-time (time-subtract (current-time) change-time)) 86400))))

;;; Task Collection

(defun rts--gtd-get-all-tasks ()
  "Get all active TODO tasks from tasks and projects files, excluding habits and dormant tasks."
  (let ((files (delq nil (list org-tasks-file org-projects-file))))
    (when files
      (seq-filter
       (lambda (task) 
         (and (not (rts--gtd-is-habit-extended task))
              (rts--gtd-is-active-task task)))
       (org-ql-select
         files
         '(todo)
         :action 'element-with-markers
         :sort '(priority))))))

(defun rts--gtd-is-active-task (task)
  "Check if TASK is active (scheduled, deadline, or NEXT status)."
  (let ((todo-keyword (rts--get-task-todo-keyword task))
        (scheduled (org-element-property :scheduled task))
        (deadline (org-element-property :deadline task)))
    (or (string= todo-keyword "NEXT")
        scheduled
        deadline)))

;;; Violation Analysis

(defun rts--gtd-analyze-violations (tasks)
  "Analyze TASKS for GTD rule violations. Returns violation data structure."
  (let ((priority-counts (make-hash-table :test 'equal))
        (next-violations nil)
        (priority-violations nil)
        (next-tasks nil))
    
    ;; Count priorities and collect violations
    (dolist (task tasks)
      (let* ((priority (rts--get-task-priority task))
             (todo-keyword (rts--get-task-todo-keyword task))
             (days-next (when (string= todo-keyword "NEXT")
                          (rts--gtd-days-since-activation task)))
             (days-priority (when priority
                              (rts--gtd-days-since-priority-change task priority))))
        
        ;; Count priorities
        (when priority
          (puthash priority (1+ (gethash priority priority-counts 0)) priority-counts))
        
        ;; Collect NEXT tasks
        (when (string= todo-keyword "NEXT")
          (push task next-tasks))
        
        ;; Check NEXT timeout violations
        (when (and days-next (> days-next 2))
          (push (list :task task :type "NEXT-timeout" :days days-next) next-violations))
        
        ;; Check priority timeout violations
        (when (and priority days-priority)
          (let ((timeout-days (cdr (assoc priority rts-gtd-timeout-rules))))
            (when (and timeout-days (> days-priority timeout-days))
              (push (list :task task :type "priority-timeout" :priority priority :days days-priority) 
                    priority-violations))))))
    
    ;; Check priority count violations
    (let ((priority-excess nil))
      (maphash (lambda (priority count)
                 (let ((limit (cdr (assoc priority rts-gtd-priority-limits))))
                   (when (and limit (> count limit))
                     (push (list :priority priority :current count :limit limit :excess (- count limit))
                           priority-excess))))
               priority-counts)
      
      ;; Check NEXT count violation
      (let ((next-excess (when (> (length next-tasks) rts-gtd-max-next-tasks)
                           (- (length next-tasks) rts-gtd-max-next-tasks))))
        
        (list :priority-counts priority-counts
              :priority-excess priority-excess
              :next-violations next-violations
              :priority-violations priority-violations
              :next-tasks next-tasks
              :next-excess next-excess)))))

;;; Smart Demotion Logic

(defun rts--gtd-find-demotion-targets (tasks reason)
  "Find best demotion targets from TASKS based on REASON using smart criteria."
  (let ((task-scores nil))
    (dolist (task tasks)
      (let* ((marker (org-element-property :org-marker task))
             (file-path (when marker (buffer-file-name (marker-buffer marker))))
             (is-tasks-file (and file-path (string= file-path org-tasks-file)))
             (has-clock (rts--gtd-has-clock-time task))
             (activation-days (or (rts--gtd-days-since-activation task) 0))
             (score 0))
        
        ;; Scoring criteria (higher score = better demotion target)
        (when is-tasks-file (setq score (+ score 100)))  ; Prefer tasks file
        (unless has-clock (setq score (+ score 50)))     ; Prefer no clock time
        (setq score (+ score activation-days))           ; Prefer more recently activated
        
        (push (cons task score) task-scores)))
    
    ;; Sort by score descending and return tasks
    (mapcar #'car (sort task-scores (lambda (a b) (> (cdr a) (cdr b)))))))

(defun rts--gtd-find-available-priority (current-priority violations)
  "Find next available lower priority slot given current VIOLATIONS."
  (let ((priority-counts (plist-get violations :priority-counts))
        (priority-order '("D" "E" "F")))
    (catch 'found
      (dolist (priority priority-order)
        (let ((count (gethash priority priority-counts 0))
              (limit (cdr (assoc priority rts-gtd-priority-limits))))
          (when (or (not limit) (< count limit))
            (throw 'found priority))))
      "F")))  ; Fallback to F if all else fails

;;; Demotion Execution

(defun rts--gtd-demote-task (task new-priority reason)
  "Demote TASK to NEW-PRIORITY with REASON logged."
  (let* ((marker (org-element-property :org-marker task))
         (heading (org-element-property :raw-value task))
         (old-priority (rts--get-task-priority task)))
    
    (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          
          ;; Change priority
          (org-priority (string-to-char new-priority))
          
          ;; Add LOGBOOK entry with reason
          (rts--add-state-change-logbook-entry 
           (format "Priority %s" (or old-priority "None"))
           (format "Priority %s" new-priority)
           reason)
          
          (rts--debug-log "GTD CLEANUP: Demoted '%s' from %s to %s (%s)" 
                          heading (or old-priority "None") new-priority reason))))))

(defun rts--gtd-demote-next-to-todo (task reason)
  "Demote TASK from NEXT to TODO with REASON logged."
  (let* ((marker (org-element-property :org-marker task))
         (heading (org-element-property :raw-value task)))
    
    (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          
          ;; Change status
          (org-todo "TODO")
          
          ;; Add LOGBOOK entry with reason
          (rts--add-state-change-logbook-entry "NEXT" "TODO" reason)
          
          (rts--debug-log "GTD CLEANUP: Demoted '%s' from NEXT to TODO (%s)" 
                          heading reason))))))

;;; Main Cleanup Functions

(defun rts--gtd-apply-demotions (violations)
  "Apply demotions based on VIOLATIONS analysis."
  (let ((changes-made 0))
    
    ;; Handle priority count violations
    (dolist (excess (plist-get violations :priority-excess))
      (let* ((priority (plist-get excess :priority))
             (excess-count (plist-get excess :excess))
             (all-tasks (rts--gtd-get-all-tasks))
             (priority-tasks (seq-filter 
                              (lambda (task) 
                                (string= (rts--get-task-priority task) priority))
                              all-tasks))
             (targets (rts--gtd-find-demotion-targets 
                       priority-tasks 
                       (format "Priority %s limit exceeded" priority))))
        
        (dotimes (i excess-count)
          (when (nth i targets)
            (let ((new-priority (rts--gtd-find-available-priority priority violations)))
              (rts--gtd-demote-task (nth i targets) new-priority 
                                    (format "Priority %s limit exceeded" 
                                            priority (+ i 1) excess-count))
              (setq changes-made (1+ changes-made)))))))
    
    ;; Handle NEXT timeout violations
    (dolist (violation (plist-get violations :next-violations))
      (let ((task (plist-get violation :task))
            (days (plist-get violation :days)))
        (rts--gtd-demote-next-to-todo task 
                                      (format "NEXT timeout: %d days" (round days)))
        (setq changes-made (1+ changes-made))))
    
    ;; Handle priority timeout violations
    (dolist (violation (plist-get violations :priority-violations))
      (let* ((task (plist-get violation :task))
             (priority (plist-get violation :priority))
             (days (plist-get violation :days))
             (new-priority (rts--gtd-find-available-priority priority violations)))
        (rts--gtd-demote-task task new-priority 
                              (format "Priority %s timeout: %d days" priority (round days)))
        (setq changes-made (1+ changes-made))))
    
    changes-made))

;;; Main Cleanup Function

(defun cleanup-gtd-system ()
  "Analyze and cleanup GTD system violations automatically."
  (interactive)
  (rts--debug-log "=== GTD SYSTEM CLEANUP STARTED ===")
  
  (let* ((tasks (rts--gtd-get-all-tasks))
         (violations (rts--gtd-analyze-violations tasks))
         (changes-made (rts--gtd-apply-demotions violations)))
    
    ;; Generate summary report
    (rts--debug-log "=== GTD CLEANUP SUMMARY ===")
    (rts--debug-log "Total tasks analyzed: %d" (length tasks))
    (rts--debug-log "Priority violations: %d" (length (plist-get violations :priority-excess)))
    (rts--debug-log "NEXT timeout violations: %d" (length (plist-get violations :next-violations)))
    (rts--debug-log "Priority timeout violations: %d" (length (plist-get violations :priority-violations)))
    (rts--debug-log "Total changes made: %d" changes-made)
    (rts--debug-log "=== GTD CLEANUP COMPLETED ===")
    
    ;; User message
    (message "GTD Cleanup: %d changes made. See *RTS Debug* buffer for details." changes-made)))

;;; ===================================================================
;;; Instant Task Creation System - Zero Friction Task Entry
;;; ===================================================================

(defvar rts-instant-task-last-category nil
  "Remember the last category used for instant tasks.")

(defvar rts-instant-task-categories
  '("Hobby" "ToImprove" "ToTheMoon" "EHP" "Entertainment" "Normal")
  "Available categories for instant tasks.")

(defvar rts-instant-task-common-tags 
  '("Active" "work" "personal" "code" "meeting" "review" "plan" 
    "Challenge" "Average" "Easy"
    "Morning" "Day" "Evening"
    "Energetic" "ModeratelyLazy" "Lazy")
  "Common tags to suggest for instant tasks.")

(defun rts--parse-tags-input (input)
  "Parse space-separated INPUT string into a list of tags."
  (when (and input (not (string-empty-p input)))
    (split-string input " " t)))

(defun rts--suggest-time-of-day-tag ()
  "Suggest time of day tag based on current time."
  (let ((hour (string-to-number (format-time-string "%H"))))
    (cond
     ((<= hour 11) "Morning")
     ((<= hour 17) "Day")
     (t "Evening"))))

(defun rts--create-instant-task (title priority effort category tags)
  "Create a new task in org-tasks-file with given parameters.
Returns the marker for the newly created task."
  (with-current-buffer (find-file-noselect org-tasks-file)
    (save-excursion
      ;; Go to end of file to append
      (goto-char (point-max))
      
      ;; Make sure we're on a new line
      (unless (bolp) (insert "\n"))
      
      ;; Insert the new task
      (insert (format "* TODO [#%s] %s" priority title))
      
      ;; Add tags if provided
      (when tags
        (insert " :" (mapconcat 'identity tags ":") ":"))
      
      (insert "\n")
      
      ;; Add SCHEDULED for today
      (insert "SCHEDULED: " (format-time-string "<%Y-%m-%d %a>") "\n")
      
      ;; Add properties drawer
      (insert ":PROPERTIES:\n")
      (insert ":CREATED:  " (format-time-string "[%Y-%m-%d %a]") "\n")
      (when effort
        (insert ":EFFORT:   " effort "\n"))
      (when category
        (insert ":CATEGORY: " category "\n"))
      (insert ":ACTIVATED: " (format-time-string "[%Y-%m-%d]") "\n")
      (insert ":END:\n\n")
      
      ;; Return marker at the task heading
      (forward-line -2)
      (org-back-to-heading t)
      (copy-marker (point)))))

(defun consult-activate-instant-task ()
  "Create and immediately activate a new task in org-tasks-file.
Prompts for title, priority, effort, category, and tags.
Schedules for today, sets to NEXT, and clocks in immediately."
  (interactive)
  (let* ((title (read-string "Task: "))
         (priority (consult--read '("A" "B" "C" "D" "E" "F")
                                  :prompt "Priority: "
                                  :default "C"))
         (effort (read-string "Effort (e.g., 2:00): " "1:00"))
         (category (consult--read rts-instant-task-categories
                                  :prompt "Category: "
                                  :default (or rts-instant-task-last-category 
                                               (car rts-instant-task-categories))))
         (time-tag (rts--suggest-time-of-day-tag))
         (tags-input (completing-read-multiple 
                      "Tags (comma-separated, TAB to complete): "
                      rts-instant-task-common-tags))
         (all-tags (append tags-input (list time-tag "Active"))))
    
    ;; Remember category for next time
    (setq rts-instant-task-last-category category)
    
    ;; Create the task
    (let ((task-marker (rts--create-instant-task title priority effort category all-tags)))
      
      (when task-marker
        ;; Change to NEXT status
        (with-current-buffer (marker-buffer task-marker)
          (save-excursion
            (goto-char task-marker)
            (org-todo "NEXT")
            
            ;; Add state change to LOGBOOK
            (rts--add-state-change-logbook-entry "TODO" "NEXT" "Instant task creation")
            
            ;; Clock in
            (org-clock-in)
            
            (rts--debug-log "Created instant task: %s [#%s]" title priority)))
        
        ;; Show success posframe
        (rts--show-unified-posframe
         title
         priority
         all-tags
         "NEXT"
         'tasks)
        
        (message "Task created and clocked in: %s" title)))))

;;; ===================================================================
;;; Project Task Activation System - Ultra Focus Mode
;;; ===================================================================

(defvar rts-project-task-siblings-limit 5
  "Number of sibling tasks to show after each NEXT task in projects.")

(defvar rts-project-files (list org-projects-file)
  "List of org files containing projects.")

(defun rts--get-parent-project-name (marker)
  "Get the parent project heading name for MARKER if applicable."
  (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (when (org-up-heading-safe)
          (org-get-heading t t t t))))))

(defun rts--get-project-next-with-siblings ()
  "Get all NEXT tasks from projects with their following siblings.
Returns a list of candidates with project context."
  (let ((candidates nil))
    (dolist (file rts-project-files)
      (when (and file (file-exists-p file))
        (with-current-buffer (find-file-noselect file)
          (org-element-map (org-element-parse-buffer) 'headline
            (lambda (element)
              ;; Check if this is a NEXT task
              (when (string= (org-element-property :todo-keyword element) "NEXT")
                (let* ((marker (copy-marker (org-element-property :begin element)))
                       (project-name (rts--get-parent-project-name marker))
                       (level (org-element-property :level element)))
                  
                  ;; Add the NEXT task itself
                  (push (list :element (org-element-put-property element :org-marker marker)
                              :project project-name
                              :is-next t
                              :type "NEXT"
                              :level level)
                        candidates)
                  
                  ;; Collect following siblings
                  (save-excursion
                    (goto-char marker)
                    (let ((sibling-count 0))
                      (while (and (< sibling-count rts-project-task-siblings-limit)
                                  (org-forward-heading-same-level 1 t))
                        (let* ((sibling-el (org-element-at-point))
                               (sibling-todo (org-element-property :todo-keyword sibling-el))
                               (sibling-marker (copy-marker (point))))
                          (when (and sibling-todo
                                     (not (member sibling-todo '("DONE" "CANCELLED"))))
                            (push (list :element (org-element-put-property sibling-el :org-marker sibling-marker)
                                        :project project-name
                                        :is-next nil
                                        :type sibling-todo
                                        :level level)
                                  candidates)
                            (setq sibling-count (1+ sibling-count))))))))))))))
    (nreverse candidates)))

(defun rts--remove-task-constraints (marker)
  "Remove TRIGGER and BLOCKER properties from task at MARKER."
  (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (org-back-to-heading t)
        ;; Remove TRIGGER property
        (org-delete-property "TRIGGER")
        ;; Remove BLOCKER property  
        (org-delete-property "BLOCKER")
        (rts--debug-log "Removed TRIGGER and BLOCKER constraints from task")))))

(defun rts--ensure-only-last-has-blocker (project-marker)
  "Ensure only the last TODO task in project has BLOCKER property."
  (when (and project-marker (markerp project-marker))
    (with-current-buffer (marker-buffer project-marker)
      (save-excursion
        (goto-char project-marker)
        (org-back-to-heading t)
        (let ((project-level (org-outline-level))
              (last-todo-marker nil))
          
          ;; Find all TODO tasks in this project
          (org-map-entries
           (lambda ()
             (let ((todo (org-get-todo-state)))
               (when (and todo (not (member todo '("DONE" "CANCELLED"))))
                 ;; Remove BLOCKER from all tasks first
                 (org-delete-property "BLOCKER")
                 (setq last-todo-marker (point-marker)))))
           (format "LEVEL=%d" (1+ project-level))
           'tree)
          
          ;; Add BLOCKER only to the last TODO
          (when last-todo-marker
            (goto-char last-todo-marker)
            (org-set-property "BLOCKER" "previous-sibling")
            (rts--debug-log "Set BLOCKER on last TODO task in project")))))))

(defun rts--get-all-projects ()
  "Get list of all active projects from project files."
  (let ((projects nil))
    (dolist (file rts-project-files)
      (when (and file (file-exists-p file))
        (with-current-buffer (find-file-noselect file)
          (org-element-map (org-element-parse-buffer) 'headline
            (lambda (element)
              (when (member "proj" (org-element-property :tags element))
                (let* ((title (org-element-property :raw-value element))
                       (marker (copy-marker (org-element-property :begin element))))
                  (push (cons title marker) projects))))))))
    (nreverse projects)))

(defun rts--clone-task-structure (template-marker new-title priority)
  "Clone task structure from TEMPLATE-MARKER with NEW-TITLE and PRIORITY.
Returns the marker for the newly created task."
  (when (and template-marker (markerp template-marker))
    (with-current-buffer (marker-buffer template-marker)
      (save-excursion
        (goto-char template-marker)
        (org-back-to-heading t)
        (let* ((template-level (org-outline-level))
               (template-tags (org-get-tags))
               (template-effort (org-entry-get nil "Effort"))
               (is-next-task (string= (org-get-todo-state) "NEXT"))
               (new-heading (format "%s %s"
                                    (if priority (format "[#%s]" priority) "")
                                    new-title)))
          
          ;; If template is NEXT, insert BEFORE it to avoid trigger chain
          ;; Otherwise insert after current task
          (if is-next-task
              (progn
                ;; Insert before current NEXT task - go to beginning of line first
                (beginning-of-line)
                (insert (make-string template-level ?*) " TODO " new-heading "\n")
                ;; Now we're on the old NEXT task line, go back to our new task
                (forward-line -1)
                (beginning-of-line))
            ;; Insert after current task (original behavior)
            (org-end-of-subtree t t)
            (unless (bolp) (insert "\n"))
            (insert (make-string template-level ?*) " TODO " new-heading "\n")
            (forward-line -1))

          (org-back-to-heading t)

          ;; Create marker NOW at the heading, before properties shift things
          (let ((new-task-marker (copy-marker (point))))

            ;; Set properties from template
            (when template-effort
              (org-set-property "Effort" template-effort))

            ;; Set CREATED date
            (org-set-property "CREATED" (format-time-string "[%Y-%m-%d]"))

            ;; Set ACTIVATED date
            (org-set-property "ACTIVATED" (format-time-string "[%Y-%m-%d]"))

            ;; Copy tags if any
            (when template-tags
              (org-set-tags template-tags))

            ;; Return the marker we created at the heading
            new-task-marker))))))

(defun rts--format-project-task-candidate (cand)
  "Format a project task candidate for consult display."
  (let* ((el (plist-get cand :element))
         (project (or (plist-get cand :project) "Standalone"))
         (heading (org-element-property :raw-value el))
         (priority (rts--get-task-priority el))
         (priority-str (if priority (format "#%s" priority) ""))
         (status (plist-get cand :type))
         (is-next (plist-get cand :is-next))
         (indent (if is-next "▸ " "  "))
         (face (if is-next 'font-lock-keyword-face 'default))
         (display (format "%-25s %s%-5s %-8s %s"
                          (propertize project 'face 'font-lock-comment-face)
                          indent
                          (propertize priority-str 'face 'font-lock-keyword-face)
                          (propertize status 'face 'font-lock-type-face)
                          (propertize heading 'face face))))
    (cons display cand)))

(defun rts--activate-project-task (marker &optional new-title)
  "Activate task at MARKER by removing constraints, scheduling, and clocking in.
If NEW-TITLE is provided, update the task title."
  (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (org-back-to-heading t)
        
        ;; Update title if provided
        (when new-title
          (let ((current-line (thing-at-point 'line t)))
            (when (string-match "^\\(\\*+ [A-Z]+ \\(?:\\[#.\\] \\)?\\).*$" current-line)
              (let ((prefix (match-string 1 current-line)))
                (beginning-of-line)
                (delete-region (point) (line-end-position))
                (insert prefix new-title)))))
        
        ;; Remove constraints
        (rts--remove-task-constraints marker)
        
        ;; Set to NEXT status
        (org-todo "NEXT")
        
        ;; Schedule for today with tomorrow deadline
        (org-schedule nil (format-time-string "<%Y-%m-%d %a>"))
        (org-deadline nil (format-time-string "<%Y-%m-%d %a>" 
                                              (time-add (current-time) (* 24 3600))))
        
        ;; Add ACTIVATED property
        (org-set-property "ACTIVATED" (format-time-string "[%Y-%m-%d]"))
        
        ;; Add state change to LOGBOOK
        (rts--add-state-change-logbook-entry "TODO" "NEXT" "Activated via project task selector")

        ;; Ensure we're at the heading before clocking in
        (goto-char marker)
        (org-back-to-heading t)

        ;; Debug: show what we're about to clock into
        (rts--debug-log "About to clock into: %s" (org-get-heading t t t t))

        ;; Clock in
        (org-clock-in)

        (rts--debug-log "Activated project task: %s"
                        (or new-title (org-get-heading t t t t)))))))

(defun consult-activate-project-task ()
  "Select or create a project task, activate it, and start clocking.
Shows NEXT tasks and their siblings from all projects.
If input doesn't match, creates new task in selected project."
  (interactive)
  (let* ((candidates (rts--get-project-next-with-siblings))
         (formatted (mapcar #'rts--format-project-task-candidate candidates))
         (selected-or-input
          (consult--read formatted
                         :prompt "Project task (or enter new): "
                         :sort nil
                         :require-match nil  ; Allow free input
                         :category 'project-task
                         :preview-key "C-."
                         :state (lambda (action selected)
                                  (when (and (eq action 'preview) selected)
                                    (let* ((cand (cdr (assoc selected formatted)))
                                           (marker (when cand 
                                                     (org-element-property :org-marker 
                                                                           (plist-get cand :element)))))
                                      (when (and marker (markerp marker) 
                                                 (buffer-live-p (marker-buffer marker)))
                                        (switch-to-buffer (marker-buffer marker) nil t)
                                        (goto-char marker)
                                        (org-show-entry)
                                        (recenter 0 t))))))))
    
    (cond
     ;; Existing task selected
     ((assoc selected-or-input formatted)
      (let* ((selected-cand (cdr (assoc selected-or-input formatted)))
             (el (plist-get selected-cand :element))
             (is-next (plist-get selected-cand :is-next))
             (marker (org-element-property :org-marker el))
             (project-marker (when marker
                               (with-current-buffer (marker-buffer marker)
                                 (save-excursion
                                   (goto-char marker)
                                   (org-up-heading-safe)
                                   (copy-marker (point)))))))
        
        (when marker
          ;; If it's a TODO task (not NEXT), move it before the first NEXT task
          (unless is-next
            (with-current-buffer (marker-buffer marker)
              (save-excursion
                ;; Find the first NEXT task in this project
                (goto-char project-marker)
                (let ((next-marker nil))
                  (org-map-entries
                   (lambda ()
                     (unless next-marker
                       (when (string= (org-get-todo-state) "NEXT")
                         (setq next-marker (copy-marker (point))))))
                   nil
                   'tree)
                  
                  ;; If we found a NEXT task, move our TODO before it
                  (when next-marker
                    ;; Get the task content
                    (goto-char marker)
                    (org-back-to-heading t)
                    (let* ((task-start (point))
                           (task-end (save-excursion (org-end-of-subtree t t) (point)))
                           (task-content (buffer-substring task-start task-end)))
                      
                      ;; Delete from current position
                      (delete-region task-start task-end)
                      
                      ;; Insert before NEXT task
                      (goto-char next-marker)
                      (org-back-to-heading t)
                      (insert task-content)
                      (unless (bolp) (insert "\n"))
                      
                      ;; Update marker to new position
                      (forward-line -1)
                      (org-back-to-heading t)
                      (move-marker marker (point))
                      
                      (rts--debug-log "Moved TODO task before NEXT task")))))))
          
          ;; Activate the selected task
          (rts--activate-project-task marker)
          
          ;; Ensure only last task has blocker
          (when project-marker
            (rts--ensure-only-last-has-blocker project-marker))
          
          ;; Show success posframe
          (rts--show-unified-posframe 
           (org-element-property :raw-value el)
           (rts--get-task-priority el)
           (rts--get-task-tags el)
           "NEXT"
           'tasks)
          
          (rts--debug-log "Activated existing project task"))))
     
     ;; New task input
     (selected-or-input
      (let* ((new-task-title selected-or-input)
             (projects (rts--get-all-projects))
             (project-names (mapcar #'car projects))
             (selected-project-name 
              (consult--read project-names
                             :prompt "Add to project: "
                             :require-match t
                             :sort nil))
             (project-marker (cdr (assoc selected-project-name projects)))
             (priority (consult--read '("A" "B" "C" "D" "E" "F")
                                      :prompt "Priority: "
                                      :default "C")))
        
        (when project-marker
          ;; Find a NEXT task in this project to use as template
          (with-current-buffer (marker-buffer project-marker)
            (save-excursion
              (goto-char project-marker)
              (let ((template-marker nil))
                ;; Find first NEXT or TODO task to clone
                (org-map-entries
                 (lambda ()
                   (unless template-marker
                     (when (member (org-get-todo-state) '("NEXT" "TODO"))
                       (setq template-marker (copy-marker (point))))))
                 nil
                 'tree)
                
                (if template-marker
                    (let ((new-marker (rts--clone-task-structure 
                                       template-marker 
                                       new-task-title 
                                       priority)))
                      
                      ;; Activate the new task
                      (rts--activate-project-task new-marker)
                      
                      ;; Ensure only last task has blocker
                      (rts--ensure-only-last-has-blocker project-marker)
                      
                      ;; Show success posframe
                      (rts--show-unified-posframe
                       new-task-title
                       priority
                       nil
                       "NEXT"
                       'tasks)
                      
                      (rts--debug-log "Created and activated new project task: %s" 
                                      new-task-title))
                  (message "No template task found in project %s" selected-project-name)))))))))))
;;; ===================================================================
;;; Quick Clock-in for Mundane/Leisure Tasks
;;; ===================================================================

(defun rts--get-mundane-task-candidates ()
  "Get formatted candidates for mundane/leisure task selection.
Returns sorted list of (display . marker) pairs."
  (let* ((tasks (org-ql-select
                  (org-agenda-files)
                  '(and (not (done))
                        (or (todo "TOREAD" "READING" "REREADING" "SUMMARIZING")
                            (todo "TOSTUDY" "STUDYING" "REVISING") 
                            (todo "TOPRACTICE" "PRACTICING" "REPRACTICING")
                            (todo "TOWATCH" "WATCHING" "REWATCH")
                            (todo "TONOTDO")))
                  :action 'element-with-markers
                  :sort '(todo priority)))
         (candidates (mapcar
                      (lambda (task)
                        (let* ((heading (org-element-property :raw-value task))
                               (status (org-element-property :todo-keyword task))
                               (priority (rts--get-task-priority task))
                               (tags (rts--get-task-tags task))
                               (marker (org-element-property :org-marker task))
                               ;; Status weighting for sorting - active tasks get higher weight
                               (weight (cond
                                        ((member status '("READING" "STUDYING" "PRACTICING" "WATCHING")) 100)
                                        ((member status '("SUMMARIZING")) 90)
                                        ((member status '("REREADING" "REVISING" "REPRACTICING" "REWATCH")) 50)
                                        (t 10)))
                               ;; Format display with status, priority, and heading
                               (display (format "%-12s | %s | %s"
                                                (propertize status 'face 
                                                            (if (> weight 50) 
                                                                'font-lock-keyword-face
                                                              'font-lock-comment-face))
                                                (if priority 
                                                    (propertize (format "[#%s]" priority) 
                                                                'face 'font-lock-type-face)
                                                  "    ")
                                                heading)))
                          (cons display marker)))
                      tasks)))
    ;; Sort candidates by weight (active tasks first)
    (sort candidates 
          (lambda (a b)
            (let* ((status-a (car (split-string (car a) " ")))
                   (status-b (car (split-string (car b) " ")))
                   (weight-a (cond
                              ((member status-a '("READING" "STUDYING" "PRACTICING" "WATCHING")) 100)
                              ((member status-a '("SUMMARIZING")) 90)
                              ((member status-a '("REREADING" "REVISING" "REPRACTICING" "REWATCH")) 50)
                              (t 10)))
                   (weight-b (cond
                              ((member status-b '("READING" "STUDYING" "PRACTICING" "WATCHING")) 100)
                              ((member status-b '("SUMMARIZING")) 90)
                              ((member status-b '("REREADING" "REVISING" "REPRACTICING" "REWATCH")) 50)
                              (t 10))))
              (> weight-a weight-b))))))

(defun rts--add-clock-entry-to-task (marker start-time-obj end-time-obj duration-minutes)
  "Add clock entry to task at MARKER with given time objects and duration."
  (with-current-buffer (marker-buffer marker)
    (save-excursion
      (goto-char marker)
      (org-back-to-heading t)
      (let* ((start-str (format-time-string "[%Y-%m-%d %a %H:%M]" start-time-obj))
             (end-str (format-time-string "[%Y-%m-%d %a %H:%M]" end-time-obj))
             (hours (/ duration-minutes 60))
             (mins (% duration-minutes 60))
             (clock-entry (format "CLOCK: %s--%s =>  %2d:%02d" start-str end-str hours mins)))
        
        (let* ((heading-start (point))
               (heading-end (save-excursion 
                              (org-end-of-subtree t t)
                              (point)))
               ;; Search for existing LOGBOOK drawer
               (logbook-region (save-excursion
                                 (goto-char heading-start)
                                 (forward-line 1)
                                 (when (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" heading-end t)
                                   (let ((lb-start (line-beginning-position)))
                                     (when (re-search-forward "^[ \t]*:END:[ \t]*$" heading-end t)
                                       (cons lb-start (line-beginning-position))))))))
          
          (if logbook-region
              ;; LOGBOOK exists, add entry after :LOGBOOK: line
              (progn
                (goto-char (car logbook-region))
                (forward-line 1)
                (insert clock-entry "\n"))
            ;; No LOGBOOK, create one after metadata
            (progn
              (goto-char heading-start)
              (org-end-of-meta-data)
              (insert ":LOGBOOK:\n")
              (insert clock-entry "\n")
              (insert ":END:\n"))))
        
        ;; Save all org buffers
        (org-save-all-org-buffers)))))

(defun consult-clock-nonimportant-task (&optional add-past-time)
  "Quick clock into mundane/leisure tasks with smart status prioritization.
Prioritizes active statuses (READING, STUDYING, PRACTICING) over pending ones.
With prefix argument ADD-PAST-TIME, prompts for start/end times instead of clocking in."
  (interactive "P")
  (let* ((sorted (rts--get-mundane-task-candidates))
         (prompt (if add-past-time 
                     "Add clock time to mundane task: "
                   "Clock into mundane/leisure task: "))
         (selected (when sorted
                     (consult--read sorted
                                    :prompt prompt
                                    :require-match t
                                    :sort nil
                                    :category 'mundane-task))))
    
    (if selected
        (let ((marker (cdr (assoc selected sorted))))
          (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
            (if add-past-time
                ;; Add past time mode
                (let* ((start-time (read-string "Start time (HH:MM): "))
                       (end-time (read-string "End time (HH:MM): "))
                       ;; Parse time inputs
                       (start-parts (split-string start-time ":"))
                       (end-parts (split-string end-time ":"))
                       (start-hour (string-to-number (car start-parts)))
                       (start-min (string-to-number (cadr start-parts)))
                       (end-hour (string-to-number (car end-parts)))
                       (end-min (string-to-number (cadr end-parts)))
                       ;; Create time objects for today with specified times
                       (today (decode-time (current-time)))
                       (start-time-obj (encode-time 0 start-min start-hour 
                                                    (nth 3 today) (nth 4 today) (nth 5 today)))
                       (end-time-obj (encode-time 0 end-min end-hour 
                                                  (nth 3 today) (nth 4 today) (nth 5 today)))
                       ;; Calculate duration in minutes
                       (duration-seconds (float-time (time-subtract end-time-obj start-time-obj)))
                       (duration-minutes (round (/ duration-seconds 60))))
                  
                  ;; Validate inputs
                  (unless (and (>= start-hour 0) (<= start-hour 23) (>= start-min 0) (<= start-min 59))
                    (error "Invalid start time format. Use HH:MM (e.g., 14:30)"))
                  (unless (and (>= end-hour 0) (<= end-hour 23) (>= end-min 0) (<= end-min 59))
                    (error "Invalid end time format. Use HH:MM (e.g., 16:45)"))
                  (unless (> duration-minutes 0)
                    (error "End time must be after start time"))
                  
                  ;; Add clock entry
                  (rts--add-clock-entry-to-task marker start-time-obj end-time-obj duration-minutes)
                  
                  ;; Get task info for display
                  (with-current-buffer (marker-buffer marker)
                    (save-excursion
                      (goto-char marker)
                      (let* ((task (org-element-at-point))
                             (heading (org-element-property :raw-value task))
                             (status (org-element-property :todo-keyword task))
                             (priority (rts--get-task-priority task))
                             (tags (rts--get-task-tags task)))
                        
                        ;; Show success posframe
                        (rts--show-unified-posframe
                         heading
                         priority
                         tags
                         status
                         'leisure)
                        
                        (when rts-debug-mode
                          (rts--debug-log "Added %d minutes (%s to %s) to mundane task: %s [%s]" 
                                          duration-minutes start-time end-time heading status))
                        
                        (message "Added %d minutes (%s to %s) to '%s' and saved all org buffers" 
                                 duration-minutes start-time end-time heading)))))
              
              ;; Normal clock-in mode
              (with-current-buffer (marker-buffer marker)
                (save-excursion
                  (goto-char marker)
                  (org-clock-in)
                  
                  ;; Get task info for display
                  (let* ((task (org-element-at-point))
                         (heading (org-element-property :raw-value task))
                         (status (org-element-property :todo-keyword task))
                         (priority (rts--get-task-priority task))
                         (tags (rts--get-task-tags task)))
                    
                    ;; Show success posframe with appropriate styling
                    (rts--show-unified-posframe
                     heading
                     priority
                     tags
                     status
                     'leisure)
                    
                    (when rts-debug-mode
                      (rts--debug-log "Clocked into mundane task: %s [%s]" heading status))
                    
                    (message "Clocked into: %s" heading)))))))
      (message "No mundane/leisure tasks found."))))

(defun consult-add-clock-to-mundane-task ()
  "Select a mundane/leisure task from a list and add clock time with start/end times.
This is an alias for calling consult-clock-nonimportant-task with prefix argument."
  (interactive)
  (consult-clock-nonimportant-task t))

(defun rts--get-all-task-candidates ()
  "Get formatted candidates from base tasks AND mundane/leisure tasks.
Returns list of (display . marker) pairs with duplicates removed."
  (let* ((base-tasks (rts--get-base-tasks 'tasks))
         (mundane-tasks (org-ql-select
                          (org-agenda-files)
                          '(and (not (done))
                                (or (todo "TOREAD" "READING" "REREADING" "SUMMARIZING")
                                    (todo "TOSTUDY" "STUDYING" "REVISING")
                                    (todo "TOPRACTICE" "PRACTICING" "REPRACTICING")
                                    (todo "TOWATCH" "WATCHING" "REWATCH")
                                    (todo "TONOTDO")))
                          :action 'element-with-markers))
         ;; Combine and dedupe by marker position
         (seen-positions (make-hash-table :test 'equal))
         (all-tasks (seq-filter
                     (lambda (task)
                       (let* ((marker (org-element-property :org-marker task))
                              (key (cons (marker-buffer marker) (marker-position marker))))
                         (unless (gethash key seen-positions)
                           (puthash key t seen-positions)
                           t)))
                     (append base-tasks mundane-tasks)))
         (candidates (mapcar
                      (lambda (task)
                        (let* ((heading (org-element-property :raw-value task))
                               (status (org-element-property :todo-keyword task))
                               (priority (rts--get-task-priority task))
                               (marker (org-element-property :org-marker task))
                               (display (format "%-12s | %s | %s"
                                                (propertize (or status "")
                                                            'face 'font-lock-keyword-face)
                                                (if priority
                                                    (propertize (format "[#%s]" priority)
                                                                'face 'font-lock-type-face)
                                                  "    ")
                                                heading)))
                          (cons display marker)))
                      all-tasks)))
    candidates))

(defun consult-add-clock-to-task ()
  "Select any task (scheduled, deadline, or mundane) and add clock time."
  (interactive)
  (let* ((candidates (rts--get-all-task-candidates))
         (selected (when candidates
                     (consult--read candidates
                                    :prompt "Add clock time to task: "
                                    :require-match t
                                    :sort nil
                                    :category 'org-task))))
    (if selected
        (let ((marker (cdr (assoc selected candidates))))
          (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
            (let* ((start-time (read-string "Start time (HH:MM): "))
                   (end-time (read-string "End time (HH:MM): "))
                   (start-parts (split-string start-time ":"))
                   (end-parts (split-string end-time ":"))
                   (start-hour (string-to-number (car start-parts)))
                   (start-min (string-to-number (cadr start-parts)))
                   (end-hour (string-to-number (car end-parts)))
                   (end-min (string-to-number (cadr end-parts)))
                   (today (decode-time (current-time)))
                   (start-time-obj (encode-time 0 start-min start-hour
                                                (nth 3 today) (nth 4 today) (nth 5 today)))
                   (end-time-obj (encode-time 0 end-min end-hour
                                              (nth 3 today) (nth 4 today) (nth 5 today)))
                   (duration-seconds (float-time (time-subtract end-time-obj start-time-obj)))
                   (duration-minutes (round (/ duration-seconds 60))))

              (unless (and (>= start-hour 0) (<= start-hour 23) (>= start-min 0) (<= start-min 59))
                (error "Invalid start time format. Use HH:MM (e.g., 14:30)"))
              (unless (and (>= end-hour 0) (<= end-hour 23) (>= end-min 0) (<= end-min 59))
                (error "Invalid end time format. Use HH:MM (e.g., 16:45)"))
              (unless (> duration-minutes 0)
                (error "End time must be after start time"))

              (rts--add-clock-entry-to-task marker start-time-obj end-time-obj duration-minutes)

              (with-current-buffer (marker-buffer marker)
                (save-excursion
                  (goto-char marker)
                  (let* ((task (org-element-at-point))
                         (heading (org-element-property :raw-value task))
                         (status (org-element-property :todo-keyword task))
                         (priority (rts--get-task-priority task))
                         (tags (rts--get-task-tags task)))

                    (rts--show-unified-posframe
                     heading
                     priority
                     tags
                     status
                     'tasks)

                    (when rts-debug-mode
                      (rts--debug-log "Added %d minutes (%s to %s) to task: %s [%s]"
                                      duration-minutes start-time end-time heading status))

                    (message "Added %d minutes (%s to %s) to '%s'"
                             duration-minutes start-time end-time heading)))))))
      (message "No tasks found."))))

;;; ===================================================================
;;; Universal Clock Time Functions - Work in Agenda and Org Mode
;;; ===================================================================

(defun rts--get-current-task-marker ()
  "Get marker for task at point, works in both agenda and org mode."
  (cond
   ;; In agenda mode
   ((derived-mode-p 'org-agenda-mode)
    (org-get-at-bol 'org-marker))
   ;; In org mode
   ((derived-mode-p 'org-mode)
    (save-excursion
      (org-back-to-heading t)
      (point-marker)))
   (t
    (error "Not in org-mode or agenda mode"))))

(defun rts--get-task-marker-smart ()
  "Get marker for task - from point if in org/agenda, or via consult selection.
Returns marker or nil if cancelled."
  (cond
   ;; In agenda mode - use task at point
   ((derived-mode-p 'org-agenda-mode)
    (org-get-at-bol 'org-marker))
   ;; In org mode - use task at point
   ((derived-mode-p 'org-mode)
    (save-excursion
      (org-back-to-heading t)
      (point-marker)))
   ;; Not in org context - show task selector
   (t
    (let* ((candidates (rts--get-all-task-candidates))
           (selected (when candidates
                       (consult--read candidates
                                      :prompt "Select task: "
                                      :require-match t
                                      :sort nil
                                      :category 'org-task))))
      (when selected
        (cdr (assoc selected candidates)))))))

(defun add-clock-time-by-offset ()
  "Add clock time to a task using offset approach.
Works from anywhere:
- In org/agenda mode: uses task at point
- Elsewhere: shows task selector via consult

Prompts for duration and end offset."
  (interactive)
  (let ((marker (rts--get-task-marker-smart)))
    (if (not marker)
        (message "No task selected")
      (let* ((duration (read-number "Minutes to clock: " 30))
             (end-offset (read-number "End how many minutes ago (0 = now): " 0))
             (end-offset (if (= end-offset 0) 1 end-offset))) ; Default to 1 minute ago if 0

        (when (> duration 0)
          (with-current-buffer (marker-buffer marker)
            (save-excursion
              (goto-char marker)
              (org-back-to-heading t)
              (let* ((heading (org-get-heading t t t t))
                     (now (current-time))
                     (end-time (time-subtract now (seconds-to-time (* end-offset 60))))
                     (start-time (time-subtract end-time (seconds-to-time (* duration 60))))
                     (start-str (format-time-string "[%Y-%m-%d %a %H:%M]" start-time))
                     (end-str (format-time-string "[%Y-%m-%d %a %H:%M]" end-time))
                     (hours (/ duration 60))
                     (mins (% duration 60))
                     (clock-entry (format "CLOCK: %s--%s =>  %2d:%02d" start-str end-str hours mins)))

                ;; Remember this task for rts-flow-clock-goto
                (setq rts-last-task-marker (copy-marker (point))
                      rts-last-task-heading heading)

                (rts--add-clock-entry-to-logbook clock-entry)
                (org-save-all-org-buffers)

                (when rts-debug-mode
                  (rts--debug-log "Added %d minutes (from %d to %d mins ago) via offset method"
                                  duration (+ duration end-offset) end-offset))

                (message "Added %d minutes to '%s' (from %d to %d mins ago)"
                         duration heading (+ duration end-offset) end-offset)))))))))

(defun add-clock-time-direct ()
  "Add clock time to a task using direct start/end time approach.
Works from anywhere:
- In org/agenda mode: uses task at point
- Elsewhere: shows task selector via consult

Prompts for start and end times (HH:MM format)."
  (interactive)
  (let ((marker (rts--get-task-marker-smart)))
    (if (not marker)
        (message "No task selected")
      (let* ((start-time-str (read-string "Start time (HH:MM): "))
             (end-time-str (read-string "End time (HH:MM): "))
             ;; Parse time inputs
             (start-parts (split-string start-time-str ":"))
             (end-parts (split-string end-time-str ":"))
             (start-hour (string-to-number (car start-parts)))
             (start-min (string-to-number (cadr start-parts)))
             (end-hour (string-to-number (car end-parts)))
             (end-min (string-to-number (cadr end-parts)))
             ;; Create time objects for today with specified times
             (today (decode-time (current-time)))
             (start-time-obj (encode-time 0 start-min start-hour
                                          (nth 3 today) (nth 4 today) (nth 5 today)))
             (end-time-obj (encode-time 0 end-min end-hour
                                        (nth 3 today) (nth 4 today) (nth 5 today)))
             ;; Calculate duration in minutes
             (duration-seconds (float-time (time-subtract end-time-obj start-time-obj)))
             (duration-minutes (round (/ duration-seconds 60))))

        ;; Validate inputs
        (unless (and (>= start-hour 0) (<= start-hour 23) (>= start-min 0) (<= start-min 59))
          (error "Invalid start time format. Use HH:MM (e.g., 14:30)"))
        (unless (and (>= end-hour 0) (<= end-hour 23) (>= end-min 0) (<= end-min 59))
          (error "Invalid end time format. Use HH:MM (e.g., 16:45)"))
        (unless (> duration-minutes 0)
          (error "End time must be after start time"))

        (when (> duration-minutes 0)
          (with-current-buffer (marker-buffer marker)
            (save-excursion
              (goto-char marker)
              (org-back-to-heading t)
              (let ((heading (org-get-heading t t t t)))

                ;; Remember this task for rts-flow-clock-goto
                (setq rts-last-task-marker (copy-marker (point))
                      rts-last-task-heading heading)

                ;; Add clock entry using existing helper function
                (rts--add-clock-entry-to-task marker start-time-obj end-time-obj duration-minutes)

                (when rts-debug-mode
                  (rts--debug-log "Added %d minutes (%s to %s) via direct time method"
                                  duration-minutes start-time-str end-time-str))

                (message "Added %d minutes (%s to %s) to '%s'"
                         duration-minutes start-time-str end-time-str heading)))))))))

(defun rts--add-clock-entry-to-logbook (clock-entry)
  "Add CLOCK-ENTRY to the current task's LOGBOOK drawer.
Helper function for universal clock time functions."
  (let* ((heading-start (point))
         (heading-end (save-excursion 
                        (org-end-of-subtree t t)
                        (point)))
         ;; Search for existing LOGBOOK drawer after the heading line
         (logbook-region (save-excursion
                           (goto-char heading-start)
                           (forward-line 1) ; Skip the heading line itself
                           (when (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" heading-end t)
                             (let ((lb-start (line-beginning-position)))
                               (when (re-search-forward "^[ \t]*:END:[ \t]*$" heading-end t)
                                 (cons lb-start (line-beginning-position))))))))
    
    (if logbook-region
        ;; LOGBOOK exists, add entry after :LOGBOOK: line
        (progn
          (goto-char (car logbook-region))
          (forward-line 1)
          (insert clock-entry "\n"))
      ;; No LOGBOOK, create one after metadata
      (progn
        (goto-char heading-start)
        (org-end-of-meta-data)
        (insert ":LOGBOOK:\n")
        (insert clock-entry "\n")
        (insert ":END:\n")))))

;;; Taken from https://xenodium.com/building-your-own-bookmark-launcher/
;;;###autoload
(defun browser-bookmarks (org-file)
  "Return all links from ORG-FILE."
  (with-temp-buffer
    (let (links)
      (insert-file-contents org-file)
      (org-mode)
      (org-element-map (org-element-parse-buffer) 'link
        (lambda (link)
          (let* ((raw-link (org-element-property :raw-link link))
                 (content (org-element-contents link))
                 (title (substring-no-properties (or (seq-first content) raw-link))))
            (push (concat title
                          "\n\n"
                          (propertize raw-link 'face 'whitespace-space)
                          "\n\n")
                  links)))
        nil nil 'link)
      (seq-sort 'string-greaterp links))))


;;; ===================================================================
;;; Auto-open Links for Study Tasks
;;; ===================================================================

(defvar rts-auto-open-links-on-clock-in t
  "When non-nil, automatically open links when clocking into study/leisure tasks.")

(defvar rts-link-open-tags '("studyactive" "blog" "youtube" "watchlist" "repo" "technical")
  "List of tags that trigger automatic link opening when clocking in.")

(defun rts--extract-links-from-entry ()
  "Extract all URLs from the current org entry (heading and content).
Returns a list of URLs found."
  (save-excursion
    (org-back-to-heading t)
    (let* ((element (org-element-at-point))
           (begin (org-element-property :begin element))
           (end (org-element-property :end element))
           (content (buffer-substring-no-properties begin end))
           (urls nil))
      ;; Match various URL patterns
      (with-temp-buffer
        (insert content)
        (goto-char (point-min))
        ;; Match plain URLs
        (while (re-search-forward "https?://[^[:space:]\n]+" nil t)
          (push (match-string 0) urls))
        ;; Also match org-link format [[URL][description]]
        (goto-char (point-min))
        (while (re-search-forward "\\[\\[\\(https?://[^]]+\\)\\]" nil t)
          (push (match-string 1) urls)))
      (nreverse urls))))

(defun rts--should-auto-open-link-p ()
  "Check if current entry should trigger automatic link opening.
Returns t if any of the auto-open tags are present."
  (let ((tags (org-get-tags)))
    (seq-some (lambda (tag) (member tag tags)) rts-link-open-tags)))

(defun rts--open-links-for-task ()
  "Open all links found in the current task if appropriate."
  (when (and rts-auto-open-links-on-clock-in
             (rts--should-auto-open-link-p))
    (let ((urls (rts--extract-links-from-entry)))
      (when urls
        (dolist (url urls)
          ;; Clean up the URL (remove trailing punctuation, org-link remnants)
          (setq url (replace-regexp-in-string "\\].*$" "" url))
          (setq url (replace-regexp-in-string "[,;.]$" "" url))
          (browse-url url)
          (when rts-debug-mode
            (rts--debug-log "Opened URL: %s" url)))
        (message "Opened %d link(s) for task" (length urls))))))

(defun rts--clock-in-with-link-opening (orig-fun &rest args)
  "Advice function to open links after clocking in.
Wraps org-clock-in to add link opening functionality."
  (let ((result (apply orig-fun args)))
    ;; After successful clock-in, check for and open links
    (rts--open-links-for-task)
    result))

;; Install advice when productivity system loads
(advice-add 'org-clock-in :around #'rts--clock-in-with-link-opening)

;;; ===================================================================
;;; LAST_ACCESSED Tracking - Foundation for River Flow System
;;; ===================================================================

(defvar rts-track-last-accessed t
  "When non-nil, automatically update LAST_ACCESSED property on clock-in.")

(defun rts--update-last-accessed ()
  "Update LAST_ACCESSED property for the current entry.
Called automatically when clocking in to track engagement."
  (when rts-track-last-accessed
    (save-excursion
      (org-back-to-heading t)
      (org-set-property "LAST_ACCESSED" (format-time-string "[%Y-%m-%d %a]"))
      (when rts-debug-mode
        (rts--debug-log "Updated LAST_ACCESSED for: %s"
                        (org-get-heading t t t t))))))

(defun rts--get-days-since-accessed (task)
  "Get number of days since TASK was last accessed.
Returns nil if LAST_ACCESSED is not set, indicating never accessed."
  (let ((marker (org-element-property :org-marker task)))
    (when (and marker (markerp marker) (buffer-live-p (marker-buffer marker)))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (let ((last-accessed (org-entry-get nil "LAST_ACCESSED")))
            (when last-accessed
              (let ((accessed-time (org-time-string-to-time last-accessed)))
                (/ (float-time (time-subtract (current-time) accessed-time))
                   86400.0)))))))))

(defun rts--calculate-neglect-bonus (task)
  "Calculate bonus points for neglected items.
Items not accessed recently get higher probability of selection.
Returns points to add to base probability."
  (let ((days (rts--get-days-since-accessed task)))
    (cond
     ((null days) 8)           ; Never accessed = high priority
     ((> days 30) 15)          ; Month+ neglected = very high
     ((> days 14) 10)          ; 2 weeks = high
     ((> days 7) 5)            ; 1 week = moderate
     ((> days 3) 2)            ; Few days = slight
     (t 0))))                  ; Recently accessed = no bonus

;; Add to clock-in hook
(add-hook 'org-clock-in-hook #'rts--update-last-accessed)

(provide 'productivity)
;;; productivity.el ends here
