;; Must Have packages
;; (package! helm-org-rifle)
(package! org-ql)
(package! elfeed-goodies)
;; ox twitter bootstrap
(package! ox-twbs)
;; useful for parsing web pages
(package! org-web-tools)
;; Optional
(package! gnuplot)
;; Testing
;; analyze when you have entered data and filter activity based on your clocking
(package! org-analyzer)
(package! org-mru-clock) ;; clocking in and out easier
(package! org-time-budgets
  :recipe (:host github :repo "leoc/org-time-budgets" :branch "develop" :no-byte-compile t)) ;; budgeting on tasks
(package! grab-x-link) ;; grabbing links from firefox, chrome and so on.
(package! org-noter) ;; notes for pdfs and on

(package! org-noter-pdftools
  :recipe (:host github :repo "fuxialexander/org-pdftools"))
(package! xkcd)
(package! leetcode)
(package! anki-editor)
(package! org-ref)
(package! nepali-romanized
  :recipe (:host github :repo "bishesh/emacs-nepali-romanized"))
;;(package! memrise)
(package! org-clock-convenience)

;; Download images directly into org mode
(package! org-download)

(package! org-roam-bibtex
  :recipe (:host github :repo "org-roam/org-roam-bibtex"))

;; When using org-roam via the `+roam` flag
(unpin! org-roam)

;; When using bibtex-completion via the `biblio` module
(unpin! bibtex-completion helm-bibtex ivy-bibtex)

(package! magit-delta
  :recipe (:host github :repo "dandavison/magit-delta"))
(package! academic-phrases)
(package! lorem-ipsum)

;; I think it's already in
;; (package! ace-link)
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

;; Web servers were clashing. Orch needed one and org-roam-server needed other.
;; I still have no idea how this is working now.
(package! simple-httpd
  :recipe (:local-repo "~/.doom.d/skeeto-web-server/"))
(package! web-server
  :recipe (:local-repo "~/.doom.d/eschulte-web-server/"))

;; fast reading with ease. I love spray when I am bored to read through the page
(package! spray
  :recipe (:local-repo "~/.doom.d/spray"))

;; see weather with ease
(package! wttrin
          :recipe (:local-repo "~/.doom.d/wttrin"))

;; handle very large files
(package! vlf :recipe (:host github :repo "m00natic/vlfi" :files ("*.el")))

;; get new themes also ;)
;; (unpin! doom-themes)

;; for managing book reading
(package! org-books)
;;  :recipe (:local-repo "~/.doom.d/org-books/"))
;; since doom emacs doesn't add it by default for it's setup
(package! lsp-julia :recipe (:host github :repo "non-jedi/lsp-julia"))
;; had issues with native emacs so let's not byte compile them
(package! ein :recipe (:no-byte-compile t))
;; export org mode notebooks to ipynb
(package! ox-ipynb
  :recipe (:host github :repo "zaeph/ox-ipynb"))
;; org roam server to see my notes in graphs
(package! org-roam-server :recipe(:no-byte-compile t))
;; easy to read auto fill without doing anything
(package! virtual-auto-fill)
;; (package! helm-bibtex)
;; (package! nov)
;; (package! ob-mermaid)
;; (package! org-autolist) ;; For now , org-return-dwim from kitchin works
(package! dired-sidebar)
(package! dired-subtree)
;; (package! gkroam)
(package! org-pretty-table
  :recipe (:host github :repo "Fuco1/org-pretty-table"))
(package! libmpdel)
(package! mpdel)
(package! ivy-mpdel)
(package! org-fragtog)
;; (package! org-pretty-table-mode
;;   :recipe (:host github :repo "Fuco1/org-pretty-table") :pin "88380f865a...")
(package! tab-jump-out)
;; (package! declutter
;;   :recipe (:host github :repo "sanel/declutter"))
(package! tree-sitter)
(package! tree-sitter-langs)
(package! focus)
(package! aggressive-indent)
;; Package doesn't work for me.
;; (package! valign
;;   :recipe (:host github :repo "casouri/valign"))
(package! ftable
  :recipe (:host github :repo "casouri/ftable"))
(package! spacemacs-theme)
(package! visual-regexp-steroids)
(package! org-edna)
(package! emacs-monkeytype
  :recipe (:host github :repo "jpablobr/emacs-monkeytype"))
(package! jupyter)
(package! org-super-agenda :recipe (:no-byte-compile t))
(package! nov)
;; Taken from org +pretty as I am modifying it right now.
(package! org-superstar)
(package! org-fancy-priorities)
(package! citeproc-org)
(package! exwm)
(package! exwm-firefox-evil)
(package! desktop-environment)
(package! evil-escape)
(package! edwina)
(package! quick-peek
  :recipe (:host github :repo "cpitclaudel/quick-peek"))
;; (package! blacken)
(package! py-autopep8)
(package! pip-requirements)
