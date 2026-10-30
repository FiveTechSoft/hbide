import glob, os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

# Linux PTY: F7/F9 remain safe when the current source disappears.
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

open(os.path.join(work, 'fn.prg'), 'w').write('procedure Main()\n   local n := 1\n   n := bump( n )\n   ? n\nreturn\nfunction bump( x )\n   x := x + 41\n   return x\n')
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

def wait_for(text, timeout=8):
    t0=time.time()
    while text not in scr.text() and time.time()-t0 < timeout:
        pump(.2)
    return text in scr.text()
def execution_line():
    for i in range(2,20):
        if scr.at[i][25][1]==4:
            m=re.match(r'x(\d+):',''.join(scr.g[i]))
            if m:return int(m.group(1))
    return None
try:
    assert wait_for('noname.prg')
    send(b'\x1bf');pump(.5);send(b'o');assert wait_for('Open a file')
    send(work.encode()+b'/fn.prg\r');pump(.8)
    send(b'\x1br');pump(.5);send(b'd');assert wait_for('Command',12)
    other=os.path.join(work,'other.prg')
    open(other,'w').write('procedure Other()\nreturn\n')
    send(('view '+other+'\r').encode());pump(.5)

    sources=glob.glob(work+'/__hbide_dbg__*.prg')
    assert sources,('compiled source fixture missing',os.listdir(work))
    for source in sources:
        os.rename(source,source+'.bak')
    send(b'\x1b[19~');pump(.7)
    assert 'File not found' in scr.text(),scr.text()
    for key in (b'\x1b[20~',b'\x1b[18~'):
        send(key);pump(.4)
        assert 'No exported method' not in scr.text() and 'Message' not in scr.text(),scr.text()
        send(b'? 8*8\r');pump(.4)
        assert '64' in scr.text(),scr.text()
    print('PASS F9 and F7 without source preserve debugger and evaluator')
    for text in ('goto 3','find n','locate next','num off','num on','bp 4','delete bp all','monitor local on','wp n','delete wp all','monitor local off','tp n','delete tp all','callstack on','callstack off'):
        send((text+'\r').encode());pump(.3)
        assert 'No exported method' not in scr.text() and 'Message' not in scr.text(),(text,scr.text())
        send(b'? 9*9\r');pump(.3)
        assert '81' in scr.text(),(text,scr.text())
    print('PASS navigation display and explicit BP commands without source remain usable')

    for source in glob.glob(work+'/__hbide_dbg__*.prg.bak'):
        os.rename(source,source[:-4])
    send(('view '+other+'\r').encode());pump(.4)
    source=glob.glob(work+'/__hbide_dbg__*.prg')[0]
    send(('view '+source+'\r').encode());pump(.4)
    assert 'local n := 1' in scr.text(),scr.text()
    send(b'bp 4\r');pump(.3)
    send(b'\x1b[15~');pump(.8)
    assert execution_line()==4,('valid breakpoint still stops after source returns',execution_line(),scr.text())
    print('PASS source reopens and valid breakpoint still stops VM')
    send(b'\x1bx');pump(.6)
    assert ' File  Edit' in scr.text(),scr.text()
    print('PASS debugger exits to IDE')
finally:
    try:os.kill(pid,signal.SIGHUP)
    except ProcessLookupError:pass
    for d in (home,rec,work):shutil.rmtree(d,ignore_errors=True)
