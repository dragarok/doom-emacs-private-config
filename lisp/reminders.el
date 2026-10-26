;;; reminders.el --- A task's reminder, rung by the Emacs Home app -*- lexical-binding: t -*-

;;; Commentary:
;; Emacs on the phone is asleep or gone most of the time, so its timers
;; can't ring a reminder.  The Emacs Home app can: it sets an exact alarm
;; for each line of reminders.tsv, which Emacs writes into the folder they
;; share (`emacs-home-dir'), and rings it as a notification -- Open, Clock
;; in, Snooze -- whether Emacs is awake or not.
;;
;; What reminds, and when:
;;   - a task (or event) with a time -- SCHEDULED, an active timestamp, or
;;     a DEADLINE, with a time of day -- `reminders-default-minutes' before;
;;   - its :REMIND: property, set with `reminders-set' (SPC m R, or in the
;;     agenda): "30m", "1h", "1d" before that time; a time of its own (a
;;     timestamp, so a task with no time can remind too); or "none".
;; Done tasks don't.  Only the next `reminders-days' are written.
;;
;; Written on the phone only (the Mac has no app to ring them): when an
;; agenda file is saved, and every half hour (files that came by Syncthing,
;; and the window moving on).  Read from the files on disk, not buffers.

;;; Code:

(require 'org)
(require 'org-agenda)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar emacs-home-dir "/data/data/com.termux/files/home/.emacs-home/")

(defgroup reminders nil
  "A task's reminder, rung by the Emacs Home app."
  :group 'org)

(defcustom reminders-default-minutes 10
  "A task with a time reminds this many minutes before, unless :REMIND: says."
  :type 'integer)

(defcustom reminders-days 7
  "Reminders this many days ahead are written for the app."
  :type 'integer)

;;; When a task reminds

(defun reminders--offset (s)
  "Minutes in S -- \"10\", \"10m\", \"2h\", \"1d\" -- or nil."
  (when (and s (string-match "\\`[ \t]*\\([0-9]+\\)[ \t]*\\([mhd]?\\)[ \t]*\\'" s))
    (* (string-to-number (match-string 1 s))
       (pcase (match-string 2 s) ("h" 60) ("d" 1440) (_ 1)))))

(defun reminders--timed (stamp)
  "STAMP's start as a time, when it has a time of day; else nil."
  (when (and stamp (string-match-p "[0-9]\\{1,2\\}:[0-9]\\{2\\}" stamp))
    (org-time-string-to-time stamp)))

(defun reminders--base ()
  "The time the entry at point is at: its timed SCHEDULED, active
timestamp, or DEADLINE, in that order; nil if none has a time."
  (seq-some (lambda (p) (reminders--timed (org-entry-get nil p)))
            '("SCHEDULED" "TIMESTAMP" "DEADLINE")))

(defun reminders-time ()
  "When the entry at point reminds, as a time, or nil."
  (let ((remind (org-entry-get nil "REMIND"))
        (base (reminders--base)))
    (cond ((and remind (string-match-p "\\`[ \t]*none[ \t]*\\'" remind)) nil)
          ((reminders--offset remind)
           (and base (time-subtract base (* 60 (reminders--offset remind)))))
          ((and remind (string-match-p "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" remind))
           (org-time-string-to-time remind))
          (base (time-subtract base (* 60 reminders-default-minutes))))))

;;; Written for the app

(defun reminders--clean (s)
  "S as one line of plain text: links as their descriptions, no tabs."
  (string-trim
   (replace-regexp-in-string
    "[\t\n]+" " "
    (replace-regexp-in-string "\\[\\[\\(?:[^]]*\\]\\[\\)?\\([^]]*\\)\\]\\]" "\\1" s))))

(defun reminders-collect (files &optional now)
  "The reminders in FILES from NOW (default: now) to `reminders-days' on,
in time order: (TIME TITLE AT FILE HEADING), AT the task's own time
\"HH:MM\" or \"\"."
  (let* ((now (or now (current-time)))
         (until (time-add now (days-to-time reminders-days)))
         out)
    (dolist (file files)
      (when (file-exists-p file)
        (with-temp-buffer
          (let ((coding-system-for-read 'utf-8)) (insert-file-contents file))
          (delay-mode-hooks (org-mode))
          (org-map-entries
           (lambda ()
             (unless (org-entry-is-done-p)
               (when-let* ((time (reminders-time))
                           ((time-less-p now time))
                           ((time-less-p time until)))
                 (let ((heading (substring-no-properties (org-get-heading t t t t)))
                       (base (reminders--base)))
                   (push (list time (reminders--clean heading)
                               (if base (format-time-string "%H:%M" base) "")
                               file heading)
                         out)))))))))
    (sort out (lambda (a b) (time-less-p (car a) (car b))))))

(defun reminders--files ()
  "The agenda's files, as `org-agenda-files' names them (directories too)."
  (seq-filter #'file-regular-p (org-agenda-files t)))

(defun reminders-write (&optional now)
  "Write reminders.tsv for the app: TIME-MS TAB TITLE TAB AT TAB FILE TAB
HEADING, a line each.  Written whole and moved into place, so the app
reads it once, complete.  Only where the app's folder is."
  (interactive)
  (when (file-directory-p emacs-home-dir)
    (let ((file (expand-file-name "reminders.tsv" emacs-home-dir))
          (tmp (expand-file-name ".reminders.tsv.tmp" emacs-home-dir))
          (rows (reminders-collect (reminders--files) now)))
      (with-temp-file tmp
        (dolist (r rows)
          (insert (format "%d\t%s\t%s\t%s\t%s\n"
                          (truncate (* 1000 (float-time (nth 0 r))))
                          (nth 1 r) (nth 2 r) (nth 3 r) (reminders--clean (nth 4 r))))))
      (rename-file tmp file t)
      (when (called-interactively-p 'any)
        (message "%d reminder%s for the next %d days" (length rows) (if (= 1 (length rows)) "" "s")
                 reminders-days))
      rows)))

;;; Setting one

;;;###autoload
(defun reminders-set ()
  "Set the reminder of the task at point (or the agenda's line): minutes
or hours before its time (\"30m\", \"1h\"), a time of its own (\"8:30\",
\"tomorrow 9am\"), \"none\" -- or empty, for the default."
  (interactive)
  (let ((marker (if (derived-mode-p 'org-agenda-mode)
                    (or (org-get-at-bol 'org-hd-marker) (user-error "No task on this line"))
                  (point-marker))))
    (with-current-buffer (marker-buffer marker)
      (org-with-wide-buffer
       (goto-char marker)
       (org-back-to-heading t)
       (let* ((base (reminders--base))
              (answer (string-trim
                       (read-string
                        (format "Remind %s — \"30m\"/\"1h\" before%s, a time (8:30, tomorrow 9am), none (empty: %s): "
                                (substring-no-properties (org-get-heading t t t t))
                                (if base (format-time-string " %H:%M" base) " its time")
                                (if base (format "%dm before" reminders-default-minutes) "no reminder"))))))
         (cond ((string-empty-p answer) (org-entry-delete nil "REMIND"))
               ((or (equal answer "none") (reminders--offset answer)) (org-entry-put nil "REMIND" answer))
               (t (org-entry-put nil "REMIND"
                                 (format-time-string "[%Y-%m-%d %a %H:%M]" (org-read-date t t answer)))))
         (save-buffer)
         (message "Reminder: %s"
                  (if-let* ((time (reminders-time))) (format-time-string "%a %d %b %H:%M" time) "none")))))))

;;; From the app's buttons

(defun reminders--goto (file heading)
  "Visit FILE at HEADING (exact), or the file's top if it is gone."
  (find-file file)
  (widen)
  (goto-char (or (org-find-exact-headline-in-buffer heading nil t) (point-min)))
  (org-fold-show-context)
  (org-fold-show-entry))

(defun reminders-open (file heading)
  "The app's Open: the task, in Emacs."
  (reminders--goto file heading))

(defun reminders-clock-in (file heading)
  "The app's Clock in: clock into the task."
  (save-window-excursion
    (reminders--goto file heading)
    (org-clock-in)))

;;; Keeping the file current

(defvar reminders--timer nil)

(defun reminders--after-save ()
  "An agenda file saved: write the reminders again, once things are quiet."
  (when (and buffer-file-name (member (file-truename buffer-file-name)
                                      (mapcar #'file-truename (reminders--files))))
    (when (timerp reminders--timer) (cancel-timer reminders--timer))
    (setq reminders--timer
          (run-with-idle-timer 2 nil (lambda () (with-demoted-errors "reminders: %S" (reminders-write)))))))

(defvar reminders--clock nil)

;;;###autoload
(define-minor-mode reminders-mode
  "Keep reminders.tsv written for the Emacs Home app."
  :global t :group 'reminders
  (when (timerp reminders--clock) (cancel-timer reminders--clock))
  (remove-hook 'after-save-hook #'reminders--after-save)
  (when reminders-mode
    (add-hook 'after-save-hook #'reminders--after-save)
    (setq reminders--clock
          (run-at-time 30 1800 (lambda () (with-demoted-errors "reminders: %S" (reminders-write)))))))

(provide 'reminders)
;;; reminders.el ends here
