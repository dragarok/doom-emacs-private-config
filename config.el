(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

(setq doom-font (font-spec :family "SpaceMono Nerd Font Mono" :size 17)
      doom-variable-pitch-font (font-spec :family "Overpass Mono" :size 17)
      ;; doom-variable-pitch-font (font-spec :family "Iosevka Etoile" :size 18)
      doom-serif-font (font-spec :family "Overpass Mono" :size 17)
      ;; doom-variable-pitch-font (font-spec :family "Source Serif Pro" :size 22)
      ;; doom-serif-font (font-spec :family "Source Serif Pro" :weight 'light)
      doom-big-font (font-spec :family "SpaceMono Nerd Font" :size 24))

(load-theme 'modus-operandi 'noconfirm)

(pixel-scroll-precision-mode)

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

;; ;; add to $DOOMDIR/config.el
;; (remove-hook 'org-mode-hook #'+literate-enable-recompile-h)

(setq org-directory "~/OneDrive/OrgMode/org/")
(setq elfeed-score-file "~/OneDrive/OrgMode/elfeed/elfeed-score.el")

(setq! citar-bibliography '((concat org-directory "references.bib")))
(setq! citar-notes-paths '(org-roam-directory))
(setq! citar-library-paths '(("~/OneDrive/OrgMode/Ref_Library/")))

(setq org-directory "~/OneDrive/OrgMode/org/")
(setq org-roam-directory "~/OneDrive/OrgMode/org/notes")
(setq org-agenda-directory "~/Dropbox/")
(setq org-agenda-files '(org-agenda-directory))
(setq org-inbox-file (concat org-agenda-directory "inbox.org"))
(setq org-recurring-file (concat org-agenda-directory "recurring.org"))
(setq org-bookslog-file (concat org-agenda-directory "books_log.org"))
(setq org-projects-file (concat org-agenda-directory "projects.org"))
(setq org-tasks-file (concat org-agenda-directory "tasks.org"))
(setq org-diary-file (concat org-directory "lookbacks/diary.org"))
(setq org-motto-file (concat org-agenda-directory "motto.org"))
(setq org-someday-file (concat org-directory "archive/someday.org"))

(setq rmh-elfeed-org-files (list "~/OneDrive/OrgMode/elfeed/elfeed.org"))

(setq bookmark-default-file "~/.doom.d/bookmarks")

(setq doom-scratch-buffer-major-mode t)
(setq show-trailing-whitespace t)

(setq display-line-numbers-type 'relative)

(setq org-support-shift-select t)

(setq doom-localleader-key ",")

(setq delete-by-moving-to-trash t)

(after! evil
  (setq +evil-want-o/O-to-continue-comments nil)
  (setq evil-ex-substitute-global t
        evil-move-cursor-back nil
        evil-kill-on-visual-paste nil))

(after! org
  (set-popup-rule! "*CAPTURE-*" :side 'left :size .30 :select t)
  ;; (set-popup-rule! "^CAPTURE-[A-Za-z]*\.org$" :side 'right :size .50 :select t :vslot 2 :ttl 3)
  ;; (set-popup-rule! "*helm*" :side 'bottom :height .40 :select t :vslot 5 :ttl 3)
  ;; (set-popup-rule! "^\\*Org Src" :side 'bottom :slot -2 :height 0.6 :width 0.5 :select t :autosave t :ttl nil :quit nil)
  (set-popup-rule! "*Org QL View:*" :side 'right :size .25 :select t)
  (set-popup-rule! "\\*RefTeX Select\\*" :size 80)
  (set-popup-rule! "*Org Select" :side 'bottom :size .50 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "*WordNut*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  ;; (set-popup-rule! "*Calendar*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "Dictionary" :side 'bottom :height .40 :width 20 :select t :vslot 3 :ttl 3)
  ;;(set-popup-rule! "*eww*" :side 'right :size .40 :slect t :vslot 5 :ttl 3)
  (set-popup-rule! "*deadgrep" :side 'bottom :height .40 :select t :vslot 4 :ttl 3)
  ;;  (set-popup-rule! "*org-roam" :side 'right :size .25 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "\\Swiper" :side 'bottom :size .30 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "*xwidget" :side 'right :size .40 :select t :vslot 5 :ttl 3)
  (set-popup-rule! "*eshell*" :side 'bottom :size .30 :select t :hslot 2 :ttl 3)
  (set-popup-rule! "*Org clock budget report*" :side 'bottom :size .40 :select t :hslot 2 :ttl 3)
  (set-popup-rule! "*Python:ob-ipython-py*" :side 'right :size .25 :select t)
  )

(use-package! ace-link
  :commands (ace-link))
(after! avy
  (setq avy-keys '(?a ?s ?d ?f ?j ?k ?l ?\;)))
(after! ace-window
  (setq aw-keys '(?f ?d ?s ?r ?e ?w)
        aw-scope 'frame
        aw-ignore-current t
        aw-background nil))

(after! dash-docs
  (setq counsel-dash-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))
  (setq dash-docs-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas")))

(add-hook 'dired-mode-hook
          (lambda ()
            (dired-hide-details-mode)))

;; Modified from https://wilkesley.org/~ian/xah/emacs/dired_sort.html
(defun light-dired-sort ()
  "Sort dired dir listing in different ways.
Prompt for a choice.
URL `http://ergoemacs.org/emacs/dired_sort.html'
Version 2015-07-30"
  (interactive)
  (let (-sort-by -hidden -arg)
    (setq -sort-by (completing-read "Sort by:" '( "Date" "Size" "Name" "Ext" "Dir" "Date Asc" "Name Desc" "Size Asc")))
    (setq -hidden (completing-read "Show Hidden Files:" '("Yes" "No")))
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

(custom-set-faces!
 '(vterm-color-black :foreground "OrangeRed3" :background "BlueViolet"))

;;;###autoload
(defun dired-mark-empty-dirs ()
  "Interactively mark all empty directories in current Dired buffer."
  (interactive)
  (when (equal major-mode 'dired-mode)
    (save-excursion
      (dired-goto-first)
      (while (not (eobp))
        (ignore-errors
          (when (directory-empty-p (dired-get-filename))
            (dired-mark 1)
            (dired-previous-line 1)))
        (dired-next-line 1)))))

;;;###autoload
(defun kill-dired-buffers ()
  (interactive)
  (mapc (lambda (buffer)
          (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
            (kill-buffer buffer)))
        (buffer-list)))

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
      "nohup 1>
/dev/null 2>/dev/null %s \"%s\""
      (if (and (> (length file-list) 1)
               (setq list-switch
                     (cadr (assoc cmd dired-filelist-cmd))))
          (format "%s %s" cmd list-switch)
        cmd)
      (mapconcat #'expand-file-name file-list "\" \"")))))
(define-key dired-mode-map "r" 'dired-start-process)

(defun dired-find-file-or-do-async-shell-command ()
  "If there is a default command defined for this file type,
 run it asynchronously.If not, open it in Emacs."
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
(define-key dired-mode-map (kbd "<C-return>") #'dired-find-file-or-do-async-shell-command)
;; For added convenience: Don't open a new Async Shell Command window
(add-to-list 'display-buffer-alist(cons "\\*Async Shell Command\\*.*" (cons #'display-buffer-no-window nil)))
;; Always open a new buffer if default is occupied.
;; (setq async-shell-command-buffer 'new-buffer)

;;;###autoload
(defun dired-send-kdeconnect ()
  "This function is used to mark and send file to kdeconnect device"
  (interactive)
  (let ((device-names (shell-command-to-string "kdeconnect-cli -a --id-name-only")))
    (if (equal device-names "0 devices found")
        (message "No devices found. Cannot send the file")
      (let ((device-to-send (consult--read
                             (delete "" (split-string device-names "\n"))
                             :prompt "Select device to send:  "
                             :history 'consult-kdeconnect-history
                             :require-match t
                             )))
        (let ((filenames (if (eq (dired-get-marked-files) nil)
                             ;; since filenames with spaces will have errors, enclose them with quotes
                             (mapconcat (lambda (x) (concat "\"" x "\"")) (dired-get-filename) " ")
                           (mapconcat (lambda (x) (concat "\"" x "\"")) (dired-get-marked-files) " "))))
          (message filenames)
          (shell-command (concat "kdeconnect-cli -d"
                                 (car (split-string device-to-send))
                                 " --share "
                                 filenames
                                 )
                         )
          )
        )
      )
    )
  )

(use-package! dirvish
  :config
  (map! :map dirvish-mode-map
        :n "y" #'dirvish-yank-menu
        :n "TAB" #'dirvish-subtree-toggle)
  (require 'dirvish-peek)
  (require 'dirvish-extras))

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

