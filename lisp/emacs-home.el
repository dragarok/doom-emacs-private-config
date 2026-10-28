;;; emacs-home.el --- Emacs as the Android home screen -*- lexical-binding: t -*-

;;; Commentary:
;; The Emacs Home app (~/.doom.d/emacs-home) is the phone's launcher.  It has
;; no screen of its own: Home brings Emacs forward, as it was, and calls
;; `emacs-home-on-home', it keeps apps.tsv and icons/ in `emacs-home-dir'
;; current, and it opens emacs-home://launch/PACKAGE/ACTIVITY for us.
;;
;; The homepage shows your pinned apps as rows of small icons, so a couple of
;; rows still fit above the touch keyboard.  `emacs-home-launch' (the
;; toolbar's Apps) picks from every app and the pinned shortcuts;
;; `emacs-home-toggle-pin' pins or unpins one.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'usage-log)

(defconst emacs-home-dir "/data/data/com.termux/files/home/.emacs-home/"
  "Where the app writes the catalog.  It shares Emacs's uid, so both can.")

(defvar emacs-home-icons-per-row 8
  "Pinned apps across the homepage; the icons grow to fill the width.")

(defvar emacs-home-icon-fill 0.78
  "How much of its cell an icon takes; the rest is the gap between them.")

(defun emacs-home--apps ()
  "Installed apps as (LABEL PACKAGE ACTIVITY), from the app's catalog."
  (let ((file (expand-file-name "apps.tsv" emacs-home-dir)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (mapcar (lambda (line) (split-string line "\t"))
                (split-string (buffer-string) "\n" t))))))

(defun emacs-home--key (app)
  (format "%s/%s" (nth 1 app) (nth 2 app)))

;; Besides apps, the grid takes apps' shortcuts (Shortcuts.java: Firefox's
;; private tab) and Hail's freeze; and other apps' widgets show under it as
;; a line of their text, read off them by the app (Widgets.java).  They are
;; pinned like apps, as entries ("LABEL" "widget" PROVIDER CELLS), ("LABEL"
;; "shortcut" "PACKAGE/ID") and ("LABEL" "hail" ACTION).

(defvar emacs-home-hail-action "FREEZE_AUTO"
  "Hail's API action for its tile: Hail's auto freeze, of the apps not running.")

(defun emacs-home--providers ()
  "Installed widgets as (\"App: Widget\" \"widget\" PROVIDER CELLS)."
  (let ((file (expand-file-name "providers.tsv" emacs-home-dir)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (mapcar (lambda (line)
                  (pcase-let ((`(,label ,provider ,cells) (split-string line "\t")))
                    (list (concat "Widget: " label) "widget" provider
                          (string-to-number (or cells "1")))))
                (split-string (buffer-string) "\n" t))))))

(defun emacs-home--shortcuts ()
  "Apps' shortcuts as (\"App: Shortcut\" \"shortcut\" \"PACKAGE/ID\" ICON-FILE)."
  (let ((file (expand-file-name "shortcuts.tsv" emacs-home-dir)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (mapcar (lambda (line)
                  (pcase-let ((`(,label ,pkg ,id ,icon) (split-string line "\t")))
                    (list label "shortcut" (concat pkg "/" id) icon)))
                (split-string (buffer-string) "\n" t))))))

(defun emacs-home--hail-app (apps)
  (seq-find (lambda (a) (equal (nth 1 a) "com.aistra.hail")) apps))

(defun emacs-home--pinnable (apps)
  "Everything that can be pinned: APPS, the widgets, shortcuts and Hail's freeze."
  (append apps
          (emacs-home--providers)
          (emacs-home--shortcuts)
          (when (emacs-home--hail-app apps)
            (list (list "Hail: freeze apps" "hail" emacs-home-hail-action)))))

(defun emacs-home--widget-png (provider)
  (expand-file-name (format "widgets/%s.png"
                            (replace-regexp-in-string "[^A-Za-z0-9._-]" "_" provider))
                    emacs-home-dir))

