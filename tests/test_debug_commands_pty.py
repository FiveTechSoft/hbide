import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

# Linux PTY effects: GOTO/FIND/INPUT against an 83-line source.
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
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM="xterm")

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
    check('IDE starts',wait_for('noname.prg'))
    send(b'\x1bf');pump(.5);send(b'o');wait_for('Open a file')
    send(work.encode()+b'/fn.prg\r');pump(.8)
    send(b'\x1br');pump(.5);send(b'd')
    check('Debugger enters',wait_for('Command',12))
    send(b'goto 3\r');pump(.6)
    check('GOTO 3 scrolls target to first source row', 'n := n + 3 ' in ''.join(scr.g[2]))
    send(b'goto 70\r');pump(.6)
    check('GOTO 70 scrolls distant target to first source row', 'n := n + 70' in ''.join(scr.g[2]) and 'procedure __Main' not in scr.text())
    send(b'find n + 11\r');pump(.6)
    check('FIND selects matching line after distant GOTO', selected_source('n := n + 11'))
    send(b'find n + 1\r');pump(.6)
    check('FIND first partial match selects line 10', selected_source('n := n + 10'))
    send(b'next\r');pump(.6)
    check('NEXT selects following match 11', selected_source('n := n + 11'))
    send(b'prev\r');pump(.6)
    check('PREVIOUS selects earlier match 10', selected_source('n := n + 10'))
    script=os.path.join(work,'commands.cld')
    open(script,'w').write('Num Off\nOptions TabWidth 12\nGoto 60\n')
    send(b'input '+script.encode()+b'\r');pump(.8)
    check('INPUT executes Num Off and GOTO from script', selected_source('n := n + 60') and not re.search(r'x\d+:',scr.text()) and 'Command error' not in scr.text())
    send(b'num on\r');pump(.6)
    check('NUM ON restores source numbers', re.search(r'x60:',scr.text()) is not None)
    before_color=scr.at[3][25]
    send(b'options monodisplay\r');pump(.6)
    mono_color=scr.at[3][25]
    check('Mono Display changes source palette', mono_color != before_color)
    send(b'options monodisplay\r');pump(.6)
    check('Mono Display restores color palette', scr.at[3][25] == before_color)
    nested=os.path.join(work,'sources');os.mkdir(nested)
    open(os.path.join(nested,'pathprobe.prg'),'w').write('PATH_RESOLVED_MARKER\n')
    send(b'options pathforfiles '+nested.encode()+b'\r');pump(.7)
    # Only the configured directory contains this source, never the current dir.
    send(b'file open pathprobe.prg\r');pump(.7)
    check('Path For Files resolves source outside CWD by basename', 'PATH_RESOLVED_MARKER' in scr.text() and 'pathprobe.prg' in scr.text())
    send(b'\x1bw');wait_for('Iconize',3);send(b'i');pump(.8)
    check('Window Iconize collapses the code window content', 'PATH_RESOLVED_MARKER' not in scr.text())
    send(b'\x1bw');wait_for('Iconize',3);send(b'i');pump(.8)
    check('Window Iconize restores the code window content', 'PATH_RESOLVED_MARKER' in scr.text())
    # Viewport preservation needs the cursor away from the first source row:
    # the one-row icon strip must not drag the scroll position to the cursor.
    send(b'file open '+work.encode()+b'/fn.prg\r');pump(.7)
    send(b'goto 60\r');pump(.6)
    for _ in range(5): send(b'\x1b[B');pump(.2)
    view_before=[''.join(r) for r in scr.g[2:17]]
    send(b'\x1bw');wait_for('Iconize',3);send(b'i');pump(.8)
    send(b'\x1bw');wait_for('Iconize',3);send(b'i');pump(.8)
    check('Window Iconize preserves the code window viewport', [''.join(r) for r in scr.g[2:17]] == view_before)
    send(b'\x1bo');pump(.5);send(b't');wait_for('Tab width',4)
    check('INPUT script applied TabWidth 12', any('12' in ''.join(scr.g[i]) for i in range(8,11)))
    send(b'\x1b');pump(.5)
    send(b'\x1bx');pump(.8)
    check('Debugger exits back to IDE', 'Edit' in scr.text() and 'fn.prg' in scr.text())
finally:
    try: os.kill(pid,signal.SIGHUP)
    except ProcessLookupError: pass
    for d in (home,rec,work): shutil.rmtree(d,ignore_errors=True)
fails=sum(not ok for _,ok in results)
print('TOTAL',len(results)-fails,'PASS',fails,'FAIL')
sys.exit(bool(fails))
