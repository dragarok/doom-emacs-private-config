;;; voice-agents.el --- Voice domain: agents in Herdr and on other machines -*- lexical-binding: t -*-

;;; Commentary:
;; See voice-command.el for how the parts fit.

;;; Code:

(require 'voice-core)

(defun voice-type-to-agent (text)
  "Type TEXT into the agent's chat, without sending it."
  (claude-remote--send text)
  (format "Typed: %s" text))

(defun voice-send-to-agent ()
  "Send what is typed in the agent's chat."
  (claude-remote--send "\r")
  "Sent")

(voice-action '("open herdr" "open mac" "herdr" "mac agents") #'claude-remote-mac
              :when 'android :name "open herdr")

(voice-action '("open kai" "kai agents") #'claude-remote-kai :when 'android :name "open kai")

(voice-action '("next" "next agent" "switch to next") #'claude-remote-next-session
              :when 'remote :quiet t :name "next agent")

(voice-action '("previous" "previous agent" "back" "switch to previous") #'claude-remote-prev-session
              :when 'remote :quiet t :name "previous agent")

;; In an agent's chat, and on a photo
(voice-action '("type …" "tell claude …" "dictate …" "tell it …") #'voice-type-to-agent :slot 'text
              :when 'remote :quiet t :name "type to agent")

(voice-action '("send" "send it" "submit" "press enter" "enter") #'voice-send-to-agent
              :when 'remote :quiet t :name "send to agent")

(voice-define-domain 'agents
  :doc "Agents in Herdr and on other machines: open, flip, type, send."
  :context (lambda (_source) (and (bound-and-true-p claude-remote--machine-name) '(remote))))

(provide 'voice-agents)
;;; voice-agents.el ends here