(defvar emacs-home-widget-text-drop
  (rx bos (or (seq (or "आइत" "सोम" "मंगल" "बुध" "बिही" "शुक्र" "शनि") "बार")
              (seq (+ (any "A-Za-z0-9 ,.")) (= 4 digit))      ; Oct 26, 2026
              (+ (any "-–·,")))
      eos)
  "A widget's text lines left out of its line: what the status bar already
says (the weekday, the English date) and bare separators.")

(defun emacs-home--widget-text (provider)
  "The text PROVIDER's widget shows, its lines joined, or nil."
  (let ((file (concat (file-name-sans-extension (emacs-home--widget-png provider)) ".txt")))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((lines (seq-remove (lambda (l) (string-match-p emacs-home-widget-text-drop l))
                                 (split-string (buffer-string) "\n" t))))
          ;; A bare day number goes with the month after it: "९ कार्तिक".
          (let (parts)
            (while lines
              (push (if (and (cdr lines) (string-match-p "\\`[0-9०-९]+\\'" (car lines)))
                        (concat (pop lines) " " (pop lines))
                      (pop lines))
                    parts))
            (and parts (string-join (nreverse parts) "  ·  "))))))))

(defun emacs-home--write-widget-sizes (sizes)
  "Tell the app which widgets to draw, at what size: SIZES, (PROVIDER W H)."
  (let ((file (expand-file-name "widgets.tsv" emacs-home-dir))
        (text (mapconcat (lambda (s) (format "%s\t%d\t%d\n" (car s) (nth 1 s) (nth 2 s))) sizes "")))
    ;; Only when it changes: the app redraws on every write.
    (unless (and (file-exists-p file)
                 (equal text (with-temp-buffer (insert-file-contents file) (buffer-string))))
      (with-temp-file file (insert text)))))

