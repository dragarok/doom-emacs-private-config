;;; usage-log.el --- Which of my commands I actually use -*- lexical-binding: t -*-

;;; Commentary:
;; Logs every run of the commands this config defines (lisp/*.el,
;; config.el), however they were started: a dashboard or homepage button,
;; the toolbar, a Termux widget, the clock's island, M-x, the leader key or
;; any other key.  Anything else started from the toolbar, M-x or the
;; leader is logged too -- those are choices, unlike typing and moving.
;;
;; One file per machine, like the notes logs, so Syncthing brings the
;; phone's log to the Mac without conflicts:
;;   org-logs-directory/usage_log_HOST.tsv   TIME TAB SOURCE TAB COMMAND
;;
;; `usage-log-report' counts the last week (C-u: ask how many days) across
;; every machine, and lists the commands of this config never used.

;;; Code:

(require 'cl-lib)
(require 'org-table)
(require 'seq)
(require 'subr-x)

(defvar usage-log-file
  (expand-file-name (format "usage_log_%s.tsv" (system-name)) org-logs-directory)
  "This machine's usage log.")

(defvar usage-log-source nil
  "Where the command now starting was pressed, when the caller knows.
Buttons bind it around `call-interactively'; see `usage-log-call'.")

(defvar usage-log--own (make-hash-table :test #'eq)
  "Commands this config defines, which are advised to log themselves.")

(defvar usage-log--running nil
  "Non-nil inside a logged command, so the commands it calls aren't logged too.")

(defun usage-log (source command)
  "Append COMMAND, pressed from SOURCE, to `usage-log-file'."
  (with-demoted-errors "usage-log: %S"
    (write-region (format "%s\t%s\t%s\n" (format-time-string "%F %T") source command)
                  nil usage-log-file t 'silent)))

(defun usage-log--source ()
  "Where the current command came from, as best the keys tell."
  (let ((keys (this-command-keys-vector)))
    (cond (usage-log-source)
          ;; M-x rewrites `real-this-command' to the command it ran, but
          ;; leaves the keys reading "M-x NAME RET".
          ((and (> (length keys) 0) (eql (aref keys 0) ?\M-x)) "M-x")
          ((and (> (length keys) 0) (eq (aref keys 0) 'tool-bar)) "toolbar")
          ((and (> (length keys) 1) (memql (aref keys 0) '(?\s ?\M-\s))) "leader")
          ((memq real-this-command '(push-button widget-button-click)) "button")
          (t "key"))))

(defun usage-log-call (source command)
  "Run COMMAND interactively, logged as pressed from SOURCE."
  (unless (gethash command usage-log--own)
    (usage-log source command))
  (let ((usage-log-source source))
    (call-interactively command)))

;;; This config's commands log themselves

(defun usage-log--wrap (command)
  "Advise COMMAND to log each run."
  (unless (gethash command usage-log--own)
    (puthash command t usage-log--own)
    (advice-add command :around
                (lambda (fn &rest args)
                  (if (or usage-log--running (not (usage-log--chosen-p command)))
                      (apply fn args)
                    (usage-log (usage-log--source) command)
                    (let ((usage-log--running t))
                      (apply fn args))))
                '((name . usage-log)))))

(defun usage-log--chosen-p (command)
  "Non-nil if you started COMMAND, rather than a timer or a hook calling it."
  (or usage-log-source
      (eq this-command command)
      (memq real-this-command '(push-button widget-button-click))))

(defvar usage-log--user-dir (file-truename doom-user-dir))

(defun usage-log--own-file-p (file)
  (and file (string-prefix-p usage-log--user-dir (file-truename file))))

(defun usage-log--file-commands (entry)
  "The commands a `load-history' ENTRY, (FILE . DEFINITIONS), defined."
  (let (commands)
    (dolist (d (cdr entry) commands)
      (when (and (eq (car-safe d) 'defun)
                 (commandp (cdr d))
                 (not (string-prefix-p "usage-log" (symbol-name (cdr d)))))
        (push (cdr d) commands)))))

;; From `load-history', one pass over what each of this config's files
;; defined -- not `mapatoms' and `symbol-file', which walk all of
;; load-history for every symbol: run for each module as it loaded, with
;; Doom holding off garbage collection through startup, that ran the phone
;; out of memory before Emacs could start.
(defun usage-log--own-commands ()
  "Commands defined by this config's loaded files."
  (mapcan (lambda (entry)
            (and (stringp (car entry)) (usage-log--own-file-p (car entry))
                 (usage-log--file-commands entry)))
          load-history))

(defun usage-log-install ()
  "Advise every command this config defines so far."
  (mapc #'usage-log--wrap (usage-log--own-commands)))

(defun usage-log--after-load (file)
  ;; Modules loaded after startup -- deferred packages' config, M-x
  ;; load-file: only what that file defined.
  (when (and after-init-time (usage-log--own-file-p file))
    (mapc #'usage-log--wrap (usage-log--file-commands (assoc file load-history)))))

(defun usage-log--post-command ()
  "Log other commands, when they were picked from the toolbar, M-x or leader."
  (when (and this-command (symbolp this-command)
             (not (gethash this-command usage-log--own)))
    (let ((source (usage-log--source)))
      (when (member source '("M-x" "toolbar" "leader"))
        (usage-log source this-command)))))

;; Once Emacs is up and idle, not while it starts.
(add-hook 'emacs-startup-hook (lambda () (run-with-idle-timer 3 nil #'usage-log-install)))
(add-hook 'after-load-functions #'usage-log--after-load)
(add-hook 'post-command-hook #'usage-log--post-command)

;;; Report

(defun usage-log-entries (from &optional to)
  "Entries dated FROM to TO (YYYY-MM-DD, inclusive; TO defaults to FROM's
day onwards) from every machine, as (TIME HOST SOURCE COMMAND), oldest first."
  (let (entries)
    (dolist (file (directory-files org-logs-directory t "\\`usage_log_.*\\.tsv\\'"))
      ;; usage_log_Aloks-MacBook-Pro.local.tsv -> Aloks-MacBook-Pro
      (let ((host (car (split-string (string-remove-prefix
                                      "usage_log_" (file-name-base file))
                                     "\\."))))
        (with-temp-buffer
          (insert-file-contents file)
          (dolist (line (split-string (buffer-string) "\n" t))
            (pcase (split-string line "\t")
              (`(,time ,source ,command)
               (unless (or (string< time from)
                           (and to (string< (concat to "\xff") time)))
                 (push (list time host source command) entries))))))))
    (sort entries (lambda (a b) (string< (car a) (car b))))))

(defun usage-log--count (entries key)
  "Count ENTRIES by KEY, a function of an entry; most frequent first."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (e entries)
      (cl-incf (gethash (funcall key e) table 0)))
    (sort (mapcar (lambda (k) (cons k (gethash k table))) (hash-table-keys table))
          (lambda (a b) (> (cdr a) (cdr b))))))

(defun usage-log-report (&optional days)
  "Show which commands were used in the last DAYS days (7; C-u asks)."
  (interactive (list (if current-prefix-arg (read-number "Days: " 30) 7)))
  (let* ((days (or days 7))
         (entries (usage-log-entries
                   (format-time-string "%F" (time-subtract nil (days-to-time (1- days))))))
         (used (make-hash-table :test #'equal)))
    (dolist (e entries) (puthash (nth 3 e) t used))
    (with-current-buffer (get-buffer-create "*Usage*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "#+TITLE: Usage, last %d days (%d runs)\n\n" days (length entries)))
        (insert "* By command\n| Runs | Command | From | Last |\n|-\n")
        (dolist (c (usage-log--count entries (lambda (e) (nth 3 e))))
          (let ((mine (seq-filter (lambda (e) (equal (nth 3 e) (car c))) entries)))
            (insert (format "| %d | %s | %s | %s |\n" (cdr c) (car c)
                            (mapconcat (lambda (s) (format "%s %d" (car s) (cdr s)))
                                       (usage-log--count
                                        mine (lambda (e) (format "%s/%s" (nth 1 e) (nth 2 e))))
                                       ", ")
                            (substring (car (sort (mapcar #'car mine) #'string>)) 0 16)))))
        (insert "\n* By source\n| Runs | Machine/source |\n|-\n")
        (dolist (s (usage-log--count entries (lambda (e) (format "%s/%s" (nth 1 e) (nth 2 e)))))
          (insert (format "| %d | %s |\n" (cdr s) (car s))))
        (let ((unused (seq-remove (lambda (c) (gethash (symbol-name c) used))
                                  (usage-log--own-commands))))
          (insert (format "\n* Never used (%d of this config's %d commands on %s)\n"
                          (length unused) (length (usage-log--own-commands)) (system-name)))
          (insert "| Command | File |\n|-\n")
          (dolist (c (sort unused (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
            (insert (format "| %s | %s |\n" c
                            (file-name-nondirectory (or (symbol-file c 'defun) ""))))))
        (org-mode)
        (goto-char (point-min))
        (while (re-search-forward "^|" nil t)
          (org-table-align)
          (goto-char (org-table-end)))
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))))

(provide 'usage-log)
;;; usage-log.el ends here
