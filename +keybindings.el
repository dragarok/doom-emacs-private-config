;; Keybindings


(define-key 'help-command "A" 'apropos)
(define-key 'help-command (kbd "C-f") 'find-function)
(define-key 'help-command (kbd "C-k") 'find-function-on-key)
(define-key 'help-command (kbd "C-v") 'find-variable)
(define-key 'help-command (kbd "C-l") 'find-library)
(define-key 'help-command (kbd "C-i") 'info-display-manual)
(global-set-key [(shift return)] 'smart-open-line)
(global-set-key (kbd "s-/") 'hippie-expand)
(global-set-key (kbd "C-c a") 'org-agenda)
(define-key global-map (kbd "C-c t") 'org-capture)
(global-set-key (kbd "C-M-\\") 'indent-region-or-buffer)
(global-set-key [remap fill-paragraph] #'endless/fill-or-unfill)
(global-set-key (kbd "<f5>") 'zilongshanren/run-current-file)

;; org-related key bindings by reading the blog
(global-set-key (kbd "<f12>") 'org-agenda)
(global-set-key (kbd "C-c c") #'org-mru-clock-in)
(global-set-key (kbd "C-c C-r") #'org-mru-clock-select-recent-task)

(global-set-key (kbd "C-c o") 'bh/make-org-scratch)
(global-set-key (kbd "C-c s") 'bh/switch-to-scratch)

;; company
(map!
 (:after company
   :map company-active-map
   "TAB"       nil
   [tab]       nil
   [backtab]   nil
   "C-j"         #'company-select-next
   "C-n"         #'company-select-next
   "C-k"         #'company-select-previous
   "C-p"         #'company-select-previous
   "C-d"         #'company-show-doc-buffer
   "C-i"   #'company-complete-selection
   )
 (:after python
   :localleader
   :map python-mode-map
   :desc "Insert breakpoint" "b" #'+python/toggle-breakpoint
   (:prefix ("i" . "Import")
     :desc "Remove unused impoorts" "r" #'+python/autoflake-remove-imports
     :desc "Isort buffer"    "s" #'python-isort-autosave-mode
     :desc "Import at point" "i" #'importmagic-fix-symbol-at-point
     :desc "Import all"      "a" #'importmagic-fix-imports)
   (:prefix ("v" . "ENV")
     "c" #'conda-env-activate
     "C" #'conda-env-deactivate
     "w" #'pyvenv-workon
     "v" #'pyvenv-activate
     "V" #'pyvenv-deactivate
     "p" #'pipenv-activate
     "P" #'pipenv-deactivate))
 )
;; This is for later to configure emacs notebook way of operation.
;;        ("?" spacemacs//ipython-notebook-ms-toggle-doc)
;;        ("h" ein:notebook-worksheet-open-prev-or-last)
;;        ("j" ein:worksheet-goto-next-input)
;;        ("k" ein:worksheet-goto-prev-input)
;;        ("l" ein:notebook-worksheet-open-next-or-first)
;;        ("H" ein:notebook-worksheet-move-prev)
;;        ("J" ein:worksheet-move-cell-down)
;;        ("K" ein:worksheet-move-cell-up)
;;        ("L" ein:notebook-worksheet-move-next)
;;        ("t" ein:worksheet-toggle-output)
;;        ("d" ein:worksheet-kill-cell)
;;        ("R" ein:worksheet-rename-sheet)
;;        ("y" ein:worksheet-copy-cell)
;;        ("p" ein:worksheet-yank-cell)
;;        ("o" ein:worksheet-insert-cell-below)
;;        ("O" ein:worksheet-insert-cell-above)
;;        ("u" ein:worksheet-change-cell-type)
;;        ("RET" ein:worksheet-execute-cell-and-goto-next)
;;        ;; Output
;;        ("C-l" ein:worksheet-clear-output)
;;        ("C-S-l" ein:worksheet-clear-all-output)
;;        ;;Console
;;        ("C-o" ein:console-open)
;;        ;; Merge cells
;;        ("C-k" ein:worksheet-merge-cell)
;;        ("C-j" spacemacs/ein:worksheet-merge-cell-next)
;;        ;; Notebook
;;        ("C-s" ein:notebook-save-notebook-command)
;;        ("C-r" ein:notebook-rename-command)
;;        ("1" ein:notebook-worksheet-open-1th)
;;        ("2" ein:notebook-worksheet-open-2th)
;;        ("3" ein:notebook-worksheet-open-3th)
;;        ("4" ein:notebook-worksheet-open-4th)
;;        ("5" ein:notebook-worksheet-open-5th)
;;        ("6" ein:notebook-worksheet-open-6th)
;;        ("7" ein:notebook-worksheet-open-7th)
;;        ("8" ein:notebook-worksheet-open-8th)
;;        ("9" ein:notebook-worksheet-open-last)
;;        ("+" ein:notebook-worksheet-insert-next)
;;        ("-" ein:notebook-worksheet-delete)
;;        ("x" ein:notebook-close)





(map! :leader
      "8" 'split-window-below
      "9" 'split-window-right
      (:prefix "a"
        :n "h" #'anki-editor-cloze-region-dont-incr
        :n "k" #'anki-editor-cloze-region-auto-incr
        :n "l" #'anki-editor-reset-cloze-number
        :n "j" #'anki-editor-push-tree))

(after! dired
  (map! :map dired-mode-map
        :ng "o" #'dired-find-file-other-window
        :ng "C-k" 'dired-up-directory
        :ng "<RET>" 'dired-find-alternate-file
        :ng "E" 'dired-toggle-read-only
        :ng "C" 'dired-do-copy
        :ng "<mouse-2>" 'my-dired-find-file
        :ng "`" 'dired-open-term
        :ng "p" 'peep-dired-prev-file
        :ng "n" 'peep-dired-next-file
        ;; "gr" 'revert-buffer
        :ng "z" 'dired-get-size
        :ng "c" 'dired-copy-file-here
        :ng "J" 'counsel-find-file
        :ng "f" 'open-file-with-projectile-or-counsel-git
        :ng ")" 'dired-omit-mode))


(map! :localleader
      :map markdown-mode-map
      :prefix ("i" . "Insert")
      :desc "Blockquote"    "q" 'markdown-insert-blockquote
      :desc "Bold"          "b" 'markdown-insert-bold
      :desc "Code"          "c" 'markdown-insert-code
      :desc "Emphasis"      "e" 'markdown-insert-italic
      :desc "Footnote"      "f" 'markdown-insert-footnote
      :desc "Code Block"    "s" 'markdown-insert-gfm-code-block
      :desc "Image"         "i" 'markdown-insert-image
      :desc "Link"          "l" 'markdown-insert-link
      :desc "List Item"     "n" 'markdown-insert-list-item
      :desc "Pre"           "p" 'markdown-insert-pre
      (:prefix ("h" . "Headings")
        :desc "One"   "1" 'markdown-insert-atx-1
        :desc "Two"   "2" 'markdown-insert-atx-2
        :desc "Three" "3" 'markdown-insert-atx-3
        :desc "Four"  "4" 'markdown-insert-atx-4
        :desc "Five"  "5" 'markdown-insert-atx-5
        :desc "Six"   "6" 'markdown-insert-atx-6))


(bind-key "C-<down>" #'+org/insert-item-below)
(map!
 :nvime "<f5> d" #'helm-org-rifle-directories
 :nvime "<f5> b" #'helm-org-rifle-current-buffer
 :nvime "<f5> o" #'helm-org-rifle-org-directory
 :nvime "<f5> a" #'helm-org-rifle-agenda-files)

(map! :leader
      :n "e" #'ace-window
      :n "!" #'swiper
      :n "@" #'swiper-all
      :n "#" #'deadgrep
      :n "$" #'helm-org-rifle-directories
      :n "X" #'org-capture
      :n "/" #'my/last-captured-org-note
      (:prefix-map ("=" . "Refile todos")
        :n "n" #'zyrohex/org-notes-refile
        :n "r" #'zyrohex/org-reference-refile
        :n "t" #'zyrohex/org-tasks-refile)
      (:prefix "o"
        :n "e" #'elfeed
        :n "g" #'metrics-tracker-graph
        :n "o" #'org-open-at-point
        :n "u" #'elfeed-update
        :n "w" #'deft)
      (:prefix-map ("f" . "file")
        "j" #'dired-jump)
      (:prefix "n"
        :n "D" #'dictionary-lookup-definition
        :n "T" #'powerthesaurus-lookup-word)
      (:prefix "s"
        :n "d" #'deadgrep
        :n "q" #'org-ql-search
        :n "b" #'helm-org-rifle-current-buffer
        :n "o" #'helm-org-rifle-org-directory
        :n "." #'helm-org-rifle-directories)
      (:prefix "g"
        "s" #'magit-status)
      (:prefix "b"
        :n "c" #'org-board-new
        :n "e" #'org-board-open)
      (:prefix "t"
        :n "s" #'org-narrow-to-subtree
        :n "w" #'widen))

(bind-keys :prefix-map macro-map
           :prefix "C-c m"
           ("a" . kmacro-add-counter)
           ("b" . kmacro-bind-to-key)
           ("e" . kmacro-edit-macro)
           ("i" . kmacro-insert-counter)
           ("I" . insert-kbd-macro)
           ("K" . kmacro-end-or-call-macro-repeat)
           ("n" . kmacro-cycle-ring-next)
           ("N" . kmacro-name-last-macro)
           ("p" . kmacro-cycle-ring-previous)
           ("r" . apply-macro-to-region-lines)
           ("c" . kmacro-set-counter)
           ("s" . kmacro-start-macro)
           ("t" . kmacro-end-or-call-macro))

(bind-key "C-c 2" 'vsplit-last-buffer)
(bind-key "C-c 3" 'hsplit-last-buffer)
