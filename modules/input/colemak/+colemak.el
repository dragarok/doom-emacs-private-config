;;; input/layout/+colemak.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +layout-colemak-rotate-ne-bare-keymap (keymaps)
  "Rotate [jkl] with [nei] in KEYMAP."
  (evil-collection-translate-key nil keymaps
    "n" "j"
    "N" "J"
    "e" "k"
    "E" "K"
    "j" "n"
    "J" "N"
    "k" "e"
    "K" "E"
    (kbd "C-n") (kbd "C-j")
    (kbd "C-e") (kbd "C-k")
    (kbd "C-j") (kbd "C-n")
    (kbd "C-k") (kbd "C-e")
    (kbd "M-n") (kbd "M-j")
    (kbd "M-e") (kbd "M-k")
    (kbd "M-j") (kbd "M-n")
    (kbd "M-k") (kbd "M-e")
    (kbd "C-S-n") (kbd "C-S-j")
    (kbd "C-S-e") (kbd "C-S-k")
    (kbd "C-S-j") (kbd "C-S-n")
    (kbd "C-S-k") (kbd "C-S-e")
    (kbd "M-S-n") (kbd "M-S-j")
    (kbd "M-S-e") (kbd "M-S-k")
    (kbd "M-S-j") (kbd "M-S-n")
    (kbd "M-S-k") (kbd "M-S-e")))

;;;###autoload
(defun +layout-colemak-rotate-i-bare-keymap (keymaps)
  "Rotate [uil] with [ilu] in KEYMAP."
  (evil-collection-translate-key nil keymaps
    "i" "l"
    "I" "L"
    "l" "u"
    "L" "U"
    "u" "i"
    "U" "I"
    (kbd "C-u") (kbd "C-i")
    (kbd "C-i") (kbd "C-l")
    (kbd "C-l") (kbd "C-u")
    (kbd "M-l") (kbd "M-i")
    (kbd "M-i") (kbd "M-l")
    (kbd "M-l") (kbd "M-u")
    (kbd "C-S-l") (kbd "C-S-i")
    (kbd "C-S-i") (kbd "C-S-l")
    (kbd "C-S-l") (kbd "C-S-u")
    (kbd "M-S-l") (kbd "M-S-i")
    (kbd "M-S-i") (kbd "M-S-l")
    (kbd "M-S-l") (kbd "M-S-u")))

;;;###autoload
(defun +layout-colemak-rotate-bare-keymap (keymaps)
  "Rotate [jkl] with [nei] in KEYMAP."
  (+layout-colemak-rotate-ne-bare-keymap keymaps)
  (+layout-colemak-rotate-i-bare-keymap keymaps))

;;;###autoload
(defun +layout-colemak-rotate-evil-keymap ()
  "Remap evil-{normal,operator,motion,...}-state-map to be more natural with
colemak keyboard layout."
    (evil-collection-translate-key nil
      '(evil-normal-state-map evil-motion-state-map evil-visual-state-map evil-operator-state-map)
      "n" "j"
      "N" "J"
      "e" "k"
      "E" "K"
      "j" "n"
      "J" "N"
      "k" "e"
      "K" "E"
      "i" "l"
      "I" "L"
      "l" "u"
      "L" "U"
      "u" "i"
      "U" "I"
      ))

