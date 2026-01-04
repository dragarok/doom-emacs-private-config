;;; ai-workflows.el --- AI/LLM integrations and workflows -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for gptel, Claude Code, MCP hub, and other AI tools.
;; Includes keybindings, notifications, and font fixes for terminal AI tools.

;;; Code:

;; ============================================================
;; GPTEL - Main LLM Interface
;; ============================================================

(use-package! gptel
  :config
  (setq gptel-display-buffer-action nil)  ; if user changes this, popup manager will bow out
  (set-popup-rule!
    (lambda (bname _action)
      (and (null gptel-display-buffer-action)
           (buffer-local-value 'gptel-mode (get-buffer bname))))
    :select t
    :size 0.3
    :quit nil
    :ttl nil)
  (setq! gptel-api-key (auth-source-pick-first-password :user "chatgapi"))
  (gptel-make-ollama
      "Ollama"
    :host "localhost:11434"
    :models '("gemma3:latest")
    :stream t)
  (gptel-make-anthropic "Claude"
    :stream t
    :key (auth-source-pick-first-password :user "anthroapi"))
  (gptel-make-gemini "Gemini"
    :stream t
    :key (auth-source-pick-first-password :user "geminiapi"))
  (gptel-make-gh-copilot "Copilot")

  (map! :leader
        (:prefix ("l" . "llm")
         :desc "Add text to context"        "a" #'gptel-add
         :desc "Explain"                    "e" #'gptel-quick
         :desc "Add file to context"        "f" #'gptel-add-file
         :desc "Open gptel"                 "l" #'gptel
         :desc "Send to gptel"              "s" #'gptel-send
         :desc "Open gptel menu"            "m" #'gptel-menu
         :desc "Rewrite"                    "r" #'gptel-rewrite
         :desc "Org: set topic"             "o" #'gptel-org-set-topic
         :desc "Org: set properties"        "O" #'gptel-org-set-properties)))

;; ============================================================
;; MCP HUB
;; ============================================================

;; (use-package! mcp-hub
;;   :init
;;   (setq mcp-hub-servers
;;         '(("maitreyamcp" .
;;            (:command "/Users/alokregmi/.pyenv/versions/mcpdev/bin/python"
;;             :args ("/Users/alokregmi/workspace/personal/maitreyamcp_dev/modules/maitreyamcp_python/python_server.py"))))))

;; (use-package! gptel-integrations
;;   :after (gptel mcp-hub))

(use-package! gptel-magit
  :when (modulep! :tools magit)
  :hook (magit-mode . gptel-magit-install))

;; ============================================================
;; GPTEL PROMPTS
;; ============================================================

(use-package gptel-prompts
  :after (gptel)
  :demand t
  :config
  (setq gptel-prompts-directory "~/.doom.d/llm-system-prompts")
  (gptel-prompts-update)
  (gptel-prompts-add-update-watchers))

;; ============================================================
;; CLAUDE CODE
;; ============================================================

(defun my-claude-notify (title message)
  "Display a macOS notification with sound."
  (call-process "osascript" nil nil nil
                "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                             message title)))

(use-package! claude-code
  :config
  (setq claude-code-notification-function #'my-claude-notify)
  (setq claude-code-startup-delay 0.2)
  (setq claude-code-terminal-backend 'vterm)
  (add-hook 'claude-code-start-hook
            (lambda ()
              (setq-local line-spacing 0.1))))

(use-package claude-code-ide
  :config
  (claude-code-ide-emacs-tools-setup)
  (define-key prog-mode-map (kbd "s-TAB") #'claude-code-ide-menu)
  (setq claude-code-ide-use-ide-diff nil))

;; ============================================================
;; VTERM/EAT FONT FIXES FOR CLAUDE
;; ============================================================

(defun diego--vterm-font-setup ()
  "Configure font settings specifically for vterm buffers, workaround claude-code."
  (let ((tbl (or buffer-display-table (setq buffer-display-table (make-display-table)))))
    (dolist (pair
             '((#x273B . ?*) ; TEARDROP-SPOKED ASTERISK
               (#x273D . ?*) ; HEAVY TEARDROP-SPOKED ASTERISK
               (#x2722 . ?+) ; FOUR TEARDROP-SPOKED ASTERISK
               (#x2736 . ?+) ; SIX-POINTED BLACK STAR
               (#x2733 . ?*) ; EIGHT SPOKED ASTERISK
               ))
      (aset tbl (car pair) (vector (cdr pair))))))

(add-hook 'vterm-mode-hook #'diego--vterm-font-setup)

(defvar sm-subsitutions
  '((?⏺ . ?\-)
    (?· . ?.)
    (?✢ . ?+)
    (?✳ . ?*)
    (?∗ . ?*)
    (?✻ . ?*)
    (?✽ . ?*)
    (?╭ . ?+)
    (?╮ . ?+)
    (?╰ . ?+)
    (?╯ . ?+)
    (?⎿ . ?|)
    (?│ . ?|)
    (?🤖 . ?*)))

(defun sm-replace-problem-chars (args)
  (let ((terminal (nth 0 args))
        (output (nth 1 args)))
    (dolist (sub sm-subsitutions)
      (setq output (subst-char-in-string (car sub) (cdr sub) output)))
    (list terminal output)))

(advice-add 'eat-term-process-output :filter-args #'sm-replace-problem-chars)

;; Customize cursor type in read-only mode
(setq claude-code-eat-read-only-mode-cursor-type '(bar nil nil))

;; Control eat scrollback size for longer conversations
(setq eat-term-scrollback-size 500000)

(add-hook 'claude-code-start-hook
          (lambda ()
            (setq-local line-spacing 0.1)))

(custom-set-faces
 '(claude-code-repl-face ((t (:family "JuliaMono")))))

;; ============================================================
;; AI CODE INTERFACE
;; ============================================================

(use-package ai-code-interface
  :config
  (ai-code-set-backend 'claude-code-ide)
  (with-eval-after-load 'magit
    (ai-code-magit-setup-transients)))

;; ============================================================
;; GEMINI CLI
;; ============================================================

(use-package gemini-cli
  :defer t)

(defun my-gemini-notify (title message)
  "Display a macOS notification with sound."
  (call-process "osascript" nil nil nil
                "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                             message title)))

(setq gemini-cli-notification-function #'my-gemini-notify)

;; ============================================================
;; CLAUDE ACCOUNT SWITCHING
;; ============================================================

(defun claude-switch-accounts ()
  "Toggle between default claude account and the ~/.claude333 account."
  (interactive)
  (if (string-prefix-p "CLAUDE_CONFIG_DIR=" claude-code-ide-cli-path)
      ;; Currently using the alternate account -> switch to default
      (progn
        (setq claude-code-ide-cli-path "claude")
        (setq claude-code-program        "claude"))
    ;; Currently using default -> switch to alternate
    (progn
      (setq claude-code-ide-cli-path "CLAUDE_CONFIG_DIR=~/.claude333 claude")
      (setq claude-code-program        "CLAUDE_CONFIG_DIR=~/.claude333 claude")))
  (message "Claude CLI now using: %s" claude-code-ide-cli-path))

;; ============================================================
;; EAT KEYBINDINGS
;; ============================================================

(with-eval-after-load 'eat
  (define-key eat-mode-map (kbd "s-p") #'eat-yank)
  (define-key eat-semi-char-mode-map (kbd "s-p") #'eat-yank))

(provide 'ai-workflows)
;;; ai-workflows.el ends here
