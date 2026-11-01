# Vendored Harbour source debugger

The fourteen upstream-derived compiled sources in this directory were compared
with the local Harbour checkout at commit
`694428e1c12f726675b19324d62167fa77d68185`, remote
`https://github.com/harbour/core.git`. This is a comparison reference, not proof
of the exact original import revision. An earlier README described snapshot
r2610240856 and claimed that only two files had changed. That description is
historical and does not describe the current tree.

At the Q427 comparison, four complete compiled files are byte-identical to that
checkout: `dbgbrwsr.prg`, `dbgtmenu.prg`, `dbgtmitm.prg` and `dbgwa.prg`.
Ten differ outside their initial notices: `dbghelp.prg`, `dbgmenu.prg`,
`dbgtarr.prg`, `dbgthsh.prg`, `dbgtinp.prg`, `dbgtobj.prg`, `dbgtwin.prg`,
`tbrwtext.prg`, `debugger.prg` and `dbgentry.c`. All fourteen initial comment
notices match the comparison checkout. `en.txt`, the bundled debugger help,
is byte-identical to its upstream counterpart. `dbgscript.prg` is an additional
local compiled helper with no same-named file in that checkout.

The IDE carries local debugger behavior changes in its repository rather than
changing the shared Harbour toolchain. These include returning from debugger
Quit to the IDE, resetting per-session VM state, and changes to menus, editing,
search, variables and window behavior. The two original Quit/reset examples
are not an exhaustive change list. File hashes and comparison results are in
`docs/evidence/harbour-provenance-refresh-q427.json`; the earlier comparison is
`docs/evidence/harbour-notice-provenance-q353.json`.

The upstream notices describe GPL v2-or-later terms and a Harbour exception.
The literal upstream license reference is kept separately in
`third-party/harbour/LICENSE.upstream.txt`, with its provenance alongside it.
This records upstream text, not a license selection for hbide's own code or
modifications. The root `LICENSE.txt` reference remains missing. Holders' terms,
modified-file exception scope, dependency notices and final-package review
remain open. Neither matching headers nor this README clears redistribution.
