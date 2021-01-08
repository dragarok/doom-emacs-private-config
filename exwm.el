;;; os/exwm/config.el -*- lexical-binding: t; -*-

(setq counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
(setq dw/exwm-enabled t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        System specific                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package exwm
  :init
  (setq mouse-autoselect-window t
        focus-follows-mouse t
        exwm-workspace-warp-cursor t
        exwm-workspace-number 10)
                                        ;exwm-workspace-display-echo-area-timeout 5
                                        ;exwm-workspace-minibuffer-position 'bottom) ;; Annoying focus issues
  :config
  ;; TODO Add class and name config here from doom emacs
  (exwm-enable))

;; Use the `ido' configuration for a few configuration fixes that alter
;; 'C-x b' workplace switching behaviour. This also effects the functionality
;; of 'SPC .' file searching in doom regardless of the users `ido' configuration.
(use-package! exwm-config
  :after exwm
  :config
  (exwm-config--fix/ido-buffer-window-other-frame))

(use-package! exwm-xim
    :after exwm
    :config
    ;; These variables are required for X programs to pick up Emacs IM.
    (setenv "XMODIFIERS" "@im=exwm-xim")
    (setenv "GTK_IM_MODULE" "xim")
    (setenv "QT_IM_MODULE" "xim")
    (setenv "CLUTTER_IM_MODULE" "xim")
    (setenv "QT_QPA_PLATFORM" "xcb")
    (setenv "SDL_VIDEODRIVER" "x11")
    (exwm-xim-enable))


(defun exwm/run-in-background (command)
  (let ((command-parts (split-string command "[ ]+")))
    (apply #'call-process `(,(car command-parts) nil 0 nil ,@(cdr command-parts)))))

(defun exwm/bind-function (key invocation &rest bindings)
  "Bind KEYs to FUNCTIONs globally"
  (while key
    (exwm-input-set-key (kbd key)
                        `(lambda ()
                           (interactive)
                           (funcall ',invocation)))
    (setq key (pop bindings)
          invocation (pop bindings))))

(defun exwm/bind-command (key command &rest bindings)
  "Bind KEYs to COMMANDs globally"
  (while key
    (exwm-input-set-key (kbd key)
                        `(lambda ()
                           (interactive)
                           (exwm/run-in-background ,command)))
    (setq key (pop bindings)
          command (pop bindings))))

(defun dw/exwm-init-hook ()
  ;; Make workspace 1 be the one where we land at startup
  (exwm-workspace-switch-create 1)

  ;; Launch apps that will run in the background
  (exwm/run-in-background "dunst")
  (exwm/run-in-background "picom" "--config" "~/.config/picom/picom.conf")
  ;; (exwm/run-in-background "picom --config ~/.config/picom/picom.conf")
  (exwm/run-in-background "mpd")
  (exwm/run-in-background "indicator-kdeconnect")
  (exwm/run-in-background "mathpix-snipping-tool")
  (exwm/run-in-background "blueman-applet")
  (exwm/run-in-background "nm-applet")
  ;; (exwm/run-in-background "redshift -l 47.675510:-122.203362 -t 6500:3500")
  (exwm/run-in-background "dropbox"))

(use-package exwm
  :if dw/exwm-enabled
  :config
  (add-hook 'exwm-mode-hook
            (lambda ()
              (evil-local-set-key 'motion (kbd "C-u") nil)))

  (defun dw/setup-window-by-class ()
    (interactive)
    (pcase exwm-class-name
      ("teams-for-linux" (exwm-workspace-move-window 3))
      ("firefox" (exwm-workspace-move-window 2))
      ("Opera" (exwm-workspace-move-window 8))
      ("Microsoft Teams - Preview" (exwm-workspace-move-window 3))
      ("Spotify" (exwm-workspace-move-window 4))
      ("Vimb" (exwm-workspace-move-window 2))
      ("Brave-browser" (exwm-workspace-move-window 8))
      ("pavucontrol" (exwm-floating-toggle-floating))
      ("mpv" (exwm-floating-toggle-floating))))

  ;; Do some post-init setup
  (add-hook 'exwm-init-hook #'dw/exwm-init-hook)

  ;; Manipulate windows as they're created
  (add-hook 'exwm-manage-finish-hook
            (lambda ()
              ;; Send the window where it belongs
              (dw/setup-window-by-class)))

  ;; Hide the modeline on all X windows
                                        ;(exwm-layout-hide-mode-line)))
  ;; Automatically move EXWM buffer to current workspace when selected
  (setq exwm-layout-show-all-buffers t)

  ;; Display all EXWM buffers in every workspace buffer list
  (setq exwm-workspace-show-all-buffers t)

  ;; Hide the modeline on all X windows
  (add-hook 'exwm-floating-setup-hook
            (lambda ()
              (exwm-layout-hide-mode-line))))

(use-package exwm-systemtray
  :if dw/exwm-enabled
  :after (exwm)
  :config
  ;;  (exwm-systemtray-enable)
  ;; Show battery status in the mode line
  (display-battery-mode 1)
  ;; Show the time and date in modeline
  (setq display-time-day-and-date t)
  (display-time-mode 1))
;;(setq exwm-systemtray-height 17))

(defun dw/run-xmodmap ()
  (interactive)
  (start-process-shell-command "xmodmap" nil "xmodmap ~/.Xmodmap"))
(defun dw/run-picom ()
  (interactive)
  (start-process-shell-command "picom" nil "picom ~/.config/picom/picom.conf"))
(defun dw/update-wallpapers ()
  (interactive)
  (start-process-shell-command
   "feh" nil
   (format "feh --bg-scale ~/Pictures/on.jpg")))

(setq dw/polybar-process nil)
(defun dw/kill-panel ()
  (interactive)
  (when dw/panel-process
    (ignore-errors
      (kill-process dw/panel-process)))
  (setq dw/panel-process nil))
(defun dw/start-panel ()
  (interactive)
  (dw/kill-panel)
  (setq dw/polybar-process (start-process-shell-command "polybar" nil "polybar -c ~/.config/polybar/config.ini main")))

;; (defun dw/update-screen-layout ()
;;   (interactive)
;;   (let ((layout-script "~/.bin/update-screens"))
;;     (message "Running screen layout script: %s" layout-script)
;;     (start-process-shell-command "xrandr" nil layout-script)))

(defun dw/configure-desktop ()
  (interactive)
  (dw/run-xmodmap)
  (dw/run-picom)
  (run-at-time "2 sec" nil (lambda () (dw/update-wallpapers))))
;; (dw/update-screen-layout))

(defun dw/on-exwm-init ()
  (dw/configure-desktop)
  (dw/start-panel))

(when dw/exwm-enabled
  ;; Configure the desktop for first load
  (add-hook 'exwm-init-hook #'dw/on-exwm-init))

(defalias 'switch-to-buffer-original 'exwm-workspace-switch-to-buffer)
;; (defalias 'switch-to-buffer 'exwm-workspace-switch-to-buffer)

;; (defun dw/counsel-switch-buffer ()
;;   "Switch to another buffer.
;; Display a preview of the selected ivy completion candidate buffer
;; in the current window."
;;   (interactive)
;;   (ivy-read "Switch to buffer: " 'internal-complete-buffer
;;             :preselect (buffer-name (other-buffer (current-buffer)))
;;             :keymap ivy-switch-buffer-map
;;             :action #'ivy--switch-buffer-action
;;             :matcher #'ivy--switch-buffer-matcher
;;             :caller 'counsel-switch-buffer
;;             :unwind #'counsel--switch-buffer-unwind
;;             :update-fn 'counsel--switch-buffer-update-fn)
;; )

(when dw/exwm-enabled
  ;; Ctrl+Q will enable the next key to be sent directly
  (define-key exwm-mode-map [?\C-q] 'exwm-input-send-next-key)

  (defun exwm/run-vimb ()
    (exwm/run-in-background "vimb")
    (exwm-workspace-switch-create 2))

  (defun exwm/run-brave ()
    (exwm/run-in-background "brave")
    (exwm-workspace-switch-create 8))

  (exwm/bind-function
   "s-o" 'exwm/run-brave)

  (exwm/bind-command
   "s-p" "playerctl play-pause"
   "s-[" "playerctl previous"
   "s-]" "playerctl next")

  (use-package desktop-environment
    :after exwm
    :init
    (setq desktop-environment-brightness-get-command "light")
    (setq desktop-environment-brightness-set-command "light %s")
    (setq desktop-environment-brightness-get-regexp "^\\([0-9]+\\)")
    (setq desktop-environment-brightness-normal-increment "-A 10")
    (setq desktop-environment-brightness-normal-decrement "-U 10")
    (setq desktop-environment-brightness-small-increment "-A 5")
    (setq desktop-environment-brightness-small-decrement "-U 5")
    :config (desktop-environment-mode)
    :custom
    (desktop-environment-brightness-small-increment "2%+")
    (desktop-environment-brightness-small-decrement "2%-")
    (desktop-environment-brightness-normal-increment "5%+")
    (desktop-environment-brightness-normal-decrement "5%-"))


  ;; This needs a more elegant ASCII banner
  (defhydra hydra-exwm-move-resize (:timeout 4)
    "Move/Resize Window (Shift is bigger steps, Ctrl moves window)"
    ("j" (lambda () (interactive) (exwm-layout-enlarge-window 10)) "V 10")
    ("J" (lambda () (interactive) (exwm-layout-enlarge-window 30)) "V 30")
    ("k" (lambda () (interactive) (exwm-layout-shrink-window 10)) "^ 10")
    ("K" (lambda () (interactive) (exwm-layout-shrink-window 30)) "^ 30")
    ("h" (lambda () (interactive) (exwm-layout-shrink-window-horizontally 10)) "< 10")
    ("H" (lambda () (interactive) (exwm-layout-shrink-window-horizontally 30)) "< 30")
    ("l" (lambda () (interactive) (exwm-layout-enlarge-window-horizontally 10)) "> 10")
    ("L" (lambda () (interactive) (exwm-layout-enlarge-window-horizontally 30)) "> 30")
    ("C-j" (lambda () (interactive) (exwm-floating-move 0 10)) "V 10")
    ("C-S-j" (lambda () (interactive) (exwm-floating-move 0 30)) "V 30")
    ("C-k" (lambda () (interactive) (exwm-floating-move 0 -10)) "^ 10")
    ("C-S-k" (lambda () (interactive) (exwm-floating-move 0 -30)) "^ 30")
    ("C-h" (lambda () (interactive) (exwm-floating-move -10 0)) "< 10")
    ("C-S-h" (lambda () (interactive) (exwm-floating-move -30 0)) "< 30")
    ("C-l" (lambda () (interactive) (exwm-floating-move 10 0)) "> 10")
    ("C-S-l" (lambda () (interactive) (exwm-floating-move 30 0)) "> 30")
    ("f" nil "finished" :exit t))

  ;; Workspace switching
  (setq exwm-input-global-keys
        `(([?\s-r] . exwm-reset)
          ([?\s-w] . exwm-workspace-switch)

          ;; Move between windows
          ([s-left] . windmove-left)
          ([s-right] . windmove-right)
          ([s-up] . windmove-up)
          ([s-down] . windmove-down)

          ([?\s-r] . hydra-exwm-move-resize/body)
          ([?\s-e] . dired-jump)
          ([?\s-E] . (lambda () (interactive) (dired "~")))
          ([?\s-Q] . (lambda () (interactive) (kill-buffer)))
          ([?\s-`] . (lambda () (interactive) (exwm-workspace-switch-create 0)))

          ;; Launch applications via shell command
          ([?\s-&] . (lambda (command)
                       (interactive (list (read-shell-command "$ ")))
                       (start-process-shell-command command nil command)))

          ,@(mapcar (lambda (i)
                      `(,(kbd (format "s-%d" i)) .
                        (lambda ()
                          (interactive)
                          (exwm-workspace-switch-create ,i))))
                    (number-sequence 0 9))))
  ;; Show `exwm' buffers in buffer switching prompts.
  (add-hook 'exwm-mode-hook #'doom-mark-buffer-as-real-h)

  ;; Restore window configurations involving exwm buffers by only changing names
  ;; of visible buffers.
  (advice-add #'exwm--update-utf8-title :around #'exwm--update-utf8-title-advice)

  (exwm-input-set-key (kbd "<s-return>") 'vterm)
  (exwm-input-set-key (kbd "s-d") 'counsel-linux-app)
  (exwm-input-set-key (kbd "s-f") 'exwm-layout-toggle-fullscreen))

(use-package! exwm-randr
  :if dw/exwm-enabled
  :after exwm
  :config
  (add-hook 'exwm-randr-screen-change-hook
            (lambda ()
              (let ((xrandr-output-regexp "\n\\([^ ]+\\) connected ")
                    default-output)
                (with-temp-buffer
                  (call-process "xrandr" nil t nil)
                  (goto-char (point-min))
                  (re-search-forward xrandr-output-regexp nil 'noerror)
                  (setq default-output (match-string 1))
                  (forward-line)
                  (if (not (re-search-forward xrandr-output-regexp nil 'noerror))
                      (call-process
                       "xrandr" nil nil nil
                       "--auto")
                    (call-process
                     "xrandr" nil nil nil
                     "--output" (match-string 1) "--rate" "60" "--right-of" default-output)
                    ;;                     "--output" (match-string 1) "--mode" "1920x1080" "--right-of" default-output)
                    (setq exwm-randr-workspace-monitor-plist
                          (list 0 (match-string 1))))))))
  (exwm-randr-enable))

(use-package! exwm-firefox-core
  :after exwm
  :config
  ;; Add the <ESC> key to the exwm input keys for firefox buffers.
  (dolist (k `(escape))
    (cl-pushnew k exwm-input-prefix-keys)))

;; Configure further depending if the user has evil mode enabled.
(use-package! exwm-firefox-evil
  :after exwm
  :config
  ;; Add the firefox wm class name.
  (dolist (k `("firefox"))
    (cl-pushnew k exwm-firefox-evil-firefox-class-name))
  ;; Add the firefox buffer hook
  (add-hook 'exwm-manage-finish-hook
            'exwm-firefox-evil-activate-if-firefox))


;; (defun efs/polybar-exwm-workspace ()
;;   (pcase exwm-workspace-current-index
;;     (1 "")
;;     (2 "")
;;     (3 "")
;;     (4 "")
;;     (0 "")))

;; (defun efs/send-polybar-hook (module-name hook-index)
;;   (start-process-shell-command "polybar-msg" nil (format "polybar-msg hook %s %s" module-name hook-index)))

;; (defun efs/send-polybar-exwm-workspace ()
;;   (efs/send-polybar-hook "exwm" 1))

;; ;; Update panel indicator when workspace changes
;; (add-hook 'exwm-workspace-switch-hook #'efs/send-polybar-exwm-workspace)
