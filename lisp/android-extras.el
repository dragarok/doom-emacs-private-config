;;; android-extras.el --- Android-specific utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Extra Android-specific functions for Termux Emacs.
;; Includes touch-screen keyboard control and dired xdg-open.

;;; Code:

;; ──────────────────────────────────────────────────────────────
;; Touch-screen keyboard full control – 3 modes
;; ──────────────────────────────────────────────────────────────

(defvar my/keyboard-mode 'always-on
  "Keyboard mode: 'normal, 'always-on, or 'off.
- normal: Default behavior, keyboard shows when tapping editable areas
- always-on: Keyboard always visible regardless of buffer
- off: Keyboard completely suppressed")

(defun my/touch-screen-keyboard-decide (&rest _)
  "Decide whether to show keyboard based on current mode."
  (pcase my/keyboard-mode
    ('always-on t)      ; Always allow keyboard
    ('off nil)          ; Never show
    (_ t)))             ; normal - let Emacs decide

;; Critical: use `add-function' with :around so we completely override whatever
;; Emacs or other packages (Doom, etc.) might have set before or after us.
(add-function :around touch-screen-keyboard-function #'my/touch-screen-keyboard-decide)

(defun my/cycle-keyboard-mode ()
  "Cycle through keyboard modes: normal -> always-on -> off -> normal."
  (interactive)
  (setq my/keyboard-mode
        (pcase my/keyboard-mode
          ('normal 'always-on)
          ('always-on 'off)
          ('off 'normal)))
  ;; For always-on, immediately show keyboard
  (when (eq my/keyboard-mode 'always-on)
    (frame-toggle-on-screen-keyboard nil nil))
  ;; For off, hide keyboard immediately
  (when (eq my/keyboard-mode 'off)
    (frame-toggle-on-screen-keyboard nil t))
  (message "Keyboard mode: %s" my/keyboard-mode))

;; Keep old function name as alias for compatibility
(defalias 'my/toggle-touch-keyboard 'my/cycle-keyboard-mode)

;; Show keyboard at startup if mode is always-on
(when (eq my/keyboard-mode 'always-on)
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-timer 0.5 nil
                              (lambda ()
                                (frame-toggle-on-screen-keyboard nil nil))))))

;; ──────────────────────────────────────────────────────────────
;; Dired xdg-open integration
;; ──────────────────────────────────────────────────────────────

(defun my-dired-open-xdg ()
  "Open the file at point in Dired using browse-url-xdg-open."
  (interactive)
  (let ((file (dired-get-file-for-visit)))
    (if (file-exists-p file)
        (browse-url-xdg-open file)
      (error "File does not exist: %s" file))))

(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c o") #'my-dired-open-xdg))

;; ──────────────────────────────────────────────────────────────
;; Vterm Termux shell
;; ──────────────────────────────────────────────────────────────

(after! vterm
  (setq vterm-shell "/data/data/com.termux/files/usr/bin/bash"))

;; ──────────────────────────────────────────────────────────────
;; Android UI settings
;; ──────────────────────────────────────────────────────────────

;; Always confirm before quitting on Android
(setq confirm-kill-emacs 'y-or-n-p)

;; ──────────────────────────────────────────────────────────────
;; Camera & Screenshot Attachment
;; ──────────────────────────────────────────────────────────────

(defvar my/android-media-dirs
  '("/sdcard/DCIM/Camera"
    "/sdcard/Pictures/Screenshots"
    "/sdcard/DCIM/Screenshots")
  "List of directories to search for recent photos and screenshots.")

(defun my/android-get-latest-media-file ()
  "Find the most recently modified file in `my/android-media-dirs`."
  (let ((files '()))
    (dolist (dir my/android-media-dirs)
      (when (file-directory-p dir)
        (dolist (file (directory-files dir t "^[^.]" t)) ; Skip . and ..
          (unless (file-directory-p file)
            (push file files)))))
    (car (sort files
               (lambda (a b)
                 (time-less-p (file-attribute-modification-time (file-attributes b))
                              (file-attribute-modification-time (file-attributes a))))))))

(defun my/org-attach-media ()
  "Attach the latest photo or screenshot to the current Org node.
Prompts to open Camera or just use the latest existing file."
  (interactive)
  (let ((choice (read-char-choice "Attach: [c]amera or [l]atest? " '(?c ?l))))
    (when (eq choice ?c)
      (call-process-shell-command "am start -a android.media.action.STILL_IMAGE_CAMERA")
      (read-char "Take photo, return to Emacs, and press any key to continue..."))
    
    (let ((latest-file (my/android-get-latest-media-file)))
      (if (and latest-file (file-exists-p latest-file))
          (let* ((ext (file-name-extension latest-file))
                 (ts (format-time-string "%Y%m%d_%H%M%S"))
                 (new-name (format "%s.%s" ts ext)))
            ;; We manually copy and attach to avoid moving (deleting) the source
            (org-attach-attach latest-file nil 'cp)
            ;; Rename the attachment to be cleaner (timestamp based) if needed, 
            ;; but org-attach-attach keeps filename. Let's rely on standard attach.
            (insert (format "[[attachment:%s]]" (file-name-nondirectory latest-file)))
            (org-display-inline-images)
            (message "Attached: %s" (file-name-nondirectory latest-file)))
        (error "No media files found in configured directories")))))

(provide 'android-extras)
;;; android-extras.el ends here
