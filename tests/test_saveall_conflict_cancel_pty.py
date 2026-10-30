import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

# Linux PTY SaveAll conflict cancel preserves dirty buffer/disk and saves other document.
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

home = tempfile.mkdtemp(prefix='hbide-df-home-')
rec  = tempfile.mkdtemp(prefix='hbide-df-rec-')
work = tempfile.mkdtemp(prefix='hbide-df-work-')
pathdir=os.path.join(work,"script path");os.mkdir(pathdir)
open(os.path.join(pathdir,"frompath.cld"),"w").write("Options Tab 11\n")
open(os.path.join(pathdir,"init.cld"),"w").write("Options Tab 13\n")
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM="xterm", PATH=pathdir+os.pathsep+os.environ["PATH"])

# fixture: a call (for Trace/Calls/NextRoutine) and a changing var (for TP)
open(os.path.join(work, 'fn.prg'), 'w').write(
    'procedure Main()\n'          # 1
    '   local n := 1\n'           # 2
    '   n := bump( n )\n'         # 3
    '   ? n\n'                    # 4
    'return\n'                    # 5
    'function bump( x )\n'        # 6
    '\tx := x + 41\n'              # 7
    'return x\n')                 # 8

open(os.path.join(work, 'fn.prg'), 'w').write('procedure Main()\n   local n := 1\n' + ''.join('   n := n + %d\n' % i for i in range(3,83)) + 'return\n')
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
    for m in re.finditer(rb'\x1b\[(\d+);(\d+)H', buf):
        LASTCUR[0] = (int(m.group(1)), int(m.group(2)))
    scr.feed(buf)

LASTCUR = [None]
def send(b):
    os.write(fd, b)

results = []
def check(name, cond):
    results.append((name, bool(cond)))
    print(('PASS' if cond else 'FAIL'), name)
    if not cond:
        print(scr.text())
def wait_for(text, timeout=8):
    t0=time.time()
    while text not in scr.text() and time.time()-t0 < timeout:
        pump(.2)
    return text in scr.text()
def selected_source(text):
    # Source cursor highlight has a different text color from adjacent rows.
    for i in range(2,18):
        if text in ''.join(scr.g[i]):
            return scr.at[i][25] != scr.at[i-1][25] and scr.at[i][25] != scr.at[i+1][25]
    return False
try:
    assert wait_for('noname.prg'),scr.text()
    first=os.path.join(work,'fn.prg'); second=os.path.join(work,'second.prg')
    open(second,'w').write('SECOND DISK\n')
    def open_doc(path):
        send(b'\x1bf');pump(.3);send(b'o');assert wait_for('Open a file')
        send(path.encode()+b'\r');pump(.5)
    open_doc(first);send(b'LOCAL');pump(.3)
    open_doc(second);send(b'OTHER');pump(.3)
    external=b'EXTERNAL DISK CHANGE\n';open(first,'wb').write(external)
    send(b'\x1b[12;5~')
    assert wait_for('File changed on disk and you have unsaved changes'),scr.text()
    # Keep mine for the external-change watch; then Cancel the save guard.
    send(b'k');pump(.4)
    assert wait_for('it?'),scr.text()
    send(b'c');pump(.6)
    assert wait_for('could not be saved'),scr.text()
    summary=scr.text().replace(' ','').replace('\n','')
    assert '1saved' in summary and '1couldnotbesaved' in summary,summary
    send(b'\r');pump(.4)
    assert open(first,'rb').read()==external
    assert open(second,'rb').read()==b'OTHERSECOND DISK\n'
    send(b'\x1b[17;5~');pump(.4)
    assert 'LOCALprocedure Main()' in scr.text(),scr.text()
    print('PASS SaveAll cancelled conflict leaves external bytes and dirty edit, other document saves')

finally:
    try: os.kill(pid,signal.SIGHUP)
    except ProcessLookupError: pass
    for d in (home,rec,work):
        for name in ('denied.cld',):
            try: os.chmod(os.path.join(d,name),0o600)
            except FileNotFoundError: pass
        shutil.rmtree(d,ignore_errors=True)
