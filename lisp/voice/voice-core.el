;;; voice-core.el --- Voice: the core -- actions, context, words -*- lexical-binding: t -*-

;;; Commentary:
;; What every part of voice shares: the settings, the list of actions and
;; how one is added (`voice-action'), the context an utterance is heard
;; in, and the words of what was said.  Domains (voice-tasks.el,
;; voice-photos.el …) add actions here; they never touch the planner.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'voice-match)

;;;; top

(require 'cl-lib)

(require 'subr-x)

(require 'seq)

(require 'voice-match)

(require 'voice-emacs)

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
  "PHRASE as (WORDS . SLOT): its words before \"…\"; SLOT nil when it has
no \"…\", t when \"…\" ends it, else the words after it, which must end
what is said (\"mark … done\")."
  (if (not (string-match "…\\|\\.\\.\\." phrase))
      (cons (voice-match-tokens phrase t) nil)
    (let* ((from (match-beginning 0)) (to (match-end 0))
           (tail (voice-match-tokens (substring phrase to) t)))
      (cons (voice-match-tokens (substring phrase 0 from) t)
            (or tail t)))))

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

;;;; Domains
;;
;; A domain is what can be said about one part of your life or of Emacs:
;; tasks and the clock, photos, agents, any command.  Its file adds its
;; phrases with `voice-action' and says what else it knows here.  The
;; planner asks every domain the same questions and never names one, so a
;; new domain is a new file; nothing else changes.

(defvar voice-domains nil
  "The domains, in the order defined: (NAME . SPEC).  See `voice-define-domain'.")

(cl-defun voice-define-domain (name &rest spec &key doc context actions offers claim fallback
                                    slots kinds vocab enable disable &allow-other-keys)
  "Add the domain NAME (a symbol), or replace it: its old DISABLE runs
first, then the new ENABLE, so a file loaded again leaves nothing behind.
DOC says what it is for.  Each of the rest is optional:

CONTEXT (SOURCE): flags it adds to `voice-context' now (clocking, image).
ACTIONS (CONTEXT): more actions, made now (the toolbar's buttons).
OFFERS (U): what U (see `voice--utterance') may mean besides phrases, as
  near options: (S ACTION PHRASE SLOT-WORDS), best first.
CLAIM (U BEST): a plan, when what was said is clearly this domain's
  (a task named, a photo's tags said), as near as BEST, the nearest
  option's S, at least.  The nearest claim wins; S is its plan's :near.
FALLBACK (U STRICT): (S . PLAN), what to show when nothing is near
  enough: the tasks to pick from, the closest commands.  The highest S
  is shown.  STRICT: only what is worth offering after a no.
SLOTS: ((SLOT . FN) …): FN (TEXT ACTION SLOT REQUEST) makes the plan for
  an action whose … is SLOT (\='task: the task it names).
KINDS: ((KIND . FN) …): FN (PLAN) does a plan of KIND; returns what to tell.
VOCAB (): phrases the speech engine should hear well, as strings: names
  a general model doesn't know (tasks, apps, the commands' jargon).  See
  voice-engine.el."
  (ignore doc context actions offers claim fallback slots kinds vocab disable)
  (let ((old (assq name voice-domains)))
    (when-let* ((off (plist-get (cdr old) :disable))) (ignore-errors (funcall off)))
    (if old (setcdr old spec) (setq voice-domains (append voice-domains (list (cons name spec))))))
  (when enable (funcall enable))
  name)

(defun voice--domains (key)
  "Every domain's KEY, where it has one, in the order they were defined."
  (delq nil (mapcar (lambda (d) (plist-get (cdr d) key)) voice-domains)))

(defun voice--domain-table (key)
  "Every domain's KEY alist, as one."
  (apply #'append (voice--domains key)))

(defun voice--utterance (text source context words request actions)
  "What was said, as domains are asked about it: a plist of TEXT, SOURCE,
CONTEXT, WORDS (pairs), REQUEST (without chatter) and the ACTIONS that
hold.  `voice--once' keeps what is worked out about it."
  (list :text text :source source :context context :words words :request request
        :actions actions))

(defun voice--once (u key make)
  "U's KEY, made by MAKE the first time it is asked for."
  (if (plist-member u key) (plist-get u key)
    (let ((v (funcall make))) (plist-put u key v) v)))

;;;; Context

(defun voice-context (&optional source)
  "Flags for now: minibuffer, android, each domain's (clocking, remote,
image …), plus the major mode and its parents.  From the island, only
what holds whatever app is in front: you are not looking at an Emacs
buffer."
  (let ((buffer-flags (not (equal source "island"))))
    (delq nil
          (append
           (list (and (active-minibuffer-window) 'minibuffer)
                 (and voice--android 'android))
           (apply #'append (mapcar (lambda (f) (ignore-errors (funcall f source)))
                                   (voice--domains :context)))
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
        ((and (symbolp when) (or (eq when 'image) (string-suffix-p "-mode" (symbol-name when)))) 2)
        ((symbolp when) 1)
        ((functionp when) 1)
        ((listp when) (apply #'max 0 (mapcar #'voice--specificity when)))
        (t 1)))

;;;; Ready-made actions: the toolbar and the homepage

(defun voice--denied-p (command)
  (string-match-p voice-deny-regexp (symbol-name command)))

(defun voice--all-actions (context)
  "Every action that holds in CONTEXT: yours first, then the ones domains
make now (the toolbar's buttons, the homepage's tiles) that run a command
none of yours does."
  (let* ((mine (seq-filter (lambda (a) (voice--when-p (plist-get a :when) context))
                           voice-actions))
         (cmds (mapcar (lambda (a) (plist-get a :run)) mine)))
    (append mine
            (seq-filter (lambda (a) (and (not (memq (plist-get a :run) cmds))
                                         (voice--when-p (plist-get a :when) context)
                                         (push (plist-get a :run) cmds)))
                        (apply #'append (mapcar (lambda (f) (funcall f context))
                                                (voice--domains :actions)))))))

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

(provide 'voice-core)
;;; voice-core.el ends here
