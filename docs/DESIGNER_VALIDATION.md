# Designer validation log (designer-robustness)

End-to-end validation of the interactive dialog designer, driven through its
own UI inside hbide (xterm on Xvfb) plus runtime execution of the generated
code. Dogfooding model: a "Find" dialog built entirely with the designer
(SAY, GET, CheckBox, three PushButtons, RadioGroup, ListBox).

## Validated end-to-end (live UI + compiled runtime)

- Full palette: SAY, GET, CheckBox, PushButton, RadioGroup, ListBox.
  F2 palette -> ghost -> drop -> F9 codegen -> generated PRG compiles and runs.
- PushButton actions: new buttons default to `lOk := .T., oDlg:End()`;
  an explicit action (e.g. `oDlg:End()` for Cancel) is preserved verbatim;
  clearing the Action field in Control properties restores the confirm
  fallback. Runtime: OK -> .T., Find -> .T., Cancel -> .F., Escape -> .F.
  (results written to file by the generated program, not read from screen).
- Dialog colors: Back/Text/Focus trio in F3, JSON roundtrip, runtime paint
  (blue dialog, white-on-red focused GET). Empty color -> W+/W fallback.
- JSON roundtrip: F10/F11 save, F12 reload ("Loaded" hint), models preserved.
- Delete / ^Z undo / ^Y redo, clipboard ^C/^X/^V: control counts and
  positions verified in the saved JSON after each step.
- Mouse resize: bottom-right handle drag grows/shrinks the control
  (ListBox height 4 -> 5 verified in JSON; snap clamps width).
- Keyboard move with arrows; EditProperties via Enter; F3 dialog props
  (caption/name/width/height/colors).
- RadioGroup/ListBox runtime navigation: Down moves selection/cursor,
  list scrolls, Escape exits with .F.
- Inspector: F4 opens/closes the panel, F6 toggles keyboard focus, Esc is
  layered - focused Esc unfocuses, unfocused Esc closes the panel, the next
  Esc offers exit. (Before 9ff3757, Esc with the panel open exited the
  designer directly.)
- ListBox scroll: 12 items in a 5-row box; Down moves the cursor past the
  visible window and the list scrolls (It4/It5/It6 shown after 5 Downs);
  Escape exits with .F..
- ListBox paging: PgDn/PgUp page the focused listbox by its visible rows
  (It1 -> It4 -> It7 -> It10, PgUp back to It7) without leaving the READ;
  clamped at both ends; Escape still exits with .F.. Mouse focus works
  too: clicking a listbox row focuses the control and selects that row,
  and PgDn/PgUp page from there (click on row 2 -> It2, PgDn -> It5,
  PgUp -> It2). PgDn on a non-listbox control keeps stock reader
  behavior (replay untrapped, READ exits with .F. on the last GET).
  Implemented in HBWindow:Activate (SetKey trap + clamped Down/Up
  injection, same var-sync path as the mouse layer), so every generated
  dialog gets it. The trap saves previous handlers on a stack, so
  consecutive and nested dialogs restore their own level, and a leaked
  idle re-arm after the READ is a no-op. Suite covers: page clamps at
  the first/last item, handler restore, consecutive and nested
  install/remove, idle-leak guard. The generated LISTBOX carries no
  SCROLLBAR clause.
- Clipboard and history: Tab selects a control, ^C copies it (hint
  "Copied <type>"), ^V pastes a fresh clone one cell off with a fresh
  unique variable name (hint "Pasted <type>", second label visible one
  row below the original), ^Z undoes the paste, ^Y redoes it (canvas
  captures each step). ^C/^X with no selection now show "Select a
  control first (Tab / click)" instead of failing silently.
- Dialog colors roundtrip: F3 opens Dialog properties, clicking the
  Back field focuses it, typing overstrikes W -> B, OK repaints the
  whole canvas in the new palette (buttons, radio and listbox
  recombine), and reopening F3 shows Back: B persisted.
- List control palettes: no constant cyan. RadioGroup selected marker is
  bright black on the dialog background; ListBox rows paint on the dialog
  background, current item is subtle bright black, focused cursor is the
  green bar; moving the cursor leaves no color trail (runtime captures).
- Hint bar distinguishes move vs resize: "Arrows move Mouse resizes"
  (canvas and post-drop variants).

- Move/resize/delete dogfood: arrow-move shifts the selected control one
  cell per key, Del deletes it and ^Z restores it, click selects a
  listbox and dragging its bottom-right handle resizes it; the resize is
  a normal undoable model edit (^Z reverts the extra row).
- ListBox empty interior: after a mouse resize the rows below the last
  item kept showing the dialog background even when selected. The canvas
  painter only drew item rows; it now fills the empty interior with the
  control color, matching the runtime listbox, which paints the whole
  box with its own colorspec (live captures: uniform green selected,
  uniform blue unselected).
- RadioGroup value roundtrip (generated runtime): keyboard (Tab to the
  group, Down to Option 2, OK) applies nVar=2; direct mouse clicks on
  options move the selection (clicked row -> selection via the MouseClick
  screen-marker scan) and OK applies nVar=3. Verified against an
  instrumented build that dumps the dialog vars after Activate.
