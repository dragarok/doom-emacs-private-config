(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(setq delete-by-moving-to-trash t)
(setq doom-localleader-key ",")

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

(setq gc-cons-threshold 4073741824 )
(setq show-trailing-whitespace t)

(setq org-roam-directory "~/Dropbox/org/notes/")
(setq org-roam-db-location "~/.org/org-roam.db")
(setq org-roam-dailies-directory "daily/")

(add-hook 'dired-mode-hook
          (lambda ()
            (dired-hide-details-mode)))


;; (setq wl-copy-process nil)
;; (defun wl-copy (text)
;;   (setq wl-copy-process (make-process :name "wl-copy"
;;                                       :buffer nil
;;                                       :command '("wl-copy" "-f" "-n")
;;                                       :connection-type 'pipe))
;;   (process-send-string wl-copy-process text)
;;   (process-send-eof wl-copy-process))
;; (defun wl-paste ()
;;   (if (and wl-copy-process (process-live-p wl-copy-process))
;;       nil ; should return nil if we're the current paste owner
;;       (shell-command-to-string "wl-paste -n | tr -d \r")))
;; (setq interprogram-cut-function 'wl-copy)
;; (setq interprogram-paste-function 'wl-paste)



;; ;;;###autoload
;; (defun copy-link-for-kindle ()
;;   (interactive)
;;   (elfeed-show-yank)
;;   (org-capture nil "k")
;;   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Add entry to wallabag                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun copy-link-for-kindle ()
  (interactive)
  (elfeed-show-yank)
  (wallabag-add-entry (car kill-ring) "")
  )


(setq doom-font (font-spec :family "Iosevka" :size 16)
      ;;       doom-variable-pitch-font (font-spec :family "FantasqueSansMono Nerd Font" :size 22)

      doom-variable-pitch-font (font-spec :family "Iosevka Etoile" :size 18)
      doom-serif-font (font-spec :family "Arvo" :size 18)
      ;; doom-variable-pitch-font (font-spec :family "Source Serif Pro" :size 22)
      ;; doom-serif-font (font-spec :family "Source Serif Pro" :weight 'light)
      doom-big-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 30))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org Mode Beautification                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package! org-superstar ; "prettier" bullets
  :hook (org-mode . org-superstar-mode)
  :config
  ;; Make leading stars truly invisible, by rendering them as spaces!
  (setq org-superstar-leading-bullet ?\s
        org-superstar-headline-bullets-list '(?\s)
        org-superstar-leading-fallback ?\s
        org-superstar-remove-leading-stars t
        org-superstar-todo-bullet-alist
        '(("TODO" . 9744)
          ("[ ]"  . 9744)
          ("DONE" . 9745)
          ("[X]"  . 9745)))
  ;; (org-superstar-restart)
  )


(use-package! org-fancy-priorities ; priority icons
  :after org
  :init
  :config
  (org-fancy-priorities-mode)
  (setq org-fancy-priorities-list
        `((?A ,(all-the-icons-octicon "flame" :height 1.2))
          (?B ,(all-the-icons-octicon "arrow-up" :height 1.2))
          (?C ,(all-the-icons-octicon "chevron-up" :height 1.2))
          (?D ,(all-the-icons-octicon "squirrel" :height 1.2))
          ))

  (setq org-priority-faces '((?A . (:foreground "red" :weight bold))
                             (?B . (:foreground "green" :weight bold))
                             (?C . (:foreground "tomato"))
                             (?D . (:foreground "orange"))))

  (setq org-priority-default 68
        org-priority-highest 65
        org-priority-lowest 68)
  )

(add-hook! 'org-mode-hook #'+org-pretty-mode #'mixed-pitch-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                       Org Mode Beautification End                                                     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(if (not window-system)
    (setq doom-theme 'doom-solarized-light))

;; ascii art taken from https://www.asciiart.eu/space/telescopes (Telescope by Dokusan)
(defun doom-dashboard-widget-banner ()
  (let ((point (point)))
    (mapc (lambda (line)
            (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                                'face 'bold))
            (insert "\n"))
          '("             _              "
            "           /(_))            "
            "         _/   /             "
            "        //   /              "
            "       //   /               "
            "      /\\__/                "
            "      \\O_/=-0             "
            "  _  /|| \\              "
            "   \\\\/()_) \\.              "
            "  ^^  <__> \\()             "
            "    //||\\\\              "
            "     //_||_\\\\               "
            "    // \\||/ \\\\              "
            "   //   ||   \\\\             "
            "  \\/    |/    \\/            "
            "  /     |      \\            "
            " /      |       \\           "
            "        |                   "
            "-----LIGHT-----            "))
    (when (and (display-graphic-p)
               (stringp fancy-splash-image)
               (file-readable-p fancy-splash-image))
      (let ((image (create-image (fancy-splash-image-file))))
        (add-text-properties
         point (point) `(display ,image rear-nonsticky (display)))
        (save-excursion
          (goto-char point)
          (insert (make-string
                   (truncate
                    (max 0 (+ 1 (/ (- +doom-dashboard--width
                                      (car (image-size image nil)))
                                   2))))
                   ? ))))
      (insert (make-string (or (cdr +doom-dashboard-banner-padding) 0)
                           ?\n)))))

