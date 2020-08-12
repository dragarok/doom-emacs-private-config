;; Must Have packages
(package! exwm)
(package! helm-exwm)
(package! helm-org-rifle)
(package! org-kanban)
(package! org-ql)
(package! org-super-agenda)
(package! org-timeline)
(package! elfeed)
(package! elfeed-goodies)
(package! elfeed-org)
(package! ox-pandoc)
;; ox twitter bootstrap
(package! ox-twbs)
;;(package! deadgrep)
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
;;(package! golden-ratio)
;;(package! helm-bibtex)
(package! nov)
(package! flutter)
(package! ob-mermaid)
;;(package! org-roam
;;  :recipe (:host github :repo "jethrokuan/org-roam")
;;  :pin "df29da1b6d")

(package! mathpix.el
  :recipe (:host github :repo "jethrokuan/mathpix.el"))
(package! org-ref-ex-hugo
  :recipe (:host github :repo "jethrokuan/org-ref-ox-hugo" :branch "custom/overrides"))
;;(package! org-pdftools)
;;(package! org-noter-pdftools
;;  :recipe (:host github :repo "fuxialexander/org-pdftools"))
(package! xkcd)
(package! leetcode)
(package! anki-editor)
(package! org-ref)
;;(package! julia-snail)
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
(package! lsp-julia :recipe (:host github :repo "non-jedi/lsp-julia"))
(package! org-download)
;; (package! webkit-katex-render
;;   :recipe (:host github :repo "fuxialexander/emacs-webkit-katex-render" ) :pin "ecf8f8a")
(package! org-roam-bibtex
  :recipe (:host github :repo "zaeph/org-roam-bibtex"))
(package! magit-delta
  :recipe (:host github :repo "dandavison/magit-delta"))
(package! transmission)
(package! academic-phrases)
(package! lorem-ipsum)
(package! prism
  :recipe (:host github :repo "alphapapa/prism.el"))
(package! ace-link)
(package! disable-mouse)
(package! ov
  :recipe (:host github :repo "emacsorphanage/ov.el"))
(package! helm-posframe)
(package! hydra-posframe
  :recipe (:host github :repo "Ladicle/hydra-posframe"))

(package! scihub
  :recipe (:host github :repo "emacs-pe/scihub.el"))
(package! zotxt)

(package! orch
  :recipe (:local-repo "/home/lis19/.doom.d/orch/"))
;; (package! orch
;;   :recipe (:host github :repo "yati-sagade/orch"))
(package! org-roam-server)
(package! simple-httpd
  :recipe (:local-repo "/home/lis19/.doom.d/skeeto-web-server/"))
  ;; :recipe (:host github :repo "skeeto/emacs-web-server"))
(package! web-server
  :recipe (:local-repo "/home/lis19/.doom.d/eschulte-web-server/"))
  ;; :recipe (:host github :repo "eschulte/emacs-web-server"))
;; (package! eaf
;;   :recipe (:host github :repo "manateelazycat/emacs-application-framework"))

(package! spray
  :recipe (:host gitlab :repo "iankelling/spray"))
;; (package! elegant-emacs
;;   :recipe (:host github :repo "rougier/elegant-emacs"))
