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
| F3       | Dialog properties (caption, name, width, height) |
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

## Roadmap (not in this version)

- RadioButton and ListBox controls
- Control resize handles (only move is supported)
- Undo/redo, copy/paste of controls
- Grid/snap and alignment helpers
- Opening the generated .prg directly in the editor
