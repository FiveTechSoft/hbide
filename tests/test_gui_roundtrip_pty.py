"""Compile real designer outputs and verify final values after keyboard/mouse input.
Linux PTY only. No pixel or Windows certification. Does not change user files.
"""
import pathlib, tempfile, subprocess, os, pty, struct, fcntl, termios, select, time, signal, shutil, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
ROWS, COLS = 25, 80
# Shared, already-tested terminal emulator. Stop before that harness's execution.
text = (ROOT / 'tests/test_designer_pty.py').read_text()
exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work = pathlib.Path(tempfile.mkdtemp(prefix='hbide-gui-roundtrip-'))
results = []
def check(name, ok):
    results.append((name,bool(ok)))
    print(('PASS' if ok else 'FAIL'),name,flush=True)
def build(inputs, output):
    p = subprocess.run(['hbmk2',*map(str,inputs), '-gttrm','-quiet','-o'+str(output)],cwd=ROOT,
        stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if p.returncode: print(p.stdout.decode(errors='replace'))
    return p.returncode == 0
lib = [ROOT/p for p in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']]
try:
    gen = work/'generate'
    if not build([ROOT/'tests/gui_roundtrip_fixture.prg',ROOT/'designer.prg',ROOT/'safeio.prg',*lib],gen):raise RuntimeError('fixture build')
    subprocess.run([str(gen),str(work)],check=True,stdout=subprocess.PIPE)
    for kind in ['radiogroup','listbox','combobox','checkbox','get']:
        exe=work/kind
        check(kind+' artifact compiles',build([work/(kind+'.prg'),*lib],exe))
        for mode in (['keyboard','mouse','scrolled-mouse'] if kind in ['listbox','combobox'] else ['keyboard','mouse']):
            value=work/(kind+'.value');value.unlink(missing_ok=True)
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
            def click(label,offset=0):
                for row in range(ROWS):
                    col=''.join(screen.g[row]).find(label)
                    if col>=0:
                        send(b'\x1b[M'+bytes([32,col+33+offset,row+33]),.1)
                        send(b'\x1b[M'+bytes([35,col+33+offset,row+33]),.4)
                        return True
                return False
            try:
                pump(1.4)
                if mode=='keyboard':
                    if kind=='combobox':send(b'\t');send(b' ')
                    if kind in ['radiogroup','listbox','combobox']:send(b'\x1b[B')
                    elif kind=='checkbox':send(b' ')
                    else:send(b'Antonio')
                    send(b'\t');send(b'\r',.6)
                    expect='2' if kind in ['radiogroup','listbox','combobox'] else ('T' if kind=='checkbox' else 'Antonio')
                else:
                    if kind=='combobox':
                        click('First');check('combo mouse opens from another GET','Second' in screen.text())
                    if mode=='scrolled-mouse':
                        for _ in range(7):send(b'\x1b[B',.08)
                        check(kind+' scroll reaches eighth','Eighth' in screen.text())
                        click('Sixth')
                    elif kind in ['radiogroup','listbox','combobox']:click('Third')
                    elif kind=='checkbox':click('Enabled')
                    else:
                        # Blank text field at model row2,col4 inside centered50x20 dialog.
                        send(b'\x1b[M'+bytes([32,52,38]),.1)
                        send(b'\x1b[M'+bytes([35,52,38]),.2)
                        send(b'Antonio')
                    click('OK',1);pump(.5)
                    expect='6' if mode=='scrolled-mouse' else '3' if kind in ['radiogroup','listbox','combobox'] else ('T' if kind=='checkbox' else 'Antonio')
                check(kind+' '+mode+' commits final value',value.exists() and value.read_text().strip()==expect)
                if not value.exists():
                    (work/(kind+'-'+mode+'.screen')).write_text(screen.text())
            finally:
                w=os.waitpid(pid,os.WNOHANG)
                if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
                os.close(fd)
    failures=sum(not ok for _,ok in results)
    print('TOTAL',len(results)-failures,'PASS',failures,'FAIL; evidence',work)
    sys.exit(bool(failures))
finally:
    pass # Preserve generated source, binaries and failure screens for inspection.
