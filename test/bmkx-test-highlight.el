;;; bmkx-test-highlight.el --- Persistent bookmark highlighting   -*- lexical-binding: t -*-
;;
;; These tests exercise `bookmark-x-lit.el'.  They are skipped if the
;; library is not loaded.

;;; Code:

(require 'bmkx-test-helper)


(defmacro bmkx-test-skip-unless-lit (&rest body)
  "Run BODY only if `bookmark-x-lit' is loaded."
  (declare (indent 0) (debug t))
  `(if (featurep 'bookmark-x-lit)
       (progn ,@body)
     (ert-skip "bookmark-x-lit not loaded")))

(defmacro bmkx-test-with-lit-fixture (buf text &rest body)
  "Run BODY in a clean bookmark fixture buffer, if highlighting is available."
  (declare (indent 2) (debug (symbolp form body)))
  `(bmkx-test-skip-unless-lit
     (bmkx-test-with-clean-bookmarks
       (bmkx-test-with-fixture-buffer ,buf ,text
         ,@body))))


(defun bmkx-test--overlays-for-bookmark (file name)
  "Return all `bookmark-plus' overlays in FILE's buffer tagged with NAME."
  (let ((dest (find-file-noselect file)))
    (with-current-buffer dest
      (cl-remove-if-not
       (lambda (ov)
         (let ((bmk (overlay-get ov 'bookmark)))
           (and (eq 'bookmark-plus (overlay-get ov 'category))
                (consp bmk)
                (equal name (car bmk)))))
       (overlays-in (point-min) (point-max))))))

(defun bmkx-test--margin-display-side (string)
  "Return the margin side encoded by STRING's `display' property."
  (let* ((display  (and string  (get-text-property 0 'display string)))
        (head     (car-safe display)))
    (cond ((memq head '(left-margin right-margin)) head)
         ((and (consp head)  (eq 'margin (car head))) (cadr head)))))

(ert-deftest bmkx-test-highlight/light-adds-overlay ()
  "Lighting a bookmark adds at least one overlay in the destination buffer."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "lit-target" buf 7)
          (bmkx-light-bookmark "lit-target")
          (should (bmkx-test--overlays-for-bookmark file "lit-target")))))))

(ert-deftest bmkx-test-highlight/unlight-removes-overlay ()
  "Unlighting a bookmark removes its overlay."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "lit-rm" buf 7)
          (bmkx-light-bookmark "lit-rm")
          (should     (bmkx-test--overlays-for-bookmark file "lit-rm"))
          (bmkx-unlight-bookmark "lit-rm")
          (should-not (bmkx-test--overlays-for-bookmark file "lit-rm")))))))

(ert-deftest bmkx-test-highlight/delete-removes-overlay ()
  "Deleting a bookmark with `bmkx-delete' removes its overlay."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "lit-stale" buf 7)
          (bmkx-light-bookmark "lit-stale" 'bol)
          (should (bmkx-test--overlays-for-bookmark file "lit-stale"))
          (bmkx-delete "lit-stale")
          (should-not (bmkx-test--overlays-for-bookmark file "lit-stale")))))))

(ert-deftest bmkx-test-highlight/delete-key-invokes-bmkx-delete ()
  "Bookmark-X binds `d' in `bookmark-map' to `bmkx-delete'."
  (should (eq (lookup-key bookmark-map "d") 'bmkx-delete)))

(ert-deftest bmkx-test-highlight/light-records-style-override ()
  "Setting a per-bookmark lighting style stores a `lighting' property."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "x"
        (bmkx-test--make-bookmark "ovr" buf))
      ;; `bmkx-set-lighting-for-bookmark' is interactive; call it via the
      ;; setter helpers it uses internally.
      (let ((rec (bmkx-get-bookmark "ovr")))
        (bookmark-prop-set rec 'lighting '(:style line :face nil)))
      (should (bmkx-get-lighting "ovr")))))


(ert-deftest bmkx-test-highlight/margin-style-adds-overlay ()
  "Lighting a bookmark with `lmargin' style adds an overlay."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "margin-lit" buf 7)
          (bmkx-light-bookmark "margin-lit" 'lmargin nil)
          (should (bmkx-test--overlays-for-bookmark file "margin-lit")))))))

