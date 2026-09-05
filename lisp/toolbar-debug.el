;;; toolbar-debug.el --- Find the form that breaks the toolbar setup -*- lexical-binding: t -*-

;;; Commentary:
;; Throwaway.  `M-x rts-flow-setup-toolbar' dies with (void-function nil),
;; and a phone is a bad place to read a backtrace, so this runs the SAME
;; setup with every `keymap-set-after' counted and named on the way past.
;; The report then says which button the run got to before it died, which
;; puts the bad form between that button and the next one in
;; `lisp/android-toolbar.el'.
;;
;;   M-x rts-toolbar-debug
;;
;; Read the three outcomes like this:
;;
;;   "FAILED after N buttons"  the broken form is the one right AFTER the
;;                             named button in android-toolbar.el.
;;   "FAILED after 0 buttons"  it never reached the first button, so the
;;                             `setopt' pair at the top is the culprit.
;;   "ran clean"               setup is fine and the error comes from
;;                             REDISPLAY instead -- i.e. one of the
;;                             `:visible' or `:image' forms, which Emacs
;;                             evaluates every time it draws the tool bar,
;;                             not while building it.  Different hunt.
;;
;; Delete this file once the offending form is fixed.

;;; Code:

;; Soft: if android-toolbar itself dies partway through loading, the defun
;; is already in place (it sits above the auto-setup at the file's foot), so
;; there is still something to run -- and a hard `require' here would only
;; re-raise the very error we are trying to name.
(require 'android-toolbar nil t)
(declare-function rts-flow-setup-toolbar "android-toolbar")

(defvar rts-toolbar-debug--step 0
  "How many `keymap-set-after' calls the run has got through.")
(defvar rts-toolbar-debug--key nil
  "Key of the last `keymap-set-after' call that started.")
(defvar rts-toolbar-debug--log nil
  "Reversed list of the buttons set so far, newest first.")

(defun rts-toolbar-debug--record (&rest args)
  "Note that `keymap-set-after' was called with ARGS."
  (setq rts-toolbar-debug--step (1+ rts-toolbar-debug--step)
        rts-toolbar-debug--key (nth 1 args))
  (push (format "%3d  %s" rts-toolbar-debug--step rts-toolbar-debug--key)
        rts-toolbar-debug--log))

;;;###autoload
(defun rts-toolbar-debug ()
  "Run the River Flow toolbar setup and report the first form that fails.
Leaves the findings in a `*toolbar-debug*' buffer, which is readable and
copyable on a phone in a way the debugger's backtrace is not."
  (interactive)
  (unless (fboundp 'rts-flow-setup-toolbar)
    (user-error "rts-flow-setup-toolbar is not defined — android-toolbar never loaded"))
  (setq rts-toolbar-debug--step 0
        rts-toolbar-debug--key nil
        rts-toolbar-debug--log nil)
  (advice-add 'keymap-set-after :before #'rts-toolbar-debug--record)
  (unwind-protect
      (let ((err (condition-case e
                     (progn (rts-flow-setup-toolbar) nil)
                   (error e)))
            (graphic (display-graphic-p)))
        (with-current-buffer (get-buffer-create "*toolbar-debug*")
          (erase-buffer)
          (cond
           ((not graphic)
            (insert "display-graphic-p is nil, so the whole setup body was\n"
                    "skipped and this run proves nothing.  Run it from the\n"
                    "graphical Emacs, not a -nw one.\n\n"))
           (err
            (insert (format "FAILED after %d buttons.\n\n" rts-toolbar-debug--step)
                    (format "Last button set : %s\n" (or rts-toolbar-debug--key "(none)"))
                    (format "Error           : %S\n\n" err)
                    (if (zerop rts-toolbar-debug--step)
                        (concat "It never reached the first button, so the culprit is the\n"
                                "`setopt' pair at the top of rts-flow-setup-toolbar.\n\n")
                      (concat "The broken form is the one RIGHT AFTER that button in\n"
                              "lisp/android-toolbar.el.\n\n"))))
           (t
            (insert (format "Ran clean: all %d buttons set, no error.\n\n"
                            rts-toolbar-debug--step)
                    "So the error is NOT in the setup -- it comes from redisplay,\n"
                    "i.e. one of the `:visible' or `:image' forms, which Emacs\n"
                    "evaluates every time it draws the tool bar.\n\n")))
          (insert "Buttons set, in order:\n")
          (dolist (line (nreverse rts-toolbar-debug--log))
            (insert line "\n"))
          (goto-char (point-min))
          (display-buffer (current-buffer)))
        (message "%s"
                 (cond ((not graphic) "Not a graphical frame — see *toolbar-debug*")
                       (err (format "FAILED after %s — see *toolbar-debug*"
                                    (or rts-toolbar-debug--key "0 buttons (the setopt)")))
                       (t "Setup ran clean — see *toolbar-debug*"))))
    (advice-remove 'keymap-set-after #'rts-toolbar-debug--record)))

(provide 'toolbar-debug)
;;; toolbar-debug.el ends here
