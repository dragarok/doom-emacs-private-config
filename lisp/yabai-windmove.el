;;; yabai-windmove.el --- Seamless window management between Emacs and yabai -*- lexical-binding: t; -*-

;;; Commentary:
;; Raptor v3: Unified M-hjkl for Emacs windows AND yabai windows
;; Try Emacs windmove first, fall back to yabai

;;; Code:

;;; Window Focus (M-hjkl)
;; Try Emacs windmove first, fall back to yabai

(defun yabai-move-on-error (direction move-fn)
  "Try MOVE-FN for Emacs windows, fall back to yabai DIRECTION on error."
  (condition-case nil
      (funcall move-fn)
    (error
     (let ((cmd (pcase direction
                  ("west"  "window --focus west || yabai -m window --focus stack.prev || yabai -m window --focus stack.next")
                  ("east"  "window --focus east || yabai -m window --focus stack.next || yabai -m window --focus stack.prev")
                  ("north" "window --focus north || yabai -m window --focus stack.next || yabai -m window --focus stack.prev")
                  ("south" "window --focus south || yabai -m window --focus stack.prev || yabai -m window --focus stack.next"))))
       (call-process-shell-command (concat "yabai -m " cmd) nil 0)))))

(defun yabai-window-left ()
  (interactive)
  (yabai-move-on-error "west" #'windmove-left))

(defun yabai-window-right ()
  (interactive)
  (yabai-move-on-error "east" #'windmove-right))

(defun yabai-window-up ()
  (interactive)
  (yabai-move-on-error "north" #'windmove-up))

(defun yabai-window-down ()
  (interactive)
  (yabai-move-on-error "south" #'windmove-down))

;;; Window Swap/Move (M-S-hjkl)
;; Try evil-window-move, fall back to yabai warp

(defun yabai-swap-on-error (direction move-fn)
  "Try MOVE-FN to swap Emacs windows, fall back to yabai warp."
  (if (one-window-p)
      ;; Only one Emacs window, use yabai
      (call-process-shell-command
       (concat "yabai -m window --warp " direction) nil 0)
    ;; Multiple Emacs windows, use evil-window-move
    (funcall move-fn)))

(defun yabai-swap-left ()
  (interactive)
  (yabai-swap-on-error "west" #'evil-window-move-far-left))

(defun yabai-swap-right ()
  (interactive)
  (yabai-swap-on-error "east" #'evil-window-move-far-right))

(defun yabai-swap-up ()
  (interactive)
  (yabai-swap-on-error "north" #'evil-window-move-very-top))

(defun yabai-swap-down ()
  (interactive)
  (yabai-swap-on-error "south" #'evil-window-move-very-bottom))

;;; Toggle Split (M-;)
;; Emacs: cycle window split, yabai: toggle split

(defun yabai-toggle-split ()
  "Toggle window split in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m window --toggle split" nil 0)
    (window-split-toggle)))

;;; Rotate Layout (M-S-i)
;; Emacs: rotate windows, yabai: rotate space

(defun yabai-rotate ()
  "Rotate windows in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m space --rotate 270" nil 0)
    (evil-window-rotate-upwards)))

;;; Zoom Fullscreen (M-f)
;; Emacs: maximize buffer, yabai: zoom-fullscreen

(defun yabai-zoom-fullscreen ()
  "Maximize buffer in Emacs or toggle yabai zoom-fullscreen."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m window --toggle zoom-fullscreen" nil 0)
    (doom/window-maximize-buffer)))

;;; Balance Windows (M-=)
;; Emacs: balance-windows, yabai: space --balance

(defun yabai-balance ()
  "Balance windows in Emacs or yabai."
  (interactive)
  (if (one-window-p)
      (call-process-shell-command "yabai -m space --balance" nil 0)
    (balance-windows)))

;;; Keybindings (Doom Emacs)

(map! :invm "M-h" #'yabai-window-left
      :invm "M-l" #'yabai-window-right
      :invm "M-k" #'yabai-window-up
      :invm "M-j" #'yabai-window-down

      :invm "M-H" #'yabai-swap-left
      :invm "M-L" #'yabai-swap-right
      :invm "M-K" #'yabai-swap-up
      :invm "M-J" #'yabai-swap-down

      :invm "M-;" #'yabai-toggle-split    ;; 0x23 = semicolon
      :invm "M-I" #'yabai-rotate          ;; M-S-i
      :invm "M-f" #'yabai-zoom-fullscreen
      :invm "M-=" #'yabai-balance)

(after! org
  (map!
   :after evil-org
   :map evil-org-mode-map
   :invm "M-h" #'yabai-window-left
   :invm "M-l" #'yabai-window-right
   :invm "M-k" #'yabai-window-up
   :invm "M-j" #'yabai-window-down))

(after! org
  (evil-define-key '(normal insert visual motion) 'global
    (kbd "M-h") 'yabai-window-left
    (kbd "M-l") 'yabai-window-right
    (kbd "M-k") 'yabai-window-up
    (kbd "M-j") 'yabai-window-down))

(provide 'yabai-windmove)
;;; yabai-windmove.el ends here
