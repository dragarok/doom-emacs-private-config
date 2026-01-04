;;; qsv-csv.el --- QSV-powered CSV operations for Emacs -*- lexical-binding: t; -*-

;; Fast CSV operations using qsv (https://github.com/dathere/qsv)
;; First principles: minimal code, maximum utility

(require 'consult)

(defvar csv-last-sort-columns nil
  "Remember last sort columns for quick reuse.")

(defvar csv-last-sort-reverse nil
  "Remember if last sort was reversed.")

(defun csv--get-column-names ()
  "Extract column names from current CSV buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((header (buffer-substring-no-properties 
                   (line-beginning-position) 
                   (line-end-position))))
      (split-string header "," t " "))))

(defun csv--build-column-spec ()
  "Build column specification using consult.
Returns (columns . reverse-p) where columns is a comma-separated string."
  (let* ((column-names (csv--get-column-names))
         (indexed-columns (cl-loop for name in column-names
                                   for i from 1
                                   collect (format "%d:%s" i name)))
         (initial (when csv-last-sort-columns
                    (concat csv-last-sort-columns 
                            (if csv-last-sort-reverse " R" ""))))
         (input (consult--read
                 indexed-columns
                 :prompt "Columns (comma-sep, add R for reverse): "
                 :initial initial
                 :history 'csv-sort-history
                 :sort nil)))
    (let* ((reverse-p (string-match-p " R$" input))
           (clean-input (replace-regexp-in-string " R$" "" input))
           (parts (split-string clean-input "," t " "))
           (columns (mapconcat
                     (lambda (part)
                       (cond
                        ((string-match "^[0-9]+:" part)
                         (car (split-string part ":")))
                        ((string-match "^[0-9]+$" part)
                         part)
                        (t part)))
                     parts ",")))
      (setq csv-last-sort-columns columns
            csv-last-sort-reverse reverse-p)
      (cons columns reverse-p))))

(defun csv-sort-by-columns ()
  "Sort CSV buffer by selected columns using qsv."
  (interactive)
  (let* ((spec (csv--build-column-spec))
         (columns (car spec))
         (reverse-p (cdr spec))
         (buffer-name (format "*CSV sorted: %s%s*" 
                              columns 
                              (if reverse-p " (R)" "")))
         (cmd (format "qsv sort -s %s%s" 
                      columns
                      (if reverse-p " -R" "")))
         (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string 
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)
    (message "Sorted by: %s%s" columns (if reverse-p " (reversed)" ""))))

(defun csv-sort-numeric ()
  "Sort CSV numerically by selected columns."
  (interactive)
  (let* ((spec (csv--build-column-spec))
         (columns (car spec))
         (reverse-p (cdr spec))
         (buffer-name (format "*CSV sorted numeric: %s%s*"
                              columns
                              (if reverse-p " (R)" "")))
         (cmd (format "qsv sort -s %s -N%s"
                      columns
                      (if reverse-p " -R" "")))
         (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)))

(defun csv-stats ()
  "Show statistics for current CSV using qsv stats."
  (interactive)
  (let ((buffer-name "*CSV Stats*")
        (cmd "qsv stats")
        (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)))

(defun csv-filter (query)
  "Filter CSV rows using qsv search."
  (interactive "sFilter query: ")
  (let ((buffer-name (format "*CSV filtered: %s*" query))
        (cmd (format "qsv search '%s'" query))
        (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)))

(defun csv-select-columns ()
  "Select specific columns using qsv select."
  (interactive)
  (let* ((column-names (csv--get-column-names))
         (selected (completing-read-multiple
                    "Select columns: "
                    column-names))
         (columns (mapconcat 'identity selected ","))
         (buffer-name (format "*CSV columns: %s*" columns))
         (cmd (format "qsv select %s" columns))
         (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)))

(defun csv-frequency (column)
  "Show frequency table for a column."
  (interactive
   (list (completing-read "Column: " (csv--get-column-names))))
  (let ((buffer-name (format "*CSV frequency: %s*" column))
        (cmd (format "qsv frequency -s %s -l 0" column))
        (csv-content (buffer-string)))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert (shell-command-to-string
               (format "echo %s | %s"
                       (shell-quote-argument csv-content)
                       cmd)))
      (csv-mode)
      (csv-align-mode 1)
      (goto-char (point-min)))
    (switch-to-buffer buffer-name)))

;; Keybindings - defer until csv-mode is loaded
(with-eval-after-load 'csv-mode
  (define-key csv-mode-map (kbd "C-c s") 'csv-sort-by-columns)
  (define-key csv-mode-map (kbd "C-c n") 'csv-sort-numeric)
  (define-key csv-mode-map (kbd "C-c t") 'csv-stats)
  (define-key csv-mode-map (kbd "C-c f") 'csv-filter)
  (define-key csv-mode-map (kbd "C-c c") 'csv-select-columns)
  (define-key csv-mode-map (kbd "C-c q") 'csv-frequency))

(provide 'qsv-csv)
;;; csv.el ends here