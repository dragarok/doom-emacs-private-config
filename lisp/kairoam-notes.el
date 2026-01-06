;;; kairoam-notes.el --- Horizontal evergreen notes for org-roam -*- lexical-binding: t; -*-

;; Author: kairoam (adapted for user)
;; Version: 0.1
;; Keywords: notes, org, org-roam, convenience
;; Package-Requires: ((emacs "27.1") (org-roam "2.0"))
;; Compatible with Doom Emacs (uses core libs only)

;;; Commentary:
;; Single-file implementation of an "evergreen" notes UI with mobile/laptop modes:
;; - Laptop mode: opens notes side-by-side (horizontal splits)
;; - Mobile mode: opens notes top-to-bottom (vertical splits)
;; - inserts new notes at current+1
;; - keeps up to `kairoam-max-expanded-windows' expanded (default 3)
;; - folds the farthest expanded window when needed
;; - folded windows show title overlay (vertical in laptop, horizontal in mobile)
;; - never reuses existing windows (always creates a new split)
;;
;; Key commands:
;;  C-c k r      kairoam-open-note-to-right (right in laptop, below in mobile)
;;  C-c k l      kairoam-open-at-point
;;  C-c k f      kairoam-fold-window
;;  C-c k e      kairoam-expand-window
;;  C-c k d      kairoam-debug
;;  C-c k t      kairoam-toggle-layout-mode (switch between mobile/laptop)
;;  C-c k m      kairoam-mobile-mode (set mobile mode)
;;  C-c k L      kairoam-laptop-mode (set laptop mode)
;;  C-c k R      kairoam-reset (reset and disable mode, C-u to kill buffers)
;;  C-c k K      kairoam-kill-all-buffers (reset and kill all tracked buffers)

;;; Code:

(require 'cl-lib)
(require 'subr-x)
;; doom typically already loads dash/s, but we don't rely on them explicitly.


;;; Configuration and simple logging

(defgroup kairoam nil
  "Kairoam evergreen-style org-roam panes."
  :group 'convenience)

(defcustom kairoam-layout-mode 'laptop
  "Layout mode: 'laptop for side-by-side (horizontal split), 'mobile for top-bottom (vertical split)."
  :type '(choice (const :tag "Laptop (side-by-side)" laptop)
          (const :tag "Mobile (top-bottom)" mobile))
  :group 'kairoam)

(defcustom kairoam-folded-width 5
  "Width (columns) for folded windows in laptop mode (thin column)."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-folded-height 1
  "Height (lines) for folded windows in mobile mode (thin row)."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-max-expanded-windows 3
  "Maximum number of expanded (full-content) windows to show at once."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-default-expanded-width 80
  "Fallback width to use when calculating expanded window sizes in laptop mode."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-default-expanded-height 30
  "Fallback height to use when calculating expanded window sizes in mobile mode."
  :type 'integer
  :group 'kairoam)

(defcustom kairoam-max-title-length 40
  "Maximum length for vertical titles in folded windows. Longer titles will be truncated."
  :type 'integer
  :group 'kairoam)

(defvar kairoam--log-buffer "*kairoam-log*")
(defun kairoam--log (lvl fmt &rest args)
  "Simple logger: LVL (string), FMT and ARGS."
  (let ((msg (apply #'format fmt args))
        (ts (format-time-string "%H:%M:%S")))
    (with-current-buffer (get-buffer-create kairoam--log-buffer)
      (goto-char (point-max))
      (insert (format "[%s] [%s] %s\n" ts lvl msg)))))

(defun kairoam--info (fmt &rest args) (apply #'kairoam--log "INFO" fmt args))
(defun kairoam--warn (fmt &rest args) (apply #'kairoam--log "WARN" fmt args))
(defun kairoam--error (fmt &rest args) (apply #'kairoam--log "ERR" fmt args))


;;; Core data structure: cl-defstruct for tracked windows

(cl-defstruct kairoam-window
  window    ;; the window object
  buffer    ;; buffer shown
  position  ;; integer position in sequence
  state     ;; 'expanded or 'folded
  overlay   ;; overlay object if folded
  line-numbers-mode-state) ;; original state of display-line-numbers-mode

(defvar kairoam--registry nil
  "Ordered list (vector-like) of `kairoam-window' structs representing sequence 0..n-1.")

(defun kairoam--registry-reset () (setq kairoam--registry nil))
(defun kairoam--registry-count () (length kairoam--registry))

(defun kairoam--find-by-window (win)
  "Return state struct for WIN, or nil."
  (cl-find-if (lambda (s) (and (kairoam-window-window s)
                               (eq (kairoam-window-window s) win)))
              kairoam--registry))

