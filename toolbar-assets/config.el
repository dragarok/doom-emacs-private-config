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
                         '("e" "Link Capture" entry (file org-inbox-file)
                           "* TODO %:link %:description"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("h" "Clip Link Capture" entry (file org-inbox-file)
                           "* TODO [#F] %:link
:PROPERTIES:
:CREATED:    %U
:CATEGORY: Normal
:EFFORT: 0:30
:END:
"
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
                           :immediate-finish t
                           :jump-to-captured t)))

(after! org (add-to-list 'org-capture-templates
                         '("ry" "Daily Review Yesterday" entry (file+olp+datetree org-dailyreview-file)
                           (file "/sdcard/org/templates/dailyreviewtemplate_yesterday.org")
                           :immediate-finish t
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

(defun my-agenda-motto (&rest _ignore)
  "INSERTS MOTTO FROM MOTTO FILE TO AGENDA"
  (let ((motto-line "")
        (decorated-motto ""))
    (with-temp-buffer
      (insert-file-contents org-motto-file)
      (goto-char (point-max))
      (forward-line -1)
      (setq motto-line (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position)))
      (setq decorated-motto (concat "MOTTO: "
                                    (s-upcase (s-replace "\*" "" motto-line)))))

    ;; Add properties directly to the motto
    (add-text-properties 0 (length decorated-motto)
                         '(face (:foreground "OrangeRed4" :weight bold))
                         decorated-motto)

    (dotimes (_ 160) (insert "="))
    (insert "\n")
    (dotimes (_ 40) (insert "="))
    (insert decorated-motto)
    (dotimes (_ 40) (insert "="))
    (insert "\n")
    (dotimes (_ 160) (insert "="))
    (insert "\n")))

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
                           ("k" "Today's View"
                            ((my-agenda-motto "" nil)
                             (agenda ""
                                     ((org-agenda-overriding-header "Overall Agenda View")
                                      (org-agenda-span 'day)
                                      (org-deadline-warning-days 7)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-sorting-strategy '(priority-down effort-down))))
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
                                     (list org-inbox-file))
                                    (org-agenda-overriding-header " Process and refile inbox\n ===================================================================\n")
                                    ))
                             (todo "TOREAD"
                                   ((org-agenda-files
                                     (list org-bookslog-file))
                                    (org-agenda-overriding-header " Do you want to read some new book\n ===========================================================\n")
                                    ))
                             (todo "WAITING"
                                   ((org-agenda-files
                                     (list org-tasks-file))
                                    (org-agenda-overriding-header " Waiting for something else\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-files
                                     (list org-projects-file))
                                    (org-agenda-overriding-header " Projects Work for Next Week\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-overriding-header " Process Someday\n ===========================================================\n")
                                    (org-agenda-files
                                     (list org-someday-file))
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
                                          (list org-bookslog-file))
                                         (org-agenda-overriding-header " Why not read something rather than waste time?"))
                                        )
                                        ; Get entertained
                             (tags-todo "+entertaintment"
                                        ((org-agenda-files
                                          (list org-inbox-file))
                                         (org-agenda-overriding-header " Enjoy some time doing whatever"))
                                        )
                             ))
                           ("z" "Outdoors"
                                        ; Priority A
                            ((tags-todo "+outdoor"
                                        ((org-agenda-overriding-header "Outdoor Tasks to be done")))
                             ))
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

  (defun image-previous-file-nofreeze (&optional n)
    "Visit the preceding image in the same directory as the current file.
With optional argument N, visit the Nth image file preceding the
current one, in reverse alphabetical order.

This command visits the specified file via `find-alternate-file',
replacing the current Image mode buffer."
    (interactive "p" image-mode)
    (unless (derived-mode-p 'image-mode)
      (error "The buffer is not in Image mode"))
    (unless buffer-file-name
      (error "The current image is not associated with a file"))
    (let* ((n (or n 1))  ; Default to 1
           (file buffer-file-name)
           (dir (file-name-directory file))
           ;; Get sorted list of files matching image-file-name-regexp
           (files (sort (directory-files dir t (image-file-name-regexp)) #'string<))
           (index (cl-position file files :test #'string-equal)))
      (if (or (null index) (<= index (1- n)))
          (user-error "No previous image file")
        (find-alternate-file (nth (- index n) files)))))

  (map! :map image-mode-map
        :nvm "q" #'image-kill-buffer
        :nvm "c" #'my/crop-save-tags-rename-and-next
        :nvm "d" #'my/delete-image-and-next
        :nvm "e" #'set-image-tags-and-rename-and-next
        :nvm "C-j" #'image-next-line
        :nvm "C-k" #'image-previous-line
        :nvm "j" #'image-next-file
        :nvm "k" #'image-previous-file-nofreeze
        )
  )

;; Org Roam
(after! org
  (setq org-roam-dailies-directory "daily/")

  ;;(org-roam-setup)

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
                ;; Insert before current NEXT task
                (unless (bolp) (insert "\n"))
                (insert (make-string template-level ?*) " TODO " new-heading "\n")
                (forward-line -1))
            ;; Insert after current task (original behavior)
            (org-end-of-subtree t t)
            (unless (bolp) (insert "\n"))
            (insert (make-string template-level ?*) " TODO " new-heading "\n")
            (forward-line -1))
          
          (org-back-to-heading t)
          
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
          
          ;; Return marker for new task
          (copy-marker (point)))))))

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

;;; ===================================================================
;;; Add Clock Time Functions - Works in Agenda and Org Mode
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

(defun add-clock-time-by-offset ()
  "Add clock time to current task using offset approach.
Works in both agenda mode and org mode. Similar to org-agenda-add-clock-time
but universal. Prompts for duration and end offset."
  (interactive)
  (let* ((marker (rts--get-current-task-marker))
         (duration (read-number "Minutes to clock: " 30))
         (end-offset (read-number "End how many minutes ago (0 = now): " 0))
         (end-offset (if (= end-offset 0) 1 end-offset))) ; Default to 1 minute ago if 0
    
    (when (and marker (> duration 0))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          (let* ((now (current-time))
                 (end-time (time-subtract now (seconds-to-time (* end-offset 60))))
                 (start-time (time-subtract end-time (seconds-to-time (* duration 60))))
                 (start-str (format-time-string "[%Y-%m-%d %a %H:%M]" start-time))
                 (end-str (format-time-string "[%Y-%m-%d %a %H:%M]" end-time))
                 (hours (/ duration 60))
                 (mins (% duration 60))
                 (clock-entry (format "CLOCK: %s--%s =>  %2d:%02d" start-str end-str hours mins)))
            
            (rts--add-clock-entry-to-logbook clock-entry)
            (org-save-all-org-buffers)
            
            (when rts-debug-mode
              (rts--debug-log "Added %d minutes (from %d to %d mins ago) via offset method" 
                              duration (+ duration end-offset) end-offset))
            
            (message "Added %d minutes (from %d to %d mins ago)" 
                     duration (+ duration end-offset) end-offset)))))))

(defun add-clock-time-direct ()
  "Add clock time to current task using direct start/end time approach.
Works in both agenda mode and org mode. Similar to consult-add-clock-to-mundane-task
but works on current task without selection. Prompts for start and end times."
  (interactive)
  (let* ((marker (rts--get-current-task-marker))
         (start-time (read-string "Start time (HH:MM): "))
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
    
    (when (and marker (> duration-minutes 0))
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (org-back-to-heading t)
          
          ;; Add clock entry using existing helper function
          (rts--add-clock-entry-to-task marker start-time-obj end-time-obj duration-minutes)
          
          (when rts-debug-mode
            (rts--debug-log "Added %d minutes (%s to %s) via direct time method" 
                            duration-minutes start-time end-time))
          
          (message "Added %d minutes (%s to %s) and saved all org buffers" 
                   duration-minutes start-time end-time))))))

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


;;; ===================================================================
;;; Auto link open Hook while clocking in  
;;; ===================================================================


(defvar rts-auto-open-links-on-clock-in t
  "When non-nil, automatically open links when clocking into study/leisure tasks.")

(defvar rts-link-open-tags '("studyactive" "study" "blog" "youtube" "watchlist" "repo" "technical")
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
  (let ((url (seq-elt (split-string (completing-read "Open: " (browser-bookmarks "~/Nextcloud/org/notes/bookmarks.org")) "\n") 2)))
    (browse-url-firefox url)))

(defun open-random-bookmark ()
  "Open a random bookmark from the bookmarks file."
  (interactive)
  (let* ((bookmarks (browser-bookmarks "~/Nextcloud/org/notes/bookmarks.org"))
         (random-bookmark (when bookmarks
                            (seq-random-elt bookmarks))))
    (if random-bookmark
        (let ((url (seq-elt (split-string random-bookmark "\n") 2)))
          (browse-url-firefox url))
      (message "No bookmarks found!"))))

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


(use-package! claude-code
  :config
  (defun my-claude-notify (title message)
    "Display a macOS notification with sound."
    (call-process "osascript" nil nil nil
                  "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                               message title)))

  (setq claude-code-notification-function #'my-claude-notify)
  (setq claude-code-startup-delay 0.2)
  (setq claude-code-terminal-backend 'vterm)
  (add-hook 'claude-code-start-hook
            (lambda ()
              ;; Reduce line spacing to fix vertical bar gaps
              (setq-local line-spacing 0.1)))
  )

(defun diego--vterm-font-setup ()
  "Configure font settings specifically for vterm buffers, workaround claude-code."

  ;; Apply ASCII replacements for vterm specifically
  (let ((tbl (or buffer-display-table (setq buffer-display-table (make-display-table)))))
    (dolist (pair
             '((#x273B . ?*) ; ✻ TEARDROP-SPOKED ASTERISK
               (#x273D . ?*) ; ✽ HEAVY TEARDROP-SPOKED ASTERISK
               (#x2722 . ?+) ; ✢ FOUR TEARDROP-SPOKED ASTERISK
               (#x2736 . ?+) ; ✶ SIX-POINTED BLACK STAR
               (#x2733 . ?*) ; ✳ EIGHT SPOKED ASTERISK
               ))
      (aset tbl (car pair) (vector (cdr pair))))))

(add-hook 'vterm-mode-hook #'diego--vterm-font-setup)


;; ADDITIONAL ANDROID CONFIG
(set-popup-rule! "^\\*Messages\\*$" :height 1 :quit nil :select t)
(map! :map org-roam-mode-map [mouse-1] #'org-roam-preview-visit)


;; Function to open files using browse-url-xdg-open with file:// URLs
(defun my-open-file-xdg (file)
  "Open FILE using browse-url-xdg-open as a file:// URL."
  (let ((url (concat "file://" (expand-file-name file))))
    (condition-case err
        (browse-url-xdg-open url)
      (error (message "Failed to open %s: %s" file err)))))

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

;; kairoam
;;; kairoam-notes.el --- Horizontal evergreen notes for org-roam -*- lexical-binding: t; -*-

;; Author: kairoam (adapted for user)
;; Version: 0.1
;; Keywords: notes, org, org-roam, convenience
;; Package-Requires: ((emacs "27.1") (org-roam "2.0"))
;; Compatible with Doom Emacs (uses core libs only)

;;; Commentary:
;; Single-file implementation of an "evergreen" notes UI with mobile/laptop modes:
;; - Laptop mode: opens notes side-by-side (horizontal splits)
;; - Mobile mode: opens notes top-to-bottom (vertical splits)
;; - inserts new notes at current+1
;; - keeps up to `kairoam-max-expanded-windows' expanded (default 3)
;; - folds the farthest expanded window when needed
;; - folded windows show title overlay (vertical in laptop, horizontal in mobile)
;; - never reuses existing windows (always creates a new split)
;;
;; Key commands:
;;  C-c k r      kairoam-open-note-to-right (right in laptop, below in mobile)
;;  C-c k l      kairoam-open-at-point
;;  C-c k f      kairoam-fold-window
;;  C-c k e      kairoam-expand-window
;;  C-c k d      kairoam-debug
;;  C-c k t      kairoam-toggle-layout-mode (switch between mobile/laptop)
;;  C-c k m      kairoam-mobile-mode (set mobile mode)
;;  C-c k L      kairoam-laptop-mode (set laptop mode)
;;  C-c k R      kairoam-reset (reset and disable mode, C-u to kill buffers)
;;  C-c k K      kairoam-kill-all-buffers (reset and kill all tracked buffers)

;;; Code:

(require 'cl-lib)
(require 'subr-x)
;; doom typically already loads dash/s, but we don't rely on them explicitly.


;;; Configuration and simple logging

(defgroup kairoam nil
  "Kairoam evergreen-style org-roam panes."
  :group 'convenience)

(defcustom kairoam-layout-mode 'mobile
  "Layout mode: 'laptop for side-by-side (horizontal split), 'mobile for top-bottom (vertical split)."
  :type '(choice (const :tag "Laptop (side-by-side)" laptop)
          (const :tag "Mobile (top-bottom)" mobile))
  :group 'kairoam)

(defcustom kairoam-folded-width 3
  "Width (columns) for folded windows in laptop mode (thin column)."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-folded-height 2
  "Height (lines) for folded windows in mobile mode (thin row)."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-max-expanded-windows 3
  "Maximum number of expanded (full-content) windows to show at once."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-default-expanded-width 80
  "Fallback width to use when calculating expanded window sizes in laptop mode."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-default-expanded-height 30
  "Fallback height to use when calculating expanded window sizes in mobile mode."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-max-title-length 80
  "Maximum length for vertical titles in folded windows. Longer titles will be truncated."
  :type 'integer
  :group 'kairoam)

(defvar kairoam--log-buffer "*kairoam-log*")
(defun kairoam--log (lvl fmt &rest args)
  "Simple logger: LVL (string), FMT and ARGS."
  (let ((msg (apply #'format fmt args))
        (ts (format-time-string "%H:%M:%S")))
    (with-current-buffer (get-buffer-create kairoam--log-buffer)
      (goto-char (point-max))
      (insert (format "[%s] [%s] %s\n" ts lvl msg)))))

(defun kairoam--info (fmt &rest args) (apply #'kairoam--log "INFO" fmt args))
(defun kairoam--warn (fmt &rest args) (apply #'kairoam--log "WARN" fmt args))
(defun kairoam--error (fmt &rest args) (apply #'kairoam--log "ERR" fmt args))


;;; Core data structure: cl-defstruct for tracked windows

(cl-defstruct kairoam-window
  window    ;; the window object
  buffer    ;; buffer shown
  position  ;; integer position in sequence
  state     ;; 'expanded or 'folded
  overlay   ;; overlay object if folded
  line-numbers-mode-state) ;; original state of display-line-numbers-mode

(defvar kairoam--registry nil
  "Ordered list (vector-like) of `kairoam-window' structs representing sequence 0..n-1.")

(defun kairoam--registry-reset () (setq kairoam--registry nil))
(defun kairoam--registry-count () (length kairoam--registry))

(defun kairoam--find-by-window (win)
  "Return state struct for WIN, or nil."
  (cl-find-if (lambda (s) (and (kairoam-window-window s)
                               (eq (kairoam-window-window s) win)))
              kairoam--registry))

(defun kairoam--find-by-buffer (buf)
  (cl-find-if (lambda (s) (eq (kairoam-window-buffer s) buf))
              kairoam--registry))

(defun kairoam--position-of-window (win)
  (let ((s (kairoam--find-by-window win)))
    (and s (kairoam-window-position s))))

(defun kairoam--rebuild-positions ()
  "Rebuild positions in kairoam--registry so they are sequential 0..n-1."
  (cl-loop for i from 0
           for s in kairoam--registry
           do (setf (kairoam-window-position s) i))
  (kairoam--info "Rebuilt positions; total=%d" (kairoam--registry-count)))

(defun kairoam--register-new (win buf pos)
  "Insert new kairoam-window for WIN and BUF at POS, shifting following entries."
  (let ((new (make-kairoam-window :window win :buffer buf :position pos :state 'expanded 
                                  :overlay nil :line-numbers-mode-state nil)))
    (if (>= pos (kairoam--registry-count))
        (setq kairoam--registry (append kairoam--registry (list new)))
      (setq kairoam--registry
            (append (cl-subseq kairoam--registry 0 pos)
                    (list new)
                    (cl-subseq kairoam--registry pos)))
      (kairoam--rebuild-positions)
      (kairoam--info "Registered new window pos=%d buf=%s" pos (buffer-name buf))
      new)))

(defun kairoam--unregister-window (win)
  "Remove window WIN from registry and cleanup overlay if present."
  (let ((s (kairoam--find-by-window win)))
    (when s
      (when (kairoam-window-overlay s)
        (ignore-errors (delete-overlay (kairoam-window-overlay s))))
      (setq kairoam--registry (cl-remove s kairoam--registry :test #'eq))
      (kairoam--rebuild-positions)
      (kairoam--info "Unregistered window %s" (prin1-to-string win)))))

(defun kairoam--cleanup-dead ()
  "Remove entries whose window or buffer is dead."
  (let ((removed 0))
    (setq kairoam--registry
          (cl-remove-if
           (lambda (s)
             (let ((w (kairoam-window-window s))
                   (b (kairoam-window-buffer s)))
               (unless (and (windowp w) (window-live-p w) (bufferp b) (buffer-live-p b))
                 (cl-incf removed)
                 (when (kairoam-window-overlay s)
                   (ignore-errors (delete-overlay (kairoam-window-overlay s))))
                 t)))
           kairoam--registry))
    (when (> removed 0) (kairoam--info "Cleaned up %d dead registry entries" removed))
    (kairoam--rebuild-positions)
    removed))


;;; Helpers: title extraction, vertical title display

(defun kairoam--buffer-title (buf)
  "Return title for BUF. Try #+TITLE:, then first heading, then buffer name."
  (with-current-buffer buf
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (or 
         ;; Try #+TITLE: (case insensitive)
         (when (re-search-forward "^#\\+\\(?:TITLE\\|title\\|Title\\):\\s-*\\(.*\\)$" nil t)
           (string-trim (match-string 1)))
         ;; Try first level-1 org heading
         (progn
           (goto-char (point-min))
           (when (re-search-forward "^\\* \\(.+\\)$" nil t)
             (string-trim (match-string 1))))
         ;; Fallback to buffer name without extension
         (file-name-sans-extension (buffer-name buf)))))))

(defun kairoam--verticalize (s)
  "Return a string with S vertically (each char on its own line) with org-level-1 styling."
  (mapconcat (lambda (c) 
               (propertize (string c) 
                           'face '(:inherit org-level-1 :height 1.1 :weight bold)))
             (string-to-list s) "\n"))

(defun kairoam--horizontalize (s)
  "Return a styled horizontal title string for mobile mode."
  (propertize s 'face '(:inherit org-level-1 :height 1.2 :weight bold)))

(defun kairoam--make-title-overlay (buf title)
  "Create an overlay in BUF that displays TITLE.
In laptop mode: displays vertically centered.
In mobile mode: displays horizontally centered."
  (with-current-buffer buf
    (save-excursion
      (goto-char (point-min))
      ;; Ensure buffer has content to overlay (needed for empty buffers)
      (when (eobp)
        (insert " "))
      (let* ((win (get-buffer-window buf))
             (mobile-mode (eq kairoam-layout-mode 'mobile))
             ;; Truncate title if too long
             (truncated-title (if (> (length title) kairoam-max-title-length)
                                  (concat (substring title 0 (- kairoam-max-title-length 3)) "...")
                                title))
             (ov (make-overlay (point-min) (point-max)))
             display-content)
        (kairoam--info "Creating overlay for %s in %s mode" title (if mobile-mode "mobile" "laptop"))
        (if mobile-mode
            ;; Mobile mode: horizontal title centered on single line
            (let* ((w (if win (window-width win) 80))
                   (title-len (length truncated-title))
                   (padding-spaces (max 0 (/ (- w title-len) 2)))
                   (left-padding (make-string padding-spaces ?\s))
                   (horizontal-title (kairoam--horizontalize truncated-title)))
              ;; Just show title on one line for compact folded view
              (setq display-content (concat left-padding horizontal-title)))
          ;; Laptop mode: vertical title centered
          (let* ((h (if win (window-height win) 20))
                 (padding-lines (max 1 (/ h 4)))
                 (top-padding (make-string padding-lines ?\n))
                 (vertical-title (kairoam--verticalize truncated-title)))
            (setq display-content (concat top-padding vertical-title))))
        ;; Cover entire buffer content with styled title
        (overlay-put ov 'display display-content)
        (overlay-put ov 'kairoam-title t)
        (overlay-put ov 'priority 100) ; Ensure it's on top
        ov))))

(defun kairoam--remove-title-overlay (buf)
  (with-current-buffer buf
    (remove-overlays (point-min) (point-max) 'kairoam-title t)))


;;; Window (fold/expand) resizing functions

(defun kairoam--safe-window-width (win)
  (condition-case _err
      (window-width win)
    (error kairoam-folded-width)))

(defun kairoam--safe-window-height (win)
  (condition-case _err
      (window-height win)
    (error kairoam-folded-height)))

(defun kairoam--resize-window-to (win desired-size &optional vertical)
  "Resize WIN to DESIRED-SIZE (columns or lines based on VERTICAL flag).
  If VERTICAL is non-nil, resize height, otherwise resize width."
  (when (and (windowp win) (window-live-p win))
    (let* ((cur (if vertical 
                    (kairoam--safe-window-height win)
                  (kairoam--safe-window-width win)))
           (delta (- desired-size cur)))
      (when (/= delta 0)
        ;; Try multiple resize strategies in order of preference
        (condition-case err1
            ;; Strategy 1: Use adjust-window-trailing-edge
            (adjust-window-trailing-edge win delta (not vertical))
          (error 
           ;; Strategy 2: Select window first, then resize
           (condition-case err2
               (with-selected-window win
                 (window-resize win delta (not vertical)))
             (error 
              ;; Strategy 3: Use shrink/enlarge commands with selected window
              (condition-case err3
                  (with-selected-window win
                    (if vertical
                        (if (> delta 0)
                            (enlarge-window delta)
                          (shrink-window (- delta)))
                      (if (> delta 0)
                          (enlarge-window-horizontally delta)
                        (shrink-window-horizontally (- delta)))))
                (error
                 ;; Strategy 4: Try with ignore flag to bypass size constraints
                 (condition-case err4
                     (with-selected-window win
                       (window-resize win delta (not vertical) t))
                   (error 
                    (kairoam--warn "All resize strategies failed for window %s: %s" 
                                   (prin1-to-string win) 
                                   (error-message-string err4))))))))))))))

(defun kairoam--distribute-sizes ()
  "Compute and set sizes for all tracked windows based on layout mode.
In laptop mode: distributes widths horizontally.
In mobile mode: distributes heights vertically."
  (kairoam--cleanup-dead)
  (let* ((entries kairoam--registry)
         (expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) entries))
         (folded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'folded)) entries))
         (mobile-mode (eq kairoam-layout-mode 'mobile))
         (frame-size (if mobile-mode (frame-height) (frame-width)))
         (folded-size (if mobile-mode kairoam-folded-height kairoam-folded-width))
         (folded-total (* (length folded) folded-size))
         (available (max 1 (- frame-size folded-total)))
         (nexp (max 1 (length expanded)))
         (per-expanded (max 10 (floor (/ available nexp))))) ;; target size for expanded windows
    
    ;; First pass: Force folded windows to their exact size
    (dolist (s folded)
      (let ((win (kairoam-window-window s)))
        (when (and (windowp win) (window-live-p win))
          (let ((attempts 0)
                (current-size (if mobile-mode 
                                  (window-height win)
                                (window-width win))))
            (while (and (< attempts 3)
                        (/= current-size folded-size))
              (kairoam--resize-window-to win folded-size mobile-mode)
              (setq current-size (if mobile-mode 
                                     (window-height win)
                                   (window-width win)))
              (setq attempts (1+ attempts)))))))
    
    ;; Second pass: Resize expanded windows and ensure equal distribution
    (let ((remaining-size available)
          (remaining-windows (length expanded)))
      (dolist (s expanded)
        (let* ((win (kairoam-window-window s))
               (target-size (if (= remaining-windows 1)
                                remaining-size
                              per-expanded)))
          (when (and (windowp win) (window-live-p win))
            (kairoam--resize-window-to win target-size mobile-mode)
            (setq remaining-size (- remaining-size target-size))
            (setq remaining-windows (1- remaining-windows))))))
    
    ;; Third pass: Fine-tune expanded windows to ensure they're actually equal
    (when (> (length expanded) 1)
      (let* ((actual-sizes (mapcar (lambda (s) 
                                     (let ((w (kairoam-window-window s)))
                                       (if mobile-mode
                                           (window-height w)
                                         (window-width w))))
                                   expanded))
             (avg-size (/ (apply #'+ actual-sizes) (length actual-sizes))))
        ;; If sizes vary too much, try to equalize them
        (when (> (- (apply #'max actual-sizes) (apply #'min actual-sizes)) 2)
          (dolist (s expanded)
            (let ((win (kairoam-window-window s)))
              (when (and (windowp win) (window-live-p win))
                (kairoam--resize-window-to win avg-size mobile-mode)))))))
    
    ;; Final pass: Double-check folded windows stayed at minimum size
    (dolist (s folded)
      (let ((win (kairoam-window-window s)))
        (when (and (windowp win) (window-live-p win))
          (let ((current-size (if mobile-mode
                                  (window-height win)
                                (window-width win))))
            (when (/= current-size folded-size)
              (kairoam--resize-window-to win folded-size mobile-mode))))))
    
    (kairoam--info "Distributed sizes (%s mode): expanded=%d folded=%d frame=%d per=%d"
                   (if mobile-mode "mobile" "laptop")
                   (length expanded) (length folded) frame-size per-expanded)))


;;; Folding / expanding

(defun kairoam--fold-window-internal (win)
  "Internal: Fold WIN without triggering redistribution. Returns the state struct."
  (let* ((s (kairoam--find-by-window win))
         (buf (window-buffer win)))
    ;; ensure tracked
    (unless s (setq s (kairoam--register-new win buf (kairoam--registry-count))))
    ;; set state
    (setf (kairoam-window-state s) 'folded)
    ;; Save and disable line numbers
    (with-current-buffer buf
      (setf (kairoam-window-line-numbers-mode-state s) 
            (if (bound-and-true-p display-line-numbers-mode) t
              (if display-line-numbers t nil)))
      (setq-local display-line-numbers nil))
    ;; overlay
    (when (kairoam-window-overlay s)
      (ignore-errors (delete-overlay (kairoam-window-overlay s))))
    (let ((title (kairoam--buffer-title buf)))
      (setf (kairoam-window-overlay s) (kairoam--make-title-overlay buf title)))
    (kairoam--info "Folded window pos=%s title=%s" (kairoam-window-position s) (kairoam--buffer-title buf))
    s))

(defun kairoam-fold-window (&optional win)
  "Fold WIN (defaults to selected-window). Create vertical title overlay and shrink width."
  (interactive)
  (let* ((win (or win (selected-window)))
         (s (kairoam--fold-window-internal win)))
    ;; resize and distribute
    (kairoam--distribute-sizes)
    s))

(defun kairoam-expand-window (&optional win)
  "Expand WIN (defaults to selected-window). Remove overlay and mark expanded.
Enforces max-expanded-windows limit by folding farthest windows if needed."
  (interactive)
  (let* ((win (or win (selected-window)))
         (s (kairoam--find-by-window win))
         (buf (window-buffer win)))
    (unless s (user-error "Window not tracked by kairoam"))
    ;; Mark as expanded
    (setf (kairoam-window-state s) 'expanded)
    ;; Restore line numbers to their original state
    (with-current-buffer buf
      (let ((saved-state (kairoam-window-line-numbers-mode-state s)))
        (when saved-state
          (setq-local display-line-numbers (if (eq saved-state t) t nil)))))
    ;; Remove ALL overlays to ensure buffer content is visible
    (when (kairoam-window-overlay s)
      (delete-overlay (kairoam-window-overlay s))
      (setf (kairoam-window-overlay s) nil))
    (with-current-buffer buf
      (kairoam--remove-title-overlay buf)
      ;; Force window to show buffer content
      (set-window-buffer win buf))
    (kairoam--info "Expanded window pos=%s title=%s" (kairoam-window-position s) (kairoam--buffer-title buf))
    ;; Apply max-expanded rule (this does batch folding without redistribution)
    (kairoam--apply-max-expanded-rule (kairoam-window-position s))
    ;; Single redistribution after all state changes are complete
    (kairoam--distribute-sizes)
    ;; Select the expanded window
    (select-window win)
    s))


;;; Smart-folding algorithm (distance-based)

(defun kairoam--farthest-expanded-from (pos)
  "Return the kairoam-window struct (expanded) farthest from POS, or nil."
  (let ((expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) kairoam--registry))
        farthest bestd)
    (dolist (s expanded)
      (let* ((p (kairoam-window-position s))
             (d (abs (- p pos))))
        (when (or (null bestd) (> d bestd))
          (setq bestd d farthest s))))
    farthest))

(defun kairoam--apply-max-expanded-rule (trigger-pos)
  "Ensure no more than `kairoam-max-expanded-windows' expanded windows. Fold farthest ones.
Returns t if any windows were folded, nil otherwise."
  (let ((expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) kairoam--registry))
        (folded-any nil))
    (when (> (length expanded) kairoam-max-expanded-windows)
      (let ((excess (- (length expanded) kairoam-max-expanded-windows)))
        (dotimes (_ excess)
          (let ((f (kairoam--farthest-expanded-from trigger-pos)))
            (when f
              ;; Use internal fold to avoid redistribution until all folding is done
              (kairoam--fold-window-internal (kairoam-window-window f))
              (setq folded-any t))))))
    folded-any))


;;; Opening notes and smart insertion

(defun kairoam--open-node-at-position (node position)
  "Open org-roam NODE at POSITION (insert at current+1 semantics). Returns new window."
  (unless node (user-error "Node missing"))
  (let* ((file (if (fboundp 'org-roam-node-file) (org-roam-node-file node)
                 (error "org-roam node-file accessor missing")))
         (buf (find-file-noselect file))
         ;; reference window: if inserting at pos>0, use window at pos-1 as anchor, else use selected-window
         (ref-win (if (and (> position 0)
                           (< (1- position) (kairoam--registry-count)))
                      (kairoam-window-window (nth (1- position) kairoam--registry))
                    (selected-window)))
         ;; split direction based on layout mode
         (split-dir (if (eq kairoam-layout-mode 'mobile) 'below 'right))
         new-win)
    (setq new-win (split-window ref-win nil split-dir))
    (with-selected-window new-win
      (switch-to-buffer buf))
    (kairoam--register-new new-win buf position)
    new-win))

(defun kairoam--open-node-with-smart-folding (node pos trigger-pos)
  "Open NODE at pos and apply smart folding using trigger-pos. 
If node's buffer is already open in a kairoam window, expand that window instead."
  (let* ((file (if (fboundp 'org-roam-node-file) 
                   (org-roam-node-file node)
                 (error "org-roam node-file accessor missing")))
         (buf (find-file-noselect file))
         (existing (kairoam--find-by-buffer buf)))
    (if existing
        ;; Buffer already tracked - just expand it and select it
        (progn
          (kairoam--info "Buffer %s already open at pos %d, expanding it" 
                         (buffer-name buf) (kairoam-window-position existing))
          (let ((win (kairoam-window-window existing)))
            (when (eq (kairoam-window-state existing) 'folded)
              (kairoam-expand-window win))
            (select-window win)
            win))
      ;; Not already open - create new window (starts as expanded)
      (let ((new (kairoam--open-node-at-position node pos)))
        ;; Apply max-expanded rule BEFORE counting the new window
        ;; Use the new position as trigger to keep it expanded
        (kairoam--apply-max-expanded-rule pos)
        (kairoam--distribute-sizes)
        ;; Make sure the new window stays expanded and visible
        (with-selected-window new
          (kairoam--remove-title-overlay buf))
        new))))

;;; Public interactive: open via consult or org-roam

(defun kairoam-open-note-to-right ()
  "Interactive: open a node to the right/below current window (based on layout mode)."
  (interactive)
  (kairoam--cleanup-dead)
  (let* ((cur-win (selected-window))
         (cur-pos (kairoam--position-of-window cur-win)))
    (unless cur-pos
      ;; If current not tracked, start a new sequence with current at 0
      (kairoam--register-new cur-win (window-buffer cur-win) 0)
      (setq cur-pos 0))
    (let ((new-pos (1+ cur-pos)) node)
      (condition-case _err
          (cond
           ((fboundp 'consult-org-roam-file)
            (setq node (consult-org-roam-file)))
           (t
            (setq node (org-roam-node-read))))
        (error (user-error "Failed to select node")))
      (when node
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))

(defun kairoam-open-note-to-left ()
  "Open a node to the left/above current window (based on layout mode)."
  (interactive)
  (kairoam--cleanup-dead)
  (let* ((cur-win (selected-window))
         (cur-pos (kairoam--position-of-window cur-win)))
    (unless cur-pos
      (kairoam--register-new cur-win (window-buffer cur-win) 0)
      (setq cur-pos 0))
    (let ((new-pos cur-pos) node)
      (condition-case _err
          (cond
           ((fboundp 'consult-org-roam-file)
            (setq node (consult-org-roam-file)))
           (t
            (setq node (org-roam-node-read))))
        (error (user-error "Failed to select node")))
      (when node
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))

(defun kairoam-open-at-point ()
  "Open org-roam link at point (id link) to the right of current."
  (interactive)
  (kairoam--cleanup-dead)
  (let ((ctx (condition-case nil (org-element-context) (error nil))))
    (unless (and ctx (eq (org-element-type ctx) 'link) (string= (org-element-property :type ctx) "id"))
      (user-error "No org id link at point"))
    (let* ((id (org-element-property :path ctx))
           (node (condition-case nil (org-roam-node-from-id id) (error nil))))
      (unless node (user-error "Could not find node for id %s" id))
      (let* ((cur-pos (or (kairoam--position-of-window (selected-window))
                          (progn (kairoam--register-new (selected-window) (current-buffer) 0) 0)))
             (new-pos (1+ cur-pos)))
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))


;;; Utilities / debug / health

(defun kairoam-debug ()
  "Show simple debug info in message and log buffer."
  (interactive)
  (kairoam--cleanup-dead)
  (let ((lines (mapcar (lambda (s)
                         (format "pos=%d state=%s buf=%s win=%s"
                                 (kairoam-window-position s)
                                 (kairoam-window-state s)
                                 (kairoam--buffer-title (kairoam-window-buffer s))
                                 (prin1-to-string (kairoam-window-window s))))
                       kairoam--registry)))
    (kairoam--info "=== kairoam-debug begin ===")
    (dolist (l lines) (kairoam--info "%s" l))
    (kairoam--info "=== kairoam-debug end ===")
    (when lines (message "kairoam: %s" (string-join (cl-subseq lines 0 (min 4 (length lines))) " | ")))))

(defun kairoam-health-check ()
  "Run basic sanity checks and attempt repairs."
  (interactive)
  ;; ensure limited number of entries
  (kairoam--cleanup-dead)
  (kairoam--rebuild-positions)
  (kairoam--distribute-sizes)
  (message "kairoam: health-check complete"))


;;; Advice for seamless integration with Doom's +org/dwim-at-point

(defun kairoam--advice-dwim-at-point (orig-fn &optional arg)
  "Advice for +org/dwim-at-point to use kairoam for ID links when kairoam-mode is active."
  (if (and kairoam-mode
           (let ((ctx (ignore-errors (org-element-context))))
             (and ctx 
                  (eq (org-element-type ctx) 'link)
                  (string= (org-element-property :type ctx) "id"))))
      ;; We're in kairoam-mode and on an ID link - use kairoam's handler
      (kairoam-open-at-point)
    ;; Otherwise use the original function
    (funcall orig-fn arg)))

(defun kairoam--advice-org-open-at-mouse (orig-fn &optional arg)
  "Advice for org-open-at-mouse to use kairoam for ID links when kairoam-mode is active."
  (if (and kairoam-mode
           (let ((ctx (ignore-errors (org-element-context))))
             (and ctx 
                  (eq (org-element-type ctx) 'link)
                  (string= (org-element-property :type ctx) "id"))))
      ;; We're in kairoam-mode and on an ID link - use kairoam's handler
      (kairoam-open-at-point)
    ;; Otherwise use the original function
    (funcall orig-fn arg)))
;;; Minor mode & keymap

(defvar kairoam-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "C-c k r") #'kairoam-open-note-to-right)
    (define-key m (kbd "C-c k l") #'kairoam-open-at-point)
    (define-key m (kbd "C-c k f") #'kairoam-fold-window)
    (define-key m (kbd "C-c k e") #'kairoam-expand-window)
    (define-key m (kbd "C-c k d") #'kairoam-debug)
    (define-key m (kbd "C-c k t") #'kairoam-toggle-layout-mode)
    (define-key m (kbd "C-c k m") #'kairoam-mobile-mode)
    (define-key m (kbd "C-c k L") #'kairoam-laptop-mode)
    (define-key m (kbd "C-c k R") #'kairoam-reset)
    (define-key m (kbd "C-c k K") #'kairoam-kill-all-buffers)
    m)
  "Keymap for `kairoam-mode'.")

;;;###autoload
(define-minor-mode kairoam-mode
  "Toggle Kairoam evergreen note layout mode."
  :global t
  :lighter " kairoam"
  :keymap kairoam-mode-map
  (if kairoam-mode
      (progn
        (kairoam--info "kairoam-mode enabled")
        ;; Install advice for +org/dwim-at-point if it exists
        (when (fboundp '+org/dwim-at-point)
          (advice-add '+org/dwim-at-point :around #'kairoam--advice-dwim-at-point))
        (when (fboundp 'org-open-at-mouse)
          (advice-add 'org-open-at-mouse :around #'kairoam--advice-org-open-at-mouse))
        ;; auto-track current buffer if it's an org-roam file
        (when (and (buffer-file-name)
                   (bound-and-true-p org-roam-directory)
                   (string-prefix-p (expand-file-name org-roam-directory)
                                    (expand-file-name (or (buffer-file-name) ""))))
          (kairoam--register-new (selected-window) (current-buffer) 0)
          (kairoam--distribute-sizes)))
    (kairoam--info "kairoam-mode disabled")
    ;; Remove advice when disabling mode
    (when (fboundp '+org/dwim-at-point)
      (advice-remove '+org/dwim-at-point #'kairoam--advice-dwim-at-point))
    (when (fboundp 'org-open-at-mouse)
      (advice-remove 'org-open-at-mouse #'kairoam--advice-org-open-at-mouse))
    ;; Restore line numbers and cleanup overlays
    (dolist (s kairoam--registry)
      ;; Restore line numbers for each buffer
      (let ((buf (kairoam-window-buffer s))
            (saved-state (kairoam-window-line-numbers-mode-state s)))
        (when (and buf (buffer-live-p buf) saved-state)
          (with-current-buffer buf
            (setq-local display-line-numbers 
                        (if (eq saved-state t) t nil)))))
      ;; Remove overlays
      (when (kairoam-window-overlay s)
        (ignore-errors (delete-overlay (kairoam-window-overlay s)))))
    (kairoam--registry-reset)))

(defun kairoam--set-layout-mode (new-mode)
  "Internal function to set layout mode to NEW-MODE and reconfigure windows."
  (unless (memq new-mode '(laptop mobile))
    (error "Invalid layout mode: %s" new-mode))
  
  (if (eq kairoam-layout-mode new-mode)
      (message "Already in %s mode" new-mode)
    (let ((old-mode kairoam-layout-mode))
      ;; Set new mode
      (setq kairoam-layout-mode new-mode)
      
      ;; Save window configuration
      (let ((windows-info (mapcar (lambda (s)
                                    (cons (kairoam-window-buffer s)
                                          (kairoam-window-state s)))
                                  kairoam--registry)))
        ;; Reset windows
        (delete-other-windows)
        
        ;; Clear registry but keep mode active
        (kairoam--registry-reset)
        
        ;; Recreate windows in new layout
        (when windows-info
          (let ((first-buf (caar windows-info))
                (prev-win nil))
            ;; Start with first buffer
            (switch-to-buffer first-buf)
            (kairoam--register-new (selected-window) first-buf 0)
            (setq prev-win (selected-window))
            
            ;; Add remaining windows - split from the previous window, not selected
            (cl-loop for (buf . state) in (cdr windows-info)
                     for pos from 1
                     do (let ((new-win (split-window prev-win nil 
                                                     (if (eq kairoam-layout-mode 'mobile) 
                                                         'below 'right))))
                          (with-selected-window new-win
                            (switch-to-buffer buf))
                          (kairoam--register-new new-win buf pos)
                          (setq prev-win new-win)
                          ;; Restore fold state
                          (when (eq state 'folded)
                            (kairoam--fold-window-internal new-win)))))
          
          ;; Apply sizing - this should properly resize all windows
          (kairoam--distribute-sizes)))
      
      (message "Kairoam layout mode changed from %s to %s" 
               old-mode kairoam-layout-mode))))

(defun kairoam-toggle-layout-mode ()
  "Toggle between laptop (side-by-side) and mobile (top-bottom) layout modes."
  (interactive)
  (kairoam--set-layout-mode (if (eq kairoam-layout-mode 'mobile) 'laptop 'mobile)))

(defun kairoam-mobile-mode ()
  "Switch to mobile layout mode (top-bottom splits)."
  (interactive)
  (kairoam--set-layout-mode 'mobile))

(defun kairoam-laptop-mode ()
  "Switch to laptop layout mode (side-by-side splits)."
  (interactive)
  (kairoam--set-layout-mode 'laptop))

(defun kairoam-auto-detect-mode ()
  "Auto-detect and set the appropriate layout mode based on frame dimensions."
  (interactive)
  (let* ((width (frame-width))
         (height (frame-height))
         (aspect-ratio (/ (float width) height))
         (new-mode (if (< aspect-ratio 1.0) 'mobile 'laptop)))
    (when (not (eq kairoam-layout-mode new-mode))
      (kairoam--set-layout-mode new-mode)
      (message "Auto-detected %s mode (width: %d, height: %d, ratio: %.2f)"
               new-mode width height aspect-ratio))))

(defun kairoam-reset (&optional kill-buffers)
  "Reset all note windows to single expanded view and disable kairoam-mode.
With prefix arg or if KILL-BUFFERS is non-nil, also kill all kairoam-tracked buffers."
  (interactive "P")
  ;; Save buffers list before resetting
  (let ((buffers-to-kill (when kill-buffers
                           (mapcar #'kairoam-window-buffer kairoam--registry))))
    ;; Disable mode (this restores line numbers)
    (kairoam-mode -1)
    ;; Reset window configuration
    (delete-other-windows)
    (when (fboundp 'org-show-all)
      (ignore-errors (org-show-all)))
    ;; Kill buffers if requested
    (when kill-buffers
      (dolist (buf buffers-to-kill)
        (when (and buf (buffer-live-p buf))
          (kill-buffer buf)))
      (message "Kairoam reset - mode disabled and %d buffers killed" 
               (length buffers-to-kill)))
    (unless kill-buffers
      (message "Kairoam layout reset and mode disabled."))))

(defun kairoam-kill-all-buffers ()
  "Kill all buffers tracked by kairoam and reset."
  (interactive)
  (kairoam-reset t))

(defun kairoam-balance ()
  "Balance all kairoam windows according to their state (folded/expanded).
Fixes any window sizing issues and ensures proper distribution."
  (interactive)
  (when kairoam-mode
    ;; Clean up any dead windows first
    (kairoam--cleanup-dead)
    
    ;; Re-apply overlays for folded windows (in case they got messed up)
    (dolist (s kairoam--registry)
      (when (eq (kairoam-window-state s) 'folded)
        (let* ((win (kairoam-window-window s))
               (buf (kairoam-window-buffer s)))
          (when (and win (window-live-p win) buf (buffer-live-p buf))
            ;; Ensure overlay is properly set
            (when (kairoam-window-overlay s)
              (ignore-errors (delete-overlay (kairoam-window-overlay s))))
            (let ((title (kairoam--buffer-title buf)))
              (setf (kairoam-window-overlay s) (kairoam--make-title-overlay buf title)))))))
    
    ;; Force redistribute all window sizes
    (kairoam--distribute-sizes)
    
    ;; Ensure expanded windows are properly shown
    (dolist (s kairoam--registry)
      (when (eq (kairoam-window-state s) 'expanded)
        (let* ((win (kairoam-window-window s))
               (buf (kairoam-window-buffer s)))
          (when (and win (window-live-p win) buf (buffer-live-p buf))
            ;; Force redisplay of buffer content
            (with-current-buffer buf
              (kairoam--remove-title-overlay buf))
            (set-window-buffer win buf)))))
    
    (kairoam--info "Balanced %d windows (%d expanded, %d folded)"
                   (length kairoam--registry)
                   (length (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) 
                                             kairoam--registry))
                   (length (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'folded)) 
                                             kairoam--registry)))
    (message "Kairoam windows balanced")))

(defun kairoam-toggle ()
  "Toggle kairoam mode if not active else reset"
  (interactive)
  (if (eq kairoam-mode t)
      (kairoam-reset)
    (kairoam-mode)))

(provide 'kairoam-notes)

;; Beancount helper

;;; beancount_helper.el --- Consult-based Beancount Transaction Entry -*- lexical-binding: t; -*-

;;; Commentary:
;; Streamlined beancount transaction entry using consult prompts

;;; Code:

(require 'cl-lib)

;; Only require these if available
(require 'consult nil t)
(require 'beancount nil t)

(defvar beancount-helper-file "/sdcard/org/personal.beancount"
  "Path to the main beancount file to read from and write to.")

(defvar beancount-helper-default-currency "NPR"
  "Default currency for transactions.")

(defvar beancount-helper-common-payees
  '("Bhatbhateni" "Salesberry" "BigMart" "Foodmandu" "Pathao" "InDrive" 
    "Daraz" "Gyapu" "CG Digital" "Ncell" "NTC" "WorldLink" "Subisu"
    "KFC" "Pizza Hut" "Burger House" "Cafe" "Restaurant" "Pharmacy"
    "Hospital" "Clinic" "Lab" "Uber" "Sajilo Marmat" "Electricity" "Water")
  "Common payees for quick selection.")

(defvar beancount-helper-persons
  '("MY" "MOM" "DAD" "SUS" "SAJ")
  "Family members for investment accounts.")

(defvar beancount-helper-stock-types
  '("Regular" "IPO" "FPO")
  "Types of stock purchases.")

(defvar beancount-helper-section-markers
  '((expenses . "^\\* Expenses")
    (income . "^\\* Taxable Investments")
    (investments . "^\\* Taxable Investments")
    (banking . "^\\* Banking")
    (cash . "^\\* Cash")
    (credit-cards . "^\\* Credit-Cards"))
  "Regex patterns to find section markers in the beancount file.")

(defun beancount-helper--get-all-accounts ()
  "Get all accounts from the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((accounts '()))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ open \\([A-Za-z:]+\\)" nil t)
          (push (match-string 1) accounts)))
      (nreverse accounts))))

(defun beancount-helper--account-exists-p (account)
  "Check if ACCOUNT exists in the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (save-excursion
      (goto-char (point-min))
      (re-search-forward (format "^[0-9-]+ open %s" (regexp-quote account)) nil t))))

(defun beancount-helper--get-section-name (account)
  "Get the appropriate section name for ACCOUNT."
  (let* ((account-type (car (split-string account ":")))
         (account-parts (split-string account ":")))
    (cond
     ((string= account-type "Expenses") "Expenses")
     ((string= account-type "Income") "Taxable Investments")
     ((string= account-type "Assets")
      (cond
       ;; ETrade accounts go to Taxable Investments
       ((and (>= (length account-parts) 3)
             (string= (nth 2 account-parts) "ETrade"))
        "Taxable Investments")
       ;; Cash/Esewa/Khalti go to Cash section
       ((string-match-p "Cash\\|Esewa\\|Khalti" account) "Cash")
       ;; Default assets go to Banking
       (t "Banking")))
     ((string= account-type "Liabilities") "Credit-Cards")
     (t "Banking"))))

(defun beancount-helper--find-section-bounds (section-name)
  "Find the start and end positions of SECTION-NAME in the beancount file.
Returns (START . END) where START is after the section header
and END is before the next section or EOF."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward (format "^\\* %s" (regexp-quote section-name)) nil t)
        (let ((section-start (progn (forward-line 1) (point)))
              (section-end (if (re-search-forward "^\\* " nil t)
                               (progn (beginning-of-line) (point))
                             (point-max))))
          (cons section-start section-end))))))

(defun beancount-helper--create-account (account)
  "Create a new ACCOUNT in the appropriate section."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let* ((section-name (beancount-helper--get-section-name account))
           (bounds (beancount-helper--find-section-bounds section-name)))
      (if bounds
          (save-excursion
            ;; Go to start of section (right after header)
            (goto-char (car bounds))
            ;; Skip any existing blank lines
            (while (and (looking-at "^\\s-*$") 
                        (< (point) (cdr bounds)))
              (forward-line 1))
            ;; Insert the new account
            (insert (format "%s open %s\n" (format-time-string "%Y-%m-%d") account))
            (save-buffer)
            (message "Created account: %s in section %s" account section-name))
        ;; Section doesn't exist - create it
        (save-excursion
          (goto-char (point-max))
          (insert (format "\n* %s\n\n%s open %s\n" 
                          section-name
                          (format-time-string "%Y-%m-%d")
                          account))
          (save-buffer)
          (message "Created section %s and account: %s" section-name account))))))

(defun beancount-helper--get-payees ()
  "Get all unique payees from the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((payees beancount-helper-common-payees))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ \\*\\(\\|!\\) \"\\([^\"]+\\)\"" nil t)
          (let ((payee (match-string 2)))
            (unless (member payee payees)
              (push payee payees)))))
      payees)))

(defun beancount-helper--find-insertion-point (date &optional section-name)
  "Find the appropriate insertion point for a transaction with DATE.
Optional SECTION-NAME to specify which section to insert into."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let* ((section (or section-name "Taxable Investments"))
           (bounds (beancount-helper--find-section-bounds section)))
      (if bounds
          (save-excursion
            (goto-char (cdr bounds))
            (skip-chars-backward " \t\n")
            (unless (bolp) (forward-line 1))
            (point))
        ;; Fallback to end of file
        (save-excursion
          (goto-char (point-max))
          (skip-chars-backward " \t\n")
          (unless (bolp) (forward-line 1))
          (point))))))

(defun beancount-helper--insert-transaction (transaction date &optional section-name)
  "Insert TRANSACTION at the appropriate point for DATE in the file.
Optional SECTION-NAME to specify which section to insert into."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (goto-char (beancount-helper--find-insertion-point date section-name))
    (insert "\n" transaction)
    (save-buffer)))

(defun beancount-helper--create-commodity (ticker)
  "Create a commodity for TICKER if needed."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (unless (save-excursion
              (goto-char (point-min))
              (re-search-forward (format "^[0-9-]+ commodity %s" ticker) nil t))
      (when (y-or-n-p (format "Create commodity %s? " ticker))
        (let ((bounds (beancount-helper--find-section-bounds "Commodities")))
          (if bounds
              (save-excursion
                (goto-char (car bounds))
                ;; Skip existing commodities to add at end of section content
                (while (and (not (looking-at "^\\s-*$\\|^\\*"))
                            (< (point) (cdr bounds)))
                  (forward-line 1))
                (insert (format "\n%s commodity %s\n  name: \"%s Stock\"\n" 
                                (format-time-string "%Y-%m-%d") ticker ticker))
                (save-buffer))
            ;; Create Commodities section if missing
            (save-excursion
              (goto-char (point-min))
              (if (re-search-forward "^\\* Options" nil t)
                  (progn
                    (if (re-search-forward "^\\* " nil t)
                        (beginning-of-line)
                      (goto-char (point-max)))
                    (insert (format "\n* Commodities\n\n%s commodity %s\n  name: \"%s Stock\"\n"
                                    (format-time-string "%Y-%m-%d") ticker ticker)))
                ;; Fallback
                (goto-char (point-min))
                (insert (format "* Commodities\n\n%s commodity %s\n  name: \"%s Stock\"\n\n"
                                (format-time-string "%Y-%m-%d") ticker ticker)))
              (save-buffer))))))))

(defun beancount-helper--format-amount (amount currency)
  "Format AMOUNT with CURRENCY, handling negative values."
  (if (string-match "^-" amount)
      (format "%s %s" amount currency)
    (format "%s %s" amount currency)))

;;;###autoload
(defun beancount-helper-add-transaction ()
  "Add a new transaction with consult prompts."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (payee (completing-read "Payee: " (beancount-helper--get-payees) nil nil))
         (description (read-string "Description (optional): " ""))
         (all-accounts (beancount-helper--get-all-accounts))
         (from-account (completing-read "From account: " all-accounts nil nil))
         (to-account (completing-read "To account: " all-accounts nil nil))
         (amount (read-string "Amount: "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil beancount-helper-default-currency)))
    
    ;; Create accounts if they don't exist
    (unless (beancount-helper--account-exists-p from-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " from-account))
        (beancount-helper--create-account from-account)))
    
    (unless (beancount-helper--account-exists-p to-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " to-account))
        (beancount-helper--create-account to-account)))
    
    ;; Build transaction string
    (let ((transaction (format "%s * \"%s\"%s\n  %s  %s\n  %s  %s\n"
                               date
                               payee
                               (if (equal description "") "" (format " \"%s\"" description))
                               from-account
                               (beancount-helper--format-amount (format "-%s" amount) currency)
                               to-account
                               (beancount-helper--format-amount amount currency))))
      
      ;; Insert at appropriate position in the file
      (beancount-helper--insert-transaction transaction date)
      (message "Transaction added successfully!"))))

(defun beancount-helper--get-person-accounts ()
  "Get all person expense accounts from the file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((persons '()))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ open Expenses:Person:\\([A-Za-z]+\\)" nil t)
          (push (match-string 1) persons)))
      (nreverse persons))))

(defun beancount-helper--create-person-account (person)
  "Create a person expense account for PERSON."
  (let ((account (format "Expenses:Person:%s" person)))
    (unless (beancount-helper--account-exists-p account)
      (beancount-helper--create-account account))))

;;;###autoload
(defun beancount-helper-add-expense ()
  "Quick expense entry with optional split functionality."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (total-amount (string-to-number (read-string "Amount spent: ")))
         (payee (completing-read "Payee/Store: " (beancount-helper--get-payees) nil nil))
         (description (read-string "Description (optional): " ""))
         (expense-categories '("Expenses:Food:Outdoors"
                               "Expenses:Food:Groceries"
                               "Expenses:Food:Gatherings"
                               "Expenses:Travel"
                               "Expenses:Home:Internet"
                               "Expenses:Home:Mobile"
                               "Expenses:Ownership:Clothing"
                               "Expenses:Ownership:Electronics"
                               "Expenses:Medicine"
                               "Expenses:RandomFun"
                               "Expenses:HouseCommon"))
         (expense-account (completing-read "Expense type: " expense-categories nil nil))
         (payment-accounts '("Assets:NP:MY:Cash"
                             "Assets:NP:MY:Esewa"
                             "Assets:NP:MY:Khalti"
                             "Assets:NP:MY:RBBChecking"
                             "Assets:NP:MY:SBLChecking"
                             "Liabilities:NP:SBL"))
         (from-account (completing-read "Paid with: " payment-accounts nil nil))
         (split-p (y-or-n-p "Split this expense? ")))
    
    (if (not split-p)
        ;; Regular expense without split
        (let ((transaction (format "%s * \"%s\"%s\n  %s  -%s NPR\n  %s  %s NPR\n"
                                   date
                                   payee
                                   (if (equal description "") "" (format " \"%s\"" description))
                                   from-account
                                   (format "%.2f" total-amount)
                                   expense-account
                                   (format "%.2f" total-amount))))
          (beancount-helper--insert-transaction transaction date "Expenses")
          (message "Expense added: %.2f NPR at %s" total-amount payee))
      
      ;; Split expense among people
      (let* ((existing-persons (beancount-helper--get-person-accounts))
             (all-persons (append existing-persons 
                                  '("Family" "Sajja" "Sushma" "Momma" "Dad" 
                                    "Aashish" "Shambhu" "Aatish" "Shishir")))
             ;; Use completing-read-multiple for comma-separated selection
             (selected-persons (completing-read-multiple
                                "Select people to split with (comma-separated): "
                                all-persons nil nil)))
        
        ;; Create person accounts for new people
        (dolist (person selected-persons)
          (unless (member person existing-persons)
            (when (y-or-n-p (format "Create new person account for %s? " person))
              (beancount-helper--create-person-account person))))
        
        (if (null selected-persons)
            (message "No people selected for split. Cancelling.")
          ;; Calculate split
          (let* ((num-people (1+ (length selected-persons))) ; +1 for yourself
                 (share-amount (/ total-amount num-people))
                 (my-share share-amount)
                 (transaction-lines (list (format "%s * \"%s\"%s"
                                                  date payee
                                                  (if (equal description "") 
                                                      " \"Split expense\""
                                                    (format " \"%s (split)\"" description))))))
            
            ;; Payment line
            (push (format "  %s  -%.2f NPR" from-account total-amount) transaction-lines)
            
            ;; My share of the expense
            (push (format "  %s  %.2f NPR" expense-account my-share) transaction-lines)
            
            ;; Each person owes their share
            (dolist (person selected-persons)
              (push (format "  Expenses:Person:%s  %.2f NPR" person share-amount) transaction-lines))
            
            (let ((transaction (mapconcat 'identity (nreverse transaction-lines) "\n")))
              (beancount-helper--insert-transaction (concat transaction "\n") date "Expenses")
              (message "Split expense: %.2f NPR total, %.2f NPR each among %d people" 
                       total-amount share-amount num-people))))))))

;;;###autoload
(defun beancount-helper-add-income ()
  "Quick income entry."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (amount (read-string "Income amount: "))
         (source (read-string "Income source: "))
         (income-accounts '("Income:NP:Nepali:Freelancing"
                            "Income:US:Foreign:Freelancing"
                            "Income:NP:Nepali:HouseCommon"))
         (income-account (completing-read "Income type: " income-accounts nil nil))
         (deposit-accounts '("Assets:NP:MY:RBBChecking"
                             "Assets:NP:MY:SBLChecking"
                             "Assets:US:MY:Deel"
                             "Assets:NP:MY:Cash"
                             "Assets:NP:MY:Esewa"))
         (to-account (completing-read "Deposit to: " deposit-accounts nil nil))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil "NPR")))
    
    (let ((transaction (format "%s * \"%s\"\n  %s  %s %s\n  %s  -%s %s\n"
                               date
                               source
                               to-account
                               amount
                               currency
                               income-account
                               amount
                               currency)))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Income added: %s %s from %s" amount currency source))))

;;;###autoload
(defun beancount-helper-transfer ()
  "Quick transfer between accounts."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (amount (read-string "Transfer amount: "))
         (all-accounts (beancount-helper--get-all-accounts))
         (from-account (completing-read "Transfer from: " all-accounts nil nil))
         (to-account (completing-read "Transfer to: " all-accounts nil nil))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil "NPR"))
         (description (read-string "Description (optional): " "Transfer")))
    
    (let ((transaction (format "%s * \"%s\"\n  %s  -%s %s\n  %s  %s %s\n"
                               date
                               description
                               from-account
                               amount
                               currency
                               to-account
                               amount
                               currency)))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Transfer completed: %s %s from %s to %s" amount currency from-account to-account))))

;;;###autoload
(defun beancount-helper-buy-stock ()
  "Buy stock, IPO, or FPO shares with person tracking."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (stock-type (completing-read "Type: " beancount-helper-stock-types nil t nil nil "Regular"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of shares: " 
                              (if (string= stock-type "IPO") "10" "")))
         (price (read-string "Price per share: "))
         (currency (or (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR") "NPR"))
         (commission (or (read-string "Commission (default 25): " "25") "25"))
         (broker-accounts '("Assets:NP:MY:RBBChecking"
                            "Assets:NP:MY:SBLChecking"
                            "Assets:NP:MY:Cash"
                            "Assets:US:MY:Deel"))
         (cash-account (or (completing-read "Pay from account: " broker-accounts nil t) 
                           (car broker-accounts)))
         (stock-account (if (string= stock-type "Regular")
                            (format "Assets:%s:ETrade:%s:%s" 
                                    (if (string= currency "USD") "US" "NP")
                                    person ticker)
                          (format "Assets:%s:ETrade:%s:%s:%s"
                                  (if (string= currency "USD") "US" "NP")
                                  person stock-type ticker)))
         (commission-account (format "Expenses:%s:Financial:Commissions" person))
         (total (+ (* (string-to-number shares) (string-to-number price))
                   (string-to-number commission))))
    
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " stock-account))
        (beancount-helper--create-account stock-account)))
    
    ;; Create commission account if needed
    (unless (beancount-helper--account-exists-p commission-account)
      (when (y-or-n-p (format "Create %s account? " commission-account))
        (beancount-helper--create-account commission-account)))
    
    ;; Validate inputs
    (when (or (equal ticker "")
              (equal shares "")
              (equal price ""))
      (error "Ticker, shares, and price are required"))
    
    (let ((transaction (format "%s * \"Buy %sshares of %s%s\"\n  %s  -%.2f %s\n  %s  %s %s {%s %s, %s}\n  %s  %s %s\n"
                               date 
                               (if (string= stock-type "Regular") "" (concat stock-type " "))
                               ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account total currency
                               stock-account shares ticker price currency date
                               commission-account commission currency))
          (inhibit-read-only t))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Bought %s shares of %s at %s %s" shares ticker price currency))))

;;;###autoload
(defun beancount-helper-sell-stock ()
  "Sell stock shares with person and type detection."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (ticker (upcase (read-string "Stock ticker to sell: ")))
         ;; Find available lots across all persons
         (lots (beancount-helper--get-stock-lots ticker))
         (lot-strings (mapcar (lambda (lot)
                                (format "%s: %s shares @ %s %s%s (bought %s)"
                                        (nth 0 lot) ; person
                                        (nth 2 lot) ; shares
                                        (nth 3 lot) ; price
                                        (nth 4 lot) ; currency
                                        (if (nth 1 lot) (format " (%s)" (nth 1 lot)) "") ; type
                                        (nth 5 lot))) ; date
                              lots)))
    
    (if (null lots)
        (message "No lots found for %s" ticker)
      (let* ((selected-lot (completing-read "Select lot to sell: " lot-strings nil t))
             (lot-index (cl-position selected-lot lot-strings :test 'string=))
             (lot (nth lot-index lots))
             (person (nth 0 lot))
             (stock-type (nth 1 lot))
             (shares-available (nth 2 lot))
             (cost-price (nth 3 lot))
             (currency (nth 4 lot))
             (buy-date (nth 5 lot))
             (shares (read-string (format "Shares to sell (max %s): " shares-available) shares-available))
             (sell-price (read-string "Sell price per share: "))
             (commission (or (read-string "Commission (default 25): " "25") "25"))
             (cash-accounts '("Assets:NP:ETrade:Cash"
                              "Assets:NP:MY:RBBChecking"
                              "Assets:NP:MY:SBLChecking"))
             (cash-account (completing-read "Deposit to account: " cash-accounts nil t))
             (stock-account (if stock-type
                                (format "Assets:%s:ETrade:%s:%s:%s"
                                        (if (string= currency "USD") "US" "NP")
                                        person stock-type ticker)
                              (format "Assets:%s:ETrade:%s:%s"
                                      (if (string= currency "USD") "US" "NP")
                                      person ticker)))
             (commission-account (format "Expenses:%s:Financial:Commissions" person))
             (pnl-account (format "Income:%s:ETrade:%s:PnL" 
                                  (if (string= currency "USD") "US" "NP") person))
             (proceeds (- (* (string-to-number shares) (string-to-number sell-price))
                          (string-to-number commission)))
             (pnl (- (* (string-to-number shares) 
                        (- (string-to-number sell-price) (string-to-number cost-price)))
                     (string-to-number commission))))
        
        ;; Create accounts if needed
        (unless (beancount-helper--account-exists-p commission-account)
          (when (y-or-n-p (format "Create %s account? " commission-account))
            (beancount-helper--create-account commission-account)))
        
        (unless (beancount-helper--account-exists-p pnl-account)
          (when (y-or-n-p (format "Create %s account? " pnl-account))
            (beancount-helper--create-account pnl-account)))
        
        (let ((transaction (format "%s * \"Sell %sshares of %s%s\"\n  %s  -%s %s {%s %s, %s} @ %s %s\n  %s  %.2f %s\n  %s  %s %s\n  %s  %.2f %s\n"
                                   date 
                                   (if stock-type (concat stock-type " ") "")
                                   ticker
                                   (if (string= person "MY") "" (format " for %s" person))
                                   stock-account shares ticker cost-price currency buy-date sell-price currency
                                   cash-account proceeds currency
                                   commission-account commission currency
                                   pnl-account (- pnl) currency))
              (inhibit-read-only t))
          
          (beancount-helper--insert-transaction transaction date)
          (message "Sold %s shares of %s for %s - P&L: %.2f %s" shares ticker person pnl currency))))))

(defun beancount-helper--get-stock-lots (ticker)
  "Get all available lots for TICKER across all persons."
  (let ((lots '())
        ;; Match: Assets:NP:ETrade:PERSON:TYPE:TICKER or Assets:NP:ETrade:PERSON:TICKER
        (stock-pattern (format "Assets:[A-Z]+:ETrade:\\([A-Z]+\\)\\(?::\\([A-Z]+\\)\\)?:%s\\s-+\\([0-9.]+\\)\\s-+%s\\s-+{\\([0-9.]+\\)\\s-+\\([A-Z]+\\),\\s-+\\([0-9-]+\\)}"
                               ticker ticker)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward stock-pattern nil t)
        (let* ((person (match-string 1))
               (type-or-shares (match-string 2))
               (shares (if type-or-shares (match-string 3) (match-string 2)))
               (price (if type-or-shares (match-string 4) (match-string 3)))
               (currency (if type-or-shares (match-string 5) (match-string 4)))
               (date (if type-or-shares (match-string 6) (match-string 5)))
               (stock-type (when (and type-or-shares 
                                      (member type-or-shares '("IPO" "FPO")))
                             type-or-shares)))
          (push (list person stock-type shares price currency date) lots))))
    (nreverse lots)))

;;;###autoload
(defun beancount-helper-dividend ()
  "Record dividend income with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (ticker (upcase (read-string "Stock ticker (or 'PORTFOLIO' for mixed): ")))
         (amount (read-string "Dividend amount: "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (cash-account (format "Assets:%s:ETrade:%s:Cash" 
                               (if (string= currency "USD") "US" "NP") person))
         (dividend-account (format "Income:%s:ETrade:%s:Dividends"
                                   (if (string= currency "USD") "US" "NP") person)))
    
    ;; Create cash account if needed
    (unless (beancount-helper--account-exists-p cash-account)
      (when (y-or-n-p (format "Create %s account? " cash-account))
        (beancount-helper--create-account cash-account)))
    
    ;; Create dividend account if needed
    (unless (beancount-helper--account-exists-p dividend-account)
      (when (y-or-n-p (format "Create %s account? " dividend-account))
        (beancount-helper--create-account dividend-account)))
    
    (let ((transaction (format "%s * \"Dividends on %s%s\"\n  %s  %s %s\n  %s  -%s %s\n"
                               date 
                               (if (string= ticker "PORTFOLIO") "portfolio" ticker)
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account amount currency
                               dividend-account amount currency))
          (inhibit-read-only t))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Dividend recorded: %s %s from %s for %s" amount currency ticker person))))

;;;###autoload
(defun beancount-helper-bonus-shares ()
  "Record bonus shares received with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (stock-type (completing-read "Type: " '("Regular" "IPO" "FPO") nil t nil nil "Regular"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of bonus shares: "))
         (price (read-string "Price per share (0 for free bonus): " "0"))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (stock-account (if (string= stock-type "Regular")
                            (format "Assets:%s:ETrade:%s:%s" 
                                    (if (string= currency "USD") "US" "NP")
                                    person ticker)
                          (format "Assets:%s:ETrade:%s:%s:%s"
                                  (if (string= currency "USD") "US" "NP")
                                  person stock-type ticker)))
         (bonus-account (format "Income:%s:ETrade:%s:BonusShares"
                                (if (string= currency "USD") "US" "NP") person)))
    
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Create %s account? " stock-account))
        (beancount-helper--create-account stock-account)))
    
    ;; Create bonus account if needed
    (unless (beancount-helper--account-exists-p bonus-account)
      (when (y-or-n-p (format "Create %s account? " bonus-account))
        (beancount-helper--create-account bonus-account)))
    
    (let ((transaction (format "%s * \"Bonus shares of %s%s\"\n  %s  %s %s {%s %s, %s}\n  %s  -%s %s\n"
                               date ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               stock-account shares ticker price currency date
                               bonus-account
                               (format "%.2f" (* (string-to-number shares) (string-to-number price)))
                               currency))
          (inhibit-read-only t))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Bonus shares recorded: %s shares of %s for %s" shares ticker person))))

;;;###autoload
(defun beancount-helper-rights-shares ()
  "Record rights shares purchase with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of rights shares: "))
         (price (read-string "Price per share (rights price): "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (commission (or (read-string "Commission (default 25): " "25") "25"))
         (broker-accounts '("Assets:NP:MY:RBBChecking"
                            "Assets:NP:MY:SBLChecking"
                            "Assets:NP:MY:Cash"))
         (cash-account (or (completing-read "Pay from account: " broker-accounts nil t) 
                           (car broker-accounts)))
         ;; Rights shares typically go into the same structure as regular shares
         (stock-account (format "Assets:%s:ETrade:%s:RIGHTS:%s" 
                                (if (string= currency "USD") "US" "NP")
                                person ticker))
         (commission-account (format "Expenses:%s:Financial:Commissions" person))
         (total (+ (* (string-to-number shares) (string-to-number price))
                   (string-to-number commission))))
    
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " stock-account))
        (beancount-helper--create-account stock-account)))
    
    ;; Create commission account if needed
    (unless (beancount-helper--account-exists-p commission-account)
      (when (y-or-n-p (format "Create %s account? " commission-account))
        (beancount-helper--create-account commission-account)))
    
    (let ((transaction (format "%s * \"Buy RIGHTS shares of %s%s\"\n  %s  -%.2f %s\n  %s  %s %s {%s %s, %s}\n  %s  %s %s\n"
                               date ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account total currency
                               stock-account shares ticker price currency date
                               commission-account commission currency))
          (inhibit-read-only t))
      
      (beancount-helper--insert-transaction transaction date)
      (message "Rights shares recorded: %s shares of %s at %s %s for %s" 
               shares ticker price currency person))))

(provide 'beancount-helper)
;;; beancount_helper.el ends here


(defun org-agenda-add-clock-time ()
  "Add clock time to task at point in org-agenda.
Prompts for duration in minutes and optional end offset.
Example: 30 minutes duration, 5 minutes offset = clock from 35 mins ago to 5 mins ago."
  (interactive)
  (org-agenda-check-type t 'agenda 'todo 'tags 'search)
  (let* ((marker (org-get-at-bol 'org-marker))
         (duration (read-number "Minutes to clock: " 30))
         (end-offset (read-number "End how many minutes ago (0 = now): " 0))
         (end-offset (if (= end-offset 0) 1 end-offset))) ; Default to 1 minute ago if 0
    (when (and marker (> duration 0))
      (org-with-point-at marker
        (let* ((now (current-time))
               (end-time (time-subtract now (seconds-to-time (* end-offset 60))))
               (start-time (time-subtract end-time (seconds-to-time (* duration 60))))
               (start-str (format-time-string "[%Y-%m-%d %a %H:%M]" start-time))
               (end-str (format-time-string "[%Y-%m-%d %a %H:%M]" end-time))
               (hours (/ duration 60))
               (mins (% duration 60))
               (clock-entry (format "CLOCK: %s--%s =>  %2d:%02d" start-str end-str hours mins)))
          (save-excursion
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
                    (insert clock-entry "\n"))
                ;; No LOGBOOK, create one after metadata
                (progn
                  (goto-char heading-start)
                  (org-end-of-meta-data)
                  (insert ":LOGBOOK:\n")
                  (insert clock-entry "\n")
                  (insert ":END:\n")))))
          (message "Added %d minutes (from %d to %d mins ago)" 
                   duration (+ duration end-offset) end-offset))))))


;;;###autoload
(defun org-roam-dailies-goto-monday-of-week ()
  "Find the daily-note for the Monday of the current week, creating it if necessary."
  (interactive)
  (let* ((now (current-time))
         (decoded (decode-time now))
         (dow (nth 6 decoded))  ; 0=Sunday, 1=Monday, etc.
         (days-back (if (= dow 0) 6 (1- dow)))
         (monday-time (time-add now (days-to-time (- days-back)))))
    (org-roam-dailies--capture monday-time t)))

;;;###autoload
(defun org-roam-dailies-goto-monday-of-next-week ()
  "Find the daily-note for the Monday of next week, creating it if necessary."
  (interactive)
  (let* ((now (current-time))
         (decoded (decode-time now))
         (dow (nth 6 decoded))  ; 0=Sunday, 1=Monday, etc.
         (days-forward (if (= dow 0) 1 (- 8 dow)))
         (next-monday-time (time-add now (days-to-time days-forward))))
    (org-roam-dailies--capture next-monday-time t)))



(setq window-min-height 1)


;; ;; Optional: Dired binding for consistency
(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c o") #'my-dired-open-xdg))

(defun my-dired-open-xdg ()
  "Open the file at point in Dired using browse-url-xdg-open."
  (interactive)
  (let ((file (dired-get-file-for-visit)))
    (if (file-exists-p file)
        (my-open-file-xdg file)
      (message "File does not exist: %s" file))))

;; termux shell for vterm
(after! vterm
  (setq vterm-shell "/data/data/com.termux/files/usr/bin/bash"))

(defun my-org-agenda ()
  (interactive)
  (org-agenda nil "k"))

;;; Tool bar FUNCTIONS -*- lexical-binding: t; -*-
(tool-bar-mode 1)
;; (modifier-bar-mode 1)
;;;###autoload
(defun my/insert-tool-bar-icon (map icon function)
  "Insert Icon in Tool Bar."
  (keymap-set-after map (concat "<" icon ">")
    `(menu-item ,(capitalize icon) ,function
      :image
      `(image :type svg :file ,(concat "~/toolbar-assets/org-tool-bar/"
                                       ,icon ".svg")
        :height 36 :width 36))))

;; (add-hook 'org-mode-hook
;;           (lambda ()
;;             (setq-local tool-bar-map
;;                         (let ((map (make-sparse-keymap)))
;;                           (tool-bar-local-item-from-menu 'save-buffer "save" map)
;;                           (keymap-set-after (default-value 'tool-bar-map) "<separator-tasks>" menu-bar-separator)

;;                           (keymap-set-after map "<separator-1>" menu-bar-separator)
;;                           (keymap-set-after map "<separator-org>" menu-bar-separator)
;;                           (keymap-set-after map "<kairoam-toggle>"
;;                             '(menu-item "Kairoam Toggle" kairoam-toggle
;;                               :help "Toggle Kairoam mode"
;;                               :image (image :type svg :file "~/toolbar-assets/toggle-on-svgrepo-com.svg" :height 36 :width 36)))
;;                           (keymap-set-after map "<kairoam-expand>"
;;                             '(menu-item "Expand" kairoam-expand-window
;;                               :help "Expand Kairoam window"
;;                               :image (image :type svg :file "~/toolbar-assets/expand-alt-svgrepo-com.svg" :height 36 :width 36)))
;;                           (keymap-set-after map "<kairoam-fold>"
;;                             '(menu-item "Fold" kairoam-fold-window
;;                               :help "Fold Kairoam window"
;;                               :image (image :type svg :file "~/toolbar-assets/fold-svgrepo-com.svg" :height 36 :width 36)))
;;                           (keymap-set-after map "<kairoam-open-right>"
;;                             '(menu-item "Open Right" kairoam-open-note-to-right
;;                               :help "Open note to right"
;;                               :image (image :type svg :file "~/toolbar-assets/click-to-fold-svgrepo-com.svg" :height 36 :width 36)))
;;                           map))))

;; ──────────────────────────────────────────────────────────────
;; Touch-screen keyboard full control – fixed & minimal
;; ──────────────────────────────────────────────────────────────

(defvar my/keyboard-auto-show t
  "Internal: t = normal Emacs behaviour, nil = completely suppress auto keyboard.")

(defun my/touch-screen-keyboard-decide (&rest _)
  "Decide whether Emacs is allowed to show the on-screen keyboard automatically.
This is called on every tap in a writable buffer."
  my/keyboard-auto-show)

;; Critical: use `add-function' with :around so we completely override whatever
;; Emacs or other packages (Doom, etc.) might have set before or after us.
(add-function :around touch-screen-keyboard-function #'my/touch-screen-keyboard-decide)

(defun my/toggle-touch-keyboard ()
  "Toggle automatic on-screen keyboard.
When OFF → keyboard never appears on tap.
When ON  → back to normal behaviour."
  (interactive)
  (setq my/keyboard-auto-show (not my/keyboard-auto-show))
  (message "Touch keyboard auto-show → %s"
           (if my/keyboard-auto-show "ON" "OFF")))

(defun daily-review-shortcut ()
  (interactive)
  (org-capture-finalize nil "rd"))

;;; ADD TOOL BAR BUTTONS
;; It's possible add submenus in tool bar such as: <tool-bar> <copy> <COMMAND>
(when (display-graphic-p)
  (setopt tool-bar-style 'image
          tool-bar-position 'bottom)
  ;; (if (eq system-type 'android) (modifier-bar-mode t))

  ;; (tool-bar-add-item-from-menu 'undo-redo "redo" nil) ; Add Redo

  ;; (keymap-set-after (default-value 'tool-bar-map) "<undo-redo>"
  ;;   (cdr (assq 'undo-redo tool-bar-map))
  ;;   'undo)

  ;; (keymap-set-after (default-value 'tool-bar-map) "<explorer>"
  ;;   '(menu-item "Explorer" my/explorer-open
  ;;     :help "Hide/Show Side Explorer"
  ;;     :visible (or (derived-mode-p 'prog-mode)
  ;;                  (derived-mode-p 'text-mode))
  ;;     :image
  ;;     `(image :type svg :file ,(concat "~/.doom.d/toolbar-assets/tree_explorer.svg") :height 36 :width 36))
  ;;   'isearch-forward)

  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-4>"
  ;;   menu-bar-separator 'my/explorer-open) ; Add Separator

  ;; (keymap-set-after (default-value 'tool-bar-map) "<packages>"
  ;;   '(menu-item "packages" list-packages
  ;;     :help   "Show List Packages"
  ;;     :image
  ;;     `(image :type svg :file ,(concat "~/.doom.d/toolbar-assets/elpa.svg") :height 36 :width 36))
  ;;   'my/explorer-open)


  (keymap-set-after (default-value 'tool-bar-map) "<separator-19>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<separator-org-19>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<kairoam-expand>"
    '(menu-item "Expand" kairoam-expand-window
      :help "Expand Kairoam window"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/expand-alt-svgrepo-com.svg" :height 36 :width 36)))

  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-18>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<kairoam-fold>"
    '(menu-item "Fold" kairoam-fold-window
      :help "Fold Kairoam window"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/click-to-fold-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-170>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<kairoam-balance>"
    '(menu-item "Balance" kairoam-balance
      :help "Balance Kairoam windows"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/balance-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-17>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<kairoam-toggle>"
    '(menu-item "Kairoam Toggle" kairoam-toggle
      :help "Toggle Kairoam mode"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/toggle-on-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-16>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<kairoam-open-right>"
    '(menu-item "Open Right" kairoam-open-note-to-right
      :help "Open note to right"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/fold-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-15>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-15>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<random-task>"
    '(menu-item "Random Task" random-task-select
      :help "Select random task"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/random-1dice-svgrepo-com.svg" :height 48 :width 48)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-14>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-14>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<priority-task>"
    '(menu-item "Priority Task" priority-time-task-select
      :help "Select priority task"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/security-priority-solid-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-13>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-13>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<project-task>"
    '(menu-item "Project Task" consult-activate-project-task
      :help "Activate project task"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/project-presentation-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-12>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-12>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<instant-task>"
    '(menu-item "Instant Task" consult-activate-instant-task
      :help "Activate instant task"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/instant-camera-svgrepo-com.svg" :height 36 :width 36)))
  
  
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-11>" menu-bar-separator)
  ;; ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-11>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<random-piano>"
  ;;   '(menu-item "Random Piano" random-piano-select
  ;;     :help "Select random piano piece"
  ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/piano-svgrepo-com.svg" :height 36 :width 36)))
  
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-10>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-10>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<random-guitar>"
  ;;   '(menu-item "Random Guitar" random-guitar-select
  ;;     :help "Select random guitar piece"
  ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/guitar-svgrepo-com.svg" :height 36 :width 36)))
  
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-9>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-9>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<random-music>"
  ;;   '(menu-item "Random Music" random-music-select
  ;;     :help "Select random music"
  ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/music-note-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-8>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-8>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<random-study>"
    '(menu-item "Random Study" random-study-select
      :help "Select random study material"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/study-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-7>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-7>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<random-book>"
    '(menu-item "Random Book" random-book-select
      :help "Select random book"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/book-svgrepo-com.svg" :height 36 :width 36)))
  

  (keymap-set-after (default-value 'tool-bar-map) "<separator-8>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-7>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<random-blog>"
    '(menu-item "Random Blog" random-blog-study-select
      :help "Select random blog to read"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/blog-blogger-blogging-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-6>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<separator-org-6>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<beancount-income>"
    '(menu-item "Beancount Income" beancount-helper-add-income
      :help "Beancount Income"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/money-detail-inflow-line-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-5>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-5>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<beancount-expense>"
    '(menu-item "Beancount Expense" beancount-helper-add-expense
      :help "Beancount Expense"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/money-detail-outflow-line-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-4>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<separator-org-4>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-nonimp-task>"
    '(menu-item "Clock NonImportant" consult-clock-nonimportant-task
      :help "Clock NonImportant"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/clock-circle-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-20>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-goto>"
    '(menu-item "Clock Goto" org-clock-goto
      :help "Clock Goto"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/find-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-2>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-out-and-done>"
    '(menu-item "Clock Out and Done" clock-out-and-mark-current-todo-done
      :help "Clock Out and Done"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/done-1477-svgrepo-com.svg" :height 36 :width 36)))
  
  (keymap-set-after (default-value 'tool-bar-map) "<separator-102>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<ibuffer>"
    '(menu-item "Ibuffer" ibuffer
      :help "Ibuffer"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/buffer-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-101>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<zen-workspace>"
    '(menu-item "Zen" global-writeroom-mode
      :help "Zen workspace"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/zen-brush-symbol-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-1>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<random-leisure>"
    '(menu-item "Random Leisure" random-leisure-select
      :help "Select random leisure activity"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/leisure-bowling-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-004>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<org-node-random-large>"
    '(menu-item "Random Org Note Large" org-roam-open-large-note-randomly
      :help "Random Org Note Large"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/random-2dice-svgrepo-com.svg" :height 48 :width 48)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-003>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<org-node-random>"
    '(menu-item "Random Org Note" org-roam-node-random
      :help "Random Org Note"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/shuffle-random-mix-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0025>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<org-roam-ui-opener>"
    '(menu-item "Org Roam UI Open" org-roam-ui-open
      :help "Org Roam UI Open"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/graph-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-002>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<ibuffer>"
    '(menu-item "Ibuffer" ibuffer
      :help "Ibuffer"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/buffer-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-001>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-2>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<org-agenda>"
    '(menu-item "My agenda" my-org-agenda
      :help "My agenda"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/agenda-book-business-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-000>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<home>"
    '(menu-item "Home" +doom-dashboard/open
      :help "Home"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/bank-svgrepo-com.svg" :height 36 :width 36)))
  ;; 5. Add the static tool-bar button exactly like your example
  (keymap-set-after (default-value 'tool-bar-map) "<separator-0009>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<keyboard>"
    '(menu-item "Keyboard" my/toggle-touch-keyboard
      :help "Keyboard"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/keyboard-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0008>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<nodefind>"
    '(menu-item "Nodefind" org-roam-node-find
      :help "Nodefind"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/node-0-connections-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0007>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<directclock>"
    '(menu-item "Directclock" add-clock-time-direct
      :help "Directclock"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/add-circle-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0006>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<offsetclock>"
    '(menu-item "Offsetclock" add-clock-time-by-offset
      :help "Offsetclock"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/add-circle2-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-mundane-task>"
    '(menu-item "Clock Mundane" consult-add-clock-to-mundane-task
      :help "Clock Mundane"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/clock-circle3-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0005>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<saveorg>"
    '(menu-item "Saveorg" org-save-all-org-buffers
      :help "Save org buffers"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/save-floppy-svgrepo-com.svg" :height 36 :width 36)))


  (keymap-set-after (default-value 'tool-bar-map) "<separator-0004>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-in>"
    '(menu-item "Clock In" org-clock-in
      :help "Clock In"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/clock-square-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0003>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<clock-out>"
    '(menu-item "Clock Out" org-clock-out
      :help "Clock Out"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/clock-square2-svgrepo-com.svg" :height 36 :width 36)))


  (keymap-set-after (default-value 'tool-bar-map) "<separator-00022>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<dailyreview>"
    '(menu-item "DailyReview" daily-review-shortcut
      :help "Daily Review"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/daily-calendar-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-00021>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<executor>"
    '(menu-item "Executor" execute-extended-command
      :help "Executor"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/menu-svgrepo-com.svg" :height 36 :width 36)))

  (keymap-set-after (default-value 'tool-bar-map) "<separator-0002>" menu-bar-separator)
  ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-org-3>" menu-bar-separator)
  (keymap-set-after (default-value 'tool-bar-map) "<evilquit>"
    '(menu-item "Evilquit" evil-quit
      :help "Evil quit"
      :image (image :type svg :file "~/.doom.d/toolbar-assets/close-circle-svgrepo-com.svg" :height 36 :width 36)))

  )


;; ;; Optional: Dired binding for consistency
(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c o") #'my-dired-open-xdg))

(defun my-dired-open-xdg ()
  "Open the file at point in Dired using browse-url-xdg-open."
  (interactive)
  (let ((file (dired-get-file-for-visit)))
    (if (file-exists-p file)
        (my-open-file-xdg file)
      (message "File does not exist: %s" file))))

;; termux shell for vterm
(after! vterm
  (setq vterm-shell "/data/data/com.termux/files/usr/bin/bash"))
;; Always confirm before quitting Emacs, even with no modified buffers
(setq confirm-kill-emacs 'y-or-n-p)

;; (setq yas-prompt-functions '(yas-no-prompt))
