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

(defvar voice-match--forms (make-hash-table :test 'equal)
  "Word -> (SINGLE SKELETON DEVOICED), worked out once: commands repeat
the same few thousand words.")

(defun voice-match--forms (word)
  "WORD's sound forms: see `voice-match--single', `--skeleton', `--devoice'."
  (or (gethash word voice-match--forms)
      (let* ((single (replace-regexp-in-string "\\(.\\)\\1+" "\\1" word))
             (skeleton (if (string-empty-p single) single
                         (concat (substring single 0 1)
                                 (replace-regexp-in-string "[aeiouy]" "" (substring single 1)))))
             (devoiced (copy-sequence single)))
        (dotimes (i (length devoiced))
          (let ((c (assq (aref devoiced i) '((?d . ?t) (?b . ?p) (?g . ?k) (?v . ?f) (?z . ?s)))))
            (when c (aset devoiced i (cdr c)))))
        (when (> (hash-table-count voice-match--forms) 200000) (clrhash voice-match--forms))
        (puthash word (list single skeleton devoiced) voice-match--forms))))

(defun voice-match--single (word)
  "WORD with doubled letters single: \"ellen\" and \"elon\" sound alike."
  (nth 0 (voice-match--forms word)))

(defun voice-match--skeleton (word)
  "WORD's first letter and its later consonants: names sound alike by them."
  (nth 1 (voice-match--forms word)))

(defun voice-match--devoice (word)
  "WORD single, its voiced consonants unvoiced: recognisers swap d and t
\(\"dagging\" for \"tagging\"), b and p, g and k, v and f, z and s."
  (nth 2 (voice-match--forms word)))

(defvar voice-match--sims (make-hash-table :test 'equal)
  "(X . Y) -> `voice-match-sim', remembered: the same pairs come up for
every candidate.")

(defun voice-match-sim (x y)
  "How alike words X and Y are, 0 to 1."
  (let ((key (cons x y)))
    (or (gethash key voice-match--sims)
        (progn (when (> (hash-table-count voice-match--sims) 300000) (clrhash voice-match--sims))
               (puthash key (voice-match--sim x y) voice-match--sims)))))

(defun voice-match--sim (x y)
  "`voice-match-sim' worked out."
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

(defvar voice-match-related nil
  "Nil, or a function of two words giving how alike they are in meaning,
0 to 1: words for one thing in command names (voice-emacs.el binds it
while it ranks commands).  Task titles never use it.")

(defvar voice-match-expand nil
  "Nil, or a function giving the words related to a word: looked up too,
and lending their weight to a word no title has.")

(defun voice-match--whole-sim (x y)
  "How alike X and Y are as whole words, for words run together: as
`voice-match-sim', but one the start of the other is no likeness
\(\"switch\" is not \"switchdark\")."
  (let ((lx (length x)) (ly (length y)))
    (cond ((string= x y) 1.0)
          ((string= (voice-match--single x) (voice-match--single y)) 0.95)
          ((and (>= lx 4) (>= ly 4)
                (or (string= (voice-match--skeleton x) (voice-match--skeleton y))
                    (string= (voice-match--devoice x) (voice-match--devoice y))))
           0.9)
          ((and (>= lx 4) (>= ly 4))
           (let ((s (- 1.0 (/ (float (string-distance x y)) (max lx ly)))))
             (if (>= s 0.8) s 0.0)))
          (t 0.0))))

(defun voice-match--best-sim (word words)
  "The best `voice-match-sim' of WORD against WORDS (or, while
`voice-match-related' is set, of their meanings)."
  (let ((best 0.0))
    (while (and words (< best 0.999))
      (let ((w (pop words)))
        (setq best (max best (voice-match-sim word w)
                        (if voice-match-related (funcall voice-match-related word w) 0.0)))))
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
  "TOKEN's idf in INDEX.  One no title has weighs as the rarest, unless
`voice-match-expand' relates it to words titles have: then as the
rarest of those."
  (or (gethash token (voice-match-index-idf index))
      (and voice-match-expand
           (let ((known (delq nil (mapcar (lambda (x) (gethash x (voice-match-index-idf index)))
                                          (funcall voice-match-expand token)))))
             (and known (apply #'max known))))
      (voice-match-index-default-idf index)))

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
                 (sim (apply #'max 0.0 (mapcar (lambda (x) (if (>= (length x) 6) (voice-match--whole-sim x joined) 0.0))
                                               query))))
            (when (>= sim 0.85) (push (list sim i joined) out)))
          (setq ws (cdr ws) i (1+ i)))))
    out))

(defun voice-match--runs (query words)
  "Runs of two or three neighbouring QUERY words said for one long word of
WORDS: \"car io\" for acario.  Only words no word of WORDS is like on its
own, and no numbers (\"chapter 5\" is not \"chapter\").  Return (SIM WORD
. POSITIONS) for each."
  (let* ((v (vconcat query)) (n (length query))
         (loose (vconcat (mapcar (lambda (x) (and (not (string-match-p "[0-9]" x))
                                                  (< (voice-match--best-sim x words) 0.85)))
                                 query)))
         out)
    (when (cdr query)
      (dolist (y words)
        (when (>= (length y) 5)
          (dotimes (i n)
            (dolist (len '(2 3))
              (when (and (<= (+ i len) n)
                         (cl-loop for j from i below (+ i len) always (aref loose j)))
                (let ((sim (voice-match--whole-sim y (apply #'concat (append (seq-subseq v i (+ i len)) nil)))))
                  (when (>= sim 0.8)
                    (push (cons sim (cons y (number-sequence i (+ i len -1)))) out)))))))))
    out))

(defvar voice-match-title-share 0.25
  "How much of S is the title's words being said; the rest is what was
said being in the title.  Commands' names, where every word picks one
out, bind it higher.")

(defun voice-match--score-words (index query words extra)
  "S for QUERY tokens against a title's WORDS and its EXTRA tokens."
  (if (or (null query) (null words)) 0.0
    (let* ((num 0.0) (den 0.0) (num2 0.0) (den2 0.0)
           (joined (voice-match--joined query words))
           (joined-words (mapcar #'caddr joined))
           ;; Words said apart for one, only when some word said is
           ;; not in the title as it is.
           (runs (and (seq-some (lambda (x) (< (voice-match--best-sim x words) 0.85)) query)
                      (voice-match--runs query words)))
           (run-sim (lambda (pred) (apply #'max 0.0 (mapcar #'car (seq-filter pred runs))))))
      (let ((i 0))
        (dolist (x query)
          (let ((w (voice-match--weight index x)) (pos i))
            (cl-incf den w)
            (cl-incf num (* w (max (voice-match--best-sim x words)
                                   (if joined-words (voice-match--best-sim x joined-words) 0.0)
                                   (* 0.6 (voice-match--best-sim x extra))
                                   (if runs (funcall run-sim (lambda (r) (memq pos (cddr r)))) 0.0)))))
          (cl-incf i)))
      (let ((i 0))
        (dolist (y words)
          (let ((w (voice-match--weight index y))
                (pair (seq-find (lambda (j) (memq i (list (nth 1 j) (1+ (nth 1 j))))) joined)))
            (cl-incf den2 w)
            (cl-incf num2 (* w (max (voice-match--best-sim y query) (if pair (car pair) 0.0)
                                    (if runs (funcall run-sim (lambda (r) (equal (cadr r) y))) 0.0)))))
          (cl-incf i)))
      (min 1.0 (+ (* (- 1 voice-match-title-share) (/ num den)) (* voice-match-title-share (/ num2 den2))
                  (if (and (cdr query) (voice-match--in-order-p query words)) 0.05 0.0))))))

(defun voice-match--score (index query entry)
  "S for QUERY tokens against ENTRY: its title or its best alias."
  (let ((extra (plist-get entry :extra)))
    (apply #'max (voice-match--score-words index query (plist-get entry :words) extra)
           (mapcar (lambda (a) (voice-match--score-words index query a nil))
                   (plist-get entry :aliases)))))

(defvar voice-match-shortlist nil
  "Nil, or how many entries, the best by a rough score, are weighed in
full: for big indexes (every command).")

(defvar voice-match-common-key 300
  "A lookup key shared by more entries than this is too common to bring
in candidates alone.")

(defun voice-match-rank (index query &optional limit prior-fn)
  "Candidates of INDEX for QUERY (a string), best first, at most LIMIT.
Each result is (F S ENTRY): F is S plus the priors, given by ENTRY's
:prior, plus what PRIOR-FN returns for ENTRY if given; capped at
`voice-match-prior-cap', and only added when S is 0.5 or more."
  (let* ((query (if (stringp query) (voice-match-tokens query) query))
         (seen (make-hash-table))
         out)
    (dolist (x query)
      ;; A related word is looked up as itself only: its near sounds
      ;; would bring in half the index.  A key most entries share (mode,
      ;; among commands) brings in no one by itself, when the query has
      ;; other words: it still counts in the score.  Each entry found
      ;; gets a rough score, the idf of the words that found it.
      (let ((mine (make-hash-table)) (w (voice-match--idf index x)))
        (dolist (k (voice-match--keys x))
          (let ((hits (gethash k (voice-match-index-keys index))))
            (unless (and (cdr query) (> (length hits) voice-match-common-key))
              (dolist (i hits) (puthash i (max (gethash i mine 0) (if (equal k x) w (* 0.7 w))) mine)))))
        (dolist (k (and voice-match-expand (funcall voice-match-expand x)))
          (let ((hits (gethash k (voice-match-index-keys index))))
            (unless (and (cdr query) (> (length hits) voice-match-common-key))
              (dolist (i hits) (puthash i (max (gethash i mine 0) (* 0.8 w)) mine)))))
        (maphash (lambda (i v) (puthash i (+ v (gethash i seen 0)) seen)) mine)))
    ;; Only the best by that rough score are weighed in full.
    (when (and voice-match-shortlist (> (hash-table-count seen) voice-match-shortlist))
      (let (all)
        (maphash (lambda (i v) (push (cons v i) all)) seen)
        (setq all (seq-take (sort all (lambda (a b) (> (car a) (car b)))) voice-match-shortlist))
        (clrhash seen)
        (dolist (a all) (puthash (cdr a) t seen))))
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
