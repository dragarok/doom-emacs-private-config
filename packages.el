;; Must Have packages
(package! helm-org-rifle)
;;(package! org-kanban)
(package! org-ql)
(package! org-super-agenda)
(package! org-timeline)
(package! elfeed)
(package! elfeed-goodies)
(package! elfeed-org)
(package! ox-pandoc)
;; ox twitter bootstrap
(package! ox-twbs)
(package! org-web-tools)
;; Optional
(package! org-sidebar)
(package! pdf-tools)
(package! gnuplot)
(package! gnuplot-mode)
;; Testing
;; analyze when you have entered data and filter activity
(package! org-analyzer)
(package! org-autolist)
(package! org-mru-clock)
;;(package! org-time-budgets)
(package! org-clock-budget
:recipe (:host github :repo "fuco1/org-clock-budget"))
(package! grip-mode)
(package! web-beautify)
(package! ox-reveal)
(package! grab-x-link)
(package! org-noter)
;;(package! helm-bibtex)
(package! nov)
(package! flutter)
(package! ob-mermaid)

(package! mathpix.el
  :recipe (:host github :repo "jethrokuan/mathpix.el"))
(package! org-ref-ex-hugo
  :recipe (:host github :repo "jethrokuan/org-ref-ox-hugo" :branch "custom/overrides"))
(package! org-noter-pdftools
  :recipe (:host github :repo "fuxialexander/org-pdftools"))
(package! xkcd)
(package! leetcode)
(package! anki-editor)
(package! org-ref)
(package! nepali-romanized
  :recipe (:host github :repo "bishesh/emacs-nepali-romanized"))
(package! all-the-icons-dired)
(package! dired-rainbow)
(package! dired-subtree)
(package! dired-filter)
(package! dired-collapse)
(package! zoom)
(package! evil-tutor)
;;(package! memrise)
(package! org-clock-convenience)
(package! org-download)
(package! org-roam-bibtex
  :recipe (:host github :repo "zaeph/org-roam-bibtex"))
(package! magit-delta
  :recipe (:host github :repo "dandavison/magit-delta"))
(package! transmission)
(package! academic-phrases)
(package! lorem-ipsum)
(package! ace-link)
(package! ov
  :recipe (:host github :repo "emacsorphanage/ov.el"))
(package! hydra-posframe
  :recipe (:host github :repo "Ladicle/hydra-posframe"))

(package! scihub
  :recipe (:host github :repo "emacs-pe/scihub.el"))
(package! zotxt)
(package! orch
  :recipe (:local-repo "~/.doom.d/orch/"))
(package! simple-httpd
  :recipe (:local-repo "~/.doom.d/skeeto-web-server/"))
(package! web-server
  :recipe (:local-repo "~/.doom.d/eschulte-web-server/"))
(package! spray
  :recipe (:host gitlab :repo "iankelling/spray"))
(package! wttrin
          :recipe (:local-repo "~/.doom.d/wttrin"))
(package! vlf :recipe (:host github :repo "m00natic/vlfi" :files ("*.el")))
(unpin! doom-themes)

(package! org-books
  :recipe (:local-repo "~/.doom.d/org-books/"))
(package! lsp-julia :recipe (:host github :repo "non-jedi/lsp-julia"))
(package! jupyter :recipe (:no-byte-compile t))
(package! ein :recipe (:no-byte-compile t))
(package! ox-ipynb
  :recipe (:host github :repo "jkitchin/ox-ipynb" :no-byte-compile t))
(package! org-roam-server :recipe(:no-byte-compile t))
(package! virtual-auto-fill)
