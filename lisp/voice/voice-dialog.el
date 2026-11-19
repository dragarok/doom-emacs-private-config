;;; voice-dialog.el --- Voice: asking -- did you mean, the question on screen, lists -*- lexical-binding: t -*-

;;; Commentary:
;; Everything voice asks you, and how what you say answers what Emacs asks.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--choice)
(defvar voice-ask-score)
(defvar voice--confirm)

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

(defun voice--answer-prompt (text &optional source)
  "Answer the open question with TEXT, heard from SOURCE: a key for a key
question, a choice by name or place, else TEXT as typed.  A name near one
of a list's entries but not clearly it is asked about (\"Did you mean
doom-ayu-light?\"); a yes picks it and is learned."
  (when (eq (plist-get (plist-get voice--confirm :plan) :kind) 'answer)
    (setq voice--confirm nil)
    (voice--show-question ""))
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
            (let ((a (voice--list-answer text (voice--collection-strings table minibuffer-completion-predicate)
                                         (and (bound-and-true-p vertico--candidates) vertico--candidates))))
              (pcase (car a)
                ('pick (voice--set-and-exit (cdr a)) (format "Answered: %s" (cdr a)))
                ('ask (voice--ask-entry text (cdr a) source))
                (_ (delete-minibuffer-contents) (insert text) "Typed it in: pick, or say which"))))
           (t
            (let ((s (or (and (voice--prompt-wants-duration-p prompt) (voice--duration words))
                         text)))
              (voice--set-and-exit s)
              (format "Answered: %s" s)))))))
     (t nil))))

