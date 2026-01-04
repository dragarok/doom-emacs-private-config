;;; android-extras.el --- Android-specific utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Extra Android-specific functions for Termux Emacs.
;; Includes touch-screen keyboard control and dired xdg-open.

;;; Code:

;; ──────────────────────────────────────────────────────────────
;; Touch-screen keyboard full control – fixed & minimal
;; ──────────────────────────────────────────────────────────────

(defvar my/keyboard-auto-show t
  "Internal: t = normal Emacs behaviour, nil = completely suppress auto keyboard.")

(defun my/touch-screen-keyboard-decide (&rest _)
  "Decide whether Emacs is allowed to show the on-screen keyboard automatically.
This is called on every tap in a writable buffer."
  my/keyboard-auto-show)

;; Critical: use `add-function' with :around so we completely override whatever
;; Emacs or other packages (Doom, etc.) might have set before or after us.
(add-function :around touch-screen-keyboard-function #'my/touch-screen-keyboard-decide)

(defun my/toggle-touch-keyboard ()
  "Toggle automatic on-screen keyboard.
When OFF → keyboard never appears on tap.
When ON  → back to normal behaviour."
  (interactive)
  (setq my/keyboard-auto-show (not my/keyboard-auto-show))
  (message "Touch keyboard auto-show → %s"
           (if my/keyboard-auto-show "ON" "OFF")))

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

(provide 'android-extras)
;;; android-extras.el ends here
