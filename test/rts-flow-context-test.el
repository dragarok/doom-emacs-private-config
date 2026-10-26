;;; rts-flow-context-test.el --- Flow knows where you are -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/rts-flow-context-test.el -f ert-run-tests-batch-and-exit
;; Topics files are temporary; ~/org is never touched.

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
* TODO Scales :pianopractice:
* TODO Read the piano theory book :pianoreading:
* Watch list :entertainment:
** TODO Some series
")

(defmacro rts-flow-test--with (topics &rest body)
  "BODY in a buffer of `rts-flow-test--items', with TOPICS as the topics
file (nil: none, the defaults apply); `items' are its entries as the
selectors give them, `left' the titles a place keeps."
  (declare (indent 1))
  `(let* ((dir (make-temp-file "rts-flow-test" t))
          (org-summary-topics-file (expand-file-name "topics.org" dir)))
     (when ,topics (with-temp-file org-summary-topics-file (insert ,topics)))
     (unwind-protect
         (with-temp-buffer
           (insert rts-flow-test--items)
           (org-mode)
           (let ((items (org-map-entries
                         (lambda () (list 'headline (list :org-marker (point-marker)
                                                          :raw-value (org-get-heading t t t t)))))))
             (cl-flet ((left (ctx) (let ((rts-flow-current-context ctx))
                                     (mapcar (lambda (i) (org-element-property :raw-value i))
                                             (rts-flow--filter-by-needs items)))))
               ,@body)))
       (delete-directory dir t))))

(ert-deftest rts-flow-test-needs ()
  "Needs come from tags (inherited too), keywords, title words and links;
:anywhere: overrides; a Music tag on a book is not an instrument."
  (rts-flow-test--with nil
    (should (equal (org-map-entries (lambda () (cons (org-get-heading t t t t) (rts-flow--needs-at-point))))
                   '(("Write the essay")
                     ("A film" "video")
                     ("Tacit knowledge videos lesswrong" "video")
                     ("Gibson's Learn & Master Guitar Boxed Dvd/CD Set" "video" "guitar")
                     ("Diffusion models from scratch" "video")
                     ("Initial Political Campaign Video" "video" "talk")
                     ("Call the bank" "talk")
                     ("Read about recording studios")
                     ("Godel, Escher, Bach")
                     ("Scales" "piano")
                     ("Read the piano theory book" "piano")
                     ("Watch list" "video")
                     ("Some series" "video"))))))

(ert-deftest rts-flow-test-default-places ()
  "With no topics file: in public only what needs nothing hidden there;
your room keeps everything; no place, nothing filtered."
  (rts-flow-test--with nil
    (should (equal (left 'public)
                   '("Write the essay" "Read about recording studios" "Godel, Escher, Bach")))
    (should (= (length (left 'personalroom)) (length items)))
    (should (= (length (left nil)) (length items)))
    (should (member "A film" (left 'othersroom)))
    (should-not (member "Scales" (left 'othersroom)))))

(ert-deftest rts-flow-test-file-places ()
  "The topics file sets each place: -x hides tasks with tag or need x,
+x shows them anyway; a place it doesn't name keeps its default."
  (rts-flow-test--with "* Needs
- video :: video watch youtube.com towatch entertainment
- piano :: piano pianopractice
* Places
- public :: -video -piano +pianoreading -mentalgym
"
    (should (equal (left 'public)
                   '("Write the essay" "Tacit knowledge videos lesswrong"
                     "Gibson's Learn & Master Guitar Boxed Dvd/CD Set" "Call the bank"
                     "Read about recording studios" "Godel, Escher, Bach"
                     "Read the piano theory book")))
    ;; travel isn't in the file: its default, which hides video.
    (should-not (member "A film" (left 'travel)))
    (should (member "Call the bank" (left 'travel)))))

(ert-deftest rts-flow-test-paused ()
  "A paused need or topic is left out wherever you are, your room too."
  (rts-flow-test--with (format "* Paused\n- piano :: %s ..\n- weeklyvideo :: %s ..\n"
                               (format-time-string "%F") (format-time-string "%F"))
    (should (equal (rts-flow--paused) '("piano" "weeklyvideo")))
    (let ((room (left 'personalroom)))
      (should-not (member "Scales" room))
      (should-not (member "Read the piano theory book" room))
      (should-not (member "Initial Political Campaign Video" room))
      (should (member "Call the bank" room)))))

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
      (let ((rts-flow-current-context nil))
        (rts-flow-set-context (rts-flow--read-choice "Where? " rts-flow-contexts nil))
        (should (eq rts-flow-current-context 'public))))))

(ert-deftest rts-flow-test-not-with-me ()
  "\"Not with me\" in the place question pauses the need, then asks again."
  (let (paused)
    (cl-letf (((symbol-function 'org-summary-pause-topic) (lambda (n) (push n paused)))
              ((symbol-function 'rts-flow--paused) (lambda () nil))
              ((symbol-function 'completing-read)
               (let ((answers (list "⏸ Not with me: piano, guitar…" "piano  (with me)" "🏠 Personal Room")))
                 (lambda (&rest _) (pop answers)))))
      (let ((rts-flow-current-context nil))
        (call-interactively #'rts-flow-set-context)
        (should (equal paused '("piano")))
        (should (eq rts-flow-current-context 'personalroom))))))

;;; rts-flow-context-test.el ends here
