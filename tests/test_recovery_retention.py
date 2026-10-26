import os, pty, sys, struct, fcntl, termios, select, time, signal, tempfile, re, pathlib

# Linux-only E2E: retention of old-session journals through the recovery
# prompt. Discard deletes the base journal; Later keeps it and the prompt
# comes back on the next start. Complements test_recovery_multi.py (Recover
# path) and the unit suite (DeleteBase mechanics).
ROWS, COLS = 40, 120
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

rec  = tempfile.mkdtemp(prefix='hbide-ret-rec-')
home = tempfile.mkdtemp(prefix='hbide-ret-home-')
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM='xterm')

def seed():
    pathlib.Path(rec, 'a.journal').write_text('keep-or-drop')
    pathlib.Path(rec, 'a.target').write_text('/tmp/hbide-ret-a.prg')

def boot():
    pid, fd = pty.fork()
    if pid == 0:
        os.execve(BIN, [BIN], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))
    return pid, fd

scr = Scr()
def pump(secs, fd):
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

results = []
def check(name, cond):
    results.append((name, bool(cond)))
    if not cond:
        open('/tmp/ret-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

def wait_has(name, subs, fd, timeout=9.0):
    t0 = time.time()
    while True:
        tt = scr.text().replace(' ', '')
        if all(s in tt for s in subs):
            check(name, True); return
        if time.time() - t0 > timeout:
            check(name, False); return
        pump(0.3, fd)

# ---- Discard: the base journal is deleted, no re-prompt next start
seed()
pid, fd = boot()
try:
    wait_has('prompt before Discard', ['interruptedsession'], fd)
    os.write(fd, b'd')               # Discard hotkey
    t0 = time.time()
    while pathlib.Path(rec, 'a.journal').exists() and time.time() - t0 < 5.0:
        pump(0.2, fd)
    check('Discard deletes base journal', not pathlib.Path(rec, 'a.journal').exists())
    check('Discard deletes sidecar', not pathlib.Path(rec, 'a.target').exists())
finally:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)

scr = Scr()
pid, fd = boot()
try:
    pump(2.5, fd)
    check('no re-prompt after Discard', 'interruptedsession' not in scr.text().replace(' ', ''))
finally:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)

# ---- Later: the base journal is kept and the prompt returns next start
seed()
scr = Scr()
pid, fd = boot()
try:
    wait_has('prompt before Later', ['interruptedsession'], fd)
    os.write(fd, b'l')               # Later hotkey
    pump(1.0, fd)
    check('Later keeps base journal', pathlib.Path(rec, 'a.journal').exists())
finally:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)

scr = Scr()
pid, fd = boot()
try:
    wait_has('prompt returns after Later', ['interruptedsession'], fd)
finally:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)

fails = [n for n, ok in results if not ok]
for n, ok in results:
    print(('PASS' if ok else 'FAIL'), n)
if fails:
    sys.exit(1)
print('PASS retention: Discard deletes, Later keeps and re-prompts')
