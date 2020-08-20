;;;###autoload
(defun doom/toggle-comment-region-or-line ()
  "Comments or uncomments the whole region or if no region is
selected, then the current line."
  (interactive)
  (let (beg end)
    (if (region-active-p)
        (setq beg (region-beginning) end (region-end))
      (setq beg (line-beginning-position) end (line-end-position)))
    (comment-or-uncomment-region beg end)))

(map!
 (:after evil-vars
  (:map evil-window-map
   :leader
   (:prefix "w"
    :desc "evil-window-decrease-height" "-" (λ! (evil-window-decrease-height 10))
    :desc "evil-window-increase-height" "+" (λ! (evil-window-increase-height 10))
    :desc "evil-window-decrease-width" "<"  (λ! (evil-window-decrease-width 20))
    :desc "evil-window-increase-width" ">"  (λ! (evil-window-increase-width 20)))))
)


;; eshell aliases
(after! eshell
  (set-eshell-alias!
   "f"   "find-file $1"
   "l"   "ls -1"
   "ll"   "ls -lh"
   "la"   "ls -la"
   "d"   "dired $1"
   "gl"  "(call-interactively 'magit-log-current)"
   "gs"  "magit-status"
   "gc"  "magit-commit"
   "d" "dired $1"
   "gl" "(call-interactively 'magit-log-current)"
   "gb" "(call-interactively #'magit-branch-checkout)"
   "gbc" "(call-interactively #'magit-branch-create)"
   "bat" "+eshell/bat $1"
   "sudo" "eshell/sudo $*"
   "nm" "nc/enwc"
   "locate" "counsel-locate $1"
   "man" "(+default/man-or-woman)"
   "info" "+eshell/info-manual"
   "tm" "transmission"
   "cal" "calendar"
   "pass" "(pass)"
   "fd" "+eshell/fd $1"
   "fo" "find-file-other-window $1"
   "rgi" "+default/search-cwd"
   "rg"  "rg --color=always $*"))


