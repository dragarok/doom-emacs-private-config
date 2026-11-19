;;; voice-anycommand.el --- Voice domain: any command, by what it is called -*- lexical-binding: t -*-

;;; Commentary:
;; Every interactive command, found by voice-emacs.el's catalog: its name,
;; what its key says, words that mean the same, and what it asks for.

;;; Code:

(require 'voice-core)
(require 'voice-emacs)
(declare-function voice--exact-command "voice-plan" (commands near))

;; Bound here, defined in another part.
(defvar voice--answers)
(defvar voice--fill)
(defvar voice--recording)

;;;; Any command, by what it is called (voice-emacs.el)

(defvar voice-pick-command-score 0.3
  "Least S for showing the closest commands to pick from, when nothing is
nearer: below it, the words are no command.")

(defvar voice--last-run nil
  "(:cmd COMMAND :answer STRING) of the last command voice ran: what to
learn on a yes or a pick.")

(defun voice--emacs-context (context)
  "CONTEXT (`voice-context') as `voice-emacs-rank' takes it."
  (let ((modes (seq-filter (lambda (m) (and (symbolp m) (string-suffix-p "-mode" (symbol-name m))))
                           context)))
    (list :modes modes :here (and modes (voice-emacs-here)))))

(defun voice--command-action (r)
  "An action running the command of R, a result of `voice-emacs-rank'."
  (let ((cmd (plist-get r :cmd)))
    (list :name (symbol-name cmd) :run cmd :slot 'command :command t
          :runner #'voice--run-command-plan
          :value (plist-get r :value) :kind (plist-get r :kind)
          :exact (plist-get r :exact) :literal (plist-get r :literal) :f (plist-get r :f)
          :phrases (list (plist-get r :label)) :patterns nil)))

(defun voice--command-options (words _actions context)
  "Commands WORDS (pairs) may mean, as near actions are: (S ACTION PHRASE
SLOT-WORDS), best first."
  (mapcar (lambda (r)
            (list (plist-get r :s) (voice--command-action r) (plist-get r :label) (plist-get r :slot)))
          (ignore-errors (voice-emacs-rank words (voice--emacs-context context) 8))))

(defun voice--run-command (cmd &optional answer source)
  "Run CMD as M-x does; ANSWER, if given, answers its first question (a
list's entry it names, else the list opens with the nearest first); a
number is its count too, its prefix argument (\"down 5\": C-u 5 <down>).  One
whose name kills, deletes, reverts, quits or evaluates asks first, and
that question is yours to answer by hand."
  (let ((real (or (command-remapping cmd) cmd)))
    (unless (commandp real) (user-error "Voice: no command %s" cmd))
    (when (and (voice--denied-p real)
               (not (let ((voice--fill nil))
                      (y-or-n-p (format "Run %s?  Answer by hand " real)))))
      (user-error "Voice: not run"))
    (setq voice--last-run nil)
    (voice--listen-soon source)
    (let* ((count (and (numberp answer) answer))
           (answer (if count (number-to-string count) answer))
           (voice--fill (and answer (list :pool nil :answers (list (cons "" answer)) :owned nil)))
           (voice--recording t)
           (voice--answers nil)
           (prefix-arg (or count prefix-arg)))
      (command-execute real 'record)
      ;; What Emacs's repeat (C-x z, "repeat") does again, with its count.
      (unless (eq real 'repeat)
        (setq last-repeatable-command real last-prefix-arg count))
      (let ((got (seq-find #'stringp (reverse voice--answers))))
        (setq voice--last-run (list :cmd cmd :answer (or got answer)))
        (format "Ran %s%s" real (if got (format ": %s" got) ""))))))

(defun voice--canonical (run)
  "RUN (`voice--last-run') as words that do it again: \"run load-theme doom-one\"."
  (and run (string-trim (format "run %s %s" (plist-get run :cmd) (or (plist-get run :answer) "")))))

(defun voice--learn-command (said)
  "Teach voice.org that SAID means the command voice just ran.  Return
what to tell, or nil."
  (and said (not (string-empty-p said)) voice--last-run
       (voice--add-rule "Phrases" said (voice--canonical voice--last-run))))

(defun voice--best-first (names)
  "A completion table of NAMES that keeps their order: best first."
  (lambda (string pred action)
    (if (eq action 'metadata)
        '(metadata (category . command) (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action names string pred))))

(defun voice--pick-command (said options &optional source)
  "Show every command, the OPTIONS (near ones, from `voice--command-options')
first, to say or tap which SAID meant; run it, and learn it."
  (let* ((names (delete-dups
                 (append (mapcar (lambda (o) (symbol-name (plist-get (nth 1 o) :run))) options)
                         (mapcar (lambda (e) (symbol-name (plist-get e :cmd)))
                                 (voice-match-index-entries (voice-emacs-catalog))))))
         (voice--fill nil)
         (name (completing-read (format "Which command is \"%s\"? " said)
                                (voice--best-first names) nil t nil 'voice-command-history))
         (result (voice--run-command (intern name) nil source))
         (learned (voice--learn-command said)))
    (if learned (format "%s; %s" result learned) result)))

(defun voice-run-command (text)
  "Run the command TEXT names, as M-x does: by its own name (\"run
load-theme doom-one\", as voice.org's learned phrases write it, the rest
answering its question), or by what it is called, when clear; else the
closest commands open, to pick by voice or tap."
  (let* ((parts (split-string (string-trim text) "[[:space:]]+" t))
         (named (and parts (string-match-p "[-/:]" (car parts)) (intern-soft (car parts)))))
    (if (and named (commandp named))
        (let ((rest (and (cdr parts) (string-join (cdr parts) " "))))
          ;; "run next-line 5", as voice.org writes a count learned.
          (voice--run-command named (if (and rest (string-match-p "\\`[0-9]+\\'" rest)
                                             (eq (car (voice-emacs-asks named)) 'number))
                                        (string-to-number rest)
                                      rest)
                              voice--source))
      (let* ((options (voice--command-options-for text voice--source))
             (top (voice--command-choice options)))
        (if top
            (voice--run-command (plist-get (nth 1 top) :run)
                                (or (plist-get (nth 1 top) :value)
                                    (and (nth 3 top) (voice--join (nth 3 top))))
                                voice--source)
          (voice--pick-command (or voice--said text) options voice--source))))))

(defun voice--command-options-for (text source)
  "The commands TEXT, said from SOURCE, may mean (`voice--command-options')."
  (let ((words (voice--words text)))
    (and words (voice--command-options words nil (voice-context source)))))

(defun voice--command-choice (options)
  "Of OPTIONS (`voice--command-options'), the one \"run …\" runs: one said
just as it is called (`voice--exact-command'), else one clearly nearest;
nil when it is for you to pick."
  (let ((top (car options)) (next (cadr options)))
    (or (voice--exact-command options nil)
        (and top (>= (car top) voice-act-score)
             (>= (- (car top) (if next (car next) 0.0)) voice-act-margin)
             top))))

;; Collected once Emacs is idle, so the first command said doesn't wait.
(when voice--android (run-with-idle-timer 60 nil #'voice-emacs-catalog))

;;;; What to say

;; Any command
(voice-action '("run …" "m x …" "mx …" "meta x …" "execute …" "run command …") #'voice-run-command
              :slot 'text :name "run command")

;;;; The domain

(defun voice--run-command-plan (plan)
  "Run PLAN's command, what was said after its name answering its question."
  (let ((action (plist-get plan :action)) (slot (plist-get plan :slot)))
    (voice--run-command (plist-get action :run)
                        (or (plist-get action :value) (and slot (not (string-empty-p slot)) slot))
                        (plist-get plan :source))))

(defun voice--command-offers (u)
  (voice--command-options (plist-get u :words) nil (plist-get u :context)))

(defun voice--command-fallback (u strict)
  "The commands nearest what U says, to pick one: near enough to ask
about, when STRICT, else to be a command at all."
  (let ((cmds (seq-filter (lambda (o) (plist-get (nth 1 o) :command)) (voice--offers u))))
    (when (and cmds (>= (car (car cmds)) (if strict voice-ask-score voice-pick-command-score)))
      (cons (car (car cmds)) (list :kind 'pick-command :text (plist-get u :text) :options cmds :front t)))))

(defun voice--execute-pick-command (plan)
  (voice--pick-command (plist-get plan :text) (plist-get plan :options) (plist-get plan :source)))

(defun voice--command-vocab ()
  "The jargon in command names, said as words: the libraries the commands
you have keys for or have used come from (magit, vertico, consult, dired,
org roam).  A word is jargon when it names a library Emacs has loaded;
\"buffer\" and \"move\" name none, and a recogniser knows them already."
  (let ((labels (voice-emacs--labels)) (history (voice-emacs--history))
        (seen (make-hash-table :test 'equal)) out)
    (dolist (cmd (voice-emacs--commands))
      (when (or (gethash cmd labels) (> (gethash (symbol-name cmd) history 0) 0))
        (let ((w (split-string (voice-emacs--name-words cmd) " " t)))
          (dotimes (n (min 3 (length w)))
            (let ((lib (string-join (seq-take w (1+ n)) "-")))
              (unless (gethash lib seen)
                (puthash lib t seen)
                (when (featurep (intern lib)) (push (string-replace "-" " " lib) out))))))))
    (append (voice--key-label-vocab labels) out)))

(defun voice--key-label-vocab (labels)
  "What the leader's keys are called (\"Habits this month\", \"Find file\"),
as they are said: the words a recogniser should hear as one phrase, not
pulled toward a task's title that sounds alike.  LABELS: `voice-emacs--labels'."
  (let (out)
    (maphash (lambda (_cmd v)
               (when (nth 2 v)
                 ;; As the key shows it, its group unsaid (the BARE labels).
                 (dolist (l (nth 3 v))
                   (let ((name (and (stringp l) (string-trim (voice-emacs--label-name l)))))
                     (when (and name (string-match-p "[[:alpha:]]" name)
                                (not (string-match-p "[→←]" name)))
                       (push name out))))))
             labels)
    (delete-dups out)))

(voice-define-domain 'anycommand
  :doc "Every command, by its name, what its key says, or words meaning the same."
  :vocab #'voice--command-vocab
  :offers #'voice--command-offers
  :fallback #'voice--command-fallback
  :kinds '((pick-command . voice--execute-pick-command)))

(provide 'voice-anycommand)
;;; voice-anycommand.el ends here
