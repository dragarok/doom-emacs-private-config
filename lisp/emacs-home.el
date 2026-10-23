;;; emacs-home.el --- Emacs as the Android home screen -*- lexical-binding: t -*-

;;; Commentary:
;; The Emacs Home app (~/.doom.d/emacs-home) is the phone's launcher.  It has
;; no screen of its own: Home brings Emacs forward and calls
;; `emacs-home-on-home', it keeps apps.tsv and icons/ in `emacs-home-dir'
;; current, and it opens emacs-home://launch/PACKAGE/ACTIVITY for us.
;;
;; The homepage shows your pinned apps as rows of small icons, so a couple of
;; rows still fit above the touch keyboard.  `emacs-home-launch' picks from
;; every app; `emacs-home-toggle-pin' pins or unpins one.

;;; Code:

(require 'seq)
(require 'subr-x)

(defconst emacs-home-dir "/data/data/com.termux/files/home/.emacs-home/"
  "Where the app writes the catalog.  It shares Emacs's uid, so both can.")

(defvar emacs-home-icon-lines 1.4
  "Pinned icon height, in lines.")

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

(defun emacs-home--pins ()
  "Pinned apps' keys, in pinning order."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (expand-file-name "pins.eld" emacs-home-dir))
      (read (current-buffer)))))

(defun emacs-home-open (app)
  "Launch APP, a (LABEL PACKAGE ACTIVITY) entry."
  (android-browse-url (format "emacs-home://launch/%s" (emacs-home--key app))))

(defun emacs-home--read-app (prompt &optional mark)
  "Read an installed app with PROMPT, showing icons.
MARK, if non-nil, is called with each app and returns a suffix string."
  (let ((table (make-hash-table :test #'equal))
        (height (* 2 (default-line-height))))
    (dolist (app (emacs-home--apps))
      ;; Two launcher entries can share a label; tell them apart.
      (puthash (if (gethash (car app) table)
                   (format "%s (%s)" (car app) (nth 1 app))
                 (car app))
               app table))
    (gethash
     (completing-read
      prompt
      (lambda (str pred action)
        (if (eq action 'metadata)
            `(metadata
              (category . emacs-home-app)
              (affixation-function
               . ,(lambda (cands)
                    (mapcar (lambda (c)
                              (let ((app (gethash c table)))
                                (list c (concat (emacs-home--icon app height) " ")
                                      (if mark (funcall mark app) ""))))
                            cands))))
          (complete-with-action action (hash-table-keys table) str pred)))
      nil t)
     table)))

(defun emacs-home-launch ()
  "Pick an installed app and launch it."
  (interactive)
  (emacs-home-open (emacs-home--read-app "App: ")))

(defun emacs-home-toggle-pin ()
  "Pin an app to the homepage, or unpin it if it is pinned."
  (interactive)
  (let* ((pins (emacs-home--pins))
         (key (emacs-home--key
               (emacs-home--read-app
                "Pin/unpin: "
                (lambda (app)
                  (if (member (emacs-home--key app) pins) "  ★ pinned" ""))))))
    (with-temp-file (expand-file-name "pins.eld" emacs-home-dir)
      (prin1 (if (member key pins) (delete key pins) (append pins (list key)))
             (current-buffer)))
    (+dashboard-reload t)))

(defun emacs-home-on-home ()
  "Called by the app on every Home press: show the homepage."
  ;; Called from emacsclient's process filter, so get out of it first.
  (run-at-time 0 nil (lambda () (+dashboard/open (selected-frame))))
  (when (active-minibuffer-window)
    (run-at-time 0 nil #'abort-recursive-edit))
  nil)

(defun emacs-home-widget ()
  "Dashboard widget: All apps and Pin buttons, then the pinned icons."
  (let* ((apps (emacs-home--apps))
         (by-key (mapcar (lambda (app) (cons (emacs-home--key app) app)) apps))
         (pinned (delq nil (mapcar (lambda (key) (cdr (assoc key by-key)))
                                   (emacs-home--pins))))
         (height (round (* emacs-home-icon-lines (default-line-height))))
         (gap (frame-char-width))
         ;; Measured, not HEIGHT: `image-scaling-factor' enlarges it on screen.
         (icon (and pinned (get-text-property 0 'display
                                              (emacs-home--icon (car pinned) height))))
         (width (if (consp icon) (car (image-size icon t)) height))
         ;; Two spaces lead each row, one follows each icon.
         (per-row (max 1 (/ (- (window-body-width nil t) (* 2 gap))
                            (+ width gap)))))
    (insert "\n  ")
    ;; First button, so the dashboard parks point -- and the line highlight
    ;; and box cursor that come with it -- on this text, not the icons.
    (insert-text-button (format "All apps (%d)" (length apps))
                        'action (lambda (_) (emacs-home-launch))
                        'follow-link t
                        'face 'android-homepage-title)
    (insert "    ")
    (insert-text-button "Pin / unpin"
                        'action (lambda (_) (emacs-home-toggle-pin))
                        'follow-link t
                        'face 'android-homepage-title)
    (insert "\n")
    (dolist (row (seq-partition pinned per-row))
      (insert "  ")
      (dolist (app row)
        ;; Not the `button' face: its underline sits on the baseline, which
        ;; `:ascent center' puts straight through the middle of the icon.
        (insert-text-button (emacs-home--icon app height)
                            'face 'default
                            'action (lambda (_) (emacs-home-open app))
                            'follow-link t
                            'help-echo (car app))
        (insert " "))
      (insert "\n"))))

(add-to-list '+dashboard-functions #'emacs-home-widget)

(provide 'emacs-home)
;;; emacs-home.el ends here
