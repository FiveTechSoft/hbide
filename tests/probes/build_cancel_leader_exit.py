"""Leader exits before readiness; its child remains finite and never detaches."""
import os, pathlib, subprocess
root = pathlib.Path(os.environ['HBIDE_PROBE_PID_DIR'])
(root / 'parent.pid').write_text(str(os.getpid()))
child = subprocess.Popen(['/usr/bin/python3', '-c', 'import time; time.sleep(3)'])
(root / 'child.pid').write_text(str(child.pid))
# No STARTED token: the ownership probe must not signal an unverified group.
