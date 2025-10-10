;;; termux_config.el -*- lexical-binding: t; -*-

;; User details
(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

;; Font settings
(setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 26)
      doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :size 25)
      doom-variable-pitch-font (font-spec :family "SpaceMono Nerd Font" :size 36)
      doom-serif-font (font-spec :family "BlexMono Nerd Font" :size 36 :weight 'light))

;; Android ease of use
(setq +zen-mixed-pitch-modes nil)
(setq touch-screen-precision-scroll t)
(setq doom-theme 'doom-acario-light)
(setq overriding-text-conversion-style nil)
(setq tool-bar-position 'bottom
      tool-bar-mode t
      modifier-bar-mode t)

(setq nextcloud-dir (expand-file-name "/sdcard/"))
(setq project-resources-dir (concat nextcloud-dir "workspace/"))
(setq org-directory (expand-file-name "/sdcard/org/"))

;; LOAD UP ORG MODE AT THE BEGINNING
(require 'org)

;; ONLY ON ANDROID DEVICES FOR ORG MODE
(setq org-startup-folded 'showeverything)
(setq display-line-numbers-type t)
(setq browse-url-browser-function 'browse-url-xdg-open)
(add-to-list 'org-file-apps '("\\.pdf\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.png\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.jpg\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.jpeg\\'" . "termux-open %s"))

(setq org-catch-invisible-edits 'show-and-error)
(setq org-cycle-separator-lines -1)
(setq org-return-follows-link t)



(setq! citar-bibliography '("/sdcard/org/references/articles.bib"))
(setq! citar-notes-paths '(org-roam-directory))
(setq! citar-library-paths '("/sdcard/Books/Papers/articles/"))

(setq project-resources-dir (concat nextcloud-dir "workspace/"))
(setq org-roam-directory "/sdcard/org/notes/")
(setq org-logs-directory (concat org-directory "logs/"))
(setq org-agenda-directory (concat org-directory "agenda/"))
(setq org-templates-directory (concat org-directory "templates/"))
(setq org-lookbacks-directory (concat org-directory "lookbacks/"))
(setq org-agenda-files '("/sdcard/org/agenda/"))
(setq org-inbox-file (concat org-agenda-directory "inbox.org"))
(setq org-recurring-file (concat org-agenda-directory "recurring.org"))
(setq org-bookslog-file (concat org-agenda-directory "log_books.org"))
(setq org-books-file org-bookslog-file)
(setq org-projects-file (concat org-agenda-directory "projects.org"))
(setq org-tasks-file (concat org-agenda-directory "tasks.org"))
(setq org-diary-file (concat org-directory "lookbacks/diary.org"))
(setq org-motto-file (concat org-agenda-directory "motto.org"))
(setq org-someday-file (concat org-directory "archive/someday.org"))
(setq org-dailyreview-file (concat org-lookbacks-directory "dailyreview.org"))
(setq org-monthlyreview-file (concat org-lookbacks-directory "monthlyreview.org"))
(setq org-weeklyreview-file (concat org-lookbacks-directory "weeklyreview.org"))
(setq org-quarterlyreview-file (concat org-lookbacks-directory "quarterlyreview.org"))
(setq org-yearlyreview-file (concat org-lookbacks-directory "yearlyreview.org"))
(setq org-roam-logs-file (concat org-logs-directory "notes_log.txt"))

(setq org-refile-targets
      '((org-someday-file :maxlevel . 1)
        (org-agenda-files :maxlevel . 3)))

(setq doom-localleader-key ",")

(setq calendar-week-start-day 1) ; 0:Sunday, 1:Monday

(after! popup
  (set-popup-rule! "^\\*Python*" :side 'bottom :height 0.3 :quit nil)
  (set-popup-rule! "*WordNut*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "*Org QL View:*" :side 'right :size 0.3 :select t :quit nil)
  )

(after! org
  (setq org-highlight-latex-and-related '(native script entities)))

;;;###autoload
(defun consult-recent-file ()
  "Find recent using `completing-read'."
  (interactive)
  (find-file
   (consult--read
    (or (message (mapcar #'abbreviate-file-name recentf-list))
        (user-error "No recent files, `recentf-mode' is %s"
                    (if recentf-mode "on" "off")))
    :prompt "Find recent file: "
    :sort nil
    :require-match t
    :category 'file
    :state (consult--file-preview)
    :history 'file-name-history)))


;; Time related functions from holtzermann17
;;;###autoload
(defun now ()
  "Insert string for the current time formatted like '2:34 PM'."
  (interactive)
  (insert (format-time-string "[%D %-I:%M %p]")))
;; 04/29/21 3:08 pm

;;;###autoload
(defun today ()
  "Insert string for today's date nicely formatted in American style,
e.g. Sunday, September 17, 2000."
  (interactive)
  (insert (format-time-string "[%Y-%m-%d %a]")))
;; Thu, April 29, 2021
;; Thursday, April 29, 2021
;; <2021-04-29 Thu, April 29>

;;;###autoload
(defun date ()
  (interactive)
  (insert (date-string)))

;;;###autoload
(defun date-string ()
  (interactive)
  (format-time-string  "[%Y-%m-%d %a %-H:%M]" nil t))

;;;###autoload
(defun now-string ()
  (interactive)
  (format-time-string  "[%Y-%m-%d %-H:%M|Z]" nil t))

;; Org roam autoread and break down large notes
(setq org-roam-autoread-max-words 500)
(setq org-roam-autoread-enabled t)

(defun org-roam-autoread-mode-check ()
  (if (and org-roam-autoread-enabled
           (eq major-mode 'org-mode)
           (string-prefix-p org-roam-directory buffer-file-name)
           (< org-roam-autoread-max-words (buffer-count-words))
           (not (or (string-prefix-p "ln_" (file-name-nondirectory buffer-file-name))
                    (string-prefix-p "br_" (file-name-nondirectory buffer-file-name))
                    (string-prefix-p "private_" (file-name-nondirectory buffer-file-name)))))
      (read-only-mode)))

(add-hook 'after-save-hook #'org-roam-autoread-mode-check)

(defun count-words-in-file (file)
  "Count the number of words in FILE using the buffer word counting logic."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char 0)
    (let ((counter 0))
      (while (< (point) (point-max))
        (when (re-search-forward "\\w+\\W*" nil t)
          (setq counter (1+ counter))))
      counter)))

(defun org-roam-open-large-note-randomly ()
  "Open a random Org-roam note with more than `org-roam-autoread-max-words` words.
Ignores files prefixed with 'ln_', 'br_', or 'private_'. Uses Org-roam DB for file list."
  (interactive)
  (let* ((all-files (org-roam-list-files))
         (filtered-files (seq-filter
                          (lambda (file)
                            (let ((fname (file-name-nondirectory file)))
                              (and (not (or (string-prefix-p "ln_" fname)
                                            (string-prefix-p "br_" fname)
                                            (string-prefix-p "private_" fname)))
                                   (> (count-words-in-file file)
                                      org-roam-autoread-max-words))))
                          all-files))
         (num-large (length filtered-files)))
    (if (zerop num-large)
        (message "No Org-roam notes exceed %d words after filtering." org-roam-autoread-max-words)
      (let ((random-file (seq-random-elt filtered-files)))
        (find-file-other-window random-file)
        (message "Opened random large note: %s (%d words)" (file-name-nondirectory random-file)
                 (count-words-in-file random-file))))))

(setq org-roam-autoread-max-bytes (* org-roam-autoread-max-words 6))  ; Rough estimate: ~6 bytes per word

(defun org-roam-open-nth-largest-large-note (&optional n)
  "Open the Nth largest Org-roam note (by file size) with more than `org-roam-autoread-max-words` estimated words.
Ignores files prefixed with 'ln_', 'br_', or 'private_'. Uses Org-roam DB for file list and file attributes for size.
N defaults to 1 (largest)."
  (interactive "p")
  (let* ((all-files (org-roam-list-files))
         (filtered-files (seq-filter
                          (lambda (file)
                            (let ((fname (file-name-nondirectory file)))
                              (not (or (string-prefix-p "ln_" fname)
                                       (string-prefix-p "br_" fname)
                                       (string-prefix-p "private_" fname)))))
                          all-files))
         (sized-files (seq-map
                       (lambda (file)
                         (cons (file-attribute-size (file-attributes file)) file))
                       filtered-files))
         (sorted-large-files (seq-filter
                              (lambda (pair)
                                (> (car pair) org-roam-autoread-max-bytes))
                              (seq-sort (lambda (a b) (> (car a) (car b))) sized-files)))
         (num-large (length sorted-large-files))
         (effective-n (or n 1)))
    (if (or (zerop num-large) (> effective-n num-large))
        (message "No Org-roam notes exceed estimated %d words (%d bytes) after filtering, or N=%d is out of range (max %d)."
                 org-roam-autoread-max-words org-roam-autoread-max-bytes effective-n num-large)
      (let* ((nth-pair (seq-elt sorted-large-files (1- effective-n)))
             (size (car nth-pair))
             (nth-file (cdr nth-pair)))
        (find-file-other-window nth-file)
        (message "Opened %d%s largest large note: %s (~%d words, %d bytes)"
                 effective-n (if (= effective-n 1) "st" (if (= effective-n 2) "nd" "th"))
                 (file-name-nondirectory nth-file)
                 (/ size 6) size)))))

;;;###autoload
(defun title-to-org-roam-node (title)
  "Create an Org-roam note from the current headline and jump to it."
  (interactive)
  (let ((node nil)
        (filetag ""))
    (setq node (org-roam-node-create :title title))
    (setq filetag (list "auto"))
    (if (org-roam-node-file node)
        (progn
          (message "Skipping %s, node already exists" title)
          node)  ; Return node here if it already exists
      (org-roam-capture- :node node
                         :keys "r")
      (org-entry-put (point-min) "PROJ_RESOURCES_DIR" (concat "[[" project-resources-dir title "]]"))
      (org-roam-tag-add filetag)
      (org-capture-finalize nil)
      ;; (kill-whole-line)
      ;; (org-capture-finalize nil)
      node)  ; Return node here after creating new node
    ))

;;;###autoload
(defun clock-out-and-mark-current-todo-done ()
  "Clock out the currently active todo and mark it as DONE.
Additionally, prompt for work mode (normal, focus, deepwork) and add the corresponding tag if not normal."
  (interactive)
  (if (org-clocking-p)
      (let ((clocked-buffer (marker-buffer org-clock-marker))
            (clocked-position (marker-position org-clock-marker)))
        ;; Clock out first
        (org-clock-out)

        ;; Go to the clocked item and mark as DONE
        (when (and clocked-buffer clocked-position)
          (with-current-buffer clocked-buffer
            (save-excursion
              (goto-char clocked-position)
              (org-back-to-heading t)
              (org-todo "DONE")
              ;; Prompt for work mode and add tag if not normal
              (let ((mode (completing-read "Work mode (default: normal): " '("normal" "focus" "deepwork") nil t nil nil "normal")))
                (unless (string= mode "normal")
                  (org-toggle-tag mode 'on))
                (message "Clocked out and marked todo as DONE%s" (if (string= mode "normal") "." (format ", and added %s tag" mode)))))))
        (message "No active clock to clock out"))))

(after! org
  (defun log-todo-next-creation-date (&rest ignore)
    "Log NEXT creation time in the property drawer under the key 'ACTIVATED'"
    (when (and (string= (org-get-todo-state) "NEXT")
               (not (org-entry-get nil "ACTIVATED")))
      (org-entry-put nil "ACTIVATED" (format-time-string "[%Y-%m-%d]"))))
  (add-hook 'org-after-todo-state-change-hook #'log-todo-next-creation-date)

;;;###autoload
  (defun jethro/org-agenda-process-inbox-item ()
    "Process a single item in the org-agenda."
    (org-with-wide-buffer
     (org-agenda-set-tags)
     ;; (org-agenda-set-property)
     (org-agenda-priority)
     (org-agenda-set-effort)
     (call-interactively 'org-agenda-schedule)
     (org-agenda-set-property)
     (org-agenda-refile nil nil t)))


;;;###autoload
  (defun jethro/bulk-process-entries ()
    (interactive)
    (if (not (null org-agenda-bulk-marked-entries))
        (let ((entries (reverse org-agenda-bulk-marked-entries))
              (processed 0)
              (skipped 0))
          (dolist (e entries)
            (let ((pos (text-property-any (point-min) (point-max) 'org-hd-marker e)))
              (if (not pos)
                  (progn (message "Skipping removed entry at %s" e)
                         (cl-incf skipped))
                (goto-char pos)
                (let (org-cl-loop-over-headlines-in-active-region) (funcall 'jethro/org-agenda-process-inbox-item))
                ;; `post-command-hook' is not run yet.  We make sure any
                ;; pending log note is processed.
                (when (or (memq 'org-add-log-note (default-value 'post-command-hook))
                          (memq 'org-add-log-note post-command-hook))
                  (org-add-log-note))
                (cl-incf processed))))
          (org-agenda-redo)
          (unless org-agenda-persistent-marks (org-agenda-bulk-unmark-all))
          (message "Acted on %d entries%s%s"
                   processed
                   (if (= skipped 0)
                       ""
                     (format ", skipped %d (disappeared before their turn)"
                             skipped))
                   (if (not org-agenda-persistent-marks) "" " (kept marked)")))))


;;;###autoload
  (defun jethro/org-process-inbox ()
    "Called in org-agenda-mode, processes all inbox items."
    (interactive)
    (org-agenda-bulk-mark-regexp "refile")
    (jethro/bulk-process-entries))
  )

(bind-key "C-M-s-z" 'consult-recent-file)
(bind-key "C-M-s-x" 'consult-buffer)
(bind-key "C-M-s-a" 'open-bookmark)
(bind-key "C-s-a" 'open-random-bookmark)
(bind-key "C-s-u" 'today)
(bind-key "C-M-s-{" 'org-roam-dailies-find-today)
(bind-key "C-M-s-}" 'org-roam-dailies-find-tomorrow)
(bind-key "C-M-s-:" 'org-roam-dailies-find-yesterday)
(bind-key "C-M-s-r" 'org-roam-node-find)
(bind-key "C-M-s-SPC" 'insert-org-roam-link)
(bind-key "C-s-v" 'yank-from-kill-ring)
;; scroll other window, useful when working with multiple files
(bind-key "C-M-s-n" 'scroll-other-window-down)
(bind-key "C-M-s-e" 'scroll-other-window)
(bind-key "C-M-s-c" 'screenshot-as-file-link)
;; last set of key bindings
(bind-key "C-M-s-g" 'clock-out-and-mark-current-todo-done)

(define-key global-map (kbd "C-s-n") #'random-task-select)
(define-key global-map (kbd "C-s-e") #'priority-time-task-select)
(define-key global-map (kbd "C-s-i") #'send-to-daily-highlights)
;; (define-key global-map (kbd "C-s-h") #'consult-buffer)
(define-key global-map (kbd "C-s-u") #'random-piano-select)
(define-key global-map (kbd "C-s-y") #'random-blog-study-select)
(define-key global-map (kbd "C-s-j") #'random-guitar-select)
(define-key global-map (kbd "C-s-k") #'random-study-select)
(define-key global-map (kbd "C-s-l") #'random-leisure-select)
(define-key global-map (kbd "C-s-m") #'random-music-select)
(define-key global-map (kbd "C-s-b") #'random-book-select)


(map! :leader
      (:prefix "v"
       :n "i" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-inbox-file)))
       :n "t" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-tasks-file)))
       :n "d" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-diary-file)))
       :n "b" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-bookslog-file)))
       :n "p" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-projects-file)))
       :n "h" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-directory "/agenda/habits.org"))))
       :n "v" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-directory "/agenda/log_blogsnvideos.org"))))
       :n "m" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-directory "/agenda/mundane.org"))))
       :n "r" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-recurring-file))))
      )

(after! org
  ;; (define-key org-mode-map (kbd "H--") 'other-window)
  ;; (define-key org-mode-map (kbd "H-+") 'org-strikethrough-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-|") 'org-italics-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-+") 'org-bold-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-_") 'org-verbatim-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-(") 'org-code-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-)") 'org-underline-region-or-point)
  ;; (define-key org-mode-map (kbd "H-l") 'org-latex-math-region-or-point)
  )

(setq! org-agenda-category-icon-alist
       `(
         ;; Tasks that are still not classified but will be in the future
         ("Inbox" ,(list (nerd-icons-mdicon "nf-md-checkbox_blank_badge" :height 1.2)) nil nil :ascent center)
         ;; Reminders of dates for something important
         ("Events" ,(list (nerd-icons-mdicon "nf-md-calendar_clock" :height 1.2)) nil nil :ascent center)
         ;; Long term tasks whose output is not immediately known
         ("ToTheMoon" ,(list (nerd-icons-mdicon "nf-md-rocket_launch_outline" :height 1.2)) nil nil :ascent center)
         ;; Short term tasks that show immediate improvements
         ("ToImprove" ,(list (nerd-icons-mdicon "nf-md-motorbike" :height 1.2)) nil nil :ascent center)
         ;; Something I do just for the sake of doing it
         ("Hobby" ,(list (nerd-icons-mdicon "nf-md-spa" :height 1.2)) nil nil :ascent center)
         ;; Health related tasks
         ("Fitness" ,(list (nerd-icons-faicon "nf-fa-heartbeat" :height 1.2)) nil nil :ascent center)
         ;; Tasks that don't fall into any category
         ("Normal" ,(list (nerd-icons-mdicon "nf-md-laptop" :height 1.2)) nil nil :ascent center)
         ;; Something that is not too valuable in terms of information
         ("Mundane" ,(list (nerd-icons-mdicon "nf-md-emoticon_sad_outline" :height 1.2)) nil nil :ascent center)
         ;; Birthdays and Anniversaries
         ("Celebration" ,(list (nerd-icons-mdicon "nf-md-cake" :height 1.2)) nil nil :ascent center)
         ;; Birthdays and Anniversaries
         ("EHP" ,(list (nerd-icons-faicon "nf-fa-key" :height 1.2)) nil nil :ascent center)
         ))


;; Org mode archiving
(after! org
  ;; (add-hook 'org-mode-hook #'auto-fill-mode)
  (setq org-attach-id-dir (concat org-directory "attachments/org-attach/")
        org-attach-auto-tag nil
        ;; show images instead of links to images
        org-startup-with-inline-images t
        org-archive-tag "DONE"
        org-image-actual-width nil
        org-archive-location (concat org-directory "archive/archive.org::datetree/")
        org-default-notes-file org-inbox-file
        projectile-project-search-path '("/sdcard/workspace/"))
  )

(after! org
  (setq org-agenda-start-with-log-mode t)
  (setq org-columns-default-format "%40ITEM(Task) %Effort(EE){:} %CLOCKSUM(Time Spent) %SCHEDULED(Scheduled) %DEADLINE(Deadline) %TAGS")
  (setq org-tags-exclude-from-inheritance '("project"))
  (setq org-agenda-sorting-strategy
        '((agenda time-up) (todo time-up) (tags time-up) (search time-up)))

  (add-to-list 'org-global-properties
               '("Effort". "0:05 0:15 0:30 1:00 2:00 3:00 4:00"))
  (setq org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-scheduled-if-deadline-is-shown t
        ;; for showing only recurring task's next entry
        org-agenda-show-future-repeats "next"
        )


  (setq org-todo-keyword-faces
        '(("TODO" :foreground "DeepSkyBlue4" :weight bold)
          ("TOREAD" :foreground "DeepSkyBlue4" :weight bold)
          ("TOWATCH" :foreground "DeepSkyBlue4" :weight bold)
          ("TOSTUDY" :foreground "DeepSkyBlue4" :weight bold)
          ("TOPRACTICE" :foreground "DeepSkyBlue4" :weight bold)
          ("WAITING" :foreground "light sea green" :weight bold)
          ("READING" :foreground "light sea green" :weight bold)
          ("STUDYING" :foreground "light sea green" :weight bold)
          ("WATCHING" :foreground "light sea green" :weight bold)
          ("PRACTICING" :foreground "light sea green" :weight bold)
          ("SOMEDAY" :foreground "chocolate3" :weight bold)
          ("REVISING" :foreground "firebrick" :weight bold)
          ("REREADING" :foreground "firebrick" :weight bold)
          ("REPRACTICING" :foreground "firebrick" :weight bold)
          ("REWATCH" :foreground "firebrick" :weight bold)
          ("SUMMARISING" :foreground "Gold" :weight bold)
          ("DELEGATED" :foreground "Gold" :weight bold)
          ("NEXT" :foreground "red1" :weight bold)
          ("ACTIVE" :background "DimGray" :foreground "gold1" :weight bold)
          ("DONE" :foreground "slategrey" :weight bold)))

  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "ACTIVE(a)" "REVISE(y)" "REVIEW(r@/!)" "|" "DONE(d!/!)")
          (sequence "SOMEDAY(f@/!)" "|" "CANCELED(c@/!)")
          (sequence "PROJ(p)" "|" "DONE(d!/!)" "CANCELED(c@/!)")
          (sequence "WAITING(w@/!)" "|" "CANCELED(c@/!)")))

  (setq org-log-state-notes-insert-after-drawers nil
        org-log-into-drawer t
        org-log-done 'time
        org-log-repeat 'time
        org-log-redeadline 'note
        org-log-reschedule 'note)

  (setq org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm)

  ;;(advice-add #'org-refile :after 'org-save-all-org-buffers)
  ;; (advice-add #'org-agenda-exit :around 'doom-shut-up-a)
  ;;(advice-add #'org-agenda-exit :before 'org-save-all-org-buffers)

  (setq org-startup-indented t
        org-src-tab-acts-natively t)
  ;; (add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

  (setq org-tag-alist '(
                        ;; Type of work
                        (:startgroup . nil)
                        ;; Have topic you are planning for as a tag
                        ("plan" . ?n)

                        ;; Have place and person who you are meeting with
                        ;; You can use additonal tags to describe the meeting
                        ;; For example, you can use e.g. Zoom, Slack, Messenger, Place Name etc.
                        ("meeting". ?m)
                        ;; Have person as a tag if working with someone or collaborating
                        ;; ("assist". ?A)

                        ;; hobby category and coding type
                        ;; ("customization". ?C)
                        ;; ("do" . ?d)
                        ("code" . ?c)
                        ("practice" . ?s)
                        ("plain" . ?l)
                        (:endgroup . nil)

                        (:startgroup . nil)
                        ("personal" . ?p)
                        ("work" . ?w)
                        ("both" . ?b)
                        (:endgroup . nil)

                        ;; Active or Passive Work
                        (:startgroup . nil)
                        ("Active". ?a)
                        ;; ("read" . ?r)
                        ;; ("write" . ?W)
                        ("Passive". ?v)
                        ;; ("watch" . ?w)
                        ;; ("listen" . ?L)
                        (:endgroup . nil)
                        (:startgroup . nil)
                        ("ehpsupport" . ?z)
                        ("ehpmodeling" . ?x)
                        ("ehpdragonfly" . ?y)
                        ("ehparchitecture" . ?e)
                        ("ehpresearch" . ?i)
                        (:endgroup . nil)

                        ;; Difficulty of work
                        (:startgroup . nil)
                        ("Challenge" . ?1)
                        ("Average" . ?2)
                        ("Easy" . ?3)
                        (:endgroup . nil)

                        ;; ;; Time Context for the work
                        (:startgroup . nil)
                        ("Morning" . ?4)
                        ("Day" . ?5)
                        ("Evening" . ?6)
                        (:endgroup . nil)

                        ;; Motivation required for this work
                        (:startgroup . nil)
                        ("Lazy" . ?7)
                        ("ModeratelyLazy" . ?8)
                        ("Energetic" . ?9)
                        (:endgroup . nil)
                        ))

  (setq org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id
        org-clone-delete-id t)
  )

;; ORG CAPTURE TEMPLATES

(after! org (add-to-list 'org-capture-templates
                         '("l" "Link Capture" entry (file (concat org-directory "extra/links.org"))
                           "* TODO [[%^{link}][%^{description}]]"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("h" "Clip Link Capture" entry (file (concat org-directory "extra/links.org"))
                           "* TODO %(org-cliplink-capture)"
                           :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("pn" "New Project" entry
                           (file "/sdcard/org/agenda/inbox.org")
                           (file "/sdcard/org/templates/newprojtemplate.org"))
                         ))


(after! org (add-to-list 'org-capture-templates
                         '("ps" "Create Project Subtask" entry (file org-inbox-file)
                           "* TODO %^{taskname}%?
:PROPERTIES:
:TRIGGER: next-sibling scheduled!(\"++%^{NEXT_TASK_AFTER}\") todo!(NEXT)
:BLOCKER:  previous-sibling
:CREATED:    %U
:END:
" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("v" "Create a new habit" entry (file org-recurring-file)
                           "* TODO %^{description} %?
SCHEDULED: %^{Start Time:}t
:PROPERTIES:
:STYLE: habit
:CREATED: %U
:END:
")))

(after! org (add-to-list 'org-capture-templates
                         '("z" "Create EHP Task" entry (file org-tasks-file)
                           "* TODO %^{Task Description} %(org-set-tags \"work:Day\")%(org-set-tags-command)
SCHEDULED: %t
:PROPERTIES:
:CREATED: %U
:CATEGORY: EHP
:END:
")))

;; TODO Upgrade this functionality to use a template
;; (after! org (add-to-list 'org-capture-templates
;;                          '("e" "Add an event" entry (file (concat org-agenda-directory "birthdays_and_anniversaries.org"))
;;                            "* %^{Person}
;; \%\%(org-anniversary %^{Date}) %^{Person}'s %^{Event}
;; " :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("d" "Diary Log" entry(file+olp+datetree org-diary-file)
                           "** <%<%I:%M:%S>> %^{diary entry}
%?")))


(after! org (add-to-list 'org-capture-templates
                         '("m" "Set a Motto" entry(file+olp+datetree org-motto-file)
                           "* %^{diary entry}
%?" :immediate-finish t)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     REVIEW TEMPLATES                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



(after! org
  (add-to-list 'org-capture-templates
               '("r" "Make a review")))

(after! org
  (add-to-list 'org-capture-templates
               '("rw" "Weekly Review" entry
                 (file+olp+datetree org-weeklyreview-file)
                 (file "/sdcard/org/templates/weeklyreviewtemplate.org") :jump-to-captured t :tree-type week))

  (add-to-list 'org-capture-templates
               '("rl" "Last Week Weekly Review" entry
                 (file+olp+datetree org-weeklyreview-file)
                 (file "/sdcard/org/templates/weeklyreviewtemplate_lastweek.org") :jump-to-captured t :tree-type week))
  )

(after! org
  (add-to-list 'org-capture-templates
               '("rm" "Monthly Review" entry
                 (file+olp+datetree org-monthlyreview-file)
                 (file "/sdcard/org/templates/monthlyreviewtemplate.org") :jump-to-captured t :tree-type month)))

(after! org
  (add-to-list 'org-capture-templates
               '("rq" "Quarterly Review" entry
                 (file+olp+datetree org-quarterlyreview-file)
                 (file "/sdcard/org/templates/quarterlyreviewtemplate.org") :jump-to-captured t :tree-type quarter)))

(after! org (add-to-list 'org-capture-templates
                         '("rd" "Daily Review" entry (file+olp+datetree org-dailyreview-file)
                           (file "/sdcard/org/templates/dailyreviewtemplate.org")
                           :jump-to-captured t)))

(after! org (add-to-list 'org-capture-templates
                         '("ry" "Daily Review Yesterday" entry (file+olp+datetree org-dailyreview-file)
                           (file "/sdcard/org/templates/dailyreviewtemplate_yesterday.org")
                           :jump-to-captured t)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        REVIEW TEMPLATES DONE                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(after! org
  (add-to-list 'org-capture-templates
               '("C"  "Contact" entry (file (concat org-directory "extra/contacts.org"))
                 "* %(org-contacts-template-name)
    :PROPERTIES:
    :EMAIL: %(org-contacts-template-email)
    :PHONE: %^{Phone}
    :ADDRESS: %^{Home Address}
    :BIRTHDAY: %^{yyyy-mm-dd}
    :ORG:  %^{Company}
    :NOTE: %^{NOTE}
    :END:"
                 :empty-lines 1)))

(after! org (add-to-list 'org-capture-templates
                         '("c" "Capture Immediate" entry (file org-inbox-file)
                           "* TODO %^{taskname}%?
:PROPERTIES:
:CREATED:    %U
:END:
" :immediate-finish t)))

(after! org
  (require 'org-time-budgets)
  (setq org-time-budgets '((:title "EHP" :match "+work" :budget "30:00" :blocks (workday week))
                           (:title "EHP Deep Work" :match "+work+deepwork" :budget "13:00" :blocks (workday week))
                           (:title "Meditation" :match "+meditation" :budget "5:00" :blocks (day week))
                           (:title "Review" :match "+review" :budget "0:30" :blocks (day week))
                           (:title "Ritual" :match "+ritual" :budget "0:30" :blocks (day week))
                           (:title "Entertainment" :match "+entertainment" :budget "10:00" :blocks (day week))
                           (:title "Guitar" :match "+music" :budget "6:00" :blocks (day week))
                           (:title "Exercise" :match "+exercise" :budget "1:45" :blocks (day week))
                           (:title "Coding" :match "+code" :budget "40:00" :blocks (nil week))
                           (:title "Reading" :match "+book" :budget "3:00" :blocks (nil week))
                           ;; (:title "Yollo" :match "+personal+code" :budget "20:00" :blocks (nil week))
                           ))
  )

;; ORG AGENDA VIEWS

;;;###autoload
(after! org-agenda (setq org-agenda-custom-commands
                         '(
                           ("k" "Today\'s View"
                            ((my-agenda-motto "" nil)
                             (agenda ""
                                     ((org-agenda-overriding-header "Overall Agenda View")
                                      (org-agenda-span 'day)
                                      (org-deadline-warning-days 7)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-sorting-strategy '(priority-down effort-down))
                                      (org-agenda-current-span 'day))
                                     )
                             (org-time-budgets-in-agenda-maybe)
                             (todo "SUMMARISING"
                                   ((org-agenda-overriding-header "Books I am currently reading and summarizing\n ======================================================\n")))
                             )
                            nil)
                           ("n" "Next tasks"
                            ((todo "NEXT"
                                   ((org-agenda-overriding-header " PROJECT TASKS\n ===================================================================\n")
                                    ))
                             ) nil)
                           ("o" "Monthly Review"
                            ((agenda "" ((org-agenda-span 30)
                                         (org-agenda-overriding-header " Previous Month Deferred and not completed\n ===================================================================\n")
                                         (org-agenda-start-day "-7d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (agenda "" ((org-agenda-span 30)
                                         (org-agenda-overriding-header " Planned for next month\n ===================================================================\n")
                                         (org-agenda-start-day "+1d")
                                         (org-agenda-entry-types '(:timestamp))))
                             ) nil)
                           ("W" "Weekly Review"
                            ((agenda "" ((org-agenda-span 7)
                                         (org-agenda-overriding-header " Previous Week Deferred and not completed\n ===================================================================\n")
                                         (org-agenda-start-day "-7d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (agenda "" ((org-agenda-span 7)
                                         (org-agenda-overriding-header " Planned for next week\n ===================================================================\n")
                                         (org-agenda-start-day "-1d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (todo ""
                                   ((org-agenda-files
                                     '(org-inbox-file))
                                    (org-agenda-overriding-header " Process and refile inbox\n ===================================================================\n")
                                    ))
                             (todo "TOREAD"
                                   ((org-agenda-files
                                     '(org-bookslog-file))
                                    (org-agenda-overriding-header " Do you want to read some new book\n ===========================================================\n")
                                    ))
                             (todo "WAITING"
                                   ((org-agenda-files
                                     '(org-tasks-file))
                                    (org-agenda-overriding-header " Waiting for something else\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-files
                                     '(org-projects-file))
                                    (org-agenda-overriding-header " Projects Work for Next Week\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-overriding-header " Process Someday\n ===========================================================\n")
                                    (org-agenda-files
                                     '(org-someday-file))
                                    ))
                             )
                            nil)
                           ("v" "I am bored"
                                        ; Easy tasks
                            ((tags-todo "+Easy"
                                        ((org-agenda-overriding-header " Get over easier things now")
                                         ))
                                        ; Read when bored
                             (tags-todo "+read"
                                        ((org-agenda-files
                                          '(org-bookslog-file))
                                         (org-agenda-overriding-header " Why not read something rather than waste time?"))
                                        )
                                        ; Get entertained
                             (tags-todo "+entertaintment"
                                        ((org-agenda-files
                                          '(org-inbox-file))
                                         (org-agenda-overriding-header " Enjoy some time doing whatever"))
                                        )
                             ))
                           ;; ("w" "Office agenda"
                           ;;              ; Priority A
                           ;;  ((tags-todo "PRIORITY=\"A\"&+office"
                           ;;              ((org-agenda-overriding-header "Priority A")))
                           ;;              ; Due soon
                           ;;   (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&+office"
                           ;;              ((org-agenda-overriding-header "Due soon")))
                           ;;   ))
                           ;; ("l" "Home agenda"
                           ;;              ; Priority A
                           ;;  ((tags-todo "PRIORITY=\"A\"&+home"
                           ;;              ((org-agenda-overriding-header "Priority A")))
                           ;;              ; Due soon
                           ;;   (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&+home"
                           ;;              ((org-agenda-overriding-header "Due soon")))
                           ;;   ))
                           )))

(after! org
  (setq org-highlight-latex-and-related '(native script entities))
  (add-hook 'org-mode-hook 'org-fragtog-mode)
  )

(add-hook! 'org-mode-hook #'org-appear-mode)

(after! org
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks t)
  ;;(run-at-time nil nil #'org-appear--set-elements)
  )

;; Image mode
(after! image-mode
  (defun my/delete-image-and-next ()
    "Move to the next image and delete the previous one."
    (interactive)
    (let ((previous-file (buffer-file-name)))
      ;; First, check if we are in image mode and there is a next image.
      (if (and (eq major-mode 'image-mode) (image-next-file 1))
          (progn
            ;; After moving to next image, delete the previous file.
            (when previous-file
              (delete-file previous-file)
              (message "Deleted file %s" previous-file)))
        )))
  
  (defun my/read-filename-and-tags ()
    "Read new filename and tags from the user."
    (let ((filename (read-string "Enter new filename: "))
          (tags (read-string "Enter tags (comma-separated): ")))
      (list filename tags)))
  
  
  (defvar my-image-index-file (concat org-directory "imageindex.csv"))
  (defvar my-image-processed-dir "/sdcard/Pictures/S23/Processed/")
  
  (setq my-image-tags '("personal" "work" "meditation" "books" "research"
                        "learningnote" "todo" "meme" "dance" "music" "movie"
                        "wise" "quote" "money" "health" "food" "travel" "nature"
                        "design" "art" "gif" "funny" "tech" "reference" "favorite"
                        "strange" "party" "qr" "raw" "wallpaper" "memory" ))
  
  (defun read-tags-from-csv (csv-file)
    "Read tags from a CSV file, print them with counts to the message buffer, and return a frequency-sorted list of tags."
    (let ((tag-counts (make-hash-table :test 'equal)))
      (with-temp-buffer
        (insert-file-contents csv-file)
        (while (not (eobp))
          (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                 (elements (split-string line "," t))
                 (tags (cdr elements)))  ; Skip the first element (filename)
            (dolist (tag tags)
              (let ((trimmed-tag (string-trim tag)))  ; Trim whitespace from tag
                (when (not (string-empty-p trimmed-tag))  ; Only process non-empty tags
                  (puthash trimmed-tag (1+ (gethash trimmed-tag tag-counts 0)) tag-counts))))
            (forward-line 1)))
        (let ((sorted-tags (sort (hash-table-keys tag-counts)
                                 (lambda (a b) (> (gethash a tag-counts) (gethash b tag-counts))))))
          (append sorted-tags my-image-tags)))))
  
  (defun set-image-tags-and-rename-and-next ()
    "Set tags for the current image, rename the file using the first tag, move it to the processed directory, save details to an image index file, and then move to the next unprocessed image."
    (interactive)
    ;; Ensure we are in an image buffer
    (unless (eq major-mode 'image-mode)
      (error "Not in an image-mode buffer"))
    
    (let* ((file (buffer-file-name))
           (all-tags (read-tags-from-csv my-image-index-file))
           (selected-tags (completing-read-multiple
                           "Select tags (use comma to separate): "
                           all-tags nil t))
           ;; Trim whitespace from selected tags
           (trimmed-selected-tags (mapcar #'string-trim selected-tags))
           ;; Filter out empty tags
           (final-tags (seq-filter (lambda (tag) (not (string-empty-p tag))) trimmed-selected-tags))
           (extension (file-name-extension file))
           (first-tag (car final-tags))
           (new-base-name (replace-regexp-in-string "[ ,]" "_" (file-name-base file)))
           (new-name (concat (if first-tag
                                 (concat first-tag "--" new-base-name)
                               new-base-name)
                             "." extension))
           (processed-path (expand-file-name new-name my-image-processed-dir))
           (index-entry (format "%s,%s\n" processed-path (string-join final-tags ", "))))
      
      ;; Perform the rename operation
      (when file
        (evil-save file t)
        (rename-file file processed-path)
        ;; Add entry to the image index file
        (with-temp-buffer
          (insert index-entry)
          (append-to-file (point-min) (point-max) my-image-index-file))
        (message "Moved and renamed file to %s and updated index with tags: %s" processed-path (string-join final-tags ", ")))
      
      ;; Move to the next image
      (my/delete-image-and-next)))
  
  (defun my/crop-save-tags-rename-and-next ()
    "Crop the current image, save it with the same name, set tags, rename the file using the first tag, move it to the processed directory, save details to an image index file, and then move to the next unprocessed image."
    (interactive)
    ;; Ensure we are in an image buffer
    (unless (eq major-mode 'image-mode)
      (error "Not in an image-mode buffer"))
    
    ;; Crop the image
    (image-crop)
    
    ;; for some reason image save cannot happen without few escapes
    (execute-kbd-macro (kbd "ESC ESC ESC"))
    ;; Save the cropped image using the same filename
    (let ((file (buffer-file-name)))
      (when file
        (my/save-cropped-image file)))
    (revert-buffer t t)
    ;; Set tags, rename and move to the processed directory
    (set-image-tags-and-rename-and-next))
  
  (defun my/save-cropped-image (filename)
    "Save the current buffer's image to FILENAME."
    (interactive "F")
    (let ((image (image-get-display-property)))
      (when image
        (let ((data (plist-get (cdr image) :data)))
          (unless data
            (error "No image data available"))
          (with-temp-file filename
            (insert data))
          (message "Image saved to %s" filename)))))
  
  (map! :map image-mode-map
        :nvm "q" #'image-kill-buffer
        :nvm "c" #'my/crop-save-tags-rename-and-next
        :nvm "d" #'my/delete-image-and-next
        :nvm "e" #'set-image-tags-and-rename-and-next
        :nvm "C-j" #'image-next-line
        :nvm "C-k" #'image-previous-line
        :nvm "j" #'image-next-file
        :nvm "k" #'image-previous-file
        )
  )

;; Org Roam
(after! org
  (setq org-roam-dailies-directory "daily/")

  (org-roam-setup)

  ;; Remove org-roam side buffer on phones ONLY FOR PHONES
  (remove-hook 'org-roam-find-file-hook '+org-roam-open-with-buffer-maybe-h)


  ;; Attachments removed from org-roam db
  (setq org-roam-db-node-include-function
        (lambda ()
          (or
           (not (cdr  (assoc "NOTER_PAGE" (org-entry-properties))))
           (not (member "ATTACH" (org-get-tags)))
           )))

  ;; Org-roam interface
  (cl-defmethod org-roam-node-hierarchy ((node org-roam-node))
    "Return the node's TITLE, as well as it's HIERACHY."
    (let* ((title (org-roam-node-title node))
           (olp (mapcar (lambda (s) (if (> (length s) 30) (concat (substring s 0 30)  "...") s)) (org-roam-node-olp node)))
           (level (org-roam-node-level node))
           (filetitle (org-roam-get-keyword "TITLE" (org-roam-node-file node)))
           (shortentitle (if (> (length filetitle) 30) (concat (substring filetitle 0 30)  "...") filetitle))
           (separator (concat " " (nerd-fonts-insert-faicon "nf-fa-chevron_right") " ")))
      (cond
       ((= level 1) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-green)) " "
                            (propertize shortentitle 'face 'org-roam-dim) separator title))
       ((= level 2) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-dpurple)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       ((> level 2) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-dsilver)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       (t (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "list" :face 'all-the-icons-yellow)) " " title)))))

  (defconst my/org-roam-special-tags
    '("bibnote" "bookreview" "literaturenote" "default" "abstract" "blog" "person" "creativewriting")
    "Special tags that are unique to each file to represent the note's function.")

  (defconst my/frg-roam-generalnote-tags
    '("beautiful" "idgi" "seed" "readmore" "talkabout" "tmi" "research")
    "Special tags that are unique to each file to represent the note's function.")

  (defconst my/org-roam-ignored-tags
    '("ATTACH")
    "Tags that are ignored when displaying function and other tags.")

  (defun my/org-roam-filtered-tags (node)
    "Return the tags of NODE after filtering out ignored tags."
    (seq-remove (lambda (tag)
                  (member tag my/org-roam-ignored-tags))
                (org-roam-node-tags node)))

  (cl-defmethod org-roam-node-functiontag ((node org-roam-node))
    "Return the FUNCTION TAG for each node."
    (let* ((tags (my/org-roam-filtered-tags node))
           (functiontag (seq-intersection my/org-roam-special-tags tags 'string=)))
      (concat
       (if functiontag
           (propertize "=has:functions=" 'display (nerd-icons-faicon "nf-fa-gear" :face 'all-the-icons-silver :v-adjust 0.02))
         (propertize "=not-functions=" 'display (nerd-icons-faicon "nf-fa-gear" :face 'org-roam-dim :v-adjust 0.02)))
       " " (string-join functiontag ", "))))

  (cl-defmethod org-roam-node-othertags ((node org-roam-node))
    "Return the OTHER TAGS of each notes."
    (let* ((tags (my/org-roam-filtered-tags node))
           (othertags (seq-difference tags my/org-roam-special-tags 'string=)))
      (when othertags
        (concat
         (propertize "=has:tags=" 'display (nerd-icons-faicon "nf-fa-tags" :face 'all-the-icons-dgreen :v-adjust 0.02)) " "
         (propertize (string-join othertags ", ") 'face 'all-the-icons-dgreen)))))

  (cl-defmethod org-roam-node-backlinkscount ((node org-roam-node))
    (let* ((count (caar (org-roam-db-query
                         [:select (funcall count source)
                          :from links
                          :where (= dest $s1)
                          :and (= type "id")]
                         (org-roam-node-id node)))))
      (if (> count 0)
          (concat (propertize "=has:backlinks=" 'display (nerd-icons-insert-octicon "nf-oct-link" :face 'all-the-icons-dblue)) (format "%d" count))
        (concat (propertize "=not-backlinks=" 'display (nerd-icons-insert-octicon "nf-oct-link" :face 'org-roam-dim))  " "))))

  (defun my/org-roam-compute-tags (node)
    "Compute the function tags and other tags for the given NODE.
Return a list where the first element is the function tags and
the second element is the other tags."
    (let* ((tags (seq-remove (lambda (tag)
                               (member tag my/org-roam-ignored-tags))
                             (org-roam-node-tags node)))
           (functiontags (seq-intersection my/org-roam-special-tags tags 'string=))
           (othertags (seq-difference tags my/org-roam-special-tags 'string=)))
      (list functiontags othertags)))

  (defun org-roam-node-fullformat (node)
    "Return a formatted string containing the title and computed tags for the NODE."
    (let* ((tags (my/org-roam-compute-tags node))
           (functiontag (car tags))
           (othertags (cadr tags))
           (functiontag-str (format "%-15s"
                                    (concat
                                     ;; (if functiontag
                                     ;;     (propertize "=has:functions=" 'display (all-the-icons-octicon "gear" :face 'all-the-icons-silver :v-adjust 0.02))
                                     ;;   (propertize "=not-functions=" 'display (all-the-icons-octicon "gear" :face 'org-roam-dim :v-adjust 0.02)))
                                     " " (string-join functiontag ", "))))
           (othertags-str (when othertags
                            (concat
                             (propertize "=has:tags=" 'display (nerd-icons-faicon "nf-fa-tags" :face 'nerd-icons-dgreen :v-adjust 0.02)) " "
                             (propertize (string-join othertags ", ") 'face 'nerd-icons-dgreen)))))
      (format " %s %s %s" functiontag-str (org-roam-node-title node) (or othertags-str ""))))

  (setq org-roam-node-display-template
        (concat  "${fullformat}"))

  ;; (setq org-roam-node-display-template
  ;;       (concat  "${functiontag:27} ${title} ${othertags}"))



  ;; ;; Keys binding
  (map! :leader
        :prefix "n"
        (:prefix ("r" . "Org-roam")
         :desc "Toggle roam buffer"            "t" #'org-roam-buffer-toggle
         :desc "Refile"                        "r" #'org-roam-refile
         (:prefix ("l" . "Roam Alias")
          :desc "Add alias"                    "a" #'org-roam-alias-add
          :desc "Remove alias"                 "d" #'org-roam-alias-remove)))
  )


(after! org-roam
  (setq org-roam-capture-templates
        '(("d" "Default" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :default:
")
           :immediate-finish t)

          ("r" "Default but open buffer" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS:
")
           :unnarrowed t)

          ("t" "Tagged" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: %^G
")
           :unnarrowed t)

          ("o" "Abstract ON Note " plain "%?"
           :if-new (file+head "on_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :abstract:
")
           :unnarrowed t)

          ("l" "Literature Note " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :literaturenote:%^{definition|theory|course|video|article|library|subject|chapter|topic|research}:%^G
#+REF_URL:
")
           :unnarrowed t)

          ("e" "EHP Note" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :ehp:%^{type|ultra|dragonfly|architecture}:%^G
#+REF_URL:
")
           :unnarrowed t)

          ("b" "Book Review " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :bookreview:
")
           :unnarrowed t)

          ("c" "Composition" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :composition:
")
           :unnarrowed t)

          ;; TODO Manage it later
          ;;           ("m" "Meeting Notes" plain "%?"
          ;;            :if-new (file+head "meet_${slug}.org"
          ;;                               "#+TITLE: ${title}
          ;; #+CREATED_DATE: %T
          ;; #+filetags: :meeting:
          ;; #+ATTENDEES: %^{Attendees}
          ;; #+LOCATION: %^{Location}
          ;; #+START_TIME: %^{Start Time}
          ;; #+END_TIME: %^{End Time}
          ;; ")
          ;;            :unnarrowed t)

          ("p" "Person" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :person:
")
           :unnarrowed t)

          ;; Org roam bibtex template
          ("r" "Bibliography Reference" plain
           (file (concat org-templates-directory "orbreftemplate.org"))
           :if-new
           (file+head "papers/${citekey}.org"
                      "#+title: ${title}
#+FILETAGS: :bibnote:
")
           :unnarrowed t)

          ;; Use this field if necessary #+EXPORT_FILE_NAME: %^{export name}
          ("h" "Blog Post" plain
           "%?"
           :if-new (file+head "blogs/%<%Y%m%d%H%M%S>-${slug}.org" "#+SETUPFILE:../hugo_in_setup.org
#+HUGO_SECTION: ${ai|emacs|neuroscience}
#+HUGO_SLUG: ${slug}
#+HUGO_TAGS:
#+HUGO_CATEGORIES:
#+HUGO_DRAFT: false\n
#+AUTHOR: Alok Regmi
#+FILETAGS: :blog:${filetags}\n
#+TITLE: ${title}
")
           :unnarrowed t)

          ;;           ("j" "paper-description" plain "* Main Contribution \n\n* Your description of significance \n\n* New algorithm or principles\n\n* Simulation Results and Comparisons\n\n* Solid Conclusion"
          ;;            :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
          ;;                               "#+title: ${title}\n#+filetags: paper")
          ;;            :unnarrowed t)

          ;;           ("e" "ref" plain "%?"
          ;;            :if-new (file+head "websites/${slug}.org" "#+SETUPFILE:./hugo_in_setup.org
          ;; ,#+ROAM_KEY: ${ref}#+TITLE: ${title}\n- source :: ${ref}")
          ;;            :unnarrowed t)

          ("k" "private" plain
           "%?" :if-new (file+head "private-${slug}.org"
                                   "#+TITLE: ${title}\n
#+FILETAGS: %^G
")
           :unnarrowed t)

          ("w" "webref" entry "* ${title} ([[${ref}][${hostname}]])\n%?"
           :if-new
           (file+head (concat org-roam-dailies-directory "%<%Y-%m-%d>.org")
                      "#+title: %<%Y-%m-%d %a>
#+FILETAGS: journal
#+STARTUP: overview
")
           :unnarrowed t)
          ))

  (defun my/org-roam-set-created ()
    "Set a CREATED property in the current Org-roam node."
    (when (and (org-roam-buffer-p)
               (not (org-entry-get (point) "CREATED")))
      (org-set-property "CREATED" (format-time-string "[%Y-%m-%d %a %H:%M]"))))

  (add-hook 'org-roam-capture-new-node-hook #'my/org-roam-set-created)


  )


(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam ;; or :after org
  ;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
  ;;         a hookable mode anymore, you're advised to pick something yourself
  ;;         if you don't care about startup time, use
  :hook (org-roam . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(after! org-roam

;;;###autoload
  (defun bms/org-roam-rg-search ()
    "Search org-roam directory using consult-ripgrep. With live-preview."
    (interactive)
    (let ((consult-ripgrep-command "rg --null --ignore-case --type org --line-buffered --color=always --max-columns=500 --no-heading --line-number . -e ARG OPTS"))
      (consult-ripgrep org-roam-directory)))

;;;###autoload
  (defun insert-org-roam-link ()
    "Insert a Roam link and place the cursor next to the colon.
   If in Evil normal mode, switch to insert mode."
    (interactive)
    (if (and (bound-and-true-p evil-mode)
             (eq evil-state 'normal))
        (evil-insert-state)) ; Switch to insert mode if in normal mode
    (insert "[[roam:")
    (save-excursion
      (insert "]]")))

;;;###autoload
  (defun org-roam-dailies-goto-monday-of-week ()
    "Find the daily-note for the Monday of the current week, creating it if necessary."
    (interactive)
    (let* ((now (current-time))
           (decoded (decode-time now))
           (dow (nth 6 decoded))
           (days-back (if (= dow 0) 6 (- dow 1)))
           (monday-time (time-add now (* (- days-back) 86400))))
      (org-roam-dailies--capture monday-time t)))
  )

(use-package! hackernews
  :defer t)


;; RTS AND PRODUCTIVITY SETUP
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

(defun rts--add-state-change-logbook-entry (old-state new-state)
  "Add a state change entry to the current task's LOGBOOK."
  (let ((timestamp (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (org-back-to-heading t)
    (forward-line 1)

    ;; Look for existing LOGBOOK drawer
    (let ((logbook-start nil)
          (logbook-end nil)
          (properties-end (save-excursion
                            (when (looking-at "[ \t]*:PROPERTIES:")
                              (org-get-property-block)))))

      ;; Skip past PROPERTIES drawer if it exists
      (when properties-end
        (goto-char (cdr properties-end))
        (forward-line 1))

      ;; Look for LOGBOOK drawer
      (when (looking-at "[ \t]*:LOGBOOK:")
        (setq logbook-start (point))
        (setq logbook-end (save-excursion
                            (re-search-forward "^[ \t]*:END:" nil t)
                            (point))))

      (if logbook-start
          ;; LOGBOOK exists, add entry at the beginning
          (progn
            (goto-char logbook-start)
            (forward-line 1)
            (insert (format "- State \"%s\" from \"%s\" %s\n" new-state old-state timestamp)))
        ;; No LOGBOOK, create one
        (insert ":LOGBOOK:\n")
        (insert (format "- State \"%s\" from \"%s\" %s\n" new-state old-state timestamp))
        (insert ":END:\n"))))

  (when rts-debug-mode
    (rts--debug-log "Added LOGBOOK entry: %s -> %s" old-state new-state)))

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
   ((eq selector-type 'tasks)
    (list "Task" "🎯" "gray"))
   ((eq selector-type 'books)
    (list "Book" "📚" "blue"))
   ((or (eq selector-type 'guitar) (rts--has-tag-p tags "guitaractive"))
    (list "Guitar" "🎸" "orange"))
   ((or (eq selector-type 'piano) (rts--has-tag-p tags "pianoactive"))
    (list "Piano" "🎹" "purple"))
   ((or (eq selector-type 'study) (rts--has-tag-p tags "studyactive"))
    (list "Study" "📚" "blue"))
   ((eq selector-type 'music)
    (list "Music" "🎵" "green"))
   ((eq selector-type 'leisure)
    (list "Leisure" "🎯" "gold"))
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
          (let ((selected-task (nth (random (length same-time-tasks)) same-time-tasks)))
            (when rts-debug-mode
              (rts--debug-log "=== PRIORITY A SELECTION ===")
              (rts--debug-log "Selected from %d tasks in %s group" (length same-time-tasks) current-time-group))
            (rts--display-selected-item selected-task 'tasks)))

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
           (rts--select-by-probability final-filtered 'tasks)))))))

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

;;; Modified Display Function for Lazy Low-Effort
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

;;;###autoload
(defun open-bookmark ()
  (interactive)
  (let ((url (seq-elt (split-string (completing-read "Open: " (browser-bookmarks "/sdcard/org/notes/bookmarks.org")) "\n") 2)))
    (browse-url-firefox url)))

(defun open-random-bookmark ()
  "Open a random bookmark from the bookmarks file."
  (interactive)
  (let* ((bookmarks (browser-bookmarks "/sdcard/org/notes/bookmarks.org"))
         (random-bookmark (when bookmarks
                            (seq-random-elt bookmarks))))
    (if random-bookmark
        (let ((url (seq-elt (split-string random-bookmark "\n") 2)))
          (browse-url-firefox url))
      (message "No bookmarks found!"))))

;;;###autoload
(defun send-to-daily-highlights ()
  "Send selected text to highlights section in today's org-roam daily note with linked subheading."
  (interactive)
  (if (use-region-p)
      (let* ((selected-text-raw (buffer-substring-no-properties (region-beginning) (region-end)))
             ;; Only strip leading whitespace if first line starts with spaces followed by - or +
             (selected-text-clean (if (string-match "^\\s-+[-+]" selected-text-raw)
                                      (replace-regexp-in-string "^\\s-+" "" selected-text-raw)
                                    selected-text-raw))
             (current-buffer-name (buffer-name))
             (is-org-roam (and (derived-mode-p 'org-mode)
                               (org-roam-file-p)))
             ;; Get line number of selection start
             (start-line (line-number-at-pos (region-beginning)))
             ;; Detect if it's a code file
             (is-code-file (and buffer-file-name
                                (not (derived-mode-p 'org-mode))
                                (or (string-match "\\.[a-zA-Z0-9]+$" buffer-file-name))))
             (file-extension (when is-code-file
                               (file-name-extension buffer-file-name)))
             ;; Map common extensions to language names
             (language (when file-extension
                         (cond
                          ((string= file-extension "el") "elisp")
                          ((string= file-extension "py") "python")
                          ((string= file-extension "js") "javascript")
                          ((string= file-extension "ts") "typescript")
                          ((string= file-extension "java") "java")
                          ((string= file-extension "c") "c")
                          ((string= file-extension "cpp") "cpp")
                          ((string= file-extension "h") "c")
                          ((string= file-extension "hpp") "cpp")
                          ((string= file-extension "sh") "bash")
                          ((string= file-extension "rb") "ruby")
                          ((string= file-extension "go") "go")
                          ((string= file-extension "rs") "rust")
                          ((string= file-extension "php") "php")
                          ((string= file-extension "html") "html")
                          ((string= file-extension "css") "css")
                          ((string= file-extension "json") "json")
                          ((string= file-extension "xml") "xml")
                          ((string= file-extension "yaml") "yaml")
                          ((string= file-extension "yml") "yaml")
                          (t file-extension))))
             ;; Format the text appropriately
             (formatted-content (cond
                                 ;; Code file - wrap in src block
                                 (is-code-file
                                  (format "\n#+begin_src %s :eval no\n%s\n#+end_src"
                                          (or language "text")
                                          selected-text-clean))
                                 ;; Already starts with bullet point
                                 ((string-match "^\\s-*[-+]" selected-text-clean)
                                  selected-text-clean)
                                 ;; Regular text - add bullet point
                                 (t (format "- %s" selected-text-clean))))
             (linked-heading (if is-org-roam
                                 (let* ((node (org-roam-node-at-point))
                                        (id (org-roam-node-id node))
                                        (title (org-roam-node-title node)))
                                   (format "[[id:%s][%s]]" id title))
                               ;; For non-org-roam files, include line number
                               (format "[[file:%s::%d][%s]]"
                                       (buffer-file-name)
                                       start-line
                                       (file-name-sans-extension current-buffer-name))))
             (heading-display-name (if is-org-roam
                                       (org-roam-node-title (org-roam-node-at-point))
                                     (file-name-sans-extension current-buffer-name))))

        ;; Get today's daily note file using the public API
        (let ((current-buffer (current-buffer)))
          (org-roam-dailies-goto-today)
          (let ((daily-buffer (current-buffer)))
            ;; Go back to original buffer
            (switch-to-buffer current-buffer)

            ;; Work with daily note in background
            (with-current-buffer daily-buffer
              ;; Find or create highlights section
              (goto-char (point-min))
              (unless (re-search-forward "^\\* Highlights" nil t)
                (goto-char (point-max))
                (insert "\n* Highlights\n"))

              ;; Look for existing subheading
              (let ((subheading-exists nil))
                (save-excursion
                  (when (re-search-forward (format "^\\*\\* .*\\[%s\\]" (regexp-quote heading-display-name)) nil t)
                    (setq subheading-exists t)))

                ;; Add to existing or create new subheading
                (if subheading-exists
                    (progn
                      (re-search-forward (format "^\\*\\* .*\\[%s\\]" (regexp-quote heading-display-name)) nil t)
                      (forward-line 1)
                      ;; Skip to end of this subheading
                      (while (and (not (eobp))
                                  (not (looking-at "^\\*\\* "))
                                  (not (looking-at "^\\* ")))
                        (forward-line 1))
                      (backward-char 1)
                      (insert (format "\n%s" formatted-content)))
                  ;; Create new subheading with link
                  (goto-char (point-max))
                  (insert (format "\n** %s\n%s" linked-heading formatted-content))))

              (save-buffer))))

        (message "Added to daily highlights under '%s'" heading-display-name))
    (message "No text selected")))

(with-eval-after-load 'eat
  (define-key eat-mode-map (kbd "s-p") #'eat-yank)
  (define-key eat-semi-char-mode-map (kbd "s-p") #'eat-yank)
  )

(use-package! claude-code
  :config
  (defun my-claude-notify (title message)
    "Display a macOS notification with sound."
    (call-process "osascript" nil nil nil
                  "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                               message title)))

  (setq claude-code-notification-function #'my-claude-notify)
  (setq claude-code-startup-delay 0.2)
  (add-hook 'claude-code-start-hook
            (lambda ()
              ;; Reduce line spacing to fix vertical bar gaps
              (setq-local line-spacing 0.1)))
  )

(after! eat
  (defvar sm-subsitutions
    '((?⏺ . ?\-)
      (?· . ?.)
      (?✢ . ?+)
      (?✳ . ?*)
      (?∗ . ?*)
      (?✻ . ?*)
      (?✽ . ?*)
      (?╭ . ?+)
      (?╮ . ?+)
      (?╰ . ?+)
      (?╯ . ?+)
      (?⎿ . ?|)
      (?│ . ?|)
      (?🤖 . ?*)))

  (defun sm-replace-problem-chars (args)
    (let ((terminal (nth 0 args))
          (output (nth 1 args)))
      (dolist (sub sm-subsitutions)
        (setq output (subst-char-in-string (car sub) (cdr sub) output)))
      (list terminal output)))


  (advice-add 'eat-term-process-output :filter-args #'sm-replace-problem-chars))

;; ORG TIME BUDGETS - YESTERDAY TABLE FOR YESTERDAY DAILY REVIEW
(defun org-time-budgets-yesterday-range ()
  "Return the time range (tstart tend) for yesterday from midnight to midnight."
  (let* ((high (decode-time (current-time)))
         (high (list 0 0 0 (nth 3 high) (nth 4 high) (nth 5 high)))
         (high (apply #'encode-time high))
         (yend high)
         (ystart (time-subtract yend (days-to-time 1))))
    (list ystart yend)))

(defun org-time-budgets-format-block-yesterday (block match ystart-s yend-s wstart-s wend-s range-budget)
  "Format a single block for yesterday table."
  (if (null block)
      (make-string 29 ?\s)  ; Approximate width for empty daily column
    (let* ((is-daily (memq block '(day workday)))
           (current (org-time-budgets-time (list :match match
                                                 :tstart (if is-daily ystart-s wstart-s)
                                                 :tend (if is-daily yend-s wend-s))))
           (budget (pcase block
                     ('day (/ range-budget 7))
                     ('workday (/ range-budget 5))
                     ('week range-budget)
                     (_ 0))))
      (if (and current budget)
          (format "[%s] %s / %s"
                  (org-time-budgets-bar 14 current budget)
                  (org-time-budgets-minutes-to-string current)
                  (org-time-budgets-minutes-to-string budget))
        (make-string 29 ?\s)))))

(defun org-time-budgets-table-yesterday ()
  "List the time budgets in a table, with yesterday for daily blocks and this week for weekly blocks."
  (let* ((title-column-width (apply #'max
                                    (mapcar #'(lambda (budget) (string-width (plist-get budget :title)))
                                            org-time-budgets)))
         (w-trange (org-clock-special-range 'thisweek))
         (wstart (nth 0 w-trange))
         (wend (nth 1 w-trange))
         (wstart-s (format-time-string "[%Y-%m-%d]" wstart))
         (wend-s (format-time-string "[%Y-%m-%d]" wend))
         (y-trange (org-time-budgets-yesterday-range))
         (ystart (car y-trange))
         (yend (cadr y-trange))
         (ystart-s (format-time-string "[%Y-%m-%d]" ystart))
         (yend-s (format-time-string "[%Y-%m-%d]" yend)))
    (mapconcat #'(lambda (budget)
                   (let* ((title (plist-get budget :title))
                          (match (or (plist-get budget :match)
                                     (plist-get budget :tags))) ;; support for old :tags syntax
                          (blocks (or (plist-get budget :blocks)
                                      (cl-case (plist-get budget :block) ;; support for old :block syntax
                                        (week '(day week))
                                        (workweek '(workday week)))
                                      '(day week)))
                          (range-budget (org-time-budgets-string-to-minutes (plist-get budget :budget))))
                     (format "%s  %s"
                             (concat
                              title
                              (make-string (max 0 (- title-column-width (string-width title))) ?\s))
                             (mapconcat
                              (lambda (block)
                                (org-time-budgets-format-block-yesterday block match ystart-s yend-s wstart-s wend-s range-budget))
                              blocks
                              "  "))))
               org-time-budgets
               "\n")))

;; ADDITIONAL ANDROID CONFIG
(set-popup-rule! "^\\*Messages\\*$" :height 1 :quit nil :select t)
(map! :map org-roam-mode-map [mouse-1] #'org-roam-preview-visit)

;; Custom parser to relativize paths from macOS to Android
(after! citar
  (defun my-citar-relativize-parser (field)
    "Parse FILE-FIELD and relativize paths by removing the fixed base prefix."
    (let ((paths (or (citar-file--parser-default field)
                     (citar-file--parser-triplet field))))
      (when paths
        (mapcar (lambda (p)
                  (string-remove-prefix "/Users/alokregmi/Books/Papers/articles/" p))
                paths))))

  ;; Prepend custom parser to Citar's parser list
  (setq citar-file-parser-functions
        (cons 'my-citar-relativize-parser
              citar-file-parser-functions))

  ;; Function to open files using browse-url-xdg-open with file:// URLs
  (defun my-open-file-xdg (file)
    "Open FILE using browse-url-xdg-open as a file:// URL."
    (let ((url (concat "file://" (expand-file-name file))))
      (condition-case err
          (browse-url-xdg-open url)
        (error (message "Failed to open %s: %s" file err)))))

  ;; Configure Citar to use browse-url-xdg-open for PDFs and images
  (setq citar-file-open-functions
        '(("pdf" . my-open-file-xdg)
          ("jpg" . my-open-file-xdg)
          ("jpeg" . my-open-file-xdg)))

  (bind-key "M-+" 'citar-open-files)
  (bind-key "M--" 'citar-open-notes)
  )
;; ;; Optional: Dired binding for consistency
;; (with-eval-after-load 'dired
;;   (define-key dired-mode-map (kbd "C-c o") #'my-dired-open-xdg))

;; (defun my-dired-open-xdg ()
;;   "Open the file at point in Dired using browse-url-xdg-open."
;;   (interactive)
;;   (let ((file (dired-get-file-for-visit)))
;;     (if (file-exists-p file)
;;         (my-open-file-xdg file)
;;       (message "File does not exist: %s" file))))
