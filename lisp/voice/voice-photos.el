;;; voice-photos.el --- Voice domain: tagging photos -*- lexical-binding: t -*-

;;; Commentary:
;; Say a photo's tags; delete, skip, rotate.

;;; Code:

(require 'voice-core)

;; Bound here, defined in another part.
(defvar voice--fill)

;;;; Context

(defvar voice-photo-session nil
  "While a tagging session runs: (:tagged N :deleted N :clocked BOOL).")

;;;; Near, not word for word

(defun voice--tag-share (request heard)
  "How much of REQUEST, by words, named photo tags; HEARD is what
`voice--spoken-tags' returned with UNKNOWN.  0 to 1."
  (let ((total (length (voice--spoken-words request))))
    (if (or (zerop total) (null (car heard))) 0.0
      (- 1.0 (/ (float (length (cdr heard))) total)))))

;;;; Tagging photos

(defvar voice-photo-inbox nil
  "Where photos wait to be tagged.  Nil: the folder that holds
`my-image-processed-dir' (Pictures/S23 on the phone).")

(defvar voice-photo-task "image tagging"
  "The task a tagging session clocks in to, when one clearly is it.")

(defvar voice-photo-trash-days 30
  "Photos deleted by voice wait this long in Trash/ beside them, for undo.")

(defun voice--photo-inbox ()
  (require 'image-mode)                 ; image-workflow.el's paths and commands
  (file-name-as-directory
   (or voice-photo-inbox
       (file-name-directory (directory-file-name (bound-and-true-p my-image-processed-dir))))))

(defun voice--photos-in (dir)
  (sort (seq-remove #'file-directory-p (directory-files dir t (image-file-name-regexp))) #'string<))

(defvar voice--photo-tags-cache nil "(MTIME . TAGS) of imageindex.csv.")

(defun voice--photo-tags ()
  "Every tag used so far, most used first, then the default ones."
  (require 'image-mode)
  (let* ((f (bound-and-true-p my-image-index-file))
         (mtime (and f (file-exists-p f) (file-attribute-modification-time (file-attributes f)))))
    (if (and voice--photo-tags-cache (equal (car voice--photo-tags-cache) mtime))
        (cdr voice--photo-tags-cache)
      (let ((tags (delete-dups
                   (append (and mtime (fboundp 'read-tags-from-imageindex-csv)
                                (ignore-errors (read-tags-from-imageindex-csv f)))
                           (bound-and-true-p my-image-tags)
                           nil))))
        (setq voice--photo-tags-cache (cons mtime tags))
        tags))))

(defvar voice-tag-filler '("about" "also" "plus" "photo" "picture" "image" "pic" "tag" "tags" "maybe" "then")
  "Words said between tags that are no tag and not worth telling about.")

(defun voice--spoken-words (text)
  (seq-remove (lambda (w) (or (member w voice-match-stop-words) (member w voice-tag-filler)))
              (voice-match-words text)))

(defvar voice--tag-forms-cache nil "(TAGS . FORMS): each tag with its name and stem.")

(defun voice--tag-forms (tags)
  (unless (eq (car voice--tag-forms-cache) tags)
    (setq voice--tag-forms-cache
          (cons tags
                (seq-remove (lambda (f) (string-empty-p (nth 1 f)))
                            (mapcar (lambda (tag)
                                      (let ((norm (downcase (replace-regexp-in-string "[^[:alnum:]]" "" tag))))
                                        (list tag norm (voice-match-stem norm))))
                                    tags)))))
  (cdr voice--tag-forms-cache))

(defun voice--tag-score (tag-norm tag-stem word)
  "How well WORD names a tag: 3 its name, 2 its stem, 1 nearly, else nil."
  (cond ((equal tag-norm word) 3)
        ((equal tag-stem (voice-match-stem word)) 2)
        ((and (>= (length word) 4)
              (>= (voice-match-sim tag-stem (voice-match-stem word)) 0.9))
         1)))

(defun voice--spoken-tags (text tags &optional unknown)
  "The TAGS (strings) TEXT says, in the order said.  Each word names one
tag, the closest (\"app\" is app, not apps); two words may name one run
together (\"learning note\": learningnote).  Ties go to the tag earlier
in TAGS, the more used.  With UNKNOWN, return (TAGS . WORDS-NAMING-NONE)."
  (let* ((words (vconcat (voice--spoken-words text)))
         (forms (voice--tag-forms tags))
         (i 0) found none)
    (while (< i (length words))
      (let* ((w (aref words i))
             (pair (and (< (1+ i) (length words)) (concat w (aref words (1+ i)))))
             (joined (and pair (seq-find (lambda (f) (equal (nth 1 f) pair)) forms)))
             best)
        (if joined
            (progn (push (car joined) found) (setq i (+ i 2)))
          (dolist (f forms)
            (let ((score (voice--tag-score (nth 1 f) (nth 2 f) w)))
              (when (and score (or (null best) (> score (car best))))
                (setq best (cons score (car f))))))
          (if best (push (cdr best) found) (push w none))
          (setq i (1+ i)))))
    (let ((found (delete-dups (nreverse found))))
      (if unknown (cons found (nreverse none)) found))))

(defun voice--photo-window ()
  "The window showing a photo, or an error."
  (or (seq-find (lambda (w) (with-current-buffer (window-buffer w) (derived-mode-p 'image-mode)))
                (cons (selected-window) (window-list)))
      (user-error "Voice: no photo open; say \"tag photos\"")))

(defun voice--photo-count (key)
  (when voice-photo-session
    (setq voice-photo-session
          (plist-put voice-photo-session key (1+ (or (plist-get voice-photo-session key) 0))))))

(defun voice--photos-left (dir)
  (format "%d to go" (length (voice--photos-in dir))))

(defun voice-start-tagging ()
  "Clock in to the image tagging task and show the first photo waiting."
  (let* ((dir (voice--photo-inbox))
         (photos (voice--photos-in dir))
         (clocked nil))
    (unless photos (user-error "Voice: no photos waiting in %s" dir))
    (voice--prune-photo-trash dir)
    (let ((ranked (voice-rank-tasks voice-photo-task)))
      (when (and ranked (eq (voice-match-decide ranked) 'act)
                 (not (and (fboundp 'org-clocking-p) (org-clocking-p)
                           (equal (bound-and-true-p org-clock-current-task)
                                  (plist-get (nth 2 (car ranked)) :title)))))
        (save-window-excursion (voice-clock-in (nth 2 (car ranked))))
        (setq clocked t)))
    (setq voice-photo-session (list :tagged 0 :deleted 0 :clocked clocked))
    (find-file (car photos))
    (format "%d photos to tag: say the tags, or delete, skip, back, undo, stop tagging"
            (length photos))))

(defun voice-stop-tagging ()
  "End the tagging session: close the photo, and the clock it started."
  (let ((s voice-photo-session))
    (setq voice-photo-session nil)
    (ignore-errors (kill-buffer (window-buffer (voice--photo-window))))
    (when (and (fboundp 'org-clocking-p) (org-clocking-p)
               (or (plist-get s :clocked)
                   (equal (downcase (or (bound-and-true-p org-clock-current-task) ""))
                          (downcase voice-photo-task))))
      (org-clock-out))
    (format "Tagging done: %d tagged, %d deleted"
            (or (plist-get s :tagged) 0) (or (plist-get s :deleted) 0))))

(defun voice-tag-photo (text)
  "Tag the photo with the tags TEXT says, file it as the e key does, and
show the next.  No tag heard: the tag question is asked as usual."
  (let* ((heard (voice--spoken-tags text (voice--photo-tags) t))
         (tags (car heard))
         (win (voice--photo-window))
         (file (buffer-file-name (window-buffer win)))
         (dir (file-name-directory file))
         (index (bound-and-true-p my-image-index-file)))
    (with-selected-window win
      (let ((voice--fill (list :pool nil :answers (and tags (list (cons "\\`Select tags" tags)))
                               :owned '("\\`Select tags"))))
        (set-image-tags-and-rename-and-next)))
    ;; Undo: the photo back where it was, its index line gone.
    (let ((line (and index (with-temp-buffer
                             (insert-file-contents index)
                             (car (last (split-string (buffer-string) "\n" t)))))))
      (when (and line (string-match "\\`\\([^,]+\\)," line))
        (let ((moved (match-string 1 line)))
          (setq voice--last
                (list :what (format "tags on %s" (file-name-nondirectory file))
                      :undo (lambda ()
                              (rename-file moved file)
                              (with-temp-buffer
                                (insert-file-contents index)
                                (goto-char (point-max))
                                (when (re-search-backward (concat "^" (regexp-quote moved) ",.*\n?") nil t)
                                  (replace-match "")
                                  (write-region nil nil index nil 'silent)))
                              (when (fboundp 'my/image-media-scan) (my/image-media-scan file))
                              (with-selected-window (voice--photo-window) (find-alternate-file file))))))))
    (voice--photo-count :tagged)
    (format "Tagged %s%s, %s" (if tags (string-join tags ", ") "it")
            (if (cdr heard) (format " (no such tag: %s)" (string-join (cdr heard) " ")) "")
            (voice--photos-left dir))))

(defun voice-delete-photo ()
  "Move the photo to Trash/ beside it, where undo can find it, and show
the next."
  (let* ((win (voice--photo-window))
         (file (buffer-file-name (window-buffer win)))
         (dir (file-name-directory file))
         (trash (expand-file-name "Trash/" dir))
         (dest (expand-file-name (file-name-nondirectory file) trash))
         (left (length (voice--photos-in dir))))
    (make-directory trash t)
    (with-selected-window win
      (if (> left 1)
          (image-next-file 1)
        (kill-buffer (current-buffer))))
    (rename-file file dest t)
    (when (fboundp 'my/image-media-scan) (my/image-media-scan file) (my/image-media-scan dest))
    (setq voice--last
          (list :what (format "delete of %s" (file-name-nondirectory file))
                :undo (lambda ()
                        (rename-file dest file)
                        (when (fboundp 'my/image-media-scan) (my/image-media-scan file))
                        (find-file file))))
    (voice--photo-count :deleted)
    (format "Deleted, %s" (voice--photos-left dir))))

(defun voice--prune-photo-trash (dir)
  (let ((trash (expand-file-name "Trash/" dir)))
    (when (file-directory-p trash)
      (dolist (f (directory-files trash t "^[^.]"))
        (when (> (float-time (time-since (file-attribute-modification-time (file-attributes f))))
                 (* 86400 voice-photo-trash-days))
          (ignore-errors (delete-file f)))))))

;;;; What to say

(voice-action '("next" "next image" "next photo" "skip" "skip it" "next one") #'image-next-file
              :when 'image :quiet t :name "next image")

(voice-action '("previous" "previous image" "previous photo" "back" "go back") #'image-previous-file
              :when 'image :quiet t :name "previous image")

(voice-action '("tag …" "tag it …" "tags …" "tag it as …") #'voice-tag-photo :slot 'text
              :when 'image :quiet t :name "tag image")

(voice-action '("delete" "delete it" "delete this" "delete photo" "trash it" "bin it" "remove it")
              #'voice-delete-photo :when 'image :quiet t :name "delete photo")

(voice-action '("start image tagging" "image tagging" "tag photos" "tag images" "tag my photos"
                "start tagging" "tag pictures")
              #'voice-start-tagging :name "tag photos")

(voice-action '("stop tagging" "stop image tagging" "done tagging" "finish tagging" "end tagging")
              #'voice-stop-tagging :quiet t :name "stop tagging")

(voice-action '("that's all" "done" "i'm done" "that's it")
              #'voice-stop-tagging :when 'image :quiet t :name "stop tagging here")

(voice-action '("rotate" "rotate it" "rotate image") #'image-rotate :when 'image :quiet t :name "rotate image")

;;;; The domain

(defun voice--photo-flags (source)
  "image, while a photo is on screen: from the island too while a tagging
session runs, since then you are looking at it."
  (and (or (not (equal source "island")) voice-photo-session)
       (with-current-buffer (window-buffer (selected-window))
         (derived-mode-p 'image-mode))
       '(image)))

(defun voice--photo-claim (u best)
  "On a photo, tags said (\"food travel\"), more of what was said than
any command explains (BEST): tag it."
  (when (memq 'image (plist-get u :context))
    (let* ((request (plist-get u :request))
           (heard (voice--spoken-tags request (voice--photo-tags) t))
           (share (if heard (voice--tag-share request heard) 0.0)))
      (when (and (>= share 0.5) (>= share best))
        (list :kind 'action :text (plist-get u :text) :slot request :quiet t :near share
              :action (seq-find (lambda (a) (equal (plist-get a :name) "tag image")) voice-actions))))))

(voice-define-domain 'photos
  :doc "Tagging photos: say their tags; delete, skip, rotate."
  :context #'voice--photo-flags
  :claim #'voice--photo-claim)

(provide 'voice-photos)
;;; voice-photos.el ends here
