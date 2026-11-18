;;; voice-keys-check.el --- Can every key be said?  -*- lexical-binding: t -*-

;;; Commentary:
;; Every key binding, in the order they matter, said as you would say it,
;; through voice's planner (nothing is run): does voice do what the key does?
;;
;;   1. yours: what config.el and lisp/*.el bind (map!, define-key,
;;      global-set-key, keymap-set, evil-define-key), read from the source;
;;   2. Doom's leader (SPC), from the live keymap, by what which-key says;
;;   3. the rest: global keys, evil's states, and each major mode's own keys
;;      and local leader.
;;
;; Each binding is said by its label (what which-key shows; a note in
;; brackets unsaid unless another key's label is then the same), with its
;; group when another binding has the same label or it is one word, else
;; by its command's name.  A mode's keys are said with that mode in front.  Load it in an Emacs running
;; your config, then
;;
;;   (voice-keys-check "~/somewhere/")           ; all three tiers
;;   (voice-keys-check "~/somewhere/" '(1 2))    ; only yours and the leader
;;
;; It works through them on a timer, so Emacs stays usable, and writes
;; keys.tsv (one row per phrase) and summary.txt when done.  Outcomes:
;;   act      voice does it
;;   ask      voice asks "did you mean" it
;;   wrong    voice would do something else
;;   ask-else voice asks about something else
;;   pick     voice shows a list to pick from
;;   none     voice doesn't take it as anything
;;   unnamed  the key runs a lambda or a macro: voice can't name it
;;   absent   its command isn't defined in this Emacs (a package not loaded)
;;   own      a phrase of voice's own, said word for word, takes it ("help")
;;   named    the phrase is another command's own name, which runs instead
;;   elsewhere bound only where a condition holds that doesn't here (IS-ANDROID)
;;   shadowed another binding took the keys: a conflict in the config
;;   task     the phrase is one of your tasks' names, which voice clocks into
;;   key-label the phrase is what a leader key calls another command, which runs
;;   key-only a command that is only a key's (a digit of a count, typing, macOS's ns-)

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)

(declare-function voice-plan "voice-plan")
(declare-function voice--rewrite "voice-rules")
(declare-function voice-emacs-catalog "voice-emacs")

;;;; Yours, read from the source

(defvar voice-keys-config-files
  (lambda ()
    (let ((dir (or (bound-and-true-p doom-user-dir) "~/.doom.d/")))
      (cons (expand-file-name "config.el" dir)
            (directory-files (expand-file-name "lisp" dir) t "\\`[^.].*\\.el\\'"))))
  "The files whose bindings are yours: a list, or a function giving one.")

(defun voice-keys--forms (file)
  "Every top-level form in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (forms)
      (condition-case nil
          (while t (push (read (current-buffer)) forms))
        (error nil))
      (nreverse forms))))

(defun voice-keys--key (k)
  "K, a key in source (a string, (kbd S), a vector), as a string, or nil."
  (cond ((stringp k) k)
        ((and (consp k) (memq (car k) '(kbd key-description)) (stringp (cadr k))) (cadr k))
        ((vectorp k) (ignore-errors (key-description k)))))

(defun voice-keys--def (d)
  "D, a definition in source, as (KIND . VALUE): (cmd . SYMBOL), (lambda .
FORM), (macro . STRING), (map . SYMBOL), or nil."
  (pcase d
    (`(function ,(and s (pred symbolp))) (and s (cons 'cmd s)))
    (`(quote ,(and s (pred symbolp))) (and s (cons 'cmd s)))
    (`(function (lambda . ,_)) (cons 'lambda d))
    (`(lambda . ,_) (cons 'lambda d))
    (`(,(or 'cmd! 'cmd!! 'cmds! 'interactive!) . ,_) (cons 'lambda d))
    ((pred stringp) (cons 'macro d))
    ((and (pred symbolp) (guard (and d (string-suffix-p "-map" (symbol-name d))))) (cons 'map d))))

(defconst voice-keys--states
  (mapcar (lambda (s) (intern (concat ":" s)))
          '("n" "v" "i" "e" "o" "m" "r" "g" "nv" "nm" "nvm" "mn" "vn" "ni" "nvi" "nmv" "mv" "iv" "ie" "nve" "nvo")))

(defvar voice-keys--off nil
  "The condition, false in this Emacs, the forms being read are under:
their bindings are made elsewhere (the phone), not here.")

(defun voice-keys--holds (c)
  "Whether condition C holds in this Emacs: t, nil, or `unknown' -- read
without running anything but variables, features and the system's kind."
  (pcase c
    ('t t) ('nil nil)
    ((pred symbolp) (if (boundp c) (and (symbol-value c) t) 'unknown))
    (`(not ,x) (let ((v (voice-keys--holds x))) (if (eq v 'unknown) v (not v))))
    (`(and . ,xs) (let ((vs (mapcar #'voice-keys--holds xs)))
                    (cond ((memq nil vs) nil) ((memq 'unknown vs) 'unknown) (t t))))
    (`(or . ,xs) (let ((vs (mapcar #'voice-keys--holds xs)))
                   (cond ((memq t vs) t) ((memq 'unknown vs) 'unknown) (t nil))))
    (`(,(or 'featurep 'display-graphic-p 'modulep! 'eq 'memq) . ,_)
     (if (or (memq (car c) '(featurep display-graphic-p modulep!))
             (eq (nth 1 c) 'system-type))
         (condition-case nil (and (eval c t) t) (error 'unknown))
       'unknown))
    (_ 'unknown)))

(defun voice-keys--map! (args file emit &optional ctx)
  "Read map! ARGS (Doom's), calling EMIT with each binding found.  CTX:
(:prefix KEYS :leader BOOL :localleader BOOL :map MAPS :group DESC :states S)."
  (let ((ctx (copy-sequence ctx)) desc)
    (while args
      (let ((a (pop args)))
        (cond
         ((memq a '(:leader :localleader))
          (setq ctx (plist-put ctx a t)))
         ((memq a '(:map :map*))
          (let ((m (pop args)))
            (setq ctx (plist-put ctx :map (if (listp m) m (list m))))))
         ((memq a '(:prefix :prefix-map))
          (let* ((p (pop args)) (key (if (consp p) (car p) p)) (d (and (consp p) (cdr p))))
            (setq ctx (plist-put ctx :prefix (append (plist-get ctx :prefix) (list (voice-keys--key key)))))
            (when (stringp d) (setq ctx (plist-put ctx :group d)))))
         ((eq a :desc) (setq desc (pop args)))
         ((memq a '(:when :unless))
          (let* ((c (pop args)) (v (voice-keys--holds c)))
            (when (eq v (eq a :unless)) (setq ctx (plist-put ctx :off c)))))
         ((memq a '(:after :mode :textobj)) (pop args))
         ((memq a voice-keys--states) (setq ctx (plist-put ctx :states a)))
         ((keywordp a) nil)
         ;; A nested block: (:prefix ...), (:map ...), (:when C ...).
         ((and (consp a) (keywordp (car a)))
          (voice-keys--map! a file emit ctx))
         (t
          (let ((key (voice-keys--key a)) (def (voice-keys--def (pop args))))
            (when (and key def)
              (funcall emit (list :keys (string-join (append (cond ((plist-get ctx :leader) '("SPC"))
                                                                  ((plist-get ctx :localleader) '(",")))
                                                            (delq nil (plist-get ctx :prefix))
                                                            (list key))
                                                     " ")
                                  :def def :desc (and (stringp desc) desc)
                                  :group (plist-get ctx :group)
                                  :map (plist-get ctx :map) :states (plist-get ctx :states)
                                  :leader (plist-get ctx :leader) :localleader (plist-get ctx :localleader)
                                  :off (or (plist-get ctx :off) voice-keys--off)
                                  :file (file-name-nondirectory file))))
            (setq desc nil))))))))

(defun voice-keys--scan (form file emit)
  "Find the binding forms anywhere in FORM; EMIT each binding."
  (when (consp form)
    (let ((head (car form)))
      (pcase head
        ('map! (voice-keys--map! (cdr form) file emit))
        ((or 'define-key 'keymap-set 'evil-define-key 'evil-define-key*)
         (let* ((args (cdr form))
                (args (if (memq head '(evil-define-key evil-define-key*)) (cdr args) args))
                (map (car args)))
           (setq args (cdr args))
           (while (cdr args)
             (let ((key (voice-keys--key (pop args))) (def (voice-keys--def (pop args))))
               (when (and key def)
                 (funcall emit (list :keys key :def def
                                     :map (list (if (eq (car-safe map) 'quote) (cadr map) map))
                                     :off voice-keys--off
                                     :file (file-name-nondirectory file))))))))
        ((or 'global-set-key 'keymap-global-set)
         (let ((key (voice-keys--key (nth 1 form))) (def (voice-keys--def (nth 2 form))))
           (when (and key def)
             (funcall emit (list :keys key :def def :map '(global-map) :off voice-keys--off
                                 :file (file-name-nondirectory file))))))
        (_ nil))
      (cond
       ((eq head 'quote) nil)
       ;; Under a condition false here: bound elsewhere (IS-ANDROID).
       ((and (memq head '(when unless if)) (consp (cdr form)))
        (let* ((v (voice-keys--holds (nth 1 form)))
               (off-then (if (eq head 'unless) (eq v t) (null v)))
               (off-else (eq v t)))
          (let ((voice-keys--off (or voice-keys--off (and off-then (nth 1 form)))))
            (if (eq head 'if)
                (voice-keys--scan (nth 2 form) file emit)
              (dolist (f (nthcdr 2 form)) (voice-keys--scan f file emit))))
          (when (eq head 'if)
            (let ((voice-keys--off (or voice-keys--off (and off-else (list 'not (nth 1 form))))))
              (dolist (f (nthcdr 3 form)) (voice-keys--scan f file emit))))))
       (t
        (let ((rest form))
          (while (consp rest)
            (voice-keys--scan (car rest) file emit)
            (setq rest (cdr rest)))))))))

(defun voice-keys-yours ()
  "Your bindings, read from `voice-keys-config-files': plists."
  (let (out)
    (dolist (f (if (functionp voice-keys-config-files) (funcall voice-keys-config-files)
                 voice-keys-config-files))
      (dolist (form (voice-keys--forms f))
        (voice-keys--scan form f (lambda (b) (push (plist-put b :tier 1) out)))))
    (nreverse out)))

;;;; From the live keymaps

(defun voice-keys--walk (map fn &optional keys group seen depth)
  "Call FN with (KEYS CMD LABEL GROUP) for each command under MAP: KEYS a
string, LABEL what which-key shows (a description), GROUP its prefix's."
  (let ((seen (or seen (make-hash-table :test 'eq))) (depth (or depth 0)))
    (unless (or (> depth 6) (gethash map seen))
      (puthash map t seen)
      (map-keymap
       (lambda (ev def)
         (let (label)
           (when (and (consp def) (stringp (car def)))
             (setq label (car def) def (cdr def))
             (when (and (consp def) (stringp (car def))) (setq def (cdr def))))
           (when (eq (car-safe def) 'menu-item)
             (setq label (nth 1 def) def (nth 2 def)))
           (let ((k (string-trim (concat (or keys "") " " (single-key-description ev)))))
             (cond ((and def (symbolp def) (commandp def) (not (keymapp def)))
                    (funcall fn k def (and (stringp label) label) group))
                   ((and def (not (symbolp def)) (commandp def) (not (keymapp def)))
                    (funcall fn k 'lambda (and (stringp label) label) group))
                   ((and (keymapp def) (not (and (symbolp def) (autoloadp (indirect-function def)))))
                    (voice-keys--walk (if (symbolp def) (indirect-function def) def) fn k
                                      (if (stringp label) label group) seen (1+ depth)))))))
       map))))

(defun voice-keys-leader ()
  "Doom's leader bindings: plists."
  (let (out)
    (when (and (boundp 'doom-leader-map) (keymapp doom-leader-map))
      (voice-keys--walk doom-leader-map
                        (lambda (k cmd label group)
                          (push (list :tier 2 :keys (concat "SPC " k)
                                      :def (if (eq cmd 'lambda) (cons 'lambda nil) (cons 'cmd cmd))
                                      :desc label :group group :leader t)
                                out))))
    (nreverse out)))

(defvar voice-keys-modes
  '(org-mode emacs-lisp-mode dired-mode magit-status-mode org-agenda-mode markdown-mode
    image-mode ibuffer-mode help-mode helpful-mode prog-mode text-mode)
  "Major modes whose own keys tier 3 says, with the mode in front.")

(defun voice-keys--mode-map (mode)
  (let ((v (intern-soft (format "%s-map" mode))))
    (and v (boundp v) (keymapp (symbol-value v)) (symbol-value v))))

(defun voice-keys-rest ()
  "Global keys, evil's states, and `voice-keys-modes' own keys: plists."
  (let (out)
    (dolist (spec (append (list (list 'global-map nil) (list 'evil-normal-state-map nil)
                                (list 'evil-motion-state-map nil) (list 'evil-window-map nil))
                          (mapcar (lambda (m) (list (intern (format "%s-map" m)) m)) voice-keys-modes)))
      (let* ((var (car spec)) (mode (cadr spec))
             (map (and (boundp var) (symbol-value var))))
        (when (keymapp map)
          (voice-keys--walk map
                            (lambda (k cmd label group)
                              (unless (string-match-p "mouse\\|<menu-bar>\\|<tool-bar>\\|wheel" k)
                                (push (list :tier 3 :keys k :def (if (eq cmd 'lambda) (cons 'lambda nil)
                                                                   (cons 'cmd cmd))
                                            :desc label :group group :map (list var) :mode mode)
                                      out)))))))
    (nreverse out)))

;;;; Saying them

(defun voice-keys--clean (s)
  "S as words: no +, …, brackets or punctuation."
  (let ((s (replace-regexp-in-string "[^[:alnum:]' ]+" " " (or s ""))))
    (string-trim (replace-regexp-in-string " +" " " (downcase s)))))

(defun voice-keys--name-words (cmd)
  (voice-keys--clean (replace-regexp-in-string "\\`\\(?:[+]+\\|my[/-]\\|doom/\\|\\+\\)" ""
                                               (symbol-name cmd))))

(defun voice-keys--mode-of (b)
  "The major mode B's keys belong to, or nil for anywhere."
  (or (plist-get b :mode)
      (let ((m (car (plist-get b :map))))
        (and (symbolp m) m (not (memq m '(global-map evil-normal-state-map evil-motion-state-map
                                                     evil-visual-state-map evil-window-map override-global-map
                                                     doom-leader-map)))
             (let ((name (string-remove-suffix "-map" (symbol-name m))))
               (and (string-suffix-p "-mode" name) (intern name)))))))

(defun voice-keys--phrases (bindings)
  "BINDINGS with :phrase: the label, its group's words added when another
binding has the same label; else the command's name.  One per command and
phrase; a binding of a lambda or macro gets :unnamed."
  (let ((count (make-hash-table :test 'equal)) out seen)
    ;; A mouse's keys are no words.
    (setq bindings (seq-remove (lambda (b) (string-match-p "mouse\\|wheel" (or (plist-get b :keys) ""))) bindings))
    ;; A label is said without its note ("add project"), unless that is
    ;; another key's label too ("open repl" and "open repl (same window)").
    (let ((plains (make-hash-table :test 'equal)))
      (dolist (b bindings)
        (let ((raw (voice-keys--clean (plist-get b :desc))))
          (unless (string-empty-p raw)
            (cl-pushnew raw (gethash (voice-keys--clean (voice-emacs--label-name (plist-get b :desc))) plains)
                        :test #'equal))))
      (setq bindings
            (mapcar (lambda (b)
                      (let ((desc (plist-get b :desc)))
                        (if (and desc (null (cdr (gethash (voice-keys--clean (voice-emacs--label-name desc)) plains))))
                            (plist-put (copy-sequence b) :desc (voice-emacs--label-name desc))
                          b)))
                    bindings)))
    (dolist (b bindings)
      (let ((d (voice-keys--clean (plist-get b :desc))))
        (unless (string-empty-p d)
          (puthash d (cons (cdr (plist-get b :def)) (gethash d count)) count))))
    (dolist (b bindings (nreverse out))
      ;; A leader key's lambda has a name voice gives it (voice-emacs--key-command).
      (when (and (eq (car (plist-get b :def)) 'lambda) (plist-get b :desc))
        ;; A mode's lambdas are named when its keys are walked.
        (let ((mode (voice-keys--mode-of b)))
          (when (and mode (symbolp mode)) (ignore-errors (voice-keys--here mode))))
        (let ((sym (voice-keys--key-command (plist-get b :keys) (plist-get b :desc))))
          (when sym (setq b (plist-put (copy-sequence b) :def (cons 'cmd sym))))))
      (let* ((def (plist-get b :def))
             (d (voice-keys--clean (plist-get b :desc)))
             (g (voice-keys--clean (plist-get b :group)))
             (clash (and (not (string-empty-p d))
                         (> (length (delete-dups (copy-sequence (gethash d count)))) 1)))
             ;; Said with its group when the label alone is another's too, or
             ;; one word ("one" under markdown's header: "header one").
             (phrase (cond ((not (string-empty-p d))
                            (if (and (or clash (not (string-match-p " " d))) (not (string-empty-p g)))
                                (voice-keys--with-group d g) d))
                           ((eq (car def) 'cmd) (voice-keys--name-words (cdr def)))))
             (key (list (cdr def) phrase (voice-keys--mode-of b))))
        (when (and phrase (not (string-empty-p phrase)) (not (member key seen)))
          (push key seen)
          (push (append (list :phrase phrase :unnamed (not (eq (car def) 'cmd))) b) out))))))

;;;; Checking

(defun voice-keys--with-group (label group)
  "LABEL said with the words of GROUP it lacks, those first: \"org agenda\"
for Agenda under org agenda, \"header one\" for One under header."
  (let* ((have (voice-match-tokens label t))
         (more (seq-remove (lambda (w) (member (voice-match-stem w) have)) (voice-match-words group))))
    (string-join (append more (list label)) " ")))

(defun voice-keys--key-only-p (cmd)
  "Non-nil for a command that is only a key's: a count's digit, typing a
character, nothing."
  (and (symbolp cmd)
       (or (memq cmd '(digit-argument negative-argument self-insert-command ignore undefined
                       universal-argument))
           (string-match-p "digit-argument\\|-self-insert\\|\\`ns-" (symbol-name cmd)))))

(defun voice-keys--shadowed (b)
  "What runs instead under B's leader keys, when another binding took them."
  (let ((keys (plist-get b :keys)) (want (cdr (plist-get b :def))))
    (when (and (plist-get b :leader) (symbolp want) (string-prefix-p "SPC " keys)
               (boundp 'doom-leader-map))
      (let ((live (ignore-errors (lookup-key doom-leader-map (kbd (substring keys 4))))))
        (when (and (consp live) (stringp (car live))) (setq live (cdr live)))
        (when (eq (car-safe live) 'menu-item) (setq live (nth 2 live)))
        (and live (not (numberp live)) (not (keymapp live))
             (not (voice-keys--same-p want live))
             live)))))

(defun voice-keys--same-p (a b)
  "Non-nil when commands A and B do the same: one, an alias, a remap, the
same function (a key's lambda and the phrase that runs it)."
  (let ((fa (if (symbolp a) (ignore-errors (indirect-function a)) a))
        (fb (if (symbolp b) (ignore-errors (indirect-function b)) b)))
    (and a b
         (or (eq a b)
             (and (symbolp a) (symbolp b)
                  (or (eq (command-remapping a) b) (eq (command-remapping b) a)))
             (and fa (not (autoloadp fa)) (or (eq fa fb) (and (not (symbolp fa)) (equal fa fb))))))))

(defun voice-keys--key-command (keys desc)
  "The name voice gave the lambda under KEYS called DESC
\(voice-emacs--key-command): voice-key/SPC_o_v_w; under a mode's map, one
ending so (\"<normal-state> , z\") with that label."
  (let* ((tail (string-replace " " "_" (or (ignore-errors (key-description (kbd keys))) keys)))
         (exact (intern-soft (concat "voice-key/" tail))))
    (if (and exact (fboundp exact)) exact
      (let (found)
        (mapatoms (lambda (s)
                    (when (and (not found) (fboundp s)
                               (string-prefix-p "voice-key/" (symbol-name s))
                               (string-suffix-p (concat "_" tail) (symbol-name s))
                               (equal (get s 'voice-label) (and desc (voice-emacs--label-name desc))))
                      (setq found s))))
        found))))

(defun voice-keys--plan-cmd (plan)
  (let ((a (plist-get plan :action)))
    (and a (plist-get a :run))))

(defun voice-keys--modes (mode)
  (let (modes (m mode))
    (while m (push m modes) (setq m (get m 'derived-mode-parent)))
    modes))

(defvar voice-keys--here-memo (make-hash-table :test 'eq))

(defun voice-keys--here (mode)
  "The commands MODE's map binds, as voice-emacs-here gives them (once a run)."
  (or (gethash mode voice-keys--here-memo)
      (puthash mode (voice-emacs--here-of (list (voice-keys--mode-map mode))) voice-keys--here-memo)))

(defvar voice--choice)
(defvar voice--confirm)

(defun voice-keys--plan (phrase mode)
  "The plan for PHRASE, said from the island, or with MODE in front; as
if no question were open (a prompt left open in this Emacs would take
every phrase as its answer)."
  (let* ((real (symbol-function 'voice-context))
         (flags (remq 'minibuffer (funcall real "island")))
         (modes (and mode (voice-keys--modes mode)))
         (here (if mode (voice-keys--here mode) (make-hash-table :test 'eq)))
         (voice--choice nil) (voice--confirm nil))
    (cl-letf (((symbol-function 'voice-context) (lambda (&optional _source) (append modes flags)))
              ((symbol-function 'voice-emacs-here) (lambda () here)))
      (let* ((source (if mode "typed" "island"))
             (plan (voice-plan (voice--rewrite phrase) source)))
        ;; "run …": the command it would run, as voice-run-command chooses.
        (if (eq (voice-keys--plan-cmd plan) 'voice-run-command)
            (let ((top (voice--command-choice (voice--command-options-for (plist-get plan :slot) source))))
              (plist-put plan :runs (if top (plist-get (nth 1 top) :run) 'pick)))
          plan)))))

(defun voice-keys--outcome (b plan)
  "B's outcome under PLAN: (OUTCOME GOT SCORE)."
  (let* ((want (cdr (plist-get b :def)))
         (kind (plist-get plan :kind))
         (runs (plist-get plan :runs))
         (got (if (and runs (not (eq runs 'pick))) runs (voice-keys--plan-cmd plan)))
         (own (and (eq kind 'action) (not (plist-get (plist-get plan :action) :command))
                   (string-empty-p (or (plist-get plan :slot) ""))))
         (opt (and (eq kind 'ask) (plist-get (nth 1 (car (plist-get plan :options))) :run)))
         (score (or (plist-get plan :near-score)
                    (and (eq kind 'ask) (car (car (plist-get plan :options))))))
         (shown (plist-get plan :ranked)))
    (list (cond ((plist-get b :off) "elsewhere")
                ((voice-keys--key-only-p want) "key-only")
                ((voice-keys--shadowed b) "shadowed")
                ((plist-get b :unnamed) "unnamed")
                ((not (commandp want)) "absent")
                ((eq runs 'pick) "pick")
                ((and (eq kind 'action) (voice-keys--same-p want got)) "act")
                ;; A phrase of voice's own, word for word ("help": voice's help).
                ((and own (not runs)) "own")
                ;; The phrase is another command's own name ("describe
                ;; package" for doom/describe-package): that one it runs.
                ((and (eq kind 'action) (symbolp got) got
                      (equal (voice-match-tokens (plist-get b :phrase))
                             (voice-match-tokens (voice-emacs--name-words got))))
                 "named")
                ;; What a leader key calls another command ("save buffer",
                ;; SPC b s): the key you see runs.
                ((and (eq kind 'action) (memq (plist-get (plist-get plan :action) :exact) '(key label plain here)))
                 "key-label")
                ((eq kind 'action) "wrong")
                ((eq kind 'ask) (if (voice-keys--same-p want opt) "ask" "ask-else"))
                ((eq kind 'task) "task")
                ((or (eq kind 'none) (null kind)) "none")
                (t "pick"))
          (or got opt (and shown (plist-get (nth 2 (car shown)) :title)) (and kind (symbol-name kind)))
          score)))

(defvar voice-keys--job nil)

(defun voice-keys--row (b outcome)
  (mapconcat (lambda (x) (replace-regexp-in-string "[\t\n]" " " (format "%s" (or x ""))))
             (list (plist-get b :tier) (nth 0 outcome) (plist-get b :phrase) (cdr (plist-get b :def))
                   (nth 1 outcome) (and (nth 2 outcome) (format "%.2f" (nth 2 outcome)))
                   (plist-get b :keys) (voice-keys--mode-of b) (plist-get b :desc) (plist-get b :group)
                   (plist-get b :file))
             "\t"))

(defun voice-keys--summary (rows)
  "Counts per tier and outcome, as text."
  (let ((tiers (make-hash-table :test 'equal)))
    (dolist (r rows)
      (let* ((f (split-string r "\t")) (tier (nth 0 f)) (o (nth 1 f))
             (h (or (gethash tier tiers) (puthash tier (make-hash-table :test 'equal) tiers))))
        (puthash o (1+ (gethash o h 0)) h)
        (puthash "all" (1+ (gethash "all" h 0)) h)))
    (mapconcat
     (lambda (tier)
       (let ((h (gethash tier tiers)))
         (if (not h) ""
           (let ((all (gethash "all" h 0)))
             (format "tier %s (%s): %d phrases\n%s" tier
                     (pcase tier ("1" "yours") ("2" "Doom's leader") (_ "the rest"))
                     all
                     (mapconcat (lambda (o) (let ((n (gethash o h 0)))
                                              (format "  %-9s %4d  %5.1f%%" o n (/ (* 100.0 n) (max 1 all)))))
                                '("act" "own" "named" "key-label" "task" "ask" "wrong" "ask-else" "pick" "none" "unnamed" "absent" "elsewhere" "shadowed" "key-only") "\n"))))))
     '("1" "2" "3") "\n\n")))

(defun voice-keys-check (dir &optional tiers)
  "Say every binding of TIERS (default 1 2 3) to voice's planner, on a
timer; write DIR/keys.tsv and DIR/summary.txt."
  (clrhash voice-keys--here-memo)
  (let* ((tiers (or tiers '(1 2 3)))
         (bindings (append (and (memq 1 tiers) (voice-keys-yours))
                           (and (memq 2 tiers) (voice-keys-leader))
                           (and (memq 3 tiers) (voice-keys-rest))))
         (todo (voice-keys--phrases bindings))
         (dir (file-name-as-directory (expand-file-name dir))))
    (make-directory dir t)
    (voice-emacs-catalog)
    (when (timerp (car voice-keys--job)) (cancel-timer (car voice-keys--job)))
    (with-temp-file (concat dir "progress") (insert (format "0 %d\n" (length todo))))
    (setq voice-keys--job (list nil todo nil dir 0 (length todo)))
    (setcar voice-keys--job (run-with-timer 0.05 0.05 #'voice-keys--step))
    (format "Checking %d phrases into %s" (length todo) dir)))

(defun voice-keys--step ()
  "Check the next few phrases; finish when none are left."
  (pcase-let ((`(,timer ,todo ,rows ,dir ,done ,all) voice-keys--job)
              (t0 (float-time)))
    (while (and todo (< (- (float-time) t0) 0.4))
      (let* ((b (pop todo))
             (plan (if (or (plist-get b :off) (plist-get b :unnamed) (not (commandp (cdr (plist-get b :def))))) nil
                     (condition-case err (voice-keys--plan (plist-get b :phrase) (voice-keys--mode-of b))
                       (error (list :kind 'error :text (error-message-string err)))))))
        (push (voice-keys--row b (voice-keys--outcome b plan)) rows)
        (cl-incf done)))
    (setq voice-keys--job (list timer todo rows dir done all))
    (with-temp-file (concat dir "progress") (insert (format "%d %d\n" done all)))
    (unless todo
      (cancel-timer timer)
      (setq rows (nreverse rows))
      (with-temp-file (concat dir "keys.tsv")
        (insert "tier\toutcome\tphrase\twant\tgot\tscore\tkeys\tmode\tdesc\tgroup\tfile\n"
                (mapconcat #'identity rows "\n") "\n"))
      (with-temp-file (concat dir "summary.txt") (insert (voice-keys--summary rows) "\n"))
      (with-temp-file (concat dir "progress") (insert (format "done %d\n" all)))
      (setq voice-keys--job nil))))

;;;; Said naturally

(defconst voice-keys-natural
  '(("next line" (next-line evil-next-line evil-next-visual-line))
    ("down 5" (next-line evil-next-line evil-next-visual-line) nil 5)
    ("down five lines" (next-line evil-next-line evil-next-visual-line) nil 5)
    ("up 10" (previous-line evil-previous-line evil-previous-visual-line) nil 10)
    ("go to line 42" (goto-line evil-goto-line consult-goto-line) nil 42)
    ("beginning of buffer" (beginning-of-buffer evil-goto-first-line))
    ("top of buffer" (beginning-of-buffer evil-goto-first-line))
    ("end of buffer" (end-of-buffer evil-goto-line))
    ("bottom of the file" (end-of-buffer evil-goto-line))
    ("page down" (scroll-up-command evil-scroll-page-down))
    ("page up" (scroll-down-command evil-scroll-page-up))
    ("scroll down" (scroll-up-command evil-scroll-down evil-scroll-page-down))
    ("scroll up" (scroll-down-command evil-scroll-up evil-scroll-page-up))
    ("forward word" (forward-word evil-forward-word-begin))
    ("back three words" (backward-word evil-backward-word-begin) nil 3)
    ("end of line" (end-of-line move-end-of-line evil-end-of-line))
    ("beginning of line" (beginning-of-line move-beginning-of-line evil-beginning-of-line))
    ("other window" (other-window evil-window-next))
    ("split window right" (split-window-right evil-window-vsplit +evil/window-vsplit-and-follow))
    ("split window below" (split-window-below evil-window-split +evil/window-split-and-follow))
    ("window left" (evil-window-left windmove-left rift-window-left))
    ("window right" (evil-window-right windmove-right rift-window-right))
    ("close window" (delete-window evil-window-delete quit-window +workspace/close-window-or-workspace))
    ("delete other windows" (delete-other-windows doom/window-maximize-buffer))
    ("maximize window" (maximize-window doom/window-maximize-buffer))
    ("switch buffer" (switch-to-buffer consult-buffer +vertico/switch-workspace-buffer persp-switch-to-buffer voice-switch-buffer))
    ("previous buffer" (previous-buffer evil-prev-buffer))
    ("next buffer" (next-buffer evil-next-buffer))
    ("undo" (undo evil-undo undo-fu-only-undo voice-undo))
    ("redo" (undo-redo evil-redo undo-fu-only-redo))
    ("find file" (find-file))
    ("save file" (save-buffer basic-save-buffer))
    ("kill this buffer" (kill-current-buffer kill-this-buffer))
    ("jump to definition" (+lookup/definition evil-goto-definition xref-find-definitions))
    ("next heading" (outline-next-heading org-next-visible-heading) org-mode)
    ("previous heading" (outline-previous-heading org-previous-visible-heading) org-mode)
    ("select all" (mark-whole-buffer))
    ("delete line" (evil-delete-line kill-whole-line))
    ("comment line" (comment-line evilnc-comment-or-uncomment-lines))
    ("repeat" (repeat)))
  "Everyday ways of moving about, as said: (PHRASE COMMANDS [MODE COUNT]),
COMMANDS any of which is right, MODE the buffer in front (else Emacs
Lisp), COUNT the number it should run with.  Not phrases voice knows:
what it is measured on.")

(defun voice-keys-natural-check (&optional dir)
  "Plan each of `voice-keys-natural'; a table of what each would do, and
how many are right.  With DIR, write it to DIR/natural.tsv too."
  (let ((right 0) rows)
    (dolist (n voice-keys-natural)
      (let* ((plan (voice-keys--plan (car n) (or (nth 2 n) 'emacs-lisp-mode)))
             (a (plist-get plan :action))
             (got (or (and (plist-get plan :runs) (not (eq (plist-get plan :runs) 'pick)) (plist-get plan :runs))
                      (and (eq (plist-get plan :kind) 'action) (plist-get a :run))))
             (count (plist-get a :value))
             (ok (and got (seq-some (lambda (c) (voice-keys--same-p c got)) (nth 1 n))
                      (or (null (nth 3 n)) (eql count (nth 3 n))))))
        (when ok (cl-incf right))
        (push (format "%s\t%s\t%s\t%s\t%s" (if ok "ok" "no") (car n) (plist-get plan :kind)
                      (or got (mapconcat (lambda (o) (format "%s" (plist-get (nth 1 o) :run)))
                                         (seq-take (plist-get plan :options) 3) ","))
                      (or count ""))
              rows)))
    (let ((text (concat (format "%d of %d right\n" right (length voice-keys-natural))
                        (string-join (nreverse rows) "\n") "\n")))
      (when dir (with-temp-file (expand-file-name "natural.tsv" dir) (insert text)))
      text)))

(provide 'voice-keys-check)
;;; voice-keys-check.el ends here