(defun voice--open-list ()
  "The open minibuffer's list, when what is said is answered from it as
`voice--answer-prompt' does: (ENTRIES . SHOWN), SHOWN the ones on
screen; else nil (no list, a y-or-n, a key question, one never answered)."
  (when (and (not voice--choice) (active-minibuffer-window))
    (with-selected-window (active-minibuffer-window)
      (let ((prompt (or (minibuffer-prompt) "")) (table minibuffer-completion-table))
        (and table
             (not (memq minibuffer-history-variable voice--refused-histories))
             (not (let ((case-fold-search t)) (string-match-p voice-refused-prompt-regexp prompt)))
             (not (string-match-p "(y or n)" prompt))
             (not (and (boundp 'crm-completion-table) crm-completion-table
                       (eq table 'crm--collection-fn)))
             (cons (voice--collection-strings table minibuffer-completion-predicate)
                   (and (bound-and-true-p vertico--candidates) vertico--candidates)))))))

(defun voice--answer-decision (text)
  "How TEXT answers the open minibuffer's list: act when it names an
entry, ask when it is near one, type when neither; nil when no list is
open to pick from, or TEXT cancels.  Of the engine's readings, the first
that names an entry is the one done (`voice--best-reading')."
  (let ((open (voice--open-list)))
    (when (and open (not (member (string-join (voice-match-words text) " ")
                                 '("cancel" "never mind" "nevermind" "stop" "quit" "escape"))))
      (pcase (car (voice--list-answer text (car open) (cdr open)))
        ('pick 'act) ('ask 'ask) (_ 'type)))))

(defvar voice-list-ask-lead 0.05
  "Least lead of a list's nearest entry over the next for asking about it.")

(defun voice--list-answer (text cands &optional shown)
  "What TEXT says of a list's entries CANDS, SHOWN the ones on screen:
\(pick . ENTRY) when it names one, by name, as it sounds, or by place
\(\"the second one\"); (ask . ENTRY) when it is near one but not clearly
it; else nil."
  (let* ((words (voice-match-words text)) (tokens (voice-match-tokens text t))
         (n (voice--ordinal words))
         (letters (and cands (cl-every (lambda (c) (= 1 (length c))) cands)))
         ranked
         (hit (cond ((car (member text cands)))
                    ((and n shown (<= n (length shown))) (nth (1- n) shown))
                    ((and n cands (<= n (length cands))) (nth (1- n) cands))
                    ((and letters (null (cdr words)))
                     (let ((l (cdr (assoc (car words) voice--letters))))
                       (seq-find (lambda (c) (equal (upcase c) l)) cands)))
                    (t (or (voice-match-mentioned cands tokens)
                           (progn (setq ranked (voice-match-strings cands text 2))
                                  (and (eq (voice-match-decide ranked) 'act)
                                       (plist-get (nth 2 (car ranked)) :title))))))))
    (cond (hit (cons 'pick hit))
          ((and ranked (>= (nth 1 (car ranked)) voice-ask-score)
                ;; Near several alike ("light" of every light theme),
                ;; asking about one would be a guess.
                (or (null (cadr ranked))
                    (>= (- (car (car ranked)) (car (cadr ranked))) voice-list-ask-lead)))
           (cons 'ask (plist-get (nth 2 (car ranked)) :title))))))

;;;; Did you mean

(defvar voice--confirm nil
  "A question open: (:plan PLAN :said TEXT :meant PHRASE :rest OPTIONS
:ranked TASKS :until TIME).")

(defvar voice-confirm-seconds 60 "How long a \"did you mean\" waits for yes or no.")

(defconst voice--yes '("yes" "yeah" "yep" "yup" "ya" "yah" "yea" "sure" "correct" "right"
                       "okay" "ok" "affirmative" "absolutely" "exactly" "please" "go ahead" "do it")
  "Answers meaning yes; misheard ones are as near as `voice-match-sim' allows.")

(defconst voice--no '("no" "nope" "nah" "not" "wrong" "cancel" "never mind" "neither" "none")
  "Answers meaning no.")

(defun voice--confirm-live-p ()
  (and voice--confirm (< (float-time) (plist-get voice--confirm :until))))

(defun voice--yes-or-no (text)
  "`yes' or `no' when TEXT is a short answer meaning so, else nil."
  (let* ((words (voice-match-words text))
         (phrase (string-join words " "))
         (near (lambda (list) (seq-some (lambda (a)
                                          (or (equal phrase a) (equal (car words) a)
                                              (>= (voice-match-sim (car words) a) 0.9)))
                                        list))))
    (when (and words (<= (length words) 4))
      (cond ((funcall near voice--no) 'no)
            ((funcall near voice--yes) 'yes)))))

(defun voice--show-question (question)
  "Show QUESTION on the island with Yes and No (\"\" takes it away)."
  (when (and voice--android (bound-and-true-p emacs-home-dir))
    (with-demoted-errors "voice question: %S"
      (write-region (concat question "\n") nil
                    (expand-file-name "voice-confirm.tsv" emacs-home-dir) nil 'silent))))

(defun voice--option-label (option)
  "How a near command (S ACTION PHRASE SLOT) is asked about: the phrase,
what its … got, and the command's name when the phrase isn't it:
\"stop\" (pause)."
  (let* ((slot (voice--join (nth 3 option)))
         (phrase (string-trim (replace-regexp-in-string "[[:space:]]*\\(…\\|\\.\\.\\.\\)[[:space:]]*" " " (nth 2 option))))
         (name (plist-get (nth 1 option) :name)))
    (concat "\"" phrase (if (string-empty-p slot) "" (concat " " slot)) "\""
            (if (equal (voice-match-normalize name) (voice-match-normalize phrase)) ""
              (format " (%s)" name)))))

(defun voice--ask (said options fallback source)
  "Ask whether the first of OPTIONS was meant by SAID; keep the rest, and
FALLBACK, a plan (the tasks or commands to pick from), for the last no."
  (let* ((option (car options))
         (command (plist-get (nth 1 option) :command))
         (question (format "Did you mean %s?" (voice--option-label option))))
    (setq voice--confirm
          (list :plan (voice--action-plan said (nth 1 option) (voice--join (nth 3 option)) said)
                :said said :command command
                :phrase (concat (replace-regexp-in-string "…\\|\\.\\.\\." " " (nth 2 option))
                                " " (voice--join (nth 3 option)))
                :meant (and (not command) (null (nth 3 option)) (not (string-match-p "…" (nth 2 option)))
                            (nth 2 option))
                :rest (seq-remove (lambda (o) (eq (nth 1 o) (nth 1 option))) (cdr options))
                :fallback fallback :source source
                :until (+ (float-time) voice-confirm-seconds)))
    (voice--pose question source)))

(defun voice--ask-entry (said entry source)
  "Ask whether SAID, answering the open list, meant its ENTRY: a yes picks
it, and voice.org learns that SAID is ENTRY (\"are you light\" for
doom-ayu-light, as you say it)."
  (setq voice--confirm
        (list :plan (list :kind 'answer :text entry :source source :front t)
              :said said :meant entry :phrase entry :source source
              :until (+ (float-time) voice-confirm-seconds)))
  (voice--pose (format "Did you mean %s?" entry) source))

(defun voice--pose (question source)
  "Show QUESTION, the one in `voice--confirm', and listen for its answer.
Return what to tell."
  (voice--show-question question)
  ;; Unanswered, it goes, and off the island too.
  (let ((c voice--confirm))
    (run-at-time (1+ voice-confirm-seconds) nil
                 (lambda () (when (eq voice--confirm c)
                              (setq voice--confirm nil)
                              (voice--show-question "")))))
  ;; From the island or the toolbar, listen for the answer right away.
  (when (and voice--android (member source '("island" "toolbar" "app")) voice-listen-function)
    (run-at-time 1.2 nil (lambda () (ignore-errors (funcall voice-listen-function source)))))
  (concat question " Say yes or no"))

(defun voice--said-in-p (phrase said)
  "Non-nil when SAID has PHRASE's words in a row: nothing to learn from
it, the rest was noise (\"Play Store split window right\")."
  (let ((p (voice-match-tokens (or phrase ""))))
    (and p (voice-match--in-order-p p (voice-match-tokens (or said ""))))))

(defun voice--answer-confirm (answer)
  "Do what the open question asked about on a yes; on a no, ask about the
next near command, or offer the tasks."
  (let ((c voice--confirm))
    (setq voice--confirm nil)
    (voice--show-question "")
    (if (eq answer 'yes)
        (let* ((result (voice--execute (plist-get c :plan)))
               ;; Taught: the same sentence is that command from now on,
               ;; with what its question got.
               (meant (if (plist-get c :command) (voice--canonical voice--last-run) (plist-get c :meant))))
          (when (and meant (not (voice--said-in-p (plist-get c :phrase) (plist-get c :said))))
            (let ((learned (voice--add-rule "Phrases" (plist-get c :said) meant)))
              (when learned (setq result (format "%s; %s" (or result "Done") learned)))))
          result)
      (cond ((plist-get c :rest)
             (voice--ask (plist-get c :said) (plist-get c :rest) (plist-get c :fallback) (plist-get c :source)))
            ((plist-get c :fallback)
             (voice--execute (plist-put (copy-sequence (plist-get c :fallback)) :source (plist-get c :source))))
            (t "Okay, not that")))))

;;;; Moving in an open list

(defun voice--press (key)
  "Press KEY (as `kbd' reads it) in the open question, as if typed."
  (setq unread-command-events (append unread-command-events (listify-key-sequence (kbd key))))
  nil)

(defun voice--minibuffer-move (words text)
  "The action moving in the open list that WORDS (pairs) say word for
word, unless TEXT is one of the list's entries."
  (let ((mw (active-minibuffer-window)))
    (when (and mw words
               (with-selected-window mw
                 (and minibuffer-completion-table
                      (not (string-match-p "(y or n)" (or (minibuffer-prompt) ""))))))
      (let* ((moves (seq-filter (lambda (a) (eq (plist-get a :when) 'minibuffer)) voice-actions))
             (hit (voice--best-action words moves))
             (said (voice-match-normalize text)))
        (when (and hit (null (nth 1 hit))
                   (not (with-selected-window mw
                          (seq-some (lambda (c) (equal (voice-match-normalize c) said))
                                    (voice--collection-strings minibuffer-completion-table
                                                               minibuffer-completion-predicate)))))
          (car hit))))))

;;;; What to say

;; In an open list (any minibuffer question with choices)
(voice-action '("next" "next one" "down" "go down") (lambda () (voice--press "<down>") "Next")
              :when 'minibuffer :quiet t :name "next choice")

(voice-action '("previous" "previous one" "up" "go up") (lambda () (voice--press "<up>") "Previous")
              :when 'minibuffer :quiet t :name "previous choice")

(voice-action '("more" "page down" "next page" "show more") (lambda () (voice--press "<next>") "More")
              :when 'minibuffer :quiet t :name "next page")

(voice-action '("page up" "previous page") (lambda () (voice--press "<prior>") "Back a page")
              :when 'minibuffer :quiet t :name "previous page")

(voice-action '("this one" "that one" "select" "select it" "choose it" "pick it" "pick this"
                "ok" "okay" "enter" "yes" "do it" "confirm" "go")
              (lambda () (voice--press "RET") "Chosen") :when 'minibuffer :quiet t :name "choose this")

(voice-action '("clear" "show all" "clear it" "all of them")
              (lambda () (with-selected-window (active-minibuffer-window) (delete-minibuffer-contents)) "Cleared")
              :when 'minibuffer :quiet t :name "clear the list")

(defun voice--listen-soon (source)
  "From the island or the toolbar: listen again in a moment, if a question
is open then, for its answer."
  (when (and voice--android voice-listen-function (member source '("island" "toolbar" "app")))
    (run-at-time 1.5 nil (lambda ()
                           (when (or (active-minibuffer-window) voice--choice)
                             (ignore-errors (funcall voice-listen-function source)))))))

(provide 'voice-dialog)
;;; voice-dialog.el ends here
