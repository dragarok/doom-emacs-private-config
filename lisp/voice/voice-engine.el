;;; voice-engine.el --- Voice: the speech engine, kept loaded, and your words -*- lexical-binding: t -*-

;;; Commentary:
;; What hears you: hear (~/.doom.d/voice-engine/), Phonon-2.5 in plain C,
;; kept loaded in a process Emacs starts and listening on a Unix socket.
;; Emacs Home's island streams the microphone to it (Hear.java), and it
;; answers with what was said and its other readings; Emacs picks the
;; reading it can act on (voice-app.el).
;;
;; It is pulled toward your words: every domain's :vocab (task names, the
;; phone's apps, the commands' jargon: magit, vertico, org roam), and from
;; voice.org its names, its * Hear list and every word * Sounds says was
;; misheard, written to a file the engine reads again whenever it changes.
;; Each utterance is saved with what was heard, in
;; `voice-engine-save-directory' (heard.tsv beside the WAVs): what a weekly
;; retraining learns from.
;;
;; Another model is another directory under `voice-engine-dir' named by
;; `voice-engine-model'; another engine is another program speaking the
;; same protocol (voice-engine/hear.c, the top comment).

;;; Code:

(require 'voice-core)
(require 'seq)
(require 'subr-x)

(defvar emacs-home-dir)
(defvar doom-user-dir)

(defvar voice-engine-dir
  (if voice--android "/data/data/com.termux/files/home/.local/share/hear/" "~/.local/share/hear/")
  "Where the engine's models and your words live.")

(defvar voice-engine-model "phonon-2.5"
  "The model: a directory under `voice-engine-dir' with weights.bin,
weights.json and tokens.txt.")

(defvar voice-engine-source
  (expand-file-name "voice-engine/" (or (bound-and-true-p doom-user-dir) "~/.doom.d/"))
  "The engine's source; `voice-engine-setup' builds hear here.")

(defvar voice-engine-program (expand-file-name "hear" voice-engine-source)
  "The engine.")

