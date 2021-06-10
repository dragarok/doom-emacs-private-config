;; Project Management This project workflow primarily uses a single frame with
;; different workspaces, made possible by projectile, persp-mode, and eyebrowse.
;; Workflow is: open a project (see `cpm/open-existing-project-and-workspace`) and
;; use as many workspaces (via eyebrowse) as you need in that project. You can also
;; create a new buffer in a new perspective using a dummy git project and create a
;; new project entirely
;; See also https://raw.githubusercontent.com/seagle0128/.emacs.d/master/lisp/init-persp.el
;; and https://github.com/yanghaoxie/emacs.d#workspaces

;;; Projectile
(use-package projectile
  :hook (after-init . projectile-mode)
  :init
  ;; save projectile-known-projects-file in cache folder
  (setq projectile-known-projects-file
        (concat cpm-cache-dir "projectile-bookmarks.eld"))
  (setq projectile-cache-file
        (concat cpm-cache-dir "projectile.cache"))
  (setq projectile-enable-caching t
        projectile-files-cache-expire 60)
  :config
  ;; Use the faster searcher to handle project files: ripgrep `rg'.
  (when (and (not (executable-find "fd"))
             (executable-find "rg"))
    (setq projectile-generic-command
          (let ((rg-cmd ""))
            (dolist (dir projectile-globally-ignored-directories)
              (setq rg-cmd (format "%s --glob '!%s'" rg-cmd dir)))
            (concat "rg -0 --files --color=never --hidden" rg-cmd))))
  (setq projectile-git-submodule-command nil
        projectile-current-project-on-switch 'move-to-end))
  ;; (setq projectile-mode-line-prefix " P:")
  ;; (setq projectile-dynamic-mode-line t))

  (add-hook 'projectile-after-switch-project-hook (lambda ()
                                                    (projectile-invalidate-cache nil)))


;;; Eyebrowse
(use-package eyebrowse
  :hook (after-init . eyebrowse-mode)
  :general
  (:keymaps 'override
   :states '(normal visual motion)
   "gt" 'eyebrowse-next-window-config
   "gT" 'eyebrowse-prev-window-config
   "gc" 'eyebrowse-create-window-config
   "gd" 'eyebrowse-close-window-config
   "gl" 'eyebrowse-last-window-config
   "g0" 'eyebrowse-switch-to-window-config-0
   "g1" 'eyebrowse-switch-to-window-config-1
   "g2" 'eyebrowse-switch-to-window-config-2
   "g3" 'eyebrowse-switch-to-window-config-3
   "g4" 'eyebrowse-switch-to-window-config-4
   "g5" 'eyebrowse-switch-to-window-config-5
   "g6" 'eyebrowse-switch-to-window-config-6
   "g7" 'eyebrowse-switch-to-window-config-7
   "g8" 'eyebrowse-switch-to-window-config-8
   "g9" 'eyebrowse-switch-to-window-config-9)
  (cpm/leader-keys
    "w." 'hydra-eyebrowse/body
    "ww" 'eyebrowse-switch-to-window-config
    "wr" 'eyebrowse-rename-window-config)
  :config
  (setq eyebrowse-new-workspace 'dired-jump
        eyebrowse-mode-line-style 'hide
        eyebrowse-wrap-around t
        eyebrowse-switch-back-and-forth t)
  (custom-set-faces '(eyebrowse-mode-line-active ((nil))))
  (eyebrowse-mode))

(defhydra hydra-eyebrowse (:hint nil)
  "
 Go to^^^^^^                         Actions^^
 [_0_.._9_]^^     nth/new workspace  [_d_] close current workspace
 [_C-0_.._C-9_]^^ nth/new workspace
 [_<tab>_]^^^^    last workspace     [_q_] quit
 [_c_/_C_]^^      create workspace
 [_n_/_C-l_]^^    next workspace
 [_N_/_p_/_C-h_]  prev workspace
 [_w_]^^^^        workspace w/helm/ivy\n"
  ("0" eyebrowse-switch-to-window-config-0 :exit t)
  ("1" eyebrowse-switch-to-window-config-1 :exit t)
  ("2" eyebrowse-switch-to-window-config-2 :exit t)
  ("3" eyebrowse-switch-to-window-config-3 :exit t)
  ("4" eyebrowse-switch-to-window-config-4 :exit t)
  ("5" eyebrowse-switch-to-window-config-5 :exit t)
  ("6" eyebrowse-switch-to-window-config-6 :exit t)
  ("7" eyebrowse-switch-to-window-config-7 :exit t)
  ("8" eyebrowse-switch-to-window-config-8 :exit t)
  ("9" eyebrowse-switch-to-window-config-9 :exit t)
  ("C-0" eyebrowse-switch-to-window-config-0)
  ("C-1" eyebrowse-switch-to-window-config-1)
  ("C-2" eyebrowse-switch-to-window-config-2)
  ("C-3" eyebrowse-switch-to-window-config-3)
  ("C-4" eyebrowse-switch-to-window-config-4)
  ("C-5" eyebrowse-switch-to-window-config-5)
  ("C-6" eyebrowse-switch-to-window-config-6)
  ("C-7" eyebrowse-switch-to-window-config-7)
  ("C-8" eyebrowse-switch-to-window-config-8)
  ("C-9" eyebrowse-switch-to-window-config-9)
  ("<tab>" eyebrowse-last-window-config)
  ("<return>" nil :exit t)
  ("TAB" eyebrowse-last-window-config)
  ("RET" nil :exit t)
  ("c" eyebrowse-create-window-config :exit t)
  ("C" eyebrowse-create-window-config)
  ("C-h" eyebrowse-prev-window-config)
  ("C-l" eyebrowse-next-window-config)
  ("d" eyebrowse-close-window-config)
  ;; ("l" hydra-persp/body :exit t)
  ("n" eyebrowse-next-window-config)
  ("N" eyebrowse-prev-window-config)
  ("p" eyebrowse-prev-window-config)
  ("r" eyebrowse-rename-window-config)
  ("w" eyebrowse-switch-to-window-config :exit t)
  ("q" nil))


;;; Perspectives
(use-package persp-mode
  :hook (after-init . persp-mode)
  :general
  (:states '(insert normal motion emacs)
   :keymaps 'override
   "s-p" 'persp-switch
   "s-]" 'persp-next
   "s-[" 'persp-prev)
  :config
  (setq persp-reset-windows-on-nil-window-conf t
        persp-set-last-persp-for-new-frames nil
        persp-auto-resume-time -1
        persp-add-buffer-on-after-change-major-mode t
        persp-nil-name "default"
        persp-kill-foreign-buffer-behaviour 'kill
        persp-remove-buffers-from-nil-persp-behaviour nil
        persp-autokill-persp-when-removed-last-buffer t
        persp-autokill-buffer-on-remove 'kill
        persp-save-dir (expand-file-name "persp-confs/" cpm-cache-dir))
  ;; persp-common-buffer-filter-functions
  ;; (list #'(lambda (b)
  ;;           "Ignore temporary buffers."
  ;;           (or (string-prefix-p " " (buffer-name b))
  ;;               (and (string-prefix-p "*" (buffer-name b))
  ;;                    (not (string-equal "*scratch*" (buffer-name b))))
  ;;               (string-prefix-p "magit" (buffer-name b))
  ;;               (string-prefix-p "Pfuture-Callback" (buffer-name b))
  ;;               (eq (buffer-local-value 'major-mode b) 'nov-mode)
  ;;               (eq (buffer-local-value 'major-mode b) 'vterm-mode)))))

  ;; fix for (void-function make-persp-internal) error
  ;; NOTE: Redefine `persp-add-new' to address.
  ;; Issue: Unable to create/handle persp-mode
  ;; https://github.com/Bad-ptr/persp-mode.el/issues/96
  ;; https://github.com/Bad-ptr/persp-mode-projectile-bridge.el/issues/4
  ;; https://emacs-china.org/t/topic/6416/7
  (cl-defun persp-add-new (name &optional (phash *persp-hash*))
    "Create a new perspective with the given `NAME'. Add it to `PHASH'.
   Return the created perspective."
    (interactive "sA name for the new perspective: ")
    (if (and name (not (equal "" name)))
        (cl-destructuring-bind (e . p)
            (persp-by-name-and-exists name phash)
          (if e p
            (setq p (if (equal persp-nil-name name)
                        nil (make-persp :name name)))
            (persp-add p phash)
            (run-hook-with-args 'persp-created-functions p phash)
            p))
      (message "[persp-mode] Error: Can't create a perspective with empty name.")
      nil)))

  ;; ;; Integrate Ivy
  ;; ;; https://gist.github.com/Bad-ptr/1aca1ec54c3bdb2ee80996eb2b68ad2d#file-persp-ivy-el
  ;; (with-eval-after-load 'ivy
  ;;   (add-to-list 'ivy-ignore-buffers
  ;;                #'(lambda (b)
  ;;                    (when persp-mode
  ;;                      (let ((persp (get-current-persp)))
  ;;                        (if persp
  ;;                            (not (persp-contain-buffer-p b persp))
  ;;                          nil)))))

  ;;   (setq ivy-sort-functions-alist
  ;;         (append ivy-sort-functions-alist
  ;;                 '((persp-kill-buffer   . nil)
  ;;                   (persp-remove-buffer . nil)
  ;;                   (persp-add-buffer    . nil)
  ;;                   (persp-switch        . nil)
  ;;                   (persp-window-switch . nil))))))

  (use-package persp-mode-projectile-bridge
    :after (persp-mode projectile-mode)
    :hook (persp-mode . persp-mode-projectile-bridge-mode)
    :functions (persp-add-new
                persp-add-buffer
                set-persp-parameter)
    :commands (persp-mode-projectile-bridge-find-perspectives-for-all-buffers
               persp-mode-projectile-bridge-kill-perspectives
               persp-mode-projectile-bridge-add-new-persp
               projectile-project-buffers))

