;;; claude-podcast.el --- Learn-while-you-wait podcast autoplay -*- lexical-binding: t; -*-

;; Author: Roger Parkinson
;; Keywords: multimedia, convenience

;;; Commentary:

;; An auxiliary multitasking layer for the master-Claude workflow: while you
;; are waiting on agents (idle, not typing), a podcast plays so you keep
;; learning; the instant you start giving input to an agent, it pauses.
;;
;; - Podcasts come from `elfeed' feeds tagged `podcast' (the "podcast scene").
;; - Playback is `mpv', driven over its JSON IPC socket (instant pause/resume,
;;   seeking, playback speed).
;; - `claude-podcast-mode' (global, ON by default) is the automatic behavior:
;;     play/resume when you have been idle `claude-podcast-idle-delay' seconds,
;;     pause the moment you type into a Claude session.
;;   Toggle it off (`claude-podcast-mode' / SPC o p t) to stop the automation;
;;   the manual commands still work.
;;
;; Requires: the `mpv' binary (brew install mpv) and the `elfeed' package.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'json)

(declare-function elfeed "elfeed")
(declare-function elfeed-update "elfeed")
(declare-function elfeed-entry-tags "elfeed-db")
(declare-function elfeed-entry-enclosures "elfeed-db")
(declare-function elfeed-entry-date "elfeed-db")
(declare-function elfeed-entry-title "elfeed-db")
(declare-function elfeed-tag "elfeed-db")
(declare-function elfeed-db-save "elfeed-db")
(declare-function elfeed-search-toggle-all "elfeed-search")
(declare-function elfeed-show-tag "elfeed-show")
(defvar elfeed-feeds)
(defvar elfeed-show-entry)


;;;; Customization

(defgroup claude-podcast nil
  "Autoplay podcasts while waiting on Claude agents."
  :group 'multimedia
  :prefix "claude-podcast-")

