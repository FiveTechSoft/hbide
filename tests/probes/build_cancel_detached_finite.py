"""Finite negative: child changes session and closes inherited output pipes."""
import os,pathlib,subprocess
root=pathlib.Path(os.environ['HBIDE_PROBE_PID_DIR'])
(root/'parent.pid').write_text(str(os.getpid()))
child=subprocess.Popen(['/usr/bin/python3','-c','import time;time.sleep(3)'],start_new_session=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
(root/'child.pid').write_text(str(child.pid))
