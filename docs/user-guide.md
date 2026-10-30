# hbide user guide

Menus, keys and features, with diagrams. Everything here describes the
current sources on `designer-robustness`, verified on Linux. Where Windows
behaviour is not yet validated, the text says so.

## The screen

```text
 File  Edit  Project  Window  Run  Options  Help       <- menu bar
+--------------------------- noname.prg ---------------------------+
| 1  #include "hbclass.ch"                                         |
| 2                                                                |
| 3  function Main()                                               |
| 4     local n := 1          <- editing area, one window per file |
| 5     ? n                    red gutter mark = breakpoint (F9)   |
+------------------------------------------------------------------+
 INS   MARK                                      row: 4, col: 5     <- status bar
```

- Menu bar: Alt+letter opens a menu, arrows move, Enter runs, Esc closes.
- Status bar: INS/OVR (Ins toggles), MARK when a selection is anchored
  (F8), and the cursor position.
- If your locale is not UTF-8, a "Locale not UTF-8" notice appears on the
  right of the menu bar; see "Terminal notes" below.

## Menus

| Menu | Options |
| --- | --- |
| File | New, Open..., Save (F2), Save As..., Save All (Ctrl+F2), Close, Exit |
| Edit | Undo (Ctrl+Z), Redo (Ctrl+U), Copy, Cut, Paste, Delete Line (Ctrl+Y), Duplicate Line, Find... (F5), Repeat Last Find (F3), Replace..., Goto Line..., Go to Function... (Ctrl+G) |
| Project | Open .hbp..., Sources / Build..., Close project |
| Window | Next (Ctrl+F6), Previous (Ctrl+Shift+F6), Close, List... (Alt+0), Messages..., Next Message (Alt+F8), Previous Message (Alt+F7) |
| Run | Start, Script, Debug, Arguments... |
| Options | Compiler Flags..., Display..., Designer... |
| Help | Index, Contents, About... |

Copy, Cut and Paste act on the selected range when one is active, and on
the current line otherwise.

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| F1 | Help about the selected menu option or the editor |
| F2 | Save |
| F3 | Repeat last find |
| F5 | Find... |
| F8 | Anchor / extend a selection range from the cursor |
| F9 | Toggle a breakpoint on the current line |
| Ins | Insert / overwrite mode |
| Ctrl+Z / Ctrl+U | Undo / redo (typing coalesces per line) |
| Ctrl+Y | Delete line |
| Ctrl+Right / Alt+Left | Move by word forward / back (Ctrl+Left also jumps back on terminals that deliver extended key codes; otherwise it arrives as Undo) |
| Ctrl+F6 / Ctrl+Shift+F6 | Next / previous document |
| Alt+0 / Ctrl+F2 | Window list / Save All |
| Ctrl+G | Go to function, procedure or method |
| Alt+F8 / Alt+F7 | Next / previous compiler message (details: [navigation-build-run](navigation-build-run-2026-10-29.md)) |
| Alt+letter | Open menus and activate dialog hotkeys |
| Esc | Close menus and dialogs, cancel |

In dialogs: Tab / Shift+Tab move between fields, arrows move inside a
field or list, Enter confirms, Space toggles.

## Multiple documents

File > New and File > Open... add documents; the Window menu and
Ctrl+F6 / Ctrl+Shift+F6 switch between them. Each document keeps its own
text, name, dirty flag, undo/redo history, cursor, scroll, selection and
breakpoints. Close asks only about the current document; Exit reviews all
of them. Save As refuses to overwrite a path that is open in another
document.

## Saving and safety

- Saves create an exclusive sibling temp and check the full write and close
  before replacement. POSIX rename replacement is atomic; Windows uses
  park-and-replace and is not atomic or natively validated here. There is no
  fsync/power-loss guarantee. Partial write failure keeps the original and
  buffer, without promising a complete recovery copy. A complete temp is kept
  and named if a later step fails. F2 attempts a `.bak` copy; a backup failure
  is reported but does not block saving.
- hbide watches the file on disk. If it changes externally you can Reload
  or Keep mine; saving over external changes asks first; if the file was
  deleted you can Recreate it or Cancel.
- Run > Start saves before building, and a blocked save cancels the build
  instead of compiling stale disk content.

## Crash recovery

While a buffer has unsaved changes, hbide keeps a journal of its full text
in `~/.hbide/recovery` (override with `HBIDE_RECOVERY_DIR`), refreshed on
the 2-second tick of the main loop and written atomically.

```text
 editing (unsaved changes)     every 2 s while dirty
         |                             v
         +---------->  journal in ~/.hbide/recovery
                              |
                   hbide is killed or crashes
                              |
                    next start: journal found
                              |
              +-----------+-----------+----------+
              | Recover   | Discard   | Later    |
              +-----------+-----------+----------+
                  |            |            |
        text back as an   journal      journal stays
        unsaved buffer    deleted      for the next start
```

What to expect:

- You get the content of the last 2-second tick, not of every keystroke.
- Unnamed buffers are recovered too.
- Each running instance keeps its own journal, so saving or discarding in
  one never deletes another instance's unsaved work.
- If the journal cannot be written (permissions, full disk), editing
  continues and hbide warns once per failure streak; recovery is never
  silently assumed.
- One journal per absolute path: aliases or symlinks to the same file
  produce separate journals.

Compare gives a read-only summary before deciding. For UTF-8 journals it
reconstructs save bytes with the recorded codepage and BOM only after a
lossless roundtrip. Unknown codepages do not produce a reconstructed comparison. View bytes opens journal editor
payload and raw disk snapshots (J/D), with scrolling, Home/End and Esc back.
The hex is exact; control and non-ASCII bytes appear as dots in the ASCII column.
This is not a line diff or a decoded Unicode text preview. Viewing does not
recover, save or discard. Failed journal reads/metadata and unknown codepages
leave the current document and journal untouched.

