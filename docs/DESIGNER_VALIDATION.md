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
  Escape exits with .F.. PgDn while on the listbox (last GET) exits the
  READ with .F. - stock Harbour reader behavior; the generated LISTBOX
  does not page on PgDn and carries no SCROLLBAR clause.
- List control palettes: no constant cyan. RadioGroup selected marker is
  bright black on the dialog background; ListBox rows paint on the dialog
  background, current item is subtle bright black, focused cursor is the
  green bar; moving the cursor leaves no color trail (runtime captures).
- Hint bar distinguishes move vs resize: "Arrows move Mouse resizes"
  (canvas and post-drop variants).

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

## Known limits / open items

- No keyboard resize binding: resize is mouse-drag only; the hint bar now
  says so explicitly ("Arrows move Mouse resizes").
- The "?" glyph issue reported in IDE-integrated runs was isolated by the
  IDE lane to DispBox output outside the IDE (same xterm/launcher, both
  EN and UTF-8 codepages clean); not attributable to hbwindow/designer.
  The UTF-8 opt-in is intentionally not used by codegen.
- Publish flow: atomic /edit/ editor fill per file (EditorView dispatch);
  delete+upload is forbidden to avoid windows with missing sources.
