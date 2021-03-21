;;; os/exwm/config.el -*- lexical-binding: t; -*-

(server-start)
(setq counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
(setq dw/exwm-enabled t)

;; Define custom variables for the `exwm-update-class-hook' for users to
;; configure which buffers names should NOT be modified.
(defvar exwm/ignore-wm-prefix "sun-awt-X11-"
  "Don't rename exwm buffers with this prefix.")
(defvar exwm/ignore-wm-name "gimp"
  "Don't rename exwm buffers with this name.")

;; Make sure `exwm' windows can be restored when switching workspaces.
(defun exwm--update-utf8-title-advice (oldfun id &optional force)
  "Only update the window title when the buffer is visible."
  (when (get-buffer-window (exwm--id->buffer id))
    (funcall oldfun id force)))

;; Confgure `exwm' the X window manager for emacs.
(use-package! exwm
  :if dw/exwm-enabled
  :init
  (setq mouse-autoselect-window t
        focus-follows-mouse t
        exwm-workspace-warp-cursor t
        exwm-workspace-number 10)
  :config

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
  (add-hook 'exwm-init-hook #'dw/exwm-init-hook)
  ;; Manipulate windows as they're created
  (add-hook 'exwm-manage-finish-hook
            (lambda ()
              ;; Send the window where it belongs
              (dw/setup-window-by-class)))
  (exwm-layout-hide-mode-line)
  ;; Automatically move EXWM buffer to current workspace when selected
  (setq exwm-layout-show-all-buffers t)

  ;; Display all EXWM buffers in every workspace buffer list
  (setq exwm-workspace-show-all-buffers t)

  ;; Hide the modeline on all X windows
  (add-hook 'exwm-floating-setup-hook
            (lambda ()
              (exwm-layout-hide-mode-line)))
  ;; Configure global key bindings.
  (setq exwm-input-global-keys
        `(([?\s-r] . exwm-reset)
          ([?\s-w] . exwm-workspace-switch)

          ([?\s-d] . counsel-linux-app)
          ([?\s-f] . exwm-layout-toggle-fullscreen)

          ;; Move between windows
          ([s-left] . windmove-left)
          ([s-right] . windmove-right)
          ([s-up] . windmove-up)
          ([s-down] . windmove-down)
          ([?\s-r] . hydra-exwm-move-resize/body)

          ([?\s-e] . dired-jump)
          ([?\s-E] . (lambda () (interactive) (dired "~")))
          ([?\s-Q] . (lambda () (interactive) (kill-buffer)))

          ([?\s-&] . (lambda (command)
                       (interactive (list (read-shell-command "$ ")))
                       (start-process-shell-command command nil command)))
          ,@(mapcar (lambda (i)
                      `(,(kbd (format "s-%d" i)) .
                        (lambda ()
                          (interactive)
                          (exwm-workspace-switch-create ,i))))
                    (number-sequence 0 9))))

  ;; Configure the default buffer behaviour. All buffers created in `exwm-mode'
  ;; are named "*EXWM*". Change it in `exwm-update-class-hook' and `exwm-update-title-hook'
  ;; which are run when a new X window class name or title is available.
  (add-hook 'exwm-update-class-hook
            (lambda ()
              (unless (or (string-prefix-p exwm/ignore-wm-prefix exwm-instance-name)
                          (string= exwm/ignore-wm-name exwm-instance-name))
                (exwm-workspace-rename-buffer exwm-class-name))))
  (add-hook 'exwm-update-title-hook
            (lambda ()
              (when (or (not exwm-instance-name)
                        (string-prefix-p exwm/ignore-wm-prefix exwm-instance-name)
                        (string= exwm/ignore-wm-name exwm-instance-name))
                (exwm-workspace-rename-buffer exwm-title))))

  ;; Show `exwm' buffers in buffer switching prompts.
  (add-hook 'exwm-mode-hook #'doom-mark-buffer-as-real-h)

  ;; Restore window configurations involving exwm buffers by only changing names
  ;; of visible buffers.
  (advice-add #'exwm--update-utf8-title :around #'exwm--update-utf8-title-advice)

  ;; Enable the window manager.
  (exwm-enable))

;; Use the `ido' configuration for a few configuration fixes that alter
;; 'C-x b' workplace switching behaviour. This also effects the functionality
;; of 'SPC .' file searching in doom regardless of the users `ido' configuration.
(use-package! exwm-config
  :after exwm
  :config
  (exwm-config--fix/ido-buffer-window-other-frame))

;; Configure `exwm-randr' to support multi-monitor setups as well as
;; hot-plugging HDMI outputs. Read more at:
;; https://github.com/ch11ng/exwm/wiki#randr-multi-screen
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

;; Configure emacs input methods in all X windows.
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

;; Configure the rudamentary status bar.
(setq display-time-default-load-average nil)
(display-time-mode +1)
(display-battery-mode +1)

;; ;; Configure `exwm-firefox-*'.
;; (use-package! exwm-firefox-core
;;   :after exwm
;;   :config
;;   ;; Add the <ESC> key to the exwm input keys for firefox buffers.
;;   (dolist (k `(escape))
;;     (cl-pushnew k exwm-input-prefix-keys)))

;; ;; Configure further depending if the user has evil mode enabled.
;; (use-package! exwm-firefox-evil
;;   :after exwm
;;   :config
;;   ;; Add the firefox wm class name.
;;   (dolist (k `("firefox"))
;;     (cl-pushnew k exwm-firefox-evil-firefox-class-name))
;;   ;; Add the firefox buffer hook
;;   (add-hook 'exwm-manage-finish-hook
;;             'exwm-firefox-evil-activate-if-firefox))


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
  ;; Launch apps that will run in the background
  (exwm/run-in-background "dunst")
  (exwm/run-in-background "mpd")
  (exwm/run-in-background "kdeconnect-indicator")
  (exwm/run-in-background "mathpix-snipping-tool")
  (exwm/run-in-background "blueman-applet")
  (exwm/run-in-background "nm-applet")
  (exwm/run-in-background "picom --config ~/.config/picom/picom.conf")
  (exwm/run-in-background "redshift-gtk -l 27.7:85.3")
  (exwm/run-in-background "dropbox"))

(defun dw/run-xmodmap ()
  (interactive)
  (start-process-shell-command "xmodmap" nil "xmodmap ~/.Xmodmap")
  (start-process-shell-command "xcape" nil "xcape -e 'Control_L=Escape'"))
(defun dw/run-picom ()
  (interactive)
  (start-process-shell-command "picom" nil "picom ~/.config/picom/picom.conf"))
(defun dw/update-wallpapers ()
  (interactive)
  (start-process-shell-command
   "feh" nil
   (format "feh --bg-scale ~/Pictures/Wallpapers/vv3.png")))
(defun dw/nitro-update-wallpapers ()
  (interactive)
  (start-process-shell-command
   "nitrogen" nil
   (format "nitrogen --restore")))
(defun dw/configure-desktop ()
  (interactive)
  (dw/run-xmodmap)
  (dw/run-picom)
  (dw/nitro-update-wallpapers))
(defun dw/on-exwm-init ()
  (dw/configure-desktop))
  ;; (dw/start-panel))

(when dw/exwm-enabled

  ;; Set frame transparency
  (set-frame-parameter (selected-frame) 'alpha '(80 . 80))
  (add-to-list 'default-frame-alist '(alpha . (80 . 80)))
  (set-frame-parameter (selected-frame) 'fullscreen 'maximized)
  (add-to-list 'default-frame-alist '(fullscreen . maximized))


  (add-hook 'exwm-init-hook #'dw/on-exwm-init)

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

  ;; Ctrl+Q will enable the next key to be sent directly
  (define-key exwm-mode-map [?\C-q] 'exwm-input-send-next-key)
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


  ;; (setq dw/polybar-process nil)
  ;; (defun dw/kill-panel ()
  ;;   (interactive)
  ;;   (when dw/polybar-process
  ;;     (ignore-errors
  ;;       (kill-process dw/polybar-process)))
  ;;   (setq dw/polybar-process nil))
  ;; (defun dw/start-panel ()
  ;;   (interactive)
  ;;   (dw/kill-panel)
  ;;   (setq dw/polybar-process (start-process-shell-command "polybar" nil "polybar -c ~/.config/polybar/config.ini main")))

  ;; ;; Start the Polybar panel
  ;; ;; (dw/start-panel)

  ;; (defun efs/polybar-exwm-workspace ()
  ;;   (pcase exwm-workspace-current-index
  ;;     (1 "")
  ;;     (2 "")
  ;;     (3 "")
  ;;     (4 "")
  ;;     (5 "")
  ;;     (6 "")
  ;;     (7 "")
  ;;     (8 "")
  ;;     (9 "")
  ;;     (0 "")))
  ;; (defun efs/send-polybar-hook (module-name hook-index)
  ;;   (start-process-shell-command "polybar-msg" nil (format "polybar-msg hook %s %s" module-name hook-index)))
  ;; (defun efs/send-polybar-exwm-workspace ()
  ;;   (efs/send-polybar-hook "exwm" 1))
  ;; ;; Update panel indicator when workspace changes
  ;; (add-hook 'exwm-workspace-switch-hook #'efs/send-polybar-exwm-workspace)
  )

(use-package edwina
  :after exwm
  :config
  (setq display-buffer-base-action '(display-buffer-below-selected))
  (edwina-setup-dwm-keys)
  (edwina-mode 1))
