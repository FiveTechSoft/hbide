# hbide vs the Borland Turbo C/C++ IDE

29 October 2026. Requested by the project owner: compare hbide with the
Turbo C/C++ IDE and see how hbide can be completed. This document analyses
and proposes; it does not mark anything as implemented.

## Reference edition

The user's reference is "el IDE de Turbo C/C++". Several editions existed
and they differ, so this document anchors on one:

**Turbo C++ 3.0 for DOS (1991)** - the classic blue Turbo Vision IDE.
Verified edition differences that matter here:

- Turbo C 2.0 (1989): no syntax highlighting, no code examples in the
  help, no mouse-driven windowed editing. It added breakpoints and
  Ctrl+F1 language help over 1.x.
- Turbo C++ 3.0 (1991): added colour syntax highlighting, help with code
  examples, mouse, overlapping edit windows, debug watches and projects.
  Contemporary press confirms highlighting shipped in 3.0.
- Borland C++ (same years) was the professional line; extras like the
  SpeedBar are Borland C++, not Turbo C++ 3.0, and are not used here.

Features from different editions are never merged into one claim.

## The Turbo C++ 3.0 IDE on one screen

```text
 File Edit Search Run Compile Debug Project Options Window Help
 +--------------------------------------------------------------+
 | editor window 1 (overlapping, mouse, syntax colours)         |
 +--------------------------------------------------------------+
 | editor window 2                                              |
 +--------------------------------------------------------------+
 | Message / Watch / Output windows (compiler errors, watches)  |
 +--------------------------------------------------------------+
 F1 Help   Alt+F7/F8 prev/next error   F9 Make   Ctrl+F9 Run
```

## Area by area

"hbide today" is grounded in the source on branch designer-robustness
(commit 0759fd9), not in memory or plans.

### Editing

| Capability            | TC++ 3.0            | hbide today                     |
| --------------------- | ------------------- | ------------------------------- |
| Multi-file editing    | yes, many windows   | yes, multi-doc (Ctrl+F6)        |
| Syntax highlighting   | yes (new in 3.0)    | yes (keywords, strings, comments) |
| Undo / redo           | yes                 | yes                             |
| Find / replace        | yes                 | yes                             |
| Block operations      | yes                 | yes (copy, cut, search, replace) |
| Word movement         | yes                 | yes                             |
| Mouse                 | yes                 | yes (windows, designer)         |
| UTF-8                 | no (CP437 era)      | yes, verified                   |
| Crash recovery        | no                  | yes, journals per document      |
| External-change watch | no                  | yes                             |
| Safe save / build     | no                  | yes, atomic promote on success  |

Verdict: hbide matches the editor and exceeds it on safety.

### Search and navigation

| Capability              | TC++ 3.0                 | hbide today            |
| ----------------------- | ------------------------ | ---------------------- |
| Prev/next compiler error | yes, Alt+F7 / Alt+F8    | only in project desktop |
| Locate function          | yes (after compile)     | no                     |
| Go to line               | yes                     | yes                    |

Gap: the editor cannot jump between build errors; diagnostics with
file(line):col are parsed only inside the project desktop. Gap: no
"go to procedure/function".

### Build and run

| Capability          | TC++ 3.0                    | hbide today               |
| ------------------- | --------------------------- | ------------------------- |
| Compile / make      | F9 make, Alt+F9 compile     | Run > Start via hbmk2     |
| Project build       | .PRJ + make dependencies    | .hbp desktop via hbmk2    |
| Build messages      | Message window, parsed      | parsed in project desktop |
| Run                 | Ctrl+F9                     | auto-run after build flag |
| Program arguments   | yes, Run > Arguments        | no                        |
| User screen         | Alt+F5                      | after the program ends    |

Gap: no way to pass arguments to the program from the IDE.
hbmk2 already owns dependency tracking, so no Make clone is needed.

### Debugger

| Capability            | TC++ 3.0              | hbide (Harbour debugger, vendored)      |
| --------------------- | --------------------- | --------------------------------------- |
| Step / trace          | F7 / F8               | F8 step, F10 trace, F7 to cursor        |
| Continue              | F9 make / Ctrl+F9 run | F5 go                                   |
| Breakpoints           | Ctrl+F8 + dialog      | F9, watchpoints, tracepoints            |
| Watches               | watch window          | watchpoints + monitors (locals, privates, statics, globals) |
| Evaluate / modify     | yes, Ctrl+F4          | no expression dialog                    |
| Inspect (C++ objects) | yes, Alt+F4           | n/a: C++-specific (inherited, methods)  |
| Call stack            | Ctrl+F3               | yes, View > CallStack                   |
| Program reset         | Ctrl+F2               | no in-place restart                     |
| Harbour extras        | n/a                   | workareas F6, sets, PPO view, codeblock trace, animate |

Gap: evaluate/modify of arbitrary expressions and program reset.
Some upstream menu items are stubs (Exchange Screens, swap on Input,
Menu Bar) - they exist in the menu and are not functional; do not count
them as working.

### Windows and desktop

| Capability            | TC++ 3.0                    | hbide today                  |
| --------------------- | --------------------------- | ---------------------------- |
| Zoom / next / close   | F5 / F6 / Alt+F3            | debugger windows only        |
| Tile / cascade        | yes                         | debugger windows only        |
| Size / move           | Ctrl+F5                     | debugger windows only        |
| List all windows      | Alt+0                       | no                           |
| Save all files        | yes                         | no (save is per document)    |
| Desktop persistence   | options save (era standard) | recovery journals, not layout |

