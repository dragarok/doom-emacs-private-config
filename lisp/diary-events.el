;;; diary-events.el --- Events diary mode for capturing daily photos -*- lexical-binding: t; -*-

;;; Commentary:
;; Browse today's photos and add them to org-roam daily notes.
;; Images are copied to org-directory/diary-images/YYYY-MM-DD/

;;; Code:

(require 'image-mode)
(require 'org-roam-dailies nil t)

;;; Configuration

(defvar my/diary-photo-source-dir "~/PicturesShared/S23/"
  "Primary source directory where phone photos are synced.")

(defvar my/diary-photo-extra-dirs nil
  "Additional directories to search for photos.
These are searched in addition to `my/diary-photo-source-dir'.
Useful for phone environments with multiple photo locations.

Example:
  (setq my/diary-photo-extra-dirs
        \\='(\"~/storage/DCIM/Camera/\"
          \"~/storage/DCIM/Screenshots/\"
          \"~/storage/Download/\"
          \"~/storage/Pictures/WhatsApp/\"))")

;; Automatically add common Android directories if on Android
(when (eq system-type 'android)
  (setq my/diary-photo-extra-dirs
        (append '("/sdcard/DCIM"
                  "/sdcard/Pictures"
                  "/sdcard/Download")
                my/diary-photo-extra-dirs)))

(defvar my/diary-images-dir (expand-file-name "attachments/diary-images" org-directory)
  "Directory where diary images are stored, organized by date.")

(defvar my/diary-image-extensions '("jpg" "jpeg" "png" "gif" "heic" "webp")
  "Image file extensions to consider.")

;;; Helper Functions

(defun my/diary-today-string ()
  "Return today's date as YYYY-MM-DD string."
  (format-time-string "%Y-%m-%d"))

(defun my/diary-today-images-dir ()
  "Return the directory for today's diary images, creating if needed."
  (my/diary-images-dir-for-date (my/diary-today-string)))

(defun my/diary-images-dir-for-date (date-string)
  "Return the directory for DATE-STRING's diary images, creating if needed."
  (let ((dir (expand-file-name date-string my/diary-images-dir)))
    (unless (file-exists-p dir)
      (make-directory dir t))
    dir))

(defun my/diary-file-modified-today-p (file)
  "Return t if FILE was modified today."
  (my/diary-file-modified-on-date-p file (my/diary-today-string)))

(defun my/diary-file-modified-on-date-p (file date-string)
  "Return t if FILE was modified on DATE-STRING (YYYY-MM-DD)."
  (let* ((attrs (file-attributes file))
         (mtime (file-attribute-modification-time attrs))
         (file-date (format-time-string "%Y-%m-%d" mtime)))
    (string= file-date date-string)))

(defun my/diary-all-source-dirs ()
  "Return list of all source directories to search."
  (seq-filter #'file-directory-p
              (mapcar #'expand-file-name
                      (cons my/diary-photo-source-dir
                            my/diary-photo-extra-dirs))))

(defun my/diary-image-file-p (filename)
  "Return t if FILENAME is an image file."
  (let ((ext (downcase (or (file-name-extension filename) ""))))
    (member ext my/diary-image-extensions)))

(defun my/diary-get-today-images ()
  "Get list of images modified today."
  (my/diary-get-images-for-date (my/diary-today-string)))

(defun my/diary-get-images-for-date (date-string)
  "Get list of images modified on DATE-STRING from all source directories RECURSIVELY.
Searches `my/diary-photo-source-dir' and `my/diary-photo-extra-dirs'.
Returns files sorted by modification time (most recent first)."
  (let ((all-images '()))
    (dolist (dir (my/diary-all-source-dirs))
      (when (file-directory-p dir)
        (dolist (file (directory-files-recursively dir "." nil))
          (when (and (my/diary-image-file-p file)
                     (my/diary-file-modified-on-date-p file date-string))
            (push file all-images)))))
    ;; Sort by mtime (newest first)
    (sort all-images
          (lambda (a b)
            (time-less-p (file-attribute-modification-time (file-attributes b))
                         (file-attribute-modification-time (file-attributes a)))))))

(defun my/diary-generate-unique-name (original-path dest-dir)
  "Generate a unique filename in DEST-DIR based on ORIGINAL-PATH."
  (let* ((base (file-name-base original-path))
         (ext (file-name-extension original-path))
         (new-name (format "%s.%s" base ext))
         (full-path (expand-file-name new-name dest-dir))
         (counter 1))
    ;; If file exists, append counter
    (while (file-exists-p full-path)
      (setq new-name (format "%s_%d.%s" base counter ext))
      (setq full-path (expand-file-name new-name dest-dir))
      (setq counter (1+ counter)))
    full-path))

;;; Main Functions

(defun my/diary-browse-today-images ()
  "Open image-mode buffer showing today's photos."
  (interactive)
  (my/diary-browse-images-for-date (my/diary-today-string)))

(defun my/diary-browse-yesterday-images ()
  "Open image-mode buffer showing yesterday's photos."
  (interactive)
  (my/diary-browse-images-for-date
   (format-time-string "%Y-%m-%d" (time-subtract nil (* 24 60 60)))))

(defun my/diary-browse-images ()
  "Browse images for a specific date (prompts with date picker)."
  (interactive)
  (my/diary-browse-images-for-date
   (org-read-date nil nil nil "Browse images for date: ")))

(defun my/diary-browse-images-for-date (date-string)
  "Open image-mode buffer showing photos from DATE-STRING.
Only shows images modified on that date, sorted by most recent first."
  (let ((images (my/diary-get-images-for-date date-string))
        (dirs-searched (my/diary-all-source-dirs)))
    (if images
        (progn
          ;; Open most recent image directly in image-mode for quick browsing
          (find-file (car images))
          (message "Found %d images from %s. j/k=navigate, a/A=add, C-u a=other date, s=skip"
                   (length images)
                   date-string))
      (message "No images from %s in: %s"
               date-string
               (string-join (mapcar #'abbreviate-file-name dirs-searched) ", ")))))

(defun my/diary-browse-today-dired ()
  "Open dired buffer showing today's photos from all source directories."
  (interactive)
  (let ((today-images (my/diary-get-today-images)))
    (if today-images
        ;; Use dired with full paths (virtual dired style)
        (dired (cons "Today's Photos" today-images))
      (message "No images from today in configured directories"))))

(defun my/diary-add-image-to-today (&optional date)
  "Add current image to today's diary (or DATE if specified).
Copies image to diary-images directory and inserts link in daily note.
With prefix arg C-u, prompt for date."
  (interactive
   (list (when current-prefix-arg
           (org-read-date nil nil nil "Add to which date? "))))
  (my/diary-add-image-internal date t))

(defun my/diary-add-image-quick (&optional date)
  "Quickly add current image to diary without caption prompt.
With prefix arg C-u, prompt for date."
  (interactive
   (list (when current-prefix-arg
           (org-read-date nil nil nil "Add to which date? "))))
  (my/diary-add-image-internal date nil))

(defun my/diary-add-image-internal (date prompt-caption)
  "Internal function to add image to diary.
DATE is the target date (nil for today).
PROMPT-CAPTION if non-nil, ask for caption."
  (unless (eq major-mode 'image-mode)
    (error "Not in an image-mode buffer"))

  (let* ((date-string (or date (my/diary-today-string)))
         (source-file (buffer-file-name))
         (dest-dir (my/diary-images-dir-for-date date-string))
         (dest-file (my/diary-generate-unique-name source-file dest-dir))
         (daily-file (my/diary-get-or-create-daily date-string))
         (daily-dir (file-name-directory daily-file))
         ;; Relative path from daily note location to image
         (relative-path (file-relative-name dest-file daily-dir))
         (caption (if prompt-caption
                      (read-string "Caption (optional): ")
                    ""))
         (attrs (file-attributes source-file))
         (mtime (file-attribute-modification-time attrs))
         (datetime-str (format-time-string "%Y-%m-%d %H:%M" mtime))
         (description (if (string-empty-p caption)
                          datetime-str
                        (format "%s %s" datetime-str caption)))
         (org-link (format "#+attr_org: :width 600px\n[[file:%s][%s]]"
                           relative-path
                           description)))

    ;; Copy the image
    (copy-file source-file dest-file)
    (message "Copied to %s" dest-file)

    ;; Insert link into daily note
    (my/diary-insert-into-daily org-link)

    ;; Move to next image
    (when (image-next-file 1)
      (message "Added to diary. Moved to next image."))))

(defun my/diary-insert-into-daily (content)
  "Insert CONTENT into today's org-roam daily note."
  (let ((daily-file (my/diary-get-or-create-daily)))
    (with-current-buffer (find-file-noselect daily-file)
      (goto-char (point-max))
      ;; Add under a "Photos" heading if it exists, otherwise at end
      (if (re-search-backward "^\\*+ Photos" nil t)
          (progn
            (org-end-of-subtree)
            (insert "\n" content "\n"))
        ;; Create Photos heading if not exists
        (insert "\n* Photos\n" content "\n"))
      (save-buffer)
      (message "Added to daily note: %s" daily-file))))

(defun my/diary-get-or-create-daily (&optional date-string)
  "Get or create daily note file path for DATE-STRING (default today).
Works with org-roam-dailies if available, otherwise uses simple dated file."
  (let ((date (or date-string (my/diary-today-string))))
    (if (and (featurep 'org-roam-dailies)
             (boundp 'org-roam-dailies-directory))
        ;; Use org-roam-dailies
        (let* ((daily-dir (expand-file-name org-roam-dailies-directory org-roam-directory))
               (daily-file (expand-file-name (concat date ".org") daily-dir)))
          (unless (file-exists-p daily-file)
            ;; Create via org-roam-dailies to get proper template
            (save-window-excursion
              (org-roam-dailies-goto-date date)
              (save-buffer)))
          daily-file)
      ;; Fallback: simple dated file in org-directory
      (let ((daily-file (expand-file-name
                         (concat "daily/" date ".org")
                         org-directory)))
        (unless (file-exists-p daily-file)
          (make-directory (file-name-directory daily-file) t)
          (with-temp-file daily-file
            (insert (format "#+title: %s\n\n" date))))
        daily-file))))

(defun my/diary-add-and-next ()
  "Add current image to diary and move to next."
  (interactive)
  (my/diary-add-image-to-today))

(defun my/diary-skip-and-next ()
  "Skip current image without adding to diary."
  (interactive)
  (if (image-next-file 1)
      (message "Skipped. Moved to next image.")
    (message "No more images.")))

;;; Keybindings

(with-eval-after-load 'image-mode
  (define-key image-mode-map (kbd "a") #'my/diary-add-image-to-today)
  (define-key image-mode-map (kbd "A") #'my/diary-add-image-quick)
  (define-key image-mode-map (kbd "s") #'my/diary-skip-and-next))

;; For evil mode users
(with-eval-after-load 'evil
  (evil-define-key 'normal image-mode-map
    "a" #'my/diary-add-image-to-today
    "A" #'my/diary-add-image-quick
    "s" #'my/diary-skip-and-next))

(provide 'diary-events)
;;; diary-events.el ends here
