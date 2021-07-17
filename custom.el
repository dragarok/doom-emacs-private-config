(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("e27556a94bd02099248b888555a6458d897e8a7919fd64278d1f1e8784448941" "ff3c57a5049010a76de8949ddb629d29e2ced42b06098e046def291989a4104a" "56d10d2b60685d112dd54f4ba68a173c102eacc2a6048d417998249085383da1" "990e24b406787568c592db2b853aa65ecc2dcd08146c0d22293259d400174e37" default))
 '(org-super-agenda-mode t t)
 '(safe-local-variable-values
   '((git-commit-major-mode . git-commit-elisp-text-mode)
     (org-refile-targets)
     (org-download-delete-image-after-download)
     (org-download-method . directory)
     (django-commands-list quote
                           ("source activate mhs" "python manage.py runserver"))
     (conda-project-env-path . "mhs")))
 '(smtpmail-smtp-server "smtp.gmail.com")
 '(smtpmail-smtp-service 587))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(hydra-posframe-border-face ((t (:background "#6272a4"))))
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
 '(org-document-title ((t (:height 1.3 :weight normal :underline nil))))
 '(org-done ((t (:strike-through t :weight bold))))
 '(org-ellipsis ((t (:underline nil))))
 '(org-headline-done ((t (:strike-through t))))
 '(org-link ((t (:weight bold :height 1.1 :underline t))))
 '(org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch) :foreground "dark orange"))))
 '(org-property-value ((t (:inherit fixed-pitch))) t)
 '(org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
 '(org-table ((t (:inherit variable-pitch :foreground "#83a598"))))
 ;; '(org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 1.1))))
 '(org-verbatim ((t (:inherit shadow))))
 ;; '(outline-1 ((t (:inherit variable-pitch :weight extra-bold :height 1.3))))
 ;; '(outline-2 ((t (:inherit variable-pitch :weight bold :height 1.25))))
 ;; '(outline-3 ((t (:inherit variable-pitch :slant italic :weight bold :height 1.2))))
 ;; '(outline-4 ((t (:inherit variable-pitch :slant italic :weight semi-bold :height 1.15))))
 ;; '(outline-5 ((t (:inherit variable-pitch :slant italic :weight semi-bold :height 1.1))))
 ;; '(outline-6 ((t (:inherit variable-pitch :slant italic :weight semi-bold :height 1.1))))
 ;; '(outline-8 ((t (:inherit variable-pitch :slant italic :weight semi-bold :height 1.1))))
 ;; '(outline-9 ((t (:inherit variable-pitch :slant italic :weight semi-bold :height 1.1))))
 '(vterm-color-black ((t (:foreground "SandyBrown" :background "SandyBrown")))))

(customize-set-value
 'org-agenda-category-icon-alist
 `(
   ;; based on where the task comes from
   ("tasks" ,(list (all-the-icons-material "functions" :height 1.2)) nil nil :ascent center)
   ("events" ,(list (all-the-icons-material "event_note" :height 1.2)) nil nil :ascent center)
   ("inbox" ,(list (all-the-icons-material "check_box" :height 1.2)) nil nil :ascent center)
   ("recurring" ,(list (all-the-icons-material "loop" :height 1.2)) nil nil :ascent center)
   ("someday" ,(list (all-the-icons-material "schedule" :height 1.2)) nil nil :ascent center)
   ("project" ,(list (all-the-icons-material "stars" :height 1.2)) nil nil :ascent center)
   ("ideas" ,(list (all-the-icons-material "lightbulb_outline" :height 1.2)) nil nil :ascent center)
   ("books" ,(list (all-the-icons-material "book" :height 1.2)) nil nil :ascent center)
   ("finance" ,(list (all-the-icons-material "attach_money" :height 1.2)) nil nil :ascent center)
   ;;
   ;; ("office" ,(list (all-the-icons-material "work" :height 1.2)) nil nil :ascent center)
   ;; ("mundane" ,(list (all-the-icons-material "weekend" :height 1.2)) nil nil :ascent center)
   ;; ("reading" ,(list (all-the-icons-material "book" :height 1.2)) nil nil :ascent center)
   ;; ("coding" ,(list (all-the-icons-material "code" :height 1.2)) nil nil :ascent center)
   ;; ("finance" ,(list (all-the-icons-material "attach_money" :height 1.2)) nil nil :ascent center)
   ;; ("emacs" ,(list (all-the-icons-material "format_paint" :height 1.2)) nil nil :ascent center)
   ;; ("necessity" ,(list (all-the-icons-material "rowing" :height 1.2)) nil nil :ascent center)
   ;; ("tinker" ,(list (all-the-icons-material "build" :height 1.2)) nil nil :ascent center)
   ;; ("personal" ,(list (all-the-icons-material "mood" :height 1.2)) nil nil :ascent center)
   ;; ("planning" ,(list (all-the-icons-material "tune" :height 1.2)) nil nil :ascent center)
   ;; ("research" ,(list (all-the-icons-material "explore" :height 1.2)) nil nil :ascent center)
   ;; ("freelance" ,(list (all-the-icons-material "redeem" :height 1.2)) nil nil :ascent center)
   ;; ("book" ,(list (all-the-icons-material "book" :height 1.2)) nil nil :ascent center)
   ;; ("chill" ,(list (all-the-icons-material "gamepad" :height 1.2)) nil nil :ascent center)
   ))