(defun emacs-home--icon (app height)
  "APP's icon as a string displaying an image HEIGHT pixels tall.
Hail's freeze shows Hail's own."
  (let* ((app (if (equal (nth 1 app) "hail") (emacs-home--hail-app (emacs-home--apps)) app))
         (png (expand-file-name (if (equal (nth 1 app) "shortcut")
                                    (concat "icons/" (nth 3 app))
                                  (format "icons/%s_%s.png" (nth 1 app) (nth 2 app)))
                                emacs-home-dir)))
    (if (file-exists-p png)
        ;; :scale 1 -- HEIGHT is meant in screen pixels, not before
        ;; `image-scaling-factor'.
        (propertize " " 'display (create-image png 'png nil :height height :scale 1
                                               :ascent 'center))
      " ")))

(defun emacs-home--pins ()
  "Pinned apps' keys, in pinning order."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (expand-file-name "pins.eld" emacs-home-dir))
      (read (current-buffer)))))

(defun emacs-home-open (app)
  "Launch APP, a (LABEL PACKAGE ACTIVITY) entry, and log it to the usage log."
  (usage-log "app" (car app))
  (android-browse-url (format "emacs-home://launch/%s" (emacs-home--key app))))

;;; The clock, for the dashboard line and the app's floating pill

(defvar emacs-home--last-task nil
  "Heading of the last task clocked into, for Resume.")

(defun emacs-home--clean (s)
  (replace-regexp-in-string "[\t\n]" " " (substring-no-properties (or s ""))))

(defun emacs-home--write-clock ()
  "Write clock.tsv, which the app watches: clocked|idle, start, task."
  (when (org-clocking-p)
    (setq emacs-home--last-task (emacs-home--clean org-clock-current-task)))
  (with-temp-file (expand-file-name "clock.tsv" emacs-home-dir)
    (insert (if (org-clocking-p)
                (format "clocked\t%d\t%s\n" (truncate (float-time org-clock-start-time))
                        emacs-home--last-task)
              (format "idle\t0\t%s\n" (or emacs-home--last-task ""))))))

(defun emacs-home--clock-changed ()
  ;; Note the task now, in case it is clocked out before the write runs.
  (when (org-clocking-p)
    (setq emacs-home--last-task (emacs-home--clean org-clock-current-task)))
  ;; Org runs these hooks mid-change; write once it has settled.
  (run-at-time 0 nil #'emacs-home--write-clock))

(defun emacs-home--forget ()
  "Drop the Resume target: the task was cancelled."
  (setq emacs-home--last-task nil))

(defun emacs-home--forget-if-done ()
  "Drop the Resume target once that task is marked done, from anywhere."
  ;; `org-state', not `org-entry-is-done-p': a repeating habit is already
  ;; back to TODO by now.
  (when (and (member org-state org-done-keywords)
             (equal (emacs-home--clean (org-get-heading t t t t)) emacs-home--last-task))
    (emacs-home--forget)
    (emacs-home--clock-changed)))

(with-eval-after-load 'org-clock
  (dolist (hook '(org-clock-in-hook org-clock-out-hook org-clock-cancel-hook))
    (add-hook hook #'emacs-home--clock-changed))
  (add-hook 'org-clock-cancel-hook #'emacs-home--forget)
  (add-hook 'org-after-todo-state-change-hook #'emacs-home--forget-if-done)
  (emacs-home--write-clock))

(defun emacs-home--cancel ()
  "Cancel the clock, through River Flow when it picked this task.
`rts-flow-cancel' acts on River Flow's last pick, which need not be what
is clocked -- after a manual clock-in it would revert the wrong task."
  (interactive)
  (if (and (fboundp 'rts-flow--has-last-task-p) (rts-flow--has-last-task-p)
           (equal (emacs-home--clean rts-flow-last-task-heading)
                  (emacs-home--clean org-clock-current-task)))
      (rts-flow-cancel)
    (org-clock-cancel)))

(defun emacs-home-clock-action (action)
  "Run ACTION from the app's floating clock: pause, resume, done, cancel,
flow, clockin (any task, as the homepage's Clock in)."
  (when-let ((command (pcase action
                        ('pause #'org-clock-out)
                        ('resume #'org-clock-in-last)
                        ('done #'rts-flow-clock-out)
                        ('cancel #'emacs-home--cancel)
                        ('flow #'rts-flow)
                        ('clockin #'rts-flow-manual))))
    ;; Called from emacsclient's process filter, so get out of it first.
    (run-at-time 0 nil #'usage-log-call "island" command))
  nil)

(defun emacs-home--read-app (prompt &optional mark apps)
  "Read an installed app with PROMPT, showing icons.
MARK, if non-nil, is called with each app and returns a suffix string.
APPS, if given, is what to choose from instead of the installed apps."
  (let ((table (make-hash-table :test #'equal))
        (height (* 2 (default-line-height))))
    (dolist (app (or apps (emacs-home--apps)))
      ;; Two launcher entries can share a label; tell them apart.
      (puthash (if (gethash (car app) table)
                   (format "%s (%s)" (car app) (nth 1 app))
                 (car app))
               app table))
    (gethash
     (completing-read
      prompt
      (lambda (str pred action)
        (if (eq action 'metadata)
            `(metadata
              (category . emacs-home-app)
              (affixation-function
               . ,(lambda (cands)
                    (mapcar (lambda (c)
                              (let ((app (gethash c table)))
                                (list c (concat (emacs-home--icon app height) " ")
                                      (if mark (funcall mark app) ""))))
                            cands))))
          (complete-with-action action (hash-table-keys table) str pred)))
      nil t)
     table)))

(defun emacs-home--run (entry source)
  "Launch ENTRY -- an app, a shortcut or Hail's freeze -- logged as from SOURCE."
  (pcase (nth 1 entry)
    ("hail"
     (usage-log source "hail-freeze")
     (android-browse-url (format "emacs-home://hail/%s" (nth 2 entry))))
    ("shortcut"
     (usage-log source (nth 2 entry))
     ;; The id may hold a / itself; the package can't.
     (string-match "\\`\\([^/]+\\)/" (nth 2 entry))
     (android-browse-url (format "emacs-home://shortcut/%s/%s"
                                 (match-string 1 (nth 2 entry))
                                 (url-hexify-string (substring (nth 2 entry) (match-end 0))))))
    (_ (emacs-home-open entry))))

