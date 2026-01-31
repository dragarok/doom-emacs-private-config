;;; notable.el --- PKM integration for Notable e-ink notebook -*- lexical-binding: t; -*-

;; Author: Alok Regmi
;; Version: 1.0.0
;; Package-Requires: ((emacs "28.1") (transient "0.4.0"))

;;; Commentary:
;; A transient-based interface for managing Notable notebooks from Emacs.
;; Device-aware: different features available on Boox, Android, and desktop.
;;
;; Feature availability:
;; - Create (folder/book/page): Boox only (IS-ONYX)
;; - Open/Export: Any Android device (IS-ANDROID)
;; - Insert links: All devices (desktop, Android, Boox)
;; - Sync index: Any Android device (IS-ANDROID)

;;; Code:

(require 'transient)
(require 'json)
(require 'org-id)

;;;; Device Detection
;; These variables should be defined in config.el, but we provide fallbacks

(defvar IS-ANDROID (eq system-type 'android)
  "Are we running on Android?")

(defvar IS-ONYX (and (boundp 'IS-ANDROID) IS-ANDROID
                     (boundp 'android-build-fingerprint)
                     (string-prefix-p "ONYX" android-build-fingerprint))
  "Are we running on an Onyx Boox e-reader?")

;;;; Configuration

(defgroup notable nil
  "Notable e-ink notebook integration."
  :group 'applications)

(defcustom notable-index-file
  (if IS-ANDROID
      (expand-file-name "Documents/notabledb/notable-index.json"
                        (or (getenv "EXTERNAL_STORAGE") "/sdcard"))
    nil)
  "Path to the Notable index JSON file.
Only relevant on Android devices."
  :type '(choice file (const nil))
  :group 'notable)

;;;; Index Reading

(defvar notable--index-cache nil
  "Cached Notable index data.")

(defvar notable--index-mtime nil
  "Last modification time of the index file.")

(defun notable--read-index ()
  "Read and cache the Notable index.
Returns cached data if file hasn't changed."
  (when (and notable-index-file (file-exists-p notable-index-file))
    (let ((mtime (file-attribute-modification-time
                  (file-attributes notable-index-file))))
      (when (or (null notable--index-cache)
                (not (equal mtime notable--index-mtime)))
        (setq notable--index-cache (json-read-file notable-index-file))
        (setq notable--index-mtime mtime)))
    notable--index-cache))

(defun notable--get-folders ()
  "Get list of folders from index."
  (when-let ((index (notable--read-index)))
    (append (alist-get 'folders index) nil)))

(defun notable--get-notebooks ()
  "Get list of notebooks from index."
  (when-let ((index (notable--read-index)))
    (append (alist-get 'notebooks index) nil)))

(defun notable--get-pages ()
  "Get list of pages from index."
  (when-let ((index (notable--read-index)))
    (append (alist-get 'pages index) nil)))

(defun notable--get-export-formats ()
  "Get available export formats."
  (if-let ((index (notable--read-index)))
      (append (alist-get 'exportFormats index) nil)
    '("pdf" "png" "jpg" "xopp")))

;;;; Deep Link Invocation

(defun notable--invoke-link (url)
  "Invoke a Notable deep link URL.
On Android, uses `am start`. On other platforms, just shows the link."
  (if IS-ANDROID
      (start-process "notable" nil
                     "am" "start" "-a" "android.intent.action.VIEW"
                     "-d" url)
    (message "Notable link (not on Android): %s" url)))

;;;; Android Operations (Open, Export, Sync)

(defun notable-sync-index ()
  "Force Notable to refresh its index."
  (interactive)
  (unless IS-ANDROID
    (user-error "Sync only available on Android"))
  (notable--invoke-link "notable://sync-index")
  (message "Syncing Notable index...")
  (run-at-time 3 nil (lambda ()
                       (setq notable--index-cache nil)
                       (notable--read-index)
                       (message "Notable index refreshed"))))

(defun notable-open-page (page-id)
  "Open a page by PAGE-ID."
  (interactive
   (list (notable--select-page "Open page: ")))
  (unless IS-ANDROID
    (user-error "Open only available on Android"))
  (when page-id
    (notable--invoke-link (format "notable://page-%s" page-id))))

(defun notable-open-book (book-id)
  "Open a book by BOOK-ID."
  (interactive
   (list (notable--select-notebook "Open book: ")))
  (unless IS-ANDROID
    (user-error "Open only available on Android"))
  (when book-id
    (notable--invoke-link (format "notable://book-%s" book-id))))

(defun notable-export-page (page-id format)
  "Export PAGE-ID to FORMAT."
  (interactive
   (list (notable--select-page "Export page: ")
         (completing-read "Format: " (notable--get-export-formats) nil t)))
  (unless IS-ANDROID
    (user-error "Export only available on Android"))
  (when page-id
    (notable--invoke-link (format "notable://export/page/%s?format=%s" page-id format))
    (message "Exporting page as %s..." format)))

(defun notable-export-book (book-id format)
  "Export BOOK-ID to FORMAT."
  (interactive
   (list (notable--select-notebook "Export book: ")
         (completing-read "Format: " (notable--get-export-formats) nil t)))
  (unless IS-ANDROID
    (user-error "Export only available on Android"))
  (when book-id
    (notable--invoke-link (format "notable://export/book/%s?format=%s" book-id format))
    (message "Exporting book as %s..." format)))

;;;; Boox-Only Operations (Create)

(defun notable-create-folder (name &optional parent-name)
  "Create a new folder with NAME, optionally under PARENT-NAME."
  (interactive
   (let* ((parent (notable--select-folder "Parent folder (empty for root): " t))
          (name (read-string "Folder name: ")))
     (list name parent)))
  (unless IS-ONYX
    (user-error "Create folder only available on Boox"))
  (let ((url (if parent-name
                 (format "notable://new-folder?name=%s&parent=%s"
                         (url-hexify-string name)
                         (url-hexify-string parent-name))
               (format "notable://new-folder?name=%s"
                       (url-hexify-string name)))))
    (notable--invoke-link url)
    (message "Created folder: %s" name)))

(defun notable-create-book (name &optional folder-name)
  "Create a new book with NAME, optionally in FOLDER-NAME."
  (interactive
   (let* ((folder (notable--select-folder "Folder (empty for root): " t))
          (name (read-string "Book name: ")))
     (list name folder)))
  (unless IS-ONYX
    (user-error "Create book only available on Boox"))
  (let ((url (if folder-name
                 (format "notable://new-book?name=%s&folder=%s"
                         (url-hexify-string name)
                         (url-hexify-string folder-name))
               (format "notable://new-book?name=%s"
                       (url-hexify-string name)))))
    (notable--invoke-link url)
    (message "Created book: %s" name)))

(defun notable-create-page (&optional name folder-name)
  "Create a new quick page with optional NAME in FOLDER-NAME."
  (interactive
   (let* ((folder (notable--select-folder "Folder (empty for root): " t))
          (name (read-string "Page name (optional): ")))
     (list (if (string-empty-p name) nil name) folder)))
  (unless IS-ONYX
    (user-error "Create page only available on Boox"))
  (let* ((uuid (org-id-uuid))
         (url (concat "notable://new-page/" uuid
                      (when (or name folder-name) "?")
                      (when name (format "name=%s" (url-hexify-string name)))
                      (when (and name folder-name) "&")
                      (when folder-name (format "folder=%s" (url-hexify-string folder-name))))))
    (notable--invoke-link url)
    (notable--insert-link uuid name)
    (message "Created page: %s" (or name uuid))))

(defun notable-create-page-in-book (book-id &optional name)
  "Create a new page in BOOK-ID with optional NAME."
  (interactive
   (let* ((book-id (notable--select-notebook "Book: "))
          (name (read-string "Page name (optional): ")))
     (list book-id (if (string-empty-p name) nil name))))
  (unless IS-ONYX
    (user-error "Create page only available on Boox"))
  (when book-id
    (let* ((uuid (org-id-uuid))
           (url (format "notable://book/%s/new-page/%s%s"
                        book-id uuid
                        (if name (format "?name=%s" (url-hexify-string name)) ""))))
      (notable--invoke-link url)
      (notable--insert-link uuid name)
      (message "Created page in book: %s" (or name uuid)))))

;;;; Universal Operations (Insert Links)

(defun notable--insert-link (page-id name)
  "Insert an org-mode link for PAGE-ID with NAME at point."
  (let ((link (format "notable://page-%s" page-id))
        (desc (or name "Notable Page")))
    (insert (format "[[%s][%s]]" link desc))))

(defun notable-insert-page-link ()
  "Select an existing page and insert a link to it."
  (interactive)
  (let* ((page-id (notable--select-page "Link to page: "))
         (pages (notable--get-pages))
         (page (seq-find (lambda (p) (string= (alist-get 'id p) page-id)) pages))
         (name (alist-get 'name page)))
    (when page-id
      (notable--insert-link page-id name))))

(defun notable-insert-book-link ()
  "Select an existing book and insert a link to it."
  (interactive)
  (let* ((book-id (notable--select-notebook "Link to book: "))
         (notebooks (notable--get-notebooks))
         (book (seq-find (lambda (b) (string= (alist-get 'id b) book-id)) notebooks))
         (name (alist-get 'name book)))
    (when book-id
      (insert (format "[[notable://book-%s][%s]]" book-id (or name "Notable Book"))))))

;;;; Selection Helpers

(defun notable--select-folder (prompt &optional allow-empty)
  "Select a folder with PROMPT. If ALLOW-EMPTY, allow empty selection."
  (let* ((folders (notable--get-folders))
         (choices (mapcar (lambda (f)
                            (cons (alist-get 'path f) (alist-get 'name f)))
                          folders))
         (selection (completing-read prompt choices nil (not allow-empty))))
    (if (string-empty-p selection)
        nil
      selection)))

(defun notable--select-notebook (prompt)
  "Select a notebook with PROMPT."
  (let* ((notebooks (notable--get-notebooks))
         (choices (mapcar (lambda (n)
                            (let ((path (alist-get 'folderPath n))
                                  (name (alist-get 'name n))
                                  (id (alist-get 'id n)))
                              (cons (if path (format "%s/%s" path name) name) id)))
                          notebooks))
         (selection (completing-read prompt choices nil t)))
    (cdr (assoc selection choices))))

(defun notable--select-page (prompt)
  "Select a page with PROMPT."
  (let* ((pages (notable--get-pages))
         (notebooks (notable--get-notebooks))
         (nb-map (mapcar (lambda (n) (cons (alist-get 'id n) (alist-get 'name n))) notebooks))
         (choices (mapcar (lambda (p)
                            (let* ((id (alist-get 'id p))
                                   (name (alist-get 'name p))
                                   (nb-id (alist-get 'notebookId p))
                                   (nb-name (cdr (assoc nb-id nb-map)))
                                   (folder-path (alist-get 'folderPath p))
                                   (idx (alist-get 'pageIndex p))
                                   (display (cond
                                             ((and nb-name idx)
                                              (format "%s/p%d%s" nb-name (1+ idx)
                                                      (if name (format " (%s)" name) "")))
                                             (name (if folder-path
                                                       (format "%s/%s" folder-path name)
                                                     name))
                                             (t (format "[%s]" (substring id 0 8))))))
                              (cons display id)))
                          pages))
         (selection (completing-read prompt choices nil t)))
    (cdr (assoc selection choices))))

;;;; Transient Interface

;; Transient predicates for conditional display
(defun notable--on-android-p () IS-ANDROID)
(defun notable--on-boox-p () IS-ONYX)

;;;###autoload (autoload 'notable "notable" nil t)
(transient-define-prefix notable ()
  "Notable notebook management.

Features available based on device:
- Boox: Create, Open, Export, Links, Sync
- Android: Open, Export, Links, Sync
- Desktop: Links only"
  [:if notable--on-android-p
   :description "Navigation"
   ("o p" "Open page" notable-open-page)
   ("o b" "Open book" notable-open-book)]
  [:if notable--on-boox-p
   :description "Create (Boox only)"
   ("c f" "New folder" notable-create-folder)
   ("c b" "New book" notable-create-book)
   ("c p" "New quick page" notable-create-page)
   ("c P" "New page in book" notable-create-page-in-book)]
  [:if notable--on-android-p
   :description "Export"
   ("e p" "Export page" notable-export-page)
   ("e b" "Export book" notable-export-book)]
  ["Links (all devices)"
   ("l p" "Insert page link" notable-insert-page-link)
   ("l b" "Insert book link" notable-insert-book-link)]
  [:if notable--on-android-p
   :description "Utility"
   ("r" "Refresh index" notable-sync-index)]
  [("q" "Quit" transient-quit-one)])

;; Register notable:// as an org-mode link type
(with-eval-after-load 'org
  (org-link-set-parameters "notable"
    :follow (lambda (path)
              (if IS-ANDROID
                  (notable--invoke-link (concat "notable:" path))
                (message "Notable links only work on Android: notable:%s" path)))))

(provide 'notable)
;;; notable.el ends here
