# Build errors, Go to Function, Run arguments, Save All

First P0 batch from [the Turbo C++ comparison](turbo-cpp-comparison-2026-10-29.md).
Verified on Linux (PTY test `tests/test_nav_pty.py`, 30 checks). Not run on
Windows. Alt+F7/F8 and Ctrl+F2 depend on the terminal delivering those
keys; every action is also in a menu.

## Compiler messages -> source line

- Run > Start parses the hbmk2 output (Harbour `file(line) Error ...` and
  C compiler `file:line:col:` forms). After a failed build the cursor lands
  on the first error.
- Alt+F8 next message, Alt+F7 previous (wraps around). Window > Messages
  opens a filterable list; Enter jumps.
- The status row shows `n/total LEVEL: text` until the next key.
- A project build (Project > Sources / Build) feeds the same list.
- Messages are replaced by every new build. Paths are relative to the
  current directory, as hbmk2 prints them.

## Go to Function

Ctrl+G or Edit > Go to Function. Lists `FUNCTION`, `PROCEDURE` (also
`STATIC`/`INIT`/`EXIT`), `CLASS` and `METHOD ... CLASS x` of the current
document. Type to filter, Enter jumps. Commented lines, `/* */` blocks and
`#pragma begindump` C blocks are ignored. The entry containing the cursor
is preselected.

## Run > Arguments

Arguments are kept for the session (not saved to disk).

- Start: split into words (double quotes group words), then each word is
  single-quoted for the shell (double-quoted on Windows, untested). `;`, `&`,
  `|`, `$`, backticks and `>` are literal argument text, never extra commands;
  variables are not expanded.
- Script and Debug: the same words, split with quotes honoured, arrive as the
  parameters of `Main()`. `hb_argv()` does not see them in these two modes.

## Save All and Window list

- Ctrl+F2 or File > Save All saves every modified document that has a name,
  through the normal save path (`.bak` copy, disk-change check). Untitled
  buffers are never saved silently: they are counted and left modified.
  A failed save leaves that buffer modified and is reported by the normal save
  path; Save All then ends with a summary (saved / failed / untitled skipped).
  Failure injection (unwritable directory) was not verified in the PTY test.
- Alt+0 or Window > List shows all open documents (`*` = modified, `>` =
  current). Type to filter, Enter switches.

## Not part of this batch

No change to F2 palette letters, Menu Bar hide/show, PRG-to-designer import
or any P1/P2 item.
