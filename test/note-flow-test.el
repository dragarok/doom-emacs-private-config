;;; note-flow-test.el --- Empty notes filled in, big notes broken down -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/note-flow-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched.

(require 'ert)
(require 'cl-lib)
(require 'note-flow)

(defvar org-roam-directory)

(defun note-flow-test--note (dir name text)
  (let ((f (expand-file-name name dir)))
    (make-directory (file-name-directory f) t)
    (with-temp-file f (insert text))
    f))

(defun note-flow-test--text (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defmacro note-flow-test--with (links &rest body)
  "BODY in a notes directory `dir'; LINKS maps an ID to the titles linking
to it, standing in for the org-roam database."
  (declare (indent 1))
  `(let* ((dir (file-name-as-directory (make-temp-file "note-flow-test" t)))
          (org-roam-directory dir)
          (links ,links))
     (cl-letf (((symbol-function 'org-roam-db-query)
                (lambda (_sql id) (mapcar #'list (cdr (assoc id links))))))
       (unwind-protect (progn ,@body)
         (dolist (b (buffer-list))
           (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
             (with-current-buffer b (set-buffer-modified-p nil))
             (kill-buffer b)))
         (delete-directory dir t)))))

(defvar note-flow-test--words nil
  "Answers to \"what would you type to find it\", in turn (each a list); none: nothing.")

(defmacro note-flow-test--answering (strings chars &rest body)
  "BODY with `read-string' answering STRINGS and `read-char-choice' CHARS in
turn, and \"what would you type to find it\" `note-flow-test--words'."
  (declare (indent 2))
  `(let ((sq ,strings) (cq ,chars))
     (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (or (pop sq) "")))
               ((symbol-function 'read-char-choice) (lambda (&rest _) (or (pop cq) ?q)))
               ((symbol-function 'completing-read-multiple) (lambda (&rest _) (pop note-flow-test--words)))
               ((symbol-function 'note-flow--search-offers) (lambda () nil))
               ((symbol-function 'recenter) #'ignore))
       ,@body)))

(defconst note-flow-test--stub ":PROPERTIES:
:ID:       %s
:END:
#+TITLE: %s
#+FILETAGS: :abstract:
")

(defun note-flow-test--big (id)
  (concat (format ":PROPERTIES:\n:ID:       %s\n:END:\n#+TITLE: Big book\n#+FILETAGS: :literaturenote:\n\n" id)
          "* Chapter one\n:PROPERTIES:\n:ID:       chapter-one\n:END:\n"
          (mapconcat #'identity (make-list 400 "word") " ") "\n** A detail\nmore words here\n"
          "* Chapter two\n" (mapconcat #'identity (make-list 400 "word") " ") "\n"
          "* Chapter three\n" (mapconcat #'identity (make-list 400 "word") " ") "\n"))

;;; Which notes

(ert-deftest note-flow-test-own-words ()
  "Drawers, #+ lines and link targets are not your words; link descriptions are."
  (with-temp-buffer
    (insert ":PROPERTIES:\n:ID:       x\n:CREATED:  [2026-10-26]\n:END:\n#+TITLE: Some long title here\n"
            "Two words [[id:abc][and three more]] [[id:def]]\n")
    (should (= (note-flow--own-words) 5))))

(ert-deftest note-flow-test-empty ()
  "Empty notes, the most linked first; not dailies, hubs, notes kept whole,
or put off to a day still to come; a day gone by brings them back."
  (note-flow-test--with '(("linked" "A" "B"))
    (note-flow-test--note dir "lonely.org" (format note-flow-test--stub "lonely" "Lonely"))
    (note-flow-test--note dir "linked.org" (format note-flow-test--stub "linked" "Linked"))
    (note-flow-test--note dir "daily/2026-10-26.org" (format note-flow-test--stub "day" "2026-10-26"))
    (note-flow-test--note dir "hub.org" (concat (format note-flow-test--stub "hub" "Hub")) )
    (with-current-buffer (find-file-noselect (expand-file-name "hub.org" dir))
      (note-flow--set "NOTE_FLOW" "hub") (save-buffer))
    (note-flow-test--note dir "later.org" ":PROPERTIES:\n:ID:       later\n:NOTE_FLOW_LATER: [2999-01-01 Tue]\n:END:\n#+TITLE: Later\n")
    (note-flow-test--note dir "back.org" ":PROPERTIES:\n:ID:       back\n:NOTE_FLOW_LATER: [2020-01-01 Wed]\n:END:\n#+TITLE: Back\n")
    (note-flow-test--note dir "written.org"
                          (concat (format note-flow-test--stub "written" "Written")
                                  (mapconcat #'identity (make-list 40 "word") " ") "\n"))
    (let ((empty (note-flow-empty)))
      (should (equal (car (mapcar (lambda (n) (plist-get n :title)) empty)) "Linked"))
      (should (equal (sort (mapcar (lambda (n) (plist-get n :title)) empty) #'string<)
                     '("Back" "Linked" "Lonely")))
      (should (equal (plist-get (car empty) :backlinks) '("A" "B"))))))

;;; Filling them in

(ert-deftest note-flow-test-fill ()
  "w writes your line as the note's first paragraph; h makes it a hub, never
asked again; n puts it off a month; d, offered only when nothing links to
it, deletes it."
  (note-flow-test--with '(("linked" "A"))
    (let ((linked (note-flow-test--note dir "linked.org" (format note-flow-test--stub "linked" "Linked")))
          (lonely (note-flow-test--note dir "lonely.org" (format note-flow-test--stub "lonely" "Lonely")))
          offered)
      (note-flow-test--answering '("It is the thing that ties A together.") '(?w)
        (cl-letf* ((real (symbol-function 'read-char-choice))
                   ((symbol-function 'read-char-choice)
                    (lambda (prompt chars) (push (cons prompt chars) offered) (funcall real prompt chars))))
          (note-flow-fill 1)))
      (should (string-match-p "linked from A" (car (car offered))))
      (should-not (memq ?d (cdr (car offered))))
      (should (string-match-p "#\\+FILETAGS: :abstract:\n\nIt is the thing that ties A together.\n"
                              (note-flow-test--text linked)))
      (should-not (mapcar (lambda (n) (plist-get n :title))
                          (seq-filter (lambda (n) (equal (plist-get n :title) "Linked")) (note-flow-empty))))
      ;; The lonely one: put off, then (as if a month on) deleted.
      (note-flow-test--answering nil '(?n) (note-flow-fill))
      (should (string-match-p ":NOTE_FLOW_LATER: \\[" (note-flow-test--text lonely)))
      (should-not (note-flow-empty))
      (kill-buffer (find-buffer-visiting lonely))
      (with-temp-file lonely (insert (format note-flow-test--stub "lonely" "Lonely")))
      (note-flow-test--answering nil '(?d) (note-flow-fill))
      (should-not (file-exists-p lonely)))))

(ert-deftest note-flow-test-hub ()
  "h: a hub, its backlinks its content, never offered again."
  (note-flow-test--with '(("ml" "A" "B" "C" "D"))
    (let ((ml (note-flow-test--note dir "ml.org" (format note-flow-test--stub "ml" "Machine Learning"))))
      (note-flow-test--answering nil '(?h) (note-flow-fill))
      (should (string-match-p ":NOTE_FLOW: +hub" (note-flow-test--text ml)))
      (should-not (note-flow-empty)))))

(ert-deftest note-flow-test-no-database ()
  "Without org-roam's database, links are unknown, and nothing is deletable."
  ;; Only where org-roam isn't loaded (batch): in a running Emacs it is.
  (skip-unless (not (featurep 'org-roam)))
  (note-flow-test--with nil
    (note-flow-test--note dir "lonely.org" (format note-flow-test--stub "lonely" "Lonely"))
    (let (offered)
      (cl-letf (((symbol-function 'org-roam-db-query) nil))
        (fmakunbound 'org-roam-db-query)
        (note-flow-test--answering nil nil
          (cl-letf (((symbol-function 'read-char-choice)
                     (lambda (_ chars) (setq offered chars) ?n)))
            (note-flow-fill))))
      (should offered)
      (should-not (memq ?d offered)))))

;;; Breaking them down

(ert-deftest note-flow-test-big ()
  "Big notes with headings to split by; kept whole, never again."
  (note-flow-test--with nil
    (let ((big (note-flow-test--note dir "big.org" (note-flow-test--big "big"))))
      (note-flow-test--note dir "flat.org"
                            (concat (format note-flow-test--stub "flat" "Flat")
                                    (mapconcat #'identity (make-list 1200 "word") " ") "\n"))
      (should (equal (mapcar (lambda (n) (plist-get n :title)) (note-flow-big)) '("Big book")))
      (note-flow-test--answering nil '(?k) (note-flow-split))
      (should (string-match-p ":NOTE_FLOW: +whole" (note-flow-test--text big)))
      (should-not (note-flow-big)))))

(ert-deftest note-flow-test-breakdown ()
  "A line on what it is about at the top; a heading made its own note keeps
its ID, its sub-headings move up, its tags come along, and it links back;
its link and a line stay in its place.  A heading kept stays as it was.
A note made read-only by autoread is still broken down."
  (note-flow-test--with nil
    (let ((big (note-flow-test--note dir "big.org" (note-flow-test--big "big"))))
      (with-current-buffer (find-file-noselect big)
        (read-only-mode 1)
        (note-flow-test--answering '("A book on books." "The first chapter, in short.") '(?e ?k ?q)
          (note-flow-breakdown)))
      (let ((parent (note-flow-test--text big))
            (child (expand-file-name "chapter_one.org" dir)))
        (should (string-match-p "#\\+FILETAGS: :literaturenote:\n\nA book on books.\n" parent))
        (should (string-match-p "^\\* \\[\\[id:chapter-one\\]\\[Chapter one\\]\\]\nThe first chapter, in short.\n\\* Chapter two\n"
                                parent))
        (should-not (string-match-p "A detail" parent))
        (should (string-match-p "^\\* Chapter three$" parent))
        (should (file-exists-p child))
        (let ((text (note-flow-test--text child)))
          (should (string-match-p "^:ID: +chapter-one$" text))
          (should (string-match-p "^#\\+TITLE: Chapter one$" text))
          (should (string-match-p "^#\\+FILETAGS: :literaturenote:$" text))
          (should (string-match-p "^From \\[\\[id:big\\]\\[Big book\\]\\]\\.$" text))
          (should (string-match-p "^\\* A detail$" text))
          (should-not (string-match-p "^:PROPERTIES:\n:ID:.*\n:END:\n:PROPERTIES:" text)))))))

(ert-deftest note-flow-test-breakdown-under-one-heading ()
  "Everything under one top heading: split by the headings under it; a
second heading of the same name gets a file of its own."
  (note-flow-test--with nil
    (note-flow-test--note dir "notes_on_x.org" ":PROPERTIES:\n:ID:       old\n:END:\n#+TITLE: Notes on X\n")
    (let ((f (note-flow-test--note dir "x.org"
                                   (concat ":PROPERTIES:\n:ID:       x\n:END:\n#+TITLE: X\n\n* Notes\n"
                                           "** Notes on X\nfirst\n** Other\nsecond\n"))))
      (with-current-buffer (find-file-noselect f)
        (note-flow-test--answering '("" "") '(?e ?q) (note-flow-breakdown)))
      (should (file-exists-p (expand-file-name "notes_on_x_2.org" dir)))
      (should (string-match-p "^\\*\\* \\[\\[id:.*\\]\\[Notes on X\\]\\]\n\\*\\* Other$"
                              (note-flow-test--text f))))))

;;; New notes

(defmacro note-flow-test--new-note (origin-tags answers &rest body)
  "BODY in a fresh note's buffer after `note-flow-new-note' asked ANSWERS,
made from a note tagged ORIGIN-TAGS."
  (declare (indent 2))
  `(let ((origin (generate-new-buffer "origin")))
     (unwind-protect
         (with-temp-buffer
           (with-current-buffer origin
             (insert "#+TITLE: Origin\n" (if ,origin-tags (format "#+FILETAGS: %s\n" ,origin-tags) "")))
           (insert ":PROPERTIES:\n:ID:       new\n:END:\n#+TITLE: Spaced repetition\n")
           ;; As inside a capture of a new file (in a running Emacs, org-roam
           ;; is loaded and says otherwise out of one).
           (cl-letf (((symbol-function 'org-roam-capture--get) (lambda (key) (eq key :new-file)))
                     ((symbol-function 'org-roam-node-read) (lambda (&rest _) nil)))
             (let ((note-flow--origin origin))
               (note-flow-test--answering ,answers nil (note-flow-new-note))))
           ,@body)
       (kill-buffer origin))))

(ert-deftest note-flow-test-new-note ()
  "Your words, where it is from (a source tags it a literature note), why it
matters; the EHP tag of the note it was made from comes along."
  (note-flow-test--new-note ":ehp:work:" '("Reviewing at growing intervals." "Make It Stick" "So I keep what I read.")
    (let ((text (buffer-string)))
      (should (string-match-p "^#\\+TITLE: Spaced repetition\n#\\+FILETAGS: :ehp:literaturenote:\n" text))
      (should-not (string-match-p "work" text))
      (should (string-match-p "\n\nReviewing at growing intervals.\n\n- From :: Make It Stick\n- Why it matters :: So I keep what I read.\n\\'" text)))))

(ert-deftest note-flow-test-new-note-later ()
  "Enter on the first question: nothing more is asked, nothing written."
  (note-flow-test--new-note nil '("" "never asked")
    (should (equal (buffer-string) ":PROPERTIES:\n:ID:       new\n:END:\n#+TITLE: Spaced repetition\n"))))

(ert-deftest note-flow-test-new-note-link ()
  "A link as the source is the note's ROAM_REFS, not a line, and still a
literature note; your own thought (no source) is not one."
  (note-flow-test--new-note nil '("A paper on memory." "https://example.org/paper" "")
    (should (string-match-p ":ROAM_REFS: https://example.org/paper" (buffer-string)))
    (should (string-match-p "literaturenote" (buffer-string)))
    (should-not (string-match-p "From ::" (buffer-string))))
  (note-flow-test--new-note nil '("Mine." "" "")
    (should-not (string-match-p "FILETAGS" (buffer-string)))))

(ert-deftest note-flow-test-new-note-only-from-find-or-insert ()
  "A note made any other way (a paper's template, a daily) is not asked."
  (with-temp-buffer
    (insert "#+TITLE: Paper\n")
    (let ((note-flow--origin nil))
      (note-flow-test--answering '("should not be asked") nil (note-flow-new-note)))
    (should (equal (buffer-string) "#+TITLE: Paper\n"))))

(ert-deftest note-flow-test-one-template ()
  "Find and insert make a new note from `note-flow-template', remembering
where it was made from; a caller's own templates are left alone."
  (let (got)
    (note-flow--find-a (lambda (&rest args) (setq got (cons note-flow--origin args))) '(4))
    (should (eq (car got) (current-buffer)))
    (should (equal (cdr got) (list '(4) nil nil nil :templates (list note-flow-template))))
    (note-flow--insert-a (lambda (&rest args) (setq got args)))
    (should (equal got (list nil :templates (list note-flow-template))))
    (note-flow--insert-a (lambda (&rest args) (setq got args)) nil :templates '(mine))
    (should (equal got '(nil :templates (mine))))))

;;; Rereading

(defun note-flow-test--long (id title &optional props)
  (concat ":PROPERTIES:\n:ID:       " id "\n" (or props "") ":END:\n#+TITLE: " title "\n\n"
          (mapconcat #'identity (make-list 600 "thought") " ") "\n"))

(ert-deftest note-flow-test-reread-pick ()
  "The most overdue first; with none due, the one untouched longest; never
a literature note, a note kept whole, a short one, or one not yet due."
  (note-flow-test--with nil
    (let ((old (note-flow-test--note dir "old.org" (note-flow-test--long "old" "Old")))
          (new (note-flow-test--note dir "new.org" (note-flow-test--long "new" "New"))))
      (set-file-times old (time-subtract nil (days-to-time 400)))
      (note-flow-test--note dir "ln_book.org" (note-flow-test--long "ln" "Book"))
      (note-flow-test--note dir "log.org" (note-flow-test--long "log" "Log" ":NOTE_FLOW: whole\n"))
      (note-flow-test--note dir "soon.org" (note-flow-test--long "soon" "Soon" ":NEXT_READ: [2999-01-01 Tue]\n"))
      (should (equal (plist-get (note-flow-reread-pick) :title) "Old"))
      (note-flow-test--note dir "due.org" (note-flow-test--long "due" "Due" ":NEXT_READ: [2020-01-01 Wed]\n"))
      (should (equal (plist-get (note-flow-reread-pick) :title) "Due"))
      (ignore new))))

(ert-deftest note-flow-test-reread ()
  "Opened, it is read-only and marked read today; the review asks what you'd
keep, writes it under * Rereads, and the next reread is a week off, then
a month.  Not opened: not asked."
  (note-flow-test--with nil
    (let ((f (note-flow-test--note dir "idea.org" (note-flow-test--long "idea" "Idea")))
          (note-flow--reread-today nil) asked)
      (note-flow-test--answering '("never asked") nil
        (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (setq asked t) "")))
          (note-flow-reread-review)))
      (should-not asked)
      (note-flow-reread)
      (should buffer-read-only)
      (should (string-match-p ":LAST_READ: +\\[" (note-flow-test--text f)))
      (note-flow-test--answering '("It still holds, and links to Flow.") nil (note-flow-reread-review))
      (let ((text (note-flow-test--text f)))
        (should (string-match-p "^\\* Rereads\n- \\[[-0-9]+ [A-Za-z]+\\] It still holds, and links to Flow.$" text))
        (should (string-match-p ":READS: +1" text))
        (should (string-match-p (concat ":NEXT_READ: +\\["
                                        (format-time-string "%Y-%m-%d" (time-add nil (days-to-time 7))))
                                text)))
      ;; Read again (as if a week on): a second line, a month off.
      (with-current-buffer (find-buffer-visiting f) (note-flow--log-reread "") (note-flow--save))
      (let ((text (note-flow-test--text f)))
        (should (string-match-p "Flow.\n- \\[[-0-9]+ [A-Za-z]+\\] reread$" text))
        (should (string-match-p (concat ":NEXT_READ: +\\["
                                        (format-time-string "%Y-%m-%d" (time-add nil (days-to-time 30))))
                                text))))))

;;; Found again by the words you'd search with

(ert-deftest note-flow-test-new-note-search ()
  "Asked what you'd type to find it; kept as :SEARCH:."
  (let ((note-flow-test--words '(("barre" "guitar thumb"))))
    (note-flow-test--new-note nil '("Barre chords need the thumb low." "" "")
      (should (string-match-p ":SEARCH: +barre; guitar thumb" (buffer-string))))))

(ert-deftest note-flow-test-search-offers ()
  "Offered: every tag and every search word given before, once each."
  (cl-letf (((symbol-function 'org-roam-db-query)
             (lambda (sql &rest _)
               (if (seq-contains-p sql 'tags)
                   '(("guitar") ("ehp"))
                 '(((("SEARCH" . "barre; guitar"))) (nil) ((("ID" . "x"))))))))
    (should (equal (note-flow--search-offers) '("guitar" "ehp" "barre")))))

(ert-deftest note-flow-test-reread-asks-search ()
  "Reread, a note with no :SEARCH: is asked what you'd type to find it;
the words add to what it had."
  (note-flow-test--with nil
    (let ((f (note-flow-test--note dir "idea.org" (note-flow-test--long "idea" "Idea")))
          (note-flow--reread-today nil)
          (note-flow-test--words '(("mental models"))))
      (note-flow-reread)
      (note-flow-test--answering '("Still true.") nil (note-flow-reread-review))
      (should (string-match-p ":SEARCH: +mental models" (note-flow-test--text f)))
      (with-current-buffer (find-buffer-visiting f)
        (let ((inhibit-read-only t)) (note-flow--set-search '("models" "mental models"))))
      (should (equal (with-current-buffer (find-buffer-visiting f) (note-flow--file-property "SEARCH"))
                     "mental models; models")))))

;;; note-flow-test.el ends here
