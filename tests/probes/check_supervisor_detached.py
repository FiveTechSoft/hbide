"""Observe finite detached negative without signalling any process."""
import json,os,pathlib,subprocess,sys,tempfile,time
exe=str(pathlib.Path(sys.argv[1]).resolve())
fixture=pathlib.Path(__file__).with_name('build_cancel_detached_finite.py').resolve()
def state(pid):
    p=pathlib.Path('/proc')/str(pid)/'stat'
    return None if not p.exists() else p.read_text().rsplit(')',1)[1].split()
with tempfile.TemporaryDirectory(prefix='hbide-supervisor-detached-') as tmp:
    start=time.monotonic()
    p=subprocess.run(['/usr/bin/setsid',exe,str(fixture)],env=dict(os.environ,HBIDE_PROBE_PID_DIR=tmp),capture_output=True,text=True,timeout=8)
    elapsed=time.monotonic()-start
    pid=int((pathlib.Path(tmp)/'child.pid').read_text());s=state(pid)
    r={'supervisor_exit':p.returncode,'seconds':round(elapsed,3),'stdout':p.stdout,'stderr':p.stderr,'child_state_on_return':s[0] if s else 'gone','child_pgrp':int(s[2]) if s else None,'child_session':int(s[3]) if s else None}
    assert p.returncode==0 and elapsed<2 and 'GROUP_EMPTY' in p.stdout and s and s[0]!='Z',r
    end=time.monotonic()+5
    while time.monotonic()<end:
        s=state(pid)
        if s is None or s[0]=='Z':break
        time.sleep(.03)
    else:raise AssertionError('finite child unexpectedly still alive')
    r['child_after_finite_lifetime']='gone' if s is None else s[0]
    r['signal_sent']=False
    print(json.dumps(r,indent=2))
