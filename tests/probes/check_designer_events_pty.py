"""Compile real designer outputs and exercise synthetic event handlers.
Linux PTY only. No pixel or Windows certification. Does not change user files.
"""
import pathlib, tempfile, subprocess, os, pty, struct, fcntl, termios, select, time, signal, shutil, re, sys, json, hashlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
ROWS, COLS = 25, 80
# Shared, already-tested terminal emulator. Stop before that harness's execution.
text = (ROOT / 'tests/test_designer_pty.py').read_text()
exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work = pathlib.Path(tempfile.mkdtemp(prefix='hbide-gui-roundtrip-'))
results = []
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
changes=subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=ROOT,text=True)
inputs=['tests/probes/designer_events_fixture.prg','tests/probes/check_designer_events_pty.py','tests/test_designer_pty.py','designer.prg','safeio.prg','hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']
def digest(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
hashes={p:digest(ROOT/p) for p in inputs}
artifacts=[]
def check(name, ok):
    results.append((name,bool(ok)))
    print(('PASS' if ok else 'FAIL'),name,flush=True)
def build(inputs, output):
    p = subprocess.run(['hbmk2',*map(str,inputs), '-gttrm','-quiet','-o'+str(output)],cwd=ROOT,
        stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    if p.returncode: print(p.stdout.decode(errors='replace'))
    return p.returncode == 0
lib = [ROOT/p for p in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']]
try:
    gen = work/'generate'
    if not build([ROOT/'tests/probes/designer_events_fixture.prg',ROOT/'designer.prg',ROOT/'safeio.prg',*lib],gen):raise RuntimeError('fixture build')
    subprocess.run([str(gen),str(work)],check=True,stdout=subprocess.PIPE)
    for kind in ['get','checkbox','button','radiogroup','listbox','combobox']:
        exe=work/kind
        check(kind+' artifact compiles',build([work/(kind+'.prg'),*lib],exe))
        screen=Scr();pid,fd=pty.fork()
        if pid==0:
            os.environ.update(TERM='xterm',HOME=str(work),HBIDE_RECOVERY_DIR=str(work/'rec'))
            os.execv(str(exe),[str(exe)])
        fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0))
        def pump(secs):
            until=time.monotonic()+secs;b=b''
            while time.monotonic()<until:
                r,_,_=select.select([fd],[],[],.05)
                if not r:continue
                try:d=os.read(fd,65536)
                except OSError:break
                b+=d
                if b'\x1b[6n' in d:os.write(fd,b'\x1b[25;1R')
                if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;25;80t')
            screen.feed(b)
        def send(key,delay=.25):os.write(fd,key);pump(delay)
        try:
            pump(1.2)
            if kind=='get':send(b'X')
            elif kind in ['button','checkbox']:send(b' ')
            elif kind in ['radiogroup','listbox']:send(b'\x1b[B')
            else:
                send(b'\x1b[1;3B');send(b'\x1b[B');send(b'\r')
            send(b'\t');send(b'\r',.5)
            okfile=work/(kind+'.ok')
            check(kind+' normal OK return',okfile.exists() and okfile.read_text()=='T')
            events=(work/(kind+'.events')).read_text().splitlines() if (work/(kind+'.events')).exists() else []
            expected=['when','valid']
            if kind!='get':expected+=['focus']
            if kind in ['checkbox','listbox','combobox']:expected+=['state']
            if kind=='button':expected+=['action']
            for event in expected:check(kind+' invokes '+event,event in events)
            artifacts.append({'control':kind,'events':events,'prg_sha256':digest(work/(kind+'.prg')),'binary_sha256':digest(exe)})
            print(kind,'event trace',events,flush=True)
            (work/(kind+'.screen')).write_text(screen.text())
        finally:
            w=os.waitpid(pid,os.WNOHANG)
            if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
            os.close(fd)
    check('source unchanged during probe',source==subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() and changes==subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=ROOT,text=True) and all(digest(ROOT/p)==h for p,h in hashes.items()))
    (work/'results.json').write_text(json.dumps({'scope':'Synthetic generated event invocation and normal OK return, Linux GTTRM. Not veto semantics, all mouse/keyboard paths, pixels or Windows acceptance.','source':source,'tracked_changes':changes,'source_sha256':hashes,'checks':results,'artifacts':artifacts},indent=2)+'\n')
    failures=sum(not ok for _,ok in results)
    print('TOTAL',len(results)-failures,'PASS',failures,'FAIL; evidence',work)
    sys.exit(bool(failures))
finally:
    pass # Preserve generated source, binaries and screens for inspection.
