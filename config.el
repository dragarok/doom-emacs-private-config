;; (add-to-list 'default-frame-alist '(undecorated . t))

(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(setq delete-by-moving-to-trash t)

(setq doom-localleader-key ",")

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")

(setq gc-cons-threshold 4073741824 )

(setq org-roam-directory "~/Dropbox/org/notes")

(setq doom-scratch-buffer-major-mode t)
(setq show-trailing-whitespace t)

(setq doom-font (font-spec :family "Cascadia Code" :size 18)
      doom-variable-pitch-font (font-spec :family "Iosevka NF" :size 18)
      ;; doom-variable-pitch-font (font-spec :family "Iosevka Etoile" :size 18)
      doom-serif-font (font-spec :family "Microsoft Sans Serif" :size 18)
      ;; doom-variable-pitch-font (font-spec :family "Source Serif Pro" :size 22)
      ;; doom-serif-font (font-spec :family "Source Serif Pro" :weight 'light)
      doom-big-font (font-spec :family "SpaceMono NF" :size 22))

(load-theme 'modus-operandi 'noconfirm)


(after! evil

  ;; Mapping
  ;; Vim ==> Colemak Mine
  ;; j ==> n
  ;; k ==> e
  ;; l ==> i
  ;; i ==> l
  ;; n ==> k
  ;; e ==> j
  (map! :n "l" 'evil-insert
        :n "L" 'evil-insert-line
        :nv "k" 'evil-ex-search-next
        :nv "K" 'evil-ex-search-previous
        :nvm "j" 'evil-forward-word-end
        :nvm "J" 'evil-forward-word-end
        :nv "N" 'evil-join
        :nvm "n" 'evil-next-line
        :nvm "e" 'evil-previous-line
        :nvm "E" '+lookup/documentation
        :nvm "i" 'evil-forward-char
        :nvm "I" 'evil-window-bottom
        :nv "gI" 'evil-lion-left
        :nv "gi" 'evil-lion-right
        :nv "gl" 'evil-insert-resume
        :nv "gL" '+lookup/implementations
        :nv "gj" 'evil-backward-word-end
        :nv "gJ" 'evil-backward-WORD-end
        :nv "gE" 'evil-join-whitespace
        :nv "ge" 'evil-next-visual-line
        :nv "gk" 'evil-next-match
        :nv "gK" 'evil-previous-match
        :nv "gn" 'evil-previous-visual-line
        :nv "gN" nil
        :n "zn" '+fold/next
        :n "ze" '+fold/previous
        :n "zE" 'nil
        :n "zD" 'vimish-fold-delete-all
        :n "zi" 'evil-scroll-column-right
        :n "zI" 'evil-scroll-right
        :nv "zk" '+evil:narrow-buffer
        :n "zK" 'doom/widen-indirectly-narrowed-buffer
        )

  (map! :leader
        (:prefix "w"
         :n "J" nil
         :n "n" #'evil-window-down
         :n "e" #'evil-window-up
         :n "i" #'evil-window-right
         :n "N" #'+evil/window-move-down
         :n "E" #'+evil/window-move-up
         :n "I" #'+evil/window-move-right
         :n "C-n" #'evil-window-down
         :n "C-e" #'evil-window-up
         :n "C-i" #'evil-window-right
         ;; Not losing keybinding for C-n
         :n "C-j" #'evil-window-new
         :n "j" #'evil-window-new
         :n "C-S-n" #'evil-window-move-very-bottom
         :n "C-S-e" #'evil-window-move-very-top
         :n "C-S-i" #'evil-window-move-far-right)
        (:prefix "c")
        :n "F" #'consult-flycheck
        :n "T" #'lsp-treemacs-symbols
        )
  )


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
      )

;; (if (not window-system)
;;     (setq doom-theme 'doom-))

(pixel-scroll-precision-mode)

;; ascii art taken from https://www.asciiart.eu/space/telescopes (Telescope by Dokusan)
;; (defun doom-dashboard-widget-banner ()
;;   (let ((point (point)))
;;     (mapc (lambda (line)
;;             (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
;;                                 'face 'bold))
;;             (insert "\n"))
;;           '("             _              "
;;             "           /(_))            "
;;             "         _/   /
;;             "        //   /              "
;;             "       //   /               "
;;             "      /\\__/                "
;;             "      \\O_/=-0             "
;;             "  _  /|| \\              "
;;             "   \\\\/()_) \\.              "
;;             "  ^^  <__> \\()             "
;;             "    //||\\\\              "
;;             "     //_||_\\\\               "
;;             "    // \\||/ \\\\              "
;;             "   //   ||   \\\\             "
;;             "  \\/    |/    \\/            "
;;             "  /     |      \\            "
;;             " /      |       \\           "
;;             "        |                   "
;;             "-----LIGHT-----            "))
;;     (when (and (display-graphic-p)
;;                (stringp fancy-splash-image)
;;                (file-readable-p fancy-splash-image))
;;       (let ((image (create-image (fancy-splash-image-file))))
;;         (add-text-properties
;;          point (point) `(display ,image rear-nonsticky (display)))
;;         (save-excursion
;;           (goto-char point)
;;           (insert (make-string
;;                    (truncate
;;                     (max 0 (+ 1 (/ (- +doom-dashboard--width
;;                                       (car (image-size image nil)))
;;                                    2))))
;;                    ? ))))
;;       (insert (make-string (or (cdr +doom-dashboard-banner-padding) 0)
;;                            ?\n)))))

(setq display-line-numbers-type 'relative
      writeroom-extra-line-spacing 0.3
      )

(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

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

(setq org-support-shift-select t)

(setq bookmark-default-file "~/.doom.d/bookmarks")

(use-package anki-editor
  :after org
  :bind (:map org-mode-map
         ("<f12>" . anki-editor-cloze-region-auto-incr)
         ("<f11>" . anki-editor-cloze-region-dont-incr)
         ("<f10>" . anki-editor-reset-cloze-number)
         ("<f9>"  . anki-editor-push-tree))
  :hook (org-capture-after-finalize . anki-editor-reset-cloze-number) ; Reset cloze-number after each capture.
  :config
  (setq anki-editor-create-decks t ;; Allow anki-editor to create a new deck if it doesn't exist
        anki-editor-org-tags-as-anki-tags t)

  (defun anki-editor-cloze-region-auto-incr (&optional arg)
    "Cloze region without hint and increase card number."
    (interactive)
    (anki-editor-cloze-region my-anki-editor-cloze-number "")
    (setq my-anki-editor-cloze-number (1+ my-anki-editor-cloze-number))
    (forward-sexp))
  (defun anki-editor-cloze-region-dont-incr (&optional arg)
    "Cloze region without hint using the previous card number."
    (interactive)
    (anki-editor-cloze-region (1- my-anki-editor-cloze-number) "")
    (forward-sexp))
  (defun anki-editor-reset-cloze-number (&optional arg)
    "Reset cloze number to ARG or 1"
    (interactive)
    (setq my-anki-editor-cloze-number (or arg 1)))
  (defun anki-editor-push-tree ()
    "Push all notes under a tree."
    (interactive)
    (anki-editor-push-notes '(4))
    (anki-editor-reset-cloze-number))
  ;; Initialize
  (anki-editor-reset-cloze-number)
  )

(after! org
    (add-to-list 'org-capture-templates
          '("a" "Anki basic"
           entry
           (file+headline org-my-anki-file "Dispatch")
           "* %<%H:%M>\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Basic\n:ANKI_DECK: Mega\n:END:\n** Front\n%?\n** Back\n")))


(after! org
    (add-to-list 'org-capture-templates
          '("A" "Anki cloze"
           entry
           (file+headline org-my-anki-file "Dispatch")
           "* %<%H:%M>\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Cloze\n:ANKI_DECK: Mega\n:END:\n** Text\n** Extra\n")))

(after! org
  (autoload 'orch-toggle "orch" nil t))

(after! dash-docs
  (setq counsel-dash-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas"))
  (setq dash-docs-docsets '("Numpy" "SciPy" "R" "Julia" "Python 3" "Matplotlib" "Typescript" "Pandas")))

(setq projectile-ignored-projects '("~/" "/tmp" "~/.emacs.d/.local/straight/repos/"))
(defun projectile-ignored-project-function (filepath)
  "Return t if FILEPATH is within any of `projectile-ignored-projects'"
  (or (mapcar (lambda (p) (s-starts-with-p p filepath)) projectile-ignored-projects)))

(global-set-key (kbd "<f6>") 'spray-mode)

(use-package spray
  ;; :commands (spray-faster spray-slower)
  :defer t
  :config
  :bind (:map spray-mode-map
         ("s-7" . spray-faster)
         ("s-8" . spray-slower)
         ("s-9" . spray-start/stop)
         ("s-0" . spray-quit)
         )
  )

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

(add-hook 'dired-mode-hook
          (lambda ()
            (dired-hide-details-mode)))

(use-package dired-subtree
  :after dired
  :config
  (setq dired-subtree-use-backgrounds nil)
  :bind (:map dired-mode-map
              ("<tab>" . dired-subtree-toggle)
              ("<C-tab>" . dired-subtree-cycle)
              ("<S-iso-lefttab>" . dired-subtree-remove)))

(use-package gif-screencast
  :defer t
  :bind
  ("<C-print>" . gif-screencast-start-or-stop)
  :config
  (setq gif-screencast-output-directory (expand-file-name "images/gif-screencast" org-directory)))

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

(add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode)

(after! org
  (setq org-highlight-latex-and-related '(native script entities)))

(after! ess
  (set-popup-rule! "^\\*R:" :ignore t))

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

(setq +python-ipython-repl-args '("-i" "--simple-prompt" "--no-color-info"))
(setq +python-jupyter-repl-args '("--simple-prompt"))

;; Roam id reference giving hash-table error
(defun my/org-id-update-org-roam-files ()
  "Update Org-ID locations for all Org-roam files."
  (interactive)
  (org-id-update-id-locations (org-roam--list-all-files)))

(defun my/org-id-update-id-current-file ()
  "Scan the current buffer for Org-ID locations and update them."
  (interactive)
  (org-id-update-id-locations (list (buffer-file-name (current-buffer)))))

;; Borrowed from http://postmomentum.ch/blog/201304/blog-on-emacs

(use-package! dirvish
  :config
  (require 'dirvish-peek)
  (require 'dirvish-extras))

(use-package! powershell
  :config
  )

;; (after! org
;; (require 'org-capture)
;; (require 'org-protocol)

;;; Org Capture
;;;; Thank you random guy from StackOverflow
;;;; http://stackoverflow.com/questions/23517372/hook-or-advice-when-aborting-org-capture-before-template-selection

;; (defadvice org-capture
;;     (after make-full-window-frame activate)
;;   "Advise capture to be the only window when used as a popup"
;;   (if (equal "emacs-capture" (frame-parameter nil 'name))
;;       (delete-other-windows)))

;; (defadvice org-capture-finalize
;;     (after delete-capture-frame activate)
;;   "Advise capture-finalize to close the frame"
;;   (if (equal "emacs-capture" (frame-parameter nil 'name))
;;       (delete-frame)))
;; )

(after! org

  (lambda () (progn
          (setq left-margin-width 2)
          (setq right-margin-width 2)
          (set-window-buffer nil (current-buffer))))

  (setq org-startup-indented t
        org-superstar-headline-bullets-list '(" ")
        org-hide-leading-stars t
        org-ellipsis "  " ;; folding symbol
        org-hide-emphasis-markers t ;; show actually italicized text instead of /italicized text/
        org-agenda-block-separator ""
        org-fontify-whole-heading-line t
        org-fontify-done-headline t
        org-fontify-quote-and-verse-blocks t)

  ;;(setq global-org-pretty-table-mode t)
  (custom-set-faces!
    '(outline-1 :weight extra-bold :height 1.25)
    '(outline-2 :weight bold :height 1.15)
    '(outline-3 :weight bold :height 1.12)
    '(outline-4 :weight semi-bold :height 1.09)
    '(outline-5 :weight semi-bold :height 1.06)
    '(outline-6 :weight semi-bold :height 1.03)
    '(outline-8 :weight semi-bold)
    '(outline-9 :weight semi-bold)
    '(org-link :weight bold :height 1.1 :underline t)
    '(org-document-info :foreground "dark orange")
    '(hydra-posframe-border-face :background "OrangeRed3")
    '(org-done :strike-through t :weight bold)
    '(org-headline-done :strike-through t)
    '(org-code :inherit (fixed-pitch shadow) :height 1.1)
    '(org-verbatim :inherit shadow)
    '(org-block :inherit (fixed-pitch shadow) :background nil :height 1.2)
    '(org-block-begin-line :inherit region  :background nil :height 0.9)
    '(org-block-end-line :inherit region :background nil :height 0.8)
    '(org-document-title :height 1.2 :weight normal :underline nil)
    ;; '(org-document-info :height 1.2 :slant italic)
    '(org-document-info-keyword :inherit shadow :height 0.8)
    '(org-meta-line :inherit (font-lock-comment-face fixed-pitch) :foreground "dark orange")
    '(org-property-value :inherit fixed-pitch)
    '(org-special-keyword :inherit (font-lock-comment-face fixed-pitch))
    '(org-table :inherit fixed-pitch :foreground "#83a598")
    '(org-tag :inherit (shadow fixed-pitch) :weight bold :height 1.1)
    '(org-block :inherit fixed-pitch)
    '(org-ellipsis :underline nil)
    '(org-agenda-date :height 1.1 :background nil)
    '(org-agenda-date-today :height 1.2 :background nil)
    '(org-table :inherit fixed-pitch-serif :height 0.9)
    '(vterm-color-black :foreground "OrangeRed3" :background "BlueViolet")
    )
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

;; (use-package! clip2org
;;   :defer t)
;; (require 'clip2org)
;; (setq clip2org-clippings-file "~/scratch/kindle-clippings-manager/Myelse/My Clippings (3).txt")

(use-package! page-break-lines
  :config
  (global-page-break-lines-mode))

;; (require 'mpdel)

(defvar *buffer-layouts* (list) "Buffer-layout associations")
(defvar *protect-buffer-layouts* nil "Temporarily protect buffer layouts")
(defun restore-buffer-layout ()
  "Restore the layout associated with the current buffer."
  (interactive)
  (let ((conf (alist-get (current-buffer) *buffer-layouts*)))
    (if conf
	(progn
	  (set-window-configuration conf)
	  (message "Restored buffer layout"))
      (setf (alist-get (current-buffer) *buffer-layouts*)
	    (current-window-configuration))
      (message "Set buffer layout"))))

(defun switch-to-buffer-with-layout ()
  "Switch to the window layout associated with a buffer. At the
same time, associate the original buffer with the original
layout.

If the new buffer has no associated layout, it is displayed as
the only window in the frame."
  (interactive)
  (let ((*protect-buffer-layouts* t))
    (dolist (window (window-list))
      (setf (alist-get (window-buffer window) *buffer-layouts*)
	    (current-window-configuration)))
    (call-interactively #'consult-buffer)
    (delete-other-windows)
    (let* ((buf (current-buffer))
	   (conf (alist-get buf *buffer-layouts*)))
      (when conf
	(set-window-configuration conf)
	(select-window (get-buffer-window buf))))))

(advice-add #'delete-other-windows :before
	    (lambda (&optional window)
	      (when (not *protect-buffer-layouts*)
		(dolist (window (window-list))
		  (setf (alist-get (window-buffer window) *buffer-layouts*) nil)))))
(advice-add #'delete-window :before
	    (lambda (&optional window)
	      (when (not window)
		(setq window (get-buffer-window)))
	      (when (not *protect-buffer-layouts*)
		(setf (alist-get (window-buffer window) *buffer-layouts*) nil))))
(advice-add #'quit-window :before
	    (lambda (&optional kill window)
	      (when (not window)
		(setq window (get-buffer-window)))
	      (when (not *protect-buffer-layouts*)
		(setf (alist-get (window-buffer window) *buffer-layouts*) nil))))

(bind-key "C-M-s-v" 'switch-to-buffer-with-layout)
(bind-key "C-M-s-V" 'restore-buffer-layout)
()
;; (bind-key "RET" 'unpackaged/org-return-dwim)

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


(defun my/resolve-orgzly-autosync ()
  (interactive)
  (kai/autosync-resolve-conflicts "~/Dropbox/org/notes"))

(defun kai/autosync-resolve-conflicts (directory)
  "Resolve all conflicts under given DIRECTORY."
  (interactive "D")
  (let* ((all (kai/autosync--get-sync-conflicts directory))
         (chosen (kai/autosync--pick-a-conflict all)))
    (kai/autosync-resolve-conflict chosen)))

(defun kai/autosync-show-conflicts-dired (directory)
  "Open dired buffer at DIRECTORY showing all autosync conflicts."
  (interactive "D")
  (find-name-dired directory "*\\(conflict*"))

(defun kai/autosync-resolve-conflict-dired (&optional arg)
  "Resolve conflict of first marked file in dired or close to point with ARG."
  (interactive "P")
  (let ((chosen (car (dired-get-marked-files nil arg))))
    (kai/autosync-resolve-conflict chosen)))

(defun kai/autosync-resolve-conflict (conflict)
  "Resolve CONFLICT file using ediff."
  (let* ((normal (kai/autosync--get-normal-filename conflict)))
    (message normal)
    (kai/ediff-files
     (list conflict normal)
     `(lambda ()
        (when (y-or-n-p "Delete conflict file? ")
          (kill-buffer (get-file-buffer ,conflict))
          (delete-file ,conflict))))))

(defun kai/autosync--get-sync-conflicts (directory)
  "Return a list of all sync conflict files in a DIRECTORY."
  (directory-files-recursively directory "\\(conflict*\\)"))

(defvar kai/autosync--conflict-history nil
  "Completion conflict history")

(defun kai/autosync--pick-a-conflict (conflicts)
  "Let user choose the next conflict from CONFLICTS to investigate."
  (completing-read "Choose the conflict to investigate: " conflicts
                   nil t nil kai/autosync--conflict-history))


(defun kai/autosync--get-normal-filename (conflict)
  "Get non-conflict filename matching the given CONFLICT."
  (replace-regexp-in-string " \(conflict.*\)" "\\1" conflict))


(defun kai/ediff-files (&optional files quit-hook)
  (interactive)
  (lexical-let ((files (or files (dired-get-marked-files)))
                (quit-hook quit-hook)
                (wnd (current-window-configuration)))
    (if (<= (length files) 2)
        (let ((file1 (car files))
              (file2 (if (cdr files)
                         (cadr files)
                       (read-file-name
                        "file: "
                        (dired-dwim-target-directory)))))
          (if (file-newer-than-file-p file1 file2)
              (ediff-files file2 file1)
            (ediff-files file1 file2))
          (add-hook 'ediff-after-quit-hook-internal
                    (lambda ()
                      (setq ediff-after-quit-hook-internal nil)
                      (when quit-hook (funcall quit-hook))
                      (set-window-configuration wnd))))
      (error "no more than 2 files should be marked"))))

;; ;; WHen ediff always expand org mode files
;; (with-eval-after-load 'outline
;;   (add-hook 'ediff-prepare-buffer-hook #'org-show-all))

(use-package consult-dir
  :ensure t
  :config
  (setq consult-dir-project-list-function #'consult-dir-projectile-dirs)
  :bind (("C-x C-d" . consult-dir)
         :map vertico-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file)))

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
  "Go to the task under point, mark it done, return back, and update in roam-dailies"
  (interactive)
  (save-excursion
    (link-hint-open-link-at-point)
    (org-todo 'done)
    (save-buffer)
    (org-mark-ring-goto)
    (org-toggle-checkbox)
    ))

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

(add-hook! (gfm-mode markdown-mode) #'mixed-pitch-mode)
(add-hook! (gfm-mode markdown-mode) #'visual-line-mode #'turn-off-auto-fill)

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

(add-hook 'yaml-mode-hook
          (lambda ()
            (define-key yaml-mode-map "\C-m" 'newline-and-indent)))

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

;; Add properties to generic stuffs
(defun nm/org-clarify-properties ()
  "Clarify properties for task."
  (interactive)
  (let ((my-list nm/org-clarify-templates)
        (my-temp nil))
    (dolist (i my-list) (push (car i) my-temp))
    (dolist (i (cdr (assoc (consult-completing-read-multiple "template: " my-temp) nm/org-clarify-templates))) (org-entry-put nil i (consult-completing-read-multiple (format "%s: " i) (delete-dups (org-map-entries (org-entry-get nil i nil) nil 'file)))))))

(setq nm/org-clarify-templates '(("book" "AUTHOR" "YEAR" "SOURCE")
                                 ("online" "SOURCE" "SITE" "AUTHOR")
                                 ("purchase" "WHY" "FUNCTION")
                                 ("task" "AREA")
                                 ("project" "GOAL" "DUE")
                                 ("article" "SOURCE" "SITE" "SUBJECT")))

(use-package! org-pandoc-import :after org)

;;(add-hook 'magit-mode-hook (lambda () (magit-delta-mode +1)))

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

(defun +my/vterm-run-project ()
  (interactive)
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

(require 'nepali-romanized)

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
      "nohup 1>/dev/null 2>/dev/null %s \"%s\""
      (if (and (> (length file-list) 1)
               (setq list-switch
                     (cadr (assoc cmd dired-filelist-cmd))))
          (format "%s %s" cmd list-switch)
        cmd)
      (mapconcat #'expand-file-name file-list "\" \"")))))
(define-key dired-mode-map "r" 'dired-start-process)

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

(defun my/vterm-execute-current-line ()
  "Insert text of current line in vterm and execute."
  (interactive)
  (require 'vterm)
  (let ((command (buffer-substring
                  (save-excursion
                    (beginning-of-line)
                    (point))
                  (save-excursion
                    (end-of-line)
                    (point)))))
    (let ((buf (current-buffer)))
      (unless (get-buffer vterm-buffer-name)
        (vterm))
      (display-buffer vterm-buffer-name t)
      (switch-to-buffer-other-window vterm-buffer-name)
      (vterm--goto-line -1)
      (message command)
      (vterm-send-string command)
      (vterm-send-return)
      (switch-to-buffer-other-window buf)
      )))

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
;;;###autoload
(defun copy-link-for-kindle ()
  (interactive)
  (elfeed-show-yank)
  (wallabag-add-entry (car kill-ring) "")
  )

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

;; (after! citar
;;   (map! :map org-mode-map
;;         :desc "Insert citation" "C-c b" #'citar-insert-citation)
;;   (setq citar-bibliography jethro/default-bibliography
;;         citar-at-point-function 'embark-act
;;         citar-symbol-separator "  "
;;         citar-format-reference-function 'citar-citeproc-format-reference
;;         org-cite-csl-styles-dir "~/Zotero/styles"
;;         citar-citeproc-csl-styles-dir org-cite-csl-styles-dir
;;         citar-citeproc-csl-locales-dir "~/Zotero/locales"
;;         citar-citeproc-csl-style (file-name-concat org-cite-csl-styles-dir "apa.csl")))


;; (after! bibtex-completion
;;   (after! org-roam
;;     (setq! bibtex-completion-notes-path org-roam-directory)))

;; (after! bibtex-completion
;;   (setq! bibtex-completion-notes-path org-roam-directory
;;          bibtex-completion-bibliography "~/Dropbox/org/references/articles.bib"
;;          org-cite-global-bibliography "~/Dropbox/org/references/articles.bib"
;;          bibtex-completion-pdf-field "file"))

(after! org
  (defun jethro/tag-new-node-as-draft ()
    (org-roam-tag-add '("draft")))
  (add-hook 'org-roam-capture-new-node-hook #'jethro/tag-new-node-as-draft)

  (defun jethro/org-roam-node-from-cite (keys-entries)
    (interactive (list (citar-select-ref :multiple nil :rebuild-cache t)))
    (let ((title (citar--format-entry-no-widths (cdr keys-entries)
                                                "${author editor} :: ${title}")))
      (org-roam-capture- :templates
                         '(("r" "reference" plain "%?" :if-new
                            (file+head "reference/${citekey}.org"
                                       ":PROPERTIES:
:ROAM_REFS: [cite:@${citekey}]
:END:
#+title: ${title}\n")
                            :immediate-finish t
                            :unnarrowed t))
                         :info (list :citekey (car keys-entries))
                         :node (org-roam-node-create :title title)
                         :props '(:finalize find-file))))
  )

(global-set-key (kbd "C-c o") 'bh/make-org-scratch)
(global-set-key (kbd "C-c s") 'bh/switch-to-scratch)
(bind-key "H-q" '+workspace/close-window-or-workspace)
(bind-key "H-w" '+workspace/load)
(bind-key "H-a" '+vertico/switch-workspace-buffer)
(bind-key "H-S" 'consult-ripgrep)
(bind-key "H-d" 'projectile-find-dir-other-window)
(bind-key "H-s" '+vertico/switch-workspace-buffer-other-window)
(bind-key "H-z" 'consult-recent-file)
(bind-key "H-x" 'consult-buffer)
(bind-key "H-e" 'org-roam-dailies-find-today)
(bind-key "H-E" 'org-roam-dailies-find-tomorrow)
;; (bind-key "H-a" '+ivy/switch-workspace-buffer)
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
(bind-key "H-c" #'doom/toggle-comment-region-or-line)
(map! :leader
      (:prefix "e"
       :n "e" #'ace-window
       :n "u" #'swiper-all
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
       :n "a" #'consult-org-agenda
       :n "w" #'consult-org-heading)
      (:prefix "v"
       :n "i" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-roam-directory "inbox.org"))))
       :n "t" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-roam-directory "tasks.org"))))
       :n "h" #'(lambda ()
                  (interactive)
                  (switch-to-buffer (find-file-noselect (concat org-roam-directory "habits.org"))))
       :n "d" #'dash-docs-activate-docset
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
      )

(after! org

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
  (define-key org-mode-map (kbd "H--") 'other-window)
  (define-key org-mode-map (kbd "H-+") 'org-strikethrough-region-or-point)
  (define-key org-mode-map (kbd "H-i") 'org-italics-region-or-point)
  (define-key org-mode-map (kbd "H-I") 'org-bold-region-or-point)
  (define-key org-mode-map (kbd "H-v") 'org-verbatim-region-or-point)
  (define-key org-mode-map (kbd "H-V") 'org-code-region-or-point)
  (define-key org-mode-map (kbd "H-U") 'org-superscript-region-or-point)
  (define-key org-mode-map (kbd "H-u") 'org-underline-region-or-point)
  (define-key org-mode-map (kbd "H-l") 'org-latex-math-region-or-point)
  )

(bind-key "H-t" '+my/vterm-run-project)

(setq scihub-homepage "https://sci-hub.st"
      scihub-download-directory "~/pdfs"
      scihub-open-after-download nil)

(use-package! org-mru-clock
  :after org
  :config
  (setq org-mru-clock-how-many 40)
  (add-hook 'minibuffer-setup-hook #'org-mru-clock-embark-minibuffer-hook)
  )

;; (setq org-books-file "~/Dropbox/org/notes/books.org")

;; (after! org
;;   (require 'org-books)
;;   (add-to-list 'org-capture-templates
;;                '("f" "Book" entry (file "~/Dropbox/org/notes/books.org")
;;                  "%(let* ((url (substring-no-properties (current-kill 0)))
;;                   (details (org-books-get-details url)))
;;              (when details (apply #'org-books-format 1 details)))"))
;;   )

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

(after! org
  ;; (add-hook 'org-mode-hook #'auto-fill-mode)
  (setq org-directory "~/Dropbox/org/"
        org-attach-id-dir "~/Dropbox/org/.attach/"
        ;; show images instead of links to images
        org-startup-with-inline-images t
        org-archive-mark-done t
        org-archive-tag "DONE"
        org-image-actual-width nil
        +org-export-directory "~/Dropbox/publish/"
        org-archive-location "~/Dropbox/org/gtd/archive.org::datetree/"
        org-default-notes-file "~/Dropbox/org/gtd/inbox.org"
        projectile-project-search-path '("~/workspace/projects/"))
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
  (setq org-tags-column 40)
  ;; (setq org-agenda-files '("~/Dropbox/org/gtd/"))
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
                        ;; Type of work
                        (:startgroup . nil)
                        ;; Have topic you are planning for as a tag
                        ("plan" . ?p)

                        ;; Have place and person who you are meeting with
                        ("meeting". ?m)
                        ;; Have person as a tag if working with someone or collaborating
                        ;; ("assist". ?A)

                        ;; hobby category and coding type
                        ;; ("customization". ?C)
                        ;; ("do" . ?d)

                        ("code" . ?c)
                        ("practice" . ?s)
                        (:endgroup . nil)

                        ;; Active or Passive Work
                        (:startgroup . nil)
                        ("Active". "V")
                        ;; ("read" . ?r)
                        ;; ("write" . ?W)
                        ("Passive". "P")
                        ;; ("watch" . ?w)
                        ;; ("listen" . ?L)
                        (:endgroup . nil)

                        ;; Difficulty of work
                        (:startgroup . nil)
                        ("Challenge" . ?1)
                        ("Average" . ?2)
                        ("Easy" . ?3)
                        (:endgroup . nil)

                        ;; ;; Time Context for the work
                        ;; (:startgroup . nil)
                        ;; ("Morning" . ?4)
                        ;; ("Day" . ?5)
                        ;; ("Evening" . ?6)
                        ;; (:endgroup . nil)

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
          ("<H-up>" . org-clock-convenience-timestamp-up)
          ("<H-down>" . org-clock-convenience-timestamp-down)
          ("<H-right>" . org-clock-convenience-fill-gap)
          ("<H-left>" . org-clock-convenience-fill-gap-both)))

(setq org-time-budgets '((:title "Spanish Lessons" :match "+spanish" :budget "10:00" :blocks (day week))
                         (:title "Growing Personally" :match "+@growth+home" :budget "30:00" :blocks (day week))
                         (:title "Entertaintment" :match "+entertaintment" :budget "5:00" :blocks (day week))
                         (:title "All Mundane" :match "+@mundane" :budget "8:00" :blocks (day week))
                         (:title "Freelancing Projects" :match "+@work+home" :budget "20:00" :blocks (day week))
                         (:title "Guitar practice" :match "+music" :budget "5:00" :blocks (nil week))
                         (:title "Sanskrit" :match "+sanskrit" :budget "5:15" :blocks (day week))))

(after! org
  (defun ibizaman/org-babel-goto-tangle-file ()
    (if-let* ((args (nth 2 (org-babel-get-src-block-info t)))
              (tangle (alist-get :tangle args)))
        (when (not (equal "no" tangle))
          (find-file tangle)
          t)))

  (add-hook 'org-open-at-point-functions 'ibizaman/org-babel-goto-tangle-file))

(after! org (add-to-list 'org-capture-templates
                         '("l" "Link Capture" entry (file "~/Dropbox/org/links.org")
                           "* TODO [[%^{link}][%^{description}]]"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("h" "Clip Link Capture" entry (file "~/Dropbox/org/links.org")
                           "* TODO %(org-cliplink-capture)"
                           :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("ps" "Create Project Subtask" entry (file "~/Dropbox/org/notes/inbox.org")
                           "* TODO %^{taskname}%?
:PROPERTIES:
:TRIGGER: next-sibling scheduled!(\"++%^{NEXT_TASK_AFTER}\") todo!(NEXT)
:BLOCKER:  previous-sibling
:CREATED:    %U
:END:
" :immediate-finish t)))


(after! org (add-to-list 'org-capture-templates
                         '("v" "Create a new habit" entry (file "~/Dropbox/org/notes/habits.org")
                           "* TODO %^{description} %?
SCHEDULED: %^{Start Time:}t
:PROPERTIES:
:STYLE: habit
:CREATED:    %U
:END:
")))

(after! org (add-to-list 'org-capture-templates
                         '("e" "Add an event" entry(file "~/Dropbox/org/notes/birthdays_and_anniversaries.org")
                           "* TODO Wish %^{Person} on their %^{Event}
:PROPERTIES:
:END:" :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
                         '("d" "Diary Log" entry(file+olp+datetree"~/Dropbox/org/notes/daily/diary.org")
                           "** <%<%I:%M:%S>> %^{diary entry}
%?")))


(after! org (add-to-list 'org-capture-templates
                         '("G" "Set a Motto" entry(file+olp+datetree"~/Dropbox/org/notes/daily/motto.org")
                           "* %^{diary entry}
%?" :immediate-finish t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     REVIEW TEMPLATES                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(after! org
  (add-to-list 'org-capture-templates
               '("r" "Make a review")))

(after! org (add-to-list 'org-capture-templates
                         '("rw" "Weekly Review" entry (file+olp+datetree "~/Dropbox/org/weeklyreview.org")
                           (file "~/Dropbox/org/templates/weeklyreviewtemplate.org") :tree-type week)))

(after! org (add-to-list 'org-capture-templates
                         '("rm" "Monthly Review" entry (file+olp+datetree "~/Dropbox/org/monthlyreview.org")
                           (file "~/Dropbox/org/templates/monthlyreviewtemplate.org") :tree-type month)))

(after! org (add-to-list 'org-capture-templates
                         '("rd" "Daily Review" entry (file+olp+datetree "~/Dropbox/org/notes/daily/dailyreview.org")
                           (file "~/Dropbox/org/templates/dailyreviewtemplate.org"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        REVIEW TEMPLATES DONE                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(after! org (add-to-list 'org-capture-templates
                         '("k" "Read on Kindle [Clipboard URL]" entry(file "~/Dropbox/org/kindle_daily.org")
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
                         '("c" "Capture Immediate" entry (file "~/Dropbox/org/notes/inbox.org")
                           "* TODO %^{taskname}%?
:PROPERTIES:
:CREATED:    %U
:END:
" :immediate-finish t)))

(defun my-agenda-motto (&rest _ignore)
  " INSERTS MOTTO FROM MOTTO FILE TO AGENDA"
  (with-temp-buffer
    (insert-file-contents "~/Dropbox/org/notes/daily/motto.org")
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

(after! org
  (add-hook 'org-agenda-finalize-hook
            (lambda () (remove-text-properties
                   (point-min) (point-max) '(mouse-face t))))
  ;; (add-hook 'org-finalize-agenda-hook (lambda () (hl-line-mode 1))))
  )

;;;###autoload
(defun my-agenda-motto (&rest _ignore)
  " INSERTS MOTTO FROM MOTTO FILE TO AGENDA"
  (with-temp-buffer
    (insert-file-contents "~/Dropbox/org/notes/daily/motto.org")
    (goto-char (point-max))
    (forward-line -1)
    (setq myLine (buffer-substring-no-properties
                  (line-beginning-position)
                  (line-end-position)))
    (setq myLine (concat "MOTTO OF THE DAY: " (s-upcase (s-replace "\*" "" myLine)))))
  (dotimes (_ 160) (insert "\t"))
  (insert "\n")
  (insert (propertize myLine 'face '(bold :height 1.4)))
  (insert "\n")
  (dotimes (_ 160) (insert "\t"))
  (insert "\n")
  )
(after! org-agenda (setq org-agenda-custom-commands
                         '(
                           ("k" "Today\'s View"
                            ((my-agenda-motto "" nil)
                             (agenda ""
                                     ((org-agenda-overriding-header "Overall Agenda View")
                                      (org-agenda-span 'day)
                                      (org-deadline-warning-days 7)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-tag-filter-preset
                                       '("-daytoday"))
                                      (org-agenda-sorting-strategy '(priority-down effort-down))
                                      (org-agenda-current-span 'day))
                                     )
                             (todo "NEXT"
                                   ((org-agenda-overriding-header " PROJECT TASKS\n ===================================================================\n")
                                    ))
                             (todo "READING"
                                   ((org-agenda-overriding-header "Books I am currently reading\n ======================================================\n")))
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
                                     '("~/Dropbox/org/notes/inbox.org"))
                                    (org-agenda-overriding-header " Process and refile inbox\n ===================================================================\n")
                                    ))
                             (todo "TOREAD"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/notes/books.org"))
                                    (org-agenda-overriding-header " Do you want to read some new book\n ===========================================================\n")
                                    ))
                             (todo "WAITING"
                                   ((org-agenda-files
                                     '("~/Dropbox/org/notes/tasks.org"))
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
                                     )) nil)
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
  (setq org-highlight-latex-and-related '(native script entities))
  (add-hook 'org-mode-hook 'org-fragtog-mode)
)

(after! org
  (+org-init-custom-links-h))
(defun +org-init-custom-links-h ()
  ;; Modify default file: links to colorize broken file links red
  (org-link-set-parameters
   "file"
   :face (lambda (path)
           (if (or (file-remote-p path)
                   ;; filter out network shares on windows (slow)
                   (and IS-WINDOWS (string-prefix-p "\\\\" path))
                   (file-exists-p path))
               'org-link
             '(warning org-link))))

  ;; Additional custom links for convenience
  (pushnew! org-link-abbrev-alist
            '("github"      . "https://github.com/%s")
            '("youtube"     . "https://youtube.com/watch?v=%s")
            '("google"      . "https://google.com/search?q=")
            '("gimages"     . "https://google.com/images?q=%s")
            '("gmap"        . "https://maps.google.com/maps?q=%s")
            '("duckduckgo"  . "https://duckduckgo.com/?q=%s")
            '("wikipedia"   . "https://en.wikipedia.org/wiki/%s")
            '("wolfram"     . "https://wolframalpha.com/input/?i=%s")
            '("doom-repo"   . "https://github.com/hlissner/doom-emacs/%s"))

  (+org-define-basic-link "org" 'org-directory)
  (+org-define-basic-link "doom" 'doom-emacs-dir)
  (+org-define-basic-link "doom-docs" 'doom-docs-dir)
  (+org-define-basic-link "doom-modules" 'doom-modules-dir)

  ;; Add "lookup" links for packages and keystrings; useful for Emacs
  ;; documentation -- especially Doom's!
  (org-link-set-parameters
   "kbd"
   :follow (lambda (_) (minibuffer-message "%s" (+org-display-link-in-eldoc-a)))
   :help-echo #'+org-read-kbd-at-point
   :face 'help-key-binding)
  (org-link-set-parameters
   "doom-package"
   :follow #'+org-link--doom-package-follow-fn
   :face (lambda (_) '(:inherit org-priority :slant italic)))
  (org-link-set-parameters
   "doom-module"
   :follow #'+org-link--doom-module-follow-fn
   :face #'+org-link--doom-module-face-fn)

  ;; Allow inline image previews of http(s)? urls or data uris.
  ;; `+org-http-image-data-fn' will respect `org-display-remote-inline-images'.
  (setq org-display-remote-inline-images 'download) ; TRAMP urls
  (org-link-set-parameters "http"  :image-data-fun #'+org-http-image-data-fn)
  (org-link-set-parameters "https" :image-data-fun #'+org-http-image-data-fn)
  (org-link-set-parameters "img"   :image-data-fun #'+org-inline-image-data-fn)

  ;; Add support for youtube links + previews
  (require 'org-yt nil t)

  (defadvice! +org-dont-preview-if-disabled-a (&rest _)
    "Make `org-yt' respect `org-display-remote-inline-images'."
    :before-while #'org-yt-image-data-fun
    (not (eq org-display-remote-inline-images 'skip))))

(add-hook! 'org-mode-hook #'org-appear-mode)
(after! org
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks t)
  ;;(run-at-time nil nil #'org-appear--set-elements)
  )

(after! org
  (add-hook! 'org-mode-hook #'+org-pretty-mode)
  (setq org-hide-emphasis-markers t
        org-startup-indented t
        org-fontify-quote-and-verse-blocks t
        org-hide-leading-stars t
        org-agenda-block-separator ""
        org-fontify-whole-heading-line t
        org-fontify-done-headline t
        org-list-demote-modify-bullet '(("+" . "-") ("1." . "a.") ("-" . "+") ("a." . "1."))
        org-superstar-leading-bullet ?\s
        org-superstar-headline-bullets-list '(?\s)
        org-superstar-leading-fallback ?\s
        org-superstar-remove-leading-stars t
        org-superstar-todo-bullet-alist
        '(("TODO" . 9744)
          ("[ ]"  . 9744)
          ("DONE" . 9745)
          ("[X]"  . 9745))
        org-priority-faces '((?A . (:foreground "red" :weight bold))
                             (?B . (:foreground "green" :weight bold))
                             (?C . (:foreground "tomato"))
                             (?D . (:foreground "orange")))
        org-priority-default 68
        org-priority-highest 65
        org-priority-lowest 68
        org-ellipsis "⤵"
        )
  (setq org-emphasis-alist
        '(("*" (bold :foreground "Orange" ))
          ("/" (italic :foreground "VioletRed"))
          ("_" underline)
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
  (global-set-key (kbd "<s-print>") 'my-org-download-screenshot)
)

(after! org
  (setq org-roam-directory (file-truename "~/Dropbox/org/notes/")
        org-roam-dailies-directory "daily/")
  ;; (org-roam-setup)
  ;; ;; Org-roam interface
  ;; (cl-defmethod org-roam-node-hierarchy ((node org-roam-node))
  ;;   "Return the node's TITLE, as well as it's HIERACHY."
  ;;   (let* ((title (org-roam-node-title node))
  ;;          (olp (mapcar (lambda (s) (if (> (length s) 30) (concat (substring s 0 30)  "...") s)) (org-roam-node-olp node)))
  ;;          (level (org-roam-node-level node))
  ;;          (filetitle (org-roam-get-keyword "TITLE" (org-roam-node-file node)))
  ;;          (shortentitle (if (> (length filetitle) 30) (concat (substring filetitle 0 30)  "...") filetitle))
  ;;          (separator (concat " " (all-the-icons-material "chevron_right") " ")))
  ;;     (cond
  ;;      ((= level 1) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-green)) " "
  ;;                           (propertize shortentitle 'face 'org-roam-dim) separator title))
  ;;      ((= level 2) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-dpurple)) " "
  ;;                           (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
  ;;      ((> level 2) (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "list" :face 'all-the-icons-dsilver)) " "
  ;;                           (propertize (concat shortentitle separator (string-join olp separator)) 'face 'org-roam-dim) separator title))
  ;;      (t (concat (propertize (format "=level:%d=" level) 'display (all-the-icons-material "insert_drive_file" :face 'all-the-icons-yellow)) " " title)))))

  ;; (cl-defmethod org-roam-node-functiontag ((node org-roam-node))
  ;;   "Return the FUNCTION TAG for each node. These tags are intended to be unique to each file, and represent the note's function."
  ;;   (let* ((specialtags '("journal" "book" "concept" "blog" "inquiry" "bio" "literature" "stockmarket"))
  ;;          (tags (seq-filter (lambda (tag) (not (string= tag "ATTACH"))) (org-roam-node-tags node)))
  ;;          (functiontag (seq-intersection specialtags tags 'string=)))
  ;;     (concat
  ;;      (if functiontag
  ;;          (propertize "=has:functions=" 'display (all-the-icons-octicon "gear" :face 'all-the-icons-silver :v-adjust 0.02))
  ;;        (propertize "=not-functions=" 'display (all-the-icons-octicon "gear" :face 'org-roam-dim :v-adjust 0.02)))
  ;;      " " (string-join functiontag ", "))))

  ;; (cl-defmethod org-roam-node-othertags ((node org-roam-node))
  ;;   "Return the OTHER TAGS of each notes."
  ;;   (let* ((tags (seq-filter (lambda (tag) (not (string= tag "ATTACH"))) (org-roam-node-tags node)))
  ;;          (specialtags '("journal" "book" "concept" "blog" "inquiry" "bio" "literature" "stockmarket"))
  ;;          (othertags (seq-difference tags specialtags 'string=)))
  ;;     (concat
  ;;      (if othertags
  ;;          (propertize "=has:tags=" 'display (all-the-icons-faicon "tags" :face 'all-the-icons-dgreen :v-adjust 0.02))) " "
  ;;      (propertize (string-join othertags ", ") 'face 'all-the-icons-dgreen))))

  ;; (cl-defmethod org-roam-node-backlinkscount ((node org-roam-node))
  ;;   (let* ((count (caar (org-roam-db-query
  ;;                        [:select (funcall count source)
  ;;                         :from links
  ;;                         :where (= dest $s1)
  ;;                         :and (= type "id")]
  ;;                        (org-roam-node-id node)))))
  ;;     (if (> count 0)
  ;;         (concat (propertize "=has:backlinks=" 'display (all-the-icons-material "link" :face 'all-the-icons-dblue)) (format "%d" count))
  ;;       (concat (propertize "=not-backlinks=" 'display (all-the-icons-material "link" :face 'org-roam-dim))  " "))))

  ;; (setq org-roam-node-display-template
  ;;       (concat  "${backlinkscount:16} ${functiontag:27} ${hierarchy} ${othertags}"))
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

  ;; Attachments removed from org-roam db
  (setq org-roam-db-node-include-function
        (lambda ()
          (not (member "ATTACH" (org-get-tags)))))

  ;; From System Crafter's streams https://systemcrafters.net/build-a-second-brain-in-emacs/5-org-roam-hacks/
  (defun org-roam-node-insert-immediate (arg &rest args)
    (interactive "P")
    (let ((args (push arg args))
          (org-roam-capture-templates (list (append (car org-roam-capture-templates)
                                                    '(:immediate-finish t)))))
      (apply #'org-roam-node-insert args)))

  ;; ORG ROAM TO AGENDA
  ;; https://systemcrafters.net/build-a-second-brain-in-emacs/5-org-roam-hacks/
  ;; The buffer you put this code in must have lexical-binding set to t!
  ;; See the final configuration at the end for more details.

  (defun my/org-roam-filter-by-tag (tag-name)
    (lambda (node)
      (member tag-name (org-roam-node-tags node))))

  (defun my/org-roam-list-notes-by-tag (tag-name)
    (delete-dups (mapcar #'org-roam-node-file
                         (seq-filter
                          (my/org-roam-filter-by-tag tag-name)
                          (org-roam-node-list)))))

  (defun my/org-roam-refresh-agenda-list ()
    (interactive)
    (setq org-agenda-files (my/org-roam-list-notes-by-tag "agenda")))

  ;; Build the agenda list the first time for the session
  (my/org-roam-refresh-agenda-list)

  ;; TO FIND ONLY AGENDA FILES IN ORG-ROAM
  ;;
  ;;
  (defun my/org-roam-project-finalize-hook ()
    "Adds the captured project file to `org-agenda-files' if the
capture was not aborted."
    ;; Remove the hook since it was added temporarily
    (remove-hook 'org-capture-after-finalize-hook #'my/org-roam-project-finalize-hook)

    ;; Add project file to the agenda list if the capture was confirmed
    (unless org-note-abort
      (with-current-buffer (org-capture-get :buffer)
        (add-to-list 'org-agenda-files (buffer-file-name)))))

  (defun my/org-roam-find-project ()
    (interactive)
    ;; Add the project file to the agenda after capture is finished
    (add-hook 'org-capture-after-finalize-hook #'my/org-roam-project-finalize-hook)

    ;; Select a project file to open, creating it if necessary
    (org-roam-node-find
     nil
     nil
     (my/org-roam-filter-by-tag "agenda")
     :templates
     '(("p" "project" entry
        (file "~/Dropbox/org/templates/newprojtemplate.org")
        :if-new (file "%<%Y%m%d%H%M%S>-${slug}.org")
        :unnarrowed t)))
    )

  ;; Org-roam template similar to org template
  ;;
  (defun my/org-roam-capture-idea ()
    (interactive)
    ;; Add the project file to the agenda after capture is finished
    (add-hook 'org-capture-after-finalize-hook #'my/org-roam-project-finalize-hook)

    ;; Capture the new task, creating the project file if necessary
    (org-roam-capture- :node (org-roam-node-read
                              nil
                              (my/org-roam-filter-by-tag "agenda"))
                       :templates '(("i" "idea" plain "** TODO %?"
                                     :if-new (file+head+olp "%<%Y%m%d%H%M%S>-${slug}.org"
                                                            "#+title: ${title}\n#+category: ${title}\n#+filetags: agenda"
                                                            ("Ideas and Tasks"))))))
  )

(setq org-roam-capture-templates
      '(("d" "default" plain "%?"
         :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                            "#+title: ${title}\n")
         :unnarrowed t)

        ("a" "agenda" plain "%?"
         :if-new (file+head "${slug}.org"
                            "#+title: ${title}\n
#+filetags: agenda")
         :unnarrowed t)

        ;; Org roam bibtex template
        ("r" "Bibliography Reference" plain
         (file "~/Dropbox/org/templates/orbreftemplate.org")
         :if-new
         (file+head "papers/${citekey}.org" "#+title: ${title}\n")
         :unnarrowed t)

        ;; Use this field if necessary #+EXPORT_FILE_NAME: %^{export name}
        ("b" "Blog Post" plain
         "%?"
         :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+SETUPFILE:../hugo_in_setup.org
#+HUGO_SECTION: ${ai|emacs|neuroscience}
#+HUGO_SLUG: ${slug}
#+hugo_tags:
#+hugo_categories:
#+hugo_draft: false\n
#+author: Alok Regmi
#+filetags: ${filetags}\n
#+title: ${title}
#+date: %t\n")
         :unnarrowed t)

        ("j" "paper-description" plain "* Main Contribution \n\n* Your description of significance \n\n* New algorithm or principles\n\n* Simulation Results and Comparisons\n\n* Solid Conclusion"
         :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                            "#+title: ${title}\n#+filetags: paper")
         :unnarrowed t)

        ("e" "ref" plain "%?"
         :if-new (file+head "websites/${slug}.org" "#+SETUPFILE:./hugo_in_setup.org
#+ROAM_KEY: ${ref}#+TITLE: ${title}\n- source :: ${ref}")
         :unnarrowed t)

        ("k" "private" plain (function org-roam--capture-get-point)
         "%?" :if-new (file+head "private-${slug}"
                                 "#+TITLE: ${title}\n")
         :unnarrowed t)

        ("w" "webref" entry "* ${title} ([[${ref}][${hostname}]])\n%?"
         :if-new
         (file+head (concat org-roam-dailies-directory "%<%Y-%m-%d>.org")
                    "#+title: %<%Y-%m-%d %a>\n#+filetags: journal\n#+startup: overview\n#+created: %U\n\n")
         :unnarrowed t)
        ))

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

(setq frame-title-format
      '(""
        (:eval
         (if (s-contains-p org-roam-directory (or buffer-file-name ""))
             (replace-regexp-in-string
              ".*/[0-9]*-?" "☰ "
              (subst-char-in-string ?_ ?  buffer-file-name))
           "%b"))
        (:eval
         (let ((project-name (projectile-project-name)))
           (unless (string= "-" project-name)
             (format (if (buffer-modified-p)  " ◉ %s" "  ●  %s") project-name))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org roam
;;                                        backlinks fix                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun collect-backlinks-string (backend)
  (when (org-roam-node-at-point)
    (let* ((source-node (org-roam-node-at-point))
           (source-file (org-roam-node-file source-node))
           (nodes-in-file (--filter (s-equals? (org-roam-node-file it) source-file)
                                    (org-roam-node-list)))
           (nodes-start-position (-map 'org-roam-node-point nodes-in-file))
           ;; Nodes don't store the last position, so get the next headline position
           ;; and subtract one character (or, if no next headline, get point-max)
           (nodes-end-position (-map (lambda (nodes-start-position)
                                       (goto-char nodes-start-position)
                                       (if (org-before-first-heading-p) ;; file node
                                           (point-max)
                                         (call-interactively
                                          'org-forward-heading-same-level)
                                         (if (> (point) nodes-start-position)
                                             (- (point) 1) ;; successfully found next
                                           (point-max)))) ;; there was no next
                                     nodes-start-position))
           ;; sort in order of decreasing end position
           (nodes-in-file-sorted (->> (-zip nodes-in-file nodes-end-position)
                                      (--sort (> (cdr it) (cdr other))))))
      (dolist (node-and-end nodes-in-file-sorted)
        (-let (((node . end-position) node-and-end))
          (when (org-roam-backlinks-get node)
            (goto-char end-position)
            ;; Add the references as a subtree of the node
            (setq heading (format "\n\n%s References\n"
                                  (s-repeat (+ (org-roam-node-level node) 1) "*")))
            (insert heading)
            (setq properties-drawer ":PROPERTIES:\n:HTML_CONTAINER_CLASS: references\n:END:\n")
            (insert properties-drawer)
            (dolist (backlink (org-roam-backlinks-get node))
              (let* ((source-node (org-roam-backlink-source-node backlink))
                     (properties (org-roam-backlink-properties backlink))
                     (outline (when-let ((outline (plist-get properties :outline)))
                                (mapconcat #'org-link-display-format outline " > ")))
                     (point (org-roam-backlink-point backlink))
                     (text (s-replace "\n" " " (org-roam-preview-get-contents
                                                (org-roam-node-file source-node)
                                                point)))
                     (reference (format "%s [[id:%s][%s]]\n%s\n%s\n\n"
                                        (s-repeat (+ (org-roam-node-level node) 2) "*")
                                        (org-roam-node-id source-node)
                                        (org-roam-node-title source-node)
                                        (if outline (format "%s (/%s/)"
                                                            (s-repeat (+ (org-roam-node-level node) 3) "*") outline) "")
                                        text)))
                (insert reference)))))))))
(add-hook 'org-export-before-processing-hook 'collect-backlinks-string)

;;;###autoload
(defun bms/org-roam-rg-search ()
  "Search org-roam directory using consult-ripgrep. With live-preview."
  (interactive)
  (let ((consult-ripgrep-command "rg --null --ignore-case --type org --line-buffered --color=always --max-columns=500 --no-heading --line-number . -e ARG OPTS"))
    (consult-ripgrep org-roam-directory)))
(global-set-key (kbd "H-o") 'bms/org-roam-rg-search)

(defun jupyter-python-to-only-python (text backend info)
  "Replace jupyter-python src blocks with python blocks."
  (replace-regexp-in-string "```jupyter-python" "```python" text))
(add-hook 'org-export-filter-src-block-functions #'jupyter-python-to-only-python)

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

(set-email-account! "campus"
                    '((mu4e-sent-folder       . "/pulchowk/Sent Mail")
                      (mu4e-drafts-folder     . "/pulchowk/Drafts")
                      (mu4e-trash-folder      . "/pulchowk/Trash")
                      (mu4e-refile-folder     . "/pulchowk/All Mail")
                      (smtpmail-smtp-user     . "072bex403.alok@pcampus.edu.np")
                      (user-mail-address      . "072bex403.alok@pcampus.edu.np")
                      (mu4e-compose-signature . "---\nAlok Regmi\n Pulchowk Campus, Lalitpur, Nepal"))
                    t)

(set-email-account! "personal"
                    '((mu4e-sent-folder       . "/personal/Sent Mail")
                      (mu4e-drafts-folder     . "/personal/Drafts")
                      (mu4e-trash-folder      . "/personal/Trash")
                      (mu4e-refile-folder     . "/personal/All Mail")
                      (smtpmail-smtp-user     . "sagar.r.alok@gmail.com")
                      (user-mail-address      . "sagar.r.alok@gmail.com")
                      (mu4e-compose-signature . "---\nAlok Regmi"))
                    t)
(add-to-list 'load-path "/usr/share/emacs/site-lisp/mu4e")

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
        org-noter-notes-search-path '("~/Dropbox/org/interleave_notes/")
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

;; (setq org-books-file "~/Dropbox/org/gtd/books.org")

;; (after! org
;;   (require 'org-books)
;;   (add-to-list 'org-capture-templates
;;                '("f" "Book" entry (file "~/Dropbox/org/gtd/books.org")
;;                  "%(let* ((url (substring-no-properties (current-kill 0)))
;;                   (details (org-books-get-details url)))
;;              (when details
;;                (apply #'org-books-format 3 details))))"))
;;   (add-to-list 'org-capture-templates
;;                '("g" "Auto Book Entry" entry (file "~/Dropbox/org/gtd/books.org")
;;                  "%(let* ((url (substring-no-properties (current-kill 0)))
;;                   (details (org-books-get-details %u)))
;;              (when details
;;                (apply #'org-books-format 3 details))))"))
;;   )

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

  )

(after! org
  ;;* org-numbered headings
  (defun scimax-overlay-numbered-headings ()
    "Put numbered overlays on the headings."
    (interactive)
    (loop for (p lv) in (let ((counters (copy-list '(0 0 0 0 0 0 0 0 0 0)))
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
                                         (incf (nth current-level counters)))

                                        ;; decrease in level
                                        (t
                                         (loop for i from (+ 1 current-level) below (length counters)
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
_a_: begin def/class _x_: syntax    _Sb_: send buffer
_e_: end def/class   _n_: next err  _Ss_: Switch to shell
_<_: dedent line     _p_: prev err  _Sc_: Create shell
_>_: indent line
_j_: jump to
_._: goto definition
_t_: run tests _m_: magit  _8_: black autopep8
"
    ("a" beginning-of-defun)
    ("e" end-of-defun)
    ("<" python-indent-shift-left)
    (">" python-indent-shift-right)
    ("j" consult-imenu)

    ("t" python-pytest-file-dwim)
    ("." evil-goto-definition)
    ("x" consult-flycheck)
    ("n" flycheck-next-error)
    ("p" flycheck-previous-error)

    ("m" magit-status)

    ("Sc" run-python)
    ("Sb" python-shell-send-region)
    ("Ss" python-shell-switch-to-shell)

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
                     (relpath (file-relative-name fullpath current-dir)))
                ;; delete the existing link
                (delete-region link-begin link-end)
                ;; replace with file: link and file: description
                (insert (format "[[file:%s][file:%s]]" relpath relpath)))))))))

(use-package! org-fancy-priorities
  :defer 20
  :config
  (setq org-fancy-priorities-list
        `(
          (?A . ,(concat " " (all-the-icons-octicon "pulse" :height 1.2) " "))
          (?B . ,(concat " " (all-the-icons-octicon "mortar-board" :height 1.2) " "))
          (?C . ,(concat " " (all-the-icons-octicon "flame" :height 1.2) " "))
          (?D . ,(concat " " (all-the-icons-octicon "telescope" :height 1.2) " "))
          )
        )
  )


;; (after! lsp
;;   (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]NinjaTrader"))

(after! org
  (setq pdf-tools-msys2-directory "c:/Users/Kai/scoop/apps/msys2/current/"))

(setq w32-apps-modifier 'hyper)
;; (setq shell-file-name "C:/Windows/System32/bash.exe")
;; (setenv "ESHELL" "bash")
(global-set-key [f8] 'shell)



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
  '("go" "python" "ipython" "bash" "sh"))
(dolist (lang org-babel-lang-list)
  (eval `(lsp-org-babel-enable ,lang)))


;; Exporting youtube links

(after! org
  (org-link-set-parameters "yt" :export #'+org-export-yt)
  (defun +org-export-yt (path desc backend _com)
    (cond ((org-export-derived-backend-p backend 'html)
           (format "<iframe width='440' \
height='335' \
src='https://www.youtube.com/embed/%s' \
frameborder='0' \
allowfullscreen>%s</iframe>" path (or "" desc)))
          ((org-export-derived-backend-p backend 'latex)
           (format "\\href{https://youtu.be/%s}{%s}" path (or desc "youtube")))
          (t (format "https://youtu.be/%s" path))))


  (setq org-format-latex-header "\\documentclass{article}
\\usepackage[usenames]{xcolor}

\\usepackage[T1]{fontenc}

\\usepackage{booktabs}

\\pagestyle{empty}             % do not remove
% The settings below are copied from fullpage.sty
\\setlength{\\textwidth}{\\paperwidth}
\\addtolength{\\textwidth}{-3cm}
\\setlength{\\oddsidemargin}{1.5cm}
\\addtolength{\\oddsidemargin}{-2.54cm}
\\setlength{\\evensidemargin}{\\oddsidemargin}
\\setlength{\\textheight}{\\paperheight}
\\addtolength{\\textheight}{-\\headheight}
\\addtolength{\\textheight}{-\\headsep}
\\addtolength{\\textheight}{-\\footskip}
\\addtolength{\\textheight}{-3cm}
\\setlength{\\topmargin}{1.5cm}
\\addtolength{\\topmargin}{-2.54cm}
% my custom stuff
\\usepackage[nofont,plaindd]{bmc-maths}
\\usepackage{arev}
")


  (setq org-format-latex-options
        (plist-put org-format-latex-options :background "Transparent"))


  )




;; Numbered equations all have (1) as the number for fragments with vanilla
;; org-mode. This code injects the correct numbers into the previews so they
;; look good.
(defun scimax-org-renumber-environment (orig-func &rest args)
  "A function to inject numbers in LaTeX fragment previews."
  (let ((results '())
        (counter -1)
        (numberp))
    (setq results (cl-loop for (begin . env) in
                           (org-element-map (org-element-parse-buffer) 'latex-environment
                                            (lambda (env)
                                              (cons
                                               (org-element-property :begin env)
                                               (org-element-property :value env))))
                           collect
                           (cond
                            ((and (string-match "\\\\begin{equation}" env)
                                  (not (string-match "\\\\tag{" env)))
                             (cl-incf counter)
                             (cons begin counter))
                            ((string-match "\\\\begin{align}" env)
                             (prog2
                                 (cl-incf counter)
                                 (cons begin counter)
                               (with-temp-buffer
                                 (insert env)
                                 (goto-char (point-min))
                                 ;; \\ is used for a new line. Each one leads to a number
                                 (cl-incf counter (count-matches "\\\\$"))
                                 ;; unless there are nonumbers.
                                 (goto-char (point-min))
                                 (cl-decf counter (count-matches "\\nonumber")))))
                            (t
                             (cons begin nil)))))

    (when (setq numberp (cdr (assoc (point) results)))
      (setf (car args)
            (concat
             (format "\\setcounter{equation}{%s}\n" numberp)
             (car args)))))

  (apply orig-func args))


(defun scimax-toggle-latex-equation-numbering ()
  "Toggle whether LaTeX fragments are numbered."
  (interactive)
  (if (not (get 'scimax-org-renumber-environment 'enabled))
      (progn
        (advice-add 'org-create-formula-image :around #'scimax-org-renumber-environment)
        (put 'scimax-org-renumber-environment 'enabled t)
        (message "Latex numbering enabled"))
    (advice-remove 'org-create-formula-image #'scimax-org-renumber-environment)
    (put 'scimax-org-renumber-environment 'enabled nil)
    (message "Latex numbering disabled.")))

(after! latex
  (advice-add 'org-create-formula-image :around #'scimax-org-renumber-environment)
  (put 'scimax-org-renumber-environment 'enabled t)
  )

(setq org-latex-pdf-process '("LC_ALL=en_US.UTF-8 latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

(after! lsp-mode
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\Feedback\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\NinjaTrader\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\Trading_Fleet\\'")
  )

(defalias 'Portfolio_yaml
  (kmacro "0 $ v F : x ^ h p i : SPC <escape> ^ x x j"))

(after! org
  (add-hook 'org-mode-hook #'mixed-pitch-mode))

(setq shell-file-name "C:/Windows/system32/bash.exe")
(setenv "ESHELL" "bash")
(setq doom-projectile-fd-binary "fdfind")

;; Evil specific functions

;;;###autoload
;; (defun +vertico/switch-workspace-buffer-other-window()
;;   (interactive)
;;   (+evil-window-vsplit-a)
;;   (+vertico/switch-workspace-buffer))

;; (setq +evil-want-o/O-to-continue-comments nil)

;; (bind-key "H-F" 'evil-window-split)
;; (bind-key "H-f" 'evil-window-vsplit)
;; (bind-key "H-t" '+my/vterm-run-project)
;; (bind-key "H-;" '+evil-window-split-a)
;; (bind-key "H-\\" '+evil-window-vsplit-a)


;; (evil-define-command evil-buffer-org-new (count file)
;;   "Creates a new ORG buffer replacing the current window, optionally
;;    editing a certain FILE"
;;   :repeat nil
;;   (interactive "P<f>")
;;   (if file
;;       (evil-edit file)
;;     (let ((buffer (generate-new-buffer "*new org*")))
;;       (set-window-buffer nil buffer)
;;       (with-current-buffer buffer
;;         (org-mode)))))
;; (map! :leader
;;       (:prefix "b"
;;        :desc "New empty ORG buffer" "o" #'evil-buffer-org-new))


;; (after! evil
;;   (setq evil-ex-substitute-global t
;;         evil-move-cursor-back nil
;;         evil-kill-on-visual-paste nil))


;; (after! org
;;   ;; (add-hook 'evil-org-agenda-mode-hook 'org-save-all-org-buffers)
;;   (evil-define-key 'normal org-mode-map
;;     ;; keybindings mirror ipython web interface behavior
;;     "go" 'org-babel-previous-src-block
;;     "gO" 'org-babel-next-src-block)
;;   (map!
;;    :after evil-org
;;    :map evil-org-mode-map
;;    :i [return] #'unpackaged/org-return-dwim)
;;   )

;; (use-package! yasnippet
;;   :config
;;   ;; It will test whether it can expand, if yes, change cursor color
;;   (defun hp/change-cursor-color-if-yasnippet-can-fire (&optional field)
;;     (interactive)
;;     (setq yas--condition-cache-timestamp (current-time))
;;     (let (templates-and-pos)
;;       (unless (and yas-expand-only-for-last-commands
;;                    (not (member last-command yas-expand-only-for-last-commands)))
;;         (setq templates-and-pos (if field
;;                                     (save-restriction
;;                                       (narrow-to-region (yas--field-start field)
;;                                                         (yas--field-end field))
;;                                       (yas--templates-for-key-at-point))
;;                                   (yas--templates-for-key-at-point))))
;;       (set-cursor-color (if (and templates-and-pos (first templates-and-pos)
;;                                  (eq evil-state 'insert))
;;                             (doom-color 'red)
;;                           (face-attribute 'default :foreground)))))
;;   :hook (post-command . hp/change-cursor-color-if-yasnippet-can-fire))
;; ;; For adding code snippets in yasnippet
;; (add-to-list 'warning-suppress-types '(yasnippet backquote-change))

(after! org
  ;; (define-key org-mode-map [remap org-return] 'unpackaged/org-return-dwim)
  (map! :map org-mode-map
        :desc "Org Return DWIM" "RET" #'unpackaged/org-return-dwim))
;; (setq shell-file-name "C:/Users/Kai/scoop/apps/emacs-k/current/libexec/emacs/29.0.50/x86_64-w64-mingw32/cmdproxy.exe")
(when (eq system-type 'windows-nt)
  (defun me/bash ()
    (interactive)
    (let ((explicit-shell-file-name "C:/Windows/System32/bash.exe"))
      (shell))))

;; Add frame borders and window dividers
(modify-all-frames-parameters
 '((right-divider-width . 20)
   (internal-border-width . 20)))
(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))
(set-face-background 'fringe (face-attribute 'default :background))

(after! org
  (setq
   ;; Edit settings
   org-auto-align-tags nil
   org-tags-column 0
   org-catch-invisible-edits 'show-and-error
   org-special-ctrl-a/e t
   org-insert-heading-respect-content t

   ;; Org styling, hide markup etc.
   org-hide-emphasis-markers t
   org-pretty-entities t
   org-ellipsis "..."))

(global-org-modern-mode)

;; (map!
;;  ;; window management (prefix "C-w")
;;  (:map evil-window-map
;;   ;; Navigation
;;   "C-h"     #'evil-window-left
;;   "C-n"     #'evil-window-down
;;   "C-i"     #'evil-window-up
;;   "C-l"     #'evil-window-right
;;   "C-w"     #'other-window
;;   ;; Extra split commands
;;   "S"       #'+evil/window-split-and-follow
;;   "V"       #'+evil/window-vsplit-and-follow
;;   ;; Swapping windows
;;   "H"       #'+evil/window-move-left
;;   "J"       #'+evil/window-move-down
;;   "K"       #'+evil/window-move-up
;;   "L"       #'+evil/window-move-right
;;   "C-S-w"   #'ace-swap-window
;;   ;; Window undo/redo
;;   (:prefix "m"
;;    "m"       #'doom/window-maximize-buffer
;;    "v"       #'doom/window-maximize-vertically
;;    "s"       #'doom/window-maximize-horizontally)
;;   "u"       #'winner-undo
;;   "C-u"     #'winner-undo
;;   "C-r"     #'winner-redo
;;   "o"       #'doom/window-enlargen
;;   ;; Delete window
;;   "d"       #'evil-window-delete
;;   "C-C"     #'ace-delete-window
;;   "T"       #'tear-off-window)

;;  ;; text objects
;;  :textobj "a" #'evil-inner-arg                    #'evil-outer-arg
;;  :textobj "B" #'evil-textobj-anyblock-inner-block #'evil-textobj-anyblock-a-block
;;  :textobj "c" #'evilnc-inner-comment              #'evilnc-outer-commenter
;;  :textobj "f" #'+evil:defun-txtobj                #'+evil:defun-txtobj
;;  :textobj "g" #'+evil:whole-buffer-txtobj         #'+evil:whole-buffer-txtobj
;;  :textobj "i" #'evil-indent-plus-i-indent         #'evil-indent-plus-a-indent
;;  :textobj "j" #'evil-indent-plus-i-indent-up-down #'evil-indent-plus-a-indent-up-down
;;  :textobj "k" #'evil-indent-plus-i-indent-up      #'evil-indent-plus-a-indent-up
;;  :textobj "q" #'+evil:inner-any-quote             #'+evil:outer-any-quote
;;  :textobj "u" #'+evil:inner-url-txtobj            #'+evil:outer-url-txtobj
;;  :textobj "x" #'evil-inner-xml-attr               #'evil-outer-xml-attr

;;  ;; evil-easymotion
;;  (:after evil-easymotion
;;   :m "gs" evilem-map
;;   (:map evilem-map
;;    "a" (evilem-create #'evil-forward-arg)
;;    "A" (evilem-create #'evil-backward-arg)
;;    "s" #'evil-avy-goto-char-2
;;    "SPC" (cmd! (let ((current-prefix-arg t)) (evil-avy-goto-char-timer)))
;;    "/" #'evil-avy-goto-char-timer))

;;  ;; evil-snipe
;;  (:after evil-snipe
;;   :map evil-snipe-parent-transient-map
;;   "C-;" (cmd! (require 'evil-easymotion)
;;               (call-interactively
;;                (evilem-create #'evil-snipe-repeat
;;                               :bind ((evil-snipe-scope 'whole-buffer)
;;                                      (evil-snipe-enable-highlight)
;;                                      (evil-snipe-enable-incremental-highlight))))))

;;  ;; evil-surround
;;  :v "S" #'evil-surround-region
;;  :o "s" #'evil-surround-edit
;;  :o "S" #'evil-Surround-edit

;;  ;; evil-lion
;;  :n "gl" #'evil-lion-left
;;  :n "gL" #'evil-lion-right
;;  :v "gl" #'evil-lion-left
;;  :v "gL" #'evil-lion-right

;;  ;; Omni-completion
;;  (:when (featurep! :completion company)
;;   (:prefix "C-x"
;;    :i "C-l"    #'+company/whole-lines
;;    :i "C-k"    #'+company/dict-or-keywords
;;    :i "C-f"    #'company-files
;;    :i "C-]"    #'company-etags
;;    :i "s"      #'company-ispell
;;    :i "C-s"    #'company-yasnippet
;;    :i "C-o"    #'company-capf
;;    :i "C-n"    #'+company/dabbrev
;;    :i "C-p"    #'+company/dabbrev-code-previous)))

(after! python-mode
  (setq dap-python-debugger 'debugpy)
  ;; (dap-register-debug-template
  ;;  "Python :: Run pytest"
  ;;  (list :type "python"
  ;;        :cwd "C:/EHP/utils/"
  ;;        :module "pytest"
  ;;        :request "launch"
  ;;        :debugger 'debugpy
  ;;        :name "Python :: Run Pytest (EHP)"))
  )

;; accept completion from copilot and fallback to company
(defun my-tab ()
  (interactive)
  (or (copilot-accept-completion)
      (company-indent-or-complete-common nil)))

(use-package! copilot
  :hook (prog-mode . copilot-mode)
  :bind (("C-TAB" . 'copilot-accept-completion-by-word)
         ("C-<tab>" . 'copilot-accept-completion-by-word)
         :map company-active-map
         ("<tab>" . 'my-tab)
         ("TAB" . 'my-tab)
         :map company-mode-map
         ("<tab>" . 'my-tab)
         ("TAB" . 'my-tab)))

;; (use-package! tree-sitter
;;   :config
;;   (require 'tree-sitter-langs)
;;   (global-tree-sitter-mode)
;;   (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))
;; (pushnew! tree-sitter-major-mode-language-alist
;;           '(scss-mode . css))

(use-package elfeed-tube
  ;; :straight (:host github :repo "karthink/elfeed-tube")
  :after elfeed
  :demand t
  :config
  ;; (setq elfeed-tube-auto-save-p nil) ;; t is auto-save (not default)
  ;; (setq elfeed-tube-auto-fetch-p t) ;;  t is auto-fetch (default)
  (elfeed-tube-setup)

  :bind (:map elfeed-show-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)
         :map elfeed-search-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)))

(use-package elfeed-tube-mpv
  ;; :straight (:host github :repo "karthink/elfeed-tube")
  :bind (:map elfeed-show-mode-map
         ("C-c C-f" . elfeed-tube-mpv-follow-mode)
         ("C-c C-w" . elfeed-tube-mpv-where)))

;; open subsrciptions csv in side buffer and elfeed on left buffer
(defalias 'subscription_elfeed
  (kmacro "0 v f , h y SPC w w i l * * * * SPC [ [ <escape> p i a [ <escape> SPC w w f , i v $ h y SPC w w p o <escape> SPC w w n"))

