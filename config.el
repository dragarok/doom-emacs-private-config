;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;;(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;; To get information about any of these functions/macros, move the cursor over the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.





;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Personal-info                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setq user-full-name "Alok Regmi"
      user-mail-address "sagar.r.alok@gmail.com")


;; pretty mode hassling everywhere even when not needed
;;(remove-hook 'after-change-major-mode-hook #'+pretty-code-init-pretty-symbols-h)


;; ascii art taken from https://www.asciiart.eu/space/telescopes (Telescope by Dokusan)
(defun doom-dashboard-widget-banner ()
  (let ((point (point)))
    (mapc (lambda (line)
            (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                                'face 'doom-dashboard-banner) " ")
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Basic-fns                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;(require 'golden-ratio)

;;(golden-ratio-mode 1)

;; replacement to buggy golden ratio mode
(require 'zoom)
(setq-default zoom-mode t)
;;(setq zoom-size '(0.618 . 0.618))


;;wallpapers

;;(use-package dired-subtree
;;  :ensure t
;;  :after dired
;;  :bind (:map dired-mode-map
;;              ("<tab>" . dired-subtree-toggle)
;;              ("<C-tab>" . dired-subtree-cycle)
;;              ("<backtab>" . dired-subtree-remove)))


;;(after! dired
;;  (add-hook 'dired-mode-hook 'all-the-icons-dired-mode))
;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)


(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "Iosevka Nerd Font" :size 14)
      doom-variable-pitch-font (font-spec :family "Source Code Variable" :size 12)
      doom-unicode-font (font-spec :family "Iosevka Nerd Font")
      doom-big-font (font-spec :family "Iosevka Nerd Font Complete Mono" :size 12))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-acario-dark)
(setq doom-themes-treemacs-theme "doom-colors") ; use the colorful treemacs theme

;;elfeed
(after! org (setq rmh-elfeed-org-files (list "~/Dropbox/elfeed/elfeed.org")
                  elfeed-db-directory "~/Dropbox/elfeed/"))






;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Deft                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(use-package deft
  :bind (("<f8>" . deft))
  :commands (deft deft-open-file deft-new-file-named)
  :config
  (setq deft-directory "~/Dropbox/org/notes/"
        deft-auto-save-interval 0
        deft-use-filename-as-title nil
        deft-current-sort-method 'title
        deft-recursive t
        deft-extensions '("md" "txt" "org")
        deft-markdown-mode-title-level 1
        deft-file-naming-rules '((noslash . "-")
                                 (nospace . "-")
                                 (case-fn . downcase)))
 
  (defun my-deft/strip-quotes (str)
    (cond ((string-match "\"\\(.+\\)\"" str) (match-string 1 str))
          ((string-match "'\\(.+\\)'" str) (match-string 1 str))
          (t str)))

  (defun my-deft/parse-title-from-front-matter-data (str)
    (if (string-match "^title: \\(.+\\)" str)
        (let* ((title-text (my-deft/strip-quotes (match-string 1 str)))
               (is-draft (string-match "^draft: true" str)))
          (concat (if is-draft "[DRAFT] " "") title-text))))

  (defun my-deft/deft-file-relative-directory (filename)
    (file-name-directory (file-relative-name filename deft-directory)))

  (defun my-deft/title-prefix-from-file-name (filename)
    (let ((reldir (my-deft/deft-file-relative-directory filename)))
      (if reldir
          (concat (directory-file-name reldir) " > "))))

  (defun my-deft/parse-title-with-directory-prepended (orig &rest args)
    (let ((str (nth 1 args))
          (filename (car args)))
      (concat
       (my-deft/title-prefix-from-file-name filename)
       (let ((nondir (file-name-nondirectory filename)))
         (if (or (string-prefix-p "README" nondir)
                 (string-suffix-p ".txt" filename))
             nondir
           ;; for files whose title can't be properly parsed due to hugo flags.
           (org-roam--get-title-or-slug filename)
       )))))

;;  (defun my-deft/parse-title-with-directory-prepended (orig &rest args)
;;    (let ((str (nth 1 args))
;;          (filename (car args)))
;;      (concat
;;       (my-deft/title-prefix-from-file-name filename)
;;       (let ((nondir (file-name-nondirectory filename)))
;;         (if (or (string-prefix-p "README" nondir)
;;                 (string-suffix-p ".txt" filename))
;;             nondir
;;           (if (string-prefix-p "---\n" str)
;;               (my-deft/parse-title-from-front-matter-data
;;                (car (split-string (substring str 4) "\n---\n")))
;;             (apply orig args))))
;;
;;       )))
  (provide 'my-deft-title)
  (require 'my-deft-title) (advice-add 'deft-parse-title :around #'my-deft/parse-title-with-directory-prepended))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Novel mode                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package nov
  :defer t
  :config
  (setq nov-text-width t
        visual-fill-column-center-text t)
  (add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))
  (defun my-nov-font-setup ()
    (face-remap-add-relative 'variable-pitch :family "Liberation Serif"
                             :size 16
                             :height 1.3))
  (add-hook 'nov-mode-hook 'visual-line-mode)
  (add-hook 'nov-mode-hook 'visual-fill-column-mode)
  (add-hook 'nov-mode-hook 'my-nov-font-setup)
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Pdf tools                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(use-package pdf-tools
  :defer t
  :config
  ;; initialise
  (pdf-tools-install)
  ;; open pdfs scaled to fit page
  (setq-default pdf-view-display-size 'fit-width)
  ;; automatically annotate highlights
  (setq pdf-annot-activate-created-annotations t)
  ;; zoom set to 10% instead of 25
  (setq pdf-view-resize-factor 1.1)
  ;; keyboard shortcuts
  (define-key pdf-view-mode-map (kbd "c") 'pdf-annot-add-highlight-markup-annotation)
  (define-key pdf-view-mode-map (kbd "d") 'pdf-annot-add-text-annotation)
  (define-key pdf-view-mode-map (kbd "D") 'pdf-annot-delete)
  ;; use normal isearch
  (define-key pdf-view-mode-map (kbd "C-s-/") 'isearch-forward)
  (with-eval-after-load "pdf-annot"
    (define-key pdf-annot-edit-contents-minor-mode-map (kbd "<return>") 'pdf-annot-edit-contents-commit)
    (define-key pdf-annot-edit-contents-minor-mode-map (kbd "<S-return>") 'newline)
    ;; save after adding comment
    (advice-add 'pdf-annot-edit-contents-commit :after 'bjm/save-buffer-no-args))
)



(use-package org-pdftools
  :defer t
  :init (setq org-pdftools-search-string-separator "??")
  :config (setq org-pdftools-root-dir "~/Dropbox/pdfs/")
  (after! org
    (org-link-set-parameters "pdftools"
                             :follow #'org-pdftools-open
                             :complete #'org-pdftools-complete-link
                             :store #'org-pdftools-store-link
                             :export #'org-pdftools-export)
    (add-hook 'org-store-link-functions 'org-pdftools-store-link))
)







;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        References                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(use-package org-ref
  :after org)
(use-package org-ref-ox-hugo
  :after org org-ref ox-hugo
  :config
  (add-to-list 'org-ref-formatted-citation-formats
               '("md"
                 ("article" . "${author}, *${title}*, ${journal}, *${volume}(${number})*, ${pages} (${year}). ${doi}")
                 ("inproceedings" . "${author}, *${title}*, In ${editor}, ${booktitle} (pp. ${pages}) (${year}). ${address}: ${publisher}.")
                 ("book" . "${author}, *${title}* (${year}), ${address}: ${publisher}.")
                 ("phdthesis" . "${author}, *${title}* (Doctoral dissertation) (${year}). ${school}, ${address}.")
                 ("inbook" . "${author}, *${title}*, In ${editor} (Eds.), ${booktitle} (pp. ${pages}) (${year}). ${address}: ${publisher}.")
                 ("incollection" . "${author}, *${title}*, In ${editor} (Eds.), ${booktitle} (pp. ${pages}) (${year}). ${address}: ${publisher}.")
                 ("proceedings" . "${editor} (Eds.), _${booktitle}_ (${year}). ${address}: ${publisher}.")
                 ("unpublished" . "${author}, *${title}* (${year}). Unpublished manuscript.")
                 ("misc" . "${author} (${year}). *${title}*. Retrieved from [${howpublished}](${howpublished}). ${note}.")
                 (nil . "${author}, *${title}* (${year}).")))
)

;; Comehere
(after! org
  (setq bibtex-completion-library-path "~/Dropbox/pdfs/"
      bibtex-completion-bibliography "~/Dropbox/org/references/articles.bib"
      bibtex-completion-notes-path "~/Dropbox/org/references/articles.org"
      bibtex-completion-notes-path "~/Dropbox/org/references/articles.org")

  (setq org-ref-notes-directory "~/Dropbox/org/notes/"
      org-ref-bibliography-notes "~/Dropbox/org/references/articles.org"
      org-ref-default-bibliography '("~/Dropbox/org/references/articles.bib")
      org-ref-pdf-directory "~/Dropbox/pdfs")
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org noter and pdftools                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org-noter
  :defer t
  :commands
  (org-noter org-noter-create-skeleton)
  :config
  (require 'org-noter-pdftools)
  (after! pdf-tools
    (setq pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note))
  (setq org-noter-notes-search-path '("~/Dropbox/org/interleave_notes/"))
  (setq org-noter-always-create-frame nil)
)


(use-package org-noter-pdftools
  :after (org-noter)
)





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org-roam config                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; org roam protocol
;;(after! org
;;  (require 'org-roam-protocol)
;;)
;;;; org roam loading
;;(use-package! org-roam
;;  :defer t
;;  :commands (org-roam-insert org-roam-find-file org-roam)
;;  :init
;;  (setq org-roam-directory "~/Dropbox/org/notes")
;;  (map! :leader
;;        :prefix "d"
;;        :desc "org-roam" "d" #'org-roam
;;        :desc "Org-Roam-Insert" "l" #'org-roam-insert
;;        :desc "org-roam-switch-to-buffer" "s" #'org-roam-switch-to-buffer
;;        :desc "Org-Roam-Find"   "f" #'org-roam-find-file
;;        :desc "Org-Roam-Graph"  "g" #'org-roam-show-graph)
;;  :config
;;  (setq org-roam-completion-system 'default)
;;  (setq org-roam-link-title-format "R:%s")
;;  (with-eval-after-load 'org-roam
;;    (with-eval-after-load 'company
;;      (with-eval-after-load 'org
;;        (require 'company-org-roam)
;;        (company-org-roam-init))))
;;
(after! org-roam
  (setq org-roam-directory "~/Dropbox/org/notes/")
  (setq org-roam-capture-templates
        '(("x" "default" plain (function org-roam--capture-get-point)
           "%?"
           :file-name "${slug}"
           :head "#+SETUPFILE:./hugo_setup.org
#+HUGO_SECTION: braindump
#+HUGO_SLUG: ${slug}
#+TITLE: ${title}\n"
           :unnarrowed t)

          ("e" "ref" plain (function org-roam--capture-get-point)
           "%?"
           :file-name "websites/${slug}"
           :head "#+SETUPFILE:./hugo_setup.org
#+ROAM_KEY: ${ref}
#+HUGO_SLUG: ${slug}
#+TITLE: ${title}

- source :: ${ref}"
           :unnarrowed t)

          ("k" "private" plain (function org-roam--capture-get-point)
           "%?"
           :file-name "private-${slug}"
           :head "#+TITLE: ${title}\n"
           :unnarrowed t)

          ("h" "hugo blogging" plain
           (function org-roam--capture-get-point)
           "%?"
           :file-name "%<%Y%m%d%H%M%S>-${slug}"
           :head "#+SETUPFILE:./hugo_setup.org
#+HUGO_SECTION: posts
#+HUGO_TAGS: %^{Tags}
#+EXPORT_FILE_NAME: %^{export name}
#+TITLE: ${title}
#+AUTHOR: Alok Regmi
#+DATE: %t"
           :unnarrowed t)
          ))
)

(after! (org org-roam)
    (defun my/org-roam--backlinks-list (file)
      (if (org-roam--org-roam-file-p file)
          (--reduce-from
           (concat acc (format "- [[file:%s][%s]]\n"
                               (file-relative-name (car it) org-roam-directory)
                               (org-roam--get-title-or-slug (car it))))
           "" (org-roam-sql [:select [from]
                             :from links
                             :where (= to $s1)
                             :and from :not :like $s2] file "%private%"))
        ""))
    (defun my/org-export-preprocessor (_backend)
      (let ((links (my/org-roam--backlinks-list (buffer-file-name))))
        (unless (string= links "")
          (save-excursion
            (goto-char (point-max))
            (insert (concat "\n* Backlinks\n" links))))))
    (add-hook 'org-export-before-processing-hook 'my/org-export-preprocessor))

(after! (org ox-hugo)
  (defun jethro/conditional-hugo-enable ()
    (save-excursion
      (if (cdr (assoc "SETUPFILE" (org-roam--extract-global-props '("SETUPFILE"))))
          (org-hugo-auto-export-mode +1)
        (org-hugo-auto-export-mode -1))))
  (add-hook 'org-mode-hook #'jethro/conditional-hugo-enable))





;;;; org roam backlinks
;;(with-eval-after-load 'org
;;  (defun my/org-roam--backlinks-list (file)
;;    (if (org-roam--org-roam-file-p file)
;;        (--reduce-from
;;         (concat acc (format "- [[file:%s][%s]]\n"
;;                             (file-relative-name (car it) org-roam-directory)
;;                             (org-roam--get-title-or-slug (car it))))
;;         "" (org-roam-sql [:select [file-from]
;;                                   :from file-links
;;                                   :where (= file-to $s1)
;;                                   :and file-from :not :like $s2] file "%private%"))
;;      ""))
;;  (defun my/org-export-preprocessor (_backend)
;;    (let ((links (my/org-roam--backlinks-list (buffer-file-name))))
;;      (unless (string= links "")
;;        (save-excursion
;;          (goto-char (point-max))
;;          (insert (concat "\n* Backlinks\n" links))))))
;;  (add-hook 'org-export-before-processing-hook 'my/org-export-preprocessor))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Blogging                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(after! org (setq org-publish-project-alist
                  '(("references-attachments"
                     :base-directory "~/Dropbox/org/notes/images/"
                     :base-extension "jpg\\|jpeg\\|png\\|pdf\\|css"
                     :publishing-directory "~/Dropbox/publish/publish_html/references/images"
                     :publishing-function org-publish-attachment)
                    ("references-md"
                     :base-directory "~/Dropbox/org/notes/"
                     :publishing-directory "~/Dropbox/publish/publish_md"
                     :base-extension "org"
                     :recursive t
                     :headline-levels 5
                     :publishing-function org-html-publish-to-html
                     :section-numbers nil
                     :html-head "<link rel=\"stylesheet\" href=\"http://thomasf.github.io/solarized-css/solarized-light.min.css\" type=\"text/css\"/>"
                     :infojs-opt "view:t toc:t ltoc:t mouse:underline buttons:0 path:http://thomas.github.io/solarized-css/org-info.min.js"
                     :with-email t
                     :with-toc t)
                    ("tasks"
                     :base-directory "~/Dropbox/org/gtd/"
                     :publishing-directory "~/Dropbox/publish/publish_tasks"
                     :base-extension "org"
                     :recursive t
                     :auto-sitemap t
                     :sitemap-filename "index"
                     :html-link-home "../index.html"
                     :publishing-function org-html-publish-to-html
                     :section-numbers nil
                     :html-head "<link rel=\"stylesheet\" href=\"https://codepen.io/nmartin84/pen/MWWdwbm.css\" type=\"text/css\"/>"
                     :with-email t
                     :html-link-up ".."
                     :auto-preamble t
                     :with-toc t)
                    ("pdf"
                     :base-directory "~/Dropbox/org/references/"
                     :base-extension "org"
                     :publishing-directory "~/Dropbox/publish/publish_pdf"
                     :preparation-function somepreparationfunction
                     :completion-function  somecompletionfunction
                     :publishing-function org-latex-publish-to-pdf
                     :recursive t
                     :latex-class "koma-article"
                     :headline-levels 5
                     :with-toc t)
                    ("myprojectweb" :components("references-attachments" "pdf" "references-md" "tasks")))))

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




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                       Julia Programming                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(use-package julia-snail
  :defer t
  :hook (julia-mode . julia-snail-mode))
(setq lsp-julia-default-environment "~/.julia/environments/v1.4")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Competitive Programming                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(use-package leetcode
  :defer t
  :config
  (setq leetcode-prefer-language "python3"
        leetcode-prefer-sql "mysql"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Python                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;checkhere
(use-package conda
  :after python
  :init
  (setq-default
   conda-env-home-directory "/opt/anaconda3/"
   conda-anaconda-home "/opt/anaconda3/bin/")
  :config
  (setq flycheck-checker-error-threshold nil)
  ;; if you want interactive shell support, include:
  (conda-env-initialize-interactive-shells)
  ;; if you want eshell support, include:
  (conda-env-initialize-eshell)
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Js and HTML                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Web mode
(eval-after-load 'js2-mode
  '(define-key js2-mode-map (kbd "C-c b") 'web-beautify-js))

(eval-after-load 'js
  '(define-key js-mode-map (kbd "C-c b") 'web-beautify-js))

(eval-after-load 'json-mode
  '(define-key json-mode-map (kbd "C-c b") 'web-beautify-js))

(eval-after-load 'sgml-mode
  '(define-key html-mode-map (kbd "C-c b") 'web-beautify-html))

(eval-after-load 'web-mode
  '(define-key web-mode-map (kbd "C-c b") 'web-beautify-html))

(eval-after-load 'css-mode
  '(define-key css-mode-map (kbd "C-c b") 'web-beautify-css))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Dart and Flutter                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Dart and Flutter
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
;;  (dart-enable-analysis-server t))

(use-package flutter
  :after dart-mode
  :custom
  (flutter-sdk-path "/opt/flutter/"))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Anki Editor                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package anki-editor
  :after org
 ;; :hook (org-capture-after-finalize . anki-editor-reset-cloze-number) ; Reset cloze-number after each capture.
  :config
  (setq anki-editor-create-decks t
        anki-editor-org-tags-as-anki-tags t)
  ;; Initialize
;;  (anki-editor-reset-cloze-number)
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





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Link abbrev list                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Add links from various places with ease
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

;; treemacs to ignore files from gitignore
(with-eval-after-load 'treemacs
  (defun treemacs-ignore-gitignore (file _)
    (string= file ".gitignore"))
  (push #'treemacs-ignore-gitignore treemacs-ignored-file-predicates))

(use-package gif-screencast
  :defer t
  :bind
  ("<C-print>" . gif-screencast-start-or-stop)
  :config
  (setq gif-screencast-output-directory (expand-file-name "images/gif-screencast" org-directory)))


(use-package plantuml-mode
  :defer t
  :mode ("\\.plantuml\\'" . plantuml-mode)
  :config
  (setq plantuml-executable-path "/usr/bin/plantuml")
  (setq plantuml-default-exec-mode 'executable)
)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Org mode config                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(after! org
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






 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;                                        Org mode UI                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; beautiful bullets
  (setq org-bullets-bullet-list '("◉" "◎" "✸" "✿" "✤" "⚫")
        org-hide-emphasis-markers t
        org-list-demote-modify-bullet '(("+" . "-") ("1." . "a.") ("-" . "+"))
        org-ellipsis "▼")

  ;; emphasis beautiful
  (setq org-emphasis-alist
  '(("*" (bold :foreground "Orange" ))
    ("/" italic)
    ("_" underline)
    ("=" (:foreground "maroon"))
    ("@" (:foreground "seashell"))
    ("~" (:foreground "deep sky blue"))
    ("+" (:strike-through t))))

  (let* ((variable-tuple
          (cond ((x-list-fonts "Iosevka Nerd Font") '(:font "Iosevka Nerd Font"))
                ((x-list-fonts "Liberation Serif")   '(:font "Liberation Serif"))
                ((x-family-fonts "Sans Serif")    '(:family "Sans Serif"))
                (nil (warn "Cannot find a Sans Serif Font.  Install Source Sans Pro."))))
         (headline           `(:inherit default :weight bold )))

    (custom-theme-set-faces
     'user
     `(org-level-8 ((t (:foreground "DarkGoldenrod4" ,@headline ,@variable-tuple :height 1.0))))
     `(org-level-7 ((t (:foreground "OrangeRed3",@headline ,@variable-tuple :height 1.10))))
     `(org-level-6 ((t (:foreground "DarkGoldenrod2",@headline ,@variable-tuple :height 1.15))))
     `(org-level-5 ((t (:foreground "brown",@headline ,@variable-tuple :height 1.2))))
     `(org-level-4 ((t (:foreground "#c397d8",@headline ,@variable-tuple :height 1.25))))
     `(org-level-3 ((t (:foreground "DarkOliveGreen3",@headline ,@variable-tuple :height 1.30))))
     `(org-level-2 ((t (:foreground "goldenred",@headline ,@variable-tuple :height 1.35))))
     `(org-level-1 ((t (:foreground "#d54e53" ,@headline ,@variable-tuple :height 1.4))))
     `(org-document-title ((t (:foreground "OrangeRed3",@headline ,@variable-tuple :height 1.45 :underline nil))))))

  (custom-theme-set-faces
   'user
   '(variable-pitch ((t (:family "Iosevka Nerd Font" :height 180 :weight medium))))
   '(fixed-pitch ((t ( :family "Iosevka Nerd Font" :slant normal :weight normal :height 1.0 :width normal)))))
  (add-hook 'org-mode-hook 'variable-pitch-mode)
  (add-hook 'org-mode-hook 'visual-line-mode)
  (custom-theme-set-faces
   'user
   '(org-block ((t (:inherit fixed-pitch))))
   '(org-code ((t (:inherit (shadow fixed-pitch)))))
   '(org-document-info ((t (:foreground "dark orange"))))
   '(org-document-info-keyword ((t (:inherit (shadow fixed-pitch)))))
   '(org-indent ((t (:inherit (org-hide fixed-pitch)))))
   '(org-link ((t (:foreground "royal blue" :underline t))))
   '(org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch)))))
   '(org-property-value ((t (:inherit fixed-pitch))) t)
   '(org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
   '(org-table ((t (:inherit fixed-pitch :foreground "#83a598"))))
   '(org-done ((t (:strike-through t :weight bold))))
   '(org-headline-done ((t (:strike-through t))))
   '(org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 1.1))))
   '(org-verbatim ((t (:inherit (shadow fixed-pitch))))))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Popup buffer rules                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(set-popup-rule! "*helm*" :side 'bottom :height .35 :select t :vslot 5 :ttl 3)

;; Popup rules for certain buffers
(after! org
  (set-popup-rule! "^CAPTURE-[A-Za-z]*\.org$" :side 'right :size .50 :select t :vslot 2 :ttl 3)
  (set-popup-rule! "Dictionary" :side 'bottom :height .40 :width 20 :select t :vslot 3 :ttl 3)
  (set-popup-rule! "*eww*" :side 'right :size .40 :slect t :vslot 5 :ttl 3)
  (set-popup-rule! "*deadgrep" :side 'bottom :height .40 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "*org-roam" :side 'right :size .35 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "\\Swiper" :side 'bottom :size .30 :select t :vslot 4 :ttl 3)
  (set-popup-rule! "*xwidget" :side 'right :size .40 :select t :vslot 5 :ttl 3)
  (set-popup-rule! "*eshell*" :side 'bottom :size .30 :select t :hslot 2 :ttl 3)
)

;; comehere--todo
;; reveal js presentation configuration
;;(after! org
;;  (require 'ox-reveal)
;;  (setq org-reveal-title-slide nil)
;;  (setq org-reveal-root "file://~/Dropbox/reveal/js/reveal.js")
;;  (setq sentence-end-double-space nil)
;;)

;; comehere--todo : First make sure effort works then uncomment this
;;(after! org
;;
;;  (add-hook 'org-clock-in-prepare-hook
;;            'my/org-mode-ask-effort)
;;
;;  (defun my/org-mode-ask-effort ()
;;    "Ask for an effort estimate when clocking in."
;;    (unless (org-entry-get (point) "Effort")
;;      (let ((effort
;;             (completing-read
;;              "Effort: "
;;              (org-entry-get-multivalued-property (point) "Effort"))))
;;        (unless (equal effort "")
;;          (org-set-property "Effort" effort)))))
;;
;;  (defun jethro/set-todo-state-next ()
;;    "Visit each parent task and change NEXT states to TODO"
;;    (org-todo "NEXT"))
;;
;;  (add-hook 'org-clock-in-hook 'jethro/set-todo-state-next 'append)
;;)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Agenda and Views                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(after! org


  (setq org-super-agenda-mode t)
  (setq org-agenda-files '("~/Dropbox/org/gtd/"))
  ;;(setq org-agenda-start-with-log-mode t)

  (setq org-columns-default-format "%40ITEM(Task) %Effort(EE){:} %CLOCKSUM(Time Spent) %SCHEDULED(Scheduled) %DEADLINE(Deadline) %TAGS")

  (setq org-tags-exclude-from-inheritance '("project"))
  (setq org-agenda-sorting-strategy
      '((agenda time-up) (todo time-up) (tags time-up) (search time-up)))

  (add-to-list 'org-global-properties
               '("Effort". "0:05 0:15 0:30 1:00 2:00 3:00 4:00"))
;;  (setq org-agenda-prefix-format
;;        '((agenda . " %i %-12:c%?-14t%s")
;;          (timeline . "  % s")
;;          (todo . " %i %-14:c")
;;          (tags . " %i %-14:c")
;;          (search . " %i %-14:c")))

  (setq org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        ;;org-habit-show-habits t
  )

  (setq org-super-agenda-groups
                  '((:auto-category t)))



  (setq org-todo-keyword-faces
                    '(("TODO" :foreground "tomato" :weight bold)
                      ("WAITING" :foreground "light sea green" :weight bold)
                      ("SOMEDAY" :foreground "firebrick" :weight bold)
                      ("STARTED" :foreground "DodgerBlue" :weight bold)
                      ("DELEGATED" :foreground "Gold" :weight bold)
                      ("NEXT" :foreground "violet red" :weight bold)
                      ("DONE" :foreground "slategrey" :weight bold)))

  (setq org-todo-keywords
      '((sequence "TODO(t)" "STARTED(s!)" "WAITING(w@/!)" "NEXT(n)" "SOMEDAY(f@/!)" "PROJ(p)" "|" "DONE(d!)" "CANCELLED(c@/!)")))
;;
;;  (setq org-todo-state-tags-triggers
;;        (quote (("CANCELLED" ("CANCELLED" . t))
;;                ("WAITING" ("WAITING" . t))
;;                (done ("WAITING") ("SOMEDAY"))
;;                ("TODO" ("WAITING") ("CANCELLED") ("SOMEDAY"))
;;                ("NEXT" ("WAITING") ("CANCELLED") ("SOMEDAY"))
;;                ("DONE" ("WAITING") ("CANCELLED") ("SOMEDAY"))
;;                ("SOMEDAY" ("WAITING") ("SOMEDAY" . t)))))

  (setq org-log-state-notes-insert-after-drawers nil
        org-log-into-drawer t
        org-log-done 'time
        org-log-repeat 'time
        org-log-redeadline 'note
        org-log-reschedule 'note)

  (setq org-refile-targets '((org-agenda-files . (:maxlevel . 5)))
        org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm)

  (advice-add #'org-refile :after #'org-save-all-org-buffers)
  (advice-add #'org-agenda-exit :around 'doom-shut-up-a)
  (advice-add #'org-agenda-exit :before #'org-save-all-org-buffers)

  (setq org-startup-indented t
        org-src-tab-acts-natively t)
  (add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

  (setq org-tag-alist '((:startgroup . nil)
                                  ("@personal" . ?p)
                                  ("@work" . ?w)
                                  ("@growth" . ?g)
                                  (:endgroup . nil)
                                  (:startgroup . nil)
                                  ("project". ?x)
                                  ("music" . ?m)
                                  ("catchingup" . ?c)
                                  ("grocery" . ?y)
                                  ("goingout". ?t)
                                  ("home" . ?h)
                                  ("now" . ?n)
                                  ("laptop" . ?l)
                                  ("phone" . ?e)
                                  ("office" . ?o)
                                  ("reads" . ?r)
                                  ("entertaintment" . ?z)
                                  (:endgroup . nil)
                                  (:startgroup . nil)
                                  ("Challenge" . ?1)
                                  ("Average" . ?2)
                                  ("Easy" . ?3)
                                  (:endgroup . nil)
                                  ))

;;  (defun org-clock-switch ()
;;    "Switch task and go-to that task"
;;    (interactive)
;;    (setq current-prefix-arg '(12)) ; C-u
;;    (call-interactively 'org-clock-goto)
;;    (org-clock-in)
;;    (org-clock-goto))
;;  (provide 'org-clock-switch)
;;
;;
;;
;;  (defun my-agenda-prefix ()
;;    (format "%s" (my-agenda-indent-string (org-current-level))))
;;
;;  (defun my-agenda-indent-string (level)
;;    (if (= level 1)
;;        ""
;;      (let ((str ""))
;;        (while (> level 2)
;;          (setq level (1- level)
;;                str (concat str "──")))
;;        (concat str "►"))))

;;  (defun org-update-cookies-after-save()
;;    (interactive)
;;    (let ((current-prefix-arg '(4)))
;;      (org-update-statistics-cookies "ALL")))
;;
;;  (add-hook 'org-mode-hook
;;            (lambda ()
;;              (add-hook 'before-save-hook 'org-update-cookies-after-save nil 'make-it-local)))
;;  (provide 'org-update-cookies-after-save)

  (defun my/org-tasks-refile ()
    "Process a single TODO task item."
    (interactive)
    (call-interactively 'org-agenda-schedule)
    (org-agenda-set-tags)
    (org-agenda-priority)
    (let ((org-refile-targets '((helm-read-file-name :maxlevel .3)))
          (call-interactively #'org-refile))))
  (provide 'my/org-tasks-refile)

  (defun zyrohex/org-notes-refile ()
    "Process an item to the notes bucket"
    (interactive)
    (let ((org-refile-targets '(("~/Dropbox/org/gtd/notes.org" :maxlevel . 6)))
          (org-refile-allow-creating-parent-nodes 'confirm))
      (call-interactively #'org-refile)))
  (provide 'zyrohex/org-notes-refile)



;;
;;

  (setq org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id
        org-clone-delete-id t)

)






;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Capture templates                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Note: Anki capture templates are in anki side and roam capture in roam side
(after! org
    (add-to-list 'org-capture-templates
                 '("j"  "Contact" entry (file "~/Dropbox/org/contacts.org")
                   "* %(org-contacts-template-name)
    :PROPERTIES:
    :EMAIL: %(org-contacts-template-email)
    :PHONE: %^{Phone}
    :ADDRESS: %^{Home Address}
    :BIRTHDAY: %^{yyyy-mm-dd}
    :ORG:  %^{Company}
    :NOTE: %^{NOTE}
    :END:"
                   :empty-lines 1))
    )

(after! org (add-to-list 'org-capture-templates
             '("c" "Capture [GTD]" entry (file "~/Dropbox/org/gtd/inbox.org")
"* TODO %^{taskname}%?
:PROPERTIES:
:Effort_ALL: %^{effort}%?
:CREATED:    %U
:END:
" :immediate-finish t)))

;; added some capture template from jethrokuan's blog to capture webpage either from clipboard
;; or from browser directly.
(after! org (add-to-list 'org-capture-templates
             '("l" "Link Capture" entry (file "~/Dropbox/org/gtd/inbox.org")
"* TODO [[%:link][%:description]]\n\n %i" :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
             '("h" "Clip Link Capture" entry (file "~/Dropbox/org/gtd/inbox.org")
"* TODO %(org-cliplink-capture)" :immediate-finish t)))

(after! org (add-to-list 'org-capture-templates
             '("ph" "New Project" entry (file+function my/generate-org-note-name org-back-to-heading-or-point-min)
"* TODO %^{projectname} :project:
:PROPERTIES:
:GOAL:    %^{goal}
:END:
:RESOURCES:
:END:

+ REQUIREMENTS:
  %^{requirements}

\** TODO %^{task1}\n\** TODO %^{task2}")))

(after! org (add-to-list 'org-capture-templates
                         '("v" "Create a new habit" entry (file "~/Dropbox/org/gtd/recurring.org")
                           "* TODO %^{description} %?
:SCHEDULED: %^{schedule}t
:PROPERTIES:
:STYLE: habit
:CREATED:    %U
:END:
")))

(after! org (add-to-list 'org-capture-templates
             '("i" "Coding notes" entry(file+headline"~/Dropbox/org/notes/examples.org" "INBOX")
"* %^{example}
:PROPERTIES: :SOURCE:  %^{source|Command|Script|Code|Usage} :SUBJECT: %^{subject}
:END:

\#+BEGIN_SRC %^{lang}
%x
\#+END_SRC
%?")))

(after! org (add-to-list 'org-capture-templates
             '("m" "Mood Log" entry(file+olp+datetree"~/Dropbox/org/journal/mood.org")
               "** <%<%I:%M:%S>> %\\1 (%\\2 x mood swing) :: %\\3
:PROPERTIES:
:OVERALL MOOD: %^{MOOD|Excellent|Good|Okay|Worse}
:MOOD SWINGS: %^{SWING|None|Normal|Extreme}
:SPIRITUAL: %^{SPIRITUAL|YES|NO}
:DESCRIPTION: %^{DESCRIPTION}
:COMMENT:  %^{COMMENT}
")))

(after! org (add-to-list 'org-capture-templates
             '("b" "Book Log" entry(file "~/Dropbox/org/gtd/book.org")
"* SOMEDAY Read %^{Title}
:PROPERTIES:
:AUTHOR: %^{Author}
:GENRE: %^{Genre}
:RECOMMENDER: %^{Recommender}
:RATED: %^{RATING|5|4|3|2|1}
:COMMENT:  %^{Comment}
:END:")))

(after! org (add-to-list 'org-capture-templates
             '("P" "Paper Log" entry(file "~/Dropbox/org/gtd/paper.org")
"* SOMEDAY Read %^{Title}
:PROPERTIES:
:AUTHOR: %^{Author}
:CATEGORY: %^{CATEGORY|VISION|NLP|RL|NEURO|MISC}
:SUBCATEGORY: %^{Subcategory}
:LINK: %^{Link}
:SOTA: %^{SOTA|YES|NO}
:COMMENT:  %^{Comment}
:END:")))

(after! org (add-to-list 'org-capture-templates
             '("d" "Diary Log" entry(file+olp+datetree"~/Dropbox/org/journal/diary.org")
               "** <%<%I:%M:%S>> %^{diary entry}
%?")))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Functions for ease                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun my/generate-org-note-name ()
  (setq my-org-note--name (read-string "Name: "))
  (expand-file-name (format "%s.org"my-org-note--name) "~/Dropbox/org/gtd/projects/"))

(defun org-gtd/find-project-task ()
  "Move point to the parent (project) task if any"
  (interactive)
  (save-restriction
    (widen)
    (let ((parent-task (save-excursion (org-back-to-heading 'invisible-ok) (point))))
      (while (org-up-heading-safe)
        (when (string-match-p "project" (org-get-tags-string))
          (setq parent-task (point))))
      (goto-char parent-task)
      parent-task)))

(defun org-gtd/is-project-subtree-p ()
  "Any task that is a project subtree"
  (let ((task (save-excursion (org-back-to-heading 'invisible-ok)
                              (point))))
    (save-excursion
      (org-gtd/find-project-task)
      (if (equal (point) task)
          nil
        t))))

(defun org-gtd/skip-project-tasks ()
  "Skip tasks belonging to projects"
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((org-gtd/is-project-subtree-p)
        subtree-end)
       (t
        nil)))))

(defun org-gtd/remove-started-tag-when-done ()
  "Remove started tag from task when marked as DONE"
  (interactive)
  (when (org-entry-is-done-p)
    (save-excursion
      (org-back-to-heading)
      (org-set-tags-to (if (string= (org-get-tags-string) ":started:")
                           ""
                         (mapconcat 'identity
                                    (delete "started" (split-string (org-get-tags-string) ":")) ":"))))))

(defun org-gtd/archive-all-done-entries ()
  "Archive all entries marked DONE"
  (interactive)
  (save-excursion
    (goto-char (point-max))
    (while (outline-previous-heading)
      (when (org-entry-is-done-p)
        (org-archive-subtree)))))


(defun my/last-captured-org-note ()
  "Move to the last line of the last org capture note."
  (interactive)
  (goto-char (point-max)))


(defun bh/make-org-scratch ()
  (interactive)
  (find-file "/tmp/publish/scratch.org")
  (gnus-make-directory "/tmp/publish"))

(defun bh/switch-to-scratch ()
  (interactive)
  (switch-to-buffer "*scratch*"))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Keybindings                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(bind-key "C-c 2" 'vsplit-last-buffer)
(bind-key "C-c 3" 'hsplit-last-buffer)
(bind-key "s-<return>" 'newline-and-indent)
(map! :leader
      (:prefix "e"
        :n "e" #'ace-window
        :n "u" #'swiper-all
        :n "s" #'deadgrep
        :n "r" #'helm-org-rifle-directories
        :n "l" #'my/last-captured-org-note)
      (:prefix-map ("=" . "Refile todos")
        :n "t" #'my/org-tasks-refile)
      (:prefix "o"
        :n "e" #'elfeed
        :n "s" #'org-open-at-point
        :n "u" #'elfeed-update
        :n "o" #'dired-jump)
      (:prefix "s"
        :n "q" #'org-ql-search
        :n "a" #'helm-org-rifle-current-buffer
        :n "w" #'helm-org-rifle-org-directory
        :n "h" #'helm-org-rifle-directories)
      (:prefix "t"
        :n "s" #'org-narrow-to-subtree
        :n "w" #'widen)
)

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

(global-set-key (kbd "C-c o") 'bh/make-org-scratch)
(global-set-key (kbd "C-c s") 'bh/switch-to-scratch)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        Super agenda                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(after! org-agenda (setq org-agenda-custom-commands
                         '(("k" "Morning View"
                            ((agenda ""
                                     ((org-agenda-files
                                       '("~/Dropbox/org/gtd/tasks.org" "~/Dropbox/org/gtd/recurring.org" "~/Dropbox/org/gtd/projects/"))
                                      (org-agenda-overriding-header "What's on my calendar")
                                      (org-agenda-span 'day)
                                      (org-agenda-start-day
                                       (org-today))
                                      (org-agenda-current-span 'day)
                                      (org-super-agenda-groups
                                       '((:name "Today's Schedule" :scheduled t :time-grid t :deadline t :order 13)))))
                             (todo ""
                                   ((org-agenda-overriding-header "[[~/Dropbox/org/gtd/tasks.org][Task list]]")
                                    (org-agenda-prefix-format " %(my-agenda-prefix) ")
                                    (org-agenda-files
                                     '("~/Dropbox/org/gtd/tasks.org"))
                                    (org-super-agenda-groups
                                     '((:name "CRITICAL" :priority "A" :order 1)
                                       (:name "NEXT UP" :todo "NEXT" :order 2))))))
                            nil)
                           ("a" "Agenda"
                            ((agenda "" ((org-agenda-sorting-strategy '(habit-down time-up priority-down category-keep user-defined-up))))
                             (org-time-budgets-for-agenda)))
                           ("i" "Inbox"
                            ((todo ""
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/inbox.org"))
                                    (org-agenda-overriding-header "Items in my inbox")
                                    (org-super-agenda-groups
                                     '((:auto-ts t))))))
                            nil)
                           ("x" "Get to someday"
                            ((todo ""
                                   ((org-agenda-overriding-header "Projects marked Someday")
                                    (org-agenda-files
                                     '("~/Dropbox/org/gtd/someday.org"))
                                    (org-super-agenda-groups
                                     '((:auto-ts t))))))
                            nil)
                           ("p" "Projects"
                            ((todo ""
                                   ((org-agenda-files
                                     '("~/Dropbox/org/gtd/projects/"))
                                    (org-agenda-overriding-header "Project related items"))))
                            nil)
                           ("bl" "Before Lunch"
                            ((todo ""
                             ((org-agenda-overriding-header "Can you spare some time?\n ==============================================================\n")
                             (org-agenda-tag-filter-preset
                              '("+laptop" "+phone" "+office" "-home" "-Challenge")))))
                             (todo ""
                             ((org-agenda-overriding-header "Today's office work\n ===================================================================\n")
                             (org-agenda-tag-filter-preset
                              '("+@work"))))
                            nil)
                           ("bh" "Before going home"
                            (( todo ""
                             ((org-agenda-span '2)
                             (org-agenda-overriding-header "Buy on the way today\n ===================================================================\n")
                             (org-agenda-span '3)
                             (org-agenda-tag-filter-preset
                              '("+grocery" "+goingout"))))
                             ( agenda ""
                             ((org-agenda-overriding-header "Checklist before you go\n ==================================================================\n")
                             (org-deadline-warning-days 3)
                             (org-agenda-tag-filter-preset
                              '("+@work"))))))
;;                           ("o" "Office View"
;;                                        ; Priority A
;;                            ((tags-todo "PRIORITY=\"A\"&-home"
;;                                        ((org-agenda-overriding-header "Priority A")))
;;                                        ; Due soon
;;                             (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&-home"
;;                                        ((org-agenda-overriding-header "Due soon")))
;;                                        ; Project list
;;                             (tags "LEVEL=2&-home"
;;                                   ((org-agenda-files '("~/Dropbox/org/gtd/projects/"))
;;                                    (org-agenda-overriding-header "Projects")))
;;                             (tags-todo (concat "-home&-TODO=\"WAITING\"&-FILE=\""
;;                                                (expand-file-name "~/Dropbox/org/gtd/projects/")
;;                                                "\"")
;;                                        ((org-agenda-overriding-header "All non-project tasks")))
;;                             )
;;                            ((org-agenda-compact-blocks t)))
;;                           ("h" "Home agenda"
;;                                        ; Priority A
;;                             ((tags-todo "PRIORITY=\"A\"&-work"
;;                                         ((org-agenda-overriding-header "Priority A")))
;;                                        ; Due soon
;;                              (tags-todo "-PRIORITY=\"A\"&DEADLINE<=\"<+7d>\"&-work"
;;                                         ((org-agenda-overriding-header "Due soon")))
;;                                        ; Project list
;;                              (tags "LEVEL=2&-work"
;;                                    ((org-agenda-files '("~/Dropbox/org/gtd/projects/"))
;;                                     (org-agenda-overriding-header "Projects")))
;;
;;                              (tags-todo (concat "-work&-TODO=\"WAITING\"&-FILE=\""
;;                                                 (expand-file-name "~/Dropbox/org/gtd/projects/")
;;                                                 "\"")
;;                                         ((org-agenda-overriding-header "All non-project tasks"))))
;;                             ((org-agenda-compact-blocks t)))
                           )))



(require 'nepali-romanized)

(after! pdf-tools
    ;; workaround for pdf-tools not reopening to last-viewed page of the pdf:
    ;; https://github.com/politza/pdf-tools/issues/18
    (defun brds/pdf-set-last-viewed-bookmark ()
      (interactive)
      (when (eq major-mode 'pdf-view-mode)
        (bookmark-set (brds/pdf-generate-bookmark-name))))

    (defun brds/pdf-jump-last-viewed-bookmark ()
      (when
          (brds/pdf-has-last-viewed-bookmark)
        (bookmark-jump (brds/pdf-generate-bookmark-name))))

    (defun brds/pdf-has-last-viewed-bookmark ()
      (assoc
       (brds/pdf-generate-bookmark-name) bookmark-alist))

    (defun brds/pdf-generate-bookmark-name ()
      (concat "PDF-LAST-VIEWED: " (buffer-file-name)))

    (defun brds/pdf-set-all-last-viewed-bookmarks ()
      (dolist (buf (buffer-list))
        (with-current-buffer buf
            (brds/pdf-set-last-viewed-bookmark))))

    (add-hook 'kill-buffer-hook 'brds/pdf-set-last-viewed-bookmark)
    (add-hook 'pdf-view-mode-hook 'brds/pdf-jump-last-viewed-bookmark)
    (unless noninteractive  ; as `save-place-mode' does
      (add-hook 'kill-emacs-hook #'brds/pdf-set-all-last-viewed-bookmarks))
)





(use-package! smerge-mode
  :bind (("C-c h s" . jethro/hydra-smerge/body))
  :init
  (defun jethro/enable-smerge-maybe ()
    "Auto-enable `smerge-mode' when merge conflict is detected."
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^<<<<<<< " nil :noerror)
        (smerge-mode 1))))
  (add-hook 'find-file-hook #'jethro/enable-smerge-maybe :append)
  :config
  (defhydra jethro/hydra-smerge (:color pink
                                        :hint nil
                                        :pre (smerge-mode 1)
                                        ;; Disable `smerge-mode' when quitting hydra if
                                        ;; no merge conflicts remain.
                                        :post (smerge-auto-leave))
    "
   ^Move^       ^Keep^               ^Diff^                 ^Other^
   ^^-----------^^-------------------^^---------------------^^-------
   _n_ext       _b_ase               _<_: upper/base        _C_ombine
   _p_rev       _u_pper           g   _=_: upper/lower       _r_esolve
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
    ("q" nil "cancel" :color blue)))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                        latest additions for review                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(use-package org-clock-convenience
  :after org
  :bind (:map org-agenda-mode-map
          ("<S-up>" . org-clock-convenience-timestamp-up)
          ("<S-down>" . org-clock-convenience-timestamp-down)
          ("<S-right>" . org-clock-convenience-fill-gap)
          ("<S-left>" . org-clock-convenience-fill-gap-both)))


(after! org
  (setq org-time-budgets '((:title "Work" :tags "+@work" :budget "30:00" :block workweek)
                           (:title "Sideprojects" :tags "+@personal+project" :budget "15:00" :block week)
                           (:title "Music Practice" :tags "+music" :budget "4:00" :block week)
                           (:title "Evolution" :tags "+@growth" :budget "5:00" :block week)
                           (:title "Easy work" :tags "+Easy" :budget "40:00" :block week)
                           (:title "Average" :tags "+Average" :budget "20:00" :block week)
                           (:title "Challenge" :tags "+Challenge" :budget "10:00" :block week)
                           (:title "Personal Tasks" :tags "+@personal" :budget "19:00" :block week)))
)


;;(after! org
;;  (appendq! +pretty-code-symbols
;;            '(:checkbox    "☐"
;;              :pending     "◼"
;;              :checkedbox  "☑"
;;              :results     "🠶"
;;              :property    "☸"
;;              :properties  "⚙"
;;              :end         "∎"
;;              :options     "⌥"
;;              :begin_quote "❮"
;;              :end_quote   "❯"
;;              :em_dash     "—"))
;;  (set-pretty-symbols! 'org-mode
;;    :merge t
;;    :checkbox    "[ ]"
;;    :pending     "[-]"
;;    :checkedbox  "[X]"
;;    :results     "#+RESULTS:"
;;    :property    "#+PROPERTY:"
;;    :property    ":PROPERTIES:"
;;    :end         ":END:"
;;    :options     "#+OPTIONS:"
;;    :title       "#+TITLE:"
;;    :author      "#+AUTHOR:"
;;    :date        "#+DATE:"
;;    :begin_quote "#+BEGIN_QUOTE"
;;    :end_quote   "#+END_QUOTE"
;;    :em_dash     "---")
;;)
;;(plist-put +pretty-code-symbols :name "⁍")

;;(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

;;(after! latex
;;  (setq +latex-viewers '(skim evince sumatrapdf zathura pdf-tools )))







;;  '(("*" (bold :foreground "Orange" ))
;;    ("/" italic)
;;    ("_" underline)
;;    ("=" (:foreground "maroon"))
;;    ("@" (:foreground "#d54e53"))
;;    ("~" (:foreground "deep sky blue"))
;;    ("+" (:strike-through t))))


;;
;;
;;(defun my-html-mark-tag (text backend info)
;;  "Transcode :blah: into <mark>blah</mark> in body text."
;;  (when (org-export-derived-backend-p backend 'html)
;;
;;    (let ((text (replace-regexp-in-string "[^\\w]\\(~\\)[^\n\t\r]+\\(~\\)[^\\w]" "<span style=\"background-color: #A8D1FF\">"  text nil nil 1 nil)))
;;      (replace-regexp-in-string "[^\\w]\\(<span style=\"background-color: #A8D1FF\">\\)[^\n\t\r]+\\(~\\)[^\\w]" "</span>" text nil nil 2 nil))
;;
;;    (let ((text (replace-regexp-in-string "[^\\w]\\(@\\)[^\n\t\r]+\\(@\\)[^\\w]" "<span style=\"background-color: #FFB7B7\">"  text nil nil 1 nil)))
;;      (replace-regexp-in-string "[^\\w]\\(<span style=\"background-color: #FFB7B7\">\\)[^\n\t\r]+\\(@\\)[^\\w]" "</span>" text nil nil 2 nil))
;;
;;    (let ((text (replace-regexp-in-string "[^\\w]\\(=\\)[^\n\t\r]+\\(=\\)[^\\w]" "<span style=\"background-color: #FFB7B7\">"  text nil nil 1 nil)))
;;      (replace-regexp-in-string "[^\\w]\\(<span style=\"background-color: #FFB7B7\">\\)[^\n\t\r]+\\(=\\)[^\\w]" "</span>" text nil nil 2 nil))
;;
;;    (let ((text (replace-regexp-in-string "[^\\w]\\(:\\)[^\n\t\r]+\\(:\\)[^\\w]" "<span style=\"background-color: #FFF2A8\">"  text nil nil 1 nil)))
;;      (replace-regexp-in-string "[^\\w]\\(<span style=\"background-color: #FFF2A8\">\\)[^\n\t\r]+\\(:\\)[^\\w]" "</span>" text nil nil 2 nil))
;;
;;))
;;
;;(add-to-list 'org-export-filter-plain-text-functions 'my-html-mark-tag)
;;
;;(after! org
;;  (defun org-add-my-extra-markup ()
;;    "Add highlight emphasis."
;;    (add-to-list 'org-font-lock-extra-keywords
;;                 '("[^\\w]\\(=\\[^\n\r\t]+=\\)[^\\w]"
;;                   (1 '(face highlight invisible nil)))))
;;
;;  (add-hook 'org-font-lock-set-keywords-hook #'org-add-my-extra-markup)
;;
;;  (defun my-html-mark-tag (text backend info)
;;    "Transcode :blah: into <mark>blah</mark> in body text."
;;    (when (org-export-derived-backend-p backend 'html)
;;      (let ((text (replace-regexp-in-string "[^\\w]\\(=\\)[^\n\t\r]+\\(=\\)[^\\w]" "<span style=\"background-color: #FFB7B7\">"  text nil nil 1 nil)))
;;        (replace-regexp-in-string "[^\\w]\\(<span style=\"background-color: #FFB7B7\">\\)[^\n\t\r]+\\(=\\)[^\\w]" "</span>" text nil nil 2 nil))))
;;
;;  (add-to-list 'org-export-filter-plain-text-functions 'my-html-mark-tag)
;;)


(use-package dired-rainbow
  :after dired
  :config
  (progn
    (dired-rainbow-define-chmod directory "#6cb2eb" "d.*")
    (dired-rainbow-define html "#eb5286" ("css" "less" "sass" "scss" "htm" "html" "jhtm" "mht" "eml" "mustache" "xhtml"))
    (dired-rainbow-define xml "#f2d024" ("xml" "xsd" "xsl" "xslt" "wsdl" "bib" "json" "msg" "pgn" "rss" "yaml" "yml" "rdata"))
    (dired-rainbow-define document "#9561e2" ("docm" "doc" "docx" "odb" "odt" "pdb" "pdf" "ps" "rtf" "djvu" "epub" "odp" "ppt" "pptx"))
    (dired-rainbow-define markdown "#ffed4a" ("org" "etx" "info" "markdown" "md" "mkd" "nfo" "pod" "rst" "tex" "textfile" "txt"))
    (dired-rainbow-define database "#6574cd" ("xlsx" "xls" "csv" "accdb" "db" "mdb" "sqlite" "nc"))
    (dired-rainbow-define media "#de751f" ("mp3" "mp4" "MP3" "MP4" "avi" "mpeg" "mpg" "flv" "ogg" "mov" "mid" "midi" "wav" "aiff" "flac"))
    (dired-rainbow-define image "#f66d9b" ("tiff" "tif" "cdr" "gif" "ico" "jpeg" "jpg" "png" "psd" "eps" "svg"))
    (dired-rainbow-define log "#c17d11" ("log"))
    (dired-rainbow-define shell "#f6993f" ("awk" "bash" "bat" "sed" "sh" "zsh" "vim"))
    (dired-rainbow-define interpreted "#38c172" ("py" "ipynb" "rb" "pl" "t" "msql" "mysql" "pgsql" "sql" "r" "clj" "cljs" "scala" "js"))
    (dired-rainbow-define compiled "#4dc0b5" ("asm" "cl" "lisp" "el" "c" "h" "c++" "h++" "hpp" "hxx" "m" "cc" "cs" "cp" "cpp" "go" "f" "for" "ftn" "f90" "f95" "f03" "f08" "s" "rs" "hi" "hs" "pyc" ".java"))
    (dired-rainbow-define executable "#8cc4ff" ("exe" "msi"))
    (dired-rainbow-define compressed "#51d88a" ("7z" "zip" "bz2" "tgz" "txz" "gz" "xz" "z" "Z" "jar" "war" "ear" "rar" "sar" "xpi" "apk" "xz" "tar"))
    (dired-rainbow-define packaged "#faad63" ("deb" "rpm" "apk" "jad" "jar" "cab" "pak" "pk3" "vdf" "vpk" "bsp"))
    (dired-rainbow-define encrypted "#ffed4a" ("gpg" "pgp" "asc" "bfe" "enc" "signature" "sig" "p12" "pem"))
    (dired-rainbow-define fonts "#6cb2eb" ("afm" "fon" "fnt" "pfb" "pfm" "ttf" "otf"))
    (dired-rainbow-define partition "#e3342f" ("dmg" "iso" "bin" "nrg" "qcow" "toast" "vcd" "vmdk" "bak"))
    (dired-rainbow-define vc "#0074d9" ("git" "gitignore" "gitattributes" "gitmodules"))
    (dired-rainbow-define-chmod executable-unix "#38c172" "-.*x.*")
))

(use-package dired-subtree
  :after dired
  :config
  (setq dired-subtree-use-backgrounds nil)
  :bind (:map dired-mode-map
              ("<tab>" . dired-subtree-toggle)
              ("<C-tab>" . dired-subtree-cycle)
              ("<S-iso-lefttab>" . dired-subtree-remove)))

(use-package winner
  :hook (after-init . winner-mode)
  :bind ("<s-right>" . winner-redo)
         ("<s-left>" . winner-undo))



(after! org
  ;;(load! "+dragndrop")
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
