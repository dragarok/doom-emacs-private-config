(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(safe-local-variable-values
   '((git-commit-major-mode . git-commit-elisp-text-mode)
     (org-refile-targets)
     (org-download-delete-image-after-download)
     (org-download-method . directory)))
 '(smtpmail-smtp-server "smtp.gmail.com")
 '(smtpmail-smtp-service 587))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(hydra-posframe-border-face ((t (:background "#6272a4"))))
 ;; '(org-ref-cite-face :weight unspecified :foreground unspecified :underline ,(doom-color 'grey))
 '(org-agenda-date ((t (:height 1.1 :background nil))))
 '(org-agenda-date-today ((t (:height 1.5 :background nil))))
 ;; '(org-block ((t (:inherit (fixed-pitch shadow) :background nil :height 1.2))))
 ;; '(org-block-begin-line ((t (:inherit region :background nil :height 0.9))))
 ;; '(org-block-end-line ((t (:inherit region :background nil :height 0.8))))
 ;; '(org-code ((t (:inherit (fixed-pitch shadow) :height 1.1))))
 '(org-block ((t (:inherit (fixed-pitch shadow) :background nil))))
 '(org-block-begin-line ((t (:inherit region :background nil))))
 '(org-block-end-line ((t (:inherit region :background nil))))
 '(org-code ((t (:inherit (fixed-pitch shadow)))))
 '(org-document-info ((t (:foreground "dark orange"))))
 ;; '(org-document-info-keyword ((t (:inherit shadow :height 0.8))))
 ;; '(org-document-title ((t (:height 1.3 :weight normal :underline nil))))
 '(org-done ((t (:strike-through t :weight bold))))
 '(org-ellipsis ((t (:underline nil))))
 '(org-headline-done ((t (:strike-through t))))
 '(org-link ((t (:weight bold :height 1.1 :underline t))))
 '(org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch) :foreground "dark orange"))))
 '(org-property-value ((t (:inherit fixed-pitch))) t)
 '(org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
 '(org-table ((t (:foreground "#83a598" :height 0.8))))
 ;; '(org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 1.1))))
 '(org-verbatim ((t (:inherit shadow))))
 '(outline-1 ((t (:weight extra-bold :height 1.3))))
 '(outline-2 ((t (:weight bold :height 1.25))))
 '(outline-3 ((t (:slant italic :weight bold :height 1.2))))
 '(outline-4 ((t (:slant italic :weight semi-bold :height 1.15))))
 '(outline-5 ((t (:slant italic :weight semi-bold :height 1.1))))
 '(outline-6 ((t (:slant italic :weight semi-bold :height 1.1))))
 '(outline-8 ((t (:slant italic :weight semi-bold :height 1.1))))
 '(outline-9 ((t (:slant italic :weight semi-bold :height 1.1))))
 '(vterm-color-black ((t (:foreground "SandyBrown" :background "SandyBrown")))))

(customize-set-value
 'org-agenda-category-icon-alist
 `(
   ("Events" ,(list (all-the-icons-material "event_note" :height 1.2)) nil nil :ascent center)
   ("Inbox" ,(list (all-the-icons-material "check_box" :height 1.2)) nil nil :ascent center)
   ("ToTheMoon" ,(list (all-the-icons-octicon "rocket" :height 1.2)) nil nil :ascent center)
   ("Hobby" ,(list (all-the-icons-material "spa" :height 1.2)) nil nil :ascent center)
   ("Fitness" ,(list (all-the-icons-material "fitness_center" :height 1.2)) nil nil :ascent center)
   ("Normal" ,(list (all-the-icons-material "computer" :height 1.2)) nil nil :ascent center)
   ("ToImprove" ,(list (all-the-icons-material "motorcycle" :height 1.2)) nil nil :ascent center)
   ("Mundane" ,(list (all-the-icons-material "sentiment_dissatisfied" :height 1.2)) nil nil :ascent center)
   ;; based on where the task comes from
   ;; ("recurring" ,(list (all-the-icons-material "loop" :height 1.2)) nil nil :ascent center)
   ;; ("someday" ,(list (all-the-icons-material "schedule" :height 1.2)) nil nil :ascent center)
   ;; ("project" ,(list (all-the-icons-material "stars" :height 1.2)) nil nil :ascent center)
   ;; ("reading" ,(list (all-the-icons-material "book" :height 1.2)) nil nil :ascent center)
   ;; ("coding" ,(list (all-the-icons-material "code" :height 1.2)) nil nil :ascent center)
   ;; Based on purpose
   ;; ("hobby" ,(list (all-the-icons-material "gamepad" :height 1.2)) nil nil :ascent center)
   ;; ("finance" ,(list (all-the-icons-material "attach_money" :height 1.2)) nil nil :ascent center)
   ;; ("skill" ,(list (all-the-icons-material "directions_bike" :height 1.2)) nil nil :ascent center)
   ;; ("relax" ,(list (all-the-icons-material "ondemand_video" :height 1.2)) nil nil :ascent center)
   ;; ("research" ,(list (all-the-icons-material "explore" :height 1.2)) nil nil :ascent center)
   ;; ("fitness" ,(list (all-the-icons-material "spa" :height 1.2)) nil nil :ascent center)
   ;; ("daytoday" ,(list (all-the-icons-material "local_grocery_store" :height 1.2)) nil nil :ascent center)
   ;; ("feedback" ,(list (all-the-icons-material "loop" :height 1.2)) nil nil :ascent center)
   ;; ;; Things that get excluded from the list of purpose
   ;; ("events" ,(list (all-the-icons-material "event" :height 1.2)) nil nil :ascent center)
   ;; ("inbox" ,(list (all-the-icons-material "check_box" :height 1.2)) nil nil :ascent center)
   ;; ("necessity" ,(list (all-the-icons-material "hourglass_full" :height 1.2)) nil nil :ascent center)
   ;;
   ;; ("office" ,(list (all-the-icons-material "work" :height 1.2)) nil nil :ascent center)
   ;; ("mundane" ,(list (all-the-icons-material "weekend" :height 1.2)) nil nil :ascent center)
   ;; ("emacs" ,(list (all-the-icons-material "format_paint" :height 1.2)) nil nil :ascent center)
   ;; ("tinker" ,(list (all-the-icons-material "build" :height 1.2)) nil nil :ascent center)
   ;; ("freelance" ,(list (all-the-icons-material "redeem" :height 1.2)) nil nil :ascent center)
   ;; ("book" ,(list (all-the-icons-material "book" :height 1.2)) nil nil :ascent center)
   ))

(customize-set-value
 'org-fancy-priorities-list
 `(
   (?A ,(concat " " (all-the-icons-octicon "pulse" :height 1.2) " "))
   (?B ,(concat " " (all-the-icons-octicon "mortar-board" :height 1.2) " "))
   (?C ,(concat " " (all-the-icons-octicon "flame" :height 1.2) " "))
   (?D ,(concat " " (all-the-icons-octicon "telescope" :height 1.2) " "))
   ))

(customize-set-value
 'org-priority-faces
 `(
   (?A . (:foreground "red" :weight bold))
   (?B . (:foreground "green" :weight bold))
   (?C . (:foreground "tomato"))
   (?D . (:foreground "orange"))
   )
 )
