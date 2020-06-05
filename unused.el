;;; ~/.doom.d/unused.el -*- lexical-binding: t; -*-


;; (use-package pdf-tools
;;   :defer t
;;   ;; :pin manual ;; manually update
;;   ;; :straight tablist
;;   ;; :straight hydra
;;   ;; :straight web-server
;;   ;; :load-path (lambda () (if (memq system-type '(windows-nt)) ;; If under Windows, use the customed build in Dropbox.
;;   ;;                       (expand-file-name "elisp/pdf-tools-20180428.827/"
;;   ;;                                         my-emacs-conf-directory)))
;;   ;; Tell Emacs to autoloads the package
;;   ;; :init (load "pdf-tools-autoloads" nil t)
;;   ;; If under Linux, manually install it with package-install.
;;   ;; If there's error for pdf-occur mode, delete pdf-occur.elc manually.
;;   :bind (:map pdf-view-mode-map
;;               ("C-s" . 'isearch-forward)
;;               ("C-r" . 'isearch-backward)
;;               ("C-z p" . hydra-pdftools/body)
;;               ("M-w" . 'pdf-view-kill-ring-save)
;;               ("c" . 'pdf-annot-add-highlight-markup-annotation)
;;               ("d" . 'pdf-annot-add-text-annotation)
;;               ("D" . 'pdf-annot-delete)
;;               ("S" . 'sync-pdf-in-pdfjs)
;;               )
;;   :magic ("%PDF" . pdf-view-mode)
;;   :config
;;   (add-to-list 'load-path "/home/light/.emacs-web-server")
;;   (setq-default pdf-view-display-size 'fit-width)
;;   ;; automatically annotate highlights
;;   (setq pdf-annot-activate-created-annotations t)
;;   ;; zoom set to 10% instead of 25
;;   (setq pdf-view-resize-factor 1.1)
;;   ;; keyboard shortcuts
;;   (define-key pdf-view-mode-map (kbd "c") 'pdf-annot-add-highlight-markup-annotation)
;;   (define-key pdf-view-mode-map (kbd "d") 'pdf-annot-add-text-annotation)
;;   (define-key pdf-view-mode-map (kbd "D") 'pdf-annot-delete)
;;   ;; use normal isearch
;;   (define-key pdf-view-mode-map (kbd "C-s-/") 'isearch-forward)
;;   ;; automatically annotate highlights
;;   (setq pdf-annot-activate-created-annotation t)

;;   (pdf-tools-install t) ;; Install pdf tools with no queries
;;   )

;;   (defhydra hydra-pdftools (:color blue :hint nil)
;;     "
;;                                                                       ╭───────────┐
;;        Move  History   Scale/Fit     Annotations  Search/Link    Do   │ PDF Tools │
;;    ╭──────────────────────────────────────────────────────────────────┴───────────╯
;;          ^^_g_^^      _B_    ^↧^    _+_    ^ ^      [_al_] list    [_s_] search    [_u_] revert buffer
;;          ^^^↑^^^      ^↑^    _H_    ^↑^  ↦ _W_ ↤     [_am_] markup  [_o_] outline   [_i_] info
;;          ^^_p_^^      ^ ^    ^↥^    _0_    ^ ^      [_at_] text    [_F_] link      [_d_] dark mode
;;          ^^^↑^^^      ^↓^  ╭─^─^─┐  ^↓^  ╭─^ ^─┐   [_ad_] delete  [_f_] search link
;;     _h_ ←pag_e_→ _l_  _N_  │ _P_ │  _-_    _b_     [_aa_] dired
;;          ^^^↓^^^      ^ ^  ╰─^─^─╯  ^ ^  ╰─^ ^─╯   [_y_]  yank
;;          ^^_n_^^      ^ ^  _r_eset slice box
;;          ^^^↓^^^
;;          ^^_G_^^
;;    --------------------------------------------------------------------------------
;;         "
;;     ("\\" hydra-master/body "back")
;;     ("<ESC>" nil "quit")
;;     ("al" pdf-annot-list-annotations)
;;     ("ad" pdf-annot-delete)
;;     ("aa" pdf-annot-attachment-dired)
;;     ("am" pdf-annot-add-markup-annotation)
;;     ("at" pdf-annot-add-text-annotation)
;;     ("y"  pdf-view-kill-ring-save)
;;     ("+" pdf-view-enlarge :color red)
;;     ("-" pdf-view-shrink :color red)
;;     ("0" pdf-view-scale-reset)
;;     ("H" pdf-view-fit-height-to-window)
;;     ("W" pdf-view-fit-width-to-window)
;;     ("P" pdf-view-fit-page-to-window)
;;     ("n" pdf-view-next-page-command :color red)
;;     ("p" pdf-view-previous-page-command :color red)
;;     ("d" pdf-view-dark-minor-mode)
;;     ("b" pdf-view-set-slice-from-bounding-box)
;;     ("r" pdf-view-reset-slice)
;;     ("g" pdf-view-first-page)
;;     ("G" pdf-view-last-page)
;;     ("e" pdf-view-goto-page)
;;     ("o" pdf-outline)
;;     ("s" pdf-occur)
;;     ("i" pdf-misc-display-metadata)
;;     ("u" pdf-view-revert-buffer)
;;     ("F" pdf-links-action-perfom)
;;     ("f" pdf-links-isearch-link)
;;     ("B" pdf-history-backward :color red)
;;     ("N" pdf-history-forward :color red)
;;     ("l" image-forward-hscroll :color red)
;;     ("h" image-backward-hscroll :color red))
;;   )




;; (after! org
;;   (setq org-time-budgets '((:title "Work" :tags "+@work" :budget "30:00" :block workweek)
;;                            (:title "Sideprojects" :tags "+@personal+project" :budget "15:00" :block week)
;;                            (:title "Music Practice" :tags "+music" :budget "4:00" :block week)
;;                            (:title "Evolution" :tags "+@growth" :budget "5:00" :block week)
;;                            (:title "Easy work" :tags "+Easy" :budget "40:00" :block week)
;;                            (:title "Average" :tags "+Average" :budget "20:00" :block week)
;;                            (:title "Challenge" :tags "+Challenge" :budget "10:00" :block week)
;;                            (:title "Personal Tasks" :tags "+@personal" :budget "19:00" :block week)))
;; )




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Prism color chooser                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; (unpackaged/define-chooser ap/prism-theme
;;   ("Keen"
;;    (prism-set-colors :num 16
;;      :local (pcase current-prefix-arg
;;               ('(16) 'reset)
;;               (_ current-prefix-arg))
;;      :desaturations (cl-loop for i from 0 below 16
;;                              collect (* i 2.5))
;;      :lightens (cl-loop for i from 0 below 16
;;                         collect (* i 2.5))
;;      :colors (list "sandy brown" "dodgerblue" "medium sea green")
;;      :comments-fn (lambda (color)
;;                     (prism-blend color (face-attribute 'font-lock-comment-face :foreground)
;;                                  0.25))
;;      :strings-fn (lambda (color)
;;                    (prism-blend color "white" 0.5))))
;;   ("Solarized: rainbow"
;;    (prism-set-colors :num 24
;;      :local (pcase current-prefix-arg
;;               ('(16) 'reset)
;;               (_ current-prefix-arg))
;;      :lightens '(5 15 25)
;;      :colors (list "#dc322f" "#cb4b16" "#b58900" "#859900" "#268bd2" "#2aa198" "#6c71c4" "#d33682")
;;      :comments-fn (lambda (color)
;;                     (--> color
;;                          (color-desaturate-name it 50)))
;;      :strings-fn (lambda (color)
;;                    (prism-blend color "white" 0.5))))
;;   ("Solarized: rainbow inverted"
;;    (prism-set-colors :num 24
;;      :local (pcase current-prefix-arg
;;               ('(16) 'reset)
;;               (_ current-prefix-arg))
;;      :lightens '(5 15 25)
;;      :colors (nreverse (list "#dc322f" "#cb4b16" "#b58900" "#859900" "#268bd2" "#2aa198" "#6c71c4" "#d33682"))
;;      :comments-fn (lambda (color)
;;                     (--> color
;;                          (color-desaturate-name it 50)))
;;      :strings-fn (lambda (color)
;;                    (prism-blend color "white" 0.5)))))
