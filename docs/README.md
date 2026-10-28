# hbide documentation

## Using hbide

- [quickstart.md](quickstart.md) - from clone to your first debug session.
- [user-guide.md](user-guide.md) - menus, keyboard shortcuts and features,
  with diagrams.

## Features and design

- [designer.md](designer.md) - dialog designer: usage, keys, JSON format,
  generated code and architecture notes.
- [DESIGNER_VALIDATION.md](DESIGNER_VALIDATION.md) - what the designer
  verification covers.
- [designer-events.md](designer-events.md) - events routed to code in
  generated dialogs (two-way tools).
- [designer-color-aliases.md](designer-color-aliases.md) - colour alias
  tables used by the designer.
- [help-browser.md](help-browser.md) - Help > Contents browser: layout,
  search, Markdown export and limits.
- [project-module-2026-10-26.md](project-module-2026-10-26.md) - .hbp
  project model, build and diagnostics contract.
- [context-help-2026-10-26.md](context-help-2026-10-26.md) - F1 contextual
  help notes.
- [borland-window-layout-2026-10-26.md](borland-window-layout-2026-10-26.md) -
  debugger window layout work (Move/Size/Zoom/Tile/Cascade).
- [foxpro-demo.md](foxpro-demo.md) - the FoxPro-for-DOS replica demo
  (`demos/foxpro.prg`) and what it studies.
- [calculator-demo.md](calculator-demo.md) - the calculator demo
  (`demos/calculator.prg`).

## Verification checkpoints

- [editor-checkpoint-2026-10-24.md](editor-checkpoint-2026-10-24.md) and
  [editor-checkpoint-2026-10-25.md](editor-checkpoint-2026-10-25.md) -
  editor fixes, tests and limits per block.
- [debugger-checkpoint-2026-10-25.md](debugger-checkpoint-2026-10-25.md) -
  debugger integration: fixed bugs, verified behaviour, anomalies.
- [recovery-verification-2026-10-26.md](recovery-verification-2026-10-26.md) -
  crash-recovery verification.
- [editor-repaint-2026-10-26.md](editor-repaint-2026-10-26.md) - per-keystroke
  repaint performance work.

## Planning

- [ROADMAP.md](ROADMAP.md) - direction, priorities with exit criteria,
  integration gate and open decisions. It proposes work; it does not turn
  pending items into implemented ones.

## Examples

[examples/](examples/) holds JSON designs and generated PRGs from the
designer (for example `mydialog`, `resizedemo`, `buildoptions`,
`findreplace`) plus `demobig`, a larger generated dialog.
