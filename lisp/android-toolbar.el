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
      ;; KAIROAM - Window Management
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-kai-1>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-toggle-size>"
        `(menu-item "Toggle Size" kairoam-toggle-size
          :help "Smart toggle: expand if folded, fold if expanded"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/expand-alt-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-balance>"
        `(menu-item "Balance" kairoam-balance
          :help "Balance Kairoam windows"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/balance-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-toggle>"
        `(menu-item "Kairoam Toggle" kairoam-toggle
          :help "Toggle Kairoam mode on/off"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/toggle-on-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<kairoam-open-right>"
        `(menu-item "Open Right" kairoam-open-note-to-right
          :help "Open note to right"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/fold-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; CORE FLOW COMMANDS - The essentials
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-1>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow>"
        `(menu-item "FLOW" rts-flow
          :help "Pick new task (context/energy aware)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/water-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-continue>"
        `(menu-item "Continue" rts-flow-continue
          :help "Continue last task"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/play-button-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-cancel>"
        `(menu-item "Cancel" rts-flow-cancel
          :help "Cancel last selection (undo status, discard clock)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/cancel-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; CLOCK OPERATIONS
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-2>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-manual>"
        `(menu-item "Manual Clock" rts-flow-manual
          :help "Clock into any task via search"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/clock-circle-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-clock-out>"
        `(menu-item "Clock Out" rts-flow-clock-out
          :help "Smart clock out (auto-DONE for habits)"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/done-1477-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-clock-goto>"
        `(menu-item "Goto Task" rts-flow-clock-goto
          :help "Jump to clocked/last interacted task"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/find-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; ADD THINGS
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-3>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-add>"
        `(menu-item "Add" rts-flow-add
          :help "Add task, beancount entry, or clock time"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/add-circle2-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; STATE - Single button for context + energy
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-4>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<rts-flow-set-state>"
        `(menu-item "State" rts-flow-set-state
          :help "Set context AND energy in one go"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/winter-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; NAVIGATION
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-5>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<org-agenda>"
        `(menu-item "Agenda" my-org-agenda
          :help "Open org agenda"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/agenda-book-business-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<org-roam-node-find>"
        `(menu-item "Find Node" org-roam-node-find
          :help "Find org-roam node"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/node-0-connections-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<home>"
        `(menu-item "Home" +doom-dashboard/open
          :help "Go to dashboard"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/bank-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; ORG-ROAM EXTRAS
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-6>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<org-roam-dailies-today>"
        `(menu-item "Dailies Switch" my/org-roam-dailies-cycle-focus
          :help "Cycle: Today -> Prev Monday -> Next Monday"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/sun-weather-sunny-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<org-node-random-large>"
        `(menu-item "Random Large Note" org-roam-open-large-note-randomly
          :help "Open a random large org-roam note"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/random-1dice-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<org-node-random>"
        `(menu-item "Random Note" org-roam-node-random
          :help "Open a random org-roam note"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/shuffle-random-mix-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<org-roam-ui>"
        `(menu-item "Graph UI" org-roam-ui-open
          :help "Open org-roam graph UI"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/graph-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      ;; ===================================================================
      ;; UTILITIES
      ;; ===================================================================

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-7>" menu-bar-separator)
      (keymap-set-after (default-value 'tool-bar-map) "<ibuffer>"
        `(menu-item "Ibuffer" ibuffer
          :help "Buffer list"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/buffer-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<zen-workspace>"
        `(menu-item "Zen" global-writeroom-mode
          :help "Toggle zen/writeroom mode"
          :image (image :type svg :file "~/.doom.d/toolbar-assets/zen-brush-symbol-svgrepo-com.svg"
                        :height ,icon-size :width ,icon-size)))

      (keymap-set-after (default-value 'tool-bar-map) "<separator-flow-8>" menu-bar-separator)
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

      (message "River Flow toolbar configured with %dx%d icons" icon-size icon-size))))

;; Auto-setup when loaded
(with-eval-after-load 'productivity_flow
  (rts-flow-setup-toolbar))

(provide 'android-toolbar)
;;; android-toolbar.el ends here
