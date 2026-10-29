import os, sys
# the in-app build runs hbmk2 from the IDE process: make it findable before
# the shared core snapshots os.environ for the spawned IDE
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

# project fixture: two sources + .hbp
open(os.path.join(work, 'demo1.prg'), 'w').write('? "demo1"\nreturn\n')
open(os.path.join(work, 'demo2.prg'), 'w').write('? "demo2"\nreturn\n')
open(os.path.join(work, 'test.hbp'), 'w').write('demo1.prg\ndemo2.prg\n')

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])

# open demo1.prg (reuses the clean boot noname) and dirty it
send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/demo1.prg'); send(b'\r'); pump(1.2)
check('demo1 open (caption)', 'demo1.prg' in scr.text())
send(b'x'); pump(0.6)

# ProjectOpen CHAINS into ProjectDesktop: the dirty prompt must appear first,
# covering ANY dirty named doc (multidoc), not only the current one
send(b'\x1bp'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a project' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
check('project dialog opened', 'Open a project' in scr.text())
send(work.encode() + b'/test.hbp'); send(b'\r'); pump(1.5)
t = wait_has('dirty named buffer prompts before desktop', ['demo1.prg', 'builds read disk'], collapse=False)

# Cancel: back to the editor, no desktop
send(b'c'); pump(1.2)
t = scr.text()
check('cancel keeps editor (no desktop)', 'SOURCES' not in t and 'demo1.prg' in t)

# menu Project>Sources/Build -> prompt again -> Save saves dirty named docs
send(b'\x1bp'); pump(0.8); send(b's')
t0 = time.time()
while 'builds read disk' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
check('prompt again via menu', 'builds read disk' in scr.text())
send(b's'); pump(1.5)
wait_has('desktop opens after Save', ['SOURCES'], collapse=False)
disk = open(os.path.join(work, 'demo1.prg')).read()
check('Save wrote the dirty buffer to disk', 'x' in disk.split('\n')[0] or '\nx' in disk)

# Enter on the first source row: demo1 is already open -> switch, no duplicate
send(b'\r'); pump(1.2)
t = scr.text()
check('Enter jumps to source doc', 'demo1.prg' in t)
check('desktop closed after jump', 'SOURCES' not in t)

# reopen desktop (all clean now -> no prompt), Down to demo2, Enter -> second doc
send(b'\x1bp'); pump(0.8); send(b's')
t0 = time.time()
while 'SOURCES' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
check('desktop reopens clean (no prompt)', 'SOURCES' in scr.text())
send(b'\x1b[B'); pump(0.4); send(b'\r'); pump(1.2)
check('second source opens as its own doc', 'demo2.prg' in scr.text())
send(KF6_CTRL); pump(1.0)
check('Ctrl+F6 back to demo1', 'demo1.prg' in scr.text())

# Messages view without a build reports the empty state
send(b'\x1bp'); pump(0.8); send(b's')
t0 = time.time()
while 'SOURCES' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(b'\x1bOS'); pump(0.8)   # F4 -> Messages
check('messages view shows no-diagnostics state', 'No parsed diagnostics' in scr.text())
send(b'\x1b'); pump(1.0)   # ESC closes desktop

# dirty NONAME buffer: excluded from the build dirty-check by design (no
# disk file to save or compare), but the buffer itself must stay intact
# and dirty across desktop + build - exclusion, not loss
send(b'\x1bf'); pump(0.8); send(b'n')   # File > New -> fresh noname doc
pump(1.0)
check('new noname doc current', 'noname.prg' in scr.text())
send(b'q'); pump(0.6)
check('noname dirty content visible', 'q' in ''.join(scr.g[2]))
send(b'\x1bp'); pump(0.8); send(b's')   # desktop must open WITHOUT prompting
t0 = time.time()
while 'SOURCES' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
t = scr.text()
check('desktop opens directly with only a dirty noname (exclusion)', 'SOURCES' in t)
check('no dirty prompt for noname', 'builds read disk' not in t)
send(KF9)   # build with the dirty noname still in memory
t0 = time.time()
while 'Build OK' not in scr.text() and 'BUILD FAILED' not in scr.text() and time.time() - t0 < 15.0:
    pump(0.3)
# the earlier flow saved an 'x' prefix into demo1.prg, so the real build
# fails on disk content - which also proves the build really ran
t = scr.text()
check('build really runs with dirty noname in memory', 'BUILD FAILED' in t and 'ERROR demo1.prg:1' in t)
send(b'\x1b'); pump(1.0)   # close desktop
t = scr.text()
check('noname buffer intact after desktop+build', 'noname.prg' in t and 'q' in ''.join(scr.g[2]))

# clean exit: the dirty noname must STILL be dirty -> exit prompt proves it
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
