;;; papers.el --- A paper in: its entry, its PDF, its note -*- lexical-binding: t -*-

;;; Commentary:
;; Found on 2026-10-26: the bibliography (Zotero's Better BibTeX export,
;; references/articles.bib, 174 entries) had not grown since 2025-09-20;
;; no note carried a citekey (0 ROAM_REFS), so citar never saw a paper as
;; having notes; the "R" template errored every time; citar-org-roam's
;; own notes were titled with the whole author list.  So, one path:
;;
;;   `papers-add' (SPC n r p): a DOI, an arXiv id, or a link to either --
;;   offered from the clipboard when that is one.  The entry comes from
;;   Crossref or DataCite (arXiv's own DOIs) into `papers-bib-file', a file of its
;;   own so Zotero's export never writes over it; the PDF, when arXiv has
;;   it, into the library as KEY.pdf; and the note, notes/KEY.org, with
;;   :ROAM_REFS: @KEY and the PDF as its NOTER_DOCUMENT.  One question:
;;   why this paper.  The takeaways come after reading -- the empty notes'
;;   walk asks a paper the one idea you'd keep (note-flow.el).
;;
;;   A paper already in the bibliography: SPC n b (citar) makes the same
;;   note, the same way (`papers-note' stands in for citar-org-roam's).
;;
;; Paths in the entry and the note are relative (the PDF to the library,
;; the note's NOTER_DOCUMENT to the note), so they hold on the Mac and on
;; the phone alike.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'url)
(require 'bibtex)
(require 'ucs-normalize)
(require 'org)
(require 'org-id)

(defvar org-directory)
(defvar org-roam-directory)
(defvar citar-bibliography)
(defvar citar-library-paths)

(defgroup papers nil
  "A paper in: its entry, its PDF, its note."
  :group 'org)

(defcustom papers-bib-file nil
  "The bibliography papers are added to: not Zotero's export, which would
write over them.  Nil: references/added.bib in `org-directory'."
  :type '(choice (const nil) file))

(defun papers--bib-file ()
  (or papers-bib-file (expand-file-name "references/added.bib" org-directory)))

(defun papers--library ()
  "Where the PDFs live: the first of `citar-library-paths'."
  (expand-file-name (or (car (bound-and-true-p citar-library-paths)) "~/Books/Papers/articles/")))

(defun papers--bib-files ()
  (seq-filter #'file-exists-p
              (seq-uniq (mapcar #'expand-file-name
                                (cons (papers--bib-file) (bound-and-true-p citar-bibliography))))))

;;; What was given

(defun papers--doi (input)
  "The DOI INPUT names -- a DOI, doi.org link, arXiv id or arXiv link -- or nil."
  (let ((s (string-trim (or input ""))))
    (cond
     ((string-match "\\(?:arxiv\\.org/\\(?:abs\\|pdf\\)/\\|\\`arxiv:\\)\\([0-9]\\{4\\}\\.[0-9]\\{4,5\\}\\)" (downcase s))
      (concat "10.48550/arXiv." (match-string 1 (downcase s))))
     ((string-match "\\`\\([0-9]\\{4\\}\\.[0-9]\\{4,5\\}\\)\\(?:v[0-9]+\\)?\\'" s)
      (concat "10.48550/arXiv." (match-string 1 s)))
     ((string-match "\\(10\\.[0-9]\\{4,9\\}/[^ \t\n\"<>]+\\)" s)
      (string-remove-suffix "." (match-string 1 s))))))

(defun papers--arxiv-id (doi)
  (when (and doi (string-match "\\`10\\.48550/arxiv\\.\\(.+\\)\\'" (downcase doi)))
    (match-string 1 (downcase doi))))

;;; The entry

(defun papers--get (url)
  "URL's body as a string when it answers 200 with BibTeX, else nil."
  (let ((url-show-status nil))
    (when-let* ((buf (ignore-errors (url-retrieve-synchronously url t t 30))))
      (with-current-buffer buf
        (unwind-protect
            (progn
              (goto-char (point-min))
              (when (and (re-search-forward "^HTTP/[0-9.]+ 200" (line-end-position) t)
                         (re-search-forward "\n\n" nil t))
                (let ((body (decode-coding-string (buffer-substring-no-properties (point) (point-max)) 'utf-8)))
                  (and (string-match-p "@[a-zA-Z]+[ \t]*{" body) (string-trim body)))))
          (kill-buffer))))))

(defun papers--fetch-bibtex (doi)
  "DOI's BibTeX entry, from the registry that holds it: DataCite (arXiv's
DOIs) or Crossref (journals).  Not by doi.org's content negotiation: its
redirect loses the Accept header in url.el, and arXiv's page comes back."
  (or (seq-some (lambda (u) (papers--get (format u (replace-regexp-in-string " " "%20" doi))))
                (if (papers--arxiv-id doi)
                    '("https://api.datacite.org/dois/application/x-bibtex/%s")
                  '("https://api.crossref.org/works/%s/transform/application/x-bibtex"
                    "https://api.datacite.org/dois/application/x-bibtex/%s")))
      (user-error "No BibTeX found for %s" doi)))

(defun papers--parse (bibtex)
  "BIBTEX's entry as an alist (\"=type=\" and field names, lower case),
values without their outer braces."
  (with-temp-buffer
    (insert bibtex)
    (bibtex-mode)
    (goto-char (point-min))
    (bibtex-skip-to-valid-entry)
    (mapcar (lambda (f)
              (cons (downcase (car f))
                    (replace-regexp-in-string "[ \t\n]+" " " (string-trim (cdr f) "[{\" \t\n]+" "[}\" \t\n]+"))))
            (bibtex-parse-entry t))))

(defun papers--plain (s)
  "S without TeX braces and accents' markup, for keys and titles."
  (string-trim (replace-regexp-in-string "[{}\\\\]\\|\\\\['`^\"~]" "" (or s ""))))

(defun papers--key (fields)
  "A citekey as Better BibTeX makes them: first author's last name, the
first three words of the title that matter, the year."
  (let* ((author (papers--plain (cdr (assoc "author" fields))))
         (first (car (split-string author " and " t)))
         (last (if (string-match-p "," (or first "")) (car (split-string first ","))
                 (car (last (split-string (or first "anon") " " t)))))
         (stop '("a" "an" "the" "is" "are" "of" "on" "in" "for" "and" "to" "with" "via" "from" "by" "at"))
         (words (seq-take (seq-remove (lambda (w) (member (downcase w) stop))
                                      (split-string (papers--plain (cdr (assoc "title" fields))) "[^[:alnum:]]+" t))
                          3)))
    (concat (downcase (replace-regexp-in-string "[^[:alnum:]]" "" (ucs-normalize-NFD-string (or last "anon"))))
            (mapconcat (lambda (w) (concat (upcase (substring w 0 1)) (substring w 1))) words "")
            (or (cdr (assoc "year" fields)) ""))))

(defun papers--existing-key (doi)
  "The key of the entry with DOI in any bibliography, or nil."
  (catch 'found
    (dolist (f (papers--bib-files))
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (when (re-search-forward (format "doi[ \t]*=[ \t]*[{\"]%s[}\"]" (regexp-quote doi)) nil t)
          (when (re-search-backward "^@[a-zA-Z]+[ \t]*{[ \t]*\\([^, \t\n]+\\)" nil t)
            (throw 'found (match-string-no-properties 1))))))))

(defun papers--key-taken-p (key)
  (seq-some (lambda (f) (with-temp-buffer (insert-file-contents f)
                          (goto-char (point-min))
                          (re-search-forward (format "^@[a-zA-Z]+[ \t]*{[ \t]*%s," (regexp-quote key)) nil t)))
            (papers--bib-files)))

(defun papers--unique-key (key)
  (let ((k key) (n ?a))
    (while (papers--key-taken-p k)
      (setq k (format "%s%c" key n) n (1+ n)))
    k))

(defun papers--format-entry (key type fields file)
  "The BibTeX entry @TYPE{KEY} with FIELDS, and FILE (if any) as its file."
  (concat "@" type "{" key ",\n"
          (mapconcat (lambda (f) (format "  %s = {%s}" (car f) (cdr f)))
                     (append (seq-remove (lambda (f) (or (string-prefix-p "=" (car f))
                                                         (equal (car f) "file")))
                                         fields)
                             (when file (list (cons "file" file))))
                     ",\n")
          "\n}\n"))

;;; The PDF

(defun papers--fetch-pdf (arxiv-id file)
  "Download ARXIV-ID's PDF to FILE.  Non-nil when it is there and a PDF."
  (ignore-errors
    (make-directory (file-name-directory file) t)
    (url-copy-file (concat "https://arxiv.org/pdf/" arxiv-id) file t)
    (if (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally file nil 0 5)
          (equal (buffer-string) "%PDF-"))
        t
      (delete-file file)
      nil)))

;;; The note

(defun papers--note-file (key)
  (expand-file-name (concat key ".org") org-roam-directory))

(defun papers--note-with-ref (key)
  "The note that has KEY in its ROAM_REFS, from the org-roam database, or nil."
  (when (fboundp 'org-roam-db-query)
    (caar (ignore-errors
            (org-roam-db-query [:select [nodes:file] :from refs
                                :inner-join nodes :on (= refs:node-id nodes:id)
                                :where (= refs:ref $s1)]
                               key)))))

(defun papers-write-note (key title pdf)
  "Make notes/KEY.org for the paper KEY titled TITLE, PDF (a file, or nil)
its NOTER_DOCUMENT, and ask why this paper.  Returns the file."
  (let ((file (papers--note-file key)))
    (unless (file-exists-p file)
      (let ((why (string-trim (read-string (format "Why \"%s\" — what do you want from it? (empty: skip) " title)))))
        (with-temp-file file
          (insert ":PROPERTIES:\n"
                  (format ":ID:       %s\n" (org-id-new))
                  (format ":ROAM_REFS: @%s\n" key)
                  (if pdf (format ":NOTER_DOCUMENT: %s\n" (file-relative-name pdf (file-name-directory file))) "")
                  (format ":CREATED:  %s\n" (format-time-string "[%Y-%m-%d %a %H:%M]"))
                  ":END:\n"
                  (format "#+TITLE: %s\n#+FILETAGS: :paper:\n" title)
                  (if (string-empty-p why) "" (format "\n- Why I'm reading it :: %s\n" why))))
        (when (fboundp 'org-roam-db-update-file)
          (ignore-errors (org-roam-db-update-file file)))))
    file))

;;;###autoload
(defun papers-add (input)
  "Add a paper from INPUT -- a DOI, an arXiv id, or a link to either: its
entry to `papers-bib-file', its PDF (from arXiv) to the library, and its
note, which opens.  A paper already in a bibliography just opens its note."
  (interactive
   (let ((clip (ignore-errors (current-kill 0 t))))
     (list (read-string "Paper — DOI, arXiv id or link: "
                        (and clip (papers--doi clip) (string-trim clip))))))
  (let* ((doi (or (papers--doi input) (user-error "Not a DOI or arXiv id: %s" input)))
         (old (papers--existing-key doi)))
    (if old
        (progn (find-file (or (papers--note-with-ref old) (papers-write-note old old nil)))
               (message "Already in: %s" old))
      (let* ((fields (papers--parse (papers--fetch-bibtex doi)))
             (title (papers--plain (cdr (assoc "title" fields))))
             (key (papers--unique-key (papers--key fields)))
             (arxiv (papers--arxiv-id doi))
             (pdf (expand-file-name (concat key ".pdf") (papers--library)))
             (pdf (and arxiv (papers--fetch-pdf arxiv pdf) pdf))
             (bib (papers--bib-file)))
        (make-directory (file-name-directory bib) t)
        (with-temp-buffer
          (when (file-exists-p bib) (insert-file-contents bib))
          (goto-char (point-max))
          (unless (or (bobp) (looking-back "\n\n" nil)) (insert (if (bolp) "\n" "\n\n")))
          (insert (papers--format-entry key (or (cdr (assoc "=type=" fields)) "misc")
                                        (cons (cons "doi" doi) (seq-remove (lambda (f) (equal (car f) "doi")) fields))
                                        (and pdf (file-name-nondirectory pdf))))
          (write-region nil nil bib nil 'silent))
        (find-file (papers-write-note key title pdf))
        (message "Added %s: %s%s" key title
                 (if pdf "" (format " — no free PDF; put it in the library as %s.pdf" key)))))))

;;; citar's notes, made the same way

(defun papers-note (citekey entry)
  "Stands in for `citar-org-roam--create-capture-note': CITEKEY's note,
made as `papers-add' makes it, titled by the paper, not its authors."
  (let* ((title (papers--plain (or (and (fboundp 'citar-get-value) (citar-get-value "title" entry))
                                   citekey)))
         (files (and (fboundp 'citar-get-files)
                     (ignore-errors (gethash citekey (citar-get-files citekey)))))
         (pdf (seq-find (lambda (f) (string-suffix-p ".pdf" f t)) files)))
    (find-file (papers-write-note citekey title pdf))))

(with-eval-after-load 'citar-org-roam
  (advice-add 'citar-org-roam--create-capture-note :override #'papers-note))

(provide 'papers)
;;; papers.el ends here
