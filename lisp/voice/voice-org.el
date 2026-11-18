;;; voice-org.el --- Voice domain: your days -- reviews, diary, agenda, notes -*- lexical-binding: t -*-

;;; Commentary:
;; See voice-command.el for how the parts fit.

;;; Code:

(require 'voice-core)

;;;; What to say

(defun voice-diary ()
  "A diary line, through the diary template; its question is answered
from what was said."
  (org-capture nil "d")
  (when (bound-and-true-p org-capture-mode) (org-capture-finalize))
  "Added to the diary")

(voice-action '("flow" "what next" "what should i do") #'rts-flow :name "flow")

(voice-action '("review" "daily review" "write the review") #'day-log-review :name "review")

(voice-action '("attach camera photo" "attach a photo" "take a photo" "camera photo" "attach camera")
              #'my/org-attach-media :when 'android :name "camera photo")

(voice-action '("attach latest photo" "attach the latest" "attach screenshot" "attach last photo")
              #'my/org-attach-media :when 'android :name "latest photo")

(voice-action '("agenda" "open agenda" "my agenda") #'my-org-agenda :name "agenda")

(voice-action '("graph" "show the graph" "open graph" "note graph") #'org-roam-ui-open :name "graph")

(voice-action '("reread" "re read" "read again" "today's note") #'note-flow-reread :name "reread")

(voice-action '("diary" "photo diary" "browse photos") #'my/diary-browse-images :name "photo diary")

(voice-action '("neglect" "neglect report" "what am i neglecting") #'rts-flow-weekly-neglect-report
              :name "neglect")

(voice-action '("dailies" "daily notes") #'my/org-roam-dailies-cycle-focus :name "dailies")

(voice-action '("log" "daily note" "open log" "open the log") #'micro-experiments-log :name "log")

(voice-action '("find note …" "find node …" "open note …" "go to note …" "note called …") #'org-roam-node-find
              :asks '((:prompt "\\`Node" :type rest)) :name "find note")

(voice-action '("today" "today's view" "today view" "my day") (lambda () (org-agenda nil "k")) :name "today")

;; Planning
(voice-action '("walk" "walk tasks" "date tasks" "undated tasks") #'org-flow-date-undated :name "walk tasks")

(voice-action '("plan tomorrow" "time box tomorrow" "timebox tomorrow" "timebox") #'timebox-tomorrow
              :name "plan tomorrow")

(voice-action '("weekly review") (lambda () (org-capture nil "rw")) :name "weekly review")

(voice-action '("monthly review") (lambda () (org-capture nil "rm")) :name "monthly review")

(voice-action '("motto …" "set motto …" "set a motto …") (lambda () (org-capture nil "m"))
              :asks '((:prompt "diary entry" :type rest)) :name "motto")

(voice-action '("diary …" "dear diary …" "diary entry …" "write in diary …") #'voice-diary
              :asks '((:prompt "diary entry" :type rest)) :name "diary")

(provide 'voice-org)
;;; voice-org.el ends here
