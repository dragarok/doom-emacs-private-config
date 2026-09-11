;;; init.el -*- lexical-binding: t; -*-

;; This file controls what Doom modules are enabled and what order they load
;; in. Remember to run 'doom sync' after modifying it!

;; NOTE Press 'SPC h d h' (or 'C-h d h' for non-vim users) to access Doom's
;;      documentation. There you'll find a "Module Index" link where you'll find
;;      a comprehensive list of Doom's modules and what flags they support.

;; NOTE Move your cursor over a module's name (or its flags) and press 'K' (or
;;      'C-c c k' for non-vim users) to view its documentation. This works on
;;      flags as well (those symbols that start with a plus).
;;
;;      Alternatively, press 'gd' (or 'C-c c d') on a module to browse its
;;      directory (for easy access to its source code).

;; Platform detection for conditional module loading
(defconst IS-ANDROID (eq system-type 'android))

;; Doom core and :ui dashboard live in two repos that `doom upgrade' can
;; leave a step apart.  When core is the newer half it no longer defines
;; `doom-version', but the dashboard still formats it into the mode line
;; (`+dashboard-mode' does `(format "DOOM v%s" doom-version)'), so entering
;; the buffer dies with (void-variable doom-version) -- and since the
;; dashboard IS the startup buffer, the splash screen never comes up.
;; Define it here, before any module loads, so the phone boots on whichever
;; half of the upgrade it is currently sitting on.  Harmless once the two
;; repos line up again: the core's own definition wins.
(unless (boundp 'doom-version)
  (defvar doom-version "unknown"))

;; (add-to-list 'default-frame-alist '(undecorated-round . t))

(doom! :input
       ;;chinese
       ;;japanese
       ;;layout            ; auie,ctsrnm is the superior home row

       :completion
       ;; company           ; the ultimate code completion backend
       (:unless IS-ANDROID
         (corfu +icons +orderless))
       (:if IS-ANDROID corfu)
       ;;helm              ; the *other* search engine for love and life
       ;;ido               ; the other *other* search engine...
       ;;ivy               ; a search engine for love and life
       (:unless IS-ANDROID
         (vertico +childframe +icons))
       (:if IS-ANDROID vertico)

       :ui
       ;;deft              ; notational velocity for Emacs
       doom              ; what makes DOOM look the way it does
       dashboard    ; a nifty splash screen for Emacs
       (:unless IS-ANDROID smooth-scroll)
       ;; doom-quit         ; DOOM quit-message prompts when you quit Emacs
       (emoji +unicode)  ; emoji support on all platforms
       hl-todo           ; highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
       ;; hydra
       indent-guides     ; highlighted indent columns
       ligatures         ; ligatures and symbols to make your code pretty again
       ;;minimap           ; show a map of the code on the side
       modeline          ; snazzy, Atom-inspired modeline, plus API
       ;; nav-flash         ; blink cursor line after big motions
       ;;neotree           ; a project drawer, like NERDTree for vim
       (:unless IS-ANDROID ophints)  ; highlight the region an operation acts on
       (popup +defaults)   ; tame sudden yet inevitable temporary windows
       ;; tabs              ; a tab bar for Emacs
       (:unless IS-ANDROID (treemacs +lsp))  ; a project drawer, like neotree but cooler
       unicode  ; extended unicode support for various languages
       (:unless IS-ANDROID (vc-gutter +pretty))  ; vcs diff in the fringe
       ;; vi-tilde-fringe   ; fringe tildes to mark beyond EOB
       (:unless IS-ANDROID (window-select +numbers))  ; visually switch windows
       workspaces        ; tab emulation, persistence & separate workspaces
       zen               ; distraction-free coding or writing

       :editor
       (evil +everywhere); come to the dark side, we have cookies
       (:unless IS-ANDROID file-templates)  ; auto-snippets for empty files
       fold              ; (nigh) universal code folding
       (format +onsave)  ; automated prettiness
       ;;god               ; run Emacs commands without modifier keys
       ;;lispy             ; vim for lisp, for people who don't like vim
       (:unless IS-ANDROID multiple-cursors)  ; editing in many places at once
       ;;objed             ; text object editing for the innocent
       ;;parinfer          ; turn lisp into python, sort of
       ;; rotate-text       ; cycle region at point between text candidates
       snippets          ; my elves. They type so I don't have to
       (whitespace +guess +trim)  ; a butler for your whitespace
       (:unless IS-ANDROID word-wrap)  ; soft wrapping with language-aware indent

       :emacs
       (dired +dirvish)
       electric          ; smarter, keyword-based electric-indent
       (:unless IS-ANDROID (ibuffer +icons))  ; interactive buffer management
       (:if IS-ANDROID (ibuffer))
       (:unless IS-ANDROID (undo +tree))
       (:unless IS-ANDROID tramp)             ; remote files at your arthritic fingertips
       (:if IS-ANDROID undo)  ; persistent, smarter undo for your inevitable mistakes
       (:unless IS-ANDROID vc)  ; version-control and Emacs, sitting in a tree

       :term
       eshell            ; the elisp shell that works everywhere
       ;;shell             ; simple shell REPL for Emacs
       ;;term              ; basic terminal emulator for Emacs

       :checkers
       (:unless IS-ANDROID (syntax +childframe))  ; tasing you for every semicolon you forget
       (:unless IS-ANDROID (spell +hunspell))  ; tasing you for misspelling mispelling
       ;; grammar           ; tasing grammar mistake every you make

       :tools
       ;;ansible
       biblio            ; Writes a PhD for you (citation needed)
       (:unless IS-ANDROID debugger)  ; FIXME stepping through code, to help you add bugs
       direnv
       (:unless IS-ANDROID docker)
       (:unless IS-ANDROID editorconfig)  ; let someone else argue about tabs vs spaces
       (:unless IS-ANDROID ein)  ; tame Jupyter notebooks with emacs
       (:unless IS-ANDROID (eval +overlay))  ; run code, run (also, repls)
       ;; gist              ; interacting with github gists
       (:unless IS-ANDROID (lookup +dictionary +offline +docsets))  ; navigate your code and its documentation
       (:unless IS-ANDROID (lsp +peek +booster))  ; M-x vscode
       ;; llm
       (:unless IS-ANDROID (magit +forge))
       (:if IS-ANDROID magit)  ; a git porcelain for Emacs
       ;;make              ; run make tasks from Emacs
       (:unless IS-ANDROID pass)  ; password manager for nerds
       (:unless IS-ANDROID pdf)   ; pdf enhancements
       ;;taskrunner        ; taskrunner for all your projects
       (:unless IS-ANDROID terraform)  ; infrastructure as code
       ;;tmux              ; an API for interacting with tmux
       (:unless IS-ANDROID tree-sitter)
       (:unless IS-ANDROID upload)  ; map local to remote projects via ssh/ftp

       :os
       (:if (featurep :system 'macos) macos)  ; improve compatibility with macOS
       (:unless IS-ANDROID (tty +osc))               ; improve the terminal Emacs experience

       :lang
       ;;agda              ; types of types of types of types...
       (:unless IS-ANDROID (beancount +lsp))
       (:if IS-ANDROID beancount)  ; mind the GAAP
       ;;cc                ; C > C++ == 1
       ;;clojure           ; java with a lisp
       ;;common-lisp       ; if you've seen one lisp, you've seen them all
       ;;coq               ; proofs-as-programs
       ;;crystal           ; ruby at the speed of c
       (:unless IS-ANDROID (csharp +tree-sitter +lsp))  ; unity, .NET, and mono shenanigans
       (:unless IS-ANDROID data)  ; config/data formats
       ;;(dart +flutter)   ; paint ui and not much else
       ;;dhall
       ;;elixir            ; erlang done right
       ;;elm               ; care for a cup of TEA?
       emacs-lisp        ; drown in parentheses
       ;;erlang            ; an elegant language for a more civilized age
       (:unless IS-ANDROID ess)  ; emacs speaks statistics
       ;;factor
       ;;faust             ; dsp, but you get to keep your soul
       ;;fortran           ; in FORTRAN, GOD is REAL (unless declared INTEGER)
       ;;fsharp            ; ML stands for Microsoft's Language
       ;;fstar             ; (dependent) types and (monadic) effects and Z3
       ;;gdscript          ; the language you waited for
       (:unless IS-ANDROID (go +lsp))  ; the hipster dialect
       (:unless IS-ANDROID (haskell +lsp))  ; a language that's lazier than I am
       ;;hy                ; readability of scheme w/ speed of python
       ;;idris             ; a language you can depend on
       (:unless IS-ANDROID json)  ; At least it ain't XML
       ;;(java +meghanada) ; the poster child for carpal tunnel syndrome
       (:unless IS-ANDROID (javascript +tree-sitter +lsp))  ; all(hope(abandon(ye(who(enter(here))))))
       ;; (julia +lsp)      ; a better, faster MATLAB
       (:unless IS-ANDROID (kotlin +lsp))  ; a better, slicker Java(Script)
       (:unless IS-ANDROID (latex +cdlatex +fold +lsp +latexmk))  ; writing papers in Emacs has never been so fun
       ;;lean              ; for folks with too much to prove
       ;;ledger            ; be audit you can be
       ;;lua               ; one-based indices? one-based indices
       (:unless IS-ANDROID (markdown +grip))  ; writing docs for people to ignore
       (:if IS-ANDROID markdown)  ; writing docs for people to ignore
       ;;nim               ; python + lisp at the speed of c
       ;;nix               ; I hereby declare "nix geht mehr!"
       ;;ocaml             ; an objective camel
       (:unless IS-ANDROID
         (org +dragndrop +hugo +jupyter +noter +pandoc +present +pretty +roam2))
       (:if IS-ANDROID
           (org +pretty +roam2))  ; organize your plain life in plain text
       ;;php               ; perl's insecure younger brother
       ;; plantuml          ; diagrams for confusing people more
       ;;purescript        ; javascript, but functional
       (:unless IS-ANDROID (python +tree-sitter +lsp +uv))
       (:if IS-ANDROID (python +pyenv))  ; beautiful is better than ugly
       ;;qt                ; the 'cutest' gui framework ever
       ;;racket            ; a DSL for DSLs
       ;;raku              ; the artist formerly known as perl6
       ;;rest              ; Emacs as a REST client
       ;;rst               ; ReST in peace
       ;;(ruby +rails)     ; 1.step {|i| p "Ruby is #{i.even? ? 'love' : 'life'}"}
       (:unless IS-ANDROID (rust +lsp))  ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
       ;;scala             ; java, but good
       ;;(scheme +guile)   ; a fully conniving family of lisps
       (:unless IS-ANDROID (sh +powershell +tree-sitter +lsp))
       (:if IS-ANDROID sh)  ; she sells {ba,z,fi}sh shells on the C xor
       ;;sml
       ;;solidity          ; do you need a blockchain? No.
       (:unless IS-ANDROID (swift +lsp +tree-sitter))  ; who asked for emoji variables?
       ;;terra             ; Earth and Moon in alignment for performance.
       (:unless IS-ANDROID (web +tree-sitter +lsp))  ; the tubes
       (:unless IS-ANDROID (yaml +lsp))  ; JSON, but readable
       ;;zig               ; C, but simpler

       :email
       ;; (mu4e +org +gmail)
       ;;notmuch
       ;;(wanderlust +gmail)

       :app
       calendar
       ;; emms
       (:unless IS-ANDROID everywhere)  ; *leave* Emacs!? You must be joking
       ;;irc               ; how neckbeards socialize
       ;; (rss +org)        ; emacs as an RSS reader
       ;; twitter           ; twitter client https://twitter.com/vnought

       :config
       ;;literate
       (:unless IS-ANDROID (default +bindings))
       (:if IS-ANDROID (default +bindings +smartparens)))

;; Machine-local values (Tailscale IPs etc.) — git-ignored, one per device
(load (expand-file-name "local.el" doom-user-dir) t t)

;; Termux PATH setup for Android
(when IS-ANDROID
  (let ((termux-bin "/data/data/com.termux/files/usr/bin")
        (home-bin "/data/data/com.termux/files/home/bin")
        (termux-local-bin "/data/data/com.termux/files/home/.local/bin")
        (texlive-bin "/data/data/com.termux/files/usr/bin/texlive"))
    ;; Prepend ~/bin, texlive, and Termux bin to PATH
    (setenv "PATH" (concat home-bin ":" termux-local-bin ":" texlive-bin ":" termux-bin ":" (getenv "PATH")))
    (setq exec-path (cons home-bin (cons termux-local-bin (cons texlive-bin (cons termux-bin exec-path)))))

    ;; Android Emacs exports LANG=en_US.utf8 — a spelling macOS doesn't have,
    ;; so mosh/ssh sessions spawned from a terminal buffer break. Match Termux instead.
    (setenv "LANG" "en_US.UTF-8")

    ;; Claude Code needs a writable tmp dir — /tmp doesn't exist on Android
    (let ((claude-tmp (concat home-bin "/../.claude-tmp")))
      (unless (file-directory-p claude-tmp) (make-directory claude-tmp t))
      (setenv "CLAUDE_CODE_TMPDIR" claude-tmp)
      (setenv "TMPDIR" claude-tmp)
      (setq temporary-file-directory (file-name-as-directory claude-tmp)))

    ;; Point TeX Live to the full installation (not the broken 2025.0 stub)
    (setenv "TEXMFROOT" "/data/data/com.termux/files/usr/share/texlive/2025")
    (setenv "TEXMFLOCAL" "/data/data/com.termux/files/usr/share/texlive/texmf-local")

    ;; Optional: explicitly force ssh program (extra safety)
    (let ((termux-ssh (concat termux-bin "/ssh")))
      (when (file-executable-p termux-ssh)
        (setq ssh-program termux-ssh)
        (setenv "GIT_SSH" termux-ssh)))))
