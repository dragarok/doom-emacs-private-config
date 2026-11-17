;;; voice-match.el --- Match spoken words to titles -*- lexical-binding: t -*-

;;; Commentary:
;; The matcher behind voice-command.el, and nothing else: no Org, no Doom,
;; so it loads under emacs -Q and is tested in batch.
;;
;; Words are normalised (lower case, number words as digits, a light
;; stemmer) and compared loosely: equal, the same consonants (a name
;; misheard), one a prefix of the other, or a small edit distance.  Each
;; word counts by how rare it is among the titles (idf), so "guitar"
;; decides a match and "practice" barely does.
;;
;; A candidate scores S, how well what was said and its title cover each
;; other, plus P, small priors (clocked lately, due today) that only break
;; ties.  `voice-match-decide' acts on a clear winner, offers a short pick
;; list when it is close, and gives up when nothing is near.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)

(defvar voice-match-act-score 0.80
  "Least S for acting on the best candidate without asking.")

(defvar voice-match-act-margin 0.20
  "Least lead, in S + P, of the best candidate over the next to act on it.")

(defvar voice-match-pick-score 0.45
  "Least S for offering a candidate in the pick list.")

(defvar voice-match-prior-cap 0.15
  "Most the priors may add.  Kept under the margin: priors alone never act.")

(defconst voice-match-stop-words
  '("a" "an" "the" "to" "of" "for" "in" "on" "at" "my" "and" "or" "with"
    "into" "is" "it" "this" "that" "please" "some" "up" "me" "i" "be")
  "Words dropped before matching titles.")

(defconst voice-match-numbers
  '(("zero" . "0") ("one" . "1") ("two" . "2") ("three" . "3") ("four" . "4")
    ("five" . "5") ("six" . "6") ("seven" . "7") ("eight" . "8") ("nine" . "9")
    ("ten" . "10") ("eleven" . "11") ("twelve" . "12") ("fifteen" . "15")
    ("twenty" . "20") ("thirty" . "30") ("forty" . "40") ("fifty" . "50")
    ("sixty" . "60") ("ninety" . "90") ("hundred" . "100")))

;;;; Words

(defun voice-match-stem (word)
  "WORD with a common English ending taken off, the same way every time."
  (let ((n (length word)))
    (cond ((< n 4) word)
          ((and (>= n 6) (string-suffix-p "ing" word)) (substring word 0 -3))
          ((and (>= n 5) (string-suffix-p "ies" word)) (concat (substring word 0 -3) "y"))
          ((and (>= n 5) (string-suffix-p "ed" word)) (substring word 0 -2))
          ((and (string-suffix-p "s" word) (not (string-suffix-p "ss" word))
                (not (string-suffix-p "us" word)))
           (substring word 0 -1))
          (t word))))

(defun voice-match-words (string)
  "STRING as lower-case words, number words as digits, not stemmed."
  (mapcar (lambda (w) (or (cdr (assoc w voice-match-numbers)) w))
          (split-string (downcase (or string "")) "[^[:alnum:]]+" t)))

(defun voice-match-tokens (string &optional keep-stop)
  "STRING's words, stemmed, without stop words unless KEEP-STOP."
  (mapcar #'voice-match-stem
          (if keep-stop
              (voice-match-words string)
            (seq-remove (lambda (w) (member w voice-match-stop-words))
                        (voice-match-words string)))))

(defun voice-match-normalize (string)
  "STRING's words joined by single spaces: what equal phrases share."
  (string-join (voice-match-words string) " "))

(defun voice-match--single (word)
  "WORD with doubled letters single: \"ellen\" and \"elon\" sound alike."
  (replace-regexp-in-string "\\(.\\)\\1+" "\\1" word))

(defun voice-match--skeleton (word)
  "WORD's first letter and its later consonants: names sound alike by them."
  (let ((word (voice-match--single word)))
    (if (string-empty-p word) word
      (concat (substring word 0 1)
              (replace-regexp-in-string "[aeiouy]" "" (substring word 1))))))

(defun voice-match--devoice (word)
  "WORD single, its voiced consonants unvoiced: recognisers swap d and t
\(\"dagging\" for \"tagging\"), b and p, g and k, v and f, z and s."
  (let ((w (voice-match--single word)))
    (dotimes (i (length w))
      (let ((c (assq (aref w i) '((?d . ?t) (?b . ?p) (?g . ?k) (?v . ?f) (?z . ?s)))))
        (when c (aset w i (cdr c)))))
    w))

(defun voice-match-sim (x y)
  "How alike words X and Y are, 0 to 1."
  (let ((lx (length x)) (ly (length y)))
    (cond ((string= x y) 1.0)
          ((string-match-p "\\`[0-9]+\\'" (concat x y)) 0.0) ; numbers are exact
          ((string= (voice-match--single x) (voice-match--single y)) 0.95)
          ((and (>= lx 4) (>= ly 4)
                (or (string= (voice-match--skeleton x) (voice-match--skeleton y))
                    (string= (voice-match--devoice x) (voice-match--devoice y))))
           0.9)
          ((and (>= (min lx ly) 3)
                (or (string-prefix-p x y) (string-prefix-p y x)))
           0.85)
          ((and (>= lx 4) (>= ly 4))
           (let ((s (- 1.0 (/ (float (string-distance x y)) (max lx ly)))))
             (if (>= s 0.75) s 0.0)))
          (t 0.0))))

