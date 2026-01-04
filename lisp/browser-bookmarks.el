;;; browser-bookmarks.el --- Browser bookmark utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Functions for working with browser bookmarks (Chrome, Brave, etc.)
;; Mac-only - not needed on Android.

;;; Code:

(defvar chrome-bookmarks-file
  (cl-find-if
   #'file-exists-p
   ;; Base on `helm-chrome-file'
   (list
    "~/Library/Application Support/Google/Chrome/Profile 1/Bookmarks"
    "~/Library/Application Support/Google/Chrome/Default/Bookmarks"
    "~/AppData/Local/Google/Chrome/User Data/Default/Bookmarks"
    "~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks"
    (substitute-in-file-name
     "$LOCALAPPDATA/Google/Chrome/User Data/Default/Bookmarks")
    (substitute-in-file-name
     "$USERPROFILE/Local Settings/Application Data/Google/Chrome/User Data/Default/Bookmarks")))
  "Path to Google Chrome Bookmarks file (it's JSON).")

;;;###autoload
(defun chrome-bookmarks-insert-as-org ()
  "Insert Chrome Bookmarks as org-mode headings."
  (interactive)
  (require 'json)
  (require 'org)
  (let ((data (let ((json-object-type 'alist)
                    (json-array-type  'list)
                    (json-key-type    'symbol)
                    (json-false       nil)
                    (json-null        nil))
                (json-read-file chrome-bookmarks-file)))
        level)
    (cl-labels ((fn
                  (al)
                  (pcase (alist-get 'type al)
                    ("folder"
                     (insert
                      (format "%s %s\n"
                              (make-string level ?*)
                              (alist-get 'name al)))
                     (cl-incf level)
                     (mapc #'fn (alist-get 'children al))
                     (cl-decf level))
                    ("url"
                     (insert
                      (format "%s %s\n"
                              (make-string level ?*)
                              (org-make-link-string
                               (alist-get 'url al)
                               (alist-get 'name al))))))))
      (setq level 1)
      (fn (alist-get 'bookmark_bar (alist-get 'roots data)))
      (setq level 1)
      (fn (alist-get 'other (alist-get 'roots data))))))

(defun firefox--find-places-sqlite ()
  "Return the first places.sqlite file found in Firefox or Zen Browser profiles."
  (let ((base-dirs
         (list
          ;; macOS
          ;; "~/Library/Application Support/Firefox/Profiles"
          "~/Library/Application Support/zen/Profiles"
          ;; Linux
          "~/.mozilla/firefox"
          ;; Windows
          (substitute-in-file-name "$APPDATA/Mozilla/Firefox/Profiles")
          (substitute-in-file-name "$USERPROFILE/AppData/Roaming/Mozilla/Firefox/Profiles")))
        found-files)
    (dolist (dir base-dirs)
      (when (file-directory-p (expand-file-name dir))
        (let ((files (directory-files-recursively (expand-file-name dir) "places\\.sqlite$")))
          (dolist (file files)
            (when (file-exists-p file)
              (push file found-files))))))
    (if found-files
        (progn
          (message "Found places.sqlite files: %s" found-files)
          (car found-files))
      (error "No places.sqlite files found in Firefox or Zen Browser profiles"))))

(defun firefox--copy-places-sqlite (bookmark-file)
  "Copy BOOKMARK-FILE to a temporary location to avoid database lock."
  (let ((temp-file (make-temp-file "places-sqlite-")))
    (copy-file bookmark-file temp-file t)
    (message "Copied %s to %s" bookmark-file temp-file)
    temp-file))

;;;###autoload
(defun firefox-bookmarks-insert-as-org ()
  "Insert Firefox or Zen Browser bookmarks as org-mode headings."
  (interactive)
  (require 'org)
  (let* ((original-file (firefox--find-places-sqlite))
         (bookmark-file (if original-file
                            (firefox--copy-places-sqlite original-file)
                          (error "No places.sqlite file found")))
         level)
    (message "Using places.sqlite copy: %s" bookmark-file)
    (let ((bookmark-data (firefox--get-bookmarks bookmark-file)))
      (cl-labels ((fn
                    (item)
                    (pcase (plist-get item :type)
                      ("folder"
                       (insert
                        (format "%s %s\n"
                                (make-string level ?*)
                                (or (plist-get item :title) "")))
                       (cl-incf level)
                       (mapc #'fn (plist-get item :children))
                       (cl-decf level))
                      ("url"
                       (when (plist-get item :url)
                         (insert
                          (format "%s %s\n"
                                  (make-string level ?*)
                                  (org-make-link-string
                                   (plist-get item :url)
                                   (or (plist-get item :title) (plist-get item :url))))))))))
        (setq level 1)
        (dolist (root (list (plist-get bookmark-data :menu)
                            (plist-get bookmark-data :toolbar)
                            (plist-get bookmark-data :unfiled)))
          (when root
            (fn root)))))
    ;; Clean up temporary file
    (when (file-exists-p bookmark-file)
      (delete-file bookmark-file))))

(defun firefox--get-bookmarks (bookmark-file)
  "Retrieve Firefox or Zen Browser bookmarks from BOOKMARK-FILE and return as a plist."
  (unless bookmark-file
    (error "No Firefox or Zen Browser places.sqlite file provided"))
  (let* ((sql-query
          "SELECT b.id, b.parent, b.type, b.title, b.position, p.url
           FROM moz_bookmarks b
           LEFT JOIN moz_places p ON b.fk = p.id
           WHERE b.type IN (1, 2) AND b.title IS NOT NULL")
         (temp-file (make-temp-file "firefox-bookmarks-"))
         (escaped-file (shell-quote-argument (expand-file-name bookmark-file)))
         (command (format "sqlite3 -json %s %s > %s"
                          escaped-file
                          (shell-quote-argument sql-query)
                          (shell-quote-argument temp-file)))
         (json-data (progn
                      (message "Executing command: %s" command)
                      (let ((exit-code (shell-command command)))
                        (unless (zerop exit-code)
                          (error "SQLite command failed with exit code %d: %s"
                                 exit-code command)))
                      (with-temp-buffer
                        (insert-file-contents temp-file)
                        (if (> (buffer-size) 0)
                            (json-read-from-string (buffer-string))
                          (error "No data returned from SQLite query: %s" command)))))
         (bookmarks (make-hash-table :test 'equal))
         (root-data (list :menu nil :toolbar nil :unfiled nil)))
    ;; Build bookmark items (normalize vector → list)
    (dolist (row (append json-data nil))
      (let* ((id (alist-get 'id row nil nil #'equal))
             (parent (alist-get 'parent row nil nil #'equal))
             (type (alist-get 'type row nil nil #'equal)) ;; 1 = URL, 2 = folder
             (title (alist-get 'title row nil nil #'equal))
             (position (alist-get 'position row nil nil #'equal))
             (url (alist-get 'url row nil nil #'equal))
             (item (list :id id
                         :parent parent
                         :type (if (= type 2) "folder" "url")
                         :title title
                         :url url
                         :position position
                         :children (when (= type 2) '())
                         :pending-children (when (= type 2) '()))))
        (puthash id item bookmarks)))
    ;; Assign children to folders
    (maphash
     (lambda (_id item)
       (let ((parent (plist-get item :parent)))
         (when (and parent (gethash parent bookmarks))
           (let ((p-item (gethash parent bookmarks)))
             (when (string= (plist-get p-item :type) "folder")
               (push (cons (or (plist-get item :position) 0) _id)
                     (plist-get p-item :pending-children)))))))
     bookmarks)
    ;; Sort and resolve children
    (maphash
     (lambda (_id item)
       (when (plist-get item :pending-children)
         (let ((sorted-pending (sort (plist-get item :pending-children)
                                     (lambda (a b) (< (car a) (car b))))))
           (setf (plist-get item :children)
                 (mapcar (lambda (pos-id)
                           (gethash (cdr pos-id) bookmarks))
                         sorted-pending))
           (setf (plist-get item :pending-children) nil))))
     bookmarks)
    ;; Identify root folders by fixed IDs
    (maphash
     (lambda (_id item)
       (cond
        ((= _id 2) (setf (plist-get root-data :menu) item))
        ((= _id 3) (setf (plist-get root-data :toolbar) item))
        ((= _id 5) (setf (plist-get root-data :unfiled) item))
        ((= _id 6) (setf (plist-get root-data :mobile) item)))) ;; add mobile too
     bookmarks)
    ;; Clean up temp JSON file
    (when (file-exists-p temp-file)
      (delete-file temp-file))
    root-data))

;;; Taken from https://xenodium.com/building-your-own-bookmark-launcher/
;;;###autoload
(defun browser-bookmarks (org-file)
  "Return all links from ORG-FILE."
  (with-temp-buffer
    (let (links)
      (insert-file-contents org-file)
      (org-mode)
      (org-element-map (org-element-parse-buffer) 'link
        (lambda (link)
          (let* ((raw-link (org-element-property :raw-link link))
                 (content (org-element-contents link))
                 (title (substring-no-properties (or (seq-first content) raw-link))))
            (push (concat title
                          "\n\n"
                          (propertize raw-link 'face 'whitespace-space)
                          "\n\n")
                  links)))
        nil nil 'link)
      (seq-sort 'string-greaterp links))))

;;;###autoload
(defun open-bookmark ()
  (interactive)
  (let ((url (seq-elt (split-string (completing-read "Open: " (browser-bookmarks (concat org-roam-directory "bookmarks.org"))) "\n") 2)))
    (browse-url-firefox url)))

(defun open-random-bookmark ()
  "Open a random bookmark from the bookmarks file."
  (interactive)
  (let* ((bookmarks (browser-bookmarks (concat org-roam-directory "bookmarks.org")))
         (random-bookmark (when bookmarks
                            (seq-random-elt bookmarks))))
    (if random-bookmark
        (let ((url (seq-elt (split-string random-bookmark "\n") 2)))
          (browse-url-firefox url))
      (message "No bookmarks found!"))))

(provide 'browser-bookmarks)
;;; browser-bookmarks.el ends here