(defun emacs-home-launch ()
  "Pick an installed app, or a pinned shortcut or Hail's freeze, and launch it."
  (interactive)
  (let* ((apps (emacs-home--apps))
         (pins (emacs-home--pins))
         (pinned (seq-filter (lambda (e) (and (member (nth 1 e) '("shortcut" "hail"))
                                              (member (emacs-home--key e) pins)))
                             (emacs-home--pinnable apps))))
    (emacs-home--run (emacs-home--read-app "App: " nil (append pinned apps)) "app")))

(defun emacs-home-toggle-pin ()
  "Pin an app to the homepage, or unpin it if it is pinned."
  (interactive)
  (let* ((pins (emacs-home--pins))
         (key (emacs-home--key
               (emacs-home--read-app
                "Pin/unpin: "
                (lambda (app)
                  (if (member (emacs-home--key app) pins) "  ★ pinned" ""))
                (emacs-home--pinnable (emacs-home--apps))))))
    (with-temp-file (expand-file-name "pins.eld" emacs-home-dir)
      (prin1 (if (member key pins) (delete key pins) (append pins (list key)))
             (current-buffer)))
    (+dashboard-reload t)))

(defvar emacs-home--days-closed nil
  "The day past days were last closed for: they close once a day.")

(defun emacs-home--close-past-days ()
  "On the first Home press of a day (turning at 4am), close past reviews.
Loads the day log then, a moment after, rather than at startup."
  (let ((day (format-time-string "%F" (time-subtract nil (* 4 3600)))))
    (unless (equal day emacs-home--days-closed)
      (setq emacs-home--days-closed day)
      (run-with-idle-timer 2 nil (lambda ()
                                   (with-demoted-errors "day-log: %S"
                                     (day-log-close-pending)))))))

(defun emacs-home-on-home ()
  "Called by the app on every Home press: back to whatever was open.
Only a minibuffer is closed; the toolbar's Home button is the homepage."
  (usage-log "home" "home")
  (emacs-home--close-past-days)
  (when (+dashboard-buffer-p (window-buffer (selected-window)))
    ;; Called from emacsclient's process filter, so get out of it first.
    (run-at-time 0 nil #'+dashboard-reload t))  ; fresh clock line
  (when (active-minibuffer-window)
    (run-at-time 0 nil #'abort-recursive-edit))
  nil)

(defvar emacs-home--started nil
  "The day (turning at 4am) something was first clocked into.")

(defun emacs-home--today ()
  (format-time-string "%F" (time-subtract nil (* 4 3600))))

(add-hook 'org-clock-in-hook (lambda () (setq emacs-home--started (emacs-home--today))))

(defun emacs-home--first-thing ()
  "Last night's first thing for today, until something is clocked today."
  (and (not (equal emacs-home--started (emacs-home--today)))
       (featurep 'day-log)              ; loaded by the first Home press
       (ignore-errors (day-log-first-thing))))

(defun emacs-home-start-first-thing ()
  "Clock in on last night's first thing: the Clock in picker with it typed
in -- pick the task it matches, or RET to make it one."
  (interactive)
  (let ((text (or (emacs-home--first-thing) "")))
    (minibuffer-with-setup-hook (lambda () (insert text))
      (rts-flow-manual))))

(defun emacs-home--cell (entry size)
  "ENTRY's tile, (ICON ACTION LABEL SPAN), SIZE pixels tall."
  (pcase (nth 1 entry)
    ("hail" (list (emacs-home--icon entry size)
                  (lambda (_) (emacs-home--run entry "dashboard"))
                  "Freeze apps (Hail)" 1))
    (_ (list (emacs-home--icon entry size)
             (lambda (_) (emacs-home--run entry "dashboard"))
             (car entry) 1))))

(defun emacs-home--rows (cells per-row)
  "CELLS, (ICON ACTION LABEL SPAN), in rows of PER-ROW slots."
  (let (rows row (used 0))
    (dolist (c cells)
      (let ((span (min per-row (or (nth 3 c) 1))))
        (when (> (+ used span) per-row)
          (push (nreverse row) rows)
          (setq row nil used 0))
        (push c row)
        (cl-incf used span)))
    (when row (push (nreverse row) rows))
    (nreverse rows)))

(defun emacs-home-widget ()
  "Dashboard widget: the clock line, Pin and Day, then the pinned icons,
`emacs-home-icons-per-row' to a row, big.  All apps is on the toolbar."
  (let* ((apps (emacs-home--apps))
         (by-key (mapcar (lambda (app) (cons (emacs-home--key app) app))
                         (emacs-home--pinnable apps)))
         (pinned (delq nil (mapcar (lambda (key) (cdr (assoc key by-key)))
                                   (emacs-home--pins))))
         (margin (frame-char-width))
         (cell (/ (- (window-body-width nil t) (* 2 margin)) emacs-home-icons-per-row))
         (size (round (* cell emacs-home-icon-fill)))
         (gap (propertize " " 'display `(space :width (,(- cell size)))))
         (widgets (seq-filter (lambda (e) (equal (nth 1 e) "widget")) pinned))
         (cells (mapcar (lambda (app) (emacs-home--cell app size))
                        (seq-difference pinned widgets))))
    (insert "\n  ")
    ;; First button, so the dashboard parks point -- and the line highlight
    ;; and box cursor that come with it -- on this text, not the icons.
    (if (and (fboundp 'org-clocking-p) (org-clocking-p))
        (insert-text-button
         (format "⏱  %s  ·  %s" (emacs-home--clean org-clock-current-task)
                 (org-duration-from-minutes (org-clock-get-clocked-time)))
         'action (lambda (_) (usage-log-call "dashboard" #'org-clock-goto))
         'follow-link t
         'face 'android-homepage-title)
      (when-let* ((first (emacs-home--first-thing)))
        ;; The morning: what last night's review said to start with.
        (insert-text-button
         (format "☀  First: %s" first)
         'action (lambda (_) (usage-log-call "dashboard" #'emacs-home-start-first-thing))
         'follow-link t
         'face 'android-homepage-title)
        (insert "\n  "))
      (insert-text-button
       (if emacs-home--last-task
           (format "○  No clock  ·  resume: %s" emacs-home--last-task)
         "○  No clock  ·  Flow")
       'action (lambda (_) (usage-log-call
                            "dashboard"
                            (if emacs-home--last-task #'org-clock-in-last #'rts-flow)))
       'follow-link t
       'face 'android-homepage-desc))
    (insert "\n  ")
    (insert-text-button "Pin / unpin"
                        'action (lambda (_) (usage-log-call "dashboard" #'emacs-home-toggle-pin))
                        'follow-link t
                        'face 'android-homepage-title)
    (insert "    ")
    (insert-text-button "Day"
                        'action (lambda (_) (usage-log-call "dashboard" #'day-log-today))
                        'follow-link t
                        'face 'android-homepage-title)
    (insert "\n")
    ;; Drawn only to be read; the app lays each out at least at its
    ;; provider's minimum size, which keeps all its text.
    (emacs-home--write-widget-sizes
     (mapcar (lambda (e) (list (nth 2 e) (* (nth 3 e) cell) cell)) widgets))
    (dolist (row (emacs-home--rows cells emacs-home-icons-per-row))
      (insert (propertize " " 'display `(space :width (,margin))))
      (pcase-dolist (`(,icon ,action ,label) row)
        ;; Not the `button' face: its underline sits on the baseline, which
        ;; `:ascent center' puts straight through the middle of the icon.
        (insert-text-button icon
                            'face 'default
                            'action action
                            'follow-link t
                            'help-echo label)
        (insert gap))
      ;; A little air between rows too, so a tap lands on one icon.
      (insert (propertize "\n" 'line-spacing (/ (- cell size) 2))))
    ;; Pinned widgets, as their text read off their views: a line each
    ;; (Simple Patro's date, as Simple Patro writes it).  Tap: their app.
    (dolist (entry widgets)
      (when-let* ((text (emacs-home--widget-text (nth 2 entry))))
        (insert "  ")
        (insert-text-button text
                            'action (let ((app (seq-find (lambda (a) (equal (nth 1 a) (car (split-string (nth 2 entry) "/"))))
                                                         apps)))
                                      (lambda (_) (when app (emacs-home-open app))))
                            'follow-link t
                            'face 'android-homepage-title)
        (insert "\n")))))

(add-to-list '+dashboard-functions #'emacs-home-widget)

(provide 'emacs-home)
;;; emacs-home.el ends here
