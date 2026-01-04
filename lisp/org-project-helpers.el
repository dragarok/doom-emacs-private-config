;;; org-project-helpers.el --- Project navigation helpers for Org mode -*- lexical-binding: t; -*-

;;; Commentary:
;; Helper functions for navigating project properties in Org mode headings.
;; Allows opening project URLs, notes, and resource directories from
;; current or ancestor headings.

;;; Code:

(after! org
  (defun project/open-from-ancestor-heading (fn property)
    "Check the current heading and go up recursively to the parent heading until the specified property is found, then execute the given function FN."
    (save-excursion
      (while (and (not (org-entry-get nil property))
                  (org-up-heading-safe)))
      (funcall fn)))

  (defun project/open-proj-ref-url ()
    "Open the REF_URL property from the current or ancestor Org mode heading."
    (interactive)
    (project/open-from-ancestor-heading
     (lambda ()
       (let ((ref-url (org-entry-get nil "PROJ_REF_URL")))
         (when ref-url
           (browse-url ref-url))))
     "PROJ_REF_URL"))

  (defun recursively-open-ref-url ()
    "Open the REF_URL property from the current or ancestor Org mode heading."
    (interactive)
    (project/open-from-ancestor-heading
     (lambda ()
       (let ((ref-url (org-entry-get nil "REF_URL")))
         (when ref-url
           (browse-url ref-url))))
     "REF_URL"))

  (defun project/open-proj-notes ()
    "Open the ORG_FILE property from the current or ancestor Org mode heading."
    (interactive)
    (project/open-from-ancestor-heading
     (lambda ()
       (let ((org-file-id (org-entry-get nil "PROJ_NOTES")))
         (when org-file-id
           (org-open-link-from-string org-file-id))))
     "PROJ_NOTES"))

  (defun recursively-open-ref-org-note ()
    "Open the ORG_FILE property from the current or ancestor Org mode heading."
    (interactive)
    (project/open-from-ancestor-heading
     (lambda ()
       (let ((org-file-id (org-entry-get nil "REF_NOTE")))
         (when org-file-id
           (org-open-link-from-string org-file-id))))
     "REF_NOTE"))

  (defun project/open-resources-dir ()
    "Open the RESOURCES_DIR property from the current or ancestor Org mode heading."
    (interactive)
    (project/open-from-ancestor-heading
     (lambda ()
       (let ((resources-dir (org-entry-get nil "PROJ_RESOURCES_DIR")))
         (when resources-dir
           (let ((path (replace-regexp-in-string "\\[\\[\\|\\]\\]" "" resources-dir)))
             (dired (org-link-unescape path))))))
     "PROJ_RESOURCES_DIR"))

  (map! :map org-mode-map
        :localleader
        :desc "Open ref org note" "z" #'recursively-open-ref-org-note
        :desc "Open ref url" "u" #'recursively-open-ref-url
        :prefix ("p" . "Project Mappings")
        :desc "Open proj ref url" "u" #'project/open-proj-ref-url
        :desc "Open proj notes" "n" #'project/open-proj-notes
        :desc "Open resources dir" "p" #'project/open-resources-dir
        "d" nil)

  ;; For agenda mode
  (defun project/execute-in-org-buffer (fn)
    "Execute the given function FN in the org buffer if called from org-agenda."
    (if (eq major-mode 'org-agenda-mode)
        (progn
          (split-window-right) ; Split the window to the right
          (other-window 1) ; Move to the new window
          (org-agenda-switch-to) ; Switch to the corresponding Org buffer
          (funcall fn))   ; Call the given function
      (call-interactively fn)))

  (map! :map org-agenda-mode-map
        :localleader
        :desc "Open ref org note" "z" (lambda () (interactive) (project/execute-in-org-buffer #'recursively-open-ref-org-note))
        :desc "Open ref url" "u" (lambda () (interactive) (project/execute-in-org-buffer #'recursively-open-ref-url))
        :desc "Open proj ref url" "pu" (lambda () (interactive) (project/execute-in-org-buffer #'project/open-proj-ref-url))
        :desc "Open proj notes" "pn" (lambda () (interactive) (project/execute-in-org-buffer #'project/open-proj-notes))
        :desc "Open resources dir" "pr" (lambda () (interactive) (project/execute-in-org-buffer #'project/open-resources-dir))
        "pd" nil))

(provide 'org-project-helpers)
;;; org-project-helpers.el ends here
