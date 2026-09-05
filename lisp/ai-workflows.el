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

(use-package! claude-code
  :config
  ;; Use ghostel (libghostty-powered terminal emulator):
  (if IS-MAC
      (setq claude-code-terminal-backend 'ghostel))
  (if IS-LINUX
      (setq claude-code-terminal-backend 'ghostel))
  )

;; --------------------------------------------------------------
;; TEMP FIX -- remove once stevemolitor/claude-code.el#142 lands.
;; ghostel >= 0.22 replaced `ghostel--copy-mode-active' with
;; `ghostel--input-mode' and `ghostel-copy-mode-exit' with
;; `ghostel-readonly-exit'.  claude-code.el's three ghostel
;; read-only methods still reference the old names, so its resize
;; advice errored on every window-size change:
;;   Error adjusting window size: (void-variable ghostel--copy-mode-active)
;; and the swallowed error kept SIGWINCH from reaching the PTY
;; (TUI stuck at the 80-column default).  Redefining the methods
;; here (same specializers) replaces the package's copies without
;; touching the package, so Doom updates can't wipe the fix.
;; --------------------------------------------------------------
(defun my/claude-ghostel-in-copy-mode-p ()
  "Non-nil when the current ghostel buffer is in copy/Emacs (read-only) mode.
Handles both ghostel >= 0.22 (`ghostel--input-mode') and older
releases (`ghostel--copy-mode-active')."
  (if (boundp 'ghostel--input-mode)
      (memq ghostel--input-mode '(copy emacs))
    (bound-and-true-p ghostel--copy-mode-active)))

(cl-defmethod claude-code--term-in-read-only-p ((_backend (eql ghostel)))
  "Check if ghostel terminal is in read-only mode."
  (my/claude-ghostel-in-copy-mode-p))

(cl-defmethod claude-code--term-read-only-mode ((_backend (eql ghostel)))
  "Switch ghostel terminal to read-only mode."
  (claude-code--ensure-ghostel)
  (unless (my/claude-ghostel-in-copy-mode-p)
    (ghostel-copy-mode)))

(cl-defmethod claude-code--term-interactive-mode ((_backend (eql ghostel)))
  "Switch ghostel terminal back to interactive mode."
  (claude-code--ensure-ghostel)
  (when (my/claude-ghostel-in-copy-mode-p)
    (if (fboundp 'ghostel-readonly-exit)
        (ghostel-readonly-exit)
      (ghostel-copy-mode-exit))
    ;; Exiting copy mode restores the saved keymap; re-apply ours.
    (claude-code--term-setup-keymap 'ghostel)))

;; Ported from claude-code-ide.el (a9485f7): ghostel manages resizing
;; natively, so the vterm/eat "signal only on width change" reflow
;; workaround stays OFF for it.  Suppressing height-only SIGWINCHes
;; also recreates the window-height != PTY-rows mismatch behind the
;; phone scroll bugs, and its advice was the code path that hit the
;; void-variable error on every resize.
(when (eq claude-code-terminal-backend 'ghostel)
  (setq claude-code-optimize-window-resize nil))

;; Ported from claude-code-ide.el (cc50839): route insert-state ESC to
;; evil (not the terminal) in Claude ghostel buffers, so keys can't get
;; locked in when Claude enters the alternate screen.  Belt-and-braces
;; with the CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN env var below; C-g
;; still sends a real ESC to Claude (claude-code binds it to
;; `claude-code--ghostel-send-escape').
(add-hook 'claude-code-start-hook
          (defun my/claude-ghostel-esc-to-evil ()
            (when (and (eq claude-code-terminal-backend 'ghostel)
                       (bound-and-true-p evil-ghostel-mode)
                       (boundp 'evil-ghostel--escape-mode))
              (setq-local evil-ghostel--escape-mode 'evil))))

;; Ported from claude-code-ide.el's `sync-terminal-dimensions': manual
;; escape hatch when the TUI is stuck at the wrong size (e.g. 80 cols
;; after a missed SIGWINCH).
(defun my/claude-ghostel-resync-size ()
  "Force the Claude ghostel PTY size to match its window."
  (interactive)
  (let* ((buf (if (derived-mode-p 'ghostel-mode)
                  (current-buffer)
                (cl-find-if (lambda (b)
                              (and (string-prefix-p "*claude" (buffer-name b))
                                   (eq (buffer-local-value 'major-mode b)
                                       'ghostel-mode)))
                            (buffer-list))))
         (win (and buf (get-buffer-window buf t)))
         (proc (and buf (get-buffer-process buf))))
    (unless (and win proc)
      (user-error "No visible Claude ghostel buffer with a live process"))
    (with-current-buffer buf
      (ghostel--window-adjust-process-window-size proc (list win)))
    (message "Resynced %s to %dx%d" (buffer-name buf)
             (window-body-width win) (window-body-height win))))

;; Keep Claude's TUI compatible with the claude-workspace grid.  Claude
;; Code >=2.1.x ships two things that break it in a ghostel buffer:
;;   1. A fullscreen pager that runs on the terminal alternate screen
;;      (DECSET 1049).  Under alt-screen, evil-ghostel's `auto' ESC routing
;;      sends ESC to the terminal, so you can't reach evil normal state
;;      ("keys locked in"), and Claude's virtual scroll replaces the
;;      Emacs/evil scrollback the grid relies on.
;;   2. The agent view (`<- for agents', left arrow): pressing left opens a
;;      fullscreen agents browser that re-enters alt-screen and re-locks the
;;      keys -- present even with `/tui default', so disabling the alt screen
;;      alone is not enough.
;; Both are turned off via env vars (verified real in the 2.1.x binary).
;; Scoped to this hook, so `claude' in a plain terminal keeps both if you
;; want them there.
(add-hook 'claude-code-process-environment-functions
          (lambda (&rest _)
            (list "CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1"
                  "CLAUDE_CODE_DISABLE_AGENT_VIEW=1")))

(use-package claude-code-ide
  :config
  ;; (if IS-ANDROID
  ;;     (setq claude-code-ide-use-side-window nil))
  (setq claude-code-ide-use-side-window nil)
  (claude-code-ide-emacs-tools-setup)
  (define-key prog-mode-map (kbd "s-TAB") #'claude-code-ide-menu)
  (setq claude-code-ide-use-ide-diff nil))

(map! :leader
      (:prefix ("l" . "llm")
       :desc "Cycle Claude sessions" "c" #'my/claude-cycle-sessions))

;; ============================================================
;; CYCLE CLAUDE BUFFERS ACROSS WORKSPACES
;; ============================================================

(defvar my/claude-cycle--last-buffer nil
  "Last Claude buffer visited by `my/claude-cycle-sessions'.")

(defun my/claude--session-buffers ()
  "Return all live Claude session buffers across all workspaces."
  (seq-filter
   (lambda (buf)
     (let ((name (buffer-name buf)))
       (or (string-prefix-p "*claude:" name)
           (string-prefix-p "*claude-code[" name))))
   (buffer-list)))

(defun my/claude--workspace-for-buffer (buf)
  "Find the workspace name that contains BUF, or nil."
  (cl-loop for name in (+workspace-list-names)
           when (memq buf (persp-buffers (persp-get-by-name name)))
           return name))

(defun my/claude-cycle-sessions ()
  "Cycle through Claude Code sessions across workspaces.
Switches to the workspace containing the next buffer and displays it
without stealing focus from the current window layout."
  (interactive)
  (let ((bufs (my/claude--session-buffers)))
    (unless bufs
      (user-error "No Claude sessions found"))
    (let* ((sorted (sort bufs (lambda (a b) (string< (buffer-name a) (buffer-name b)))))
           (current (cl-position my/claude-cycle--last-buffer sorted))
           (next-idx (if current (mod (1+ current) (length sorted)) 0))
           (next-buf (nth next-idx sorted))
           (ws (my/claude--workspace-for-buffer next-buf)))
      (when ws
        (+workspace/switch-to ws))
      (display-buffer next-buf '(display-buffer-use-some-window))
      (setq my/claude-cycle--last-buffer next-buf)
      (message "Claude: %s [%s]" (buffer-name next-buf) (or ws "none")))))

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
  ;; (use-package ai-code
  ;;   :config
  ;;   (ai-code-set-backend  'claude-code-ide)
  ;;   (global-auto-revert-mode 1)
  ;;   (setq auto-revert-interval 1)
  ;;   (with-eval-after-load 'magit
  ;;     (ai-code-magit-setup-transients)))

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
