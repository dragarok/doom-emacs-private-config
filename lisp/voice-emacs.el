;;; voice-emacs.el --- Any Emacs command, by what you call it -*- lexical-binding: t -*-

;;; Commentary:
;; voice-command.el's own actions are a few dozen; this finds the rest of
;; Emacs.  Every command is known by
;;
;;  - its name's words: consult-theme is "consult theme";
;;  - what its keys call it: Doom's leader says SPC b B is "Switch buffer",
;;    the menu says "Open File", and the prefixes above it name its group
;;    (buffer, help);
;;  - what it asks for, by its first argument's name or interactive codes:
;;    THEME, BUFFER, FILE.  Each such kind has values (the themes there
;;    are, each with its own description: "A dark theme inspired by..."),
;;    so a value said names the command too.
;;
;; What was said is weighed as everywhere in voice (voice-match.el): each
;; word by how few commands use it, near sounds nearly as well, words said
;; apart for one long word ("a car io" for acario) too.  Words that mean
;; the same in command names (`voice-emacs-synonyms': change, switch,
;; load, set) count nearly as the word; yours go under * Words in
;; voice.org.  Commands you run from M-x, the leader's, and those bound in
;; the buffer in front count a little more, only to break ties.
;;
;; A sentence may be a command and then what it asks for: "change theme to
;; tango dark".  Every split is weighed, the front against the commands,
;; the rest against the values of what each asks; the rest then answers
;; its first question.  A value with no command ("switch to dark mode": no
;; command says dark, but themes do) suggests the commands of its kind.
;;
;; This file only ranks.  voice-command.el decides: do it, ask "did you
;; mean", or show the closest commands to pick from; a yes or a pick is
;; learned, so the same words do it next time.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'voice-match)

(defvar doom-leader-map)
(defvar recentf-list)
(declare-function bookmark-all-names "bookmark")
(declare-function custom-theme--load-path "custom")

;;;; Words that mean the same in commands

(defvar voice-emacs-synonyms
  '(("change" "switch" "set" "load" "select" "pick" "choose" "use" "apply" "enable")
    ("open" "find" "visit" "launch" "browse")
    ("show" "view" "display" "list" "see")
    ("goto" "go" "jump" "navigate")
    ("close" "quit" "exit" "dismiss" "bury" "hide")
    ("delete" "remove" "erase" "trash" "kill")
    ("cut" "kill")
    ("paste" "yank")
    ("copy" "duplicate" "clone")
    ("new" "create" "make" "add" "insert")
    ("toggle" "turn" "flip" "switch")
    ("toggle" "mode" "enable" "disable" "activate" "deactivate")
    ("search" "find" "grep" "look" "query" "lookup")
    ("rename" "move")
    ("bigger" "larger" "increase" "enlarge" "grow" "more")
    ("smaller" "decrease" "shrink" "reduce" "less")
    ("start" "begin" "run" "launch" "execute" "call" "invoke")
    ("stop" "end" "halt" "abort" "cancel")
    ("next" "forward" "following")
    ("previous" "prev" "back" "backward" "prior")
    ("top" "beginning" "first")
    ("bottom" "end" "last")
    ("help" "describe" "explain" "documentation" "doc" "manual" "info")
    ("theme" "color" "colour" "scheme" "colorscheme" "look")
    ("window" "pane" "split")
    ("file" "document")
    ("folder" "directory" "dir")
    ("reload" "refresh" "restart" "update")
    ("save" "write" "store")
    ("maximize" "maximise" "fullscreen" "enlarge")
    ("font" "text")
    ("note" "node")
    ("todo" "task")
    ("git" "magit" "vc")
    ("terminal" "term" "shell" "vterm" "eshell" "ghostel")
    ("spell" "spelling" "ispell" "flyspell")
    ("line" "row"))
  "Words that mean the same in command names, each list one meaning.
Each counts nearly as the word itself: \"change theme\" is load-theme.
They are the words of Emacs, not mishearings (those go under * Sounds in
voice.org); yours go under * Words there, as - said :: means.")

(defvar voice-emacs-user-words nil
  "Yours, from voice.org's * Words: (SAID . MEANS), set by voice-command.el.")

(defvar voice-emacs--related-cache nil "(SOURCES . TABLE).")

(defun voice-emacs--related-table ()
  "Token -> the tokens that mean the same, from the synonyms and yours."
  (let ((sources (cons voice-emacs-synonyms voice-emacs-user-words)))
    (if (and voice-emacs--related-cache (equal (car voice-emacs--related-cache) sources))
        (cdr voice-emacs--related-cache)
      (let ((table (make-hash-table :test 'equal)))
        (dolist (group (append voice-emacs-synonyms
                               (mapcar (lambda (p) (list (car p) (cdr p))) voice-emacs-user-words)))
          (let ((stems (delete-dups
                        (mapcar (lambda (w) (voice-match-stem (downcase w)))
                                (seq-remove (lambda (w) (string-match-p " " w)) group)))))
            (dolist (w stems)
              (puthash w (delete-dups (append (remove w stems) (gethash w table))) table))))
        (setq voice-emacs--related-cache (cons sources table))
        table))))

(defun voice-emacs-related (token)
  "The tokens that mean what TOKEN does in command names."
  (gethash token (voice-emacs--related-table)))

(defun voice-emacs-related-sim (x y)
  "How alike X and Y are in meaning: 0.8 for words of one meaning, else 0."
  (if (member y (voice-emacs-related x)) 0.8 0.0))

(defmacro voice-emacs--with-meanings (&rest body)
  "BODY with words that mean the same counting in voice-match."
  `(let ((voice-match-related #'voice-emacs-related-sim)
         (voice-match-expand #'voice-emacs-related)
         (voice-match-shortlist 150)
         (voice-match-title-share 0.4))
     ,@body))

;;;; Every command

(defvar voice-emacs-refresh-seconds 600
  "How old the list of commands may get before it is looked at again.")

(defvar voice-emacs-skip-regexp
  (concat "--\\|-mouse-\\|\\`\\(?:mouse\\|menu-bar\\|tool-bar\\|tab-bar-mouse\\|xterm\\|tmm"
          "\\|ns\\|w32\\|x\\|pgtk\\|haiku\\)-"
          "\\|\\`\\(?:self-insert-command\\|digit-argument\\|negative-argument\\|ignore\\|undefined\\)\\'")
  "Commands never offered: internal ones, the mouse's, the menus' own.")

(defvar voice-emacs--catalog nil "(TIME COUNT . INDEX).")

(defun voice-emacs--name-words (cmd)
  "CMD's name as words: doom/reload-theme is \"doom reload theme\"; a
leading + or my/ is no word.  A key's lambda (`voice-emacs--key-command')
is what its key calls it."
  (or (get cmd 'voice-label)
      (let ((name (replace-regexp-in-string "\\`\\(?:[+]+\\|my[/-]\\)" "" (symbol-name cmd))))
        (string-join (split-string name "[^[:alnum:]]+" t) " "))))

(defun voice-emacs--walk (map fn &optional prefixes seen depth keys)
  "Call FN with each command bound in MAP, its label (a description, as
Doom's leader gives, or a menu item's name; else nil), the names of the
prefixes above it, innermost first, and its keys (a vector, from MAP).
A command bound as a lambda (Doom's cmd!) comes as that function."
  (let ((seen (or seen (make-hash-table :test 'eq)))
        (depth (or depth 0)))
    (unless (or (> depth 6) (gethash map seen))
      (puthash map t seen)
      (map-keymap
       (lambda (key def)
         (let (label (here (vconcat keys (vector key))))
           ;; ("Description" . DEF), ("Name" "Help" . DEF), (menu-item "Name" DEF ...)
           (when (and (consp def) (stringp (car def)))
             (setq label (car def) def (cdr def))
             (when (and (consp def) (stringp (car def))) (setq def (cdr def))))
           (when (eq (car-safe def) 'menu-item)
             (setq label (nth 1 def) def (nth 2 def)))
           (cond ((and def (or (symbolp def) (functionp def)) (commandp def) (not (keymapp def)))
                  (funcall fn def (and (stringp label) label) prefixes here))
                 ((and (keymapp def)
                       ;; A keymap still to be loaded stays so.
                       (not (and (symbolp def) (autoloadp (indirect-function def)))))
                  (voice-emacs--walk (if (symbolp def) (indirect-function def) def) fn
                                     (if (stringp label) (cons label prefixes) prefixes)
                                     seen (1+ depth) here)))))
       map))))

(defun voice-emacs--key-command (def label keys &optional local)
  "DEF, a command bound under KEYS, as a symbol: itself, or for a lambda
with a LABEL (Doom's cmd!: SPC o v w \"Weekly review\") a name standing
for that key, voice-key/SPC_o_v_w, so it can be found and run like any.
LOCAL: the key is a mode's, so its name is for that mode's buffers only,
never in the catalog."
  (cond ((symbolp def) def)
        ((and label keys)
         (let ((sym (intern (concat "voice-key/" (replace-regexp-in-string
                                                  " " "_" (key-description keys))))))
           (unless (eq (symbol-function sym) def) (defalias sym def))
           (put sym 'voice-label (voice-emacs--label-name label))
           (when local (put sym 'voice-skip t))
           sym))))

(defun voice-emacs--literal (string)
  "STRING's words as said, sorted, unstemmed, no stop words."
  (sort (seq-remove (lambda (w) (member w voice-match-stop-words)) (voice-match-words string))
        #'string<))

(defvar voice-emacs-key-names
  '((up . "up") (down . "down") (left . "left") (right . "right")
    (home . "home") (end . "end") (next . "page down") (prior . "page up")
    (delete . "delete") (deletechar . "delete") (insert . "insert") (escape . "escape"))
  "The keyboard's keys, by the names on them: what a command bound to one
alone in the global map is called (<down>: next-line).")

(defun voice-emacs--label-name (label)
  "LABEL without its notes: \"Add project (C-u: shell only)\" is called
\"Add project\"; \"Remote: add session\" keeps its words."
  (let ((name (string-trim (replace-regexp-in-string "[[:space:]]*([^)]*)" "" label))))
    (if (string-empty-p name) label name)))

(defun voice-emacs--within (label prefix)
  "LABEL with PREFIX's words it lacks: \"Find file\" in notes is \"Find
file notes\", \"Save buffer\" in buffer stays."
  (let ((have (voice-match-tokens label t)))
    (string-join (cons label (and prefix (seq-remove (lambda (w) (member (voice-match-stem w) have))
                                                     (voice-match-words prefix))))
                 " ")))

(defun voice-emacs--labels ()
  "Command -> (LABELS MENU-WORDS LEADER BARE PLAIN MENU): what the leader's
keys call it, within their group, and the keyboard's own keys (<down>:
\"down\", <next>: \"page down\"); the menus' names for it and the prefixes
above (\"buffer\"), which only describe it; whether the leader has it;
the labels as the keys show them, group unsaid (\"Restart emacs\" under
quit/session); without their notes (\"Add project\" for \"Add project
\(C-u: shell only)\"); and the menu bar's names for it (\"Select All\"),
said just so only when nothing else is (a package's menu says \"Open
file\" for its own)."
  (let ((table (make-hash-table :test 'eq)))
    (dolist (spec (list (cons (and (boundp 'doom-leader-map) doom-leader-map) t)
                        (cons global-map nil)))
      (when (keymapp (car spec))
        (voice-emacs--walk
         (car spec)
         (lambda (def label prefixes keys)
           ;; The leader's lambdas too, by what it calls them.
           (let* ((cmd (if (cdr spec) (voice-emacs--key-command def label keys) (and (symbolp def) def)))
                  (e (and cmd (or (gethash cmd table) (list nil nil nil nil nil nil))))
                  (named-key (and (not (cdr spec)) (= (length keys) 1)
                                  (alist-get (aref keys 0) voice-emacs-key-names))))
             (when cmd
               ;; A leader key's description is within its prefix: SPC n f
               ;; "Find file" finds a file in notes.
               (when (and label (cdr spec))
                 (let ((within (voice-emacs--within label (car prefixes)))
                       (plain (voice-emacs--label-name label)))
                   (unless (member within (nth 0 e)) (setf (nth 0 e) (cons within (nth 0 e))))
                   (unless (member label (nth 3 e)) (setf (nth 3 e) (cons label (nth 3 e))))
                   (unless (equal plain label)
                     (dolist (p (list plain (voice-emacs--within plain (car prefixes))))
                       (unless (member p (nth 4 e)) (setf (nth 4 e) (cons p (nth 4 e))))))))
               (when named-key
                 (unless (member named-key (nth 0 e)) (setf (nth 0 e) (cons named-key (nth 0 e))))
                 (unless (member named-key (nth 3 e)) (setf (nth 3 e) (cons named-key (nth 3 e)))))
               (when (and label (not (cdr spec)) (eq (aref keys 0) 'menu-bar))
                 (let ((m (voice-emacs--label-name label)))
                   (unless (member m (nth 5 e)) (setf (nth 5 e) (cons m (nth 5 e))))))
               (dolist (p (if (and label (not (cdr spec))) (cons label prefixes) prefixes))
                 (unless (member p (nth 1 e)) (setf (nth 1 e) (cons p (nth 1 e)))))
               (when (cdr spec) (setf (nth 2 e) t))
               (puthash cmd e table))))
         nil nil nil (and (cdr spec) (vector ?\s)))))
    table))

(defun voice-emacs--history ()
  "Command name -> how often M-x ran it lately."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (s (bound-and-true-p extended-command-history))
      (puthash s (1+ (gethash s h 0)) h))
    h))

(defun voice-emacs--own-mode (cmd)
  "The major modes CMD belongs to, by its name, longest first
\(beancount-insert-date: beancount-mode; org-agenda-goto-date:
org-agenda-mode and org-mode), or nil."
  (let* ((words (split-string (symbol-name cmd) "[-/]" t)) modes)
    (dotimes (i (1- (length words)))
      (let ((mode (intern-soft (concat (string-join (seq-take words (1+ i)) "-") "-mode"))))
        (when (and mode (fboundp mode) (not (memq mode minor-mode-list))
                   (not (boundp mode)))            ; a minor mode has a variable
          (push mode modes))))
    ;; The first word alone, as ever, even when the name is one word more.
    (unless modes
      (let ((mode (and words (intern-soft (concat (car words) "-mode")))))
        (when (and mode (fboundp mode) (not (memq mode minor-mode-list)) (not (boundp mode)))
          (push mode modes))))
    modes))

(defun voice-emacs--entry-point-p (cmd)
  "Non-nil when CMD is a way into its package, meant to be run from
anywhere: named just as the package (magit, dired, calendar), or
autoloaded, which is a package saying so."
  (or (not (string-match-p "[-/]" (symbol-name cmd)))
      (and (fboundp 'help-fns--autoloaded-p)
           (ignore-errors (help-fns--autoloaded-p cmd)))))

(defvar voice-emacs--features nil "Names of the features loaded, a hash, while the catalog is made.")

(defun voice-emacs--short-name (cmd)
  "CMD's name past its namespace, as tokens, when that says something
alone (two words or more): doom/window-enlargen is \"window enlargen\",
evil-window-left (evil is a library) \"window left\"; +zen/toggle is no
\"toggle\".  A key's lambda has none."
  (let ((name (symbol-name cmd)) rest)
    (unless (get cmd 'voice-label)
      (if (string-match "/\\([^/]+\\)\\'" name)
          (setq rest (match-string 1 name))
        ;; The longest leading words naming a library loaded.
        (let ((words (split-string name "-" t)))
          (cl-loop for i from (- (length words) 2) downto 1
                   when (and voice-emacs--features
                             (gethash (string-join (seq-take words i) "-") voice-emacs--features))
                   return (setq rest (string-join (nthcdr i words) "-")))))
      (let ((toks (and rest (voice-match-tokens rest))))
        (and (cdr toks) toks)))))

(defun voice-emacs--entry (cmd labels history)
  "CMD as a candidate for voice-match: its name, labels, prefixes, prior,
and the major mode it belongs to unless a global key or the leader has it."
  (let* ((l (gethash cmd labels))
         (count (gethash (symbol-name cmd) history 0)))
    (list :title (voice-emacs--name-words cmd)
          :mode (and (not l) (zerop count) (not (voice-emacs--entry-point-p cmd))
                     (voice-emacs--own-mode cmd))
          :aliases (nth 0 l)
          :bare (mapcar #'voice-match-tokens (nth 3 l))
          :plain (mapcar #'voice-match-tokens (nth 4 l))
          :menu (mapcar #'voice-match-tokens (nth 5 l))
          ;; As said, unstemmed: \"pull request\" is not \"pull requests\".
          :literal (mapcar #'voice-emacs--literal (append (nth 0 l) (nth 3 l) (nth 4 l)))
          :short (voice-emacs--short-name cmd)
          :extra (and (nth 1 l) (string-join (nth 1 l) " "))
          :prior (+ (cond ((nth 2 l) 0.04) (l 0.02) (t 0.0))
                    (if (> count 0) (min 0.08 (+ 0.03 (* 0.01 count))) 0.0))
          :cmd cmd)))

(defun voice-emacs--commands ()
  "Every command voice may offer."
  (let (cmds)
    (mapatoms (lambda (s)
                (when (and (commandp s)
                           (not (get s 'byte-obsolete-info))
                           (not (get s 'voice-skip))
                           (not (string-match-p voice-emacs-skip-regexp (symbol-name s))))
                  (push s cmds))))
    cmds))

(defun voice-emacs-catalog ()
  "The index of every command; looked at again when old, rebuilt when
commands came or went (a package loaded)."
  (if (and voice-emacs--catalog
           (< (float-time (time-since (car voice-emacs--catalog))) voice-emacs-refresh-seconds))
      (cddr voice-emacs--catalog)
    ;; The labels first: they name the leader's lambdas, which are commands then.
    (let* ((labels (voice-emacs--labels))
           (cmds (voice-emacs--commands)))
      (if (and voice-emacs--catalog (= (length cmds) (cadr voice-emacs--catalog)))
          (progn (setcar voice-emacs--catalog (current-time))
                 (cddr voice-emacs--catalog))
        (let* ((history (voice-emacs--history))
               (voice-emacs--features (let ((h (make-hash-table :test 'equal :size (length features))))
                                        (dolist (f features h) (puthash (symbol-name f) t h))))
               (index (voice-match-index
                       (mapcar (lambda (c) (voice-emacs--entry c labels history)) cmds))))
          (setq voice-emacs--catalog (cons (current-time) (cons (length cmds) index)))
          index)))))

(defvar voice-emacs--by-cmd nil "(INDEX . TABLE): command -> its entry in INDEX.")
(defvar voice-emacs--said nil "(INDEX . TABLE): what commands are called, sorted tokens joined -> ((CMD . WAY)...).")

(defconst voice-emacs-exact-order '(here key label plain name short menu)
  "Which way of being said just so wins, first first: what a key of the
buffer in front calls it, what a leader key calls it (what you see, and
chose) with its group or without, then without its note (\"Open repl\"
before \"Open repl (same window)\"), then a command's own name, with its
namespace or without (doom/window-enlargen: \"window enlargen\"), and
last the menu bar's name (\"select all\").")

(defconst voice-emacs-shared-ways '(short menu)
  "Ways of being called that name a command only when no other command
there is so called: \"next heading\" is outline's, reftex's and others'
short name, so none of theirs.")

(defun voice-emacs--sole-p (cmd way toks modes)
  "Non-nil when CMD is the one command called TOKS (sorted) the WAY given,
of those for MODES (or for any mode)."
  (let ((hits (seq-filter
               (lambda (h)
                 (and (eq (cdr h) way)
                      (let ((m (plist-get (voice-emacs--entry-of (car h)) :mode)))
                        (or (null m) (seq-intersection m modes)))))
               (gethash (string-join toks " ") (voice-emacs--said-index)))))
    (and hits (null (cdr (delete-dups (mapcar #'car hits)))) (eq (caar hits) cmd))))

(defun voice-emacs--better-way-p (a b)
  "Non-nil when way A of being said just so is better than B."
  (and a (or (null b) (< (cl-position a voice-emacs-exact-order) (cl-position b voice-emacs-exact-order)))))

(defun voice-emacs--said-index ()
  "What each command of the catalog is called, any order: an index from
the words (sorted tokens) to the commands so called and how (key, label,
plain, short, menu), so being said just so never waits on ranking."
  (let ((index (voice-emacs-catalog)))
    (unless (eq (car voice-emacs--said) index)
      (let ((h (make-hash-table :test 'equal)))
        (seq-doseq (e (voice-match-index-entries index))
          (dolist (way '((:aliases . key) (:bare . label) (:plain . plain) (:menu . menu)))
            (dolist (toks (plist-get e (car way)))
              ;; A menu's one word says too little alone ("Reload": envrc's).
              (when (and toks (or (cdr toks) (not (eq (cdr way) 'menu))))
                (push (cons (plist-get e :cmd) (cdr way))
                      (gethash (string-join (sort (copy-sequence toks) #'string<) " ") h)))))
          (let ((short (plist-get e :short)))
            (when short
              (push (cons (plist-get e :cmd) 'short)
                    (gethash (string-join (sort (copy-sequence short) #'string<) " ") h)))))
        (setq voice-emacs--said (cons index h))))
    (cdr voice-emacs--said)))

(defun voice-emacs--entry-of (cmd)
  "CMD's entry in the catalog, or nil."
  (let ((index (voice-emacs-catalog)))
    (unless (eq (car voice-emacs--by-cmd) index)
      (let ((h (make-hash-table :test 'eq)))
        (seq-doseq (e (voice-match-index-entries index)) (puthash (plist-get e :cmd) e h))
        (setq voice-emacs--by-cmd (cons index h))))
    (gethash cmd (cdr voice-emacs--by-cmd))))

(defun voice-emacs-label (cmd)
  "How CMD is shown: what its key calls it, else its name's words."
  (let ((e (voice-emacs--entry-of cmd)))
    (or (car (plist-get e :aliases)) (voice-emacs--name-words cmd))))

(defvar voice-emacs--here-cache nil
  "(MAPS TIME HERE): the keymaps of the buffer in front last asked about,
when, and what they bind.")

(defun voice-emacs-here ()
  "Commands the buffer in front binds -- its mode's keys, its local leader,
its minor modes' -- as `voice-emacs--here-of' gives them; walked again
when the keymaps differ, or are `voice-emacs-refresh-seconds' old."
  (with-current-buffer (window-buffer (selected-window))
    (let ((maps (cons (current-local-map) (current-minor-mode-maps)))
          (c voice-emacs--here-cache))
      (if (and c (= (length maps) (length (car c))) (cl-every #'eq maps (car c))
               (< (float-time (time-since (nth 1 c))) voice-emacs-refresh-seconds))
          (nth 2 c)
        (let ((h (voice-emacs--here-of maps)))
          (setq voice-emacs--here-cache (list maps (current-time) h))
          h)))))

(defun voice-emacs--here-of (maps)
  "The commands MAPS bind, each to what those keys call it, (WITHIN-GROUP
. LABEL) pairs (\"Deadline date\" . \"Deadline\"), or t when they call it
nothing.  A lambda with a label comes as its `voice-emacs--key-command'
name."
  (let ((h (make-hash-table :test 'eq))
        (seen (make-hash-table :test 'eq)))
    (dolist (map maps)
      (when (keymapp map)
        (voice-emacs--walk
         map
         (lambda (def label prefixes keys)
           (let ((cmd (voice-emacs--key-command def label keys t)))
             (when cmd
               (let ((old (gethash cmd h)))
                 (puthash cmd (if label
                                  (let ((plain (voice-emacs--label-name label)))
                                    (append (list (cons (voice-emacs--within label (car prefixes)) label))
                                            (and (not (equal plain label))
                                                 (list (cons (voice-emacs--within plain (car prefixes)) plain)))
                                            (and (consp old) old)))
                                (or old t))
                          h)))))
         nil seen)))
    h))

(defvar voice-emacs--here-labels-cache (make-hash-table :test 'eq :weakness 'key)
  "HERE -> its labels, as `voice-emacs--here-labels' makes them once.")

(defun voice-emacs--here-labels (here)
  "HERE (`voice-emacs-here')'s labels: (VECTOR . KEYS), VECTOR of (CMD
WITHIN-TOKENS LABEL-TOKENS), one per label, KEYS the lookup keys of their
words (`voice-match--keys') to indices in VECTOR."
  (or (and (hash-table-p here) (gethash here voice-emacs--here-labels-cache))
      (let (all (keys (make-hash-table :test 'equal)))
        (when (hash-table-p here)
          (maphash (lambda (cmd labels)
                     (when (consp labels)
                       (dolist (l labels)
                         (push (list cmd (voice-match-tokens (car l)) (voice-match-tokens (cdr l))) all))))
                   here))
        (let ((vec (vconcat all)))
          (dotimes (i (length vec))
            (dolist (tok (delete-dups (append (nth 1 (aref vec i)) (nth 2 (aref vec i)) nil)))
              (dolist (k (voice-match--keys tok)) (push i (gethash k keys)))))
          (let ((r (cons vec keys)))
            (when (hash-table-p here) (puthash here r voice-emacs--here-labels-cache))
            r)))))

(defun voice-emacs--here-candidates (here toks)
  "The labels of HERE that TOKS may say: those sharing a lookup key with
a word of TOKS or a word it means (`voice-match-expand'), as the catalog
finds its candidates."
  (let* ((labels (voice-emacs--here-labels here)) (seen (make-hash-table)) out)
    (dolist (x toks)
      (dolist (k (append (voice-match--keys x)
                         (and voice-match-expand (funcall voice-match-expand x))))
        (dolist (i (gethash k (cdr labels)))
          (unless (gethash i seen)
            (puthash i t seen)
            (push (aref (car labels) i) out)))))
    out))

;;;; What a command asks for

(defvar voice-emacs--theme-cache nil "(THEMES . VALUES).")

(defvar voice-emacs--extras (make-hash-table :test 'equal)
  "A value's name -> the words that describe it, for any kind looked at.")

(defun voice-emacs--themes ()
  "The themes there are, each described by its own file."
  (let ((themes (ignore-errors (custom-available-themes))))
    (if (and voice-emacs--theme-cache (equal (car voice-emacs--theme-cache) themes))
        (cdr voice-emacs--theme-cache)
      (let ((values (mapcar (lambda (th)
                              (let ((doc (voice-emacs--theme-doc th)))
                                (when doc (puthash (symbol-name th) doc voice-emacs--extras))
                                (list :title (symbol-name th) :extra doc)))
                            themes)))
        (setq voice-emacs--theme-cache (cons themes values))
        values))))

(defun voice-emacs--theme-doc (theme)
  "What THEME's file says it is (\"A dark theme inspired by Atom One
Dark.\"), and its background, dark or light."
  (let* ((name (symbol-name theme))
         (file (ignore-errors (locate-file (concat name "-theme") (custom-theme--load-path)
                                           '(".el" ".el.gz")))))
    (when file
      (with-temp-buffer
        (ignore-errors (insert-file-contents file nil 0 40000))
        (goto-char (point-min))
        (let (doc mode)
          (when (re-search-forward (concat "(\\(?:[[:alnum:]-]*theme\\)[ \t\n]+'?"
                                           (regexp-quote name) "[ \t\n]+\"")
                                   nil t)
            (goto-char (1- (point)))
            (setq doc (ignore-errors (read (current-buffer))))
            (when (re-search-forward ":background-mode[ \t\n]+'?\\(dark\\|light\\)"
                                     (min (point-max) (+ (point) 2000)) t)
              (setq mode (match-string 1))))
          (let ((first (and (stringp doc) (car (split-string doc "\n" t)))))
            (and (or first mode)
                 (string-join (delq nil (list first (and mode (concat mode " background")))) " "))))))))

(defun voice-emacs--buffers ()
  (mapcar (lambda (b) (list :title (buffer-name b)))
          (seq-remove (lambda (b) (string-prefix-p " " (buffer-name b))) (buffer-list))))

(defun voice-emacs--files ()
  (mapcar (lambda (f) (list :title (file-name-nondirectory (directory-file-name f))
                            :extra (file-name-directory f)
                            :answer (abbreviate-file-name f)))
          (seq-take (bound-and-true-p recentf-list) 300)))

(defun voice-emacs--bookmarks ()
  (and (featurep 'bookmark)
       (mapcar (lambda (b) (list :title b)) (ignore-errors (bookmark-all-names)))))

(defvar voice-emacs-domains
  '((theme :args "\\`theme\\'" :values voice-emacs--themes :alone t)
    (buffer :args "buffer" :spec "bB" :values voice-emacs--buffers)
    (file :args "\\`file\\|filename" :spec "fFG" :values voice-emacs--files)
    (bookmark :args "\\`bookmark" :values voice-emacs--bookmarks)
    (directory :args "\\`dir" :spec "D")
    (command :args "\\`command\\'" :spec "C")
    (function :args "\\`function\\'" :spec "a")
    (variable :args "\\`variable\\'" :spec "v")
    (text :spec "sM"))
  "Kinds of things commands ask for.  A command's kind is known by its
interactive codes (:spec), else its first argument's name (:args), else,
for a kind with values, its name's words (consult-buffer asks a buffer).
:values gives the ones there are, as plists: :title, :extra (words that
describe it), :answer (what to give the question, else the title).
:alone: its values' words are their own (a theme's name and description;
any word is in some file's path): a value said alone, or words its values
use (\"dark\"), name a command of the kind.")

(defconst voice-emacs--input-codes (string-to-list "abBcCDfFGkKMnNsSvxXzZ")
  "Interactive codes that read something.")

(defun voice-emacs--codes (spec)
  "The input codes of interactive SPEC, a string."
  (seq-filter (lambda (c) (memq c voice-emacs--input-codes))
              (delq nil (mapcar (lambda (item)
                                  (let ((item (replace-regexp-in-string "\\`[*@^]+" "" item)))
                                    (and (> (length item) 0) (aref item 0))))
                                (split-string spec "\n")))))

(defvar voice-emacs--asks-cache (make-hash-table :test 'eq)
  "Command -> (FUNCTION . ASKS), good while its function is that.")

(defun voice-emacs-asks (cmd)
  "What CMD asks for, as (KIND . READS): KIND one of
`voice-emacs-domains' or nil; READS t, nil (it asks nothing) or maybe.
An autoloaded command is never loaded for this: its name tells."
  (let ((fn (ignore-errors (indirect-function cmd)))
        (hit (gethash cmd voice-emacs--asks-cache)))
    (if (and hit (eq (car hit) fn)) (cdr hit)
      (cdr (puthash cmd (cons fn (voice-emacs--asks cmd fn)) voice-emacs--asks-cache)))))

(defun voice-emacs--asks (cmd fn)
  "`voice-emacs-asks' worked out, FN being CMD's function."
  (let* ((fn fn)
         (loaded (and fn (not (autoloadp fn))))
         (spec (and loaded (ignore-errors (cadr (interactive-form cmd)))))
         ;; An autoloaded one's arguments are in its docstring's usage.
         (args (if loaded (ignore-errors (help-function-arglist cmd t))
                 ;; (None there: it takes none.)
                 (let ((usage (car (ignore-errors (help-split-fundoc (documentation cmd t) cmd)))))
                   (and usage (ignore-errors (cdr (read (downcase usage))))))))
         (first (and (listp args)
                     (seq-find (lambda (a) (and (symbolp a) (not (memq a '(&optional &rest))))) args)))
         (codes (and (stringp spec) (voice-emacs--codes spec)))
         (silent (and (stringp spec) (null codes)))
         (words (split-string (voice-emacs--name-words cmd)))
         (kind (car (or (and codes
                             (seq-find (lambda (d) (let ((s (plist-get (cdr d) :spec)))
                                                     (and s (seq-some (lambda (c) (seq-contains-p s c)) codes))))
                                       voice-emacs-domains))
                        (and first (not silent)
                             (seq-find (lambda (d) (let ((re (plist-get (cdr d) :args)))
                                                     (and re (string-match-p re (downcase (symbol-name first))))))
                                       voice-emacs-domains))
                        ;; By name, its last word, if it takes something:
                        ;; consult-buffer (sources) asks a buffer; doom/
                        ;; reload-theme takes nothing, flymake-show-buffer-
                        ;; diagnostics a diagnostic.
                        (and (not silent) (not codes) (or (not (listp args)) first)
                             (seq-find (lambda (d) (and (plist-get (cdr d) :values)
                                                        (equal (symbol-name (car d)) (car (last words)))))
                                       voice-emacs-domains))))))
    ;; Nothing else asked, a count it may take: \"down 5\" is <down> five times.
    (when (and (null kind) (voice-emacs--takes-count-p spec first))
      (setq kind 'number))
    (cons kind (cond (silent nil) ((or (and kind (not (eq kind 'number))) codes) t) (t 'maybe)))))

(defvar voice-emacs-count-args "\\`\\(?:count\\|n\\|lines?\\|num\\|number\\)\\'"
  "A command's first argument so named is a count, when its interactive
form is not a string to tell (evil's motions: count; goto-line: line).")

(defun voice-emacs--takes-count-p (spec first)
  "Non-nil when a command with interactive SPEC and FIRST argument takes a
number: its prefix argument (p, P), one it reads (n, N), or, its form no
string, a first argument named so (`voice-emacs-count-args')."
  (if (stringp spec)
      (string-match-p "\\(?:\\`\\|\n\\)[*@^]*[pPnN]" spec)
    (and first (string-match-p voice-emacs-count-args (downcase (symbol-name first))))))

(defun voice-emacs--count (tokens &optional own)
  "The number TOKENS say, words OWN has (the command's own: \"down 5
lines\") aside: \"5\", \"forty two\" (40 2); else nil."
  (let ((toks (seq-remove (lambda (x) (member x own)) tokens)))
    (and toks (seq-every-p (lambda (x) (string-match-p "\\`[0-9]+\\'" x)) toks)
         (let ((ns (mapcar #'string-to-number toks)))
           (pcase ns
             (`(,a) a)
             ;; forty two: tens then a unit
             (`(,a ,b) (and (>= a 20) (zerop (% a 10)) (< b 10) (+ a b))))))))

(defun voice-emacs-values (kind)
  "The values of KIND there are now."
  (let ((f (plist-get (cdr (assq kind voice-emacs-domains)) :values)))
    (and f (ignore-errors (funcall f)))))

(defun voice-emacs--kind-data (kind)
  "KIND's values now, as (INDEX . VOCABULARY): the index to name one by,
and every word they and their descriptions use."
  (let ((values (voice-emacs-values kind)))
    (and values
         (cons (voice-match-index values)
               (let (all)
                 (dolist (v values (delete-dups all))
                   (setq all (nconc (voice-match-tokens (concat (plist-get v :title) " "
                                                                (or (plist-get v :extra) "")))
                                    all))))))))

(defun voice-emacs--value (data tokens)
  "The value DATA's index has that TOKENS name clearly, as (ANSWER . S):
one called just that (\"doom one\", though doom-one-light has those words
too), else the clear best."
  (let* ((exact (and tokens (seq-find (lambda (e) (equal (plist-get e :words) tokens))
                                      (voice-match-index-entries (car data)))))
         (ranked (and data tokens (not exact) (voice-match-rank (car data) tokens 2)))
         (e (or exact (and ranked (eq (voice-match-decide ranked) 'act) (>= (nth 1 (car ranked)) 0.8)
                           (nth 2 (car ranked))))))
    (and e (cons (or (plist-get e :answer) (plist-get e :title)) (if exact 1.0 (nth 1 (car ranked)))))))

(defun voice-emacs--evidence (data tokens catalog)
  "How much of TOKENS the values in DATA use, each token counted by how
rare it is among commands' words: in \"dark mode\", dark (themes have it,
few commands) counts, mode (thousands of commands) barely.  0 to 1."
  (let ((num 0.0) (den 0.0))
    (when (cdr data)
      (dolist (x tokens)
        (let ((w (voice-match--idf catalog x)))
          (cl-incf den w)
          (when (>= (voice-match--best-sim x (cdr data)) 0.85) (cl-incf num w)))))
    (if (> den 0) (/ num den) 0.0)))

(defun voice-emacs-order (text strings)
  "STRINGS with the closest to TEXT first, by name and description (a
theme's \"dark\"); nil when none is near."
  (let* ((index (voice-match-index (mapcar (lambda (s) (list :title s :extra (gethash s voice-emacs--extras)))
                                           strings)))
         (near (mapcar (lambda (r) (plist-get (nth 2 r) :title))
                       (seq-filter (lambda (r) (>= (nth 1 r) 0.2)) (voice-match-rank index text)))))
    (and near (append near (seq-difference strings near)))))

;;;; Ranking what was said

(defconst voice-emacs--leads
  '("to" "two" "too" "on" "the" "my" "for" "into" "in" "a" "an" "as" "with" "called" "named" "of" "at")
  "Words before what a command asks for: \"change theme TO tango dark\".")

(defun voice-emacs--lead-off (words)
  "WORDS (pairs) without the leading `voice-emacs--leads'."
  (while (and words (member (downcase (car (car words))) voice-emacs--leads))
    (pop words))
  words)

(defun voice-emacs--spoken (tokens)
  "TOKENS (an index entry's alias) as words again."
  (if (stringp tokens) tokens (string-join tokens " ")))

(defun voice-emacs--said-as (said names)
  "Non-nil when SAID (sorted tokens) is one of NAMES (token lists), in any order."
  (seq-some (lambda (a) (equal said (sort (copy-sequence a) #'string<))) names))

(defun voice-emacs--tokens (words)
  (voice-match-tokens (mapconcat #'car words " ")))

(defun voice-emacs--key (cmd)
  "What CMD does, so a command and the one it is remapped to count once."
  (let ((real (or (command-remapping cmd) cmd)))
    (or (ignore-errors (let ((f (indirect-function real))) (and (not (autoloadp f)) f))) real)))

(defvar voice-emacs-unsaid 0.85
  "How near a command of a kind is when only a value of the kind was said
\(\"switch to dark mode\", \"doom one\"): the same for each, so the priors
pick among them.")

(defvar voice-emacs-default-verb "change"
  "What a thing named with no verb is to be done with: \"doom one theme\"
is weighed as \"change theme\", so load-theme comes before disable-theme.")

(defvar voice-emacs-head-words 5
  "Most words a command's name takes in what is said; the rest is what it asks.")

(defvar voice-emacs-elsewhere 0.85
  "What a mode's own command counts for outside that mode: beancount's
insert date, said in an Org buffer.")

(defun voice-emacs-rank (words &optional context limit)
  "Commands WORDS ((RAW . TOKEN) pairs) may mean, best first, at most
LIMIT: plists with :s (how near, 0 to 1), :f (:s plus the priors, which
only break ties), :cmd, :slot (the words left for what it asks, as
pairs), :value (the answer they name), :label (how it is called), :kind,
:exact (here: what a key of the buffer in front calls it; key: what the
leader's key calls it, with its group; label: the same, its group unsaid;
plain: its note unsaid too; name: what was said is its name; short: its
name, namespace unsaid; menu: the menu bar's name), :literal (said word
for word, unstemmed).
CONTEXT: (:here COMMANDS :modes MODES), the commands the buffer in front
binds (`voice-emacs-here') and its major mode and parents; a mode's own
command outside it counts `voice-emacs-elsewhere'.

Each split counts: the first words name the command (S, as any title),
the rest are what it asks for.  The rest counts by its share of what was
said (words weighed by rarity) times how well it is explained: a value of
the command's kind named, fully; words its kind's values use, by how
many; text for a command that reads text, 0.6; anything else 0.3; and
nothing for a command that asks nothing."
  (voice-emacs--with-meanings
   (let* ((catalog (voice-emacs-catalog))
          (here (plist-get context :here))
          (modes (plist-get context :modes))
          (prior-fn (and here (lambda (e) (and (gethash (plist-get e :cmd) here) 0.06))))
          (n (length words))
          (literal (voice-emacs--literal (mapconcat #'car words " ")))
          (memo (make-hash-table :test 'equal))
          (rank (lambda (toks lim)
                  (let ((key (cons lim toks)))
                    (or (gethash key memo)
                        (puthash key (voice-match-rank catalog toks lim prior-fn) memo)))))
          (data (make-hash-table :test 'eq))
          (kind-data (lambda (kind)
                       (if (gethash kind data 'none)
                           (let ((d (gethash kind data 'none)))
                             (if (eq d 'none) (puthash kind (voice-emacs--kind-data kind) data) d))
                         nil)))
          (values-memo (make-hash-table :test 'equal))
          (value (lambda (kind d toks)
                   (let ((key (cons kind toks)))
                     (car (or (gethash key values-memo)
                              (puthash key (list (voice-emacs--value d toks)) values-memo))))))
          (evidence-memo (make-hash-table :test 'equal))
          (evidence (lambda (kind d toks)
                      (let ((key (cons kind toks)))
                        (or (gethash key evidence-memo)
                            (puthash key (voice-emacs--evidence d toks catalog) evidence-memo)))))
          (weight (lambda (toks) (apply #'+ 0.0 (mapcar (lambda (x) (voice-match--idf catalog x)) toks))))
          (best (make-hash-table :test 'eq))
          (seen nil)
          (keep (lambda (cmd s p slot value e kind &optional exact)
                  ;; A command and the one it is remapped to are one: the
                  ;; better way it was said, the higher of their priors.
                  (let* ((key (voice-emacs--key cmd))
                         (old (gethash key best))
                         (s (if (and (plist-get e :mode) (not (seq-intersection (plist-get e :mode) modes)))
                                (* s voice-emacs-elsewhere)
                              s))
                         (p (max p (or (plist-get old :p) 0.0))))
                    ;; Said just so one way, nearer another: still said just so,
                    ;; the better way.
                    (when (and old (null slot) (eq cmd (plist-get old :cmd))
                               (voice-emacs--better-way-p (plist-get old :exact) exact))
                      (setq exact (plist-get old :exact)))
                    (when (and old (null slot) (eq cmd (plist-get old :cmd)) (= s (plist-get old :s))
                               (voice-emacs--better-way-p exact (plist-get old :exact)))
                      (plist-put old :exact exact))
                    ;; Nearer, or as near and said a better way (org-timestamp
                    ;; said, org-time-stamp its alias found first).
                    (if (or (> s (or (plist-get old :s) -1.0))
                            (and old (= s (plist-get old :s))
                                 (voice-emacs--better-way-p exact (plist-get old :exact))))
                        (puthash key (list :s s :p p :f (+ s (if (>= s 0.5) p 0.0)) :cmd cmd
                                           :slot slot :value value :kind kind :exact exact
                                           :literal (and exact (member literal (plist-get e :literal)) t)
                                           :label (if (plist-get e :aliases)
                                                      (voice-emacs--spoken (car (plist-get e :aliases)))
                                                    (plist-get e :title)))
                                 best)
                      (when old
                        (setq old (plist-put old :p p))
                        (plist-put old :f (+ (plist-get old :s) (if (>= (plist-get old :s) 0.5) p 0.0)))))))))
     (cl-loop
      for k from n downto 1 do
      (let* ((head (seq-take words k))
             (tail (and (< k n) (voice-emacs--lead-off (nthcdr k words))))
             (htoks (voice-emacs--tokens head))
             (ttoks (voice-emacs--tokens tail)))
        ;; All that was said may be a name however long ("jupyter org
        ;; next busy src block"); a name with words after it, at most so long.
        (when (and htoks (or (= k n) (<= (length htoks) voice-emacs-head-words))
                   (or (= k n) ttoks)
                   (not (member (cons htoks ttoks) seen)))
          (push (cons htoks ttoks) seen)
          (let ((share (if (= k n) 1.0
                         (let ((h (funcall weight htoks)) (tw (funcall weight ttoks)))
                           (if (> (+ h tw) 0) (/ h (+ h tw)) 0.5)))))
            (dolist (r (funcall rank htoks 25))
              (let* ((e (nth 2 r)) (cmd (plist-get e :cmd)) (s (nth 1 r)) (p (- (car r) s)))
                (if (= k n)
                    (funcall keep cmd s p nil nil e nil
                             (let ((said (sort (copy-sequence htoks) #'string<)))
                               ;; The best way it was said (`voice-emacs-exact-order').
                               ;; In any order: "toggle line numbers" is SPC t l,
                               ;; "Line numbers" under toggle.
                               (cond ((voice-emacs--said-as said (plist-get e :aliases)) 'key)
                                     ;; Its group unsaid: "restart emacs", SPC q r.
                                     ((voice-emacs--said-as said (plist-get e :bare)) 'label)
                                     ;; Its note unsaid: "add project".
                                     ((voice-emacs--said-as said (plist-get e :plain)) 'plain)
                                     ((equal htoks (plist-get e :words)) 'name)
                                     ;; Its namespace unsaid: "window enlargen".
                                     ((and (equal htoks (plist-get e :short))
                                           (voice-emacs--sole-p cmd 'short said modes))
                                      'short)
                                     ;; The menu bar's name: "select all".
                                     ((and (cdr said) (voice-emacs--said-as said (plist-get e :menu))
                                           (voice-emacs--sole-p cmd 'menu said modes))
                                      'menu))))
                  (let* ((asks (voice-emacs-asks cmd)) (kind (car asks))
                         (d (and kind (not (eq kind 'number)) (funcall kind-data kind)))
                         (v (if (eq kind 'number)
                                (let ((n (voice-emacs--count
                                          ttoks (append (plist-get e :words) (apply #'append (plist-get e :aliases))))))
                                  (and n (cons n 1.0)))
                              (and d (funcall value kind d ttoks))))
                         (explained (cond ((eq kind 'number) (if v 1.0 0.0))
                                          ((null (cdr asks)) 0.0)
                                          (v (cdr v))
                                          ((and d (plist-get (cdr (assq kind voice-emacs-domains)) :alone))
                                           (funcall evidence kind d ttoks))
                                          ((eq kind 'text) 0.6)
                                          (t 0.3))))
                    (funcall keep cmd (* s (+ share (* (- 1 share) explained))) p
                             tail (car v) e kind)))))
            ;; A value said, its kind not: "switch to DARK mode" is a theme.
            (when (< k n)
              (dolist (dom voice-emacs-domains)
                (let* ((kind (car dom))
                       ;; (Its kind said anywhere, the splits above have it.)
                       (d (and (plist-get (cdr dom) :alone)
                               (not (member (symbol-name kind) htoks))
                               (not (member (symbol-name kind) ttoks))
                               (funcall kind-data kind)))
                       (ev (if d (funcall evidence kind d ttoks) 0.0)))
                  (when (>= ev 0.5)
                    (let* ((v (funcall value kind d ttoks))
                           (factor (+ share (* (- 1 share) (if v (cdr v) ev)))))
                      ;; The kind was not said: how its name says it
                      ;; tells nothing, the priors pick; but with no verb
                      ;; said either, the commands that use the thing.
                      (let* ((ranked (funcall rank (cons (or (car htoks) voice-emacs-default-verb)
                                                         (append (cdr htoks) (list (symbol-name kind))))
                                              10))
                             (top (and (null htoks)
                                       (cl-loop for r in ranked
                                                when (eq (car (voice-emacs-asks (plist-get (nth 2 r) :cmd))) kind)
                                                maximize (nth 1 r)))))
                        (dolist (r ranked)
                          (let ((e (nth 2 r)))
                            (when (eq (car (voice-emacs-asks (plist-get e :cmd))) kind)
                              (funcall keep (plist-get e :cmd)
                                       (* 0.9 voice-emacs-unsaid factor (if top (/ (nth 1 r) top) 1.0))
                                       (- (car r) (nth 1 r)) tail (car v) e kind))))))))))))))
     ;; Called just so, whether the ranking found it or not: "select all"
     ;; (the menu's mark-whole-buffer), "window left".
     (let ((all (voice-emacs--tokens words)))
       (when all
         (let ((said (sort (copy-sequence all) #'string<)))
           (dolist (hit (gethash (string-join said " ") (voice-emacs--said-index)))
             (let ((e (voice-emacs--entry-of (car hit))))
               (when (and e (or (not (memq (cdr hit) voice-emacs-shared-ways))
                                (voice-emacs--sole-p (car hit) (cdr hit) said modes)))
                 (funcall keep (car hit) 1.0 (or (plist-get e :prior) 0.0) nil nil e nil (cdr hit))))))))
     ;; What the keys of the buffer in front call a command: "next cell" in
     ;; a notebook, "deadline" under Org's local leader.  Said just so, it
     ;; is that command (:exact here), before any other of the name.
     (let ((all (voice-emacs--tokens words)))
       (when all
         (let ((said (sort (copy-sequence all) #'string<)))
           (dolist (l (voice-emacs--here-candidates here all))
             (let ((s (max (voice-match--score-words catalog all (nth 1 l) nil)
                           (voice-match--score-words catalog all (nth 2 l) nil))))
               (when (>= s 0.5)
                 (let* ((cmd (car l))
                        (e (append (list :aliases (list (nth 1 l)) :mode nil)
                                   (or (voice-emacs--entry-of cmd)
                                       (list :title (voice-emacs--name-words cmd) :cmd cmd)))))
                   (funcall keep cmd s 0.06 nil nil e nil
                            (and (voice-emacs--said-as said (cdr l)) 'here)))))))))
     ;; A value alone, of a kind whose names are its own: "doom acario
     ;; dark" is a theme, to load.
     (let ((all (voice-emacs--tokens (voice-emacs--lead-off words))))
       (dolist (dom voice-emacs-domains)
         (let* ((kind (car dom))
                ;; Its kind said too, after it: "doom one theme".
                (toks (remove (symbol-name kind) all))
                (d (and toks (plist-get (cdr dom) :alone) (funcall kind-data kind)))
                (v (and d (funcall value kind d toks))))
           (when v
             ;; Said with no verb, it is to be used: the commands are
             ;; weighed as if "change theme" was said, relative to the best.
             (let* ((ranked (funcall rank (list voice-emacs-default-verb (symbol-name kind)) 10))
                    (top (or (cl-loop for r in ranked
                                      when (eq (car (voice-emacs-asks (plist-get (nth 2 r) :cmd))) kind)
                                      maximize (nth 1 r))
                             1.0)))
               (dolist (r ranked)
                 (let ((e (nth 2 r)))
                   (when (eq (car (voice-emacs-asks (plist-get e :cmd))) kind)
                     (funcall keep (plist-get e :cmd) (* 0.9 voice-emacs-unsaid (cdr v) (/ (nth 1 r) top))
                              (- (car r) (nth 1 r)) (voice-emacs--lead-off words) (car v) e kind)))))))))
     (let (out)
       (maphash (lambda (_k v) (push v out)) best)
       ;; On a tie, what was said just so first: nine winum-select-window-N
       ;; are as near "winum select window 1" (a count), one is called so.
       (setq out (sort out (lambda (a b)
                             (or (> (plist-get a :f) (plist-get b :f))
                                 (and (= (plist-get a :f) (plist-get b :f))
                                      (or (voice-emacs--better-way-p (plist-get a :exact) (plist-get b :exact))
                                          (and (eq (plist-get a :exact) (plist-get b :exact))
                                               (> (plist-get a :s) (plist-get b :s)))))))))
       (if (and limit (> (length out) limit)) (seq-take out limit) out)))))

(provide 'voice-emacs)
;;; voice-emacs.el ends here
