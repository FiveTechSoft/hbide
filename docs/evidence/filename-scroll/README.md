# SelectFileName horizontal scroll, Linux40x120

Before: default80chars was truncated to35 before GET; exact returned string
folder with spaces/segmentsegmentse instead of full path. Typing past35
filled field and advanced focus. Fix uses capacityMax255/Len(default)+20
and visible PICTURE@S35; default/typed80chars now pass exact native queued
picker assertions. This is not arbitrary-length path or filesystem support.

Actual full IDE F11, CtrlY clears default, type synthetic long path, Home,
Esc. Full pixels inspected: tail.json and beginning folder with spaces/
visible within field, buttons/lower borders intact; Esc removes dialog and
restores canvas/editor/status. No file saved or private data used.
First visual typed without clearing default; discarded and rerunCtrlY.
Initial queued run exceeded default typeahead buffer and timed out; fixture
sets512 before asserting. These setup errors are not product evidence.

Screens are from local uncommitted fix, source follows commit. capture.py
uses local checkout path, Xvfb/xfce4-terminal/xdotool/ImageMagick; terminal
profile disables only its F10 menu shortcut and cursor blink. This is focal
Linux40x120, not25x80, every input method, filenameUndoLoad or Windows.
