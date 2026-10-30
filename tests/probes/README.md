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
