;;; android-toolbar.el --- Simplified River Flow Toolbar -*- lexical-binding: t -*-

;;; Commentary:
;; Minimal, focused toolbar for the River Flow productivity system.
;; Icon sizes are device-dependent: POCO uses 64x64, ONYX uses 80x80.
;;
;; Core Flow Commands:
;;   rts-flow          - Pick new task (context/energy aware)
;;   rts-flow-continue - Resume last task
;;   rts-flow-cancel   - Undo last selection
;;   rts-flow-manual   - Consult clock-in to any task
;;   rts-flow-clock-out - Smart clock out (auto-DONE for habits)
;;   rts-flow-add      - Add task/beancount/clock time
;;   rts-flow-set-state - Set context AND energy in one go
;;
;; Requires: productivity_flow.el, kairoam.el

;;; Code:

(require 'productivity_flow)
(require 'micro-experiments)

(defun rts-flow-setup-toolbar ()
  "Set up the simplified River Flow toolbar with device-appropriate icon sizes.
POCO devices use 64x64, ONYX e-readers use 80x80."
  (interactive)
  (when (display-graphic-p)
    (setopt tool-bar-style 'image
            tool-bar-position 'bottom)

    ;; Determine icon size based on device
    (let ((icon-size (cond
                      ((bound-and-true-p IS-POCO) 64)
                      ((bound-and-true-p IS-ONYX) 80)
                      (t 64))))

      ;; ===================================================================
      ;; MICRO EXPERIMENT - One tap, one task, go do it
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-micro-1>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<micro-experiments-pick>"
        `(menu-item "Micro" micro-experiments-pick
          :help "Pick a random 5-min task. Just do it."
          :image (image :type svg :file "~/.doom.d/toolbar-assets/lightning-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; (keymap-set-after (default-value 'tool-bar-map) "<micro-experiments-log>"
      ;;   `(menu-item "Log" micro-experiments-log
      ;;     :help "Log what you're working on to daily note"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/blog-blogger-blogging-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; CORE FLOW COMMANDS - The essentials
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-1>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow>"
        `(menu-item "FLOW" rts-flow
          :help "Pick new task (context/energy aware)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/flow-chart-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-continue>"
        `(menu-item "Continue" rts-flow-continue
          :help "Continue last task"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/debug-continue-small-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-cancel>"
        `(menu-item "Cancel" rts-flow-cancel
          :help "Cancel last selection (undo status, discard clock)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/cancel-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; CLOCK OPERATIONS
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-manual>"
        `(menu-item "Manual Clock" rts-flow-manual
          :help "Clock into any task via search"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/time-add-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-2>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-clock-out>"
        `(menu-item "Clock Out" rts-flow-clock-out
          :help "Smart clock out (auto-DONE for habits)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/time-check-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<separator-clock-3>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-clock-goto>"
        `(menu-item "Goto Task" rts-flow-clock-goto
          :help "Jump to clocked/last interacted task"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/time-oclock-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; ADD THINGS
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-3>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-add>"
        `(menu-item "Add" rts-flow-add
          :help "Add task, beancount entry, or clock time"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/add-circle2-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; STATE - Single button for context + energy (moved to homepage)
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-4>" menu-bar-separator)
      ;; (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-set-state>"
      ;;   `(menu-item "State" rts-flow-set-state
      ;;     :help "Set context AND energy in one go"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/winter-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; NAVIGATION (Agenda and Find Node moved to homepage)
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-5>" menu-bar-separator)
      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-agenda>"
      ;;   `(menu-item "Agenda" my-org-agenda
      ;;     :help "Open org agenda"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/agenda-book-business-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-roam-node-find>"
      ;;   `(menu-item "Find Node" org-roam-node-find
      ;;     :help "Find org-roam node"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/node-0-connections-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; ARROW KEYS - Cursor navigation
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-arrows>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<arrow-left>"
        `(menu-item "Left" ,(lambda () (interactive) (execute-kbd-macro (kbd "<left>")))
          :help "Move left"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/left-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<arrow-down>"
        `(menu-item "Down" ,(lambda () (interactive) (execute-kbd-macro (kbd "<down>")))
          :help "Move down"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/down-arrow-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<arrow-up>"
        `(menu-item "Up" ,(lambda () (interactive) (execute-kbd-macro (kbd "<up>")))
          :help "Move up"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/up-arrow-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<arrow-right>"
        `(menu-item "Right" ,(lambda () (interactive) (execute-kbd-macro (kbd "<right>")))
          :help "Move right"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/right-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-8>" menu-bar-separator)

      (keymap-set-after (default-value 'tool-bar-map) "<home>"
        `(menu-item "Home" android-homepage-toggle
          :help "Toggle homepage / last buffer"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/bank-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; ORG-ROAM EXTRAS (moved to homepage)
      ;; ===================================================================

      ;; (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-6>" menu-bar-separator)
      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-roam-dailies-today>"
      ;;   `(menu-item "Dailies Switch" my/org-roam-dailies-cycle-focus
      ;;     :help "Cycle: Today -> Prev Monday -> Next Monday"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/sun-weather-sunny-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-node-random-large>"
      ;;   `(menu-item "Random Large Note" org-roam-open-large-note-randomly
      ;;     :help "Open a random large org-roam note"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/random-1dice-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-node-random>"
      ;;   `(menu-item "Random Note" org-roam-node-random
      ;;     :help "Open a random org-roam note"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/shuffle-random-mix-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; (keymap-set-after (default-value 'tool-bar-map) "<org-roam-ui>"
      ;;   `(menu-item "Graph UI" org-roam-ui-open
      ;;     :help "Open org-roam graph UI"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/graph-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; UTILITIES
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-7>" menu-bar-separator)
      ;; (keymap-set-after (default-value 'tool-bar-map) "<ibuffer>"
      ;;   `(menu-item "Ibuffer" ibuffer
      ;;     :help "Buffer list"
      ;;     :image (image :type svg :file "~/.doom.d/toolbar-assets/buffer-svgrepo-com.svg"
      ;;                   :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<zen-workspace>"
        `(menu-item "Zen" global-writeroom-mode
          :help "Toggle zen/writeroom mode"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/zen-brush-symbol-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; SAVE
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-save>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<save-file>"
        `(menu-item "Save" save-buffer
          :help "Save current file"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/save-floppy-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-9>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<keyboard>"
        `(menu-item "Keyboard" my/toggle-touch-keyboard
          :help "Toggle touch keyboard"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/keyboard-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<evil-quit>"
        `(menu-item "Quit" evil-quit
          :help "Close window/buffer"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/close-circle-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))


      (keymap-set-after (default-value 'tool-bar-map) "<org-attach-media>"
        `(menu-item "Attach Media" my/org-attach-media
          :help "Attach photo or screenshot to current Org node"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/instant-camera-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; MAC EMACS (claude-mac: mosh window into the Mac)
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-claude>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<claude-mac-connect>"
        `(menu-item "Mac" claude-mac
          :help "Connect/jump to the active remote Emacs over mosh (grabs keyboard)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/terminal-alt-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))
      (keymap-set-after (default-value 'tool-bar-map) "<claude-mac-keys>"
        `(menu-item "Keys" claude-mac-toggle
          :help "Toggle keyboard passthrough to the active remote Emacs"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/keyboard-shortcuts-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))


      ;; ===================================================================
      ;; KAIROAM - Window Management (org-mode only)
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-kai-1>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-toggle-size>"
        `(menu-item "Toggle Size" kairoam-toggle-size
          :help "Smart toggle: expand if folded, fold if expanded"
          :visible (derived-mode-p 'org-mode)
          :image (image :type svg :file "~/.doom.d/toolbar-assets/expand-alt-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-balance>"
        `(menu-item "Balance" kairoam-balance
          :help "Balance Kairoam windows"
          :visible (derived-mode-p 'org-mode)
          :image (image :type svg :file "~/.doom.d/toolbar-assets/balance-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-toggle>"
        `(menu-item "Kairoam Toggle" kairoam-toggle
          :help "Toggle Kairoam mode on/off"
          :visible (derived-mode-p 'org-mode)
          :image (image :type svg :file "~/.doom.d/toolbar-assets/toggle-on-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-open-right>"
        `(menu-item "Open Right" kairoam-open-note-to-right
          :help "Open note to right"
          :visible (derived-mode-p 'org-mode)
          :image (image :type svg :file "~/.doom.d/toolbar-assets/fold-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (message "River Flow toolbar configured with %dx%d icons" icon-size icon-size))))

;; Auto-setup when loaded
(with-eval-after-load 'productivity_flow
  (rts-flow-setup-toolbar))

(provide 'android-toolbar)
;;; android-toolbar.el ends here
