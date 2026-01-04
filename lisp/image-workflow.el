;;; image-workflow.el --- Image processing workflow -*- lexical-binding: t; -*-

;;; Commentary:
;; Image-mode workflow for processing and tagging photos.
;; Works on both Mac and Android with platform-specific paths.

;;; Code:

;; Platform-specific paths
(defvar my-image-index-file (concat org-directory "imageindex.csv")
  "CSV file to store image index with tags.")

(defvar my-image-processed-dir
  (if (eq system-type 'android)
      "/sdcard/Pictures/S23/Processed/"
    (expand-file-name "~/Pictures/Processed/"))
  "Directory to move processed images to.")

(defvar my-image-tags '("personal" "work" "meditation" "books" "research"
                        "learningnote" "todo" "meme" "dance" "music" "movie"
                        "wise" "quote" "money" "health" "food" "travel" "nature"
                        "design" "art" "gif" "funny" "tech" "reference" "favorite"
                        "strange" "party" "qr" "raw" "wallpaper" "memory")
  "Default list of image tags.")

(after! image-mode
  (defun my/delete-image-and-next ()
    "Move to the next image and delete the previous one."
    (interactive)
    (let ((previous-file (buffer-file-name)))
      (if (and (eq major-mode 'image-mode) (image-next-file 1))
          (when previous-file
            (delete-file previous-file)
            (message "Deleted file %s" previous-file)))))

  (defun read-tags-from-csv (csv-file)
    "Read tags from CSV-FILE and return frequency-sorted list."
    (let ((tag-counts (make-hash-table :test 'equal)))
      (when (file-exists-p csv-file)
        (with-temp-buffer
          (insert-file-contents csv-file)
          (while (not (eobp))
            (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                   (elements (split-string line "," t))
                   (tags (cdr elements)))
              (dolist (tag tags)
                (let ((trimmed-tag (string-trim tag)))
                  (when (not (string-empty-p trimmed-tag))
                    (puthash trimmed-tag (1+ (gethash trimmed-tag tag-counts 0)) tag-counts))))
              (forward-line 1)))))
      (let ((sorted-tags (sort (hash-table-keys tag-counts)
                               (lambda (a b) (> (gethash a tag-counts) (gethash b tag-counts))))))
        (append sorted-tags my-image-tags))))

  (defun set-image-tags-and-rename-and-next ()
    "Set tags, rename and move image to processed directory."
    (interactive)
    (unless (eq major-mode 'image-mode)
      (error "Not in an image-mode buffer"))
    ;; Ensure processed directory exists
    (unless (file-directory-p my-image-processed-dir)
      (make-directory my-image-processed-dir t))
    (let* ((file (buffer-file-name))
           (all-tags (read-tags-from-csv my-image-index-file))
           (selected-tags (completing-read-multiple "Select tags: " all-tags nil t))
           (final-tags (seq-filter (lambda (tag) (not (string-empty-p tag)))
                                   (mapcar #'string-trim selected-tags)))
           (extension (file-name-extension file))
           (first-tag (car final-tags))
           (new-base-name (replace-regexp-in-string "[ ,]" "_" (file-name-base file)))
           (new-name (concat (if first-tag (concat first-tag "--" new-base-name) new-base-name)
                             "." extension))
           (processed-path (expand-file-name new-name my-image-processed-dir))
           (index-entry (format "%s,%s\n" processed-path (string-join final-tags ", "))))
      (when file
        (evil-save file t)
        (rename-file file processed-path)
        (with-temp-buffer
          (insert index-entry)
          (append-to-file (point-min) (point-max) my-image-index-file))
        (message "Moved to %s with tags: %s" processed-path (string-join final-tags ", ")))
      (my/delete-image-and-next)))

  (defun my/save-cropped-image (filename)
    "Save the current buffer's image to FILENAME."
    (interactive "F")
    (let ((image (image-get-display-property)))
      (when image
        (let ((data (plist-get (cdr image) :data)))
          (unless data (error "No image data available"))
          (with-temp-file filename (insert data))
          (message "Image saved to %s" filename)))))

  (defun my/crop-save-tags-rename-and-next ()
    "Crop, save, tag, rename and move to next image."
    (interactive)
    (unless (eq major-mode 'image-mode)
      (error "Not in an image-mode buffer"))
    (image-crop)
    (execute-kbd-macro (kbd "ESC ESC ESC"))
    (let ((file (buffer-file-name)))
      (when file (my/save-cropped-image file)))
    (revert-buffer t t)
    (set-image-tags-and-rename-and-next))

  (defun image-previous-file-nofreeze (&optional n)
    "Visit the preceding image without freezing."
    (interactive "p" image-mode)
    (unless (derived-mode-p 'image-mode)
      (error "The buffer is not in Image mode"))
    (unless buffer-file-name
      (error "The current image is not associated with a file"))
    (let* ((n (or n 1))
           (file buffer-file-name)
           (dir (file-name-directory file))
           (files (sort (directory-files dir t (image-file-name-regexp)) #'string<))
           (index (cl-position file files :test #'string-equal)))
      (if (or (null index) (<= index (1- n)))
          (user-error "No previous image file")
        (find-alternate-file (nth (- index n) files)))))

  (map! :map image-mode-map
        :nvm "q" #'image-kill-buffer
        :nvm "c" #'my/crop-save-tags-rename-and-next
        :nvm "d" #'my/delete-image-and-next
        :nvm "e" #'set-image-tags-and-rename-and-next
        :nvm "C-j" #'image-next-line
        :nvm "C-k" #'image-previous-line
        :nvm "j" #'image-next-file
        :nvm "k" #'image-previous-file-nofreeze))

(provide 'image-workflow)
;;; image-workflow.el ends here
