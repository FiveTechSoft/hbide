# Project model and diagnostics (independent module)

This change adds `project.prg`, not a finished project UI. It does not touch the
reserved editor, Start/OpenFile, designer or build menu integration.

## Contract

`oProject := HBIDEProject():New()`

- `Open(cHbp)` returns logical. Requires an existing .hbp. On failure it clears
  the previous project so an accidental Build cannot target an old project.
- `cFile`, `cRoot`: absolute normalized project filename and directory.
- `cOriginal`: original bytes; this module never writes the .hbp.
- `aMembers`: hashes `path, token, line, exists, kind`. Literal PRG, CH, C, CPP,
  H, HBP, HBM and HBC references only. `kind` distinguishes source, subproject
  and configuration. Duplicates are removed. Missing files remain visible.
- `aUnresolved`: `{hbpLine, token, reason}` arrays for filters, macros,
  wildcards, @ references or unbalanced quotes. These are not guessed, expanded
  or treated as verified source members.
- `Info(cHbmk2)` calls real hbmk2 `--hbinfo`, returns logical and fills `hInfo`
  with the returned target metadata. This is NOT a complete source graph.
- `Build(cHbmk2,lRebuild)` returns logical and fills `hBuild` with
  `exit, output, command, ok, diagnostics`. `ok` is based solely on exit zero,
  never on an executable left by an earlier build. `-rebuild` is optional.
  A trailing `-run-` disables the project-level `-run` option. There is no
  Run operation in this module. Supply the configured absolute hbmk2 path.
- `cError` contains the last failure summary.
- Each diagnostic has `path, line, column, level, text, raw`. Harbour
  `file(line) Error/Warning` and GCC/Clang `file:line[:column]: error/warning`
  are recognized, including drive-letter paths. Other output is retained.

All work is Harbour. No new C module or library is needed. Add `project.prg`
to the IDE's source list when integration is accepted.

## Integration needed, not included

1. Project > Open selects .hbp and displays members plus unresolved entries.
2. Opening a member routes its resolved `path` through the future multibuffer
   owner; it must not overwrite a modified single buffer.
3. Compile/build invokes `Build` explicitly. Populate the Messages view with
   the full output and diagnostic list, including builds that fail to launch.
4. Selecting a diagnostic requests the editor owner open its path and jump to
   its 1-based line/column. Do not claim a jump succeeded until the editor
   confirms the actual file and position.
5. Run remains separate and must be disabled after a failed build. A proper
   target launch needs output path/targettype validation from hbmk2 metadata,
   not an assumed executable extension.

## Boundaries

The source list is deliberately conservative, not a second hbmk2 interpreter.
It does not recursively parse HBP/HBM/HBC, expand environment/macros, discover
implicit includes, or rewrite options. Raw project data remains available.
A build is synchronous and temporarily changes process cwd, restoring it after
the process returns or raises. Do not call it concurrently with other cwd-
sensitive work. It has no cancellation, timeout or progress UI yet.
Stdout and stderr are captured separately then concatenated; their original
interleaving is not preserved. This does not affect parsed file positions.
Building a project uses hbmk2 and its normal hooks/plugins. A file from an
untrusted source is not safe to build merely because it ends in .hbp.
Linux was compiled and run; no Windows runtime claim is made.

## Verification

Build and run `tests/test_project.prg` together with `project.prg` using
`-gtstd`. Pass the absolute hbmk2 path as the test program's first argument.
The test uses a temporary two-source project with a CH include. It verifies:

- actual successful build and hbinfo target metadata;
- intentional syntax error in source 2, exact file and line 2;
- failed build does not run the prior executable;
- successful build does not run either, even with -run in .hbp;
- project/source names and directory containing spaces;
- process-launch failure and cwd restoration;
- unchanged project bytes and cleared state after failed Open;
- missing members, quotes and explicit unresolved filters/macros/wildcards;
- synthetic Harbour warning and Windows GCC drive/line/column diagnostics.

These tests have no visual UI; no UI screenshot is offered as proof of a
project manager or Messages panel that does not yet exist.