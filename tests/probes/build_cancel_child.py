import os,subprocess,time
open('/tmp/hbide-process-parent.pid','w').write(str(os.getpid()))
p=subprocess.Popen(['/usr/bin/python3','-c','import time;time.sleep(15)'])
open('/tmp/hbide-process-grandchild.pid','w').write(str(p.pid))
print('STARTED',flush=True)
time.sleep(15)
