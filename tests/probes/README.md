# Build cancellation feasibility probe (Linux only)

This is not a release acceptance suite and does not implement cancellation.
It demonstrates why killing only the direct compiler process is unsafe.
Run in a disposable environment; the child sleeps for 15 seconds and exits.
The parent process writes two PID files under `/tmp`. Delete those files after
checking them. Never interpret a zero process result alone as build success
when cancellation was requested.

```
hbmk2 tests/probes/build_cancel_process.prg -gtstd -o/tmp/build-cancel-probe
/tmp/build-cancel-probe "$PWD/tests/probes/build_cancel_child.py"
```

Observed October30,2026 with Harbour694428e on Linux:
- nonblocking read received `STARTED`, process still running (`-1`)
- `hb_processClose(handle,.F.)` returned true
- `hb_processValue(handle,.T.)` returned0 after termination by signal
- direct process was gone; its spawned child was still alive

The exploratory run explicitly killed the remaining child afterward. This
probe itself lets that child expire after 15 seconds. It is not safe to use
this pattern for cancelling real builds, whose descendants may keep writing.
A finished implementation must own the entire build tree, drain output
without deadlock, record cancellation separately from exit code, restore the
working directory, and never launch a stale executable. Windows needs its
own verified process-tree behavior.

## Isolated Linux process-group probe

```
hbmk2 tests/probes/build_cancel_group.prg hbunix.hbc -gtstd -o/tmp/build-cancel-group
/tmp/build-cancel-group "$PWD/tests/probes/build_cancel_child.py"
```

This second exploratory probe starts the child under `/usr/bin/setsid` and
uses `posix_kill(-processHandle,"KILL")`. In this Linux test both direct
process and its child were gone immediately afterward. Kill returned0
(success), while processValue again returned0. This is evidence that group
isolation can address this specific descendant case, not a production-safe
implementation. It depends on an external utility, assumes the utility does
not fork, and has no group-identity check before signalling. Production must
verify that the group is newly owned by this build, handle startup failure,
check cancellation completion, and account for descendants that detach.
Never apply this probe to an existing or shared process group.

No Windows/macOS result is implied. No timeout, output flood, interactive
compiler, detached descendant, UI cancellation or artifact-commit acceptance
has been added to the IDE by either probe.

## Ownership-checked Linux probe

`build_cancel_owned.prg` adds a bounded startup check: `/proc/<pid>/stat`
PID, process group and session must all equal the newly returned process
handle, and stdout must contain STARTED. Immediately before signalling it
checks process starttime/group/session again and confirms the child is still
running. Both stdout and stderr are drained with short reads. Cancellation
has its own flag, independent of the observed exit0 after a signal.

```
hbmk2 tests/probes/build_cancel_owned.prg hbunix.hbc -gtstd -o/tmp/build-cancel-owned
/tmp/build-cancel-owned "$PWD/tests/probes/build_cancel_child.py"
```

Observed Linux run: OWNED true, CANCELLED true, group kill0, exit0; direct
process and spawned child absent afterward. This closes only the missing
identity-check experiment. `/proc` check-to-signal still has a race; escaped
sessions, process-group leader exit before cancellation, output floods,
startup failures, timeouts, interactive compilers and UI integration are not
accepted by this probe. No production build path or Windows support changed.
Do not call this production-safe ownership or finished cancellation.

### Finite pipe flood and missing-script check

`python tests/probes/check_cancel_owned.py /tmp/build-cancel-owned` drives
`build_cancel_flood.py`, which writes256KiB to each pipe before STARTED.
The probe drains both completely, cancels its owned group, and the harness
checks both recorded processes are gone. A missing Python script exits2;
the probe returns failure without signalling any group. These tests do not
cover a missing setsid/Python executable, an infinite flood, detached child,
leader exit, UI cancellation or Windows. PID files use a unique test directory.

### Leader exit is not tree completion

`build_cancel_leader_exit.py` starts a child that lives3seconds and exits
before emitting STARTED. The ownership probe returns failure without a group
signal, despite observed leader exit0. The child was still running when the
probe returned, then was confirmed gone after its bounded lifetime. This is
an expected negative, not cancellation acceptance. A supervisor that stays
alive while descendants exist needs separate investigation before integration.

## Debugger screen snapshot feasibility (Linux GTTRM)

`debug_screen_snapshot.prg` checks the mechanism used by the vendored debugger:
HB_GTI_GETWIN returns a seven-element screen/cursor snapshot and SETWIN restores
it into the active GT buffer. It is not an independent hidden rendering context
on the default GT implementation (`harbour/src/rtl/hbgtcore.c`, cases GETWIN and
SETWIN). The fixture restores two different snapshots exactly, then proves
application output while the debugger snapshot is active modifies that active
buffer. No product behavior changes and no visual/UI acceptance is claimed.

The manual `hbdebug/en.txt:427-438` says Exchange Screens defaults ON and Swap
on Input matters only with Exchange OFF. Keeping a debugger picture visible
while application output is captured privately therefore needs a separate
rendering mechanism, not skipping RestoreAppScreen alone. Input-idle callbacks
are not a universal signal: `harbour/src/rtl/idle.c` invokes them for idle sleep
as well as the GT INKEY loop. Selective input swapping remains unimplemented;
no Windows or all-input guarantee is implied by these source observations.

```
hbmk2 tests/probes/debug_screen_snapshot.prg -gttrm -o/tmp/debug-screen-snapshot
/tmp/debug-screen-snapshot /tmp/debug-screen-snapshot.json
```