;;;###autoload
(defun +brett/find-notes-for-project (&optional arg)
  "Find notes for the current project"
  (interactive)
  (let ((default-directory (expand-file-name "projects/" +org-dir)))
    (if arg
        (call-interactively #'find-file)
      (find-file
       (expand-file-name (concat (doom-project-name 'nocache) ".org"))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Compare fonts                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar lorem-ipsum-text)

;;;###autoload
(defun unpackaged/font-compare (text fonts)
  "Compare TEXT displayed in FONTS.
If TEXT is nil, use `lorem-ipsum' text.  FONTS is a list of font
family strings and/or font specs.

Interactively, prompt for TEXT, using `lorem-ipsum' if left
empty, and select FONTS with `x-select-font', pressing Cancel to
stop selecting fonts."
  (interactive (list (pcase (read-string "Text: ")
                       ("" nil)
                       (else else))
                     ;; `x-select-font' calls quit() when Cancel is pressed, so we use
                     ;; `inhibit-quit', `with-local-quit', and `quit-flag' to avoid that.
                     (let ((inhibit-quit t))
                       (cl-loop for font = (with-local-quit
                                             (x-select-font))
                                while font
                                collect font into fonts
                                finally do (setf quit-flag nil)
                                finally return fonts))))
  (setq text (or text (s-word-wrap 80 (s-join " " (progn
                                                    (require 'lorem-ipsum)
                                                    (seq-random-elt lorem-ipsum-text))))))
  (with-current-buffer (get-buffer-create "*Font Compare*")
    (erase-buffer)
    (--each fonts
      (let ((family (cl-typecase it
                      (font (symbol-name (font-get it :family)))
                      (string it))))
        (insert family ": "
                (propertize text
                            'face (list :family family))
                "\n\n")))
    (pop-to-buffer (current-buffer))))



(defcustom unpackaged/lorem-ipsum-overlay-exclude nil
  "List of regexps to exclude from `unpackaged/lorem-ipsum-overlay'."
  :type '(repeat regexp))

;;;###autoload
(defun unpackaged/lorem-ipsum-overlay ()
  "Overlay all text in current buffer with \"lorem ipsum\" text.
When called again, remove overlays.  Useful for taking
screenshots without revealing buffer contents.

Each piece of non-whitespace text in the buffer is compared with
regexps in `unpackaged/lorem-ipsum-overlay-exclude', and ones
that match are not overlaid.  Note that the regexps are compared
against the entire non-whitespace token, up-to and including the
preceding whitespace, but only the alphabetic part of the token
is overlaid.  For example, in an Org buffer, a line that starts
with:

  #+TITLE: unpackaged.el

could be matched against the exclude regexp (in `rx' syntax):

  (rx (or bol bos blank) \"#+\" (1+ alnum) \":\" (or eol eos blank))

And the line would be overlaid like:

  #+TITLE: parturient.et"
  (interactive)
  (require 'lorem-ipsum)
  (let ((ovs (overlays-in (point-min) (point-max))))
    (if (cl-loop for ov in ovs
                 thereis (overlay-get ov :lorem-ipsum-overlay))
        ;; Remove overlays.
        (dolist (ov ovs)
          (when (overlay-get ov :lorem-ipsum-overlay)
            (delete-overlay ov)))
      ;; Add overlays.
      (let ((lorem-ipsum-words (--> lorem-ipsum-text
                                    (-flatten it) (apply #'concat it)
                                    (split-string it (rx (or space punct)) 'omit-nulls)))
            (case-fold-search nil))
        (cl-labels ((overlay-match (group)
                                   (let* ((beg (match-beginning group))
                                          (end (match-end group))
                                          (replacement-word (lorem-word (match-string group)))
                                          (ov (make-overlay beg end)))
                                     (when replacement-word
                                       (overlay-put ov :lorem-ipsum-overlay t)
                                       (overlay-put ov 'display replacement-word))))
                    (lorem-word (word)
                                (if-let* ((matches (lorem-matches (length word))))
                                    (apply-case word (downcase (seq-random-elt matches)))
                                  ;; Word too long: compose one.
                                  (apply-case word (downcase (compose-word (length word))))))
                    (lorem-matches (length &optional (comparator #'=))
                                   (cl-loop for liw in lorem-ipsum-words
                                            when (funcall comparator (length liw) length)
                                            collect liw))
                    (apply-case (source target)
                                (cl-loop for sc across-ref source
                                         for tc across-ref target
                                         when (not (string-match-p (rx lower) (char-to-string sc)))
                                         do (setf tc (string-to-char (upcase (char-to-string tc)))))
                                target)
                    (compose-word (length)
                                  (cl-loop while (> length 0)
                                           for word = (seq-random-elt (lorem-matches length #'<=))
                                           concat word
                                           do (cl-decf length (length word)))))
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward (rx (group (1+ (or bol bos blank (not alpha)))
                                                 (0+ (not (any alpha blank)))
                                                 (group (1+ alpha))
                                                 (0+ (not (any alpha blank)))))
                                      nil t)
              (unless (cl-member (match-string 0) unpackaged/lorem-ipsum-overlay-exclude
                                 :test (lambda (string regexp)
                                         (string-match-p regexp string)))
                (overlay-match 2))
              (goto-char (match-end 2)))))))))


;;;###autoload
(defun unpackaged/org-attach-download (url)
  "Download file at URL and attach with `org-attach'.
Interactively, look for URL at point, in X clipboard, and in
kill-ring, prompting if not found.  With prefix, prompt for URL."
  (interactive (list (if current-prefix-arg
                         (read-string "URL: ")
                       (or (org-element-property :raw-link (org-element-context))
                           (org-web-tools--get-first-url)
                           (read-string "URL: ")))))
  (when (yes-or-no-p (concat "Attach file at URL: " url))
    (let* ((temp-dir (make-temp-file "org-attach-download-" 'dir))
           (basename (file-name-nondirectory (directory-file-name url)))
           (local-path (expand-file-name basename temp-dir))
           size)
      (unwind-protect
          (progn
            (url-copy-file url local-path 'ok-if-exists 'keep-time)
            (setq size (file-size-human-readable
                        (file-attribute-size
                         (file-attributes local-path))))
            (org-attach-attach local-path nil 'mv)
            (message "Attached %s (%s)" url size))
        (delete-directory temp-dir)))))




;;;###autoload
(defun unpackaged/org-refile-to-datetree-using-ts-in-entry (which-ts file &optional subtree-p)
  "Refile current entry to datetree in FILE using timestamp found in entry.
WHICH should be `earliest' or `latest'. If SUBTREE-P is non-nil,
search whole subtree."
  (interactive (list (intern (completing-read "Which timestamp? " '(earliest latest)))
                     (read-file-name "File: " (concat org-directory "/") nil 'mustmatch nil
                                     (lambda (filename)
                                       (string-suffix-p ".org" filename)))
                     current-prefix-arg))
  (require 'ts)
  (let* ((sorter (pcase which-ts
                   ('earliest #'ts<)
                   ('latest #'ts>)))
         (tss (unpackaged/org-timestamps-in-entry subtree-p))
         (ts (car (sort tss sorter)))
         (date (list (ts-month ts) (ts-day ts) (ts-year ts))))
    (unpackaged/org-refile-to-datetree file :date date)))

;;;###autoload
(defun unpackaged/org-timestamps-in-entry (&optional subtree-p)
  "Return timestamp objects for all Org timestamps in entry.
 If SUBTREE-P is non-nil (interactively, with prefix), search
 whole subtree."
  (interactive (list current-prefix-arg))
  (save-excursion
    (let* ((beg (org-entry-beginning-position))
           (end (if subtree-p
                    (org-end-of-subtree)
                  (org-entry-end-position))))
      (goto-char beg)
      (cl-loop while (re-search-forward org-tsr-regexp-both end t)
               collect (ts-parse-org (match-string 0))))))

;;;###autoload
(cl-defun unpackaged/org-refile-to-datetree (file &key (date (calendar-current-date)) entry)
  "Refile ENTRY or current node to entry for DATE in datetree in FILE."
  (interactive (list (read-file-name "File: " (concat org-directory "/") nil 'mustmatch nil
                                     (lambda (filename)
                                       (string-suffix-p ".org" filename)))))
  ;; If org-datetree isn't loaded, it will cut the tree but not file
  ;; it anywhere, losing data. I don't know why
  ;; org-datetree-file-entry-under is in a separate package, not
  ;; loaded with the rest of org-mode.
  (require 'org-datetree)
  (unless entry
    (org-cut-subtree))
  ;; Using a condition-case to be extra careful. In case the refile
  ;; fails in any way, put cut subtree back.
  (condition-case err
      (with-current-buffer (or (org-find-base-buffer-visiting file)
                               (find-file-noselect file))
        (org-datetree-file-entry-under (or entry (car kill-ring)) date)
        (save-buffer))
    (error (unless entry
             (org-paste-subtree))
           (message "Unable to refile! %s" err))))

(defun unpackaged/org-outline-numbers (&optional remove-p)
  "Add outline number overlays to the current buffer.
When REMOVE-P is non-nil (interactively, with prefix), remove
them.  Overlays are not automatically updated when the outline
structure changes."
  ;; NOTE: This does not necessarily play nicely with org-indent-mode
  ;; or org-bullets, but it probably wouldn't be too hard to fix that.
  (interactive (list current-prefix-arg))
  (cl-labels ((heading-number ()
               (or (when-let ((num (previous-sibling-number)))
                     (1+ num))
                   1))
              (previous-sibling-number ()
               (save-excursion
                 (let ((pos (point)))
                   (org-backward-heading-same-level 1)
                   (when (/= pos (point))
                     (heading-number)))))
              (number-list ()
               (let ((ancestor-numbers (save-excursion
                                         (cl-loop while (org-up-heading-safe)
                                                  collect (heading-number)))))
                 (nreverse (cons (heading-number) ancestor-numbers))))
              (add-overlay ()
               (let* ((ov-length (org-current-level))
                      (ov (make-overlay (point) (+ (point) ov-length)))
                      (ov-string (concat (mapconcat #'number-to-string (number-list) ".")
                                         ".")))
                 (overlay-put ov 'org-outline-numbers t)
                 (overlay-put ov 'display ov-string))))
    (remove-overlays nil nil 'org-outline-numbers t)
    (unless remove-p
      (org-with-wide-buffer
       (goto-char (point-min))
       (when (org-before-first-heading-p)
         (outline-next-heading))
       (cl-loop do (add-overlay)
                while (outline-next-heading))))))
