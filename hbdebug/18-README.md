# Vendored Harbour source debugger

Copied from the Harbour 3.2.1dev sources (`src/debug/`) of the toolchain
used to build hbide (Harbour snapshot r2610240856). Harbour is free software
under the GNU General Public License v2 or later (with the Harbour runtime
exception); the original copyright and license headers are kept unmodified
at the top of every file. `en.txt` is the debugger help text.

hbide carries these sources inside its own repository so the IDE can adapt
debugger behavior without touching the shared Harbour toolchain. Local
modifications:

- `debugger.prg`, `Quit()` (Alt+X / File>Exit): `__Quit()` replaced by
  `Break( NIL )` and the `__dbgSetQuit()` call removed. The debugger no
  longer kills the host process; it unwinds to the recovery point the IDE
  installs around `hb_HrbRun()`, aborting only the debugged program.
- `dbgentry.c`, added `__hbide_dbgReset()`: clears `bInside`/`bQuit` of the
  per-stack debug-info structure. A `Break()` out of the debugger skips the
  `bInside` restore in `hb_dbgActivate()`, which otherwise suppresses every
  later debug session in the same process.

Everything else is byte-identical to upstream r2610240856.
