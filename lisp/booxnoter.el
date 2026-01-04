;;; booxnoter.el --- Convert Boox and e-reader highlights to Org-roam notes -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Your Name

;; Author: Your Name
;; Keywords: org, notes, books, highlights
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org-roam "2.0.0") (s "1.12.0") (dash "2.19.0") (f "0.20.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; This package provides a modular system for processing e-reader highlights
;; into organized Org-roam notes.  Currently supports Boox note format with
;; planned support for KOReader and other formats.
;;
;; Features:
;; - Automatic book metadata extraction
;; - Chapter-aware quote organization
;; - Duplicate detection
;; - Smart file management
;; - Extensible parser architecture

;;; Code:

(require 'org-roam)
(require 's)
(require 'dash)
(require 'f)
(require 'cl-lib)

;;; Customization

(defgroup booxnoter nil
  "Process e-reader highlights into Org-roam notes."
  :group 'org
  :prefix "booxnoter-")

(defcustom booxnoter-pdf-destination-dir
  (expand-file-name "~/Nextcloud/org/handwritten_notes/boox_notes")
  "Directory where processed PDF files will be stored."
  :type 'directory
  :group 'booxnoter)

(defcustom booxnoter-processed-subdir "done"
  "Subdirectory name for processed highlight files."
  :type 'string
  :group 'booxnoter)

(defcustom booxnoter-default-filetags '("bookreview")
  "Default filetags to add to book review notes."
  :type '(repeat string)
  :group 'booxnoter)

;;; Data Structures

(cl-defstruct booxnoter-book
  "Structure representing a book with its metadata."
  title
  author
  year
  publisher
  raw-title)

(cl-defstruct booxnoter-quote
  "Structure representing a single highlight/quote."
  text
  page
  timestamp
  chapter
  source-file)

(cl-defstruct booxnoter-highlight-file
  "Structure representing a parsed highlight file."
  filepath
  book
  quotes
  highlight-number)

;;; Parser Architecture - Base Classes

(defclass booxnoter-parser ()
  ((name :initarg :name
         :type string
         :documentation "Name of the parser")
   (patterns :initarg :patterns
             :type list
             :documentation "Regex patterns for parsing"))
  "Base class for highlight file parsers.")

(cl-defgeneric booxnoter-parser-can-parse (parser filepath)
  "Return non-nil if PARSER can parse FILEPATH.")

(cl-defgeneric booxnoter-parser-parse-file (parser filepath)
  "Parse FILEPATH using PARSER, return booxnoter-highlight-file struct.")

;;; Boox Format Parser

(defclass booxnoter-boox-parser (booxnoter-parser)
  ((name :initform "Boox Parser")
   (patterns :initform '(:header-pattern "Reading Notes \\| <<\\(.+?\\)>>\\(.+\\)"
                         :date-pattern "\\([0-9-]+ [0-9:]+\\)\\s-*|\\s-*Page No\\.:\\s-*\\([0-9]+\\)"
                         :separator-pattern "^-+$")))
  "Parser for Boox note format.")

(cl-defmethod booxnoter-parser-can-parse ((parser booxnoter-boox-parser) filepath)
  "Check if file at FILEPATH is in Boox format."
  (when (f-readable? filepath)
    (with-temp-buffer
      (insert-file-contents filepath nil 0 500)
      (goto-char (point-min))
      (looking-at-p "Reading Notes"))))

(cl-defmethod booxnoter-parser-parse-file ((parser booxnoter-boox-parser) filepath)
  "Parse Boox format file at FILEPATH."
  (let* ((content (f-read-text filepath))
         (lines (split-string content "\n"))
         (book (booxnoter--parse-boox-header (car lines)))
         (quotes '())
         (current-chapter nil)
         (quote-text nil)
         (quote-page nil)
         (quote-timestamp nil))
    
    (dolist (line (cdr lines))
      (cond
       ;; Separator - save previous quote if exists
       ((string-match-p "^-+$" line)
        (when (and quote-text quote-page)
          (push (make-booxnoter-quote
                 :text (s-trim quote-text)
                 :page quote-page
                 :timestamp quote-timestamp
                 :chapter current-chapter
                 :source-file (f-filename filepath))
                quotes)
          (setq quote-text nil
                quote-page nil
                quote-timestamp nil)))
       
       ;; Date and page line
       ((string-match "\\([0-9]+-[0-9]+-[0-9]+ [0-9:]+\\)\\s-*|\\s-*Page No\\.:\\s-*\\([0-9]+\\)" line)
        (setq quote-timestamp (match-string 1 line))
        (setq quote-page (string-to-number (match-string 2 line))))
       
       ;; Empty line - skip
       ((string-blank-p line) nil)
       
       ;; Chapter heading (non-empty, non-separator, before any date line)
       ((and (not quote-page) (not (string-blank-p line)))
        (setq current-chapter (s-trim line)))
       
       ;; Quote text
       (t
        (setq quote-text (if quote-text
                             (concat quote-text "\n" line)
                           line)))))
    
    ;; Don't forget last quote
    (when (and quote-text quote-page)
      (push (make-booxnoter-quote
             :text (s-trim quote-text)
             :page quote-page
             :timestamp quote-timestamp
             :chapter current-chapter
             :source-file (f-filename filepath))
            quotes))
    
    (make-booxnoter-highlight-file
     :filepath filepath
     :book book
     :quotes (nreverse quotes)
     :highlight-number nil)))

(defun booxnoter--parse-boox-header (header-line)
  "Parse HEADER-LINE to extract book metadata."
  (if (string-match "<<\\([^>]+\\)>>" header-line)
      (let* ((raw-title (match-string 1 header-line))
             (author-part (if (string-match ">>\\(.+\\)" header-line)
                              (s-trim (match-string 1 header-line))
                            nil))
             (title-parts (booxnoter--extract-title-components raw-title)))
        (make-booxnoter-book
         :title (plist-get title-parts :title)
         :author (or (plist-get title-parts :author) author-part)
         :year (plist-get title-parts :year)
         :publisher (plist-get title-parts :publisher)
         :raw-title raw-title))
    (make-booxnoter-book :title "Unknown Book" :raw-title header-line)))

(defun booxnoter--extract-title-components (raw-title)
  "Extract title, author, year, and publisher from RAW-TITLE string."
  (let ((title nil)
        (author nil)
        (year nil)
        (publisher nil)
        (cleaned-title raw-title))
    
    ;; First, remove any trailing source indicators
    (setq cleaned-title (replace-regexp-in-string " - \\(libgen\\.[a-z]+\\|Z-Library\\|anna's archive\\|libgen\\.lc\\)$" "" cleaned-title))
    
    (cond
     ;; Special case: web capture format with date (highagency_com_2025-03-26_06-17-15)
     ((string-match "\\([^_]+\\)_com_\\([0-9]+-[0-9]+-[0-9]+\\)_" cleaned-title)
      (setq title (s-replace "_" " " (match-string 1 cleaned-title)))
      (setq author nil))
     
     ;; Pattern: Author - Title (Year, Publisher)
     ((string-match "^\\([^-]+\\) - \\(.+\\)$" cleaned-title)
      (let* ((before-dash (s-trim (match-string 1 cleaned-title)))
             (after-dash (s-trim (match-string 2 cleaned-title)))
             ;; Get just the title part before parentheses
             (title-candidate after-dash))
        
        ;; Remove parenthetical content from title
        (when (string-match "^\\([^(]+?\\)\\s-*(" title-candidate)
          (setq title-candidate (s-trim (match-string 1 title-candidate))))
        
        ;; Extract author from before-dash
        (setq author before-dash)
        ;; Clean up author - remove company names and underscores
        (when (string-match "\\([^_]+\\)$" author)
          (setq author (match-string 1 author)))
        (setq author (s-replace "_" " " author))
        
        ;; Extract year from parentheses  
        (when (string-match "(\\([0-9]\\{4\\}\\)" after-dash)
          (setq year (match-string 1 after-dash)))
        
        ;; Extract publisher from parentheses
        (when (string-match "(\\([0-9]+[^,]*\\),\\s-*\\([^)]+\\))" after-dash)
          (setq publisher (match-string 2 after-dash)))
        
        (setq title title-candidate)))
     
     ;; Pattern: Just title with possible parenthetical metadata
     ((not (string-match " - " cleaned-title))
      (let ((base-title cleaned-title))
        ;; Remove all parenthetical content
        (when (string-match "^\\([^(]+?\\)\\s-*(" base-title)
          (setq base-title (s-trim (match-string 1 base-title))))
        
        (setq title (s-replace "_" " " base-title))
        
        ;; Try to extract year if present
        (when (string-match "(\\([0-9]\\{4\\}\\)" cleaned-title)
          (setq year (match-string 1 cleaned-title)))
        
        ;; Check for author info in parentheses
        (when (string-match "(\\([^,)]+\\)[,)]" cleaned-title)
          (let ((paren-content (match-string 1 cleaned-title)))
            (unless (string-match "^[0-9]" paren-content)
              (setq author paren-content))))))
     
     ;; Fallback
     (t
      (setq title (s-replace "_" " " cleaned-title))
      (setq title (replace-regexp-in-string " *([^)]*)" "" title))))
    
    ;; Final cleanup
    (when title
      (setq title (replace-regexp-in-string "\\.pdf$" "" title))
      (setq title (replace-regexp-in-string "_" " " title))
      (setq title (s-trim title)))
    
    (list :title (or title "Unknown Book") 
          :author author 
          :year year 
          :publisher publisher)))

;;; Quote Processing

(defun booxnoter--sort-quotes (quotes)
  "Sort QUOTES by page number, then by timestamp."
  (sort quotes
        (lambda (q1 q2)
          (let ((page1 (booxnoter-quote-page q1))
                (page2 (booxnoter-quote-page q2)))
            (if (= page1 page2)
                (let ((ts1 (booxnoter-quote-timestamp q1))
                      (ts2 (booxnoter-quote-timestamp q2)))
                  (and ts1 ts2 (string< ts1 ts2)))
              (< page1 page2))))))

(defun booxnoter--group-quotes-by-chapter (quotes)
  "Group QUOTES by their chapter, maintaining order."
  (let ((groups '())
        (current-chapter nil)
        (current-group '()))
    (dolist (quote quotes)
      (let ((chapter (booxnoter-quote-chapter quote)))
        (unless (equal chapter current-chapter)
          (when current-group
            (push (cons current-chapter (nreverse current-group)) groups))
          (setq current-chapter chapter
                current-group '()))
        (push quote current-group)))
    (when current-group
      (push (cons current-chapter (nreverse current-group)) groups))
    (nreverse groups)))

(defun booxnoter--merge-highlight-files (highlight-files)
  "Merge multiple HIGHLIGHT-FILES for the same book."
  (when highlight-files
    (let* ((first-file (car highlight-files))
           (book (booxnoter-highlight-file-book first-file))
           (all-quotes '()))
      
      ;; Collect all quotes with their source file tags
      (cl-loop for file in highlight-files
               for index from 1
               do (let ((hl-tag (format "highlight_%d" index)))
                    (dolist (quote (booxnoter-highlight-file-quotes file))
                      (setf (booxnoter-quote-source-file quote) hl-tag)
                      (push quote all-quotes))))
      
      (make-booxnoter-highlight-file
       :filepath (booxnoter-highlight-file-filepath first-file)
       :book book
       :quotes (booxnoter--sort-quotes (nreverse all-quotes))
       :highlight-number nil))))

;;; Org-roam Integration

(defun booxnoter--create-org-roam-node (book)
  "Create or find an Org-roam node for BOOK."
  (let* ((title (format "BR %s" (booxnoter-book-title book)))
         (node (org-roam-node-from-title-or-alias title)))
    (if node
        node
      ;; Create new node using capture
      (org-roam-capture-
       :node (org-roam-node-create :title title)
       :templates '(("b" "book review" plain "%?"
                     :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                                        "#+title: ${title}\n#+filetags: :bookreview:\n")
                     :unnarrowed t))
       :props '(:finalize find-file)))))

(defun booxnoter--format-quote-as-org (quote)
  "Format QUOTE as an Org-mode entry."
  (let ((source-tag (booxnoter-quote-source-file quote))
        (page (booxnoter-quote-page quote))
        (timestamp (booxnoter-quote-timestamp quote))
        (text (booxnoter-quote-text quote)))
    (concat
     (format "** Quote :%s:\n" (or source-tag ""))
     ":PROPERTIES:\n"
     (format ":PAGE: %d\n" page)
     (when timestamp
       (format ":TIMESTAMP: [%s]\n"
               (replace-regexp-in-string
                "\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\) \\([0-9]+:[0-9]+\\)"
                "\\1-\\2-\\3 \\4"
                timestamp)))
     ":END:\n"
     "#+BEGIN_QUOTE\n"
     text "\n"
     "#+END_QUOTE\n")))

(defun booxnoter--quote-exists-p (quote buffer)
  "Check if QUOTE already exists in BUFFER."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let ((page (booxnoter-quote-page quote))
            (text-snippet (substring (booxnoter-quote-text quote) 
                                     0 (min 50 (length (booxnoter-quote-text quote))))))
        (or (re-search-forward 
             (format ":PAGE: %d" page) nil t)
            (search-forward text-snippet nil t))))))

(defun booxnoter--insert-quotes-into-org-buffer (highlight-file buffer)
  "Insert quotes from HIGHLIGHT-FILE into BUFFER."
  (with-current-buffer buffer
    (goto-char (point-max))
    (let ((chapter-groups (booxnoter--group-quotes-by-chapter 
                           (booxnoter-highlight-file-quotes highlight-file))))
      (dolist (group chapter-groups)
        (let ((chapter (car group))
              (quotes (cdr group)))
          ;; Insert chapter heading if it exists
          (when chapter
            (insert (format "\n* %s\n" chapter)))
          ;; Insert quotes for this chapter
          (dolist (quote quotes)
            (unless (booxnoter--quote-exists-p quote buffer)
              (insert "\n" (booxnoter--format-quote-as-org quote)))))))))

;;; File Management

(defun booxnoter--find-matching-pdf (highlight-file)
  "Find PDF file matching HIGHLIGHT-FILE."
  (let* ((filepath (booxnoter-highlight-file-filepath highlight-file))
         (dir (f-dirname filepath))
         (book-title (booxnoter-book-title 
                      (booxnoter-highlight-file-book highlight-file)))
         (pdf-files (f-files dir (lambda (f) (f-ext? f "pdf")) nil))) ;; non-recursive for PDFs
    ;; First try to find PDF with "scribble" in the name (most common pattern)
    (or (cl-find-if 
         (lambda (pdf)
           (s-contains? "scribble" (downcase (f-filename pdf))))
         pdf-files)
        ;; Otherwise try to find matching PDF by title similarity
        (cl-find-if 
         (lambda (pdf)
           (let ((pdf-name (downcase (f-base pdf)))
                 (title-parts (downcase book-title)))
             (or (s-contains? title-parts pdf-name)
                 (s-contains? (car (s-split " " title-parts)) pdf-name))))
         pdf-files))))

(defun booxnoter--find-png-files (highlight-file)
  "Find PNG files in the same directory as HIGHLIGHT-FILE."
  (let* ((filepath (booxnoter-highlight-file-filepath highlight-file))
         (dir (f-dirname filepath)))
    (f-files dir (lambda (f) (f-ext? f "png")) nil)))

(defun booxnoter--move-pdf-to-destination (pdf-path book)
  "Move PDF at PDF-PATH to destination with BOOK metadata."
  (when (and pdf-path (f-exists? pdf-path))
    (let* ((year (or (booxnoter-book-year book) "unknown"))
           (title (booxnoter-book-title book))
           (new-name (format "%s -- %s -- scribble.pdf" year title))
           (dest-path (f-join booxnoter-pdf-destination-dir new-name)))
      (unless (f-exists? booxnoter-pdf-destination-dir)
        (make-directory booxnoter-pdf-destination-dir t))
      (rename-file pdf-path dest-path t)
      dest-path)))

(defun booxnoter--move-png-files-to-destination (png-files book)
  "Move PNG-FILES to destination with BOOK metadata, return list of destination paths."
  (let ((destinations '())
        (year (or (booxnoter-book-year book) "unknown"))
        (title (booxnoter-book-title book)))
    (cl-loop for png in png-files
             for index from 1
             do (when (f-exists? png)
                  (let* ((suffix (if (> (length png-files) 1)
                                     (format "_%d" index)
                                   ""))
                         (new-name (format "%s -- %s -- screenshot%s.png" year title suffix))
                         (dest-path (f-join booxnoter-pdf-destination-dir new-name)))
                    (unless (f-exists? booxnoter-pdf-destination-dir)
                      (make-directory booxnoter-pdf-destination-dir t))
                    (rename-file png dest-path t)
                    (push dest-path destinations))))
    (nreverse destinations)))

(defun booxnoter--move-to-done (filepath base-directory)
  "Move FILEPATH to done subdirectory at BASE-DIRECTORY level, preserving folder structure."
  (let* ((relative-path (f-relative filepath base-directory))
         (done-dir (f-join base-directory booxnoter-processed-subdir))
         (dest-dir (f-join done-dir (f-dirname relative-path)))
         (dest (f-join dest-dir (f-filename filepath))))
    (unless (f-exists? dest-dir)
      (make-directory dest-dir t))
    (when (f-exists? filepath)
      (rename-file filepath dest t))))

;;; Main Processing Pipeline

(defun booxnoter--get-available-parsers ()
  "Return list of available parser instances."
  (list (booxnoter-boox-parser)))

(defun booxnoter--find-parser-for-file (filepath)
  "Find appropriate parser for FILEPATH."
  (cl-find-if 
   (lambda (parser)
     (booxnoter-parser-can-parse parser filepath))
   (booxnoter--get-available-parsers)))

(defun booxnoter-process-directory (directory)
  "Process all highlight files in DIRECTORY and subdirectories."
  (interactive "DSelect directory with highlight files: ")
  (let* ((txt-files (f-files directory 
                             (lambda (f) 
                               (and (f-ext? f "txt")
                                    (not (s-contains? (concat "/" booxnoter-processed-subdir "/") f))))
                             t)) ;; t for recursive
         (books-table (make-hash-table :test 'equal))
         (file-count (length txt-files)))
    
    (when (zerop file-count)
      (message "No text files found in %s or its subdirectories" directory)
      (cl-return-from booxnoter-process-directory nil))
    
    (message "Found %d text files to process recursively" file-count)
    
    ;; Parse all files and group by book
    ;; Group files by their parent directory first to assign highlight numbers correctly
    (let ((dir-files-table (make-hash-table :test 'equal)))
      ;; Group files by directory
      (dolist (filepath txt-files)
        (let ((dir (f-dirname filepath)))
          (push filepath (gethash dir dir-files-table))))
      
      ;; Process each directory's files
      (maphash
       (lambda (dir files)
         (let ((sorted-files (sort files 'string<)))
           (cl-loop for filepath in sorted-files
                    for index from 1
                    do (let ((parser (booxnoter--find-parser-for-file filepath)))
                         (if parser
                             (let* ((hl-file (booxnoter-parser-parse-file parser filepath))
                                    (book-title (booxnoter-book-title 
                                                 (booxnoter-highlight-file-book hl-file))))
                               (setf (booxnoter-highlight-file-highlight-number hl-file) index)
                               (push hl-file (gethash book-title books-table)))
                           (message "No parser found for %s" filepath))))))
       dir-files-table))
    
    ;; Process each book
    (maphash 
     (lambda (book-title highlight-files)
       (message "Processing book: %s" book-title)
       (let* ((merged (booxnoter--merge-highlight-files (reverse highlight-files)))
              (book (booxnoter-highlight-file-book merged))
              (node-title (format "BR %s" book-title))
              (all-file-links '()))
         
         ;; Find and move all PDFs and PNGs, collecting their destination paths
         (dolist (hl-file (reverse highlight-files))
           ;; Handle PDF
           (let ((pdf (booxnoter--find-matching-pdf hl-file)))
             (when pdf
               (let ((pdf-dest (booxnoter--move-pdf-to-destination pdf book)))
                 (when pdf-dest
                   (push (format "[[file:%s]]" pdf-dest) all-file-links)))))
           ;; Handle PNGs
           (let ((pngs (booxnoter--find-png-files hl-file)))
             (when pngs
               (let ((png-dests (booxnoter--move-png-files-to-destination pngs book)))
                 (dolist (png-dest png-dests)
                   (push (format "[[file:%s]]" png-dest) all-file-links))))))
         
         ;; Remove duplicates from file links
         (setq all-file-links (delete-dups (nreverse all-file-links)))
         
         ;; Create or find org-roam node
         (let ((node (org-roam-node-from-title-or-alias node-title)))
           (unless node
             ;; Create new node via org-roam-capture
             (org-roam-capture-
              :node (org-roam-node-create :title node-title)
              :templates `(("b" "book review" plain ""
                            :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                                               ,(concat "#+title: ${title}\n"
                                                        "#+filetags: :bookreview:\n"))
                            :immediate-finish t
                            :unnarrowed t))))
           
           ;; Find the buffer for this node
           (let* ((node (org-roam-node-from-title-or-alias node-title))
                  (file (org-roam-node-file node)))
             (when file
               (with-current-buffer (find-file-noselect file)
                 (goto-char (point-max))
                 ;; Check if file links section already exists
                 (unless (save-excursion
                           (goto-char (point-min))
                           (re-search-forward "^\\[\\[file:" nil t))
                   ;; Add all file links at the end of the header section
                   (when all-file-links
                     (insert "\n")
                     (dolist (link all-file-links)
                       (insert link "\n"))
                     (insert "\n")))
                 ;; Insert quotes
                 (booxnoter--insert-quotes-into-org-buffer merged (current-buffer))
                 (save-buffer)
                 (message "Added %d quotes and %d file links to %s" 
                          (length (booxnoter-highlight-file-quotes merged))
                          (length all-file-links)
                          node-title)))))
         
         ;; Move text files to done
         (dolist (hl-file (reverse highlight-files))
           (let ((filepath (booxnoter-highlight-file-filepath hl-file)))
             (booxnoter--move-to-done filepath directory)))))
     books-table)
    
    ;; Clean up empty directories after moving files
    (let ((subdirs (f-directories directory nil t)))
      (dolist (subdir subdirs)
        (unless (string= (f-filename subdir) booxnoter-processed-subdir)
          (when (and (f-directory? subdir)
                     (zerop (length (f-entries subdir))))
            (delete-directory subdir)))))
    
    (message "Processing complete! Processed %d books." (hash-table-count books-table))))

;;; Interactive Commands

;;;###autoload
(defun booxnoter-process-folder ()
  "Interactively process a folder of highlight files."
  (interactive)
  (let ((dir (read-directory-name "Select folder with highlight files: "
                                  "~/Boox/notes/")))
    (booxnoter-process-directory dir)))

;;;###autoload
(defun booxnoter-process-current-folder ()
  "Process highlight files in the current buffer's directory."
  (interactive)
  (if buffer-file-name
      (booxnoter-process-directory (f-dirname buffer-file-name))
    (user-error "Current buffer is not visiting a file")))

(provide 'booxnoter)
;;; booxnoter.el ends here
