;;; voice-help.el --- Voice: what you can say -*- lexical-binding: t -*-

;;; Commentary:
;; See voice-command.el for how the parts fit.

;;; Code:

(require 'voice-core)

(defun voice--when-label (when)
  (pcase when
    ('nil nil) ('clocking "while clocked in") ('android "phone") ('remote "in an agent's chat")
    ((or 'image 'image-mode) "on a photo") ((pred symbolp) (symbol-name when)) (_ "sometimes")))

(defun voice-help (&optional all)
  "Show what you can say here; with ALL (\\[universal-argument]), everything and when."
  (interactive "P")
  (let* ((context (voice-context))
         (mine (reverse (if all voice-actions
                          (seq-filter (lambda (a) (voice--when-p (plist-get a :when) context))
                                      voice-actions))))
         (mine-cmds (mapcar (lambda (a) (plist-get a :run)) voice-actions))
         (others (delete-dups
                  (mapcar (lambda (a) (plist-get a :name))
                          (seq-remove (lambda (a) (memq (plist-get a :run) mine-cmds))
                                      (append (voice--toolbar-actions) (voice--homepage-actions)))))))
    (with-current-buffer (get-buffer-create "*Voice commands*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (if all "#+title: Everything you can say\n\n" "#+title: What you can say here\n\n")
                "/A phrase with … takes the rest of what you say./\n\n* Commands\n")
        (dolist (a mine)
          (let ((label (or (plist-get a :where) (voice--when-label (plist-get a :when)))))
            (insert (format "- *%s*%s :: %s\n" (plist-get a :name)
                            (if label (format " (%s)" label) "")
                            (mapconcat (lambda (p) (format "\"%s\"" p)) (plist-get a :phrases) ", ")))))
        (when others
          (insert "\n* Buttons and tiles, by their names\n"
                  (mapconcat #'identity others ", ") "\n"))
        (insert "\n* Anything else\n"
                "- A task's name alone: the closest tasks, to pick one.\n"
                "- With a question open: its answer.  A choice by name or \"the second one\", yes or no, the text; \"cancel\" closes it.\n"
                "- Your own words for things: ~/org/voice.org (* Phrases, * Names).\n")
        (org-mode)
        (read-only-mode 1)
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))
    "What you can say"))

(voice-action '("help" "what can i say" "voice commands" "commands" "show help" "help me"
                "what can you do")
              #'voice-help :name "help")

(provide 'voice-help)
;;; voice-help.el ends here
