#!/usr/bin/env python3
# After a debug session the IDE must be repainted with its own colours (CLS/SetColor
# regression guard): normal end, Alt+X abort, runtime error, and F4 (app screen) round trip.
import importlib.util, os, pty, sys, struct, fcntl, termios, select, time, signal, tempfile
spec = importlib.util.spec_from_file_location("tc", os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_debug_commands_pty.py"))
tc = importlib.util.module_from_spec(spec); sys.modules['tc']=tc
try: spec.loader.exec_module(tc)
except SystemExit: pass
Scr=tc.Scr; ROWS=tc.ROWS; COLS=tc.COLS
BIN=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','hbide')
PROGS={
 'normal': 'procedure Main()\n   ? "hello"\nreturn\n',
 'altx':   'procedure Main()\n   local a := 1\n   inkey(0)\nreturn\n',
 'error':  'procedure Main()\n   local a := 0\n   a := 1 / a\n   ? a\nreturn\n',
}
results=[]
def check(n,c,d=''):
    results.append(bool(c)); print('PASS' if c else 'FAIL',n,('- '+d) if not c and d else '')
def run(kind):
    work=tempfile.mkdtemp(prefix='hbide-exit-'); open(os.path.join(work,'fn.prg'),'w').write(PROGS[kind])
    pid,fd=pty.fork()
    if pid==0:
        os.environ['HOME']=work; os.chdir(work); os.execv(BIN,[BIN])
    fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack("HHHH",ROWS,COLS,0,0))
    scr=Scr()
    def pump(s):
        e=time.time()+s
        while time.time()<e:
            r,_,_=select.select([fd],[],[],.1)
            if r:
                try: d=os.read(fd,65536)
                except OSError: return
                if not d: return
                scr.feed(d)
    def send(b): os.write(fd,b)
    def wait(f,t=8):
        t0=time.time()
        while not f() and time.time()-t0<t: pump(.2)
        return f()
    wait(lambda:'File' in scr.text())
    send(b'\x1bf');pump(.5);send(b'o');wait(lambda:'Open a file' in scr.text())
    send((work+'/fn.prg').encode()+b'\r');pump(.8)
    base=scr.at[3][40]   # editor body attribute before the session
    base_txt='procedure' in scr.text()
    send(b'\x1br');pump(.5);send(b'd');wait(lambda:'Command' in scr.text(),10)
    check(kind+': debugger entered','Command' in scr.text())
    if kind=='normal':
        send(b'go\r'); pump(2.5)
    elif kind=='altx':
        send(b'step\r');pump(1.5);send(b'step\r');pump(1.5)
        send(b'appscreen\r');pump(1.5)    # same routine as F4 (blank-app-screen visibility is not asserted: fails identically on 50cf1d0 in this harness)
        send(b' ');pump(1.5)                # any key returns to the debugger
        check('altx: debugger back after app screen','Command' in scr.text())
        send(b'\x1bx');pump(2.5)            # Alt+X
    else:
        send(b'go\r');pump(2.5)
        send(b'\r');pump(1.0)               # dismiss error alert if any
        for _ in range(3):
            if 'Command' in scr.text(): send(b'\x1bx');pump(2.0)
            else: send(b'\r');pump(1.0)
    ok=wait(lambda:'Command' not in scr.text() and 'File' in scr.text(),6)
    check(kind+': back in IDE with menu',ok,scr.text()[:150])
    check(kind+': editor text repainted','procedure' in scr.text())
    check(kind+': editor body colour restored', scr.at[3][40]==base, '%s vs %s'%(scr.at[3][40],base))
    send(b'\x1bf');pump(.6)
    check(kind+': menu still works after session','Open' in scr.text())
    os.close(fd)
    try: os.kill(pid,signal.SIGKILL)
    except: pass
for k in PROGS: run(k)
n=sum(results); print('---\nTOTAL',n,'PASS',len(results)-n,'FAIL'); sys.exit(len(results)-n!=0)
