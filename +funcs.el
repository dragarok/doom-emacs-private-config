;;; ~/.doom.d/+funcs.el -*- lexical-binding: t; -*-
(defun browse-pdf ()
  (interactive)
  (dired "~/Dropbox/pdfs/"))

(defun browse-current-file ()
  "Open the current file as a URL using `browse-url'."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if (and (fboundp 'tramp-tramp-file-p)
             (tramp-tramp-file-p file-name))
        (error "Cannot open tramp file")
      (browse-url (concat "file://" file-name)))))

(defun gettoday ()
  (interactive)               
  (insert (format-time-string "%A, %B %e, %Y")))

(defun getnow ()
  (interactive)                
  (insert (format-time-string "%D %-I:%M %p")))

(defun bh/make-org-scratch ()
  (interactive)
  (find-file "/tmp/publish/scratch.org")
  (gnus-make-directory "/tmp/publish"))

(defun bh/switch-to-scratch ()
  (interactive)
  (switch-to-buffer "*scratch*"))

(defun yank-to-end-of-line ()
  "Yank to end of line."
  (interactive)
  (evil-yank (point) (point-at-eol)))

(defun smart-open-line ()
  "Insert an empty line after the current line.
Position the cursor at its beginning, according to the current mode."
  (interactive)
  (move-end-of-line 't)
  (newline-and-indent))

(defun indent-buffer()
  (interactive)
  (indent-region (point-min) (point-max)))

(defun indent-region-or-buffer()
  (interactive)
  (save-excursion
    (if (region-active-p)
        (progn
          (indent-region (region-beginning) (region-end))
          (message "Indent selected region."))
      (progn
        (indent-buffer)
        (message "Indent buffer.")))))

(defun dired-get-size ()
  (interactive)
  (let ((files (dired-get-marked-files)))
    (with-temp-buffer
      (apply 'call-process "/usr/bin/du" nil t nil "-sch" files)
      (message
       "Size of all marked files: %s"
       (progn
         (re-search-backward "\\(^[ 0-9.,]+[A-Za-z]+\\).*total$")
         (match-string 1))))))

(defun dired-start-process (cmd &optional file-list)
  (interactive
   (let ((files (dired-get-marked-files
                 t current-prefix-arg)))
     (list
      (dired-read-shell-command "& on %s: "
                                current-prefix-arg files)
      files)))
  (let (list-switch)
    (start-process
     cmd nil shell-file-name
     shell-command-switch
     (format
      "nohup 1>/dev/null 2>/dev/null %s \"%s\""
      (if (and (> (length file-list) 1)
               (setq list-switch
                     (cadr (assoc cmd dired-filelist-cmd))))
          (format "%s %s" cmd list-switch)
        cmd)
      (mapconcat #'expand-file-name file-list "\" \"")))))

(defun dired-open-term ()
  "Open an `ansi-term' that corresponds to current directory."
  (interactive)
  (let* ((current-dir (dired-current-directory))
         (buffer (if (get-buffer "*zshell*")
                     (switch-to-buffer "*zshell*")
                   (ansi-term "/usr/bin/zsh" "zshell")))
         (proc (get-buffer-process buffer)))
    (term-send-string
     proc
     (if (file-remote-p current-dir)
         (let ((v (tramp-dissect-file-name current-dir t)))
           (format "ssh %s@%s\n"
                   (aref v 1) (aref v 2)))
       (format "cd '%s'\n" current-dir)))))

(defun dired-copy-file-here (file)
  (interactive "fCopy file: ")
  (copy-file file default-directory))

(defun my-dired-find-file ()
  "Open buffer in another window"
  (interactive)
  (let ((filename (dired-get-filename nil t)))
    (if (car (file-attributes filename))
        (dired-find-alternate-file)
      (dired-find-file-other-window))))

(defun dired-do-command (command)
  "Run COMMAND on marked files. Any files not already open will be opened.
After this command has been run, any buffers it's modified will remain
open and unsaved."
  (interactive "CRun on marked files M-x ")
  (save-window-excursion
    (mapc (lambda (filename)
            (find-file filename)
            (call-interactively command))
          (dired-get-marked-files))))


(defun dired-up-directory()
  "goto up directory and resue buffer"
  (interactive)
  (find-alternate-file ".."))

(defun insert-space-after-point ()
  (interactive)
  (save-excursion (insert " ")))

(defun vsplit-last-buffer ()
  (interactive)
  (split-window-vertically)
  (other-window 1 nil)
  (switch-to-next-buffer))

(defun hsplit-last-buffer ()
  (interactive)
  (split-window-horizontally)
  (other-window 1 nil)
  (switch-to-next-buffer))

;;;###autoload
(defun +python/annotate-pdb ()
  "Highlight break point lines."
  (interactive)
  (highlight-lines-matching-regexp "breakpoint()" 'breakpoint-enabled)
  (highlight-lines-matching-regexp "import \\(pdb\\|ipdb\\|pudb\\|wdb\\)" 'breakpoint-enabled)
  (highlight-lines-matching-regexp "\\(pdb\\|ipdb\\|pudb\\|wdb\\).set_trace()" 'breakpoint-enabled)
  (highlight-lines-matching-regexp "trepan.api.debug()") 'breakpoint-enabled)

;;;###autoload
(defun +python/toggle-breakpoint ()
  "Add a break point, highlight it."
  (interactive)
  (let ((trace (cond ((executable-find "trepan3k") "import trepan.api; trepan.api.debug()")
                     ((executable-find "wdb") "import wdb; wdb.set_trace()")
                     ((executable-find "ipdb") "import ipdb; ipdb.set_trace()")
                     ((executable-find "pudb") "import pudb; pudb.set_trace()")
                     ((executable-find "ipdb3") "import ipdb; ipdb.set_trace()")
                     ((executable-find "pudb3") "import pudb; pudb.set_trace()")
                     ((executable-find "python3.7") "breakpoint()")
                     ((executable-find "python3.8") "breakpoint()")
                     (t "import pdb; pdb.set_trace()")))
        (line (thing-at-point 'line)))
    (if (and line (string-match trace line))
        (kill-whole-line)
      (progn
        (back-to-indentation)
        (insert trace)
        (insert "\n")
        (python-indent-line))))
  (+python/annotate-pdb))

;;;###autoload
(defun +python/autoflake-remove-imports ()
  "Remove unused imports."
  (interactive)
  (shell-command
   (concat "autoflake --in-place --remove-all-unused-imports " (buffer-file-name)))
  (revert-buffer-no-confirm))

(defun my-org-agenda-skip-all-siblings-but-first ()
  "Skip all but the first non-done entry."
  (let (should-skip-entry)
    (unless (org-current-is-todo)
      (setq should-skip-entry t))
    (save-excursion
      (while (and (not should-skip-entry) (org-goto-sibling t))
        (when (org-current-is-todo)
          (setq should-skip-entry t))))
    (when should-skip-entry
      (or (outline-next-heading)
          (goto-char (point-max))))))

;; gtd specific to show only the first actionable item
(defun org-current-is-todo ()
  (string= "TODO" (org-get-todo-state)))

(defun org-gtd/find-project-task ()
  "Move point to the parent (project) task if any"
  (interactive)
  (save-restriction
    (widen)
    (let ((parent-task (save-excursion (org-back-to-heading 'invisible-ok) (point))))
      (while (org-up-heading-safe)
        (when (string-match-p "project" (org-get-tags-string))
          (setq parent-task (point))))
      (goto-char parent-task)
      parent-task)))

(defun org-gtd/is-project-subtree-p ()
  "Any task that is a project subtree"
  (let ((task (save-excursion (org-back-to-heading 'invisible-ok)
                              (point))))
    (save-excursion
      (org-gtd/find-project-task)
      (if (equal (point) task)
          nil
        t))))

(defun org-gtd/skip-project-tasks ()
  "Skip tasks belonging to projects"
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((org-gtd/is-project-subtree-p)
        subtree-end)
       (t
        nil)))))

(defun org-gtd/remove-started-tag-when-done ()
  "Remove started tag from task when marked as DONE"
  (interactive)
  (when (org-entry-is-done-p)
    (save-excursion
      (org-back-to-heading)
      (org-set-tags-to (if (string= (org-get-tags-string) ":started:")
                           ""
                         (mapconcat 'identity
                                    (delete "started" (split-string (org-get-tags-string) ":")) ":"))))))

(defun org-gtd/archive-all-done-entries ()
  "Archive all entries marked DONE"
  (interactive)
  (save-excursion
    (goto-char (point-max))
    (while (outline-previous-heading)
      (when (org-entry-is-done-p)
        (org-archive-subtree)))))

(defun bjm/save-buffer-no-args ()
  "Save buffer ignoring arguments"
  (save-buffer))

(defun create-non-existent-directory ()
  "Check whether a given file's parent directories exist; if they do not, offer to create them."
  (let ((parent-directory (file-name-directory buffer-file-name)))
    (when (and (not (file-exists-p parent-directory))
               (y-or-n-p (format "Directory `%s' does not exist! Create it?" parent-directory)))
      (make-directory parent-directory t))))
(add-to-list 'find-file-not-found-functions #'create-non-existent-directory)


(defun repeat-macro-until-abort ()
  (interactive)
  (while t
    (ignore-errors
      (kmacro-call-macro 0))))




;;; anki functions
(defun anki-editor-cloze-region-auto-incr (&optional arg)
  "Cloze region without hint and increase card number."
  (interactive)
  (anki-editor-cloze-region my-anki-editor-cloze-number "")
  (setq my-anki-editor-cloze-number (1+ my-anki-editor-cloze-number))
  (forward-sexp))
(defun anki-editor-cloze-region-dont-incr (&optional arg)
  "Cloze region without hint using the previous card number."
  (interactive)
  (anki-editor-cloze-region (1- my-anki-editor-cloze-number) "")
  (forward-sexp))
(defun anki-editor-reset-cloze-number (&optional arg)
  "Reset cloze number to ARG or 1"
  (interactive)
  (setq my-anki-editor-cloze-number (or arg 1)))
(defun anki-editor-push-tree ()
  "Push all notes under a tree."
  (interactive)
  (anki-editor-push-notes '(4))
  (anki-editor-reset-cloze-number))
