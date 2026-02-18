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
    "/sdcard/Pictures/Twitter"
    "/sdcard/Pictures/Screenshots"
    "/sdcard/DCIM/Screenshots")
  "List of directories to search for recent photos and screenshots.")

(defun my/android-get-latest-media-file ()
  "Find the most recently modified image file in `my/android-media-dirs` using `fd`.
Optimized for speed on Android by limiting to recent files (last 30 days)."
  (let* ((dirs (seq-filter #'file-exists-p my/android-media-dirs))
         (dir-args (mapconcat #'shell-quote-argument dirs " "))
         ;; Use fd to find files changed in last 30 days, then use ls -t to sort them
         (cmd (format "fd -e jpg -e jpeg -e png -e mp4 --type f --changed-within \"10 days\" --exclude .thumbnails . %s -X ls -t | head -n 1" dir-args)))
    (when dirs
      (let ((result (string-trim (shell-command-to-string cmd))))
        (unless (string-empty-p result)
          result)))))

(defvar my/android-captured-images-dir "attachments/captured-images"
  "Relative path within org-directory to store captured media.")

(defun my/org-attach-media ()
  "Attach the latest photo or screenshot to the current Org node.
Stores in `org-directory`/attachments/captured-images/YYYY-MM-DD/."
  (interactive)
  (let ((choice (read-char-choice "Attach: [c]amera or [l]atest? " '(?c ?l))))
    (when (eq choice ?c)
      (call-process-shell-command "am start -a android.media.action.STILL_IMAGE_CAMERA")
      (read-char "Take photo, return to Emacs, and press any key to continue..."))
    
    (let ((latest-file (my/android-get-latest-media-file)))
      (if (and latest-file (file-exists-p latest-file))
          (let* ((attrs (file-attributes latest-file))
                 (mtime (file-attribute-modification-time attrs))
                 (date-str (format-time-string "%Y-%m-%d" mtime))
                 (datetime-str (format-time-string "%Y-%m-%d %H:%M" mtime))
                 
                 ;; Destination setup
                 ;; Use project root to ensure dest and buffer share the same path prefix (e.g. ~/org)
                 ;; This fixes the "absolute path" issue when org-directory is /sdcard/org but buffer is ~/org/...
                 (base-dir (or (doom-project-root) org-directory))
                 (ext (file-name-extension latest-file))
                 (ts (format-time-string "%Y%m%d_%H%M%S" mtime))
                 (new-filename (format "%s.%s" ts ext))
                 (dest-root (expand-file-name my/android-captured-images-dir base-dir))
                 (dest-dir (expand-file-name date-str dest-root))
                 (dest-file (expand-file-name new-filename dest-dir))
                 
                 ;; Link setup
                 (caption (read-string "Caption (optional): "))
                 (description (if (string-empty-p caption)
                                  datetime-str
                                (format "%s %s" datetime-str caption)))
                 (relative-path (file-relative-name dest-file (file-name-directory (buffer-file-name)))))
            
            (unless (file-exists-p dest-dir)
              (make-directory dest-dir t))
            
            (copy-file latest-file dest-file)
            (insert (format "[[file:%s][%s]]" relative-path description))
            (org-display-inline-images)
            (message "Attached: %s" new-filename))
        (error "No media files found in: %s" (string-join my/android-media-dirs ", "))))))


(setq browse-url-browser-function 'browse-url-xdg-open)
(add-to-list 'org-file-apps '("\\.pdf\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.png\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.jpg\\'" . "termux-open %s"))
(add-to-list 'org-file-apps '("\\.jpeg\\'" . "termux-open %s"))

;; Function to open files using browse-url-xdg-open with file:// URLs
(defun my-open-file-xdg (file)
  "Open FILE using browse-url-xdg-open as a file:// URL."
  (let ((url (concat "file://" (expand-file-name file))))
    (condition-case err
        (browse-url-xdg-open url)
      (error (message "Failed to open %s: %s" file err)))))

(provide 'android-extras)
;;; android-extras.el ends here
