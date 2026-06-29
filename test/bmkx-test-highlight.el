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
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let* ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "margin-disp" buf 7)
          (bmkx-light-bookmark "margin-disp" 'lmargin nil)
          (let ((ovs (bmkx-test--overlays-for-bookmark file "margin-disp")))
            (should ovs)
            (let ((bs (overlay-get (car (last ovs)) 'before-string)))
              (should bs)
              (should (eq 'left-margin
                          (car-safe (get-text-property 0 'display bs)))))))))))

(ert-deftest bmkx-test-highlight/line+margin-applies-line-face ()
  "`line+lmargin' style applies a line face, unlike plain `lmargin'."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (let ((file (buffer-file-name buf)))
          (bmkx-test--make-bookmark "lmargin-line" buf 7)
          (bmkx-light-bookmark "lmargin-line" 'line+lmargin nil)
          (let* ((ovs (bmkx-test--overlays-for-bookmark file "lmargin-line"))
                 (ov  (car (last ovs))))
            (should ovs)
            (should (overlay-get ov 'face))
            (should (eq 'left-margin
                        (car-safe (get-text-property
                                   0 'display (overlay-get ov 'before-string)))))))))))

(ert-deftest bmkx-test-highlight/fringe-fallback-in-tty ()
  "Fringe styles fall back to margin on a non-graphic display."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (let ((bmkx-light-fringe-to-margin-fallback t))
        (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
          (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
            (let ((file (buffer-file-name buf)))
              (bmkx-test--make-bookmark "fallback-tty" buf 7)
              (bmkx-light-bookmark "fallback-tty" 'lfringe nil)
              (let* ((ovs (bmkx-test--overlays-for-bookmark file "fallback-tty"))
                     (ov  (car (last ovs))))
                (should ovs)
                (let ((bs (overlay-get ov 'before-string)))
                  (should bs)
                  (let ((dsp (get-text-property 0 'display bs)))
                    (should (eq 'left-margin (car-safe dsp)))
                    (should-not (eq 'left-fringe (car-safe dsp)))))))))))))

(ert-deftest bmkx-test-highlight/fringe-no-fallback-when-disabled ()
  "Fringe styles do NOT fall back when `bmkx-light-fringe-to-margin-fallback' is nil."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (let ((bmkx-light-fringe-to-margin-fallback nil))
        (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
          (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
            (let ((file (buffer-file-name buf)))
              (bmkx-test--make-bookmark "no-fallback" buf 7)
              (bmkx-light-bookmark "no-fallback" 'lfringe nil)
              (let* ((ovs (bmkx-test--overlays-for-bookmark file "no-fallback"))
                     (ov  (car (last ovs))))
                (should ovs)
                (let ((bs (overlay-get ov 'before-string)))
                  (should bs)
                  (let ((dsp (get-text-property 0 'display bs)))
                    (should (eq 'left-fringe (car-safe dsp)))))))))))))

(ert-deftest bmkx-test-highlight/margin-fallback-preserves-stored-style ()
  "Fallback does not mutate the bookmark's stored `lighting' property."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (let ((bmkx-light-fringe-to-margin-fallback t))
        (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
          (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _f) nil)))
            (let ((file (buffer-file-name buf)))
              (bmkx-test--make-bookmark "stored-style" buf 7)
              (bmkx-set-lighting-for-bookmark "stored-style" 'lfringe nil nil)
              (bmkx-light-bookmark "stored-style" nil)
              (let ((rec (bmkx-get-bookmark "stored-style")))
                (should rec)
                (should (eq 'lfringe (bmkx-lighting-style rec)))))))))))

(ert-deftest bmkx-test-highlight/margin-sets-margin-width ()
  "Lighting a margin-style bookmark sets `left-margin-width' to ≥ 1."
  (bmkx-test-skip-unless-lit
    (bmkx-test-with-clean-bookmarks
      (bmkx-test-with-fixture-buffer buf "alpha beta gamma"
        (with-current-buffer buf
          (setq left-margin-width 0))
        (bmkx-test--make-bookmark "margin-width" buf 7)
        (bmkx-light-bookmark "margin-width" 'lmargin nil)
        (with-current-buffer buf
          (should (>= left-margin-width 1)))))))


(provide 'bmkx-test-highlight)
;;; bmkx-test-highlight.el ends here
