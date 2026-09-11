;;; toolbar-debug.el --- Find the form that breaks the toolbar -*- lexical-binding: t -*-

;;; Commentary:
;; Throwaway.  Loading `android-toolbar' dies with nothing but "Symbol's
;; function definition is void: nil", which names no function because the
;; function IS nil -- something evaluated a form whose head was nil.  Only
;; a backtrace can say where, and a phone is a bad place to read one.
;;
;; This file deliberately does NOT require android-toolbar: that require is
;; the thing that blows up, and a load-time one here would take this file
;; down with it before it could report anything.
;;
;;   M-x rts-toolbar-debug-load    load android-toolbar.el and catch the
;;                                 backtrace -- START HERE, the error is at
;;                                 load time
;;   M-x rts-toolbar-debug         same, but for `rts-flow-setup-toolbar'
;;                                 alone, once the file does load
;;
;; Both leave their findings in a `*toolbar-debug*' buffer you can read,
;; scroll and copy.  Read the frames top-down: line 1 is this file's own
;; debugger, line 2 is the nil that got called AND WHAT WAS PASSED TO IT,
;; and the lines under it name the form that did it.  That is the answer.
;;
;; Delete this file once the offending form is fixed.

;;; Code:

(require 'seq)

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
Arguments are truncated: the point is to fit the answer on a phone
screen, not to reproduce the debugger."
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
Named rather than anonymous so it can be handed to `backtrace-frames' as
the base to trim at -- that is what keeps this machinery out of the
frames you are meant to read."
  (setq rts-toolbar-debug--error args
        rts-toolbar-debug--frames
        (rts-toolbar-debug--format-frames
         (backtrace-frames 'rts-toolbar-debug--debugger)))
  (throw 'rts-toolbar-debug--captured nil))

(defun rts-toolbar-debug--run (thunk)
  "Run THUNK twice and return the error it dies on, or nil.
Twice, and the reason is not obvious: an error with a `condition-case'
around it counts as HANDLED, and `debug-on-error' does not call the
debugger for handled errors -- so the safe pass that yields the error
object can never yield frames.  Pass 1 catches, pass 2 lets it fly with
the debugger installed.  Both passes run the same thunk, which is fine
for the two things this file runs: loading a file and setting keymap
entries are equally happy to happen twice."
  (setq rts-toolbar-debug--step 0
        rts-toolbar-debug--key nil
        rts-toolbar-debug--log nil
        rts-toolbar-debug--error nil
        rts-toolbar-debug--frames nil)
  (let ((fallback nil))
    (advice-add 'keymap-set-after :before #'rts-toolbar-debug--record)
    (unwind-protect
        (condition-case err (funcall thunk) (error (setq fallback err)))
      (advice-remove 'keymap-set-after #'rts-toolbar-debug--record))
    (when fallback
      (catch 'rts-toolbar-debug--captured
        (let ((debugger #'rts-toolbar-debug--debugger)
              (debug-on-error t)
              (debug-ignored-errors nil)
              (inhibit-debugger nil))
          (funcall thunk))))
    fallback))

(defun rts-toolbar-debug--report (what err)
  "Write the findings about WHAT to `*toolbar-debug*' and echo a headline.
ERR is the error caught by the safe pass, or nil when there was none."
  (with-current-buffer (get-buffer-create "*toolbar-debug*")
    (erase-buffer)
    (insert (format "%s\n%s\n\n" what (make-string (length what) ?=)))
    (unless (display-graphic-p)
      (insert "NOTE: display-graphic-p is nil, so the toolbar body is skipped\n"
              "entirely and a clean result here proves nothing.  Run this from\n"
              "the graphical Emacs.\n\n"))
    (if (not err)
        (insert "Ran clean: no error.\n\n"
                "If the toolbar still misbehaves, the fault is in REDISPLAY --\n"
                "one of the `:visible' or `:image' forms, which Emacs evaluates\n"
                "every time it draws the bar rather than while building it.\n\n")
      (insert (format "Error : %S\n\n" err))
      (when rts-toolbar-debug--form
        (insert (format "Died on the form at line %d:\n\n  %s\n\n"
                        rts-toolbar-debug--line
                        (truncate-string-to-width
                         (format "%S" rts-toolbar-debug--form) 300 nil nil "…"))))
      (if rts-toolbar-debug--frames
          (insert "Backtrace — line 1 is this debugger, line 2 is the nil that\n"
                  "got called and what was passed to it, and the lines under it\n"
                  "name the form that called it:\n\n"
                  rts-toolbar-debug--frames "\n\n")
        (insert "No backtrace: the debugger never ran, so all we have is the\n"
                "error above.\n\n")))
    (insert (format "Loaded already? productivity_flow:%s  micro-experiments:%s  android-toolbar:%s\n"
                    (featurep 'productivity_flow)
                    (featurep 'micro-experiments)
                    (featurep 'android-toolbar)))
    (insert (format "Buttons set before it stopped: %d%s\n"
                    rts-toolbar-debug--step
                    (if rts-toolbar-debug--key
                        (format " (last: %s)" rts-toolbar-debug--key)
                      "")))
    (when rts-toolbar-debug--log
      (insert "\nButtons set, in order:\n")
      (dolist (line (nreverse rts-toolbar-debug--log))
        (insert line "\n")))
    (goto-char (point-min))
    (display-buffer (current-buffer)))
  (message "%s — see *toolbar-debug*" (if err "FAILED" "Ran clean")))

(defvar rts-toolbar-debug-file
  (expand-file-name "lisp/android-toolbar.el"
                    (or (bound-and-true-p doom-user-dir) "~/.doom.d/"))
  "Source file to step through.  The .el, deliberately: if stepping the
source runs clean while `load' does not, the answer is a stale .elc or
.eln left behind by the Emacs upgrade, not the code.")

(defvar rts-toolbar-debug--form nil
  "Top-level form the file died on.")
(defvar rts-toolbar-debug--line nil
  "Line `rts-toolbar-debug--form' starts on.")

(defun rts-toolbar-debug--step-file (file)
  "Eval FILE one top-level form at a time, stopping at the first failure.
`load' can only ever blame the whole file -- a top-level error leaves
nothing but `load-with-code-conversion' in the frames -- so the form and
its line number have to be recovered by reading them one at a time."
  (setq rts-toolbar-debug--form nil
        rts-toolbar-debug--line nil)
  (with-temp-buffer
    (insert-file-contents file)
    (emacs-lisp-mode)
    (goto-char (point-min))
    (let ((err nil) (done nil))
      (while (not (or err done))
        (forward-comment (buffer-size))  ; land on the form, not the blurb above it
        (let ((line (line-number-at-pos))
              (form nil))
          (condition-case _ (setq form (read (current-buffer)))
            (end-of-file (setq done t)))
          (unless done
            (setq err (rts-toolbar-debug--run (lambda () (eval form t))))
            (when err
              (setq rts-toolbar-debug--form form
                    rts-toolbar-debug--line line)))))
      err)))

;;;###autoload
(defun rts-toolbar-debug-load ()
  "Step through android-toolbar.el and report the form that kills it.
Start here: the error fires while the file is being LOADED, which is why
`require' and `M-x rts-flow-setup-toolbar' both show it -- the file runs
the setup itself on the way past its own foot."
  (interactive)
  (rts-toolbar-debug--report
   (format "Stepping %s" (abbreviate-file-name rts-toolbar-debug-file))
   (rts-toolbar-debug--step-file rts-toolbar-debug-file)))

;;;###autoload
(defun rts-toolbar-debug-load-file ()
  "Plain `load' of android-toolbar, for comparison with the stepper.
If this fails where `rts-toolbar-debug-load' succeeds, the source is
innocent and you are loading a stale .elc or .eln."
  (interactive)
  (rts-toolbar-debug--report
   "Plain load of android-toolbar"
   (rts-toolbar-debug--run (lambda () (load "android-toolbar" nil t)))))

;;;###autoload
(defun rts-toolbar-debug ()
  "Run `rts-flow-setup-toolbar' alone and report what makes it die.
Only useful once the file itself loads; until then use
`rts-toolbar-debug-load'."
  (interactive)
  (unless (fboundp 'rts-flow-setup-toolbar)
    (user-error "rts-flow-setup-toolbar is not defined — run rts-toolbar-debug-load first"))
  (rts-toolbar-debug--report
   "Running rts-flow-setup-toolbar"
   (rts-toolbar-debug--run #'rts-flow-setup-toolbar)))

(provide 'toolbar-debug)
;;; toolbar-debug.el ends here
