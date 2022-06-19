;; Must Have packages
;; (package! helm-org-rifle)
(package! org-ql)
(package! org-noter-pdftools)
;; useful for parsing web pages
(package! org-web-tools)
;; Testing
;; analyze when you have entered data and filter activity based on your clocking
(package! org-analyzer)
(package! org-mru-clock) ;; clocking in and out easier
(package! grab-x-link) ;; grabbing links from firefox, chrome and so on.
(package! xkcd)
(package! anki-editor)
(package! nepali-romanized
  :recipe (:host github :repo "bishesh/emacs-nepali-romanized"))
(package! org-clock-convenience)
(package! magit-delta
  :recipe (:host github :repo "dandavison/magit-delta"))
(package! ov
  :recipe (:host github :repo "emacsorphanage/ov.el"))

;; Who likes hydra when it's not centered?
(package! hydra-posframe
  :recipe (:host github :repo "Ladicle/hydra-posframe"))

;; Why go to scihub when emacs can do it?
(package! scihub
  :recipe (:host github :repo "emacs-pe/scihub.el"))

;; Managing citations with zotero
(package! zotxt)

;; Send notes from my S-note to Org mode directly
(package! orch
  :recipe (:local-repo "~/.doom.d/orch/"))

;; Web servers were clashing. Orch needed one and org-roam-web-server the other
;; I still have no idea how this is working now.
(package! simple-httpd)

;; fast reading with ease. I love spray when I am bored to read through the page
(package! spray
  :recipe (:local-repo "~/.doom.d/spray"))

;; see weather with ease
(package! wttrin
          :recipe (:local-repo "~/.doom.d/wttrin"))

;; handle very large files
(package! vlf :recipe (:host github :repo "m00natic/vlfi" :files ("*.el")))
(package! ox-ipynb
  :recipe (:host github :repo "jkitchin/ox-ipynb"))
;; easy to read auto fill without doing anything
(package! virtual-auto-fill)
(package! org-fragtog)
;; (package! tree-sitter)
;; (package! tree-sitter-langs)
(package! focus)
(package! aggressive-indent)
(package! visual-regexp-steroids)
(package! org-edna)
(package! org-super-agenda)
(package! ess-view)
(package! screenshot :recipe (:host github :repo "tecosaur/screenshot"))
(package! laas)
(package! org-pandoc-import
  :recipe (:host github
           :repo "tecosaur/org-pandoc-import"
           :files ("*.el" "filters" "preprocessors")))
(package! wallabag
  :recipe (:host github
           :repo "chenyanming/wallabag.el"
           :files ("*.el" "*.alist" "*.css")))

(package! clip2org
  :recipe (:local-repo "~/.doom.d/clip2org/"))
(package! page-break-lines)
(package! websocket)
(package! org-roam-ui :recipe (:host github :repo "org-roam/org-roam-ui" :files ("*.el" "out")))
(package! consult-dir)
(package! ox-json)
(package! org-roam-bibtex)
(package! dirvish)
(package! powershell)
(package! evil-escape :disable t)
(package! org-modern)
(package! org-appear)
(package! copilot
  :recipe (:host github :repo "zerolfx/copilot.el" :files ("*.el" "dist")))
(package! elfeed-tube
  :recipe (:host github :repo "karthink/elfeed-tube"))
(package! elfeed-tube-mpv
  :recipe (:host github :repo "karthink/elfeed-tube"))
;; for managing book reading
;; (package! org-books)
;;  :recipe (:local-repo "~/.doom.d/org-books/"))
;; (package! ein :recipe (:no-byte-compile t))
;; (package! ein)

;; export org mode notebooks to ipynb
;; (package! ob-mermaid)
;; (package! org-autolist) ;; For now , org-return-dwim from kitchin works
;; (package! dired-sidebar)
;; (package! emacs-monkeytype
;;   :recipe (:host github :repo "jpablobr/emacs-monkeytype"))
;; (package! jupyter)
;; (package! org-super-agenda :recipe (:no-byte-compile t))
;; (package! citeproc-org)

