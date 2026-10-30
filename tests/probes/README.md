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
