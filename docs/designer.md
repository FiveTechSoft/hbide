# HbIde Dialog Designer

First version of the interactive dialog designer, written in pure Harbour
(no C code). Design a dialog visually inside hbide, save it as JSON and
generate Harbour code that rebuilds it with `HBWindow`.

## How to use

Open it from `Options > Designer...`. A window appears in the center of the
IDE: that window *is* the dialog you are designing. You can drag it by its
frame and resize it from the bottom-right corner with the mouse.

| Key      | Action |
|----------|--------|
| F2 or right-click | Palette: add Label (SAY), Input (GET), CheckBox, PushButton, RadioGroup or ListBox; dialog properties; save/open/generate |
| Arrows   | Move the ghost while placing, or move the selected control one cell |
| Mouse    | Click to select, drag to move, click to drop while placing |
| Enter    | Drop the ghost (while placing) or edit the selected control properties |
| Tab / Shift+Tab | Select next / previous control |
| Del      | Delete the selected control |
| F3       | Dialog properties (caption, name, width, height, color) |
| F9       | Generate `<name>.prg` |
| F10      | Save `<name>.json` |
| F12      | Load a JSON dialog |
| Esc      | Cancel placing / exit (asks if there are unsaved changes) |

Control properties (Enter on a selected control): row, column, caption,
variable and width, depending on the control type. Variables are normalized
to valid Harbour identifiers.

## JSON format

Coordinates are relative to the dialog client area, zero based.

```json
{
  "name": "MyDialog",
  "caption": "My Dialog",
  "width": 41,
  "height": 13,
  "color": "W+/W",
  "controls":
  [
    { "type": "say",      "row": 2, "col": 4, "caption": "Label" },
    { "type": "get",      "row": 4, "col": 4, "variable": "cVar2", "width": 10 },
    { "type": "checkbox", "row": 6, "col": 4, "caption": "Check", "variable": "lVar3" },
    { "type": "button",   "row": 9, "col": 4, "caption": "&OK" }
  ]
}
```

`type` is one of `say`, `get`, `checkbox`, `button`, `radiogroup`, `listbox`. Radio groups and list boxes keep their options in the `items` property (comma separated); a `&` before a letter in a radio item makes it that option's accelerator (painted in a distinct color); the generated PRG uses the standard `@ ... GET ... RADIOGROUP` / `LISTBOX` clauses with an array of `RadioButto()` objects or item strings. See
`docs/examples/mydialog.json` and the code generated from it in
`docs/examples/mydialog.prg`.

## Object inspector (F4)

F4 toggles a floating, non-modal inspector panel. It shows the properties of
the selected control, or of the dialog itself when no control is selected.

- F6 (or a click inside the panel) moves keyboard focus between the canvas
  and the inspector.
- Up/Down choose a field, Left/Right adjust numeric fields by one (the
  control moves or resizes live on the canvas), Enter edits text fields
  inline.
- Ctrl+Arrows move the panel; it can also be dragged by its title bar.
- Esc returns focus to the canvas. F4 hides the panel.

## Generated code

F9 writes `<name>.prg` with a function `Dlg_<Name>()` that recreates the
dialog with `HBWindow():Dialog()`, `oDlg:Say()` and `@ ... GET` commands,
ready to compile against hbide's own `hbwindow.prg` (see
`docs/examples/mydialog.prg`).

## Architecture notes

- `designer.prg`: all the designer. The `HbDesigner` class owns the UI;
  the functions `DsnBuildModel()`, `DsnControlSize()`, `DsnDrawControl()`,
  `DsnValidVar()` and `DsnGenCode()` are UI-free and testable.
- `hbwindow.prg`: `HbWindow` has an optional `bPopup` callback; in design
  mode the right-click invokes it. Without `bPopup` the previous popup is
  kept intact.
- `hbmenu.prg`: popup menus now close after running the selected action.
- `tests/test_designer.prg`: non-interactive checks for the model, the
  JSON round trip and the code generator.

## Robustness fixes (second pass)

- Popup menus created by the designer no longer crash with error 9001 on
  letter hotkeys: standalone popups (lPopup) handle their own hotkeys in
  `hbmenu.prg` instead of deferring to the top-bar menu handler.
- Duplicate hotkeys in the designer popup renamed ("~PushButton",
  "ListBo~x") so every item is reachable by keyboard.
- `DsnUniqueVar()` + type-aware generator: a repeated variable name with an
  incompatible type (text vs logical vs numeric) is renamed in the generated
  code (`cName` -> `cName2`) and counted in the hint; the model is untouched.
- RadioGroup/ListBox without items are skipped in generated code with an
  explanatory comment instead of emitting broken `@ ... RADIO` lines.
