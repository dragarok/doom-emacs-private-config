;;; voice-plan.el --- Voice: understanding and deciding -*- lexical-binding: t -*-

;;; Commentary:
;; What was said is weighed against every action, task and command the
;; same way; one rule decides to do it, ask about it or show the closest.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--fill)

;;;; Planning and running

(defun voice--strip-tail (tail words)
  "WORDS (pairs) without TAIL, the literal words a phrase ends with, or
`fail' when they don't end WORDS or nothing is left before them."
  (let ((n (length tail)))
    (if (and (> (length words) n)
             (cl-every (lambda (pair) (>= (voice--literal-sim (car pair) (cdr (cdr pair))) 0.8))
                       (cl-mapcar #'cons tail (last words n))))
        (butlast words n)
      'fail)))

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
            (let ((rest (nthcdr (car m) words)))
              (when (consp (cdr p)) (setq rest (voice--strip-tail (cdr p) rest)))
              (unless (eq rest 'fail)
                (let* ((slot (voice--slot-words rest))
                       (cand (list a slot (- (+ (cdr m) (if (consp (cdr p)) (length (cdr p)) 0))
                                             (if (and (cdr p) (null slot)) 0.5 0))
                                   (voice--specificity (plist-get a :when))
                                   (car m))))
                  (when (or (null best) (> (nth 2 cand) (nth 2 best))
                            (and (= (nth 2 cand) (nth 2 best)) (> (nth 3 cand) (nth 3 best))))
                    (setq best cand)))))))))
    best))

;;;; Near, not word for word

;;
;; What was said is weighed against every command the same way: how much
;; of it the command's words explain (all its phrases' words: "pause
;; clocking" is pause's), and how much of the command's phrase was said.
;; Words count by how few commands use them, as task titles' words do.
;; Then one rule decides: a clear winner is done, a near one is asked
;; about ("Did you mean stop tagging?"), and a yes teaches voice.org the
;; sentence, so next time it is done.  No list of mishearings by hand.

(defvar voice-act-score 0.85
  "Least S for doing a command said nearly, not word for word.")

(defvar voice-act-margin 0.15
  "Least lead over the next command for that.")

(defvar voice-ask-score 0.5
  "Least S for asking whether a command was meant.")

(defun voice--action-vocab (action)
  "Every word ACTION's phrases use."
  (delete-dups
   (apply #'append (mapcar (lambda (p) (append (car p) (and (consp (cdr p)) (cdr p))))
                           (plist-get action :patterns)))))

(defun voice--covered (xs ys weight sim)
  "How much of XS, each counted by WEIGHT (of it and its place), its best
SIM in YS explains, 0 to 1."
  (let ((num 0.0) (den 0.0) (i 0))
    (dolist (x xs)
      (let ((w (funcall weight x i)))
        (cl-incf den w)
        (cl-incf num (* w (let ((best 0.0)) (dolist (y ys) (setq best (max best (funcall sim x y)))) best))))
      (cl-incf i))
    (if (> den 0) (/ num den) 0.0)))

(defun voice--near-actions (words actions)
  "ACTIONS ranked by how near WORDS (pairs) are to what each is called,
best first, as (S ACTION PHRASE SLOT-WORDS).

S is 0.75 of how much of what was said the action's words explain (all
its phrases' words: \"pause clocking\" is pause's), plus 0.25 of how much
of its best phrase was said.  A phrase with \"…\" is weighed on its own
literal words against the words said in their place; the rest is its slot.

A word counts by how few commands use it (idf); one no command uses, as
an average word, since it tells nothing about which; a small word
(\"to\", \"on\") a quarter of that, though it still tells \"clock in\" from
\"clock out\".  What is said first counts more: commands open with their
verb.  A phrase said in full at the start (\"clock out\" on image tagging)
is at least worth asking about.

A phrase whose … names a thing of a kind a domain knows (an app, a task,
a buffer) counts as a command's rest does: S times its share of what was
said, plus the rest's share times how well it names one of them.
\"switch to a dark theme\" is near \"switch to buffer …\", but no buffer
is called dark theme."
  (let* ((tokens (mapcar #'cdr words))
         (vocabs (mapcar (lambda (a) (cons a (voice--action-vocab a))) actions))
         (df (make-hash-table :test 'equal))
         (n (length actions))
         (slots (voice--domain-table :slots))
         (found-memo (make-hash-table :test 'equal))
         (found (lambda (a slot)
                  (let ((make (alist-get (plist-get a :slot) slots)))
                    (when make
                      (let* ((text (voice--join (voice--slot-words slot)))
                             (key (cons (plist-get a :slot) text)))
                        (if (string-empty-p text) 0.0
                          (with-memoization (gethash key found-memo)
                            (or (ignore-errors (plist-get (funcall make "" a text "") :found))
                                0.0))))))))
         out)
    (dolist (v vocabs) (dolist (w (cdr v)) (puthash w (1+ (gethash w df 0)) df)))
    (let* ((idf (lambda (d) (log (+ 1.0 (/ (float n) (+ 1 d))))))
           (mean (let ((sum 0.0) (k 0))
                   (maphash (lambda (_w d) (cl-incf sum (funcall idf d)) (cl-incf k)) df)
                   (if (> k 0) (/ sum k) 1.0)))
           (word-weight (lambda (w)
                          (if (member w voice-match-stop-words) (* 0.25 mean)
                            (let ((d (gethash w df))) (if d (funcall idf d) mean)))))
           (said-weight (lambda (w i) (* (funcall word-weight w) (+ 1.0 (/ 1.0 (+ i 1))))))
           (phrase-weight (lambda (w _i) (funcall word-weight w)))
           (heard-sim (lambda (heard cmd) (voice--literal-sim cmd heard)))
           (cmd-sim (lambda (cmd heard) (voice--literal-sim cmd heard))))
      (when tokens
        (dolist (v vocabs)
          (let ((a (car v)) best)
            (dolist (p (plist-get a :patterns))
              (let* ((lit (car p))
                     (tail (and (consp (cdr p)) (cdr p)))
                     (slot-p (cdr p))
                     (k (length lit)) (m (length tail))
                     (head (if slot-p (seq-take tokens k) tokens))
                     (end (and tail (last tokens m)))
                     (slot (and slot-p (> (length words) (+ k m))
                                (butlast (nthcdr k words) m))))
                (when (and (or lit tail) (or (not slot-p) slot))
                  (let* ((heard (append head end))
                         (s (+ (* 0.75 (voice--covered heard (if slot-p (append lit tail) (cdr v))
                                                       said-weight heard-sim))
                               (* 0.25 (voice--covered (append lit tail) heard phrase-weight cmd-sim))))
                         (named (and slot (funcall found a slot))))
                    (when named
                      (let* ((w (lambda (xs) (apply #'+ 0.0 (mapcar word-weight xs))))
                             (all (funcall w tokens))
                             (share (if (> all 0) (/ (funcall w heard) all) 1.0)))
                        (setq s (* s (+ share (* (- 1 share) named))))))
                    ;; Said in full, first: worth asking about.
                    (when (and (not slot-p) (voice--match-literal p words))
                      (setq s (max s voice-ask-score)))
                    (when (or (null best) (> s (car best)))
                      (setq best (list s a (nth (cl-position p (plist-get a :patterns)) (plist-get a :phrases))
                                       (voice--slot-words slot))))))))
            (when best (push best out))))))
    (sort out (lambda (x y) (> (car x) (car y))))))

(defun voice--opening (words actions)
  "How many of WORDS (pairs), from the first, a phrase without \"…\" of
ACTIONS says word for word, at most; and that action: (N . ACTION)."
  (let (best)
    (dolist (a actions)
      (dolist (p (plist-get a :patterns))
        (unless (cdr p)
          (let ((m (voice--match-literal p words)))
            (when (and m (or (null best) (> (car m) (car best))))
              (setq best (cons (car m) a)))))))
    best))

(defun voice--action-plan (text action slot request)
  "The plan for doing ACTION, SLOT (a string) what its … got: made by the
domain whose slot it is (a task's name), else to run it."
  (let ((make (alist-get (plist-get action :slot) (voice--domain-table :slots))))
    (if make (funcall make text action slot request)
      (list :kind 'action :text text :action action :slot slot
            :front (not (plist-get action :quiet))))))

(defun voice-plan (text &optional source)
  "What TEXT, heard from SOURCE, would do: a plist.  Does nothing itself.
An open question takes the answer first.  Word for word a phrase is done;
else every phrase and every domain's options are weighed against what
was said, and the best done when it clearly wins, asked about when near,
else the closest shown (see `voice--decide')."
  (let* ((context (voice-context source))
         (words (voice--strip-chatter (voice--words text)))
         (request (if words (voice--join words) text))
         (answer (and (voice--confirm-live-p) (voice--yes-or-no text))))
    (cond
     (answer
      (list :kind 'confirm :text text :answer answer
            ;; Emacs comes forward to do what was meant, if that asks
            ;; something, or on the last no, for the list to pick from.
            :front (if (eq answer 'yes) (plist-get (plist-get voice--confirm :plan) :front)
                     (and (null (plist-get voice--confirm :rest))
                          (plist-get voice--confirm :fallback)
                          t))))
     ((or voice--choice (memq 'minibuffer context))
      (let ((move (and (not voice--choice) (voice--minibuffer-move words text))))
        (if move
            (list :kind 'action :text text :action move :slot "" :front t)
          (list :kind 'answer :text text :source source :front t))))
     ((null words) (list :kind 'none :text text))
     (t (voice--plan-said (voice--utterance text source context words request
                                            (voice--all-actions context)))))))

(defun voice--offers (u)
  "Every domain's options for U besides phrases, best first; made once."
  (voice--once u :offers
               (lambda ()
                 (let ((all (apply #'append (mapcar (lambda (f) (funcall f u)) (voice--domains :offers)))))
                   (sort all (lambda (a b) (> (car a) (car b))))))))

(defun voice--plan-said (u)
  "The plan for U, said with no question open."
  (let* ((text (plist-get u :text)) (words (plist-get u :words))
         (request (plist-get u :request)) (actions (plist-get u :actions))
         (hit (voice--best-action words actions))
         (opening (and hit (voice--opening words actions)))
         literal unnamed)
    ;; Word for word, unless another phrase says more of how it opens:
    ;; "clock OUT on image tagging" is not "clock in …" with the small
    ;; word left out.
    (when (and opening (not (eq (cdr opening) (car hit))) (> (car opening) (nth 4 hit)))
      (setq hit nil))
    (setq literal (and hit (voice--action-plan text (car hit) (voice--join (nth 1 hit)) request)))
    ;; A phrase whose … named nothing clearly ("switch to dark mode": no
    ;; task called that) gives way to an option nearer than what it found.
    (when (and literal (plist-get literal :decision) (not (eq (plist-get literal :decision) 'act))
               (not (string-empty-p (or (plist-get literal :slot) ""))))
      (let ((offer (car (voice--offers u))))
        (when (and offer (>= (car offer) voice-ask-score)
                   (> (car offer) (or (plist-get literal :found) 0.0)))
          (setq unnamed (car hit) literal nil))))
    ;; Word for word only by near sounds ("list buffers" for "last
    ;; buffer"), when an option is called exactly that.
    (when (and literal (< (nth 2 hit) (nth 4 hit)))
      (let ((exact (seq-find (lambda (c) (eq (plist-get (nth 1 c) :exact) 'name)) (voice--offers u))))
        (when exact (setq literal (voice--action-plan text (nth 1 exact) "" request)))))
    ;; A phrase whose … took words, not clearly naming its thing, gives way
    ;; to a command the whole sentence names just so: "run project" is SPC
    ;; p R's, not M-x "project"; "diary add image to today" the image key's,
    ;; not a diary entry saying "add image to today".
    (when (and literal (not (eq (plist-get literal :decision) 'act))
               (not (string-empty-p (or (plist-get literal :slot) ""))))
      (let ((exact (voice--exact-command (voice--offers u) nil)))
        (when exact
          (setq literal (plist-put (voice--action-plan text (nth 1 exact) "" request)
                                   :near-score (car exact))))))
    (or literal (voice--decide u unnamed))))

(defun voice--fallback (u strict)
  "The best of the domains' fallbacks for U, (S . PLAN); on a tie, the
domain defined first.  STRICT: only what is worth offering after a no."
  (let (best)
    (dolist (f (voice--domains :fallback))
      (let ((fb (funcall f u strict)))
        (when (and fb (or (null best) (> (car fb) (car best))))
          (setq best fb))))
    best))

(defun voice--decide (u unnamed)
  "One rule for what U means, nothing said word for word (UNNAMED: a
phrase that gave way).  A domain's claim as near as anything: done.  Said
just as an option is called: done.  One option clearly nearest: done.
One near: asked about, the next ones and the best fallback kept for a no.
Else the best fallback shows: the tasks or commands to pick from."
  (let* ((text (plist-get u :text)) (request (plist-get u :request))
         (offers (voice--offers u))
         (near (voice--merge-near (seq-remove (lambda (n) (eq (nth 1 n) unnamed))
                                              (voice--near-actions (plist-get u :words) (plist-get u :actions)))
                                  offers))
         (exact (voice--exact-command offers near))
         (top (car near))
         (s1 (if top (car top) 0.0))
         (s2 (or (car (seq-find (lambda (n) (not (or (voice--same-option-p n top)
                                                     (voice--same-intent-p n top))))
                                (cdr near)))
                 0.0))
         (claim (let (best)
                  (dolist (f (voice--domains :claim))
                    (let ((c (funcall f u s1)))
                      (when (and c (or (null best) (> (plist-get c :near) (plist-get best :near))))
                        (setq best c))))
                  best)))
    (cond
     (claim claim)
     (exact
      (plist-put (voice--action-plan text (nth 1 exact) "" request) :near-score (car exact)))
     ((and top (>= s1 voice-act-score) (>= (- s1 s2) voice-act-margin))
      (plist-put (voice--action-plan text (nth 1 top) (voice--join (nth 3 top)) request)
                 :near-score s1))
     ((>= s1 voice-ask-score)
      (let ((fallback (cdr (voice--fallback u t))))
        (list :kind 'ask :text text :front nil
              :options (seq-take (seq-filter (lambda (n) (>= (car n) voice-ask-score)) near) 4)
              :fallback fallback
              :ranked (plist-get fallback :ranked))))
     ;; Marked, so a reading that does something can be preferred to it,
     ;; and words for a text field are typed rather than picked from.
     (t (let ((fallback (cdr (voice--fallback u nil))))
          (if fallback (plist-put fallback :fallen t)
            (list :kind 'none :text text)))))))

(defun voice--run-action (plan)
  "Run PLAN's action: by its domain's runner if it has one (a command
found by name), else its questions filled from what was said."
  (let ((runner (plist-get (plist-get plan :action) :runner)))
    (if runner (funcall runner plan) (voice--run-plain-action plan))))

(defun voice--run-plain-action (plan)
  "Run PLAN's action, one of `voice-actions', its questions filled from
what was said."
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
      (let ((result (cond ((or (eq kind 'text) (and kind (not (commandp run)))) (funcall run slot))
                          ((commandp run) (call-interactively run))
                          (t (funcall run)))))
        (if (stringp result) result (format "Done: %s" (plist-get action :name)))))))

(defun voice--execute (plan)
  "Do what PLAN says; return what to tell.  A kind of plan a domain makes
is done by that domain."
  (pcase (plist-get plan :kind)
    ('answer (or (voice--answer-prompt (plist-get plan :text) (plist-get plan :source)) "No question open"))
    ('action (voice--run-action plan))
    ('ask (voice--ask (plist-get plan :text) (plist-get plan :options) (plist-get plan :fallback)
                      (plist-get plan :source)))
    ('confirm (voice--answer-confirm (plist-get plan :answer)))
    (kind (let ((do (alist-get kind (voice--domain-table :kinds))))
            (if do (funcall do plan) (format "Didn't get: %s" (plist-get plan :text)))))))

(defun voice--tell (plan message)
  "Show MESSAGE; from the island (or a field of another app) the island
says it too, Emacs being out of sight."
  (when message
    (message "%s" message)
    (when (and voice--android (member (plist-get plan :source) '("island" "field"))
               (bound-and-true-p emacs-home-dir))
      (with-demoted-errors "voice toast: %S"
        (write-region (concat message "\n") nil
                      (expand-file-name "voice-said.tsv" emacs-home-dir) nil 'silent)))))

(defvar voice--source nil "Where the words being done came from.")

(defvar voice--said nil "The words being done, as heard.")

(defvar voice--planned nil
  "(TIME TEXT SOURCE . PLAN): what `voice-from-app' just planned, so the
dispatch a moment later need not weigh every command again.")

(defun voice--plan-for (said source)
  "The plan for SAID from SOURCE: the one just made, if fresh."
  (let ((p voice--planned))
    (setq voice--planned nil)
    (if (and p (< (- (float-time) (nth 0 p)) 5) (equal (nth 1 p) said) (equal (nth 2 p) source))
        (copy-sequence (nthcdr 3 p))
      (voice-plan said source))))

(cl-defun voice-dispatch (text &key (source "typed") dry-run)
  "Do what TEXT says, heard from SOURCE.  With DRY-RUN, or `voice-dry-run',
only say what would happen.  Return the plan."
  (let* ((t0 (float-time))
         (said (voice--rewrite text))
         (plan (plist-put (plist-put (voice--plan-for said source) :source source) :t0 t0))
         (voice--source source)
         (voice--said text)
         result)
    (unless (memq (plist-get plan :kind) '(confirm))
      (when voice--confirm (setq voice--confirm nil) (voice--show-question "")))
    (when (fboundp 'usage-log) (usage-log "voice" (or (plist-get (plist-get plan :action) :name)
                                                      (plist-get plan :kind))))
    (setq result
          (if (or dry-run voice-dry-run)
              (format "Would %s: %s" (plist-get plan :kind)
                      (or (and (plist-get plan :ranked) (plist-get (nth 2 (car (plist-get plan :ranked))) :title))
                          (plist-get (plist-get plan :action) :name) said))
            (condition-case err
                (with-local-quit
                  (prog1 (voice--execute plan)
                    ;; Still in a list: listen for the next word of it.
                    (when (or (eq (plist-get plan :kind) 'answer)
                              (eq (plist-get (plist-get plan :action) :when) 'minibuffer))
                      (voice--listen-soon source))))
              (quit "Stopped")
              (user-error (error-message-string err))
              (error (format "Voice failed: %s" (error-message-string err))))))
    (unless (member source '("typed" "test"))
      (voice--save-audio (format-time-string "%Y%m%d-%H%M%S" t0)))
    (voice--log plan (round (* 1000 (- (float-time) t0))) result)
    (voice--tell plan result)
    (plist-put plan :result result)))

;;;; Near options, merged

(defun voice--merge-near (actions commands)
  "Near ACTIONS and COMMANDS as one list, best first; on a tie an action,
then the command with the higher priors.  A command an action runs too
is there once, the nearer way."
  (let (out)
    (dolist (o (sort (append actions commands nil) ; copied: sort is destructive
                     (lambda (a b) (or (> (car a) (car b))
                                       (and (= (car a) (car b))
                                            (> (or (plist-get (nth 1 a) :f) 2.0)
                                               (or (plist-get (nth 1 b) :f) 2.0)))))))
      (unless (seq-some (lambda (x) (voice--same-option-p x o)) out)
        (push o out)))
    (nreverse out)))

(defun voice--same-option-p (a b)
  "Non-nil when near options A and B do the same."
  (or (eq (nth 1 a) (nth 1 b))
      (let ((ra (plist-get (nth 1 a) :run)) (rb (plist-get (nth 1 b) :run)))
        (and (symbolp ra) ra (eq ra rb)))))

(defun voice--same-intent-p (a b)
  "Non-nil when near options A and B are commands that ask the same kind
of thing and would get the same answer: load-theme and enable-theme, for
\"change theme to tango dark\", or for \"switch to a dark theme\" (no one
theme named: the same list, dark ones first).  Then the priors pick, no
question."
  (let ((sa (nth 3 a)) (sb (nth 3 b)) (a (nth 1 a)) (b (nth 1 b)))
    (and (plist-get a :command) (plist-get b :command)
         (plist-get a :kind) (eq (plist-get a :kind) (plist-get b :kind))
         (equal (plist-get a :value) (plist-get b :value))
         (or (plist-get a :value) (and sa (equal sa sb))))))

(defvar voice-emacs-exact-order)

(defun voice--exact-command (commands near)
  "The command of COMMANDS said just as it is called -- by `voice-emacs-exact-order',
then word for word unstemmed (\"browse an issue\" not \"browse issues\"),
then the best by priors; none when an action is as near."
  (let* ((exact (seq-filter (lambda (c) (plist-get (nth 1 c) :exact)) commands))
         (pick (cl-loop for way in voice-emacs-exact-order
                        for these = (seq-filter (lambda (c) (eq (plist-get (nth 1 c) :exact) way)) exact)
                        when these
                        return (car (sort these (lambda (a b)
                                                  (let ((la (plist-get (nth 1 a) :literal))
                                                        (lb (plist-get (nth 1 b) :literal)))
                                                    (if (eq (not la) (not lb))
                                                        (> (plist-get (nth 1 a) :f) (plist-get (nth 1 b) :f))
                                                      la))))))))
    (and pick
         (not (seq-some (lambda (n) (and (not (plist-get (nth 1 n) :command)) (>= (car n) (car pick)))) near))
         pick)))

(provide 'voice-plan)
;;; voice-plan.el ends here
