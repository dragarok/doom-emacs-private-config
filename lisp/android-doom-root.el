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

(defun doom-root--env ()
  "Environment for the batch child, as VAR=VALUE words for `env'."
  (mapconcat
   #'shell-quote-argument
   (append
    (delq nil (mapcar (lambda (v) (when (getenv v) (format "%s=%s" v (getenv v))))
                      '("EMACS_CLASS_PATH" "EMACS_LD_LIBRARY_PATH" "TMPDIR")))
    (list (format "HOME=%s" doom-root--files)
          (format "EMACS=%s" doom-root--emacs)
          (concat "PATH=/data/data/com.termux/files/usr/bin:" (getenv "PATH"))
          ;; Root running git over repos owned by the app uid.
          "GIT_CONFIG_COUNT=1" "GIT_CONFIG_KEY_0=safe.directory" "GIT_CONFIG_VALUE_0=*"))
   " "))

(defun doom-root (args)
  "Run `doom ARGS' as root, then give root's files back to Emacs."
  (interactive (list (read-string "doom (as root): " "sync")))
  (let* ((default-directory (file-name-as-directory doom-root--files))
         (label (string-trim (shell-command-to-string
                              (format "stat -c %%C %s" doom-root--files))))
         (uid (user-uid))
         (script
          (format "env %s sh %s/.config/emacs/bin/doom %s; rc=$?; \
echo '== handing files back to uid %d'; \
find %s -user 0 -exec chcon -h %s {} + ; \
find %s -user 0 -exec chown -h %d:%d {} + ; \
exit $rc"
                  (doom-root--env) doom-root--files args uid
                  doom-root--files (shell-quote-argument label)
                  doom-root--files uid uid))
         ;; Bound while `compile' starts the process: KernelSU's su is an
         ;; exec hook, which Emacs's own loader would bypass.
         (android-use-exec-loader nil))
    (compile (format "su -c %s" (shell-quote-argument script)))))

(provide 'android-doom-root)
;;; android-doom-root.el ends here