- LoadJson validates the model (`DsnValidModel`) and normalizes control
  fields with coercion/clamps (`DsnNormalizeControls`); invalid entries are
  skipped and reported in the hint, the original file is never overwritten
  on load (cFileName cleared, dialog marked dirty when entries are skipped).
- SAY captions draw "&" literally; checkbox width excludes the "&" marker.
- F9 asks for confirmation before overwriting an existing .prg (Alert).
- Alert dialogs suspend/resume the designer UI so the canvas repaints.
- Designer popup geometry clamped to MaxRow()/MaxCol() so it never draws
  off-screen on terminals smaller than the menu.

### Display encoding note (investigated, not a defect)

The designer draws button shadows and GET fills with CP437 bytes
(`Chr(220)`, `Chr(223)`, `Chr(176)`), matching `hbwindow.prg`. gttrm
detects UTF-8 terminals (LANG/IUTF8) and translates those bytes to UTF-8
block glyphs automatically; verified at byte level (Chr(220) -> E2 96 84
on a UTF-8 terminal). Strange glyphs only appear when the terminal itself
runs a mismatched locale (e.g. Latin-1 xterm), which affects every CP437
byte the app emits, not just the designer.

### Verified interactively (Xvfb + xdotool, real app)

- Mouse drag of a control updates its row/col (inspector shows new values).
- Inspector panel drags by its title bar.
- Full flow: open designer, place all control types, generate, save JSON,
  reload, discard confirmation.

## Roadmap (not in this version)

- Control resize handles (only move is supported)
- Undo/redo, copy/paste of controls
- Grid/snap and alignment helpers
- Opening the generated .prg directly in the editor

## Property popup focus indicator (2026-10-24)

The Control properties, Dialog properties and file-name popups now give every
plain GET an explicit color (`N/W,W+/B,W+/W,GR+/W`), so the focused field shows
a solid blue highlight. Previously these GETs inherited the dialog color, so
there was no visible focus indicator and blind editing could corrupt fields.
Verified interactively: built the `docs/examples/buildoptions.json` dialog with
the designer itself (8 controls, distinct Build/Cancel actions), generated the
PRG, compiled it and ran it: typing, Tab navigation, checkbox, radiogroup
accelerators and both button paths (Build sets lOk, Cancel ends with no
effects) all work.

## Field entry behavior and listbox item data (2026-10-24, second pass)

Characterized per keystroke while editing the example dialog:

- Numeric GETs (PICTURE "999", e.g. Width/Height): the first key on a freshly
  focused field replaces the whole value, so typing "22" over "31" yields 22.
- Text GETs (e.g. Items, Caption): typing on a freshly focused field overtypes
  at the cursor and any tail of the old value survives. The focused field shows
  a solid highlight, so the remaining tail is visible; delete it explicitly.
  This is stock Harbour GET behavior, not a designer defect.
- Popups commit through their OK pushbutton; clicking OK is the reliable way
  to apply edits.

Listbox items are data, not prompts: the codegen now emits them verbatim into
the generated array and the designer canvas paints them verbatim, so literal
values such as "R&D.prg" survive round trips. Radio items keep "&" as the
hotkey marker. Covered by tests/test_designer.prg (107 checks) and verified
interactively: docs/examples/buildoptions.json was repaired in the designer
itself (height 31 -> 22 via numeric replace, items "&Main.prg,..." cleaned to
"Main.prg,Utils.prg,Res.rc"), saved, regenerated, recompiled and run; the
listbox renders and navigates the verbatim items, Build accepts (lOk = .T.)
and Cancel exits with no effects (lOk = .F.).

## Mouse support in dialogs (2026-10-24)

During READ (HbWindow:Activate) an idle hook polls the mouse: clicking a
control moves focus to it, clicking a checkbox toggles it, clicking a
pushbutton activates it, and clicking a listbox or radiogroup item selects
it by stuffing the exact Up/Down keystrokes (commits 9238a98, cf944d3).

Control geometry and state are read from the screen buffer, not from the
control internals, which are PROTECTED in Harbour's control classes and
whose GET buffers stay NIL:

- Framed hit-test: each framed control's real extents are recovered by
  scanning the SaveScreen bytes for its border characters. Single- and
  double-line styles are accepted, in both CP437 and UTF-16-low-byte
  encodings (gttrm under a UTF-8 terminal stores UTF-16 low bytes).
  Double-line matters because focused controls redraw their frame double.
  Items live one row inside the frame.
- Current radiogroup selection: the "(*)" marker next to the control
  origin on screen.
