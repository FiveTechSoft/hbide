#!/usr/bin/env python3
# Debuggee input consumption test (GREEN), 2026-10-26.
# Proves: during a stepped READ the app screen is shown (no Command window),
# typed letters echo in the GET field, Enter completes the READ, the debugger
# re-enters at the next line, the debuggee consumes the typed value (raw pty
# stream contains the debuggee's own output "GOT:[OLIN"), and a following
# inkey(0) blocks until a real key arrives.
# Lessons baked in: marker strings must not appear in the source listing
# (checked against app-screen-only rows), stepping is cursor-driven (typing
# during a re-entry window races), and final-value proof uses the RAW stream
# because the emulator grid can be overwritten by later repaints.
import importlib.util, os, pty, sys, struct, fcntl, termios, select, time, signal, tempfile, re
spec = importlib.util.spec_from_file_location("tc", os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_debug_commands_pty.py"))
tc = importlib.util.module_from_spec(spec); sys.modules['tc']=tc
try: spec.loader.exec_module(tc)
except SystemExit: pass
Scr=tc.Scr; ROWS=tc.ROWS; COLS=tc.COLS
BIN='/home/sandbox/hbide/hbide'
work=tempfile.mkdtemp(prefix='hbide-input-')
open(os.path.join(work,'fn.prg'),'w').write(
'procedure Main()\n'
'   local cName := space(10)\n'
'   @ 5, 5 say "Name: " get cName\n'
'   read\n'
'   ? "GOT:[" + cName + "]"\n'
'   inkey(0)\n'
'return\n')
pid, fd = pty.fork()
if pid==0:
    os.chdir(work); os.execv(BIN,[BIN])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH",ROWS,COLS,0,0))
scr=Scr(); raw=bytearray()
def pump(secs):
    end=time.time()+secs
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.1)
        if r:
            try: data=os.read(fd,65536)
            except OSError: break
            if not data: break
            raw.extend(data); scr.feed(data)
def send(b): os.write(fd,b)
def wait_cond(fn,timeout=8):
    t0=time.time()
    while not fn() and time.time()-t0<timeout: pump(.2)
    return fn()
def cursor_line():
    from collections import Counter
    for r in range(2,18):
        if Counter(scr.at[r][3:78]).most_common(1)[0][0]==(15,4):
            m=re.search(r'(\d+):',''.join(scr.g[r]))
            if m: return int(m.group(1))
    return None
results=[]
def check(name,cond,detail=''):
    results.append((name,bool(cond)))
    print(('PASS' if cond else 'FAIL'),name,('- '+detail) if not cond and detail else '')
wait_cond(lambda:'File' in scr.text())
send(b'\x1bf');pump(.5);send(b'o');wait_cond(lambda:'Open a file' in scr.text())
send(work.encode()+b'/fn.prg\r');pump(.8)
send(b'\x1br');pump(.5);send(b'd')
ok=False
for i in range(8):
    if cursor_line()==4: ok=True; break
    send(b'step\r');pump(1.2)
check('stopped at read line',ok)
send(b'step\r');pump(1.5)
t=scr.text()
check('READ blocks with app screen (no Command window)', 'Command' not in t, t[:200])
check('GET prompt visible on app screen rows', any('Name:' in ''.join(scr.g[r]) for r in (5,6)))
send(b'OLIN');pump(1.0)
rows=[i for i,row in enumerate(scr.g) if 'OLIN' in ''.join(row)]
check('letters echo in GET field row, not Command', rows and all(r in (5,6) for r in rows), 'rows=%s'%rows)
check('no residual editor char before GET value', any(re.search(r'Name:\s+OLIN\s*$',''.join(scr.g[r]).rstrip()) and 'dOLIN' not in ''.join(scr.g[r]) for r in (5,6)), ''.join(scr.g[5]))
send(b'\r');pump(2.0)
check('debugger re-entered after Enter', 'Command' in scr.text(), scr.text()[:200])
check('stopped at line after read', cursor_line()==5, 'cursor=%s'%cursor_line())
send(b'step\r');pump(1.2)
send(b'step\r');pump(1.5)
t=scr.text()
check('inkey(0) blocks holding app screen', 'Command' not in t, t[:200])
check('raw stream shows debuggee consumed OLIN', b'GOT:[OLIN' in bytes(raw))
send(b'x');pump(1.5)
check('debugger back after inkey key', 'Command' in scr.text(), scr.text()[:200])
os.close(fd)
try: os.kill(pid, signal.SIGKILL)
except: pass
print('---'); n=sum(1 for _,k in results if k)
print('TOTAL',n,'PASS',len(results)-n,'FAIL')
sys.exit(len(results)-n != 0)
