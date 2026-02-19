;;; config.el --- Unified Doom Emacs config for Mac, Linux, and Android -*- lexical-binding: t; -*-

;; ============================================================
;; PLATFORM DETECTION
;; ============================================================
(defconst IS-ANDROID (eq system-type 'android)
  "Are we running on Android (Termux)?")

;; Android device detection (POCO phone vs ONYX e-reader)
(defconst IS-ONYX (and IS-ANDROID
                       (boundp 'android-build-fingerprint)
                       (string-prefix-p "ONYX" android-build-fingerprint))
  "Are we running on an Onyx Boox e-reader?")

(defconst IS-POCO (and IS-ANDROID
                       (boundp 'android-build-fingerprint)
                       (string-prefix-p "POCO" android-build-fingerprint))
  "Are we running on a POCO phone?")

;; ============================================================
;; BASIC SETTINGS
;; ============================================================
(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

(setq doom-localleader-key ",")
;; ============================================================
;; FONTS - Platform specific
;; ============================================================
(cond
 (IS-ONYX
  ;; Onyx Boox e-reader - larger fonts for e-ink display
  (setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 30)
        doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :size 36)
        doom-variable-pitch-font (font-spec :family "SpaceMono Nerd Font" :size 40)
        doom-serif-font (font-spec :family "BlexMono Nerd Font" :size 40 :weight 'light)))
 (IS-POCO
  ;; POCO phone - standard Android sizes
  (setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 26)
        doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :size 25)
        doom-variable-pitch-font (font-spec :family "SpaceMono Nerd Font" :size 36)
        doom-serif-font (font-spec :family "BlexMono Nerd Font" :size 36 :weight 'light)))
 (IS-ANDROID
  ;; Fallback for other Android devices (same as POCO)
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
 (IS-ONYX
  ;; Onyx Boox e-reader - modus-operandi is great for e-ink
  (setq doom-theme 'modus-operandi))
 (IS-ANDROID
  ;; Other Android devices (POCO, etc.)
  (if (eq toolkit-theme 'dark )
      (setq doom-theme 'doom-monokai-ristretto)
    (setq doom-theme 'doom-acario-light)))
 (IS-MAC
  (add-hook 'ns-system-appearance-change-functions #'my/apply-theme)
  (setq doom-theme 'doom-gruvbox-light))
 (t
  (setq doom-theme 'doom-gruvbox-light)))

(pixel-scroll-precision-mode)

;; Add lisp directory to load-path early (needed for android-extras and other modules)
(add-to-list 'load-path (expand-file-name "lisp" doom-user-dir))

;; ============================================================
;; ANDROID-SPECIFIC UI SETTINGS
;; ============================================================
(when IS-ANDROID
  (setq +zen-mixed-pitch-modes nil)
  (setq touch-screen-precision-scroll t)
  (setq overriding-text-conversion-style nil)
  (setq tool-bar-position 'bottom)
  (tool-bar-mode 1)

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

;; Separate C-i from TAB (only needed on Mac GUI)
(unless IS-ANDROID
  (define-key input-decode-map [?\C-i] [C-i]))

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
      (setq project-resources-dir "/sdcard/workspace/resources")
      (setq org-directory (expand-file-name "/sdcard/org/"))
      (setq! citar-bibliography '("/sdcard/org/references/articles.bib"))
      (setq! citar-library-paths '("/sdcard/Books/Papers/articles/"))
      (setq org-roam-directory "/sdcard/org/notes/")
      (setq org-agenda-files '("/sdcard/org/agenda/")))
  (progn
    (setq project-resources-dir "~/workspace/resources/")
    (setq org-directory (expand-file-name "~/org/"))
    (setq! citar-bibliography '("~/org/references/articles.bib"))
    (setq! citar-library-paths '("~/Books/Papers/articles/"))
    (setq org-roam-directory "~/org/notes/")
    (setq org-agenda-files '("~/org/agenda/"))))

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

;; ============================================================
;; LOAD LISP MODULES (after essential paths are set)
;; ============================================================

;; Core productivity modules (both Mac and Android)
(require 'org-roam-config)
(require 'productivity)
(require 'productivity_flow)
(require 'productivity_addons)
(require 'beancount-helper)
(require 'kairoam-notes)
(require 'booxnoter)
(require 'notable)
(require 'diary-events)
(require 'qsv-csv)
(require 'org-project-helpers)
(require 'image-workflow)
(require 'review-reminders)
(require 'momentum)

;; Android-specific toolbar
(when IS-ANDROID
  (require 'android-toolbar))

;; Mac-only modules
(unless IS-ANDROID
  (require 'ai-workflows)          ; gptel, claude-code, mcp-hub
  (require 'yabai-windmove)        ; yabai window management
  (require 'chezmoi-config)        ; dotfiles manager
  (require 'prodigy-services)      ; dev server management
  (require 'jupyter-config)        ; Jupyter/EIN notebook support
  (require 'browser-bookmarks))    ; Chrome/Brave bookmark utilities


;; Prevent citar-org-roam from triggering org-roam-db-sync (prevents slow rebuilds)
;; We temporarily make org-roam-db-sync a no-op during citar-org-roam-setup
(when IS-ANDROID
  (after! citar
    ;; Function to open files using browse-url-xdg-open with file:// URLs
    (defun my-open-file-xdg (file)
      "Open FILE using browse-url-xdg-open as a file:// URL."
      (let ((url (concat "file://" (expand-file-name file))))
        (condition-case err
            (browse-url-xdg-open url)
          (error (message "Failed to open %s: %s" file err)))))

    (defun my-citar-relativize-parser (field)
      "Parse FILE-FIELD and relativize paths by removing the fixed base prefix."
      (let ((paths (or (citar-file--parser-default field)
                       (citar-file--parser-triplet field))))
        (when paths
          (mapcar (lambda (p)
                    (string-remove-prefix "/Users/alokregmi/Books/Papers/articles/" p))
                  paths))))

    ;; Prepend custom parser to Citar's parser list
    (setq citar-file-parser-functions
          (cons 'my-citar-relativize-parser
                citar-file-parser-functions))


    ;; Configure Citar to use browse-url-xdg-open for PDFs and images
    (setq citar-file-open-functions
          '(("pdf" . my-open-file-xdg)
            ("jpg" . my-open-file-xdg)
            ("jpeg" . my-open-file-xdg)))

    (bind-key "M-+" 'citar-open-files)
    (bind-key "M--" 'citar-open-notes))
  (defadvice! my/citar-org-roam-setup-no-sync (fn &rest args)
    :around #'citar-org-roam-setup
    (cl-letf (((symbol-function 'org-roam-db-sync) #'ignore))
      (apply fn args)))

  )

;; ============================================================
;; GENERAL SETTINGS
;; ============================================================

(setq show-trailing-whitespace t)
;; (setq frame-title-format '("Kaimacs - %b\n\n"))

(setq display-line-numbers-type 'relative)

(setq org-support-shift-select t)


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

(setq bookmark-default-file (expand-file-name "bookmarks" doom-user-dir))

(after! popup
  (set-popup-rule! "^\\*Python*" :side 'bottom :height 0.3 :quit nil)
  (set-popup-rule! "*WordNut*" :side 'bottom :size .40 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "*Org QL View:*" :side 'right :size 0.3 :select t :quit nil)
  )

(unless IS-ANDROID
  (after! dash-docs
    (setq counsel-dash-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))
    (setq dash-docs-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))))

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

(setq doom-projectile-cache-blacklist `("~" "/tmp" "/" ,(expand-file-name "~/")))
(setq projectile-ignored-projects `(,(expand-file-name "~/") "~/" "/tmp" "~/.emacs.d/.local/straight/repos/"))
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

(require 'nepali-romanized)

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

(unless IS-ANDROID
  (add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode))

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
        :nvm "/" #'hydra-posframe-mode)
  )

(setq lsp-pyright-multi-root nil)

(unless IS-ANDROID
  (use-package numpydoc
    :ensure t
    :bind (:map python-mode-map
                ("C-c C-n" . numpydoc-generate))
    :config
    (setq! numpydoc-insertion-style 'yas)))

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

(unless IS-ANDROID
  (use-package! orgmdb
    :after org
    :config
    (setq orgmdb-omdb-apikey "")))

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

(when (eq system-type 'windows-nt)
  (defun me/bash ()
    (interactive)
    (let ((explicit-shell-file-name "C:/Windows/System32/bash.exe"))
      (shell))))

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

(add-hook! (gfm-mode markdown-mode) #'mixed-pitch-mode)
(add-hook! (gfm-mode markdown-mode) #'visual-line-mode #'turn-off-auto-fill)

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
    (or (mapcar #'abbreviate-file-name recentf-list)
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

(unless IS-ANDROID
  (use-package! org-pandoc-import :after org)
  (add-hook 'magit-mode-hook (lambda () (magit-delta-mode +1))))

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
        (find-file random-file)
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
        (find-file nth-file)
        (message "Opened %d%s largest large note: %s (~%d words, %d bytes)"
                 effective-n (if (= effective-n 1) "st" (if (= effective-n 2) "nd" "th"))
                 (file-name-nondirectory nth-file)
                 (/ size 6) size)))))

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
  )

(use-package! saveplace-pdf-view
  :disabled t)

;;(bind-key "C-M-s-u" 'org-roam-dailies-find-tomorrow)

(bind-key "C-M-s-o" 'bms/org-roam-rg-search)
(bind-key "C-M-s-s" 'basic-save-buffer)
;; (bind-key "C-M-s-j" 'scroll-other-window-down)
;; (bind-key "C-M-s-k" 'scroll-other-window)
(bind-key "C-M-s-~" '+python/open-ipython-repl)
(bind-key "C-s-~" '+popup/toggle)
(bind-key "C-s-t" '+vterm/here)  ; Changed from C-s-t (now used for rts-flow-select-task)
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
(bind-key "C-s-'" 'open-random-bookmark)  ; Changed from C-s-a (now used for rts-flow-add)
(bind-key "C-s-d" 'today)  ; Changed from C-s-u (D = Day/today)
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
(bind-key "C-s-v" 'yank-from-kill-ring)
;; (bind-key "C-M-s-$" 'winum-select-window-4)
;; (bind-key "C-M-s-%" 'winum-select-window-5)
;; scroll other window, useful when working with multiple files
(bind-key "C-M-s-n" 'scroll-other-window-down)
(bind-key "C-M-s-e" 'scroll-other-window)
;; (bind-key "C-M-s-:" 'newline-and-indent)
;; (bind-key "C-M-s-w" 'winner-undo)
(unless IS-ANDROID
  (bind-key "C-M-s-c" 'screenshot-as-file-link))
;; last set of key bindings
(bind-key "C-M-s-g" 'clock-out-and-mark-current-todo-done)
;;; ===================================================================
;;; RTS-FLOW Keybindings (Mnemonic)
;;; ===================================================================
;; Core Flow Commands
(define-key global-map (kbd "C-s-n") #'rts-flow)              ; F = Flow (pick new task)
(define-key global-map (kbd "C-M-s-w") #'rts-flow)              ; F = Flow (pick new task)
(define-key global-map (kbd "C-s-y") #'rts-flow-continue)     ; R = Resume last task
(define-key global-map (kbd "C-s-l") #'rts-flow-cancel)       ; X = cancel/undo selection
(define-key global-map (kbd "C-s-h") #'rts-flow-manual)       ; M = Manual clock-in (consult)
(define-key global-map (kbd "C-M-s-%") #'rts-flow-manual)          ; A = Add task/beancount/time
(define-key global-map (kbd "C-s-d") #'rts-flow-clock-out)    ; Q = Quit/clock out
(define-key global-map (kbd "C-s-g") #'rts-flow-clock-goto)   ; G = Goto clocked task
(define-key global-map (kbd "C-M-s-g") #'rts-flow-clock-goto)   ; G = Goto clocked task
(define-key global-map (kbd "C-s-+") #'rts-flow-add)          ; A = Add task/beancount/time
(define-key global-map (kbd "C-M-s-$") #'rts-flow-add)          ; A = Add task/beancount/time
(define-key global-map (kbd "C-M-s-+") #'rts-flow-add)          ; A = Add task/beancount/time
(define-key global-map (kbd "C-s-_") #'rts-flow-set-state)    ; S = State (context + energy)
;; Direct Selectors (for specific activity types)
;; (define-key global-map (kbd "C-s-t") #'rts-flow-select-task)    ; T = Task
;; (define-key global-map (kbd "C-s-b") #'rts-flow-select-book)    ; B = Book
;; (define-key global-map (kbd "C-s-y") #'rts-flow-select-study)   ; Y = studY
;; (define-key global-map (kbd "C-s-u") #'rts-flow-select-music)   ; U = mUsic (guitar/piano)
;; (define-key global-map (kbd "C-s-l") #'rts-flow-select-leisure) ; L = Leisure
;; (define-key global-map (kbd "C-s-n") #'rts-flow-select-notes)   ; N = Notes (org-roam)
;; Kairoam Window Management
(define-key global-map (kbd "C-s-o") #'kairoam-toggle)           ; O = On/Off toggle
(define-key global-map (kbd "C-s-e") #'kairoam-toggle-size)      ; E = Expand/fold toggle
(define-key global-map (kbd "C-s-;") #'kairoam-open-note-to-right)

;; Utilities
(define-key global-map (kbd "C-s-?") #'my-org-roam-search)
(define-key global-map (kbd "C-s-p") #'send-to-daily-highlights) ; P = Post to highlights

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
       :n "D" (if IS-ANDROID #'ignore #'dash-docs-activate-docset)
       :n "f" #'sp-forward-sexp)
      (:prefix "z"
       :n "a" #'unpackaged/iedit-or-flyspell
       :n "w" #'change-env-and-restart-lsp
       :n "h" #'unpackaged/org-outline-numbers
       :n "f" #'auto-fill-mode
       :n "j" (if IS-ANDROID #'ignore #'grab-x-link-firefox-insert-org-link)
       :n "b" (if IS-ANDROID #'ignore #'grab-x-link-brave-insert-org-link))
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
       :n "o" (if IS-ANDROID #'ignore #'org-noter)
       :n "c" (if IS-ANDROID #'ignore #'org-noter-pdftools-create-skeleton)
       :n "j" #'org-hugo-auto-export-mode
       :n "p" #'poetry
       :n "r" #'poetry-run
       :n "d" #'scimax-dired/body)
      )

(unless IS-ANDROID
  (setq scihub-homepage "https://sci-hub.st"
        scihub-download-directory "~/pdfs"
        scihub-open-after-download nil))

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
         ))


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
  (setq org-agenda-tags-column 40)
  (setq org-agenda-buffer-name "kai-agenda")
  (setq org-tags-column 40)
  (setq org-agenda-start-with-log-mode t)
  (setq org-columns-default-format "%40ITEM(Task) %Effort(EE){:} %CLOCKSUM(Time Spent) %SCHEDULED(Scheduled) %DEADLINE(Deadline) %TAGS")
  (setq org-tags-exclude-from-inheritance '("project"))
  ;; (setq org-agenda-sorting-strategy
  ;;       '((agenda time-up) (todo time-up) (tags time-up) (search time-up)))
  ;; (setq org-agenda-sorting-strategy
  ;;       '((agenda time-up timestamp-up priority-down)
  ;;         (todo priority-down category-keep)
  ;;         (tags priority-down category-keep)
  ;;         (search category-keep)))

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
                                      (org-agenda-sorting-strategy '(time-up priority-down effort-down))
                                      )
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
        org-export-with-properties nil
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
  ;; org-download-image-dir "~/org/org-images/"
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

(defun my-org-agenda (&optional p)
  (interactive "P")
  (unless IS-ANDROID
    (make-frame '((name . "kai-agenda"))))
  (if (+workspace-exists-p "kai-agenda")
      (+workspace/switch-to "kai-agenda")
    (+workspace/new-named "kai-agenda"))
  (unless IS-ANDROID
    (sleep-for 1))
  (message "Current major-mode: %s, buffer: %s" major-mode (buffer-name))
  (unless (eq major-mode 'org-agenda-mode)
    (org-agenda "" "k"))
  (org-agenda-redo-all))

(defun my-scratch (&optional p)
  (interactive "P")
  (doom/switch-to-scratch-buffer))

;; (popup-frame-define my-org-agenda "large-popup")
;; (popup-frame-define my-scratch "large-popup")

(unless IS-ANDROID
  (defun screenshot-as-file-link ()
    (interactive)
    (org-download-clipboard)
    (run-at-time "0.1 sec" nil
                 (lambda ()
                   (forward-line -1)
                   (cpb/convert-attachment-to-file)))))

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

(map! :g "s-[" #'winner-undo
      :g "s-]" #'winner-redo)

(unless IS-ANDROID
  (use-package dwim-shell-command
    :ensure t))

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

(defhydra my/simple-open-link-hydra (:color blue :hint nil :foreign-keys-run t)
  "
   Open Link At Point
"
  ("s" org-open-at-point "Same Window")
  ("v" (lambda () (interactive) (+evil/window-vsplit-and-follow) (org-open-at-point)) "Vertical Split")
  ("h" (lambda () (interactive) (+evil/window-split-and-follow) (org-open-at-point)) "Horizontal Split")
  ("q" nil "Quit"))