(defcustom claude-podcast-mpv-program "mpv"
  "Path to the mpv binary."
  :type 'string)

(defcustom claude-podcast-socket
  (expand-file-name "claude-podcast-mpv.sock" temporary-file-directory)
  "Path to the mpv IPC unix socket."
  :type 'string)

(defcustom claude-podcast-idle-delay 12
  "Seconds of inactivity before a podcast (re)starts playing."
  :type 'number)

(defcustom claude-podcast-speed 1.3
  "Playback speed for podcasts."
  :type 'number)

(defcustom claude-podcast-star-tag 'star
  "Elfeed tag marking a PRIORITY episode/feed.  Starred episodes play before
the newest unlistened one.  Star episodes in elfeed (or `claude-podcast-toggle-star')."
  :type 'symbol)

(defcustom claude-podcast-auto-start t
  "When non-nil, going idle starts the latest episode if nothing is loaded.
When nil, idle only RESUMES an already-loaded (paused) episode."
  :type 'boolean)

(defcustom claude-podcast-require-agent-working nil
  "When non-nil, only play while at least one Claude session is working.
Default nil: play whenever you are idle (your chosen behavior)."
  :type 'boolean)

(defcustom claude-podcast-feeds
  '(("https://lexfridman.com/feed/podcast/" podcast ai)
    ("https://api.substack.com/feed/podcast/1084089.rss" podcast ai) ; Latent Space
    ("https://feeds.transistor.fm/the-cognitive-revolution" podcast ai)
    ("https://feeds.megaphone.fm/dwarkesh" podcast ai))
  "Starter podcast feeds, added to `elfeed-feeds' by `claude-podcast-setup-feeds'.
Edit to taste; each entry is (URL . TAGS) and should include the `podcast' tag."
  :type '(repeat (cons string (repeat symbol))))


;;;; mpv playback over the IPC socket

(defvar claude-podcast--proc nil
  "The mpv process, or nil.")

(defvar claude-podcast--paused nil
  "Non-nil when we have paused mpv (auto or manual).")

(defvar claude-podcast--manual-pause nil
  "Non-nil when YOU paused.  Blocks idle auto-resume until you resume/play.")

(defvar claude-podcast--manual-stop nil
  "Non-nil when YOU stopped.  Blocks idle auto-start until you play again.")

(defvar claude-podcast--title nil
  "Title of the currently-loaded episode, for the mode line / messages.")

(defun claude-podcast--running-p ()
  "Non-nil when mpv is alive."
  (and claude-podcast--proc (process-live-p claude-podcast--proc)))

(defun claude-podcast--ipc-send (cmd)
  "Send CMD (a list like (\"set_property\" \"pause\" t)) to mpv via IPC."
  (when (and (claude-podcast--running-p)
             (file-exists-p claude-podcast-socket))
    (ignore-errors
      (let ((p (make-network-process
                :name "claude-podcast-ipc" :family 'local
                :service claude-podcast-socket :coding 'utf-8 :noquery t)))
        (process-send-string
         p (concat (json-encode (list :command cmd)) "\n"))
        (run-at-time 0.2 nil (lambda () (when (process-live-p p)
                                          (delete-process p))))))))

;;;###autoload
(defun claude-podcast-play-url (url &optional title)
  "Start mpv playing URL (audio only) with TITLE for display."
  (unless (executable-find claude-podcast-mpv-program)
    (user-error "mpv not found — install it first: %s"
                (if (eq system-type 'android)
                    "pkg install mpv (in Termux)"
                  "brew install mpv")))
  (claude-podcast-stop)
  (setq claude-podcast--title (or title url)
        claude-podcast--paused nil
        claude-podcast--manual-pause nil   ; explicit play clears your overrides
        claude-podcast--manual-stop nil
        claude-podcast--proc
        (start-process
         "claude-podcast-mpv" "*claude-podcast*"
         claude-podcast-mpv-program
         "--no-video" "--no-terminal" "--really-quiet"
         "--idle=no" "--keep-open=no"
         (format "--speed=%s" claude-podcast-speed)
         (format "--input-ipc-server=%s" claude-podcast-socket)
         url))
  (message "▶ podcast: %s" claude-podcast--title))

;;;###autoload
(defun claude-podcast-pause (&optional manual)
  "Pause podcast playback.
MANUAL (set when called interactively) makes the pause sticky:
idle auto-resume won't undo it — only you can, by resuming/playing."
  (interactive (list t))
  (when (and (claude-podcast--running-p) (not claude-podcast--paused))
    (claude-podcast--ipc-send '("set_property" "pause" t))
    (setq claude-podcast--paused t))
  (when manual (setq claude-podcast--manual-pause t)))

;;;###autoload
(defun claude-podcast-resume ()
  "Resume podcast playback (clears any sticky manual pause)."
  (interactive)
  (setq claude-podcast--manual-pause nil)
  (when (and (claude-podcast--running-p) claude-podcast--paused)
    (claude-podcast--ipc-send '("set_property" "pause" :json-false))
    (setq claude-podcast--paused nil)))

;;;###autoload
(defun claude-podcast-stop (&optional manual)
  "Stop podcast playback and quit mpv.
MANUAL (set when called interactively) makes the stop sticky:
idle auto-start won't pick a new episode until you play again."
  (interactive (list t))
  (when (claude-podcast--running-p)
    (claude-podcast--ipc-send '("quit"))
    (ignore-errors (delete-process claude-podcast--proc)))
  (setq claude-podcast--proc nil claude-podcast--paused nil)
  (when manual (setq claude-podcast--manual-stop t)))

;;;###autoload
(defun claude-podcast-set-speed (speed)
  "Set podcast playback SPEED (e.g. 1.0, 1.5, 2.0)."
  (interactive (list (read-number "Speed: " claude-podcast-speed)))
  (setq claude-podcast-speed speed)
  (claude-podcast--ipc-send (list "set_property" "speed" speed))
  (message "Podcast speed %sx" speed))

;;;###autoload
(defun claude-podcast-toggle-play ()
  "Manually pause/resume the podcast."
  (interactive)
  (cond
   ((not (claude-podcast--running-p)) (claude-podcast-next))
   (claude-podcast--paused (claude-podcast-resume))
   (t (claude-podcast-pause t))))


;;;; The podcast scene (elfeed)

;;;###autoload
(defun claude-podcast-setup-feeds ()
  "Add `claude-podcast-feeds' to `elfeed-feeds' (idempotent)."
  (interactive)
  (require 'elfeed)
  (dolist (f claude-podcast-feeds)
    (cl-pushnew f elfeed-feeds :test #'equal))
  (message "Added %d podcast feed(s) to elfeed" (length claude-podcast-feeds)))

(defun claude-podcast--starred-p (entry)
  "Non-nil if ENTRY carries the priority star tag."
  (memq claude-podcast-star-tag (elfeed-entry-tags entry)))

(defun claude-podcast--candidates ()
  "Unlistened `podcast' entries with an enclosure, STARRED first then newest."
  (when (require 'elfeed nil t)
    (let (cands)
      (with-no-warnings
        (with-elfeed-db-visit (entry _feed)
          (when (and (memq 'podcast (elfeed-entry-tags entry))
                     (not (memq 'listened (elfeed-entry-tags entry)))
                     (elfeed-entry-enclosures entry))
            (push entry cands))))
      (sort cands
            (lambda (a b)
              (let ((sa (claude-podcast--starred-p a))
                    (sb (claude-podcast--starred-p b)))
                (cond ((and sa (not sb)) t)
                      ((and sb (not sa)) nil)
                      (t (> (elfeed-entry-date a) (elfeed-entry-date b))))))))))

(defun claude-podcast--play-entry (entry)
  "Play ENTRY's audio enclosure and mark it listened."
  (let ((url (car (car (elfeed-entry-enclosures entry))))
        (title (elfeed-entry-title entry)))
    (claude-podcast-play-url url (concat (if (claude-podcast--starred-p entry) "★ " "") title))
    (with-no-warnings
      (elfeed-tag entry 'listened)
      (ignore-errors (elfeed-db-save)))))

;;;###autoload
(defun claude-podcast-next ()
  "Play the next podcast episode: a STARRED one if any, else the newest."
  (interactive)
  (let ((entry (car (claude-podcast--candidates))))
    (if (null entry)
        (message "No unlistened podcast — run `elfeed-update' (or `claude-podcast-setup-feeds' first)")
      (claude-podcast--play-entry entry))))

;;;###autoload
(defun claude-podcast-choose ()
  "Pick a podcast episode to play (starred shown first) via completion."
  (interactive)
  (let* ((cands (claude-podcast--candidates))
         (alist (mapcar
                 (lambda (e)
                   (cons (format "%s %-70s  %s"
                                 (if (claude-podcast--starred-p e) "★" " ")
                                 (truncate-string-to-width (elfeed-entry-title e) 70)
                                 (format-time-string "%Y-%m-%d"
                                                     (seconds-to-time (elfeed-entry-date e))))
                         e))
                 cands)))
    (if (null alist)
        (message "No episodes — run `elfeed-update'")
      (let* ((choice (completing-read "Play podcast: " alist nil t))
             (entry (cdr (assoc choice alist))))
        (when entry (claude-podcast--play-entry entry))))))

;;;###autoload
(defun claude-podcast-toggle-star ()
  "Toggle the priority star on the selected episode(s) in an elfeed buffer."
  (interactive)
  (require 'elfeed)
  (cond
   ((derived-mode-p 'elfeed-search-mode)
    (with-no-warnings (elfeed-search-toggle-all claude-podcast-star-tag)))
   ((derived-mode-p 'elfeed-show-mode)
    (with-no-warnings
      (elfeed-tag elfeed-show-entry claude-podcast-star-tag)
      (ignore-errors (elfeed-db-save))
      (message "★ starred")))
   (t (user-error "Use this in an elfeed search/show buffer"))))


;;;; Automatic play-while-idle / pause-on-input

(defvar claude-podcast--idle-timer nil)

(defun claude-podcast--session-buffer-p (buf)
  "Non-nil if BUF is a Claude session terminal.
Matches local Claude Code sessions (*claude:...*) and remote
claude-remote windows (*claude-remote[...]*) on Android."
  (and (bufferp buf)
       (let ((name (buffer-name buf)))
         (or (string-prefix-p "*claude:" name)
             (string-prefix-p "*claude-remote[" name)))))

(defun claude-podcast--agent-working-p ()
  "Non-nil if the gate is satisfied: either we don't require a working agent,
or at least one managed session is currently working."
  (or (not claude-podcast-require-agent-working)
      (and (boundp 'claude-workspace--sessions)
           (cl-some (lambda (b)
                      (and (buffer-live-p b)
                           (boundp 'claude-workspace--needs-attention)
                           ;; "working" ~= not idle/waiting (no attention flag)
                           (not (buffer-local-value 'claude-workspace--needs-attention b))))
                    claude-workspace--sessions))))

(defun claude-podcast--on-command ()
  "Pause the podcast the moment you give input to a Claude session."
  (when (and claude-podcast-mode
             (claude-podcast--running-p)
             (not claude-podcast--paused)
             (claude-podcast--session-buffer-p (current-buffer)))
    (claude-podcast-pause)))

(defun claude-podcast--on-idle ()
  "When idle, resume or (auto-)start the podcast.  Silent if there is nothing
to play or mpv is absent, so it never nags before things are set up."
  (when (and claude-podcast-mode
             (executable-find claude-podcast-mpv-program)
             (claude-podcast--agent-working-p))
    (cond
     ;; resume only what WE auto-paused — never undo the user's pause
     ((and (claude-podcast--running-p) claude-podcast--paused
           (not claude-podcast--manual-pause))
      (claude-podcast-resume))
     ;; auto-start only if the user didn't explicitly stop
     ((and (not (claude-podcast--running-p)) claude-podcast-auto-start
           (not claude-podcast--manual-stop))
      (let ((entry (car (claude-podcast--candidates))))
        (when entry (claude-podcast--play-entry entry)))))))

(defun claude-podcast--on-remote-attach ()
  "Sticky-pause when a tty client frame attaches.
A terminal client (phone over mosh, ssh) means you are NOT in front of
this machine — its speakers must not keep playing, and idle auto-resume
must not restart them after you detach."
  (when (and claude-podcast-mode
             (not (display-graphic-p))
             (claude-podcast--running-p)
             (not claude-podcast--paused))
    (claude-podcast-pause t)
    (message "Podcast paused — remote client attached")))

;;;###autoload
(define-minor-mode claude-podcast-mode
  "Automatically play podcasts while you wait, pause when you type.
ON by default.  Toggle off to stop the automation (manual commands still work)."
  :global t
  :group 'claude-podcast
  (if claude-podcast-mode
      (progn
        (add-hook 'pre-command-hook #'claude-podcast--on-command)
        (add-hook 'server-after-make-frame-hook #'claude-podcast--on-remote-attach)
        (when (timerp claude-podcast--idle-timer)   ; never leak a second timer
          (cancel-timer claude-podcast--idle-timer))
        (setq claude-podcast--idle-timer
              (run-with-idle-timer claude-podcast-idle-delay t
                                   #'claude-podcast--on-idle))
        ;; explicit re-enable = opting back in: clear sticky overrides
        (setq claude-podcast--manual-pause nil
              claude-podcast--manual-stop nil)
        (message "Claude podcast autoplay ON — learns while you wait"))
    (remove-hook 'pre-command-hook #'claude-podcast--on-command)
    (remove-hook 'server-after-make-frame-hook #'claude-podcast--on-remote-attach)
    (when (timerp claude-podcast--idle-timer)
      (cancel-timer claude-podcast--idle-timer)
      (setq claude-podcast--idle-timer nil))
    (claude-podcast-pause)
    (message "Claude podcast autoplay OFF")))


;;;; Menu

;;;###autoload (autoload 'claude-podcast-transient "claude-podcast" nil t)
(transient-define-prefix claude-podcast-transient ()
  "Podcasts — learn while you wait on agents."
  [:description
   (lambda ()
     (format "Podcast   [%s%s]"
             (if claude-podcast-mode "auto-on" "auto-off")
             (cond ((not (claude-podcast--running-p)) "")
                   (claude-podcast--paused " · paused")
                   (t (format " · ▶ %s" (or claude-podcast--title ""))))))
   ["Play"
    ("p" "Pause/resume" claude-podcast-toggle-play)
    ("n" "Next (starred → newest)" claude-podcast-next)
    ("c" "Choose episode…" claude-podcast-choose)
    ("s" "Speed…" claude-podcast-set-speed)
    ("x" "Stop" claude-podcast-stop)]
   ["Scene"
    ("f" "Add podcast feeds" claude-podcast-setup-feeds)
    ("u" "Update feeds" (lambda () (interactive) (require 'elfeed) (elfeed-update)))
    ("*" "Toggle ★ (in elfeed)" claude-podcast-toggle-star)
    ("e" "Open elfeed" (lambda () (interactive) (require 'elfeed) (elfeed)))]
   ["Auto"
    ("t" "Toggle autoplay" claude-podcast-mode)]])

(require 'transient)

(provide 'claude-podcast)
;;; claude-podcast.el ends here
