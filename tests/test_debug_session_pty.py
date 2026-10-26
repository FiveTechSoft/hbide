import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

ROWS, COLS = 25, 80
BIN = '/home/sandbox/hbide/hbide'

class Scr:
    def __init__(self):
        self.g = [[' ']*COLS for _ in range(ROWS)]
        self.at = [[(7,0)]*COLS for _ in range(ROWS)]
        self.r = self.c = 0
        self.fg, self.bg = 7, 0
    def sgr(self, params):
        p = [int(x) if x else 0 for x in params.split(';')] if params else [0]
        i = 0
        while i < len(p):
            v = p[i]
            if v == 0: self.fg, self.bg = 7, 0
            elif v == 1: self.fg |= 8
            elif v == 22: self.fg &= 7
            elif 30 <= v <= 37: self.fg = (self.fg & 8) | (v - 30)
            elif v == 39: self.fg = 7
            elif 40 <= v <= 47: self.bg = v - 40
            elif v == 49: self.bg = 0
            elif 90 <= v <= 97: self.fg = 8 + v - 90
            elif 100 <= v <= 107: self.bg = 8 + v - 100
            i += 1
    def put(self, ch):
        if self.r < ROWS and self.c < COLS:
            self.g[self.r][self.c] = ch
            self.at[self.r][self.c] = (self.fg, self.bg)
        self.c += 1
    def gutter_bg(self, lineno):
        # screen row whose gutter (cols 1-4) shows this source line number
        want = ('%4d' % lineno)
        for r in range(ROWS):
            if ''.join(self.g[r][1:5]) == want:
                return self.at[r][2][1]
        return None
    def feed(self, data):
        i = 0
        s = data.decode('utf-8', 'replace')
        while i < len(s):
            ch = s[i]
            if ch == '\x1b' and i+1 < len(s) and s[i+1] == '[':
                m = re.match(r'\x1b\[([0-9;?]*)([A-Za-z@`~])', s[i:])
                if m:
                    params, cmd = m.group(1), m.group(2)
                    i += len(m.group(0))
                    if cmd in 'Hf':
                        p = params.split(';')
                        self.r = (int(p[0])-1) if p and p[0] else 0
                        self.c = (int(p[1])-1) if len(p) > 1 and p[1] else 0
                    elif cmd == 'J':
                        self.g = [[' ']*COLS for _ in range(ROWS)]
                    elif cmd == 'K':
                        for x in range(self.c, COLS): self.g[self.r][x] = ' '
                    elif cmd == 'm': self.sgr(params)
                    elif cmd == 'A': self.r = max(0, self.r - (int(params or '1') if params else 1))
                    elif cmd == 'B': self.r = min(ROWS-1, self.r + (int(params or '1') if params else 1))
                    elif cmd == 'C': self.c = min(COLS-1, self.c + (int(params or '1') if params else 1))
                    elif cmd == 'D': self.c = max(0, self.c - (int(params or '1') if params else 1))
                    continue
            if ch == '\x1b':
                m = re.match(r'\x1b[()][0-9A-B]', s[i:])
                if m:
                    i += len(m.group(0)); continue
                i += 1; continue
            if ch == '\r': self.c = 0
            elif ch == '\n': self.r = min(ROWS-1, self.r+1)
            elif ch == '\x08': self.c = max(0, self.c-1)
            elif ch >= ' ' and ch != '\x7f': self.put(ch)
            i += 1
    def text(self):
        return '\n'.join(''.join(row).rstrip() for row in self.g)

home = tempfile.mkdtemp(prefix='hbide-md-home-')
rec  = tempfile.mkdtemp(prefix='hbide-md-rec-')
work = tempfile.mkdtemp(prefix='hbide-md-work-')
with open(os.path.join(work, 'fixture.prg'), 'w') as f:
    f.write('\n'.join('line %02d' % n for n in range(1, 101)) + '\n')
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM="xterm")

pid, fd = pty.fork()
if pid == 0:
    os.chdir(work)
    os.execve(BIN, [BIN], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))

scr = Scr()
def pump(secs):
    t0 = time.time(); buf = b''
    while time.time() - t0 < secs:
        r,_,_ = select.select([fd],[],[],0.2)
        if not r: continue
        try: d = os.read(fd, 65536)
        except OSError: break
        if not d: break
        buf += d
        while b'\x1b[6n' in buf:
            i = buf.index(b'\x1b[6n'); buf = buf[:i] + buf[i+4:]
            os.write(fd, b'\x1b[%d;1R' % ROWS)
        while b'\x1b[18t' in buf:
            i = buf.index(b'\x1b[18t'); buf = buf[:i] + buf[i+4:]
            os.write(fd, b'\x1b[8;%d;%dt' % (ROWS, COLS))
    scr.feed(buf)

def send(b):
    os.write(fd, b)

results = []
def check(name, cond):
    results.append((name, bool(cond)))
    if not cond:
        open('/tmp/md-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

def wait_has(name, subs, timeout=6.0, collapse=True):
    t0 = time.time()
    while True:
        t = scr.text()
        tt = t.replace(' ', '') if collapse else t
        if all(s in tt for s in subs):
            check(name, True); return t
        if time.time() - t0 > timeout:
            check(name, False); return t
        pump(0.3)

# Debug session: real debugger over a real PTY.
# Fixture: Main-style source (the -n compile requires it) + a user file that
# uses the OLD fixed temp name: Run>Debug must never touch it.
open(os.path.join(work, 'dbg2.prg'), 'w').write('procedure Main()\n   local n := 1\n   ? "uno"\n   n := 40 + 2\n   ? n\nreturn\n')
open(os.path.join(work, 'stmt.prg'), 'w').write('? "top level"\nreturn\n')
open(os.path.join(work, '__hbide_dbg__.prg'), 'w').write('SENTINEL-USER-FILE\n')

def temps():
    # the unique temp pattern only; the sentinel user file is NOT a temp
    return sorted(f for f in os.listdir(work) if re.match(r'__hbide_dbg__\d+_', f))

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])
check('sentinel user file in place', open(os.path.join(work, '__hbide_dbg__.prg')).read().strip() == 'SENTINEL-USER-FILE')