- Full build cycle: F2 palette -> CheckBox -> ghost placement with
  status-bar guidance -> click drops it; F4 inspector (F6/click focuses
  the panel, Up/Down pick a field, Enter opens the inline GET, Enter
  applies) renames its caption; F9 confirms the overwrite and
  regenerates the PRG with the new control; F11 "Save JSON as..." writes
  the model (9 controls, new checkbox included) to a scratch file; F12
  reopens it intact. The regenerated PRG compiles and runs, and the new
  checkbox toggles by mouse at runtime.
- Persistence scope note: F9 regenerates the PRG from the in-memory
  model, not from the previous PRG text. The 12-item listbox literal
  once seen in a generated finddlg.prg was a manual edit of that PRG;
  the model (and finddlg.json) holds 3 items, so a regen drops manual
  PRG edits. Model/JSON roundtrip is the covered persistence path;
  PRG-to-model import is not a feature.

## Harness notes (how to reproduce)

- Launch: xterm on DISPLAY :99, geometry 82x26, `metaSendsEscape: true`,
  LANG=C.UTF-8; kill old xterms before driving (focus stealing).
- Capture with `xwd -id` of the named window (SaveScreen is blank on the
  headless GT - no screen-readback tests possible).
- Mouse cell->pixel for a window at +X+Y: px = X+2+9*(col-0.5),
  py = Y+2+18*(row-0.5), cells 1-based (font 18 => cell ~9x18 px).
