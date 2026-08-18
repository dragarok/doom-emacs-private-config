;; -*- no-byte-compile: t; -*-
;;; packages.el --- Doom Emacs package declarations -*- lexical-binding: t; -*-

;; Platform detection
(defconst IS-ANDROID (eq system-type 'android))

;; ============================================================
;; SHARED PACKAGES (both Mac and Android)
;; ============================================================

;; Core org extensions
(package! org-ql)
(package! org-fragtog)
(package! org-appear)
(package! org-edna)
(package! org-super-agenda)
(package! org-time-budgets
  :recipe (:host github :repo "dragarok/org-time-budgets" :branch "cl-lib"))

;; Org-roam UI
(package! websocket)
(package! org-roam-ui :recipe (:host github :repo "org-roam/org-roam-ui" :files ("*.el" "out")))

;; Utilities
(package! hackernews)
(package! posframe)  ; needed for productivity.el
(package! evil-escape :disable t)

;; Language support
(package! nepali-romanized
  :recipe (:host github :repo "bishesh/emacs-nepali-romanized"))

;; Claude Code integration
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

(package! claude-code
  :recipe (:host github :repo "stevemolitor/claude-code.el" :branch "main" :depth 1
           :files ("*.el" (:exclude "images/*"))))


(package! hydra-posframe
  :recipe (:host github :repo "Ladicle/hydra-posframe"))

(package! org-books
  :recipe (:host github :repo "goderich/org-books"))
(package! orgmdb)

;; File handling
(package! vlf :recipe (:host github :repo "m00natic/vlfi" :files ("*.el")))
;; ============================================================
;; MAC-ONLY PACKAGES
;; ============================================================

(unless IS-ANDROID
  ;; Web and browser integration
  (package! org-web-tools)
  (package! grab-x-link)
  (package! ox-hugo)

  ;; Git enhancements
  (package! magit-delta
    :recipe (:host github :repo "dandavison/magit-delta"))

  (package! focus)
  (package! page-break-lines)
  (package! info-colors)

  ;; Academic tools
  (package! scihub
    :recipe (:host github :repo "emacs-pe/scihub.el"))
  (package! zotxt)
  (package! virtual-auto-fill)

  ;; Editing enhancements
  (package! aggressive-indent)
  (package! visual-regexp-steroids)

  ;; Org extensions (Mac-specific)
  (package! org-pandoc-import
    :recipe (:host github
             :repo "tecosaur/org-pandoc-import"
             :files ("*.el" "filters" "preprocessors")))
  ;; (package! ox-json)

  ;; LaTeX
  (package! laas)

  ;; Screenshot
  (package! screenshot :recipe (:host github :repo "tecosaur/screenshot"))

  ;; Statistics
  (package! ess-view)

  ;; Shell/Terminal
  (package! powershell)
  (package! dwim-shell-command)
  (package! eat
    :recipe (:host codeberg
             :repo "akib/emacs-eat"
             :files ("*.el" ("term" "term/*.el") "*.texi"
                     "*.ti" ("terminfo/e" "terminfo/e/*")
                     ("terminfo/65" "terminfo/65/*")
                     ("integration" "integration/*")
                     (:exclude ".dir-locals.el" "*-tests.el"))))

  ;; Python
  (package! numpydoc
    :recipe (:host github :repo "douglasdavis/numpydoc.el"))

  ;; AI/LLM tools
  (package! copilot
    :recipe (:host github :repo "zerolfx/copilot.el" :files ("*.el" "dist")))
  (package! copilot-chat)
  (package! gptel)
  (package! gptel-magit)
  (package! gptel-prompts
    :recipe (:host github :repo "jwiegley/gptel-prompts"))
  (package! mcp
    :recipe (:host github :repo "lizqwerscott/mcp.el"))
  (package! mcp-hub
    :recipe (:host github :repo "lizqwerscott/mcp.el"))

  (package! ai-code)
  (package! gemini-cli
    :recipe (:host github :repo "linchen2chris/gemini-cli.el"
             :files ("*.el" (:exclude "demo.gif"))))

  (package! ghostel)
  (package! evil-ghostel)
  ;; Search
  (package! consult-web
    :recipe (:host github :repo "armindarvish/consult-web" :files (:defaults "sources/*.el")))

  ;; Dotfiles management
  (package! chezmoi
    :recipe (:host github :repo "dragarok/chezmoi.el"
             :files (:defaults "extensions/*.el"))))

;; Podcast scene for claude-podcast.el (learn-while-you-wait autoplay)
(package! elfeed)
;; (package! elfeed-tube
;;   :recipe (:host github :repo "karthink/elfeed-tube"))
;; (package! elfeed-tube-mpv
;;   :recipe (:host github :repo "karthink/elfeed-tube"))
