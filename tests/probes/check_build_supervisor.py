"""Bounded Linux group-lifetime experiment, not production supervision."""
import json,os,pathlib,subprocess,sys,tempfile,time
exe=str(pathlib.Path(sys.argv[1]).resolve())
fixture=pathlib.Path(__file__).with_name('build_cancel_leader_exit.py').resolve()
with tempfile.TemporaryDirectory(prefix='hbide-supervisor-') as tmp:
    start=time.monotonic()
    p=subprocess.run(['/usr/bin/setsid',exe,str(fixture)],env=dict(os.environ,HBIDE_PROBE_PID_DIR=tmp),capture_output=True,text=True,timeout=9)
    elapsed=time.monotonic()-start
    states={}
    for file in pathlib.Path(tmp).glob('*.pid'):
        stat=pathlib.Path('/proc')/file.read_text().strip()/'stat'
        states[file.name]='gone' if not stat.exists() else stat.read_text().rsplit(')',1)[1].split()[0]
    r={'exit':p.returncode,'seconds':round(elapsed,3),'stdout':p.stdout,'stderr':p.stderr,'process_states':states}
    assert p.returncode==0 and elapsed>=2.5 and elapsed<8 and 'GROUP_EMPTY' in p.stdout,r
    assert len(states)==2 and all(v in ('gone','Z') for v in states.values()),r
    print(json.dumps(r,indent=2))
