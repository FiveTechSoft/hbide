# Recovery verification and limits, Linux, 2026-10-26

Single editor buffer, snapshots on the existing approximately 2-second
main-loop tick. This is not per-keystroke durability or a power-loss guarantee.
Menu/modal processing can delay that tick.

- Session-suffixed journals avoid cross-instance deletion on save.
- An OS byte-range lock identifies a live writer. Other processes do not
  offer its journal. The kernel releases the lock after SIGKILL.
- Recovery retains the original snapshot until successful save or explicit
  discard. Before loading a second snapshot, CheckUnsaved protects the
  current recovered buffer. Cancel leaves the next snapshot untouched.
- Journal errors produce one visible warning per failing streak; editing
  continues. Temporary writes are checked for size and content before rename.
- Relative targets are stored as absolute paths, so a different startup
  directory cannot redirect a recovered save. Symlink aliases are not merged.

Tests: test_recovery 36 checks; test_recovery_live uses independent processes
and verifies a live owner is excluded, then its intact snapshot becomes
available after kill. Linux IDE PTY kill/relaunch/recover/save flow verified
with a freshly created output file. A real PNG prompt was inspected; known
terminal button glyph defects remain visible. Windows remains unverified.

Remaining work before claiming the entire ROADMAP recovery contract:
comparison UI, storage retention policy, Windows replacement/lock behavior,
long-path key limits.
Multi-journal modal E2E (tests/test_recovery_multi.py) passes: recover A,
attempt to recover B, Cancel at CheckUnsaved, save A byte-exactly, B remains
untouched. No blanket "never loses work" claim is supported.
