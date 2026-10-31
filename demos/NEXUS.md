# NEXUS demo

Interactive Harbour showcase with hbide's own HbWindow, GET PushButton,
hbgetu and HbMenu classes. Fictional sample data only; no external services.
Designed and checked on Linux native terminal, 120 columns x 40 rows.

Open `demos/nexus.prg` in hbide, choose Run > Script. The IDE already links
the GUI classes. Escape returns to the source editor.

Standalone build from repository root: `hbmk2 demos/nexus.hbp`.
Run the resulting `demos/nexus` in a UTF-8 120x40 terminal.

- Run scenario: moves the next sample project to READY and refreshes summary.
- Inspect data: opens a real modal window with a sample record.
- Export CSV: writes four current rows to `nexus-demo.csv` in working folder.
- Reset: restores the initial statuses and scenario counter.
- Exit or Escape: returns to the caller.
- Tab/Enter and mouse activate the actual GET buttons.

Left-hand feature names and chart are information, not dummy navigation.
Revenue bars are illustrative and independent of project portfolio totals.
The screenshot proves this demo, not Windows support or full IDE acceptance.