(defun kairoam--find-by-buffer (buf)
  (cl-find-if (lambda (s) (eq (kairoam-window-buffer s) buf))
              kairoam--registry))

(defun kairoam--position-of-window (win)
  (let ((s (kairoam--find-by-window win)))
    (and s (kairoam-window-position s))))

(defun kairoam--rebuild-positions ()
  "Rebuild positions in kairoam--registry so they are sequential 0..n-1."
  (cl-loop for i from 0
           for s in kairoam--registry
           do (setf (kairoam-window-position s) i))
  (kairoam--info "Rebuilt positions; total=%d" (kairoam--registry-count)))

(defun kairoam--register-new (win buf pos)
  "Insert new kairoam-window for WIN and BUF at POS, shifting following entries."
  (let ((new (make-kairoam-window :window win :buffer buf :position pos :state 'expanded 
                                  :overlay nil :line-numbers-mode-state nil)))
    (if (>= pos (kairoam--registry-count))
        (setq kairoam--registry (append kairoam--registry (list new)))
      (setq kairoam--registry
            (append (cl-subseq kairoam--registry 0 pos)
                    (list new)
                    (cl-subseq kairoam--registry pos)))
      (kairoam--rebuild-positions)
      (kairoam--info "Registered new window pos=%d buf=%s" pos (buffer-name buf))
      new)))

(defun kairoam--unregister-window (win)
  "Remove window WIN from registry and cleanup overlay if present."
  (let ((s (kairoam--find-by-window win)))
    (when s
      (when (kairoam-window-overlay s)
        (ignore-errors (delete-overlay (kairoam-window-overlay s))))
      (setq kairoam--registry (cl-remove s kairoam--registry :test #'eq))
      (kairoam--rebuild-positions)
      (kairoam--info "Unregistered window %s" (prin1-to-string win)))))

(defun kairoam--cleanup-dead ()
  "Remove entries whose window or buffer is dead."
  (let ((removed 0))
    (setq kairoam--registry
          (cl-remove-if
           (lambda (s)
             (let ((w (kairoam-window-window s))
                   (b (kairoam-window-buffer s)))
               (unless (and (windowp w) (window-live-p w) (bufferp b) (buffer-live-p b))
                 (cl-incf removed)
                 (when (kairoam-window-overlay s)
                   (ignore-errors (delete-overlay (kairoam-window-overlay s))))
                 t)))
           kairoam--registry))
    (when (> removed 0) (kairoam--info "Cleaned up %d dead registry entries" removed))
    (kairoam--rebuild-positions)
    removed))


;;; Helpers: title extraction, vertical title display

(defun kairoam--buffer-title (buf)
  "Return title for BUF. Try #+TITLE:, then first heading, then buffer name."
  (with-current-buffer buf
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (or 
         ;; Try #+TITLE: (case insensitive)
         (when (re-search-forward "^#\\+\\(?:TITLE\\|title\\|Title\\):\\s-*\\(.*\\)$" nil t)
           (string-trim (match-string 1)))
         ;; Try first level-1 org heading
         (progn
           (goto-char (point-min))
           (when (re-search-forward "^\\* \\(.+\\)$" nil t)
             (string-trim (match-string 1))))
         ;; Fallback to buffer name without extension
         (file-name-sans-extension (buffer-name buf)))))))

(defun kairoam--verticalize (s)
  "Return a string with S vertically (each char on its own line) with org-level-1 styling."
  (mapconcat (lambda (c) 
               (propertize (string c) 
                           'face '(:inherit org-level-1 :height 1.1 :weight bold)))
             (string-to-list s) "\n"))

(defun kairoam--horizontalize (s)
  "Return a styled horizontal title string for mobile mode."
  (propertize s 'face '(:inherit org-level-1 :height 1.2 :weight bold)))

