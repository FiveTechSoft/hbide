"""Finite output flood before readiness, followed by a short-lived child tree."""
import os, pathlib, subprocess, time
root = pathlib.Path(os.environ['HBIDE_PROBE_PID_DIR'])
(root / 'parent.pid').write_text(str(os.getpid()))
child = subprocess.Popen(['/usr/bin/python3', '-c', 'import time; time.sleep(15)'])
(root / 'child.pid').write_text(str(child.pid))
for _ in range(32):
    os.write(1, b'O' * 8192)
    os.write(2, b'E' * 8192)
print('STARTED', flush=True)
time.sleep(15)
