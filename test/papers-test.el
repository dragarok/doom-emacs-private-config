;;; papers-test.el --- A paper in: its entry, its PDF, its note -*- lexical-binding: t -*-

;; Run: emacs -Q --batch -L lisp -l test/papers-test.el -f ert-run-tests-batch-and-exit
;; Everything happens in a temporary directory; ~/org is never touched,
;; and nothing goes out on the network (doi.org and arXiv are stood in for).

(require 'ert)
(require 'cl-lib)
(require 'papers)

(defvar org-roam-directory)
(defvar citar-library-paths)
(defvar citar-bibliography)

(defconst papers-test--bibtex "@misc{https://doi.org/10.48550/arxiv.2401.14196,
  doi = {10.48550/ARXIV.2401.14196},
  url = {https://arxiv.org/abs/2401.14196},
  author = {Guo, Daya and Zhu, Qihao and Yang, Dejian},
  title = {DeepSeek-Coder: When the Large Language Model Meets Programming -- The Rise of Code Intelligence},
  publisher = {arXiv},
  year = {2024}
}")

(defmacro papers-test--with (&rest body)
  "BODY with `dir' holding org/ (notes, references) and a library."
  (declare (indent 0))
  `(let* ((dir (file-name-as-directory (make-temp-file "papers-test" t)))
          ;; Whatever buffer the tests run from, a directory that exists.
          (default-directory dir)
          (org-directory (expand-file-name "org/" dir))
          (org-roam-directory (expand-file-name "org/notes/" dir))
          (citar-library-paths (list (expand-file-name "Books/Papers/articles/" dir)))
          (citar-bibliography (list (expand-file-name "org/references/articles.bib" dir)))
          (papers-bib-file nil))
     (make-directory org-roam-directory t)
     (make-directory (expand-file-name "org/references/" dir) t)
     (with-temp-file (car citar-bibliography)
       (insert "@misc{oldKeyPaper2020,\n  title = {Old},\n  doi = {10.1234/old},\n  year = {2020}\n}\n"))
     (unwind-protect (progn ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p dir (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory dir t))))

(ert-deftest papers-test-doi ()
  "Every way of naming a paper comes to its DOI."
  (should (equal (papers--doi "2401.14196") "10.48550/arXiv.2401.14196"))
  (should (equal (papers--doi "2401.14196v2") "10.48550/arXiv.2401.14196"))
  (should (equal (papers--doi "arXiv:2401.14196") "10.48550/arXiv.2401.14196"))
  (should (equal (papers--doi "https://arxiv.org/abs/2401.14196v3") "10.48550/arXiv.2401.14196"))
  (should (equal (papers--doi "https://arxiv.org/pdf/2401.14196") "10.48550/arXiv.2401.14196"))
  (should (equal (papers--doi "https://doi.org/10.1038/nature14539") "10.1038/nature14539"))
  (should (equal (papers--doi "10.1038/nature14539.") "10.1038/nature14539"))
  (should-not (papers--doi "a shopping list"))
  (should (equal (papers--arxiv-id "10.48550/arXiv.2401.14196") "2401.14196")))

(ert-deftest papers-test-key ()
  "Last name, three title words that matter, year -- as Better BibTeX."
  (let ((fields (papers--parse papers-test--bibtex)))
    (should (equal (papers--key fields) "guoDeepSeekCoderWhen2024"))
    (should (equal (papers--key '(("author" . "Sébastien Bubeck and Others") ("title" . "The {{Sparks}} of AGI") ("year" . "2023")))
                   "bubeckSparksAGI2023"))))

(ert-deftest papers-test-add ()
  "An arXiv id in: the entry in added.bib under its own key, with the DOI
and the PDF (relative); the PDF in the library; the note with the key in
its ROAM_REFS, the PDF as NOTER_DOCUMENT, tagged paper, why you read it."
  (papers-test--with
    (cl-letf (((symbol-function 'papers--fetch-bibtex) (lambda (_) papers-test--bibtex))
              ((symbol-function 'url-copy-file)
               (lambda (_url file &rest _) (with-temp-file file (insert "%PDF-1.5 fake"))))
              ((symbol-function 'read-string) (lambda (&rest _) "To see how they trained on repos.")))
      (papers-add "https://arxiv.org/abs/2401.14196"))
    (let ((bib (with-temp-buffer (insert-file-contents (expand-file-name "org/references/added.bib" dir)) (buffer-string)))
          (pdf (expand-file-name "Books/Papers/articles/guoDeepSeekCoderWhen2024.pdf" dir))
          (note (with-temp-buffer (insert-file-contents (expand-file-name "org/notes/guoDeepSeekCoderWhen2024.org" dir))
                                  (buffer-string))))
      (should (string-match-p "\\`@misc{guoDeepSeekCoderWhen2024,\n" bib))
      (should (string-match-p "  doi = {10.48550/arXiv.2401.14196}" bib))
      (should (string-match-p "  file = {guoDeepSeekCoderWhen2024.pdf}\n}\n\\'" bib))
      (should (file-exists-p pdf))
      (should (string-match-p ":ROAM_REFS: @guoDeepSeekCoderWhen2024" note))
      (should (string-match-p ":NOTER_DOCUMENT: \\.\\./\\.\\./Books/Papers/articles/guoDeepSeekCoderWhen2024.pdf" note))
      (should (string-match-p "#\\+TITLE: DeepSeek-Coder: When the Large Language Model Meets Programming -- The Rise of Code Intelligence\n#\\+FILETAGS: :paper:\n" note))
      (should (string-match-p "- Why I'm reading it :: To see how they trained on repos." note)))))

(ert-deftest papers-test-add-again ()
  "A paper already in a bibliography is not added twice: its note opens."
  (papers-test--with
    (let (fetched)
      (cl-letf (((symbol-function 'papers--fetch-bibtex) (lambda (_) (setq fetched t) ""))
                ((symbol-function 'read-string) (lambda (&rest _) "")))
        (papers-add "10.1234/old"))
      (should-not fetched)
      (should (equal (file-name-nondirectory buffer-file-name) "oldKeyPaper2020.org")))))

(ert-deftest papers-test-no-pdf ()
  "No free PDF (not arXiv, or arXiv sends something else): the entry has no
file, the note no NOTER_DOCUMENT, and nothing is left in the library."
  (papers-test--with
    (cl-letf (((symbol-function 'papers--fetch-bibtex)
               (lambda (_) "@article{LeCun_2015, title={Deep learning}, DOI={10.1038/nature14539}, author={LeCun, Yann and Bengio, Yoshua}, year={2015}}"))
              ((symbol-function 'read-string) (lambda (&rest _) "")))
      (papers-add "10.1038/nature14539"))
    (let ((bib (with-temp-buffer (insert-file-contents (expand-file-name "org/references/added.bib" dir)) (buffer-string))))
      (should (string-match-p "@article{lecunDeepLearning2015," bib))
      (should-not (string-match-p "file =" bib))
      (let ((note buffer-file-name))
        (should-not (string-match-p "NOTER_DOCUMENT\\|Why I'm" (with-temp-buffer (insert-file-contents note) (buffer-string)))))))
  (papers-test--with
    (cl-letf (((symbol-function 'url-copy-file)
               (lambda (_url file &rest _) (with-temp-file file (insert "<html>captcha</html>")))))
      (should-not (papers--fetch-pdf "2401.14196" (expand-file-name "x.pdf" (car citar-library-paths))))
      (should-not (file-exists-p (expand-file-name "x.pdf" (car citar-library-paths)))))))

;;; papers-test.el ends here
