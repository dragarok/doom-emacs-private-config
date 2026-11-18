;;; voice-everyday.el --- Voice domain: everyday Emacs -- buffers, files, moving, time -*- lexical-binding: t -*-

;;; Commentary:
;; See voice-command.el for how the parts fit.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--fill)

;;;; More things to say

(defun voice--choose (prompt candidates text)
  "The one of CANDIDATES (strings) TEXT clearly names; else ask with
PROMPT, TEXT's words typed, so a tap finishes it."
  (let ((ranked (and text (not (string-empty-p text)) (voice-match-strings candidates text 5))))
    (if (and ranked (eq (voice-match-decide ranked) 'act))
        (plist-get (nth 2 (car ranked)) :title)
      (let ((voice--fill nil))
        (completing-read prompt candidates nil t (and text (voice--typed text)))))))

(defun voice-switch-buffer (text)
  "Switch to the buffer TEXT names."
  (let* ((names (seq-remove (lambda (n) (string-prefix-p " " n)) (mapcar #'buffer-name (buffer-list))))
         (name (voice--choose "Buffer: " names text)))
    (switch-to-buffer name)
    (format "Buffer: %s" name)))

(defun voice-recent-file (text)
  "Open the recent file TEXT names, by its name."
  (require 'recentf)
  (let* ((files (seq-take recentf-list 300))
         (by-name (mapcar (lambda (f) (cons (format "%s  %s" (file-name-nondirectory f)
                                                    (abbreviate-file-name (file-name-directory f)))
                                            f))
                          files))
         (pick (voice--choose "Recent file: " (mapcar #'car by-name) text)))
    (find-file (cdr (assoc pick by-name)))
    (format "Opened %s" (file-name-nondirectory (cdr (assoc pick by-name))))))

(defun voice-time ()
  "The time now."
  (format-time-string "It's %H:%M, %A %e %B"))

(defun voice-timer (text)
  "An Org countdown of the minutes TEXT says: \"25 minutes\", \"1 hour\"."
  (require 'org-timer)
  (let* ((hm (or (voice--duration (voice-match-words text))
                 (user-error "Voice: how long?  Say 25 minutes or 1 hour")))
         (minutes (+ (* 60 (string-to-number (car (split-string hm ":"))))
                     (string-to-number (cadr (split-string hm ":"))))))
    (when (bound-and-true-p org-timer-countdown-timer) (org-timer-stop))
    (org-timer-set-timer minutes)
    (format "Timer: %d minutes" minutes)))

;;;; What to say

(voice-action '("save all" "save everything" "save org files" "save org buffers")
              #'org-save-all-org-buffers :quiet t :name "save everything")

(voice-action '("zen" "zen mode" "focus mode") #'global-writeroom-mode :quiet t :name "zen")

(voice-action '("home" "emacs home" "go home" "dashboard") #'android-homepage-toggle
              :when 'android :quiet t :name "home")

;; The homepage's tiles, with more ways to say them: one short word alone
;; is what the voice app most often mishears.
(voice-action '("tip" "show a tip" "give me a tip" "next tip" "a tip") #'tips-next :name "tip")

(voice-action '("buffers" "buffer list" "show buffers" "all buffers") #'ibuffer :name "buffers")

;; Going places
;; The … must name one of the phone's apps clearly (voice-home.el), as
;; "clock in to …" must a task: "open magit" is no app, so the command wins.
(voice-action '("open …" "launch …" "open app …" "start app …") #'emacs-home-launch
              :when 'android :asks '((:prompt "\\`App: " :type rest)) :slot 'app :name "open app")

(voice-action '("buffer …" "switch to buffer …" "go to buffer …") #'voice-switch-buffer
              :slot 'text :name "buffer")

(voice-action '("open file …" "recent file …" "file …") #'voice-recent-file :slot 'text :name "recent file")

(voice-action '("go back" "previous buffer" "last buffer") #'previous-buffer :quiet t :name "go back")

(voice-action '("close" "close window" "close this") #'quit-window :quiet t :name "close")

(voice-action '("scroll down" "page down" "down") #'scroll-up-command :quiet t :name "scroll down")

(voice-action '("scroll up" "page up" "up") #'scroll-down-command :quiet t :name "scroll up")

(voice-action '("top" "go to top" "beginning") #'beginning-of-buffer :quiet t :name "top")

(voice-action '("bottom" "go to bottom" "end") #'end-of-buffer :quiet t :name "bottom")

(voice-action '("bigger" "bigger text" "zoom in" "text bigger") #'text-scale-increase :quiet t :name "bigger text")

(voice-action '("smaller" "smaller text" "zoom out" "text smaller") #'text-scale-decrease :quiet t :name "smaller text")

(voice-action '("time" "what time is it" "what's the time") #'voice-time :quiet t :name "time")

(voice-action '("timer …" "set a timer for …" "set timer for …" "set a timer …" "timer for …")
              #'voice-timer :slot 'text :quiet t :name "timer")

(provide 'voice-everyday)
;;; voice-everyday.el ends here
