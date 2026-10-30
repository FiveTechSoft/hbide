# Inline event scroll visual, Linux40x120

Direct designer fixture on76d750e, GTTRM in real terminal. Inspected actual
pixels: long When field initially shows _TAIL at end, Home shows Start_ at
beginning; Esc removes edit highlight and returns nonediting inspector.
Inspector, canvas lower borders and status remain visible. No CLS/redraw
between the three captures. Initial canvas setup uses CLS/redraw.

This is not the full IDE, automatic modal restoration, cursor-placement
certification or Windows acceptance. A block cursor is visible on the blank
canvas in this standalone fixture; no claim that it is the inline caret.
First terminal startup closed before focus; second attempt captured the
three states. That setup failure is not counted as a product failure/pass.
