# Designer color specs: alias C/M/Y vs GT reality

Finding (2026-10-26, verified with `hb_ColorToN` on the build toolchain):

- `hb_ColorToN( "N/C" )` = 0, `"N/M"` = 0, `"N/Y"` = 0 — the single letters
  C, M and Y translate to **N/N (invisible)** in the GT layer.
- Working forms: cyan `"BG"`, magenta `"RB"`, yellow `"GR+"` (brown `"GR"`).
- `DsnValidColorToken()` accepts C/M/Y (letter set `WBGRNCMYUIX`), so a
  hand-typed spec like `"C"` validates but paints invisible.

Decision: the validator is **unchanged** — rejecting C/M/Y would break
existing JSON specs and DlgProperties behavior. The inspector color picker
(`DsnColorPick`) accepts them as read-time aliases (canonicalizes C→BG,
M→RB, Y→GR+) but never emits them: everything it writes is GT-valid.
Every grid token is checked against `hb_ColorToN` in test_designer.

Backgrounds: the bright bit of a background is the blink bit — bright
backgrounds do not exist in a color pair (`hb_ColorToN("W+/B+")` equals
`"W+/B"`). The picker offers 16 foreground colors and 8 background
colors; offering a bright-background row would write values the GT
silently maps to their non-bright form (decorative option).

If a future pass wants stricter validation, the compatible path is:
keep accepting C/M/Y on READ (canonicalize to BG/RB/GR+), write only
canonical forms, and only warn — never reject old specs.
