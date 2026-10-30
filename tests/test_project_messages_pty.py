import os, sys
# the build runs hbmk2 from the app process: make it findable before the
# shared core snapshots os.environ for the spawned IDE
if '/home/sandbox/harbour/bin/linux/gcc' not in os.environ.get('PATH', '').split(':'):
    os.environ['PATH'] = '/home/sandbox/harbour/bin/linux/gcc:' + os.environ.get('PATH', '')
    os.execv(sys.executable, [sys.executable] + sys.argv)

import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

ROWS, COLS = 25, 80
BIN = os.environ.get('HBIDE_BIN', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'hbide'))

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

KF6_CTRL = b'\x1b[17;5~'
KF9 = b'\x1b[20~'


os.makedirs(os.path.join(work, 'folder (12)'), exist_ok=True)
# fixture: one clean source, one source with a real Harbour error at line 3
open(os.path.join(work, 'ok1.prg'), 'w').write('? "ok"\nreturn\n')
open(os.path.join(work, 'folder (12)', 'bad1.prg'), 'w').write('? "l1"\n? "l2"\n? x ++ y\nreturn\n')
open(os.path.join(work, 'test.hbp'), 'w').write('ok1.prg\n"folder (12)/bad1.prg"\n')

def wait_for(needles, secs=8.0):
    t0 = time.time()
    while time.time() - t0 < secs:
        t = scr.text()
        if all(n in t for n in needles):
            return t
        pump(0.3)
    check('TIMEOUT waiting ' + str(needles) + ' :: ' + scr.text().replace('\n', '|')[-200:], False)
    return scr.text()

def row_col():
    m = re.search(r'row:\s*(\d+),\s*col:\s*(\d+)', scr.text())
    return (int(m.group(1)), int(m.group(2))) if m else (None, None)

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])

# open the project; ProjectOpen chains the desktop (no dirty docs -> direct)
send(b'\x1bp'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a project' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/test.hbp'); send(b'\r'); pump(1.5)
wait_for(['SOURCES'])
check('desktop opens after project open (no dirty docs)', 'SOURCES' in scr.text())

# F9: real build -> real failure -> Messages lists the parsed diagnostic
send(KF9)
t = wait_for(['BUILD FAILED', 'diagnostics'], secs=15.0)
check('real build fails (exit shown)', 'BUILD FAILED' in t)
t = wait_for(['ERROR bad1.prg:3'], secs=4.0)
check('Messages lists parsed diagnostic bad1.prg:3', 'ERROR bad1.prg:3' in t)

# Enter on the diagnostic: opens the file and lands on the failing line/col
send(b'\r'); pump(1.5)
t = scr.text()
check('diagnostic jump opens bad1.prg', 'bad1.prg' in t)
r, c = row_col()
check('cursor lands on line 3', r == 3)
check('cursor lands on column 1', c == 1)
check('desktop closed after jump', 'SOURCES' not in t and 'MESSAGES' not in t)
check('buffer loaded clean from disk', 'x ++ y' in t)

# dirty that buffer (line 1 gets a z prefix); disk stays untouched
send(b'\x1b[A'); pump(0.3); send(b'\x1b[A'); pump(0.3); send(b'\x1b[H'); pump(0.3)
r, c = row_col()
check('cursor moved to line 1', r == 1)
send(b'z'); pump(0.6)
check('buffer now dirty with z edit visible', 'z? "l1"' in scr.text())

# desktop again: the dirty named buffer prompts; Use disk keeps the buffer
send(b'\x1bp'); pump(0.8); send(b's')
wait_for(['builds read disk'], secs=4.0)
send(b'u'); pump(1.2)
wait_for(['SOURCES'], secs=4.0)

# rebuild -> same diagnostic from the DISK file
send(KF9)
t = wait_for(['BUILD FAILED'], secs=15.0)
wait_for(['ERROR bad1.prg:3'], secs=4.0)

# Enter on it: the dirty buffer is already open -> switch, no reload, no dup
send(b'\r'); pump(1.5)
t = scr.text()
check('jump returns to the already-open bad1.prg', 'bad1.prg' in t)
check('dirty buffer preserved (z edit survives)', 'z? "l1"' in t)
r, c = row_col()
check('cursor back on line 3', r == 3)
disk = open(os.path.join(work, 'folder (12)', 'bad1.prg')).read()
check('disk file untouched (no silent save)', disk.startswith('? "l1"'))

# no duplicate doc: cycle must be exactly bad1 <-> ok1 (open ok1 first)
send(b'\x1bp'); pump(0.8); send(b's')
wait_for(['builds read disk'], secs=4.0)
send(b'u'); pump(1.2)
wait_for(['SOURCES'], secs=4.0)
send(b'\r'); pump(1.2)   # row 1 = ok1.prg (rows follow .hbp order)
t = scr.text()
check('second source opens as its own doc', 'ok1.prg' in t)
seq = []
for _ in range(4):
    send(KF6_CTRL); pump(0.8)
    seq.append('ok1' if 'ok1.prg' in scr.text() else ('bad1' if 'bad1.prg' in scr.text() else '?'))
check('exactly two docs cycle (no duplicate)', seq == ['bad1', 'ok1', 'bad1', 'ok1'])

# clean exit: bad1 still dirty -> prompt -> Discard
send(b'\x1b'); pump(1.0)
t = scr.text()
if 'Unsaved changes' in t:
    send(b'd'); pump(1.0)
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
