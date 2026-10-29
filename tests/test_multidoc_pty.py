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
KF6_CTRLSHIFT = b'\x1b[17;6~'

# ---- boot: first paint can take several seconds under PTY
pump(4.0)
wait_has('boot caption noname', ['noname.prg'])

# doc1: type marker (goes wherever the cursor sits; position-agnostic)
send(b'aa1')
pump(0.8)
check('doc1 marker visible', 'aa1' in scr.text())

# File>New via Alt+F then n
send(b'\x1bf'); pump(0.8); send(b'n'); pump(1.0)
send(b'bb2')
pump(0.8)
t2 = scr.text()
wait_has('doc2 marker visible after New', ['bb2'])
check('doc1 marker hidden in doc2', 'aa1' not in t2.replace(' ', ''))

# switch back with Ctrl+F6
send(KF6_CTRL); pump(1.0)
t1 = wait_has('Ctrl+F6 back to doc1 shows its text', ['aa1'])
check('doc2 text hidden in doc1', 'bb2' not in t1.replace(' ', ''))

# undo isolation: undo in doc1 removes only doc1 burst
send(b'\x1a')  # Ctrl+Z
pump(0.8)
check('undo reverts doc1 burst', 'aa1' not in scr.text().replace(' ', ''))
send(b'\x15'); pump(0.6)   # Ctrl+U redo
check('redo restores doc1 burst', 'aa1' in scr.text().replace(' ', ''))
send(b'\x1a'); pump(0.6)   # undo again: back to saved state
send(KF6_CTRL); pump(1.0)
wait_has('doc2 burst survives doc1 undo', ['bb2'])

# cursor preservation: switch to doc1, cursor row should be 1
send(KF6_CTRL); pump(1.0)
m = re.search(r'row:\s*(\d+),\s*col:\s*(\d+)', scr.text())
check('doc1 cursor preserved (row 1)', m and m.group(1) == '1')

# breakpoints are per-document (F9 toggles; gutter line-number goes W+/R)
KF9 = b'\x1b[20~'
send(KF9); pump(0.6)            # doc1: BP at line 1 (cursor 1,5)
send(b'\x1b[B'); pump(0.3); send(b'\x1b[B'); pump(0.3)  # Down x2 -> line 3
send(KF9); pump(0.6)            # doc1: BP at line 3
check('doc1 BP gutters red at lines 1 and 3', scr.gutter_bg(1) == 1 and scr.gutter_bg(3) == 1)
check('doc1 line 2 has no BP', scr.gutter_bg(2) == 7)   # N/W gutter
send(KF6_CTRL); pump(1.0)       # -> doc2
check('doc2 shows no doc1 BPs', scr.gutter_bg(1) == 7 and scr.gutter_bg(3) == 7)
send(b'\x1b[B'); pump(0.3); send(b'\x1b[B'); pump(0.3); send(b'\x1b[B'); pump(0.3); send(b'\x1b[B'); pump(0.3)
send(KF9); pump(0.6)            # doc2: BP at line 5
check('doc2 BP gutter red at line 5', scr.gutter_bg(5) == 1)
check('doc2 line 1 has no BP', scr.gutter_bg(1) == 7)
send(KF6_CTRL); pump(1.0)       # -> doc1
check('doc1 BPs survive doc2 editing', scr.gutter_bg(1) == 1 and scr.gutter_bg(3) == 1)
check('doc1 shows no doc2 BP', scr.gutter_bg(5) == 7)

# selection survives a doc switch: F8 + Right x3 selects 'fun' on line 1;
# typing X after doc1->doc2->doc1 must REPLACE it ('Xction'), proving the mark lived
KHOME = b'\x1b[H'
KRIGHT = b'\x1b[C'
KPGDN = b'\x1b[6~'
KF8 = b'\x1b[19~'
for _ in range(5): send(b'\x1b[A'); pump(0.15)
send(KHOME); pump(0.3)
send(KF8); pump(0.3)
for _ in range(3): send(KRIGHT); pump(0.15)
send(KF6_CTRL); pump(0.8)       # -> doc2
send(KF6_CTRL); pump(0.8)       # -> doc1
send(b'X'); pump(0.6)
t = scr.text().replace(' ', '')
check('selection survives doc switch (X replaces fun)', 'XctionMain()' in t)
send(b'\x1a'); pump(0.6)       # undo the replace -> demo text restored
check('selection-test undo restores line', 'functionMain()' in scr.text().replace(' ', ''))

# dirty doc1 BEFORE opening the fixture: Open reuses a CLEAN noname doc
# (by design), which would silently replace doc1; dirty doc1 forces an append
for _ in range(10): send(b'\x1b[A'); pump(0.1)
send(KHOME); pump(0.2)
send(b'z'); pump(0.5)

