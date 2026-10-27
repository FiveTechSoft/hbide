import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

ROWS, COLS = 25, 80
BIN = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.expanduser('~/hbide/hbide')

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
        open('/tmp/sr-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

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

# Combined regression: SaveAs onto a path that another open doc owns is
# refused; then kill -9; restart; both dirty buffers (the unsaved noname doc
# and the doc saved as dup.prg plus later edits) come back as separate docs,
# and the refusal neither created nor changed anything on disk.
# Usage: python3 tests/test_saveas_refusal_recovery_pty.py /abs/path/to/hbide

def dirs():
    return sorted(os.listdir(rec))

def open_saveas(name):
    send(b'\x1bf'); pump(0.8); send(b'a')
    t0 = time.time()
    while 'Save as' not in scr.text() and time.time() - t0 < 4.0:
        pump(0.3)
    send(work.encode() + b'/' + name); send(b'\r'); pump(1.5)

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])
send(b'aa1'); pump(0.8)
send(b'\x1bf'); pump(0.8); send(b'n'); pump(1.0)       # doc2
send(b'bb2'); pump(0.8)
open_saveas(b'dup.prg')                                  # doc2 -> dup.prg
wait_has('doc2 saved as dup.prg', ['dup.prg'], collapse=False)
dup = os.path.join(work, 'dup.prg')
check('dup.prg written', os.path.exists(dup))
before = open(dup, 'rb').read() if os.path.exists(dup) else None
check('dup.prg holds doc2 text only', before is not None and b'bb2' in before and b'aa1' not in before)

send(KF6_CTRL); pump(1.0)                                # doc1 (noname, aa1)
wait_has('doc1 shows aa1', ['aa1'])
open_saveas(b'dup.prg')                                  # same route -> refused
wait_has('SaveAs collision refused', ['Already open in another document'], collapse=False)
send(b'\x1b'); pump(0.8)
check('refusal left dup.prg byte-identical', open(dup, 'rb').read() == before)
check('refusal created no other file', sorted(p for p in os.listdir(work) if p.endswith('.prg')) == ['dup.prg', 'fixture.prg'])
check('doc1 still unsaved noname', 'noname.prg' in scr.text())

send(KF6_CTRL); pump(1.0)                                # doc2 = dup.prg
send(b'q7k'); pump(0.8)                                  # make dup.prg dirty again
check('dup.prg edit visible', 'q7k' in scr.text().replace(' ', ''))
pump(3.5)                                                # 2 s journal tick
j = dirs()
bases = [x for x in j if x.endswith('.journal')]
check('two base journals (noname doc + dup.prg)', len(bases) == 2)
check('dup.prg still unchanged on disk before kill', open(dup, 'rb').read() == before)

os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); pump(0.5)

pid, fd = pty.fork()
if pid == 0:
    os.chdir(work)
    os.execve(BIN, [BIN], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))
scr = Scr()
pump(5.0)
wait_has('recovery prompt on restart', ['interrupted session'], collapse=False)
seen = scr.text()
send(b'\r'); pump(1.5)
t = scr.text()
if 'interrupted session' in t:
    seen += t
    send(b'\r'); pump(1.5)
check('recovery dialogs cleared', 'interrupted session' not in scr.text())
check('prompts named dup.prg', 'dup.prg' in seen)

ta = scr.text().replace(' ', '')
send(KF6_CTRL); pump(1.0)
tb = scr.text().replace(' ', '')
tc = ta + tb
check('noname buffer recovered (aa1)', 'aa1' in tc)
check('dup.prg buffer recovered (bb2 and q7k)', 'bb2' in tc and 'q7k' in tc)
check('recovered into separate docs', ('aa1' in ta) != ('aa1' in tb))
check('disk dup.prg still the pre-crash save', open(dup, 'rb').read() == before)

# save the recovered dup.prg doc with F2: disk must equal what was recovered
if 'q7k' not in tb:
    send(KF6_CTRL); pump(1.0)
send(b'\x1bOQ'); pump(1.5)
after = open(dup, 'rb').read()
check('F2 saved recovered dup.prg with q7k', b'q7k' in after and b'bb2' in after and b'aa1' not in after)
check('saved file is old bytes plus the lost edit only', len(after) == len(before) + 3)

os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)
fails = 0
for name, ok in results:
    print(('PASS' if ok else 'FAIL'), name)
    if not ok: fails += 1
print('TOTAL', len(results)-fails, 'PASS', fails, 'FAIL')
shutil.rmtree(home, ignore_errors=True); shutil.rmtree(rec, ignore_errors=True); shutil.rmtree(work, ignore_errors=True)
sys.exit(1 if fails else 0)
