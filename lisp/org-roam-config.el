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
  ;; Doom's `+org-roam-try-init-db-a' is KEPT (it used to be removed here).
  ;; It is a one-shot advice that syncs the database at the first query of
  ;; the session, then removes itself.  Removing it did not make anything
  ;; "immediate" -- it meant nothing ever synced, so a note written on
  ;; another machine never showed up in `org-roam-node-find'.  It was removed
  ;; because the sync took minutes, and that was the path bug (see config.el).

  ;; Dailies directory
  (setq org-roam-dailies-directory "daily/")

  ;; ============================================================
  ;; V2 NODE DISPLAY - Custom accessors
  ;; ============================================================

  ;; Tag constants
  (defconst my/org-roam-special-tags
    '("bibnote" "bookreview" "literaturenote" "default" "abstract" "blog" "person" "creativewriting")
    "Special tags that are unique to each file to represent the note's function.")

  (defconst my/org-roam-ignored-tags
    '("ATTACH")
    "Tags that are ignored when displaying function and other tags.")

  ;; Only fullformat is shown (the display template below); the other
  ;; accessors (hierarchy, functiontag, othertags, backlinkscount) were never
  ;; used and went on 2026-10-26.
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
             ;; No shell: a title with a ' broke the command line.  Titles are
             ;; quoted for PCRE, or one with ( or + matched something else.
             (pcre-quote (lambda (s) (replace-regexp-in-string "[][\\^$.|?*+(){}]" "\\\\\\&" s)))
             (results (apply #'process-lines-ignore-status "rg"
                             (append '("-L" "-o" "--vimgrep" "-P" "-i")
                                     (mapcan (lambda (glob) (list "-g" (string-trim glob "\"" "\"")))
                                             (org-roam--list-files-search-globs org-roam-file-extensions))
                                     (list (concat "\\[([^[]]++|(?R))*\\]"
                                                   (mapconcat (lambda (title)
                                                                (format "|(\\b%s\\b)" (funcall pcre-quote title)))
                                                              titles ""))
                                           (expand-file-name org-roam-directory)))))
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

  ;; A new note from find or insert (SPC n r f / i) is made from one
  ;; template, with no menu, and asks what makes a good note (note-flow.el).
  ;; Papers: SPC n r p (papers.el).  These are the kinds SPC n r n still
  ;; offers, cut on 2026-10-26 to what the notes actually used; "w" and "R"
  ;; errored every time, "t" and "c" went unused.  "r" stays for
  ;; `title-to-org-roam-node'.
  (setq org-roam-capture-templates
        '(("d" "Default" plain "%?"
           :target (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :default:\n")
           :immediate-finish t)

          ("r" "Default but open buffer" plain "%?"
           :target (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS:\n")
           :unnarrowed t)

          ("o" "Abstract ON Note " plain "%?"
           :target (file+head "on_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :abstract:\n")
           :unnarrowed t)

          ("l" "Literature Note " plain "%?"
           :target (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :literaturenote:%^{definition|theory|course|video|article|library|subject|chapter|topic|research}:%^G\n#+REF_URL:\n")
           :unnarrowed t)

          ("e" "EHP Note" plain "%?"
           :target (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :ehp:%^{type|ultra|dragonfly|architecture}:%^G\n#+REF_URL:\n")
           :unnarrowed t)

          ;; br_, as the 64 book reviews before it (it was ln_ by mistake).
          ("b" "Book Review " plain "%?"
           :target (file+head "br_${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :bookreview:\n")
           :unnarrowed t)

          ("p" "Person" plain "%?"
           :target (file+head "${slug}.org"
                              "#+TITLE: ${title}\n#+FILETAGS: :person:\n")
           :unnarrowed t)

          ("h" "Blog Post" plain
           "%?"
           :target (file+head "blogs/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+SETUPFILE:../hugo_in_setup.org\n#+HUGO_SECTION: ${ai|emacs|neuroscience}\n#+HUGO_SLUG: ${slug}\n#+HUGO_TAGS:\n#+HUGO_CATEGORIES:\n#+HUGO_DRAFT: false\n\n#+AUTHOR: Alok Regmi\n#+FILETAGS: :blog:${filetags}\n\n#+TITLE: ${title}\n")
           :unnarrowed t)

          ("k" "private" plain
           "%?" :target (file+head "private-${slug}.org"
                                   "#+TITLE: ${title}\n\n#+FILETAGS: %^G\n")
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
    (interactive (list (substring-no-properties (org-get-heading t t t t))))
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
        ;; A plain "r", not ("r" . "Org-roam"): the description form makes
        ;; SPC n r a fresh, empty keymap, which wiped Doom's own roam keys
        ;; (find, insert, capture, dailies...) whenever org-roam loaded.
        (:prefix "r"
         :desc "Find node"                     "f" #'org-roam-node-find
         :desc "Toggle roam buffer"            "t" #'org-roam-buffer-toggle
         :desc "Refile"                        "r" #'org-roam-refile
         :desc "Fill empty notes"              "e" #'note-flow-fill
         :desc "Break this note down"          "b" #'note-flow-breakdown
         :desc "Break big notes down"          "B" #'note-flow-split
         :desc "Reread today's note"           "o" #'note-flow-reread
         :desc "Add a paper"                   "p" #'papers-add
         :desc "Notes for what I'm doing"      "w" #'note-flow-for-now
         (:prefix ("l" . "Roam Alias")
          :desc "Add alias"                    "a" #'org-roam-alias-add
          :desc "Remove alias"                 "d" #'org-roam-alias-remove)))

  ;; Useful for kairoam on phones
  (map! :map org-roam-mode-map [mouse-1] #'org-roam-preview-visit)
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
  ;; Started by hand (the homepage's Graph): an `org-roam' hook it used to
  ;; hang on is never run.
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
  (consult-ripgrep org-roam-directory))

;; ============================================================
;; ORG EXPORT JUPYTER PYTHON BLOCKS
;; ============================================================

(after! org
  (defun jupyter-python-to-only-python (text backend info)
    "Replace jupyter-python src blocks with python blocks."
    (replace-regexp-in-string "```jupyter-python" "```python" text))
  (add-hook 'org-export-filter-src-block-functions #'jupyter-python-to-only-python))

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

(defun org-roam-dailies-goto-monday-of-next-week ()
  "Find the daily-note for the Monday of next week, creating it if necessary."
  (interactive)
  (let* ((now (current-time))
         (decoded (decode-time now))
         (dow (nth 6 decoded))  ; 0=Sunday, 1=Monday, etc.
         (days-forward (if (= dow 0) 1 (- 8 dow)))
         (next-monday-time (time-add now (days-to-time days-forward))))
    (org-roam-dailies--capture next-monday-time t)))

(defvar my/org-roam-dailies-focus-mode 'today
  "Current focus mode for dailies: 'today, 'current-monday, or 'next-monday.")

(defun my/org-roam-dailies-cycle-focus ()
  "Cycle through dailies focus: Today -> Current Monday -> Next Monday -> Today."
  (interactive)
  ;; A first tap is today; tapped again straight after, the Mondays.
  (unless (eq last-command this-command)
    (setq my/org-roam-dailies-focus-mode 'next-monday))
  (setq my/org-roam-dailies-focus-mode
        (pcase my/org-roam-dailies-focus-mode
          ('today 'current-monday)
          ('current-monday 'next-monday)
          ('next-monday 'today)
          (_ 'today)))
  
  (message "Dailies Focus: %s" my/org-roam-dailies-focus-mode)
  
  (pcase my/org-roam-dailies-focus-mode
    ('today (org-roam-dailies-goto-today))
    ('current-monday (org-roam-dailies-goto-monday-of-week))
    ('next-monday (org-roam-dailies-goto-monday-of-next-week))))


;; ============================================================
;; NOTES FROM THE OTHER MACHINE
;; ============================================================

;; Autosync indexes only what is saved here; a note written on the phone
;; (or the Mac) waited for the next session's first sync to be found.
;; Now an idle Emacs syncs, at most every half hour (1s on the Mac).
(defvar my/org-roam-last-sync 0)
(run-with-idle-timer
 120 t
 (lambda ()
   (when (and (featurep 'org-roam)
              (> (- (float-time) my/org-roam-last-sync) 1800))
     (setq my/org-roam-last-sync (float-time))
     (let ((inhibit-message t)) (ignore-errors (org-roam-db-sync))))))

(provide 'org-roam-config)
;;; org-roam-config.el ends here
