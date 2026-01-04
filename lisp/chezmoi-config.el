;;; chezmoi-config.el --- Chezmoi dotfiles manager integration -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for chezmoi dotfiles manager with evil mode integration.
;; Mac-only - not needed on Android.

;;; Code:

(use-package! chezmoi
  :defer t
  :config
  (require 'chezmoi-cape)
  (require 'chezmoi-magit)
  (require 'chezmoi-dired)
  (add-to-list 'completion-at-point-functions #'chezmoi-capf)

  (defun chezmoi--evil-insert-state-enter ()
    "Run after evil-insert-state-entry."
    (chezmoi-template-buffer-display nil (point))
    (remove-hook 'after-change-functions #'chezmoi-template--after-change 1))

  (defun chezmoi--evil-insert-state-exit ()
    "Run after evil-insert-state-exit."
    (chezmoi-template-buffer-display nil)
    (chezmoi-template-buffer-display t)
    (add-hook 'after-change-functions #'chezmoi-template--after-change nil 1))

  (defun chezmoi-evil ()
    (if chezmoi-mode
        (progn
          (add-hook 'evil-insert-state-entry-hook #'chezmoi--evil-insert-state-enter nil 1)
          (add-hook 'evil-insert-state-exit-hook #'chezmoi--evil-insert-state-exit nil 1))
      (progn
        (remove-hook 'evil-insert-state-entry-hook #'chezmoi--evil-insert-state-enter 1)
        (remove-hook 'evil-insert-state-exit-hook #'chezmoi--evil-insert-state-exit 1))))

  (add-hook 'chezmoi-mode-hook #'chezmoi-evil))

(provide 'chezmoi-config)
;;; chezmoi-config.el ends here