;;;###autoload
(defun +layout-colemak-rotate-keymaps (keymaps)
  "Remap evil-collection keybinds in KEYMAPS for Colemak keyboard keyboard layouts."
    (evil-collection-translate-key '(normal motion visual operator) keymaps
      "n" "j"
      "N" "J"
      "e" "k"
      "E" "K"
      "j" "n"
      "J" "N"
      "k" "e"
      "K" "E"
      "i" "l"
      "I" "L"
      "l" "u"
      "L" "U"
      "u" "i"
      "U" "I"
      (kbd "C-n") (kbd "C-j")
      (kbd "C-N") (kbd "C-J")
      (kbd "C-e") (kbd "C-k")
      (kbd "C-E") (kbd "C-K")
      (kbd "C-i") (kbd "C-l")
      (kbd "C-I") (kbd "C-L")
      (kbd "C-l") (kbd "C-u")
      (kbd "C-L") (kbd "C-U")
      (kbd "C-u") (kbd "C-i")
      (kbd "C-U") (kbd "C-I")
      (kbd "C-j") (kbd "C-n")
      (kbd "C-J") (kbd "C-N")
      (kbd "C-k") (kbd "C-e")
      (kbd "C-K") (kbd "C-E")
      (kbd "C-l") (kbd "C-i")
      (kbd "C-L") (kbd "C-I")
      (kbd "M-n") (kbd "M-j")
      (kbd "M-N") (kbd "M-J")
      (kbd "M-e") (kbd "M-k")
      (kbd "M-E") (kbd "M-K")
      (kbd "M-i") (kbd "M-l")
      (kbd "M-I") (kbd "M-L")
      (kbd "M-l") (kbd "M-u")
      (kbd "M-L") (kbd "M-U")
      (kbd "M-u") (kbd "M-i")
      (kbd "M-U") (kbd "M-I")
      (kbd "M-j") (kbd "M-n")
      (kbd "M-J") (kbd "M-N")
      (kbd "M-k") (kbd "M-e")
      (kbd "M-K") (kbd "M-E")
      )
    (evil-collection-translate-key '(insert) keymaps
      (kbd "M-n") (kbd "M-j")
      (kbd "M-N") (kbd "M-J")
      (kbd "M-e") (kbd "M-k")
      (kbd "M-E") (kbd "M-K")
      (kbd "M-i") (kbd "M-l")
      (kbd "M-I") (kbd "M-L")
      (kbd "M-l") (kbd "M-u")
      (kbd "M-L") (kbd "M-U")
      (kbd "M-u") (kbd "M-i")
      (kbd "M-U") (kbd "M-I")
      (kbd "M-j") (kbd "M-n")
      (kbd "M-J") (kbd "M-N")
      (kbd "M-k") (kbd "M-e")
      (kbd "M-K") (kbd "M-E")))


