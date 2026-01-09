;;; productivity_addons.el --- Additional productivity functions for org-mode -*- lexical-binding: t -*-

;;; Commentary:
;; Simple functions to enhance org-mode productivity workflow

;;; Code:

(defun open-latest-download ()
  "Open the most recently downloaded file from Downloads folder.
Uses dired/dirvish to handle file opening automatically."
  (interactive)
  (let* ((downloads-dir (if (eq system-type 'android)
                            "/sdcard/Download/"
                          (expand-file-name "~/Downloads/")))
         (files (directory-files downloads-dir t "^[^.]" t))
         (latest-file (car (sort files
                                 (lambda (a b)
                                   (time-less-p (nth 5 (file-attributes b))
                                                (nth 5 (file-attributes a))))))))
    (if latest-file
        (progn
          (dired downloads-dir)
          (dired-goto-file latest-file)
          (dired-find-file))
      (message "No files found in Downloads folder: %s" downloads-dir))))

(provide 'productivity_addons)
;;; productivity_addons.el ends here