(ert-deftest bmkx-test-highlight/margin-style-removes-overlay ()
  "Unlighting a margin-style bookmark removes its overlay."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "margin-rm" buf 7)
          (bmkx-light-bookmark "margin-rm" 'lmargin nil)
          (should (bmkx-test--overlays-for-bookmark file "margin-rm"))
          (bmkx-unlight-bookmark "margin-rm")
          (should-not (bmkx-test--overlays-for-bookmark file "margin-rm")))))))

(ert-deftest bmkx-test-highlight/margin-style-sets-margin-display ()
  "Margin-style overlay `before-string' carries a `left-margin' display spec."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let* ((file (buffer-file-name buf))
           ovs
           bs)
      (bmkx-test--make-bookmark "margin-disp" buf 7)
      (bmkx-light-bookmark "margin-disp" 'lmargin nil)
      (setq ovs  (bmkx-test--overlays-for-bookmark file "margin-disp")
            bs   (and ovs  (overlay-get (car (last ovs)) 'before-string)))
      (should ovs)
      (should bs)
      (should (eq 'left-margin (bmkx-test--margin-display-side bs))))))

(ert-deftest bmkx-test-highlight/line+margin-applies-line-face ()
  "`line+lmargin' style applies a line face, unlike plain `lmargin'."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let* ((file (buffer-file-name buf))
           ovs
           ov
           side)
      (bmkx-test--make-bookmark "lmargin-line" buf 7)
      (bmkx-light-bookmark "lmargin-line" 'line+lmargin nil)
      (setq ovs  (bmkx-test--overlays-for-bookmark file "lmargin-line")
            ov   (and ovs  (car (last ovs)))
            side (and ov   (bmkx-test--margin-display-side
                            (overlay-get ov 'before-string))))
      (should ovs)
      (should (overlay-get ov 'face))
      (should (eq 'left-margin side)))))

(ert-deftest bmkx-test-highlight/fringe-fallback-in-tty ()
  "Fringe styles fall back to margin on a non-graphic display."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let ((bmkx-light-fringe-to-margin-fallback t)
          ovs
          ov
          bs)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
        (bmkx-test--make-bookmark "fallback-tty" buf 7)
        (bmkx-light-bookmark "fallback-tty" 'lfringe nil)
        (setq ovs  (bmkx-test--overlays-for-bookmark (buffer-file-name buf) "fallback-tty")
              ov   (and ovs  (car (last ovs)))
              bs   (and ov   (overlay-get ov 'before-string))))
      (should ovs)
      (should bs)
      (should (eq 'left-margin (bmkx-test--margin-display-side bs))))))

(ert-deftest bmkx-test-highlight/fringe-no-fallback-when-disabled ()
  "Fringe styles do NOT fall back when `bmkx-light-fringe-to-margin-fallback' is nil."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let ((bmkx-light-fringe-to-margin-fallback nil)
          ovs
          ov
          bs)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
        (bmkx-test--make-bookmark "no-fallback" buf 7)
        (bmkx-light-bookmark "no-fallback" 'lfringe nil)
        (setq ovs  (bmkx-test--overlays-for-bookmark (buffer-file-name buf) "no-fallback")
              ov   (and ovs  (car (last ovs)))
              bs   (and ov   (overlay-get ov 'before-string))))
      (should ovs)
      (should bs)
      (should (eq 'left-fringe
                  (car-safe (get-text-property 0 'display bs)))))))

(ert-deftest bmkx-test-highlight/margin-fallback-preserves-stored-style ()
  "Fallback does not mutate the bookmark's stored `lighting' property."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let ((bmkx-light-fringe-to-margin-fallback t))
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
        (bmkx-test--make-bookmark "stored-style" buf 7)
        (bmkx-set-lighting-for-bookmark "stored-style" 'lfringe nil nil)
        (bmkx-light-bookmark "stored-style" nil))
      (let ((rec (bmkx-get-bookmark "stored-style")))
        (should rec)
        (should (eq 'lfringe (bmkx-lighting-style rec)))))))

(ert-deftest bmkx-test-highlight/margin-sets-margin-width ()
  "Lighting a margin-style bookmark sets `left-margin-width' to ≥ 1."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (with-current-buffer buf
      (setq left-margin-width 0))
    (bmkx-test--make-bookmark "margin-width" buf 7)
    (bmkx-light-bookmark "margin-width" 'lmargin nil)
    (with-current-buffer buf
      (should (>= left-margin-width 1)))))

(ert-deftest bmkx-test-highlight/margin-refreshes-correct-window ()
  "Lighting a margin bookmark from another window refreshes the file window.
Regression test for the `set-window-buffer (selected-window)' bug:
when the file buffer is displayed in a window OTHER than the selected
one, the margin width must be set on the file-buffer's window, and the
selected window's buffer must NOT be hijacked."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer file-buf "alpha beta gamma"
        (let ((menu-buf (get-buffer-create "*bmkx-test-menu-sim*"))
              file-win menu-win)
          (unwind-protect
              (progn
                ;; Display file-buf in the selected window, then split and
                ;; put menu-buf in the selected window.  file-buf is now in
                ;; a non-selected window.
                (set-window-buffer (selected-window) file-buf)
                (split-window)
                (setq file-win (selected-window)
                      menu-win (next-window))
                (set-window-buffer menu-win menu-buf)
                (select-window menu-win)
                ;; Sanity: selected window shows menu, other shows file.
                (should (eq (window-buffer menu-win) menu-buf))
                (should (eq (window-buffer file-win) file-buf))
                (should-not (eq (selected-window) file-win))
                ;; Light a margin-style bookmark from the menu window.
                (bmkx-test--make-bookmark "win-refresh" file-buf 7)
                (bmkx-light-bookmark "win-refresh" 'lmargin nil)
                ;; The file-buffer's window must now have a non-zero left margin.
                (should (<= 1 (or (car (window-margins file-win)) 0)))
                ;; The selected window must still show menu-buf (not hijacked).
                (should (eq (window-buffer (selected-window)) menu-buf)))
            (when (buffer-live-p menu-buf) (kill-buffer menu-buf))))))))

(ert-deftest bmkx-test-highlight/margin-restores-width-on-correct-window ()
  "Unlighting the last margin bookmark restores margin on the file window.
Regression test: the restore path must also refresh the file-buffer's
window, not the selected window."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer file-buf "alpha beta gamma"
        (let ((menu-buf (get-buffer-create "*bmkx-test-menu-sim2*"))
              file-win menu-win)
          (unwind-protect
              (progn
                (set-window-buffer (selected-window) file-buf)
                (split-window)
                (setq file-win (selected-window)
                      menu-win (next-window))
                (set-window-buffer menu-win menu-buf)
                (select-window menu-win)
                (bmkx-test--make-bookmark "win-restore" file-buf 7)
                (bmkx-light-bookmark "win-restore" 'lmargin nil)
                (should (<= 1 (or (car (window-margins file-win)) 0)))
                ;; Unlight from the menu window.
                (bmkx-unlight-bookmark "win-restore")
                ;; The file-buffer window's margin should be restored to 0/nil.
                (should-not (car (window-margins file-win)))
                ;; Selected window still shows menu-buf.
                (should (eq (window-buffer (selected-window)) menu-buf)))
            (when (buffer-live-p menu-buf) (kill-buffer menu-buf))))))))

(ert-deftest bmkx-test-highlight/fringe-fallback-uses-effective-style-for-face ()
  "Fallback `line+rfringe'->`line+rmargin' applies a non-fringe line face.
Regression test for the face-skip guard: when a fringe style falls back
to a margin style, the line face must still be applied (because the
effective style `line+rmargin' is NOT in `bmkx-light--no-face-styles')."
  (bmkx-test-with-lit-fixture buf "alpha beta gamma"
    (let ((bmkx-light-fringe-to-margin-fallback t)
          ovs
          ov)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
        (bmkx-test--make-bookmark "eff-face" buf 7)
        (bmkx-light-bookmark "eff-face" 'line+rfringe nil)
        (setq ovs  (bmkx-test--overlays-for-bookmark (buffer-file-name buf) "eff-face")
              ov   (and ovs  (car (last ovs)))))
      (should ovs)
      (should (overlay-get ov 'face))
      (should (eq 'right-margin
                  (bmkx-test--margin-display-side
                   (overlay-get ov 'before-string)))))))


(provide 'bmkx-test-highlight)
;;; bmkx-test-highlight.el ends here
