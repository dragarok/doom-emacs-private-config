;;; ai-workflows.el --- AI/LLM integrations and workflows -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for gptel, Claude Code, MCP hub, and other AI tools.
;; Includes keybindings, notifications, and font fixes for terminal AI tools.

;;; Code:

;; ============================================================
;; GPTEL - Main LLM Interface (Mac-only)
;; ============================================================

(unless IS-ANDROID
  (use-package! gptel
    :config
    (setq gptel-display-buffer-action nil)
    (set-popup-rule!
      (lambda (bname _action)
        (and (null gptel-display-buffer-action)
             (buffer-local-value 'gptel-mode (get-buffer bname))))
      :select t
      :size 0.3
      :quit nil
      :ttl nil)
    ;; (setq! gptel-api-key (auth-source-pick-first-password :user "chatgapi"))
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

  ;; (use-package! mcp-hub
  ;;   :init
  ;;   (setq mcp-hub-servers
  ;;         '(("maitreyamcp" .
  ;;            (:command "/Users/alokregmi/.pyenv/versions/mcpdev/bin/python"
  ;;             :args ("/Users/alokregmi/workspace/personal/maitreyamcp_dev/modules/maitreyamcp_python/python_server.py"))))))

  ;; (use-package! gptel-integrations
  ;;   :after (gptel mcp-hub))

  ;; ghostel for ghostty backend useful for ai workflows
  (use-package ghostel
    :ensure t)
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
  (use-package! claude-code
    :config
    ;; Use ghostel (libghostty-powered terminal emulator):
    (setq claude-code-terminal-backend 'ghostel))

  (use-package! gptel-magit
    :when (modulep! :tools magit)
    :hook (magit-mode . gptel-magit-install))

  (use-package gptel-prompts
    :after (gptel)
    :demand t
    :config
    (setq gptel-prompts-directory "~/.doom.d/llm-system-prompts")
    (gptel-prompts-update)
    (gptel-prompts-add-update-watchers)))

;; ============================================================
;; CLAUDE CODE
;; ============================================================

;; (defun my-claude-notify (title message)
;;   "Display a macOS notification with sound."
;;   (call-process "osascript" nil nil nil
;;                 "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
;;                              message title)))

(use-package claude-code-ide
  :config
  (if IS-ANDROID
      (setq claude-code-ide-use-side-window nil))
  (claude-code-ide-emacs-tools-setup)
  (define-key prog-mode-map (kbd "s-TAB") #'claude-code-ide-menu)
  (setq claude-code-ide-use-ide-diff nil))

;; ============================================================
;; CLAUDE IMAGE ATTACHMENT (local on Android, remote via SSH on Mac)
;; ============================================================

(defvar my/termux-ssh-key (or (getenv "TERMUX_SSH_KEY") "~/.ssh/id_termux")
  "SSH key for connecting to Termux. Set via TERMUX_SSH_KEY env var.")
(defvar my/termux-host (getenv "TERMUX_HOST")
  "Tailscale IP of the phone running Termux. Set via TERMUX_HOST env var.")
(defvar my/termux-user (getenv "TERMUX_USER")
  "Termux SSH user. Set via TERMUX_USER env var.")
(defvar my/termux-ssh-port (or (getenv "TERMUX_SSH_PORT") "8022")
  "Termux SSH port. Set via TERMUX_SSH_PORT env var.")
(defvar my/mac-host (getenv "MAC_HOST")
  "Tailscale IP of the Mac. Set via MAC_HOST env var.")
(defvar my/mac-user (getenv "MAC_USER")
  "Mac SSH user. Set via MAC_USER env var.")

(defvar my/image-screenshot-dirs
  '("/sdcard/Pictures/Screenshots" "/sdcard/DCIM/Screenshots")
  "Directories to search for screenshots on Android.")

(defvar my/image-camera-dirs
  '("/sdcard/DCIM/Camera")
  "Directories to search for camera photos on Android.")

(defun my/claude--find-latest-local-image (dirs)
  "Find the most recent image file in DIRS (Android local)."
  (let* ((globs (mapconcat (lambda (d)
                             (format "%s/*.png %s/*.jpg %s/*.jpeg %s/*.heic" d d d d))
                           (seq-filter #'file-exists-p dirs) " "))
         (cmd (format "ls -t %s 2>/dev/null | grep -v thumbnails | head -1" globs)))
    (let ((result (string-trim (shell-command-to-string cmd))))
      (unless (string-empty-p result) result))))

(defun my/claude--paste-into-buffer (image-path)
  "Paste IMAGE-PATH into the current project's Claude Code vterm buffer.
On Mac, copies image to clipboard and sends Cmd+V.
On Android, types the file path directly."
  (let* ((project (file-name-nondirectory (directory-file-name default-directory)))
         (buffer-name (format "*claude-code[%s]*" project))
         (buf (get-buffer buffer-name)))
    (if buf
        (with-current-buffer buf
          (if IS-ANDROID
              ;; Android: type the path directly
              (vterm-send-string image-path)
            ;; Mac: copy to clipboard and paste
            (call-process "osascript" nil nil nil
                          "-e" (format "set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)" image-path))
            (vterm-send-key "v" nil nil t))
          (message "Attached %s into %s" image-path buffer-name))
      (kill-new image-path)
      (message "Copied %s to kill ring (no buffer: %s)" image-path buffer-name))))

;; --- Local functions (Android) ---

(defun my/claude-attach-local-screenshot ()
  "Attach latest local screenshot to Claude Code (Android)."
  (interactive)
  (let ((img (my/claude--find-latest-local-image my/image-screenshot-dirs)))
    (if img
        (my/claude--paste-into-buffer img)
      (message "No screenshots found"))))

(defun my/claude-attach-local-camera ()
  "Attach latest local camera photo to Claude Code (Android)."
  (interactive)
  (let ((img (my/claude--find-latest-local-image my/image-camera-dirs)))
    (if img
        (my/claude--paste-into-buffer img)
      (message "No photos found"))))

;; --- Remote functions (Mac → phone via SSH) ---

(defun my/claude-attach-remote-image (type)
  "Fetch latest image from phone via SSH/SCP and paste into Claude Code buffer.
TYPE is 'screenshot or 'camera."
  (let* ((ssh-cmd (format "ssh -i %s -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p %s %s@%s"
                          (expand-file-name my/termux-ssh-key)
                          my/termux-ssh-port my/termux-user my/termux-host))
         (remote-path (if (eq type 'screenshot) "/tmp/ss.png" "/tmp/img.jpg"))
         (find-cmd (if (eq type 'screenshot)
                       "ls -t /sdcard/Pictures/Screenshots/*.png /sdcard/Pictures/Screenshots/*.jpg /sdcard/Pictures/Screenshots/*.jpeg 2>/dev/null | head -1"
                     "ls -t /sdcard/DCIM/Camera/*.png /sdcard/DCIM/Camera/*.jpg /sdcard/DCIM/Camera/*.jpeg /sdcard/DCIM/Camera/*.heic 2>/dev/null | grep -v thumbnails | head -1"))
         (scp-cmd (format "%s 'F=$(%s); [ -n \"$F\" ] && scp -i ~/.ssh/mac_tailscale -o ConnectTimeout=5 \"$F\" %s@%s:%s && echo OK || echo FAIL'"
                          ssh-cmd find-cmd (or my/mac-user (getenv "MAC_USER")) (or my/mac-host (getenv "MAC_HOST")) remote-path)))
    (message "Fetching %s from phone..." type)
    (let ((result (string-trim (shell-command-to-string scp-cmd))))
      (if (string-match-p "OK" result)
          (my/claude--paste-into-buffer remote-path)
        (message "Failed to fetch %s from phone: %s" type result)))))

(defun my/claude-attach-remote-screenshot ()
  "Fetch latest screenshot from phone via SSH and paste into Claude Code (Mac)."
  (interactive)
  (my/claude-attach-remote-image 'screenshot))

(defun my/claude-attach-remote-camera ()
  "Fetch latest camera photo from phone via SSH and paste into Claude Code (Mac)."
  (interactive)
  (my/claude-attach-remote-image 'camera))

;; --- Auto-detecting functions (work on both platforms) ---

(defun my/claude-attach-screenshot ()
  "Attach latest screenshot to Claude Code. Auto-detects platform."
  (interactive)
  (if IS-ANDROID
      (my/claude-attach-local-screenshot)
    (my/claude-attach-remote-screenshot)))

(defun my/claude-attach-camera ()
  "Attach latest camera photo to Claude Code. Auto-detects platform."
  (interactive)
  (if IS-ANDROID
      (my/claude-attach-local-camera)
    (my/claude-attach-remote-camera)))

(defun my/claude-attach-image ()
  "Attach screenshot or camera photo to Claude Code. Auto-detects platform."
  (interactive)
  (let ((type (intern (completing-read "Attach: " '("screenshot" "camera") nil t))))
    (if (eq type 'screenshot)
        (my/claude-attach-screenshot)
      (my/claude-attach-camera))))


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
;; (setq claude-code-eat-read-only-mode-cursor-type '(bar nil nil))

;; Control eat scrollback size for longer conversations
(setq eat-term-scrollback-size 500000)

;; (add-hook 'claude-code-start-hook
;;           (lambda ()
;;             (setq-local line-spacing 0.1)))

;; (custom-set-faces
;;  '(claude-code-repl-face ((t (:family "JuliaMono")))))

;; ============================================================
;; MAC-ONLY: AI CODE, GEMINI CLI, EAT
;; ============================================================

(unless IS-ANDROID
  (use-package ai-code
    :config
    (ai-code-set-backend  'claude-code-ide)
    (global-auto-revert-mode 1)
    (setq auto-revert-interval 1)
    (with-eval-after-load 'magit
      (ai-code-magit-setup-transients)))

  (use-package gemini-cli
    :defer t)

  (defun my-gemini-notify (title message)
    "Display a macOS notification with sound."
    (call-process "osascript" nil nil nil
                  "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                               message title)))

  (setq gemini-cli-notification-function #'my-gemini-notify)

  (with-eval-after-load 'eat
    (define-key eat-mode-map (kbd "s-p") #'eat-yank)
    (define-key eat-semi-char-mode-map (kbd "s-p") #'eat-yank)))

(provide 'ai-workflows)
;;; ai-workflows.el ends here
