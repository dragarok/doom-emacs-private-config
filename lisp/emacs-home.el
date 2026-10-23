;;; emacs-home.el --- Emacs as the Android home screen -*- lexical-binding: t -*-

;;; Commentary:
;; The Emacs Home app (~/.doom.d/emacs-home) is the phone's launcher.  It has
;; no screen of its own: Home brings Emacs forward and calls
;; `emacs-home-on-home', it keeps apps.tsv and icons/ in `emacs-home-dir'
;; current, and it opens emacs-home://launch/PACKAGE/ACTIVITY for us.
;;
;; The homepage gets a row of the apps you launch most, and `emacs-home-launch'
;; picks from all of them.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst emacs-home-dir "/data/data/com.termux/files/home/.emacs-home/"
  "Where the app writes the catalog.  It shares Emacs's uid, so both can.")

(defvar emacs-home-favorites 6
  "How many of the most-launched apps the homepage shows.")

(defvar emacs-home--usage nil
  "Alist of (\"PACKAGE/ACTIVITY\" . LAUNCH-COUNT), kept in usage.eld.")

(defun emacs-home--apps ()
  "Installed apps as (LABEL PACKAGE ACTIVITY), from the app's catalog."
  (let ((file (expand-file-name "apps.tsv" emacs-home-dir)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (mapcar (lambda (line) (split-string line "\t"))
                (split-string (buffer-string) "\n" t))))))

(defun emacs-home--key (app)
  (format "%s/%s" (nth 1 app) (nth 2 app)))

(defun emacs-home--icon (app height)
  "APP's icon as a string displaying an image HEIGHT pixels tall."
  (let ((png (expand-file-name (format "icons/%s_%s.png" (nth 1 app) (nth 2 app))
                               emacs-home-dir)))
    (if (file-exists-p png)
        (propertize " " 'display (create-image png 'png nil :height height
                                               :ascent 'center))
      " ")))

(defun emacs-home--usage ()
  (or emacs-home--usage
      (setq emacs-home--usage
            (ignore-errors
              (with-temp-buffer
                (insert-file-contents (expand-file-name "usage.eld" emacs-home-dir))
                (read (current-buffer)))))))

(defun emacs-home-open (app)
  "Launch APP, a (LABEL PACKAGE ACTIVITY) entry, and count it."
  (let* ((usage (emacs-home--usage))
         (cell (assoc (emacs-home--key app) usage)))
    (if cell (cl-incf (cdr cell))
      (push (cons (emacs-home--key app) 1) emacs-home--usage))
    (with-temp-file (expand-file-name "usage.eld" emacs-home-dir)
      (prin1 emacs-home--usage (current-buffer))))
  (android-browse-url (format "emacs-home://launch/%s" (emacs-home--key app))))

(defun emacs-home-launch ()
  "Pick an installed app and launch it."
  (interactive)
  (let* ((apps (emacs-home--apps))
         (table (make-hash-table :test #'equal))
         (height (* 2 (default-line-height))))
    (dolist (app apps)
      ;; Two launcher entries can share a label; tell them apart.
      (puthash (if (gethash (car app) table)
                   (format "%s (%s)" (car app) (nth 1 app))
                 (car app))
               app table))
    (emacs-home-open
     (gethash
      (completing-read
       "App: "
       (lambda (str pred action)
         (if (eq action 'metadata)
             `(metadata
               (category . emacs-home-app)
               (affixation-function
                . ,(lambda (cands)
                     (mapcar (lambda (c)
                               (list c (concat (emacs-home--icon (gethash c table) height)
                                               " ")
                                     ""))
                             cands))))
           (complete-with-action action (hash-table-keys table) str pred)))
       nil t)
      table))))

(defun emacs-home-on-home ()
  "Called by the app on every Home press: show the homepage."
  ;; Called from emacsclient's process filter, so get out of it first.
  (run-at-time 0 nil (lambda () (+dashboard/open (selected-frame))))
  (when (active-minibuffer-window)
    (run-at-time 0 nil #'abort-recursive-edit))
  nil)

(defun emacs-home-widget ()
  "Dashboard widget: the most-launched apps, then a button for all of them."
  (let* ((apps (emacs-home--apps))
         (usage (emacs-home--usage))
         (count (lambda (app) (or (cdr (assoc (emacs-home--key app) usage)) 0)))
         (top (seq-take (seq-filter (lambda (app) (> (funcall count app) 0))
                                    (sort (copy-sequence apps)
                                          (lambda (a b) (> (funcall count a)
                                                           (funcall count b)))))
                        emacs-home-favorites))
         (height (* 3 (default-line-height))))
    (insert "\n")
    (+dashboard-insert
     (propertize "━━  APPS  ━━" 'face 'android-homepage-section))
    (insert "\n")
    ;; First button, so the dashboard parks point -- and the line highlight
    ;; and box cursor that come with it -- on this text, not the icons.
    (insert "  ")
    (insert-text-button (format "All apps (%d)" (length apps))
                        'action (lambda (_) (emacs-home-launch))
                        'follow-link t
                        'face 'android-homepage-title)
    (insert "\n\n")
    (when top
      (insert "  ")
      (dolist (app top)
        ;; Not the `button' face: its underline sits on the baseline, which
        ;; `:ascent center' puts straight through the middle of the icon.
        (insert-text-button (emacs-home--icon app height)
                            'face 'default
                            'action (lambda (_) (emacs-home-open app))
                            'follow-link t
                            'help-echo (car app))
        (insert "  "))
      (insert "\n"))))

(add-to-list '+dashboard-functions #'emacs-home-widget)

(provide 'emacs-home)
;;; emacs-home.el ends here
