;;; prodigy-services.el --- Prodigy service definitions -*- lexical-binding: t; -*-

;;; Commentary:
;; Prodigy service definitions for development servers.
;; Mac-only - not needed on Android.

;;; Code:

(after! prodigy
  (prodigy-define-service
    :name "Hugo server"
    :tags '(personal)
    :port 5000
    :command "hugo"
    :args '("server" "-t")
    :cwd "~/workspace/personal/personalblog/"
    :stop-signal 'sigkill
    :kill-process-buffer-on-stop t)

  (prodigy-define-service
    :name "FastAPI Uvicorn with Direnv"
    :tags '(work)
    :command "sh"
    :args '("-c" "direnv exec . uvicorn src.optfastapi.main:app --host 0.0.0.0 --port 8080 --reload")
    :cwd "~/workspace/EHP/OptAPI/"
    :port 8080)

  (prodigy-define-service
    :name "Jarvisapi"
    :tags '(work)
    :command "sh"
    :args '("-c" "direnv exec . uvicorn src.jarvisfastapi.main:app --host 0.0.0.0 --port 9000 --reload")
    :cwd "~/workspace/EHP/JarvisAPI/"
    :port 9000))

(provide 'prodigy-services)
;;; prodigy-services.el ends here
