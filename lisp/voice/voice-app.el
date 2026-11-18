;;; voice-app.el --- Voice: where words come in, and updating itself -*- lexical-binding: t -*-

;;; Commentary:
;; Typed (SPC V), or from the phone's voice app through Emacs Home.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--fill)
(defvar voice-log-file)

;;;; Entry points

(defun voice-command (text)
  "Do what TEXT says, as if spoken."
  (interactive (list (let ((voice--fill nil)) (read-string "Say: "))))
  (voice-dispatch text :source "typed"))

(defun voice-listen ()
  "Listen, and do what is said: the island on the phone, else type."
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

(defun voice--decisive-p (plan)
  "Non-nil when PLAN does something by itself: no question to ask, no list
to pick from."
  (and plan
       (not (memq (plist-get plan :kind) '(ask none)))
       (not (plist-get plan :fallen))
       (not (and (eq (plist-get plan :kind) 'task) (not (eq (plist-get plan :decision) 'act))))))

(defvar voice-readings-tried 3
  "How many of the engine's readings are weighed, best first.")

(defun voice--best-reading (readings source)
  "Of READINGS (what was heard, the engine's best first), the first whose
plan does something by itself, else the first: (TEXT SAID . PLAN).  The
recogniser says what it heard best; Emacs knows which reading makes sense."
  (let (first chosen)
    (dolist (r (seq-take readings voice-readings-tried))
      (unless chosen
        (let* ((said (voice--rewrite r)) (plan (voice-plan said source)))
          (unless first (setq first (cons r (cons said plan))))
          (when (voice--decisive-p plan) (setq chosen (cons r (cons said plan)))))))
    (or chosen first)))

(defun voice-from-app ()
  "Called by Emacs Home once it heard something: plan it now, do it just
after.  Return front when Emacs should come forward, type when the words
are to be typed where the cursor is, else quiet.  The line is EPOCH TAB
SOURCE TAB TEXT, then the engine's other readings, a tab before each.
From a text field of another app (SOURCE field), only what is clearly a
command is done; anything else is typed there."
  (condition-case err
      (with-temp-buffer
        (insert-file-contents (voice--heard-file))
        (let* ((line (car (last (split-string (buffer-string) "\n" t))))
               (parts (and line (split-string line "\t")))
               (when-heard (and parts (string-to-number (car parts))))
               (source (or (nth 1 parts) "app"))
               (text (string-trim (or (nth 2 parts) "")))
               (others (seq-remove #'string-empty-p (mapcar #'string-trim (nthcdr 3 parts)))))
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
            (pcase-let ((`(,heard ,said . ,plan) (voice--best-reading (cons text others) source)))
              (if (and (equal source "field") (not (voice--decisive-p plan)))
                  (progn (voice--log (list :kind 'typed :text text :source source) 0 "typed")
                         'type)
                (setq voice--planned (cons (float-time) (cons said (cons source plan))))
                (run-at-time 0 nil (lambda () (voice-dispatch heard :source source)))
                (if (plist-get plan :front) 'front 'quiet)))))))
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

;;;; Updating itself

(defun voice-update ()
  "Pull this config and load the voice files again: what was just pushed
works without a restart, or anyone typing into the phone."
  (let* ((default-directory (file-name-as-directory
                             (or (bound-and-true-p doom-user-dir) "~/.doom.d/")))
         (git (lambda (&rest args)
                (with-temp-buffer
                  (cons (apply #'call-process "git" nil t nil args)
                        (string-trim (buffer-string))))))
         (branch (cdr (funcall git "rev-parse" "--abbrev-ref" "HEAD")))
         (pull (funcall git "pull" "--ff-only" "origin" branch)))
    (if (/= 0 (car pull))
        (format "Update failed: %s" (car (last (split-string (cdr pull) "\n" t))))
      ;; Its tables are code, not settings: the new ones replace the old.
      (dolist (v '(voice-emacs-synonyms voice-emacs-domains voice-emacs-skip-regexp))
        (makunbound v))
      (setq voice-emacs--catalog nil)
      ;; The libraries, then the umbrella (it names the parts, new ones
      ;; too), then every part again, so a changed one is the new one.
      (dolist (f '("lisp/voice-match.el" "lisp/voice-emacs.el" "lisp/voice-command.el"))
        (when (file-exists-p f) (load (expand-file-name f) nil t)))
      (dolist (m (bound-and-true-p voice-modules))
        (let ((f (format "lisp/voice/%s.el" m)))
          (when (file-exists-p f) (load (expand-file-name f) nil t))))
      (when (file-exists-p "lisp/image-workflow.el")
        (load (expand-file-name "lisp/image-workflow.el") nil t))
      (format "Voice updated: %s" (cdr (funcall git "log" "--oneline" "-1"))))))

;;;; What to say

;; Itself
(voice-action '("update voice" "update voice commands" "reload voice" "voice update" "update yourself")
              #'voice-update :name "update voice")

(provide 'voice-app)
;;; voice-app.el ends here
