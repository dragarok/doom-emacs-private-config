;;; tips.el --- One tip at a time, from the guide -*- lexical-binding: t -*-

;;; Commentary:
;; docs/guide.org is how this Emacs works; each of its second-level
;; headings is a tip.  `tips-next' (the dashboard's Tip button) shows one,
;; small, at the bottom of the frame -- the next one each time, in the
;; guide's order, so they are learnt a few at a time rather than read all
;; at once.  Where you are is kept per machine, in Doom's cache.  n / p:
;; next or previous, a: the whole guide, q: close.

;;; Code:

(require 'org)
(require 'seq)
(require 'subr-x)

(defvar doom-user-dir)
(defvar doom-cache-dir)
(declare-function +popup-shrink-to-fit "popup")

(defgroup tips nil "One tip at a time, from the guide." :group 'convenience)

(defcustom tips-file (expand-file-name "docs/guide.org" (or (bound-and-true-p doom-user-dir) user-emacs-directory))
  "The guide: each second-level heading is a tip."
  :type 'file)

(defcustom tips-position-file (expand-file-name "tips-next" (or (bound-and-true-p doom-cache-dir) user-emacs-directory))
  "Where the number of the next tip is kept, on this machine."
  :type 'file)

(defun tips-read ()
  "The tips in `tips-file': a list of (SECTION TITLE BODY)."
  (with-temp-buffer
    (insert-file-contents tips-file)
    (let (section out)
      (goto-char (point-min))
      (while (re-search-forward "^\\(\\*\\*?\\) \\(.*\\)$" nil t)
        (if (equal (match-string 1) "*")
            (setq section (match-string-no-properties 2))
          (let ((title (match-string-no-properties 2))
                (beg (1+ (match-end 0))))
            (save-excursion
              (let ((end (if (re-search-forward "^\\*+ " nil t) (match-beginning 0) (point-max))))
                (push (list section title (string-trim (buffer-substring-no-properties (min beg end) end)))
                      out))))))
      (nreverse out))))

(defun tips--position ()
  (or (ignore-errors
        (with-temp-buffer
          (insert-file-contents tips-position-file)
          (max 0 (string-to-number (buffer-string)))))
      0))

(defun tips--save-position (n)
  (ignore-errors
    (make-directory (file-name-directory tips-position-file) t)
    (with-temp-file tips-position-file (insert (number-to-string n)))))

(defvar-keymap tips-mode-map
  "n" #'tips-next
  "p" #'tips-previous
  "a" #'tips-all
  "q" #'quit-window)

(define-derived-mode tips-mode org-mode "Tip"
  "One tip from the guide.  \\{tips-mode-map}"
  (setq-local mode-line-format nil)
  (setq buffer-read-only t))

(with-eval-after-load 'evil
  (when (fboundp 'evil-set-initial-state)
    (evil-set-initial-state 'tips-mode 'emacs)))

(when (fboundp 'set-popup-rule!)
  (set-popup-rule! "^\\*Tip\\*$" :side 'bottom :size #'+popup-shrink-to-fit :select t :quit t :ttl 0))

(defun tips--button (label action)
  (insert-text-button label 'action (lambda (_) (call-interactively action))
                      'follow-link t 'face 'link)
  (insert "   "))

(defun tips-show (n)
  "Show tip N (from 0; it wraps around), and keep the next as N + 1."
  (let* ((tips (or (tips-read) (user-error "No tips in %s" tips-file)))
         (n (mod n (length tips)))
         (tip (nth n tips))
         (buf (get-buffer-create "*Tip*")))
    (tips--save-position (1+ n))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (unless (derived-mode-p 'tips-mode) (tips-mode))
        (insert (propertize (format "Tip %d of %d · %s" (1+ n) (length tips) (nth 0 tip)) 'face 'shadow)
                "\n* " (nth 1 tip) "\n" (nth 2 tip) "\n\n")
        (tips--button "[Next]" #'tips-next)
        (tips--button "[Back]" #'tips-previous)
        (tips--button "[All tips]" #'tips-all)
        (tips--button "[Close]" #'quit-window)
        (font-lock-ensure)
        (org-fold-show-all)
        (goto-char (point-min))))
    (pop-to-buffer buf)
    (fit-window-to-buffer (get-buffer-window buf) (/ (frame-height) 2))))

;;;###autoload
(defun tips-next ()
  "Show the next tip from the guide."
  (interactive)
  (tips-show (tips--position)))

(defun tips-previous ()
  "Show the tip before the one shown."
  (interactive)
  (tips-show (- (tips--position) 2)))

;;;###autoload
(defun tips-all ()
  "Open the whole guide."
  (interactive)
  (when-let* ((win (get-buffer-window "*Tip*"))) (quit-window nil win))
  (find-file tips-file))

(provide 'tips)
;;; tips.el ends here
