;;; tips-test.el --- Tests for tips.el -*- lexical-binding: t -*-

(require 'ert)
(require 'tips)

(ert-deftest tips-test-read ()
  "Each second-level heading is a tip, with its section; text before the
first section is not."
  (let ((tips-file (make-temp-file "guide" nil ".org"
                                   "#+TITLE: G\nIntro.\n* Notes\n** Find one\nSPC n r f.\n*bold* line.\n\n** Link one\nSPC n r i.\n* Tasks\n** Effort\nSPC m c E.\n")))
    (unwind-protect
        (should (equal (tips-read)
                       '(("Notes" "Find one" "SPC n r f.\n*bold* line.")
                         ("Notes" "Link one" "SPC n r i.")
                         ("Tasks" "Effort" "SPC m c E."))))
      (delete-file tips-file))))

(ert-deftest tips-test-one-at-a-time ()
  "Each call shows the next tip, wrapping around; back goes back one."
  (let ((tips-file (make-temp-file "guide" nil ".org" "* S\n** One\na\n** Two\nb\n"))
        (tips-position-file (make-temp-file "tips-next"))
        shown)
    (delete-file tips-position-file)
    (unwind-protect
        (cl-letf (((symbol-function 'pop-to-buffer) #'ignore)
                  ((symbol-function 'fit-window-to-buffer) #'ignore))
          (dolist (f (list #'tips-next #'tips-next #'tips-next #'tips-previous))
            (funcall f)
            (push (with-current-buffer "*Tip*"
                    (goto-char (point-min)) (forward-line 1)
                    (buffer-substring-no-properties (point) (line-end-position)))
                  shown))
          (should (equal (nreverse shown) '("* One" "* Two" "* One" "* Two")))
          (should (with-current-buffer "*Tip*" buffer-read-only)))
      (delete-file tips-file)
      (ignore-errors (delete-file tips-position-file))
      (kill-buffer "*Tip*"))))

;;; tips-test.el ends here
