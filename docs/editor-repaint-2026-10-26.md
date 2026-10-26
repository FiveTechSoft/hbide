# Editor repaint verification, Linux, 2026-10-26

Baseline: cef6cab (before repaint change). Patch: da79311.
Current printable-character path without a selection uses one colored
DisplayLine instead of uncolored RefreshLine plus previous/current/next
DisplayLine. A change to block-comment state forces a full Display.
Selection replacement and wordwrap retain their general paths.

## Measured, not inferred

`tests/measure_editor_terminal.py ABSOLUTE_BINARY 500` uses a fresh HOME
and recovery directory per run, Linux gttrm, TERM=xterm, 40x120 PTY,
default template and a burst of 500 x characters. Four empty 150ms reads
end the sample, imposing 600ms idle overhead.

Two runs per binary:

| Build | Output bytes | Quiescence, seconds |
| --- | ---: | ---: |
| Before | 48124 | 0.72 |
| Before | 48124 | 0.72 |
| After | 19799 | 0.72 |
| After | 19799 | 0.72 |

This is 2.43 times less terminal traffic, NOT 2.43 times faster typing.
The harness did not demonstrate a wall-time improvement. The ordinary
non-scrolling character path has one colored-line call instead of three
and no inherited uncolored line refresh. Horizontal scroll can still
require a full display. No Windows/GTWVT run has been performed.

An early broken-binary sample was discarded after functional testing
found an undefined _REFRESH_NONE constant. It is not evidence.

## Regression

`tests/test_editor_repaint.prg`: 11 checks pass under real 25x80 PTY.
Instrumented DisplayLine/Display counts, typing, undo, redo, comment open
and close propagation, horizontal-scroll text preservation, inclusive F8
selection replacement, and wordwrap typing.

Real Linux terminal PNGs checked before/open/closed with three lines:
local alpha := 1; local beta := 2; return alpha + beta. Opening /* makes
all three lines magenta, closing */ at the end of the first line restores
syntax colors below. Cursor background remains turquoise; it is not
used as evidence of comment coloring.
