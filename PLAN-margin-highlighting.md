# Plan: Margin-based bookmark highlighting (terminal-friendly)

## Background

`bookmark-x-lit.el` highlights bookmarks using buffer overlays. The
"fringe" highlight styles (`lfringe`, `rfringe`, `line+lfringe`,
`line+rfringe`) attach a `before-string` whose `display` text property
is `(left-fringe BITMAP FACE)` / `(right-fringe BITMAP FACE)`.

**Problem:** Emacs running in a terminal (`emacs -nw`, `M-x term`,
ssh'd sessions, etc.) has **no fringe**. The `display` specs
`left-fringe` / `right-fringe` are silently dropped by the terminal
redisplay engine, so fringe-styled bookmarks are invisible there.

**Solution:** Add a parallel set of "margin" styles that use the
`(left-margin STRING)` / `(right-margin STRING)` `display` specs.
Margins **are** rendered in terminal Emacs (as long as
`left-margin-width` / `right-margin-width` is non-zero), so margin
styles work in both GUI and TTY frames. Margin display also works
inside `display` text properties of overlay `before-string`s, so no
new overlay machinery is needed — only a new "string builder"
analogous to `bmkx-fringe-string`.

## Goals

1. Add new highlight styles: `lmargin`, `rmargin`, `line+lmargin`,
   `line+rmargin`.
2. Add new customizable faces: `bmkx-light-margin-autonamed`,
   `bmkx-light-margin-non-autonamed`.
3. Add new defcustoms: `bmkx-light-left-margin-string`,
   `bmkx-light-right-margin-string` (the character/string painted in
   the margin).
4. Auto-enable margin width when margin styles are used (set
   `left-margin-width` / `right-margin-width` buffer-locally and force
   a window/victory refresh), and restore prior values when the last
   margin-styled overlay is removed.
5. Provide an optional automatic **fallback**: when a fringe style is
   requested on a non-graphic frame (or when `fringe-bitmaps` is
   unbound), transparently substitute the corresponding margin style.
   Gated by a new defcustom `bmkx-light-fringe-to-margin-fallback`
   (default `t`).
6. Update the manual, the quickstart (`readme.org`), and the reference
   (`doc/reference.org`) to document the new styles and option.
7. Add ERT tests covering creation, removal, restyle, fallback
   substitution, and margin-width side effects.
8. Keep byte-compilation warning-free under Emacs 30+ per
   `AGENTS.md`.

## Non-goals

- Removing or renaming existing fringe styles. They stay; margin is
  purely additive.
- Changing the on-disk bookmark format. `lighting` property values
  gain new legal `:style` symbols but the format is unchanged.
- Touching built-in `bookmark.el`.

## Relevant existing code (all in `bookmark-x-lit.el`)

| Symbol | Line | Role |
|---|---|---|
| `bmkx-light-styles-alist` | ~377 | `(DESCRIPTION . STYLE-SYMBOL)` alist used both for the `:type` of the style defcustoms and for the `completing-read` of style names. New styles must be added here. |
| `bmkx-light-style-choices` | ~389 | Builds the `:type` for the style defcustoms; consumes the alist, so no change needed beyond extending the alist. |
| `bmkx-light-style-autonamed` | ~395 | Default style. Defaults stay `line+lfringe` / `line+rfringe` so existing users see no behavior change. |
| `bmkx-light-fringe-autonamed` / `bmkx-light-fringe-non-autonamed` | ~264, ~270 | Faces for fringe. Mirror these for the new margin faces. |
| `bmkx-light-left-fringe-bitmap` / `bmkx-light-right-fringe-bitmap` | ~366, ~371 | Defcustoms for the bitmap. Mirror with `bmkx-light-left-margin-string` / `bmkx-light-right-margin-string`. |
| `bmkx-make/move-overlay-of-style` | ~1487 | The `cl-case` dispatcher that maps a style symbol to the overlay construction. New `lmargin`, `rmargin`, `line+lmargin`, `line+rmargin` cases must be added, parallel to the `lfringe`/`rfringe`/`line+lfringe`/`line+rfringe` ones. |
| `bmkx-make/move-fringe` | ~1555 | Helper that builds/moves a fringe overlay and sets `before-string`. Write a sibling `bmkx-make/move-margin` with the same signature. |
| `bmkx-fringe-string` | ~1581 | Builds the propertized display string. Write a sibling `bmkx-margin-string`. |
| `bmkx-light-bookmark` (face-skip list) | ~896, ~909, ~923, ~953, ~988 | `(member sty '(lfringe rfringe none))` guards prevent applying `face` to fringe/none overlays. These lists must also include `lmargin`, `rmargin`, `line+lmargin`, `line+rmargin` because the margin display spec carries its own face. **Note** that `line+lmargin` and `line+rmargin` should still allow a line face (same as `line+lfringe`/`line+rfringe` — check whether those currently allow a face; from the code, `line+lfringe` is *not* in the skip list, so the line face IS applied. Mirror that: `lmargin`/`rmargin` alone go in the skip list; `line+lmargin`/`line+rmargin` stay out). |
| `bmkx-read-set-lighting-args` | ~1430 | Skip face prompt for `lfringe`/`rfringe`/`none`; extend with `lmargin`/`rmargin` (but NOT `line+lmargin`/`line+rmargin`, mirroring fringe). |
| `bmkx-light-bookmarks` (style-face application) | ~1090 | Same `unless (member style '(lfringe rfringe none))` guard. Extend. |
| `bmkx-set-lighting-for-bookmarks`-adjacent code at ~1430 | Same. Extend. |

There are also two spots in `bookmark-x-1.el` that touch the built-in
`bookmark-set-fringe-mark` (Emacs 28+); leave those alone, they are
the built-in's own fringe mark, not bmkx's lighting.

## Implementation TODO

### 1. Faces (in `bookmark-x-lit.el`, "Faces (Customizable)" section)

- [ ] Add `defface bmkx-light-margin-autonamed` mirroring
      `bmkx-light-fringe-autonamed` (a visible background/foreground
      pair that renders well in terminal — prefer a plain color name
      like `"magenta"` for the dark variant and `"Orchid"` for the
      light variant, since 24-bit hex `#RRRRGGGGBBBB` strings don't
      render in 256-color terms).
- [ ] Add `defface bmkx-light-margin-non-autonamed` mirroring
      `bmkx-light-fringe-non-autonamed` similarly.
- [ ] Add the two new faces to the "Faces defined here" commentary
      list at the top of the file.

### 2. User options (in `bookmark-x-lit.el`, "User Options" section)

- [ ] Add `defcustom bmkx-light-left-margin-string ">"`
      (a one-character string rendered in the left margin). `:type`
      should be `string`.
- [ ] Add `defcustom bmkx-light-right-margin-string "<"`
      (the right-margin counterpart).
- [ ] Add `defcustom bmkx-light-fringe-to-margin-fallback` with
      `:type 'boolean` and default `t`. When non-nil, a fringe style
      requested on a frame where `(display-graphic-p)` is nil (or
      where `fringe-bitmaps` is unbound) silently becomes the matching
      margin style.
- [ ] Extend `bmkx-light-styles-alist` with the four new entries
      (`"Left Margin" . lmargin`, `"Right Margin" . rmargin`,
      `"Left Margin + Line" . line+lmargin`,
      `"Right Margin + Line" . line+rmargin`). Place them immediately
      after the fringe entries so completion reads naturally.
- [ ] Update the "User options defined here" commentary list to
      mention the three new defcustoms.

### 3. Overlay construction

- [ ] Write `bmkx-make/move-margin` (sibling of
      `bmkx-make/move-fringe`). Same signature:
      `(side pos autonamedp &optional overlay linep)`. It must:
  1. Create or move an overlay at `(line-beginning-position)` ..
      `(1+ (line-beginning-position))` (zero-width-on-next-line is
      fine, mirroring fringe behavior — see existing
      `bmkx-make/move-fringe` at line ~1555 for the exact overlay
      placement).
  2. Put `before-string` to the value of
      `(bmkx-margin-string side autonamedp)`.
  3. If `linep` is non-nil, also widen the overlay to cover the whole
      line so a line face applies — same as `bmkx-make/move-fringe`.
  4. If `linep` is nil, set `face` overlay property to nil (matching
      fringe behavior).
- [ ] Write `bmkx-margin-string` (sibling of `bmkx-fringe-string`).
      It returns a one-character string (the value of
      `bmkx-light-left-margin-string` or
      `bmkx-light-right-margin-string`) propertized with a `display`
      property of `(left-margin STRING)` or `(right-margin STRING)`,
      and with a `face` property of `bmkx-light-margin-autonamed` or
      `bmkx-light-margin-non-autonamed` depending on `autonamedp`.

      **Important Emacs quirk:** the `display` form
      `(left-margin STRING)` paints STRING in the margin **using the
      string's own face properties**, so the face must be applied to
      the *string itself*, not to the overlay. Mirror
      `bmkx-fringe-string`'s approach of putting `face` on the string
      via `put-text-property`.
- [ ] Add `lmargin`, `rmargin`, `line+lmargin`, `line+rmargin` cases
      to `bmkx-make/move-overlay-of-style`'s `cl-case`. They call
      `bmkx-make/move-margin` exactly as the fringe cases call
      `bmkx-make/move-fringe`.

### 4. Face-application guards

Every spot that currently does
`(member STY '(lfringe rfringe none))` must be reviewed. The new
*standalone* margin styles (`lmargin`, `rmargin`) carry their own face
on the display string and so should be in the skip list, exactly like
`lfringe`/`rfringe`. The *combined* line styles
(`line+lmargin`, `line+rmargin`) must NOT be in the skip list, since
the line face should still apply — matching how `line+lfringe` /
`line+rfringe` are currently NOT in the skip list.

- [ ] `bmkx-light-bookmark` interactive spec at ~896
      (`(not (member sty '(lfringe rfringe none)))`).
- [ ] `bmkx-light-bookmark` body at ~909
      (`(not (member styl '(lfringe rfringe none)))`).
- [ ] `bmkx-light-bookmark` body at ~923
      (`(not (memq styl '(lfringe rfringe none)))`).
- [ ] `bmkx-light-bookmark` body at ~953
      (`(unless (memq styl '(lfringe rfringe none))`).
- [ ] `bmkx-light-bookmark-this-buffer` interactive spec at ~988.
- [ ] `bmkx-light-bookmarks` body at ~1090.
- [ ] `bmkx-read-set-lighting-args` at ~1430.
- [ ] Any other occurrence — re-run
      `rg "(lfringe|rfringe).*none"` after edits and confirm zero
      leftover skip-lists missing the new symbols.

A convenient shared constant is acceptable but optional. If added,
define `(defconst bmkx-light--no-face-styles '(lfringe rfringe lmargin rmargin none))`
near `bmkx-light-styles-alist` and replace the inline lists. This is
optional — keep it simple if unsure.

### 5. Margin-width side effects

Margin display is only visible when the window has a non-zero margin
of the appropriate side. Buffer-local variables
`left-margin-width` and `right-margin-width` control this. They are
buffer-local; setting them requires `(set-window-buffer nil nil)` or
a `window-configuration-change-hook` nudge to actually take effect.

- [ ] Add a buffer-local variable
      `bmkx--saved-margin-widths` (a cons `(LEFT . RIGHT)`) in every
      buffer where bmkx lights a margin-styled bookmark, capturing the
      prior values of `left-margin-width` and `right-margin-width`.
      Use `(make-variable-buffer-local 'bmkx--saved-margin-widths)`.
- [ ] In `bmkx-make/move-margin`, after creating the overlay:
      if `left-margin-width` (or right) is currently 0, set it to a
      sensible default (1, or the `string-width` of
      `bmkx-light-left-margin-string`) and call
      `(set-window-buffer (selected-window) (current-buffer))` to
      force a redisplay. Capture the prior 0 value in
      `bmkx--saved-margin-widths` so it can be restored later.
- [ ] In `bmkx-unlight-bookmark` (or, more cleanly, in a helper run
      from `bmkx-unlight-bookmarks` and `bmkx-unlight-bookmark`):
      when removing the last margin-styled overlay in a buffer,
      restore `left-margin-width` / `right-margin-width` from
      `bmkx--saved-margin-widths` (if set) and force a window
      refresh. A simple `after` advice on `delete-overlay` is too
      broad — instead add an explicit cleanup helper
      `bmkx--maybe-restore-margin-widths` and call it at the end of
      `bmkx-unlight-bookmark` and at the end of the `dolist` in
      `bmkx-unlight-bookmarks`.
- [ ] For combined `line+lmargin` / `line+rmargin` styles: the margin
      marker should be shown **and** the line face applied. Make sure
      `bmkx-make/move-margin`'s `linep` path does both (mirror
      `bmkx-make/move-fringe`'s `linep` path).

### 6. Fringe-to-margin fallback

- [ ] Add a helper `bmkx--maybe-fallback-style` that takes a style
      symbol and returns it unchanged, unless
      `bmkx-light-fringe-to-margin-fallback` is non-nil AND the
      current frame cannot render fringes — detected via
      `(or (not (display-graphic-p)) (not (boundp 'fringe-bitmaps)))`.
      In that case map: `lfringe` → `lmargin`, `rfringe` → `rmargin`,
      `line+lfringe` → `line+lmargin`, `line+rfringe` →
      `line+rmargin`. Other styles pass through.
- [ ] Call this helper at the very top of
      `bmkx-make/move-overlay-of-style`, rebinding `style`. That way
      every entry point (interactive `bmkx-light-bookmark`, batch
      `bmkx-light-bookmarks`, bmenu commands) gets the fallback for
      free.
- [ ] Make sure the saved `lighting` property on the bookmark record
      is NOT rewritten by the fallback — only the *runtime* overlay
      style changes. The bookmark's stored `:style` stays as the
      user-requested `lfringe` etc., so that on a GUI frame the
      original style is honored. (This is the existing behavior: the
      `lighting` property is independent of the runtime overlay.)

### 7. Tests (in `test/bmkx-test-highlight.el`)

Add the following ERT tests inside the existing
`bmkx-test-skip-unless-lit` wrapper pattern. Reuse
`bmkx-test-with-clean-bookmarks`,
`bmkx-test-with-fixture-buffer`, and `bmkx-test--make-bookmark`.

- [ ] `bmkx-test-highlight/margin-style-adds-overlay`: lighting a
      bookmark with `style='lmargin` adds exactly one overlay in the
      destination buffer, tagged with the bookmark.
- [ ] `bmkx-test-highlight/margin-style-removes-overlay`: unlighting
      removes it.
- [ ] `bmkx-test-highlight/margin-style-sets-before-string`: the
      overlay's `before-string` is non-nil and its `display` property
      is `(left-margin ...)` / `(right-margin ...)`.
- [ ] `bmkx-test-highlight/margin-sets-margin-width`: after lighting
      a `lmargin`-styled bookmark in a buffer whose
      `left-margin-width` was 0, the buffer-local
      `left-margin-width` is now ≥ 1.
- [ ] `bmkx-test-highlight/margin-restores-margin-width`: after the
      last margin-styled overlay is removed, `left-margin-width`
      returns to the value it had before lighting (use a buffer that
      pre-set `left-margin-width` to 0).
- [ ] `bmkx-test-highlight/line+margin-applies-line-face`: for style
      `line+lmargin`, the overlay's `face` property is non-nil (the
      default line face), distinguishing it from plain `lmargin`.
