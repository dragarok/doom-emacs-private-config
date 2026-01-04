;;; config.el --- Unified Doom Emacs config for Mac, Linux, and Android -*- lexical-binding: t; -*-

;; ============================================================
;; PLATFORM DETECTION
;; ============================================================
(defconst IS-ANDROID (eq system-type 'android)
  "Are we running on Android (Termux)?")

;; ============================================================
;; BASIC SETTINGS
;; ============================================================
(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

;; ============================================================
;; FONTS - Platform specific
;; ============================================================
(cond
 (IS-ANDROID
  (setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 26)
        doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :size 25)
        doom-variable-pitch-font (font-spec :family "SpaceMono Nerd Font" :size 36)
        doom-serif-font (font-spec :family "BlexMono Nerd Font" :size 36 :weight 'light)))
 (IS-MAC
  (setq doom-font (font-spec :family "mononoki" :size 15)
        doom-variable-pitch-font (font-spec :family "Iosevka Nerd Font" :size 15)
        doom-serif-font (font-spec :family "Iosevka Nerd Font" :size 15)
        doom-big-font (font-spec :family "mononoki" :size 22)))
 (IS-LINUX
  (setq doom-font (font-spec :family "Maple Mono SC NF" :size 19)
        doom-variable-pitch-font (font-spec :family "RobotoMono Nerd Font" :size 19)
        doom-serif-font (font-spec :family "RobotoMono Nerd Font" :size 19)
        doom-big-font (font-spec :family "Maple Mono SC NF" :size 25))))

;;;###autoload
(defun my/apply-theme (appearance)
  "Load theme and set `doom-theme` based on system APPEARANCE."
  (mapc #'disable-theme custom-enabled-themes)
  (pcase appearance
    ('light
     (setq doom-theme 'doom-gruvbox-light)
     (load-theme 'doom-gruvbox-light t))
    ('dark
     (setq doom-theme 'doom-pine)
     (load-theme 'doom-pine t))))

;; Theme - Platform specific
(cond
 (IS-ANDROID
  (setq doom-theme 'doom-acario-light))
 (IS-MAC
  (add-hook 'ns-system-appearance-change-functions #'my/apply-theme)
  (setq doom-theme 'doom-gruvbox-light))
 (t
  (setq doom-theme 'doom-gruvbox-light)))

(pixel-scroll-precision-mode)

;; ============================================================
;; ANDROID-SPECIFIC UI SETTINGS
;; ============================================================
(when IS-ANDROID
  (setq +zen-mixed-pitch-modes nil)
  (setq touch-screen-precision-scroll t)
  (setq overriding-text-conversion-style nil)
  (setq tool-bar-position 'bottom)
  (tool-bar-mode 1)
  (modifier-bar-mode 1)

  ;; Load org early on Android
  (require 'org)

  ;; Android org-mode settings
  (setq org-startup-folded 'showeverything)
  (setq browse-url-browser-function 'browse-url-xdg-open)
  (add-to-list 'org-file-apps '("\\.pdf\\'" . "termux-open %s"))
  (add-to-list 'org-file-apps '("\\.png\\'" . "termux-open %s"))
  (add-to-list 'org-file-apps '("\\.jpg\\'" . "termux-open %s"))
  (add-to-list 'org-file-apps '("\\.jpeg\\'" . "termux-open %s"))

  ;; Load Android-specific modules (from lisp/)
  (require 'android-extras))       ; keyboard control, dired xdg-open, vterm shell

;; Image workflow - works on both Mac and Android with platform-specific paths
(require 'image-workflow)

(define-key input-decode-map [?\C-i] [C-i])

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

;; ============================================================
;; PATHS - Platform specific
;; ============================================================
(if IS-ANDROID
    (progn
      (setq nextcloud-dir (expand-file-name "/sdcard/"))
      (setq project-resources-dir (concat nextcloud-dir "workspace/"))
      (setq org-directory (expand-file-name "/sdcard/org/"))
      (setq! citar-bibliography '("/sdcard/org/references/articles.bib"))
      (setq! citar-library-paths '("/sdcard/Books/Papers/articles/"))
      (setq org-roam-directory "/sdcard/org/notes/")
      (setq org-agenda-files '("/sdcard/org/agenda/")))
  (progn
    (setq nextcloud-dir (expand-file-name "~/Nextcloud/"))
    (setq project-resources-dir (concat nextcloud-dir "projects/"))
    (setq org-directory (expand-file-name "~/Nextcloud/org/"))
    (setq! citar-bibliography '("~/Nextcloud/org/references/articles.bib"))
    (setq! citar-library-paths '("~/Books/Papers/articles/"))
    (setq org-roam-directory "~/Nextcloud/org/notes/")
    (setq org-agenda-files '("~/Nextcloud/org/agenda/"))))

(setq! citar-notes-paths '(org-roam-directory))

;; Common derived paths (work on both platforms)
(setq org-logs-directory (concat org-directory "logs/"))
(setq org-agenda-directory (concat org-directory "agenda/"))
(setq org-templates-directory (concat org-directory "templates/"))
(setq org-lookbacks-directory (concat org-directory "lookbacks/"))
(setq org-inbox-file (concat org-agenda-directory "inbox.org"))
(setq org-bookslog-file (concat org-agenda-directory "log_books.org"))
(setq org-books-file org-bookslog-file)
(setq org-recurring-file (concat org-agenda-directory "recurring.org"))
(setq org-projects-file (concat org-agenda-directory "projects.org"))
(setq org-tasks-file (concat org-agenda-directory "tasks.org"))
(setq org-diary-file (concat org-directory "lookbacks/diary.org"))
(setq org-motto-file (concat org-agenda-directory "motto.org"))
(setq org-someday-file (concat org-directory "archive/someday.org"))
(setq org-dailyreview-file (concat org-lookbacks-directory "dailyreview.org"))
(setq org-monthlyreview-file (concat org-lookbacks-directory "monthlyreview.org"))
(setq org-weeklyreview-file (concat org-lookbacks-directory "weeklyreview.org"))
(setq org-quarterlyreview-file (concat org-lookbacks-directory "quarterlyreview.org"))
(setq org-yearlyreview-file (concat org-lookbacks-directory "yearlyreview.org"))
(setq org-roam-logs-file (concat org-logs-directory "notes_log.txt"))

(setq show-trailing-whitespace t)
;; (setq frame-title-format '("Kaimacs - %b\n\n"))

(setq display-line-numbers-type 'relative)

(setq org-support-shift-select t)

(setq doom-localleader-key ",")

(setq delete-by-moving-to-trash t)

(after! evil
  (setq +evil-want-o/O-to-continue-comments nil)
  (setq evil-ex-substitute-global t
        evil-move-cursor-back nil
        evil-kill-on-visual-paste nil))
(after! evil-snipe (evil-snipe-mode -1))
(map! :nv "s" #'evil-avy-goto-char-2)

(setq calendar-week-start-day 1) ; 0:Sunday, 1:Monday

(after! persp-mode
  (setq! persp-emacsclient-init-frame-behaviour-override "main")
  (setq persp-add-buffer-on-after-change-major-mode t)
  )

(setq doom-scratch-initial-major-mode 'org-mode)

(setq bookmark-default-file "/Users/alokregmi/.doom.d/bookmarks")

;; (after! org
;;   (set-popup-rule! "*CAPTURE-*" :side 'left :size .30 :select t)
;;   ;; (set-popup-rule! "^CAPTURE-[A-Za-z]*\.org$" :side 'right :size .50 :select t :vslot 2 :ttl 3)
;;   ;; (set-popup-rule! "*helm*" :side 'bottom :height .40 :select t :vslot 5 :ttl 3)
;;   ;; (set-popup-rule! "^\\*Org Src" :side 'bottom :slot -2 :height 0.6 :width 0.5 :select t :autosave t :ttl nil :quit nil)
;;   (set-popup-rule! "*Org QL View:*" :side 'right :size .25 :select t)
;;   (set-popup-rule! "\\*RefTeX Select\\*" :size 80)
;;   (set-popup-rule! "*Org Select" :side 'bottom :size .50 :select t :vslot 2 :ttl 3)
;;   (set-popup-rule! "*WordNut*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
;;   ;; (set-popup-rule! "*Calendar*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
;;   (set-popup-rule! "Dictionary" :side 'bottom :height .40 :width 20 :select t :vslot 3 :ttl 3)
;;   ;;(set-popup-rule! "*eww*" :side 'right :size .40 :slect t :vslot 5 :ttl 3)
;;   (set-popup-rule! "*deadgrep" :side 'bottom :height .40 :select t :vslot 4 :ttl 3)
;;   ;;  (set-popup-rule! "*org-roam" :side 'right :size .25 :select t :vslot 4 :ttl 3)
;;   (set-popup-rule! "\\Swiper" :side 'bottom :size .30 :select t :vslot 4 :ttl 3)
;;   (set-popup-rule! "*xwidget" :side 'right :size .40 :select t :vslot 5 :ttl 3)
;;   (set-popup-rule! "*eshell*" :side 'bottom :size .30 :select t :hslot 2 :ttl 3)
;;   (set-popup-rule! "*Org clock budget report*" :side 'bottom :size .40 :select t :hslot 2 :ttl 3)
;;   (set-popup-rule! "*Python:ob-ipython-py*" :side 'right :size .25 :select t)
;;   )
(after! popup
  (set-popup-rule! "^\\*Python*" :side 'bottom :height 0.3 :quit nil)
  (set-popup-rule! "*WordNut*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "*Org QL View:*" :side 'right :size 0.3 :select t :quit nil)
  )

(after! dash-docs
  (setq counsel-dash-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))
  (setq dash-docs-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas")))

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

(setq doom-projectile-cache-blacklist '("~" "/tmp" "/" "/Users/alokregmi/"))
(setq projectile-ignored-projects '("Users/alokregmi" "~/" "/tmp" "~/.emacs.d/.local/straight/repos/"))
(defun projectile-ignored-project-function (filepath)
  "Return t if FILEPATH is within any of `projectile-ignored-projects'"
  (or (mapcar (lambda (p) (s-starts-with-p p filepath)) projectile-ignored-projects)))

(after! projectile
  (add-to-list 'projectile-globally-ignored-directories "*.stversions"))

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

(use-package! vlf-setup
  :defer-incrementally vlf-tune vlf-base vlf-write vlf-search vlf-occur vlf-follow vlf-ediff vlf)

(setq writeroom-extra-line-spacing 0.3
      writeroom-width 100)

;; (add-hook 'writeroom-mode-hook #'mixed-pitch-mode)

(defun +my/vterm-run-project ()
  (interactive)
  (+evil-window-vsplit-a)
  (+evil-window-split-a)
  (call-interactively '+vterm/toggle))

(require 'nepali-romanized)

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

(use-package blamer
  :bind (("s-i" . blamer-show-commit-info))
  :defer 20
  :custom
  (blamer-idle-time 0.3)
  (configblamer-min-offset 70)
  :custom-face
  (blamer-face ((t :foreground "#7a88cf"
                   :background nil
                   :height 140
                   :italic t)))
  )

(after! org
  (require 'org-books)
  (setq org-books-file-depth 1)
  (setq org-books-genre-tag-associations '(("Fiction" . "Fiction")
                                           ("Nonfiction" . "Nonfiction")
                                           ("Science Fiction" . "Scifi")
                                           ("Classics" . "Classics")
                                           ("Poetry" . "Poetry")
                                           ("Drama" . "Drama")
                                           ("Comedy" . "Comedy")
                                           ("Action" . "Action")
                                           ("Adventure" . "Adventure")
                                           ("Computer Science" . "ComputerScience")
                                           ("Engineering" . "Engineering")
                                           ("Fantasy" . "Fantasy")
                                           ("Mystery" . "Mystery")
                                           ("Thriller" . "Thriller")
                                           ("Design" . "Design")
                                           ("Business" . "Business")
                                           ("Productivity" . "Productivity")
                                           ("Adult" . "Adult")
                                           ("Horror" . "Horror")
                                           ("Romance" . "Romance")
                                           ("Historical" . "Historical")
                                           ("Reference" . "Reference")
                                           ("Writing" . "Writing")
                                           ("Biography" . "Biography")
                                           ("Autobiography" . "Autobiography")
                                           ("Memoir" . "Memoir")
                                           ("History" . "History")
                                           ("Science" . "Science")
                                           ("Self Help" . "SelfHelp")
                                           ("Business" . "Business")
                                           ("Psychology" . "Psychology")
                                           ("Philosophy" . "Philosophy")
                                           ("Religion" . "Religion")
                                           ("Politics" . "Politics")
                                           ("Economics" . "Economics")
                                           ("Art" . "Art")
                                           ("Music" . "Music")
                                           ("Cooking" . "Cooking")
                                           ("Travel" . "Travel")
                                           ("Humor" . "Humor")
                                           ("Poetry" . "Poetry")
                                           ("Short Stories" . "ShortStories")
                                           ("Comics" . "Comics")
                                           ("Graphic Novels" . "GraphicNovels")
                                           ("Children's" . "Children")
                                           ("Young Adult" . "YoungAdult")
                                           ("Other" . "Other"))))

(after! org
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
        org-noter-notes-search-path '(org-roam-directory)
        org-noter-separate-notes-from-heading t
        ;; org-noter-auto-save-last-location t
        )
  ;; fuxialexander's code
  ;; (add-hook! org-noter-notes-mode (require 'org-noter-pdftools))
  )

(use-package org-noter-pdftools
  :after org-noter
  :config
  (with-eval-after-load 'pdf-annot
    (add-hook 'pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note)))

(after! dap-mode
  (setq dap-python-debugger 'debugpy)
  (setq dap-python-terminal "vterm")
  (setq dap-auto-configure-features '(sessions locals expressions repl tooltip))
  (dap-register-debug-template
   "Python :: Run with workspace folder to pythonpath"
   (list :type "python"
         :args ""
         :cwd "${workspaceFolder}"
         :module nil
         :program nil
         :request "launch"
         :env (list :PYTHONPATH "${workspaceFolder}")))
  (setq dap-ui-buffer-configurations
        `((,dap-ui--locals-buffer . ((side . left) (slot . 1) (window-height . 0.7)))
          (,dap-ui--expressions-buffer . ((side . left) (slot . 2) (window-height . 0.3)))
          (,dap-ui--breakpoints-buffer . ((side . left) (slot . 3) (window-height . 0.20)))
          (,dap-ui--sessions-buffer . ((side . left) (slot . 4) (window-height . 0.05)))
          (,dap-ui--debug-window-buffer . ((side . bottom) (slot . 1) (window-width . 0.5)))
          (,dap-ui--repl-buffer . ((side . bottom) (slot . 2) (window-height . 0.5)(window-width . 0.5))))))

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
        "C-s-<return>" 'ein:worksheet-execute-cell-and-goto-next-km
        "C-s-<tab>" 'ein:worksheet-execute-cell-km
        "C-s-o" 'ein:worksheet-insert-cell-below-km
        "C-s-O" 'ein:worksheet-insert-cell-above-km
        "C-s-c" 'ein:worksheet-change-cell-type-km
        "C-s-b" 'ein:worksheet-split-cell-at-point-km
        "C-s-k" 'ein:worksheet-move-cell-up-km
        "C-s-j" 'ein:worksheet-move-cell-down-km
        "C-s-k" 'ein:worksheet-merge-cell-km
        "C-s-j" 'spacemacs/ein:worksheet-merge-cell-next
        "C-s-y" 'ein:worksheet-copy-cell-km
        "C-s-t" 'ein:worksheet-toggle-output-km
        "C-s-p" 'ein:worksheet-yank-cell-km
        "C-s-d" 'ein:worksheet-kill-cell-km
        "C-s-m" 'ein:notebook-scratchsheet-open-km
        ;; Output
        "C-s-z" 'ein:worksheet-toggle-output-km
        "C-s-x" 'ein:worksheet-clear-output-km
        "C-s-;" 'ein:worksheet-clear-all-output-km
        ;; Notebook Opening and closing
        "C-s-s" 'ein:notebook-save-notebook-command-km
        "C-s-r" 'ein:notebook-rename-command-km
        "C-s-q" 'ein:notebook-close-km
        "C-S-s-<return>" 'ein:worksheet-execute-cell-and-goto-next-km
        "C-S-s-<tab>" 'ein:worksheet-execute-cell-km
        "C-S-s-o" 'ein:worksheet-insert-cell-below-km
        "C-S-s-O" 'ein:worksheet-insert-cell-above-km
        "C-S-s-c" 'ein:worksheet-change-cell-type-km
        "C-S-s-b" 'ein:worksheet-split-cell-at-point-km
        "C-S-s-k" 'ein:worksheet-move-cell-up-km
        "C-S-s-j" 'ein:worksheet-move-cell-down-km
        "C-S-s-k" 'ein:worksheet-merge-cell-km
        "C-S-s-j" 'spacemacs/ein:worksheet-merge-cell-next
        "C-S-s-y" 'ein:worksheet-copy-cell-km
        "C-S-s-t" 'ein:worksheet-toggle-output-km
        "C-S-s-p" 'ein:worksheet-yank-cell-km
        "C-S-s-d" 'ein:worksheet-kill-cell-km
        "C-S-s-m" 'ein:notebook-scratchsheet-open-km
        ;; Output
        "C-S-s-z" 'ein:worksheet-toggle-output-km
        "C-S-s-x" 'ein:worksheet-clear-output-km
        "C-S-s-;" 'ein:worksheet-clear-all-output-km
        ;; Notebook Opening and closing
        "C-S-s-s" 'ein:notebook-save-notebook-command-km
        "C-S-s-r" 'ein:notebook-rename-command-km
        "C-S-s-q" 'ein:notebook-close-km
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

  ;;(add-hook 'ein:notebook-mode-hook #'virtual-auto-fill-mode)
  ;;(add-hook 'ein:markdown-mode-hook #'virtual-auto-fill-mode)
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

(add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode)

(after! python
  (map! :localleader
        :map python-mode-map
        :nvm "r" #'+python/open-repl
        :nvm "R" #'+python/open-ipython-repl
        :vm "X" #'python-shell-send-region
        :n "x" #'python-shell-send-defun
        :n "X" #'python-shell-send-buffer
        :n "z" #'python-shell-send-statement
        :n "F" #'python-shell-send-file
        :nvm "h" #'scimax-python-mode/body
        :nvm "/" #'hydra-posframe-mode
        :nvm "D" #'dap-debug)
  )

(setq lsp-pyright-multi-root nil)

(use-package numpydoc
  :ensure t
  :bind (:map python-mode-map
              ("C-c C-n" . numpydoc-generate))
  :config
  (setq! numpydoc-insertion-style 'yas))

(after! org
  (setq org-highlight-latex-and-related '(native script entities)))

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
        org-fontify-quote-and-verse-blocks t
        org-auto-align-tags 'nil
        org-tags-column 0
        org-fold-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t
        org-pretty-entities t
        org-insert-heading-respect-content t
        org-priority-default 69
        org-priority-highest 65
        org-priority-lowest 70
        ;; org-habit-show-habits nil
        ;; +org-habit-min-width 180
        )

  ;; (global-org-modern-mode)
  )

(after! org
  (setq org-format-latex-options
        (plist-put org-format-latex-options
                   :scale 1.1)
        ;; org-startup-with-latex-preview nil
        ;; (+org-init-custom-links-h)
        )
  )

(use-package! orgmdb
  :after org
  :config
  (setq orgmdb-omdb-apikey "")
  )

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

(defun sanityinc/split-window()
  "Split the window to see the most recent buffer in the other window.
Call a second time to restore the original window configuration."
  (interactive)
  (if (eq last-command 'sanityinc/split-window)
      (progn
        (jump-to-register :sanityinc/split-window)
        (setq this-command 'sanityinc/unsplit-window))
    (window-configuration-to-register :sanityinc/split-window)
    (switch-to-buffer-other-window nil)))

(global-set-key (kbd "<f7>") 'sanityinc/split-window)

(when (eq system-type 'windows-nt)
  (defun me/bash ()
    (interactive)
    (let ((explicit-shell-file-name "C:/Windows/System32/bash.exe"))
      (shell))))

(defvar chrome-bookmarks-file
  (cl-find-if
   #'file-exists-p
   ;; Base on `helm-chrome-file'
   (list
    "~/Library/Application Support/Google/Chrome/Profile 1/Bookmarks"
    "~/Library/Application Support/Google/Chrome/Default/Bookmarks"
    "~/AppData/Local/Google/Chrome/User Data/Default/Bookmarks"
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

(custom-set-faces!
  '(vterm-color-black :foreground "OrangeRed3" :background "BlueViolet"))

(after! org
  (setq org-format-latex-options
        (plist-put org-format-latex-options
                   :scale 1.1)
        ;; org-startup-with-latex-preview nil
        ;; (+org-init-custom-links-h)
        )
  )

(use-package! yasnippet
  :config
  ;; It will test whether it can expand, if yes, change cursor color
  (defun hp/change-cursor-color-if-yasnippet-can-fire (&optional field)
    (interactive)
    (setq yas--condition-cache-timestamp (current-time))
    (let (templates-and-pos)
      (unless (and yas-expand-only-for-last-commands
                   (not (member last-command yas-expand-only-for-last-commands)))
        (setq templates-and-pos (if field
                                    (save-restriction
                                      (narrow-to-region (yas--field-start field)
                                                        (yas--field-end field))
                                      (yas--templates-for-key-at-point))
                                  (yas--templates-for-key-at-point))))
      (set-cursor-color (if (and templates-and-pos (first templates-and-pos)
                                 (eq evil-state 'insert))
                            (doom-color 'red)
                          (face-attribute 'default :foreground)))))
  :hook (post-command . hp/change-cursor-color-if-yasnippet-can-fire))
;; For adding code snippets in yasnippet
(add-to-list 'warning-suppress-types '(yasnippet backquote-change))

(add-hook! (gfm-mode markdown-mode) #'mixed-pitch-mode)
(add-hook! (gfm-mode markdown-mode) #'visual-line-mode #'turn-off-auto-fill)

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
 :n "p" #'pdf-keyboard-highlight
 :n "B" #'pdf-view-reset-slice)

;;;###autoload
(defun +vertico/switch-workspace-buffer-other-window()
  (interactive)
  (+evil-window-vsplit-a)
  (+vertico/switch-workspace-buffer))

(defun consult-recent-file ()
  "Find recent using `completing-read'."
  (interactive)
  (find-file
   (consult--read
    (or (message (mapcar #'abbreviate-file-name recentf-list))
        (user-error "No recent files, `recentf-mode' is %s"
                    (if recentf-mode "on" "off")))
    :prompt "Find recent file: "
    :sort nil
    :require-match t
    :category 'file
    :state (consult--file-preview)
    :history 'file-name-history)))

(add-hook 'yaml-mode-hook
          (lambda ()
            (define-key yaml-mode-map "\C-m" 'newline-and-indent)))

(use-package! org-pandoc-import :after org)

(add-hook 'magit-mode-hook (lambda () (magit-delta-mode +1)))

(defun my-magit/delete-merged-branches ()
  (interactive)
  (magit-fetch-all-prune)
  (let* ((default-branch
          (read-string "Default branch: " (magit-get-current-branch)))
         (merged-branches
          (magit-git-lines "branch"
                           "--format" "%(refname:short)"
                           "--merged"
                           default-branch))
         (branches-to-delete
          (remove default-branch merged-branches)))
    (if branches-to-delete
        (if (yes-or-no-p (concat "Delete branches? ["
                                 (mapconcat 'identity branches-to-delete ", ") "]"))
            (magit-branch-delete branches-to-delete))
      (message "Nothing to delete"))))

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

(setq ispell-dictionary "en")

(after! org
  (setq org-hugo-base-dir "~/workspace/personal/personalblog/"))

;; (setq my-book-genres '("Fantasy" "Science Fiction" "Mystery" "Thriller"
;;                        "Romance" "Historical" "Non-Fiction" "Biography"
;;                        "Self-Help" "Children's" "Young Adult"))

;; Assuming `org-books-genre-tag-associations` is defined as you provided

(defun set-book-genres ()
  "Set book genre tags on the current Org-mode heading."
  (interactive)
  ;; Ensure we are in an Org buffer
  (unless (derived-mode-p 'org-mode)
    (error "Not in an Org-mode buffer"))

  ;; Extract just the keys (genres) from the association list
  (let* ((genre-keys (mapcar 'car org-books-genre-tag-associations))
         (selected-genres (completing-read-multiple
                           "Select genres (use comma to separate): "
                           genre-keys nil t))
         ;; Look up the full tag for each selected genre
         (full-tags (mapcar (lambda (genre)
                              (cdr (assoc genre org-books-genre-tag-associations)))
                            selected-genres))
         ;; Join the full tags with colons, as required by `org-set-tags'
         (genres-str (mapconcat 'identity full-tags ":")))

    ;; Set the genres as tags on the current heading
    (org-set-tags genres-str)))

(after! dired
  (setq diff-hl-dired-ignored-backends (append
                                        '((Git) (RCS)))))
(after! diff-hl
  (remove-hook 'dired-mode-hook #'+vc-gutter-enable-maybe-h))

;;;###autoload
(defun create-new-ml-project (proj-name proj-type)
  "Initial setup for any ML project"
  (interactive "sEnter the project full path:
sEnter type of project: ")
  (+workspace/new)
  (if (equal proj-type "p")
      (setq full-proj (cl-concatenate 'string "~/workspace/personal/" proj-name ))
    (setq full-proj (cl-concatenate 'string "~/workspace/work/" proj-name)))
  ;; (message "%s" full-proj)
  (dired-create-directory full-proj)
  (dired-create-directory (cl-concatenate 'string full-proj "/src"))
  (dired-create-directory (cl-concatenate 'string full-proj "/input"))
  (dired-create-directory (cl-concatenate 'string full-proj "/models"))
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

;;;###autoload
(defun run-django-project()
  "Run a django project with commands
from .dir-locals.el"
  (interactive)
  ;; (message dir-local-variables-alist)
  (setq django-commands (eval (cdr (assoc 'django-commands dir-local-variables-alist))))
  (call-interactively '+vterm/here) ()
  (dolist (command django-commands)
    (vterm-send-string command)
    (vterm-send-return))
  )

;; Time related functions from holtzermann17
(defun now ()
  "Insert string for the current time formatted like '2:34 PM'."
  (interactive)
  (insert (format-time-string "[%D %-I:%M %p]")))
;; 04/29/21 3:08 pm

(defun today ()
  "Insert string for today's date nicely formatted in American style,
e.g. Sunday, September 17, 2000."
  (interactive)
  (insert (format-time-string "[%Y-%m-%d %a]")))
;; Thu, April 29, 2021
;; Thursday, April 29, 2021
;; <2021-04-29 Thu, April 29>

(defun date ()
  (interactive)
  (insert (date-string)))

(defun date-string ()
  (interactive)
  (format-time-string  "[%Y-%m-%d %a %-H:%M]" nil t))

(defun now-string ()
  (interactive)
  (format-time-string  "[%Y-%m-%d %-H:%M|Z]" nil t))

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

;;;###autoload
(defun my/create-id-and-copy-link()
  "Creates id for the given heading at point and returns the org link"
  (org-id-get-create)
  (kill-new (concat "[[id:" (org-id-get) "]" "["
                    ;; get 2 min taskname if it's there
                    (let ((props (org-entry-properties)))
                      (if (cdr (assoc "2_MIN_TNAME" props))
                          (cdr (assoc "2_MIN_TNAME" props))
                        (cdr (assoc "ITEM" props))))
                    "]]"))
  (save-buffer))

;;;###autoload
(defun my/copy-heading-link()
  "Copies heading link from org mode to be pasted anywhere else in org mode"
  (interactive)
  (if (equal (buffer-name) "*Org Agenda*")
      (let* ((marker (org-get-at-bol 'org-marker))
             (buffer (marker-buffer marker))
             (pos (marker-position marker)))
        (org-with-remote-undo buffer
          (with-current-buffer buffer
            (goto-char pos)
            (my/create-id-and-copy-link))))
    (my/create-id-and-copy-link)
    )
  )

;;;###autoload
(defun my/clock-in-and-back()
  "Enter on the link at point, clock in, and come back here."
  (interactive)
  (save-excursion
    (link-hint-open-link-at-point)
    (org-clock-in)
    (save-buffer)
    (org-mark-ring-goto)))

;;;###autoload
(defun my/work-done-and-update()
  "Go to the task under point, mark it done, return back,
 and update in roam-dailies"
  (interactive)
  (save-excursion
    (link-hint-open-link-at-point)
    (org-todo 'done)
    (save-buffer)
    (org-mark-ring-goto)
    (org-toggle-checkbox)
    ))

(defun buffer-count-words ()
  "Count the number of words in region"
  (save-excursion
    (goto-char 0)
    (let ((counter 0))
      (while (< (point) (point-max))
        (re-search-forward "\\w+\\W*")
        (setq counter (1+ counter)))
      (+ 0 counter))))

(setq org-roam-autoread-max-words 500)
(setq org-roam-autoread-enabled t)

(defun org-roam-autoread-mode-check ()
  (if (and org-roam-autoread-enabled
           (eq major-mode 'org-mode)
           (string-prefix-p org-roam-directory buffer-file-name)
           (< org-roam-autoread-max-words (buffer-count-words))
           (not (or (string-prefix-p "ln_" (file-name-nondirectory buffer-file-name))
                    (string-prefix-p "br_" (file-name-nondirectory buffer-file-name))
                    (string-prefix-p "private_" (file-name-nondirectory buffer-file-name)))))
      (read-only-mode)))

(add-hook 'after-save-hook #'org-roam-autoread-mode-check)

(defun count-words-in-file (file)
  "Count the number of words in FILE using the buffer word counting logic."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char 0)
    (let ((counter 0))
      (while (< (point) (point-max))
        (when (re-search-forward "\\w+\\W*" nil t)
          (setq counter (1+ counter))))
      counter)))

(defun org-roam-open-large-note-randomly ()
  "Open a random Org-roam note with more than `org-roam-autoread-max-words` words.
Ignores files prefixed with 'ln_', 'br_', or 'private_'. Uses Org-roam DB for file list."
  (interactive)
  (let* ((all-files (org-roam-list-files))
         (filtered-files (seq-filter
                          (lambda (file)
                            (let ((fname (file-name-nondirectory file)))
                              (and (not (or (string-prefix-p "ln_" fname)
                                            (string-prefix-p "br_" fname)
                                            (string-prefix-p "private_" fname)))
                                   (> (count-words-in-file file)
                                      org-roam-autoread-max-words))))
                          all-files))
         (num-large (length filtered-files)))
    (if (zerop num-large)
        (message "No Org-roam notes exceed %d words after filtering." org-roam-autoread-max-words)
      (let ((random-file (seq-random-elt filtered-files)))
        (find-file-other-window random-file)
        (message "Opened random large note: %s (%d words)" (file-name-nondirectory random-file)
                 (count-words-in-file random-file))))))

(setq org-roam-autoread-max-bytes (* org-roam-autoread-max-words 6))  ; Rough estimate: ~6 bytes per word

(defun org-roam-open-nth-largest-large-note (&optional n)
  "Open the Nth largest Org-roam note (by file size) with more than `org-roam-autoread-max-words` estimated words.
Ignores files prefixed with 'ln_', 'br_', or 'private_'. Uses Org-roam DB for file list and file attributes for size.
N defaults to 1 (largest)."
  (interactive "p")
  (let* ((all-files (org-roam-list-files))
         (filtered-files (seq-filter
                          (lambda (file)
                            (let ((fname (file-name-nondirectory file)))
                              (not (or (string-prefix-p "ln_" fname)
                                       (string-prefix-p "br_" fname)
                                       (string-prefix-p "private_" fname)))))
                          all-files))
         (sized-files (seq-map
                       (lambda (file)
                         (cons (file-attribute-size (file-attributes file)) file))
                       filtered-files))
         (sorted-large-files (seq-filter
                              (lambda (pair)
                                (> (car pair) org-roam-autoread-max-bytes))
                              (seq-sort (lambda (a b) (> (car a) (car b))) sized-files)))
         (num-large (length sorted-large-files))
         (effective-n (or n 1)))
    (if (or (zerop num-large) (> effective-n num-large))
        (message "No Org-roam notes exceed estimated %d words (%d bytes) after filtering, or N=%d is out of range (max %d)."
                 org-roam-autoread-max-words org-roam-autoread-max-bytes effective-n num-large)
      (let* ((nth-pair (seq-elt sorted-large-files (1- effective-n)))
             (size (car nth-pair))
             (nth-file (cdr nth-pair)))
        (find-file-other-window nth-file)
        (message "Opened %d%s largest large note: %s (~%d words, %d bytes)"
                 effective-n (if (= effective-n 1) "st" (if (= effective-n 2) "nd" "th"))
                 (file-name-nondirectory nth-file)
                 (/ size 6) size)))))

;; (after! org
;;   (defun tag-new-org-roam-node ()
;;     (let (-tag-list)
;;       (setq -tag-list (completing-read-multiple "Tags" (org-roam-tag-completions)))
;;       (org-roam-tag-add -tag-list)
;;       )
;;     )
;;   (add-hook 'org-roam-capture-new-node-hook #'tag-new-org-roam-node))

(defun open-main-agenda ()
  "Opens my main agenda which is at key k"
  (interactive)
  (org-agenda "" "k")
  )

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

(after! org
  (defun log-todo-next-creation-date (&rest ignore)
    "Log NEXT creation time in the property drawer under the key 'ACTIVATED'"
    (when (and (string= (org-get-todo-state) "NEXT")
               (not (org-entry-get nil "ACTIVATED")))
      (org-entry-put nil "ACTIVATED" (format-time-string "[%Y-%m-%d]"))))
  (add-hook 'org-after-todo-state-change-hook #'log-todo-next-creation-date)

;;;###autoload
  (defun jethro/org-agenda-process-inbox-item ()
    "Process a single item in the org-agenda."
    (org-with-wide-buffer
     (org-agenda-set-tags)
     ;; (org-agenda-set-property)
     (org-agenda-priority)
     (org-agenda-set-effort)
     (call-interactively 'org-agenda-schedule)
     (org-agenda-set-property)
     (org-agenda-refile nil nil t)))


;;;###autoload
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


;;;###autoload
  (defun jethro/org-process-inbox ()
    "Called in org-agenda-mode, processes all inbox items."
    (interactive)
    (org-agenda-bulk-mark-regexp "refile")
    (jethro/bulk-process-entries))
  )

(use-package! saveplace-pdf-view
  :disabled t)

;;(bind-key "C-M-s-u" 'org-roam-dailies-find-tomorrow)

(bind-key "C-M-s-o" 'bms/org-roam-rg-search)
(bind-key "C-M-s-s" 'basic-save-buffer)
(bind-key "C-M-s-j" 'scroll-other-window-down)
(bind-key "C-M-s-k" 'scroll-other-window)
(bind-key "C-M-s-~" '+python/open-ipython-repl)
(bind-key "C-s-~" '+popup/toggle)
(bind-key "C-s-t" '+vterm/here)
(bind-key "C-M-s-t" '+vterm/toggle)
(bind-key "C-M-s-\"" 'evil-avy-goto-char-timer)
(bind-key "C-M-s-h" 'evil-avy-goto-char-2)
(bind-key "C-M-s-v" 'consult-flycheck)
(bind-key "C-M-s-<return>" '+vertico/switch-workspace-buffer-other-window)
(bind-key "C-M-s-<iso-lefttab>" '+vertico/switch-workspace-buffer)
(bind-key "C-M-s-<tab>" '+vertico/switch-workspace-buffer)
(bind-key "C-M-s-d" 'projectile-find-dir-other-window)
(bind-key "C-M-s-f" 'evil-window-vsplit)
(bind-key "C-M-s-p" 'evil-window-split)
(bind-key "C-M-s-q" 'doom/kill-other-buffers)
(bind-key "C-M-s-b" 'delete-other-windows)
(bind-key "C-M-s-l" '+workspace/load)
(bind-key "C-M-s-/" 'consult-ripgrep)
(bind-key "C-M-s-z" 'consult-recent-file)
(bind-key "C-M-s-x" 'consult-buffer)
(bind-key "C-M-s-a" 'open-bookmark)
(bind-key "C-s-a" 'open-random-bookmark)
(bind-key "C-s-u" 'today)
(bind-key "C-s-w" '+workspace/display)
(bind-key "C-s-{" '+workspace/switch-left)
(bind-key "C-s-}" '+workspace/switch-right)
(bind-key "C-s-!"
          (lambda ()
            (interactive)
            (org-save-all-org-buffers)
            (org-agenda-redo)))
;; (bind-key "C-M-s-t" '+my/vterm-run-project)
(bind-key "C-M-s-q" '+workspace/close-window-or-workspace)
(bind-key "C-M-s-l" '+workspace/load)
(bind-key "C-M-s-/" 'consult-ripgrep)
(bind-key "C-M-s-d" 'projectile-find-dir-other-window)
(bind-key "C-M-s-z" 'consult-recent-file)
(bind-key "C-M-s-x" 'consult-buffer)
(bind-key "C-M-s-{" 'org-roam-dailies-find-today)
(bind-key "C-M-s-}" 'org-roam-dailies-find-tomorrow)
(bind-key "C-M-s-:" 'org-roam-dailies-find-yesterday)
(bind-key "C-M-s-r" 'org-roam-node-find)
(bind-key "C-M-s-SPC" 'insert-org-roam-link)
;; (bind-key "C-M-s-a" '+ivy/switch-workspace-buffer)
(bind-key "C-M-s-!" 'winum-select-window-1)
(bind-key "C-M-s-@" 'winum-select-window-2)
(bind-key "C-M-s-#" 'winum-select-window-3)
(bind-key "C-s-v" 'yank-from-kill-ring)
;; (bind-key "C-M-s-$" 'winum-select-window-4)
;; (bind-key "C-M-s-%" 'winum-select-window-5)
;; scroll other window, useful when working with multiple files
(bind-key "C-M-s-n" 'scroll-other-window-down)
(bind-key "C-M-s-e" 'scroll-other-window)
;; (bind-key "C-M-s-:" 'newline-and-indent)
;; (bind-key "C-M-s-w" 'winner-undo)
(bind-key "C-M-s-c" 'screenshot-as-file-link)
;; last set of key bindings
(bind-key "C-M-s-g" 'clock-out-and-mark-current-todo-done)
;; Debugging efficiently
(define-key global-map (kbd "C-s-u") #'today)
(define-key global-map (kbd "C-s-(") #'dape-step-out)
(define-key global-map (kbd "C-s-)") #'dape-step-in)
(define-key global-map (kbd "C-s-r") #'dape-next)
(define-key global-map (kbd "C-s-s") #'dape-continue)
(define-key global-map (kbd "C-s-+") #'dape-breakpoint-expression)
(define-key global-map (kbd "C-s-_") #'dape-repl)
(define-key global-map (kbd "C-s-|") #'dape-evaluate-expression)

(define-key global-map (kbd "C-s-n") #'random-task-select)
(define-key global-map (kbd "C-s-e") #'priority-time-task-select)
(define-key global-map (kbd "C-s-c") #'consult-clock-nonimportant-task)
(define-key global-map (kbd "C-s-p") #'send-to-daily-highlights)
(define-key global-map (kbd "C-s-i") #'cleanup-gtd-system)
(define-key global-map (kbd "C-s-o") #'kairoam-toggle)
(define-key global-map (kbd "C-s-h") #'kairoam-expand-window)
(define-key global-map (kbd "C-s-d") #'kairoam-fold-window)
(define-key global-map (kbd "C-s-;") #'kairoam-open-note-to-right)
;; (define-key global-map (kbd "C-s-u") #'random-piano-select)
(define-key global-map (kbd "C-s-y") #'random-blog-study-select)
(define-key global-map (kbd "C-s-j") #'random-guitar-select)
(define-key global-map (kbd "C-s-k") #'random-study-select)
(define-key global-map (kbd "C-s-l") #'random-leisure-select)
(define-key global-map (kbd "C-s-m") #'random-music-select)
(define-key global-map (kbd "C-s-b") #'random-book-select)
(define-key global-map (kbd "C-s-?") #'my-org-roam-search)
(define-key global-map (kbd "C-s-x") #'consult-activate-project-task)
(define-key global-map (kbd "C-s-z") #'consult-activate-instant-task)

(map! :leader
      :n ">" #'projectile-find-dir
      :n "[" #'+vertico/consult-fd-or-find
      :n "]" #'+default/org-notes-search
      :n "e" #'+default/compile
      (:prefix "o"
       ;; :n "U" #'elfeed
       :n "s" #'org-open-at-point
       ;; :n "u" #'elfeed-update
       ;; EXPERIMENTAL HACK
       ;; :n "p" #'dired-sidebar-toggle-sidebar
       :n "o" #'dired-jump)
      (:prefix "s"
       :n "q" #'org-ql-search
       :n "a" #'consult-org-agenda
       :n "w" #'consult-org-heading)
      (:prefix "k"
       :n "t" #'dap-breakpoint-toggle
       :n "c" #'dap-continue
       :n "n" #'dap-next
       :n "i" #'dap-step-in
       :n "o" #'dap-step-out
       :n "e" #'dap-ui-expressions-add
       :n "f" #'dap-ui-expressions-remove
       :n "g" #'dap-ui-expressions-add-prompt
       :n "x" #'dap-ui-hide-many-windows
       :n "z" #'dap-ui-show-many-windows)
      (:prefix "v"
       :n "i" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-inbox-file)))
       :n "t" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-tasks-file)))
       :n "d" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-diary-file)))
       :n "b" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-bookslog-file)))
       :n "p" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-projects-file)))
       :n "r" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect org-recurring-file)))
       :n "D" #'dash-docs-activate-docset
       :n "e" #'ein:run
       :n "f" #'sp-forward-sexp
       :n "n" #'ein:notebooklist-open
       :n "o" #'ein:notebooklist-new-notebook-with-name)
      (:prefix "j"
       :n "r" #'jupyter-org-interrupt-kernel
       :n "c" #'jupyter-org-clone-blcok
       :n "s" #'org-babel-jupyter-scratch-buffer
       :n "S" #'jupyter-repl-scratch-buffer
       :n "e" #'jupyter-org-restart-and-execute-to-point)
      (:prefix "z"
       :n "a" #'unpackaged/iedit-or-flyspell
       :n "s" #'create-new-ml-project
       :n "w" #'change-env-and-restart-lsp
       :n "h" #'unpackaged/org-outline-numbers
       :n "i" #'org-mru-clock-in
       :n "f" #'auto-fill-mode
       :n "y" #'jethro/bulk-process-entries
       :n "j" #'grab-x-link-firefox-insert-org-link
       :n "b" #'grab-x-link-brave-insert-org-link)
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
      )

(after! org

  (evil-define-key 'normal org-mode-map
    ;; keybindings mirror ipython web interface behavior
    "go" 'org-babel-previous-src-block
    "gO" 'org-babel-next-src-block)

  ;; keys used:  o, b, p, y,e  and P,Y,B,O,E,J,K
  (map! :map org-mode-map
        "<C-return>" 'org-ctrl-c-ctrl-c
        "<H-return>" 'jupyter-org-execute-and-next-block
        ;; "gI" 'org-babel-previouH-src-block
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
  ;; (define-key org-mode-map (kbd "H--") 'other-window)
  ;; (define-key org-mode-map (kbd "H-+") 'org-strikethrough-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-|") 'org-italics-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-+") 'org-bold-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-_") 'org-verbatim-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-(") 'org-code-region-or-point)
  (define-key org-mode-map (kbd "C-M-s-)") 'org-underline-region-or-point)
  ;; (define-key org-mode-map (kbd "H-l") 'org-latex-math-region-or-point)
  )

;; (bind-key "H-F" 'evil-window-split)
;; (bind-key "H-f" 'evil-window-vsplit)
;; (bind-key "H-t" '+my/vterm-run-project)
;; (bind-key "H-;" '+evil-window-split-a)
;; (bind-key "H-\\" '+evil-window-vsplit-a)

(setq scihub-homepage "https://sci-hub.st"
      scihub-download-directory "~/pdfs"
      scihub-open-after-download nil)

(use-package! org-mru-clock
  :after org
  :config
  (setq org-mru-clock-how-many 40)
  (add-hook 'minibuffer-setup-hook #'org-mru-clock-embark-minibuffer-hook)
  )

(setq! org-agenda-category-icon-alist
       `(
         ;; Tasks that are still not classified but will be in the future
         ("Inbox" ,(list (nerd-icons-mdicon "nf-md-checkbox_blank_badge" :height 1.2)) nil nil :ascent center)
         ;; Reminders of dates for something important
         ("Events" ,(list (nerd-icons-mdicon "nf-md-calendar_clock" :height 1.2)) nil nil :ascent center)
         ;; Long term tasks whose output is not immediately known
         ("ToTheMoon" ,(list (nerd-icons-mdicon "nf-md-rocket_launch_outline" :height 1.2)) nil nil :ascent center)
         ;; Short term tasks that show immediate improvements
         ("ToImprove" ,(list (nerd-icons-mdicon "nf-md-motorbike" :height 1.2)) nil nil :ascent center)
         ;; Something I do just for the sake of doing it
         ("Hobby" ,(list (nerd-icons-mdicon "nf-md-spa" :height 1.2)) nil nil :ascent center)
         ;; Health related tasks
         ("Fitness" ,(list (nerd-icons-faicon "nf-fa-heartbeat" :height 1.2)) nil nil :ascent center)
         ;; Tasks that don't fall into any category
         ("Normal" ,(list (nerd-icons-mdicon "nf-md-laptop" :height 1.2)) nil nil :ascent center)
         ;; Something that is not too valuable in terms of information
         ("Mundane" ,(list (nerd-icons-mdicon "nf-md-emoticon_sad_outline" :height 1.2)) nil nil :ascent center)
         ;; Birthdays and Anniversaries
         ("Celebration" ,(list (nerd-icons-mdicon "nf-md-cake" :height 1.2)) nil nil :ascent center)
         ;; Birthdays and Anniversaries
         ("EHP" ,(list (nerd-icons-faicon "nf-fa-key" :height 1.2)) nil nil :ascent center)
         ;; ("recurring" ,(list (nerd-icons-mdicon "loop" :height 1.2)) nil nil :ascent center)
         ;; ("someday" ,(list (nerd-icons-mdicon "schedule" :height 1.2)) nil nil :ascent center)
         ;; ("project" ,(list (nerd-icons-mdicon "stars" :height 1.2)) nil nil :ascent center)
         ;; ("reading" ,(list (nerd-icons-mdicon "book" :height 1.2)) nil nil :ascent center)
         ;; ("coding" ,(list (nerd-icons-mdicon "code" :height 1.2)) nil nil :ascent center)
         ;; Based on purpose
         ;; ("hobby" ,(list (nerd-icons-mdicon "gamepad" :height 1.2)) nil nil :ascent center)
         ;; ("finance" ,(list (nerd-icons-mdicon "attach_money" :height 1.2)) nil nil :ascent center)
         ;; ("skill" ,(list (nerd-icons-mdicon "directions_bike" :height 1.2)) nil nil :ascent center)
         ;; ("relax" ,(list (nerd-icons-mdicon "ondemand_video" :height 1.2)) nil nil :ascent center)
         ;; ("research" ,(list (nerd-icons-mdicon "explore" :height 1.2)) nil nil :ascent center)
         ;; ("fitness" ,(list (nerd-icons-mdicon "spa" :height 1.2)) nil nil :ascent center)
         ;; ("daytoday" ,(list (nerd-icons-mdicon "local_grocery_store" :height 1.2)) nil nil :ascent center)
         ;; ("feedback" ,(list (nerd-icons-mdicon "loop" :height 1.2)) nil nil :ascent center)
         ;; ;; Things that get excluded from the list of purpose
         ;; ("events" ,(list (nerd-icons-mdicon "event" :height 1.2)) nil nil :ascent center)
         ;; ("inbox" ,(list (nerd-icons-mdicon "check_box" :height 1.2)) nil nil :ascent center)
         ;; ("necessity" ,(list (nerd-icons-mdicon "hourglass_full" :height 1.2)) nil nil :ascent center)
         ;;
         ;; ("office" ,(list (nerd-icons-mdicon "work" :height 1.2)) nil nil :ascent center)
         ;; ("mundane" ,(list (nerd-icons-mdicon "weekend" :height 1.2)) nil nil :ascent center)
         ;; ("emacs" ,(list (nerd-icons-mdicon "format_paint" :height 1.2)) nil nil :ascent center)
         ;; ("tinker" ,(list (nerd-icons-mdicon "build" :height 1.2)) nil nil :ascent center)
         ;; ("freelance" ,(list (nerd-icons-mdicon "redeem" :height 1.2)) nil nil :ascent center)
         ;; ("book" ,(list (nerd-icons-mdicon "book" :height 1.2)) nil nil :ascent center)
         ))


;; (customize-set-value
;;  'org-priority-faces
;;  `(
;;    (?A . (:foreground "red" :weight bold))
;;    (?B . (:foreground "tomato" :weight bold))
;;    (?C . (:foreground "orange"))
;;    (?D . (:foreground "green"))
;;    (?D . (:foreground "green"))
;;    (?D . (:foreground "green"))
;;    ))

(after! org
  ;; (add-hook 'org-mode-hook #'auto-fill-mode)
  (setq org-attach-id-dir (concat org-directory "attachments/org-attach/")
        org-attach-auto-tag nil
        ;; show images instead of links to images
        org-startup-with-inline-images t
        org-archive-mark-done t
        org-archive-tag "DONE"
        org-image-actual-width nil
        +org-export-directory (concat org-directory "publish/")
        org-archive-location (concat org-directory "archive/archive.org::datetree/")
        org-default-notes-file org-inbox-file
        projectile-project-search-path '("~/workspace/"))
  )

(after! org
  (require 'org-edna)
  (org-edna-mode))

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
  (setq org-agenda-tags-column 40)
  (setq org-agenda-buffer-name "kai-agenda")
  (setq org-tags-column 40)
  (setq org-agenda-start-with-log-mode t)
  (setq org-columns-default-format "%40ITEM(Task) %Effort(EE){:} %CLOCKSUM(Time Spent) %SCHEDULED(Scheduled) %DEADLINE(Deadline) %TAGS")
  (setq org-tags-exclude-from-inheritance '("project"))
  (setq org-agenda-sorting-strategy
        '((agenda time-up) (todo time-up) (tags time-up) (search time-up)))

  (add-to-list 'org-global-properties
               '("Effort". "0:05 0:15 0:30 1:00 2:00 3:00 4:00"))
  (setq org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-scheduled-if-deadline-is-shown t
        ;; for showing only recurring task's next entry
        org-agenda-show-future-repeats "next"
        )


  (setq org-todo-keyword-faces
        '(("TODO" :foreground "DeepSkyBlue4" :weight bold)
          ("TOREAD" :foreground "DeepSkyBlue4" :weight bold)
          ("TOWATCH" :foreground "DeepSkyBlue4" :weight bold)
          ("TOSTUDY" :foreground "DeepSkyBlue4" :weight bold)
          ("TOPRACTICE" :foreground "DeepSkyBlue4" :weight bold)
          ("WAITING" :foreground "light sea green" :weight bold)
          ("READING" :foreground "light sea green" :weight bold)
          ("STUDYING" :foreground "light sea green" :weight bold)
          ("WATCHING" :foreground "light sea green" :weight bold)
          ("PRACTICING" :foreground "light sea green" :weight bold)
          ("SOMEDAY" :foreground "chocolate3" :weight bold)
          ("REVISING" :foreground "firebrick" :weight bold)
          ("REREADING" :foreground "firebrick" :weight bold)
          ("REPRACTICING" :foreground "firebrick" :weight bold)
          ("REWATCH" :foreground "firebrick" :weight bold)
          ("SUMMARISING" :foreground "Gold" :weight bold)
          ("DELEGATED" :foreground "Gold" :weight bold)
          ("NEXT" :foreground "red1" :weight bold)
          ("ACTIVE" :background "DimGray" :foreground "gold1" :weight bold)
          ("DONE" :foreground "slategrey" :weight bold)))

  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "ACTIVE(a)" "REVISE(y)" "REVIEW(r@/!)" "|" "DONE(d!/!)")
          ;; (sequence "TOREAD(t)" "READING(r!)" "SUMMARISING(s!)" "|" "DONE(d!/!)")
          ;; (sequence "REREADING(w!)" "SUMMARISING(s!)" "|" "DONE(d!/!)")
          ;; (sequence "TOWATCH(t)" "WATCHING(w!)"  "|" "WATCHED(W!)" "WATCHEDTWICE(T!)" "WATCHEDTHRICE(H!)" "ALWAYSWATCHING(A!)")
          ;; (sequence "REWATCH(r/!)" "WATCHING(w!)"  "|" "WATCHEDTWICE(T!)" "WATCHEDTHRICE(H!)" "ALWAYSWATCHING(A!)")
          ;; (sequence "TOSTUDY(t)" "STUDYING(s!)" "REVISING(r!)" "|" "DONE(d!/!)")
          ;; (sequence "TOPRACTICE(t)" "PRACTICING(s!)" "REPRACTICING(r!)" "|" "DONE(d!/!)")
          (sequence "SOMEDAY(f@/!)" "|" "CANCELED(c@/!)")
          (sequence "PROJ(p)" "|" "DONE(d!/!)" "CANCELED(c@/!)")
          (sequence "WAITING(w@/!)" "|" "CANCELED(c@/!)")))

  (setq org-log-state-notes-insert-after-drawers nil
        org-log-into-drawer t
        org-log-done 'time
        org-log-repeat 'time
        org-log-redeadline 'note
        org-log-reschedule 'note)

  (setq org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm)

  ;;(advice-add #'org-refile :after 'org-save-all-org-buffers)
  ;; (advice-add #'org-agenda-exit :around 'doom-shut-up-a)
  ;;(advice-add #'org-agenda-exit :before 'org-save-all-org-buffers)

  (setq org-startup-indented t
        org-src-tab-acts-natively t)
  ;; (add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

  (setq org-tag-alist '(
                        ;; Type of work
                        (:startgroup . nil)
                        ;; Have topic you are planning for as a tag
                        ("plan" . ?n)

                        ;; Have place and person who you are meeting with
                        ;; You can use additonal tags to describe the meeting
                        ;; For example, you can use e.g. Zoom, Slack, Messenger, Place Name etc.
                        ("meeting". ?m)
                        ;; Have person as a tag if working with someone or collaborating
                        ;; ("assist". ?A)

                        ;; hobby category and coding type
                        ;; ("customization". ?C)
                        ;; ("do" . ?d)
                        ("code" . ?c)
                        ("practice" . ?s)
                        ("plain" . ?l)
                        (:endgroup . nil)

                        (:startgroup . nil)
                        ("personal" . ?p)
                        ("work" . ?w)
                        ("both" . ?b)
                        (:endgroup . nil)

                        ;; Active or Passive Work
                        (:startgroup . nil)
                        ("Active". ?a)
                        ;; ("read" . ?r)
                        ;; ("write" . ?W)
                        ("Passive". ?v)
                        ;; ("watch" . ?w)
                        ;; ("listen" . ?L)
                        (:endgroup . nil)
                        (:startgroup . nil)
                        ("ehpsupport" . ?z)
                        ("ehpmodeling" . ?x)
                        ("ehpdragonfly" . ?y)
                        ("ehparchitecture" . ?e)
                        ("ehpresearch" . ?i)
                        (:endgroup . nil)

                        ;; Difficulty of work
                        (:startgroup . nil)
                        ("Challenge" . ?1)
                        ("Average" . ?2)
                        ("Easy" . ?3)
                        (:endgroup . nil)

                        ;; ;; Time Context for the work
                        (:startgroup . nil)
                        ("Morning" . ?4)
                        ("Day" . ?5)
                        ("Evening" . ?6)
                        (:endgroup . nil)

                        ;; Motivation required for this work
                        (:startgroup . nil)
                        ("Lazy" . ?7)
                        ("ModeratelyLazy" . ?8)
                        ("Energetic" . ?9)
                        (:endgroup . nil)
                        ))

  (setq org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id
        org-clone-delete-id t)
  )

(use-package org-clock-convenience
  :after org
  :bind (:map org-agenda-mode-map
              ("C-M-s-<up>" . org-clock-convenience-timestamp-up)
              ("C-M-s-<down>" . org-clock-convenience-timestamp-down)
              ("C-M-s-<right>" . org-clock-convenience-fill-gap)
              ("C-M-s-<left>" . org-clock-convenience-fill-gap-both)))

(after! org
  (defun ibizaman/org-babel-goto-tangle-file ()
    (if-let* ((args (nth 2 (org-babel-get-src-block-info t)))
              (tangle (alist-get :tangle args)))
        (when (not (equal "no" tangle))
          (find-file tangle)
          t)))

  (add-hook 'org-open-at-point-functions 'ibizaman/org-babel-goto-tangle-file))

(after! org (add-to-list 'org-capture-templates
                         '("l" "Link Capture" entry (file (concat org-directory "extra/links.org"))
                           "* TODO [[%^{link}][%^{description}]]"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("h" "Clip Link Capture" entry (file (concat org-directory "extra/links.org"))
                           "* TODO %(org-cliplink-capture)"
                           :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("pn" "New Project" entry
                           (file org-inbox-file)
                           (file (concat org-templates-directory "newprojtemplate.org")))
                         ))


(after! org (add-to-list 'org-capture-templates
                         '("ps" "Create Project Subtask" entry (file org-inbox-file)
                           "* TODO %^{taskname}%?
:PROPERTIES:
:TRIGGER: next-sibling scheduled!(\"++%^{NEXT_TASK_AFTER}\") todo!(NEXT)
:BLOCKER:  previous-sibling
:CREATED:    %U
:END:
" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("v" "Create a new habit" entry (file org-recurring-file)
                           "* TODO %^{description} %?
SCHEDULED: %^{Start Time:}t
:PROPERTIES:
:STYLE: habit
:CREATED: %U
:END:
")))

(after! org (add-to-list 'org-capture-templates
                         '("z" "Create EHP Task" entry (file org-tasks-file)
                           "* TODO %^{Task Description} %(org-set-tags \"work:Day\")%(org-set-tags-command)
SCHEDULED: %t
:PROPERTIES:
:CREATED: %U
:CATEGORY: EHP
:END:
")))

;; TODO Upgrade this functionality to use a template
;; (after! org (add-to-list 'org-capture-templates
;;                          '("e" "Add an event" entry (file (concat org-agenda-directory "birthdays_and_anniversaries.org"))
;;                            "* %^{Person}
;; \%\%(org-anniversary %^{Date}) %^{Person}'s %^{Event}
;; " :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("d" "Diary Log" entry(file+olp+datetree org-diary-file)
                           "** <%<%I:%M:%S>> %^{diary entry}
%?")))


(after! org (add-to-list 'org-capture-templates
                         '("m" "Set a Motto" entry(file+olp+datetree org-motto-file)
                           "* %^{diary entry}
%?" :immediate-finish t)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     REVIEW TEMPLATES                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



(after! org
  (add-to-list 'org-capture-templates
               '("r" "Make a review")))

(after! org
  (add-to-list 'org-capture-templates
               '("rw" "Weekly Review" entry
                 (file+olp+datetree org-weeklyreview-file)
                 (file (concat org-templates-directory "weeklyreviewtemplate.org")) :jump-to-captured t :tree-type week))

  (add-to-list 'org-capture-templates
               '("rl" "Last Week Weekly Review" entry
                 (file+olp+datetree org-weeklyreview-file)
                 (file (concat org-templates-directory "weeklyreviewtemplate_lastweek.org")) :jump-to-captured t :tree-type week))
  )

(after! org
  (add-to-list 'org-capture-templates
               '("rm" "Monthly Review" entry
                 (file+olp+datetree org-monthlyreview-file)
                 (file (concat org-templates-directory "monthlyreviewtemplate.org")) :jump-to-captured t :tree-type month)))

(after! org
  (add-to-list 'org-capture-templates
               '("rq" "Quarterly Review" entry
                 (file+olp+datetree org-quarterlyreview-file)
                 (file (concat org-templates-directory "quarterlyreviewtemplate.org")) :jump-to-captured t :tree-type quarter)))

(after! org (add-to-list 'org-capture-templates
                         '("rd" "Daily Review" entry (file+olp+datetree org-dailyreview-file)
                           (file (concat org-templates-directory "dailyreviewtemplate.org"))
                           :jump-to-captured t)))

(after! org (add-to-list 'org-capture-templates
                         '("ry" "Daily Review Yesterday" entry (file+olp+datetree org-dailyreview-file)
                           (file (concat org-templates-directory "dailyreviewtemplate_yesterday.org"))
                           :jump-to-captured t)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        REVIEW TEMPLATES DONE                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(after! org
  (add-to-list 'org-capture-templates
               '("C"  "Contact" entry (file (concat org-directory "extra/contacts.org"))
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
                         '("c" "Capture Immediate" entry (file org-inbox-file)
                           "* TODO %^{taskname}%?
:PROPERTIES:
:CREATED:    %U
:END:
" :immediate-finish t)))

(defun my-agenda-motto (&rest _ignore)
  "INSERTS MOTTO FROM MOTTO FILE TO AGENDA"
  (let ((motto-line "")
        (decorated-motto ""))
    (with-temp-buffer
      (insert-file-contents org-motto-file)
      (goto-char (point-max))
      (forward-line -1)
      (setq motto-line (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position)))
      (setq decorated-motto (concat "MOTTO: "
                                    (s-upcase (s-replace "\*" "" motto-line)))))

    ;; Add properties directly to the motto
    (add-text-properties 0 (length decorated-motto)
                         '(face (:foreground "OrangeRed4" :weight bold))
                         decorated-motto)

    (dotimes (_ 160) (insert "="))
    (insert "\n")
    (dotimes (_ 40) (insert "="))
    (insert decorated-motto)
    (dotimes (_ 40) (insert "="))
    (insert "\n")
    (dotimes (_ 160) (insert "="))
    (insert "\n")))

(after! org
  (add-hook 'org-agenda-finalize-hook
            (lambda () (remove-text-properties
                        (point-min) (point-max) '(mouse-face t))))
  )
(after! org
  (require 'org-time-budgets)
  (setq org-time-budgets '((:title "EHP" :match "+work" :budget "30:00" :blocks (workday week))
                           (:title "EHP Deep Work" :match "+work+deepwork" :budget "13:00" :blocks (workday week))
                           (:title "Meditation" :match "+meditation" :budget "5:00" :blocks (day week))
                           (:title "Review" :match "+review" :budget "0:30" :blocks (day week))
                           (:title "Ritual" :match "+ritual" :budget "0:30" :blocks (day week))
                           (:title "Entertainment" :match "+entertainment" :budget "10:00" :blocks (day week))
                           (:title "Guitar" :match "+music" :budget "6:00" :blocks (day week))
                           (:title "Exercise" :match "+exercise" :budget "1:45" :blocks (day week))
                           (:title "Coding" :match "+code" :budget "40:00" :blocks (nil week))
                           (:title "Reading" :match "+book" :budget "3:00" :blocks (nil week))
                           ;; (:title "Yollo" :match "+personal+code" :budget "20:00" :blocks (nil week))
                           ))
  )

(after! evil-org-agenda
  (evil-define-key* 'motion evil-org-agenda-mode-map
    "q" nil
    (kbd "RET") nil
    (kbd "<return>") nil))

(after! org-agenda
  (define-key org-agenda-keymap "q" nil)
  (define-key org-agenda-keymap (kbd "RET") nil)
  (define-key org-agenda-mode-map "q" nil)
  (define-key org-agenda-mode-map (kbd "RET") nil))

;;;###autoload
(after! org-agenda (setq org-agenda-custom-commands
                         '(
                           ("k" "Today's View"
                            ((my-agenda-motto "" nil)
                             (agenda ""
                                     ((org-agenda-overriding-header "Overall Agenda View")
                                      (org-agenda-span 'day)
                                      (org-deadline-warning-days 7)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-sorting-strategy '(priority-down effort-down)))
                                     )
                             (org-time-budgets-in-agenda-maybe)
                             (todo "SUMMARISING"
                                   ((org-agenda-overriding-header "Books I am currently reading and summarizing\n ======================================================\n")))
                             )
                            nil)
                           ("n" "Next tasks"
                            ((todo "NEXT"
                                   ((org-agenda-overriding-header " PROJECT TASKS\n ===================================================================\n")
                                    ))
                             ) nil)
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
                             ) nil)
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
                                     (list org-inbox-file))
                                    (org-agenda-overriding-header " Process and refile inbox\n ===================================================================\n")
                                    ))
                             (todo "TOREAD"
                                   ((org-agenda-files
                                     (list org-bookslog-file))
                                    (org-agenda-overriding-header " Do you want to read some new book\n ===========================================================\n")
                                    ))
                             (todo "WAITING"
                                   ((org-agenda-files
                                     (list org-tasks-file))
                                    (org-agenda-overriding-header " Waiting for something else\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-files
                                     (list org-projects-file))
                                    (org-agenda-overriding-header " Projects Work for Next Week\n ===================================================================\n")
                                    ))
                             (todo ""
                                   ((org-agenda-overriding-header " Process Someday\n ===========================================================\n")
                                    (org-agenda-files
                                     (list org-someday-file))
                                    ))
                             )
                            nil)
                           ("v" "I am bored"
                                        ; Easy tasks
                            ((tags-todo "+Easy"
                                        ((org-agenda-overriding-header " Get over easier things now")
                                         ))
                                        ; Read when bored
                             (tags-todo "+read"
                                        ((org-agenda-files
                                          (list org-bookslog-file))
                                         (org-agenda-overriding-header " Why not read something rather than waste time?"))
                                        )
                                        ; Get entertained
                             (tags-todo "+entertaintment"
                                        ((org-agenda-files
                                          (list org-inbox-file))
                                         (org-agenda-overriding-header " Enjoy some time doing whatever"))
                                        )
                             ))
                           ("z" "Outdoors"
                                        ; Priority A
                            ((tags-todo "+outdoor"
                                        ((org-agenda-overriding-header "Outdoor Tasks to be done")))
                             ))
                           ;; ("l" "Home agenda"
                           ;;              ; Priority A
                           ;;  ((tags-todo "PRIORITY=\"A\"&+home"
                           ;;              ((org-agenda-overriding-header "Priority A")))
                           ;;              ; Due soon
                           ;;   (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&+home"
                           ;;              ((org-agenda-overriding-header "Due soon")))
                           ;;   ))
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
  (setq org-highlight-latex-and-related '(native script entities))
  (add-hook 'org-mode-hook 'org-fragtog-mode)
  )

(add-hook! 'org-mode-hook #'org-appear-mode)

(after! org
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks t)
  ;;(run-at-time nil nil #'org-appear--set-elements)
  )

(after! org
  (setq org-html-head-include-scripts t
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
  (setq org-download-image-dir (concat org-directory "org-images/")
        org-download-heading-lvl nil
        org-download-delete-image-after-download t
        org-download-screenshot-method "grimshot save area %s"
        org-download-image-org-width 600
        org-download-annotate-function (lambda (link) "") ;; Don't annotate
        )
  ;; org-download-image-dir "~/Nextcloud/org/org-images/"
  ;; org-download-delete-image-after-download t
  (setq org-image-actual-width nil)
  (setq org-download-link-format "[[file:%s]]\n"
        org-download-abbreviate-filename-function #'file-relative-name)
  (setq org-download-link-format-function #'org-download-link-format-function-default)
  ;; (org-download-enable)
  ;; org-attach method
  (setq-default org-attach-method 'mv
                ;; org-attach-auto-tag "attach"
                org-attach-store-link-p 't)
  )
(global-set-key (kbd "<s-print>") 'my-org-download-screenshot)

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
   :i [return] #'unpackaged/org-return-dwim)

  ;; (map! :map org-mode-map
  ;;       :desc "Org Return DWIM" "RET" #'unpackaged/org-return-dwim)

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
    ("4" (org-priority 68))
    ("5" (org-priority 69))

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
    ("j" counsel-imenu)

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

(set-popup-rule! "*jupyter-pager*" :side 'right :size .40 :select t :vslot 2 :ttl 3)
(set-popup-rule! "^\\*Org Src*" :side 'right :size .60 :select t :vslot 2 :ttl 3 :quit nil)
(set-popup-rule! "*jupyter-repl*" :side 'bottom :size .30 :vslot 2 :ttl 3)

(after! jupyter
  (set-eval-handler! 'jupyter-repl-interaction-mode #'jupyter-eval-line-or-region))

;; on scratch buffer first run jupyter-associate-buffer
(add-hook! python-mode
  (set-repl-handler! 'python-mode #'jupyter-repl-pop-to-buffer))

(after! org
  (defun cpb/convert-attachment-to-file ()
    "Convert attachment type link to file type link"
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
                     (relpath (file-relative-name fullpath current-dir))
                     ;; extract just the filename for the description
                     (filename (file-name-nondirectory relpath)))
                ;; delete the existing link
                (delete-region link-begin link-end)
                ;; replace with file: link and just filename as description
                (insert (format "[[file:%s][%s]]" relpath filename)))))))))

(defun open-file-link-in-dired ()
  "Open the directory of the file link at point in Dired."
  (interactive)
  (let* ((context (org-element-context))
         (type (org-element-type context))
         (link (when (eq type 'link) context))
         (path (when link (org-element-property :path link))))
    (if (and path (string-prefix-p "file:" (org-element-property :raw-link link)))
        (dired (file-name-directory (expand-file-name path)))
      (user-error "No valid file link at point"))))

(setq org-latex-pdf-process '("LC_ALL=en_US.UTF-8 latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

(cl-defmacro lsp-org-babel-enable (lang)
  "Support LANG in org source code block."
  (setq centaur-lsp 'lsp-mode)
  (cl-check-type lang stringp)
  (let* ((edit-pre (intern (format "org-babel-edit-prep:%s" lang)))
         (intern-pre (intern (format "lsp--%s" (symbol-name edit-pre)))))
    `(progn
       (defun ,intern-pre (info)
         (let ((file-name (->> info caddr (alist-get :file))))
           (unless file-name
             (setq file-name (make-temp-file "babel-lsp-")))
           (setq buffer-file-name file-name)
           (lsp-deferred)))
       (put ',intern-pre 'function-documentation
            (format "Enable lsp-mode in the buffer of org source block (%s)."
                    (upcase ,lang)))
       (if (fboundp ',edit-pre)
           (advice-add ',edit-pre :after ',intern-pre)
         (progn
           (defun ,edit-pre (info)
             (,intern-pre info))
           (put ',edit-pre 'function-documentation
                (format "Prepare local buffer environment for org source block (%s)."
                        (upcase ,lang))))))))
(defvar org-babel-lang-list
  '("python" "ipython" "bash" "sh"))
(dolist (lang org-babel-lang-list)
  (eval `(lsp-org-babel-enable ,lang)))

;; Inspired from https://emacs.stackexchange.com/questions/38570/org-mode-quote-block-indentation-highlighting
(add-hook 'org-font-lock-hook #'aj/org-indent-quotes)

(defun aj/org-indent-quotes (limit)
  (let ((case-fold-search t))
    (while (search-forward-regexp "^[ \t]*#\\+begin_quote" limit t)
      (let ((beg (1+ (match-end 0))))
        ;; on purpose, we look further than LIMIT
        (when (search-forward-regexp "^[ \t]*#\\+end_quote" nil t)
          (let ((end (1- (match-beginning 0)))
                (indent (propertize "    " 'face 'org-hide)))
            (add-text-properties beg end (list 'line-prefix indent
                                               'wrap-prefix indent))))))))

(defun replace-jibberish-chars ()
  (interactive)
  (let ((replacements '((?\220 . " ")
                        (?\221 . "`")
                        (?\222 . "'")
                        (?\223 . "\"")
                        (?\224 . "\"")
                        (?\225 . "* ")
                        (?\226 . "--")
                        (?  . " ")
                        (?\227 . " -- "))))
    (save-excursion
      (dolist (pair replacements)
        (goto-char (point-min))
        (while (search-forward (char-to-string (car pair)) nil t)
          (replace-match (cdr pair) nil t))))))

(require 'time-stamp)
(add-hook 'write-file-functions 'time-stamp) ; update when saving

;; (after! org
;; (defun custom-quote-export-filter (text backend info)
;;   "Custom export filter for quotes with properties."
;;   (when (org-export-derived-backend-p backend 'md) ; checks if the backend is markdown
;;     (let ((quote-pattern "^#\\+BEGIN_QUOTE\n\\(.*?\\)\n#\\+END_QUOTE")
;;           (properties-pattern ":PROPERTIES:\n:PAGE: \\([0-9]+\\)\n:TIMESTAMP: \\(.*?\\)\n:AUTHOR: \\(.*?\\)\n:END:"))
;;       (if (and (string-match quote-pattern text)
;;                (string-match properties-pattern text))
;;           (let ((quote-text (match-string 1 text))
;;                 (page (match-string 1 text))
;;                 (timestamp (match-string 2 text))
;;                 (author (match-string 3 text)))
;;             (format "<div class='quote'>%s</div><div class='author'>- %s</div><div class='page'>Page: %s</div><div class='timestamp'>%s</div>"
;;                     quote-text author page timestamp))
;;         text))))
;; (add-to-list 'org-export-filter-plain-text-functions
;;              'custom-quote-export-filter))

(defun my-log-energy ()
  "Prompt for an energy level and log it with timestamp to a CSV file."
  (interactive)
  (let* ((energy-levels '("1" "2" "3" "4" "5" "6" "7" "8" "9" "10"))
         (timer (run-with-timer 30 nil (lambda () (throw 'exit t))))
         (energy nil))
    (unwind-protect
        (condition-case err
            (setq energy (consult--read energy-levels
                                        :prompt "What is your energy level? "
                                        :require-match t))
          (quit
           (message "Energy log timed out or aborted. Next prompt in 2 minutes.")))
      (when (timerp timer)
        (cancel-timer timer)))
    ;; Log energy if selected
    (when energy
      (let ((timestamp (format-time-string "%Y-%m-%d %H:%M:%S")))
        (with-temp-buffer
          (insert (format "%s,%s\n" timestamp energy))
          (append-to-file (point-min) (point-max)
                          (concat org-lookbacks-directory "energy_log.csv")))))
    ;; Schedule next prompt in 2 minutes
    (run-at-time "30 minutes" nil 'my-log-energy)))

;; To start the logging, call this once:
(run-at-time "30 minutes" nil 'my-log-energy)

(setq org-refile-targets
      '((org-someday-file :maxlevel . 1)
        (org-agenda-files :maxlevel . 3)))

(defun my-org-append-title-to-quote-at-point-and-copy ()
  "Append the Org file title within the quote block at point and copy it to clipboard."
  (interactive)
  ;; Find the beginning and end of the quote block at the current point
  (let ((begin-quote (save-excursion
                       (and (re-search-backward "^#\\+begin_quote" nil t)
                            (match-beginning 0))))
        (end-quote (save-excursion
                     (and (re-search-forward "^#\\+end_quote" nil t)
                          (match-end 0)))))
    ;; Ensure the point is within a quote block
    (when (and begin-quote end-quote (> end-quote (point)))
      ;; Find and store the title of the Org file
      (let* (title
             (quote-block (buffer-substring-no-properties begin-quote end-quote)))
        (save-excursion
          (goto-char (point-min))
          (setq title (if (re-search-forward "^#\\+title: \\(.*\\)$" nil t)
                          (match-string 1)
                        "Untitled")))
        ;; Insert the title inside the quote block
        (setq quote-block (replace-regexp-in-string "^#\\+end_quote" (concat "-- " title "\n#+end_quote") quote-block))
        ;; Copy to clipboard
        (kill-new quote-block)
        (message "Quote with title copied to clipboard")))))

(defun my/delete-image-and-next ()
  "Move to the next image and delete the previous one."
  (interactive)
  (let ((previous-file (buffer-file-name)))
    ;; First, check if we are in image mode and there is a next image.
    (if (and (eq major-mode 'image-mode) (image-next-file 1))
        (progn
          ;; After moving to next image, delete the previous file.
          (when previous-file
            (delete-file previous-file)
            (message "Deleted file %s" previous-file)))
      )))

(defun my/read-filename-and-tags ()
  "Read new filename and tags from the user."
  (let ((filename (read-string "Enter new filename: "))
        (tags (read-string "Enter tags (comma-separated): ")))
    (list filename tags)))


(defvar my-image-index-file (concat org-directory "imageindex.csv"))
(defvar my-image-processed-dir "~/PicturesShared/S23/Processed/")

(setq my-image-tags '("personal" "work" "meditation" "books" "research"
                      "learningnote" "todo" "meme" "dance" "music" "movie"
                      "wise" "quote" "money" "health" "food" "travel" "nature"
                      "design" "art" "gif" "funny" "tech" "reference" "favorite"
                      "strange" "party" "qr" "raw" "wallpaper" "memory" ))

(defun read-tags-from-csv (csv-file)
  "Read tags from a CSV file, print them with counts to the message buffer, and return a frequency-sorted list of tags."
  (let ((tag-counts (make-hash-table :test 'equal)))
    (with-temp-buffer
      (insert-file-contents csv-file)
      (while (not (eobp))
        (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
               (elements (split-string line "," t))
               (tags (cdr elements)))  ; Skip the first element (filename)
          (dolist (tag tags)
            (let ((trimmed-tag (string-trim tag)))  ; Trim whitespace from tag
              (when (not (string-empty-p trimmed-tag))  ; Only process non-empty tags
                (puthash trimmed-tag (1+ (gethash trimmed-tag tag-counts 0)) tag-counts))))
          (forward-line 1)))
      (let ((sorted-tags (sort (hash-table-keys tag-counts)
                               (lambda (a b) (> (gethash a tag-counts) (gethash b tag-counts))))))
        (append sorted-tags my-image-tags)))))

(defun set-image-tags-and-rename-and-next ()
  "Set tags for the current image, rename the file using the first tag, move it to the processed directory, save details to an image index file, and then move to the next unprocessed image."
  (interactive)
  ;; Ensure we are in an image buffer
  (unless (eq major-mode 'image-mode)
    (error "Not in an image-mode buffer"))

  (let* ((file (buffer-file-name))
         (all-tags (read-tags-from-csv my-image-index-file))
         (selected-tags (completing-read-multiple
                         "Select tags (use comma to separate): "
                         all-tags nil t))
         ;; Trim whitespace from selected tags
         (trimmed-selected-tags (mapcar #'string-trim selected-tags))
         ;; Filter out empty tags
         (final-tags (seq-filter (lambda (tag) (not (string-empty-p tag))) trimmed-selected-tags))
         (extension (file-name-extension file))
         (first-tag (car final-tags))
         (new-base-name (replace-regexp-in-string "[ ,]" "_" (file-name-base file)))
         (new-name (concat (if first-tag
                               (concat first-tag "--" new-base-name)
                             new-base-name)
                           "." extension))
         (processed-path (expand-file-name new-name my-image-processed-dir))
         (index-entry (format "%s,%s\n" processed-path (string-join final-tags ","))))

    ;; Perform the rename operation
    (when file
      (evil-save file t)
      (rename-file file processed-path)
      ;; Add entry to the image index file
      (with-temp-buffer
        (insert index-entry)
        (append-to-file (point-min) (point-max) my-image-index-file))
      (message "Moved and renamed file to %s and updated index with tags: %s" processed-path (string-join final-tags ", ")))

    ;; Move to the next image
    (my/delete-image-and-next)))

(defun my/crop-save-tags-rename-and-next ()
  "Crop the current image, save it with the same name, set tags, rename the file using the first tag, move it to the processed directory, save details to an image index file, and then move to the next unprocessed image."
  (interactive)
  ;; Ensure we are in an image buffer
  (unless (eq major-mode 'image-mode)
    (error "Not in an image-mode buffer"))

  ;; Crop the image
  (image-crop)

  ;; for some reason image save cannot happen without few escapes
  (execute-kbd-macro (kbd "ESC ESC ESC"))
  ;; Save the cropped image using the same filename
  (let ((file (buffer-file-name)))
    (when file
      (my/save-cropped-image file)))
  (revert-buffer t t)
  ;; Set tags, rename and move to the processed directory
  (set-image-tags-and-rename-and-next))

(defun my/save-cropped-image (filename)
  "Save the current buffer's image to FILENAME."
  (interactive "F")
  (let ((image (image-get-display-property)))
    (when image
      (let ((data (plist-get (cdr image) :data)))
        (unless data
          (error "No image data available"))
        (with-temp-file filename
          (insert data))
        (message "Image saved to %s" filename)))))

(defun image-previous-file-nofreeze (&optional n)
  "Visit the preceding image in the same directory as the current file.
With optional argument N, visit the Nth image file preceding the
current one, in reverse alphabetical order.

This command visits the specified file via `find-alternate-file',
replacing the current Image mode buffer."
  (interactive "p" image-mode)
  (unless (derived-mode-p 'image-mode)
    (error "The buffer is not in Image mode"))
  (unless buffer-file-name
    (error "The current image is not associated with a file"))
  (let* ((n (or n 1))  ; Default to 1
         (file buffer-file-name)
         (dir (file-name-directory file))
         ;; Get sorted list of files matching image-file-name-regexp
         (files (sort (directory-files dir t (image-file-name-regexp)) #'string<))
         (index (cl-position file files :test #'string-equal)))
    (if (or (null index) (<= index (1- n)))
        (user-error "No previous image file")
      (find-alternate-file (nth (- index n) files)))))

(map! :map image-mode-map
      :nvm "q" #'image-kill-buffer
      :nvm "c" #'my/crop-save-tags-rename-and-next
      :nvm "d" #'my/delete-image-and-next
      :nvm "e" #'set-image-tags-and-rename-and-next
      :nvm "C-j" #'image-next-line
      :nvm "C-k" #'image-previous-line
      :nvm "j" #'image-next-file
      :nvm "k" #'image-previous-file-nofreeze
      )

(use-package! gptel
  :config
  (setq gptel-display-buffer-action nil)  ; if user changes this, popup manager will bow out
  (set-popup-rule!
    (lambda (bname _action)
      (and (null gptel-display-buffer-action)
           (buffer-local-value 'gptel-mode (get-buffer bname))))
    :select t
    :size 0.3
    :quit nil
    :ttl nil)
  (setq! gptel-api-key (auth-source-pick-first-password :user "chatgapi"))
  (gptel-make-ollama
      "Ollama"                             ;Any name of your choosing
    :host "localhost:11434"                ;Where it's running
    :models '("gemma3:latest")             ;Installed models
    :stream t)                             ;Stream responses
  (gptel-make-anthropic "Claude"
    :stream t
    :key (auth-source-pick-first-password :user "anthroapi")
    )
  (gptel-make-gemini "Gemini"
    :stream t
    :key (auth-source-pick-first-password :user "geminiapi")
    )
  (gptel-make-gh-copilot "Copilot")

  (map! :leader
        (:prefix ("l" . "llm")
         :desc "Add text to context"        "a" #'gptel-add
         :desc "Explain"                    "e" #'gptel-quick
         :desc "Add file to context"        "f" #'gptel-add-file
         :desc "Open gptel"                 "l" #'gptel
         :desc "Send to gptel"              "s" #'gptel-send
         :desc "Open gptel menu"            "m" #'gptel-menu
         :desc "Rewrite"                    "r" #'gptel-rewrite
         :desc "Org: set topic"             "o" #'gptel-org-set-topic
         :desc "Org: set properties"        "O" #'gptel-org-set-properties))
  )

;; (require 'gptel-integrations)
;; (require 'mcp-hub)
;; (setq mcp-hub-servers
;;       '(("maitreyamcp" .
;;          (:command "/Users/alokregmi/.pyenv/versions/mcp/bin/python"
;;           :args ("/Users/alokregmi/workspace/personal/maitreyamcp_stable/modules/maitreyamcp_python/python_server.py")))))

(use-package! mcp-hub
  :init
  (setq mcp-hub-servers
        '(("maitreyamcp" .
           (:command "/Users/alokregmi/.pyenv/versions/mcpdev/bin/python"
            :args ("/Users/alokregmi/workspace/personal/maitreyamcp_dev/modules/maitreyamcp_python/python_server.py")))))
  ;; (add-hook! 'after-init-hook #'mcp-hub-start-all-served
  )

(use-package! gptel-integrations
  :after (gptel mcp-hub))

(use-package! gptel-magit
  :when (modulep! :tools magit)
  :hook (magit-mode . gptel-magit-install))

(after! org
  (setq org-roam-dailies-directory "daily/")

  ;;(org-roam-setup)

  ;; Attachments removed from org-roam db
  (setq org-roam-db-node-include-function
        (lambda ()
          (or
           (not (cdr  (assoc "NOTER_PAGE" (org-entry-properties))))
           (not (member "ATTACH" (org-get-tags)))
           )))

  ;; Org-roam interface
  (cl-defmethod org-roam-node-hierarchy ((node org-roam-node))
    "Return the node's TITLE, as well as it's HIERACHY."
    (let* ((title (org-roam-node-title node))
           (olp (mapcar (lambda (s) (if (> (length s) 30) (concat (substring s 0 30)  "...") s)) (org-roam-node-olp node)))
           (level (org-roam-node-level node))
           (filetitle (org-roam-get-keyword "TITLE" (org-roam-node-file node)))
           (shortentitle (if (> (length filetitle) 30) (concat (substring filetitle 0 30)  "...") filetitle))
           (separator (concat " " (nerd-fonts-insert-faicon "nf-fa-chevron_right") " ")))
      (cond
       ((= level 1) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-green)) " "
                            (propertize shortentitle 'face 'org-roam-dim) separator title))
       ((= level 2) (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "nf-fa-list" :face 'all-the-icons-dpurple)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       ((> level 2) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-dsilver)) " "
                            (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
       (t (concat (propertize (format "=level:%d=" level) 'display (nerd-icons-faicon "list" :face 'all-the-icons-yellow)) " " title)))))

  (defconst my/org-roam-special-tags
    '("bibnote" "bookreview" "literaturenote" "default" "abstract" "blog" "person" "creativewriting")
    "Special tags that are unique to each file to represent the note's function.")

  (defconst my/frg-roam-generalnote-tags
    '("beautiful" "idgi" "seed" "readmore" "talkabout" "tmi" "research")
    "Special tags that are unique to each file to represent the note's function.")

  (defconst my/org-roam-ignored-tags
    '("ATTACH")
    "Tags that are ignored when displaying function and other tags.")

  (defun my/org-roam-filtered-tags (node)
    "Return the tags of NODE after filtering out ignored tags."
    (seq-remove (lambda (tag)
                  (member tag my/org-roam-ignored-tags))
                (org-roam-node-tags node)))

  (cl-defmethod org-roam-node-functiontag ((node org-roam-node))
    "Return the FUNCTION TAG for each node."
    (let* ((tags (my/org-roam-filtered-tags node))
           (functiontag (seq-intersection my/org-roam-special-tags tags 'string=)))
      (concat
       (if functiontag
           (propertize "=has:functions=" 'display (nerd-icons-faicon "nf-fa-gear" :face 'all-the-icons-silver :v-adjust 0.02))
         (propertize "=not-functions=" 'display (nerd-icons-faicon "nf-fa-gear" :face 'org-roam-dim :v-adjust 0.02)))
       " " (string-join functiontag ", "))))

  (cl-defmethod org-roam-node-othertags ((node org-roam-node))
    "Return the OTHER TAGS of each notes."
    (let* ((tags (my/org-roam-filtered-tags node))
           (othertags (seq-difference tags my/org-roam-special-tags 'string=)))
      (when othertags
        (concat
         (propertize "=has:tags=" 'display (nerd-icons-faicon "nf-fa-tags" :face 'all-the-icons-dgreen :v-adjust 0.02)) " "
         (propertize (string-join othertags ", ") 'face 'all-the-icons-dgreen)))))

  (cl-defmethod org-roam-node-backlinkscount ((node org-roam-node))
    (let* ((count (caar (org-roam-db-query
                         [:select (funcall count source)
                          :from links
                          :where (= dest $s1)
                          :and (= type "id")]
                         (org-roam-node-id node)))))
      (if (> count 0)
          (concat (propertize "=has:backlinks=" 'display (nerd-icons-insert-octicon "nf-oct-link" :face 'all-the-icons-dblue)) (format "%d" count))
        (concat (propertize "=not-backlinks=" 'display (nerd-icons-insert-octicon "nf-oct-link" :face 'org-roam-dim))  " "))))

  (defun my/org-roam-compute-tags (node)
    "Compute the function tags and other tags for the given NODE.
Return a list where the first element is the function tags and
the second element is the other tags."
    (let* ((tags (seq-remove (lambda (tag)
                               (member tag my/org-roam-ignored-tags))
                             (org-roam-node-tags node)))
           (functiontags (seq-intersection my/org-roam-special-tags tags 'string=))
           (othertags (seq-difference tags my/org-roam-special-tags 'string=)))
      (list functiontags othertags)))

  (defun org-roam-node-fullformat (node)
    "Return a formatted string containing the title and computed tags for the NODE."
    (let* ((tags (my/org-roam-compute-tags node))
           (functiontag (car tags))
           (othertags (cadr tags))
           (functiontag-str (format "%-15s"
                                    (concat
                                     ;; (if functiontag
                                     ;;     (propertize "=has:functions=" 'display (all-the-icons-octicon "gear" :face 'all-the-icons-silver :v-adjust 0.02))
                                     ;;   (propertize "=not-functions=" 'display (all-the-icons-octicon "gear" :face 'org-roam-dim :v-adjust 0.02)))
                                     " " (string-join functiontag ", "))))
           (othertags-str (when othertags
                            (concat
                             (propertize "=has:tags=" 'display (nerd-icons-faicon "nf-fa-tags" :face 'nerd-icons-dgreen :v-adjust 0.02)) " "
                             (propertize (string-join othertags ", ") 'face 'nerd-icons-dgreen)))))
      (format " %s %s %s" functiontag-str (org-roam-node-title node) (or othertags-str ""))))

  (setq org-roam-node-display-template
        (concat  "${fullformat}"))

  ;; (setq org-roam-node-display-template
  ;;       (concat  "${functiontag:27} ${title} ${othertags}"))

  ;;;###autoload
  (defun title-to-org-roam-node (title)
    "Create an Org-roam note from the current headline and jump to it."
    (interactive)
    (let ((node nil)
          (filetag ""))
      (setq node (org-roam-node-create :title title))
      (setq filetag (list "auto"))
      (if (org-roam-node-file node)
          (progn
            (message "Skipping %s, node already exists" title)
            node)  ; Return node here if it already exists
        (org-roam-capture- :node node
                           :keys "r")
        (org-entry-put (point-min) "PROJ_RESOURCES_DIR" (concat "[[" project-resources-dir title "]]"))
        (org-roam-tag-add filetag)
        (org-capture-finalize nil)
        ;; (kill-whole-line)
        ;; (org-capture-finalize nil)
        node)  ; Return node here after creating new node
      ))

  ;; ;; Keys binding
  (map! :leader
        :prefix "n"
        (:prefix ("r" . "Org-roam")
         :desc "Toggle roam buffer"            "t" #'org-roam-buffer-toggle
         :desc "Refile"                        "r" #'org-roam-refile
         (:prefix ("l" . "Roam Alias")
          :desc "Add alias"                    "a" #'org-roam-alias-add
          :desc "Remove alias"                 "d" #'org-roam-alias-remove)))
  )

(after! org-roam
  (defun my/org-roam--backlink-files (node)
    "Get the list of files that are already backlinking to NODE."
    (seq-map
     (lambda (backlink)
       (org-roam-node-file (org-roam-backlink-source-node backlink)))
     (org-roam-backlinks-get node)))

  (defun org-roam-unique-unlinked-references-section (node)
    "The unlinked references section for NODE.
   References from files that are already backlinking to NODE are excluded."
    (when (and (executable-find "rg")
               (org-roam-node-title node)
               (not (string-match "PCRE2 is not available"
                                  (shell-command-to-string "rg --pcre2-version"))))
      (let* ((titles (cons (org-roam-node-title node)
                           (org-roam-node-aliases node)))
             (rg-command (concat "rg -L -o --vimgrep -P -i "
                                 (mapconcat (lambda (glob) (concat "-g " glob))
                                            (org-roam--list-files-search-globs org-roam-file-extensions)
                                            " ")
                                 (format " '\\[([^[]]++|(?R))*\\]%s' "
                                         (mapconcat (lambda (title)
                                                      (format "|(\\b%s\\b)" (shell-quote-argument title)))
                                                    titles ""))
                                 org-roam-directory))
             (results (split-string (shell-command-to-string rg-command) "\n"))
             (backlink-files (my/org-roam--backlink-files node))
             f row col match)
        (magit-insert-section (unlinked-references)
          (magit-insert-heading "Unlinked References:")
          (dolist (line results)
            (save-match-data
              (when (string-match org-roam-unlinked-references-result-re line)
                (setq f (match-string 1 line)
                      row (string-to-number (match-string 2 line))
                      col (string-to-number (match-string 3 line))
                      match (match-string 4 line))
                (when (and match
                           (not (file-equal-p (org-roam-node-file node) f))
                           (member (downcase match) (mapcar #'downcase titles))
                           (not (member f backlink-files)))  ; Skip files that are already backlinking
                  (magit-insert-section section (org-roam-grep-section)
                                        (oset section file f)
                                        (oset section row row)
                                        (oset section col col)
                                        (insert (propertize (format "%s:%s:%s"
                                                                    (truncate-string-to-width (file-name-base f) 15 nil nil t)
                                                                    row col) 'font-lock-face 'org-roam-dim)
                                                " "
                                                (org-roam-fontify-like-in-org-mode
                                                 (org-roam-unlinked-references-preview-line f row))
                                                "\n"))))))
          (insert ?\n)))))

  (setq org-roam-mode-sections
        (list #'org-roam-backlinks-section
              #'org-roam-reflinks-section
              #'org-roam-unique-unlinked-references-section
              ))
  )

(defun log-org-roam-file-save ()
  "Log the saving of an Org-roam file to a device-specific log file."
  (when (and (eq major-mode 'org-mode)
             (string-prefix-p (expand-file-name org-roam-directory) (expand-file-name buffer-file-name)))
    (let ((log-file (concat org-logs-directory "notes_log_" (system-name) ".txt"))
          (current-time (format-time-string "[%Y-%m-%d %H:%M:%S]"))
          (file-name (buffer-file-name)))
      (with-temp-buffer
        (insert (format "%s Saved file: %s\n" current-time file-name))
        (append-to-file (point-min) (point-max) log-file)))))

(add-hook 'after-save-hook #'log-org-roam-file-save)

(after! org-roam
  (setq org-roam-capture-templates
        '(("d" "Default" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :default:
")
           :immediate-finish t)

          ("r" "Default but open buffer" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS:
")
           :unnarrowed t)

          ("t" "Tagged" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: %^G
")
           :unnarrowed t)

          ("o" "Abstract ON Note " plain "%?"
           :if-new (file+head "on_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :abstract:
")
           :unnarrowed t)

          ("l" "Literature Note " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :literaturenote:%^{definition|theory|course|video|article|library|subject|chapter|topic|research}:%^G
#+REF_URL:
")
           :unnarrowed t)

          ("e" "EHP Note" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :ehp:%^{type|ultra|dragonfly|architecture}:%^G
#+REF_URL:
")
           :unnarrowed t)

          ("b" "Book Review " plain "%?"
           :if-new (file+head "ln_${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :bookreview:
")
           :unnarrowed t)

          ("c" "Composition" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :composition:
")
           :unnarrowed t)

          ;; TODO Manage it later
          ;;           ("m" "Meeting Notes" plain "%?"
          ;;            :if-new (file+head "meet_${slug}.org"
          ;;                               "#+TITLE: ${title}
          ;; #+CREATED_DATE: %T
          ;; #+filetags: :meeting:
          ;; #+ATTENDEES: %^{Attendees}
          ;; #+LOCATION: %^{Location}
          ;; #+START_TIME: %^{Start Time}
          ;; #+END_TIME: %^{End Time}
          ;; ")
          ;;            :unnarrowed t)

          ("p" "Person" plain "%?"
           :if-new (file+head "${slug}.org"
                              "#+TITLE: ${title}
#+FILETAGS: :person:
")
           :unnarrowed t)

          ;; Org roam bibtex template
          ("r" "Bibliography Reference" plain
           (file (concat org-templates-directory "orbreftemplate.org"))
           :if-new
           (file+head "papers/${citekey}.org"
                      "#+title: ${title}
#+FILETAGS: :bibnote:
")
           :unnarrowed t)

          ;; Use this field if necessary #+EXPORT_FILE_NAME: %^{export name}
          ("h" "Blog Post" plain
           "%?"
           :if-new (file+head "blogs/%<%Y%m%d%H%M%S>-${slug}.org" "#+SETUPFILE:../hugo_in_setup.org
#+HUGO_SECTION: ${ai|emacs|neuroscience}
#+HUGO_SLUG: ${slug}
#+HUGO_TAGS:
#+HUGO_CATEGORIES:
#+HUGO_DRAFT: false\n
#+AUTHOR: Alok Regmi
#+FILETAGS: :blog:${filetags}\n
#+TITLE: ${title}
")
           :unnarrowed t)

          ;;           ("j" "paper-description" plain "* Main Contribution \n\n* Your description of significance \n\n* New algorithm or principles\n\n* Simulation Results and Comparisons\n\n* Solid Conclusion"
          ;;            :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
          ;;                               "#+title: ${title}\n#+filetags: paper")
          ;;            :unnarrowed t)

          ;;           ("e" "ref" plain "%?"
          ;;            :if-new (file+head "websites/${slug}.org" "#+SETUPFILE:./hugo_in_setup.org
          ;; ,#+ROAM_KEY: ${ref}#+TITLE: ${title}\n- source :: ${ref}")
          ;;            :unnarrowed t)

          ("k" "private" plain
           "%?" :if-new (file+head "private-${slug}.org"
                                   "#+TITLE: ${title}\n
#+FILETAGS: %^G
")
           :unnarrowed t)

          ("w" "webref" entry "* ${title} ([[${ref}][${hostname}]])\n%?"
           :if-new
           (file+head (concat org-roam-dailies-directory "%<%Y-%m-%d>.org")
                      "#+title: %<%Y-%m-%d %a>
#+FILETAGS: journal
#+STARTUP: overview
")
           :unnarrowed t)
          ))

  (defun my/org-roam-set-created ()
    "Set a CREATED property in the current Org-roam node."
    (when (and (org-roam-buffer-p)
               (not (org-entry-get (point) "CREATED")))
      (org-set-property "CREATED" (format-time-string "[%Y-%m-%d %a %H:%M]"))))

  (add-hook 'org-roam-capture-new-node-hook #'my/org-roam-set-created)
  )

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam ;; or :after org
  ;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
  ;;         a hookable mode anymore, you're advised to pick something yourself
  ;;         if you don't care about startup time, use
  :hook (org-roam . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;;;###autoload
(defun bms/org-roam-rg-search ()
  "Search org-roam directory using consult-ripgrep. With live-preview."
  (interactive)
  (let ((consult-ripgrep-command "rg --null --ignore-case --type org --line-buffered --color=always --max-columns=500 --no-heading --line-number . -e ARG OPTS"))
    (consult-ripgrep org-roam-directory)))

(after! org
  (defun jupyter-python-to-only-python (text backend info)
    "Replace jupyter-python src blocks with python blocks."
    (replace-regexp-in-string "```jupyter-python" "```python" text))
  (add-hook 'org-export-filter-src-block-functions #'jupyter-python-to-only-python))

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

(defun my-org-roam-search (phrase)
  (interactive "sSearch phrase: ")
  (let* ((cmd (format "rg --with-filename --line-number --column --no-heading --color=never -i '%s' %s"
                      phrase org-roam-directory))
         (results (split-string (shell-command-to-string cmd) "\n" t))
         (current-file nil)
         (buffer-name (generate-new-buffer-name "*org-roam-search*")))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (dolist (line results)
        (let* ((parts (split-string line ":"))
               (file (nth 0 parts))
               (linum (string-to-number (nth 1 parts)))
               (content (string-join (nthcdr 3 parts) ":"))
               (id (with-temp-buffer
                     (insert-file-contents file)
                     (goto-char (point-min))
                     (when (re-search-forward "^:ID:[ \t]+\\(.*\\)" nil t)
                       (match-string-no-properties 1)))))
          (when (and id (not (equal current-file file)))
            (setq current-file file)
            (insert (format "\n* File: [[id:%s][%s]]\n" id (file-name-nondirectory file)))
            (insert (make-string (+ 9 (length (file-name-nondirectory file))) ?-))
            (insert "\n"))
          (when id
            (insert (format "- [[file:%s::%d][%4d]]: %s\n" file linum linum content)))))
      (switch-to-buffer-other-window buffer-name)
      (goto-char (point-min))
      (org-mode)
      (read-only-mode 1))))

(defun my-org-open-at-point-in-right-split ()
  (interactive)
  (let ((path (get-text-property (point) 'path))
        (type (get-text-property (point) 'type)))
    (when (string-equal type "file")
      (let* ((file (file-truename (car path)))
             (line (string-to-number (cadr path))))
        (split-window-right)
        (other-window 1)
        (find-file file)
        (goto-char (point-min))
        (forward-line (1- line))))))

(defun insert-org-roam-link ()
  "Insert a Roam link and place the cursor next to the colon.
   If in Evil normal mode, switch to insert mode."
  (interactive)
  (if (and (bound-and-true-p evil-mode)
           (eq evil-state 'normal))
      (evil-insert-state)) ; Switch to insert mode if in normal mode
  (insert "[[roam:")
  (save-excursion
    (insert "]]")))

;;;###autoload
(defun org-roam-dailies-goto-monday-of-week ()
  "Find the daily-note for the Monday of the current week, creating it if necessary."
  (interactive)
  (let* ((now (current-time))
         (decoded (decode-time now))
         (dow (nth 6 decoded))
         (days-back (if (= dow 0) 6 (- dow 1)))
         (monday-time (time-add now (* (- days-back) 86400))))
    (org-roam-dailies--capture monday-time t)))

;; (defun popup-frame-delete (&rest _)
;;   "Kill selected frame if it has parameter `popup-frame'."
;;   (when (frame-parameter nil 'popup-frame))
;;   (delete-frame))

;; (defmacro popup-frame-define (command title &optional delete-frame)
;;   "Define interactive function to call COMMAND in frame with TITLE."
;;   `(defun ,(intern (format "popup-frame-%s" command)) ()
;;      (interactive)
;;      (let* ((display-buffer-alist '(("")
;;                                     (display-buffer-full-frame)))
;;             (frame (make-frame
;;                     '((title . ,title)
;;                       (window-system . ns)
;;                       (popup-frame . t)))))
;;        (select-frame frame)
;;        ;; (switch-to-buffer " popup-frame-hidden-buffer")
;;        (condition-case nil
;;            (progn
;;              (call-interactively ',command)
;;              (delete-other-windows))
;;          (error (delete-frame frame)))
;;        (when ,delete-frame
;;          (sit-for 0.2)
;;          (delete-frame frame)))))


(defun my-org-agenda (&optional p)
  (interactive "P")
  (make-frame '((name . "kai-agenda")))
  (if (+workspace-exists-p "kai-agenda")
      (+workspace/switch-to "kai-agenda")
    (+workspace/new-named "kai-agenda"))
  (sleep-for 1)
  (message "Current major-mode: %s, buffer: %s" major-mode (buffer-name))
  (unless (eq major-mode 'org-agenda-mode)
    (org-agenda "" "k"))
  (org-agenda-redo-all))

(defun my-scratch (&optional p)
  (interactive "P")
  (doom/switch-to-scratch-buffer))

;; (popup-frame-define my-org-agenda "large-popup")
;; (popup-frame-define my-scratch "large-popup")

(defun screenshot-as-file-link ()
  (interactive)
  (org-download-clipboard)
  (run-at-time "0.1 sec" nil
               (lambda ()
                 (forward-line -1)
                 (cpb/convert-attachment-to-file))))

(defun my/org-attach-attach-and-link (file)
  (interactive "fFile to attach: ")
  (let ((filename (file-name-nondirectory file)))
    (org-attach-attach file)
    (insert (format "[[attachment:%s]]" filename))))
(defun my/org-copy-line-as-file-link ()
  "Copy the current line as an org-mode file link with the line content as the search."
  (interactive)
  (let* ((file-path (buffer-file-name))
         (line-content (string-trim (thing-at-point 'line t)))
         ;; Replace [ with \[ and ] with \]
         (escaped-content (replace-regexp-in-string "\\[" "\\\\["
                                                    (replace-regexp-in-string "\\]" "\\\\]" line-content)))
         (org-link (format "[[file:%s::%s]]"
                           (abbreviate-file-name file-path)
                           escaped-content)))
    (kill-new org-link)
    (message "Copied org link: %s" org-link)))

(map! :map org-mode-map
      :after org
      :localleader
      :desc "Attach file with link" "l a" #'my/org-attach-attach-and-link)

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

;; (define-key dirvish-mode-map (kbd "y") #'dirvish-ls-switches-menu)
;; (define-key dirvish-mode-map (kbd "Y") #'dired-mark-empty-dirs)
;; (define-key dirvish-mode-map (kbd "<C-return>") #'dired-find-file-or-do-async-shell-command)
(after! dirvish
  
  (map! (:after dirvish
         :map dirvish-mode-map
         :n "p" #'dirvish-ls-switches-menu
         :n "P" #'dired-mark-empty-dirs))
  (map! :map dired-mode-map
        :localleader
        "b" #'dirvish-history-go-backward
        "f" #'dirvish-history-go-forward
        "n" #'dirvish-narrow
        "m" #'dirvish-mark-menu
        "s" #'dirvish-setup-menu
        "e" #'dirvish-emerge-menu
        "q" #'+dired/quit-all
        "v" #'dirvish-vc-menu
        "f" #'dirvish-fd-menu
        "r" #'dirvish-renaming-menu
        "l" #'dirvish-layout-switch)
  (add-to-list 'dirvish-preview-disabled-exts "parquet")
  (add-to-list 'dirvish-preview-disabled-exts "ipynb")
  (add-to-list 'dirvish-preview-disabled-exts "dmg"))

(after! dirvish
  (setq dirvish-hide-details t)
  (setq! dirvish-quick-access-entries
         `(("h" "~/"                          "Home")
           ("m" ,user-emacs-directory         "Emacs user directory")
           ("e" "~/workspace/EHP/EHP/"        "EHP")
           ("d" "~/Downloads/"                "Downloads")
           ("t" "~/EHPTemp/"                  "Mounted drives")
           ("u" "~/workspace/EHP/Ultra/"      "Ultra")
           ("a" "~/workspace/EHP/Ultra/notebooks/UltraTemp/ModelArtifacts/"       "Ultra Model Artifacts")
           ("o" "~/workspace/EHP/OptAPI/"       "OptAPI")
           )))

(map! (:when (modulep! :ui workspaces)
        :n "s-t"   #'+workspace/new-named
        (:when (featurep :system 'macos)
          :g "s-t"   #'+workspace/new-named)))
(map! :leader
      (:when (modulep! :ui workspaces)
        (:prefix-map ("TAB" . "workspace")
         :desc "New named workspace"       "n"   #'+workspace/new-named
         :desc "New workspace"             "N"   #'+workspace/new)))

(use-package! hackernews
  :defer t)

(use-package elysium
  :defer t
  :custom
  ;; Below are the default values
  (elysium-window-size 0.33) ; The elysium buffer will be 1/3 your screen
  (elysium-window-style 'vertical)) ; Can be customized to horizontal

(map! :g "s-[" #'winner-undo
      :g "s-]" #'winner-redo)

(use-package! copilot-chat)

(after! prodigy
  (prodigy-define-service
   :name "Hugo server"
   :tags '(personal)
   :port 5000
   :command "hugo"
   :args '("server" "-t")
   :cwd "~/workspace/personal/personalblog/"
   :stop-signal 'sigkill
   :kill-process-buffer-on-stop t)

  (prodigy-define-service
   :name "FastAPI Uvicorn with Direnv"
   :tags '(work)
   :command "sh"
   :args '("-c" "direnv exec . uvicorn src.optfastapi.main:app --host 0.0.0.0 --port 8080 --reload")
   :cwd "~/workspace/EHP/OptAPI/"
   :port 8080
   ;; Using this way envrc-reload was only available after opening some code or project, so not using init
   ;; :command "uvicorn"  ; Use shell to run the command
   ;; :args '("src.optfastapi.main:app" "--host" "0.0.0.0" "--port" "8080" "--reload")
   ;; :init (lambda () (envrc-reload))
   )

  (prodigy-define-service
   :name "Jarvisapi"
   :tags '(work)
   :command "sh"
   :args '("-c" "direnv exec . uvicorn src.jarvisfastapi.main:app --host 0.0.0.0 --port 9000 --reload")
   :cwd "~/workspace/EHP/JarvisAPI/"
   :port 9000
   ;; :command "uvicorn"  ; Use shell to run the command
   ;; :args '("src.jarvisfastapi.main:app" "--host" "0.0.0.0" "--port" "9000" "--reload")
   ;; :init (lambda () (envrc-reload))
   )
  )

(use-package dwim-shell-command
  :ensure t)

;; Add lisp directory to load-path
(add-to-list 'load-path (expand-file-name "lisp" doom-user-dir))
;; Core productivity modules
(require 'productivity)
(require 'productivity_flow)
(require 'productivity_addons)
(require 'beancount-helper)
(require 'kairoam-notes)
(require 'booxnoter)
(require 'diary-events)
(require 'qsv-csv)

;; Android-specific toolbar
(when IS-ANDROID
  (require 'android_toolbar))

;;; Taken from https://xenodium.com/building-your-own-bookmark-launcher/
;;;###autoload
(defun browser-bookmarks (org-file)
  "Return all links from ORG-FILE."
  (with-temp-buffer
    (let (links)
      (insert-file-contents org-file)
      (org-mode)
      (org-element-map (org-element-parse-buffer) 'link
        (lambda (link)
          (let* ((raw-link (org-element-property :raw-link link))
                 (content (org-element-contents link))
                 (title (substring-no-properties (or (seq-first content) raw-link))))
            (push (concat title
                          "\n\n"
                          (propertize raw-link 'face 'whitespace-space)
                          "\n\n")
                  links)))
        nil nil 'link)
      (seq-sort 'string-greaterp links))))

;;;###autoload
(defun open-bookmark ()
  (interactive)
  (let ((url (seq-elt (split-string (completing-read "Open: " (browser-bookmarks (concat org-roam-directory "bookmarks.org"))) "\n") 2)))
    (browse-url-firefox url)))

(defun open-random-bookmark ()
  "Open a random bookmark from the bookmarks file."
  (interactive)
  (let* ((bookmarks (browser-bookmarks (concat org-roam-directory "bookmarks.org")))
         (random-bookmark (when bookmarks
                            (seq-random-elt bookmarks))))
    (if random-bookmark
        (let ((url (seq-elt (split-string random-bookmark "\n") 2)))
          (browse-url-firefox url))
      (message "No bookmarks found!"))))

(defun send-to-daily-highlights ()
  "Send selected text to highlights section in today's org-roam daily note with linked subheading."
  (interactive)
  (if (use-region-p)
      (let* ((selected-text-raw (buffer-substring-no-properties (region-beginning) (region-end)))
             ;; Only strip leading whitespace if first line starts with spaces followed by - or +
             (selected-text-clean (if (string-match "^\\s-+[-+]" selected-text-raw)
                                      (replace-regexp-in-string "^\\s-+" "" selected-text-raw)
                                    selected-text-raw))
             (current-buffer-name (buffer-name))
             (is-org-roam (and (derived-mode-p 'org-mode)
                               (org-roam-file-p)))
             ;; Get line number of selection start
             (start-line (line-number-at-pos (region-beginning)))
             ;; Detect if it's a code file
             (is-code-file (and buffer-file-name
                                (not (derived-mode-p 'org-mode))
                                (or (string-match "\\.[a-zA-Z0-9]+$" buffer-file-name))))
             (file-extension (when is-code-file
                               (file-name-extension buffer-file-name)))
             ;; Map common extensions to language names
             (language (when file-extension
                         (cond
                          ((string= file-extension "el") "elisp")
                          ((string= file-extension "py") "python")
                          ((string= file-extension "js") "javascript")
                          ((string= file-extension "ts") "typescript")
                          ((string= file-extension "java") "java")
                          ((string= file-extension "c") "c")
                          ((string= file-extension "cpp") "cpp")
                          ((string= file-extension "h") "c")
                          ((string= file-extension "hpp") "cpp")
                          ((string= file-extension "sh") "bash")
                          ((string= file-extension "rb") "ruby")
                          ((string= file-extension "go") "go")
                          ((string= file-extension "rs") "rust")
                          ((string= file-extension "php") "php")
                          ((string= file-extension "html") "html")
                          ((string= file-extension "css") "css")
                          ((string= file-extension "json") "json")
                          ((string= file-extension "xml") "xml")
                          ((string= file-extension "yaml") "yaml")
                          ((string= file-extension "yml") "yaml")
                          (t file-extension))))
             ;; Format the text appropriately
             (formatted-content (cond
                                 ;; Code file - wrap in src block
                                 (is-code-file
                                  (format "\n#+begin_src %s :eval no\n%s\n#+end_src"
                                          (or language "text")
                                          selected-text-clean))
                                 ;; Already starts with bullet point
                                 ((string-match "^\\s-*[-+]" selected-text-clean)
                                  selected-text-clean)
                                 ;; Regular text - add bullet point
                                 (t (format "- %s" selected-text-clean))))
             (linked-heading (if is-org-roam
                                 (let* ((node (org-roam-node-at-point))
                                        (id (org-roam-node-id node))
                                        (title (org-roam-node-title node)))
                                   (format "[[id:%s][%s]]" id title))
                               ;; For non-org-roam files, include line number
                               (format "[[file:%s::%d][%s]]"
                                       (buffer-file-name)
                                       start-line
                                       (file-name-sans-extension current-buffer-name))))
             (heading-display-name (if is-org-roam
                                       (org-roam-node-title (org-roam-node-at-point))
                                     (file-name-sans-extension current-buffer-name))))

        ;; Get today's daily note file using the public API
        (let ((current-buffer (current-buffer)))
          (org-roam-dailies-goto-today)
          (let ((daily-buffer (current-buffer)))
            ;; Go back to original buffer
            (switch-to-buffer current-buffer)

            ;; Work with daily note in background
            (with-current-buffer daily-buffer
              ;; Find or create highlights section
              (goto-char (point-min))
              (unless (re-search-forward "^\\* Highlights" nil t)
                (goto-char (point-max))
                (insert "\n* Highlights\n"))

              ;; Look for existing subheading
              (let ((subheading-exists nil))
                (save-excursion
                  (when (re-search-forward (format "^\\*\\* .*\\[%s\\]" (regexp-quote heading-display-name)) nil t)
                    (setq subheading-exists t)))

                ;; Add to existing or create new subheading
                (if subheading-exists
                    (progn
                      (re-search-forward (format "^\\*\\* .*\\[%s\\]" (regexp-quote heading-display-name)) nil t)
                      (forward-line 1)
                      ;; Skip to end of this subheading
                      (while (and (not (eobp))
                                  (not (looking-at "^\\*\\* "))
                                  (not (looking-at "^\\* ")))
                        (forward-line 1))
                      (backward-char 1)
                      (insert (format "\n%s" formatted-content)))
                  ;; Create new subheading with link
                  (goto-char (point-max))
                  (insert (format "\n** %s\n%s" linked-heading formatted-content))))

              (save-buffer))))

        (message "Added to daily highlights under '%s'" heading-display-name))
    (message "No text selected")))

(defun org-time-budgets-yesterday-range ()
  "Return the time range (tstart tend) for yesterday from midnight to midnight."
  (let* ((high (decode-time (current-time)))
         (high (list 0 0 0 (nth 3 high) (nth 4 high) (nth 5 high)))
         (high (apply #'encode-time high))
         (yend high)
         (ystart (time-subtract yend (days-to-time 1))))
    (list ystart yend)))

(defun org-time-budgets-format-block-yesterday (block match ystart-s yend-s wstart-s wend-s range-budget)
  "Format a single block for yesterday table."
  (if (null block)
      (make-string 29 ?\s)  ; Approximate width for empty daily column
    (let* ((is-daily (memq block '(day workday)))
           (current (org-time-budgets-time (list :match match
                                                 :tstart (if is-daily ystart-s wstart-s)
                                                 :tend (if is-daily yend-s wend-s))))
           (budget (pcase block
                     ('day (/ range-budget 7))
                     ('workday (/ range-budget 5))
                     ('week range-budget)
                     (_ 0))))
      (if (and current budget)
          (format "[%s] %s / %s"
                  (org-time-budgets-bar 14 current budget)
                  (org-time-budgets-minutes-to-string current)
                  (org-time-budgets-minutes-to-string budget))
        (make-string 29 ?\s)))))

(defun org-time-budgets-table-yesterday ()
  "List the time budgets in a table, with yesterday for daily blocks and this week for weekly blocks."
  (let* ((title-column-width (apply #'max
                                    (mapcar #'(lambda (budget) (string-width (plist-get budget :title)))
                                            org-time-budgets)))
         (w-trange (org-clock-special-range 'thisweek))
         (wstart (nth 0 w-trange))
         (wend (nth 1 w-trange))
         (wstart-s (format-time-string "[%Y-%m-%d]" wstart))
         (wend-s (format-time-string "[%Y-%m-%d]" wend))
         (y-trange (org-time-budgets-yesterday-range))
         (ystart (car y-trange))
         (yend (cadr y-trange))
         (ystart-s (format-time-string "[%Y-%m-%d]" ystart))
         (yend-s (format-time-string "[%Y-%m-%d]" yend)))
    (mapconcat #'(lambda (budget)
                   (let* ((title (plist-get budget :title))
                          (match (or (plist-get budget :match)
                                     (plist-get budget :tags))) ;; support for old :tags syntax
                          (blocks (or (plist-get budget :blocks)
                                      (cl-case (plist-get budget :block) ;; support for old :block syntax
                                        (week '(day week))
                                        (workweek '(workday week)))
                                      '(day week)))
                          (range-budget (org-time-budgets-string-to-minutes (plist-get budget :budget))))
                     (format "%s  %s"
                             (concat
                              title
                              (make-string (max 0 (- title-column-width (string-width title))) ?\s))
                             (mapconcat
                              (lambda (block)
                                (org-time-budgets-format-block-yesterday block match ystart-s yend-s wstart-s wend-s range-budget))
                              blocks
                              "  "))))
               org-time-budgets
               "\n")))

(defun firefox--find-places-sqlite ()
  "Return the first places.sqlite file found in Firefox or Zen Browser profiles."
  (let ((base-dirs
         (list
          ;; macOS
          ;; "~/Library/Application Support/Firefox/Profiles"
          "~/Library/Application Support/zen/Profiles"
          ;; Linux
          "~/.mozilla/firefox"
          ;; Windows
          (substitute-in-file-name "$APPDATA/Mozilla/Firefox/Profiles")
          (substitute-in-file-name "$USERPROFILE/AppData/Roaming/Mozilla/Firefox/Profiles")))
        found-files)
    (dolist (dir base-dirs)
      (when (file-directory-p (expand-file-name dir))
        (let ((files (directory-files-recursively (expand-file-name dir) "places\\.sqlite$")))
          (dolist (file files)
            (when (file-exists-p file)
              (push file found-files))))))
    (if found-files
        (progn
          (message "Found places.sqlite files: %s" found-files)
          (car found-files))
      (error "No places.sqlite files found in Firefox or Zen Browser profiles"))))

(defun firefox--copy-places-sqlite (bookmark-file)
  "Copy BOOKMARK-FILE to a temporary location to avoid database lock."
  (let ((temp-file (make-temp-file "places-sqlite-")))
    (copy-file bookmark-file temp-file t)
    (message "Copied %s to %s" bookmark-file temp-file)
    temp-file))

;;;###autoload
(defun firefox-bookmarks-insert-as-org ()
  "Insert Firefox or Zen Browser bookmarks as org-mode headings."
  (interactive)
  (require 'org)
  (let* ((original-file (firefox--find-places-sqlite))
         (bookmark-file (if original-file
                            (firefox--copy-places-sqlite original-file)
                          (error "No places.sqlite file found")))
         level)
    (message "Using places.sqlite copy: %s" bookmark-file)
    (let ((bookmark-data (firefox--get-bookmarks bookmark-file)))
      (cl-labels ((fn
                    (item)
                    (pcase (plist-get item :type)
                      ("folder"
                       (insert
                        (format "%s %s\n"
                                (make-string level ?*)
                                (or (plist-get item :title) "")))
                       (cl-incf level)
                       (mapc #'fn (plist-get item :children))
                       (cl-decf level))
                      ("url"
                       (when (plist-get item :url)
                         (insert
                          (format "%s %s\n"
                                  (make-string level ?*)
                                  (org-make-link-string
                                   (plist-get item :url)
                                   (or (plist-get item :title) (plist-get item :url))))))))))
        (setq level 1)
        (dolist (root (list (plist-get bookmark-data :menu)
                            (plist-get bookmark-data :toolbar)
                            (plist-get bookmark-data :unfiled)))
          (when root
            (fn root)))))
    ;; Clean up temporary file
    (when (file-exists-p bookmark-file)
      (delete-file bookmark-file))))

(defun firefox--get-bookmarks (bookmark-file)
  "Retrieve Firefox or Zen Browser bookmarks from BOOKMARK-FILE and return as a plist."
  (unless bookmark-file
    (error "No Firefox or Zen Browser places.sqlite file provided"))
  (let* ((sql-query
          "SELECT b.id, b.parent, b.type, b.title, b.position, p.url
           FROM moz_bookmarks b
           LEFT JOIN moz_places p ON b.fk = p.id
           WHERE b.type IN (1, 2) AND b.title IS NOT NULL")
         (temp-file (make-temp-file "firefox-bookmarks-"))
         (escaped-file (shell-quote-argument (expand-file-name bookmark-file)))
         (command (format "sqlite3 -json %s %s > %s"
                          escaped-file
                          (shell-quote-argument sql-query)
                          (shell-quote-argument temp-file)))
         (json-data (progn
                      (message "Executing command: %s" command)
                      (let ((exit-code (shell-command command)))
                        (unless (zerop exit-code)
                          (error "SQLite command failed with exit code %d: %s"
                                 exit-code command)))
                      (with-temp-buffer
                        (insert-file-contents temp-file)
                        (if (> (buffer-size) 0)
                            (json-read-from-string (buffer-string))
                          (error "No data returned from SQLite query: %s" command)))))
         (bookmarks (make-hash-table :test 'equal))
         (root-data (list :menu nil :toolbar nil :unfiled nil)))
    ;; Build bookmark items (normalize vector → list)
    (dolist (row (append json-data nil))
      (let* ((id (alist-get 'id row nil nil #'equal))
             (parent (alist-get 'parent row nil nil #'equal))
             (type (alist-get 'type row nil nil #'equal)) ;; 1 = URL, 2 = folder
             (title (alist-get 'title row nil nil #'equal))
             (position (alist-get 'position row nil nil #'equal))
             (url (alist-get 'url row nil nil #'equal))
             (item (list :id id
                         :parent parent
                         :type (if (= type 2) "folder" "url")
                         :title title
                         :url url
                         :position position
                         :children (when (= type 2) '())
                         :pending-children (when (= type 2) '()))))
        (puthash id item bookmarks)))
    ;; Assign children to folders
    (maphash
     (lambda (_id item)
       (let ((parent (plist-get item :parent)))
         (when (and parent (gethash parent bookmarks))
           (let ((p-item (gethash parent bookmarks)))
             (when (string= (plist-get p-item :type) "folder")
               (push (cons (or (plist-get item :position) 0) _id)
                     (plist-get p-item :pending-children)))))))
     bookmarks)
    ;; Sort and resolve children
    (maphash
     (lambda (_id item)
       (when (plist-get item :pending-children)
         (let ((sorted-pending (sort (plist-get item :pending-children)
                                     (lambda (a b) (< (car a) (car b))))))
           (setf (plist-get item :children)
                 (mapcar (lambda (pos-id)
                           (gethash (cdr pos-id) bookmarks))
                         sorted-pending))
           (setf (plist-get item :pending-children) nil))))
     bookmarks)
    ;; Identify root folders by fixed IDs
    (maphash
     (lambda (_id item)
       (cond
        ((= _id 2) (setf (plist-get root-data :menu) item))
        ((= _id 3) (setf (plist-get root-data :toolbar) item))
        ((= _id 5) (setf (plist-get root-data :unfiled) item))
        ((= _id 6) (setf (plist-get root-data :mobile) item)))) ;; add mobile too
     bookmarks)
    ;; Clean up temp JSON file
    (when (file-exists-p temp-file)
      (delete-file temp-file))
    root-data))

(defvar daily-review-reminder-timer nil "Timer for daily review reminders")
(defvar weekly-review-reminder-timer nil "Timer for weekly review reminders")

(defun daily-review-exists-p ()
  "Check if today's daily review exists in the datetree."
  (let* ((today (decode-time))
         (year (format "%04d" (nth 5 today)))
         (month (format-time-string "%B"))
         (day (format-time-string "%Y-%m-%d")))
    (condition-case nil
        (org-find-olp (list org-dailyreview-file year month day) t)
      (error nil))))

(defun weekly-review-exists-p ()
  "Check if this week's weekly review exists."
  (let* ((week-string (format-time-string "%Y-W%V")))
    (condition-case nil
        (with-current-buffer (find-file-noselect org-weeklyreview-file)
          (goto-char (point-min))
          (search-forward week-string nil t))
      (error nil))))

(defun schedule-next-daily-prompt ()
  "Schedule the next daily review prompt for tomorrow at 8 PM."
  (let* ((now (decode-time))
         (hour (nth 2 now))
         (min (nth 1 now))
         (sec (nth 0 now))
         (current-secs (+ (* hour 3600) (* min 60) sec))
         (secs-to-midnight (- 86400 current-secs))
         (target-secs-from-midnight (* 20 3600)))
    (setq daily-review-reminder-timer
          (run-at-time (+ secs-to-midnight target-secs-from-midnight) nil 'prompt-daily-review))))

(defun schedule-next-weekly-prompt ()
  "Schedule the next weekly review prompt for next Monday at 8 PM."
  (let* ((now (decode-time))
         (dow (nth 6 now))
         (hour (nth 2 now))
         (min (nth 1 now))
         (sec (nth 0 now))
         (days-to-next-monday (mod (+ (- 1 dow) 7) 7))
         (current-secs (+ (* hour 3600) (* min 60) sec))
         (target-secs (* 20 3600))
         (delta (- target-secs current-secs)))
    (setq weekly-review-reminder-timer
          (run-at-time (+ (* days-to-next-monday 86400.0) delta) nil 'prompt-weekly-review))))

(defun prompt-daily-review ()
  "Prompt for daily review with timeout and auto-reschedule."
  (interactive)
  (unless (daily-review-exists-p)
    (let* ((choices '("Today" "Yesterday" "Skip"))
           (timeout-timer (run-with-timer 30 nil (lambda () (throw 'exit :timeout))))
           (choice))
      (unwind-protect
          (condition-case err
              (setq choice (catch 'exit (consult--read choices
                                                       :prompt "Daily review missing. Create for: "
                                                       :require-match t)))
            (quit
             (message "Daily review reminder aborted. Snoozed for 1 hour.")
             (setq daily-review-reminder-timer (run-at-time "1 hour" nil 'prompt-daily-review))))
        (when (timerp timeout-timer)
          (cancel-timer timeout-timer)))
      (cond
       ((eq choice :timeout)
        (message "Daily review reminder timed out. Snoozed for 1 hour.")
        (setq daily-review-reminder-timer (run-at-time "1 hour" nil 'prompt-daily-review)))
       (choice
        (cond
         ((string= choice "Today")
          (org-capture nil "rd"))
         ((string= choice "Yesterday")
          (org-capture nil "ry"))
         ((string= choice "Skip")
          (message "Daily review skipped for today")))
        (schedule-next-daily-prompt))))))

(defun prompt-weekly-review ()
  "Prompt for weekly review with timeout and auto-reschedule."
  (interactive)
  (unless (weekly-review-exists-p)
    (let* ((choices '("This Week" "Last Week" "Skip"))
           (timeout-timer (run-with-timer 30 nil (lambda () (throw 'exit :timeout))))
           (choice))
      (unwind-protect
          (condition-case err
              (setq choice (catch 'exit (consult--read choices
                                                       :prompt "Weekly review missing. Create for: "
                                                       :require-match t)))
            (quit
             (message "Weekly review reminder aborted. Snoozed for 5 hours.")
             (setq weekly-review-reminder-timer (run-at-time "5 hours" nil 'prompt-weekly-review))))
        (when (timerp timeout-timer)
          (cancel-timer timeout-timer)))
      (cond
       ((eq choice :timeout)
        (message "Weekly review reminder timed out. Snoozed for 5 hours.")
        (setq weekly-review-reminder-timer (run-at-time "5 hours" nil 'prompt-weekly-review)))
       (choice
        (cond
         ((string= choice "This Week")
          (org-capture nil "rw"))
         ((string= choice "Last Week")
          (org-capture nil "rl"))
         ((string= choice "Skip")
          (message "Weekly review skipped for this week")))
        (schedule-next-weekly-prompt))))))

(defun start-daily-review-reminders ()
  "Start daily review reminder system."
  (interactive)
  ;; Cancel existing timer if any
  (when daily-review-reminder-timer
    (cancel-timer daily-review-reminder-timer)
    (setq daily-review-reminder-timer nil))

  ;; Check if we should start reminding today
  (let* ((now (decode-time))
         (hour (nth 2 now)))
    (if (>= hour 20)
        ;; After 8 PM, schedule for tomorrow
        (schedule-next-daily-prompt)
      ;; Before 8 PM, schedule for today 8 PM
      (let* ((min (nth 1 now))
             (sec (nth 0 now))
             (current-secs (+ (* hour 3600) (* min 60) sec))
             (target-secs (* 20 3600))
             (secs-to-8pm (- target-secs current-secs)))
        (setq daily-review-reminder-timer (run-at-time secs-to-8pm nil 'prompt-daily-review))))))

(defun start-weekly-review-reminders ()
  "Start weekly review reminder system."
  (interactive)
  ;; Cancel existing timer if any
  (when weekly-review-reminder-timer
    (cancel-timer weekly-review-reminder-timer)
    (setq weekly-review-reminder-timer nil))

  ;; Schedule for next Monday at 8 PM
  (schedule-next-weekly-prompt))

;; Auto-start the reminder systems
(add-hook 'emacs-startup-hook 'start-daily-review-reminders)
(add-hook 'emacs-startup-hook 'start-weekly-review-reminders)

;; Also check periodically in case timers get lost
(run-with-idle-timer 3600 t  ; Check every hour when idle
                     (lambda ()
                       (unless daily-review-reminder-timer
                         (start-daily-review-reminders))
                       (unless weekly-review-reminder-timer
                         (start-weekly-review-reminders))))

(defhydra my/simple-open-link-hydra (:color blue :hint nil :foreign-keys-run t)
  "

   Open Link At Point

"
  ("s" org-open-at-point "Same Window")
  ("v" (lambda () (interactive) (+evil/window-vsplit-and-follow) (org-open-at-point)) "Vertical Split")
  ("h" (lambda () (interactive) (+evil/window-split-and-follow) (org-open-at-point)) "Horizontal Split")
  ("q" nil "Quit"))

(use-package gptel-prompts
  :after (gptel)
  :demand t
  :config
  (setq gptel-prompts-directory "~/.doom.d/llm-system-prompts")
  (gptel-prompts-update)
  ;; Ensure prompts are updated if prompt files change
  (gptel-prompts-add-update-watchers))

(with-eval-after-load 'eat
  (define-key eat-mode-map (kbd "s-p") #'eat-yank)
  (define-key eat-semi-char-mode-map (kbd "s-p") #'eat-yank)
  )

(use-package! claude-code
  :config
  (defun my-claude-notify (title message)
    "Display a macOS notification with sound."
    (call-process "osascript" nil nil nil
                  "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                               message title)))

  (setq claude-code-notification-function #'my-claude-notify)
  (setq claude-code-startup-delay 0.2)
  (setq claude-code-terminal-backend 'vterm)
  (add-hook 'claude-code-start-hook
            (lambda ()
              ;; Reduce line spacing to fix vertical bar gaps
              (setq-local line-spacing 0.1)))
  )

(use-package claude-code-ide
  :config
  ;; (setq claude-code-ide-terminal-backend 'eat)
  (claude-code-ide-emacs-tools-setup)
  ;; (define-key vterm-mode-map (kbd "s-TAB") #'claude-code-ide-menu)
  (define-key prog-mode-map (kbd "s-TAB") #'claude-code-ide-menu)
  (setq claude-code-ide-use-ide-diff nil)
  )

(defun diego--vterm-font-setup ()
  "Configure font settings specifically for vterm buffers, workaround claude-code."

  ;; Apply ASCII replacements for vterm specifically
  (let ((tbl (or buffer-display-table (setq buffer-display-table (make-display-table)))))
    (dolist (pair
             '((#x273B . ?*) ; ✻ TEARDROP-SPOKED ASTERISK
               (#x273D . ?*) ; ✽ HEAVY TEARDROP-SPOKED ASTERISK
               (#x2722 . ?+) ; ✢ FOUR TEARDROP-SPOKED ASTERISK
               (#x2736 . ?+) ; ✶ SIX-POINTED BLACK STAR
               (#x2733 . ?*) ; ✳ EIGHT SPOKED ASTERISK
               ))
      (aset tbl (car pair) (vector (cdr pair))))))

(add-hook 'vterm-mode-hook #'diego--vterm-font-setup)

(defvar sm-subsitutions
  '((?⏺ . ?\-)
    (?· . ?.)
    (?✢ . ?+)
    (?✳ . ?*)
    (?∗ . ?*)
    (?✻ . ?*)
    (?✽ . ?*)
    (?╭ . ?+)
    (?╮ . ?+)
    (?╰ . ?+)
    (?╯ . ?+)
    (?⎿ . ?|)
    (?│ . ?|)
    (?🤖 . ?*)))


(defun sm-replace-problem-chars (args)
  (let ((terminal (nth 0 args))
        (output (nth 1 args)))
    (dolist (sub sm-subsitutions)
      (setq output (subst-char-in-string (car sub) (cdr sub) output)))
    (list terminal output)))


(advice-add 'eat-term-process-output :filter-args #'sm-replace-problem-chars)

;; Customize cursor type in read-only mode (default is '(box nil nil))
;; The format is (CURSOR-ON BLINKING-FREQUENCY CURSOR-OFF)
;; Cursor type options: 'box, 'hollow, 'bar, 'hbar, or nil
(setq claude-code-eat-read-only-mode-cursor-type '(bar nil nil))

;; Control eat scrollback size for longer conversations
;; The default is 131072 characters, which is usually sufficient
;; For very long Claude sessions, you may want to increase it
;; WARNING: Setting to nil (unlimited) is NOT recommended with Claude Code
;; as it can cause severe performance issues with long sessions
(setq eat-term-scrollback-size 500000)  ; Increase to 500k characters
;; Then, add the fonts after your setup is complete:

;; important - tell emacs to use our fontset settings
;; (setq use-default-font-for-symbols nil)
;; (set-fontset-font t 'unicode (font-spec :family "JuliaMono"))

;; ;; your preferred, default font:
;; (set-fontset-font t 'symbol "JuliaMono" nil 'prepend)

(add-hook 'claude-code-start-hook
          (lambda ()
            ;; Reduce line spacing to fix vertical bar gaps
            (setq-local line-spacing 0.1))) 

(custom-set-faces
 '(claude-code-repl-face ((t (:family "JuliaMono")))))

(use-package ai-code-interface
  :config
  (ai-code-set-backend  'claude-code-ide) ;; use claude-code-ide as backend
  ;; Optional: Set up Magit integration for AI commands in Magit popups
  (with-eval-after-load 'magit
    (ai-code-magit-setup-transients)))
(use-package gemini-cli
  :defer t)
(defun my-gemini-notify (title message)
  "Display a macOS notification with sound."
  (call-process "osascript" nil nil nil
                "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                             message title)))

(setq gemini-cli-notification-function #'my-gemini-notify)

(defun claude-switch-accounts ()
  "Toggle between default claude account and the ~/.claude333 account."
  (interactive)
  (if (string-prefix-p "CLAUDE_CONFIG_DIR=" claude-code-ide-cli-path)
      ;; Currently using the alternate account → switch to default
      (progn
        (setq claude-code-ide-cli-path "claude")
        (setq claude-code-program        "claude"))
    ;; Currently using default (or anything else) → switch to alternate
    (progn
      (setq claude-code-ide-cli-path "CLAUDE_CONFIG_DIR=~/.claude333 claude")
      (setq claude-code-program        "CLAUDE_CONFIG_DIR=~/.claude333 claude")))

  (message "Claude CLI now using: %s" claude-code-ide-cli-path))

(use-package! chezmoi
  :defer t
  :config
  (require 'chezmoi-cape)
  (require 'chezmoi-magit)
  (require 'chezmoi-dired)
  (add-to-list 'completion-at-point-functions #'chezmoi-capf)
  (defun chezmoi--evil-insert-state-enter ()
    "Run after evil-insert-state-entry."
    (chezmoi-template-buffer-display nil (point))
    (remove-hook 'after-change-functions #'chezmoi-template--after-change 1))

  (defun chezmoi--evil-insert-state-exit ()
    "Run after evil-insert-state-exit."
    (chezmoi-template-buffer-display nil)
    (chezmoi-template-buffer-display t)
    (add-hook 'after-change-functions #'chezmoi-template--after-change nil 1))

  (defun chezmoi-evil ()
    (if chezmoi-mode
        (progn
          (add-hook 'evil-insert-state-entry-hook #'chezmoi--evil-insert-state-enter nil 1)
          (add-hook 'evil-insert-state-exit-hook #'chezmoi--evil-insert-state-exit nil 1))
      (progn
        (remove-hook 'evil-insert-state-entry-hook #'chezmoi--evil-insert-state-enter 1)
        (remove-hook 'evil-insert-state-exit-hook #'chezmoi--evil-insert-state-exit 1))))
  (add-hook 'chezmoi-mode-hook #'chezmoi-evil)
  )

;;; yabai-windmove.el --- Seamless window management between Emacs and yabai -*- lexical-binding: t; -*-

;; Raptor v3: Unified M-hjkl for Emacs windows AND yabai windows

;;; Window Focus (M-hjkl)
;; Try Emacs windmove first, fall back to yabai

(defun yabai-move-on-error (direction move-fn)
  "Try MOVE-FN for Emacs windows, fall back to yabai DIRECTION on error."
  (condition-case nil
      (funcall move-fn)
    (error
     (let ((cmd (pcase direction
                  ("west"  "window --focus west || window --focus stack.prev")
                  ("east"  "window --focus east || window --focus stack.next")
                  ("north" "window --focus north || window --focus stack.next")
                  ("south" "window --focus south || window --focus stack.prev"))))
       (call-process-shell-command (concat "yabai -m " cmd) nil 0)))))

(defun yabai-window-left ()
  (interactive)
  (yabai-move-on-error "west" #'windmove-left))

(defun yabai-window-right ()
  (interactive)
  (yabai-move-on-error "east" #'windmove-right))

(defun yabai-window-up ()
  (interactive)
  (yabai-move-on-error "north" #'windmove-up))

(defun yabai-window-down ()
  (interactive)
  (yabai-move-on-error "south" #'windmove-down))

;;; Window Swap/Move (M-S-hjkl)
;; Try evil-window-move, fall back to yabai warp

(defun yabai-swap-on-error (direction move-fn)
  "Try MOVE-FN to swap Emacs windows, fall back to yabai warp."
  (if (one-window-p)
      ;; Only one Emacs window, use yabai
      (call-process-shell-command
       (concat "yabai -m window --warp " direction) nil 0)
    ;; Multiple Emacs windows, use evil-window-move
    (funcall move-fn)))

(defun yabai-swap-left ()
  (interactive)
  (yabai-swap-on-error "west" #'evil-window-move-far-left))

(defun yabai-swap-right ()
  (interactive)
  (yabai-swap-on-error "east" #'evil-window-move-far-right))

(defun yabai-swap-up ()
  (interactive)
  (yabai-swap-on-error "north" #'evil-window-move-very-top))

(defun yabai-swap-down ()
  (interactive)
  (yabai-swap-on-error "south" #'evil-window-move-very-bottom))

;;; Toggle Split (M-;)
;; Emacs: cycle window split, yabai: toggle split

(defun yabai-toggle-split ()
  "Toggle window split in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m window --toggle split" nil 0)
    (window-split-toggle)))

;;; Rotate Layout (M-S-i)
;; Emacs: rotate windows, yabai: rotate space

(defun yabai-rotate ()
  "Rotate windows in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m space --rotate 270" nil 0)
    (evil-window-rotate-upwards)))

;;; Zoom Fullscreen (M-f)
;; Emacs: maximize buffer, yabai: zoom-fullscreen

(defun yabai-zoom-fullscreen ()
  "Maximize buffer in Emacs or toggle yabai zoom-fullscreen."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m window --toggle zoom-fullscreen" nil 0)
    (doom/window-maximize-buffer)))

;;; Balance Windows (M-=)
;; Emacs: balance-windows, yabai: space --balance

(defun yabai-balance ()
  "Balance windows in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m space --balance" nil 0)
    (balance-windows)))

;;; Keybindings (Doom Emacs)

(map! :nvm "M-h" #'yabai-window-left
      :nvm "M-l" #'yabai-window-right
      :nvm "M-k" #'yabai-window-up
      :nvm "M-j" #'yabai-window-down

      :nvm "M-H" #'yabai-swap-left
      :nvm "M-L" #'yabai-swap-right
      :nvm "M-K" #'yabai-swap-up
      :nvm "M-J" #'yabai-swap-down

      :nvm "M-;" #'yabai-toggle-split    ;; 0x23 = semicolon
      :nvm "M-I" #'yabai-rotate          ;; M-S-i
      :nvm "M-f" #'yabai-zoom-fullscreen
      :nvm "M-=" #'yabai-balance)

(after! org
  (map!
   :after evil-org
   :map evil-org-mode-map
   :nvm "M-h" #'yabai-window-left
   :nvm "M-l" #'yabai-window-right
   :nvm "M-k" #'yabai-window-up
   :nvm "M-j" #'yabai-window-down)
  )

(after! org
  (evil-define-key '(normal insert visual motion) 'global
    (kbd "M-h") 'yabai-window-left
    (kbd "M-l") 'yabai-window-right
    (kbd "M-k") 'yabai-window-up
    (kbd "M-j") 'yabai-window-down)
  )

(provide 'yabai-windmove)
