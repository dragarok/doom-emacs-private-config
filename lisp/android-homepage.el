;;; android-homepage.el --- Touch-friendly macro-keyboard homepage -*- lexical-binding: t -*-

;;; Code:

(require 'seq)
(require 'nerd-icons)

;;; Faces

(defface android-homepage-section
  '((t :inherit +dashboard-menu-title :height 1.1 :weight bold))
  "Section headers.")

(defface android-homepage-icon
  '((t :inherit +dashboard-menu-title :height 1.4))
  "Button icons.")

(defface android-homepage-title
  '((t :inherit +dashboard-menu-title :height 1.2))
  "Button titles.")

(defface android-homepage-desc
  '((t :inherit font-lock-comment-face))
  "Button descriptions.")

;;; Toggle between homepage and last buffer

(defvar android-homepage--last-buffer nil)

(defun android-homepage-toggle ()
  "Toggle between homepage and the last non-dashboard buffer."
  (interactive)
  (if (+dashboard-buffer-p (current-buffer))
      (when-let ((buf (or (and (buffer-live-p android-homepage--last-buffer)
                               android-homepage--last-buffer)
                          (other-buffer (current-buffer) t))))
        (switch-to-buffer buf))
    (setq android-homepage--last-buffer (current-buffer))
    (+dashboard/open (selected-frame))))

;;; Section definitions

(defun android-homepage--sections ()
  "Build the homepage button grid."
  (let ((sections
         (list
          (list "River Flow"
                (list
                 (list :icon (nerd-icons-faicon "nf-fa-tint")
                       :title "Flow" :desc "Pick new task" :action 'rts-flow)
                 (list :icon (nerd-icons-faicon "nf-fa-play")
                       :title "Continue" :desc "Resume last" :action 'rts-flow-continue)
                 (list :icon (nerd-icons-faicon "nf-fa-times")
                       :title "Cancel" :desc "Undo selection" :action 'rts-flow-cancel)
                 (list :icon (nerd-icons-faicon "nf-fa-clock_o")
                       :title "Manual Clock" :desc "Clock any task" :action 'rts-flow-manual)
                 (list :icon (nerd-icons-faicon "nf-fa-check_circle")
                       :title "Clock Out" :desc "Smart clock out" :action 'rts-flow-clock-out)
                 (list :icon (nerd-icons-faicon "nf-fa-crosshairs")
                       :title "Goto Task" :desc "Jump to task" :action 'rts-flow-clock-goto)))

          (list "Quick Actions"
                (list
                 (list :icon (nerd-icons-faicon "nf-fa-plus_circle")
                       :title "Add" :desc "Task / Bean / Clock" :action 'rts-flow-add)
                 (list :icon (nerd-icons-faicon "nf-fa-compass")
                       :title "State" :desc "Context + Energy" :action 'rts-flow-set-state)
                 (list :icon (nerd-icons-faicon "nf-fa-info_circle")
                       :title "Show State" :desc "View current" :action 'rts-flow-show-state)
                 (list :icon (nerd-icons-faicon "nf-fa-bolt")
                       :title "Micro" :desc "5-min task" :action 'micro-experiments-pick)
                 (list :icon (nerd-icons-faicon "nf-fa-pencil")
                       :title "Log" :desc "Daily note" :action 'micro-experiments-log)
                 (list :icon (nerd-icons-faicon "nf-fa-lightbulb_o")
                       :title "Forgotten" :desc "Resurface note" :action 'rts-flow-surface-forgotten-note)))

          (list "Navigate"
                (list
                 (list :icon (nerd-icons-faicon "nf-fa-calendar")
                       :title "Agenda" :desc "Org agenda" :action 'my-org-agenda)
                 (list :icon (nerd-icons-faicon "nf-fa-search")
                       :title "Find Node" :desc "Org-roam search" :action 'org-roam-node-find)
                 (list :icon (nerd-icons-faicon "nf-fa-sun_o")
                       :title "Dailies" :desc "Cycle focus" :action 'my/org-roam-dailies-cycle-focus)
                 (list :icon (nerd-icons-faicon "nf-fa-random")
                       :title "Random" :desc "Random note" :action 'org-roam-node-random)
                 (list :icon (nerd-icons-faicon "nf-fa-dice")
                       :title "Random Big" :desc "Large note" :action 'org-roam-open-large-note-randomly)
                 (list :icon (nerd-icons-faicon "nf-fa-share_alt")
                       :title "Graph" :desc "Org-roam graph" :action 'org-roam-ui-open)))

          (list "Tools"
                (list
                 (list :icon (nerd-icons-faicon "nf-fa-list")
                       :title "Buffers" :desc "Buffer list" :action 'ibuffer)
                 (list :icon (nerd-icons-faicon "nf-fa-leaf")
                       :title "Zen" :desc "Writeroom" :action 'global-writeroom-mode)
                 (list :icon (nerd-icons-faicon "nf-fa-camera")
                       :title "Camera" :desc "Attach media" :action 'my/org-attach-media)
                 (list :icon (nerd-icons-faicon "nf-fa-keyboard_o")
                       :title "Keyboard" :desc "Toggle input" :action 'my/toggle-touch-keyboard)
                 (list :icon (nerd-icons-faicon "nf-fa-image")
                       :title "Diary" :desc "Browse photos" :action 'my/diary-browse-images)
                 (list :icon (nerd-icons-faicon "nf-fa-bar_chart")
                       :title "Neglect" :desc "Weekly report" :action 'rts-flow-weekly-neglect-report))))))
    sections))

;;; Rendering

(defvar android-homepage-columns 3)

(defun android-homepage--render-row (buttons)
  "Render a row of BUTTONS using pixel-based alignment."
  (let* ((ncols android-homepage-columns)
         (pad 0.03))
    (dotimes (i (length buttons))
      (let* ((btn (nth i buttons))
             (pos (+ pad (/ (float i) ncols))))
        (insert (propertize " " 'display `(space :align-to (,pos . text))))
        (insert (propertize (plist-get btn :icon) 'face 'android-homepage-icon))
        (insert " ")
        (let ((action (plist-get btn :action)))
          (insert-text-button (plist-get btn :title)
                              'action `(lambda (_) (call-interactively #',action))
                              'follow-link t
                              'face 'android-homepage-title
                              'help-echo (plist-get btn :desc)))))
    (insert "\n")
    (dotimes (i (length buttons))
      (let* ((btn (nth i buttons))
             (pos (+ pad (/ (float i) ncols))))
        (insert (propertize " " 'display `(space :align-to (,pos . text))))
        (insert (propertize (plist-get btn :desc)
                            'face 'android-homepage-desc))))
    (insert "\n")))

(defun android-homepage-widget ()
  "Dashboard widget: touch-friendly macro-keyboard grid."
  (let ((sections (android-homepage--sections)))
    (insert "\n")
    (dolist (section sections)
      (let* ((header (car section))
             (buttons (cadr section))
             (rows (seq-partition buttons 3)))
        (+dashboard-insert
         (propertize (format "━━  %s  ━━" (upcase header))
                     'face 'android-homepage-section))
        (insert "\n")
        (dolist (row rows)
          (android-homepage--render-row row)
          (insert "\n"))))))

;;; Activate — swap the default shortmenu for our grid
(setq +dashboard-functions
      '(android-homepage-widget
        +dashboard-widget-loaded
        +dashboard-widget-footer))

(provide 'android-homepage)
;;; android-homepage.el ends here
