;;; usage-log.el --- Which of my workflow commands I actually use -*- lexical-binding: t -*-

;;; Commentary:
;; Kept deliberately light -- it loads at startup on the phone, and nothing
;; here may slow that or load org:
;;   - River Flow and the other daily-workflow commands
;;     (`usage-log-commands-regexp'), however they were started
;;   - whatever is pressed on the toolbar
;;   - buttons that run through `usage-log-call': the homepage grid, the
;;     dashboard, Termux widgets, the clock's island
;;   - the review keys, SPC o v, and the capture templates picked
;;
;; One file per machine, like the notes logs, so Syncthing brings the
;; phone's log to the Mac without conflicts:
;;   org-logs-directory/usage_log_HOST.tsv   TIME TAB SOURCE TAB COMMAND
;;
;; `usage-log-report' counts the last week (C-u: ask how many days) across
;; every machine, and lists the watched commands never used.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar usage-log-file
  (expand-file-name (format "usage_log_%s.tsv" (system-name)) org-logs-directory)
  "This machine's usage log.")

(defvar usage-log-commands-regexp
  "\\`\\(rts-flow\\|micro-experiments\\|day-log\\|emacs-home\\|org-summary-\\|org-flow-\\|agent-time-\\)"
  "Commands logged however they were started.")

(defvar usage-log-leader-regexp "\\`\\(M-\\)?SPC o v "
  "Leader keys logged as typed, whatever they run -- some are lambdas.")

(defun usage-log (source command)
  "Append COMMAND, pressed from SOURCE, to `usage-log-file'."
  (with-demoted-errors "usage-log: %S"
    (write-region (format "%s\t%s\t%s\n" (format-time-string "%F %T") source command)
                  nil usage-log-file t 'silent)))

(defun usage-log-call (source command)
  "Run COMMAND interactively, logged as pressed from SOURCE."
  (usage-log source command)
  (call-interactively command))

(defun usage-log--post-command ()
  "Log toolbar presses, the review keys (`usage-log-leader-regexp'), and
the watched commands run from a key or M-x."
  (when this-command
    (let* ((keys (this-command-keys-vector))
           (name (and (symbolp this-command) (symbol-name this-command))))
      (cond ((and name (> (length keys) 0) (eq (aref keys 0) 'tool-bar))
             (usage-log "toolbar" this-command))
            ((and (> (length keys) 3)
                  (string-match-p usage-log-leader-regexp (key-description keys)))
             (usage-log "leader" (or name (key-description keys))))
            ((and name (string-match-p usage-log-commands-regexp name))
             ;; M-x leaves the keys reading "M-x NAME RET".
             (usage-log (if (and (> (length keys) 0) (eql (aref keys 0) ?\M-x)) "M-x" "key")
                        this-command))))))

(defun usage-log--capture (entry)
  "After `org-capture-select-template': log the template picked, by key."
  (when (and (consp entry) (stringp (car entry)))
    (usage-log "capture" (format "capture %s %s" (car entry) (or (nth 1 entry) ""))))
  entry)

;; Advising a function not loaded yet is fine, and loads nothing.
(advice-add 'org-capture-select-template :filter-return #'usage-log--capture)

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
  (require 'org)
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
        (let* ((watched (apropos-internal usage-log-commands-regexp #'commandp))
               (unused (seq-remove (lambda (c) (gethash (symbol-name c) used)) watched)))
          (insert (format "\n* Never used (%d of the %d watched commands)\n"
                          (length unused) (length watched)))
          (dolist (c unused) (insert (format "- %s\n" c))))
        (org-mode)
        (goto-char (point-min))
        (while (re-search-forward "^|" nil t)
          (org-table-align)
          (goto-char (org-table-end)))
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))))

(provide 'usage-log)
;;; usage-log.el ends here
