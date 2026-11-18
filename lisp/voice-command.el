;;; voice-command.el --- Say it, and Emacs does it -*- lexical-binding: t -*-

;;; Commentary:
;; Speak, and Emacs does the closest thing: clock in to a task, clock out,
;; add a task, answer the question on screen, or run a command.
;;
;; On the phone the words come from the voice app (FUTO, offline) through
;; Emacs Home: the toolbar's Voice button, or a long press on the clock
;; island from any app.  The app writes what it heard to voice-heard.tsv
;; and calls `voice-from-app'.  Anywhere, `voice-command' (SPC V) takes
;; typed words the same way.
;;
;; One pattern for everything: an action is a few phrases and a command.
;;   (voice-action '("clock in to …" "start …") #'voice-clock-in :slot 'task)
;; "…" is the rest of what was said.  When the command asks something, a
;; question already answered in the sentence is filled in -- "done, deep
;; work" answers rts-flow-clock-out's question, "attach camera photo" picks
;; [c]amera -- and the rest are asked, as always, in the minibuffer.  Any
;; open question can be answered by voice too: a choice by its name or
;; "the second one", free text as said.  So most commands work by voice
;; with no voice code, and an action names only what it needs.
;;
;; Toolbar buttons and homepage tiles are actions already, by their labels.
;; Every other command is found by what it is called (voice-emacs.el):
;; its name, what its key says, the words that mean the same, and what it
;; asks for -- "change theme to tango dark" runs load-theme with tango-dark,
;; "change theme" opens the themes to say which.  A command named clearly
;; runs; a near one is asked about; else the closest open to pick from.
;; A yes or a pick is learned in voice.org.
;;
;; Spoken words are data.  They only pick an action from this list, or a
;; task; they are never read as Lisp.  No link opens the microphone.
;;
;; How it is built (lisp/voice/):
;;   heard ──> words (voice-core) ──> rewritten by your rules (voice-rules)
;;         ──> weighed and decided (voice-plan): do, ask, or show the closest
;;         ──> done, questions filled from the sentence (voice-fill)
;;         ──> asked about, answered (voice-dialog) ──> learned (voice-rules)
;;         ──> logged (voice-log).  Words come in through voice-app.
;; Domains add what can be said: voice-tasks (tasks, the clock),
;; voice-org (reviews, diary, notes), voice-everyday (buffers, files,
;; moving), voice-agents, voice-photos, voice-home (toolbar and tiles),
;; voice-anycommand (every command, via voice-emacs.el), voice-help.
;; A new domain is a file of `voice-action's, added to `voice-modules'.
;;
;; Rules you edit live in ~/org/voice.org: "* Names" (another name for a
;; task; a pick from the list adds one), "* Phrases" (say this, mean
;; that), "* Sounds" (heard this, a command's word meant) and "* Words" (a
;; word meaning another in command names).  Every utterance is logged to
;; ~/org/logs/voice_log_HOST.tsv.

;;; Code:

(add-to-list 'load-path (expand-file-name "voice" (file-name-directory
                                                   (or load-file-name buffer-file-name))))

(defconst voice-modules
  '(;; The core: hearing, deciding, asking, doing, learning, logging.
    voice-core voice-rules voice-fill voice-dialog voice-plan voice-log voice-app voice-engine
    ;; Domains: what can be said.
    voice-home voice-tasks voice-everyday voice-org voice-agents voice-photos
    voice-help voice-anycommand)
  "The parts of voice, in the order they load (lisp/voice/).")

(mapc #'require voice-modules)

(provide 'voice-command)
;;; voice-command.el ends here
