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

;;; config/default/+bindings.el -*- lexical-binding: t; -*-

;; TODO Understand good bindings



(when (featurep! :editor evil +everywhere)
  ;; NOTE SPC u replaces C-u as the universal argument.

  ;; Minibuffer
  (map! :map (evil-ex-completion-map evil-ex-search-keymap)
        "C-a" #'evil-beginning-of-line
        "C-b" #'evil-backward-char
        "C-f" #'evil-forward-char
        :gi "C-j" #'next-complete-history-element
        :gi "C-k" #'previous-complete-history-element)

  (define-key! :keymaps +default-minibuffer-maps
    [escape] #'abort-recursive-edit
    "C-a"    #'move-beginning-of-line
    "C-r"    #'evil-paste-from-register
    "C-u"    #'evil-delete-back-to-indentation
    "C-v"    #'yank
    "C-w"    #'doom/delete-backward-word
    "C-z"    (cmd! (ignore-errors (call-interactively #'undo))))

  (define-key! :keymaps +default-minibuffer-maps
    "C-j"    #'next-line
    "C-k"    #'previous-line
    "C-S-j"  #'scroll-up-command
    "C-S-k"  #'scroll-down-command)
  ;; For folks with `evil-collection-setup-minibuffer' enabled
  (define-key! :states 'insert :keymaps +default-minibuffer-maps
    "C-j"    #'next-line
    "C-k"    #'previous-line)
  (define-key! read-expression-map
    "C-j" #'next-line-or-history-element
    "C-k" #'previous-line-or-history-element))


;;
;;; Global keybindings

;; Smart tab, these will only work in GUI Emacs
(map! :i [tab] (cmds! (and (featurep! :editor snippets)
                           (yas-maybe-expand-abbrev-key-filter 'yas-expand))
                      #'yas-expand
                      (and (bound-and-true-p company-mode)
                           (featurep! :completion company +tng))
                      #'company-indent-or-complete-common)
      :m [tab] (cmds! (and (featurep! :editor snippets)
                           (evil-visual-state-p)
                           (or (eq evil-visual-selection 'line)
                               (not (memq (char-after) (list ?\( ?\[ ?\{ ?\} ?\] ?\))))))
                      #'yas-insert-snippet
                      (and (featurep! :editor fold)
                           (save-excursion (end-of-line) (invisible-p (point))))
                      #'+fold/toggle
                      ;; Fixes #4548: without this, this tab keybind overrides
                      ;; mode-local ones for modes that don't have an evil
                      ;; keybinding scheme or users who don't have :editor (evil
                      ;; +everywhere) enabled.
                      (or (doom-lookup-key
                           [tab]
                           (list (evil-get-auxiliary-keymap (current-local-map) evil-state)
                                 (current-local-map)))
                          (doom-lookup-key
                           (kbd "TAB")
                           (list (evil-get-auxiliary-keymap (current-local-map) evil-state)))
                          (doom-lookup-key (kbd "TAB") (list (current-local-map))))
                      it
                      (fboundp 'evil-jump-item)
                      #'evil-jump-item)

      (:after help :map help-mode-map
       :n "o"       #'link-hint-open-link)
      (:after helpful :map helpful-mode-map
       :n "o"       #'link-hint-open-link)
      (:after info :map Info-mode-map
       :n "o"       #'link-hint-open-link)
      (:after apropos :map apropos-mode-map
       :n "o"       #'link-hint-open-link
       :n "TAB"     #'forward-button
       :n [tab]     #'forward-button
       :n [backtab] #'backward-button)
      (:after view :map view-mode-map
       [escape]  #'View-quit-all)
      (:after man :map Man-mode-map
       :n "q"    #'kill-current-buffer)
      (:after geiser-doc :map geiser-doc-mode-map
       :n "o"    #'link-hint-open-link)

      (:unless (featurep! :input layout +bepo)
       (:after (evil-org evil-easymotion)
        :map evil-org-mode-map
        :m "gsh" #'+org/goto-visible))

      (:when (featurep! :editor multiple-cursors)
       :prefix "gz"
       :nv "d" #'evil-mc-make-and-goto-next-match
       :nv "D" #'evil-mc-make-and-goto-prev-match
       :nv "j" #'evil-mc-make-cursor-move-next-line
       :nv "k" #'evil-mc-make-cursor-move-prev-line
       :nv "m" #'evil-mc-make-all-cursors
       :nv "n" #'evil-mc-make-and-goto-next-cursor
       :nv "N" #'evil-mc-make-and-goto-last-cursor
       :nv "p" #'evil-mc-make-and-goto-prev-cursor
       :nv "P" #'evil-mc-make-and-goto-first-cursor
       :nv "q" #'evil-mc-undo-all-cursors
       :nv "t" #'+multiple-cursors/evil-mc-toggle-cursors
       :nv "u" #'+multiple-cursors/evil-mc-undo-cursor
       :nv "z" #'+multiple-cursors/evil-mc-toggle-cursor-here
       :v  "I" #'evil-mc-make-cursor-in-visual-selection-beg
       :v  "A" #'evil-mc-make-cursor-in-visual-selection-end)

      ;; misc
      :n "C-S-f"  #'toggle-frame-fullscreen
      :n "C-+"    #'doom/reset-font-size
      ;; Buffer-local font resizing
      :n "C-="    #'text-scale-increase
      :n "C--"    #'text-scale-decrease
      ;; Frame-local font resizing
      :n "M-C-="  #'doom/increase-font-size
      :n "M-C--"  #'doom/decrease-font-size)


;;
;;; Module keybinds

;;; :completion
(map! (:when (featurep! :completion company)
       :i "C-@"    (cmds! (not (minibufferp)) #'company-complete-common)
       :i "C-SPC"  (cmds! (not (minibufferp)) #'company-complete-common)
       (:after company
        (:map company-active-map
         "C-w"     nil  ; don't interfere with `evil-delete-backward-word'
         "C-n"     #'company-select-next
         "C-p"     #'company-select-previous
         "C-j"     #'company-select-next
         "C-k"     #'company-select-previous
         "C-h"     #'company-show-doc-buffer
         "C-u"     #'company-previous-page
         "C-d"     #'company-next-page
         "C-s"     #'company-filter-candidates
         "C-S-s"   (cond ((featurep! :completion helm) #'helm-company)
                         ((featurep! :completion ivy)  #'counsel-company))
         "C-SPC"   #'company-complete-common
         "TAB"     #'company-complete-common-or-cycle
         [tab]     #'company-complete-common-or-cycle
         [backtab] #'company-select-previous
         [f1]      nil)
        (:map company-search-map  ; applies to `company-filter-map' too
         "C-n"     #'company-select-next-or-abort
         "C-p"     #'company-select-previous-or-abort
         "C-j"     #'company-select-next-or-abort
         "C-k"     #'company-select-previous-or-abort
         "C-s"     #'company-filter-candidates
         [escape]  #'company-search-abort)))

      (:when (featurep! :completion ivy)
       (:after ivy
        :map ivy-minibuffer-map
        "C-SPC" #'ivy-call-and-recenter  ; preview file
        "C-l"   #'ivy-alt-done
        "C-v"   #'yank)
       (:after counsel
        :map counsel-ag-map
        "C-SPC"    #'ivy-call-and-recenter ; preview
        "C-l"      #'ivy-done
        [C-return] #'+ivy/git-grep-other-window-action))

      (:when (featurep! :completion helm)
       (:after helm :map helm-map
        [remap next-line]     #'helm-next-line
        [remap previous-line] #'helm-previous-line
        [left]     #'left-char
        [right]    #'right-char
        "C-S-f"    #'helm-previous-page
        "C-S-n"    #'helm-next-source
        "C-S-p"    #'helm-previous-source
        (:when (featurep! :editor evil +everywhere)
         "C-j"    #'helm-next-line
         "C-k"    #'helm-previous-line
         "C-S-j"  #'helm-next-source
         "C-S-k"  #'helm-previous-source)
        "C-u"      #'helm-delete-minibuffer-contents
        "C-s"      #'helm-minibuffer-history
        ;; Swap TAB and C-z
        "TAB"      #'helm-execute-persistent-action
        [tab]      #'helm-execute-persistent-action
        "C-z"      #'helm-select-action)
       (:after helm-ag :map helm-ag-map
        "C--"      #'+helm-do-ag-decrease-context
        "C-="      #'+helm-do-ag-increase-context
        [left]     nil
        [right]    nil)
       (:after helm-files :map (helm-find-files-map helm-read-file-map)
        [C-return] #'helm-ff-run-switch-other-window
        "C-w"      #'helm-find-files-up-one-level)
       (:after helm-locate :map helm-generic-files-map
        [C-return] #'helm-ff-run-switch-other-window)
       (:after helm-buffers :map helm-buffer-map
        [C-return] #'helm-buffer-switch-other-window)
       (:after helm-occur :map helm-occur-map
        [C-return] #'helm-occur-run-goto-line-ow)
       (:after helm-grep :map helm-grep-map
        [C-return] #'helm-grep-run-other-window-action)))

;;; :ui
(map! (:when (featurep! :ui popup)
       "C-`"   #'+popup/toggle
       "C-~"   #'+popup/raise
       "C-x p" #'+popup/other)

      (:when (featurep! :ui workspaces)
       :n "C-t"   #'+workspace/new
       :n "C-S-t" #'+workspace/display
       :g "M-1"   #'+workspace/switch-to-0
       :g "M-2"   #'+workspace/switch-to-1
       :g "M-3"   #'+workspace/switch-to-2
       :g "M-4"   #'+workspace/switch-to-3
       :g "M-5"   #'+workspace/switch-to-4
       :g "M-6"   #'+workspace/switch-to-5
       :g "M-7"   #'+workspace/switch-to-6
       :g "M-8"   #'+workspace/switch-to-7
       :g "M-9"   #'+workspace/switch-to-8
       :g "M-0"   #'+workspace/switch-to-final
       (:when IS-MAC
        :g "s-t"   #'+workspace/new
        :g "s-T"   #'+workspace/display
        :n "s-1"   #'+workspace/switch-to-0
        :n "s-2"   #'+workspace/switch-to-1
        :n "s-3"   #'+workspace/switch-to-2
        :n "s-4"   #'+workspace/switch-to-3
        :n "s-5"   #'+workspace/switch-to-4
        :n "s-6"   #'+workspace/switch-to-5
        :n "s-7"   #'+workspace/switch-to-6
        :n "s-8"   #'+workspace/switch-to-7
        :n "s-9"   #'+workspace/switch-to-8
        :n "s-0"   #'+workspace/switch-to-final)))

;;; :editor
(map! (:when (featurep! :editor format)
       :n "gQ" #'+format:region)

      (:when (featurep! :editor rotate-text)
       :n "]r"  #'rotate-text
       :n "[r"  #'rotate-text-backward)

      (:when (featurep! :editor multiple-cursors)
       ;; evil-multiedit
       :v  "R"     #'evil-multiedit-match-all
       :n  "M-d"   #'evil-multiedit-match-symbol-and-next
       :n  "M-D"   #'evil-multiedit-match-symbol-and-prev
       :v  "M-d"   #'evil-multiedit-match-and-next
       :v  "M-D"   #'evil-multiedit-match-and-prev
       :nv "C-M-d" #'evil-multiedit-restore
       (:after evil-multiedit
        (:map evil-multiedit-state-map
         "M-d"    #'evil-multiedit-match-and-next
         "M-D"    #'evil-multiedit-match-and-prev
         "RET"    #'evil-multiedit-toggle-or-restrict-region
         [return] #'evil-multiedit-toggle-or-restrict-region)))

      (:when (featurep! :editor snippets)
       ;; auto-yasnippet
       :i  [C-tab] #'aya-expand
       :nv [C-tab] #'aya-create))

;;; :tools
(when (featurep! :tools eval)
  (map! "M-r" #'+eval/buffer))


;;
;;; <leader>

(map! :leader
      :desc "Eval expression"       ";"    #'pp-eval-expression
      :desc "M-x"                   ":"    #'execute-extended-command
      :desc "Pop up scratch buffer" "x"    #'doom/open-scratch-buffer
      :desc "Org Capture"           "X"    #'org-capture
      ;; C-u is used by evil
      :desc "Universal argument"    "u"    #'universal-argument
      :desc "window"                "w"    evil-window-map
      :desc "help"                  "h"    help-map

      (:when (featurep! :ui popup)
       :desc "Toggle last popup"     "~"    #'+popup/toggle)
      :desc "Find file"             "."    #'find-file
      :desc "Switch buffer"         ","    #'switch-to-buffer
      (:when (featurep! :ui workspaces)
       :desc "Switch workspace buffer" "," #'persp-switch-to-buffer
       :desc "Switch buffer"           "<" #'switch-to-buffer)
      :desc "Switch to last buffer" "`"    #'evil-switch-to-windows-last-buffer
      :desc "Resume last search"    "'"
      (cond ((featurep! :completion ivy)   #'ivy-resume)
            ((featurep! :completion helm)  #'helm-resume))

      :desc "Search for symbol in project" "*" #'+default/search-project-for-symbol-at-point
      :desc "Search project"               "/" #'+default/search-project

      :desc "Find file in project"  "SPC"  #'projectile-find-file
      :desc "Jump to bookmark"      "RET"  #'bookmark-jump

      ;;; <leader> TAB --- workspace
      (:when (featurep! :ui workspaces)
       (:prefix-map ("TAB" . "workspace")
        :desc "Display tab bar"           "TAB" #'+workspace/display
        :desc "Switch workspace"          "."   #'+workspace/switch-to
        :desc "Switch to last workspace"  "`"   #'+workspace/other
        :desc "New workspace"             "n"   #'+workspace/new
        :desc "New named workspace"       "N"   #'+workspace/new-named
        :desc "Load workspace from file"  "l"   #'+workspace/load
        :desc "Save workspace to file"    "s"   #'+workspace/save
        :desc "Delete session"            "x"   #'+workspace/kill-session
        :desc "Delete this workspace"     "d"   #'+workspace/delete
        :desc "Rename workspace"          "r"   #'+workspace/rename
        :desc "Restore last session"      "R"   #'+workspace/restore-last-session
        :desc "Next workspace"            "]"   #'+workspace/switch-right
        :desc "Previous workspace"        "["   #'+workspace/switch-left
        :desc "Switch to 1st workspace"   "1"   #'+workspace/switch-to-0
        :desc "Switch to 2nd workspace"   "2"   #'+workspace/switch-to-1
        :desc "Switch to 3rd workspace"   "3"   #'+workspace/switch-to-2
        :desc "Switch to 4th workspace"   "4"   #'+workspace/switch-to-3
        :desc "Switch to 5th workspace"   "5"   #'+workspace/switch-to-4
        :desc "Switch to 6th workspace"   "6"   #'+workspace/switch-to-5
        :desc "Switch to 7th workspace"   "7"   #'+workspace/switch-to-6
        :desc "Switch to 8th workspace"   "8"   #'+workspace/switch-to-7
        :desc "Switch to 9th workspace"   "9"   #'+workspace/switch-to-8
        :desc "Switch to final workspace" "0"   #'+workspace/switch-to-final))

      ;;; <leader> b --- buffer
      (:prefix-map ("b" . "buffer")
       :desc "Toggle narrowing"            "-"   #'doom/toggle-narrow-buffer
       :desc "Previous buffer"             "["   #'previous-buffer
       :desc "Next buffer"                 "]"   #'next-buffer
       (:when (featurep! :ui workspaces)
        :desc "Switch workspace buffer" "b" #'persp-switch-to-buffer
        :desc "Switch buffer"           "B" #'switch-to-buffer)
       (:unless (featurep! :ui workspaces)
        :desc "Switch buffer"           "b" #'switch-to-buffer)
       :desc "Clone buffer"                "c"   #'clone-indirect-buffer
       :desc "Clone buffer other window"   "C"   #'clone-indirect-buffer-other-window
       :desc "Kill buffer"                 "d"   #'kill-current-buffer
       :desc "ibuffer"                     "i"   #'ibuffer
       :desc "Kill buffer"                 "k"   #'kill-current-buffer
       :desc "Kill all buffers"            "K"   #'doom/kill-all-buffers
       :desc "Switch to last buffer"       "l"   #'evil-switch-to-windows-last-buffer
       :desc "Set bookmark"                "m"   #'bookmark-set
       :desc "Delete bookmark"             "M"   #'bookmark-delete
       :desc "Next buffer"                 "n"   #'next-buffer
       :desc "New empty buffer"            "N"   #'evil-buffer-new
       :desc "Kill other buffers"          "O"   #'doom/kill-other-buffers
       :desc "Previous buffer"             "p"   #'previous-buffer
       :desc "Revert buffer"               "r"   #'revert-buffer
       :desc "Save buffer"                 "s"   #'basic-save-buffer
       :desc "Save all buffers"            "S"   #'evil-write-all
       :desc "Save buffer as root"         "u"   #'doom/sudo-save-buffer
       :desc "Pop up scratch buffer"       "x"   #'doom/open-scratch-buffer
       :desc "Switch to scratch buffer"    "X"   #'doom/switch-to-scratch-buffer
       :desc "Bury buffer"                 "z"   #'bury-buffer
       :desc "Kill buried buffers"         "Z"   #'doom/kill-buried-buffers)

      ;;; <leader> c --- code
      (:prefix-map ("c" . "code")
       (:when (and (featurep! :tools lsp) (not (featurep! :tools lsp +eglot)))
        :desc "LSP Execute code action" "a" #'lsp-execute-code-action
        :desc "LSP Organize imports" "o" #'lsp-organize-imports
        (:when (featurep! :completion ivy)
         :desc "Jump to symbol in current workspace" "j"   #'lsp-ivy-workspace-symbol
         :desc "Jump to symbol in any workspace"     "J"   #'lsp-ivy-global-workspace-symbol)
        (:when (featurep! :completion helm)
         :desc "Jump to symbol in current workspace" "j"   #'helm-lsp-workspace-symbol
         :desc "Jump to symbol in any workspace"     "J"   #'helm-lsp-global-workspace-symbol)
        (:when (featurep! :ui treemacs +lsp)
         :desc "Errors list"                         "X"   #'lsp-treemacs-errors-list
         :desc "Incoming call hierarchy"             "y"   #'lsp-treemacs-call-hierarchy
         :desc "Outgoing call hierarchy"             "Y"   (cmd!! #'lsp-treemacs-call-hierarchy t)
         :desc "References tree"                     "R"   (cmd!! #'lsp-treemacs-references t)
         :desc "Symbols"                             "S"   #'lsp-treemacs-symbols)
        :desc "LSP"                                  "l"   #'+default/lsp-command-map
        :desc "LSP Rename"                           "r"   #'lsp-rename)
       (:when (featurep! :tools lsp +eglot)
        :desc "LSP Execute code action" "a" #'eglot-code-actions
        :desc "LSP Rename" "r" #'eglot-rename
        :desc "LSP Find declaration" "j" #'eglot-find-declaration)
       :desc "Compile"                               "c"   #'compile
       :desc "Recompile"                             "C"   #'recompile
       :desc "Jump to definition"                    "d"   #'+lookup/definition
       :desc "Jump to references"                    "D"   #'+lookup/references
       :desc "Evaluate buffer/region"                "e"   #'+eval/buffer-or-region
       :desc "Evaluate & replace region"             "E"   #'+eval:replace-region
       :desc "Format buffer/region"                  "f"   #'+format/region-or-buffer
       :desc "Find implementations"                  "i"   #'+lookup/implementations
       :desc "Jump to documentation"                 "k"   #'+lookup/documentation
       :desc "Send to repl"                          "s"   #'+eval/send-region-to-repl
       :desc "Find type definition"                  "t"   #'+lookup/type-definition
       :desc "Delete trailing whitespace"            "w"   #'delete-trailing-whitespace
       :desc "Delete trailing newlines"              "W"   #'doom/delete-trailing-newlines
       :desc "List errors"                           "x"   #'flymake-show-diagnostics-buffer
       (:when (featurep! :checkers syntax)
        :desc "List errors"                         "x"   #'flycheck-list-errors))

      ;;; <leader> f --- file
      (:prefix-map ("f" . "file")
       :desc "Open project editorconfig"   "c"   #'editorconfig-find-current-editorconfig
       :desc "Copy this file"              "C"   #'doom/copy-this-file
       :desc "Find directory"              "d"   #'+default/dired
       :desc "Delete this file"            "D"   #'doom/delete-this-file
       :desc "Find file in emacs.d"        "e"   #'doom/find-file-in-emacsd
       :desc "Browse emacs.d"              "E"   #'doom/browse-in-emacsd
       :desc "Find file"                   "f"   #'find-file
       :desc "Find file from here"         "F"   #'+default/find-file-under-here
       :desc "Locate file"                 "l"   #'locate
       :desc "Find file in private config" "p"   #'doom/find-file-in-private-config
       :desc "Browse private config"       "P"   #'doom/open-private-config
       :desc "Recent files"                "r"   #'recentf-open-files
       :desc "Rename/move file"            "R"   #'doom/move-this-file
       :desc "Save file"                   "s"   #'save-buffer
       :desc "Save file as..."             "S"   #'write-file
       :desc "Sudo find file"              "u"   #'doom/sudo-find-file
       :desc "Sudo this file"              "U"   #'doom/sudo-this-file
       :desc "Yank file path"              "y"   #'+default/yank-buffer-path
       :desc "Yank file path from project" "Y"   #'+default/yank-buffer-path-relative-to-project)

      ;;; <leader> g --- git/version control
      (:prefix-map ("g" . "git")
       :desc "Revert file"                 "R"   #'vc-revert
       :desc "Copy link to remote"         "y"   #'+vc/browse-at-remote-kill
       :desc "Copy link to homepage"       "Y"   #'+vc/browse-at-remote-kill-homepage
       (:when (featurep! :ui hydra)
        :desc "SMerge"                    "m"   #'+vc/smerge-hydra/body)
       (:when (featurep! :ui vc-gutter)
        (:when (featurep! :ui hydra)
         :desc "VCGutter"                "."   #'+vc/gutter-hydra/body)
        :desc "Revert hunk"               "r"   #'git-gutter:revert-hunk
        :desc "Git stage hunk"            "s"   #'git-gutter:stage-hunk
        :desc "Git time machine"          "t"   #'git-timemachine-toggle
        :desc "Jump to next hunk"         "]"   #'git-gutter:next-hunk
        :desc "Jump to previous hunk"     "["   #'git-gutter:previous-hunk)
       (:when (featurep! :tools magit)
        :desc "Magit dispatch"            "/"   #'magit-dispatch
        :desc "Magit file dispatch"       "."   #'magit-file-dispatch
        :desc "Forge dispatch"            "'"   #'forge-dispatch
        :desc "Magit switch branch"       "b"   #'magit-branch-checkout
        :desc "Magit status"              "g"   #'magit-status
        :desc "Magit status here"         "G"   #'magit-status-here
        :desc "Magit file delete"         "D"   #'magit-file-delete
        :desc "Magit blame"               "B"   #'magit-blame-addition
        :desc "Magit clone"               "C"   #'magit-clone
        :desc "Magit fetch"               "F"   #'magit-fetch
        :desc "Magit buffer log"          "L"   #'magit-log-buffer-file
        :desc "Git stage file"            "S"   #'magit-stage-file
        :desc "Git unstage file"          "U"   #'magit-unstage-file
        (:prefix ("f" . "find")
         :desc "Find file"                 "f"   #'magit-find-file
         :desc "Find gitconfig file"       "g"   #'magit-find-git-config-file
         :desc "Find commit"               "c"   #'magit-show-commit
         :desc "Find issue"                "i"   #'forge-visit-issue
         :desc "Find pull request"         "p"   #'forge-visit-pullreq)
        (:prefix ("o" . "open in browser")
         :desc "Browse file or region"     "o"   #'+vc/browse-at-remote
         :desc "Browse homepage"           "h"   #'+vc/browse-at-remote-homepage
         :desc "Browse remote"             "r"   #'forge-browse-remote
         :desc "Browse commit"             "c"   #'forge-browse-commit
         :desc "Browse an issue"           "i"   #'forge-browse-issue
         :desc "Browse a pull request"     "p"   #'forge-browse-pullreq
         :desc "Browse issues"             "I"   #'forge-browse-issues
         :desc "Browse pull requests"      "P"   #'forge-browse-pullreqs)
        (:prefix ("l" . "list")
         (:when (featurep! :tools gist)
          :desc "List gists"              "g"   #'+gist:list)
         :desc "List repositories"         "r"   #'magit-list-repositories
         :desc "List submodules"           "s"   #'magit-list-submodules
         :desc "List issues"               "i"   #'forge-list-issues
         :desc "List pull requests"        "p"   #'forge-list-pullreqs
         :desc "List notifications"        "n"   #'forge-list-notifications)
        (:prefix ("c" . "create")
         :desc "Initialize repo"           "r"   #'magit-init
         :desc "Clone repo"                "R"   #'magit-clone
         :desc "Commit"                    "c"   #'magit-commit-create
         :desc "Fixup"                     "f"   #'magit-commit-fixup
         :desc "Branch"                    "b"   #'magit-branch-and-checkout
         :desc "Issue"                     "i"   #'forge-create-issue
         :desc "Pull request"              "p"   #'forge-create-pullreq)))

      ;;; <leader> i --- insert
      (:prefix-map ("i" . "insert")
       :desc "Emoji"                         "e"   #'emojify-insert-emoji
       :desc "Current file name"             "f"   #'+default/insert-file-path
       :desc "Current file path"             "F"   (cmd!! #'+default/insert-file-path t)
       :desc "Evil ex path"                  "p"   (cmd! (evil-ex "R!echo "))
       :desc "From evil register"            "r"   #'evil-ex-registers
       :desc "Snippet"                       "s"   #'yas-insert-snippet
       :desc "Unicode"                       "u"   #'insert-char
       :desc "From clipboard"                "y"   #'+default/yank-pop)

      ;;; <leader> n --- notes
      (:prefix-map ("n" . "notes")
       :desc "Search notes for symbol"      "*" #'+default/search-notes-for-symbol-at-point
       :desc "Org agenda"                   "a" #'org-agenda
       (:when (featurep! :tools biblio)
        :desc "Bibliographic entries"        "b"
        (cond ((featurep! :completion ivy)   #'ivy-bibtex)
              ((featurep! :completion helm)  #'helm-bibtex)))

       :desc "Toggle last org-clock"        "c" #'+org/toggle-last-clock
       :desc "Cancel current org-clock"     "C" #'org-clock-cancel
       :desc "Open deft"                    "d" #'deft
       (:when (featurep! :lang org +noter)
        :desc "Org noter"                  "e" #'org-noter)

       :desc "Find file in notes"           "f" #'+default/find-in-notes
       :desc "Browse notes"                 "F" #'+default/browse-notes
       :desc "Org store link"               "l" #'org-store-link
       :desc "Tags search"                  "m" #'org-tags-view
       :desc "Org capture"                  "n" #'org-capture
       :desc "Goto capture"                 "N" #'org-capture-goto-target
       :desc "Active org-clock"             "o" #'org-clock-goto
       :desc "Todo list"                    "t" #'org-todo-list
       :desc "Search notes"                 "s" #'+default/org-notes-search
       :desc "Search org agenda headlines"  "S" #'+default/org-notes-headlines
       :desc "View search"                  "v" #'org-search-view
       :desc "Org export to clipboard"        "y" #'+org/export-to-clipboard
       :desc "Org export to clipboard as RTF" "Y" #'+org/export-to-clipboard-as-rich-text

       (:when (featurep! :lang org +roam)
        (:prefix ("r" . "roam")
         :desc "Switch to buffer"              "b" #'org-roam-switch-to-buffer
         :desc "Org Roam Capture"              "c" #'org-roam-capture
         :desc "Find file"                     "f" #'org-roam-find-file
         :desc "Show graph"                    "g" #'org-roam-graph
         :desc "Insert"                        "i" #'org-roam-insert
         :desc "Insert (skipping org-capture)" "I" #'org-roam-insert-immediate
         :desc "Org Roam"                      "r" #'org-roam
         (:prefix ("d" . "by date")
          :desc "Arbitrary date" "d" #'org-roam-dailies-find-date
          :desc "Today"          "t" #'org-roam-dailies-find-today
          :desc "Tomorrow"       "m" #'org-roam-dailies-find-tomorrow
          :desc "Yesterday"      "y" #'org-roam-dailies-find-yesterday)))

       (:when (featurep! :lang org +journal)
        (:prefix ("j" . "journal")
         :desc "New Entry"           "j" #'org-journal-new-entry
         :desc "New Scheduled Entry" "J" #'org-journal-new-scheduled-entry
         :desc "Search Forever"      "s" #'org-journal-search-forever)))

      ;;; <leader> o --- open
      (:prefix-map ("o" . "open")
       :desc "Org agenda"       "A"  #'org-agenda
       (:prefix ("a" . "org agenda")
        :desc "Agenda"         "a"  #'org-agenda
        :desc "Todo list"      "t"  #'org-todo-list
        :desc "Tags search"    "m"  #'org-tags-view
        :desc "View search"    "v"  #'org-search-view)
       :desc "Default browser"    "b"  #'browse-url-of-file
       :desc "Start debugger"     "d"  #'+debugger/start
       :desc "New frame"          "f"  #'make-frame
       :desc "Select frame"       "F"  #'select-frame-by-name
       :desc "REPL"               "r"  #'+eval/open-repl-other-window
       :desc "REPL (same window)" "R"  #'+eval/open-repl-same-window
       :desc "Dired"              "-"  #'dired-jump
       (:when (featurep! :ui neotree)
        :desc "Project sidebar"              "p" #'+neotree/open
        :desc "Find file in project sidebar" "P" #'+neotree/find-this-file)
       (:when (featurep! :ui treemacs)
        :desc "Project sidebar" "p" #'+treemacs/toggle
        :desc "Find file in project sidebar" "P" #'treemacs-find-file)
       (:when (featurep! :term shell)
        :desc "Toggle shell popup"    "t" #'+shell/toggle
        :desc "Open shell here"       "T" #'+shell/here)
       (:when (featurep! :term term)
        :desc "Toggle terminal popup" "t" #'+term/toggle
        :desc "Open terminal here"    "T" #'+term/here)
       (:when (featurep! :term vterm)
        :desc "Toggle vterm popup"    "t" #'+vterm/toggle
        :desc "Open vterm here"       "T" #'+vterm/here)
       (:when (featurep! :term eshell)
        :desc "Toggle eshell popup"   "e" #'+eshell/toggle
        :desc "Open eshell here"      "E" #'+eshell/here)
       (:when (featurep! :os macos)
        :desc "Reveal in Finder"           "o" #'+macos/reveal-in-finder
        :desc "Reveal project in Finder"   "O" #'+macos/reveal-project-in-finder
        :desc "Send to Transmit"           "u" #'+macos/send-to-transmit
        :desc "Send project to Transmit"   "U" #'+macos/send-project-to-transmit
        :desc "Send to Launchbar"          "l" #'+macos/send-to-launchbar
        :desc "Send project to Launchbar"  "L" #'+macos/send-project-to-launchbar
        :desc "Open in iTerm"              "i" #'+macos/open-in-iterm)
       (:when (featurep! :tools docker)
        :desc "Docker" "D" #'docker)
       (:when (featurep! :email mu4e)
        :desc "mu4e" "m" #'=mu4e)
       (:when (featurep! :email notmuch)
        :desc "notmuch" "m" #'=notmuch)
       (:when (featurep! :email wanderlust)
        :desc "wanderlust" "m" #'=wanderlust))

      ;;; <leader> p --- project
      (:prefix-map ("p" . "project")
       :desc "Browse project"               "." #'+default/browse-project
       :desc "Browse other project"         ">" #'doom/browse-in-other-project
       :desc "Run cmd in project root"      "!" #'projectile-run-shell-command-in-root
       :desc "Add new project"              "a" #'projectile-add-known-project
       :desc "Switch to project buffer"     "b" #'projectile-switch-to-buffer
       :desc "Compile in project"           "c" #'projectile-compile-project
       :desc "Repeat last command"          "C" #'projectile-repeat-last-command
       :desc "Remove known project"         "d" #'projectile-remove-known-project
       :desc "Discover projects in folder"  "D" #'+default/discover-projects
       :desc "Edit project .dir-locals"     "e" #'projectile-edit-dir-locals
       :desc "Find file in project"         "f" #'projectile-find-file
       :desc "Find file in other project"   "F" #'doom/find-file-in-other-project
       :desc "Configure project"            "g" #'projectile-configure-project
       :desc "Invalidate project cache"     "i" #'projectile-invalidate-cache
       :desc "Kill project buffers"         "k" #'projectile-kill-buffers
       :desc "Find other file"              "o" #'projectile-find-other-file
       :desc "Switch project"               "p" #'projectile-switch-project
       :desc "Find recent project files"    "r" #'projectile-recentf
       :desc "Run project"                  "R" #'projectile-run-project
       :desc "Save project files"           "s" #'projectile-save-project-buffers
       :desc "List project todos"           "t" #'magit-todos-list
       :desc "Test project"                 "T" #'projectile-test-project
       :desc "Pop up scratch buffer"        "x" #'doom/open-project-scratch-buffer
       :desc "Switch to scratch buffer"     "X" #'doom/switch-to-project-scratch-buffer
       (:when (and (featurep! :tools taskrunner)
                   (or (featurep! :completion ivy)
                       (featurep! :completion helm)))
        :desc "List project tasks"          "z" #'+taskrunner/project-tasks))

      ;;; <leader> q --- quit/session
      (:prefix-map ("q" . "quit/session")
       :desc "Restart emacs server"         "d" #'+default/restart-server
       :desc "Delete frame"                 "f" #'delete-frame
       :desc "Clear current frame"          "F" #'doom/kill-all-buffers
       :desc "Kill Emacs (and daemon)"      "K" #'save-buffers-kill-emacs
       :desc "Quit Emacs"                   "q" #'save-buffers-kill-terminal
       :desc "Quit Emacs without saving"    "Q" #'evil-quit-all-with-error-code
       :desc "Quick save current session"   "s" #'doom/quicksave-session
       :desc "Restore last session"         "l" #'doom/quickload-session
       :desc "Save session to file"         "S" #'doom/save-session
       :desc "Restore session from file"    "L" #'doom/load-session
       :desc "Restart & restore Emacs"      "r" #'doom/restart-and-restore
       :desc "Restart Emacs"                "R" #'doom/restart)

      ;;; <leader> r --- remote
      (:when (featurep! :tools upload)
       (:prefix-map ("r" . "remote")
        :desc "Browse remote"              "b" #'ssh-deploy-browse-remote-base-handler
        :desc "Browse relative"            "B" #'ssh-deploy-browse-remote-handler
        :desc "Download remote"            "d" #'ssh-deploy-download-handler
        :desc "Delete local & remote"      "D" #'ssh-deploy-delete-handler
        :desc "Eshell base terminal"       "e" #'ssh-deploy-remote-terminal-eshell-base-handler
        :desc "Eshell relative terminal"   "E" #'ssh-deploy-remote-terminal-eshell-handler
        :desc "Move/rename local & remote" "m" #'ssh-deploy-rename-handler
        :desc "Open this file on remote"   "o" #'ssh-deploy-open-remote-file-handler
        :desc "Run deploy script"          "s" #'ssh-deploy-run-deploy-script-handler
        :desc "Upload local"               "u" #'ssh-deploy-upload-handler
        :desc "Upload local (force)"       "U" #'ssh-deploy-upload-handler-forced
        :desc "Diff local & remote"        "x" #'ssh-deploy-diff-handler
        :desc "Browse remote files"        "." #'ssh-deploy-browse-remote-handler
        :desc "Detect remote changes"      ">" #'ssh-deploy-remote-changes-handler))

      ;;; <leader> s --- search
      (:prefix-map ("s" . "search")
       :desc "Search buffer"                "b" #'swiper
       :desc "Search all open buffers"      "B" #'swiper-all
       :desc "Search current directory"     "d" #'+default/search-cwd
       :desc "Search other directory"       "D" #'+default/search-other-cwd
       :desc "Locate file"                  "f" #'locate
       :desc "Jump to symbol"               "i" #'imenu
       :desc "Jump to visible link"         "l" #'link-hint-open-link
       :desc "Jump to link"                 "L" #'ffap-menu
       :desc "Jump list"                    "j" #'evil-show-jumps
       :desc "Jump to bookmark"             "m" #'bookmark-jump
       :desc "Look up online"               "o" #'+lookup/online
       :desc "Look up online (w/ prompt)"   "O" #'+lookup/online-select
       :desc "Look up in local docsets"     "k" #'+lookup/in-docsets
       :desc "Look up in all docsets"       "K" #'+lookup/in-all-docsets
       :desc "Search project"               "p" #'+default/search-project
       :desc "Search other project"         "P" #'+default/search-other-project
       :desc "Jump to mark"                 "r" #'evil-show-marks
       :desc "Search buffer"                "s" #'+default/search-buffer
       :desc "Search buffer for thing at point" "S" #'swiper-isearch-thing-at-point
       :desc "Dictionary"                   "t" #'+lookup/dictionary-definition
       :desc "Thesaurus"                    "T" #'+lookup/synonyms)

      ;;; <leader> t --- toggle
      (:prefix-map ("t" . "toggle")
       :desc "Big mode"                     "b" #'doom-big-font-mode
       :desc "Fill Column Indicator"        "c" #'global-display-fill-column-indicator-mode
       :desc "Flymake"                      "f" #'flymake-mode
       (:when (featurep! :checkers syntax)
        :desc "Flycheck"                   "f" #'flycheck-mode)
       :desc "Frame fullscreen"             "F" #'toggle-frame-fullscreen
       :desc "Evil goggles"                 "g" #'evil-goggles-mode
       (:when (featurep! :ui indent-guides)
        :desc "Indent guides"              "i" #'highlight-indent-guides-mode)
       :desc "Indent style"                 "I" #'doom/toggle-indent-style
       :desc "Line numbers"                 "l" #'doom/toggle-line-numbers
       (:when (featurep! :ui minimap)
        :desc "Minimap"                      "m" #'minimap-mode)
       (:when (featurep! :lang org +present)
        :desc "org-tree-slide mode"        "p" #'org-tree-slide-mode)
       :desc "Read-only mode"               "r" #'read-only-mode
       (:when (and (featurep! :checkers spell) (not (featurep! :checkers spell +flyspell)))
        :desc "Spell checker"              "s" #'spell-fu-mode)
       (:when (featurep! :checkers spell +flyspell)
        :desc "Spell checker"              "s" #'flyspell-mode)
       (:when (featurep! :lang org +pomodoro)
        :desc "Pomodoro timer"             "t" #'org-pomodoro)
       :desc "Soft line wrapping"           "w" #'visual-line-mode
       (:when (featurep! :editor word-wrap)
        :desc "Soft line wrapping"         "w" #'+word-wrap-mode)
       (:when (featurep! :ui zen)
        :desc "Zen mode"                   "z" #'+zen/toggle
        :desc "Zen mode (fullscreen)"      "Z" #'+zen/toggle-fullscreen)))

(after! which-key
  (let ((prefix-re (regexp-opt (list doom-leader-key doom-leader-alt-key))))
    (cl-pushnew `((,(format "\\`\\(?:C-w\\|%s w\\) m\\'" prefix-re))
                  nil . "maximize")
                which-key-replacement-alist)))
