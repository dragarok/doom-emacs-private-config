;;; voice-rules.el --- Voice: your rules in ~/org/voice.org -*- lexical-binding: t -*-

;;; Commentary:
;; Phrases, names, sounds and words you taught it, read live, and
;; written to when a yes or a pick teaches it.

;;; Code:

(require 'voice-core)

;;;; Your rules: ~/org/voice.org

(defvar voice--rules-cache nil "(MTIME NAMES PHRASES).")

(defun voice--file ()
  (or voice-file (expand-file-name "voice.org" (or (bound-and-true-p org-directory) "~/org/"))))

(defun voice--rules ()
  "(NAMES . PHRASES) from voice.org, each an alist (SAID . MEANT)."
  (let* ((f (voice--file))
         (mtime (and (file-exists-p f) (file-attribute-modification-time (file-attributes f)))))
    (if (and mtime voice--rules-cache (equal (car voice--rules-cache) mtime))
        (cdr voice--rules-cache)
      (let ((names nil) (phrases nil) (sounds nil) (words nil) (hear nil) (section nil))
        (when mtime
          (with-temp-buffer
            (insert-file-contents f)
            (goto-char (point-min))
            (while (not (eobp))
              (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
                (cond ((string-match "\\`\\* +\\(.*?\\) *\\'" line)
                       (setq section (downcase (match-string 1 line))))
                      ((string-match "\\`[ \t]*- +\\(.*?\\) +:: +\\(.*?\\) *\\'" line)
                       (let ((pair (cons (match-string 1 line) (match-string 2 line))))
                         (pcase section
                           ("names" (push pair names))
                           ("phrases" (push pair phrases))
                           ("sounds" (push pair sounds))
                           ("words" (push pair words)))))
                      ((and (equal section "hear") (string-match "\\`[ \t]*- +\\(.*?\\) *\\'" line))
                       (push (match-string 1 line) hear))))
              (forward-line 1))))
        (setq voice-emacs-user-words (nreverse words))
        ;; What the engine should hear well: * Hear, and every word a
        ;; * Sounds line says was misheard.
        (setq voice--hear-words (append (nreverse hear) (mapcar #'cdr sounds)))
        (setq voice--user-sounds
              (mapcar (lambda (p) (cons (voice-match-stem (downcase (car p)))
                                        (voice-match-stem (downcase (cdr p)))))
                      sounds))
        (let ((rules (cons (nreverse names) (nreverse phrases))))
          (setq voice--rules-cache (cons mtime rules))
          rules)))))

(defvar voice--user-sounds nil "voice.org's * Sounds, as (HEARD . MEANT) stems.")

(defvar voice--hear-words nil
  "Words for the speech engine to hear well, from voice.org: its * Hear
list (\"- Hades 2\") and the meant side of every * Sounds line.")

(defconst voice-sounds-like
  '(("talk" . "clock") ("clerk" . "clock") ("lock" . "clock") ("clark" . "clock")
    ("glock" . "clock") ("clog" . "clock") ("ad" . "add") ("hell" . "help")
    ("grab" . "graph") ("grass" . "graph") ("graf" . "graph")
    ("hutter" . "herdr") ("herder" . "herdr") ("header" . "herdr") ("harder" . "herdr")
    ("hurdle" . "herdr") ("hirder" . "herdr") ("guy" . "kai") ("chai" . "kai") ("kye" . "kai")
    ("pie" . "kai") ("kay" . "kai") ("no" . "node") ("nod" . "node") ("reed" . "read")
    ("paw" . "pause") ("pose" . "pause") ("paus" . "pause"))
  "Words the voice app was heard to write for a command's words, HEARD .
MEANT, as stems: \"talk into messaging\" is \"clock into messaging\".  Only
command phrases use them, never task names.  Yours go under * Sounds in
`voice-file', as - heard :: meant.")

(defun voice--literal-sim (literal token)
  "How well TOKEN, heard, stands for a command's LITERAL word."
  (max (voice-match-sim literal token)
       (if (equal (cdr (or (assoc token voice--user-sounds) (assoc token voice-sounds-like))) literal)
           0.85 0.0)))

(defun voice--rewrite (text)
  "TEXT, or what voice.org's Phrases say it means."
  (let ((hit (assoc (voice-match-normalize text)
                    (mapcar (lambda (p) (cons (voice-match-normalize (car p)) (cdr p)))
                            (cdr (voice--rules))))))
    (if hit (cdr hit) text)))

(defun voice--add-rule (section said meant)
  "Add \"- SAID :: MEANT\" under SECTION (Names, Phrases) in voice.org,
unless SAID is there already.  Return what to tell, or nil."
  (when (and voice-learn said meant (not (string-empty-p said))
             (not (equal (voice-match-normalize said) (voice-match-normalize meant)))
             (not (assoc (voice-match-normalize said)
                         (mapcar (lambda (n) (cons (voice-match-normalize (car n)) n))
                                 (if (equal section "Names") (car (voice--rules)) (cdr (voice--rules)))))))
    (let* ((f (voice--file))
           (line (format "- %s :: %s\n" said meant))
           (buf (find-buffer-visiting f)))
      (with-current-buffer (or buf (find-file-noselect f t))
        (save-excursion
          (goto-char (point-min))
          (when (= (point-min) (point-max))
            (insert "#+TITLE: Voice\n\nOther names for tasks; a pick from the voice list adds one.\n"
                    "* Names\n* Phrases\nSay the left, mean the right.\n"))
          (goto-char (point-min))
          (unless (re-search-forward (format "^\\* %s[ \t]*$" (regexp-quote section)) nil t)
            (goto-char (point-max)) (unless (bolp) (insert "\n")) (insert (format "* %s\n" section)))
          (forward-line 1)
          (while (and (not (eobp)) (not (looking-at "^\\*"))) (forward-line 1))
          (unless (bolp) (insert "\n"))
          (insert line))
        (let ((save-silently t)) (save-buffer))
        (unless buf (kill-buffer)))
      (setq voice--rules-cache nil)
      (format "learned \"%s\"" said))))

(defun voice--sounds-like-command-p (said)
  "Non-nil when SAID is near enough a command to be asked about: then it
is no other name for a task."
  (let ((near (car (voice--near-actions (voice--words said) (voice--all-actions (voice-context "island"))))))
    (and near (>= (car near) voice-ask-score))))

(defun voice--learn-name (said title)
  "Add \"- SAID :: TITLE\" under Names in voice.org, unless SAID is there,
or sounds like a command (\"stop him is tagging\" is not Image Tagging)."
  (unless (voice--sounds-like-command-p said)
    (voice--add-rule "Names" said title)))

(provide 'voice-rules)
;;; voice-rules.el ends here
