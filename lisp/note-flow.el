;;; note-flow.el --- Empty notes filled in, big notes broken down -*- lexical-binding: t -*-

;;; Commentary:
;; The notes, counted on 2026-10-26: 1,901 of them, 458 under 30 words --
;; mostly titles made as categories (:abstract:, :literaturenote:topic:,
;; :default:) and never written -- and 219 over 1,000.  57% link to
;; nothing.  Notes got written in bursts around one book, then not for
;; months.  So, as org-flow does for tasks, the notes get walked:
;;
;;   - an empty note (fewer than `note-flow-stub-words' of your own words)
;;     is offered to be written: what is it, and why does it matter to you,
;;     in a line or two (still short a month on, it comes back to be
;;     grown).  Or it is a hub (its backlinks are its content, it
;;     is never asked about again), or it is deleted (only when nothing
;;     links to it), or later (in `note-flow-later-days').  The most linked
;;     come first: they are the ones the rest of the notes lean on.
;;   - a big note (`note-flow-big-words' or more, with headings to split it
;;     by) is offered a breakdown (`note-flow-breakdown'): one line on what
;;     it is about, which stays as the map, then heading by heading, its own
;;     note or kept here.  A heading made its own note leaves its link and a
;;     line in its place, and the new note links back.  Or the note is kept
;;     whole (a log, a list: never asked again), or later.  The most
;;     recently edited come first: what you are working with now.
;;
;;   - a new note, made from `org-roam-node-find' or `org-roam-node-insert',
;;     comes from one template, nothing to pick (`note-flow-template'), and
;;     asks what makes a good note: what it is in your own words, where it
;;     is from (a source makes it a literature note; a link, its ROAM_REFS),
;;     why it matters to you, and what it connects to.  Enter on the first
;;     leaves it for the empty notes' walk.  Made from an EHP note, it is
;;     tagged ehp too (`note-flow-inherited-tags').
;;
;;   - one note a day to reread (`note-flow-reread', the homepage's Old
;;     note): the most overdue, or else the one untouched longest.  It opens
;;     read-only; that evening the review asks what you'd keep from it now,
;;     which goes under its * Rereads, and the next reread comes further off
;;     (`note-flow-reread-intervals').  Not opened, nothing is asked.
;;
;;   - a note is for its future, not for collecting: each new note (and
;;     each one reread, or written in the walk) asks what you would type
;;     to find it when you need it -- words, phrases, tags -- kept as
;;     :SEARCH:.  `org-roam-node-find' and `org-roam-node-insert' match
;;     them (org-roam-config shows them, dimmed, after the title), so the
;;     note turns up for the search you'll make then, not only its title.
;;     SPC n r w adds words to the note you are in.
;;
;; The daily review (`day-log-review') offers `note-flow-empty-per-review'
;; empty notes and `note-flow-big-per-review' big ones.  SPC n r e and
;; SPC n r B walk all of them; SPC n r b breaks down the note you are in.
;; What was decided lives in the note: :NOTE_FLOW: hub or whole, and
;; :NOTE_FLOW_LATER: the day it comes back.

;;; Code:

(require 'org)
(require 'org-id)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar org-roam-directory)

(defgroup note-flow nil
  "Empty notes filled in, big notes broken down."
  :group 'org)

(defcustom note-flow-stub-words 30
  "A note with fewer of your own words than this is empty."
  :type 'integer)

(defcustom note-flow-big-words 1000
  "A note with this many of your own words, or more, is big."
  :type 'integer)

(defcustom note-flow-min-headings 3
  "A big note is offered a breakdown only with this many headings to split by."
  :type 'integer)

(defcustom note-flow-later-days 30
  "A note put off comes back after this many days."
  :type 'integer)

(defcustom note-flow-empty-per-review 1
  "Empty notes offered in each daily review."
  :type 'integer)

(defcustom note-flow-big-per-review 1
  "Big notes offered in each daily review."
  :type 'integer)

(defcustom note-flow-skip-directories '("daily" "blogs")
  "Directories under the notes that are never walked: the day's pages and
published posts."
  :type '(repeat string))

;;; Reading a note

(defun note-flow-files ()
  "The notes that can be walked: every .org file under `org-roam-directory'
but those in `note-flow-skip-directories'."
  (when (and (bound-and-true-p org-roam-directory) (file-directory-p org-roam-directory))
    (let ((root (file-name-as-directory (expand-file-name org-roam-directory))))
      (seq-remove
       (lambda (f)
         (let ((rel (file-relative-name f root)))
           (or (string-prefix-p "." (file-name-nondirectory f))
               (seq-some (lambda (d) (string-prefix-p (file-name-as-directory d) rel))
                         note-flow-skip-directories))))
       (directory-files-recursively root "\\.org\\'")))))

(defun note-flow--file-property (prop)
  "PROP from the drawer at the top of the buffer, before any heading."
  (save-excursion
    (goto-char (point-min))
    (let ((end (save-excursion (if (re-search-forward "^\\*+ " nil t) (point) (point-max))))
          (case-fold-search t))
      (when (re-search-forward (format "^[ \t]*:%s:[ \t]+\\(.*?\\)[ \t]*$" (regexp-quote prop)) end t)
        (match-string-no-properties 1)))))

(defun note-flow--keyword (key)
  "The #+KEY: line's value, or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t))
      (when (re-search-forward (format "^#\\+%s:[ \t]*\\(.*?\\)[ \t]*$" key) nil t)
        (match-string-no-properties 1)))))

(defun note-flow--own-words ()
  "Words in the buffer that are yours: not drawers, #+ lines, or link targets."
  (let ((text (buffer-substring-no-properties (point-min) (point-max))))
    (with-temp-buffer
      (insert text)
      (dolist (re '("^[ \t]*:[A-Za-z_]+:[ \t]*\n\\(?:.*\n\\)*?[ \t]*:END:[ \t]*$"
                    "^[ \t]*#\\+.*$"))
        (goto-char (point-min))
        (while (re-search-forward re nil t) (replace-match "")))
      (goto-char (point-min))
      (while (re-search-forward "\\[\\[[^]]*\\]\\(?:\\[\\([^]]*\\)\\]\\)?\\]" nil t)
        (replace-match "\\1" t))
      (goto-char (point-min))
      (how-many "\\w+"))))

(defun note-flow--split-level ()
  "The heading level a breakdown splits by: 1, or 2 when everything sits
under a single top heading."
  (save-excursion
    (goto-char (point-min))
    (if (= 1 (how-many "^\\* ")) 2 1)))

(defun note-flow--headings (level)
  "How many headings of LEVEL the buffer has."
  (save-excursion
    (goto-char (point-min))
    (how-many (format "^\\*\\{%d\\} " level))))

(defun note-flow--later-p (later)
  "Is LATER, a :NOTE_FLOW_LATER: date, still to come?"
  (and later (string-match "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" later)
       (string< (format-time-string "%Y-%m-%d") (match-string 0 later))))

(defun note-flow--read (file)
  "What the walks and the reread need to know about FILE, as a plist."
  (with-temp-buffer
    ;; Read as plain UTF-8, past any file handler: twenty times faster
    ;; over the whole of the notes.
    (let ((coding-system-for-read 'utf-8) (file-name-handler-alist nil))
      (insert-file-contents file))
    (list :file file
          :id (note-flow--file-property "ID")
          :title (or (note-flow--keyword "title") (file-name-base file))
          :words (note-flow--own-words)
          :headings (note-flow--headings (note-flow--split-level))
          :tags (split-string (or (note-flow--keyword "filetags") "") ":" t)
          :decided (note-flow--file-property "NOTE_FLOW")
          :later (note-flow--later-p (note-flow--file-property "NOTE_FLOW_LATER"))
          :next-read (note-flow--file-property "NEXT_READ")
          :last-read (note-flow--file-property "LAST_READ")
          :reads (string-to-number (or (note-flow--file-property "READS") "0"))
          :mtime (file-attribute-modification-time (file-attributes file)))))

(defun note-flow--walkable-p (note)
  "Is NOTE still to be walked: not decided (hub, whole), not put off?"
  (not (or (plist-get note :decided) (plist-get note :later))))

(defun note-flow--backlinks (id)
  "Titles of the notes linking to ID, from the org-roam database."
  (when (and id (fboundp 'org-roam-db-query))
    (ignore-errors
      (mapcar #'car (org-roam-db-query
                     [:select :distinct [nodes:title] :from links
                      :inner-join nodes :on (= links:source nodes:id)
                      :where (and (= links:dest $s1) (= links:type "id"))]
                     id)))))

;;; Which notes

(defun note-flow-empty ()
  "The empty notes, the most linked first, then the most recently edited."
  ;; Backlinks come from org-roam's database: loaded now, or every note
  ;; would look unlinked, and deletable.
  (require 'org-roam nil t)
  (let (out)
    (dolist (f (note-flow-files))
      ;; The biggest empty note was 885 bytes; nothing over 1.5KB is read.
      (when (< (file-attribute-size (file-attributes f)) 1500)
        (when-let* ((note (note-flow--read f))
                    ((note-flow--walkable-p note))
                    ((< (plist-get note :words) note-flow-stub-words)))
          (push (plist-put note :backlinks (note-flow--backlinks (plist-get note :id))) out))))
    (sort out (lambda (a b)
                (let ((la (length (plist-get a :backlinks))) (lb (length (plist-get b :backlinks))))
                  (if (/= la lb) (> la lb)
                    (time-less-p (plist-get b :mtime) (plist-get a :mtime))))))))

(defun note-flow-big ()
  "The big notes with headings to split by, the most recently edited first."
  (let (out)
    (dolist (f (note-flow-files))
      ;; 1,000 words is over 5KB; nothing smaller is read.
      (when (> (file-attribute-size (file-attributes f)) 5000)
        (when-let* ((note (note-flow--read f))
                    ((note-flow--walkable-p note))
                    ((>= (plist-get note :words) note-flow-big-words))
                    ((>= (plist-get note :headings) note-flow-min-headings)))
          (push note out))))
    (sort out (lambda (a b) (time-less-p (plist-get b :mtime) (plist-get a :mtime))))))

;;; Changing a note

(defun note-flow--set (prop value)
  "Set the note's PROP to VALUE, in the drawer at its top."
  (let ((inhibit-read-only t))
    (org-with-wide-buffer
     (goto-char (point-min))
     (org-entry-put nil prop value))))

(defun note-flow--later ()
  "Put the note off for `note-flow-later-days'."
  (note-flow--set "NOTE_FLOW_LATER"
                  (format-time-string "[%Y-%m-%d %a]"
                                      (time-add nil (days-to-time note-flow-later-days)))))

(defun note-flow--body-start ()
  "Where the note's own text begins: after its drawer and #+ lines."
  (save-excursion
    (goto-char (point-min))
    (when (looking-at "[ \t]*:PROPERTIES:")
      (re-search-forward "^[ \t]*:END:[ \t]*\n?" nil t))
    (while (and (not (eobp)) (looking-at "#\\+\\|[ \t]*$"))
      (forward-line 1))
    (point)))

(defun note-flow--insert-paragraph (text)
  "TEXT as the first paragraph of the note."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (note-flow--body-start))
      (if (eobp)
          (insert (if (bolp) "" "\n") "\n" text "\n")
        (insert text "\n\n")))))

(defun note-flow--db-update (file)
  (when (fboundp 'org-roam-db-update-file)
    (ignore-errors (org-roam-db-update-file file))))

(defun note-flow--delete (file)
  "Delete FILE, to the trash, and forget it in the org-roam database."
  (when-let* ((buf (find-buffer-visiting file)))
    (with-current-buffer buf (set-buffer-modified-p nil))
    (kill-buffer buf))
  (let ((delete-by-moving-to-trash t))
    (delete-file file t))
  (when (fboundp 'org-roam-db-clear-file)
    (ignore-errors (org-roam-db-clear-file file))))

;;; Breaking a note down

(defun note-flow--slug (title)
  "A file name for TITLE, as org-roam would make it."
  (let ((s (downcase (replace-regexp-in-string "[^[:alnum:]]+" "_" title))))
    (string-trim (if (string-empty-p s) "note" s) "_+" "_+")))

(defun note-flow--new-file (dir title)
  "A file in DIR for TITLE that does not exist yet."
  (let* ((base (note-flow--slug title))
         (file (expand-file-name (concat base ".org") dir))
         (n 1))
    (while (file-exists-p file)
      (setq file (expand-file-name (format "%s_%d.org" base (cl-incf n)) dir)))
    file))

(defun note-flow--extract (gist)
  "Make the subtree at point its own note, and leave its link in its place,
with GIST (if any) under it.  The heading's properties move into the new
note (its ID too, so links to the heading still land); the new note
links back to this one."
  (org-back-to-heading t)
  (let* ((inhibit-read-only t)
         (level (org-outline-level))
         (title (substring-no-properties (org-get-heading t t t t)))
         (props (org-entry-properties nil 'standard))
         (id (or (cdr (assoc "ID" props)) (org-id-new)))
         (parent-id (org-with-wide-buffer (goto-char (point-min)) (org-id-get-create)))
         (parent-title (or (note-flow--keyword "title") (file-name-base buffer-file-name)))
         (tags (note-flow--keyword "filetags"))
         (start (point))
         (end (save-excursion (org-end-of-subtree t t) (point)))
         (body (save-excursion
                 (org-end-of-meta-data t)
                 (buffer-substring-no-properties (min (point) end) end)))
         (file (note-flow--new-file (file-name-directory buffer-file-name) title)))
    ;; Its sub-headings move up to the top of the new note.
    (setq body (replace-regexp-in-string (format "^\\*\\{%d\\}\\(\\*+ \\)" level) "\\1" body))
    (with-temp-file file
      (insert ":PROPERTIES:\n"
              (format ":ID:       %s\n" id)
              (format ":CREATED:  %s\n" (format-time-string "[%Y-%m-%d %a %H:%M]")))
      (pcase-dolist (`(,k . ,v) props)
        (unless (member k '("ID" "CREATED"))
          (insert (format ":%s: %s\n" k v))))
      (insert ":END:\n"
              (format "#+TITLE: %s\n" title)
              (if (org-string-nw-p tags) (format "#+FILETAGS: %s\n" tags) "")
              (format "\nFrom [[id:%s][%s]].\n\n" parent-id parent-title)
              (string-trim body) "\n"))
    (delete-region start end)
    (goto-char start)
    (insert (make-string level ?*) (format " [[id:%s][%s]]\n" id title)
            (if (org-string-nw-p gist) (concat gist "\n") ""))
    (note-flow--db-update file)
    file))

;;;###autoload
(defun note-flow-breakdown ()
  "Break the note you are in down: one line on what it is about, which
stays at the top as the map, then heading by heading -- e its own note
(its link and a line stay here), k keep it here, q stop."
  (interactive)
  (unless (and buffer-file-name (derived-mode-p 'org-mode))
    (user-error "Not in a note"))
  (let* ((title (or (note-flow--keyword "title") (file-name-base buffer-file-name)))
         (about (string-trim (read-string (format "\"%s\" in one line — it stays at the top (empty: none): " title))))
         (level (note-flow--split-level))
         (heads (save-excursion
                  (goto-char (point-min))
                  (let (ms)
                    (while (re-search-forward (format "^\\*\\{%d\\} " level) nil t)
                      (push (copy-marker (line-beginning-position) t) ms))
                    (nreverse ms))))
         (n 0) (made 0))
    (unless heads (user-error "\"%s\" has no headings to split it by" title))
    (unless (string-empty-p about) (note-flow--insert-paragraph about))
    (catch 'stop
      (dolist (m heads)
        (cl-incf n)
        (goto-char m)
        (org-fold-show-context) (org-fold-show-subtree) (recenter 3)
        (let* ((head (substring-no-properties (org-get-heading t t t t)))
               (words (save-restriction (org-narrow-to-subtree) (note-flow--own-words)))
               (key (read-char-choice
                     (format "[%d/%d] \"%s\" (%d words) — e its own note  k keep here  q stop: "
                             n (length heads) head words)
                     '(?e ?k ?q))))
          (pcase key
            (?e (note-flow--extract
                 (string-trim (read-string (format "\"%s\" in one line, under its link here (empty: none): " head))))
                (cl-incf made))
            (?q (throw 'stop nil))))))
    (let ((inhibit-read-only t)) (save-buffer))
    (note-flow--db-update buffer-file-name)
    (message "%s: %d heading%s made notes of their own" title made (if (= made 1) "" "s"))))

;;; New notes

(defcustom note-flow-template
  '("n" "Note" plain "%?"
    :target (file+head "${slug}.org" "#+TITLE: ${title}\n")
    :immediate-finish t :unnarrowed t)
  "The one template a new note is made with from `org-roam-node-find' and
`org-roam-node-insert': nothing to pick.  The other kinds (blog, person,
paper...) stay in `org-roam-capture-templates', for `org-roam-capture'."
  :type 'sexp)

(defcustom note-flow-inherited-tags '("ehp")
  "Tags a new note takes from the note it was made from."
  :type '(repeat string))

(defvar note-flow--origin nil
  "The buffer a new note is being made from, while one is; nil otherwise.")

(defun note-flow--node-title (node)
  (and node (fboundp 'org-roam-node-title) (org-string-nw-p (org-roam-node-title node))))

(defun note-flow--add-tags (tags)
  "Add TAGS to the #+FILETAGS: line of the buffer, making one if need be."
  (when tags
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search t))
        (if (re-search-forward "^#\\+filetags:[ \t]*\\(.*?\\)[ \t]*$" nil t)
            (let ((beg (match-beginning 1)) (end (match-end 1))
                  (old (split-string (match-string 1) ":" t)))
              (delete-region beg end)
              (goto-char beg)
              (insert ":" (string-join (seq-uniq (append old tags)) ":") ":"))
          (if (re-search-forward "^#\\+title:.*$" nil t)
              (insert "\n")
            (goto-char (note-flow--body-start)))
          (insert "#+FILETAGS: :" (string-join tags ":") ":")
          (unless (looking-at "\n") (insert "\n")))))))

(defun note-flow--origin-tags ()
  "The tags in `note-flow-inherited-tags' that the origin note has."
  (when (buffer-live-p note-flow--origin)
    (with-current-buffer note-flow--origin
      (let ((tags (split-string (or (note-flow--keyword "filetags") "") ":" t)))
        (seq-filter (lambda (tag) (member tag tags)) note-flow-inherited-tags)))))

(defun note-flow-new-note ()
  "Ask what makes a good note, in the new note's buffer: what it is in
your own words, where it is from, why it matters to you, and what it
connects to.  An empty first answer leaves the note as it is (the empty
notes' walk will offer it); an empty answer after skips that one.
In `org-roam-capture-new-node-hook', only for a note made from
`org-roam-node-find' or `org-roam-node-insert', and only a new file."
  (when (and note-flow--origin
             (or (not (fboundp 'org-roam-capture--get)) (org-roam-capture--get :new-file)))
    (let* ((title (or (note-flow--keyword "title") "this"))
           (origin-tags (note-flow--origin-tags))
           (what (string-trim (read-string (format "\"%s\" — what is it, in your own words? (empty: later) " title)))))
      (note-flow--add-tags origin-tags)
      (unless (string-empty-p what)
        (let* ((from (string-trim (read-string "Where is it from — a book, paper, link, person? (empty: your own thought) ")))
               (why (string-trim (read-string "Why does it matter to you? ")))
               (words (note-flow--ask-search title))
               (link (when (fboundp 'org-roam-node-read)
                       (let ((node (org-roam-node-read nil nil nil nil "Connects to (empty: nothing): ")))
                         (when (and (note-flow--node-title node) (org-roam-node-file node))
                           node))))
               (url (string-match-p "\\`https?://" from)))
          (when url (save-excursion (goto-char (point-min)) (org-entry-put nil "ROAM_REFS" from)))
          (when words (save-excursion (goto-char (point-min)) (org-entry-put nil "SEARCH" (string-join words "; "))))
          (unless (string-empty-p from) (note-flow--add-tags '("literaturenote")))
          (save-excursion
            (goto-char (point-max))
            (unless (bolp) (insert "\n"))
            (insert "\n" what "\n")
            (when (or (and (not url) (org-string-nw-p from)) (org-string-nw-p why) link)
              (insert "\n"))
            (when (and (not url) (org-string-nw-p from)) (insert "- From :: " from "\n"))
            (when (org-string-nw-p why) (insert "- Why it matters :: " why "\n"))
            (when link
              (insert (format "- Connects to :: [[id:%s][%s]]\n"
                              (org-roam-node-id link) (org-roam-node-title link))))))))))

(defun note-flow--find-a (fn &optional other-window initial-input filter-fn pred &rest keys)
  "Around `org-roam-node-find': a new note made with `note-flow-template'."
  (if (plist-get keys :templates)
      (apply fn other-window initial-input filter-fn pred keys)
    (let ((note-flow--origin (current-buffer)))
      (apply fn other-window initial-input filter-fn pred :templates (list note-flow-template) keys))))

(defun note-flow--insert-a (fn &optional filter-fn &rest keys)
  "Around `org-roam-node-insert': a new note made with `note-flow-template'."
  (if (plist-get keys :templates)
      (apply fn filter-fn keys)
    (let ((note-flow--origin (current-buffer)))
      (apply fn filter-fn :templates (list note-flow-template) keys))))

;;;###autoload
(define-minor-mode note-flow-mode
  "New notes made from one template, with the questions that make a good note."
  :global t :group 'note-flow
  (if note-flow-mode
      (progn (advice-add 'org-roam-node-find :around #'note-flow--find-a)
             (advice-add 'org-roam-node-insert :around #'note-flow--insert-a)
             (add-hook 'org-roam-capture-new-node-hook #'note-flow-new-note 90))
    (advice-remove 'org-roam-node-find #'note-flow--find-a)
    (advice-remove 'org-roam-node-insert #'note-flow--insert-a)
    (remove-hook 'org-roam-capture-new-node-hook #'note-flow-new-note)))

;;; Found again by the words you'd search with

(defun note-flow--search-of (value)
  "A :SEARCH: VALUE as its list of words and phrases."
  (and value (seq-remove #'string-empty-p (mapcar #'string-trim (split-string value ";")))))

(defun note-flow--search-offers ()
  "Words to offer: every tag, and every search word already given."
  (when (fboundp 'org-roam-db-query)
    (ignore-errors
      (seq-uniq
       (append (mapcar #'car (org-roam-db-query [:select :distinct [tag] :from tags]))
               (mapcan (lambda (row) (note-flow--search-of (cdr (assoc "SEARCH" (car row)))))
                       (org-roam-db-query [:select [properties] :from nodes :where (= level 0)])))))))

(defun note-flow--ask-search (title)
  "The words you would type to find TITLE when you need it, as a list."
  (mapcar #'string-trim
          (completing-read-multiple
           (format "What would you type to find \"%s\" when you need it? (words or phrases, commas; empty: none) " title)
           (note-flow--search-offers))))

(defun note-flow--set-search (words)
  "Keep WORDS as the note's :SEARCH:, added to what it had."
  (when words
    (let ((old (note-flow--search-of (note-flow--file-property "SEARCH"))))
      (note-flow--set "SEARCH" (string-join (seq-uniq (append old words)) "; ")))))

;;;###autoload
(defun note-flow-search-words ()
  "Add to the words this note is found by, in `org-roam-node-find' and
`org-roam-node-insert'."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not in a note"))
  (let ((old (note-flow--file-property "SEARCH")))
    (when old (message "Found by now: %s" old))
    (note-flow--set-search (note-flow--ask-search (or (note-flow--keyword "title") (buffer-name))))
    (save-buffer)
    (note-flow--db-update buffer-file-name)))

;;; Rereading

(defcustom note-flow-reread-words 500
  "A note is reread when it has this many of your own words."
  :type 'integer)

(defcustom note-flow-reread-intervals '(7 30 90 180 365)
  "Days to the next reread, after the first, second... reread; the last repeats."
  :type '(repeat integer))

(defcustom note-flow-reread-skip-prefixes '("ln_" "br_" "private")
  "Notes whose file names start so are never offered to reread, as autoread
never opened them: literature notes, book reviews, private notes."
  :type '(repeat string))

(defvar note-flow--reread-today nil
  "(DATE . NOTE): the day's note to reread, once it is worked out.")

(defun note-flow--today () (format-time-string "%Y-%m-%d"))

(defun note-flow--date-of (stamp)
  "The YYYY-MM-DD in STAMP, or nil."
  (and stamp (string-match "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" stamp) (match-string 0 stamp)))

(defun note-flow-reread-pick ()
  "The note to reread today: the most overdue one, or else the one left
untouched longest of those never reread.  Not logs or lists kept whole."
  (let ((today (note-flow--today)) due fresh)
    (dolist (f (note-flow-files))
      (when (and (> (file-attribute-size (file-attributes f)) (* 5 note-flow-reread-words))
                 (not (seq-some (lambda (p) (string-prefix-p p (file-name-nondirectory f)))
                                note-flow-reread-skip-prefixes)))
        (let ((note (note-flow--read f)))
          (when (and (>= (plist-get note :words) note-flow-reread-words)
                     (not (equal (plist-get note :decided) "whole")))
            (let ((next (note-flow--date-of (plist-get note :next-read))))
              (cond ((null next) (push note fresh))
                    ((not (string< today next)) (push (plist-put note :next next) due))))))))
    (or (car (sort due (lambda (a b) (string< (plist-get a :next) (plist-get b :next)))))
        (car (sort fresh (lambda (a b) (time-less-p (plist-get a :mtime) (plist-get b :mtime))))))))

(defun note-flow-reread-today ()
  "Today's note to reread, worked out once a day."
  (unless (equal (car note-flow--reread-today) (note-flow--today))
    (setq note-flow--reread-today (cons (note-flow--today) (note-flow-reread-pick))))
  (cdr note-flow--reread-today))

;;;###autoload
(defun note-flow-reread ()
  "Open today's note to reread, read-only.  The evening review asks what
you would keep from it."
  (interactive)
  (let ((note (or (note-flow-reread-today) (user-error "Nothing to reread"))))
    (find-file (plist-get note :file))
    (note-flow--set "LAST_READ" (format-time-string "[%Y-%m-%d %a]"))
    (note-flow--save)
    (read-only-mode 1)
    (goto-char (point-min))
    (message "Rereading \"%s\" — tonight's review asks what you'd keep from it"
             (plist-get note :title))))

(defun note-flow--log-reread (line)
  "Note today's reread in the buffer: LINE (if any) under * Rereads, and
the next reread further off."
  (let* ((inhibit-read-only t)
         (reads (1+ (string-to-number (or (note-flow--file-property "READS") "0"))))
         (days (nth (min (1- reads) (1- (length note-flow-reread-intervals))) note-flow-reread-intervals)))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^\\* Rereads[ \t]*$" nil t)
          (org-end-of-subtree t t)
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert "* Rereads\n"))
      (unless (bolp) (insert "\n"))
      (insert (format-time-string "- [%Y-%m-%d %a] ")
              (if (org-string-nw-p line) line "reread") "\n"))
    (note-flow--set "READS" (number-to-string reads))
    (note-flow--set "NEXT_READ" (format-time-string "[%Y-%m-%d %a]" (time-add nil (days-to-time days))))))

(defun note-flow-reread-review ()
  "The review's reread step: if today's note was opened today, ask what
you'd keep from it, and put the next reread further off.  Not opened, not asked."
  (when-let* ((note (note-flow-reread-today))
              (file (plist-get note :file))
              ((file-exists-p file)))
    (with-current-buffer (find-file-noselect file)
      (when (equal (note-flow--date-of (note-flow--file-property "LAST_READ")) (note-flow--today))
        (note-flow--log-reread
         (string-trim (read-string (format "You reread \"%s\" today — what would you keep from it now? "
                                           (plist-get note :title)))))
        (unless (note-flow--file-property "SEARCH")
          (note-flow--set-search (note-flow--ask-search (plist-get note :title))))
        (note-flow--save)
        (setq note-flow--reread-today nil)))))

;;; The walks

(defun note-flow--visit (note)
  "Show NOTE's file, from the top."
  (pop-to-buffer-same-window (find-file-noselect (plist-get note :file)))
  (widen) (goto-char (point-min)) (org-fold-show-all))

(defun note-flow--save ()
  (let ((inhibit-read-only t)) (save-buffer))
  (note-flow--db-update buffer-file-name))

;;;###autoload
(defun note-flow-fill (&optional limit)
  "Walk the empty notes, the most linked first, LIMIT of them (all when nil):
w write it, h a hub, d delete (when nothing links to it), n later, q stop."
  (interactive)
  (let* ((all (note-flow-empty))
         (todo (if limit (seq-take all limit) all))
         (n 0) (counts (make-hash-table)))
    (save-window-excursion
      (catch 'stop
        (dolist (note todo)
          (cl-incf n)
          (note-flow--visit note)
          (let* ((title (plist-get note :title))
                 (links (plist-get note :backlinks))
                 ;; Without the database, links are unknown: nothing is deletable.
                 (deletable (and (null links) (fboundp 'org-roam-db-query)))
                 (keys (if deletable '(?w ?h ?d ?n ?q) '(?w ?h ?n ?q)))
                 (key (read-char-choice
                       (format "[%d/%d] empty: \"%s\"%s — w write  h hub%s  n later  q stop: "
                               n (length todo) title
                               (if links (format " (linked from %s%s)"
                                                 (string-join (seq-take links 3) ", ")
                                                 (if (cddr (cdr links)) ", …" ""))
                                 "")
                               (if deletable "  d delete" ""))
                       keys)))
            (pcase key
              (?w (let ((text (string-trim
                               (read-string
                                (format (if (member "paper" (plist-get note :tags))
                                            "\"%s\": the one idea you'd keep from it? "
                                          "\"%s\": what is it, and why does it matter to you? ")
                                        title)))))
                    (if (string-empty-p text) (setq key ?n)
                      (note-flow--insert-paragraph text)
                      (note-flow--set-search (note-flow--ask-search title)))
                    ;; A line or two is a start: if it is still short in a
                    ;; month, it comes back to be grown.
                    (note-flow--later)))
              (?h (note-flow--set "NOTE_FLOW" "hub"))
              (?d (note-flow--delete (plist-get note :file)))
              (?n (note-flow--later))
              (?q (throw 'stop nil)))
            (unless (eq key ?d) (note-flow--save))
            (cl-incf (gethash key counts 0))))))
    (message (if (null todo) "No empty notes"
               (format "Empty notes: wrote %d, hubs %d, deleted %d, later %d; %d left"
                       (gethash ?w counts 0) (gethash ?h counts 0) (gethash ?d counts 0)
                       (gethash ?n counts 0)
                       (- (length all) (gethash ?w counts 0) (gethash ?h counts 0)
                          (gethash ?d counts 0) (gethash ?n counts 0)))))))

;;;###autoload
(defun note-flow-split (&optional limit)
  "Walk the big notes, the most recently edited first, LIMIT of them (all
when nil): b break it down, k keep it whole, n later, q stop."
  (interactive)
  (let* ((all (note-flow-big))
         (todo (if limit (seq-take all limit) all))
         (n 0) (counts (make-hash-table)))
    (save-window-excursion
      (catch 'stop
        (dolist (note todo)
          (cl-incf n)
          (note-flow--visit note)
          (org-fold-show-all)
          (let ((key (read-char-choice
                      (format "[%d/%d] big: \"%s\" (%d words, %d headings) — b break down  k keep whole  n later  q stop: "
                              n (length todo) (plist-get note :title)
                              (plist-get note :words) (plist-get note :headings))
                      '(?b ?k ?n ?q))))
            (pcase key
              (?b (note-flow-breakdown))
              (?k (note-flow--set "NOTE_FLOW" "whole"))
              (?n (note-flow--later))
              (?q (throw 'stop nil)))
            (note-flow--save)
            (cl-incf (gethash key counts 0))))))
    (message (if (null todo) "No big notes to break down"
               (format "Big notes: broken down %d, kept whole %d, later %d"
                       (gethash ?b counts 0) (gethash ?k counts 0) (gethash ?n counts 0))))))

;;;###autoload
(defun note-flow-review ()
  "The daily review's notes step: what you'd keep from today's reread (if
you opened it), `note-flow-empty-per-review' empty notes, then
`note-flow-big-per-review' big ones."
  (interactive)
  (note-flow-reread-review)
  (when (> note-flow-empty-per-review 0) (note-flow-fill note-flow-empty-per-review))
  (when (> note-flow-big-per-review 0) (note-flow-split note-flow-big-per-review)))

(provide 'note-flow)
;;; note-flow.el ends here
