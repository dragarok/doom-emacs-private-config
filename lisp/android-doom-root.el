;;; android-doom-root.el --- Run `doom' on the phone, as root -*- lexical-binding: t -*-

;;; Commentary:
;; crDroid hides /system/framework/org.lineageos.*.apk from every app uid
;; (>= 10000), and batch Emacs dies building its system resources without
;; them -- so `doom sync' can't run as the app.  Root still sees the files.
;;
;; `doom-root' runs bin/doom through KernelSU's su, then hands everything
;; root created back to Emacs's user and SELinux label.  Two things make
;; that work:
;;   - `android-use-exec-loader' must be off: with it on, Emacs runs
;;     programs through its own loader and KernelSU never intercepts `su'.
;;   - the batch child needs EMACS_CLASS_PATH etc., which only this running
;;     Emacs has, so they're passed explicitly through su.
;;
;; Needs root granted to Emacs (or Termux -- same uid) in KernelSU-Next.

;;; Code:

(require 'compile)

(defconst doom-root--emacs "/data/data/org.gnu.emacs/lib/libandroid-emacs.so")
(defconst doom-root--files "/data/data/org.gnu.emacs/files")

(defun doom-root--q (s)
  "S single-quoted for /system/bin/sh."
  (concat "'" (string-replace "'" "'\\''" s) "'"))

(defun doom-root--env ()
  "Environment for the batch child, as VAR=VALUE words for `env'."
  (mapconcat
   #'doom-root--q
   (append
    (delq nil (mapcar (lambda (v) (when (getenv v) (format "%s=%s" v (getenv v))))
                      '("EMACS_CLASS_PATH" "EMACS_LD_LIBRARY_PATH" "TMPDIR")))
    (list (format "HOME=%s" doom-root--files)
          (format "EMACS=%s" doom-root--emacs)
          (concat "PATH=/data/data/com.termux/files/usr/bin:" (getenv "PATH"))))
   " "))

(defun doom-root--trust-repos ()
  "Let root's git work in repos the app user owns.
Git refuses (\"dubious ownership\") otherwise.  This goes in Termux git's
system config, not the environment: Doom's CLI can replace the whole
process environment with its saved env file, dropping anything passed
that way.  Written as the app user, which owns Termux's files."
  (unless (member "*" (process-lines-ignore-status
                       "git" "config" "--system" "--get-all" "safe.directory"))
    (call-process "git" nil nil nil "config" "--system" "--add" "safe.directory" "*")))

(defun doom-root (args)
  "Run `doom ARGS' as root, then give root's files back to Emacs."
  (interactive (list (read-string "doom (as root): " "sync")))
  (let* ((default-directory (file-name-as-directory doom-root--files))
         (label (string-trim (shell-command-to-string
                              (format "stat -c %%C %s" doom-root--files))))
         (uid (user-uid))
         ;; A script file, so the values go through one layer of quoting
         ;; instead of Emacs's shell and su's both.
         (file (expand-file-name ".doom-root.sh" doom-root--files))
         ;; Bound while `compile' starts the process: KernelSU's su is an
         ;; exec hook, which Emacs's own loader would bypass.
         (android-use-exec-loader nil))
    (with-temp-file file
      ;; bin/doom's sh half only builds this command line; run it directly
      ;; so we can tell Doom it is the app user: it aborts (exit 2) when
      ;; run as root over a non-root-owned config.
      (insert (format "env %s %s -q --no-site-file --batch \
--eval \"(fset (quote user-real-uid) (lambda () %d))\" \
--eval \"(setq warning-inhibit-types (quote ((files missing-lexbind-cookie))))\" \
--load %s/.config/emacs/bin/doom -- %s 2>&1
rc=$?
echo \"== handing files back to uid %d\"
for d in %s /data/data/org.gnu.emacs/cache; do
  find \"$d\" -user 0 -exec chcon -h %s {} +
  find \"$d\" -user 0 -exec chown -h %d:%d {} +
done
exit $rc
"
                      (doom-root--env) doom-root--emacs uid doom-root--files args uid
                      doom-root--files (doom-root--q label) uid uid)))
    (doom-root--trust-repos)
    (compile (format "su -c 'sh %s'" file))))

(provide 'android-doom-root)
;;; android-doom-root.el ends here