;;; Project Functions
;;;; Open agenda as workspace
(defun cpm/open-agenda-in-workspace ()
  "open agenda in its own perspective"
  (interactive)
  (if (get-buffer "*Org Agenda*")
      (progn
        (persp-switch "agenda")
        ;; (eyebrowse-switch-to-window-config-1)
        (switch-to-buffer "*Org Agenda*")
        (org-agenda-redo)
        (delete-other-windows))
    (progn
      (persp-switch "agenda")
      ;; (setq frame-title-format '("" "%b"))
      (require 'org)
      (require 'org-super-agenda)
      (cpm/jump-to-org-super-agenda)
      (persp-add-buffer "*Org Agenda*"))))

(general-define-key
 :states '(insert normal motion emacs)
 :keymaps 'override
 "s-1" 'cpm/open-agenda-in-workspace)

;;;; Open emacs.d in workspace
(defun cpm/open-emacsd-in-workspace ()
  "open emacsd in its own perspective"
  (interactive)
  (if (get-buffer "init.el")
      (persp-switch "emacs.d")
    (persp-switch "emacs.d")
    ;; (setq frame-title-format
    ;;       '(""
    ;;         "%b"
    ;;         (:eval
    ;;          (let ((project-name (projectile-project-name)))
    ;;            (unless (string= "-" project-name)
    ;;              (format " in [%s]" project-name))))))
    (require 'crux)
    (crux-find-user-init-file)
    (require 'magit)
    (magit-status-setup-buffer)))

(general-define-key
 :states '(insert normal motion emacs)
 :keymaps 'override
 "s-2" 'cpm/open-emacsd-in-workspace)

;;;; Open Notes in workspace
(defun cpm/open-notes-in-workspace ()
  "open notes dir in its own perspective"
  (interactive)
  (if (get-buffer "*Deft*")
      (persp-switch "Notes")
    (persp-switch "Notes")
    ;; (setq frame-title-format
    ;;       '(""
    ;;         "%b"
    ;;         (:eval
    ;;          (let ((project-name (projectile-project-name)))
    ;;            (unless (string= "-" project-name)
    ;;              (format " in [%s]" project-name))))))
    (cpm/notebook))
  (persp-add-buffer "*Deft*"))

(general-define-key
 :states '(insert normal motion emacs)
 :keymaps 'override
 "s-3" 'cpm/open-notes-in-workspace)

;;;; Terminal Workspace
(defun cpm/vterm-home ()
  (interactive)
  (let ((default-directory "~/"))
    (require 'multi-vterm)
    (multi-vterm-next)))

(defun cpm/open-new-terminal-and-workspace ()
  "open an empty buffer in its own perspective"
  (interactive)
  (if (get-buffer "*vterminal<1>*")
      (persp-switch "Terminal")
    (persp-switch "Terminal"))
  (evil-set-initial-state 'vterm-mode 'insert)
  (cpm/vterm-home)
  (delete-other-windows)
  (persp-add-buffer "*vterminal<1>*")
  ;; (setq frame-title-format '("" "%b"))
  )

(general-define-key
 :states '(insert normal motion emacs)
 :keymaps 'override
 "s-4" 'cpm/open-new-terminal-and-workspace)

;;;; Open Mu4e Email in Workspace
(defun cpm/open-email-in-workspace ()
  "open agenda in its own perspective"
  (interactive)
  (if (get-buffer "*mu4e-main*")
      (progn
        (persp-switch "Email")
        ;; (eyebrowse-switch-to-window-config-1)
        (switch-to-buffer "*mu4e-main*")
        (delete-other-windows))
    (progn
      (persp-switch "Email")
      ;; (setq frame-title-format '("" "%b"))
      (mu4e)
      (persp-add-buffer "*mu4e-main*"))))

(general-define-key
 :states '(insert normal motion emacs)
 :keymaps 'override
 "s-5" 'cpm/open-email-in-workspace)


;;;; Open New Buffer in Workspace
;; This function is a bit weird; It creates a new buffer in a new workspace with a
;; dummy git project to give the isolation of buffers typical with a git project
;; I'm sure there is a more elegant way to do this but I don't know how :)
(defun cpm/open-new-buffer-and-workspace ()
  "open an empty buffer in its own perspective"
  (interactive)
  (eyebrowse-switch-to-window-config-0)
  (persp-switch "new-persp")
  (let ((cpm-project-temp-dir "/tmp/temp-projects/"))
    (progn
      (when (not (file-exists-p cpm-project-temp-dir))
        (make-directory cpm-project-temp-dir t))
      (when (not (file-exists-p (concat cpm-project-temp-dir ".git/")))
        (magit-init cpm-project-temp-dir))
      (when (not (file-exists-p (concat cpm-project-temp-dir "temp")))
        (with-temp-buffer (write-file (concat cpm-project-temp-dir "temp")))))
    (setq default-directory cpm-project-temp-dir)
    (find-file (concat cpm-project-temp-dir "temp"))
    (persp-add-buffer "*scratch*")
    ;; (setq frame-title-format '("" "%b")))
    ))


;;;; Open Project in New Workspace
  (defun cpm/open-existing-project-and-workspace ()
    "open a project as its own perspective"
    (interactive)
    (persp-switch "new-persp")
    (projectile-switch-project)
    ;; (setq frame-title-format
    ;;       '(""
    ;;         "%b"
    ;;         (:eval
    ;;          (let ((project-name (projectile-project-name)))
    ;;            (unless (string= "-" project-name)
    ;;              (format " in [%s]" project-name))))))
    ;; (eyebrowse-rename-window-config (eyebrowse--get 'current-slot) (projectile-project-name))
    (require 'magit)
    (magit-status-setup-buffer)
    (persp-rename (projectile-project-name)))

;;;; Open & Create New Project in New Workspace
;; Create a new git project in its own perspective & workspace and create some useful
;; files
  (defun cpm/create-new-project-and-workspace ()
    "create & open a project as its own perspective"
    (interactive)
    ;; (eyebrowse-switch-to-window-config-1)
    (persp-switch "new-project")
    (cpm/git-new-project)
    ;; (setq frame-title-format
    ;;       '(""
    ;;         "%b"
    ;;         (:eval
    ;;          (let ((project-name (projectile-project-name)))
    ;;            (unless (string= "-" project-name)
    ;;              (format " in [%s]" project-name))))))
    ;; (eyebrowse-rename-window-config (eyebrowse--get 'current-slot) (projectile-project-name))
    (delete-other-windows)
    (find-file ".gitignore")
    (find-file "project-todo.org")
    (magit-status-setup-buffer))


;;;; Eyebrowse & Perspectives
;; courtesy of Spacemacs
;; Eyebrowse - allow perspective-local eyebrowse workspaces --------------------------
;; See https://github.com/syl20bnr/spacemacs/issues/3733
;; and https://github.com/syl20bnr/spacemacs/pull/5874

(defun cpm/load-eyebrowse-for-perspective (type &optional frame)
  "Load an eyebrowse workspace according to a perspective's parameters.
 FRAME's perspective is the perspective that is considered, defaulting to
 the current frame's perspective.
 If the perspective doesn't have a workspace, create one."
  (when (eq type 'frame)
    (let* ((persp (get-current-persp frame))
           (window-configs (persp-parameter 'eyebrowse-window-configs persp))
           (current-slot (persp-parameter 'eyebrowse-current-slot persp))
           (last-slot (persp-parameter 'eyebrowse-last-slot persp)))
      (if window-configs
          (progn
            (eyebrowse--set 'window-configs window-configs frame)
            (eyebrowse--set 'current-slot current-slot frame)
            (eyebrowse--set 'last-slot last-slot frame)
            (eyebrowse--load-window-config current-slot))
        (eyebrowse--set 'window-configs nil frame)
        (eyebrowse-init frame)
        (cpm/save-eyebrowse-for-perspective frame)))))

(defun cpm/update-eyebrowse-for-perspective (_new-persp-name _frame)
  "Update and save current frame's eyebrowse workspace to its perspective.
 Parameter _NEW-PERSP-NAME is ignored, and exists only for compatibility with
 `persp-before-switch-functions'."
  (eyebrowse--update-window-config-element
   (eyebrowse--current-window-config (eyebrowse--get 'current-slot)
                                     (eyebrowse--get 'current-tag)))
  (cpm/save-eyebrowse-for-perspective))

(defun cpm/save-eyebrowse-for-perspective (&optional frame)
  "Save FRAME's eyebrowse workspace to FRAME's perspective.
 FRAME defaults to the current frame."
  (let ((persp (get-current-persp frame)))
    (set-persp-parameter
     'eyebrowse-window-configs (eyebrowse--get 'window-configs frame) persp)
    (set-persp-parameter
     'eyebrowse-current-slot (eyebrowse--get 'current-slot frame) persp)
    (set-persp-parameter
     'eyebrowse-last-slot (eyebrowse--get 'last-slot frame) persp)))

(add-hook 'persp-before-switch-functions #'cpm/update-eyebrowse-for-perspective)
(add-hook 'eyebrowse-post-window-switch-hook #'cpm/save-eyebrowse-for-perspective)
(add-hook 'persp-activated-functions #'cpm/load-eyebrowse-for-perspective)


;;; Bookmarks
(use-package bookmark
  :defer 2
  :config
  (setq bookmark-default-file (concat cpm-cache-dir "bookmarks")))

(use-package bookmark+
  :commands (bmkp-switch-bookmark-file-create bmkp-set-desktop-bookmark)
  :config
  (setq bmkp-last-as-first-bookmark-file (concat cpm-cache-dir "bookmarks")))


;;; End Projects.el
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide 'setup-projects)



;;;; Org demote/promote region
(defun endless/demote-everything (number beg end)
  "Add a NUMBER of * to all headlines between BEG and END.
    Interactively, NUMBER is the prefix argument and BEG and END are
    the region boundaries."
  (interactive "p\nr")
  (save-excursion
    (save-restriction
      (save-match-data
        (widen)
        (narrow-to-region beg end)
        (goto-char (point-min))
        (let ((string (make-string number ?*)))
          (while (search-forward-regexp "^\\*" nil t)
            (insert string)))))))



(defun org-toggle-properties ()
  ;; toggle visibility of properties in current header if it exists
  (save-excursion
    (when (not (org-at-heading-p))
      (org-previous-visible-heading 1))
    (when (org-header-property-p)
      (let* ((a (re-search-forward "\n\\:" nil t)))
        (if (outline-invisible-p (point))
            (outline-show-entry)
          (org-cycle-hide-drawers 'all))))))


;;;; Org Return DWIM
;; Note that i've disabled this for now as it was causing issues
;; https://gist.github.com/alphapapa/61c1015f7d1f0d446bc7fd652b7ec4fe
(defun cpm/org-return (&optional ignore)
  "Add new list item, heading or table row with RET.
    A double return on an empty element deletes it. Use a prefix arg
    to get regular RET. "
  ;; See https://gist.github.com/alphapapa/61c1015f7d1f0d446bc7fd652b7ec4fe and
  ;; http://kitchingroup.cheme.cmu.edu/blog/2017/04/09/A-better-return-in-org-mode/
  (interactive "P")
  (if ignore
      (org-return)
    (cond ((eq 'link (car (org-element-context)))
           ;; Open links like usual
           (org-open-at-point-global))
          ((and (fboundp 'org-inlinetask-in-task-p) (org-inlinetask-in-task-p))
           ;; It doesn't make sense to add headings in inline tasks. Thanks Anders
           ;; Johansson!
           (org-return))
          ((org-at-item-checkbox-p)
           ;; Add checkboxes
           (org-insert-todo-heading nil))
          ((and (org-in-item-p) (not (bolp)))
           ;; Lists end with two blank lines, so we need to make sure we are also not
           ;; at the beginning of a line to avoid a loop where a new entry gets
           ;; created with only one blank line.
           (if (org-element-property :contents-begin (org-element-context))
               (org-insert-heading)
             (beginning-of-line)
             (delete-region (line-beginning-position) (line-end-position))
             (org-return)))
          ((org-at-heading-p)
           (if (s-present? (org-element-property :title (org-element-context)))
               (progn
                 (org-end-of-meta-data)
                 (org-insert-heading))
             (beginning-of-line)
             (delete-region (line-beginning-position) (line-end-position))))
          ((org-at-table-p)
           (if (--any? (string-empty-p it)
                       (nth (- (org-table-current-dline) 1) (org-table-to-lisp)))
               (org-return)
             ;; Empty row
             (beginning-of-line)
             (delete-region (line-beginning-position) (line-end-position))
             (org-return)))
          (t
           (org-return)))))


;;;; Org Expand Region
;; see https://www.reddit.com/r/emacs/comments/f9e6kw/expandregion_for_org_mode_with_org_element_api/
;; Expansion functions for Org mode based on Org element API.
(defun gb/er/mark-org-element (&optional parent)
  "Mark the smallest Org element or object around point.
Uses the Org Element API to identify those elements or objects.
With argument PARENT, mark the parent element instead."
  (interactive)
  (let* ((el-at-point (org-element-context))
         (up-el-at-point (org-element-property :parent el-at-point))
         (el (if parent
                 (cond
                  ((not up-el-at-point)
                   (save-excursion
                     (ignore-errors (org-up-element))
                     ;; Given el-at-point has no parent at this point,
                     ;; `org-up-element' will bring point to a heading
                     ;; (back-to-heading, if not on a heading, and
                     ;; up-heading, if on one), unless it is before the
                     ;; first one.
                     ;; Note: 'org-element-at-point' and
                     ;; 'org-element-context' won't normally get a
                     ;; headline's parent (which will return nil), we'd need
                     ;; 'org-element-parse-buffer' for that.  But we don't
                     ;; want to parse the whole buffer for an expansion
                     ;; either.
                     (when (org-with-limited-levels (org-at-heading-p))
                       (org-element-at-point))))
                  ((and
                    (memq (org-element-type el-at-point)
                          org-element-all-objects)
                    (eq (org-element-type up-el-at-point) 'paragraph)
                    (memq (org-element-type
                           (org-element-property :parent up-el-at-point))
                          '(item quote-block center-block drawer)))
                   ;; Corner case, when an 'object' is also the first thing
                   ;; on a plain list item.  In this case, if we simply get
                   ;; the parent, it will be paragraph, and further
                   ;; expansion will lose the list structure from there.
                   ;; Same thing happens on quote-blocks.  So, if element at
                   ;; point is an object, its parent is a paragraph, and its
                   ;; grandparent is one of those types, we pass the
                   ;; grandparent, to follow the structure properly.
                   ;; Probably, other cases will emerge with use, which can
                   ;; just be added here.  Unfortunately, we cannot simply
                   ;; pass the granparent for all cases: e.g. if the parent
                   ;; is a headline, there is no grandparent.
                   (org-element-property :parent up-el-at-point))
                  (t
                   up-el-at-point))
               el-at-point))
         (type (org-element-type el))
         beg end)
    (when el
      (cond
       ((memq type org-element-all-objects)
        (setq beg (org-element-property :begin el))
        (setq end (- (org-element-property :end el)
                     (org-element-property :post-blank el))))
       ((memq type '(src-block center-block comment-block
                               example-block export-block quote-block
                               special-block verse-block
                               latex-environment
                               drawer property-drawer))
        (setq beg (org-element-property :begin el))
        (setq end (save-excursion
                    (goto-char (org-element-property :end el))
                    (forward-line
                     (- (org-element-property :post-blank el)))
                    (point))))
       (t
        (setq beg (org-element-property :begin el))
        (setq end (org-element-property :end el)))))
    (when (and beg end)
      (goto-char end)
      (set-mark (point))
      (goto-char beg))))

(defun gb/er/mark-org-element-parent ()
  "Mark the parent of the Org element or object around point."
  (interactive)
  (gb/er/mark-org-element t))

(defun gb/er/mark-org-element-inside ()
  "Mark contents of the smallest Org element or object around point."
  (interactive)
  (let* ((el (org-element-context))
         (type (org-element-type el))
         beg end)
    ;; Here we handle just special cases, remaining ones will fall back to
    ;; 'gb/er/mark-org-element'. So, there is no need for a residual
    ;; condition.
    (cond
     ((memq type '(bold italic strike-through underline
                        quote-block special-block verse-block
                        drawer property-drawer
                        footnote-definition footnote-reference))
      (setq beg (org-element-property :contents-begin el))
      (setq end (org-element-property :contents-end el)))
     ((memq type '(code verbatim))
      (setq beg (save-excursion
                  (goto-char (org-element-property :begin el))
                  (unless (bolp) (backward-char 1))
                  (when (looking-at org-verbatim-re)
                    (goto-char (match-beginning 4))
                    (point))))
      (setq end (save-excursion
                  (goto-char (org-element-property :begin el))
                  (unless (bolp) (backward-char 1))
                  (when (looking-at org-verbatim-re)
                    (goto-char (match-end 4))
                    (point)))))
     ((memq type '(src-block center-block comment-block
                             example-block export-block
                             latex-environment))
      (setq beg (save-excursion
                  (goto-char (org-element-property :post-affiliated el))
                  (forward-line)
                  (point)))
      (setq end (save-excursion
                  (goto-char (org-element-property :end el))
                  (forward-line
                   (1- (- (org-element-property :post-blank el))))
                  (point))))
     ;; Unsure whether this is a good handling for headlines.
     ;; ((eq type 'headline)
     ;;  (save-excursion
     ;;    ;; Following the steps of 'org-element-headline-parser' to get the
     ;;    ;; start and end position of the title.
     ;;    (goto-char (org-element-property :begin el))
     ;;    (skip-chars-forward "*")
     ;;    (skip-chars-forward " \t")
     ;;    (and org-todo-regexp
     ;;         (let (case-fold-search) (looking-at (concat org-todo-regexp " ")))
     ;;         (goto-char (match-end 0))
     ;;         (skip-chars-forward " \t"))
     ;;    (when (looking-at "\\[#.\\][ \t]*")
     ;;      (goto-char (match-end 0)))
     ;;    (when (let (case-fold-search) (looking-at org-comment-string))
     ;;      (goto-char (match-end 0)))
     ;;    (setq beg (point))
     ;;    (when (re-search-forward
     ;;           "[ \t]+\\(:[[:alnum:]_@#%:]+:\\)[ \t]*$"
     ;;           (line-end-position)
     ;;           'move)
     ;;      (goto-char (match-beginning 0)))
     ;;    (setq end (point))))
     )
    (when (and beg end)
      (goto-char end)
      (set-mark (point))
      (goto-char beg))))

;; The default sentence expansion is quite frequently fooled by a regular
;; Org document (plain lists, code blocks, in particular), so we use Org's
;; sentence commands and restrict the mark to a single paragraph.
(defun gb/er/mark-org-sentence ()
  "Marks one sentence."
  (interactive)
  (let ((par-el (org-element-lineage
                 (org-element-context) '(paragraph) t))
        (beg-quote (when (use-region-p)
                     (save-excursion
                       (goto-char (region-beginning))
                       (looking-back "[\"“]" (1- (point))))))
        (end-quote (when (use-region-p)
                     (save-excursion
                       (goto-char (region-end))
                       (looking-at "[\"”]")))))
    (when (and
           ;; Do not mark sentences when not in a paragraph.
           par-el
           ;; Also do not mark a sentence when current region is
           ;; equivalent to an 'inside-quotes' expansion, let
           ;; 'outside-quotes' expand first.
           (not (and beg-quote end-quote)))
      (save-restriction
        ;; Never mark beyond the limits of the current paragraph.
        (narrow-to-region (org-element-property :contents-begin par-el)
                          (org-element-property :contents-end par-el))
        (forward-char 1)
        (org-backward-sentence 1)
        ;; Sentences which start or end with quotes will not be expanded
        ;; into by the heuristics of 'expand-region', as the 'inside-quotes'
        ;; expansion will prevail.  Thus, we expand the sentence up to the
        ;; quote only, to be able to expand one sentence when multiple
        ;; sentences are between quotes.  This rule of thumb will not always
        ;; be ideal: e.g. when the sentence is a sequence of multiple quoted
        ;; strings.
        (when (looking-at "[\"“]")
          (goto-char (match-end 0)))
        (set-mark (point))
        (org-forward-sentence 1)
        ;; Ditto.
        (when (looking-back "[\"”]" (1- (point)))
          (goto-char (match-beginning 0)))
        (exchange-point-and-mark)))))

;; Alternate version: simpler, but no control for quotes.
;; (defun gb/er/mark-org-sentence ()
;;   "Marks one sentence."
;;   (interactive)
;;   (let ((par-el (org-element-lineage
;;                  (org-element-context) '(paragraph) t)))
;;     ;; Do not mark sentences when not in a paragraph.
;;     (when par-el
;;       (save-restriction
;;         ;; Never mark beyond the limits of the current paragraph.
;;         (narrow-to-region (org-element-property :contents-begin par-el)
;;                           (org-element-property :contents-end par-el))
;;         (forward-char 1)
;;         (org-backward-sentence 1)
;;         (set-mark (point))
;;         (org-forward-sentence 1)
;;         (exchange-point-and-mark)))))

;; Mark curved quotes in Org mode.
(defun gb/er/mark-org-inside-curved-quotes (&optional outside)
  "Mark the inside of the current curved quotes string, not
including the quotation marks."
  (interactive)
  (let ((par-el (org-element-lineage
                 (org-element-context) '(paragraph) t)))
    (when par-el
      (save-restriction
        (narrow-to-region (org-element-property :contents-begin par-el)
                          (org-element-property :contents-end par-el))
        (let* ((beg-quote (save-excursion
                            (when (search-backward "“" nil t)
                              (if outside
                                  (match-beginning 0)
                                (match-end 0)))))
               (end-quote (save-excursion
                            (when (search-forward "”" nil t)
                              (if outside
                                  (match-end 0)
                                (match-beginning 0))))))
          (when (and beg-quote end-quote)
            (goto-char end-quote)
            (set-mark (point))
            (goto-char beg-quote)))))))

(defun gb/er/mark-org-outside-curved-quotes ()
  "Mark the current curved-quotes string, including the quotation marks."
  (interactive)
  (gb/er/mark-org-inside-curved-quotes t))

;; Control pair marking in Org: let some between-pairs objects be marked as
;; Org elements.
(defun gb/er/mark-org-inside-pairs ()
  "Mark inside pairs (as defined by the mode), not including the pairs.
Don't mark when at certain Org objects."
  (interactive)
  (unless (memq (org-element-type (org-element-context))
                '(link footnote-definition macro
                       target radio-target timestamp))
    (er/mark-inside-pairs)))

(defun gb/er/mark-org-outside-pairs ()
  "Mark pairs (as defined by the mode), including the pair chars.
Don't mark when at certain Org objects."
  (interactive)
  (unless (memq (org-element-type (org-element-context))
                '(link footnote-definition macro
                       target radio-target timestamp))
    (er/mark-outside-pairs)))

;; The default expansion for symbol includes Org's emphasis markers which
;; are contiguous to symbols (they do indeed belong to the syntax class).
;; Thus, the default expansion to symbol "leaks" beyond
;; 'inside-emphasis-markers'.  To avoid this, we restrict symbol expansion
;; to the contents of Org emphasis objects.
(defun gb/er/mark-org-symbol ()
  "Mark the entire symbol around or in front of point."
  (interactive)
  (let* ((symbol-regexp "\\s_\\|\\sw")
         (el (org-element-context))
         (type (org-element-type el))
         beg-emph end-emph)
    (cond ((memq type '(bold italic underline strike-through))
           (setq beg-emph (org-element-property :contents-begin el))
           (setq end-emph (org-element-property :contents-end el)))
          ((memq type '(code verbatim))
           (setq beg-emph (save-excursion
                            (goto-char (org-element-property :begin el))
                            (unless (bolp) (backward-char 1))
                            (when (looking-at org-verbatim-re)
                              (goto-char (match-beginning 4))
                              (point))))
           (setq end-emph (save-excursion
                            (goto-char (org-element-property :begin el))
                            (unless (bolp) (backward-char 1))
                            (when (looking-at org-verbatim-re)
                              (goto-char (match-end 4))
                              (point))))))
    (save-restriction
      (when (and beg-emph end-emph)
        (narrow-to-region beg-emph end-emph))
      (when (or (looking-at symbol-regexp)
                (er/looking-back-on-line symbol-regexp))
        (skip-syntax-forward "_w")
        (set-mark (point))
        (skip-syntax-backward "_w")))))

;; expand-region configuration for Org mode
(defun gb/er/config-org-mode-expansions ()
  (when (< emacs-major-version 27)
    (require 'seq))
  (setq-local er/try-expand-list
              (append
               ;; Removing some expansions from the list
               (seq-remove
                (lambda (x)
                  (memq x '(;; The expansions based on the Org element API
                            ;; cover most of the default expansions, others
                            ;; don't seem that useful (to me) and may
                            ;; introduce some noise in the expansion
                            ;; sequence.
                            org-mark-subtree
                            er/mark-org-element
                            er/mark-org-element-parent
                            er/mark-org-code-block
                            er/mark-org-parent
                            er/mark-comment
                            er/mark-url
                            er/mark-email
                            mark-page

                            ;; The basic symbol and method-call expansion
                            ;; consider Org emphasis markers as part of the
                            ;; unit,  so I created a dedicated function for
                            ;; symbol, disabled the others.
                            er/mark-symbol
                            er/mark-symbol-with-prefix
                            er/mark-next-accessor
                            er/mark-method-call

                            ;; er/mark-paragraph actually confuses
                            ;; expand-region on plain lists, and paragraphs
                            ;; actually do work with the other expansions on
                            ;; the list (as an org-element).  For the same
                            ;; reason, remove er/mark-text-paragraph.
                            er/mark-paragraph
                            er/mark-text-paragraph

                            ;; Remove er/mark-sentence, better to work with
                            ;; Org sentence commands, which are in
                            ;; gb/er/mark-org-sentence.  For the same reason
                            ;; remove er/mark-text-sentence.
                            er/mark-sentence
                            er/mark-text-sentence

                            ;; Tweak pair expansion for Org.
                            er/mark-inside-pairs
                            er/mark-outside-pairs)))
                er/try-expand-list)
               '(gb/er/mark-org-symbol
                 gb/er/mark-org-element
                 gb/er/mark-org-element-parent
                 gb/er/mark-org-element-inside
                 gb/er/mark-org-sentence
                 gb/er/mark-org-inside-curved-quotes
                 gb/er/mark-org-outside-curved-quotes
                 gb/er/mark-org-inside-pairs
                 gb/er/mark-org-outside-pairs))))

;;;; Org link Syntax
(defun org-update-link-syntax (&optional no-query)
  "Update syntax for links in current buffer.
Query before replacing a link, unless optional argument NO-QUERY
is non-nil."
  (interactive "P")
  (org-with-point-at 1
    (let ((case-fold-search t))
      (while (re-search-forward "\\[\\[[^]]*?%\\(?:2[05]\\|5[BD]\\)" nil t)
        (let ((object (save-match-data (org-element-context))))
          (when (and (eq 'link (org-element-type object))
                     (= (match-beginning 0)
                        (org-element-property :begin object)))
            (goto-char (org-element-property :end object))
            (let* ((uri-start (+ 2 (match-beginning 0)))
                   (uri-end (save-excursion
                              (goto-char uri-start)
                              (re-search-forward "\\][][]" nil t)
                              (match-beginning 0)))
                   (uri (buffer-substring-no-properties uri-start uri-end)))
              (when (or no-query
                        (y-or-n-p
                         (format "Possibly obsolete URI syntax: %S.  Fix? "
                                 uri)))
                (setf (buffer-substring uri-start uri-end)
                      (org-link-escape (org-link-decode uri)))))))))))


;;;; Org Table Wrap
;; see https://emacs.stackexchange.com/a/30871/11934
(defun org-table-wrap-to-width (width)
  "Wrap current column to WIDTH."
  (interactive (list (read-number "Enter column width: ")))
  (org-table-check-inside-data-field)
  (org-table-align)

  (let (cline (ccol (org-table-current-column)) new-row-count (more t))
    (org-table-goto-line 1)
    (org-table-goto-column ccol)

    (while more
      (setq cline (org-table-current-line))

      ;; Cut current field
      (org-table-copy-region (point) (point) 'cut)

      ;; Justify for width
      (setq org-table-clip
            (mapcar 'list (org-wrap (caar org-table-clip) width nil)))

      ;; Add new lines and fill
      (setq new-row-count (1- (length org-table-clip)))
      (if (> new-row-count 0)
          (org-table-insert-n-row-below new-row-count))
      (org-table-goto-line cline)
      (org-table-goto-column ccol)
      (org-table-paste-rectangle)
      (org-table-goto-line (+ cline new-row-count))

      ;; Move to next line
      (setq more (org-table-goto-line (+ cline new-row-count 1)))
      (org-table-goto-column ccol))

    (org-table-goto-line 1)
    (org-table-goto-column ccol)))

(defun org-table-insert-n-row-below (n)
  "Insert N new lines below the current."
  (let* ((line (buffer-substring (point-at-bol) (point-at-eol)))
         (new (org-table-clean-line line)))
    ;; Fix the first field if necessary
    (if (string-match "^[ \t]*| *[#$] *|" line)
        (setq new (replace-match (match-string 0 line) t t new)))
    (beginning-of-line 2)
    (setq new
          (apply 'concat (make-list n (concat new "\n"))))
    (let (org-table-may-need-update) (insert-before-markers new))  ;;; remove?
    (beginning-of-line 0)
    (re-search-forward "| ?" (point-at-eol) t)
    (and (or org-table-may-need-update org-table-overlay-coordinates) ;;; remove?
         (org-table-align))
    (org-table-fix-formulas "@" nil (1- (org-table-current-dline)) n)))


;;;; Org Copy Link
;; see https://emacs.stackexchange.com/a/63038/11934
(defun cpm/org-link-copy-at-point ()
  (interactive)
  (save-excursion
    (let* ((ol-regex "\\[\\[.*?:.*?\\]\\(\\[.*?\\]\\)?\\]")
           (beg (re-search-backward "\\[\\["))
           (end (re-search-forward ol-regex))
           (link-string (buffer-substring-no-properties (match-beginning 0) (match-end 0))))
      (kill-new link-string)
      (message "Org link %s is copied." link-string))))

;;;; Remove Org Links
;; https://emacs.stackexchange.com/a/10714/11934
(defun cpm/org-replace-link-by-link-description ()
  "Replace an org link by its description or, if empty, its address"
  (interactive)
  (if (org-in-regexp org-link-bracket-re 1)
      (save-excursion
        (let ((remove (list (match-beginning 0) (match-end 0)))
              (description
               (if (match-end 2)
                   (org-match-string-no-properties 2)
                 (org-match-string-no-properties 1))))
          (apply 'delete-region remove)
          (insert description)))))