(setq display-line-numbers-type 'relative)

;; (use-package nov
;;   :mode ("\\.epub\\'" . nov-mode)
;;   :config
;;   (setq nov-text-width t)
;;   (setq visual-fill-column-center-text t)
;;   (defun my-nov-font-setup ()
;;     (face-remap-add-relative 'variable-pitch :family "Overpass Nerd Font"
;;                              :height 1.2))
;;   (setq nov-text-width 80)
;;   (add-hook 'nov-mode-hook 'virtual-auto-fill-mode)
;;   (add-hook 'nov-mode-hook 'visual-fill-column-mode)
;;   (add-hook 'nov-mode-hook 'my-nov-font-setup))


(after! org
  (set-popup-rule! "*CAPTURE-*" :side 'left :size .30 :select t)
  ;; (set-popup-rule! "^CAPTURE-[A-Za-z]*\.org$" :side 'right :size .50 :select t :vslot 2 :ttl 3)
  ;; (set-popup-rule! "*helm*" :side 'bottom :height .40 :select t :vslot 5 :ttl 3)
  ;; (set-popup-rule! "^\\*Org Src" :side 'bottom :slot -2 :height 0.6 :width 0.5 :select t :autosave t :ttl nil :quit nil)
  (set-popup-rule! "*Org QL View:*" :side 'right :size .25 :select t)
  (set-popup-rule! "\\*RefTeX Select\\*" :size 80)
  (set-popup-rule! "*Org Select" :side 'bottom :size .50 :select t :vslot 2 :ttl 3)
  ;; (set-popup-rule! "*Calendar*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "Dictionary" :side 'bottom :height .40 :width 20 :select t :vslot 3 :ttl 3)
  ;;(set-popup-rule! "*eww*" :side 'right :size .40 :slect t :vslot 5 :ttl 3)
  (set-popup-rule! "*deadgrep" :side 'bottom :height .40 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "*org-roam" :side 'right :size .25 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "\\Swiper" :side 'bottom :size .30 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "*xwidget" :side 'right :size .40 :select t :vslot 5 :ttl 3)
  (set-popup-rule! "*eshell*" :side 'bottom :size .30 :select t :hslot 2 :ttl 3)
  (set-popup-rule! "*Org clock budget report*" :side 'bottom :size .40 :select t :hslot 2 :ttl 3)
  (set-popup-rule! "*Python:ob-ipython-py*" :side 'right :size .25 :select t)
  )

(after! org
  (autoload 'orch-toggle "orch" nil t))

(after! ein-notebook
  (defun +ein-buffer-p (buf)
    (or (memq buf (ein:notebook-opened-buffers))
        (memq buf (mapcar #'ein:notebooklist-get-buffer (ein:notebooklist-keys)))))
  (add-to-list 'doom-real-buffer-functions #'+ein-buffer-p nil #'eq)

  (defun spacemacs/ein:worksheet-merge-cell-next ()
    (interactive)
    (ein:worksheet-merge-cell (ein:worksheet--get-ws-or-error) (ein:worksheet-get-current-cell) t t))

  ;; (set-popup-rule! "^\\*ein" :ignore t)
  ;; keybindings mirror ipython web interface behavior
  (evil-define-key 'normal  ein:markdown-mode-map
    ;; keybindings mirror ipython web interface behavior
    "go" 'ein:worksheet-goto-next-input-km
    "gO" 'ein:worksheet-goto-prev-input-km)

  (evil-define-key 'insert ein:notebook-mode-map
    ;; keybindings mirror ipython web interface behavior
    "<C-return>" 'ein:worksheet-execute-cell-km
    "<C-H-return>" 'ein:worksheet-execute-cell-and-goto-next-km)

  ;; ein show images in there
  (setq ein:output-area-inlined-images t)

  (map! :map ein:notebook-mode-map
        ;; Insert new cell, Execute cells
        ;; Merge, Split, Remove or Move cells
        "<C-H-return>" 'ein:worksheet-execute-cell-km
        "<H-return>" 'ein:worksheet-execute-cell-and-goto-next-km
        "H-o" 'ein:worksheet-insert-cell-below-km
        "H-O" 'ein:worksheet-insert-cell-above-km
        "H-c" 'ein:worksheet-change-cell-type-km
        "H-b" 'ein:worksheet-split-cell-at-point-km
        "H-k" 'ein:worksheet-move-cell-up-km
        "H-j" 'ein:worksheet-move-cell-down-km
        "C-H-k" 'ein:worksheet-merge-cell-km
        "C-H-j" 'spacemacs/ein:worksheet-merge-cell-next
        "H-y" 'ein:worksheet-copy-cell-km
        "H-t" 'ein:worksheet-toggle-output-km
        "H-p" 'ein:worksheet-yank-cell-km
        "H-d" 'ein:worksheet-kill-cell-km
        "H-;" 'ein:notebook-scratchsheet-open-km
        ;; Output
        "C-H-o" 'ein:worksheet-toggle-output-km
        "C-l" 'ein:worksheet-clear-output-km
        "C-H-l" 'ein:worksheet-clear-all-output-km
        ;; Notebook Opening and closing
        "C-H-s" 'ein:notebook-save-notebook-command-km
        "C-H-r" 'ein:notebook-rename-command-km
        "C-H-x" 'ein:notebook-close-km
        :map ein:notebooklist-mode-map
        :nv "O" 'ein:notebook-open-km
        :nv "o" 'ace-link-custom)

  (map!  :localleader
         :map ein:notebook-mode-map
         :desc "Show Hydra" :n "?" #'+ein/hydra/body
         :desc "Change cell type" :n "c" #'ein:worksheet-change-cell-type-km
         :desc "Execute and step" :n "RET" #'ein:worksheet-execute-cell-and-goto-next
         :desc "Yank cell" :n "y" #'ein:worksheet-copy-cell
         :desc "Paste cell" :n "p" #'ein:worksheet-yank-cell
         :desc "Delete cell" :n "d" #'ein:worksheet-kill-cell
         :desc "Insert cell below" :n "o" #'ein:worksheet-insert-cell-below
         :desc "Insert cell above" :n "O" #'ein:worksheet-insert-cell-above
         :desc "Next cell" :n "j" #'ein:worksheet-goto-next-input
         :desc "Previous cell" :n "k" #'ein:worksheet-goto-prev-input
         :desc "Save notebook" :n "fs" #'ein:notebook-save-notebook-command)

  (add-hook 'ein:notebook-mode-hook #'virtual-auto-fill-mode)
  (add-hook 'ein:markdown-mode-hook #'virtual-auto-fill-mode)
  ;; (add-hook 'ein:ipdb-mode-hook #'virtual-auto-fill-mode)
  ;; (add-hook 'ein:shared-output-mode-hook #'virtual-auto-fill-mode)
  )

(defun my-preview-latex ()
  "Preview LaTeX from the current cell in a separate buffer.

Handles only markdown and code cells, but both in a bit different
ways: on the former, its input is being rendered, while on the
latter - its output."
  (interactive)
  (let* ((cell (ein:worksheet-get-current-cell))
	 (text-to-render
	  (cond ((ein:markdowncell-p cell) (slot-value cell :input))
		((ein:codecell-p cell)
		 (plist-get (car (cl-remove-if-not
				  (lambda (e) (string= (plist-get e :name) "stdout"))
				  (slot-value cell :outputs)))
			    :text))
		(t (error "Unsupported cell type"))))
	 (buffer (get-buffer-create " *ein: LaTeX preview*")))
    (with-current-buffer buffer
      (when buffer-read-only
	(toggle-read-only))
      (unless (= (point-min) (point-max))
	(delete-region (point-min) (point-max)))
      (insert text-to-render)
      (goto-char (point-min))
      (org-mode)
      (org-toggle-latex-fragment 16)
      (special-mode)
      (unless buffer-read-only
	(toggle-read-only))
      (display-buffer
       buffer
       '((display-buffer-below-selected display-buffer-at-bottom)
         (inhibit-same-window . t)))
      (fit-window-to-buffer (window-in-direction 'below)))))

;; (after! dash-docs
;;   (setq counsel-dash-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))
;;   (setq dash-docs-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas")))

(after! ess
  (set-popup-rule! "^\\*R:" :ignore t))

(global-set-key (kbd "<f6>") 'spray-mode)

(use-package spray
  ;; :commands (spray-faster spray-slower)
  :defer t
  :config
  (setq spray-wpm 500
        spray-height 700)
  :bind (:map spray-mode-map
         ("H-7" . spray-faster)
         ("H-8" . spray-slower)
         ("H-9" . spray-start/stop)
         ("H-0" . spray-quit)
         )
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Elfeed Setup                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(require 'avy)
(require 'elfeed-goodies)
;; (require 'xwidget)

;; * workflow and layout
;;;###autoload
(defun =rss ()
  "Activate (or switch to) `elfeed' in its workspace."
  (interactive)
  (unless (featurep! :ui workspaces)
    (user-error ":feature workspaces is required, but disabled"))
  (+workspace-switch "rss" t)
  (if-let* ((buf (cl-find-if (lambda (it) (string-match-p "^\\*elfeed" (buffer-name (window-buffer it))))
                             (doom-visible-windows))))
      (select-window (get-buffer-window buf)) (call-interactively 'elfeed))
  (+workspace/display))

;;;###autoload
(defun +rss/quit ()
  (interactive)
  (doom-kill-matching-buffers "^\\*elfeed")
  (dolist (file rmh-elfeed-org-files) (when-let* ((buf (get-file-buffer file))) (kill-buffer buf)))
  (+workspace/delete "rss"))


;;;###autoload
(defun +rss|elfeed-wrap ()
  "Enhances an elfeed entry's readability by wrapping it to a width of
`fill-column' and centering it with `visual-fill-column-mode'."
  (let ((inhibit-read-only t)
        (inhibit-modification-hooks t))
    (setq-local truncate-lines nil)
    (setq-local shr-width 120)
    (setq-local line-spacing 0.3)
    (setq-local shr-current-font '(:family "Charter" :height 1.2))
    (set-buffer-modified-p nil)))

;;;###autoload
(defun +rss/delete-pane ()
  "Delete the *elfeed-entry* split pane."
  (interactive)
  (let* ((buff (get-buffer "*elfeed-entry*"))
         (window (get-buffer-window buff)))
    (kill-buffer buff)
    (delete-window window)))

;;;###autoload
(defun +rss-popup-pane (buf)
  "Display BUF in a popup."
  (select-window (display-buffer-in-direction buf '((direction . right) (window-width . 0.6)))))

;;;###autoload
(defun +rss/open (entry)
  "Display the currently selected item in a buffer."
  (interactive (list (elfeed-search-selected :ignore-region)))
  (when (elfeed-entry-p entry)
    (elfeed-untag entry 'unread)
    (elfeed-search-update-entry entry)
    (elfeed-show-entry entry)))

;;;###autoload
(defun +rss/next ()
  "Show the next item in the elfeed-search buffer."
  (interactive)
  (funcall elfeed-show-entry-delete)
  (with-current-buffer (elfeed-search-buffer)
    (forward-line)
    (call-interactively '+rss/open)))

;;;###autoload
(defun +rss/previous ()
  "Show the previous item in the elfeed-search buffer."
  (interactive)
  (funcall elfeed-show-entry-delete)
  (with-current-buffer (elfeed-search-buffer)
    (forward-line -1)
    (call-interactively '+rss/open)))

;;;###autoload
(defun +rss-dead-feeds (&optional years)
  "Return a list of feeds that haven't posted anything in YEARS."
  (let* ((years (or years 1.0))
         (living-feeds (make-hash-table :test 'equal))
         (seconds (* years 365.0 24 60 60))
         (threshold (- (float-time) seconds)))
    (with-elfeed-db-visit (entry feed)
      (let ((date (elfeed-entry-date entry)))
        (when (> date threshold)
          (setf (gethash (elfeed-feed-url feed) living-feeds) t))))
    (cl-loop for url in (elfeed-feed-list)
             unless (gethash url living-feeds)
             collect url)))

;;;###autoload
(defun +rss/elfeed-search-print-entry (entry)
  "Print ENTRY to the buffer."
  (let* ((elfeed-goodies/tag-column-width 40)
         (elfeed-goodies/feed-source-column-width 30)
         (title (or (elfeed-meta entry :title) (elfeed-entry-title entry) ""))
         (title-faces (elfeed-search--faces (elfeed-entry-tags entry)))
         (feed (elfeed-entry-feed entry))
         (feed-title
          (when feed
            (or (elfeed-meta feed :title) (elfeed-feed-title feed))))
         (tags (mapcar #'symbol-name (elfeed-entry-tags entry)))
         (tags-str (concat (mapconcat 'identity tags ",")))
         (title-width (- (window-width) elfeed-goodies/feed-source-column-width
                         elfeed-goodies/tag-column-width 4))

         ;; (tag-column (elfeed-format-column
         ;;              tags-str (elfeed-clamp (length tags-str)
         ;;                                     elfeed-goodies/tag-column-width
         ;;                                     elfeed-goodies/tag-column-width)
         ;;              :left))
         (feed-column (elfeed-format-column
                       feed-title (elfeed-clamp elfeed-goodies/feed-source-column-width
                                                elfeed-goodies/feed-source-column-width
                                                elfeed-goodies/feed-source-column-width)
                       :left)))

    (insert (propertize feed-column 'face 'elfeed-search-feed-face) " ")
    ;; (insert (propertize tag-column 'face 'elfeed-search-tag-face) " ")
    (insert (propertize title 'face title-faces 'kbd-help title))
    (setq-local line-spacing 0.5)))

;;;###autoload
(defun +rss/elfeed-search--header-1 ()
  "Computes the string to be used as the Elfeed header."
  (cond
   ((zerop (elfeed-db-last-update))
    (elfeed-search--intro-header))
   ((> (elfeed-queue-count-total) 0)
    (let ((total (elfeed-queue-count-total))
          (in-process (elfeed-queue-count-active)))
      (format "%d feeds pending, %d in process"
              (- total in-process) in-process)))
   ((let* ((db-time (seconds-to-time (elfeed-db-last-update)))
           (update (format-time-string "%Y-%m-%d %H:%M" db-time))
           (unread (elfeed-search--count-unread)))
      (format "Updated %s, %s%s"
              (propertize update 'face 'elfeed-search-last-update-face)
              (propertize unread 'face 'elfeed-search-unread-count-face)
              (cond
               (elfeed-search-filter-active "")
               ((string-match-p "[^ ]" elfeed-search-filter)
                (concat ", " (propertize elfeed-search-filter
                                         'face 'elfeed-search-filter-face)))
               ("")))))))

;;;###autoload
(defun +rss/elfeed-search-adjust-show-entry (entry)
  "Display the currently selected item in a buffer."
  (interactive (list (elfeed-search-selected :ignore-region)))
  (require 'elfeed-show)
  (when (elfeed-entry-p entry)
    (elfeed-untag entry 'unread)
    (elfeed-search-update-entry entry)
    (+rss/elfeed-adjust-show-entry entry)))

;;;###autoload
(defun +rss/elfeed-show-next ()
  "Show the next item in the elfeed-search buffer."
  (interactive)
  (quit-window)
  (with-current-buffer (elfeed-search-buffer)
    (forward-line)
    (call-interactively #'+rss/elfeed-search-adjust-show-entry)))

;;;###autoload
(defun +rss/elfeed-show-prev ()
  "Show the previous item in the elfeed-search buffer."
  (interactive)
  (quit-window)
  (with-current-buffer (elfeed-search-buffer)
    (forward-line -1)
    (call-interactively #'+rss/elfeed-search-adjust-show-entry)))


;;;###autoload
(defun +rss/elfeed-show-entry (entry)
  "Display ENTRY in the current buffer."
  (let ((buff (get-buffer-create "*elfeed-entry*")))
    (+rss-popup-pane buff)
    (with-current-buffer buff
      (elfeed-show-mode)
      (setq elfeed-show-entry entry)
      (elfeed-show-refresh))))

;;;###autoload
(defun +rss/elfeed-adjust-show-entry (entry)
  "Display ENTRY in the current buffer."
  (let ((buff (get-buffer-create "*elfeed-entry*")))
    (+rss-popup-pane buff)
    (with-current-buffer buff
      (elfeed-show-mode)
      (setq elfeed-show-entry entry)
      (elfeed-show-refresh))))

;; * elfeed-show UI
;;;###autoload
(defun +rss/elfeed-show-refresh--better-style ()
  "Update the buffer to match the selected entry, using a mail-style."
  (interactive)
  (let* ((inhibit-read-only t)
         (title (elfeed-entry-title elfeed-show-entry))
         (date (seconds-to-time (elfeed-entry-date elfeed-show-entry)))
         (author (elfeed-meta elfeed-show-entry :author))
         (link (elfeed-entry-link elfeed-show-entry))
         (tags (elfeed-entry-tags elfeed-show-entry))
         (tagsstr (mapconcat #'symbol-name tags ", "))
         (nicedate (format-time-string "%a, %e %b %Y %T %Z" date))
         (content (elfeed-deref (elfeed-entry-content elfeed-show-entry)))
         (type (elfeed-entry-content-type elfeed-show-entry))
         (feed (elfeed-entry-feed elfeed-show-entry))
         (feed-title (elfeed-feed-title feed))
         (base (and feed (elfeed-compute-base (elfeed-feed-url feed)))))
    (erase-buffer)
    (insert "\n")
    (insert (format "%s\n\n" (propertize title 'face 'elfeed-show-title-face)))
    (insert (format "%s\t" (propertize feed-title 'face 'elfeed-show-feed-face)))
    (when (and author elfeed-show-entry-author)
      (insert (format "%s\n" (propertize author 'face 'elfeed-show-author-face))))
    (insert (format "%s\n\n" (propertize nicedate 'face 'elfeed-show-misc-face)))
    (when tags
      (insert (format "%s\n"
                      (propertize tagsstr 'face 'elfeed-show-tag-face))))
    ;; (insert (propertize "Link: " 'face 'message-header-name))
    ;; (elfeed-insert-link link link)
    ;; (insert "\n")
    (cl-loop for enclosure in (elfeed-entry-enclosures elfeed-show-entry)
             do (insert (propertize "Enclosure: " 'face 'message-header-name))
             do (elfeed-insert-link (car enclosure))
             do (insert "\n"))
    (insert "\n")
    (if content
        (if (eq type 'html)
            (elfeed-insert-html content base)
          (insert (propertize content 'face 'variable-pitch)))
      (insert (propertize "(empty)\n" 'face 'italic)))
    (goto-char (point-min))))

(add-hook! 'elfeed-search-mode-hook 'elfeed-update)


;; * ace-link and xwidget
;;;###autoload
(defun ace-link--elfeed-collect ()
  "Collect the positions of visible links in `elfeed' buffer."
  (let (candidates pt)
    (save-excursion
      (save-restriction
        (narrow-to-region
         (window-start)
         (window-end))
        (goto-char (point-min))
        (setq pt (point))
        (while (progn (shr-next-link)
                      (> (point) pt))
          (setq pt (point))
          (when (plist-get (text-properties-at (point)) 'shr-url)
            (push (point) candidates)))
        (nreverse candidates)))))

;;;###autoload
(defun ace-link--elfeed-action  (pt)
  (goto-char pt)
  (let ((url (get-text-property (point) 'shr-url)))
    (browse-url url))
  ;; (xwidget-webkit-browse-url-elfeed)
  )

;;;###autoload
(defun xwidget-webkit-browse-url-elfeed ()
  (let ((url (get-text-property (point) 'shr-url)))
    (cond
     ((not url)
      (message "No link under point"))
     ((string-match "^mailto:" url)
      (browse-url-mail url))
     (t (let*
            ((bufname "*elfeed-xwidget-webkit*")
             xw)
          (select-window (display-buffer (get-buffer-create bufname)))
          ;; The xwidget id is stored in a text property, so we need to have
          ;; at least character in this buffer.
          ;; Insert invisible url, good default for next `g' to browse url.
          (insert url)
          (put-text-property 1 (+ 1 (length url)) 'invisible t)
          (setq xw (xwidget-insert 1 'webkit bufname
                                   (xwidget-window-inside-pixel-width (selected-window))
                                   (xwidget-window-inside-pixel-height (selected-window))))
          (xwidget-put xw 'callback 'xwidget-webkit-elfeed-callback)
          (xwidget-webkit-mode)
          (xwidget-webkit-goto-uri xw url))))))

;;;###autoload
(defun xwidget-webkit-elfeed-callback (xwidget xwidget-event-type)
  "Callback for xwidgets.
XWIDGET instance, XWIDGET-EVENT-TYPE depends on the originating xwidget."
  (if (not (buffer-live-p (xwidget-buffer xwidget)))
      (xwidget-log
       "error: callback called for xwidget with dead buffer")
    (with-current-buffer (xwidget-buffer xwidget)
      (cond ((eq xwidget-event-type 'load-changed)
;;; We do not change selected window for the finish of loading a page.
;;; And do not adjust webkit size to window here, the selected window
;;; can be the mini-buffer window unwantedly.
             (let ((title (xwidget-webkit-title xwidget)))
               (xwidget-log "webkit finished loading: %s" title)))
            ((eq xwidget-event-type 'decide-policy)
             (let ((strarg  (nth 3 last-input-event)))
               (if (string-match ".*#\\(.*\\)" strarg)
                   (xwidget-webkit-show-id-or-named-element
                    xwidget
                    (match-string 1 strarg)))))
;;; TODO: Response handling other than download.
            ((eq xwidget-event-type 'response-callback)
             (let ((url  (nth 3 last-input-event))
                   (mime-type (nth 4 last-input-event))
                   (file-name (nth 5 last-input-event)))
               (xwidget-webkit-save-as-file xwidget url mime-type file-name)))
            ((eq xwidget-event-type 'javascript-callback)
             (let ((proc (nth 3 last-input-event))
                   (arg  (nth 4 last-input-event)))
               ;; Some javascript return vector as result
               (if (vectorp arg)
                   (funcall proc (seq-into arg 'list))
                 (funcall proc arg))))
            (t (xwidget-log "unhandled event:%s" xwidget-event-type))))))

;;;###autoload
(defun ace-link-elfeed ()
  "Open a visible link in `elfeed' buffer."
  (interactive)
  (let ((pt (avy-with ace-link-elfeed
              (avy--process
               (ace-link--elfeed-collect)
               #'avy--overlay-pre))))
    (ace-link--elfeed-action pt)))



(defvar +rss-split-direction 'below
  "What direction to pop up the entry buffer in elfeed.")

(use-package! elfeed
  :commands elfeed
  :init
  (defface elfeed-show-title-face '((t (:weight ultrabold :slant italic :height 1.5)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-author-face `((t (:weight light :height 1.2)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-content-face `((t (:inherit 'variable-pitch)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-feed-face `((t (:weight bold)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-tag-face `((t (:weight extralight)))
    "tag face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-misc-face `((t (:weight extralight)))
    "tag face in elfeed show buffer"
    :group 'elfeed)
  :config
  (setq elfeed-search-filter "@3-week-ago +unread "
        elfeed-db-directory "~/.elfeed/"
        elfeed-enclosure-default-dir "~/.elfeed/enclosures/"
        elfeed-search-print-entry-function '+rss/elfeed-search-print-entry
        elfeed-search-title-min-width 80
        elfeed-show-entry-switch #'pop-to-buffer
        elfeed-show-entry-delete #'+rss/delete-pane
        elfeed-show-refresh-function #'+rss/elfeed-show-refresh--better-style
        shr-max-image-proportion 0.6)

  ;; Ensure elfeed buffers are treated as real
  (push (lambda (buf) (string-match-p "^\\*elfeed" (buffer-name buf)))
        doom-real-buffer-functions)
  ;; Enhance readability of a post
  (add-hook! 'elfeed-show-mode-hook
    (writeroom-mode 1)
    (solaire-mode 1)
    ;; (awesome-tab-mode -1)
    (hide-mode-line-mode 1))
  (add-hook! 'elfeed-search-update-hook #'(solaire-mode
                                           hide-mode-line-mode))

  (after! elfeed-search
    (map! :map elfeed-search-mode-map
          :after elfeed-search
          [remap kill-this-buffer] "q"
          [remap kill-buffer] "q"
          :n doom-leader-key nil
          :n "e" #'elfeed-update
          :n "r" #'elfeed-search-untag-all-unread
          :n "u" #'elfeed-search-tag-all-unread
          :n "s" #'elfeed-search-live-filter
          :n "RET" #'elfeed-search-show-entry
          :n "p" #'elfeed-show-pdf
          :n "+" #'elfeed-search-tag-all
          :n "-" #'elfeed-search-untag-all
          :n "S" #'elfeed-search-set-filter
          :n "b" #'elfeed-search-browse-url
          :n "," #'copy-link-for-kindle
          :n "y" #'elfeed-search-yank)
    (after! evil-snipe
      (push 'elfeed-search-mode evil-snipe-disabled-modes))
    (set-evil-initial-state! 'elfeed-search-mode 'normal)
    ;; avoid ligature hang
    (advice-add #'elfeed-search--header-1 :override #'+rss/elfeed-search--header-1)
    (advice-add #'elfeed-show-next :override #'+rss/elfeed-show-next)
    (advice-add #'elfeed-show-prev :override #'+rss/elfeed-show-prev)
    )

  (after! elfeed-show
    (map! :map elfeed-show-mode-map
          :after elfeed-show
          [remap kill-this-buffer] "q"
          [remap kill-buffer] "q"
          :n doom-leader-key nil
          :nm "z" #'prot/elfeed-show-eww
          :nm "x" #'prot/elfeed-kill-buffer-close-window-dwim
          :nm "q" #'+rss/delete-pane
          :nm "o" #'ace-link-elfeed
          :nm "RET" #'org-ref-elfeed-add
          :nm "n" #'elfeed-show-next
          :nm "N" #'elfeed-show-prev
          :nm "p" #'elfeed-show-pdf
          :nm "+" #'elfeed-show-tag
          :nm "-" #'elfeed-show-untag
          :nm "s" #'elfeed-show-new-live-search
          :nm "," #'copy-link-for-kindle
          :nm "y" #'elfeed-show-yank)
    (after! evil-snipe
      (push 'elfeed-show-mode evil-snipe-disabled-modes))
    (set-evil-initial-state! 'elfeed-show-mode 'normal)
    (advice-add #'elfeed-show-entry :override #'+rss/elfeed-show-entry)


    ;; elfeed get pdf and show them
    ;; taken from tecosaur's config
    (require 'url)

    (defvar elfeed-pdf-dir
      (expand-file-name "pdfs/"
                        (file-name-directory (directory-file-name elfeed-enclosure-default-dir))))

    (defvar elfeed-link-pdfs
      '(("https://www.jstatsoft.org/index.php/jss/article/view/v0\\([^/]+\\)" . "https://www.jstatsoft.org/index.php/jss/article/view/v0\\1/v\\1.pdf")
        ("http://arxiv.org/abs/\\([^/]+\\)" . "https://arxiv.org/pdf/\\1.pdf"))
      "List of alists of the form (REGEX-FOR-LINK . FORM-FOR-PDF)")

    (defun elfeed-show-pdf (entry)
      (interactive
       (list (or elfeed-show-entry (elfeed-search-selected :ignore-region))))
      (let ((link (elfeed-entry-link entry))
            (feed-name (plist-get (elfeed-feed-meta (elfeed-entry-feed entry)) :title))
            (title (elfeed-entry-title entry))
            (file-view-function
             (lambda (f)
               (when elfeed-show-entry
                 (elfeed-kill-buffer))
               (pop-to-buffer (find-file-noselect f))))
            pdf)

        (let ((file (expand-file-name
                     (concat (subst-char-in-string ?/ ?, title) ".pdf")
                     (expand-file-name (subst-char-in-string ?/ ?, feed-name)
                                       elfeed-pdf-dir))))
          (if (file-exists-p file)
              (funcall file-view-function file)
            (dolist (link-pdf elfeed-link-pdfs)
              (when (and (string-match-p (car link-pdf) link)
                         (not pdf))
                (setq pdf (replace-regexp-in-string (car link-pdf) (cdr link-pdf) link))))
            (if (not pdf)
                (message "No associated PDF for entry")
              (message "Fetching %s" pdf)
              (unless (file-exists-p (file-name-directory file))
                (make-directory (file-name-directory file) t))
              (url-copy-file pdf file)
              (funcall file-view-function file))))))




    )


  (elfeed-org)
  (use-package! elfeed-link)


  ;; From protesilas's config
  (defun prot/elfeed-show-eww (&optional link)
    "Browse current `elfeed' entry link in `eww'.
Only show the readable part once the website loads.  This can
fail on poorly-designed websites."
    (interactive)
    (let* ((entry (if (eq major-mode 'elfeed-show-mode)
                      elfeed-show-entry
                    (elfeed-search-selected :ignore-region)))
           (link (if link link (elfeed-entry-link entry))))
      (eww link)
      (add-hook 'eww-after-render-hook 'eww-readable nil t)))
  (defun prot/elfeed-search-other-window (&optional arg)
    "Browse `elfeed' entry in the other window.
With \\[universal-argument] browse the entry in `eww' using the
`prot/elfeed-show-eww' wrapper."
    (interactive "P")
    (let* ((entry (if (eq major-mode 'elfeed-show-mode)
                      elfeed-show-entry
                    (elfeed-search-selected :ignore-region)))
           (link (elfeed-entry-link entry))
           (win (selected-window)))
      (with-current-buffer (get-buffer "*elfeed-search*")
        (unless (one-window-p)              ; experimental
          (delete-other-windows win))
        (split-window win (/ (frame-height) 5) 'below)
        (other-window 1)
        (if arg
            (progn
              (when (eq major-mode 'elfeed-search-mode)
                (elfeed-search-untag-all-unread))
              (prot/elfeed-show-eww link))
          (elfeed-search-show-entry entry)))))
  (defun prot/elfeed-kill-buffer-close-window-dwim ()
    "Do-what-I-mean way to handle `elfeed' windows and buffers.

When in an entry buffer, kill the buffer and return to the Elfeed
Search view.  If the entry is in its own window, delete it as
well.

When in the search view, close all other windows.  Else just kill
the buffer."
    (interactive)
    (let ((win (selected-window)))
      (cond ((eq major-mode 'elfeed-show-mode)
             (elfeed-kill-buffer)
             (unless (one-window-p) (delete-window win))
             (switch-to-buffer "*elfeed-search*"))
            ((eq major-mode 'elfeed-search-mode)
             (if (one-window-p)
                 (elfeed-search-quit-window)
               (delete-other-windows win))))))

  ;; scoring elfeed entries for better visibility
  ;; Jkitchin's config
  (defun score-elfeed-entry (entry)
    (let ((title (elfeed-entry-title entry))
          (content (elfeed-deref (elfeed-entry-content entry)))
          (score 0))
      (cl-loop for (pattern n) in '(("space" 1)
                                    ("machine learning\\|neural" 1)
                                    ("entrepreneurship 2")
                                    ("startups" 1)
                                    ("breakthrough" 3)
                                    ("state of the art" 3))
               if (string-match pattern title)
               do (cl-incf score n)
               if (string-match pattern content)
               do (cl-incf score n))
      (message "%s - %s" title score)

      ;; store score for later in case I ever integrate machine learning
      (setf (elfeed-meta entry :my/score) score)

      (cond
       ((= score 1)
        (elfeed-tag entry 'relevant))
       ((> score 1)
        (elfeed-tag entry 'important)))
      entry))
  (add-hook 'elfeed-new-entry-hook 'score-elfeed-entry)
  ;; faces for relevant and important feeds
  (defface relevant-elfeed-entry
    `((t :background ,(color-lighten-name "orange1" 40)))
    "Marks a relevant Elfeed entry.")
  (defface important-elfeed-entry
    `((t :background ,(color-lighten-name "OrangeRed2" 40)))
    "Marks an important Elfeed entry.")
  (push '(relevant relevant-elfeed-entry)
        elfeed-search-face-alist)
  (push '(important important-elfeed-entry)
        elfeed-search-face-alist)

  )
(use-package! elfeed-org
  :commands (elfeed-org)
  :config
  (setq rmh-elfeed-org-files (list "~/Dropbox/elfeed/elfeed.org")))
(use-package! org-ref-elfeed
  :when (featurep! :tools reference)
  :commands (org-ref-elfeed-add))



;; (use-package eww
;;   :defer t
;;   :commands (eww
;;              eww-browse-url
;;              eww-search-words
;;              eww-open-in-new-buffer
;;              eww-open-file
;;              prot/eww-visit-history)
;;   :config
;;   (setq eww-restore-desktop nil)
;;   (setq eww-desktop-remove-duplicates t)
;;   (setq eww-header-line-format "%u")
;;   (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
;;   (setq eww-download-directory "~/Downloads/")
;;   (setq eww-suggest-uris
;;         '(eww-links-at-point
;;           eww-prompt-history
;;           thing-at-point-url-at-point))
;;   (setq eww-bookmarks-directory "~/.emacs.d/eww-bookmarks/")
;;   (setq eww-history-limit 150)
;;   (setq eww-use-external-browser-for-content-type
;;         "\\`\\(video/\\|audio/\\|application/pdf\\)")
;;   (setq eww-browse-url-new-window-is-tab nil)
;;   (setq eww-form-checkbox-selected-symbol "[X]")
;;   (setq eww-form-checkbox-symbol "[ ]")

;;   (defun prot/eww-visit-history (&optional arg)
;;     "Revisit a URL from `eww-prompt-history' using completion.
;; With \\[universal-argument] produce a new buffer."
;;     (interactive "P")
;;     (let ((history eww-prompt-history)  ; eww-bookmarks
;;           (new (if arg t nil)))
;;       (icomplete-vertical-do ()
;;                              (eww
;;                               (completing-read "Visit website from history: " history nil t)
;;                               new))))
;;   :bind (:map eww-mode-map
;;          ("j" . next-line)
;;          ("k" . previous-line)
;;          ("f" . forward-char)
;;          ("b" . backward-char)
;;          ("a" . prot/eww-org-archive-current-url)
;;          ("B" . eww-back-url)
;;          ("N" . eww-next-url)
;;          ("P" . eww-previous-url)))

;; (use-package browse-url
;;   :after eww
;;   :config
;;   (setq browse-url-browser-function 'eww-browse-url))

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

(use-package! ace-link
  :commands (ace-link))
(after! avy
  (setq avy-keys '(?a ?s ?d ?f ?j ?k ?l ?\;)))
(after! ace-window
  (setq aw-keys '(?f ?d ?s ?r ?e ?w)
        aw-scope 'frame
        aw-ignore-current t
        aw-background nil))

(use-package multiple-cursors
  :functions hydra-multiple-cursors
  :bind
  ("M-u" . hydra-multiple-cursors/body)
  :preface
  ;; insert specific serial number
  (defvar ladicle/mc/insert-numbers-hist nil)
  (defvar ladicle/mc/insert-numbers-inc 1)
  (defvar ladicle/mc/insert-numbers-pad "%01d")

  (defun ladicle/mc/insert-numbers (start inc pad)
    "Insert increasing numbers for each cursor specifically."
    (interactive
     (list (read-number "Start from: " 0)
           (read-number "Increment by: " 1)
           (read-string "Padding (%01d): " nil ladicle/mc/insert-numbers-hist "%01d")))
    (setq mc--insert-numbers-number start)
    (setq ladicle/mc/insert-numbers-inc inc)
    (setq ladicle/mc/insert-numbers-pad pad)
    (mc/for-each-cursor-ordered
     (mc/execute-command-for-fake-cursor
      'ladicle/mc--insert-number-and-increase
      cursor)))

  (defun ladicle/mc--insert-number-and-increase ()
    (interactive)
    (insert (format ladicle/mc/insert-numbers-pad mc--insert-numbers-number))
    (setq mc--insert-numbers-number (+ mc--insert-numbers-number ladicle/mc/insert-numbers-inc)))

  :config
  (with-eval-after-load 'hydra
    (defhydra hydra-multiple-cursors (:color pink :hint nil)
      "
                                                                        ╔════════╗
    Point^^^^^^             Misc^^            Insert                            ║ Cursor ║
  ──────────────────────────────────────────────────────────────────────╨────────╜
     _k_    _K_    _M-k_    [_l_] edit lines  [_i_] 0...
     ^↑^    ^↑^     ^↑^     [_m_] mark all    [_a_] letters
    mark^^ skip^^^ un-mk^   [_s_] sort        [_n_] numbers
     ^↓^    ^↓^     ^↓^
     _j_    _J_    _M-j_
  ╭──────────────────────────────────────────────────────────────────────────────╯
                           [_q_]: quit, [Click]: point
"
      ("l" mc/edit-lines :exit t)
      ("m" mc/mark-all-like-this :exit t)
      ("j" mc/mark-next-like-this)
      ("J" mc/skip-to-next-like-this)
      ("M-j" mc/unmark-next-like-this)
      ("k" mc/mark-previous-like-this)
      ("K" mc/skip-to-previous-like-this)
      ("M-k" mc/unmark-previous-like-this)
      ("s" mc/mark-all-in-region-regexp :exit t)
      ("i" mc/insert-numbers :exit t)
      ("a" mc/insert-letters :exit t)
      ("n" ladicle/mc/insert-numbers :exit t)
      ("<mouse-1>" mc/add-cursor-on-click)
      ;; Help with click recognition in this hydra
      ("<down-mouse-1>" ignore)
      ("<drag-mouse-1>" ignore)
      ("q" nil))))

;;;###autoload
(defun unpackaged/iedit-or-flyspell ()
  "Toggle `iedit-mode' or correct previous misspelling with `flyspell', depending on context.
With point in code or when `iedit-mode' is already active, toggle
`iedit-mode'.  With point in a comment or string, and when
`iedit-mode' is not already active, auto-correct previous
misspelled word with `flyspell'.  Call this command a second time
to choose a different correction."
  (interactive)
  (if (or (bound-and-true-p iedit-mode)
          (and (derived-mode-p 'prog-mode)
               (not (or (nth 4 (syntax-ppss))
                        (nth 3 (syntax-ppss))))))
      ;; prog-mode is active and point is in a comment, string, or
      ;; already in iedit-mode
      (call-interactively #'iedit-mode)
    ;; Not prog-mode or not in comment or string
    (if (not (equal flyspell-previous-command this-command))
        ;; FIXME: This mostly works, but if there are two words on the
        ;; same line that are misspelled, it doesn't work quite right
        ;; when correcting the earlier word after correcting the later
        ;; one

        ;; First correction; autocorrect
        (call-interactively 'flyspell-auto-correct-previous-word)
      ;; First correction was not wanted; use popup to choose
      (progn
        (save-excursion
          (undo))  ; This doesn't move point, which I think may be the problem.
        (flyspell-region (line-beginning-position) (line-end-position))
        (call-interactively 'flyspell-correct-previous-word-generic)))))

;;;###autoload
(defun unpackaged/magit-status ()
  "Open a `magit-status' buffer and close the other window so only Magit is visible.
If a file was visited in the buffer that was active when this
command was called, go to its unstaged changes section."
  (interactive)
  (let* ((buffer-file-path (when buffer-file-name
                             (file-relative-name buffer-file-name
                                                 (locate-dominating-file buffer-file-name ".git"))))
         (section-ident `((file . ,buffer-file-path) (unstaged) (status))))
    (call-interactively #'magit-status)
    (delete-other-windows)
    (when buffer-file-path
      (goto-char (point-min))
      (cl-loop until (when (equal section-ident (magit-section-ident (magit-current-section)))
                       (magit-section-show (magit-current-section))
                       (recenter)
                       t)
               do (condition-case nil
                      (magit-section-forward)
                    (error (cl-return (magit-status-goto-initial-section-1))))))))

(use-package plantuml-mode
  :defer t
  :mode ("\\.plantuml\\'" . plantuml-mode)
  :config
  (setq plantuml-executable-path "/usr/bin/plantuml")
  (setq plantuml-default-exec-mode 'executable)
  )

(use-package smerge-mode
  :after hydra
  :config
  (defhydra unpackaged/smerge-hydra
    (:color pink :hint nil :post (smerge-auto-leave))
    "
^Move^       ^Keep^               ^Diff^                 ^Other^
^^-----------^^-------------------^^---------------------^^-------
_n_ext       _b_ase               _<_: upper/base        _C_ombine
_p_rev       _u_pper              _=_: upper/lower       _r_esolve
^^           _l_ower              _>_: base/lower        _k_ill current
^^           _a_ll                _R_efine
^^           _RET_: current       _E_diff
"
    ("n" smerge-next)
    ("p" smerge-prev)
    ("b" smerge-keep-base)
    ("u" smerge-keep-upper)
    ("l" smerge-keep-lower)
    ("a" smerge-keep-all)
    ("RET" smerge-keep-current)
    ("\C-m" smerge-keep-current)
    ("<" smerge-diff-base-upper)
    ("=" smerge-diff-upper-lower)
    (">" smerge-diff-base-lower)
    ("R" smerge-refine)
    ("E" smerge-ediff)
    ("C" smerge-combine-with-next)
    ("r" smerge-resolve)
    ("k" smerge-kill-current)
    ("ZZ" (lambda ()
            (interactive)
            (save-buffer)
            (bury-buffer))
     "Save and bury buffer" :color blue)
    ("q" nil "cancel" :color blue))
  :hook (magit-diff-visit-file . (lambda ()
                                   (when smerge-mode
                                     (unpackaged/smerge-hydra/body)))))

(use-package dired-subtree
  :after dired
  :config
  (setq dired-subtree-use-backgrounds nil)
  :bind (:map dired-mode-map
              ("<tab>" . dired-subtree-toggle)
              ("<C-tab>" . dired-subtree-cycle)
              ("<s-iso-lefttab>" . dired-subtree-remove)))

(use-package gif-screencast
  :defer t
  :bind
  ("<C-print>" . gif-screencast-start-or-stop)
  :config
  (setq gif-screencast-output-directory (expand-file-name "images/gif-screencast" org-directory)))

(after! org (setq org-link-abbrev-alist
                  '(("doom-repo" . "https://github.com/hlissner/doom-emacs/%s")
                    ("wolfram" . "https://wolframalpha.com/input/?i=%s")
                    ("duckduckgo" . "https://duckduckgo.com/?q=%s")
                    ("gmap" . "https://maps.google.com/maps?q=%s")
                    ("gimages" . "https://google.com/images?q=%s")
                    ("google" . "https://google.com/search?q=")
                    ("youtube" . "https://youtube.com/watch?v=%s")
                    ("youtu" . "https://youtube.com/results?search_query=%s")
                    ("github" . "https://github.com/%s")
                    ("attachments" . "~/Dropbox/org/.attachments/"))))

(use-package leetcode
  :defer t
  :config
  (setq leetcode-prefer-language "python3"
        leetcode-save-solutions t
        leetcode-prefer-sql "mysql"))

(use-package nov
  :defer t
  :config
  (setq nov-text-width t
        visual-fill-column-center-text t)
  (add-hook 'nov-mode-hook 'visual-line-mode)
  (add-hook 'nov-mode-hook 'visual-fill-column-mode)
  )

(setq doom-themes-treemacs-theme "doom-colors") ; use the colorful treemacs theme

(with-eval-after-load 'treemacs
  (defun treemacs-ignore-gitignore (file _)
    (string= file ".gitignore"))
  (push #'treemacs-ignore-gitignore treemacs-ignored-file-predicates))

(use-package! vlf-setup
  :defer-incrementally vlf-tune vlf-base vlf-write vlf-search vlf-occur vlf-follow vlf-ediff vlf)

(use-package hydra
  :config
  (use-package hydra-posframe
    :custom
    (hydra-posframe-parameters
     '((left-fringe . 5)
       (right-fringe . 5)))
    :custom-face
    (hydra-posframe-border-face ((t (:background "#6272a4"))))
    :hook (after-init . hydra-posframe-mode)))

(setq evil-vsplit-window-right t
      evil-split-window-below t)

(defadvice! prompt-for-buffer (&rest _)
  :after '(evil-window-split evil-window-vsplit)
  (+ivy/projectile-find-file))
(setq +ivy-buffer-preview t)

;;;###autoload
(defun +ivy/project-search-with-hidden-files ()
  (interactive)
  (let ((counsel-rg-base-command "rg -zS --no-heading --line-number --color never --hidden %s . "))
    (+ivy/project-search)))

(after! prodigy
  (prodigy-define-tag
   :name 'webpack
   :ready-message "Compiled successfully!")

  (prodigy-define-tag
   :name 'hugook
   :ready-message "Hugo service started")

  (prodigy-define-tag
   :name 'serve
   :ready-message "Serving!")
  (prodigy-define-service
   :name "Python app"
   :command "python"
   :args '("-m" "SimpleHTTPServer" "6001")
   :cwd "~/"
   :tags '(work)
   :stop-signal 'sigkill
   :kill-process-buffer-on-stop t)

  (prodigy-define-service
   :name "Hugo server"
   :port 1313
   :command "hugo"
   :args '("server" "-t")
   :cwd "~/Dropbox/org/blogging/"
   :stop-signal 'sigkill
   :tags '(hugook)
   :kill-process-buffer-on-stop t))

;; (use-package conda
;;   :after python
;;   :init
;;   (setq-default
;;    conda-env-home-directory "/home/kai/.conda/"
;;    conda-anaconda-home "/opt/anaconda3/")
;;   :config
;;   (setq flycheck-checker-error-threshold nil)
;;   ;; if you want interactive shell support, include:
;;   (conda-env-initialize-interactive-shells)
;;   ;; if you want eshell support, include:
;;   (conda-env-initialize-eshell)
;;   (require 'dap-python)
;;   )

(use-package dart-mode
  :defer t
  :init
  (setq lsp-dart-sdk-dir "/opt/flutter/bin/cache/dart-sdk/")
  (setq lsp-dart-analysis-sdk-dir "/opt/flutter/bin/cache/dart-sdk/")
  :hook ((dart-mode . smartparens-mode)
         (dart-mode . lsp))
  :custom
  (dart-format-on-save t)
  (dart-sdk-path "/opt/flutter/bin/cache/dart-sdk/"))

(use-package flutter
  :after dart-mode
  :custom
  (flutter-sdk-path "/opt/flutter/"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                       ANKI AND TEMPLATES                                                     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(use-package anki-editor
  :after org
  ;; :hook (org-capture-after-finalize . anki-editor-reset-cloze-number) ; Reset cloze-number after each capture.
  :config
  (setq anki-editor-create-decks t
        anki-editor-org-tags-as-anki-tags t
        org-my-anki-file "~/Dropbox/org/anki.org")
  ;; Initialize
  ;;  (anki-editor-reset-cloze-number)
  )

(after! org
  (add-to-list 'org-capture-templates
               '("A" "Create Anki Cards")))

(after! org
  (add-to-list 'org-capture-templates
               '("Ab" "Anki basic"
                 entry
                 (file+headline org-my-anki-file "Dispatch")
                 "* %<%H:%M>\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Basic\n:ANKI_DECK: Mega\n:END:\n** Front\n%?\n** Back\n")))

(after! org
  (add-to-list 'org-capture-templates
               '("Ac" "Anki cloze"
                 entry
                 (file+headline org-my-anki-file "Dispatch")
                 "* %<%H:%M>\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Cloze\n:ANKI_DECK: Mega\n:END:\n** Text\n** Extra\n")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        ANKI CLOSED                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




(setq lsp-julia-default-environment "~/.julia/environments/v1.5")

(defvar lorem-ipsum-text)

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

(after! org
  ;; (add-hook 'org-mode-hook #'auto-fill-mode)
  (setq org-directory "~/Dropbox/org/"
        org-attach-id-dir "~/Dropbox/org/.attach/"
        ;; show images instead of links to images
        org-startup-with-inline-images t
        org-archive-mark-done t
        org-archive-tag "DONE"
        org-image-actual-width nil
        ;; org-archive-location "~/Dropbox/org/gtd/archive.org::datetree/"
        org-default-notes-file "~/Dropbox/org/gtd/inbox.org"
        projectile-project-search-path '("~/workspace/projects/"))
  )

(after! org
  (setq org-agenda-tags-column 40)
  (setq org-tags-column 40)
  (setq org-agenda-files '("~/Dropbox/org/gtd/"))
  (setq org-agenda-start-with-log-mode t)
  (setq org-columns-default-format "%40ITEM(Task) %Effort(EE){:} %CLOCKSUM(Time Spent) %SCHEDULED(Scheduled) %DEADLINE(Deadline) %TAGS")
  (setq org-tags-exclude-from-inheritance '("project"))
  (setq org-agenda-sorting-strategy
        '((agenda time-up) (todo time-up) (tags time-up) (search time-up)))

  (add-to-list 'org-global-properties
               '("Effort". "0:05 0:15 0:30 1:00 2:00 3:00 4:00"))
  (setq org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        ;; for showing only recurring task's next entry
        org-agenda-show-future-repeats "next"
        )


  (setq org-todo-keyword-faces
        '(("TODO" :foreground "DeepSkyBlue4" :weight bold)
          ("TOREAD" :foreground "DeepSkyBlue4" :weight bold)
          ("WAITING" :foreground "light sea green" :weight bold)
          ("READING" :foreground "light sea green" :weight bold)
          ("SOMEDAY" :foreground "chocolate3" :weight bold)
          ("REVISE" :foreground "firebrick" :weight bold)
          ("SUMMARISE" :foreground "firebrick" :weight bold)
          ("DELEGATED" :foreground "Gold" :weight bold)
          ("NEXT" :foreground "red1" :weight bold)
          ("ACTIVE" :background "DimGray" :foreground "gold1" :weight bold)
          ("DONE" :foreground "slategrey" :weight bold)))

  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "ACTIVE(a)" "REVISE(y)" "REVIEW(r@/!)" "|" "DONE(d!/!)")
          (sequence "TOREAD(z)" "READING(x)" "REVIEW(r@/!)" "SUMMARISE(s)" "|" "DONE(d!/!)")
          (sequence "SOMEDAY(f@/!)" "|" "CANCELLED(c@/!)")
          (sequence "PROJ(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
          (sequence "WAITING(w@/!)" "|" "CANCELLED(c@/!)")))

  (setq org-log-state-notes-insert-after-drawers nil
        org-log-into-drawer t
        org-log-done 'time
        org-log-repeat 'time
        org-log-redeadline 'note
        org-log-reschedule 'note)

  (setq org-refile-targets '((org-agenda-files . (:maxlevel . 5)))
        org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm)

  ;;(advice-add #'org-refile :after 'org-save-all-org-buffers)
  ;; (advice-add #'org-agenda-exit :around 'doom-shut-up-a)
  ;;(advice-add #'org-agenda-exit :before 'org-save-all-org-buffers)

  (setq org-startup-indented t
        org-src-tab-acts-natively t)
  ;; (add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

  (setq org-tag-alist '(
                        ;; Why this work?
                        (:startgroup . nil)
                        ("@hobby" . ?h)
                        ("@toearn" . ?E)
                        ("@personality" . ?K)
                        ("@entertaintment" . ?e)
                        ("@research" . ?R)
                        ;; ("" . ?h)
                        ;; ("" . ?e)
                        ;; ("" . ?p)
                        ;; ("" . ?r)
                        ;; ("" . ?r)
                        (:endgroup . nil)

                        ;; Type of work
                        (:startgroup . nil)
                        ("read" . ?r)
                        ("code" . ?c)
                        ("meeting" . ?m)
                        ("practice" . ?P)
                        ("planning" . ?p)
                        ("review" . ?r)
                        (:endgroup . nil)

                        ;; Difficulty of work
                        (:startgroup . nil)
                        ("Challenge" . ?2)
                        ("Average" . ?1)
                        ("Easy" . ?0)
                        (:endgroup . nil)

                        ;; Time Context for the work
                        (:startgroup . nil)
                        ("EM" . ?3)
                        ("M" . ?4)
                        ("D" . ?5)
                        ("EV" . ?6)
                        (:endgroup . nil)

                        ;; Motivation required for this work
                        (:startgroup . nil)
                        ("MR0" . ?7)
                        ("MR1" . ?8)
                        ("MR2" . ?9)
                        ("MR3" .?Z)
                        (:endgroup . nil)
                        ))

  (setq org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id
        org-clone-delete-id t)
  )

(use-package org-clock-convenience
  :after org
  :bind (:map org-agenda-mode-map
          ("<s-up>" . org-clock-convenience-timestamp-up)
          ("<s-down>" . org-clock-convenience-timestamp-down)
          ("<s-right>" . org-clock-convenience-fill-gap)
          ("<s-left>" . org-clock-convenience-fill-gap-both)))

(use-package! org-clock-budget
  :commands (org-clock-budget-report)
  :init
  (defun my-buffer-face-mode-org-clock-budget ()
    "Sets a fixed width (monospace) font in current buffer"
    (interactive)
    (setq buffer-face-mode-face '(:family "Iosevka" :height 1.0))
    (buffer-face-mode)
    (setq-local line-spacing nil))
  :config
  (map! :map org-clock-budget-report-mode-map
        :nm "h" #'org-shifttab
        :nm "l" #'org-cycle
        :nm "e" #'org-clock-budget-report
        :nm "s" #'org-clock-budget-report-sort
        :nm "d" #'org-clock-budget-remove-budget
        :nm "q" #'quit-window)
  (add-hook! 'org-clock-budget-report-mode-hook
    (toggle-truncate-lines 1)
    (my-buffer-face-mode-org-clock-budget)))

(after! org (add-to-list 'org-capture-templates
                         '("l" "Link Capture" entry (file "~/Dropbox/org/gtd/links.org")
                           "* TODO [[%^{link}][%^{description}]]"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("h" "Clip Link Capture" entry (file "~/Dropbox/org/gtd/links.org")
                           "* TODO %(org-cliplink-capture)"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("ph" "New Project" entry (file "~/Dropbox/org/gtd/projects.org")
                           (file "~/Dropbox/org/templates/newprojtemplate.org"))))

;; (after! org (add-to-list 'org-capture-templates
;;                          '("ph" "New Project" entry (file "~/Dropbox/org/gtd/projects.org")
;;                            "* PROJ %^{projectname} :project:
;; :PROPERTIES:
;; :COOKIE_DATA: todo recursive
;; :ORDERED: t
;; :TRIGGER: next-sibling todo!(NEXT)
;; :GOAL:    %^{Main Goal}
;; :END:
;; :RESOURCES:
;; :END:

;; \** NEXT %^{Subtask1}
;; SCHEDULED: %t
;; :PROPERTIES:
;; :TRIGGER: next-sibling scheduled!(\"++%^{SECOND_TASK_AFTER}\") todo!(NEXT)
;; :BLOCKER:  previous-sibling
;; :Effort: %^{Effort}
;; :END:
;; \n\** TODO %^{Subtask2}
;; :PROPERTIES:
;; :TRIGGER: next-sibling scheduled!(\"++%^{THIRD_TASK_AFTER}\") todo!(NEXT)
;; :BLOCKER:  previous-sibling
;; :Effort: %^{Effort_2}
;; :END:
;; ")))

(after! org (add-to-list 'org-capture-templates
                         '("ps" "Create Project Subtask" entry (file "~/Dropbox/org/gtd/inbox.org")
                           "* TODO %^{taskname}%?
:PROPERTIES:
:TRIGGER: next-sibling scheduled!(\"++%^{NEXT_TASK_AFTER}\") todo!(NEXT)
:BLOCKER:  previous-sibling
:CREATED:    %U
:END:
" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("v" "Create a new habit" entry (file "~/Dropbox/org/gtd/recurring.org")
                           "* TODO %^{description} %?
SCHEDULED: %^{Start Time:}t
:PROPERTIES:
:STYLE: habit
:CREATED:    %U
:END:
")))

(after! org (add-to-list 'org-capture-templates
                         '("i" "Idea from Firefox" entry (file "~/Dropbox/org/gtd/links.org")
                           "* %^{Logging for...} :idea:
:PROPERTIES:
:Created: %U
:Linked: %(grab-x-link-firefox-insert-org-link)
:END:
%i
%?")
                         ))

;; (after! org (add-to-list 'org-capture-templates
;;              '("m" "Mood Log" entry(file+olp+datetree"~/Dropbox/org/journal/mood.org")
;;                "** <%<%I:%M:%S>> %\\1 (%\\2 mood swing) Spiritual :: %\\3
;; :PROPERTIES:
;; :OVERALL MOOD: %^{MOOD|Excellent|Good|Okay|Worse}
;; :MOOD SWINGS: %^{SWING|No|Normal|Extreme}
;; :SPIRITUAL: %^{SPIRITUAL|YES|NO}
;; :WORK LIKENESS: %^{WORK|BORING|TOLERABLE|INTERESTING}
;; :END:
;; %?")))

(after! org (add-to-list 'org-capture-templates
                         '("b" "Book Log" entry(file "~/Dropbox/org/gtd/book.org")
                           "* SOMEDAY Read %^{Title}
:PROPERTIES:
:AUTHOR: %^{Author}
:GENRE: %^{Genre}
:RECOMMENDER: %^{Recommender}
:RATED: %^{RATING|5|4|3|2|1}
:COMMENT:  %^{Comment}
:END:" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("e" "Add an event" entry(file "~/Dropbox/org/gtd/events.org")
                           "* TODO Wish %^{Person} on their %^{Event}
:PROPERTIES:
:END:" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("P" "Paper Log" entry(file "~/Dropbox/org/gtd/paper.org")
                           "* SOMEDAY Read %^{Title}
:PROPERTIES:
:AUTHOR: %^{Author}
:P_CATEGORY: %^{P_CATEGORY|VISION|NLP|RL|NEURO|MISC}
:P_SUBCATEGORY: %^{P_Subcategory}
:LINK: %^{Link}
:SOTA: %^{SOTA|YES|NO}
:COMMENT:  %^{Comment}
:END:")))

(after! org (add-to-list 'org-capture-templates
                         '("d" "Diary Log" entry(file+olp+datetree"~/Dropbox/org/journal/diary.org")
                           "** <%<%I:%M:%S>> %^{diary entry}
%?")))


(after! org (add-to-list 'org-capture-templates
                         '("G" "Set a Motto" entry(file+olp+datetree"~/Dropbox/org/journal/motto.org")
                           "* %^{diary entry}
%?" :immediate-finish t)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        TODO Weekly Review Improvements                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; (defun org-find-week-in-datetree()
;;   (org-datetree-find-iso-week-create (calendar-current-date))
;;   (kill-line))



;; (after! org (add-to-list 'org-capture-templates
;;                          '("w" "Weekly Review" entry (file+function "~/Dropbox/org/journal/review.org" org-find-week-in-datetree)
;;                            (file "~/Dropbox/org/templates/weeklyreviewtemplate.org") :tree-type week)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     REVIEW TEMPLATES                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(after! org
  (add-to-list 'org-capture-templates
               '("r" "Make a review")))

(after! org (add-to-list 'org-capture-templates
                         '("rw" "Weekly Review" entry (file+olp+datetree "~/Dropbox/org/journal/weeklyreview.org")
                           (file "~/Dropbox/org/templates/weeklyreviewtemplate.org") :tree-type week)))

(after! org (add-to-list 'org-capture-templates
                         '("rm" "Monthly Review" entry (file+olp+datetree "~/Dropbox/org/journal/monthlyreview.org")
                           (file "~/Dropbox/org/templates/monthlyreviewtemplate.org") :tree-type month)))

(after! org (add-to-list 'org-capture-templates
                         '("rd" "Daily Review" entry (file+olp+datetree "~/Dropbox/org/journal/dailyreview.org")
                           (file "~/Dropbox/org/templates/dailyreviewtemplate.org"))))

(after! org (add-to-list 'org-capture-templates
                         '("re" "Daily Enthusiasm" entry (file+olp+datetree "~/Dropbox/org/journal/daily_focus_and_enthusiasm.org")
                           (file "~/Dropbox/org/templates/dailyfocusandenthtemplate.org"))))

(after! org (add-to-list 'org-capture-templates
                         '("rr" "Reflecting the day" entry (file+olp+datetree "~/Dropbox/org/journal/reflections.org")
                           (file "~/Dropbox/org/templates/reflectiontemplate.org"))))

;; TODO Make capture template clear
(after! org (add-to-list 'org-capture-templates
                         '("rp" "Deal With It Later" entry (file+olp "~/Dropbox/org/journal/dealwithitlater.org")
                           "* <%<%I:%M:%S>> %^{The issue}
%?")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        REVIEW TEMPLATES DONE                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(after! org (add-to-list 'org-capture-templates
                         '("K" "Read on Kindle" entry(file "~/Dropbox/org/gtd/kindle_daily.org")
                           "* %<%Y-%m-%d> ==> %^{diary entry}"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
             '("k" "Read on Kindle [Clipboard URL]" entry(file "~/Dropbox/org/gtd/kindle_daily.org")
               "* %<%Y-%m-%d> ==> %c"
               :immediate-finish t)))

(after! org
  (add-to-list 'org-capture-templates
               '("C"  "Contact" entry (file "~/Dropbox/org/contacts.org")
                 "* %(org-contacts-template-name)
    :PROPERTIES:
    :EMAIL: %(org-contacts-template-email)
    :PHONE: %^{Phone}
    :ADDRESS: %^{Home Address}
    :BIRTHDAY: %^{yyyy-mm-dd}
    :ORG:  %^{Company}
    :NOTE: %^{NOTE}
    :END:"
                 :empty-lines 1)))

(after! org (add-to-list 'org-capture-templates
                         '("c" "Capture [GTD]" entry (file "~/Dropbox/org/gtd/inbox.org")
                           "* TODO %^{taskname}%?
:PROPERTIES:
:CREATED:    %U
:END:
" :immediate-finish t)))

(after! org
  (add-hook 'org-agenda-finalize-hook
            (lambda () (remove-text-properties
                   (point-min) (point-max) '(mouse-face t))))
  ;; (add-hook 'evil-org-agenda-mode-hook 'org-save-all-org-buffers)
  ;; (add-hook 'org-finalize-agenda-hook (lambda () (hl-line-mode 1))))
  )

(after! org-agenda (setq org-agenda-custom-commands
                         '(
                           ("k" "Today\'s View"
                            ((my-agenda-motto "" nil)
                             (agenda ""
                                     ((org-agenda-files
                                       '("~/Dropbox/org/gtd/tasks.org"
                                         "~/Dropbox/org/gtd/events.org" "~/Dropbox/org/gtd/projects.org"))
                                      (org-agenda-overriding-header "Overall Agenda View")
                                      (org-agenda-span 'day)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-current-span 'day))
                                     (org-time-budgets-in-agenda-maybe)
                                     )
                             (todo "NEXT"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/projects.org"))
                                    (org-agenda-overriding-header " PROJECT TASKS\n ===================================================================\n")
                                    ))
                             (todo "TODO|NEXT"
                                   ((org-agenda-overriding-header "Tasks that don't belong to project\n ==========================================================\n")
                                    ;; ((org-agenda-overriding-header "[[~/Dropbox/org/gtd/tasks.org][Task list]]")
                                    (org-agenda-files
                                     '("~/Dropbox/org/gtd/tasks.org"))))
                             (agenda ""
                                     ((org-agenda-files
                                       '("~/Dropbox/org/gtd/recurring.org"))
                                      (org-agenda-overriding-header "Habits\n ==========================================================\n")
                                      (org-agenda-span 'day)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-current-span 'day)
                                      ;; ((org-agenda-overriding-header "[[~/Dropbox/org/gtd/tasks.org][Task list]]")
                                      ))
                             ;; (todo "WAITING|NEXT"
                             ;;       ((org-agenda-files
                             ;;         '("~/Dropbox/org/gtd/tasks.org"))
                             ;;        (org-agenda-overriding-header "Tasks other than projects in action\n\n")
                             ;;        (org-agenda-use-time-grid nil)
                             ;;        (org-agenda-show-all-dates nil)
                             ;;        (org-agenda-current-span 'day)
                             ;;        (org-agenda-span 7)))
                             (todo "READING"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/books.org"))
                                    (org-agenda-overriding-header "Books I am currently reading\n ======================================================\n")
                                    ))
                             )
                            nil)
                           ("o" "Monthly Review"
                            ((agenda "" ((org-agenda-span 30)
                                         (org-agenda-overriding-header " Previous Month Deferred and not completed\n ===================================================================\n")
                                         (org-agenda-start-day "-7d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (agenda "" ((org-agenda-span 30)
                                         (org-agenda-overriding-header " Planned for next month\n ===================================================================\n")
                                         (org-agenda-start-day "+1d")
                                         (org-agenda-entry-types '(:timestamp))))
                             )
                            nil)
                           ("W" "Weekly Review"
                            ((agenda "" ((org-agenda-span 7)
                                         (org-agenda-overriding-header " Previous Week Deferred and not completed\n ===================================================================\n")
                                         (org-agenda-start-day "-7d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (agenda "" ((org-agenda-span 7)
                                         (org-agenda-overriding-header " Planned for next week\n ===================================================================\n")
                                         (org-agenda-start-day "-1d")
                                         (org-agenda-entry-types '(:timestamp))
                                         (org-agenda-show-log t)))
                             (todo ""
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/inbox.org"))
                                    (org-agenda-overriding-header " Process and refile inbox\n ===================================================================\n")
                                    ))
                             (todo "TOREAD"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/books.org"))
                                    (org-agenda-overriding-header " Do you want to read some new book\n ===========================================================\n")
                                    ))
                             (todo "WAITING"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/tasks.org"))
                                    (org-agenda-overriding-header " Waiting for something else\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/projects.org"))
                                    (org-agenda-overriding-header " Projects Work for Next Week\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-overriding-header " Process Someday\n ===========================================================\n")
                                    (org-agenda-files
                                     '("~/Dropbox/org/gtd/someday.org"))
                                    ))
                             )
                            nil)
                           ("x" "On mobile"
                            ((agenda ""
                                     ((org-agenda-span '2)
                                      ((org-agenda-overriding-header "Can you spare some time?\n ==============================================================\n")
                                       (org-agenda-span '3)
                                       (org-agenda-tag-filter-preset
                                        '("+phone" "-Challenge"))))
                                     ))
                            nil)
                           ("v" "I am bored"
                                        ; Easy tasks
                            ((tags-todo "+Easy"
                                        ((org-agenda-overriding-header " Get over easier things now")
                                         ))
                                        ; Read when bored
                             (tags-todo "+read"
                                        ((org-agenda-files
                                          '("~/Dropbox/org/gtd/paper.org" "~/Dropbox/org/gtd/book.org" ))
                                         (org-agenda-overriding-header " Why not read something rather than waste time?"))
                                        )
                                        ; Get entertained
                             (tags-todo "+entertaintment"
                                        ((org-agenda-files
                                          '("~/Dropbox/org/gtd/inbox.org"))
                                         (org-agenda-overriding-header " Enjoy some time doing whatever"))
                                        )
                             ))
                           ("w" "Office agenda"
                                        ; Priority A
                            ((tags-todo "PRIORITY=\"A\"&+office"
                                        ((org-agenda-overriding-header "Priority A")))
                                        ; Due soon
                             (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&+office"
                                        ((org-agenda-overriding-header "Due soon")))
                             ))
                           ("l" "Home agenda"
                                        ; Priority A
                            ((tags-todo "PRIORITY=\"A\"&+home"
                                        ((org-agenda-overriding-header "Priority A")))
                                        ; Due soon
                             (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&+home"
                                        ((org-agenda-overriding-header "Due soon")))
                             ))
                           )))



(after! org
  (defun my:org-agenda-time-grid-spacing ()
    "Set different line spacing w.r.t. time duration."
    (save-excursion
      (let* ((background (alist-get 'background-mode (frame-parameters)))
             (background-dark-p (string= background "dark"))
             (colors (if background-dark-p
                         (list "#aa557f" "DarkGreen" "DarkSlateGray" "DarkSlateBlue")
                       (list "#F6B1C3" "#FFFF9D" "#BEEB9F" "#ADD5F7")))
             pos
             duration)
        (nconc colors colors)
        (goto-char (point-min))
        (while (setq pos (next-single-property-change (point) 'duration))
          (goto-char pos)
          (when (and (not (equal pos (point-at-eol)))
                     (setq duration (org-get-at-bol 'duration)))
            (let ((line-height (if (< duration 30) 1.0 (+ 0.5 (/ duration 60))))
                  (ov (make-overlay (point-at-bol) (1+ (point-at-eol)))))
              (overlay-put ov 'face `(:background ,(car colors)
                                      :foreground
                                      ,(if background-dark-p "black" "white")))
              (setq colors (cdr colors))
              (overlay-put ov 'line-height line-height)
              (overlay-put ov 'line-spacing (1- line-height))))))))
  (add-hook 'org-agenda-finalize-hook #'my:org-agenda-time-grid-spacing)
  )


(after! org
  (setq org-highlight-latex-and-related '(native script entities)))

(after! org
  (setq org-hide-emphasis-markers t
        org-list-demote-modify-bullet '(("+" . "-") ("1." . "a.") ("-" . "+") ("a." . "1."))
        )
  (setq org-emphasis-alist
        '(("*" (bold :foreground "Orange" ))
          ("/" (italic :foreground "VioletRed"))
          (":" (:foreground "SandyBrown"))
          ("_" (underline))
          ("=" (:foreground "maroon"))
          ("@" (:foreground "seashell"))
          ("~" (:foreground "deep sky blue"))
          ("+" (:strike-through t :foreground "slate grey" ))))
  )



(after! org (setq org-html-head-include-scripts t
                  org-export-with-toc t
                  org-export-with-author t
                  org-export-headline-levels 5
                  org-export-with-drawers t
                  org-export-with-email t
                  org-export-with-footnotes t
                  org-export-with-latex t
                  org-export-with-section-numbers nil
                  org-export-with-properties t
                  org-export-with-smart-quotes t
                  org-export-backends '(pdf ascii html latex odt pandoc)))

(after! org
  (require 'org-download)
  (add-hook 'dired-mode-hook 'org-download-enable)
  (defun my-org-download-screenshot ()
    "Capture screenshot and insert the resulting file. The screenshot tool is determined by `org-download-screenshot-method'."
    (interactive)
    (let ((tmp-file "/tmp/screenshot.png"))
      (delete-file tmp-file)
      (call-process-shell-command "flameshot gui -p /tmp/")
      ;; Because flameshot exit immediately, keep polling to check file existence
      (while (not (file-exists-p tmp-file))
        (sleep-for 2))
      (org-download-image tmp-file)))
  (global-set-key (kbd "<H-print>") 'my-org-download-screenshot)
  )


(after! org-roam
  (setq org-roam-capture-templates
        '(("n" "Note" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+DATE: %t
#+ROAM_ALIASES: ${alias}
#+title: ${title}\n")
           :unnarrowed t)
          ("h" "Hugo" plain
           "%?"
           :if-new (file+head "emacs/${slug}.org"
                              "#+SETUPFILE:../hugo_in_setup.org
#+HUGO_SECTION: ${ai|emacs|neuroscience}
#+HUGO_SLUG: ${slug}
#+hugo_tags:
#+hugo_categories:
#+hugo_draft: false\n
#+FILETAGS: ${filetags}\n
#+TITLE: ${title}
#+DATE: %t\n")
           :unnarrowed t)
          ("j" "paper-description" plain
           "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+DATE: %t\n * Main Contribution \n* Your description of significance \n* New algorithm or principles\n* Simulation Results and Comparisons\n* Solid Conclusion"
                              :unnarrowed t))
          ("e" "ref" plain "%?"
           :if-new (file+head "websites/${slug}.org"
                              "#+SETUPFILE:./hugo_in_setup.org
#+ROAM_KEY: ${ref}
#+HUGO_SLUG: ${slug}
#+TITLE: ${title}\n- source :: ${ref}")
           :unnarrowed t)

          ("k" "private" plain
           (function org-roam--capture-get-point)
           "%?"
           :if-new (file+head "private-${slug}"
                              "#+TITLE: ${title}\n")
           :unnarrowed t)

          ;;            ("h" "hugo blogging" plain
          ;;             (function org-roam--capture-get-point)
          ;;             "%?"
          ;;             :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}"
          ;;                                "#+SETUPFILE:./hugo_setup.org
          ;; #+HUGO_SECTION: posts
          ;; #+HUGO_TAGS: %^{Tags}
          ;; #+EXPORT_FILE_NAME: %^{export name}
          ;; #+TITLE: ${title}
          ;; #+AUTHOR: Alok Regmi
          ;; #+DATE: %t")
          ;;             :unnarrowed t)
          )
        ))

(use-package org-roam-server
  :defer t
  :config
  (setq org-roam-server-host "0.0.0.0"
        org-roam-server-port 1701
        org-roam-server-export-inline-images t
        org-roam-server-authenticate nil
        org-roam-server-network-poll nil
        org-roam-server-network-arrows 'from
        org-roam-server-network-label-truncate t
        org-roam-server-network-label-truncate-length 60
        org-roam-server-network-label-wrap-length 20))

(after! org-roam

  (defadvice! doom-modeline--reformat-roam (orig-fun)
    :around #'doom-modeline-buffer-file-name
    (message "Reformat?")
    (message (buffer-file-name))
    (if (s-contains-p org-roam-directory (or buffer-file-name ""))
        (replace-regexp-in-string
         "\\(?:^\\|.*/\\)\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)[0-9]*-"
         "🢔(\\1-\\2-\\3) "
         (funcall orig-fun))
      (funcall orig-fun)))

  (setq org-roam-graph-node-extra-config '(("shape"      . "underline")
                                           ("style"      . "rounded,filled")
                                           ("fillcolor"  . "#EEEEEE")
                                           ("color"      . "#C9C9C9")
                                           ("fontcolor"  . "#111111")
                                           ("fontname"   . "Overpass Nerd Font")))

  (setq +org-roam-graph--html-template
        (replace-regexp-in-string "%\\([^s]\\)" "%%\\1"
                                  (f-read-text (concat doom-private-dir "misc/org-roam-template.html"))))

  (defadvice! +org-roam-graph--build-html (&optional node-query callback)
    "Generate a graph showing the relations between nodes in NODE-QUERY. HTML style."
    :override #'org-roam-graph--build
    (unless (stringp org-roam-graph-executable)
      (user-error "`org-roam-graph-executable' is not a string"))
    (unless (executable-find org-roam-graph-executable)
      (user-error (concat "Cannot find executable %s to generate the graph.  "
                          "Please adjust `org-roam-graph-executable'")
                  org-roam-graph-executable))
    (let* ((node-query (or node-query
                           `[:select [file titles] :from titles
                             ,@(org-roam-graph--expand-matcher 'file t)]))
           (graph      (org-roam-graph--dot node-query))
           (temp-dot   (make-temp-file "graph." nil ".dot" graph))
           (temp-graph (make-temp-file "graph." nil ".svg"))
           (temp-html  (make-temp-file "graph." nil ".html")))
      (org-roam-message "building graph")
      (make-process
       :name "*org-roam-graph--build-process*"
       :buffer "*org-roam-graph--build-process*"
       :command `(,org-roam-graph-executable ,temp-dot "-Tsvg" "-o" ,temp-graph)
       :sentinel (progn
                   (lambda (process _event)
                     (when (= 0 (process-exit-status process))
                       (write-region (format +org-roam-graph--html-template (f-read-text temp-graph)) nil temp-html)
                       (when callback
                         (funcall callback temp-html)))))))))

;; (after! (org org-roam)
;;   (defun my/org-roam--backlinks-list (file)
;;     (if (org-roam--org-roam-file-p file)
;;         (--reduce-from
;;          (concat acc (format "- [[file:%s][%s]]\n"
;;                              (file-relative-name (car it) org-roam-directory)
;;                              (org-roam--get-title-or-slug (car it))))
;;          "" (org-roam-sql [:select [from]
;;                            :from links
;;                            :where (= to $s1)
;;                            :and from :not :like $s2] file "%private%"))
;;       ""))
;;   (defun my/org-export-preprocessor (_backend)
;;     (let ((links (my/org-roam--backlinks-list (buffer-file-name))))
;;       (unless (string= links "")
;;         (save-excursion
;;           (goto-char (point-max))
;;           (insert (concat "\n* Backlinks\n" links))))))
;;   (add-hook 'org-export-before-processing-hook 'my/org-export-preprocessor))

;; (after! (org ox-hugo)
;;   (defun jethro/conditional-hugo-enable ()
;;     (save-excursion
;;       (if (cdr (assoc "SETUPFILE" (org-roam--extract-global-props '("SETUPFILE"))))
;;           (org-hugo-auto-export-mode +1)
;;         (org-hugo-auto-export-mode -1))))
;;   (add-hook 'org-mode-hook #'jethro/conditional-hugo-enable))


(use-package org-ref
  :after org)
;; Comehere
(after! org
  (setq bibtex-completion-library-path "~/Dropbox/pdfs/"
        bibtex-completion-bibliography "~/Dropbox/org/references/articles.bib"
        bibtex-completion-notes-path "~/Dropbox/org/references/articles.org"
        bibtex-completion-notes-extension "org"
        bibtex-completion-notes-path "~/Dropbox/org/references/articles.org"
        bibtex-completion-notes-template-multiple-files  (concat
                                                          "#+TITLE: ${title}\n"
                                                          "#+ROAM_KEY: cite:${=key=}\n"
                                                          "* TODO Notes\n"
                                                          ":PROPERTIES:\n"
                                                          ":Custom_ID: ${=key=}\n"
                                                          ":NOTER_DOCUMENT: %(orb-process-file-field \"${=key=}\")\n"
                                                          ":AUTHOR: ${author-abbrev}\n"
                                                          ":JOURNAL: ${journaltitle}\n"
                                                          ":DATE: ${date}\n"
                                                          ":YEAR: ${year}\n"
                                                          ":DOI: ${doi}\n"
                                                          ":URL: ${url}\n"
                                                          ":END:\n\n"
                                                          ))

  (setq org-ref-notes-directory "~/Dropbox/org/notes/"
        org-ref-completion-library 'org-ref-ivy-cite
        org-ref-get-pdf-filename-function 'org-ref-get-pdf-filename-helm-bibtex        org-ref-bibliography-notes "~/Dropbox/org/references/articles.org"
        org-ref-note-title-format "* TODO %y - %t\n :PROPERTIES:\n  :Custom_ID: %k\n  :NOTER_DOCUMENT: %F\n :ROAM_KEY: cite:%k\n  :AUTHOR: %9a\n  :JOURNAL: %j\n  :YEAR: %y\n  :VOLUME: %v\n  :PAGES: %p\n  :DOI: %D\n  :URL: %U\n :END:\n\n"
        org-ref-default-bibliography '("~/Dropbox/org/references/articles.bib")
        org-ref-notes-function 'orb-edit-notes
        org-ref-pdf-directory "~/Dropbox/pdfs")
  )
(use-package org-roam-bibtex
  :after (org-roam)
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :config
  (setq orb-preformat-keywords
        '("=key=" "title" "url" "file" "author-or-editor" "keywords"))
  (setq orb-templates
        '(("r" "ref" plain (function org-roam-capture--get-point)
           ""
           :file-name "papers/${citekey}"
           :head "#+TITLE: ${=key=}: ${title}\n#+ROAM_KEY: ${ref}

- tags ::
- keywords :: ${keywords}

\n* ${title}\n  :PROPERTIES:\n  :Custom_ID: ${=key=}\n  :URL: ${url}\n  :AUTHOR: ${author-or-editor}\n  :NOTER_DOCUMENT: %(orb-process-file-field \"${=key=}\")\n  :NOTER_PAGE: \n  :END:\n\n"

           :unnarrowed t))))


(use-package org-noter
  :defer t
  :commands (org-noter org-noter-create-skeleton)
  :config

  (defun who/org-noter-insert-highlighted-note ()
    "Highlight the active region and add a precise note at its position."
    (interactive)
    ;; Adding an annotation will deactivate the region, so we reset it afterward
    (let ((region (pdf-view-active-region)))
      (call-interactively 'pdf-annot-add-highlight-markup-annotation)
      (setq pdf-view-active-region region))
    (call-interactively 'org-noter-insert-precise-note))

  (setq org-noter-always-create-frame nil
        org-noter-insert-selected-text-inside-note t
        ;; ;; The WM can handle splits
        ;; org-noter-notes-window-location 'other-frame
        ;; I want to see the whole file
        org-noter-hide-other nil
        org-noter-insert-note-no-questions t
        org-noter-notes-search-path '("~/Dropbox/org/notes/")
        org-noter-separate-notes-from-heading t
        ;; org-noter-auto-save-last-location t
        )
  ;; fuxialexander's code
  (add-hook! org-noter-notes-mode (require 'org-noter-pdftools))
  )

(use-package org-noter-pdftools
  :after org-noter
  :config
  (with-eval-after-load 'pdf-annot
    (add-hook 'pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note)))

(use-package org-pdftools
  :hook (org-load . org-pdftools-setup-link))

(after! org
  (add-to-list 'org-src-lang-modes '("plantuml" . plantuml))
  (org-babel-do-load-languages 'org-babel-load-languages '((plantuml . t))))

(setq org-books-file "~/Dropbox/org/gtd/books.org")

(after! org
  (require 'org-books)
  (add-to-list 'org-capture-templates
               '("f" "Book" entry (file "~/Dropbox/org/gtd/books.org")
                 "%(let* ((url (substring-no-properties (current-kill 0)))
                  (details (org-books-get-details url)))
             (when details (apply #'org-books-format 1 details)))"))
)

(after! org
  (defun org-markup-region-or-point (type beginning-marker end-marker)
    "Apply the markup TYPE with BEGINNING-MARKER and END-MARKER to region, word or point.
This is a generic function used to apply markups. It is mostly
the same for the markups, but there are some special cases for
subscripts and superscripts."
    (cond
     ;; We have an active region we want to apply
     ((region-active-p)
      (let* ((bounds (list (region-beginning) (region-end)))
             (start (apply 'min bounds))
             (end (apply 'max bounds))
             (lines))
        (unless (memq type '(subscript superscript))
          (save-excursion
            (goto-char start)
            (unless (looking-at " \\|\\<")
              (backward-word)
              (setq start (point)))
            (goto-char end)
            (unless (or (looking-at " \\|\\>")
                        (looking-back "\\>" 1))
              (forward-word)
              (setq end (point)))))
        (setq lines
              (s-join "\n" (mapcar
                            (lambda (s)
                              (if (not (string= (s-trim s) ""))
                                  (concat beginning-marker
                                          (s-trim s)
                                          end-marker)
                                s))
                            (split-string
                             (buffer-substring start end) "\n"))))
        (setf (buffer-substring start end) lines)
        (forward-char (length lines))))
     ;; We are on a word with no region selected
     ((thing-at-point 'word)
      (cond
       ;; beginning of a word
       ((looking-back " " 1)
        (insert beginning-marker)
        (re-search-forward "\\>")
        (insert end-marker))
       ;; end of a word
       ((looking-back "\\>" 1)
        (insert (concat beginning-marker end-marker))
        (backward-char (length end-marker)))
       ;; not at start or end so we just sub/sup the character at point
       ((memq type '(subscript superscript))
        (insert beginning-marker)
        (forward-char (- (length beginning-marker) 1))
        (insert end-marker))
       ;; somewhere else in a word and handled sub/sup. mark up the
       ;; whole word.
       (t
        (re-search-backward "\\<")
        (insert beginning-marker)
        (re-search-forward "\\>")
        (insert end-marker))))
     ;; not at a word or region insert markers and put point between
     ;; them.
     (t
      (insert (concat beginning-marker end-marker))
      (backward-char (length end-marker)))))


  (defun org-italics-region-or-point ()
    "Italicize the region, word or character at point.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'italics "/" "/"))


  (defun org-bold-region-or-point ()
    "Bold the region, word or character at point.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'bold "*" "*"))


  (defun org-underline-region-or-point ()
    "Underline the region, word or character at point.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'underline "_" "_"))


  (defun org-code-region-or-point ()
    "Mark the region, word or character at point as code.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'underline "~" "~"))


  (defun org-verbatim-region-or-point ()
    "Mark the region, word or character at point as verbatim.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'underline "=" "="))


  (defun org-strikethrough-region-or-point ()
    "Mark the region, word or character at point as strikethrough.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'strikethrough "+" "+"))


  (defun org-subscript-region-or-point ()
    "Mark the region, word or character at point as a subscript.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'subscript "_{" "}"))

  (defun org-superscript-region-or-point ()
    "Mark the region, word or character at point as superscript.
This function tries to do what you mean:
1. If you select a region, markup the region.
2. If in a word, markup the word.
3. Otherwise wrap the character at point in the markup."
    (interactive)
    (org-markup-region-or-point 'superscript "^{" "}"))

  (defun org-latex-math-region-or-point (&optional arg)
    "Wrap the selected region in latex math markup.
\(\) or $$ (with prefix ARG) or @@latex:@@ with double prefix.
With no region selected, insert those and put point in the middle
to add an equation. Finally, if you are between these markers
then exit them."
    (interactive "P")
    (if (memq 'org-latex-and-related (get-char-property (point) 'face))
        ;; in a fragment, let's get out.
        (goto-char (or (next-single-property-change (point) 'face) (line-end-position)))
      (let ((chars
             (cond
              ((null arg)
               '("\\(" . "\\)"))
              ((equal arg '(4))
               '("$" . "$"))
              ((equal arg '(16))
               '("@@latex:" . "@@")))))
        (if (region-active-p)
            ;; wrap region
            (progn
              (goto-char (region-end))
              (insert (cdr chars))
              (goto-char (region-beginning))
              (insert (car chars)))
          (cond
           ((thing-at-point 'word)
            (save-excursion
              (end-of-thing 'word)
              (insert (cdr chars)))
            (save-excursion
              (beginning-of-thing 'word)
              (insert (car chars)))
            (forward-char (length (car chars))))
           (t
            (insert (concat  (car chars) (cdr chars)))
            (backward-char (length (cdr chars))))))))))

(after! org
  ;;* org-numbered headings
  (defun scimax-overlay-numbered-headings ()
    "Put numbered overlays on the headings."
    (interactive)
    (cl-loop for (p lv) in (let ((counters (copy-list '(0 0 0 0 0 0 0 0 0 0)))
                                 (current-level 1)
                                 last-level)
                             (mapcar (lambda (x)
                                       (list (car x)
                                             ;; trim trailing zeros
                                             (let ((v (nth 1 x)))
                                               (while (= 0 (car (last v)))
                                                 (setq v (butlast v)))
                                               v)))
                                     (org-map-entries
                                      (lambda ()
                                        (let* ((hl (org-element-context))
                                               (level (org-element-property :level hl)))
                                          (setq last-level current-level
                                                current-level level)
                                          (cond
                                           ;; no level change or increase, increment level counter
                                           ((or (= last-level current-level)
                                                (> current-level last-level))
                                            (cl-incf (nth current-level counters)))

                                           ;; decrease in level
                                           (t
                                            (cl-loop for i from (+ 1 current-level) below (length counters)
                                                     do
                                                     (setf (nth i counters) 0))
                                            (incf (nth current-level counters))))

                                          (list (point) (-slice counters 1)))))))
             do
             (let ((ov (make-overlay p p)))
               (overlay-put ov 'before-string (concat (mapconcat 'number-to-string lv ".") ". "))
               (overlay-put ov 'numbered-heading t))))

  (define-minor-mode scimax-numbered-org-mode
    "Minor mode to number org headings."
    :init-value nil
    (cl-labels ((fl-noh (limit) (save-restriction
                                  (widen)
                                  (ov-clear 'numbered-heading)
                                  (scimax-overlay-numbered-headings))))

      (if scimax-numbered-org-mode
          (progn
            (font-lock-add-keywords
             nil
             `((fl-noh 0 nil)))
            (font-lock-fontify-buffer))
        (ov-clear 'numbered-heading)
        (font-lock-remove-keywords
         nil
         `((fl-noh 0 nil))))))
  )

(after! org

  (defhydra +org-private@org-babel-hydra (:color pink :hint nil)
    "
Org-Babel: _j_/_k_ next/prev   _g_oto     _TAB_/_i_/_I_ show/hide
           _'_ edit   _c_lear result      _e_xecute     _s_plit"
    ("c" org-babel-remove-result)
    ("e" org-babel-execute-src-block)
    ("'" org-edit-src-code)
    ("TAB" org-hide-block-toggle-maybe)
    ("s" org-babel-demarcate-block)
    ("g" org-babel-goto-named-src-block)
    ("i" org-show-block-all)
    ("I" org-hide-block-all)
    ("j" org-babel-next-src-block)
    ("k" org-babel-previous-src-block)
    ("q" nil "cancel" :color blue))


  (defhydra scimax-org-table (:color red :hint nil  )
    "
org table
_ic_: insert column    _M-<left>_: move col left    _d_: edit field
_dc_: delete colum     _M-<right>_: move col right  _e_: eval formula
_ir_: insert row       _M-<up>_: move row up        _E_: export table
_ic_: delete row       _M-<down>_: move row down    _r_: recalculate
_i-_: insert line      _w_: wrap region             _I_: org-table-iterate
_-_: insert line/move  ^ ^                          _D_: formula debugger
_s_ort  _t_ranspose _m_ark
_<_: beginning of table _>_: end of table
"
    ("ic" org-table-insert-column)
    ("ir" org-table-insert-row)
    ("dc" org-table-delete-column)
    ("dr" org-table-kill-row)
    ("i-" org-table-insert-hline)
    ("-" org-table-hline-and-move)

    ("d" org-table-edit-field)
    ("e" org-table-eval-formula)
    ("E" org-table-export :color blue)
    ("r" org-table-recalculate)
    ("I" org-table-iterate)
    ("B" org-table-iterate-buffer-tables)
    ("w" org-table-wrap-region)
    ("D" org-table-toggle-formula-debugger)

    ("M-<up>" org-table-move-row-up)
    ("M-<down>" org-table-move-row-down)
    ("M-<left>" org-table-move-column-left)
    ("M-<right>" org-table-move-column-right)
    ("t" org-table-transpose-table-at-point)

    ("m" (progn (goto-char (org-table-begin))
                (org-mark-element)))
    ("s" org-table-sort-lines)
    ("<" (goto-char (org-table-begin)))
    (">" (progn (goto-char (org-table-begin))
                (goto-char (org-element-property :end (org-element-context))))))



  (defhydra scimax-org-headline (:color red :hint nil  )
    "
org headline
Navigation               Organize         insert
--------------------------------------------------------------------------------------------------------------------
_n_ext heading           _mu_: move up    _ip_: set property    _s_: narrow subtree _I_: clock in   _,_: priority
_p_revious heading       _md_: move down  _dp_: delete property _w_: widen          _O_: clock out  _0_: rm priority
_f_: forward same level  _mr_: demote     _it_: tag             _r_: refile         _e_: set effort _1_: A
_b_: back same level     _ml_: promote    _t_: todo             _mm_: mark           _E_: inc effort _2_: B
_j_ump to heading        _ih_: insert hl  _id_: deadline        _=_: columns        ^ ^             _3_: C
_F_: next block          _a_: archive     _is_: schedule
_B_: previous block      _S_: sort        _v_: agenda           _/_: sparse tree
"

    ;; Navigation
    ("n" org-next-visible-heading)
    ("p" org-previous-visible-heading)
    ("f" org-forward-heading-same-level)
    ("b" org-backward-heading-same-level)
    ("j" org-goto)
    ("F" org-next-block)
    ("B" org-previous-block)
    ("a" org-archive-subtree-default-with-confirmation)
    ("ih" org-insert-heading)
    ("S" org-sort)
    ("mm" org-mark-subtree)

    ;; organization
    ("mu" org-move-subtree-up)
    ("md" org-move-subtree-down)
    ("mr" org-demote-subtree)
    ("ml" org-promote-subtree)

    ("ip" org-set-property)
    ("dp" org-delete-property)
    ("id" org-deadline)
    ("is" org-schedule)
    ("t" org-todo)
    ("it" org-set-tags)
    ("<tab>" org-cycle)

    ("r" org-refile)
    ("#" org-toggle-comment)
    ("s" org-narrow-to-subtree)
    ("w" widen)
    ("=" org-columns)

    ("I" org-clock-in)
    ("O" org-clock-out)
    ("e" org-set-effort)
    ("E" org-inc-effort)
    ("," org-priority)
    ("0" (org-priority 32))
    ("1" (org-priority 65))
    ("2" (org-priority 66))
    ("3" (org-priority 67))

    ;; misc
    ("v" org-agenda)
    ("/" org-sparse-tree)))

(after! org

;;;###autoload
  (defhydra scimax-python-mode (:color red :hint nil  )
    "
Python helper
_a_: begin def/class  _w_: move up   _x_: syntax    _Sb_: send buffer
_e_: end def/class    _s_: move down _n_: next err  _Ss_: switch shell
_<_: dedent line      ^ ^            _p_: prev err
_>_: indent line
_j_: jump to
_._: goto definition
_t_: run tests _m_: magit  _8_: autopep8
"
    ("a" beginning-of-defun)
    ("e" end-of-defun)
    ("<" python-indent-shift-left)
    (">" python-indent-shift-right)
    ("j" consult-imenu)

    ("t" elpy-test)
    ("." elpy-goto-definition)
    ("x" elpy-check)
    ("n" elpy-flymake-next-error)
    ("p" elpy-flymake-previous-error)

    ("m" magit-status)

    ("w" elpy-nav-move-line-or-region-up)
    ("s" elpy-nav-move-line-or-region-down)

    ("Sb" elpy-shell-send-region-or-buffer)
    ("Ss" elpy-shell-switch-to-shell)

    ("8" autopep8))


  (defun autopep8 ()
    "Replace Python code block contents with autopep8 corrected code."
    (interactive)
    (unless (executable-find "autopep8")
      (if (executable-find "pip")
          (shell-command "python -c \"import pip; pip.main(['install','autopep8'])\"")
        (shell-command "python -c \"from setuptools.command import easy_install; easy_install.main(['-U','autopep8'])\"")))
    (let* ((src (org-element-context))
           (beg (org-element-property :begin src))
           (value (org-element-property :value src)))
      (save-excursion
        (goto-char beg)
        (search-forward value)
        (shell-command-on-region
         (match-beginning 0)
         (match-end 0)
         "autopep8 -a -a -" nil t))))


  ;; * pylint
  (defvar pylint-options
    '()
    "List of options to use with pylint.")

  (setq pylint-options
        '("-r no "			 ; no reports
          ;; we are not usually writing programs where it
          ;; makes sense to be too formal on variable
          ;; names.
          "--disable=invalid-name "
          ;; don't usually have modules, which triggers
          ;; this when there is not string at the top
          "--disable=missing-docstring "
          ;; superfluous-parens is raised with print(),
          ;; which I am promoting for python3
          ;; compatibility.
          "--disable=superfluous-parens "	;

          ;; these do not seem important for my work.
          "--disable=too-many-locals "	;

          ;; this is raised in solving odes and is
          ;; unimportant for us.
          "--disable=unused-argument "	;
          "--disable=unused-wildcard-import "
          "--disable=redefined-outer-name "
          ;; this is triggered a lot from fsolve
          "--disable=unbalanced-tuple-unpacking "
          "--disable=wildcard-import "
          "--disable=redefined-builtin "
          ;; I dont mind semicolon separated lines
          "--disable=multiple-statements "
          ;; pylint picks up np.linspace as a no-member error. That does not make sense.
          "--disable=no-member "
          "--disable=wrong-import-order "
          "--disable=unused-import "))

  (defun pylint ()
    "Run pylint on a source block.
Opens a buffer with links to what is found. This function installs pylint if needed."
    (interactive)
    (let ((eop (org-element-at-point))
          (temporary-file-directory ".")
          (cb (current-buffer))
          (n) ; for line number
          (cn) ; column number
          (content) ; error on line
          (pb "*pylint*")
          (link)
          (tempfile))

      (unless (executable-find "pylint")
        (if (executable-find "pip")
            (shell-command "python -c \"import pip; pip.main(['install','pylint'])\"")
          (shell-command "python -c \"from setuptools.command import easy_install; easy_install.main(['pylint'])\"")))

      ;; rm buffer if it exists
      (when (get-buffer pb) (kill-buffer pb))

      ;; only run if in a python code-block
      (when (and (eq 'src-block (car eop))
                 (string= "python" (org-element-property :language eop)))

        ;; tempfile for the code
        (setq tempfile (make-temp-file "org-py-check" nil ".py"))
        ;; create code file
        (with-temp-file tempfile
          (insert (org-element-property :value eop)))

        ;; pylint
        (let ((status (shell-command
                       (concat
                        "pylint "
                        (mapconcat 'identity pylint-options " ")
                        " "
                        ;; this is the file to check.
                        (file-name-nondirectory tempfile))))

              ;; remove empty strings
              (output (delete "" (split-string
                                  (with-current-buffer "*Shell Command Output*"
                                    (buffer-string)) "\n"))))

          ;; also remove this line so the output is empty if nothing
          ;; comes up
          (setq output (delete
                        "No config file found, using default configuration"
                        output))

          (kill-buffer "*Shell Command Output*")
          (if output
              (progn
                (set-buffer (get-buffer-create pb))
                (insert (format "\n\n* pylint (status = %s)\n" status))
                (insert "pylint checks your code for errors, style and convention. Click on the links to jump to each line.
")

                (dolist (line output)
                  ;; pylint gives a line and column number
                  (if
                      (string-match "[A-Z]:\\s-+\\([0-9]*\\),\\s-*\\([0-9]*\\):\\(.*\\)"
                                    line)
                      (let ((line-number (match-string 1 line))
                            (column-number (match-string 2 line))
                            (content (match-string 3 line)))

                        (setq link (format "[[elisp:(progn (switch-to-buffer-other-window \"%s\")(goto-char %s)(forward-line %s)(forward-line 0)(forward-char %s))][%s]]\n"
                                           cb
                                           (org-element-property :begin eop)
                                           line-number
                                           column-number
                                           line)))
                    ;; no match, just insert line
                    (setq link (concat line "\n")))
                  (insert link)))
            (message "pylint was clean!")))

        (when (get-buffer pb)
          ;; open the buffer
          (switch-to-buffer-other-window pb)
          (goto-char (point-min))
          (insert "Press q to close the window\n")
          (org-mode)
          (org-cycle '(64))  ; open everything
          ;; make read-only and press q to quit
          (setq buffer-read-only t)
          (use-local-map (copy-keymap org-mode-map))
          (local-set-key "q" #'(lambda () (interactive) (kill-buffer)))
          (switch-to-buffer-other-window cb))
        ;; final cleanup and delete file
        (delete-file tempfile))))
  )

(after! org
  (defun +org-private/get-name-src-block ()
    (interactive)
    (let ((completion-ignore-case t)
          (case-fold-search t)
          (all-block-names (org-babel-src-block-names)))
      (ivy-read "Named Source Blocks: " all-block-names
                :require-match t
                :history 'get-name-src-block-history
                :preselect (let (select (thing-at-point 'symbol))
                             (if select (substring-no-properties select)))
                :caller '+org-private/get-name-src-block
                :action #'+org-private/get-name-src-block-action-insert)))

  (defun +org-private/*org-ctrl-c-ctrl-c-counsel-org-tag ()
    "Hook for `org-ctrl-c-ctrl-c-hook' to use `counsel-org-tag'."
    (if (save-excursion
          (beginning-of-line)
          (looking-at "[ \t]*$"))
        (or (run-hook-with-args-until-success
             'org-ctrl-c-ctrl-c-final-hook)
            (user-error
             "C-c C-c can do nothing useful at this location"))
      (let* ((context (org-element-context))
             (type (org-element-type context)))
        (case type
          ;; When at a link, act according to the parent instead.
          (link
           (setq context
                 (org-element-property
                  :parent context))
           (setq type
                 (org-element-type context)))
          ;; Unsupported object types: refer to the first supported
          ;; element or object containing it.
          ((bold
            code
            entity
            export-snippet
            inline-babel-call
            inline-src-block
            italic
            latex-fragment
            line-break
            macro
            strike-through
            subscript
            superscript
            underline
            verbatim)
           (setq context
                 (org-element-lineage
                  context
                  '(radio-target
                    paragraph
                    verse-block
                    table-cell)))))
        ;; For convenience: at the first line of a paragraph on the
        ;; same line as an item, apply function on that item instead.
        (when (eq type 'paragraph)
          (let ((parent (org-element-property
                         :parent context)))
            (when (and (eq (org-element-type parent)
                           'item)
                       (= (line-beginning-position)
                          (org-element-property
                           :begin parent)))
              (setq context
                    parent
                    type
                    'item))))
        (case type
          ((headline inlinetask)
           (save-excursion
             (goto-char
              (org-element-property
               :begin context))
             (call-interactively
              'counsel-org-tag))
           t)))))

  )

(after! org
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
  )

(use-package! ob-jupyter
  :defer t
  :init
  (after! ob-async
    (pushnew! ob-async-no-async-languages-alist
              "jupyter-python"
              "jupyter-julia"
              "jupyter-R"))

  (after! org-src
    (dolist (lang '(python julia R))
      (cl-pushnew (cons (format "jupyter-%s" lang) lang)
                  org-src-lang-modes :key #'car)))

  (add-hook! '+org-babel-load-functions
    (defun +org-babel-load-jupyter-h (lang)
      (when (string-prefix-p "jupyter-" (symbol-name lang))
        (require 'jupyter)
        (let* ((lang-name (symbol-name lang))
               (lang-tail (string-remove-prefix "jupyter-" lang-name)))
          (and (not (assoc lang-tail org-src-lang-modes))
               (require (intern (format "ob-%s" lang-tail))
                        nil t)
               (add-to-list 'org-src-lang-modes (cons lang-name (intern lang-tail)))))
        (with-demoted-errors "Jupyter: %s"
          (require lang nil t)
          (require 'ob-jupyter nil t)))))
  :config
  (defadvice! +org--ob-jupyter-initiate-session-a (&rest _)
    :after #'org-babel-jupyter-initiate-session
    (unless (bound-and-true-p jupyter-org-interaction-mode)
      (jupyter-org-interaction-mode)))

  ;; Remove text/html since it's not human readable
  (delq! :text/html jupyter-org-mime-types)

  (require 'tramp))

(set-popup-rule! "*jupyter-pager*" :side 'right :size .40 :select t :vslot 2 :ttl 3)
(set-popup-rule! "^\\*Org Src*" :side 'right :size .60 :select t :vslot 2 :ttl 3 :quit nil)
(set-popup-rule! "*jupyter-repl*" :side 'bottom :size .30 :vslot 2 :ttl 3)

(after! jupyter
  (set-eval-handler! 'jupyter-repl-interaction-mode #'jupyter-eval-line-or-region))

;; on scratch buffer first run jupyter-associate-buffer
(add-hook! python-mode
  (set-repl-handler! 'python-mode #'jupyter-repl-pop-to-buffer))

(setq scihub-homepage "https://sci-hub.st"
      scihub-download-directory "~/pdfs"
      scihub-open-after-download nil)


;; PDF Tools ease of highlighting and history
(map!
 :map pdf-view-mode-map
 :v "a" #'pdf-annot-add-highlight-markup-annotation
 :v "A" #'pdf-annot-add-markup-annotation
 :v "t" #'pdf-annot-add-text-annotation
 :n "x" #'pdf-annot-delete
 :n "c" #'pdf-history-backward
 :n "C" #'pdf-history-forward
 :n "b" #'pdf-view-set-slice-from-bounding-box
 :n "B" #'pdf-view-reset-slice)

(global-set-key (kbd "C-c o") 'bh/make-org-scratch)
(global-set-key (kbd "C-c s") 'bh/switch-to-scratch)
(bind-key "H-h" '+ivy/switch-workspace-buffer-other-window)
(bind-key "H-z" 'consult-recent-file)
(bind-key "H-x" 'consult-buffer)
;; (bind-key "H-a" '+ivy/switch-workspace-buffer)
(bind-key "H-a" '+vertico/switch-workspace-buffer)
(bind-key "H-1" 'winum-select-window-1)
(bind-key "H-2" 'winum-select-window-2)
(bind-key "H-3" 'winum-select-window-3)
(bind-key "H-4" 'winum-select-window-4)
(bind-key "H-5" 'winum-select-window-5)
;; scroll other window, useful when working with multiple files
(bind-key "H-k" 'scroll-other-window-down)
(bind-key "H-j" 'scroll-other-window)
(bind-key "<f5>" 'switch-dark-mode)
(bind-key "H-<return>" 'newline-and-indent)
(bind-key "H-s" #'+ivy/project-search-with-hidden-files)
(bind-key "H-/" #'doom/toggle-comment-region-or-line)
(map! :leader
      (:prefix "e"
       :n "e" #'ace-window
       :n "u" #'swiper-all
       :n "s" #'deadgrep
       :n "r" #'helm-org-rifle-directories
       :n "l" #'my/last-captured-org-note)
      (:prefix "o"
       :n "U" #'elfeed
       :n "s" #'org-open-at-point
       :n "u" #'elfeed-update
       ;; EXPERIMENTAL HACK
       ;; :n "p" #'dired-sidebar-toggle-sidebar
       :n "o" #'dired-jump)
      (:prefix "s"
        :n "q" #'org-ql-search
        :n "a" #'helm-org-rifle-current-buffer
        :n "w" #'helm-org-rifle-org-directory
        :n "h" #'helm-org-rifle-directories)
      (:prefix "v"
       :n "d" #'dash-docs-activate-docset
       :n "e" #'ein:run
       :n "r" #'+python/open-jupyter-repl
       :n "i" #'+python/optimize-imports
       :n "f" #'sp-forward-sexp
       :n "n" #'ein:notebooklist-open
       :n "o" #'ein:notebooklist-new-notebook-with-name
       (:prefix "j"
        :n "r" #'jupyter-org-interrupt-kernel
        :n "c" #'jupyter-org-clone-blcok
        :n "s" #'org-babel-jupyter-scratch-buffer
        :n "S" #'jupyter-repl-scratch-buffer
        :n "e" #'jupyter-org-restart-and-execute-to-point))
      (:prefix "z"
       :n "a" #'unpackaged/iedit-or-flyspell
       :n "s" #'create-new-ml-project
       :n "w" #'change-env-and-restart-lsp
       :n "l" #'unpackaged/lorem-ipsum-overlay
       :n "h" #'unpackaged/org-outline-numbers
       :n "g" #'unpackaged/magit-status
       :n "u" #'unpackaged/flex-fill-paragraph
       :n "i" #'org-mru-clock-in
       :n "f" #'auto-fill-mode
       :n "z" #'zoom-mode
       :n "y" #'jethro/bulk-process-entries
       :n "j" #'grab-x-link-firefox-insert-org-link
       :n "b" #'grab-x-link-brave-insert-org-link
       :n "d" #'unpackaged/org-refile-to-datetree-using-ts-in-entry)
      (:prefix "d"
       :n "h" #'org-ref-bibtex-hydra/body
       :n "w" #'+hydra/window-nav/body
       :n "m" #'hydra-multiple-cursors/body
       :n "s" #'+org-private@org-babel-hydra/body
       :n "t" #'scimax-org-table/body
       :n "h" #'scimax-org-headline/body
       :n "n" #'org-toogle-narrow-to-subtree
       :n "w" #'+hydra/window-nav/body
       :n "p" #'scimax-python-mode/body
       :n "o" #'org-noter
       :n "c" #'org-noter-pdftools-create-skeleton
       :n "j" #'org-hugo-auto-export-mode
       :n "p" #'poetry
       :n "r" #'poetry-run
       :n "d" #'scimax-dired/body)
      (:prefix "z"
       :n "f" #'org-roam-node-find
       :n "r" #'org-roam-node-random
       :n "i" #'org-roam-capture
       :n "b" #'org-roam-buffer
       :n "B" #'org-roam-buffer-toggle)
)

(after! org

  (evil-define-key 'normal org-mode-map
    ;; keybindings mirror ipython web interface behavior
    "go" 'org-babel-previous-src-block
    "gO" 'org-babel-next-src-block)

  ;; keys used:  o, b, p, y,e  and P,Y,B,O,E,J,K
  (map! :map org-mode-map
        "<C-return>" 'org-ctrl-c-ctrl-c
        "<s-return>" 'jupyter-org-execute-and-next-block
        ;; "gI" 'org-babel-previous-src-block
        ;; "H-s" 'org-babel-next-src-block
        "H-e" 'jupyter-org-execute-to-point
        "H-E" 'jupyter-org-execute-subtree

        "H-K" 'jupyter-org-move-src-block
        "H-J" '(lambda ()
                 (interactive)
                 (jupyter-org-move-src-block t))

        "H-O" 'jupyter-org-insert-src-block
        "H-o" '(lambda ()
                 (interactive)
                 (jupyter-org-insert-src-block t))

        "H-B" 'jupyter-org-split-src-block
        "H-b" '(lambda ()
                 (interactive)
                 (jupyter-org-split-src-block t))
        "C-H-k" 'jupyter-org-merge-blocks
        "H-p" 'jupyter-org-jump-to-block
        "H-P" 'jupyter-org-jump-to-visible-block
        "H-y" 'jupyter-org-kill-block-and-results
        "H-Y" 'jupyter-org-copy-block-and-results
        "C-H-l" 'jupyter-org-clear-all-results
        "H-n" 'jupyter-org-next-busy-src-block
        "H-N" 'jupyter-org-previous-busy-src-block
        "<H-return>" '(lambda ()
                        (interactive)
                        (jupyter-org-execute-and-next-block t)))
  )

(after! org
  (define-key org-mode-map (kbd "H-Y") 'other-window)
  (define-key org-mode-map (kbd "H-y") 'org-strikethrough-region-or-point)
  (define-key org-mode-map (kbd "H-i") 'org-italics-region-or-point)
  (define-key org-mode-map (kbd "H-I") 'org-bold-region-or-point)
  (define-key org-mode-map (kbd "H-v") 'org-verbatim-region-or-point)
  (define-key org-mode-map (kbd "H-V") 'org-code-region-or-point)
  (define-key org-mode-map (kbd "H-u") 'org-superscript-region-or-point)
  (define-key org-mode-map (kbd "H-U") 'org-underline-region-or-point)
  (define-key org-mode-map (kbd "H-l") 'org-latex-math-region-or-point)
  )

(bind-key "H-d" 'evil-window-vsplit)
(bind-key "H-f" 'evil-window-split)
(bind-key "H-t" '+my/vterm-run-project)
(bind-key "H-q" '+workspace/close-window-or-workspace)
(bind-key "H-w" '+workspace/load)

(map! :localleader
      :map markdown-mode-map
      :prefix ("i" . "Insert")
      :desc "Blockquote"    "q" 'markdown-insert-blockquote
      :desc "Horiz rule"    "r" 'markdown-insert-hr
      :desc "Bold"          "b" 'markdown-insert-bold
      :desc "Table"         "T" 'markdown-insert-table
      :desc "Code"          "c" 'markdown-insert-code
      :desc "Emphasis"      "e" 'markdown-insert-italic
      :desc "Footnote"      "f" 'markdown-insert-footnote
      :desc "Code Block"    "s" 'markdown-insert-gfm-code-block
      :desc "List Item"     "n" 'markdown-insert-list-item
      :desc "Pre"           "p" 'markdown-insert-pre
      :prefix ("h" . "Headings")
      :desc "One"   "1" 'markdown-insert-header-atx-1
      :desc "Two"   "2" 'markdown-insert-header-atx-2
      :desc "Three" "3" 'markdown-insert-header-atx-3
      :desc "Four"  "4" 'markdown-insert-header-atx-4
      :desc "Five"  "5" 'markdown-insert-header-atx-5
      :desc "Six"   "6" 'markdown-insert-header-atx-6)

(defun doom/toggle-comment-region-or-line ()
  "Comments or uncomments the whole region or if no region is
selected, then the current line."
  (interactive)
  (let (beg end)
    (if (region-active-p)
        (setq beg (region-beginning) end (region-end))
      (setq beg (line-beginning-position) end (line-end-position)))
    (comment-or-uncomment-region beg end)))

;;;###autoload
(defun org-gtd/archive-all-done-entries ()
  "Archive all entries marked DONE"
  (interactive)
  (save-excursion
    (goto-char (point-max))
    (while (outline-previous-heading)
      (when (org-entry-is-done-p)))))

;;;###autoload
(defun bh/make-org-scratch ()
  (interactive)
  (find-file "/tmp/publish/scratch.org")
  (gnus-make-directory "/tmp/publish"))

;;;###autoload
(defun bh/switch-to-scratch ()
  (interactive)
  (switch-to-buffer "*scratch*"))

;;;###autoload
(defmacro unpackaged/define-chooser (name &rest choices)
  "Define a chooser command NAME offering CHOICES.
Each of CHOICES should be a list, the first of which is the
choice's name, and the rest of which is its body forms."
  (declare (indent defun))
  ;; Avoid redefining existing, non-chooser functions.
  (cl-assert (or (not (fboundp name))
                 (get name :unpackaged/define-chooser)))
  (let* ((choice-names (mapcar #'car choices))
         (choice-list (--map (cons (car it) `(lambda (&rest args)
                                               ,@(cdr it)))
                             choices))
         (prompt (format "Choose %s: " name))
         (docstring (concat "Choose between: " (s-join ", " choice-names))))
    `(progn
       (defun ,name ()
         ,docstring
         (interactive)
         (let* ((choice-name (completing-read ,prompt ',choice-names)))
           (funcall (alist-get choice-name ',choice-list nil nil #'equal))))
       (put ',name :unpackaged/define-chooser t))))

(after! org
  (defvar jethro/org-current-effort "1:00"
    "Current effort for agenda items.")

  (defun jethro/my-org-agenda-set-effort (effort)
    "Set the effort property for the current headline."
    (interactive
     (list (read-string (format "Effort [%s]: " jethro/org-current-effort) nil nil jethro/org-current-effort)))
    (setq jethro/org-current-effort effort)
    (org-agenda-check-no-diary)
    (let* ((hdmarker (or (org-get-at-bol 'org-hd-marker)
                         (org-agenda-error)))
           (buffer (marker-buffer hdmarker))
           (pos (marker-position hdmarker))
           (inhibit-read-only t)
           newhead)
      (org-with-remote-undo buffer
        (with-current-buffer buffer
          (widen)
          (goto-char pos)
          (org-show-context 'agenda)
          (funcall-interactively 'org-set-effort nil jethro/org-current-effort)
          (end-of-line 1)
          (setq newhead (org-get-heading)))
        (org-agenda-change-all-lines newhead hdmarker))))


  (defun jethro/org-agenda-process-inbox-item ()
    "Process a single item in the org-agenda."
    (org-with-wide-buffer
     (org-agenda-set-tags)
     ;; (org-agenda-set-property)
     (org-agenda-priority)
     (call-interactively 'org-agenda-schedule)
     (call-interactively 'jethro/my-org-agenda-set-effort)
     (org-agenda-refile nil nil t)))


  (defun jethro/bulk-process-entries ()
    (interactive)
    (if (not (null org-agenda-bulk-marked-entries))
        (let ((entries (reverse org-agenda-bulk-marked-entries))
              (processed 0)
              (skipped 0))
          (dolist (e entries)
            (let ((pos (text-property-any (point-min) (point-max) 'org-hd-marker e)))
              (if (not pos)
                  (progn (message "Skipping removed entry at %s" e)
                         (cl-incf skipped))
                (goto-char pos)
                (let (org-cl-loop-over-headlines-in-active-region) (funcall 'jethro/org-agenda-process-inbox-item))
                ;; `post-command-hook' is not run yet.  We make sure any
                ;; pending log note is processed.
                (when (or (memq 'org-add-log-note (default-value 'post-command-hook))
                          (memq 'org-add-log-note post-command-hook))
                  (org-add-log-note))
                (cl-incf processed))))
          (org-agenda-redo)
          (unless org-agenda-persistent-marks (org-agenda-bulk-unmark-all))
          (message "Acted on %d entries%s%s"
                   processed
                   (if (= skipped 0)
                       ""
                     (format ", skipped %d (disappeared before their turn)"
                             skipped))
                   (if (not org-agenda-persistent-marks) "" " (kept marked)")))))

  ;; capture inbox in agenda mode
  (defun jethro/org-inbox-capture ()
    (interactive)
    "Capture a task in agenda mode."
    (org-capture nil "c"))
  )

;; (setq aw-keys '(106 107 108 105 111 104 121 117 112) t)

(defun +my/vterm-run-project ()
  (interactive)
  ;; (if (not (eq (length (window-list)) 3))
  ;;     (progn
  ;;       (+evil-window-vsplit-a)
  ;;       (+evil-window-split-a)))
  (doom/window-maximize-buffer)
  (+evil-window-vsplit-a)
  (+evil-window-split-a)
  (call-interactively '+vterm/here))

;;;###autoload
(defun create-new-ml-project (proj-name proj-type)
  "Initial setup for any ML project"
  (interactive "sEnter the project full path:
sEnter type of project: ")
  (+workspace/new)
  (if (equal proj-type "p")
      (setq full-proj (concatenate 'string "~/workspace/personal/" proj-name ))
    (setq full-proj (concatenate 'string "~/workspace/work/" proj-name)))
  ;; (message "%s" full-proj)
  (dired-create-directory full-proj)
  (dired-create-directory (concatenate 'string full-proj "/src"))
  (dired-create-directory (concatenate 'string full-proj "/input"))
  (dired-create-directory (concatenate 'string full-proj "/models"))
  (magit-init full-proj)
  (shell-command "joe linux python >> .gitignore")
  (ml-gitignore)
  (setq py-files '("src/__init__.py" "predict.py" "utils.py" "dataset.py"
                   "feature_generator.py" "dispatcher.py" "create_folds.py"
                   "train.py" "loss.py"))
  (dolist (element py-files)
    (message "%s" element)
    (find-file element)
    (save-buffer))
  (projectile-add-known-project full-proj)
  (projectile-switch-project-by-name full-proj)
  )

;;;###autoload
(defun ml-gitignore ()
  (find-file ".gitignore")
  (insert "
# input and data related\n
input/\n
models/\n

# data
*.csv
*.h5
*.pkl
*.hd5
*.pth

")
  (save-buffer)
  )

(when EMACS28+
  (add-hook 'latex-mode-hook #'TeX-latex-mode))

;;;###autoload
(defun switch-dark-mode()
  "Switch to dark mode with a key"
  (interactive)
  (if (equal doom-theme 'doom-flatwhite)
      (progn
        (message "Dark theme enabled")
        (load-theme 'doom-city-lights 'noconfirm)
        (doom/reload-theme))
    (progn
      (message "Light theme enabled")
      (load-theme 'doom-flatwhite 'noconfirm)
      (doom/reload-theme))))

(defun change-env-and-restart-lsp()
  "Changes the python environment and
restart lsp based on that environment"
  (interactive)
  (conda-env-activate)
  (lsp-restart-workspace))


(require 'nepali-romanized)

(after! doom-modeline
  (doom-modeline-def-modeline 'main
    '(bar matches buffer-info remote-host buffer-position parrot selection-info)
    '(misc-info minor-modes checker input-method buffer-encoding major-mode process vcs  "    "))) ; <-- added padding here

(defvar chrome-bookmarks-file
  (cl-find-if
   #'file-exists-p
   ;; Base on `helm-chrome-file'
   (list
    ;; "~/Library/Application Support/Google/Chrome/Profile 1/Bookmarks"
    ;; "~/Library/Application Support/Google/Chrome/Default/Bookmarks"
    ;; "~/AppData/Local/Google/Chrome/User Data/Default/Bookmarks"
    ;; "~/.config/google-chrome/Default/Bookmarks"
    ;; "~/bookmarks_edge_beta.json"
    ;; "~/bookmarks_edge_dev.json"
    ;; "~/bookmarks_edge.json"
    "~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks"
    ;; "~/.config/google-chrome/Default/Bookmarks"
    ;; "~/.config/chromium/Default/Bookmarks"
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

;; (after! org
;;   (add-hook 'org-mode-hook (lambda () (org-autolist-mode))))

;; (use-package! dired-sidebar
;;   :unless (featurep! :emacs dired +ranger)
;;   :defer
;;   :config
;;   (setq dired-sidebar-width 25
;;         dired-sidebar-theme 'nerd
;;         dired-sidebar-tui-update-delay 5
;;         dired-sidebar-recenter-cursor-on-tui-update t
;;         dired-sidebar-no-delete-other-windows t
;;         dired-sidebar-use-custom-modeline t)
;;   (pushnew! dired-sidebar-toggle-hidden-commands
;;             'evil-window-rotate-upwards 'evil-window-rotate-downwards)
;;   (map! :map dired-sidebar-mode-map
;;         :n "q" #'dired-sidebar-toggle-sidebar))

;; (use-package! dired-subtree
;;   :unless (featurep! :emacs dired +ranger)
;;   :config
;;   (setq dired-subtree-cycle-depth 4
;;         dired-subtree-line-prefix ">")
;;   (map! :map dired-mode-map
;;         [backtab] #'dired-subtree-cycle
;;         [tab] #'dired-subtree-toggle
;;         :n "g^" #'dired-subtree-beginning
;;         :n "g$" #'dired-subtree-end
;;         :n "gm" #'dired-subtree-mark-subtree
;;         :n "gu" #'dired-subtree-unmark-subtree))

(after! org
  (require 'org-capture)
  (require 'org-protocol)

;;; Org Capture
;;;; Thank you random guy from StackOverflow
;;;; http://stackoverflow.com/questions/23517372/hook-or-advice-when-aborting-org-capture-before-template-selection

  (defadvice org-capture
      (after make-full-window-frame activate)
    "Advise capture to be the only window when used as a popup"
    (if (equal "emacs-capture" (frame-parameter nil 'name))
        (delete-other-windows)))

  (defadvice org-capture-finalize
      (after delete-capture-frame activate)
    "Advise capture-finalize to close the frame"
    (if (equal "emacs-capture" (frame-parameter nil 'name))
        (delete-frame)))
  )


(after! org

  (lambda () (progn
          (setq left-margin-width 2)
          (setq right-margin-width 2)
          (set-window-buffer nil (current-buffer))))

  (setq org-startup-indented t
        org-hide-leading-stars t
        org-ellipsis "  " ;; folding symbol
        org-hide-emphasis-markers t ;; show actually italicized text instead of /italicized text/
        org-agenda-block-separator ""
        org-fontify-whole-heading-line t
        org-fontify-done-headline t
        org-fontify-quote-and-verse-blocks t)

  ;;(setq global-org-pretty-table-mode t)
  )

;; Modified from https://wilkesley.org/~ian/xah/emacs/dired_sort.html
(defun light-dired-sort ()
  "Sort dired dir listing in different ways.
Prompt for a choice.
URL `http://ergoemacs.org/emacs/dired_sort.html'
Version 2015-07-30"
  (interactive)
  (let (-sort-by -hidden -arg)
    (setq -sort-by (ivy-read "Sort by:" '( "Date" "Size" "Name" "Ext" "Dir" "Date Asc" "Name Desc" "Size Asc")))
    (setq -hidden (ivy-read "Show Hidden Files:" '("Yes" "No")))
    (cond
     ((equal -hidden "Yes")
      (progn
        (cond
         ((equal -sort-by "Name") (setq -arg "-Ahl --si --time-style long-iso "))
         ((equal -sort-by "Date") (setq -arg "-Ahlt --si --time-style long-iso"))
         ((equal -sort-by "Size") (setq -arg "-AhlS --si --time-style long-iso"))
         ((equal -sort-by "Ext") (setq -arg "-AhlX --si --time-style long-iso --group-directories-first"))
         ((equal -sort-by "Name Desc") (setq -arg "-Ahlr --si --time-style long-iso "))
         ((equal -sort-by "Date Asc") (setq -arg "-Ahltr --si --time-style long-iso"))
         ((equal -sort-by "Size Asc") (setq -arg "-AhlSr --si --time-style long-iso"))
         ((equal -sort-by "Dir") (setq -arg "-Ahl --si --time-style long-iso --group-directories-first"))
         (t (error "Logic error 09535" )))
        (dired-sort-other -arg )
        ;; (dired-listing-switches -arg )
        (setq dired-listing-switches -arg)))
     ((equal -hidden "No")
      (progn
        (message -hidden)
        (cond
         ((equal -sort-by "Name") (setq -arg "-hl --si --time-style long-iso "))
         ((equal -sort-by "Date") (setq -arg "-hlt --si --time-style long-iso"))
         ((equal -sort-by "Size") (setq -arg "-hlS --si --time-style long-iso"))
         ((equal -sort-by "Ext") (setq -arg "-hlX --si --time-style long-iso --group-directories-first"))
         ((equal -sort-by "Name Desc") (setq -arg "-hlr --si --time-style long-iso"))
         ((equal -sort-by "Date Desc") (setq -arg "-hltr --si --time-style long-iso"))
         ((equal -sort-by "Size Desc") (setq -arg "-hlSr --si --time-style long-iso"))
         ((equal -sort-by "Dir") (setq -arg "-hl --si --time-style long-iso --group-directories-first"))
         (t (error "Logic error 09535" )))
        (dired-sort-other -arg )
        (setq dired-listing-switches -arg)))
     )
    ))

(map! (:after dired
       :map dired-mode-map
       :n "gb" #'light-dired-sort))

(setq writeroom-width 100)

;; Taken from tecosaur's config
;;
(setq which-key-idle-delay 0.5) ;; I need the help, I really do
(setq which-key-allow-multiple-replacements t)
(after! which-key
  (pushnew!
   which-key-replacement-alist
   '(("" . "\\`+?evil[-:]?\\(?:a-\\)?\\(.*\\)") . (nil . "◂\\1"))
   '(("\\`g s" . "\\`evilem--?motion-\\(.*\\)") . (nil . "◃\\1"))
   ))


;; So you want your return to be intelligent: Kitchin to the rescue
(after! org
  (defun unpackaged/org-element-descendant-of (type element)
    "Return non-nil if ELEMENT is a descendant of TYPE.
TYPE should be an element type, like `item' or `paragraph'.
ELEMENT should be a list like that returned by `org-element-context'."
    ;; MAYBE: Use `org-element-lineage'.
    (when-let* ((parent (org-element-property :parent element)))
      (or (eq type (car parent))
          (unpackaged/org-element-descendant-of type parent))))

;;;###autoload
  (defun unpackaged/org-return-dwim (&optional default)
    "A helpful replacement for `org-return-indent'.  With prefix, call `org-return-indent'.

On headings, move point to position after entry content.  In
lists, insert a new item or end the list, with checkbox if
appropriate.  In tables, insert a new row or end the table."
    ;; Inspired by John Kitchin: http://kitchingroup.cheme.cmu.edu/blog/2017/04/09/A-better-return-in-org-mode/
    (interactive "P")
    (if default
        (org-return t)
      (cond
       ;; Act depending on context around point.

       ;; NOTE: I prefer RET to not follow links, but by uncommenting this block, links will be
       ;; followed.

       ;; ((eq 'link (car (org-element-context)))
       ;;  ;; Link: Open it.
       ;;  (org-open-at-point-global))

       ((org-at-heading-p)
        ;; Heading: Move to position after entry content.
        ;; NOTE: This is probably the most interesting feature of this function.
        (let ((heading-start (org-entry-beginning-position)))
          (goto-char (org-entry-end-position))
          (cond ((and (org-at-heading-p)
                      (= heading-start (org-entry-beginning-position)))
                 ;; Entry ends on its heading; add newline after
                 (end-of-line)
                 (insert "\n\n"))
                (t
                 ;; Entry ends after its heading; back up
                 (forward-line -1)
                 (end-of-line)
                 (when (org-at-heading-p)
                   ;; At the same heading
                   (forward-line)
                   (insert "\n")
                   (forward-line -1))
                 ;; FIXME: looking-back is supposed to be called with more arguments.
                 (while (not (looking-back (rx (repeat 3 (seq (optional blank) "\n")))))
                   (insert "\n"))
                 (forward-line -1)))))

       ((org-at-item-checkbox-p)
        ;; Checkbox: Insert new item with checkbox.
        (org-insert-todo-heading nil))

       ((org-in-item-p)
        ;; Plain list.  Yes, this gets a little complicated...
        (let ((context (org-element-context)))
          (if (or (eq 'plain-list (car context))  ; First item in list
                  (and (eq 'item (car context))
                       (not (eq (org-element-property :contents-begin context)
                                (org-element-property :contents-end context))))
                  (unpackaged/org-element-descendant-of 'item context))  ; Element in list item, e.g. a link
              ;; Non-empty item: Add new item.
              (org-insert-item)
            ;; Empty item: Close the list.
            ;; TODO: Do this with org functions rather than operating on the text. Can't seem to find the right function.
            (delete-region (line-beginning-position) (line-end-position))
            (insert "\n"))))

       ((when (fboundp 'org-inlinetask-in-task-p)
          (org-inlinetask-in-task-p))
        ;; Inline task: Don't insert a new heading.
        (org-return t))

       ((org-at-table-p)
        (cond ((save-excursion
                 (beginning-of-line)
                 ;; See `org-table-next-field'.
                 (cl-loop with end = (line-end-position)
                          for cell = (org-element-table-cell-parser)
                          always (equal (org-element-property :contents-begin cell)
                                        (org-element-property :contents-end cell))
                          while (re-search-forward "|" end t)))
               ;; Empty row: end the table.
               (delete-region (line-beginning-position) (line-end-position))
               (org-return t))
              (t
               ;; Non-empty row: call `org-return-indent'.
               (org-return t))))
       (t
        ;; All other cases: call `org-return-indent'.
        (org-return t)))))

  (map!
   :after evil-org
   :map evil-org-mode-map
   :i [return] #'unpackaged/org-return-dwim))


;; ess config from tecosaur
(set-company-backend! 'ess-r-mode '(company-R-args company-R-objects company-dabbrev-code :separate))
(setq ess-eval-visibly 'nowait)
(setq ess-R-font-lock-keywords
      '((ess-R-fl-keyword:keywords . t)
        (ess-R-fl-keyword:constants . t)
        (ess-R-fl-keyword:modifiers . t)
        (ess-R-fl-keyword:fun-defs . t)
        (ess-R-fl-keyword:assign-ops . t)
        (ess-R-fl-keyword:%op% . t)
        (ess-fl-keyword:fun-calls . t)
        (ess-fl-keyword:numbers . t)
        (ess-fl-keyword:operators . t)
        (ess-fl-keyword:delimiters . t)
        (ess-fl-keyword:= . t)
        (ess-R-fl-keyword:F&T . t)))
(after! ess-r-mode
  (appendq! +ligatures-extra-symbols
            '(:assign "⟵"
              :multiply "×"))
  (set-ligatures! 'ess-r-mode
    ;; Functional
    :def "function"
    ;; Types
    :null "NULL"
    :true "TRUE"
    :false "FALSE"
    :int "int"
    :floar "float"
    :bool "bool"
    ;; Flow
    :not "!"
    :and "&&" :or "||"
    :for "for"
    :in "%in%"
    :return "return"
    ;; Other
    :assign "<-"
    :multiply "%*%"))

(add-hook 'org-mode-hook 'org-fragtog-mode)
(setq global-org-pretty-table-mode t)

;; irritates you every time so let it go [tecosaur's code]
(setq projectile-ignored-projects '("~/" "/tmp" "~/.emacs.d/.local/straight/repos/"))
(defun projectile-ignored-project-function (filepath)
  "Return t if FILEPATH is within any of `projectile-ignored-projects'"
  (or (mapcar (lambda (p) (s-starts-with-p p filepath)) projectile-ignored-projects)))

(setq org-time-budgets '((:title "Spanish Lessons" :match "+spanish" :budget "10:00" :blocks (day week))
                         (:title "Growing Personally" :match "+@growth+home" :budget "30:00" :blocks (day week))
                         (:title "Entertaintment" :match "+entertaintment" :budget "5:00" :blocks (day week))
                         (:title "All Mundane" :match "+@mundane" :budget "8:00" :blocks (day week))
                         (:title "Freelancing Projects" :match "+@work+home" :budget "20:00" :blocks (day week))
                         (:title "Guitar practice" :match "+music" :budget "5:00" :blocks (nil week))
                         (:title "Sanskrit" :match "+sanskrit" :budget "5:15" :blocks (day week))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Tree Sitter Highlighting                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(use-package tree-sitter
  :config
  (require 'tree-sitter-langs)
  (global-tree-sitter-mode)
  (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode)
  )


;; For converting org download links to normal file links for ease of use
(after! org
  (defun cpb/convert-attachment-to-file ()
    "Convert [[attachment:..]] to [[file:..][file:..]]"
    (interactive)
    (let ((elem (org-element-context)))
      (if (eq (car elem) 'link)
          (let ((type (org-element-property :type elem)))
            ;; only translate attachment type links
            (when (string= type "attachment")
              ;; translate attachment path to relative filename using org-attach API
              ;; 2020-11-15: org-attach-export-link was removed, so had to rewrite
              (let* ((link-end (org-element-property :end elem))
                     (link-begin (org-element-property :begin elem))
                     ;; :path is everything after attachment:
                     (file (org-element-property :path elem))
                     ;; expand that to the full filename
                     (fullpath (org-attach-expand file))
                     ;; then make it relative to the directory of this org file
                     (current-dir (file-name-directory (or default-directory
                                                           buffer-file-name)))
                     (relpath (file-relative-name fullpath current-dir)))
                ;; delete the existing link
                (delete-region link-begin link-end)
                ;; replace with file: link and file: description
                (insert (format "[[file:%s][file:%s]]" relpath relpath)))))))))

;; visiting tanglesd file at point
(after! org
  (defun ibizaman/org-babel-goto-tangle-file ()
    (if-let* ((args (nth 2 (org-babel-get-src-block-info t)))
              (tangle (alist-get :tangle args)))
        (when (not (equal "no" tangle))
          (find-file tangle)
          t)))

  (add-hook 'org-open-at-point-functions 'ibizaman/org-babel-goto-tangle-file))

(add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode)
(after! org
  (require 'ox-ipynb))

;; Managing projects with gtd workflow
;; Taken from org-gtd.el package and modified
(after! org
  (setq org-stuck-projects '("+LEVEL=1-DONE+CATEGORY=\"project\""
                             ("TODO" "NEXT" "WAIT")
                             nil ""))
  (defconst org-complete-projects
    "+LEVEL=1+CATEGORY=\"project\""
    "How to identify projects in the GTD system.")
  (defun org-gtd--org-element-pom (element)
    "Return buffer position for start of Org ELEMENT."
    (org-element-property :begin element))
  (defun org-archive-complete-projects ()
    "Archive all projects for which all actions/tasks are marked as done.
        Done here is any done `org-todo-keyword'."
    (interactive)
    (org-map-entries
     (lambda ()
       (if (org-gtd--project-complete-p)
           (progn
             (setq org-map-continue-from (org-element-property
                                          :begin
                                          (org-element-at-point)))
             (org-archive-subtree-default))))
     org-complete-projects))
  (defun org-gtd--project-complete-p ()
    "Return t if project complete, nil otherwise.
A project is considered complete when all its actions/tasks are
marked with a done `org-todo-keyword'."
    (let ((entries (cdr (org-map-entries
                         (lambda ()
                           (org-entry-get
                            (org-gtd--org-element-pom (org-element-at-point))
                            "PROJ"))
                         t
                         'tree))))
      (seq-every-p (lambda (x) (string-equal x "DONE")) entries)))
  (defun org-delegate-task ()
    "Process GTD inbox item by delegating it.
Allow the user apply user-defined tags from
`org-tag-persistent-alist', `org-tag-alist' or file-local tags in
the inbox.  Set it as a waiting action and refile to
`org-gtd-actionable-file-basename'."
    (interactive)
    (org-narrow-to-subtree)
    (org-set-tags-command)
    (org-todo "WAITING")
    (org-set-property "DELEGATED_TO" (read-string "Who will do this? "))
    (org-schedule 0)
    (widen))
  )

(after! org
  (require 'org-edna)
  (org-edna-mode))




;; Named terminal with vterm/here
;;;###autoload
(defun +vterm--change-directory-if-remote ()
  "When `default-directory` is remote, use the corresponding
method to prepare vterm at the corresponding remote directory."
  (when (and (featurep 'tramp)
             (tramp-tramp-file-p default-directory))
    (message "default-directory is %s" default-directory)
    (with-parsed-tramp-file-name default-directory path
      (let ((method (cadr (assoc `tramp-login-program
                                 (assoc path-method tramp-methods)))))
        (vterm-send-string
         (concat method " "
                 (when path-user (concat path-user "@")) path-host))
        (vterm-send-return)
        (vterm-send-string
         (concat "cd " path-localname))
        (vterm-send-return)))))

;;;###autoload
(defun +vterm/here (arg)
  "Open a terminal buffer in the current window at project root.

If prefix ARG is non-nil, cd into `default-directory' instead of project root."
  (interactive "P")
  (unless (fboundp 'module-load)
    (user-error "Your build of Emacs lacks dynamic modules support and cannot load vterm"))
  (require 'vterm)
  ;; This hack forces vterm to redraw, fixing strange artefacting in the tty.
  (save-window-excursion
    (pop-to-buffer "*scratch*"))
  (let* ((project-root (or (doom-project-root) default-directory))
         (default-directory
           (if arg
               default-directory
             project-root))
         display-buffer-alist)
    (setenv "PROOT" project-root)
    (setq my-proj-name (concat "vterm-" (nth 0 (reverse (s-split "/" project-root 'omit-nulls)))))
    (if (get-buffer my-proj-name)
        (switch-to-buffer my-proj-name)
      (vterm my-proj-name))
    ;; (vterm my-proj-name)
    (+vterm--change-directory-if-remote)))

;; Run my django project with the commands I want to run set in dir-locals.el file
;;;###autoload
(defun run-django-project()
  "Run a django project with commands
from .dir-locals.el"
  (interactive)
  (setq django-commands (eval (cdr (assoc 'django-commands-list dir-local-variables-alist))))
  (call-interactively '+vterm/here) ()
  (dolist (command django-commands)
    (vterm-send-string command)
    (vterm-send-return))
  )

;; FIXME With issue with org roam server this works
;; Taken from org-roam-server's github
;;;###autoload
(defun org-roam-server-open ()
  "Ensure the server is active, then open the roam graph."
  (interactive)
  (smartparens-global-mode -1)
  (org-roam-server-mode 1)
  (browse-url-xdg-open (format "http://localhost:%d" org-roam-server-port))
  (smartparens-global-mode 1))

;; Auto convert task to done when the checkboxes are done.
;;;###autoload
;; (after! org
;;   (defun my/org-checkbox-todo ()
;;     "Switch header TODO state to DONE when all checkboxes are ticked, to TODO otherwise"
;;     (let ((todo-state (org-get-todo-state)) beg end)
;;       (unless (not todo-state)
;;         (save-excursion
;;           (org-back-to-heading t)
;;           (setq beg (point))
;;           (end-of-line)
;;           (setq end (point))
;;           (goto-char beg)
;;           (if (re-search-forward "\\[\\([0-9]*%\\)\\]\\|\\[\\([0-9]*\\)/\\([0-9]*\\)\\]"
;;                                  end t)
;;               (if (match-end 1)
;;                   (if (equal (match-string 1) "100%")
;;                       (unless (string-equal todo-state "DONE")
;;                         (org-todo 'done))
;;                     (unless (string-equal todo-state "TODO")
;;                       (org-todo 'todo)))
;;                 (if (and (> (match-end 2) (match-beginning 2))
;;                          (equal (match-string 2) (match-string 3)))
;;                     (unless (string-equal todo-state "DONE")
;;                       (org-todo 'done))
;;                   (unless (string-equal todo-state "TODO")
;;                     (org-todo 'todo)))))))))
;;   (add-hook 'org-checkbox-statistics-hook 'my/org-checkbox-todo)
;;   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org super agenda                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; My setup is complex and I don't want to make it any harder now.
;; Worked on it for some time but it will take time.
;; Let it be for now with as much setup as done so that I can continue it later.


;; (use-package! org-super-agenda
;;   :after org-agenda
;;   :config
;;   (setq org-super-agenda-groups '((:auto-dir-name t)))
;;   (org-super-agenda-mode))

;; (after! org-agenda
;;   (org-super-agenda-mode)
;;   (setq org-super-agenda-header-map (make-sparse-keymap))
;;   (defvar org-super-agenda-header-map (copy-keymap evil-org-agenda-mode-map)))

;; (setq org-agenda-custom-commands
;;       '(("k" "Today's view"
;;          ((agenda "" ((org-agenda-span 'day)
;;                       (org-super-agenda-groups
;;                        '((:name "Today"
;;                           :time-grid t
;;                           :date today
;;                           :todo "TODAY"
;;                           :scheduled today
;;                           :order 1)))))
;;           (alltodo "" ((org-agenda-overriding-header "")
;;                        (org-super-agenda-groups
;;                         '((:name "Next to do"
;;                            :todo "NEXT"
;;                            :order 1)
;;                           (:name "Important"
;;                            :tag "Important"
;;                            :priority "A"
;;                            :order 6)
;;                           (:name "Due Today"
;;                            :deadline today
;;                            :order 2)
;;                           (:name "Due Soon"
;;                            :deadline future
;;                            :order 8)
;;                           (:name "Overdue"
;;                            :deadline past
;;                            :order 7)
;;                           (:name "Assignments"
;;                            :tag "Assignment"
;;                            :order 10)
;;                           (:name "Issues"
;;                            :tag "Issue"
;;                            :order 12)
;;                           (:name "Projects"
;;                            :tag "Project"
;;                            :order 14)
;;                           (:name "Emacs"
;;                            :tag "Emacs"
;;                            :order 13)
;;                           (:name "Research"
;;                            :tag "Research"
;;                            :order 15)
;;                           (:name "To read"
;;                            :tag "Read"
;;                            :order 30)
;;                           (:name "Waiting"
;;                            :todo "WAITING"
;;                            :order 20)
;;                           (:name "trivial"
;;                            :priority<= "C"
;;                            :tag ("Trivial" "Unimportant")
;;                            :todo ("SOMEDAY" )
;;                            :order 90)
;;                           (:discard (:tag ("Chore" "Routine" "Daily")))))))))
;;         ("W" "Weekly Review"
;;          ((agenda "" ((org-agenda-span 7)
;;                       (org-super-agenda-groups
;;                        '((:name "Completed"
;;                           :log closed
;;                           :order 1)))))
;;           alltodo "" ((org-agenda-overriding-header "")
;;                       (org-super-agenda-groups
;;                        '((:name "Process and Refile"
;;                           )
;;                          (:name "Add books to read"
;;                           )
;;                          (:name "Projects work for next week"
;;                           )
;;                          (:name "Process someday"
;;                           ))))))
;;         ("o" "Monthly Review")
;;         ("x" "On phone")
;;         ("b" "I am bored")))




;; (setq org-super-agenda-groups
;;       '((:name "Next Items"
;;          :time-grid t
;;          :tag ("NEXT" "outbox"))
;;         (:name "Important"
;;          :priority "A")
;;         (:name "Quick Picks"
;;          :effort< "0:30")
;;         (:priority<= "B"
;;          :scheduled future
;;          :order 1)))

;; I don't like what fancy priorities show.
;; Let's be more clear with the priorities
(after! org
  (setq org-highlight-latex-and-related '(native script entities)))


(use-package eaf
  :load-path "~/emacs-application-framework" ; Set to "/usr/share/emacs/site-lisp/eaf" if installed from AUR
  :defer 10
  :custom
  (eaf-find-alternate-file-in-dired t)
  :config
  (eaf-bind-key scroll_up "C-n" eaf-pdf-viewer-keybinding)
  (eaf-bind-key scroll_down "C-p" eaf-pdf-viewer-keybinding)
  (eaf-bind-key take_photo "p" eaf-camera-keybinding))

(use-package citeproc-org
  :after ox-hugo
  :config
  (citeproc-org-setup))

;;;###autoload
(defun kill-dired-buffers ()
  (interactive)
  (mapc (lambda (buffer)
          (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
            (kill-buffer buffer)))
        (buffer-list)))

;; (load! "~/.doom.d/exwm-doom.el")
(setq-default evil-escape-key-sequence "jk")
(setq evil-escape-delay 0.1)

;; (after! org
;;   (font-lock-add-keywords 'org-mode
;;                           '(("[^\\w]\\(:\\[^\n\r\t]+:\\)[^\\w]" 1 font-lock-warning-face prepend)) 'append)

;;   (defun my-html-mark-tag (text backend info)
;;     "Transcode :blah: into <mark>blah</mark> in body text."
;;     (when (org-export-derived-backend-p backend 'html)
;;       (let ((text (replace-regexp-in-string "[^\\w]\\(:\\)[^\n\t\r]+\\(:\\)[^\\w]" "<mark>"  text nil nil 1 nil)))
;;         (replace-regexp-in-string "[^\\w]\\(<mark>\\)[^\n\t\r]+\\(:\\)[^\\w]" "</mark>" text nil nil 2 nil))))

;;   (add-to-list 'org-export-filter-plain-text-functions 'my-html-mark-tag))
(setq bookmark-default-file "~/.doom.d/bookmarks")



(define-advice define-obsolete-function-alias (:filter-args (ll) fix-obsolete)
  (let ((obsolete-name (pop ll))
	(current-name (pop ll))
	(when (if ll (pop ll) "1"))
	(docstring (if ll (pop ll) nil)))
    (list obsolete-name current-name when docstring)))


(defun my/convert-task-to-org-note ()
  "Convert a task in a `org-roam' note."
  (interactive)
  (let* ((heading (org-get-heading t t t t))
         (body (org-get-entry))
         (link (format "[[id:%s][%s]]" (org-id-get-create) heading))
         (filepath (on/make-filepath heading (current-time))))
    (on/insert-org-roam-file
     filepath
     heading
     nil
     (list link)
     (format "* Note stored from tasks\n%s" body)
     nil)
    (find-file filepath)))

;; (setq! +helm-posframe-text-scale '-0.5)
;; (add-to-list 'load-path "~/.doom.d/doom-nano-testing")
;; (require 'load-nano)


(use-package! org-transclusion
  :commands (org-transclusion-mode)
  :hook ((org-load . org-transclusion-mode)))

(setq ispell-dictionary "en")

;; For having clear navigation with org-ql views
(setq org-super-agenda-header-map (make-sparse-keymap))

(defun window-split-toggle ()
  "Toggle between horizontal and vertical split with two windows."
  (interactive)
  (if (> (length (window-list)) 2)
      (error "Can't toggle with more than 2 windows!")
    (let ((func (if (window-full-height-p)
                    #'split-window-vertically
                  #'split-window-horizontally)))
      (delete-other-windows)
      (funcall func)
      (save-selected-window
        (other-window 1)
        (switch-to-buffer (other-buffer))))))
(setq +lookup-open-url-fn #'+lookup-xwidget-webkit-open-url-fn)
;; (setq +lookup-open-url-fn #'eww)

(add-hook 'magit-mode-hook (lambda () (magit-delta-mode +1)))


(use-package! aas
  :commands aas-mode)

(use-package! laas
  :hook (LaTeX-mode . laas-mode)
  :config
  (defun laas-tex-fold-maybe ()
    (unless (equal "/" aas-transient-snippet-key)
      (+latex-fold-last-macro-a)))
  (add-hook 'aas-post-snippet-expand-hook #'laas-tex-fold-maybe))

(use-package! org-pretty-table
  :commands (org-pretty-table-mode global-org-pretty-table-mode))

(use-package! org-pandoc-import :after org)


;; Org-plot with gnuplot
(after! org-plot
  (defun org-plot/generate-theme (_type)
    "Use the current Doom theme colours to generate a GnuPlot preamble."
    (format "
fgt = \"textcolor rgb '%s'\" # foreground text
fgat = \"textcolor rgb '%s'\" # foreground alt text
fgl = \"linecolor rgb '%s'\" # foreground line
fgal = \"linecolor rgb '%s'\" # foreground alt line

# foreground colors
set border lc rgb '%s'
# change text colors of  tics
set xtics @fgt
set ytics @fgt
# change text colors of labels
set title @fgt
set xlabel @fgt
set ylabel @fgt
# change a text color of key
set key @fgt

# line styles
set linetype 1 lw 2 lc rgb '%s' # red
set linetype 2 lw 2 lc rgb '%s' # blue
set linetype 3 lw 2 lc rgb '%s' # green
set linetype 4 lw 2 lc rgb '%s' # magenta
set linetype 5 lw 2 lc rgb '%s' # orange
set linetype 6 lw 2 lc rgb '%s' # yellow
set linetype 7 lw 2 lc rgb '%s' # teal
set linetype 8 lw 2 lc rgb '%s' # violet

# palette
set palette maxcolors 8
set palette defined ( 0 '%s',\
1 '%s',\
2 '%s',\
3 '%s',\
4 '%s',\
5 '%s',\
6 '%s',\
7 '%s' )
"
            (doom-color 'fg)
            (doom-color 'fg-alt)
            (doom-color 'fg)
            (doom-color 'fg-alt)
            (doom-color 'fg)
            ;; colours
            (doom-color 'red)
            (doom-color 'blue)
            (doom-color 'green)
            (doom-color 'magenta)
            (doom-color 'orange)
            (doom-color 'yellow)
            (doom-color 'teal)
            (doom-color 'violet)
            ;; duplicated
            (doom-color 'red)
            (doom-color 'blue)
            (doom-color 'green)
            (doom-color 'magenta)
            (doom-color 'orange)
            (doom-color 'yellow)
            (doom-color 'teal)
            (doom-color 'violet)
            ))
  (defun org-plot/gnuplot-term-properties (_type)
    (format "background rgb '%s' size 1050,650"
            (doom-color 'bg)))
  (setq org-plot/gnuplot-script-preamble #'org-plot/generate-theme)
  (setq org-plot/gnuplot-term-extra #'org-plot/gnuplot-term-properties))


;; TODO Acronyms let's see how that works with exports
(defun org-export-filter-text-acronym (text backend _info)
  "Wrap suspected acronyms in acronyms-specific formatting.
Treat sequences of 2+ capital letters (optionally succeeded by \"s\") as an acronym.
Ignore if preceeded by \";\" (for manual prevention) or \"\\\" (for LaTeX commands).

TODO abstract backend implementations."
  (let ((base-backend
         (cond
          ((org-export-derived-backend-p backend 'latex) 'latex)
          ;; Markdown is derived from HTML, but we don't want to format it
          ((org-export-derived-backend-p backend 'md) nil)
          ((org-export-derived-backend-p backend 'html) 'html)))
        (case-fold-search nil))
    (when base-backend
      (replace-regexp-in-string
       "[;\\\\]?\\b[A-Z][A-Z]+s?\\(?:[^A-Za-z]\\|\\b\\)"
       (lambda (all-caps-str)
         (cond ((equal (aref all-caps-str 0) ?\\) all-caps-str)                ; don't format LaTeX commands
               ((equal (aref all-caps-str 0) ?\;) (substring all-caps-str 1))  ; just remove not-acronym indicator char ";"
               (t (let* ((final-char (if (string-match-p "[^A-Za-z]" (substring all-caps-str -1 (length all-caps-str)))
                                         (substring all-caps-str -1 (length all-caps-str))
                                       nil)) ; needed to re-insert the [^A-Za-z] at the end
                         (trailing-s (equal (aref all-caps-str (- (length all-caps-str) (if final-char 2 1))) ?s))
                         (acr (if final-char
                                  (substring all-caps-str 0 (if trailing-s -2 -1))
                                (substring all-caps-str 0 (+ (if trailing-s -1 (length all-caps-str)))))))
                    (pcase base-backend
                      ('latex (concat "\\acr{" (s-downcase acr) "}" (when trailing-s "\\acrs{}") final-char))
                      ('html (concat "<span class='acr'>" acr "</span>" (when trailing-s "<small>s</small>") final-char)))))))
       text t t))))

(add-to-list 'org-export-filter-plain-text-functions
             #'org-export-filter-text-acronym)

(defun org-latex-substitute-verb-with-texttt (content)
  "Replace instances of \\verb with \\texttt{}."
  (replace-regexp-in-string
   "\\\\verb\\(.\\).+?\\1"
   (lambda (verb-string)
     (replace-regexp-in-string
      "\\\\" "\\\\\\\\" ; Why elisp, why?
      (org-latex--text-markup (substring verb-string 6 -1) 'code '(:latex-text-markup-alist ((code . protectedtexttt))))))
   content))



(defun org-html-format-headline-acronymised (todo todo-type priority text tags info)
  "Like `org-html-format-headline-default-function', but with acronym formatting."
  (org-html-format-headline-default-function
   todo todo-type priority (org-export-filter-text-acronym text 'html info) tags info))
(setq org-html-format-headline-function #'org-html-format-headline-acronymised)

(defun org-latex-format-headline-acronymised (todo todo-type priority text tags info)
  "Like `org-latex-format-headline-default-function', but with acronym formatting."
  (org-latex-format-headline-default-function
   todo todo-type priority (org-latex-substitute-verb-with-texttt
                            (org-export-filter-text-acronym text 'latex info)) tags info))
(setq org-latex-format-headline-function #'org-latex-format-headline-acronymised)

;; TODO org-hugo-use-code-for-kbd


;; Auto async onto packages
(add-transient-hook! #'org-babel-execute-src-block
  (require 'ob-async))

(defvar org-babel-auto-async-languages '()
  "Babel languages which should be executed asyncronously by default.")

(defadvice! org-babel-get-src-block-info-eager-async-a (orig-fn &optional light datum)
  "Eagarly add an :async parameter to the src information, unless it seems problematic.
This only acts o languages in `org-babel-auto-async-languages'.
Not added when either:
+ session is not \"none\"
+ :sync is set"
  :around #'org-babel-get-src-block-info
  (let ((result (funcall orig-fn light datum)))
    (when (and (string= "none" (cdr (assoc :session (caddr result))))
               (member (car result) org-babel-auto-async-languages)
               (not (assoc :async (caddr result))) ; don't duplicate
               (not (assoc :sync (caddr result))))
      (push '(:async) (caddr result)))
    result))

(use-package! graphviz-dot-mode
  :commands graphviz-dot-mode
  :mode ("\\.dot\\'" "\\.gz\\'")
  :init
  (after! org
    (setcdr (assoc "dot" org-src-lang-modes)
            'graphviz-dot)))

(use-package! company-graphviz-dot
  :after graphviz-dot-mode)

(add-hook! (gfm-mode markdown-mode) #'mixed-pitch-mode)
(add-hook! (gfm-mode markdown-mode) #'visual-line-mode #'turn-off-auto-fill)


;; TODO Use - and = key to do something that's most used such as buffer switching


;; Org capture fix
;; (defun +org--restart-mode-h ()
;;     "Restart `org-mode', but only once."
;;     (remove-hook 'doom-switch-buffer-hook #'+org--restart-mode-h
;;                  'local)
;;     (delq! (current-buffer) org-agenda-new-buffers)
;;     (let ((file buffer-file-name)
;;           (old-buffer (current-buffer))
;;           (inhibit-redisplay t)
;;           new-buffer)
;;       (kill-buffer)
;;       (setq new-buffer (find-file file))
;;       (unless (buffer-live-p old-buffer)
;;         (make-indirect-buffer new-buffer old-buffer 'clone))))


(setq lsp-julia-package-dir nil)
(setq lsp-julia-default-environment "~/.julia/environments/v1.6")
(setq lsp-enable-folding t)
;; (setq lsp-julia-flags `("-J/home/kai/.scripts/julia-lsp/languageserver.so"))
;; (setq lsp-enable-folding t)


(defun bms/consult-ripgrep-files-with-matches (&optional dir initial)
  "Use consult-find style to return matches with \"rg --file-with-matches \". No live preview."
  (interactive "P")
  (let ((consult-find-command "rg --ignore-case --type org --files-with-matches . -e ARG OPTS"))
    (consult-find dir initial)))

(defun bms/org-roam-rg-file-search ()
  "Search org-roam directory using consult-find with \"rg --file-with-matches \". No live preview."
  (interactive)
  (bms/consult-ripgrep-files-with-matches org-roam-directory))
(global-set-key (kbd "H-o") 'bms/org-roam-rg-file-search)
;; (setq lsp-signature-function 'lsp-signature-posframe)

(after! python
  (require 'dap-python))


;; Add properties to generic stuffs
(defun nm/org-clarify-properties ()
  "Clarify properties for task."
  (interactive)
  (let ((my-list nm/org-clarify-templates)
        (my-temp nil))
    (dolist (i my-list) (push (car i) my-temp))
    (dolist (i (cdr (assoc (ivy-completing-read "template: " my-temp) nm/org-clarify-templates))) (org-entry-put nil i (ivy-completing-read (format "%s: " i) (delete-dups (org-map-entries (org-entry-get nil i nil) nil 'file)))))))

(setq nm/org-clarify-templates '(("book" "AUTHOR" "YEAR" "SOURCE")
                                 ("online" "SOURCE" "SITE" "AUTHOR")
                                 ("purchase" "WHY" "FUNCTION")
                                 ("task" "AREA")
                                 ("project" "GOAL" "DUE")
                                 ("article" "SOURCE" "SITE" "SUBJECT")))

;;;###autoload
(defun nm/emacs-change-font ()
  "Change font based on available font list."
  (interactive)
  (let ((font (ivy-completing-read "font: " nm/font-family-list))
        (size (ivy-completing-read "size: " '("16" "18" "20" "22" "24" "26" "28" "30")))
        (weight (ivy-completing-read "weight: " '(normal light bold extra-light ultra-light semi-light extra-bold ultra-bold)))
        (width (ivy-completing-read "width: " '(normal condensed expanded ultra-condensed extra-condensed semi-condensed semi-expanded extra-expanded ultra-expanded))))
    (setq doom-font (font-spec :family font :size (string-to-number size) :weight (intern weight) :width (intern width))
          doom-big-font (font-spec :family font :size (+ 2 (string-to-number size)) :weight (intern weight) :width (intern width))))
  (doom/reload-font))

(setq nm/font-family-list '("Iosevka" "VictorMono Nerd Font Mono" "FiraCode Nerd Font" "Hack" "Input Mono" "Source Code Pro"  "DejaVu Sans Mono" "Liberation Mono"))

;; (defvar +fl/splashcii-query ""
;;   "The query to search on asciiur.com")

;; (defun +fl/splashcii ()
;;   (split-string (with-output-to-string
;;                   (call-process "splashcii" nil standard-output nil +fl/splashcii-query))
;;                 "\n" t))

;; (defun +fl/doom-banner ()
;;   (let ((point (point)))
;;     (mapc (lambda (line)
;;             (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
;;                                 'face 'doom-dashboard-banner) " ")
;;             (insert "\n"))
;;           (+fl/splashcii))
;;     (insert (make-string (or (cdr +doom-dashboard-banner-padding) 0) ?\n))))

;; ;; override the first doom dashboard function
;; (setcar (nthcdr 0 +doom-dashboard-functions) #'+fl/doom-banner)

;; (setq +fl/splashcii-query "space")

(after! smartparens
  (defun zz/goto-match-paren (arg)
    "Go to the matching paren/bracket, otherwise (or if ARG is not
    nil) insert %.  vi style of % jumping to matching brace."
    (interactive "p")
    (if (not (memq last-command '(set-mark
                                  cua-set-mark
                                  zz/goto-match-paren
                                  down-list
                                  up-list
                                  end-of-defun
                                  beginning-of-defun
                                  backward-sexp
                                  forward-sexp
                                  backward-up-list
                                  forward-paragraph
                                  backward-paragraph
                                  end-of-buffer
                                  beginning-of-buffer
                                  backward-word
                                  forward-word
                                  mwheel-scroll
                                  backward-word
                                  forward-word
                                  mouse-start-secondary
                                  mouse-yank-secondary
                                  mouse-secondary-save-then-kill
                                  move-end-of-line
                                  move-beginning-of-line
                                  backward-char
                                  forward-char
                                  scroll-up
                                  scroll-down
                                  scroll-left
                                  scroll-right
                                  mouse-set-point
                                  next-buffer
                                  previous-buffer
                                  previous-line
                                  next-line
                                  back-to-indentation
                                  doom/backward-to-bol-or-indent
                                  doom/forward-to-last-non-comment-or-eol
                                  )))
        (self-insert-command (or arg 1))
      (cond ((looking-at "\\s\(") (sp-forward-sexp) (backward-char 1))
            ((looking-at "\\s\)") (forward-char 1) (sp-backward-sexp))
            (t (self-insert-command (or arg 1))))))
  (map! "%" 'zz/goto-match-paren))
;; (use-package! org-roam
;;   :after org
;;   :commands
;;   (org-roam-buffer
;;    org-roam-setup
;;    org-roam-capture
;;    org-roam-node-find)
;;   :init
;;   (map! :after org
;;         :map org-mode-map
;;         :localleader
;;         :prefix ("m" . "org-roam")
;;         "b" #'org-roam-buffer-toggle
;;         "g" #'org-roam-graph
;;         "c" #'org-roam-capture
;;         (:prefix ("n" . "Node")
;;          :desc "Visit" "v" #'org-roam-node-visit
;;          :desc "Read" "r" #'org-roam-node-random
;;          :desc "Find" "f" #'org-roam-node-find
;;          :desc "Add"  "a" #'org-roam-node-insert)
;;         (:prefix ("R" . "reference")
;;          :desc "Remove" "R" #'org-roam-ref-remove
;;          :desc "Read" "r" #'org-roam-ref-read
;;          :desc "Find" "f" #'org-roam-ref-find
;;          :desc "Add"  "a" #'org-roam-ref-add)

;;         (:prefix ("t" . "Tag")
;;          :desc "Remove" "R" #'org-roam-dailies-find-previous-note
;;          :desc "Add"  "a" #'org-roam-dailies-find-next-note)

;;         (:prefix ("d" . "by date")
;;          :desc "Find previous note" "b" #'org-roam-dailies-find-previous-note
;;          :desc "Find date"          "d" #'org-roam-dailies-find-date
;;          :desc "Find next note"     "f" #'org-roam-dailies-find-next-note
;;          :desc "Find tomorrow"      "m" #'org-roam-dailies-find-tomorrow
;;          :desc "Capture today"      "n" #'org-roam-dailies-capture-today
;;          :desc "Find today"         "t" #'org-roam-dailies-find-today
;;          :desc "Capture Date"       "v" #'org-roam-dailies-capture-date
;;          :desc "Find yesterday"     "y" #'org-roam-dailies-find-yesterday
;;          :desc "Find directory"     "." #'org-roam-dailies-find-directory))
;;   :config
;;   (setq org-roam-mode-section-functions
;;        (list #'org-roam-backlinks-section
;;              #'org-roam-reflinks-section
;;              #'org-roam-unlinked-references-section))
;;   ()
;;   (org-roam-setup))

;; (defun my/org-id-update-org-roam-files ()
;;   "Update Org-ID locations for all Org-roam files."
;;   (interactive)
;;   (org-id-update-id-locations (org-roam--list-all-files)))

;; (defun my/org-id-update-id-current-file ()
;;   "Scan the current buffer for Org-ID locations and update them."
;;   (interactive)
;;   (org-id-update-id-locations (list (buffer-file-name (current-buffer)))))

(use-package! org-roam
  :init
  (map! :leader
        :prefix "z"
        :desc "org-roam" "l" #'org-roam-buffer-toggle
        :desc "org-roam-node-insert" "i" #'org-roam-node-insert
        :desc "org-roam-node-find" "f" #'org-roam-node-find
        :desc "org-roam-ref-find" "r" #'org-roam-ref-find
        :desc "org-roam-show-graph" "g" #'org-roam-show-graph
        :desc "org-roam-capture" "c" #'org-roam-capture
        :desc "org-roam-dailies-capture-today" "j" #'org-roam-dailies-capture-today)
  (setq org-roam-directory (file-truename "~/Dropbox/org/notes/")
        org-roam-db-gc-threshold most-positive-fixnum
        org-id-link-to-org-use-id t)
  (add-to-list 'display-buffer-alist
               '(("\\*org-roam\\*"
                  (display-buffer-in-direction)
                  (direction . right)
                  (window-width . 0.33)
                  (window-height . fit-window-to-buffer))))
  :config
  (setq org-roam-mode-sections
        (list #'org-roam-backlinks-insert-section
              #'org-roam-reflinks-insert-section
              #'org-roam-unlinked-references-insert-section
              ))
  (org-roam-setup))

(after! (org-roam)
  (winner-mode +1)
  (map! :map winner-mode-map
        "<M-right>" #'winner-redo
        "<M-left>" #'winner-undo))

;; Mail setup
;; (after! org
;;   (setq user-mail-address "sagar.r.alok@gmail.com"
;;         user-full-name "Alok Regmi"
;;         smtpmail-default-smtp-server "smtp.gmail.com"
;;         smtpmail-smtp-server "smtp.gmail.com"
;;         smtpmail-stream-type  'starttls
;;         smtpmail-smtp-service 587)
;;   (setq +mu4e-mu4e-mail-path)
;;   (setq mu4e-sent-folder "/personal/sent"
;;         mu4e-drafts-folder "/personal/drafts"
;;         mu4e-trash-folder "/personal/trash"
;;         mu4e-contexts
;;         `(
;;           ,(make-mu4e-context
;;             :name "Private"
;;             :enter-func (lambda () (mu4e-message "Entering Private context"))
;;             :leave-func (lambda () (mu4e-message "Leaving Private context"))
;;             :match-func (lambda (msg)
;;                           (when msg
;;                             (mu4e-message-contact-field-matches msg
;;                                                                 :to "sagar.r.alok@gmail.com")))
;;             :vars '(
;;                     (user-mail-address . "sagar.r.alok@gmail.com")
;;                     (user-full-name . "Alok Regmi" )
;;                     ;; (mu4e-sent-folder "/personal/sent")
;;                     ;; (mu4e-drafts-folder "/personal/drafts")
;;                     ;; (mu4e-trash-folder "/personal/trash")
;;                     ( mu4e-compose-signature .
;;                       (concat
;;                        "Alok Regmi\n"
;;                        "Kushma, Parbat\n"))))

;;           ,(make-mu4e-context
;;             :name "College"
;;             :enter-func (lambda () (mu4e-message "Entering College context"))
;;             :match-func (lambda (msg) (when msg (mu4e-message-contact-field-matches msg :to "072bex403.alok@pcampus.edu.np")))
;;             :vars '(
;;                     ( user-mail-address . "072bex403.alok@pcampus.edu.np"  )
;;                     ( user-full-name . "Alok Regmi" )
;;                     ( smtpmail-smtp-user "072bex403.alok@pcampus.edu.np" )
;;                     ;; (mu4e-sent-folder "/pulchowk/sent")
;;                     ;; (mu4e-drafts-folder "/pulchowk/drafts")
;;                     ;; (mu4e-trash-folder "/pulchowk/trash")
;;                     ( mu4e-compose-signature .
;;                       (concat
;;                        "Alok Regmi\n"
;;                        "Pulchowk Campus, Lalitpur, Nepal\n"))))
;;           )))


(set-email-account! "pcampus"
                    '((mu4e-sent-folder       . "/pcampus/Sent Mail")
                      (mu4e-drafts-folder     . "/pcampus/Drafts")
                      (mu4e-trash-folder      . "/pcampus/Trash")
                      (mu4e-refile-folder     . "/pcampus/All Mail")
                      (smtpmail-smtp-user     . "072bex403.alok@pcampus.edu.np")
                      (mu4e-compose-signature . "---\nAlok Regmi\n Pulchowk Campus, Lalitpur, Nepal"))
                    t)

(set-email-account! "personal"
                    '((mu4e-sent-folder       . "/personal/Sent Mail")
                      (mu4e-drafts-folder     . "/personal/Drafts")
                      (mu4e-trash-folder      . "/personal/Trash")
                      (mu4e-refile-folder     . "/personal/All Mail")
                      (smtpmail-smtp-user     . "sagar.r.alok@gmail.com")
                      (mu4e-compose-signature . "---\nAlok Regmi"))
                    t)
(add-to-list 'load-path "/usr/share/emacs/site-lisp/mu4e")

;;;###autoload
(defun sticky-agenda ()
  (progn
    (org-agenda "TODO" "k")))

;; Jupyter python to python for hugo text block syntax highlighting
(defun jupyter-python-to-only-python (text backend info)
  "Replace jupyter-python src blocks with python blocks."
  (replace-regexp-in-string "```jupyter-python" "```python" text))
(add-hook 'org-export-filter-src-block-functions #'jupyter-python-to-only-python)

;; (add-hook 'org-agenda-finalize-hook #'org-agenda-find-same-or-today-or-agenda 90)


(defun my-agenda-motto (&rest _ignore)
  " INSERTS MOTTO FROM MOTTO FILE TO AGENDA"
  (with-temp-buffer
    (insert-file-contents "~/Dropbox/org/journal/motto.org")
    (goto-char (point-max))
    (forward-line -1)
    (setq myLine (buffer-substring-no-properties
                  (line-beginning-position)
                  (line-end-position)))
    (setq myLine (concat "MOTTO: " (s-upcase (s-replace "\*" "" myLine)))))
  (dotimes (_ 160) (insert "="))
  (insert "\n")
  (dotimes (_ 40) (insert "="))
  (insert myLine)
  (dotimes (_ 40) (insert "="))
  (insert "\n")
  (dotimes (_ 160) (insert "="))
  (insert "\n")
  )

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (setq nov-save-place-file (concat doom-cache-dir "nov-places")))

;;;###autoload
(defun ruborcalor/org-pomodoro-time ()
  "Return the remaining pomodoro time"
  (if (org-pomodoro-active-p)
      (cl-case org-pomodoro-state
        (:pomodoro
         (format "Pomo: %d mins - %s" (/ (org-pomodoro-remaining-seconds) 60) org-clock-heading))
        (:short-break
         (format "SB %d minutes" (/ (org-pomodoro-remaining-seconds) 60)))
        (:long-break
         (format "LB %d mins" (/ (org-pomodoro-remaining-seconds) 60)))
        (:overtime
         (format "Overtime! %d minutes" (/ (org-pomodoro-remaining-seconds) 60))))
    "NO POMO"))

(after! org
  (require 'org-pomodoro)
  (setq org-pomodoro-length 45
        org-pomodoro-short-break-length 10
        org-pomodoro-long-break-length 15
        org-pomodoro-keep-killed-pomodoro-time t
        org-pomodoro-long-break-frequency 3
        org-pomodoro-play-sounds t
        org-pomodoro-ticking-sound-p t))

(defun ess-r-comment-box-line ()
  "Insert a comment box around the text of the current line of an R script.
If the current line indentation is 0, the comment box begins with ###.
Otherwise, it begins with ## and is indented accordingly."
  (interactive)
  (save-excursion
    (let ((beg (progn (back-to-indentation)
                      (point)))
          (end (line-end-position)))
      (comment-box beg end
                   (if (> (current-indentation) 0)
                       1
                     2)))))

;; A keybinding specific to ESS-R mode:
(add-hook 'ess-r-mode-hook
          #'(lambda ()
              (local-set-key (kbd "H-/") #'ess-r-comment-box-line)))

(use-package wallabag
  :defer t
  :config
  (setq wallabag-host "http://localhost:1702") ;; wallabag server host name
  (setq wallabag-username "wallabag") ;; username
  (setq wallabag-password "Kohostan?") ;; password
  (setq wallabag-clientid "3_bi4rte1agjwo4w80ws4c88wggkkks0wwgk4kwsk88oo8ocw4w") ;; created with API clients management
  (setq wallabag-secret "3s8ap50dd4kkc04cco84ckg400gw8ckg8os0cs8884cc4o0gok") ;; created with API clients management
  ;; (setq wallabag-db-file "~/OneDrive/Org/wallabag.sqlite") ;; optional, default is saved to ~/.emacs.d/.cache/wallabag.sqlite
  ;; (run-with-timer 0 3540 'wallabag-request-token) ;; optional, auto refresh token, token should refresh every hour
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Inkscape [ Works partially ]                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (after! org
;;   (require 'ink))

(defface vz/org-script-markers '((t :inherit shadow))
  "Face to be used for sub/superscripts markers i.e., ^, _, {, }.")

(defun vz/org-raise-scripts (limit)
  "Add raise properties to sub/superscripts but don't remove the
markers for sub/super scripts but fontify them."
  (when (and org-pretty-entities org-pretty-entities-include-sub-superscripts
             (re-search-forward
              (if (eq org-use-sub-superscripts t)
                  org-match-substring-regexp
                org-match-substring-with-braces-regexp)
              limit t))
    (let* ((pos (point)) table-p comment-p
           (mpos (match-beginning 3))
           (emph-p (get-text-property mpos 'org-emphasis))
           (link-p (get-text-property mpos 'mouse-face))
           (keyw-p (eq 'org-special-keyword (get-text-property mpos 'face))))
      (goto-char (point-at-bol))
      (setq table-p (looking-at-p org-table-dataline-regexp)
            comment-p (looking-at-p "^[ \t]*#[ +]"))
      (goto-char pos)
      ;; Handle a_b^c
      (when (member (char-after) '(?_ ?^)) (goto-char (1- pos)))
      (unless (or comment-p emph-p link-p keyw-p)
        (put-text-property (match-beginning 3) (match-end 0)
                           'display
                           (if (equal (char-after (match-beginning 2)) ?^)
                               (nth (if table-p 3 1) org-script-display)
                             (nth (if table-p 2 0) org-script-display)))
        (put-text-property (match-beginning 2) (match-end 2)
                           'face 'vz/org-script-markers)
        (when (and (eq (char-after (match-beginning 3)) ?{)
                   (eq (char-before (match-end 3)) ?}))
          (put-text-property (match-beginning 3) (1+ (match-beginning 3))
                             'face 'vz/org-script-markers)
          (put-text-property (1- (match-end 3)) (match-end 3)
                             'face 'vz/org-script-markers)))
      t)))

(add-hook 'org-mode-hook
          (lambda ()
            (vz/org-raise-scripts t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Dired Enter Key                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun dired-find-file-or-do-async-shell-command ()
  "If there is a default command defined for this file type, run it asynchronously.If not, open it in Emacs."
  (interactive)
  (let (
        ;; get the default for the file type,
        ;; putting the string into a list because dired-guess-default throws an error otherwise.
        (default (dired-guess-default (cons (dired-get-filename) '())))
        ;; put the file name into a list so dired-shell-stuff-it will accept it
        (file-list (cons (dired-get-filename) '())))
    (if (null default)
        ;; if no default found for file, open in Emacs
        (dired-find-file)
      ;; if default is found for file, run command asynchronously
      (dired-run-shell-command (dired-shell-stuff-it (concat default " &") file-list nil)))))
;; This function is bound to the Return key in dired-mode to replace the default behavior on Return
(define-key dired-mode-map (kbd "<H-return>") #'dired-find-file-or-do-async-shell-command)
;; For added convenience: Don't open a new Async Shell Command window
(add-to-list 'display-buffer-alist(cons "\\*Async Shell Command\\*.*" (cons #'display-buffer-no-window nil)))
;; Always open a new buffer if default is occupied.
;; (setq async-shell-command-buffer 'new-buffer)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        PDF keyboard
;;                                        highlight                                                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom pdf-links-convert-pointsize-scale 0.02
  "The scale factor for the -pointsize convert command.

This determines the relative size of the font, when interactively
reading links."
  :group 'pdf-links
  :type '(restricted-sexp :match-alternatives
                          ((lambda (x) (and (numberp x)
                                       (<= x 1)
                                       (>= x 0))))))

(defun pdf-links-read-char-action (query prompt)
  "Using PROMPT, interactively read a link-action.
BORROWED FROM `pdf-links-read-link-action'.
See `pdf-links-action-perform' for the interface."
  (pdf-util-assert-pdf-window)
  (let* ((links (pdf-info-search-string
                 query
                 (pdf-view-current-page)
                 (current-buffer)))
         (keys (pdf-links-read-link-action--create-keys
                (length links)))
         (key-strings (mapcar (apply-partially 'apply 'string)
                              keys))
         (alist (cl-mapcar 'cons keys links))
         (size (pdf-view-image-size))
         (colors (pdf-util-face-colors
                  'pdf-links-read-link pdf-view-dark-minor-mode))
         (args (list
                :foreground (car colors)
                :background "blue"
                :formats
                `((?c . ,(lambda (_edges) (pop key-strings)))
                  (?P . ,(number-to-string
                          (max 1 (* (cdr size)
                                    pdf-links-convert-pointsize-scale)))))
                :commands pdf-links-read-link-convert-commands
                :apply (pdf-util-scale-relative-to-pixel
                        (mapcar (lambda (l) (car (cdr (assq 'edges l))))
                                links)))))
    (print colors)

    (unless links
      (error "No links on this page"))
    (unwind-protect
        (let ((image-data nil))
          (unless image-data
            (setq image-data (apply 'pdf-util-convert-page args ))
            (pdf-cache-put-image
             (pdf-view-current-page)
             (car size) image-data 'pdf-links-read-link-action))
          (pdf-view-display-image
           (create-image image-data (pdf-view-image-type) t))
          (pdf-links-read-link-action--read-chars prompt alist))
      (pdf-view-redisplay))))

(defun avy-timed-input ()
  "BORROWED FORM `avy--read-candidates'"
  (let ((str "")
        char break)
    (while (and (not break)
                (setq char
                      (read-char (format "char%s (prefer multiple chars w.r.t. speed): "
                                         (if (string= str "")
                                             str
                                           (format " (%s)" str)))
                                 t
                                 (and (not (string= str ""))
                                      avy-timeout-seconds))))
      ;; Unhighlight
      (cond
       ;; Handle RET
       ((= char 13)
        (if avy-enter-times-out
            (setq break t)
          (setq str (concat str (list ?\n)))))
       ;; Handle C-h, DEL
       ((memq char avy-del-last-char-by)
        (let ((l (length str)))
          (when (>= l 1)
            (setq str (substring str 0 (1- l))))))
       ;; Handle ESC
       ((= char 27)
        (keyboard-quit))
       (t
        (setq str (concat str (list char))))))
    (print str)))

(defun get-coordinates (end)
  (let* ((query (avy-timed-input))
         (coords (list (or (pdf-links-read-char-action query "Please specify (SPC scrolls): ")
                           (error "No char selected")))))
    ;; (print coords)
    ;; (print (car (alist-get 'edges (car coords))))))
    (car (alist-get 'edges (car coords)))))

(defun pdf-keyboard-highlight ()
  (interactive)
  (let* ((start (get-coordinates nil))
         (end (get-coordinates t))
         (edges (append (cl-subseq start 0 2) (cl-subseq end 2 4))))
    (pdf-annot-add-markup-annotation
     edges 'highlight '"yellow") nil))

(map!
 :map pdf-view-mode-map
 :n "p" #'pdf-keyboard-highlight)

(defun org-roam-dailies-capture-this-week (n &optional goto)
  (interactive "p")
  (let ((year (string-to-number (format-time-string "%Y" (current-time))))
        (month (string-to-number (format-time-string "%m" (current-time))))
        (day (string-to-number (format-time-string "%d" (current-time)))))
    (org-roam-dailies--capture (time-add (* (org-day-of-week day month year) -86400) (current-time)) t)
    (goto-char (point-min))
    (when (not (search-forward "plan.txt" nil t))
      (goto-char (point-max))
      (insert "\n* Weekly Plan\n\n** Monday\n\n** Tuesday\n\n** Wednesday\n\n** Thursday\n\n** Friday\n\n** Saturday\n\n** Sunday"))))


;; Time related functions from holtzermann17
(defun now ()
  "Insert string for the current time formatted like '2:34 PM'."
  (interactive)
  (insert (format-time-string "%D %-I:%M %p")))
;; 04/29/21 3:08 pm

(defun today ()
  "Insert string for today's date nicely formatted in American style,
e.g. Sunday, September 17, 2000."
  (interactive)
  (insert (format-time-string "<%Y-%m-%d %a %e>")))
;; Thu, April 29, 2021
;; Thursday, April 29, 2021
;; <2021-04-29 Thu, April 29>

(defun date-string ()
  (interactive)
  (format-time-string  "<%Y-%m-%d %a %-H:%M>" nil t))

(defun date ()
  (interactive)
  (insert (date-string)))

(defun date-string ()
  (interactive)
  (format-time-string  "<%Y-%m-%d %a %-H:%M>" nil t))

(defun now-string ()
  (interactive)
  (format-time-string  "%Y-%m-%d %-H:%M|Z" nil t))

;; I don't want to easily close my agenda.
(map! :map org-agenda-mode-map
      "q" nil)
(setq org-id-link-to-org-use-id 'nil)


;; TODO Fix tab jump out mode

(setq yas-fallback-behavior '(apply tab-jump-out 1))
(setq tab-jump-out-mode t)

(require 'dired-aux)
(defvar dired-filelist-cmd
  '(("vlc" "-L")))
(defun dired-start-process (cmd &optional file-list)
  (interactive
   (let ((files (dired-get-marked-files
                 t current-prefix-arg)))
     (list
      (dired-read-shell-command "& on %s: "
                                current-prefix-arg files)
      files)))
  (let (list-switch)
    (start-process
     cmd nil shell-file-name
     shell-command-switch
     (format
      "nohup 1>/dev/null 2>/dev/null %s \"%s\""
      (if (and (> (length file-list) 1)
               (setq list-switch
                     (cadr (assoc cmd dired-filelist-cmd))))
          (format "%s %s" cmd list-switch)
        cmd)
      (mapconcat #'expand-file-name file-list "\" \"")))))
(define-key dired-mode-map "r" 'dired-start-process)