Gap: the IDE's own document windows have only next/previous; tile,
cascade, zoom and a window list exist only inside the debugger.

### Help

| Capability             | TC++ 3.0                  | hbide today                        |
| ---------------------- | ------------------------- | ---------------------------------- |
| Contents / index       | yes                       | yes, 45 topics in 8 sections       |
| Topic search on word   | Ctrl+F1 on word at cursor | F1 context (Project, Window) only  |
| Language reference     | C/C++ reference + examples| full repo docs embedded offline    |
| Code examples          | yes, with copy to editor  | docs embedded; no copy-to-editor   |
| Previous topic         | Alt+F1                    | no                                 |

Gap: help on the word under the cursor against a Harbour language
reference (needs reference content), copy example into the editor,
previous topic.

### Options and environment

TC++ 3.0 had an Environment dialog (editor preferences such as tab
size, screen modes, colours) and saved the desktop. hbide today has
Compiler Flags and Display size presets; no editor preferences dialog
(tab width, autoindent) and no layout persistence. The debugger does
have Tab Width, Colors and Save/Restore Settings.

## Where hbide goes beyond Turbo C++ 3.0, per capability

Each line is one capability, verified in the current source; the "TC3
never had it" side is an absence in that IDE, not a valuation.

- Crash recovery of unsaved changes (journals). Turbo C/C++ compiled
  from in-memory buffers and relied on the F2 save habit; a crash or
  reboot lost unsaved work (toughdev.com, edition notes).
- Verified atomic builds: the previous binary is never erased on a
  failed build (temp output promoted only after exit code 0, hbide.prg
  Start()). TC3 compiled and linked directly, with no equivalent.
- External-change watch on open files (editor.prg). Not present in TC3.
- Dialog designer with live read-only code view (F5) and events routed
  to user code (WHEN/VALID/FOCUS/STATE): the design -> code direction
  of the two-way tools. The TC3 IDE had no interactive dialog designer;
  Turbo Vision 1.0 was a separate add-on library (wikipedia).
- UTF-8 editing. TC3 was a CP437-era product.

## Parity, not advantage

- Help: TC3 shipped a full offline C/C++ language reference with
  copyable code examples; hbide embeds its repository documentation
  offline but lacks word-under-cursor lookup, previous topic and
  copy-example-to-editor. Help is therefore not counted above.
- Window management: Move/Size/Zoom/Tile/Cascade exist only inside the
  debugger's own windows (docs/borland-window-layout-2026-10-26.md);
  the editor's document windows have next/previous only. The project
  desktop and multi-document tests cover build/messages and buffer
  switching, not editor window layout or session persistence.

## What we should not copy

- C++ object inspectors (Show Inherited / Show Methods): C++-specific.
- Memory models, overlays, EMS/XMS, BGI graphics, link maps: era
  hardware and DOS concerns.
- A Make workalike: hbmk2 already resolves dependencies.
- SpeedBar / toolbars: Borland C++, not Turbo C++ 3.0; revisit only if
  asked.

## Proposal to complete hbide

Ordered by real utility for Harbour work. Sizes: S (hours), M (a day),
L (several days). All in Harbour; C only where measurement proves it.

P0 - daily-coding wins (implemented 2026-10-29, see
[navigation-build-run-2026-10-29.md](navigation-build-run-2026-10-29.md);
the table above describes the state before that batch):

1. Next/previous build error in the editor (Alt+F7 / Alt+F8), jumping
   to file:line:col. Reuse the project diagnostics parser. Size M.
2. Search > Locate procedure/function (parse PROCEDURE, FUNCTION,
   CLASS, METHOD in the buffer or project). Size M.
3. Run > Arguments for Start and Debug. Size S.
4. File > Save All and Window > List (Alt+0 style) for multi-doc. Size S.

P1 - rounds out parity:

5. Debugger program reset (restart without leaving the session);
   check upstream support first. Size M.
6. Debugger evaluate/modify expression dialog; check upstream support
   and document honestly if it stays unsupported. Size M-L.
7. Tile / cascade / zoom / list for editor document windows, matching
   the debugger's window menu. Size M.
8. Help: previous topic and copy example to the editor. Size S-M.
9. Session persistence: reopen documents and layout on start
   (complements crash recovery). Size M.
10. Editor preferences: tab width, autoindent, persisted. Size S.
11. Two-way tools completion: import a generated PRG back into the
    designer (code -> design), keeping user handlers outside the
    regenerated section. Size L.

P2 - low value, only on request:

- Print from the editor.
- IDE-level DOS shell (the debugger already has OS Shell; the
  Commander work covers file management).

## Open questions for the owner

- Is Turbo C++ 3.0 (1991, DOS) the reference edition, or Borland C++?
- Priority order: is P0 the right first batch?
- Printing: worth having at all?

## Sources

- Turbo C++ 3.0 User's Guide (1992), bitsavers.org PDF archive.
- Turbo C++ version history: en.wikipedia.org/wiki/Turbo_C++
- Edition feature timeline and limits (toughdev.com, 2021):
  https://www.toughdev.com/content/2021/06/
  revisiting-borland-turbo-cc-a-great-ide-back-in-the-90s/
- Debugger dialogs and stepping (phoenix.goucher.edu course notes).
- Shortcut reference (raviroza.com, 2022).
- 1991 press coverage confirming syntax highlighting in 3.0
  (techmonitor.ai).
- hbide state: branch designer-robustness, commit 0759fd9 (this repo).