(defun kairoam--make-title-overlay (buf title)
  "Create an overlay in BUF that displays TITLE.
In laptop mode: displays vertically centered.
In mobile mode: displays horizontally centered."
  (with-current-buffer buf
    (save-excursion
      (goto-char (point-min))
      ;; Ensure buffer has content to overlay (needed for empty buffers)
      (when (eobp)
        (insert " "))
      (let* ((win (get-buffer-window buf))
             (mobile-mode (eq kairoam-layout-mode 'mobile))
             ;; Truncate title if too long
             (truncated-title (if (> (length title) kairoam-max-title-length)
                                  (concat (substring title 0 (- kairoam-max-title-length 3)) "...")
                                title))
             (ov (make-overlay (point-min) (point-max)))
             display-content)
        (kairoam--info "Creating overlay for %s in %s mode" title (if mobile-mode "mobile" "laptop"))
        (if mobile-mode
            ;; Mobile mode: horizontal title centered on single line
            (let* ((w (if win (window-width win) 80))
                   (title-len (length truncated-title))
                   (padding-spaces (max 0 (/ (- w title-len) 2)))
                   (left-padding (make-string padding-spaces ?\s))
                   (horizontal-title (kairoam--horizontalize truncated-title)))
              ;; Just show title on one line for compact folded view
              (setq display-content (concat left-padding horizontal-title)))
          ;; Laptop mode: vertical title centered
          (let* ((h (if win (window-height win) 20))
                 (padding-lines (max 1 (/ h 4)))
                 (top-padding (make-string padding-lines ?\n))
                 (vertical-title (kairoam--verticalize truncated-title)))
            (setq display-content (concat top-padding vertical-title))))
        ;; Cover entire buffer content with styled title
        (overlay-put ov 'display display-content)
        (overlay-put ov 'kairoam-title t)
        (overlay-put ov 'priority 100) ; Ensure it's on top
        ov))))

(defun kairoam--remove-title-overlay (buf)
  (with-current-buffer buf
    (remove-overlays (point-min) (point-max) 'kairoam-title t)))


;;; Window (fold/expand) resizing functions

(defun kairoam--safe-window-width (win)
  (condition-case _err
      (window-width win)
    (error kairoam-folded-width)))

(defun kairoam--safe-window-height (win)
  (condition-case _err
      (window-height win)
    (error kairoam-folded-height)))

(defun kairoam--resize-window-to (win desired-size &optional vertical)
  "Resize WIN to DESIRED-SIZE (columns or lines based on VERTICAL flag).
  If VERTICAL is non-nil, resize height, otherwise resize width."
  (when (and (windowp win) (window-live-p win))
    (let* ((cur (if vertical 
                    (kairoam--safe-window-height win)
                  (kairoam--safe-window-width win)))
           (delta (- desired-size cur)))
      (when (/= delta 0)
        ;; Try multiple resize strategies in order of preference
        (condition-case err1
            ;; Strategy 1: Use adjust-window-trailing-edge
            (adjust-window-trailing-edge win delta (not vertical))
          (error 
           ;; Strategy 2: Select window first, then resize
           (condition-case err2
               (with-selected-window win
                 (window-resize win delta (not vertical)))
             (error 
              ;; Strategy 3: Use shrink/enlarge commands with selected window
              (condition-case err3
                  (with-selected-window win
                    (if vertical
                        (if (> delta 0)
                            (enlarge-window delta)
                          (shrink-window (- delta)))
                      (if (> delta 0)
                          (enlarge-window-horizontally delta)
                        (shrink-window-horizontally (- delta)))))
                (error
                 ;; Strategy 4: Try with ignore flag to bypass size constraints
                 (condition-case err4
                     (with-selected-window win
                       (window-resize win delta (not vertical) t))
                   (error 
                    (kairoam--warn "All resize strategies failed for window %s: %s" 
                                   (prin1-to-string win) 
                                   (error-message-string err4))))))))))))))

(defun kairoam--distribute-sizes ()
  "Compute and set sizes for all tracked windows based on layout mode.
In laptop mode: distributes widths horizontally.
In mobile mode: distributes heights vertically."
  (kairoam--cleanup-dead)
  (let* ((entries kairoam--registry)
         (expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) entries))
         (folded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'folded)) entries))
         (mobile-mode (eq kairoam-layout-mode 'mobile))
         (frame-size (if mobile-mode (frame-height) (frame-width)))
         (folded-size (if mobile-mode kairoam-folded-height kairoam-folded-width))
         (folded-total (* (length folded) folded-size))
         (available (max 1 (- frame-size folded-total)))
         (nexp (max 1 (length expanded)))
         (per-expanded (max 10 (floor (/ available nexp))))) ;; target size for expanded windows
    
    ;; First pass: Force folded windows to their exact size
    (dolist (s folded)
      (let ((win (kairoam-window-window s)))
        (when (and (windowp win) (window-live-p win))
          (let ((attempts 0)
                (current-size (if mobile-mode 
                                  (window-height win)
                                (window-width win))))
            (while (and (< attempts 3)
                        (/= current-size folded-size))
              (kairoam--resize-window-to win folded-size mobile-mode)
              (setq current-size (if mobile-mode 
                                     (window-height win)
                                   (window-width win)))
              (setq attempts (1+ attempts)))))))
    
    ;; Second pass: Resize expanded windows and ensure equal distribution
    (let ((remaining-size available)
          (remaining-windows (length expanded)))
      (dolist (s expanded)
        (let* ((win (kairoam-window-window s))
               (target-size (if (= remaining-windows 1)
                                remaining-size
                              per-expanded)))
          (when (and (windowp win) (window-live-p win))
            (kairoam--resize-window-to win target-size mobile-mode)
            (setq remaining-size (- remaining-size target-size))
            (setq remaining-windows (1- remaining-windows))))))
    
    ;; Third pass: Fine-tune expanded windows to ensure they're actually equal
    (when (> (length expanded) 1)
      (let* ((actual-sizes (mapcar (lambda (s) 
                                     (let ((w (kairoam-window-window s)))
                                       (if mobile-mode
                                           (window-height w)
                                         (window-width w))))
                                   expanded))
             (avg-size (/ (apply #'+ actual-sizes) (length actual-sizes))))
        ;; If sizes vary too much, try to equalize them
        (when (> (- (apply #'max actual-sizes) (apply #'min actual-sizes)) 2)
          (dolist (s expanded)
            (let ((win (kairoam-window-window s)))
              (when (and (windowp win) (window-live-p win))
                (kairoam--resize-window-to win avg-size mobile-mode)))))))
    
    ;; Final pass: Double-check folded windows stayed at minimum size
    (dolist (s folded)
      (let ((win (kairoam-window-window s)))
        (when (and (windowp win) (window-live-p win))
          (let ((current-size (if mobile-mode
                                  (window-height win)
                                (window-width win))))
            (when (/= current-size folded-size)
              (kairoam--resize-window-to win folded-size mobile-mode))))))
    
    (kairoam--info "Distributed sizes (%s mode): expanded=%d folded=%d frame=%d per=%d"
                   (if mobile-mode "mobile" "laptop")
                   (length expanded) (length folded) frame-size per-expanded)))


;;; Folding / expanding

(defun kairoam--fold-window-internal (win)
  "Internal: Fold WIN without triggering redistribution. Returns the state struct."
  (let* ((s (kairoam--find-by-window win))
         (buf (window-buffer win)))
    ;; ensure tracked
    (unless s (setq s (kairoam--register-new win buf (kairoam--registry-count))))
    ;; set state
    (setf (kairoam-window-state s) 'folded)
    ;; Save and disable line numbers
    (with-current-buffer buf
      (setf (kairoam-window-line-numbers-mode-state s) 
            (if (bound-and-true-p display-line-numbers-mode) t
              (if display-line-numbers t nil)))
      (setq-local display-line-numbers nil))
    ;; overlay
    (when (kairoam-window-overlay s)
      (ignore-errors (delete-overlay (kairoam-window-overlay s))))
    (let ((title (kairoam--buffer-title buf)))
      (setf (kairoam-window-overlay s) (kairoam--make-title-overlay buf title)))
    (kairoam--info "Folded window pos=%s title=%s" (kairoam-window-position s) (kairoam--buffer-title buf))
    s))

(defun kairoam-fold-window (&optional win)
  "Fold WIN (defaults to selected-window). Create vertical title overlay and shrink width."
  (interactive)
  (let* ((win (or win (selected-window)))
         (s (kairoam--fold-window-internal win)))
    ;; resize and distribute
    (kairoam--distribute-sizes)
    s))

(defun kairoam-expand-window (&optional win)
  "Expand WIN (defaults to selected-window). Remove overlay and mark expanded.
Enforces max-expanded-windows limit by folding farthest windows if needed."
  (interactive)
  (let* ((win (or win (selected-window)))
         (s (kairoam--find-by-window win))
         (buf (window-buffer win)))
    (unless s (user-error "Window not tracked by kairoam"))
    ;; Mark as expanded
    (setf (kairoam-window-state s) 'expanded)
    ;; Restore line numbers to their original state
    (with-current-buffer buf
      (let ((saved-state (kairoam-window-line-numbers-mode-state s)))
        (when saved-state
          (setq-local display-line-numbers (if (eq saved-state t) t nil)))))
    ;; Remove ALL overlays to ensure buffer content is visible
    (when (kairoam-window-overlay s)
      (delete-overlay (kairoam-window-overlay s))
      (setf (kairoam-window-overlay s) nil))
    (with-current-buffer buf
      (kairoam--remove-title-overlay buf)
      ;; Force window to show buffer content
      (set-window-buffer win buf))
    (kairoam--info "Expanded window pos=%s title=%s" (kairoam-window-position s) (kairoam--buffer-title buf))
    ;; Apply max-expanded rule (this does batch folding without redistribution)
    (kairoam--apply-max-expanded-rule (kairoam-window-position s))
    ;; Single redistribution after all state changes are complete
    (kairoam--distribute-sizes)
    ;; Select the expanded window
    (select-window win)
    s))


;;; Smart-folding algorithm (distance-based)

(defun kairoam--farthest-expanded-from (pos)
  "Return the kairoam-window struct (expanded) farthest from POS, or nil."
  (let ((expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) kairoam--registry))
        farthest bestd)
    (dolist (s expanded)
      (let* ((p (kairoam-window-position s))
             (d (abs (- p pos))))
        (when (or (null bestd) (> d bestd))
          (setq bestd d farthest s))))
    farthest))

(defun kairoam--apply-max-expanded-rule (trigger-pos)
  "Ensure no more than `kairoam-max-expanded-windows' expanded windows. Fold farthest ones.
Returns t if any windows were folded, nil otherwise."
  (let ((expanded (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) kairoam--registry))
        (folded-any nil))
    (when (> (length expanded) kairoam-max-expanded-windows)
      (let ((excess (- (length expanded) kairoam-max-expanded-windows)))
        (dotimes (_ excess)
          (let ((f (kairoam--farthest-expanded-from trigger-pos)))
            (when f
              ;; Use internal fold to avoid redistribution until all folding is done
              (kairoam--fold-window-internal (kairoam-window-window f))
              (setq folded-any t))))))
    folded-any))


;;; Opening notes and smart insertion

(defun kairoam--open-node-at-position (node position)
  "Open org-roam NODE at POSITION (insert at current+1 semantics). Returns new window."
  (unless node (user-error "Node missing"))
  (let* ((file (if (fboundp 'org-roam-node-file) (org-roam-node-file node)
                 (error "org-roam node-file accessor missing")))
         (buf (find-file-noselect file))
         ;; reference window: if inserting at pos>0, use window at pos-1 as anchor, else use selected-window
         (ref-win (if (and (> position 0)
                           (< (1- position) (kairoam--registry-count)))
                      (kairoam-window-window (nth (1- position) kairoam--registry))
                    (selected-window)))
         ;; split direction based on layout mode
         (split-dir (if (eq kairoam-layout-mode 'mobile) 'below 'right))
         new-win)
    (setq new-win (split-window ref-win nil split-dir))
    (with-selected-window new-win
      (switch-to-buffer buf))
    (kairoam--register-new new-win buf position)
    new-win))

(defun kairoam--open-node-with-smart-folding (node pos trigger-pos)
  "Open NODE at pos and apply smart folding using trigger-pos. 
If node's buffer is already open in a kairoam window, expand that window instead."
  (let* ((file (if (fboundp 'org-roam-node-file) 
                   (org-roam-node-file node)
                 (error "org-roam node-file accessor missing")))
         (buf (find-file-noselect file))
         (existing (kairoam--find-by-buffer buf)))
    (if existing
        ;; Buffer already tracked - just expand it and select it
        (progn
          (kairoam--info "Buffer %s already open at pos %d, expanding it" 
                         (buffer-name buf) (kairoam-window-position existing))
          (let ((win (kairoam-window-window existing)))
            (when (eq (kairoam-window-state existing) 'folded)
              (kairoam-expand-window win))
            (select-window win)
            win))
      ;; Not already open - create new window (starts as expanded)
      (let ((new (kairoam--open-node-at-position node pos)))
        ;; Apply max-expanded rule BEFORE counting the new window
        ;; Use the new position as trigger to keep it expanded
        (kairoam--apply-max-expanded-rule pos)
        (kairoam--distribute-sizes)
        ;; Make sure the new window stays expanded and visible
        (with-selected-window new
          (kairoam--remove-title-overlay buf))
        new))))

;;; Public interactive: open via consult or org-roam

(defun kairoam-open-note-to-right ()
  "Interactive: open a node to the right/below current window (based on layout mode)."
  (interactive)
  (kairoam--cleanup-dead)
  (let* ((cur-win (selected-window))
         (cur-pos (kairoam--position-of-window cur-win)))
    (unless cur-pos
      ;; If current not tracked, start a new sequence with current at 0
      (kairoam--register-new cur-win (window-buffer cur-win) 0)
      (setq cur-pos 0))
    (let ((new-pos (1+ cur-pos)) node)
      (condition-case _err
          (cond
           ((fboundp 'consult-org-roam-file)
            (setq node (consult-org-roam-file)))
           (t
            (setq node (org-roam-node-read))))
        (error (user-error "Failed to select node")))
      (when node
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))

(defun kairoam-open-note-to-left ()
  "Open a node to the left/above current window (based on layout mode)."
  (interactive)
  (kairoam--cleanup-dead)
  (let* ((cur-win (selected-window))
         (cur-pos (kairoam--position-of-window cur-win)))
    (unless cur-pos
      (kairoam--register-new cur-win (window-buffer cur-win) 0)
      (setq cur-pos 0))
    (let ((new-pos cur-pos) node)
      (condition-case _err
          (cond
           ((fboundp 'consult-org-roam-file)
            (setq node (consult-org-roam-file)))
           (t
            (setq node (org-roam-node-read))))
        (error (user-error "Failed to select node")))
      (when node
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))

(defun kairoam-open-at-point ()
  "Open org-roam link at point (id link) to the right of current."
  (interactive)
  (kairoam--cleanup-dead)
  (let ((ctx (condition-case nil (org-element-context) (error nil))))
    (unless (and ctx (eq (org-element-type ctx) 'link) (string= (org-element-property :type ctx) "id"))
      (user-error "No org id link at point"))
    (let* ((id (org-element-property :path ctx))
           (node (condition-case nil (org-roam-node-from-id id) (error nil))))
      (unless node (user-error "Could not find node for id %s" id))
      (let* ((cur-pos (or (kairoam--position-of-window (selected-window))
                          (progn (kairoam--register-new (selected-window) (current-buffer) 0) 0)))
             (new-pos (1+ cur-pos)))
        (kairoam--open-node-with-smart-folding node new-pos cur-pos)))))


;;; Utilities / debug / health

(defun kairoam-debug ()
  "Show simple debug info in message and log buffer."
  (interactive)
  (kairoam--cleanup-dead)
  (let ((lines (mapcar (lambda (s)
                         (format "pos=%d state=%s buf=%s win=%s"
                                 (kairoam-window-position s)
                                 (kairoam-window-state s)
                                 (kairoam--buffer-title (kairoam-window-buffer s))
                                 (prin1-to-string (kairoam-window-window s))))
                       kairoam--registry)))
    (kairoam--info "=== kairoam-debug begin ===")
    (dolist (l lines) (kairoam--info "%s" l))
    (kairoam--info "=== kairoam-debug end ===")
    (when lines (message "kairoam: %s" (string-join (cl-subseq lines 0 (min 4 (length lines))) " | ")))))

(defun kairoam-health-check ()
  "Run basic sanity checks and attempt repairs."
  (interactive)
  ;; ensure limited number of entries
  (kairoam--cleanup-dead)
  (kairoam--rebuild-positions)
  (kairoam--distribute-sizes)
  (message "kairoam: health-check complete"))


;;; Advice for seamless integration with Doom's +org/dwim-at-point

(defun kairoam--advice-dwim-at-point (orig-fn &optional arg)
  "Advice for +org/dwim-at-point to use kairoam for ID links when kairoam-mode is active."
  (if (and kairoam-mode
           (let ((ctx (ignore-errors (org-element-context))))
             (and ctx 
                  (eq (org-element-type ctx) 'link)
                  (string= (org-element-property :type ctx) "id"))))
      ;; We're in kairoam-mode and on an ID link - use kairoam's handler
      (kairoam-open-at-point)
    ;; Otherwise use the original function
    (funcall orig-fn arg)))

(defun kairoam--advice-org-open-at-mouse (orig-fn &optional arg)
  "Advice for org-open-at-mouse to use kairoam for ID links when kairoam-mode is active."
  (if (and kairoam-mode
           (let ((ctx (ignore-errors (org-element-context))))
             (and ctx 
                  (eq (org-element-type ctx) 'link)
                  (string= (org-element-property :type ctx) "id"))))
      ;; We're in kairoam-mode and on an ID link - use kairoam's handler
      (kairoam-open-at-point)
    ;; Otherwise use the original function
    (funcall orig-fn arg)))
;;; Minor mode & keymap
;;; Minor mode & keymap

(defvar kairoam-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "C-c k r") #'kairoam-open-note-to-right)
    (define-key m (kbd "C-c k l") #'kairoam-open-at-point)
    (define-key m (kbd "C-c k f") #'kairoam-fold-window)
    (define-key m (kbd "C-c k e") #'kairoam-expand-window)
    (define-key m (kbd "C-c k d") #'kairoam-debug)
    (define-key m (kbd "C-c k t") #'kairoam-toggle-layout-mode)
    (define-key m (kbd "C-c k m") #'kairoam-mobile-mode)
    (define-key m (kbd "C-c k L") #'kairoam-laptop-mode)
    (define-key m (kbd "C-c k R") #'kairoam-reset)
    (define-key m (kbd "C-c k K") #'kairoam-kill-all-buffers)
    (define-key m (kbd "C-c k b") #'kairoam-balance)
    m)
  "Keymap for `kairoam-mode'.")

;;;###autoload
(define-minor-mode kairoam-mode
  "Toggle Kairoam evergreen note layout mode."
  :global t
  :lighter " kairoam"
  :keymap kairoam-mode-map
  (if kairoam-mode
      (progn
        (kairoam--info "kairoam-mode enabled")
        ;; Install advice for +org/dwim-at-point if it exists
        (when (fboundp '+org/dwim-at-point)
          (advice-add '+org/dwim-at-point :around #'kairoam--advice-dwim-at-point))
        (when (fboundp 'org-open-at-mouse)
          (advice-add 'org-open-at-mouse :around #'kairoam--advice-org-open-at-mouse))
        ;; auto-track current buffer if it's an org-roam file
        (when (and (buffer-file-name)
                   (bound-and-true-p org-roam-directory)
                   (string-prefix-p (expand-file-name org-roam-directory)
                                    (expand-file-name (or (buffer-file-name) ""))))
          (kairoam--register-new (selected-window) (current-buffer) 0)
          (kairoam--distribute-sizes)))
    (kairoam--info "kairoam-mode disabled")
    ;; Remove advice when disabling mode
    (when (fboundp '+org/dwim-at-point)
      (advice-remove '+org/dwim-at-point #'kairoam--advice-dwim-at-point))
    (when (fboundp 'org-open-at-mouse)
      (advice-remove 'org-open-at-mouse #'kairoam--advice-org-open-at-mouse))
    ;; Restore line numbers and cleanup overlays
    (dolist (s kairoam--registry)
      ;; Restore line numbers for each buffer
      (let ((buf (kairoam-window-buffer s))
            (saved-state (kairoam-window-line-numbers-mode-state s)))
        (when (and buf (buffer-live-p buf) saved-state)
          (with-current-buffer buf
            (setq-local display-line-numbers 
                        (if (eq saved-state t) t nil)))))
      ;; Remove overlays
      (when (kairoam-window-overlay s)
        (ignore-errors (delete-overlay (kairoam-window-overlay s)))))
    (kairoam--registry-reset)))

(defun kairoam--set-layout-mode (new-mode)
  "Internal function to set layout mode to NEW-MODE and reconfigure windows."
  (unless (memq new-mode '(laptop mobile))
    (error "Invalid layout mode: %s" new-mode))
  
  (if (eq kairoam-layout-mode new-mode)
      (message "Already in %s mode" new-mode)
    (let ((old-mode kairoam-layout-mode))
      ;; Set new mode
      (setq kairoam-layout-mode new-mode)
      
      ;; Save window configuration
      (let ((windows-info (mapcar (lambda (s)
                                    (cons (kairoam-window-buffer s)
                                          (kairoam-window-state s)))
                                  kairoam--registry)))
        ;; Reset windows
        (delete-other-windows)
        
        ;; Clear registry but keep mode active
        (kairoam--registry-reset)
        
        ;; Recreate windows in new layout
        (when windows-info
          (let ((first-buf (caar windows-info))
                (prev-win nil))
            ;; Start with first buffer
            (switch-to-buffer first-buf)
            (kairoam--register-new (selected-window) first-buf 0)
            (setq prev-win (selected-window))
            
            ;; Add remaining windows - split from the previous window, not selected
            (cl-loop for (buf . state) in (cdr windows-info)
                     for pos from 1
                     do (let ((new-win (split-window prev-win nil 
                                                     (if (eq kairoam-layout-mode 'mobile) 
                                                         'below 'right))))
                          (with-selected-window new-win
                            (switch-to-buffer buf))
                          (kairoam--register-new new-win buf pos)
                          (setq prev-win new-win)
                          ;; Restore fold state
                          (when (eq state 'folded)
                            (kairoam--fold-window-internal new-win)))))
          
          ;; Apply sizing - this should properly resize all windows
          (kairoam--distribute-sizes)))
      
      (message "Kairoam layout mode changed from %s to %s" 
               old-mode kairoam-layout-mode))))

(defun kairoam-toggle-layout-mode ()
  "Toggle between laptop (side-by-side) and mobile (top-bottom) layout modes."
  (interactive)
  (kairoam--set-layout-mode (if (eq kairoam-layout-mode 'mobile) 'laptop 'mobile)))

(defun kairoam-mobile-mode ()
  "Switch to mobile layout mode (top-bottom splits)."
  (interactive)
  (kairoam--set-layout-mode 'mobile))

(defun kairoam-laptop-mode ()
  "Switch to laptop layout mode (side-by-side splits)."
  (interactive)
  (kairoam--set-layout-mode 'laptop))

(defun kairoam-auto-detect-mode ()
  "Auto-detect and set the appropriate layout mode based on frame dimensions."
  (interactive)
  (let* ((width (frame-width))
         (height (frame-height))
         (aspect-ratio (/ (float width) height))
         (new-mode (if (< aspect-ratio 1.0) 'mobile 'laptop)))
    (when (not (eq kairoam-layout-mode new-mode))
      (kairoam--set-layout-mode new-mode)
      (message "Auto-detected %s mode (width: %d, height: %d, ratio: %.2f)"
               new-mode width height aspect-ratio))))

(defun kairoam-reset (&optional kill-buffers)
  "Reset all note windows to single expanded view and disable kairoam-mode.
With prefix arg or if KILL-BUFFERS is non-nil, also kill all kairoam-tracked buffers."
  (interactive "P")
  ;; Save buffers list before resetting
  (let ((buffers-to-kill (when kill-buffers
                           (mapcar #'kairoam-window-buffer kairoam--registry))))
    ;; Disable mode (this restores line numbers)
    (kairoam-mode -1)
    ;; Reset window configuration
    (delete-other-windows)
    (when (fboundp 'org-show-all)
      (ignore-errors (org-show-all)))
    ;; Kill buffers if requested
    (when kill-buffers
      (dolist (buf buffers-to-kill)
        (when (and buf (buffer-live-p buf))
          (kill-buffer buf)))
      (message "Kairoam reset - mode disabled and %d buffers killed" 
               (length buffers-to-kill)))
    (unless kill-buffers
      (message "Kairoam layout reset and mode disabled."))))

(defun kairoam-kill-all-buffers ()
  "Kill all buffers tracked by kairoam and reset."
  (interactive)
  (kairoam-reset t))

(defun kairoam-balance ()
  "Balance all kairoam windows according to their state (folded/expanded).
Fixes any window sizing issues and ensures proper distribution."
  (interactive)
  (when kairoam-mode
    ;; Clean up any dead windows first
    (kairoam--cleanup-dead)
    
    ;; Re-apply overlays for folded windows (in case they got messed up)
    (dolist (s kairoam--registry)
      (when (eq (kairoam-window-state s) 'folded)
        (let* ((win (kairoam-window-window s))
               (buf (kairoam-window-buffer s)))
          (when (and win (window-live-p win) buf (buffer-live-p buf))
            ;; Ensure overlay is properly set
            (when (kairoam-window-overlay s)
              (ignore-errors (delete-overlay (kairoam-window-overlay s))))
            (let ((title (kairoam--buffer-title buf)))
              (setf (kairoam-window-overlay s) (kairoam--make-title-overlay buf title)))))))
    
    ;; Force redistribute all window sizes
    (kairoam--distribute-sizes)
    
    ;; Ensure expanded windows are properly shown
    (dolist (s kairoam--registry)
      (when (eq (kairoam-window-state s) 'expanded)
        (let* ((win (kairoam-window-window s))
               (buf (kairoam-window-buffer s)))
          (when (and win (window-live-p win) buf (buffer-live-p buf))
            ;; Force redisplay of buffer content
            (with-current-buffer buf
              (kairoam--remove-title-overlay buf))
            (set-window-buffer win buf)))))
    
    (kairoam--info "Balanced %d windows (%d expanded, %d folded)"
                   (length kairoam--registry)
                   (length (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'expanded)) 
                                             kairoam--registry))
                   (length (cl-remove-if-not (lambda (s) (eq (kairoam-window-state s) 'folded)) 
                                             kairoam--registry)))
    (message "Kairoam windows balanced")))

(defun kairoam-toggle ()
  "Toggle kairoam mode if not active else reset"
  (interactive)
  (if (eq kairoam-mode t)
      (kairoam-reset)
    (kairoam-mode)))

(defun kairoam-toggle-size (&optional win)
  "Smart toggle: expand if folded, fold if expanded.
If window is expanded, fold it. If folded, expand it.
Works on WIN or selected window."
  (interactive)
  (let* ((win (or win (selected-window)))
         (s (kairoam--find-by-window win)))
    (if (not s)
        ;; Window not tracked - try to expand (will register it)
        (kairoam-expand-window win)
      ;; Window is tracked - toggle based on current state
      (if (eq (kairoam-window-state s) 'expanded)
          (kairoam-fold-window win)
        (kairoam-expand-window win)))))

(when IS-ANDROID
  (setq kairoam-layout-mode 'mobile)
  (setq window-min-height 1))
(provide 'kairoam-notes)
;;; kairoam-notes.el ends here
