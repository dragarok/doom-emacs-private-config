;;; voice-fill.el --- Voice: a command's questions answered from what was said -*- lexical-binding: t -*-

;;; Commentary:
;; While an action runs, its minibuffer questions are answered from the
;; sentence ("done, deep work"), or by voice once asked.

;;; Code:

(require 'voice-core)

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

(defun voice--typed-in (text strings)
  "TEXT's words that some of STRINGS have, to type into their filter: a
word none has would empty the list."
  (if (null strings) (voice--typed text)
    (string-join (seq-filter (lambda (w) (seq-some (lambda (s) (string-match-p (regexp-quote w) (downcase s)))
                                                   strings))
                             (voice-match-tokens text))
                 " ")))

(defun voice--reordered (strings collection)
  "A completion table of STRINGS in their order, else as COLLECTION is:
its category, its annotations."
  (let ((md (ignore-errors (completion-metadata "" collection nil))))
    (lambda (string pred action)
      (if (eq action 'metadata)
          `(metadata (display-sort-function . identity) (cycle-sort-function . identity)
                     ,@(seq-remove (lambda (x) (memq (car-safe x) '(display-sort-function cycle-sort-function)))
                                   (cdr-safe md)))
        (complete-with-action action strings string pred)))))

(defvar voice--recording nil
  "Non-nil while voice runs a command: what its questions get is kept in
`voice--answers', newest first, to learn.")

(defvar voice--answers nil)

(defun voice--got (answer)
  "ANSWER, kept when a command voice runs asked for it."
  (when voice--recording (push answer voice--answers))
  answer)

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
or opens the list with the entries nearest it first (by name, and what
describes them: \"dark\" brings the dark themes up), else with its words
typed, to say which or tap."
  (let* ((claimed (and voice--fill (voice--answer-for prompt)))
         (ans (or claimed
                  (and voice--fill (not (voice--owned-p prompt))
                       (voice--from-pool (voice--collection-strings collection predicate)))))
         (settled (if (and claimed (stringp claimed))
                      (voice--settle claimed (voice--collection-strings collection predicate)
                                     (and (car args) (not (eq (car args) 'confirm-after-completion))))
                    ans)))
    (voice--got
     (cond (settled settled)
           (claimed
            (let* ((voice--fill nil)
                   (strings (voice--collection-strings collection predicate))
                   (order (and (stringp claimed) strings (< (length strings) 3000)
                               (voice-emacs-order claimed strings))))
              (if order
                  (apply orig prompt (voice--reordered order collection) nil args)
                (apply orig prompt collection predicate
                       (voice--with-initial args (voice--typed-in claimed strings))))))
           (t (let ((voice--fill nil)) (apply orig prompt collection predicate args)))))))

(defun voice--read-string-a (orig prompt &rest args)
  (voice--got (or (and voice--fill (voice--answer-for prompt))
                  (let ((voice--fill nil)) (apply orig prompt args)))))

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

(provide 'voice-fill)
;;; voice-fill.el ends here
