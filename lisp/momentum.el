;;; momentum.el --- Visual progress tracker with image sequences -*- lexical-binding: t; -*-

;;; Commentary:
;; Collect images into "momentum" sequences to track visual progress over time.
;; Sequences are org-roam notes tagged with "momentum".
;;
;; Usage:
;;   From dired or image-mode, call `momentum-add-image' to add current image
;;   to a momentum sequence. Creates dated entries with inline images.
;;
;; Commands:
;;   momentum-add-image    - Add current image to a sequence
;;   momentum-new-sequence - Create a new momentum sequence
;;   momentum-view         - Open a momentum sequence

;;; Code:

(require 'org-roam)

(defgroup momentum nil
  "Visual progress tracker with image sequences."
  :group 'org-roam)

(defcustom momentum-tag "momentum"
  "Tag used to identify momentum sequence notes."
  :type 'string
  :group 'momentum)

(defcustom momentum-image-width 400
  "Default width for inline images in momentum sequences."
  :type 'integer
  :group 'momentum)

(defcustom momentum-images-dir (expand-file-name "attachments/momentum" org-directory)
  "Directory where momentum images are stored, organized by sequence."
  :type 'string
  :group 'momentum)

(defun momentum--get-sequences ()
  "Get list of all momentum sequences (org-roam nodes with momentum tag)."
  (seq-filter
   (lambda (node)
     (member momentum-tag (org-roam-node-tags node)))
   (org-roam-node-list)))

(defun momentum--select-sequence ()
  "Prompt user to select a momentum sequence, or type new name to create.
If input doesn't match existing sequence, creates new one with that title."
  (let* ((sequences (momentum--get-sequences))
         (choices (mapcar (lambda (node)
                            (cons (org-roam-node-title node) node))
                          sequences))
         (selection (completing-read "Momentum sequence (or type new): "
                                     (mapcar #'car choices)
                                     nil nil)))
    (cond
     ;; No input
     ((or (null selection) (string-empty-p selection))
      (user-error "No sequence selected"))
     ;; Matches existing sequence
     ((assoc selection choices)
      (cdr (assoc selection choices)))
     ;; New sequence - use input as title
     (t
      (momentum--create-sequence selection)))))

(defun momentum--sequence-images-dir (title)
  "Return the images directory for sequence with TITLE, creating if needed."
  (let* ((slug (replace-regexp-in-string "[^a-zA-Z0-9]+" "-" (downcase title)))
         (dir (expand-file-name slug momentum-images-dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    dir))

(defun momentum--create-sequence (title)
  "Create a new momentum sequence with TITLE and return the node."
  (let* ((slug (replace-regexp-in-string "[^a-zA-Z0-9]+" "-" (downcase title)))
         (node (org-roam-node-create :title title)))
    ;; Use org-roam-capture to create the node properly
    (org-roam-capture-
     :node node
     :templates `(("m" "momentum" plain "%?"
                   :if-new (file+head
                            ,(format "%s-momentum.org" slug)
                            ,(format "#+title: %s\n#+filetags: :%s:\n\n* Progress\n" title momentum-tag))
                   :immediate-finish t
                   :unnarrowed t)))
    ;; Sync db and get the node
    (org-roam-db-sync)
    ;; Find and return the newly created node
    (car (seq-filter
          (lambda (n) (string= (org-roam-node-title n) title))
          (momentum--get-sequences)))))

(defun momentum-new-sequence ()
  "Interactively create a new momentum sequence."
  (interactive)
  (let ((title (read-string "Sequence name: ")))
    (momentum--create-sequence title)))

(defun momentum--get-image-path ()
  "Get image path from current context (dired or image-mode)."
  (cond
   ((derived-mode-p 'dired-mode)
    (let ((file (dired-get-file-for-visit)))
      (if (and file (string-match-p "\\.\\(png\\|jpg\\|jpeg\\|gif\\|webp\\|bmp\\)$" file))
          file
        (user-error "Not an image file"))))
   ((derived-mode-p 'image-mode)
    (buffer-file-name))
   (t
    (user-error "Not in dired or image-mode"))))

(defun momentum--copy-image-to-sequence (image-path node)
  "Copy IMAGE-PATH to NODE's sequence directory, return new path."
  (let* ((title (org-roam-node-title node))
         (dest-dir (momentum--sequence-images-dir title))
         (timestamp (format-time-string "%Y%m%d-%H%M%S"))
         (ext (file-name-extension image-path))
         (new-name (format "%s.%s" timestamp ext))
         (new-path (expand-file-name new-name dest-dir)))
    ;; Copy image
    (copy-file image-path new-path t)
    new-path))

(defun momentum--add-entry (node image-path)
  "Add an entry with IMAGE-PATH to NODE's org file."
  (let* ((node-file (org-roam-node-file node))
         (relative-path (file-relative-name image-path (file-name-directory node-file)))
         (date-heading (format-time-string "%Y-%m-%d %A"))
         (timestamp (format-time-string "[%Y-%m-%d %a %H:%M]"))
         (note (read-string "Note (optional): ")))
    (with-current-buffer (find-file-noselect node-file)
      ;; Go to end of Progress section or end of file
      (goto-char (point-min))
      (if (re-search-forward "^\\* Progress" nil t)
          (org-end-of-subtree)
        (goto-char (point-max)))
      (insert (format "\n** %s\n%s\n" date-heading timestamp))
      (when (not (string-empty-p note))
        (insert (format "%s\n\n" note)))
      (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n"
                      momentum-image-width relative-path))
      (save-buffer)
      (message "Added to %s" (org-roam-node-title node)))))

;;;###autoload
(defun momentum-add-image ()
  "Add current image to a momentum sequence.
Works from dired-mode (on an image file) or image-mode."
  (interactive)
  (let* ((image-path (momentum--get-image-path))
         (node (momentum--select-sequence)))
    (when node
      (let ((new-path (momentum--copy-image-to-sequence image-path node)))
        (momentum--add-entry node new-path)))))

;;;###autoload
(defun momentum-view ()
  "Open a momentum sequence for viewing."
  (interactive)
  (let ((node (momentum--select-sequence)))
    (when node
      (find-file (org-roam-node-file node))
      (org-display-inline-images))))

;;; Keybindings for dired and image-mode

(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c m") #'momentum-add-image))

(with-eval-after-load 'image-mode
  (define-key image-mode-map (kbd "m") #'momentum-add-image))

(with-eval-after-load 'evil
  (evil-define-key 'normal image-mode-map
    "m" #'momentum-add-image))

(provide 'momentum)
;;; momentum.el ends here
