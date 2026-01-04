;;; jupyter-config.el --- Jupyter/EIN notebook configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for Jupyter notebooks in Emacs using EIN.
;; Mac-only - not needed on Android.

;;; Code:

;; ============================================================
;; EIN (Emacs IPython Notebook)
;; ============================================================

(after! ein-notebook
  (defun +ein-buffer-p (buf)
    (or (memq buf (ein:notebook-opened-buffers))
        (memq buf (mapcar #'ein:notebooklist-get-buffer (ein:notebooklist-keys)))))
  (add-to-list 'doom-real-buffer-functions #'+ein-buffer-p nil #'eq)

  (defun spacemacs/ein:worksheet-merge-cell-next ()
    (interactive)
    (ein:worksheet-merge-cell (ein:worksheet--get-ws-or-error) (ein:worksheet-get-current-cell) t t))

  ;; keybindings mirror ipython web interface behavior
  (evil-define-key 'normal ein:markdown-mode-map
    "go" 'ein:worksheet-goto-next-input-km
    "gO" 'ein:worksheet-goto-prev-input-km)

  (evil-define-key 'insert ein:notebook-mode-map
    "<C-return>" 'ein:worksheet-execute-cell-km
    "<C-H-return>" 'ein:worksheet-execute-cell-and-goto-next-km)

  ;; ein show images inline
  (setq ein:output-area-inlined-images t)

  (map! :map ein:notebook-mode-map
        "C-s-<return>" 'ein:worksheet-execute-cell-and-goto-next-km
        "C-s-<tab>" 'ein:worksheet-execute-cell-km
        "C-s-o" 'ein:worksheet-insert-cell-below-km
        "C-s-O" 'ein:worksheet-insert-cell-above-km
        "C-s-c" 'ein:worksheet-change-cell-type-km
        "C-s-b" 'ein:worksheet-split-cell-at-point-km
        "C-s-k" 'ein:worksheet-move-cell-up-km
        "C-s-j" 'ein:worksheet-move-cell-down-km
        "C-s-y" 'ein:worksheet-copy-cell-km
        "C-s-t" 'ein:worksheet-toggle-output-km
        "C-s-p" 'ein:worksheet-yank-cell-km
        "C-s-d" 'ein:worksheet-kill-cell-km
        "C-s-m" 'ein:notebook-scratchsheet-open-km
        "C-s-z" 'ein:worksheet-toggle-output-km
        "C-s-x" 'ein:worksheet-clear-output-km
        "C-s-;" 'ein:worksheet-clear-all-output-km
        "C-s-s" 'ein:notebook-save-notebook-command-km
        "C-s-r" 'ein:notebook-rename-command-km
        "C-s-q" 'ein:notebook-close-km
        :map ein:notebooklist-mode-map
        :nv "O" 'ein:notebook-open-km
        :nv "o" 'ace-link-custom)

  (map! :localleader
        :map ein:notebook-mode-map
        :desc "Change cell type" :n "c" #'ein:worksheet-change-cell-type-km
        :desc "Execute and step" :n "RET" #'ein:worksheet-execute-cell-and-goto-next
        :desc "Yank cell" :n "y" #'ein:worksheet-copy-cell
        :desc "Paste cell" :n "p" #'ein:worksheet-yank-cell
        :desc "Delete cell" :n "d" #'ein:worksheet-kill-cell
        :desc "Insert cell below" :n "o" #'ein:worksheet-insert-cell-below
        :desc "Insert cell above" :n "O" #'ein:worksheet-insert-cell-above
        :desc "Next cell" :n "j" #'ein:worksheet-goto-next-input
        :desc "Previous cell" :n "k" #'ein:worksheet-goto-prev-input
        :desc "Save notebook" :n "fs" #'ein:notebook-save-notebook-command))

(defun my-preview-latex ()
  "Preview LaTeX from the current cell in a separate buffer."
  (interactive)
  (let* ((cell (ein:worksheet-get-current-cell))
         (text-to-render
          (cond ((ein:markdowncell-p cell) (slot-value cell :input))
                ((ein:codecell-p cell)
                 (plist-get (car (cl-remove-if-not
                                  (lambda (e) (string= (plist-get e :name) "stdout"))
                                  (slot-value cell :outputs)))
                            :text))
                (t (error "Unsupported cell type"))))
         (buffer (get-buffer-create " *ein: LaTeX preview*")))
    (with-current-buffer buffer
      (when buffer-read-only
        (toggle-read-only))
      (unless (= (point-min) (point-max))
        (delete-region (point-min) (point-max)))
      (insert text-to-render)
      (goto-char (point-min))
      (org-mode)
      (org-toggle-latex-fragment 16)
      (special-mode)
      (unless buffer-read-only
        (toggle-read-only))
      (display-buffer
       buffer
       '((display-buffer-below-selected display-buffer-at-bottom)
         (inhibit-same-window . t)))
      (fit-window-to-buffer (window-in-direction 'below)))))

;; ============================================================
;; JUPYTER ORG-MODE INTEGRATION
;; ============================================================

(after! org
  ;; Jupyter org-babel keybindings
  (map! :map org-mode-map
        "<H-return>" 'jupyter-org-execute-and-next-block
        "H-e" 'jupyter-org-execute-to-point
        "H-E" 'jupyter-org-execute-subtree
        "H-K" 'jupyter-org-move-src-block
        "H-J" (lambda () (interactive) (jupyter-org-move-src-block t))
        "H-O" 'jupyter-org-insert-src-block
        "H-o" (lambda () (interactive) (jupyter-org-insert-src-block t))
        "H-B" 'jupyter-org-split-src-block
        "H-b" (lambda () (interactive) (jupyter-org-split-src-block t))
        "C-H-k" 'jupyter-org-merge-blocks
        "H-p" 'jupyter-org-jump-to-block
        "H-P" 'jupyter-org-jump-to-visible-block
        "H-y" 'jupyter-org-kill-block-and-results
        "H-Y" 'jupyter-org-copy-block-and-results
        "C-H-l" 'jupyter-org-clear-all-results
        "H-n" 'jupyter-org-next-busy-src-block
        "H-N" 'jupyter-org-previous-busy-src-block))

;; ============================================================
;; JUPYTER POPUP RULES
;; ============================================================

(set-popup-rule! "*jupyter-pager*" :side 'right :size .40 :select t :vslot 2 :ttl 3)
(set-popup-rule! "*jupyter-repl*" :side 'bottom :size .30 :vslot 2 :ttl 3)

(after! jupyter
  (set-eval-handler! 'jupyter-repl-interaction-mode #'jupyter-eval-line-or-region))

;; on scratch buffer first run jupyter-associate-buffer
(after! python
  (set-repl-handler! 'python-mode #'jupyter-repl-pop-to-buffer))

(provide 'jupyter-config)
;;; jupyter-config.el ends here
