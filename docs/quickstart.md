# Quick start

From zero to your first debug session with hbide, in a few minutes.

## 1. What you need

- A terminal on Linux, Windows, macOS or Android.
- A Harbour build, so the `hbmk2` build tool is available. Either put
  `hbmk2` on your PATH, or clone and build
  [harbour/core](https://github.com/harbour/core) next to hbide; the
  `go.sh` script looks for `../harbour/bin/<platform>/<compiler>/hbmk2`.

## 2. Build hbide

```sh
git clone -b designer-robustness https://github.com/FiveTechSoft/hbide.git
cd hbide
hbmk2 hbide.hbp     # or ./go.sh, which also starts the IDE
```

This produces `./hbide` (`hbide.exe` on Windows).

## 3. Meet the screen

```text
 File  Edit  Project  Window  Run  Options  Help       <- menu bar (Alt+letter)
+--------------------------- noname.prg ---------------------------+
| 1  function Main()                                               |
| 2                                                                |
| 3     ? "Hello hbide"    <- your code, with colours for          |
| 4                          keywords, strings and comments        |
+------------------------------------------------------------------+
 INS                                             row: 3, col: 5     <- status bar
```

- Alt+letter opens a menu (Alt+F for File). Arrows move, Enter runs the
  selected option, Esc closes.
- F1 opens help about whatever is selected: a menu option or the editor.

Terminal tips for Linux: use a UTF-8 locale (`LANG=...UTF-8`) so borders
and button shadows draw correctly - otherwise hbide shows a
"Locale not UTF-8" notice and you may see "?" glyphs. In xterm, start it
with `-xrm 'XTerm*metaSendsEscape: true'` so Alt+letter reaches the IDE.

## 4. Edit, save, run

1. Type the three lines from the diagram above.
2. Press F2 (or File > Save) and name the file `hello.prg`. Each save
   attempts to keep the previous version as a `.bak` copy; a backup failure is reported but does not block the save.
3. Run > Start saves the file, calls `hbmk2` and runs the program only if
   the build succeeded. A failed build never deletes your previous binary
   and never runs it.

## 5. Debug it

1. Put the cursor on the `?` line and press F9: a red mark appears in the
   gutter.
2. Run > Debug. The Harbour debugger stops at your breakpoint.
3. F8 steps into, F10 steps over, F5 continues to the next breakpoint,
   F4 shows your program's screen, Alt+X returns to the IDE.

## 6. Where next

- Open several files and switch between them with Ctrl+F6.
- Draw a dialog with Options > Designer... (guide: [designer.md](designer.md)).
- Browse the built-in manual with Help > Contents; F7 searches it.
- Every menu and key: [user-guide.md](user-guide.md).