(defun voice-match--best-sim (word words)
  "The best `voice-match-sim' of WORD against WORDS."
  (let ((best 0.0))
    (while (and words (< best 0.999))
      (setq best (max best (voice-match-sim word (pop words)))))
    best))

;;;; Index

(cl-defstruct (voice-match-index (:constructor voice-match--make-index))
  entries        ; vector of plists, each with :words :extra :aliases :prior
  idf            ; hash: token -> idf
  default-idf    ; idf of a token no title has
  keys)          ; hash: key (token, skeleton, prefix) -> list of entry numbers

(defun voice-match--keys (token)
  "Lookup keys for TOKEN: itself, its consonants, its first three letters."
  (delete-dups (delq nil (list token
                               (and (>= (length token) 4)
                                    (concat "~" (voice-match--skeleton token)))
                               (and (>= (length token) 3)
                                    (concat "^" (substring token 0 3)))))))

(defun voice-match-index (candidates)
  "Index CANDIDATES for `voice-match-rank'.
Each candidate is a plist: :title (string), optionally :aliases (strings,
other names for it), :extra (string: tags, parent; counts at 0.6), :prior
\(0 to `voice-match-prior-cap'), and anything else the caller keeps."
  (let* ((n (length candidates))
         (df (make-hash-table :test 'equal))
         (keys (make-hash-table :test 'equal))
         (entries
          (vconcat
           (mapcar (lambda (c)
                     (append (list :words (voice-match-tokens (plist-get c :title))
                                   :extra (voice-match-tokens (plist-get c :extra))
                                   :aliases (mapcar #'voice-match-tokens (plist-get c :aliases)))
                             c))
                   candidates)))
         (idf (make-hash-table :test 'equal)))
    (dotimes (i (length entries))
      (let* ((e (aref entries i))
             (all (delete-dups (append (plist-get e :words)
                                       (apply #'append (plist-get e :aliases))
                                       (plist-get e :extra)))))
        (dolist (tok (delete-dups (append (plist-get e :words)
                                          (apply #'append (plist-get e :aliases)))))
          (puthash tok (1+ (gethash tok df 0)) df))
        (dolist (tok all)
          (dolist (k (voice-match--keys tok))
            (push i (gethash k keys))))))
    (maphash (lambda (tok d) (puthash tok (log (+ 1.0 (/ (float n) (+ 1 d)))) idf)) df)
    (voice-match--make-index :entries entries :idf idf
                             :default-idf (log (+ 1.0 n)) :keys keys)))

(defun voice-match--idf (index token)
  (gethash token (voice-match-index-idf index) (voice-match-index-default-idf index)))

;;;; Scoring

(defun voice-match--in-order-p (query words)
  "Non-nil when QUERY's words appear in WORDS as a run, in order."
  (and query (cl-search query words :test #'string=)))

(defun voice-match--weight (index token)
  "How much TOKEN counts: its idf, three times over for a number, which
tells siblings apart (Chapter 5, not Chapter 15)."
  (* (voice-match--idf index token) (if (string-match-p "\\`[0-9]+\\'" token) 3 1)))

(defun voice-match--joined (query words)
  "Pairs of neighbouring WORDS that a long word of QUERY says as one:
\"escherbach\" for Escher, Bach.  Return (SIM I) for each, I the first's
position."
  (let (out)
    (when (seq-some (lambda (x) (>= (length x) 6)) query)
      (let ((i 0) (ws words))
        (while (cdr ws)
          (let* ((joined (concat (car ws) (cadr ws)))
                 (sim (apply #'max 0.0 (mapcar (lambda (x) (if (>= (length x) 6) (voice-match-sim x joined) 0.0))
                                               query))))
            (when (>= sim 0.85) (push (list sim i joined) out)))
          (setq ws (cdr ws) i (1+ i)))))
    out))

(defun voice-match--score-words (index query words extra)
  "S for QUERY tokens against a title's WORDS and its EXTRA tokens."
  (if (or (null query) (null words)) 0.0
    (let* ((num 0.0) (den 0.0) (num2 0.0) (den2 0.0)
           (joined (voice-match--joined query words))
           (joined-words (mapcar #'caddr joined)))
      (dolist (x query)
        (let ((w (voice-match--weight index x)))
          (cl-incf den w)
          (cl-incf num (* w (max (voice-match--best-sim x words)
                                 (if joined-words (voice-match--best-sim x joined-words) 0.0)
                                 (* 0.6 (voice-match--best-sim x extra)))))))
      (let ((i 0))
        (dolist (y words)
          (let ((w (voice-match--weight index y))
                (pair (seq-find (lambda (j) (memq i (list (nth 1 j) (1+ (nth 1 j))))) joined)))
            (cl-incf den2 w)
            (cl-incf num2 (* w (max (voice-match--best-sim y query) (if pair (car pair) 0.0)))))
          (cl-incf i)))
      (min 1.0 (+ (* 0.75 (/ num den)) (* 0.25 (/ num2 den2))
                  (if (and (cdr query) (voice-match--in-order-p query words)) 0.05 0.0))))))

(defun voice-match--score (index query entry)
  "S for QUERY tokens against ENTRY: its title or its best alias."
  (let ((extra (plist-get entry :extra)))
    (apply #'max (voice-match--score-words index query (plist-get entry :words) extra)
           (mapcar (lambda (a) (voice-match--score-words index query a nil))
                   (plist-get entry :aliases)))))

(defun voice-match-rank (index query &optional limit prior-fn)
  "Candidates of INDEX for QUERY (a string), best first, at most LIMIT.
Each result is (F S ENTRY): F is S plus the priors, given by ENTRY's
:prior, plus what PRIOR-FN returns for ENTRY if given; capped at
`voice-match-prior-cap', and only added when S is 0.5 or more."
  (let* ((query (if (stringp query) (voice-match-tokens query) query))
         (seen (make-hash-table))
         out)
    (dolist (x query)
      (dolist (k (voice-match--keys x))
        (dolist (i (gethash k (voice-match-index-keys index)))
          (puthash i t seen))))
    (maphash
     (lambda (i _)
       (let* ((e (aref (voice-match-index-entries index) i))
              (s (voice-match--score index query e)))
         (when (> s 0.0)
           (let ((p (if (< s 0.5) 0.0
                      (min voice-match-prior-cap
                           (+ (or (plist-get e :prior) 0.0)
                              (if prior-fn (or (funcall prior-fn e) 0.0) 0.0))))))
             (push (list (+ s p) s e) out)))))
     seen)
    (setq out (sort out (lambda (a b) (or (> (car a) (car b))
                                          (and (= (car a) (car b)) (> (nth 1 a) (nth 1 b)))))))
    (if (and limit (> (length out) limit)) (seq-take out limit) out)))

(defvar voice-match-exact-margin 0.10
  "The lead enough when the best matches every word both ways (score 1):
\"read elon musk\" is the book Elon Musk, not The Elon Musk Blog Series.")

(defun voice-match-decide (ranked)
  "What to do with RANKED (from `voice-match-rank'): act, pick or none."
  (let* ((best (car ranked)) (next (cadr ranked))
         (lead (and best next (- (car best) (car next)))))
    (cond ((null best) 'none)
          ((and (>= (nth 1 best) voice-match-act-score)
                (or (null next) (>= lead voice-match-act-margin)
                    (and (>= (nth 1 best) 0.99) (< (nth 1 next) 0.99)
                         (>= lead voice-match-exact-margin))))
           'act)
          ((>= (nth 1 best) voice-match-pick-score) 'pick)
          (t 'none))))

;;;; Plain strings

(defun voice-match-strings (strings query &optional limit)
  "Rank STRINGS for QUERY, as `voice-match-rank' does; the entries' :title
is the string.  For the few choices of a prompt."
  (voice-match-rank (voice-match-index (mapcar (lambda (s) (list :title s)) strings))
                    query limit))

(defun voice-match-mentioned (strings tokens)
  "The one of STRINGS whose every word is among TOKENS (stemmed words),
preferring the one with the most words; nil when none is, or two tie.
\"done deep work\" mentions \"done, deep work\" rather than \"done\"."
  (let (best best-n tie)
    (dolist (s strings)
      (let ((words (voice-match-tokens s t)))
        (when (and words
                   (cl-every (lambda (w) (>= (voice-match--best-sim w tokens) 0.85)) words))
          (let ((n (length words)))
            (cond ((or (null best-n) (> n best-n)) (setq best s best-n n tie nil))
                  ((= n best-n) (setq tie t)))))))
    (and best (not tie) best)))

(provide 'voice-match)
;;; voice-match.el ends here
