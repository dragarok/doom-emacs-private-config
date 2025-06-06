;;; rts.el -*- lexical-binding: t; -*-

;;; Configuration
(defvar rts-difficulty-tags '("Challenge" "Average" "Easy")
  "List of difficulty tags.")

(defvar rts-energy-tags '("Lazy" "ModeratelyLazy" "Energetic")
  "List of energy level tags.")

(defvar rts-time-tags '("Morning" "Day" "Evening")
  "List of time of day tags.")

(defvar rts-priority-points
  '(("A" . 10) ("B" . 6) ("C" . 4) ("D" . 3) ("E" . 2))
  "Points assigned to each priority level for probability calculation.")

;;; Helper Functions

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

(defun rts--has-tag-p (tags target-tag)
  "Check if TAGS list contains TARGET-TAG."
  (member target-tag tags))

(defun rts--has-any-tag-p (tags tag-list)
  "Check if TAGS contains any tag from TAG-LIST."
  (seq-some (lambda (tag) (member tag tags)) tag-list))

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
    (or points 1))) ; Default to 1 point for unrecognized priorities

(defun rts--select-by-probability (tasks)
  "Select a task from TASKS based on probability weights."
  (if (= (length tasks) 1)
      (car tasks)
    (let* ((task-points (mapcar (lambda (task)
                                  (cons task (rts--calculate-task-points task)))
                                tasks))
           (total-points (apply #'+ (mapcar #'cdr task-points)))
           (random-point (random total-points))
           (current-sum 0))
      (catch 'selected
        (dolist (task-point task-points)
          (setq current-sum (+ current-sum (cdr task-point)))
          (when (>= current-sum random-point)
            (throw 'selected (car task-point))))
        ;; Fallback (shouldn't happen)
        (caar task-points)))))

(defun rts--get-base-tasks ()
  "Get base tasks that meet initial filtering criteria."
  (org-ql-select
    (org-agenda-files)
    '(and (todo)
          (or (scheduled :to 0)
              (deadline :to 7)))
    :action 'element-with-markers
    :sort '(priority)
    ))

(defun rts--display-selected-task (task)
  "Display the selected TASK."
  (if task
      (let* ((heading (org-element-property :raw-value task))
             (priority (rts--get-task-priority task))
             (tags (rts--get-task-tags task))
             (file (org-element-property :file task))
             (pos (org-element-property :begin task)))
        (message "Selected task: %s %s [%s] %s "
                 heading
                 (or priority "No priority")
                 (or file "No filename")
                 (if tags (format ":%s:" (string-join tags ":")) ""))
        ;; Jump to the task
        (find-file file)
        (goto-char pos)
        (org-show-context))
    (message "No tasks found matching criteria.")))

(defun rts--display-selected-task (task)
  "Display the selected TASK."
  (if task
      (let* ((heading (org-element-property :raw-value task))
             (priority (rts--get-task-priority task))
             (tags (rts--get-task-tags task))
             (marker (org-element-property :org-marker task)) ; Get the marker
             (file (when marker (buffer-file-name (marker-buffer marker)))) ; Get file from marker
             (pos (org-element-property :begin task)))
        (message "Selected task: %s [%s] %s %s"
                 heading
                 (or priority "No priority")
                 (or marker "No filename")
                 (if tags (format ":%s:" (string-join tags ":")) ""))
        ;; Jump to the task
        (when file
          (find-file file)
          (goto-char pos)
          (org-show-context)))
    (message "No tasks found matching criteria.")))

;;; Main Functions

(defun random-task-select (&optional prefix-arg)
  "Select a random task from filtered list.
With PREFIX-ARG, prompt for difficulty and energy filtering."
  (interactive "P")
  (let* ((base-tasks (rts--get-base-tasks))
         (filtered-tasks
          (if prefix-arg
              (let* ((difficulty (consult--read "Difficulty: " rts-difficulty-tags))
                     (energy (consult--read "Energy: " rts-energy-tags)))
                (rts--filter-by-difficulty-energy base-tasks difficulty energy))
            base-tasks)))
    (when filtered-tasks
      (let ((selected-task (nth (random (length filtered-tasks)) filtered-tasks)))
        (rts--display-selected-task selected-task)))))

(defun priority-time-task-select (&optional prefix-arg)
  "Select a task based on priority and time of day logic.
With PREFIX-ARG, apply difficulty/energy filtering to lower-priority tasks."
  (interactive "P")
  (let* ((base-tasks (rts--get-base-tasks))
         (priority-a-tasks (rts--get-priority-tasks base-tasks))
         (current-time (rts--get-current-time-of-day)))

    (if priority-a-tasks
        ;; Handle priority A tasks
        (let* ((sorted-tasks (rts--sort-by-time-priority priority-a-tasks))
               ;; Get tasks from the earliest time group
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
          (rts--display-selected-task
           (nth (random (length same-time-tasks)) same-time-tasks)))

      ;; Handle lower priority tasks
      (let* ((lower-tasks (rts--get-lower-priority-tasks base-tasks))
             (time-filtered (rts--filter-by-time-of-day lower-tasks current-time))
             (final-tasks (if (null time-filtered) lower-tasks time-filtered))
             (final-filtered
              (if prefix-arg
                  (let* ((difficulty (consult--read "Difficulty: " rts-difficulty-tags))
                         (energy (consult--read "Energy: " rts-energy-tags)))
                    (rts--filter-by-difficulty-energy final-tasks difficulty energy))
                final-tasks)))
        (when final-filtered
          (rts--display-selected-task
           (rts--select-by-probability final-filtered)))))))
