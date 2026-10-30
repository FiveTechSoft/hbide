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

### Separate hidden NUL GT buffer

`debug_hidden_gt.prg` creates a NUL GT context and switches to it only for
application output. On Linux GTTRM the original visible buffer stays byte-exact;
the hidden output can be copied back through SETWIN when effective dimensions
match. The first25x80-request fixture failed full equality because GTTRM actually
had24rows while NUL had25; the corrected fixture uses the visible buffer's actual
row/column count. This is not a completed Exchange OFF design. NUL input,
keyboard forwarding, resize, colors/codepages, application GT calls, exceptions,
external writes and switching back safely during VM/debugger stops remain open.
The demo in Harbour tests/gtwin.prg documents independent real console windows
only for drivers that support them (WVT/XWC), not generic GTTRM windows.

### Hidden GT input and color isolation

`debug_hidden_input.prg` proves only synthetic-key behavior: a key queued in
visible GTTRM is not consumed by hidden NUL, its own synthetic key is consumed
there, and both contexts retain distinct SetColor values. Real keyboard input
forwarding is NOT tested. A hidden application context cannot simply assume it
will receive keys queued on the visible context. This is another integration
requirement, not an implemented Swap on Input feature.

### Real terminal key while NUL is selected

`check_hidden_real_input.py` sends `z` through a real PTY after a ready marker
written while NUL is selected. Hidden Inkey(.6) returns0; after GTTRM is selected,
Inkey(.6) returns122. Both waits are bounded. This confirms automatic forwarding
is absent in this fixture, beyond the synthetic-queue observation. It does not
prove an idle bridge safe for READ, extended keys, mouse, resize or nested input.

### Idle forwarding is possible, but idle is not input-only

`debug_hidden_idle_bridge.prg` with `check_hidden_idle_bridge.py` moves an actual
PTY `z` from visible GTTRM into hidden NUL in an idle callback. Bounded Inkey
returns122 and the visible saved buffer plus hidden color remain unchanged.
A control run calls hb_idleSleep before Inkey: the callback already moves that
key during sleep (NextKey sees122). Therefore an unfiltered idle callback cannot
serve as the Swap on Input signal. Stack inspection in this isolated fixture
shows INKEY versus HB_IDLESLEEP in ProcName(2), a possible discriminator to test,
not a supported universal API or acceptance of READ, mouse, extended keys,
nested input, resize, exceptions or debugger stop transitions.

The initial context assertion compared hb_gtSelect handles and falsely failed:
the Harbour wrapper allocates a fresh GC holder on every call, so holder equality
is not underlying GT identity. Corrected fixture checks distinct per-GT color
state instead. Both original raw observations are retained in the evidence.
No debugger UI or application execution path has been changed by these probes.

### Input-read hook is narrower than idle, but not a wait/return hook

`debug_input_hook.prg` tests HB_GTI_INKEYREAD on hidden NUL (Linux/GTSTD host).
It is not called by hb_idleSleep; both nonblocking Inkey() and timed Inkey(.05)
call it once. Source hbgtcore.c:2978-2986 passes no wait/timeout/event-mask
arguments and has no matching after-input callback. A nonzero hook result65
returns65 but LastKey remains0 in the probe, because the early return bypasses
the normal inkeyLast assignment. Using a hook return for forwarding would alter
application-visible LastKey semantics unless handled separately. These are
constraints on a possible design, not an integrated Swap on Input feature.

## Restart lifecycle experiment, not debugger Restart

Manual en.txt:329-331 says Restart terminates and re-executes while preserving
debugger settings. The command parser still has TODO RESTART; there is no menu
item or accepted restart implementation. hbvm.h exposes debug/break/cancel/quit/
endproc requests, not a restart request in the inspected API. The IDE uses
hb_HrbRun; Quit Break unwinds past its internal unload.

`debug_restart_lifecycle.prg` instead owns hb_hrbLoad/hb_hrbDo/hb_hrbUnload handles
for two uniquely named FORCELOCAL HRBs. Each synthetic app increments a static,
logs run1, then Breaks. The host catches the marker, explicitly unloads and logs
the EXIT procedure. Result run1;exit;run1;exit; proves this isolated cleanup/reset
path, not VM restart, debugger state preservation or general process reset.
Initial draft lacked REQUEST GETENV for dynamically compiled code and hit a
bounded8second error dialog; adding the explicit dynamic dependency fixed it.
No product execution path changed. Settings/points mapping across new temporary
module names, host resources, public memvars, database/workareas, external side
effects, app EXIT failures and Windows remain unverified. Restart cannot undo
files, network calls or other side effects already performed by the app.

### Unload does not reset application resources

`debug_restart_resources.prg` creates a synthetic public memvar, changes SET
DECIMALS to7, opens a DBFCDX workarea and writes a record before Break. After
owned HRB unload, all those states survive: public variable exists, decimals7,
workarea open, record present and file on disk. The fixture then closes/releases
its own state and deletes its synthetic file. This is an expected negative for
process-like Restart, not a product failure or reset implementation. General
close-all/reset-all would risk host IDE state and is not a safe inferred fix.
Resource ownership/isolation and preserving debugger settings remain design
constraints; do not promise that starting another HRB is a clean application
restart. No user files, production debugger execution or Windows were tested.

## Finite leader-exit supervisor experiment (Linux only)

`build_supervisor.prg` is a separate executable run under setsid. It starts the
existing finite leader-exit fixture, records the direct exit0, and remains alive
while `/proc` contains live non-zombie members of its own process group. The
checked run lasts about3seconds, not immediate leader completion. Harness
`check_build_supervisor.py` confirms both recorded fixture processes gone or
zombie after GROUP_EMPTY. This is one feasibility experiment, not reliable
process-tree ownership or production cancellation. `/proc` scanning is racy;
unreadable/disappearing entries, new forks, escaped sessions, PID reuse, zombies,
output drainage/floods, interactive tools, timeout cleanup and Windows are not
accepted. The bounded6second timeout does not kill remaining descendants, so
only use the finite3second fixture. Do not integrate this scan as proof that
arbitrary compiler descendants have finished. No IDE build path changed.

Build: `hbmk2 tests/probes/build_supervisor.prg hbunix.hbc -gtstd -o/tmp/build-supervisor`
Then: `python tests/probes/check_build_supervisor.py /tmp/build-supervisor`.
Initial draft referenced nonexistent hb_ProcessId; corrected to hbunix
posix_getpid before running. This was a probe build error, not an IDE defect.
