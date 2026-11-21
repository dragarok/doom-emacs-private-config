;;; morning-ritual-test.el --- Tests for morning-ritual.el -*- lexical-binding: t -*-

;; emacs -Q --batch -L lisp -l test/morning-ritual-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(defvar org-logs-directory temporary-file-directory) ; for usage-log, stubbed below
(require 'morning-ritual)

(defmacro morning-ritual-test--with (&rest body)
  "BODY with the ritual's file in a temporary directory, its commands
counted in `ran', and timers run at once."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "morning-ritual" t))
          (morning-ritual-file (expand-file-name "sub/day" dir))
          (ran nil)
          (morning-ritual-commands '(morning-ritual-test--cmd)))
     (cl-letf (((symbol-function 'morning-ritual-test--cmd)
                (lambda () (interactive) (push 'opened ran)))
               ((symbol-function 'usage-log) #'ignore)
               ((symbol-function 'run-at-time)
                (lambda (_time _repeat fn &rest args) (apply fn args))))
       (unwind-protect (progn ,@body)
         (delete-directory dir t)))))

(ert-deftest morning-ritual-day-turns-at-three ()
  (let ((morning-ritual-from 3))
    (should (equal (morning-ritual--day (encode-time '(0 59 2 21 11 2026 nil -1 nil)))
                   "2026-11-20"))
    (should (equal (morning-ritual--day (encode-time '(0 0 3 21 11 2026 nil -1 nil)))
                   "2026-11-21"))
    (should (equal (morning-ritual--day (encode-time '(0 0 23 21 11 2026 nil -1 nil)))
                   "2026-11-21"))))

(ert-deftest morning-ritual-runs-once-a-day ()
  (morning-ritual-test--with
    (should (morning-ritual-due-p))
    (should (morning-ritual-run))
    (should (equal ran '(opened)))
    (should-not (morning-ritual-due-p))
    ;; The unlock and a Home press: still once.
    (should-not (morning-ritual-run))
    (should (equal ran '(opened)))
    ;; Asked for by hand, it runs.
    (morning-ritual-run t)
    (should (equal ran '(opened opened)))
    ;; The next morning, due again.
    (with-temp-file morning-ritual-file (insert "2001-01-01\n"))
    (should (morning-ritual-due-p))))

(ert-deftest morning-ritual-one-failing-command-leaves-the-rest ()
  (morning-ritual-test--with
    (let ((morning-ritual-commands '(morning-ritual-test--broken morning-ritual-test--cmd)))
      (cl-letf (((symbol-function 'morning-ritual-test--broken)
                 (lambda () (interactive) (error "No network"))))
        (let ((inhibit-message t)) (morning-ritual-run))
        (should (equal ran '(opened)))))))

;;; morning-ritual-test.el ends here
