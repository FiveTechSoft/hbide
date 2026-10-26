#!/usr/bin/env python3
# REPRO (currently RED) - suspected debugger input-consumption bug, 2026-10-26.
# Fixture: APPMARK123 / @ 5,5 GET cName / READ / ? "GOT:["+cName+"]" / inkey(0).
# Proven green: during the READ the app screen is visible (APPMARK123, "Name:"),
# typed letters echo, Enter unblocks the READ and the debugger re-enters.
# Failing: after re-entry the Command window shows "Command error" (evidence that
# post-READ keystrokes land in the debugger command line) and the debuggee ends
# early: inkey(0) does not block and the app screen with GOT:[OLIN is never held.
# Hypothesis: stale-key/repaint desync around RestoreAppState (hb_keySetLast) and
# the save/restore app-screen path on re-entry. Not yet root-caused.
# Runs the 18-check command suite first via import side effect (~22s).
import importlib.util, os, pty, sys, struct, fcntl, termios, select, time, signal, tempfile
spec = importlib.util.spec_from_file_location("tc", "/home/sandbox/hbide/tests/test_debug_commands_pty.py")
tc = importlib.util.module_from_spec(spec); sys.modules['tc']=tc
try: spec.loader.exec_module(tc)
except SystemExit: pass
Scr=tc.Scr; ROWS=tc.ROWS; COLS=tc.COLS
BIN='/home/sandbox/hbide/hbide'
work=tempfile.mkdtemp(prefix='hbide-input-')
open(os.path.join(work,'fn.prg'),'w').write(
'procedure Main()\n'
'   local cName := space(10)\n'
'   ? "APPMARK123"\n'
'   @ 5, 5 say "Name: " get cName\n'
'   read\n'
'   ? "GOT:[" + cName + "]"\n'
'   inkey(0)\n'
'return\n')
pid, fd = pty.fork()
if pid==0:
    os.chdir(work); os.execv(BIN,[BIN])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH",ROWS,COLS,0,0))
scr=Scr()
def pump(secs):
    end=time.time()+secs
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.1)
        if r:
            try: data=os.read(fd,65536)
            except OSError: break
            if not data: break
            scr.feed(data)
def send(b): os.write(fd,b)
def wait_for(t,timeout=8):
    t0=time.time()
    while t not in scr.text() and time.time()-t0<timeout: pump(.2)
results=[]
def dump(tag):
    print('=== DUMP', tag)
    for i,row in enumerate(scr.g): print('%02d|%s' % (i, ''.join(row)))
def check(name,cond,detail=''):
    results.append((name,bool(cond)))
    print(('PASS' if cond else 'FAIL'),name,('- '+detail) if not cond and detail else '')
wait_for('File',5)
send(b'\x1bf');pump(.5);send(b'o');wait_for('Open a file')
send(work.encode()+b'/fn.prg\r');pump(.8)
send(b'\x1br');pump(.5);send(b'd')   # Run > Debug
pump(1.5)
for _ in range(3): send(b'step\r');pump(.7)
t=scr.text()
check('debugger UI after 3 steps', 'Command' in t)
send(b'step\r');pump(1.5)  # executes READ -> debuggee blocks for input
t=scr.text()
check('app screen visible during input wait (APPMARK123)', 'APPMARK123' in t, t[:300])
check('GET prompt visible (Name:)', 'Name:' in t)
send(b'OLIN');pump(1.2)   # letters only: GET field should show them on app screen
t=scr.text()
check('GET field shows typed letters mid-READ', 'OLIN' in t, t[:400])
send(b'\r');pump(2.0)     # Enter: READ completes; VM re-enters debugger
t=scr.text()
check('debugger re-entered after input', 'Command' in t, t[:300])
send(b'step\r');pump(1.0)  # executes ? "GOT:[...]"
dump('after step GOT')
send(b'step\r');pump(1.5)  # executes inkey(0) -> blocks with app screen visible
dump('after step inkey')
t=scr.text()
check('debuggee output shows consumed value GOT:[OLIN', 'GOT:[OLIN' in t, t[:400])
send(b'x');pump(1.5)       # satisfy inkey(0); re-entry
t=scr.text()
check('debugger re-entered after inkey', 'Command' in t, t[:300])
send(b'\x1br');pump(.4);send(b'q');pump(1.0)
os.close(fd)
try: os.kill(pid, signal.SIGKILL)
except: pass
print("---"); print('%d/%d' % (sum(1 for _,ok in results if ok), len(results)))