- Current listbox selection: the item row whose attribute byte differs
  from the first item row (the selection bar). Only rows with text count,
  so a listbox taller than its items still maps correctly.
- Clicks arriving while READ is busy navigating between GETs are queued
  and retried for up to 3 s from the idle hook instead of being dropped.

Known limits, pending variant testing before this can be called general:
color schemes where the selection-bar attribute equals the first row's,
and non-standard frame styles. Scrolled listboxes are covered: clicking a
visible row selects topItem + row (verified on docs/examples/findreplace,
see below). Verified so far on docs/examples/
buildoptions with the stock colors: clicks select Exe/Library/Dll and
Main.prg/Utils.prg/Res.rc in both directions, each control independently
of the other, clicks outside and on frame borders are no-ops, and the
checkbox still toggles by click.

## Designer popup close contract

In the designer's own popups (control properties, dialog properties, file
pickers): Esc or the Cancel pushbutton discards the edits; any other READ
exit (OK pushbutton, Ctrl+W) commits them. Before commit 3659afa, Ctrl+W
silently discarded edits. Generated dialogs keep their own semantics: the
code generator cannot know which button is Cancel, so they close via
their buttons or Esc.

## Find and Replace example: variants and listbox geometry (2026-10-24)

docs/examples/findreplace.json (10 controls: two SAY/GET pairs, two
checkboxes, a radiogroup, a listbox, three pushbuttons) was edited, saved,
regenerated, recompiled and verified interactively in two variants:

- Dialog resize via F3 dialog properties: 56x20 -> 62x22 (numeric replace
  on Width/Height), F10 save, F9 generate (Overwrite? -> Yes).
- Listbox height 4 -> 6 via the object inspector (F4, F6 to focus, Down to
  the Height field, Right to adjust): the canvas reflects the new height
  immediately and the regenerated PRG carries it.

Listbox effective geometry: a listbox of height N shows N - 2 item rows;
the top and bottom frame rows are not items. Height 4 -> 2 visible rows and
height 6 -> 4 visible rows are both correct, not defects.

Both variants compiled clean and passed the same runtime battery in a
separate xterm: typing into a GET, checkbox toggle by click, radiogroup
selection by click, listbox item selection by click, scrolling with Down
and clicking a visible row after the scroll (bar lands on the absolute
item, topItem + row), and the Find pushbutton closing the dialog with
lOk = .T.

Two caveats stay open:

- Dialog-level color: F3 exposes a Color field for the dialog color
  (Harbour color string, e.g. "W+/B"); the canvas repaints with the new
  color as soon as the dialog is accepted. Input is validated
  structurally (comma-separated fg[/bg] pairs; foreground letters
  W B G R N C M Y U I X, each with an optional "+" or "*" suffix). Empty
  input or an invalid string keeps the previous color and says so in the
  status bar ("Color left empty: keeping ..." / "Invalid color '<x>':
  keeping ...") instead of failing silently. The color round-trips
  through F10/F12 as the JSON "color" property and the generated PRG
  emits it as the last argument of HBWindow():Dialog().
  Control palettes derive from the dialog color: the default white
  dialog keeps hbide's own palettes byte-exact, and on any other
  background Say/CheckBox/RadioGroup captions paint in the dialog's
  own fg/bg, GET and ListBox fields paint black-on-white for contrast,
  and PushButtons paint as a white button. The button shadow follows
  the dialog background (hbbutton's stock display hardcodes a white
  shadow, so the generated PRG re-registers the same display with the
  shadow repainted "N/<bg>"); the canvas preview paints the same
  derived scheme, including the half-height button shadow.
- Viewport fit: loading a dialog, resizing it in F3 or from the
  inspector repositions the design window so it and its shadow stay
  fully on screen. The model keeps the dialog's saved size (grown to
  the minimum that keeps every control visible); when the dialog is
  larger than the screen the design window acts as a viewport onto it,
  controls beyond the edge are clipped on the canvas but never lost
  from the model, and saving or generating keeps the true size.
  Moving a control repaints the canvas, so no ghost of its old
  position remains.
- Checkbox glyph: Harbour's stock checkbox paints CP437 0xFB (the square
  root glyph) for the checked state; in a UTF-8 terminal that byte renders
  as "u with circumflex" (the EN codepage, the only one selectable in this
  build, maps 0xFB to U+00FB instead of U+221A; hb_cdpSelect("CP437") is a
  no-op and "ES" raises an argument error). Generated dialogs therefore
  emit STYLE "[X ]", the same ASCII style the IDE itself uses, so the
  checked state is a portable [X] everywhere. The designer canvas
  paints checkboxes in the same ASCII "[ ]" style, so no stray glyph
  appears there either.
