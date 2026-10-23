;;; claude-code-setup.el --- Local Claude Code sessions (Mac only) -*- lexical-binding: t; -*-

;;; Commentary:
;; claude-code.el and claude-code-ide.el on ghostel, session cycling, and
;; image attachment fetched from the phone.  Not loaded on Android: the
;; phone drives the Mac's sessions through claude-remote instead.

;;; Code:

;; ============================================================
;; CLAUDE CODE
;; ============================================================


;; Use ghostel (libghostty-powered terminal emulator):
(use-package! claude-code
  :config
  (setq claude-code-terminal-backend 'ghostel))

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
;; natively, so the eat "signal only on width change" reflow
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
  (setq claude-code-ide-terminal-backend 'ghostel)
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
;; CLAUDE IMAGE ATTACHMENT (fetched from the phone over SSH)
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

(defun my/claude--paste-into-buffer (image-path)
  "Paste IMAGE-PATH into the current project's Claude Code ghostel buffer.
Copies the image to the clipboard and sends Ctrl+V."
  (let* ((project (file-name-nondirectory (directory-file-name default-directory)))
         (buffer-name (format "*claude-code[%s]*" project))
         (buf (get-buffer buffer-name)))
    (if buf
        (with-current-buffer buf
          (call-process "osascript" nil nil nil
                        "-e" (format "set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)" image-path))
          (ghostel-send-key "v" "ctrl")
          (message "Attached %s into %s" image-path buffer-name))
      (kill-new image-path)
      (message "Copied %s to kill ring (no buffer: %s)" image-path buffer-name))))

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

(defun my/claude-attach-image ()
  "Attach a screenshot or camera photo from the phone to Claude Code."
  (interactive)
  (my/claude-attach-remote-image
   (intern (completing-read "Attach: " '("screenshot" "camera") nil t))))

(provide 'claude-code-setup)
;;; claude-code-setup.el ends here
