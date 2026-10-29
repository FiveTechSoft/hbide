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


home = tempfile.mkdtemp(prefix='hbide-sa-home-')
rec  = tempfile.mkdtemp(prefix='hbide-sa-rec-')
work = tempfile.mkdtemp(prefix='hbide-sa-work-')
ro = os.path.join(work, 'ro'); os.mkdir(ro)
open(os.path.join(work, 'ok.prg'), 'w').write('function Ok()\nreturn nil\n')
open(os.path.join(ro, 'fail.prg'), 'w').write('function Fail()\nreturn nil\n')
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

def send(b): os.write(fd, b)

results = []
def check(name, cond):
    results.append((name, bool(cond)))
    if not cond:
        open('/tmp/nav-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

def wait_has(name, subs, timeout=8.0):
    t0 = time.time()
    while True:
        t = scr.text().replace(' ', '')
        if all(s.replace(' ', '') in t for s in subs):
            check(name, True); return scr.text()
        if time.time() - t0 > timeout:
            check(name, False); return scr.text()
        pump(0.3)

def open_file(name):
    send(b'\x1bf'); pump(0.8); send(b'o')
    t0 = time.time()
    while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
        pump(0.3)
    send(work.encode() + b'/' + name.encode()); send(b'\r'); pump(1.2)


KCTRL_F2 = b'\x1b[12;5~'
KALT_0 = b'\x1b0'
def status_row(): return scr.text().split('\n')[ROWS-1]
def open_file(path):
    send(b'\x1bf'); pump(0.8); send(b'o')
    t0 = time.time()
    while 'Open a file' not in scr.text() and time.time() - t0 < 4.0: pump(0.3)
    send(path.encode()); send(b'\r'); pump(1.2)

pump(4.0)
wait_has('boot', ['noname.prg'])
okp = os.path.join(work, 'ok.prg'); fp = os.path.join(ro, 'fail.prg')
open_file(fp); send(b'FAILEDIT'); pump(0.5)
open_file(okp); send(b'OKEDIT'); pump(0.5)
os.chmod(ro, 0o555)                       # fail.prg can no longer be rewritten (temp + rename)
fail_before = open(fp).read()
send(KCTRL_F2); pump(2.0)
shots = []
for i in range(10):
    t = scr.text(); shots.append(t)
    if '1saved,1couldnotbesaved' in t.replace(' ', '').replace('\n',''):   # the summary dialog
        break
    send(b'\r'); pump(1.5)
open('/tmp/sa-shots.txt','w').write('\n#########\n'.join(shots) + '\n#########FINAL\n' + scr.text())
final = scr.text().replace(' ', '')
check('summary says 1 saved and 1 could not be saved', '1saved' in final and '1couldnotbesaved' in final)
send(b'\r'); pump(1.0)
os.chmod(ro, 0o755)
check('failed file content on disk untouched', open(fp).read() == fail_before)
check('ok file saved with its edit', 'OKEDIT' in open(okp).read())
send(KALT_0); pump(1.0)
t = scr.text()
check('failed doc still marked modified, ok doc clean',
      re.search(r'\*\s+\S*fail\.prg', t) is not None and re.search(r'\*\s+\S*ok\.prg', t) is None)
send(b'\x1b'); pump(0.3)
os.kill(pid, signal.SIGKILL)
shutil.rmtree(home, True); shutil.rmtree(rec, True)
fails = [n for n, ok in results if not ok]
for n, ok in results: print(('PASS ' if ok else 'FAIL ') + n)
print('%d/%d passed' % (len(results) - len(fails), len(results)))
sys.exit(1 if fails else 0)
