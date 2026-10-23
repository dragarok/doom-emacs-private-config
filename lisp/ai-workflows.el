;;; ai-workflows.el --- AI/LLM integrations and workflows -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for gptel, Claude Code, MCP hub, and other AI tools.
;; Includes keybindings, notifications, and font fixes for terminal AI tools.

;;; Code:

;; ============================================================
;; GPTEL - Main LLM Interface (Mac-only)
;; ============================================================


;; ghostel for ghostty backend useful for ai workflows
(use-package ghostel
  :ensure t
  :config
  ;; 30fps redraws (0.033) across several streaming claude buffers pegs the
  ;; Emacs daemon at ~80% CPU on this 16GB box; 10fps is visually fine for
  ;; bulk TUI output. Keystroke echo stays snappy via the immediate-redraw
  ;; path, capped at 10fps too (keystroke echo worst case ~100ms).
  (setq ghostel-timer-delay 0.1
        ghostel-immediate-redraw-interval 0.1))
(use-package evil-ghostel
  :ensure t
  :after (ghostel evil)
  :hook (ghostel-mode . evil-ghostel-mode)
  :config
  (evil-define-key* 'insert evil-ghostel-mode-map
    (kbd "C-v")
    (defalias 'evil-ghostel--passthrough-ctrl-v
      (lambda ()
        (interactive)
        (evil-ghostel--passthrough-ctrl "v"))
      "Send C-v to the terminal or fall back to evil.")))

;; ============================================================
;; MAC-ONLY: AI CODE
;; ============================================================

(if IS-MAC
    (progn
      (use-package ai-code
        :config
        (ai-code-set-backend  'claude-code-ide)
        (global-auto-revert-mode 1)
        (setq auto-revert-interval 1)
        (with-eval-after-load 'magit
          (ai-code-magit-setup-transients)))

      (with-eval-after-load 'eat
        (define-key eat-mode-map (kbd "s-p") #'eat-yank)
        (define-key eat-semi-char-mode-map (kbd "s-p") #'eat-yank))
      )
  )

(provide 'ai-workflows)
;;; ai-workflows.el ends here
