;;; review-reminders.el --- Daily and weekly review reminder system -*- lexical-binding: t; -*-

;;; Commentary:
;; Automatic reminder system for daily and weekly reviews.
;; Prompts at 8 PM for daily reviews and Mondays for weekly reviews.
;; Supports snoozing and timeout handling.

;;; Code:

(require 'org)

(defvar daily-review-reminder-timer nil "Timer for daily review reminders")
(defvar weekly-review-reminder-timer nil "Timer for weekly review reminders")

(defun daily-review-exists-p ()
  "Check if today's daily review exists in the datetree."
  (let* ((today (decode-time))
         (year (format "%04d" (nth 5 today)))
         (month (format-time-string "%B"))
         (day (format-time-string "%Y-%m-%d")))
    (condition-case nil
        (org-find-olp (list org-dailyreview-file year month day) t)
      (error nil))))

(defun weekly-review-exists-p ()
  "Check if this week's weekly review exists."
  (let* ((week-string (format-time-string "%Y-W%V")))
    (condition-case nil
        (with-current-buffer (find-file-noselect org-weeklyreview-file)
          (goto-char (point-min))
          (search-forward week-string nil t))
      (error nil))))

(defun schedule-next-daily-prompt ()
  "Schedule the next daily review prompt for tomorrow at 8 PM."
  (let* ((now (decode-time))
         (hour (nth 2 now))
         (min (nth 1 now))
         (sec (nth 0 now))
         (current-secs (+ (* hour 3600) (* min 60) sec))
         (secs-to-midnight (- 86400 current-secs))
         (target-secs-from-midnight (* 20 3600)))
    (setq daily-review-reminder-timer
          (run-at-time (+ secs-to-midnight target-secs-from-midnight) nil 'prompt-daily-review))))

(defun schedule-next-weekly-prompt ()
  "Schedule the next weekly review prompt for next Monday at 8 PM."
  (let* ((now (decode-time))
         (dow (nth 6 now))
         (hour (nth 2 now))
         (min (nth 1 now))
         (sec (nth 0 now))
         (days-to-next-monday (mod (+ (- 1 dow) 7) 7))
         (current-secs (+ (* hour 3600) (* min 60) sec))
         (target-secs (* 20 3600))
         (delta (- target-secs current-secs)))
    (setq weekly-review-reminder-timer
          (run-at-time (+ (* days-to-next-monday 86400.0) delta) nil 'prompt-weekly-review))))

(defun prompt-daily-review ()
  "Prompt for daily review with timeout and auto-reschedule."
  (interactive)
  (unless (daily-review-exists-p)
    (let* ((choices '("Today" "Yesterday" "Skip"))
           (timeout-timer (run-with-timer 30 nil (lambda () (throw 'exit :timeout))))
           (choice))
      (unwind-protect
          (condition-case err
              (setq choice (catch 'exit (consult--read choices
                                                       :prompt "Daily review missing. Create for: "
                                                       :require-match t)))
            (quit
             (message "Daily review reminder aborted. Snoozed for 1 hour.")
             (setq daily-review-reminder-timer (run-at-time "1 hour" nil 'prompt-daily-review))))
        (when (timerp timeout-timer)
          (cancel-timer timeout-timer)))
      (cond
       ((eq choice :timeout)
        (message "Daily review reminder timed out. Snoozed for 1 hour.")
        (setq daily-review-reminder-timer (run-at-time "1 hour" nil 'prompt-daily-review)))
       (choice
        (cond
         ((string= choice "Today")
          (org-capture nil "rd"))
         ((string= choice "Yesterday")
          (org-capture nil "ry"))
         ((string= choice "Skip")
          (message "Daily review skipped for today")))
        (schedule-next-daily-prompt))))))

(defun prompt-weekly-review ()
  "Prompt for weekly review with timeout and auto-reschedule."
  (interactive)
  (unless (weekly-review-exists-p)
    (let* ((choices '("This Week" "Last Week" "Skip"))
           (timeout-timer (run-with-timer 30 nil (lambda () (throw 'exit :timeout))))
           (choice))
      (unwind-protect
          (condition-case err
              (setq choice (catch 'exit (consult--read choices
                                                       :prompt "Weekly review missing. Create for: "
                                                       :require-match t)))
            (quit
             (message "Weekly review reminder aborted. Snoozed for 5 hours.")
             (setq weekly-review-reminder-timer (run-at-time "5 hours" nil 'prompt-weekly-review))))
        (when (timerp timeout-timer)
          (cancel-timer timeout-timer)))
      (cond
       ((eq choice :timeout)
        (message "Weekly review reminder timed out. Snoozed for 5 hours.")
        (setq weekly-review-reminder-timer (run-at-time "5 hours" nil 'prompt-weekly-review)))
       (choice
        (cond
         ((string= choice "This Week")
          (org-capture nil "rw"))
         ((string= choice "Last Week")
          (org-capture nil "rl"))
         ((string= choice "Skip")
          (message "Weekly review skipped for this week")))
        (schedule-next-weekly-prompt))))))

;;;###autoload
(defun start-daily-review-reminders ()
  "Start daily review reminder system."
  (interactive)
  ;; Cancel existing timer if any
  (when daily-review-reminder-timer
    (cancel-timer daily-review-reminder-timer)
    (setq daily-review-reminder-timer nil))

  ;; Check if we should start reminding today
  (let* ((now (decode-time))
         (hour (nth 2 now)))
    (if (>= hour 20)
        ;; After 8 PM, schedule for tomorrow
        (schedule-next-daily-prompt)
      ;; Before 8 PM, schedule for today 8 PM
      (let* ((min (nth 1 now))
             (sec (nth 0 now))
             (current-secs (+ (* hour 3600) (* min 60) sec))
             (target-secs (* 20 3600))
             (secs-to-8pm (- target-secs current-secs)))
        (setq daily-review-reminder-timer (run-at-time secs-to-8pm nil 'prompt-daily-review))))))

;;;###autoload
(defun start-weekly-review-reminders ()
  "Start weekly review reminder system."
  (interactive)
  ;; Cancel existing timer if any
  (when weekly-review-reminder-timer
    (cancel-timer weekly-review-reminder-timer)
    (setq weekly-review-reminder-timer nil))

  ;; Schedule for next Monday at 8 PM
  (schedule-next-weekly-prompt))

;; Auto-start the reminder systems
(add-hook 'emacs-startup-hook 'start-daily-review-reminders)
(add-hook 'emacs-startup-hook 'start-weekly-review-reminders)

;; Also check periodically in case timers get lost
(run-with-idle-timer 3600 t  ; Check every hour when idle
                     (lambda ()
                       (unless daily-review-reminder-timer
                         (start-daily-review-reminders))
                       (unless weekly-review-reminder-timer
                         (start-weekly-review-reminders))))

(provide 'review-reminders)
;;; review-reminders.el ends here
