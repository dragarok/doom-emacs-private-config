;;; voice-log.el --- Voice: what was heard and done -*- lexical-binding: t -*-

;;; Commentary:
;; The log of every utterance, its recording on the phone, checking phrases
;; against what they should do, and which process failed.

;;; Code:

(require 'voice-core)

;;;; Near, not word for word

(defun voice--log-file ()
  (or voice-log-file
      (expand-file-name (format "voice_log_%s.tsv" (system-name))
                        (or (bound-and-true-p org-logs-directory)
                            (expand-file-name "logs/" (or (bound-and-true-p org-directory) "~/org/"))))))

(defun voice--log (plan ms result)
  "One line per utterance: what was heard, what it did, how sure, how long."
  (with-demoted-errors "voice log: %S"
    (let* ((ranked (plist-get plan :ranked))
           (clean (lambda (s) (replace-regexp-in-string "[\t\n]+" " " (format "%s" (or s ""))))))
      (write-region
       (concat (mapconcat (lambda (x) (funcall clean x))
                          (list (format-time-string "%F %T" (plist-get plan :t0))
                                (plist-get plan :source)
                                (with-current-buffer (window-buffer (selected-window)) major-mode)
                                (plist-get plan :text)
                                (plist-get plan :kind)
                                (plist-get (plist-get plan :action) :name)
                                (and ranked (plist-get (nth 2 (car ranked)) :title))
                                (and ranked (format "%.2f" (nth 1 (car ranked))))
                                (and (cadr ranked) (format "%.2f" (- (car (car ranked)) (car (cadr ranked)))))
                                (plist-get plan :decision)
                                (format "%d" ms)
                                result)
                          "\t")
               "\n")
       nil (voice--log-file) t 'silent))))

(defun voice--wav-header (bytes)
  "A WAV header for BYTES of 16 kHz mono 16-bit PCM."
  (let ((le (lambda (n k) (apply #'unibyte-string
                                 (cl-loop for i below k collect (logand (ash n (* -8 i)) 255))))))
    (concat "RIFF" (funcall le (+ 36 bytes) 4) "WAVEfmt " (funcall le 16 4)
            (funcall le 1 2) (funcall le 1 2) (funcall le 16000 4) (funcall le 32000 4)
            (funcall le 2 2) (funcall le 16 2) "data" (funcall le bytes 4))))

(defun voice--save-audio (stamp)
  "Save the voice app's newest finished recording as STAMP.wav in
`voice-audio-directory', a moment later so it is complete.  Read as
root: its files are private to it, and other apps' data is hidden from
ours, hence the main mount view; KernelSU's su needs Emacs's own loader
off (see android-doom-root.el)."
  (when (and voice--android voice-audio-directory
             ;; The engine keeps its own (voice-engine-save-directory).
             (not (and (fboundp 'voice-engine-running-p) (voice-engine-running-p))))
    (run-at-time
     2 nil
     (lambda ()
       (with-demoted-errors "voice audio: %S"
         (make-directory voice-audio-directory t)
         (let ((buf (generate-new-buffer " *voice-audio*"))
               (dest (expand-file-name (concat stamp ".wav") voice-audio-directory))
               (android-use-exec-loader nil))
           (with-current-buffer buf (set-buffer-multibyte nil))
           (make-process
            :name "voice-audio" :buffer buf :noquery t :connection-type 'pipe
            :coding 'binary
            :command (list "su" "--mount-master" "-c"
                           (format "f=$(ls -t %s/*.txt 2>/dev/null | head -1); [ -n \"$f\" ] && cat \"${f%%.txt}.pcm\""
                                   voice--app-history))
            :sentinel
            (lambda (proc _event)
              (unless (process-live-p proc)
                (with-current-buffer buf
                  (when (> (buffer-size) 1000)
                    (goto-char (point-min))
                    (insert (voice--wav-header (buffer-size)))
                    (let ((coding-system-for-write 'binary))
                      (write-region nil nil dest nil 'silent))))
                (kill-buffer buf)
                (voice--prune-audio))))))))))

(defvar voice-audio-days 7 "How many days of recordings to keep.")

(defun voice--prune-audio ()
  "Delete recordings older than `voice-audio-days'."
  (dolist (f (directory-files voice-audio-directory t "\\.wav\\'"))
    (when (> (float-time (time-since (file-attribute-modification-time (file-attributes f))))
             (* 86400 voice-audio-days))
      (ignore-errors (delete-file f)))))

;;;; Checking phrases against what they should do

(defun voice-expect-ok (expect plan)
  "Non-nil when PLAN does what EXPECT says: action:NAME, task:WORDS (clocks
in, the top task's title containing WORDS), pick:WORDS (a pick list,
WORDS among its top five), ask:NAME (\"did you mean\" the action or
command NAME), cmd:NAME (runs the command NAME), or none."
  (let* ((kind (plist-get plan :kind))
         (ranked (plist-get plan :ranked))
         (titles (mapcar (lambda (r) (downcase (plist-get (nth 2 r) :title))) (seq-take ranked 5)))
         (want (and (string-match ":\\(.*\\)" expect) (downcase (string-trim (match-string 1 expect))))))
    (pcase (car (split-string expect ":"))
      ("action" (and (eq kind 'action)
                     (equal (downcase (plist-get (plist-get plan :action) :name)) want)))
      ("task" (and (eq kind 'task) (eq (plist-get plan :decision) 'act)
                   (car titles) (string-match-p (regexp-quote want) (car titles))))
      ("pick" (and (eq kind 'task) (eq (plist-get plan :decision) 'pick)
                   (seq-some (lambda (ti) (string-match-p (regexp-quote want) ti)) titles)))
      ("cmd" (and (eq kind 'action) (plist-get (plist-get plan :action) :command)
                  (equal (downcase (plist-get (plist-get plan :action) :name)) want)))
      ("ask" (and (eq kind 'ask)
                  (equal (downcase (plist-get (nth 1 (car (plist-get plan :options))) :name)) want)))
      ("none" (or (eq kind 'none) (eq (plist-get plan :decision) 'none))))))

(defun voice-check-corpus (file &optional source)
  "Plan every phrase in FILE (PHRASE TAB EXPECT per line, # comments), as
heard from SOURCE (default island), doing nothing.  Write FILE-results.tsv
beside it: ok, phrase, expected, kind, action, top task, score, decision.
Return how many passed."
  (let ((rows nil) (ok 0) (n 0))
    (with-temp-buffer
      (insert-file-contents file)
      (dolist (line (split-string (buffer-string) "\n" t))
        (unless (string-prefix-p "#" line)
          (let* ((parts (split-string line "\t"))
                 (phrase (car parts)) (expect (or (nth 1 parts) "none"))
                 (plan (voice-plan (voice--rewrite phrase) (or source "island")))
                 (good (voice-expect-ok expect plan))
                 (top (car (plist-get plan :ranked))))
            (cl-incf n) (when good (cl-incf ok))
            (push (mapconcat (lambda (x) (format "%s" (or x "")))
                             (list (if good "ok" "MISS") phrase expect (plist-get plan :kind)
                                   (plist-get (plist-get plan :action) :name)
                                   (and top (plist-get (nth 2 top) :title))
                                   (and top (format "%.2f" (nth 1 top)))
                                   (plist-get plan :decision))
                             "\t")
                  rows)))))
    (with-temp-file (concat (file-name-sans-extension file) "-results.tsv")
      (insert (mapconcat #'identity (nreverse rows) "\n") "\n"))
    (format "%d of %d phrases do what they should" ok n)))

;;;; Which process failed

(defvar voice-sentinel-log
  (and voice--android "/sdcard/Documents/voice-audio/sentinel-errors.log")
  "Where a sentinel's error is written down with its process's name and
command: Emacs says only \"error in process sentinel\", not whose.
Nil: don't.  Added 2026-11-17 for a \"listp, Internal\" error while
tagging photos; remove once found.")

(defun voice--sentinel-traced (fn)
  (lambda (proc event)
    (condition-case err
        (funcall fn proc event)
      (error
       (with-demoted-errors "voice sentinel log: %S"
         (write-region (format "%s\t%s\t%S\t%S\t%s\n" (format-time-string "%F %T")
                               (process-name proc) (process-command proc) err
                               (string-trim (format "%s" event)))
                       nil voice-sentinel-log t 'silent))
       (signal (car err) (cdr err))))))

(defun voice--make-process-a (args)
  (let ((s (plist-get args :sentinel)))
    (if (and voice-sentinel-log (functionp s))
        (plist-put (copy-sequence args) :sentinel (voice--sentinel-traced s))
      args)))

(defun voice--set-process-sentinel-a (args)
  (if (and voice-sentinel-log (functionp (nth 1 args))
           (not (memq (nth 1 args) '(ignore internal-default-process-sentinel))))
      (list (car args) (voice--sentinel-traced (nth 1 args)))
    args))

(when voice-sentinel-log
  (advice-add 'make-process :filter-args #'voice--make-process-a)
  (advice-add 'set-process-sentinel :filter-args #'voice--set-process-sentinel-a))

(provide 'voice-log)
;;; voice-log.el ends here