(defun +layout-remap-keys-for-colemak-h ()
  (setq avy-keys '(?a ?r ?s ?t ?d ?h ?n ?e ?i ?o)
        lispy-avy-keys '(?a ?r ?s ?t ?d ?h ?n ?e ?i ?o ?q ?w ?f ?p ?g ?j ?l ?u ?y))

  ;; :ui window-select settings, ignoring +numbers flag for now
  (after! ace-window
    (setq aw-keys '(?a ?r ?s ?t ?d ?h ?n ?e ?i ?o)))
  (after! switch-window
    (setq switch-window-shortcut-style 'qwerty
          switch-window-qwerty-shortcuts '("a" "r" "s" "t" "d" "h" "n" "e" "i"))))

(defun +layout-remap-evil-keys-for-colemak-h ()
  ;; "ts" would be a little too common for an evil escape sequence
  (setq evil-escape-key-sequence "dh")
  (setq evil-markdown-movement-bindings '((up . "n")
                                          (down . "e")
                                          (left . "h")
                                          (right . "i"))
        evil-org-movement-bindings '((up . "n")
                                     (down . "e")
                                     (left . "h")
                                     (right . "i")))
  (+layout-colemak-rotate-ne-bare-keymap '(read-expression-map))
  (+layout-colemak-rotate-bare-keymap '(evil-window-map))
  (+layout-colemak-rotate-evil-keymap)
  ;; Remap the visual-mode-map bindings if necessary
  ;; See https://github.com/emacs-evil/evil/blob/7d00c23496c25a66f90ac7a6a354b1c7f9498162/evil-integration.el#L478-L501
  ;; Using +layout-colemak-rotate-keymaps is impossible because `evil-define-minor-mode-key' doesn't
  ;; provide an actual symbol to design the new keymap with, and instead stuff the keymap in
  ;; an auxiliary-auxiliary `minor-mode-map-alist'-like variable.
  (after! evil-integration
    (when evil-respect-visual-line-mode
      (map! :map visual-line-mode-map
            :m "n"  #'evil-next-visual-line
            :m "e"  #'evil-previous-visual-line
            :m "gn" #'evil-next-visual-line
            :m "ge" #'evil-previous-visual-line)))

  (map! :i "C-n" #'+default-newline
        (:when (featurep! :editor multiple-cursors)
         :prefix "gz"
         :nv "n"   #'evil-mc-make-cursor-move-next-line
         :nv "e"   #'evil-mc-make-cursor-move-prev-line
         :nv "N"   #'+multiple-cursors/evil-mc-toggle-cursors
         :nv "j"   nil
         :nv "k"   #'evil-mc-make-and-goto-next-cursor
         :nv "K"   #'evil-mc-make-and-goto-prev-cursor))
  (after! treemacs
    (+layout-colemak-rotate-ne-bare-keymap '(evil-treemacs-state-map)))
  (after! (:or helm ivy vertico icomplete)
    (+layout-colemak-rotate-keymaps
     '(minibuffer-local-map
       minibuffer-local-ns-map
       minibuffer-local-completion-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       read-expression-map))
    (+layout-colemak-rotate-bare-keymap
     '(minibuffer-local-map
       minibuffer-local-ns-map
       minibuffer-local-completion-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       read-expression-map)))
  (after! ivy
    (+layout-colemak-rotate-bare-keymap '(ivy-minibuffer-map ivy-switch-buffer-map))
    (+layout-colemak-rotate-keymaps '(ivy-minibuffer-map ivy-switch-buffer-map)))
  (after! swiper
    (map! :map swiper-map "C-s" nil))
  (after! helm
    (+layout-colemak-rotate-bare-keymap '(helm-map))
    (+layout-colemak-rotate-keymaps '(helm-map)))
  (after! helm-rg
    (+layout-colemak-rotate-bare-keymap '(helm-rg-map))
    (+layout-colemak-rotate-keymaps '(helm-rg-map)))
  (after! helm-files
    (+layout-colemak-rotate-bare-keymap '(helm-read-file-map))
    (+layout-colemak-rotate-keymaps '(helm-read-file-map)))
  (after! company
    (+layout-colemak-rotate-bare-keymap '(company-active-map company-search-map)))
  (after! evil-snipe
    (+layout-colemak-rotate-keymaps
     '(evil-snipe-local-mode-map evil-snipe-override-local-mode-map)))
  (after! eshell
    (add-hook 'eshell-first-time-mode-hook (lambda () (+layout-colemak-rotate-keymaps '(eshell-mode-map))) 99))
  (after! lsp-ui
    (+layout-colemak-rotate-ne-bare-keymap '(lsp-ui-peek-mode-map)))
  (after! org
    ;; (defadvice! doom-colemak--org-completing-read (&rest args)
    ;;   "Completing-read with SPACE being a normal character, and C-c mapping left alone."
    ;;   :override #'org-completing-read
    ;;   (let ((enable-recursive-minibuffers t)
    ;;         (minibuffer-local-completion-map
    ;;          (copy-keymap minibuffer-local-completion-map)))
    ;;     (define-key minibuffer-local-completion-map " " 'self-insert-command)
    ;;     (define-key minibuffer-local-completion-map "?" 'self-insert-command)
    ;;     (define-key minibuffer-local-completion-map
    ;;       (cond
    ;;        ((eq 'ergodis)
    ;;         (kbd "C-l !"))
    ;;        (t
    ;;         (kbd "C-h !")))
    ;;       'org-time-stamp-inactive)
    ;;     (apply #'completing-read args)))
    ;; Finalizing an Org-capture become `C-l C-c` (or `C-r C-c`) on top of `ZZ`
    (+layout-colemak-rotate-bare-keymap '(org-capture-mode-map)))
  ;; (after! (evil org evil-org)
  ;;   ;; FIXME: This map! call is being interpreted before the
  ;;   ;;   map! call in (use-package! evil-org :config) in modules/lang/org/config.el
  ;;   ;;   Therefore, this map! needs to be reevaluated to have effect.
  ;;   ;;   Need to find a way to call the code below after the :config block
  ;;   ;;   in :lang org code

  ;;   ;; Direct access for "unimpaired" like improvements
  ;;   (map! :map evil-org-mode-map
  ;;         ;; evil-org-movement bindings having "c" and "r" means
  ;;         ;; C-r gets mapped to `org-shiftright' in normal and insert state.
  ;;         ;; C-c gets mapped to `org-shiftleft' in normal and insert state.
  ;;         :ni "C-r" nil
  ;;         :ni "C-c" nil
  ;;         :ni "C-»" #'org-shiftright
  ;;         :ni "C-«" #'org-shiftleft
  ;;         :m ")" nil
  ;;         :m "(" nil
  ;;         :m "]" #'evil-org-forward-sentence
  ;;         :m "[" #'evil-org-backward-sentence
  ;;         :m ")h" #'org-forward-heading-same-level
  ;;         :m "(h" #'org-backward-heading-same-level
  ;;         :m ")l" #'org-next-link
  ;;         :m "(l" #'org-previous-link
  ;;         :m ")c" #'org-babel-next-src-block
  ;;         :m "(c" #'org-babel-previous-src-block))
  (after! (evil org evil-org-agenda)
    (+layout-colemak-rotate-bare-keymap '(org-agenda-keymap))
    (+layout-colemak-rotate-keymaps '(evil-org-agenda-mode-map)))
  ;; ediff add e and n to navigate up and down the diffs
  (after! (evil)
    (add-to-list 'evil-collection-ediff-bindings '("e" . ediff-previous-difference)))
  ;; (after! notmuch
  ;;   ;; Without this, "s" is mapped to `notmuch-search' and takes precedence over
  ;;   ;; the evil command to go up one line
  ;;   (map! :map notmuch-common-keymap :n "s" nil)
  ;;   (map! :map notmuch-common-keymap "s" nil))
  (after! (evil info)
    ;; Without this, "s" stays mapped to 'Info-search (in the "global"
    ;; `Info-mode-map') and takes precedence over the evil command to go up one
    ;; line (remapped in `Info-mode-normal-state-map').  Same for "t" that is
    ;; `Info-top-node' in the "global" `Info-mode-map'
    (map! :map Info-mode-map
          "n" nil
          "e" nil))
  (after! (evil magit)
    (+layout-colemak-rotate-ne-bare-keymap
     '(magit-mode-map
       magit-diff-section-base-map
       magit-staged-section-map
       magit-unstaged-section-map
       magit-untracked-section-map))
    ;; Without this, "s" is mapped to `magit-delete-thing' (the old "k" for "kill") and
    ;; takes precedence over the evil command to go up one line
    ;; :nv doesn't work on this, needs to be the bare map.
    ;; This is the output of `describe-function `magit-delete-thing' when we add :nv or :nvm
    ;; Key Bindings
    ;;   evil-collection-magit-mode-map-backup-map <normal-state> x
    ;;   evil-collection-magit-mode-map-backup-map <visual-state> x
    ;;   evil-collection-magit-mode-map-backup-map k
    ;;   evil-collection-magit-mode-map-normal-state-backup-map x
    ;;   evil-collection-magit-mode-map-visual-state-backup-map x
    ;;   magit-mode-map <normal-state> x
    ;;   magit-mode-map <visual-state> x
    ;;   magit-mode-map s
    ;; Same thing for t, which gets mapped to `magit-quick-status'
    (map! :map magit-mode-map
          "n" nil
          "e" nil)
    ;; Even though magit bindings are part of evil-collection now, the hook only
    ;; runs on `evil-collection-magit-maps', which is way to short to cover all
    ;; usages. The hook is run manually on other maps
    ;; NOTE `magit-mode-map' is last because other keymaps inherit from it.
    ;;      Therefore to prevent a "double rotation" issue, `magit-mode-map' is
    ;;      changed last.
    (+layout-colemak-rotate-keymaps
     '(magit-cherry-mode-map
       magit-blob-mode-map
       magit-diff-mode-map
       magit-log-mode-map
       magit-log-select-mode-map
       magit-reflog-mode-map
       magit-status-mode-map
       magit-log-read-revs-map
       magit-process-mode-map
       magit-refs-mode-map
       magit-mode-map)))
  ;; (after! evil-easymotion
  ;;   ;; Use "gé" instead of default "gs" to avoid conflicts w/org-mode later
  ;;   (evilem-default-keybindings "gé")
  ;;   (+layout-colemak-rotate-bare-keymap '(evilem-map)))
  )


;;
;;; Bootstrap

(+layout-remap-keys-for-colemak-h)
(when (featurep! :editor evil)
  (+layout-remap-evil-keys-for-colemak-h)
  (add-hook! 'evil-collection-setup-hook
    (defun +layout-colemak-rotate-evil-collection-keymap (_mode mode-keymaps &rest _rest)
      (+layout-colemak-rotate-keymaps mode-keymaps))))
