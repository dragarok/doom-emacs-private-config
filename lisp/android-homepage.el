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

;;; Section definitions

(defun android-homepage--sections ()
  "Build the homepage button grid."
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
          (list :icon (nerd-icons-faicon "nf-fa-bolt")
                :title "Micro" :desc "5-min task" :action 'micro-experiments-pick)
          (list :icon (nerd-icons-faicon "nf-fa-pencil")
                :title "Log" :desc "Daily note" :action 'micro-experiments-log)))

   (list "Navigate"
         (list
          (list :icon (nerd-icons-faicon "nf-fa-calendar")
                :title "Agenda" :desc "Org agenda" :action 'my-org-agenda)
          (list :icon (nerd-icons-faicon "nf-fa-search")
                :title "Find Node" :desc "Org-roam search" :action 'org-roam-node-find)
          (list :icon (nerd-icons-faicon "nf-fa-sun_o")
                :title "Dailies" :desc "Cycle focus" :action 'my/org-roam-dailies-cycle-focus)
          (list :icon (nerd-icons-faicon "nf-fa-random")
                :title "Random" :desc "Random note" :action 'org-roam-node-random)))

   (list "Windows"
         (list
          (list :icon (nerd-icons-faicon "nf-fa-expand")
                :title "Toggle Size" :desc "Expand / fold" :action 'kairoam-toggle-size)
          (list :icon (nerd-icons-faicon "nf-fa-balance_scale")
                :title "Balance" :desc "Balance windows" :action 'kairoam-balance)
          (list :icon (nerd-icons-faicon "nf-fa-toggle_on")
                :title "Kairoam" :desc "Toggle on/off" :action 'kairoam-toggle)
          (list :icon (nerd-icons-faicon "nf-fa-columns")
                :title "Open Right" :desc "Note to right" :action 'kairoam-open-note-to-right)))

   (list "Tools"
         (list
          (list :icon (nerd-icons-faicon "nf-fa-list")
                :title "Buffers" :desc "Buffer list" :action 'ibuffer)
          (list :icon (nerd-icons-faicon "nf-fa-leaf")
                :title "Zen" :desc "Writeroom" :action 'global-writeroom-mode)
          (list :icon (nerd-icons-faicon "nf-fa-camera")
                :title "Camera" :desc "Attach media" :action 'my/org-attach-media)
          (list :icon (nerd-icons-faicon "nf-fa-keyboard_o")
                :title "Keyboard" :desc "Toggle input" :action 'my/toggle-touch-keyboard)))))

;;; Rendering

(defvar android-homepage-col-width 38)

(defun android-homepage--render-row (left &optional right)
  "Render a button row with LEFT and optionally RIGHT button."
  (let ((cw android-homepage-col-width)
        (indent 4))
    (insert (make-string indent ?\s))
    (insert (propertize (plist-get left :icon) 'face 'android-homepage-icon))
    (insert " ")
    (let ((action (plist-get left :action)))
      (insert-text-button (plist-get left :title)
                          'action `(lambda (_) (call-interactively #',action))
                          'follow-link t
                          'face 'android-homepage-title
                          'help-echo (plist-get left :desc)))
    (when right
      (indent-to (+ indent cw))
      (insert (propertize (plist-get right :icon) 'face 'android-homepage-icon))
      (insert " ")
      (let ((action (plist-get right :action)))
        (insert-text-button (plist-get right :title)
                            'action `(lambda (_) (call-interactively #',action))
                            'follow-link t
                            'face 'android-homepage-title
                            'help-echo (plist-get right :desc))))
    (insert "\n")
    (insert (make-string (+ indent 3) ?\s))
    (insert (propertize (plist-get left :desc) 'face 'android-homepage-desc))
    (when right
      (indent-to (+ indent cw 3))
      (insert (propertize (plist-get right :desc) 'face 'android-homepage-desc)))
    (insert "\n")))

(defun android-homepage-widget ()
  "Dashboard widget: touch-friendly macro-keyboard grid."
  (let ((sections (android-homepage--sections)))
    (insert "\n")
    (dolist (section sections)
      (let* ((header (car section))
             (buttons (cadr section))
             (pairs (seq-partition buttons 2)))
        (+dashboard-insert
         (propertize (format "━━  %s  ━━" (upcase header))
                     'face 'android-homepage-section))
        (insert "\n")
        (dolist (pair pairs)
          (android-homepage--render-row (car pair) (cadr pair))
          (insert "\n"))))))

;;; Activate — swap the default shortmenu for our grid
(setq +dashboard-functions
      '(android-homepage-widget
        +dashboard-widget-loaded
        +dashboard-widget-footer))

(provide 'android-homepage)
;;; android-homepage.el ends here
