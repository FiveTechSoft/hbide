#!/usr/bin/env python3
# Structural regression guard for the journal-recovery guards in hbide.prg.
#
# Two invariants, both found by the PTY multidoc E2E (26-Oct-2026):
#
# 1. RecoverJournal must keep its own CheckUnsaved in the FindDoc > 0 branch
#    (route already open in another doc): switching to that doc and loading
#    the journaled text over a dirty buffer is only allowed after the user
#    explicitly resolves that buffer (Save/Discard). Cancel must abort the
#    recovery and keep the journal. This branch is NOT reachable from boot
#    flows today (RecoveryCheck runs with only the boot noname doc open and
#    hbide opens no argv/session files before it), so it cannot be exercised
#    by the PTY E2E; this guard pins the protection structurally.
#
# 2. RecoveryCheck must NOT call CheckUnsaved before RecoverJournal: in batch
#    recovery (several pending journals) that pre-check forced resolving the
#    buffer recovered one iteration earlier, and choosing Discard silently
#    lost freshly recovered work. RecoverJournal covers every case without
#    data loss (reuses only a clean noname, appends otherwise).
import re, sys

src = open('hbide.prg').read()

m = re.search(r'METHOD RecoverJournal\(.*?\n(.*?)\nENDCLASS|\Z', src, re.S)
# recover method body up to the next METHOD at column 0
m = re.search(r'METHOD RecoverJournal\( cKey, cTarget \) CLASS HbIde(.*?)\nMETHOD ', src, re.S)
if not m:
    print('FAIL: RecoverJournal not found'); sys.exit(1)
body = m.group(1)

i_find = body.find('FindDoc')
i_switch = body.find('SwitchDoc')
i_check = body.find('CheckUnsaved')
i_load = body.find('LoadText')
ok1 = 0 <= i_find < i_switch < i_check < i_load
print(('PASS' if ok1 else 'FAIL'),
      'RecoverJournal: FindDoc>0 -> SwitchDoc -> CheckUnsaved before LoadText')

m2 = re.search(r'METHOD RecoveryCheck\(\) CLASS HbIde(.*?)\nMETHOD ', src, re.S)
body2 = m2.group(1)
case_recover = body2.split('case nPick == 1')[1].split('case nPick == 2')[0]
code = '\n'.join(l for l in case_recover.splitlines() if not l.strip().startswith('//'))
ok2 = '::CheckUnsaved' not in code
print(('PASS' if ok2 else 'FAIL'),
      'RecoveryCheck: no pre-CheckUnsaved before RecoverJournal (batch recovery)')

sys.exit(0 if (ok1 and ok2) else 1)