(defvar voice-engine-socket
  (if (and voice--android (bound-and-true-p emacs-home-dir))
      (expand-file-name "hear.sock" emacs-home-dir)
    (expand-file-name "hear.sock" voice-engine-dir))
  "Where it listens.  On the phone, beside Emacs Home's files: the island
looks for it there.")

(defvar voice-engine-threads 6
  "Threads for the engine: on the phone's eight cores, six were fastest.")

(defvar voice-engine-save-directory
  (if voice--android "/sdcard/Documents/voice-audio/heard/"
    (expand-file-name "heard/" voice-engine-dir))
  "Every utterance, as WAV, with heard.tsv: time, file, where from, what
was heard, other readings.  Private: never in the repo.")

(defvar voice-engine-vocab-max 4000
  "At most this many phrases go to the engine.")

(defvar voice-engine--process nil)
(defvar voice-engine--restarts nil "Times it restarted on its own, lately.")
(defvar voice-engine--vocab-time 0 "When the words were last written.")
(defvar voice-engine--timers nil "The timers this file set, so loading it again replaces them.")

(defun voice-engine--weights () (expand-file-name voice-engine-model voice-engine-dir))
(defun voice-engine--vocab-file () (expand-file-name "vocab.txt" voice-engine-dir))

(defun voice-engine-running-p ()
  "Non-nil when the engine runs."
  (process-live-p voice-engine--process))

(defun voice-engine-ready-p ()
  "Non-nil when the engine is built and its model is in place."
  (and (file-executable-p voice-engine-program)
       (file-exists-p (expand-file-name "weights.bin" (voice-engine--weights)))))

(defun voice-engine-stale-p ()
  "Non-nil when the engine was built before its source last changed: a
pull (\"update voice\") brought a new one, so it is built again."
  (and (file-exists-p voice-engine-program)
       (seq-some (lambda (f) (file-newer-than-file-p (expand-file-name f voice-engine-source)
                                                     voice-engine-program))
                 '("hear.c" "bias.c" "bias.h"))))

;;;; Your words

(defun voice-engine-vocabulary ()
  "What the engine is pulled toward: every domain's :vocab and the names
in voice.org, each once, short phrases with a letter in them."
  (let (all)
    (dolist (f (voice--domains :vocab))
      (setq all (append (with-demoted-errors "voice vocab: %S" (funcall f)) all)))
    (dolist (n (car (ignore-errors (voice--rules)))) (push (car n) all))
    ;; Voice's own phrases, word for word ("go back", "what can i say").
    (dolist (a (bound-and-true-p voice-actions))
      (dolist (p (plist-get a :phrases))
        (unless (string-match-p "…" p) (push p all))))
    (setq all (append (bound-and-true-p voice--hear-words)
                      (mapcar #'cdr (bound-and-true-p voice-sounds-like))
                      all))
    (seq-take
     (delete-dups
      (seq-filter (lambda (s) (and (string-match-p "[[:alpha:]]" s) (< (length s) 60)))
                  (mapcar (lambda (s) (string-trim (replace-regexp-in-string "[\t\n]+" " " s)))
                          (seq-filter #'stringp all))))
     voice-engine-vocab-max)))

(defun voice-engine-write-vocab ()
  "Write the words for the engine, if they changed; it reads them again."
  (interactive)
  (setq voice-engine--vocab-time (float-time))
  (let ((text (concat (string-join (voice-engine-vocabulary) "\n") "\n"))
        (file (voice-engine--vocab-file)))
    (unless (and (file-exists-p file)
                 (equal text (with-temp-buffer (insert-file-contents file) (buffer-string))))
      (make-directory (file-name-directory file) t)
      (write-region text nil file nil 'silent))
    file))

;;;; An open list: what you'll say next

(defvar voice-engine-list-max 300
  "At most this many of an open list's entries go to the engine.")

(defvar voice-engine-list-boost 4
  "How hard an open list's entries pull: while a list is open, its
entries are what is said next (the theme list: doom ayu light, not
\"down the book\").  Your other words pull with 3.")

(defun voice-engine--list-file () (expand-file-name "list.txt" voice-engine-dir))

(defun voice-engine--spoken (entry)
  "ENTRY as it is said: doom-ayu-light is doom ayu light, tasks.org
tasks dot org."
  (string-trim (replace-regexp-in-string
                "\\(?:[]~_/*:<>()[-]\\|\\. \\|\\.\\'\\| \\)+" " "
                (replace-regexp-in-string "\\([[:alnum:]]\\)\\.\\([[:alnum:]]\\)" "\\1 dot \\2" entry))))

(defun voice-engine--list-open ()
  "A list opened in the minibuffer: the engine is pulled toward its entries
until it closes.  Not M-x, Lisp or a shell command: voice answers none;
nor every symbol there is (describe-function): too many to say."
  (when (and (voice-engine-running-p) minibuffer-completion-table
             (not (obarrayp minibuffer-completion-table))
             (not (memq minibuffer-history-variable
                        '(extended-command-history read-expression-history shell-command-history))))
    (with-demoted-errors "voice engine list: %S"
      (let* ((all (all-completions "" minibuffer-completion-table minibuffer-completion-predicate))
             (lines (delete-dups
                     (seq-filter (lambda (s) (and (string-match-p "[[:alpha:]]" s) (< (length s) 60)))
                                 (mapcar #'voice-engine--spoken (seq-take all voice-engine-list-max))))))
        (write-region (mapconcat (lambda (l) (format "%s\t%s\n" l voice-engine-list-boost)) lines "")
                      nil (voice-engine--list-file) nil 'silent)))))

(defun voice-engine--list-closed ()
  "The list closed: its entries pull no more."
  (let ((f (voice-engine--list-file)))
    (when (and (<= (minibuffer-depth) 1) (file-exists-p f)
               (> (file-attribute-size (file-attributes f)) 0))
      (with-demoted-errors "voice engine list: %S" (write-region "" nil f nil 'silent)))))

(add-hook 'minibuffer-setup-hook #'voice-engine--list-open)
(add-hook 'minibuffer-exit-hook #'voice-engine--list-closed)

(defun voice-engine--refresh ()
  "Now and then, when Emacs is idle: the words again."
  (when (and (voice-engine-running-p) (> (- (float-time) voice-engine--vocab-time) 600))
    (voice-engine-write-vocab)))

;;;; The process

(defun voice-engine-start ()
  "Start the engine unless it runs.  The island asks for this when it
can't reach it, and keeps what you said meanwhile."
  (interactive)
  (cond
   ((voice-engine-running-p) 'running)
   ((not (voice-engine-ready-p))
    (message "Voice engine: not set up (M-x voice-engine-setup)") nil)
   (t
    (with-demoted-errors "voice engine vocab: %S" (voice-engine-write-vocab))
    (make-directory voice-engine-save-directory t)
    (let ((process-environment (cons (format "P25_THREADS=%d" voice-engine-threads)
                                     process-environment)))
      (setq voice-engine--process
            (make-process
             :name "hear" :buffer " *hear*" :noquery t :connection-type 'pipe
             :command (list (expand-file-name voice-engine-program) "serve"
                            (expand-file-name (voice-engine--weights))
                            (expand-file-name voice-engine-socket)
                            "--vocab" (concat (expand-file-name (voice-engine--vocab-file)) ","
                                              (expand-file-name (voice-engine--list-file)))
                            "--save" (directory-file-name (expand-file-name voice-engine-save-directory)))
             :sentinel #'voice-engine--sentinel)))
    'started)))

(defun voice-engine--sentinel (process _event)
  "Start it again if it died on its own: three times in five minutes at most."
  (unless (or (process-live-p process) (process-get process 'stopping))
    (setq voice-engine--restarts
          (cons (float-time) (seq-filter (lambda (t0) (< (- (float-time) t0) 300)) voice-engine--restarts)))
    (if (> (length voice-engine--restarts) 3)
        (message "Voice engine: stopped (see buffer \" *hear*\")")
      (run-at-time 2 nil #'voice-engine-start))))

(defun voice-engine-stop ()
  "Stop the engine.  Its socket goes too, so the island asks Emacs to
start it again rather than waiting on a dead one."
  (interactive)
  (when (voice-engine-running-p)
    (process-put voice-engine--process 'stopping t)
    (delete-process voice-engine--process))
  (setq voice-engine--process nil)
  (when (file-exists-p voice-engine-socket) (delete-file voice-engine-socket)))

(defun voice-engine-restart ()
  "Stop and start the engine: after a rebuild, or another model."
  (interactive)
  (voice-engine-stop)
  (voice-engine-start))

(defun voice-engine-setup ()
  "Build the engine and put its model in place (voice-engine/setup.sh),
then start it.  On the phone the model comes from /sdcard/Download/hear-model
when a Mac pushed it there, else it is downloaded (183 MB)."
  (interactive)
  (if (process-live-p (get-process "hear-setup"))
      (message "Voice engine: already setting up")
    (voice-engine--setup)))

(defun voice-engine--setup ()
  (let ((default-directory voice-engine-source)
        (process-environment (cons (concat "HEAR_DIR=" (expand-file-name voice-engine-dir))
                                   process-environment)))
    (make-process
     :name "hear-setup" :buffer (get-buffer-create "*voice-engine-setup*") :noquery t
     :command (list "sh" "setup.sh")
     :sentinel (lambda (p _e)
                 (unless (process-live-p p)
                   (if (and (zerop (process-exit-status p)) (voice-engine-ready-p))
                       (progn (message "Voice engine: ready") (voice-engine-restart))
                     (message "Voice engine: setup failed, see *voice-engine-setup*")))))
    (message "Voice engine: setting up…")))

(defun voice-engine-transcribe (file)
  "What the engine hears in FILE (a WAV), with its other readings."
  (interactive "fWAV: ")
  (unless (voice-engine-running-p) (voice-engine-start) (sleep-for 1))
  (let ((out (with-temp-buffer
               (call-process (expand-file-name voice-engine-program) nil t nil
                             "send" (expand-file-name voice-engine-socket)
                             (concat "FILE " (expand-file-name file)))
               (buffer-string))))
    (when (called-interactively-p 'any) (message "%s" (string-trim out)))
    out))

;; On the phone it runs from the start, so the island never waits for it;
;; the first time, it sets itself up when it can (a compiler in Termux, or
;; what a Mac pushed to /sdcard/Download/hear-model).  When a pull brought
;; a new engine (this file is loaded again by "update voice"), it is built
;; again and restarted.
(mapc #'cancel-timer voice-engine--timers)
(setq voice-engine--timers nil)
(when (and voice--android (not noninteractive))
  (setq voice-engine--timers
        (list (run-with-idle-timer
               4 nil (lambda ()
                       (let ((can-build (or (executable-find "cc")
                                            (file-exists-p "/sdcard/Download/hear-model/hear"))))
                         (cond ((and can-build (voice-engine-stale-p)) (voice-engine-setup))
                               ((voice-engine-ready-p) (voice-engine-start))
                               (can-build (voice-engine-setup))))))
              (run-with-idle-timer 30 t #'voice-engine--refresh))))

(provide 'voice-engine)
;;; voice-engine.el ends here
