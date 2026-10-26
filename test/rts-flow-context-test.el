;;; rts-flow-context-test.el --- Flow knows where you are -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/rts-flow-context-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'productivity_flow)

(defconst rts-flow-test--items
  "#+TODO: TODO TOWATCH | DONE
* TODO Write the essay
* TOWATCH A film
* TODO Tacit knowledge videos lesswrong
* TODO Gibson's Learn & Master Guitar Boxed Dvd/CD Set
* TODO Diffusion models from scratch
Notes: https://www.youtube.com/watch?v=abc
* TODO Initial Political Campaign Video :weeklyvideo:
* TODO Call the bank
* TODO Read about recording studios :anywhere:
* TODO Godel, Escher, Bach :Music:
* Watch list :entertainment:
** TODO Some series
")

(defun rts-flow-test--needs ()
  "Each heading's title and needs, from `rts-flow-test--items'."
  (with-temp-buffer
    (insert rts-flow-test--items)
    (org-mode)
    (let (out)
      (org-map-entries
       (lambda () (push (cons (org-get-heading t t t t) (sort (rts-flow--needs-at-point)
                                                              (lambda (a b) (string< a b))))
                        out)))
      (nreverse out))))

(ert-deftest rts-flow-test-needs ()
  "Needs come from tags (inherited too), keywords, title words and links;
:anywhere: overrides; a Music tag on a book is not an instrument."
  (should (equal (rts-flow-test--needs)
                 '(("Write the essay")
                   ("A film" . (:video))
                   ("Tacit knowledge videos lesswrong" . (:video))
                   ("Gibson's Learn & Master Guitar Boxed Dvd/CD Set" . (:instruments :video))
                   ("Diffusion models from scratch" . (:video))
                   ("Initial Political Campaign Video" . (:talk :video))
                   ("Call the bank" . (:talk))
                   ("Read about recording studios")
                   ("Godel, Escher, Bach")
                   ("Watch list" . (:video))
                   ("Some series" . (:video))))))

(ert-deftest rts-flow-test-filter ()
  "In public only what needs nothing blocked there is left; in your room,
everything; with no place set, nothing is filtered."
  (with-temp-buffer
    (insert rts-flow-test--items)
    (org-mode)
    (let ((items (org-map-entries
                  (lambda () (list 'headline (list :org-marker (point-marker)
                                                   :raw-value (org-get-heading t t t t)))))))
      (cl-flet ((left (ctx) (let ((rts-flow-current-context ctx))
                              (mapcar (lambda (i) (org-element-property :raw-value i))
                                      (rts-flow--filter-by-needs items)))))
        (should (equal (left 'public)
                       '("Write the essay" "Read about recording studios" "Godel, Escher, Bach")))
        (should (= (length (left 'personalroom)) (length items)))
        (should (= (length (left nil)) (length items)))
        (should (member "A film" (left 'othersroom)))
        (should-not (member "Gibson's Learn & Master Guitar Boxed Dvd/CD Set" (left 'othersroom)))))))

(ert-deftest rts-flow-test-read-choice ()
  "The picker gives back the context's symbol, not its label, and offers
the current one first and as the default."
  (let (seen default)
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_p cands &rest r) (setq seen (mapcar #'car cands) default (nth 4 r))
                 "🏛️ Public Place")))
      (should (eq (rts-flow--read-choice "Where? " rts-flow-contexts 'travel) 'public))
      (should (equal (car seen) "✈️ Travel"))
      (should (equal default "✈️ Travel"))
      (rts-flow-set-context (rts-flow--read-choice "Where? " rts-flow-contexts nil))
      (should (eq rts-flow-current-context 'public))
      (should (rts-flow--get-context-prop rts-flow-current-context :blocks)))))

;;; rts-flow-context-test.el ends here