;; EXWM RELATED PACKAGES
;; (package! exwm)
;; (package! exwm-firefox-evil)
;; (package! desktop-environment)
;; (package! edwina)
;; (package! org-xournalpp
;;   :recipe (:host gitlab :repo "vherrmann/org-xournalpp" :files ("resources" "*.el")))

;; (package! elfeed :pin "362bbe5b38353d033c5299f621fea39e2c75a5e0")
;; (package! elfeed-org :pin "77b6bbf222487809813de260447d31c4c59902c9")
;; (package! org-transclusion :recipe (:host github :repo "nobiot/org-transclusion" :files ("*")))

;; (package! smudge)
;; (unpin! auto-activating-snippets)
;; (package! org-appear :recipe (:host github :repo "awth13/org-appear"))
;; (package! quick-peek
;;   :recipe (:host github :repo "cpitclaudel/quick-peek"))
;; (package! org-pretty-table-mode
;;   :recipe (:host github :repo "Fuco1/org-pretty-table") :pin "88380f865a...")
;; (package! tab-jump-out)
;; (package! declutter
;;   :recipe (:host github :repo "sanel/declutter"))
;; (package! lexic)
;; (package! ink
;;   :recipe (:host github
;;            :repo "foxfriday/ink"))

;; (unpin! pdf-tools)

;; (package! pdf-continuous-scroll-mode
;;   :recipe (:local-repo "~/.doom.d/pdf-continuous-scroll-mode/"))
;; (straight-use-package
;;  '(webkit :type git :host github :repo "akirakyle/emacs-webkit"
;;           :branch "main"
;;           :files (:defaults "*.js" "*.css" "*.so" "Makefile" ".c" ".h")
;;           :pre-build ("make")))
;; (package! valign)
;; (package! lsp-tailwindcss :recipe (:host github :repo "merrickluo/lsp-tailwindcss"))

;; UNUSED PACKAGES

;; (package! lister :recipe (:host github :repo "publicimageltd/lister"))
;; (package! delve :recipe (:host github :repo "publicimageltd/delve"))
;; (package! emacs-webkit
;;   :recipe (:host github :repo "akirakyle/emacs-webkit" :files ("*.el" "*.h" "*.c" "Makefile" "*.css" "*.js")))
;; (package! dogeras
;;   :recipe (:host github :repo "alphapapa/dogears.el"))
;; (package! nano-theme
;;   :recipe (:host github :repo "rougier/nano-theme"))
;; (package! beancount :recipe (:host github :repo "beancount/beancount-mode")
;;   :pin "3c04745fa5...")
;; (package! aas :recipe (:host github :repo "ymarco/auto-activating-snippets")
;;   :pin "e2b3edafd7...")
;; (package! org-time-budgets
;;   :recipe (:host github :repo "leoc/org-time-budgets" :branch "develop" :no-byte-compile t)) ;; budgeting on tasks

;; (straight-use-package
;;  '(webkit :type git :host github :repo "akirakyle/emacs-webkit"
;;           :branch "main"
;;           :files (:defaults "*.js" "*.css" "*.so" "Makefile" ".c" ".h")
;;           :pre-build ("make")))
;; (package! evil-colemak-basics)

;; Optional
;; (package! gnuplot)
;; (package! leetcode)
;; (package! org-ref-cite
;;  :recipe (:host github :repo "jkitchin/org-ref-cite"))

;; Download images directly into org mode
;; (package! org-download)
;;(package! memrise)
;; (package! academic-phrases)
;; (package! lorem-ipsum)

;; I think it's already in
;; (package! ace-link)
;; (package! web-server
;;   :recipe (:local-repo "~/.doom.d/eschulte-web-server/"))
;; (package! nov)
;; (package! dired-subtree)
;; ;; (package! gkroam)
;; (package! libmpdel)
;; (package! mpdel)
;; (package! ivy-mpdel)
;; ox twitter bootstrap
;; (package! ox-twbs)
