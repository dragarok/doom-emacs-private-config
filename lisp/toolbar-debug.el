;;; toolbar-debug.el --- Find the form that breaks the toolbar setup -*- lexical-binding: t -*-

;;; Commentary:
;; Throwaway.  `M-x rts-flow-setup-toolbar' dies with nothing but "Symbol's
;; function definition is void: nil", which names no function because the
;; function IS nil -- something evaluated a form whose head was nil.  The
;; only thing that can say WHERE is the backtrace, and a phone is a bad
;; place to read one.
;;
;;   M-x rts-toolbar-debug
;;
;; This runs the same setup with a debugger that captures the backtrace
;; into a plain buffer you can read, scroll and copy, and with every
;; `keymap-set-after' counted on the way past so the last button through
;; the door brackets the bad form even if the backtrace is unhelpful.
;;
;; Read the frames top-down: the first line is this file's own debugger,
;; the SECOND is the nil that was called, and the third and fourth name the
;; function and the call that did it.  That is the answer.
;;
;; If it reports no error at all, the setup is innocent and the fault is in
;; REDISPLAY -- one of the `:visible' or `:image' forms, which Emacs
;; re-evaluates every time it draws the bar.
;;
;; Delete this file once the offending form is fixed.

;;; Code:

(require 'seq)
;; Soft: if android-toolbar itself dies partway through loading, the defun
;; is already in place (it sits above the auto-setup at the file's foot), so
;; there is still something to run -- and a hard `require' here would only
;; re-raise the very error we are trying to name.
(require 'android-toolbar nil t)
(declare-function rts-flow-setup-toolbar "android-toolbar")

(defvar rts-toolbar-debug--step 0
  "How many `keymap-set-after' calls the run got through.")
(defvar rts-toolbar-debug--key nil
  "Key of the last `keymap-set-after' call that started.")
(defvar rts-toolbar-debug--log nil
  "Reversed list of the buttons set so far, newest first.")
(defvar rts-toolbar-debug--error nil
  "Error the run died on, as the debugger received it.")
(defvar rts-toolbar-debug--frames nil
  "Formatted backtrace captured at the moment of the error.")

(defun rts-toolbar-debug--record (&rest args)
  "Note that `keymap-set-after' was called with ARGS."
  (setq rts-toolbar-debug--step (1+ rts-toolbar-debug--step)
        rts-toolbar-debug--key (nth 1 args))
  (push (format "%3d  %s" rts-toolbar-debug--step rts-toolbar-debug--key)
        rts-toolbar-debug--log))

(defun rts-toolbar-debug--format-frames (frames)
  "Render FRAMES, as `backtrace-frames' returns them, one call per line.
Arguments are truncated: the point of this is to fit the answer on a
phone screen, not to reproduce the debugger."
  (mapconcat
   (lambda (frame)
     (format "  %s(%s)"
             (if (symbolp (nth 1 frame)) (nth 1 frame) "<lambda>")
             (mapconcat (lambda (arg)
                          (truncate-string-to-width
                           (format "%S" arg) 60 nil nil "…"))
                        (nth 2 frame) " ")))
   (seq-take frames 30)
   "\n"))

(defun rts-toolbar-debug--debugger (&rest args)
  "Debugger that records ARGS and the backtrace, then unwinds.
Named rather than anonymous so it can be handed to `backtrace-frames'
as the base to trim at -- that is what keeps this machinery out of the
frames you are meant to read."
  (setq rts-toolbar-debug--error args
        rts-toolbar-debug--frames
        (rts-toolbar-debug--format-frames
         (backtrace-frames 'rts-toolbar-debug--debugger)))
  (throw 'rts-toolbar-debug--captured nil))

;;;###autoload
(defun rts-toolbar-debug ()
  "Run the River Flow toolbar setup and report what makes it die.
Leaves the backtrace and the list of buttons that did get set in a
`*toolbar-debug*' buffer, which is readable and copyable on a phone in a
way the debugger\='s own window is not."
  (interactive)
  (unless (fboundp 'rts-flow-setup-toolbar)
    (user-error "rts-flow-setup-toolbar is not defined — android-toolbar never loaded"))
  (let ((graphic (display-graphic-p))
        (fallback nil))
    ;; Pass 1 -- safe.  A `condition-case' always yields the error object
    ;; and, with the advice on, the count of buttons that got set first.
    (setq rts-toolbar-debug--step 0
          rts-toolbar-debug--key nil
          rts-toolbar-debug--log nil
          rts-toolbar-debug--error nil
          rts-toolbar-debug--frames nil)
    (advice-add 'keymap-set-after :before #'rts-toolbar-debug--record)
    (unwind-protect
        (condition-case err
            (rts-flow-setup-toolbar)
          (error (setq fallback err)))
      (advice-remove 'keymap-set-after #'rts-toolbar-debug--record))
    ;; Pass 2 -- for the backtrace, and it has to be a SECOND pass: an
    ;; error with a `condition-case' around it counts as handled, and
    ;; `debug-on-error' does not call the debugger for handled errors, so
    ;; pass 1 can never produce frames.  Here nothing catches, the debugger
    ;; runs, and the report is written from the unwind so it survives even
    ;; if the debugger does not run and the error escapes instead.  Re-running
    ;; the setup is safe: `keymap-set-after' on the same keys just overwrites.
    (unwind-protect
        (when fallback
          (catch 'rts-toolbar-debug--captured
            (let ((debugger #'rts-toolbar-debug--debugger)
                  (debug-on-error t)
                  (debug-ignored-errors nil)
                  (inhibit-debugger nil))
              (rts-flow-setup-toolbar))))
      (rts-toolbar-debug--report graphic fallback))))

(defun rts-toolbar-debug--report (graphic fallback)
  "Write the findings to `*toolbar-debug*' and echo the headline.
GRAPHIC is what `display-graphic-p' said; FALLBACK is an error caught by
`condition-case' when the debugger never ran."
  (let ((err (or rts-toolbar-debug--error fallback)))
    (with-current-buffer (get-buffer-create "*toolbar-debug*")
      (erase-buffer)
      (cond
       ((not graphic)
        (insert "display-graphic-p was nil, so the whole setup body was skipped\n"
                "and this run proves nothing.  Run it from the graphical Emacs.\n\n"))
       (err
        (insert (format "FAILED after %d buttons.\n\n" rts-toolbar-debug--step)
                (format "Last button set : %s\n" (or rts-toolbar-debug--key "(none)"))
                (format "Error           : %S\n\n" err))
        (if rts-toolbar-debug--frames
            (insert "Backtrace — line 1 is this debugger, line 2 is the nil that\n"
                    "got called, and lines 3-4 name the function that called it:\n\n"
                    rts-toolbar-debug--frames "\n\n")
          (insert "No backtrace: the debugger never ran, so all we have is the\n"
                  "error above and the button count below.\n\n"))
        (insert (if (zerop rts-toolbar-debug--step)
                    (concat "It never reached the first button, so the culprit is the\n"
                            "`setopt' pair at the top of rts-flow-setup-toolbar.\n\n")
                  (concat "The broken form is the one RIGHT AFTER that button in\n"
                          "lisp/android-toolbar.el.\n\n"))))
       (t
        (insert (format "Ran clean: all %d buttons set, no error.\n\n"
                        rts-toolbar-debug--step)
                "So the setup is innocent and the error comes from REDISPLAY --\n"
                "one of the `:visible' or `:image' forms, which Emacs evaluates\n"
                "every time it draws the tool bar rather than while building it.\n\n")))
      (insert "Buttons set, in order:\n")
      (dolist (line (nreverse rts-toolbar-debug--log))
        (insert line "\n"))
      (goto-char (point-min))
      (display-buffer (current-buffer)))
    (message "%s"
             (cond ((not graphic) "Not a graphical frame — see *toolbar-debug*")
                   (err (format "FAILED after %s — see *toolbar-debug*"
                                (or rts-toolbar-debug--key "0 buttons (the setopt)")))
                   (t "Setup ran clean — see *toolbar-debug*")))))

(provide 'toolbar-debug)
;;; toolbar-debug.el ends here
