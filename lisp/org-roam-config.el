;;; org-roam-config.el --- Org-roam configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Org-roam configuration for knowledge management.
;; Works on both Mac and Android.
;; Uses use-package! to ensure settings override Doom's defaults.

;;; Code:

;; ============================================================
;; ORG ROAM CONFIGURATION
;; ============================================================

(use-package! org-roam
  :config
  ;; Remove Doom's lazy-init advice for faster access on Android
  ;; This advice delays db sync until first query, but we want immediate access
  (advice-remove 'org-roam-db-query #'+org-roam-try-init-db-a)

  ;; Dailies directory
  (setq org-roam-dailies-directory "daily/")

  ;; Attachments removed from org-roam db
  (setq org-roam-db-node-include-function
        (lambda ()
          (or
           (not (cdr (assoc "NOTER_PAGE" (org-entry-properties))))
           (not (member "ATTACH" (org-get-tags))))))

  ;; ============================================================
  ;; V2 NODE DISPLAY - Custom accessors
  ;; ============================================================

  ;; Tag constants
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

  ;; Custom hierarchy display with icons
  (cl-defmethod org-roam-node-hierarchy ((node org-roam-node))
    "Return the node's TITLE, as well as it's HIERARCHY."
    (let* ((title (org-roam-node-title node))
           (olp (mapcar (lambda (s) (if (> (length s) 30) (concat (substring s 0 30) "...") s)) (org-roam-node-olp node)))
           (level (org-roam-node-level node))
           (filetitle (org-roam-get-keyword "TITLE" (org-roam-node-file node)))
           (shortentitle (if (> (length filetitle) 30) (concat (substring filetitle 0 30) "...") filetitle))
           (separator (concat " " (nerd-icons-faicon "nf-fa-chevron_right") " ")))
      (cond
       ((= level 1) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-green)) " "
                            (propertize shortentitle 'face 'org-roam-dim) separator title))
       ((= level 2) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-dpurple)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       ((> level 2) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-dsilver)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       (t (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-yellow)) " " title)))))

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
          (concat (propertize "=has:backlinks=" 'display (nerd-icons-octicon "nf-oct-link" :face 'all-the-icons-dblue)) (format "%d" count))
        (concat (propertize "=not-backlinks=" 'display (nerd-icons-octicon "nf-oct-link" :face 'org-roam-dim)) " "))))

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

  ;; This MUST be a cl-defmethod to work as a template accessor
  (cl-defmethod org-roam-node-fullformat ((node org-roam-node))
    "Return a formatted string containing the title and computed tags for the NODE."
    (let* ((tags (my/org-roam-compute-tags node))
           (functiontag (car tags))
           (othertags (cadr tags))
           (functiontag-str (format "%-15s"
                                    (concat " " (string-join functiontag ", "))))
           (othertags-str (when othertags
                            (concat
                             (propertize "=has:tags=" 'display (nerd-icons-faicon "nf-fa-tags" :face 'nerd-icons-dgreen :v-adjust 0.02)) " "
                             (propertize (string-join othertags ", ") 'face 'nerd-icons-dgreen)))))
      (format " %s %s %s" functiontag-str (org-roam-node-title node) (or othertags-str ""))))

  ;; Override Doom's default display template with our custom one
  (setq org-roam-node-display-template "${fullformat}")

  ;; ============================================================
  ;; BUFFER SECTIONS
  ;; ============================================================

  (defun my/org-roam--backlink-files (node)
    "Get the list of files that are already backlinking to NODE."
    (seq-map
     (lambda (backlink)
       (org-roam-node-file (org-roam-backlink-source-node backlink)))
     (org-roam-backlinks-get node)))

  (defun org-roam-unique-unlinked-references-section (node)
    "The unlinked references section for NODE.
References from files that are already backlinking to NODE are excluded."
    (when (and (executable-find "rg")
               (org-roam-node-title node)
               (not (string-match "PCRE2 is not available"
                                  (shell-command-to-string "rg --pcre2-version"))))
      (let* ((titles (cons (org-roam-node-title node)
                           (org-roam-node-aliases node)))
             (rg-command (concat "rg -L -o --vimgrep -P -i "
                                 (mapconcat (lambda (glob) (concat "-g " glob))
                                            (org-roam--list-files-search-globs org-roam-file-extensions)
                                            " ")
                                 (format " '\\[([^[]]++|(?R))*\\]%s' "
                                         (mapconcat (lambda (title)
                                                      (format "|(\\b%s\\b)" (shell-quote-argument title)))
                                                    titles ""))
                                 org-roam-directory))
             (results (split-string (shell-command-to-string rg-command) "\n"))
             (backlink-files (my/org-roam--backlink-files node))
             f row col match)
        (magit-insert-section (unlinked-references)
          (magit-insert-heading "Unlinked References:")
          (dolist (line results)
            (save-match-data
              (when (string-match org-roam-unlinked-references-result-re line)
                (setq f (match-string 1 line)
                      row (string-to-number (match-string 2 line))
                      col (string-to-number (match-string 3 line))
                      match (match-string 4 line))
                (when (and match
                           (not (file-equal-p (org-roam-node-file node) f))
                           (member (downcase match) (mapcar #'downcase titles))
                           (not (member f backlink-files)))
                  (magit-insert-section section (org-roam-grep-section)
                    (oset section file f)
                    (oset section row row)
                    (oset section col col)
                    (insert (propertize (format "%s:%s:%s"
                                                (truncate-string-to-width (file-name-base f) 15 nil nil t)
                                                row col) 'font-lock-face 'org-roam-dim)
                            " "
                            (org-roam-fontify-like-in-org-mode
                             (org-roam-unlinked-references-preview-line f row))
                            "\n"))))))
          (insert ?\n)))))

  (setq org-roam-mode-sections
        (list #'org-roam-backlinks-section
              #'org-roam-reflinks-section
              #'org-roam-unique-unlinked-references-section))

  ;; ============================================================
  ;; CAPTURE TEMPLATES
  ;; ============================================================

  (setq org-roam-capture-templates
        '(("d" "Default" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :default:\n")
           :immediate-finish t)

          ("r" "Default but open buffer" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS:\n")
           :unnarrowed t)

          ("t" "Tagged" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: %^G\n")
           :unnarrowed t)

          ("o" "Abstract ON Note " plain "%?"
           :if-new (file+head "on_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :abstract:\n")
           :unnarrowed t)

          ("l" "Literature Note " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :literaturenote:%^{definition|theory|course|video|article|library|subject|chapter|topic|research}:%^G\n#+REF_URL:\n")
           :unnarrowed t)

          ("e" "EHP Note" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :ehp:%^{type|ultra|dragonfly|architecture}:%^G\n#+REF_URL:\n")
           :unnarrowed t)

          ("b" "Book Review " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :bookreview:\n")
           :unnarrowed t)

          ("c" "Composition" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :composition:\n")
           :unnarrowed t)

          ("p" "Person" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :person:\n")
           :unnarrowed t)

          ("R" "Bibliography Reference" plain
           (file (concat org-templates-directory "orbreftemplate.org"))
           :if-new
           (file+head "papers/${citekey}.org"
                      "#+title: ${title}\n#+FILETAGS: :bibnote:\n")
           :unnarrowed t)

          ("h" "Blog Post" plain
           "%?"
           :if-new (file+head "blogs/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+SETUPFILE:../hugo_in_setup.org\n#+HUGO_SECTION: ${ai|emacs|neuroscience}\n#+HUGO_SLUG: ${slug}\n#+HUGO_TAGS:\n#+HUGO_CATEGORIES:\n#+HUGO_DRAFT: false\n\n#+AUTHOR: Alok Regmi\n#+FILETAGS: :blog:${filetags}\n\n#+TITLE: ${title}\n")
           :unnarrowed t)

          ("k" "private" plain
           "%?" :if-new (file+head "private-${slug}.org"
                                   "#+TITLE: ${title}\n\n#+FILETAGS: %^G\n")
           :unnarrowed t)

          ("w" "webref" entry "* ${title} ([[${ref}][${hostname}]])\n%?"
           :if-new
           (file+head (concat org-roam-dailies-directory "%<%Y-%m-%d>.org")
                      "#+title: %<%Y-%m-%d %a>\n#+FILETAGS: journal\n#+STARTUP: overview\n")
           :unnarrowed t)))

  ;; Set CREATED property on new nodes
  (defun my/org-roam-set-created ()
    "Set a CREATED property in the current Org-roam node."
    (when (and (org-roam-buffer-p)
               (not (org-entry-get (point) "CREATED")))
      (org-set-property "CREATED" (format-time-string "[%Y-%m-%d %a %H:%M]"))))

  (add-hook 'org-roam-capture-new-node-hook #'my/org-roam-set-created)

  ;; ============================================================
  ;; HELPER FUNCTIONS
  ;; ============================================================

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
            node)
        (org-roam-capture- :node node
                           :keys "r")
        (org-entry-put (point-min) "PROJ_RESOURCES_DIR" (concat "[[" project-resources-dir title "]]"))
        (org-roam-tag-add filetag)
        (org-capture-finalize nil)
        node)))

  ;; ============================================================
  ;; KEYBINDINGS
  ;; ============================================================

  (map! :leader
        :prefix "n"
        (:prefix ("r" . "Org-roam")
         :desc "Toggle roam buffer"            "t" #'org-roam-buffer-toggle
         :desc "Refile"                        "r" #'org-roam-refile
         (:prefix ("l" . "Roam Alias")
          :desc "Add alias"                    "a" #'org-roam-alias-add
          :desc "Remove alias"                 "d" #'org-roam-alias-remove)))
  ) ;; End of use-package! org-roam

;; ============================================================
;; ORG ROAM LOG NOTES SAVING
;; ============================================================

(defun log-org-roam-file-save ()
  "Log the saving of an Org-roam file to a device-specific log file."
  (when (and (eq major-mode 'org-mode)
             (boundp 'org-roam-directory)
             (string-prefix-p (expand-file-name org-roam-directory) (expand-file-name buffer-file-name)))
    (let ((log-file (concat org-logs-directory "notes_log_" (system-name) ".txt"))
          (current-time (format-time-string "[%Y-%m-%d %H:%M:%S]"))
          (file-name (buffer-file-name)))
      (with-temp-buffer
        (insert (format "%s Saved file: %s\n" current-time file-name))
        (append-to-file (point-min) (point-max) log-file)))))

(add-hook 'after-save-hook #'log-org-roam-file-save)

;; ============================================================
;; ORG ROAM UI
;; ============================================================

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam
  :hook (org-roam . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;; ============================================================
;; ROAM FILE SEARCH
;; ============================================================

;;;###autoload
(defun bms/org-roam-rg-search ()
  "Search org-roam directory using consult-ripgrep. With live-preview."
  (interactive)
  (let ((consult-ripgrep-command "rg --null --ignore-case --type org --line-buffered --color=always --max-columns=500 --no-heading --line-number . -e ARG OPTS"))
    (consult-ripgrep org-roam-directory)))

;; ============================================================
;; ORG EXPORT JUPYTER PYTHON BLOCKS
;; ============================================================

(after! org
  (defun jupyter-python-to-only-python (text backend info)
    "Replace jupyter-python src blocks with python blocks."
    (replace-regexp-in-string "```jupyter-python" "```python" text))
  (add-hook 'org-export-filter-src-block-functions #'jupyter-python-to-only-python))

;; ============================================================
;; TASK TO ORG NOTE
;; ============================================================

(defun my/convert-task-to-org-note ()
  "Convert a task in a `org-roam' note."
  (interactive)
  (let* ((heading (org-get-heading t t t t))
         (body (org-get-entry))
         (link (format "[[id:%s][%s]]" (org-id-get-create) heading))
         (filepath (on/make-filepath heading (current-time))))
    (on/insert-org-roam-file
     filepath
     heading
     nil
     (list link)
     (format "* Note stored from tasks\n%s" body)
     nil)
    (find-file filepath)))

;; ============================================================
;; ORG ROAM SEARCH
;; ============================================================

(defun my-org-roam-search (phrase)
  (interactive "sSearch phrase: ")
  (let* ((cmd (format "rg --with-filename --line-number --column --no-heading --color=never -i '%s' %s"
                      phrase org-roam-directory))
         (results (split-string (shell-command-to-string cmd) "\n" t))
         (current-file nil)
         (buffer-name (generate-new-buffer-name "*org-roam-search*")))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (dolist (line results)
        (let* ((parts (split-string line ":"))
               (file (nth 0 parts))
               (linum (string-to-number (nth 1 parts)))
               (content (string-join (nthcdr 3 parts) ":"))
               (id (with-temp-buffer
                     (insert-file-contents file)
                     (goto-char (point-min))
                     (when (re-search-forward "^:ID:[ \t]+\\(.*\\)" nil t)
                       (match-string-no-properties 1)))))
          (when (and id (not (equal current-file file)))
            (setq current-file file)
            (insert (format "\n* File: [[id:%s][%s]]\n" id (file-name-nondirectory file)))
            (insert (make-string (+ 9 (length (file-name-nondirectory file))) ?-))
            (insert "\n"))
          (when id
            (insert (format "- [[file:%s::%d][%4d]]: %s\n" file linum linum content)))))
      (switch-to-buffer-other-window buffer-name)
      (goto-char (point-min))
      (org-mode)
      (read-only-mode 1))))

(defun my-org-open-at-point-in-right-split ()
  (interactive)
  (let ((path (get-text-property (point) 'path))
        (type (get-text-property (point) 'type)))
    (when (string-equal type "file")
      (let* ((file (file-truename (car path)))
             (line (string-to-number (cadr path))))
        (split-window-right)
        (other-window 1)
        (find-file file)
        (goto-char (point-min))
        (forward-line (1- line))))))

;; ============================================================
;; ORG ROAM QUICK INSERT LINK
;; ============================================================

(defun insert-org-roam-link ()
  "Insert a Roam link and place the cursor next to the colon.
If in Evil normal mode, switch to insert mode."
  (interactive)
  (if (and (bound-and-true-p evil-mode)
           (eq evil-state 'normal))
      (evil-insert-state))
  (insert "[[roam:")
  (save-excursion
    (insert "]]")))

;; ============================================================
;; ORG ROAM MONDAY CAPTURE
;; ============================================================

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

(provide 'org-roam-config)
;;; org-roam-config.el ends here