# scroll preserved per doc: open fixture.prg (100 lines) as doc3, PgDn x2,
# cycle away and back; the top gutter line must be the same as before leaving
send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
check('Open dialog opened', 'Open a file' in scr.text())
send(work.encode() + b'/fixture.prg'); send(b'\r'); pump(1.5)
t = scr.text().replace(' ', '')
check('fixture opened as its own doc', 'line01' in t and 'fixture.prg' in scr.text())
send(KPGDN); pump(0.5); send(KPGDN); pump(0.8)
def top_gutter():
    s = ''.join(scr.g[2][1:5]).strip()
    return int(s) if s.isdigit() else -1
n1 = top_gutter()
check('PgDn scrolls fixture (top gutter > 1)', n1 > 1)
send(KF6_CTRL); pump(0.8)       # -> doc1
send(KF6_CTRL); pump(0.8)       # -> doc2
send(KF6_CTRL); pump(0.8)       # -> doc3
n2 = top_gutter()
check('doc scroll preserved across switches', n2 == n1)
send(KF6_CTRL); pump(0.8)       # -> doc1 for the journal section

# wait for the 2s journal tick with doc1 (z) and doc2 (bb2) dirty
pump(3.0)

journals = sorted(os.listdir(rec))
bases = [j for j in journals if j.endswith('.journal')]
check('two journals for two dirty noname docs', len(bases) == 2)
targets = {}
for j in journals:
    if j.endswith('.target'):
        targets[j] = open(os.path.join(rec, j)).read().strip()
check('two targets', len(targets) == 2)
keys = set(t.split('.')[0] for t in targets)
check('journal keys distinct per doc', len(keys) == 2)

# ---- crash: kill -9, journals must survive
os.kill(pid, signal.SIGKILL)
os.waitpid(pid, 0)
pump(0.5)

# ---- restart: recovery prompt(s)
pid, fd = pty.fork()
if pid == 0:
    os.chdir(work)
    os.execve(BIN, [BIN], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))
scr = Scr()
pump(5.0)
wait_has('recovery prompt on restart', ['interrupted session'], collapse=False)
send(b'\r'); pump(1.5)   # Recover journal #1
t = scr.text()
if 'interrupted session' in t:
    send(b'\r'); pump(1.5)   # Recover journal #2
t = scr.text()
check('recovery dialogs cleared', 'interrupted session' not in t)

# both recovered buffers must live as separate docs: doc view 1
ta = scr.text().replace(' ', '')
send(KF6_CTRL); pump(1.0)
tb = scr.text().replace(' ', '')
both = (('zfunction' in ta or 'zfunction' in tb) and ('bb2' in ta or 'bb2' in tb))
check('both recovered buffers live as separate docs', both)

# ---- SaveAs on current doc -> dup.prg
send(b'\x1bf'); pump(0.8); send(b'a')
t0 = time.time()
while 'Save as' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
check('SaveAs dialog opened', 'Save as' in scr.text())
send(work.encode() + b'/dup.prg'); send(b'\r'); pump(1.5)
t = scr.text()
if 'File exists' in t:
    send(b'\r'); pump(1.0)   # Overwrite (first button)
wait_has('first SaveAs done (caption dup.prg)', ['dup.prg'], collapse=False)

# ---- switch to the other doc, SaveAs same route -> refused
send(KF6_CTRL); pump(1.0)
send(b'\x1bf'); pump(0.8); send(b'a')
t0 = time.time()
while 'Save as' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/dup.prg'); send(b'\r'); pump(1.5)
wait_has('SaveAs collision refused', ['Already open in another document'], collapse=False)
send(b'\x1b'); pump(0.8)  # dismiss alert

# ---- per-doc close: Window>Close on current (dirty) -> prompt -> Discard
send(b'\x1bw'); pump(0.8); send(b'c')
t0 = time.time()
while 'Unsaved changes' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
t = scr.text()
check('close dirty doc prompts', 'Unsaved changes' in t)
if 'Unsaved changes' in t:
    send(b'd'); pump(1.2)   # Discard
t = scr.text()
check('after close, a doc remains', ('dup.prg' in t) or ('noname.prg' in t))

# ---- exit review: dirty current doc, ESC prompts; Cancel keeps app; Discard exits
send(b'q'); pump(0.6)
send(b'\x1b'); pump(1.0)
wait_has('ESC with dirty doc prompts', ['Unsaved changes'], collapse=False)
send(b'c'); pump(0.8)   # Cancel
check('cancel keeps IDE alive', 'File' in scr.text())
send(b'\x1b'); pump(1.0)
send(b'd'); pump(1.5)   # Discard
t = scr.text()
if 'Unsaved changes' in t:   # another dirty doc under review
    send(b'd'); pump(1.5)
w = os.waitpid(pid, os.WNOHANG)
alive = (w[0] == 0)
check('IDE exits after reviewing all docs', not alive)
if alive:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)

fails = 0
for name, ok in results:
    print(('PASS' if ok else 'FAIL'), name)
    if not ok: fails += 1
print('TOTAL', len(results)-fails, 'PASS', fails, 'FAIL')
print('REC DIR', rec)
shutil.rmtree(home, ignore_errors=True)
shutil.rmtree(rec, ignore_errors=True)
shutil.rmtree(work, ignore_errors=True)
sys.exit(1 if fails else 0)
