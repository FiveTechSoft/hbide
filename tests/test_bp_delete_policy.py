import os, pty, sys, struct, fcntl, termios, select, time, signal, tempfile, re, pathlib

# Linux-only E2E: editor breakpoint deletion policy (3c880eb). Deleting the
# line or a selection that holds a breakpoint DROPS the mark (never a silent
# stop on another instruction); undoing the text does not restore the mark;
# splitting a marked line keeps the mark on the first fragment; a mark below
# an unrelated deletion shifts and stays on its own line copy.
ROWS, COLS = 25, 80
BIN = os.path.abspath(sys.argv[1])

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

home = tempfile.mkdtemp(prefix='hbide-bp-home-')
rec  = tempfile.mkdtemp(prefix='hbide-bp-rec-')
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM='xterm')

pid, fd = pty.fork()
if pid == 0:
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

send = lambda b: os.write(fd, b)
results = []
def check(name, cond):
    results.append((name, bool(cond)))
    if not cond:
        open('/tmp/bp-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

def no_red():
    return all(scr.gutter_bg(n) != 1 for n in range(1, 10))

KF9 = b'\x1b[20~'; KF8 = b'\x1b[19~'; KDEL = b'\x1b[3~'
KUP = b'\x1b[A'; KDOWN = b'\x1b[B'; KEND = b'\x1b[F'; KHOME = b'\x1b[H'

try:
    pump(4.0)
    check('boot noname', 'noname.prg' in scr.text())
    send(b'l1\rl2\rl3\rl4\r'); pump(1.2)
    for _ in range(3): send(KUP); pump(0.15)
    send(KF9); pump(0.6)
    check('BP set on line 2', scr.gutter_bg(2) == 1)
    # 1. delete the marked line: the mark is dropped, not relocated
    send(b'\x19'); pump(0.8)          # Ctrl+Y
    t = scr.text().replace(' ', '')
    check('marked line deleted', 'l2' not in t and 'l3' in t)
    check('deleting marked line drops BP (no red gutter)', no_red())
    # 2. undo restores the text, not the mark (documented asymmetry)
    send(b'\x1a'); pump(0.8)          # Ctrl+Z
    t = scr.text().replace(' ', '')
    check('undo restores text', 'l2' in t)
    check('undo does NOT restore the mark', no_red())
    # 3. split the marked line: mark stays on the first fragment
    for _ in range(6): send(KUP); pump(0.12)
    send(KDOWN); pump(0.2)
    send(KF9); pump(0.6)
    check('BP re-set on line 2', scr.gutter_bg(2) == 1)
    send(KEND); pump(0.2); send(b'\r'); pump(0.8)
    check('split keeps mark on first fragment', scr.gutter_bg(2) == 1)
    # 4. delete a selection spanning the marked line: mark dropped
    for _ in range(6): send(KUP); pump(0.12)
    send(KHOME); pump(0.2)
    send(KF8); pump(0.3)
    send(KDOWN + KDOWN); pump(0.3)
    send(KDEL); pump(0.8)
    t = scr.text().replace(' ', '')
    check('Delete does not open Go to Function', 'Go to function' not in scr.text())
    check('selection removed marked lines', 'l1' not in t and 'l2' not in t)
    check('selection delete drops BP (no red gutter)', no_red())
    # 5. duplicates: mark on the second copy, delete the first: the mark
    #    shifts and stays on ITS line, not silently gone or on another text
    for _ in range(9): send(KDOWN); pump(0.12)
    send(KEND); pump(0.2); send(b'\r')
    send(b'dup\rdup'); pump(0.8)
    send(KF9); pump(0.6)               # BP on second 'dup'
    n2 = None
    for r in range(ROWS):
        row = ''.join(scr.g[r])
        if row[5:].strip().startswith('dup'):
            n2 = int(row[1:5])
    if not (n2 is not None and scr.gutter_bg(n2) == 1):
        open('/tmp/bp-dup-debug.txt','w').write('n2=%r bg=%r\n' % (n2, scr.gutter_bg(n2) if n2 else None) + '\n'.join('%02d %r' % (r, ''.join(scr.g[r])[:30]) for r in range(ROWS)))
    check('found marked dup line', n2 is not None and scr.gutter_bg(n2) == 1)
    send(KUP); pump(0.2)
    send(b'\x19'); pump(0.8)          # delete FIRST dup
    check('mark shifted onto its own dup copy', n2 is not None and scr.gutter_bg(n2 - 1) == 1)
finally:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)

fails = [n for n, ok in results if not ok]
for n, ok in results:
    print(('PASS' if ok else 'FAIL'), n)
if fails:
    sys.exit(1)
print('PASS BP deletion policy: drop on delete, no undo restore, split first fragment, follow own copy')
