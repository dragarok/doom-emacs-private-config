;;; micro-experiments.el --- Random micro-task picker -*- lexical-binding: t -*-

;;; Commentary:
;; Pick a random 5-minute task from micro_experiments.org and show it.
;; One button. One task. No tracking. Just do it.
;; Logging category tasks prompt for input and write to today's org-roam daily note.
;; Works as both a button press (toolbar/keybinding) and an auto-timer.

;;; Code:

(defvar micro-experiments-file (concat org-directory "micro_experiments.org")
  "Path to the micro experiments org file.")

(defvar micro-experiments-interval "45 minutes"
  "How often to auto-prompt for a micro experiment.")

(defun micro-experiments--collect-tasks ()
  "Collect all level-2 headings with their parent category from the micro experiments file."
  (let ((tasks '()))
    (with-temp-buffer
      (insert-file-contents micro-experiments-file)
      (org-mode)
      (org-map-entries
       (lambda ()
         (when (= (org-current-level) 2)
           (let ((task (org-get-heading t t t t))
                 (category (save-excursion
                             (org-up-heading-safe)
                             (org-get-heading t t t t))))
             (push (cons category task) tasks))))))
    tasks))

(defun micro-experiments--category-emoji (category)
  "Return an emoji for CATEGORY."
  (pcase category
    ("Kitchen" "🍳")
    ("Body" "💪")
    ("Habits that I haven't been doing" "🔄")
    ("Cleaning" "🧹")
    ("Hygiene" "🚿")
    ("Logging" "📝")
    ("Transition" "🌊")
    ("Reset" "🧘")
    ("Weekly Review (Sunday evening)" "📋")
    (_ "⚡")))

(defun micro-experiments--log-to-daily (entry)
  "Write ENTRY with timestamp under * Logs in today's org-roam daily note."
  (let ((original-buffer (current-buffer))
        (timestamp (format-time-string "%H:%M")))
    (org-roam-dailies-goto-today)
    (let ((daily-buffer (current-buffer)))
      (switch-to-buffer original-buffer)
      (with-current-buffer daily-buffer
        (goto-char (point-min))
        (unless (re-search-forward "^\\* Logs" nil t)
          (goto-char (point-max))
          (insert "\n* Logs\n"))
        ;; Go to end of Logs section (before next heading or end of file)
        (let ((logs-end (save-excursion
                          (if (re-search-forward "^\\* " nil t)
                              (line-beginning-position)
                            (point-max)))))
          (goto-char logs-end)
          (unless (bolp) (insert "\n"))
          (insert (format "- =%s= %s\n" timestamp entry)))
        (save-buffer)))))

(defun micro-experiments--handle-logging (task)
  "Handle a logging category TASK: prompt for input with timeout, write to daily note."
  (let* ((emoji (micro-experiments--category-emoji "Logging"))
         (timeout-timer (run-with-timer 30 nil (lambda () (throw 'exit t))))
         (input nil))
    (unwind-protect
        (condition-case _err
            (setq input (read-string (format "%s %s: " emoji task)))
          (quit
           (message "Dismissed. Next prompt in %s." micro-experiments-interval)))
      (when (timerp timeout-timer)
        (cancel-timer timeout-timer)))
    (when (and input (not (string-empty-p input)))
      (micro-experiments--log-to-daily input)
      (message "Logged to daily note."))))

(defun micro-experiments--posframe-width ()
  "Return a responsive posframe width based on frame size.
Uses 70% of frame columns, clamped between 30 and 54."
  (max 30 (min 54 (/ (* (frame-width) 70) 100))))

(defun micro-experiments--show-posframe (category task emoji)
  "Flash TASK from CATEGORY with EMOJI in a centered posframe."
  (let* ((w (micro-experiments--posframe-width))
         (buffer (get-buffer-create "*Micro Experiment*")))

    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "%s %s" emoji (upcase category))
                            'face 'font-lock-keyword-face))
        (insert "\n\n")
        (let ((start (point)))
          (insert (propertize task 'face 'font-lock-function-name-face))
          (let ((fill-column (- w 4)))
            (fill-region start (point))))
        (insert "\n\n")
        (insert (propertize "~ Just do it. ~"
                            'face 'font-lock-comment-face))
        (setq buffer-read-only t)
        (set (make-local-variable 'face-remapping-alist)
             '((default (:height 220) default)))))

    (require 'posframe)
    (posframe-show buffer
                   :poshandler 'posframe-poshandler-frame-center
                   :width w
                   :border-width 3
                   :border-color "#e0a030"
                   :accept-focus nil)

    (run-with-timer 8 nil
                    (lambda (buf)
                      (posframe-delete buf))
                    buffer)))

(defun micro-experiments-pick ()
  "Pick a random micro experiment. Button press or timer — same function.
Logging tasks prompt for input and write to today's daily note.
All other tasks flash a posframe."
  (interactive)
  (let* ((tasks (micro-experiments--collect-tasks))
         (pick (nth (random (length tasks)) tasks))
         (category (car pick))
         (task (cdr pick))
         (emoji (micro-experiments--category-emoji category)))
    (if (member category '("Logging" "Weekly Review (Sunday evening)"))
        (micro-experiments--handle-logging task)
      (micro-experiments--show-posframe category task emoji))))

(defun micro-experiments-log ()
  "Directly log what you're doing to today's daily note. No randomness."
  (interactive)
  (micro-experiments--handle-logging "What are you working on?"))

;;; Auto-timer (like energy log)

(defun micro-experiments--timer-tick ()
  "Timer callback: pick a micro experiment, then schedule next."
  (micro-experiments-pick)
  (run-at-time micro-experiments-interval nil #'micro-experiments--timer-tick))

;; Start the timer
(run-at-time micro-experiments-interval nil #'micro-experiments--timer-tick)

(provide 'micro-experiments)
;;; micro-experiments.el ends here
