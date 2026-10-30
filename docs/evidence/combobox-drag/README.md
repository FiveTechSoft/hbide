# Integrated ComboBox physical resize, Linux40x120

On bab3533 product binary: actual IDE, JSON load, physical mouse press on
selected ComboBox bottom-right handle cell19,59, move to21,64, release.
Save JSON gives width25,height8 from20x6; CtrlZ/Save gives20x6 and
CtrlY/Save returns25x8. Whole control arrays after/redo match, row/col0/0
unchanged. Long synthetic When text is preserved. No handler executed.

Inspected full-size before/resized/redo pixels: combo face gets wider,
handle moves right/down, canvas/editor lower borders and status remain
visible. This is designer appearance, not generated popup runtime pixels.

Excluded setup attempts: first F10 opened terminal menu instead of Save;
ShortcutsNoMenukey=TRUE was set only in isolated terminal profile. Initial
pixel coordinates clicked cell18,56 inside the control, moving it instead
of resizing. A diagnostic trace established actual cell19,59; corrected
coordinates exercised RESIZE, no product change. The saved script disables
that trace and asserts final saved arrays. It uses a local checkout path;
adjust it on another machine. Needs Xvfb, xfce4-terminal, xdotool, ImageMagick.

This is one ComboBox resize with undo/redo, not all drag directions, minimums,
panning, cancellation, controls, terminal geometries or Windows acceptance.

## Documented minimums, separate run

On the5d4cb20 built binary, physical ComboBox handle shrink past the origin
clamps to4x4; Undo/Save20x6 then Redo/Save4x4 preserve exact controls.
Physical GET shrink10->1, Undo/Save10 and Redo/Save1 also match; actual
F12 reload and Save retain width1 and exact control array. These runs
exercise the documented minima without changing inspector/property minima.
Full screenshots inspected: ComboBox face One/drop arrow fits width4 and
its handle is at bottom-right of reserved4-row area; GET atwidth1 is entirely
covered by selected resize handle. That overlap is observed, not certified
as ideal visual affordance. Borders/status stay intact. No product fix.

Scripts capture-min.py/capture-get-min.py contain exact assertions. Results
are results-min.json/results-get-min.json; reloaded GET equality is asserted
by the script but not a separate row in the result JSON. Initial scripts
inherit synthetic extra items on GET; it has no runtime effect in this test.
No pan, other controls, Windows or global acceptance is implied.
