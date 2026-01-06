;;; android-extras.el --- Android-specific utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Extra Android-specific functions for Termux Emacs.
;; Includes touch-screen keyboard control and dired xdg-open.

;;; Code:

;; ──────────────────────────────────────────────────────────────
;; Touch-screen keyboard full control – 3 modes
;; ──────────────────────────────────────────────────────────────

(defvar my/keyboard-mode 'normal
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