- The standalone harness oIde:Repaint() must emulate HBIde:Repaint()'s
  full-screen erase. With a no-op Repaint the Dialog() half-size centering
  (+1 row/col span, normalized by the designer's FitWindow) leaves stale
  frame cells after the first Redraw; in the real IDE the full-screen
  erase clears them, so the +1 frame is only a transient flash at open,
  not a persistent repaint defect (verified pixel-wise, k139-k142).
- xwd captures the screen region, including occluding windows: kill or
  move other xterms before capturing or the shot shows the occluder.

## Inspector inline edit (live-verified, dsn61 captures)

- The inline editor now echoes while typing: the control-redraw idle
  (hb_IdleAdd DrawControls -> DrawInspector) was repainting the inspector
  on every InKey tick, wiping the edit overlay the same instant it was
  drawn. InspEdit wraps its loop in SuspendUI()/ResumeUI().
- DsnNormKey gained: K_END mapping (EXT 18 was unmapped, End was a no-op
  in every EXT loop), printable pass-through (gttrm delivers text events
  with a 0x200 marker in the modifier word, shift pre-applied in nLow;
  the marker is masked off, not treated as a modifier), and BackSpace
  (gttrm EXT delivers nLow 23; classic 8 also accepted).
- Verified end to end in xterm: Home/End/BackSpace/Del, shifted symbols
  ("<", ">"), Ctrl+Y field clear (DSNK_CTRL_Y), Enter apply, live echo
  with visible cursor, roundtrip apply preserved the original caption.

## Known limits / open items

- No keyboard resize binding: resize is mouse-drag only; the hint bar now
  says so explicitly ("Arrows move Mouse resizes").
- The "?" glyph issue reported in IDE-integrated runs was isolated by the
  IDE lane to DispBox output outside the IDE (same xterm/launcher, both
  EN and UTF-8 codepages clean); not attributable to hbwindow/designer.
  The UTF-8 opt-in is intentionally not used by codegen.
- Publish flow: atomic /edit/ editor fill per file (EditorView dispatch);
  delete+upload is forbidden to avoid windows with missing sources.

## 2026-10-25 checkpoint: QueueOpen publish clarification, drag diagnostics, full flow

### Factual clarification of commit a2b269d

a2b269d carries GitHub's auto-default commit message ("Update print statement
from 'Hello' to 'Goodbye'"), which does not describe its content. The commit
actually contains: the QueueOpen contract in hbide.prg
(cPendingOpen/QueueOpen/ClearPendingOpen/OpenInEditor, the post-Activate
pending-open block, and the caption refresh) and four
hb_UTF8ToStr -> hb_UTF8ToStrBox conversions ported from editor-fixes d8eb435.
History is kept as-is per repo policy; this entry is the correction.

### Drag diagnostics: prior "fast gesture" limitation retracted

Traced with the new DSN_TRACE instrumentation plus a gttrm mouse logger on
the same transport: the flakiness previously attributed to fast drag gestures
was a test-harness aiming error (window-relative screenshot coordinates used
as root coordinates), not an application defect and not a timing constraint.

- Fast move-drag: single +36px jump moved a RadioGroup col 8 -> 14
  (DragControl exit after ~2ms). Fast resize-drag: single +30px jump grew a
  GET width 16 -> 21. Both land directly; DragControl/DragResize busy-poll
  MLeftDown()/MRow()/MCol() and do not consume the Inkey queue; the button-up
  event arrives queued in the main loop after the drag (benign).
- Transport check: paced, burst and jump mouse sequences are delivered 1:1
  (XTEST -> Xvfb -> xterm -> gttrm -> Inkey), no coalescing or loss.
- The earlier "~300ms pacing" guidance and the "deselect on drag" and dead
  Open-dialog-OK click observations were all the same aiming error.

### DsnTrace instrumentation

designer.prg logs optional diagnostics to /tmp/dsn_trace.log only when the
DSN_TRACE env var is set; disabled by default, no effect otherwise. Logged:
PRESS/HIT (pointer, window rect, view offsets, control index and geometry),
DRAG/RESIZE enter+exit with iteration counts, main-loop UP, window fit, and
designer start. Coordinates and geometry only - never captions, control
names or other model content.

### Full real-use flow (this session)

Composition arranged without overlapping controls (RadioGroup (2,8), GET
(8,10) width 21), saved via F10, regenerated via "Generate and open"
(overwrite confirm -> editor opens mydialog.prg through the QueueOpen path),
compiled externally with hbmk2 and run standalone: the dialog renders as
designed and is interactive (radiogroup selection changes on click).
Suite: 359/359 with the instrumentation in place.

Known limitation: codegen emits a plain `Dlg_<Name>()` function with no Main
entry point, so running a generated dialog needs a wrapper procedure plus the
support modules (hbwindow, hbmenu, hbbutton, hbgetu) linked in, as done above.
Direct Run of a generated dialog from the IDE is therefore not claimed. The
IDE Run > Start item is broken on this branch under Linux (hardcoded
darwin/clang hbmk2 path and hardcoded noname.prg); a working Start exists on
editor-fixes and its integration is being coordinated with the IDE lane.

## 2026-10-25 checkpoint: editor-fixes hbide.prg integration

Coordinated integration with the IDE lane (editor-fixes). Comparison against
merge-base 994c8c7 showed a clean lane split, so both sides are preserved
verbatim:

- Taken from editor-fixes: hbide.prg (functional superset of this branch's:
  same QueueOpen contract, XTermMetaEsc, Alt-menu-reserved loop, caption
  refresh, UTF8ToStrBox, plus the repaired Run > Start - current editor file,
  hbmk2 from PATH, BuildFlags, ConfirmOverwrite, lAutoRun, repaint; plus
  CheckUnsaved/CheckDiskChange/NewFile/SaveAs/ReplaceDialog/Help and the
  HB_INKEY_EXT + hb_keyStd input evolution), editor.prg, help.prg,
  hbide.hbp (adds help.prg and the vendored hbdebug/ tree; already listed
  hbgetu.prg), ChangeLog.txt, docs/editor-checkpoint-2026-10-24/25.md and
  the new hbdebug/ directory (vendored Harbour source debugger).
- Kept from designer-robustness (editor-fixes never touched them since the
  merge-base): designer.prg, hbwindow.prg, hbmenu.prg, tests/,
  docs/DESIGNER_VALIDATION.md, docs/designer.md, docs/examples/,
  tests/manual/roundtrip/, .gitignore.
- hbbutton.prg: changed on both sides; this branch's version is a strict
  superset (ef's HbBtnPadChars/HbBtnShadowChars/BtnPatch already ported,
  plus hb_U* mnemonic handling, bracket-style rendering and BtnHitTest), so
  this branch's file is kept.

Verified on the integrated tree: hbmk2 build clean (0 errors/warnings),
suite 359/359, Generate-and-open with dirty model - discard No keeps the
designer, shows "(not queued)" and a later real exit does NOT open the file;
discard Yes opens mydialog.prg in the editor via QueueOpen. Run > Start on a
standalone PRG (function Main) compiles the current editor file with hbmk2
from PATH, shows the captured compiler output, auto-runs the built
executable and repaints the IDE cleanly after the child exits. Note: Start
requires hbmk2 on the IDE process PATH.

Still documented: designer codegen emits a Main-less Dlg_<Name>() function,
so running a generated dialog keeps requiring a wrapper plus the support
modules; no auto-wrapper is added in this block.

## 2026-10-25 addendum: editor lane final rounds (baseline eaadb60)

Two later editor-fixes rounds were integrated verbatim after byte-level
divergence checks (this branch's copies were identical to the editor lane's
pre-change versions both times, so nothing local was lost):

- 926c109 (commits c5958bf/8ef49bf/529580d): editor.prg multiline block
  comments with state management, cache-frontier fix, phantom-highlight
  repaint fix; ChangeLog and editor checkpoint doc updates.
- 7b7259f/a93240b/d7222fe/e2b2f00 (commits 50012ad/c4557a4/025e759/eaadb60):
  HBIDE_MsgAlert (defined in hbide.prg) replaces Alert at 25 call sites with
  the accepted visual style (white dialog, green pushbuttons, shadow),
  Enter/Space fires the focused button, SetKey state is restored; editor.prg,
  ChangeLog and checkpoint doc updated accordingly.

hbide.hbp, help.prg, hbdebug/ and this branch's designer files were not
touched by these rounds; hbbutton.prg stays as this branch's superset.
Verified on the final remote bytes at eaadb60: hbmk2 build clean
(0 errors/warnings), suite 359/359. Windows remains unverified.