send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/dbg2.prg'); send(b'\r'); pump(1.2)
check('dbg2 open', 'dbg2.prg' in scr.text())

# cursor to line 4, F9 marks a breakpoint (gutter attribute changes)
for _ in range(3): send(b'\x1b[B'); pump(0.15)
before = scr.gutter_bg(4)
send(b'\x1b[20~'); pump(0.8)   # F9
after = scr.gutter_bg(4)
check('F9 marks BP on line 4 (gutter attr)', before != after and after is not None)

# Run > Debug: the vendored source debugger takes over
send(b'\x1br'); pump(0.8); send(b'd')
t0 = time.time()
while 'Command' not in scr.text() and time.time() - t0 < 12.0:
    pump(0.5)
t = scr.text()
check('debugger UI appears (own menu + Command window)', 'Point' in t and 'Command' in t)
m = re.search(r'__hbide_dbg__\d+_\d+\.\d+\.prg', t)
check('debug module uses a unique temp name', m is not None)
check('debugger shows the buffer source', 'procedure __Main()' in t)

# F5 Go: runs to the preset breakpoint on line 4 (exec bar = distinct color)
send(b'\x1b[15~'); pump(2.0)
bar = None
for r in range(ROWS):
    line = ''.join(scr.g[r])
    if line.lstrip().startswith('x4:'):
        bar = (r, scr.at[r][2])
ok_bar = False
if bar:
    for r in range(ROWS):
        line = ''.join(scr.g[r])
        if line.lstrip().startswith('x3:'):
            ok_bar = scr.at[r][2] != bar[1]
check('F5 stops at preset BP line 4 (exec bar color)', ok_bar)

# Alt+X aborts the debuggee and returns to the IDE editor
send(b'\x1bx'); pump(1.5)
t = scr.text()
check('Alt+X returns to the IDE editor', 'dbg2.prg' in t and 'Edit' in t)
check('no temp files leaked after session', temps() == [])
check('sentinel untouched after debug session', open(os.path.join(work, '__hbide_dbg__.prg')).read().strip() == 'SENTINEL-USER-FILE')

# statement-style buffer: compile rejects it (-n) -> loud alert, no debugger,
# no temp leak (previously a silent no-op that also clobbered the fixed name)
send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/stmt.prg'); send(b'\r'); pump(1.2)
check('stmt.prg open as second doc', 'stmt.prg' in scr.text())
send(b'\x1br'); pump(0.8); send(b'd')
t0 = time.time()
while 'Debug build produced no code' not in scr.text() and time.time() - t0 < 6.0:
    pump(0.3)
t = scr.text()
check('compile failure is a visible alert', 'Debug build produced no code' in t and 'procedure Main()' in t)
check('debugger not entered on failed compile', 'Command' not in t)
send(b'\r'); pump(0.8)   # dismiss alert
check('no temp files leaked on failed compile', temps() == [])
check('sentinel still untouched', open(os.path.join(work, '__hbide_dbg__.prg')).read().strip() == 'SENTINEL-USER-FILE')

# debuggee runtime error: the alert is shown and the session unwinds to the
# IDE with ALL temps cleaned (previously leaked past the missing RECOVER)
open(os.path.join(work, 'err3.prg'), 'w').write('procedure Main()\n   local x\n   ? "antes"\n   x := nil + 1\n   ? "despues"\nreturn\n')
send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/err3.prg'); send(b'\r'); pump(1.2)
check('err3.prg open as third doc', 'err3.prg' in scr.text())
send(b'\x1br'); pump(0.8); send(b'd')
t0 = time.time()
while 'Command' not in scr.text() and time.time() - t0 < 12.0:
    pump(0.5)
check('debugger entered for err3', 'Command' in scr.text())
send(b'\x1b[15~'); pump(2.5)   # F5 Go -> nil + 1 raises
t0 = time.time()
while 'Argument error' not in scr.text() and time.time() - t0 < 6.0:
    pump(0.3)
t = scr.text()
check('debuggee runtime error shows an alert', 'Argument error' in t)
send(b'\r'); pump(1.5)   # dismiss
t = scr.text()
check('error path returns to the IDE editor', 'err3.prg' in t and 'Edit' in t)
check('no temp files leaked on the error path', temps() == [])
check('sentinel untouched after error path', open(os.path.join(work, '__hbide_dbg__.prg')).read().strip() == 'SENTINEL-USER-FILE')

# clean exit: BP marks are not text edits, all docs are clean
send(b'\x1b'); pump(1.0)
t = scr.text()
if 'Unsaved changes' in t:
    send(b'd'); pump(1.0)
w = os.waitpid(pid, os.WNOHANG)
alive = (w[0] == 0)
check('IDE exits clean', not alive)
if alive:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)

fails = 0
for name, ok in results:
    print(('PASS' if ok else 'FAIL'), name)
    if not ok: fails += 1
print('TOTAL', len(results)-fails, 'PASS', fails, 'FAIL')
shutil.rmtree(home, ignore_errors=True)
shutil.rmtree(rec, ignore_errors=True)
shutil.rmtree(work, ignore_errors=True)
sys.exit(1 if fails else 0)