- [ ] `bmkx-test-highlight/fringe-fallback-in-tty`: bind
      `display-graphic-p` to nil (use `cl-letf (((symbol-function
      'display-graphic-p) (lambda (&optional _f) nil)))`) and
      `bmkx-light-fringe-to-margin-fallback` to `t`; light a bookmark
      with style `lfringe`; assert the resulting overlay's
      `before-string` carries a `(left-margin ...)` display spec (not
      a `(left-fringe ...)`).
- [ ] `bmkx-test-highlight/fringe-no-fallback-when-disabled`: same
      as above but with `bmkx-light-fringe-to-margin-fallback` set to
      `nil`; assert the overlay keeps `(left-fringe ...)`.
- [ ] `bmkx-test-highlight/margin-fallback-preserves-stored-style`:
      after the fallback fires, the bookmark's stored `lighting`
      property `:style` is still `lfringe` (i.e. the on-disk record
      was not mutated).

Run with `make test`.

### 8. Byte-compilation hygiene

- [ ] Add `(defvar left-margin-width)` / `(defvar
      right-margin-width)` quiet-defvars if the byte-compiler
      complains (these are built-ins but sometimes need a `defvar`
      in `eval-when-compile` for `let`-binding in tests; check).
- [ ] Run `make compile` and confirm **0 warnings** under Emacs 30+.
      If a new warning appears (e.g. "unused lexical variable
      `linep`"), fix it.

### 9. Documentation

- [ ] `doc/bookmark-x.texi` (around line ~1506, the styles table):
      add four rows for `lmargin`, `rmargin`, `line+lmargin`,
      `line+rmargin`. Also document
      `bmkx-light-left-margin-string`, `bmkx-light-right-margin-string`,
      `bmkx-light-margin-autonamed`, `bmkx-light-margin-non-autonamed`,
      and `bmkx-light-fringe-to-margin-fallback` in the defcustom
      node (around the existing fringe-bitmap entries at ~2046).
- [ ] `readme.org` (around line ~1419): add the four new rows to the
      style table and a short paragraph noting that margin styles
      work in terminal Emacs.
- [ ] `doc/reference.org`: if it enumerates highlight styles, extend
      it the same way.
- [ ] Rebuild the manual: `make -C doc` and commit the regenerated
      `doc/bookmark-x.info` if the repo ships a built info file
      (check `.gitignore` first — if `*.info` is gitignored, skip
      this).

### 10. Verification checklist

- [ ] `make test` passes with new tests green and existing tests
      still green.
- [ ] `make compile` is warning-free.
- [ ] Manual smoke test in `emacs -Q -nw`:
  - `M-x bmkx-set` at some line, then
    `M-: (let ((bmkx-light-style-autonamed 'lmargin)) (bmkx-light-bookmark "name"))`
    — a marker appears in the left margin.
  - `M-x bmkx-unlight-bookmark` — marker disappears, margin width
    restored.
  - Set `bmkx-light-style-autonamed 'lfringe` and repeat — fallback
    to margin rendering fires automatically because
    `display-graphic-p` is nil.
- [ ] Manual smoke test in graphical Emacs: fringe styles render as
    fringes (no fallback), margin styles render in the margin.

## Design notes for the implementer

- **Why a new helper rather than overloading `bmkx-make/move-fringe`:**
  the `(left-fringe BITMAP FACE)` display spec is structurally
  different from `(left-margin STRING)` — one takes a bitmap symbol
  plus a face, the other takes a literal string. Forcing them through
  one function would require an awkward branch; a sibling helper is
  cleaner and mirrors the existing fringe/margin separation in Emacs
  itself.
- **Margin face gotcha:** for `(left-margin STRING)`, Emacs paints
  STRING using STRING's own text properties, ignoring the overlay's
  `face` property. So `bmkx-margin-string` MUST put the face on the
  string (via `put-text-property 'face`), exactly as
  `bmkx-fringe-string` does. Do not rely on the overlay `face`.
- **Margin width gotcha:** Emacs caches window margins; setting
  `left-margin-width` does not visibly take effect until the window
  is "re-buffered". The reliable trigger is
  `(set-window-buffer (selected-window) (current-buffer))`. An
  alternative is `(window--resize-root-window-again (selected-window))`
  but `set-window-buffer` is simpler and is what `display-line-numbers-mode`
  uses internally. Test both paths if one proves flaky.
- **Multiple bookmarks on the same line:** margin markers stack
  horizontally in the left margin if multiple overlays on a line
  each set a `before-string` with a margin display spec. There may
  be visual overlap if `left-margin-width` is 1 and there are 2+
  markers. This is acceptable for a first cut; document the
  limitation in `readme.org`. The fringe styles have the same issue
  (overlapping bitmaps).
- **`bmkx-light-threshold`:** no change needed; the threshold check
  in `bmkx-light-bookmark` counts overlays and is style-agnostic.
- **Compatibility:** Emacs 30+ is the target per `AGENTS.md`. The
  `(left-margin STRING)` display spec has existed since Emacs 22, so
  no version guard is needed. `left-margin-width` /
  `right-margin-width` are likewise ancient.
