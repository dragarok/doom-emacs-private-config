;;; voice-command.el --- Say it, and Emacs does it -*- lexical-binding: t -*-

;;; Commentary:
;; Speak, and Emacs does the closest thing: clock in to a task, clock out,
;; add a task, answer the question on screen, or run a command.
;;
;; On the phone the words come from the voice app (FUTO, offline) through
;; Emacs Home: the toolbar's Voice button, or a long press on the clock
;; island from any app.  The app writes what it heard to voice-heard.tsv
;; and calls `voice-from-app'.  Anywhere, `voice-command' (SPC V) takes
;; typed words the same way.
;;
;; One pattern for everything: an action is a few phrases and a command.
;;   (voice-action '("clock in to …" "start …") #'voice-clock-in :slot 'task)
;; "…" is the rest of what was said.  When the command asks something, a
;; question already answered in the sentence is filled in -- "done, deep
;; work" answers rts-flow-clock-out's question, "attach camera photo" picks
;; [c]amera -- and the rest are asked, as always, in the minibuffer.  Any
;; open question can be answered by voice too: a choice by its name or
;; "the second one", free text as said.  So most commands work by voice
;; with no voice code, and an action names only what it needs.
;;
;; Toolbar buttons and homepage tiles are actions already, by their labels.
;;
;; Spoken words are data.  They only pick an action from this list, or a
;; task; they are never read as Lisp.  No link opens the microphone.
;;
;; Rules you edit live in ~/org/voice.org: "* Names" (another name for a
;; task; a pick from the list adds one) and "* Phrases" (say this, mean
;; that).  Every utterance is logged to ~/org/logs/voice_log_HOST.tsv.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'voice-match)

;; Android's: bound around su, it must be the dynamic variable everywhere.
(defvar android-use-exec-loader)
(defvar recentf-list)
(defvar org-clock-start-time)

(defvar org-directory)
(defvar org-logs-directory)
(defvar org-clock-history)
(defvar org-clock-marker)
(defvar org-clock-current-task)
(defvar org-meetings-file)
(defvar emacs-home-dir)
(defvar crm-separator)
(defvar crm-completion-table)
(defvar vertico--candidates)
(defvar claude-remote--machine-name)
(declare-function org-clocking-p "org-clock")
(declare-function org-clock-in "org-clock")
(declare-function org-clock-cancel "org-clock")
(declare-function org-save-all-org-buffers "org")
(declare-function org-agenda-files "org")
(declare-function rts-flow--clock-in-at-point "productivity_flow")
(declare-function usage-log "usage-log")

(defconst voice--android (eq system-type 'android))

(defvar voice-file nil
  "Your rules: ~/org/voice.org unless set.")

(defvar voice-log-file nil
  "Where every utterance is logged: ~/org/logs/voice_log_HOST.tsv unless set.")

(defvar voice-learn voice--android
  "Non-nil: a pick from the list teaches voice.org a name.  Only the phone
writes it, so Syncthing has one writer.")

(defvar voice-dry-run nil
  "Non-nil: say and log what would happen, do nothing.")

(defvar voice-stale-seconds 30
  "Words heard longer ago than this are dropped, so nothing fires late.")

(defvar voice-excluded-files '("agents.org")
  "Agenda files whose tasks are never voice clock-in targets.
agents.org is the Mac's alone (agent-time.el).")

(defvar voice-deny-regexp
  "kill\\|delete\\|remove\\|quit\\|revert\\|reset\\|discard\\|eval\\|shell\\|compile\\|restart"
  "Toolbar and homepage commands with names matching this are never run by voice.")

(defvar voice-audio-directory (and voice--android "/sdcard/Documents/voice-audio/")
  "Where each utterance's recording is kept, named as its log line's time:
the voice app's own copy (16 kHz mono PCM, kept 24 hours there), taken as
root.  On the phone only, not synced: pull it over USB to debug.  Nil: none.")

(defconst voice--app-history "/data/user/0/org.futo.voiceinput.moonshine/no_backup/audio-history"
  "The voice app's recordings, one .pcm and .txt per utterance.")

(defvar voice-listen-function nil
  "Ask the voice app to listen, given the source; nil where there is none.")

;;;; Actions

(defvar voice-actions nil
  "Actions, newest first.  Each is a plist; see `voice-action'.")

(defun voice--pattern (phrase)
  "PHRASE as (WORDS . SLOT-P): its words, and whether it ends in \"…\"."
  (let ((slot (string-match-p "\\(…\\|\\.\\.\\.\\)[[:space:]]*\\'" phrase)))
    (cons (voice-match-tokens (replace-regexp-in-string "…\\|\\.\\.\\." "" phrase) t)
          (and slot t))))

(cl-defun voice-action (say run &key when slot asks confirm quiet name where)
  "Add an action: SAY a phrase or phrases, RUN a command.
A phrase ending in \"…\" takes the rest of what was said, the slot:
SLOT \\='text passes it to RUN as its argument, \\='task finds the task it
names and passes that (a plist), and nil uses it to answer RUN's questions.
WHEN: a major mode, a context flag (see `voice-context'), a list of them,
or a function; the action is only offered then.  ASKS: questions of RUN
answered from the slot before it runs; see `voice--claim'.  CONFIRM asks
first.  QUIET: it asks nothing itself, so the island need not bring Emacs
forward.  NAME is how logs and messages call it; WHERE, how help says when
it is offered, for a WHEN that is a function."
  (let* ((phrases (if (listp say) say (list say)))
         (name (or name (car phrases)))
         (action (list :name name :phrases phrases
                       :patterns (mapcar #'voice--pattern phrases)
                       :run run :when when :slot slot :asks asks
                       :confirm confirm :quiet quiet :where where)))
    (setq voice-actions (cons action (seq-remove (lambda (a) (equal (plist-get a :name) name))
                                                 voice-actions)))
    name))

;;;; Context

(defun voice-context (&optional source)
  "Flags for now: clocking, minibuffer, android, remote, image, plus the
major mode and its parents.  From the island, only what holds whatever
app is in front: you are not looking at an Emacs buffer."
  (let ((buffer-flags (not (equal source "island"))))
    (delq nil
          (append
           (list (and (fboundp 'org-clocking-p) (org-clocking-p) 'clocking)
                 (and (active-minibuffer-window) 'minibuffer)
                 (and voice--android 'android)
                 (and (bound-and-true-p claude-remote--machine-name) 'remote))
           (when buffer-flags
             (with-current-buffer (window-buffer (selected-window))
               (let (modes (m major-mode))
                 (while m (push m modes) (setq m (get m 'derived-mode-parent)))
                 modes)))))))

(defun voice--when-p (when context)
  "Non-nil when WHEN holds in CONTEXT."
  ;; A mode or a flag is looked up, never called (`image-mode' is a
  ;; command); any other function is asked.
  (cond ((null when) t)
        ((and (symbolp when)
              (or (not (fboundp when)) (string-suffix-p "-mode" (symbol-name when))))
         (memq when context))
        ((functionp when) (ignore-errors (funcall when)))
        ((listp when) (cl-every (lambda (w) (voice--when-p w context)) when))))

(defun voice--specificity (when)
  "How particular WHEN is: a buffer's mode beats a global flag beats none."
  (cond ((null when) 0)
        ((and (symbolp when) (string-suffix-p "-mode" (symbol-name when))) 2)
        ((symbolp when) 1)
        ((functionp when) 1)
        ((listp when) (apply #'max 0 (mapcar #'voice--specificity when)))
        (t 1)))

;;;; Ready-made actions: the toolbar and the homepage

(defun voice--denied-p (command)
  (string-match-p voice-deny-regexp (symbol-name command)))

(defun voice--toolbar-actions ()
  "The toolbar's command buttons as actions, by label, shown when the
button is."
  (when (boundp 'tool-bar-map)
    (let (out)
      (map-keymap
       (lambda (_key def)
         (when (and (eq (car-safe def) 'menu-item)
                    (stringp (nth 1 def))
                    (symbolp (nth 2 def)) (commandp (nth 2 def))
                    (not (get (nth 2 def) 'voice-skip))
                    (not (voice--denied-p (nth 2 def))))
           (let* ((props (nthcdr 3 def))
                  (visible (plist-get props :visible)))
             (push (list :name (nth 1 def) :phrases (list (nth 1 def))
                         :patterns (list (voice--pattern (nth 1 def)))
                         :run (nth 2 def) :source 'toolbar
                         :when (and visible (lambda () (eval visible t))))
                   out))))
       (default-value 'tool-bar-map))
      out)))

(defun voice--homepage-actions ()
  "The homepage's tiles as actions, by title."
  (when (fboundp 'android-homepage--sections)
    (let (out)
      (dolist (section (ignore-errors (android-homepage--sections)))
        (dolist (item (cadr section))
          (let ((cmd (plist-get item :action)) (title (plist-get item :title)))
            (when (and (symbolp cmd) (commandp cmd) (stringp title)
                       (not (voice--denied-p cmd)))
              (push (list :name title :phrases (list title)
                          :patterns (list (voice--pattern title))
                          :run cmd :source 'homepage)
                    out)))))
      out)))

(defun voice--all-actions (context)
  "Every action that holds in CONTEXT: yours first, then the toolbar's and
the homepage's that run a command none of yours does."
  (let* ((mine (seq-filter (lambda (a) (voice--when-p (plist-get a :when) context))
                           voice-actions))
         (cmds (mapcar (lambda (a) (plist-get a :run)) mine)))
    (append mine
            (seq-filter (lambda (a) (and (not (memq (plist-get a :run) cmds))
                                         (voice--when-p (plist-get a :when) context)
                                         (push (plist-get a :run) cmds)))
                        (append (voice--toolbar-actions) (voice--homepage-actions))))))

;;;; Words

(defun voice--words (text)
  "TEXT as (RAW . TOKEN) pairs: the word as said, and as matched."
  (delq nil
        (mapcar (lambda (raw)
                  (let ((clean (replace-regexp-in-string "\\`[^[:alnum:]]+\\|[^[:alnum:]]+\\'" "" raw)))
                    (unless (string-empty-p clean)
                      (cons clean (voice-match-stem (car (voice-match-words clean)))))))
                (split-string (or text "") "[[:space:]]+" t))))

(defconst voice--fillers '("to" "two" "too" "on" "the" "my" "for" "into" "in" "a" "an")
  "Words dropped from the front of a slot: \"clock in TO the guitar\".")

(defconst voice--chatter-lead
  '(("okay") ("ok") ("hey") ("please") ("so") ("now") ("um") ("uh") ("umm") ("well")
    ("alright") ("emacs") ("just") ("then") ("and")
    ("can" "you") ("could" "you") ("would" "you") ("will" "you")
    ("i" "want" "to") ("i" "wanna") ("id" "like" "to") ("i" "would" "like" "to")
    ("lets") ("let" "me") ("let" "us") ("go" "ahead" "and")
    ("im" "going" "to") ("i" "am" "going" "to") ("im" "gonna") ("i" "am" "gonna")
    ("i" "will") ("ill") ("im") ("i" "am"))
  "Ways of starting a request that ask nothing: \"okay, can you save everything\".")

(defconst voice--chatter-tail '(("please") ("thanks") ("thank" "you") ("now") ("for" "me"))
  "Ways of ending one: \"pause, please\".")

(defun voice--strip-chatter (words)
  "WORDS (pairs) without the chatter around the request."
  (let ((plain (lambda (w) (downcase (replace-regexp-in-string "[^[:alnum:]]" "" (car w)))))
        (changed t))
    (while changed
      (setq changed nil)
      (dolist (seq voice--chatter-lead)
        (when (and (> (length words) (length seq))
                   (equal (mapcar plain (seq-take words (length seq))) seq))
          (setq words (nthcdr (length seq) words) changed t)))
      (dolist (seq voice--chatter-tail)
        (when (and (> (length words) (length seq))
                   (equal (mapcar plain (last words (length seq))) seq))
          (setq words (butlast words (length seq)) changed t))))
    words))

(defun voice--match-literal (pattern words)
  "How many of WORDS (pairs) PATTERN's literal words take from the front,
and how well its literal words matched (1 each when exact); nil if it
does not match.  A literal
stop word may be left out: \"clock in guitar\" matches \"clock in to …\"."
  (let ((lit (car pattern)) (i 0) (matched 0) (n (length words)) ok)
    (setq ok t)
    (while (and ok lit)
      (let ((l (car lit)))
        (cond ((and (< i n) (>= (voice--literal-sim l (cdr (nth i words))) 0.8))
               ;; By how well: \"time\" said is the time, not the timer.
               (cl-incf matched (voice--literal-sim l (cdr (nth i words))))
               (cl-incf i) (pop lit))
              ((member l voice-match-stop-words) (pop lit))
              (t (setq ok nil)))))
    (and ok (> matched 0) (cons i matched))))

(defun voice--slot-words (words)
  "WORDS without leading fillers."
  (while (and words (member (downcase (car (car words))) voice--fillers))
    (pop words))
  words)

(defun voice--join (words)
  (mapconcat #'car words " "))

;;;; Filling a command's questions from what was said

(defvar voice--fill nil
  "While an action runs: (:pool TOKENS :answers ((PROMPT-RE . VALUE)...)
:owned PROMPT-RES).  Its questions are answered from these.")

(defvar voice--choice nil
  "(PROMPT . CHARS) while `read-char-choice' waits, for voice answers.")

(defconst voice--letters
  '(("a" . "A") ("ay" . "A") ("hey" . "A") ("b" . "B") ("be" . "B") ("bee" . "B")
    ("c" . "C") ("see" . "C") ("sea" . "C") ("d" . "D") ("dee" . "D")
    ("e" . "E") ("f" . "F") ("eff" . "F"))
  "Letters as a recogniser may write them.")

(defun voice--duration (tokens)
  "TOKENS (plain words) as an H:MM duration, or nil: \"1 hour 30 minutes\",
\"half an hour\", \"45 min\", \"90\" (minutes)."
  (let ((mins 0) (num nil) found)
    (while tokens
      (let ((w (pop tokens)))
        (cond ((string-match-p "\\`[0-9]+\\'" w) (setq num (string-to-number w)))
              ((string-match-p "\\`[0-9]+:[0-9][0-9]\\'" w)
               (let ((p (split-string w ":")))
                 (setq mins (+ mins (* 60 (string-to-number (car p))) (string-to-number (cadr p)))
                       found t)))
              ((equal w "half") (setq num 0.5))
              ((member w '("an" "a")) (unless num (setq num 1)))
              ((string-prefix-p "hour" w) (setq mins (+ mins (round (* 60 (or num 1)))) num nil found t))
              ((or (string-prefix-p "min" w) (equal w "m"))
               (setq mins (+ mins (round (or num 0))) num nil found t)))))
    (when (and num (not found)) (setq mins (round num) found t))
    (and found (> mins 0) (format "%d:%02d" (/ mins 60) (% mins 60)))))

(defun voice--choices (source)
  "SOURCE's choices: a list, or a function or variable giving one."
  (cond ((functionp source) (funcall source))
        ((and (symbolp source) (boundp source)) (symbol-value source))
        (t source)))

(defun voice--claim (asks words)
  "Answer ASKS from WORDS (pairs) before the command runs.
Each ask is a plist: :prompt (regexp), :key (a word said before the
answer: \"priority b\"), :type (choice, letter, duration or rest),
:choices.  A rest ask, last, takes whatever is still unclaimed: \"diary
went running\" answers the diary's question with \"went running\".  A
choice with no :key is found by name after to/in/into/under/for: \"add
task scales to guitar\", while \"practice guitar\" stays a title.
Return (WORDS-LEFT . ANSWERS)."
  (let (answers)
    (dolist (ask asks)
      (let* ((key (plist-get ask :key)) (type (or (plist-get ask :type) 'choice))
             (tokens (mapcar #'cdr words))
             (kpos (and key (cl-position (voice-match-stem key) tokens :test #'equal)))
             value span)
        (cond
         (kpos
          (let ((after (mapcar #'car (nthcdr (1+ kpos) words))))
            (pcase type
              ('letter (when-let* ((w (car after))
                                   (l (cdr (assoc (downcase w) voice--letters))))
                         (setq value l span (cons kpos (+ kpos 2)))))
              ('duration
               (let ((n (min 4 (length after))) v)
                 (while (and (> n 0) (not v))
                   (setq v (voice--duration (voice-match-words (string-join (seq-take after n) " "))))
                   (unless v (cl-decf n)))
                 (when v (setq value v span (cons kpos (+ kpos 1 n))))))
              (_ (let ((choices (voice--choices (plist-get ask :choices))) v (n 1))
                   (while (and (<= n (min 3 (length after))) (not v))
                     (setq v (voice-match-mentioned
                              choices (voice-match-tokens (string-join (seq-take after n) " ") t)))
                     (unless v (cl-incf n)))
                   (when v (setq value v span (cons kpos (+ kpos 1 n)))))))))
         ((eq type 'rest)
          (when words (setq value (voice--join words) span (cons 0 (length words)))))
         ((eq type 'choice)
          ;; By name: the last one to three words, or after a preposition.
          (let ((choices (voice--choices (plist-get ask :choices))) (n (length words)))
            (cl-loop for len from 3 downto 1
                     until value
                     do (cl-loop for start from (- n len) downto 1
                                 until value
                                 do (let* ((run (seq-subseq words start (+ start len)))
                                           (prev (car (nth (1- start) words)))
                                           (prep (member (downcase prev) '("to" "in" "into" "under" "for")))
                                           (v (and prep
                                                   (voice-match-mentioned
                                                    choices (mapcar #'cdr run)))))
                                      (when (and v (equal (voice-match-tokens v t) (mapcar #'cdr run)))
                                        (setq value v
                                              span (cons (if prep (1- start) start) (+ start len))))))))))
        (when (and value span (or (eq type 'rest) (> (car span) 0)))
          (push (cons (plist-get ask :prompt) value) answers)
          (setq words (append (seq-take words (car span)) (nthcdr (cdr span) words))))))
    (cons words (nreverse answers))))

(defun voice--owned-p (prompt)
  "Non-nil when one of the running action's asks owns PROMPT."
  (seq-some (lambda (re) (string-match-p re prompt)) (plist-get voice--fill :owned)))

(defun voice--answer-for (prompt)
  "The answer claimed for PROMPT, taken so it is used once."
  (let ((hit (seq-find (lambda (a) (string-match-p (car a) prompt))
                       (plist-get voice--fill :answers))))
    (when hit
      (setq voice--fill (plist-put voice--fill :answers
                                   (delq hit (plist-get voice--fill :answers))))
      (cdr hit))))

(defun voice--collection-strings (collection predicate)
  (let ((all (ignore-errors (all-completions "" collection predicate))))
    (if (> (length all) 3000) (seq-take all 3000) all)))

(defun voice--from-pool (strings)
  "The one of STRINGS the words of the running action mention."
  (let ((pool (plist-get voice--fill :pool)))
    (and pool strings (voice-match-mentioned strings pool))))

(defun voice--settle (answer strings strict)
  "ANSWER as one of STRINGS: itself, or the entry it clearly names, else
nil.  Unless STRICT (the prompt takes only its entries), only a word for
word match counts: the words might be new text."
  (if (or (null strings) (member answer strings))
      answer
    (let ((ranked (voice-match-strings strings answer 5)))
      (and (eq (voice-match-decide ranked) 'act)
           (or strict (>= (nth 1 (car ranked)) 0.99))
           (plist-get (nth 2 (car ranked)) :title)))))

(defun voice--typed (text)
  "TEXT as words to type into a list's filter: what matters, no fillers."
  (string-join (voice-match-tokens text) " "))

(defun voice--with-initial (args text)
  "`completing-read' ARGS after the collection and predicate, with TEXT as
the initial input."
  (let ((a (copy-sequence args)))
    (while (< (length a) 2) (setq a (append a (list nil))))
    (setf (nth 1 a) text)
    a))

(defun voice--completing-read-a (orig prompt collection &optional predicate &rest args)
  "Answer PROMPT from what was said, when the running action can; else ask.
A spoken answer the list does not hold picks the entry it clearly names,
or opens the list with its words typed, to finish with a tap."
  (let* ((claimed (and voice--fill (voice--answer-for prompt)))
         (ans (or claimed
                  (and voice--fill (not (voice--owned-p prompt))
                       (voice--from-pool (voice--collection-strings collection predicate)))))
         (settled (if (and claimed (stringp claimed))
                      (voice--settle claimed (voice--collection-strings collection predicate)
                                     (and (car args) (not (eq (car args) 'confirm-after-completion))))
                    ans)))
    (cond (settled settled)
          (claimed (let ((voice--fill nil))
                     (apply orig prompt collection predicate
                            (voice--with-initial args (voice--typed claimed)))))
          (t (let ((voice--fill nil)) (apply orig prompt collection predicate args))))))

(defun voice--read-string-a (orig prompt &rest args)
  (or (and voice--fill (voice--answer-for prompt))
      (let ((voice--fill nil)) (apply orig prompt args))))

(defun voice--crm-a (orig prompt table &optional predicate &rest args)
  (let ((ans (and voice--fill
                  (let ((a (voice--answer-for prompt)))
                    (cond ((consp a) a)
                          (a (list a))
                          ((not (voice--owned-p prompt))
                           (voice--mentions (voice--collection-strings table predicate)
                                            (plist-get voice--fill :pool))))))))
    (or ans (let ((voice--fill nil)) (apply orig prompt table predicate args)))))

(defun voice--mentions (strings tokens)
  "All of STRINGS whose every word is among TOKENS, longest first, none
inside another."
  (let (hits)
    (dolist (s strings)
      (let ((w (voice-match-tokens s t)))
        (when (and w (cl-every (lambda (x) (member x tokens)) w))
          (push s hits))))
    (setq hits (sort hits (lambda (a b) (> (length a) (length b)))))
    (let (out)
      (dolist (h hits (nreverse out))
        (unless (seq-some (lambda (o) (string-match-p (regexp-quote (downcase h)) (downcase o))) out)
          (push h out))))))

(defun voice--choice-labels (prompt chars)
  "(CHAR . LABEL) for each of CHARS named in PROMPT: \"[c]amera\" or
\"d date  b break down\"."
  (let (out (case-fold-search nil))
    (dolist (c chars)
      (let ((ch (regexp-quote (char-to-string c))))
        (cond
         ((string-match (concat "\\[" ch "\\]\\([[:alpha:]]+\\)") prompt)
          (push (cons c (concat (char-to-string c) (match-string 1 prompt))) out))
         ((string-match (concat "\\(?:^\\|[[:space:]]\\)" ch " \\([[:alpha:]][[:alpha:] ]*?\\)\\(?:  \\|:\\|$\\)")
                        prompt)
          (push (cons c (match-string 1 prompt)) out)))))
    (nreverse out)))

(defun voice--char-for (labels tokens)
  "The char whose label TOKENS mention."
  (let ((hit (voice-match-mentioned (mapcar #'cdr labels) tokens)))
    (and hit (car (rassoc hit labels)))))

(defun voice--read-char-choice-a (orig prompt chars &rest args)
  (let ((c (and voice--fill
                (voice--char-for (voice--choice-labels prompt chars)
                                 (plist-get voice--fill :pool)))))
    (or c (let ((voice--fill nil) (voice--choice (cons prompt chars)))
            (apply orig prompt chars args)))))

(advice-add 'completing-read :around #'voice--completing-read-a)
(advice-add 'read-string :around #'voice--read-string-a)
(advice-add 'completing-read-multiple :around #'voice--crm-a)
(advice-add 'read-char-choice :around #'voice--read-char-choice-a)

;;;; Answering the question on screen

(defconst voice--ordinals
  '(("first" . 1) ("1st" . 1) ("one" . 1) ("1" . 1) ("second" . 2) ("2nd" . 2) ("2" . 2)
    ("two" . 2) ("third" . 3) ("3rd" . 3) ("3" . 3) ("three" . 3) ("fourth" . 4) ("4" . 4)
    ("fifth" . 5) ("5" . 5) ("top" . 1) ("this" . 1) ("yes" . 1) ("ok" . 1) ("okay" . 1))
  "\"the second one\": which of the shown choices.")

(defun voice--ordinal (words)
  "N when WORDS say \"the Nth one\" and little else."
  (let ((w (seq-remove (lambda (x) (member x '("the" "one" "number" "option" "that" "please" "it")))
                       words)))
    (and w (null (cdr w)) (cdr (assoc (car w) voice--ordinals)))))

(defun voice--exit-minibuffer ()
  (when (active-minibuffer-window)
    (with-selected-window (active-minibuffer-window) (exit-minibuffer))))

(defun voice--set-and-exit (string)
  "Put STRING in the minibuffer and submit it, from a timer of its own:
the exit throws, and the voice step that called this still logs."
  (delete-minibuffer-contents)
  (insert string)
  (run-at-time 0 nil #'voice--exit-minibuffer))

(defvar voice-refused-prompt-regexp
  "exit emacs\\|kill emacs\\|quit emacs\\|restart emacs\\|delete\\|discard\\|revert\\|overwrite\\|kill buffer\\|answer by hand"
  "Questions voice never answers: a stray \"yes\" must not quit Emacs or lose work.")

(defconst voice--refused-histories
  '(read-expression-history shell-command-history extended-command-history)
  "Prompts voice never answers: Lisp to evaluate, a shell command, M-x.")

(defun voice--prompt-wants-duration-p (prompt)
  (string-match-p "effort\\|duration\\|how long\\|[0-9]:[0-9][0-9]" (downcase prompt)))

(defun voice--answer-prompt (text)
  "Answer the open question with TEXT: a key for a key question, a choice
by name or place, else TEXT as typed."
  (let ((words (voice-match-words text)) (tokens (voice-match-tokens text t)))
    (cond
     ((let ((p (or (car voice--choice)
                   (and (active-minibuffer-window)
                        (with-selected-window (active-minibuffer-window) (minibuffer-prompt))))))
        (and p (let ((case-fold-search t)) (string-match-p voice-refused-prompt-regexp p))))
      "Voice doesn't answer this question: answer it by hand")
     (voice--choice
      (let ((c (or (voice--char-for (voice--choice-labels (car voice--choice) (cdr voice--choice))
                                    tokens)
                   (and (null (cdr words)) (= 1 (length (car words)))
                        (memq (string-to-char (car words)) (cdr voice--choice))
                        (string-to-char (car words))))))
        (if c (progn (setq unread-command-events (list c)) (format "Answered: %c" c))
          (format "Not one of the keys: %s" text))))
     ((active-minibuffer-window)
      (with-selected-window (active-minibuffer-window)
        (let* ((prompt (or (minibuffer-prompt) ""))
               (refused (memq minibuffer-history-variable voice--refused-histories))
               (table minibuffer-completion-table)
               (crm (and (boundp 'crm-completion-table) crm-completion-table
                         (eq table 'crm--collection-fn))))
          (cond
           (refused "Voice doesn't answer this prompt")
           ((or (string-suffix-p "(y or n) " prompt) (string-match-p "(y or n)" prompt))
            (cond ((cl-intersection words '("yes" "yeah" "yep" "sure" "ok" "okay" "do" "y"))
                   (setq unread-command-events (list ?y)) "Yes")
                  ((cl-intersection words '("no" "nope" "don" "n" "cancel"))
                   (setq unread-command-events (list ?n)) "No")
                  (t (format "Say yes or no: %s" text))))
           ((and (member (string-join words " ") '("cancel" "never mind" "nevermind" "stop" "quit" "escape"))
                 (not (and table (member (string-join words " ")
                                         (mapcar #'downcase (voice--collection-strings
                                                             table minibuffer-completion-predicate))))))
            (run-at-time 0 nil #'abort-minibuffers)
            "Cancelled")
           (crm
            (let* ((cands (voice--collection-strings crm-completion-table minibuffer-completion-predicate))
                   (hits (voice--mentions cands tokens)))
              (if hits (progn (voice--set-and-exit (string-join hits crm-separator))
                              (format "Answered: %s" (string-join hits ", ")))
                (delete-minibuffer-contents) (insert text) "Typed it in")))
           (table
            (let* ((cands (voice--collection-strings table minibuffer-completion-predicate))
                   (n (voice--ordinal words))
                   (shown (and (bound-and-true-p vertico--candidates) vertico--candidates))
                   (letters (and cands (cl-every (lambda (c) (= 1 (length c))) cands)))
                   (hit (cond ((and n shown (<= n (length shown))) (nth (1- n) shown))
                              ((and n cands (<= n (length cands))) (nth (1- n) cands))
                              ((and letters (null (cdr words)))
                               (let ((l (cdr (assoc (car words) voice--letters))))
                                 (seq-find (lambda (c) (equal (upcase c) l)) cands)))
                              (t (or (voice-match-mentioned cands tokens)
                                     (let ((r (voice-match-strings cands text 2)))
                                       (and (eq (voice-match-decide r) 'act)
                                            (plist-get (nth 2 (car r)) :title))))))))
              (if hit (progn (voice--set-and-exit hit) (format "Answered: %s" hit))
                (delete-minibuffer-contents) (insert text) "Typed it in: pick, or say which")))
           (t
            (let ((s (or (and (voice--prompt-wants-duration-p prompt) (voice--duration words))
                         text)))
              (voice--set-and-exit s)
              (format "Answered: %s" s)))))))
     (t nil))))

;;;; Your rules: ~/org/voice.org

(defvar voice--rules-cache nil "(MTIME NAMES PHRASES).")

(defun voice--file ()
  (or voice-file (expand-file-name "voice.org" (or (bound-and-true-p org-directory) "~/org/"))))

(defun voice--rules ()
  "(NAMES . PHRASES) from voice.org, each an alist (SAID . MEANT)."
  (let* ((f (voice--file))
         (mtime (and (file-exists-p f) (file-attribute-modification-time (file-attributes f)))))
    (if (and mtime voice--rules-cache (equal (car voice--rules-cache) mtime))
        (cdr voice--rules-cache)
      (let ((names nil) (phrases nil) (sounds nil) (section nil))
        (when mtime
          (with-temp-buffer
            (insert-file-contents f)
            (goto-char (point-min))
            (while (not (eobp))
              (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
                (cond ((string-match "\\`\\* +\\(.*?\\) *\\'" line)
                       (setq section (downcase (match-string 1 line))))
                      ((string-match "\\`[ \t]*- +\\(.*?\\) +:: +\\(.*?\\) *\\'" line)
                       (let ((pair (cons (match-string 1 line) (match-string 2 line))))
                         (pcase section
                           ("names" (push pair names))
                           ("phrases" (push pair phrases))
                           ("sounds" (push pair sounds)))))))
              (forward-line 1))))
        (setq voice--user-sounds
              (mapcar (lambda (p) (cons (voice-match-stem (downcase (car p)))
                                        (voice-match-stem (downcase (cdr p)))))
                      sounds))
        (let ((rules (cons (nreverse names) (nreverse phrases))))
          (setq voice--rules-cache (cons mtime rules))
          rules)))))

(defvar voice--user-sounds nil "voice.org's * Sounds, as (HEARD . MEANT) stems.")

(defconst voice-sounds-like
  '(("talk" . "clock") ("clerk" . "clock") ("lock" . "clock") ("clark" . "clock")
    ("glock" . "clock") ("clog" . "clock") ("ad" . "add") ("hell" . "help")
    ("grab" . "graph") ("grass" . "graph") ("graf" . "graph")
    ("hutter" . "herdr") ("herder" . "herdr") ("header" . "herdr") ("harder" . "herdr")
    ("hurdle" . "herdr") ("hirder" . "herdr") ("guy" . "kai") ("chai" . "kai") ("kye" . "kai")
    ("pie" . "kai") ("kay" . "kai") ("no" . "node") ("nod" . "node") ("reed" . "read")
    ("paw" . "pause") ("pose" . "pause") ("paus" . "pause"))
  "Words the voice app was heard to write for a command's words, HEARD .
MEANT, as stems: \"talk into messaging\" is \"clock into messaging\".  Only
command phrases use them, never task names.  Yours go under * Sounds in
`voice-file', as - heard :: meant.")

(defun voice--literal-sim (literal token)
  "How well TOKEN, heard, stands for a command's LITERAL word."
  (max (voice-match-sim literal token)
       (if (equal (cdr (or (assoc token voice--user-sounds) (assoc token voice-sounds-like))) literal)
           0.85 0.0)))

(defun voice--rewrite (text)
  "TEXT, or what voice.org's Phrases say it means."
  (let ((hit (assoc (voice-match-normalize text)
                    (mapcar (lambda (p) (cons (voice-match-normalize (car p)) (cdr p)))
                            (cdr (voice--rules))))))
    (if hit (cdr hit) text)))

(defun voice--learn-name (said title)
  "Add \"- SAID :: TITLE\" under Names in voice.org, unless SAID is there."
  (when (and voice-learn said title (not (string-empty-p said))
             (not (assoc (voice-match-normalize said)
                         (mapcar (lambda (n) (cons (voice-match-normalize (car n)) n))
                                 (car (voice--rules))))))
    (let* ((f (voice--file))
           (line (format "- %s :: %s\n" said title))
           (buf (find-buffer-visiting f)))
      (with-current-buffer (or buf (find-file-noselect f t))
        (save-excursion
          (goto-char (point-min))
          (when (= (point-min) (point-max))
            (insert "#+TITLE: Voice\n\nOther names for tasks; a pick from the voice list adds one.\n"
                    "* Names\n* Phrases\nSay the left, mean the right.\n"))
          (goto-char (point-min))
          (unless (re-search-forward "^\\* Names[ \t]*$" nil t)
            (goto-char (point-max)) (unless (bolp) (insert "\n")) (insert "* Names\n"))
          (forward-line 1)
          (while (and (not (eobp)) (not (looking-at "^\\*"))) (forward-line 1))
          (unless (bolp) (insert "\n"))
          (insert line))
        (let ((save-silently t)) (save-buffer))
        (unless buf (kill-buffer)))
      (setq voice--rules-cache nil)
      (format "learned \"%s\"" said))))

;;;; Tasks

(defvar voice--file-cache (make-hash-table :test 'equal)
  "File -> (STAMP . CANDIDATES).")

(defvar voice--index nil "(STAMPS . INDEX), rebuilt when a file changes.")

(defun voice--keywords ()
  "(OPEN . DONE) keywords from `org-todo-keywords'."
  (let (open done)
    (dolist (seq (bound-and-true-p org-todo-keywords))
      (let* ((words (mapcar (lambda (w) (replace-regexp-in-string "(.*" "" w)) (cdr seq)))
             (bar (cl-position "|" words :test #'equal)))
        (if bar
            (progn (setq open (append open (seq-take words bar)))
                   (setq done (append done (nthcdr (1+ bar) words))))
          (setq open (append open (butlast words)) done (append done (last words))))))
    (cons (delete-dups (or open (list "TODO"))) (delete-dups (or done (list "DONE"))))))

(defun voice--file-keywords (kw)
  "The current buffer's keywords: its #+TODO lines if it has any, as Org
reads them, else KW."
  (let ((open nil) (done nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\(?:SEQ_\\|TYP_\\)?TODO:[ \t]*\\(.*\\)$" nil t)
        (let* ((words (mapcar (lambda (w) (replace-regexp-in-string "(.*" "" w))
                              (split-string (match-string 1))))
               (bar (cl-position "|" words :test #'equal)))
          (if bar
              (setq open (append open (seq-take words bar)) done (append done (nthcdr (1+ bar) words)))
            (setq open (append open (butlast words)) done (append done (last words)))))))
    (if (or open done) (cons open done) kw)))

(defun voice--date-days (stamp)
  "Days from today to STAMP, a YYYY-MM-DD string."
  (/ (float-time (time-subtract (date-to-time (concat stamp " 00:00"))
                                (date-to-time (format-time-string "%F 00:00"))))
     86400))

(defun voice--scan-buffer (file)
  "Candidates in the current buffer, from FILE: its open headings, and in
meetings.org its people."
  (let* ((kw (voice--file-keywords (voice--keywords)))
         (open (car kw)) (all (append (car kw) (cdr kw)))
         (meetings (and (bound-and-true-p org-meetings-file)
                        (equal (file-truename file) (file-truename org-meetings-file))))
         (stack nil) out)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward "^\\(\\*+\\)[ \t]+\\(.*?\\)[ \t]*$" nil t)
          (let* ((level (length (match-string 1)))
                 (rest (match-string-no-properties 2))
                 (pos (match-beginning 0))
                 keyword priority tags title)
            (when (string-match "\\`\\([A-Z]+\\)\\(?:[ \t]+\\|\\'\\)" rest)
              (when (member (match-string 1 rest) all)
                (setq keyword (match-string 1 rest) rest (substring rest (match-end 0)))))
            (when (string-match "\\`\\[#\\([A-Z0-9]\\)\\][ \t]*" rest)
              (setq priority (match-string 1 rest) rest (substring rest (match-end 0))))
            (when (string-match "[ \t]+\\(:[[:alnum:]_@#%:]+:\\)\\'" rest)
              (setq tags (match-string 1 rest) rest (substring rest 0 (match-beginning 0))))
            ;; A link counts by what it shows, not its id.
            (setq title (string-trim
                         (replace-regexp-in-string
                          "\\[\\[\\([^]]*\\)\\]\\]" "\\1"
                          (replace-regexp-in-string "\\[\\[[^]]*\\]\\[\\([^]]*\\)\\]\\]" "\\1" rest))))
            (while (and stack (>= (caar stack) level)) (pop stack))
            (let ((parent (cdar stack)))
              (push (cons level title) stack)
              (when (and (not (string-empty-p title))
                         (or (member keyword open)
                             (and meetings (= level 1) (null keyword) tags
                                  (string-match-p ":meeting:" tags))))
                (let ((end (save-excursion (or (and (re-search-forward "^\\*+[ \t]" nil t)
                                                    (match-beginning 0))
                                               (point-max))))
                      (prior 0.0) sched last)
                  (save-excursion
                    (forward-line 1)
                    (let ((lim (min end (save-excursion (forward-line 20) (point)))))
                      (when (re-search-forward "\\(?:SCHEDULED\\|DEADLINE\\): *<\\([0-9-]\\{10\\}\\)" lim t)
                        (setq sched (match-string 1)))
                      (goto-char (line-beginning-position 1))
                      (when (re-search-forward ":LAST_ACCESSED: *\\[\\([0-9-]\\{10\\}\\)" lim t)
                        (setq last (match-string 1)))))
                  (when (and sched (<= (voice--date-days sched) 7)) (cl-incf prior 0.06))
                  (when (member keyword '("NEXT" "ACTIVE" "READING" "WATCHING" "STARTED"))
                    (cl-incf prior 0.04))
                  (when (and last (>= (voice--date-days last) -7)) (cl-incf prior 0.03))
                  (when (member priority '("A" "B")) (cl-incf prior 0.02))
                  (push (list :title title :file file :pos pos :keyword keyword
                              :meeting (and meetings (null keyword))
                              :extra (concat (or parent "") " "
                                             (replace-regexp-in-string ":" " " (or tags "")))
                              :parent parent :prior prior)
                        out))))))))
    (nreverse out)))

(defun voice--stamp (file)
  (let ((buf (find-buffer-visiting file)))
    (if buf (list 'buf (buffer-chars-modified-tick buf))
      (let ((a (file-attributes file)))
        (list 'file (file-attribute-modification-time a) (file-attribute-size a))))))

(defun voice--task-files ()
  (seq-remove (lambda (f) (member (file-name-nondirectory f) voice-excluded-files))
              (append (and (fboundp 'org-agenda-files) (org-agenda-files t))
                      (and (bound-and-true-p org-meetings-file)
                           (file-exists-p org-meetings-file)
                           (list org-meetings-file)))))

(defun voice--file-candidates (file)
  (let ((stamp (voice--stamp file)) (hit (gethash file voice--file-cache)))
    (if (and hit (equal (car hit) stamp)) (cdr hit)
      (let ((c (let ((buf (find-buffer-visiting file)))
                 (if buf (with-current-buffer buf (voice--scan-buffer file))
                   (with-temp-buffer
                     (insert-file-contents file)
                     (voice--scan-buffer file))))))
        (puthash file (cons stamp c) voice--file-cache)
        c))))

(defun voice--task-index ()
  "The index of every task and person, rebuilt when a file changed."
  (let* ((files (delete-dups (mapcar #'file-truename (voice--task-files))))
         (stamps (mapcar (lambda (f) (cons f (voice--stamp f))) files))
         (names (car (voice--rules))))
    (if (and voice--index (equal (car voice--index) (cons names stamps)))
        (cdr voice--index)
      (let* ((cands (mapcar #'copy-sequence
                            (apply #'append (mapcar #'voice--file-candidates files))))
             (by-title (make-hash-table :test 'equal)))
        (dolist (c cands) (push c (gethash (voice-match-normalize (plist-get c :title)) by-title)))
        (dolist (n names)
          (dolist (c (gethash (voice-match-normalize (cdr n)) by-title))
            (plist-put c :aliases (cons (car n) (plist-get c :aliases)))))
        (let ((index (voice-match-index cands)))
          (setq voice--index (cons (cons names stamps) index))
          index)))))

(defun voice--verb-prior (verb)
  "Priors for the words used: \"read\" leans to books, \"watch\" to videos,
and the last few clocked tasks lean in."
  (let ((recent (seq-take (delq nil (mapcar (lambda (m) (and (markerp m) (marker-buffer m)
                                                             (cons (buffer-file-name (marker-buffer m))
                                                                   (marker-position m))))
                                            (bound-and-true-p org-clock-history)))
                          5)))
    (lambda (e)
      (+ (if (seq-some (lambda (r) (and (equal (car r) (plist-get e :file))
                                        (<= (abs (- (cdr r) (plist-get e :pos))) 200)))
                       recent)
             0.08 0.0)
         (let ((k (or (plist-get e :keyword) "")))
           (cond ((and (equal verb "read") (string-match-p "READ" k)) 0.05)
                 ((and (equal verb "watch") (string-match-p "WATCH" k)) 0.05)
                 ((and (member verb (quote ("meet" "meeting"))) (plist-get e :meeting)) 0.05)
                 (t 0.0)))))))

(defun voice-rank-tasks (text &optional verb)
  "Tasks and people for TEXT, best first, as `voice-match-rank' gives them."
  (voice-match-rank (voice--task-index) text 5 (voice--verb-prior verb)))

(defun voice--goto (c)
  "Visit candidate C's heading; point at it."
  (let ((buf (or (find-buffer-visiting (plist-get c :file))
                 (find-file-noselect (plist-get c :file) t)))
        (re (concat "^\\*+[ \t]+\\(?:[A-Z]+[ \t]+\\)?\\(?:\\[#.\\][ \t]*\\)?"
                    (regexp-quote (plist-get c :title)))))
    (set-buffer buf)
    (widen)
    (goto-char (min (plist-get c :pos) (point-max)))
    (unless (and (bolp) (looking-at re))
      (goto-char (point-min))
      (unless (re-search-forward re nil t)
        (user-error "Voice: \"%s\" is not in %s any more" (plist-get c :title)
                    (file-name-nondirectory (plist-get c :file))))
      (goto-char (line-beginning-position)))))

(defvar voice--last nil "(:what STRING :undo FUNCTION) for `voice-undo'.")

(defun voice-clock-in (c)
  "Clock in to candidate C, a task or a person; `voice-undo' takes it back."
  (let ((prev (and (fboundp 'org-clocking-p) (org-clocking-p) (copy-marker org-clock-marker))))
    (save-excursion
      (save-window-excursion
        (voice--goto c)
        (if (or (plist-get c :meeting) (not (fboundp 'rts-flow--clock-in-at-point)))
            (progn (org-clock-in) (org-save-all-org-buffers))
          (rts-flow--clock-in-at-point))))
    (setq voice--last
          (list :what (format "clock-in to %s" (plist-get c :title))
                :undo (lambda ()
                        (org-clock-cancel)
                        (when (and prev (marker-buffer prev))
                          (with-current-buffer (marker-buffer prev)
                            (save-excursion (goto-char prev) (org-clock-in))))
                        (org-save-all-org-buffers))))
    (format "Clocked in: %s%s" (if (plist-get c :meeting) "meeting with " "") (plist-get c :title))))

(defun voice--sorted-table (strings)
  (lambda (s pred action)
    (if (eq action 'metadata) '(metadata (display-sort-function . identity)
                                         (cycle-sort-function . identity))
      (complete-with-action action strings s pred))))

(defun voice--pick-task (said ranked verb)
  "Offer RANKED tasks for SAID, the best first; then a new task, then any."
  (let* ((items (append
                 (mapcar (lambda (r)
                           (let ((e (nth 2 r)))
                             (cons (format "%s%s%s" (if (plist-get e :meeting) "Meeting: " "")
                                           (plist-get e :title)
                                           (if (plist-get e :parent)
                                               (propertize (format "  · %s" (plist-get e :parent))
                                                           'face 'shadow)
                                             ""))
                                   e)))
                         ranked)
                 (list (cons (format "New task: %s" said) 'new)
                       (cons "Something else…" 'other))))
         (choice (let ((voice--fill nil))
                   (completing-read (format "Voice heard \"%s\": " said)
                                    (voice--sorted-table (mapcar #'car items)) nil t nil nil
                                    (caar items))))
         (picked (cdr (assoc choice items))))
    (pcase picked
      ('new (voice--add-task said nil))
      ('other (call-interactively (if (fboundp 'rts-flow-manual) #'rts-flow-manual #'org-clock-in)))
      ('nil "Nothing picked")
      (_ (let ((msg (voice-clock-in picked)))
           (when (and (not (equal verb "meeting")) (not (string-empty-p said)))
             (let ((learned (voice--learn-name said (plist-get picked :title))))
               (when learned (setq msg (concat msg "; " learned)))))
           msg)))))

(defun voice--add-task (title answers)
  "Add a task TITLE through Add > Task, its questions answered from ANSWERS
where said, asked otherwise."
  (let ((voice--fill (list :pool nil :answers answers
                           :owned (mapcar (lambda (a) (plist-get a :prompt)) (voice--add-task-asks)))))
    (if (fboundp 'rts-flow--add-task-dispatch)
        (rts-flow--add-task-dispatch title)
      (user-error "Voice: Add > Task is not loaded"))
    (format "Added: %s" title)))

(defun voice--add-task-asks ()
  "What adding a task may ask that a sentence can answer."
  (list (list :prompt "\\`Add to: " :type 'choice
              :choices (lambda () (bound-and-true-p rts-flow-add-destinations)))
        (list :prompt "\\`Priority: " :key "priority" :type 'letter)
        (list :prompt "\\`Effort" :key "effort" :type 'duration)
        (list :prompt "\\`Category: " :key "category" :type 'choice
              :choices (lambda () (bound-and-true-p rts-instant-task-categories)))))

(defun voice-add-task (text)
  "Add the task TEXT names; \"to mundane\", \"priority b\", \"effort one
hour\", \"category hobby\" in it answer those questions."
  (let* ((claim (voice--claim (voice--add-task-asks) (voice--words text)))
         (title (voice--join (car claim))))
    (when (string-empty-p title) (setq title (read-string "Task title: ")))
    (voice--add-task title (cdr claim))))

(defun voice-undo ()
  "Take back the last voice action, when it can be."
  (interactive)
  (if-let* ((last voice--last))
      (progn (setq voice--last nil) (funcall (plist-get last :undo))
             (format "Undone: %s" (plist-get last :what)))
    "Nothing to undo"))

;;;; Planning and running

(defun voice--best-action (words actions)
  "The action WORDS (pairs) call for, as (ACTION SLOT-WORDS LITERAL),
by phrase: the longest literal match, a buffer's own first.  A phrase
whose … got nothing loses to one that names it whole: \"diary\" alone is
the Diary tile, \"diary went running\" a diary line."
  (let (best)
    (dolist (a actions)
      (dolist (p (plist-get a :patterns))
        (let ((m (voice--match-literal p words)))
          (when (and m (or (cdr p) (= (car m) (length words))))
            (let* ((slot (voice--slot-words (nthcdr (car m) words)))
                   (cand (list a slot (- (cdr m) (if (and (cdr p) (null slot)) 0.5 0))
                               (voice--specificity (plist-get a :when)))))
              (when (or (null best) (> (nth 2 cand) (nth 2 best))
                        (and (= (nth 2 cand) (nth 2 best)) (> (nth 3 cand) (nth 3 best))))
                (setq best cand)))))))
    best))

(defun voice--fuzzy-action (text actions)
  "The action whose slotless phrase TEXT is near, if one clearly is."
  (let* ((entries (apply #'append
                         (mapcar (lambda (a)
                                   (delq nil (mapcar (lambda (ph)
                                                       (unless (cdr (voice--pattern ph))
                                                         (list :title ph :action a)))
                                                     (plist-get a :phrases))))
                                 actions)))
         (ranked (and entries (voice-match-rank (voice-match-index entries) text 3))))
    (when (and ranked (>= (nth 1 (car ranked)) 0.85)
               (or (null (cadr ranked))
                   (eq (plist-get (nth 2 (car ranked)) :action) (plist-get (nth 2 (cadr ranked)) :action))
                   (>= (- (car (car ranked)) (car (cadr ranked))) 0.1)))
      (plist-get (nth 2 (car ranked)) :action))))

(defun voice-plan (text &optional source)
  "What TEXT, heard from SOURCE, would do: a plist.  Does nothing itself."
  (let* ((context (voice-context source))
         (words (voice--strip-chatter (voice--words text)))
         (request (if words (voice--join words) text)))
    (cond
     ((or voice--choice (memq 'minibuffer context))
      (list :kind 'answer :text text :front t))
     ((null words) (list :kind 'none :text text))
     (t
      (let* ((actions (voice--all-actions context))
             (hit (voice--best-action words actions))
             (action (or (car hit) (voice--fuzzy-action text actions)))
             (slot (and hit (voice--join (nth 1 hit)))))
        (cond
         ((and action (eq (plist-get action :slot) 'task))
          (let* ((verb (car (voice-match-words (car (plist-get action :phrases)))))
                 (verb (let ((first (car (voice-match-tokens request t))))
                         (if (member first '("read" "watch" "meet")) first verb)))
                 (ranked (and slot (not (string-empty-p slot)) (voice-rank-tasks slot verb)))
                 (decision (if ranked (voice-match-decide ranked) 'none)))
            (list :kind 'task :text text :action action :slot slot :verb verb
                  :ranked ranked :decision decision
                  :front (not (eq decision 'act)))))
         (action
          (list :kind 'action :text text :action action :slot slot
                :front (not (plist-get action :quiet))))
         (t
          (let ((ranked (voice-rank-tasks request)))
            (list :kind 'task :text text :slot request :ranked ranked
                  :decision (if ranked 'pick 'none) :front t
                  :action (seq-find (lambda (a) (eq (plist-get a :slot) 'task)) voice-actions))))))))))

(defun voice--run-action (plan)
  "Run PLAN's action, its questions filled from what was said."
  (let* ((action (plist-get plan :action))
         (run (plist-get action :run))
         (slot (or (plist-get plan :slot) ""))
         (kind (plist-get action :slot))
         (pool (let ((all (voice-match-tokens (plist-get plan :text) t)))
                 (if (eq kind 'text) (seq-difference all (voice-match-tokens slot t)) all)))
         (asks (plist-get action :asks))
         (claimed (and asks (voice--claim asks (voice--words slot)))))
    (when (and (plist-get action :confirm)
               (not (y-or-n-p (format "Voice: %s? " (plist-get action :name)))))
      (user-error "Voice: not done"))
    (let ((voice--fill (list :pool pool :answers (cdr claimed)
                             :owned (mapcar (lambda (a) (plist-get a :prompt)) asks))))
      (let ((result (cond ((eq kind 'text) (funcall run slot))
                          ((commandp run) (call-interactively run))
                          (t (funcall run)))))
        (if (stringp result) result (format "Done: %s" (plist-get action :name)))))))

(defun voice--execute (plan)
  "Do what PLAN says; return what to tell."
  (pcase (plist-get plan :kind)
    ('answer (or (voice--answer-prompt (plist-get plan :text)) "No question open"))
    ('task
     (let ((ranked (plist-get plan :ranked)) (slot (plist-get plan :slot)))
       (cond ((eq (plist-get plan :decision) 'act) (voice-clock-in (nth 2 (car ranked))))
             ((or (null slot) (string-empty-p slot))
              (call-interactively (if (fboundp 'rts-flow-manual) #'rts-flow-manual #'org-clock-in))
              nil)
             (t (voice--pick-task slot ranked (plist-get plan :verb))))))
    ('action (voice--run-action plan))
    (_ (format "Didn't get: %s" (plist-get plan :text)))))

(defun voice--log-file ()
  (or voice-log-file
      (expand-file-name (format "voice_log_%s.tsv" (system-name))
                        (or (bound-and-true-p org-logs-directory)
                            (expand-file-name "logs/" (or (bound-and-true-p org-directory) "~/org/"))))))

(defun voice--log (plan ms result)
  "One line per utterance: what was heard, what it did, how sure, how long."
  (with-demoted-errors "voice log: %S"
    (let* ((ranked (plist-get plan :ranked))
           (clean (lambda (s) (replace-regexp-in-string "[\t\n]+" " " (format "%s" (or s ""))))))
      (write-region
       (concat (mapconcat (lambda (x) (funcall clean x))
                          (list (format-time-string "%F %T" (plist-get plan :t0))
                                (plist-get plan :source)
                                (with-current-buffer (window-buffer (selected-window)) major-mode)
                                (plist-get plan :text)
                                (plist-get plan :kind)
                                (plist-get (plist-get plan :action) :name)
                                (and ranked (plist-get (nth 2 (car ranked)) :title))
                                (and ranked (format "%.2f" (nth 1 (car ranked))))
                                (and (cadr ranked) (format "%.2f" (- (car (car ranked)) (car (cadr ranked)))))
                                (plist-get plan :decision)
                                (format "%d" ms)
                                result)
                          "\t")
               "\n")
       nil (voice--log-file) t 'silent))))

(defun voice--wav-header (bytes)
  "A WAV header for BYTES of 16 kHz mono 16-bit PCM."
  (let ((le (lambda (n k) (apply #'unibyte-string
                                 (cl-loop for i below k collect (logand (ash n (* -8 i)) 255))))))
    (concat "RIFF" (funcall le (+ 36 bytes) 4) "WAVEfmt " (funcall le 16 4)
            (funcall le 1 2) (funcall le 1 2) (funcall le 16000 4) (funcall le 32000 4)
            (funcall le 2 2) (funcall le 16 2) "data" (funcall le bytes 4))))

(defun voice--save-audio (stamp)
  "Save the voice app's newest finished recording as STAMP.wav in
`voice-audio-directory', a moment later so it is complete.  Read as
root: its files are private to it, and other apps' data is hidden from
ours, hence the main mount view; KernelSU's su needs Emacs's own loader
off (see android-doom-root.el)."
  (when (and voice--android voice-audio-directory)
    (run-at-time
     2 nil
     (lambda ()
       (with-demoted-errors "voice audio: %S"
         (make-directory voice-audio-directory t)
         (let ((buf (generate-new-buffer " *voice-audio*"))
               (dest (expand-file-name (concat stamp ".wav") voice-audio-directory))
               (android-use-exec-loader nil))
           (with-current-buffer buf (set-buffer-multibyte nil))
           (make-process
            :name "voice-audio" :buffer buf :noquery t :connection-type 'pipe
            :coding 'binary
            :command (list "su" "--mount-master" "-c"
                           (format "f=$(ls -t %s/*.txt 2>/dev/null | head -1); [ -n \"$f\" ] && cat \"${f%%.txt}.pcm\""
                                   voice--app-history))
            :sentinel
            (lambda (proc _event)
              (unless (process-live-p proc)
                (with-current-buffer buf
                  (when (> (buffer-size) 1000)
                    (goto-char (point-min))
                    (insert (voice--wav-header (buffer-size)))
                    (let ((coding-system-for-write 'binary))
                      (write-region nil nil dest nil 'silent))))
                (kill-buffer buf)
                (voice--prune-audio))))))))))

(defvar voice-audio-days 7 "How many days of recordings to keep.")

(defun voice--prune-audio ()
  "Delete recordings older than `voice-audio-days'."
  (dolist (f (directory-files voice-audio-directory t "\\.wav\\'"))
    (when (> (float-time (time-since (file-attribute-modification-time (file-attributes f))))
             (* 86400 voice-audio-days))
      (ignore-errors (delete-file f)))))

(defun voice--tell (plan message)
  "Show MESSAGE; from the island also as a toast, Emacs being out of sight."
  (when message
    (message "%s" message)
    (when (and voice--android (equal (plist-get plan :source) "island")
               (bound-and-true-p emacs-home-dir))
      (with-demoted-errors "voice toast: %S"
        (write-region (concat message "\n") nil
                      (expand-file-name "voice-said.tsv" emacs-home-dir) nil 'silent)))))

(cl-defun voice-dispatch (text &key (source "typed") dry-run)
  "Do what TEXT says, heard from SOURCE.  With DRY-RUN, or `voice-dry-run',
only say what would happen.  Return the plan."
  (let* ((t0 (float-time))
         (said (voice--rewrite text))
         (plan (plist-put (plist-put (voice-plan said source) :source source) :t0 t0))
         result)
    (when (fboundp 'usage-log) (usage-log "voice" (or (plist-get (plist-get plan :action) :name)
                                                      (plist-get plan :kind))))
    (setq result
          (if (or dry-run voice-dry-run)
              (format "Would %s: %s" (plist-get plan :kind)
                      (or (and (plist-get plan :ranked) (plist-get (nth 2 (car (plist-get plan :ranked))) :title))
                          (plist-get (plist-get plan :action) :name) said))
            (condition-case err
                (with-local-quit (voice--execute plan))
              (quit "Stopped")
              (user-error (error-message-string err))
              (error (format "Voice failed: %s" (error-message-string err))))))
    (unless (member source '("typed" "test"))
      (voice--save-audio (format-time-string "%Y%m%d-%H%M%S" t0)))
    (voice--log plan (round (* 1000 (- (float-time) t0))) result)
    (voice--tell plan result)
    (plist-put plan :result result)))

;;;; Entry points

(defun voice-command (text)
  "Do what TEXT says, as if spoken."
  (interactive (list (let ((voice--fill nil)) (read-string "Say: "))))
  (voice-dispatch text :source "typed"))

(defun voice-listen ()
  "Listen, and do what is said: the voice app on the phone, else type."
  (interactive)
  (if voice-listen-function
      (funcall voice-listen-function "toolbar")
    (call-interactively #'voice-command)))
;; On the toolbar, so on the Termux:Widget allowlist too: no link may
;; open the microphone (android-launcher.el), and saying "voice" is no command.
(put 'voice-listen 'no-link t)
(put 'voice-listen 'voice-skip t)

(defun voice--heard-file ()
  (expand-file-name "voice-heard.tsv" (bound-and-true-p emacs-home-dir)))

(defvar voice-test-marker (and voice--android "/sdcard/Documents/voice-audio/TEST")
  "While this file is under three hours old, words from the app are only
planned, never done, and logged to test-log.tsv beside the recordings:
for a test run (test/voice-speak-test.py), so Emacs does nothing to your
tasks while the Mac speaks at the phone.")

(defun voice--testing-p ()
  (and voice-test-marker (file-exists-p voice-test-marker)
       (< (float-time (time-since (file-attribute-modification-time
                                   (file-attributes voice-test-marker))))
          10800)))

(defun voice-from-app ()
  "Called by the voice app once it heard something: plan it now, do it
just after.  Return front when Emacs should come forward, else quiet."
  (condition-case err
      (with-temp-buffer
        (insert-file-contents (voice--heard-file))
        (let* ((line (car (last (split-string (buffer-string) "\n" t))))
               (parts (and line (split-string line "\t")))
               (when-heard (and parts (string-to-number (car parts))))
               (source (or (nth 1 parts) "app"))
               (text (string-trim (mapconcat #'identity (nthcdr 2 parts) " "))))
          (cond
           ((or (null when-heard) (string-empty-p text)) 'quiet)
           ((> (- (float-time) when-heard) voice-stale-seconds)
            (message "Voice: dropped \"%s\", heard too long ago" text) 'quiet)
           ((voice--testing-p)
            (run-at-time 0 nil
                         (lambda ()
                           (let ((voice-log-file (expand-file-name "test-log.tsv" voice-audio-directory)))
                             (voice-dispatch text :source source :dry-run t))))
            'quiet)
           (t
            (let ((plan (voice-plan (voice--rewrite text) source)))
              (run-at-time 0 nil (lambda () (voice-dispatch text :source source)))
              (if (plist-get plan :front) 'front 'quiet))))))
    (error (message "Voice: %s" (error-message-string err)) 'quiet)))

(defun voice--ask-app (source)
  "Ask Emacs Home to listen: it watches for this file."
  (write-region (format "%d\t%s\n" (float-time) source) nil
                (expand-file-name "voice-ask" emacs-home-dir) nil 'silent)
  (message "Listening…"))

(when (and voice--android (boundp 'emacs-home-dir))
  (setq voice-listen-function #'voice--ask-app))
(with-eval-after-load 'emacs-home
  (when voice--android (setq voice-listen-function #'voice--ask-app)))

;;;; Checking phrases against what they should do

(defun voice-expect-ok (expect plan)
  "Non-nil when PLAN does what EXPECT says: action:NAME, task:WORDS (clocks
in, the top task's title containing WORDS), pick:WORDS (a pick list,
WORDS among its top five), or none."
  (let* ((kind (plist-get plan :kind))
         (ranked (plist-get plan :ranked))
         (titles (mapcar (lambda (r) (downcase (plist-get (nth 2 r) :title))) (seq-take ranked 5)))
         (want (and (string-match ":\\(.*\\)" expect) (downcase (string-trim (match-string 1 expect))))))
    (pcase (car (split-string expect ":"))
      ("action" (and (eq kind 'action)
                     (equal (downcase (plist-get (plist-get plan :action) :name)) want)))
      ("task" (and (eq kind 'task) (eq (plist-get plan :decision) 'act)
                   (car titles) (string-match-p (regexp-quote want) (car titles))))
      ("pick" (and (eq kind 'task) (eq (plist-get plan :decision) 'pick)
                   (seq-some (lambda (ti) (string-match-p (regexp-quote want) ti)) titles)))
      ("none" (or (eq kind 'none) (eq (plist-get plan :decision) 'none))))))

(defun voice-check-corpus (file &optional source)
  "Plan every phrase in FILE (PHRASE TAB EXPECT per line, # comments), as
heard from SOURCE (default island), doing nothing.  Write FILE-results.tsv
beside it: ok, phrase, expected, kind, action, top task, score, decision.
Return how many passed."
  (let ((rows nil) (ok 0) (n 0))
    (with-temp-buffer
      (insert-file-contents file)
      (dolist (line (split-string (buffer-string) "\n" t))
        (unless (string-prefix-p "#" line)
          (let* ((parts (split-string line "\t"))
                 (phrase (car parts)) (expect (or (nth 1 parts) "none"))
                 (plan (voice-plan (voice--rewrite phrase) (or source "island")))
                 (good (voice-expect-ok expect plan))
                 (top (car (plist-get plan :ranked))))
            (cl-incf n) (when good (cl-incf ok))
            (push (mapconcat (lambda (x) (format "%s" (or x "")))
                             (list (if good "ok" "MISS") phrase expect (plist-get plan :kind)
                                   (plist-get (plist-get plan :action) :name)
                                   (and top (plist-get (nth 2 top) :title))
                                   (and top (format "%.2f" (nth 1 top)))
                                   (plist-get plan :decision))
                             "\t")
                  rows)))))
    (with-temp-file (concat (file-name-sans-extension file) "-results.tsv")
      (insert (mapconcat #'identity (nreverse rows) "\n") "\n"))
    (format "%d of %d phrases do what they should" ok n)))

;;;; More things to say

(defun voice--choose (prompt candidates text)
  "The one of CANDIDATES (strings) TEXT clearly names; else ask with
PROMPT, TEXT's words typed, so a tap finishes it."
  (let ((ranked (and text (not (string-empty-p text)) (voice-match-strings candidates text 5))))
    (if (and ranked (eq (voice-match-decide ranked) 'act))
        (plist-get (nth 2 (car ranked)) :title)
      (let ((voice--fill nil))
        (completing-read prompt candidates nil t (and text (voice--typed text)))))))

(defun voice-switch-buffer (text)
  "Switch to the buffer TEXT names."
  (let* ((names (seq-remove (lambda (n) (string-prefix-p " " n)) (mapcar #'buffer-name (buffer-list))))
         (name (voice--choose "Buffer: " names text)))
    (switch-to-buffer name)
    (format "Buffer: %s" name)))

(defun voice-recent-file (text)
  "Open the recent file TEXT names, by its name."
  (require 'recentf)
  (let* ((files (seq-take recentf-list 300))
         (by-name (mapcar (lambda (f) (cons (format "%s  %s" (file-name-nondirectory f)
                                                    (abbreviate-file-name (file-name-directory f)))
                                            f))
                          files))
         (pick (voice--choose "Recent file: " (mapcar #'car by-name) text)))
    (find-file (cdr (assoc pick by-name)))
    (format "Opened %s" (file-name-nondirectory (cdr (assoc pick by-name))))))

(defun voice--date (text)
  "TEXT (\"tomorrow\", \"friday\", \"in 3 days\", \"next week\") as
`org-read-date' input, or nil."
  (let ((w (voice-match-words (or text ""))))
    (cond ((member "today" w) ".")
          ((or (member "tomorrow" w) (member "tmrw" w)) "+1d")
          ((and (member "next" w) (member "week" w)) "+1w")
          ((and (member "next" w) (member "month" w)) "+1m")
          ((let ((n (seq-find (lambda (x) (string-match-p "\\`[0-9]+\\'" x)) w)))
             (and n (or (member "day" w) (member "days" w)) (format "+%sd" n))))
          ((let ((n (seq-find (lambda (x) (string-match-p "\\`[0-9]+\\'" x)) w)))
             (and n (or (member "week" w) (member "weeks" w)) (format "+%sw" n))))
          ((seq-some (lambda (x)
                       (car (seq-find (lambda (d) (string-prefix-p (cdr d) x))
                                      '(("mon" . "mon") ("tue" . "tue") ("wed" . "wed") ("thu" . "thu")
                                        ("fri" . "fri") ("sat" . "sat") ("sun" . "sun")))))
                     w)))))

(defun voice-schedule (text)
  "Schedule the task here (in the agenda, the line's task) for TEXT."
  (let ((date (or (voice--date text) (user-error "Voice: when?  Say today, tomorrow, friday or in 3 days"))))
    (if (derived-mode-p 'org-agenda-mode)
        (org-agenda-schedule nil date)
      (org-schedule nil date))
    (format "Scheduled: %s" text)))

(defun voice-mark-done ()
  "Mark the task here done (in the agenda, the line's task)."
  (if (derived-mode-p 'org-agenda-mode) (org-agenda-todo 'done) (org-todo 'done))
  "Marked done")

(defun voice--org-here-p () (derived-mode-p 'org-mode 'org-agenda-mode))

(defun voice-time ()
  "The time now."
  (format-time-string "It's %H:%M, %A %e %B"))

(defun voice-timer (text)
  "An Org countdown of the minutes TEXT says: \"25 minutes\", \"1 hour\"."
  (require 'org-timer)
  (let* ((hm (or (voice--duration (voice-match-words text))
                 (user-error "Voice: how long?  Say 25 minutes or 1 hour")))
         (minutes (+ (* 60 (string-to-number (car (split-string hm ":"))))
                     (string-to-number (cadr (split-string hm ":"))))))
    (when (bound-and-true-p org-timer-countdown-timer) (org-timer-stop))
    (org-timer-set-timer minutes)
    (format "Timer: %d minutes" minutes)))

(defun voice-type-to-agent (text)
  "Type TEXT into the agent's chat, without sending it."
  (claude-remote--send text)
  (format "Typed: %s" text))

(defun voice-send-to-agent ()
  "Send what is typed in the agent's chat."
  (claude-remote--send "\r")
  "Sent")

;;;; Any command, as M-x

(defvar voice--commands-cache nil "(TIME . INDEX) of every command, for \"run …\".")

(defun voice--commands-index ()
  "An index of every command by its name's words, rebuilt every ten minutes
as packages load more."
  (if (and voice--commands-cache
           (< (float-time (time-since (car voice--commands-cache))) 600))
      (cdr voice--commands-cache)
    (let (cands)
      (mapatoms (lambda (sym)
                  (when (and (commandp sym) (not (get sym 'byte-obsolete-info)))
                    (push (list :title (symbol-name sym)) cands))))
      (let ((index (voice-match-index cands)))
        (setq voice--commands-cache (cons (current-time) index))
        index))))

(defun voice--best-first (names)
  "A completion table of NAMES that keeps their order: best first."
  (lambda (string pred action)
    (if (eq action 'metadata)
        '(metadata (category . command) (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action names string pred))))

(defun voice-run-command (text)
  "Run the command TEXT names, as M-x does.  Said exactly (\"run magit
status\"), it runs at once; else the commands open, the closest to what was
said first, to pick by tap or by voice.  One whose name kills, deletes,
reverts, quits or evaluates asks first, and that question is yours."
  (let* ((index (voice--commands-index))
         (query (voice-match-tokens text))
         (ranked (and query (voice-match-rank index query 30)))
         (exact (seq-find (lambda (r) (equal (voice-match-tokens (plist-get (nth 2 r) :title)) query))
                          ranked))
         (name (if exact
                   (plist-get (nth 2 exact) :title)
                 (let ((voice--fill nil)
                       (names (delete-dups
                               (append (mapcar (lambda (r) (plist-get (nth 2 r) :title)) ranked)
                                       (mapcar (lambda (e) (plist-get e :title))
                                               (voice-match-index-entries index))))))
                   (completing-read (if ranked (format "Run (closest to \"%s\" first): " text) "Run: ")
                                    (voice--best-first names) nil t nil 'voice-command-history))))
         (cmd (intern-soft name)))
    (unless (commandp cmd) (user-error "Voice: no command %s" name))
    (when (and (voice--denied-p cmd)
               (not (let ((voice--fill nil))
                      (y-or-n-p (format "Run %s?  Answer by hand " name)))))
      (user-error "Voice: not run"))
    (command-execute cmd 'record)
    (format "Ran %s" name)))

;; Collected once Emacs is idle, so the first "run …" doesn't wait for it.
(when voice--android (run-with-idle-timer 60 nil #'voice--commands-index))

;;;; What you can say

(defun voice--when-label (when)
  (pcase when
    ('nil nil) ('clocking "while clocked in") ('android "phone") ('remote "in an agent's chat")
    ('image-mode "on a photo") ((pred symbolp) (symbol-name when)) (_ "sometimes")))

(defun voice-help (&optional all)
  "Show what you can say here; with ALL (\\[universal-argument]), everything and when."
  (interactive "P")
  (let* ((context (voice-context))
         (mine (reverse (if all voice-actions
                          (seq-filter (lambda (a) (voice--when-p (plist-get a :when) context))
                                      voice-actions))))
         (mine-cmds (mapcar (lambda (a) (plist-get a :run)) voice-actions))
         (others (delete-dups
                  (mapcar (lambda (a) (plist-get a :name))
                          (seq-remove (lambda (a) (memq (plist-get a :run) mine-cmds))
                                      (append (voice--toolbar-actions) (voice--homepage-actions)))))))
    (with-current-buffer (get-buffer-create "*Voice commands*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (if all "#+title: Everything you can say\n\n" "#+title: What you can say here\n\n")
                "/A phrase with … takes the rest of what you say./\n\n* Commands\n")
        (dolist (a mine)
          (let ((label (or (plist-get a :where) (voice--when-label (plist-get a :when)))))
            (insert (format "- *%s*%s :: %s\n" (plist-get a :name)
                            (if label (format " (%s)" label) "")
                            (mapconcat (lambda (p) (format "\"%s\"" p)) (plist-get a :phrases) ", ")))))
        (when others
          (insert "\n* Buttons and tiles, by their names\n"
                  (mapconcat #'identity others ", ") "\n"))
        (insert "\n* Anything else\n"
                "- A task's name alone: the closest tasks, to pick one.\n"
                "- With a question open: its answer.  A choice by name or \"the second one\", yes or no, the text; \"cancel\" closes it.\n"
                "- Your own words for things: ~/org/voice.org (* Phrases, * Names).\n")
        (org-mode)
        (read-only-mode 1)
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))
    "What you can say"))

(defun voice-status ()
  "What the clock is on, and for how long."
  (if (and (fboundp 'org-clocking-p) (org-clocking-p))
      (format "Clocked in: %s, %s" org-clock-current-task
              (org-duration-from-minutes
               (floor (float-time (time-since org-clock-start-time)) 60)))
    "Not clocked in"))

(defun voice-diary ()
  "A diary line, through the diary template; its question is answered
from what was said."
  (org-capture nil "d")
  (when (bound-and-true-p org-capture-mode) (org-capture-finalize))
  "Added to the diary")

(voice-action '("clock in to …" "clock into …" "clock in …" "start …" "work on …"
                "working on …" "start working on …" "switch to …" "time for …"
                "read …" "watch …" "practice …" "study …" "meeting with …" "meeting …")
              #'voice-clock-in :slot 'task :quiet t :name "clock in")
(voice-action '("add task …" "new task …" "add a task …" "create task …"
                "start new task …" "start a new task …")
              #'voice-add-task :slot 'text :name "add task")
(voice-action '("done …" "finished …" "not done …") #'rts-flow-clock-out
              :when 'clocking :quiet t :name "clock out")
(voice-action '("pause" "stop" "clock out" "stop the clock" "stop clock")
              #'org-clock-out :when 'clocking :quiet t :name "pause")
(voice-action '("resume" "continue" "clock in again" "back to it")
              #'org-clock-in-last :quiet t :name "resume")
(voice-action '("cancel the clock" "cancel clock" "cancel")
              (lambda () (if (fboundp 'emacs-home--cancel) (emacs-home--cancel) (org-clock-cancel)))
              :when 'clocking :confirm t :name "cancel the clock")
(voice-action '("undo" "undo that" "take that back") #'voice-undo :quiet t :name "undo")
(voice-action '("save all" "save everything" "save org files" "save org buffers")
              #'org-save-all-org-buffers :quiet t :name "save everything")
(voice-action '("zen" "zen mode" "focus mode") #'global-writeroom-mode :quiet t :name "zen")
(voice-action '("flow" "what next" "what should i do") #'rts-flow :name "flow")
(voice-action '("review" "daily review" "write the review") #'day-log-review :name "review")
(voice-action '("home" "emacs home" "go home" "dashboard") #'android-homepage-toggle
              :when 'android :quiet t :name "home")
(voice-action '("attach camera photo" "attach a photo" "take a photo" "camera photo" "attach camera")
              #'my/org-attach-media :when 'android :name "camera photo")
(voice-action '("attach latest photo" "attach the latest" "attach screenshot" "attach last photo")
              #'my/org-attach-media :when 'android :name "latest photo")
(voice-action '("open herdr" "open mac" "herdr" "mac agents") #'claude-remote-mac
              :when 'android :name "open herdr")
(voice-action '("open kai" "kai agents") #'claude-remote-kai :when 'android :name "open kai")
(voice-action '("next" "next agent" "switch to next") #'claude-remote-next-session
              :when 'remote :quiet t :name "next agent")
(voice-action '("previous" "previous agent" "back" "switch to previous") #'claude-remote-prev-session
              :when 'remote :quiet t :name "previous agent")
(voice-action '("next" "next image" "next photo") #'image-next-file
              :when 'image-mode :quiet t :name "next image")
(voice-action '("previous" "previous image" "previous photo" "back") #'image-previous-file
              :when 'image-mode :quiet t :name "previous image")
(voice-action '("tag …" "tag it …" "tags …") #'set-image-tags-and-rename-and-next
              :when 'image-mode :name "tag image")
(voice-action '("agenda" "open agenda" "my agenda") #'my-org-agenda :name "agenda")
(voice-action '("help" "what can i say" "voice commands" "commands" "show help" "help me"
                "what can you do")
              #'voice-help :name "help")
;; The homepage's tiles, with more ways to say them: one short word alone
;; is what the voice app most often mishears.
(voice-action '("tip" "show a tip" "give me a tip" "next tip" "a tip") #'tips-next :name "tip")
(voice-action '("graph" "show the graph" "open graph" "note graph") #'org-roam-ui-open :name "graph")
(voice-action '("reread" "re read" "read again" "today's note") #'note-flow-reread :name "reread")
(voice-action '("buffers" "buffer list" "show buffers" "all buffers") #'ibuffer :name "buffers")
(voice-action '("diary" "photo diary" "browse photos") #'my/diary-browse-images :name "photo diary")
(voice-action '("neglect" "neglect report" "what am i neglecting") #'rts-flow-weekly-neglect-report
              :name "neglect")
(voice-action '("dailies" "daily notes") #'my/org-roam-dailies-cycle-focus :name "dailies")
(voice-action '("log" "daily note" "open log" "open the log") #'micro-experiments-log :name "log")
;; Going places
(voice-action '("open …" "launch …" "open app …" "start app …") #'emacs-home-launch
              :when 'android :asks '((:prompt "\\`App: " :type rest)) :name "open app")
(voice-action '("find note …" "find node …" "open note …" "go to note …" "note called …") #'org-roam-node-find
              :asks '((:prompt "\\`Node" :type rest)) :name "find note")
(voice-action '("buffer …" "switch to buffer …" "go to buffer …") #'voice-switch-buffer
              :slot 'text :name "buffer")
(voice-action '("open file …" "recent file …" "file …") #'voice-recent-file :slot 'text :name "recent file")
(voice-action '("today" "today's view" "today view" "my day") (lambda () (org-agenda nil "k")) :name "today")
(voice-action '("go back" "previous buffer" "last buffer") #'previous-buffer :quiet t :name "go back")
(voice-action '("close" "close window" "close this") #'quit-window :quiet t :name "close")
(voice-action '("scroll down" "page down" "down") #'scroll-up-command :quiet t :name "scroll down")
(voice-action '("scroll up" "page up" "up") #'scroll-down-command :quiet t :name "scroll up")
(voice-action '("top" "go to top" "beginning") #'beginning-of-buffer :quiet t :name "top")
(voice-action '("bottom" "go to bottom" "end") #'end-of-buffer :quiet t :name "bottom")
(voice-action '("bigger" "bigger text" "zoom in" "text bigger") #'text-scale-increase :quiet t :name "bigger text")
(voice-action '("smaller" "smaller text" "zoom out" "text smaller") #'text-scale-decrease :quiet t :name "smaller text")
;; Any command
(voice-action '("run …" "m x …" "mx …" "meta x …" "execute …" "run command …") #'voice-run-command
              :slot 'text :name "run command")
;; Planning
(voice-action '("walk" "walk tasks" "date tasks" "undated tasks") #'org-flow-date-undated :name "walk tasks")
(voice-action '("plan tomorrow" "time box tomorrow" "timebox tomorrow" "timebox") #'timebox-tomorrow
              :name "plan tomorrow")
(voice-action '("weekly review") (lambda () (org-capture nil "rw")) :name "weekly review")
(voice-action '("monthly review") (lambda () (org-capture nil "rm")) :name "monthly review")
(voice-action '("motto …" "set motto …" "set a motto …") (lambda () (org-capture nil "m"))
              :asks '((:prompt "diary entry" :type rest)) :name "motto")
(voice-action '("schedule …" "schedule it …" "schedule for …") #'voice-schedule :slot 'text
              :when #'voice--org-here-p :where "on a task" :name "schedule")
(voice-action '("mark done" "mark as done" "mark it done" "complete it") #'voice-mark-done
              :when #'voice--org-here-p :where "on a task" :quiet t :name "mark done")
(voice-action '("time" "what time is it" "what's the time") #'voice-time :quiet t :name "time")
(voice-action '("timer …" "set a timer for …" "set timer for …" "set a timer …" "timer for …")
              #'voice-timer :slot 'text :quiet t :name "timer")
;; In an agent's chat, and on a photo
(voice-action '("type …" "tell claude …" "dictate …" "tell it …") #'voice-type-to-agent :slot 'text
              :when 'remote :quiet t :name "type to agent")
(voice-action '("send" "send it" "submit" "press enter" "enter") #'voice-send-to-agent
              :when 'remote :quiet t :name "send to agent")
(voice-action '("rotate" "rotate it" "rotate image") #'image-rotate :when 'image-mode :quiet t :name "rotate image")
(voice-action '("status" "what am i doing" "what am i on" "what's running" "how long"
                "what's the status" "what am i working on" "clock status")
              #'voice-status :quiet t :name "status")
(voice-action '("diary …" "dear diary …" "diary entry …" "write in diary …") #'voice-diary
              :asks '((:prompt "diary entry" :type rest)) :name "diary")

(provide 'voice-command)
;;; voice-command.el ends here