## Build and run

- Run > Start saves the current file and builds it with `hbmk2` (which
  must be on PATH) next to the source. The new executable replaces the old
  one only after a verified success; a failed build keeps the previous
  binary untouched and never runs it.
- Run > Script compiles the current buffer in memory and runs it inside
  the IDE process, without saving.
- Options > Compiler Flags... sets Warnings, Debug info, Strict types,
  Incremental, Optimize code and Run after build. The flags persist and apply to
  Run > Start.

## Debugger

Run > Debug compiles the current buffer with debug info and starts the
Harbour source debugger inside the IDE. Breakpoints set with F9 in the
editor (red gutter marks) apply automatically; they follow the code when
you insert or delete lines above them.

| Key | Action |
| --- | --- |
| F5 | Continue / stop at the next breakpoint |
| F7 | Run to cursor |
| F8 | Step into |
| F10 | Trace over |
| Ctrl+F5 | Next routine |
| F4 | Show the debugged program's screen |
| F9 | Toggle breakpoint |
| Tab / Shift+Tab | Cycle focus between debugger windows |
| F2 | Zoom (maximize) the focused window; again to restore |
| Alt+X | Leave the debugger and return to the IDE |

Windows can be moved, resized, zoomed, tiled and cascaded from the
debugger's own menus. Known limits: Animate can still damage the display
(F4 shows the program screen to recover the view); the debugger first stops on
the wrapper's init procedure line, so press F5 or F7 to reach your code. See
[debugger-checkpoint-2026-10-25.md](debugger-checkpoint-2026-10-25.md) for
the verified inventory.

## Projects

- Project > Open .hbp... reads a project file: members (sources,
  subprojects, configuration) and entries it cannot resolve (macros,
  wildcards, filters) are listed as such, never guessed.
- Project > Sources / Build... opens the project desktop: source list,
  build with hbmk2 and a Messages view with the parsed diagnostics
  (`file(line) Error/Warning` for Harbour, `file:line:col:` for GCC).
  Selecting a diagnostic opens the file at that line and column.
- A build reports success only from this build's exit code, never from an
  executable left by an earlier one.

See [project-module-2026-10-26.md](project-module-2026-10-26.md) for the
module contract and boundaries.

## Options

- Compiler Flags...: see "Build and run" above.
- Display...: console size presets 40x120, 30x100 and 25x80. If the
  terminal refuses the resize, hbide reverts and says so.
- Designer...: the dialog designer.

## Dialog designer

Options > Designer... opens a window that *is* the dialog you design:
drag it by the frame, resize from the bottom-right corner. F2 (or
right-click) opens the palette: Label, Input, CheckBox, PushButton,
RadioGroup and ListBox, plus dialog properties, save, load and generate.
F10 saves the design as JSON, F9 generates the Harbour `.prg`, F12 loads
a JSON design, Ctrl+Z / Ctrl+Y undo and redo model changes. The full
guide, JSON format and generated-code contract are in
[designer.md](designer.md); the validation status in
[DESIGNER_VALIDATION.md](DESIGNER_VALIDATION.md).

## Help system

F1 is contextual: on a highlighted menu option it explains that option
without running it; in the editor it opens the manual. Help > Contents
opens the browser:

```text
+-- Contents ------------------------------------------------+
| +-- Index ----------+  +-- Topic ------------------------+ |
| | 1. Basics         |  | File menu                       | |
| | 2. Editing, files |  |                                 | |
| |   File menu  <----|--| New       creates a document    | |
| | 3. Build and run  |  | Open...   opens a file          | |
| | 4. Advanced       |  | Save (F2) saves the buffer      | |
| | 5. Help and about |  |                                 | |
| +-------------------+  +---------------------------------+ |
|  [Search]  [Next]  [Export .md]  [Close]                   |
+-------------------------------------------------------------+
```

- Tab / Shift+Tab cycle focus: index, text, buttons.
- Index: arrows and PgUp/PgDn move, Enter or Right opens the topic.
- Text: arrows scroll, Left/Right go to the previous/next topic.
- F7 or Search finds in titles and bodies; F3 or Next jumps to the next
  match; the status line shows "Match i/n".
- The manual covers this whole guide from inside the IDE: quick start,
  screen map, menus, documents, saving, crash recovery, build, debugger,
  projects, options, designer, terminal notes and platform status.
- Export .md writes the whole manual as `hbide-help.md` in the current
  directory.
- In contextual F1 help, Backspace returns to the previous topic and
  Alt+Right goes forward again. The two-pane browser uses Left/Right.
- Sections 6-8 contain every complete Markdown document from the repository,
  available offline, searchable and included in Export .md. Dated
  checkpoints describe historical verification, not new tests.

Limits: the search positions topic and line but does not highlight inside
the text, and the section tree is always expanded. Details in
[help-browser.md](help-browser.md).

## Terminal notes (Linux)

- Use a UTF-8 locale (`LANG=...UTF-8`): borders, buttons and shadows are
  CP437 glyphs that only render correctly in UTF-8 mode. hbide shows a
  "Locale not UTF-8" notice otherwise.
- Alt+letter needs the terminal to send a meta ESC prefix. In xterm:
  `-xrm 'XTerm*metaSendsEscape: true'`.
- The IDE is tested at 25x80 and 40x120.

## Platform status and known limits

- Verified interactively and with automated tests on Linux.
- Windows: the IDE builds with GTWVT and a prebuilt `hbide.exe` is
  included, but it can lag behind the sources; validating the latest
  sources on Windows is pending.
- Debugger Animate has known visual defects.
- The full plan and honest per-area status live in
  [ROADMAP.md](ROADMAP.md).
