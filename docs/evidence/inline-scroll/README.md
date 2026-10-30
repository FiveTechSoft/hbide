# Inline event scroll visual, Linux40x120

Direct designer fixture on76d750e, GTTRM in real terminal. Inspected actual
pixels: long When field initially shows _TAIL at end, Home shows Start_ at
beginning; Esc removes edit highlight and returns nonediting inspector.
Inspector, canvas lower borders and status remain visible. No CLS/redraw
between the three captures. Initial canvas setup uses CLS/redraw.

This is not the full IDE, automatic modal restoration, cursor-placement
certification or Windows acceptance. The gray block on the blank canvas is the selected ComboBox resize handle
(DrawControls/ResizeHandlePos), not the inline caret. The initial capture did
not establish caret position because terminal cursor blinking was enabled.
See ../inline-integrated/README.md for the separate integrated check.
First terminal startup closed before focus; second attempt captured the
three states. That setup failure is not counted as a product failure/pass.
