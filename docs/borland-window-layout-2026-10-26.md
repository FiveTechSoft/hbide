# Borland-inspired debugger window management

Base: designer-robustness 75ffd7e. New code is Harbour, using the existing HBDbWindow and browser primitives. No Borland IDE source code was copied.

> Historical checkpoint. Iconize was subsequently implemented in `533d993`.
> Current acceptance and evidence: [COMPLETION_ROADMAP.md](COMPLETION_ROADMAP.md)
> and [COMPLETION_LOG.md](COMPLETION_LOG.md).

## Implemented

- Window > Move / Size: arrow keys, Enter accepts, Esc restores original rectangle. Kept inside the desktop, menu and status rows remain free.
- Window > Zoom, F2: maximize the focused panel, invoke again to restore its rectangle.
- Window > Tile: all visible panels arranged without overlap.
- Window > Cascade: overlapping panels, focused panel painted last.
- Command equivalents: Window Move, Window Size, Window Zoom, Window Tile, Window Cascade.
- Existing Tab/Shift+Tab focus works with overlapping layouts. Mouse hit testing selects the visible topmost panel rather than a covered source window.
- Source browser, local variables, watches, call stack and command input move/resize together. Manual rectangles survive step refreshes. Existing settings serialize rectangles.
- Removed the unimplemented Iconize menu item rather than presenting a decorative action. The legacy command still reports unsupported.

## Verification

Built hbide and the runtime test with Harbour 3.2.1dev on Linux. Test command:

    hbmk2 tests/test_debug_layout.prg hbdebug/*.prg hbdebug/dbgentry.c -gttrm -otests/test_debug_layout

Geometry test covers 324 panel cases across 25/40/50 rows, 80/120/160 columns, 1-8 windows. Runtime tests cover Tile, Zoom/restore, Move accept/cancel, Size accept, Cascade and topmost hit testing.

Also tested from the actual IDE using File > Open and Run > Debug. Source, Local, Watch, Calls and Command were tiled; F10 kept layout intact while nTotal changed from 0 to 9. Inspected rendered images of the live screen buffer, including zoom, restore and cascade. Capture instrumentation is NOT in the patch.

## Remaining scope and caveats

Windows runtime not tested. The prior Animate/app-output tearing is not fixed by this layout work. Iconize, Exchange Screens, swap on Input and Menu Bar remain unimplemented. This is debugger window management, not a multifile editor/project manager. No push or merge performed here. Integrator should run full regression tests with the latest local designer/PRG-preview changes.

## Reference sources

- Turbo C++ 3.0 screenshot with visible version: https://winworldpc.com/product/turbo-c/3x
- Editor/help and Preferences screenshots: https://www.toughdev.com/content/2021/06/revisiting-borland-turbo-cc-a-great-ide-back-in-the-90s/
- Watch/Output/Message tiled reference: https://www.geeksforgeeks.org/cpp/debugging-in-turbo-cpp/
- Borland's 1990 manual, window management, status line, projects, help, editing: https://bitsavers.org/pdf/borland/turbo_c/Turbo_C++_Users_Guide_1990.pdf
- Turbo C++ 3.0 manual: https://bitsavers.org/pdf/borland/turbo_c/Turbo_C++_3.0_Users_Guide_1992.pdf
- Debugging reference: https://phoenix.goucher.edu/~kelliher/cs17/debugging.html
