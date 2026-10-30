import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

# Linux PTY: CallStack window effect on/off and stack content.
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
    send(b'\x1b[19~');pump(.8)
    assert execution_line()==2,('entry step',execution_line())
    send(b'\x1b[19~');pump(.8)
    assert execution_line()==3,('call step',execution_line())
    send(b'callstack on\r');pump(.7)
    t=scr.text();assert 'Calls' in t and re.search(r'x\s+MAIN\s+x', t) is not None, t
    stackfile=os.path.join(work,'stack.cld')
    send(b'options savesettings '+stackfile.encode()+b'\r');pump(.5)
    send(b'options restoresettings '+stackfile.encode()+b'\r');pump(.7)
    assert 'Calls' in scr.text(),('saved ON restore',scr.text())
    send(b'options restoresettings '+stackfile.encode()+b'\r');pump(.7)
    assert 'Calls' in scr.text(),('repeat ON restore',scr.text())
    print('PASS saved CallStack ON restores repeatedly without toggling')
    send(b'\x1b[15;5~');pump(.8)
    assert execution_line()==7,execution_line()
    t=scr.text();assert 'BUMP' in t and re.search(r'x\s+MAIN\s+x', t) is not None, t
    # Manual non-overlapping layout, saved with a non-default focus.
    send(b'window tile\r');pump(.5)
    send(b'window next\r');pump(.4)
    send(b'window next\r');pump(.4)
    layoutfile=os.path.join(work,'layout.cld')
    layoutcopy=os.path.join(work,'layout-copy.cld')
    send(b'options savesettings '+layoutfile.encode()+b'\r');pump(.5)
    send(b'options restoresettings '+layoutfile.encode()+b'\r');pump(.7)
    assert 'Calls' in scr.text() and 'BUMP' in scr.text(),('manual restore stack visible',scr.text())
    send(b'options savesettings '+layoutcopy.encode()+b'\r');pump(.5)
    def geometry(path):
        return [line for line in open(path).read().splitlines() if line.startswith('Window ')]
    assert geometry(layoutfile)==geometry(layoutcopy),('manual layout drift',geometry(layoutfile),geometry(layoutcopy))
    send(b'options restoresettings '+layoutfile.encode()+b'\r');pump(.7)
    send(b'options savesettings '+layoutcopy.encode()+b'\r');pump(.5)
    assert geometry(layoutfile)==geometry(layoutcopy),('repeat manual layout drift',geometry(layoutfile),geometry(layoutcopy))
    assert 'Calls' in scr.text() and 'BUMP' in scr.text(),scr.text()
    print('PASS manual layout restores same named window geometry from non-default focus')
    send(b'window select callstack\r');pump(.4)
    send(b'window iconize\r');pump(.4)
    assert 'BUMP' not in scr.text(),('icon hides stack content',scr.text())
    iconfile=os.path.join(work,'icon.cld')
    send(b'options savesettings '+iconfile.encode()+b'\r');pump(.5)
    send(b'options restoresettings '+iconfile.encode()+b'\r');pump(.7)
    assert 'BUMP' not in scr.text(),('restore retains icon state',scr.text())
    send(b'options restoresettings '+iconfile.encode()+b'\r');pump(.7)
    assert 'BUMP' not in scr.text(),('repeat restore retains icon state',scr.text())
    send(b'window select callstack\r');pump(.4)
    send(b'window iconize\r');pump(.4)
    assert 'Calls' in scr.text() and 'BUMP' in scr.text(),('icon restores original browser',scr.text())
    print('PASS saved iconized stack remains iconized and restores original content')
    # Saving a zoomed pane must retain its return rectangle.
    send(b'window select callstack\r');pump(.3)
    send(b'window zoom\r');pump(.4)
    zoomfile=os.path.join(work,'zoom.cld')
    send(b'options savesettings '+zoomfile.encode()+b'\r');pump(.5)
    send(b'options restoresettings '+zoomfile.encode()+b'\r');pump(.7)
    send(b'window select callstack\r');pump(.3)
    send(b'window zoom\r');pump(.4)
    send(b'options savesettings '+layoutcopy.encode()+b'\r');pump(.5)
    assert geometry(layoutfile)[:-1]==geometry(layoutcopy)[:-1],('saved zoom loses return layout',geometry(layoutfile),geometry(layoutcopy))
    print('PASS saved zoom restores and unzooms to original layout')
    send(b'callstack off\r');pump(.7)
    assert 'Calls' not in scr.text(), scr.text()
    stackoff=os.path.join(work,'stackoff.cld')
    send(b'options savesettings '+stackoff.encode()+b'\r');pump(.5)
    send(b'callstack on\r');pump(.5)
    assert 'Calls' in scr.text(),scr.text()
    send(b'options restoresettings '+stackoff.encode()+b'\r');pump(.7)
    assert 'Calls' not in scr.text(),('saved OFF restore',scr.text())
    print('PASS saved CallStack OFF hides changed visible stack')
    # Restore a saved window set after Calls was actually destroyed.
    send(b'options restoresettings '+layoutfile.encode()+b'\r');pump(.7)
    assert 'Calls' in scr.text() and 'BUMP' in scr.text(),('recreate Calls from saved layout',scr.text())
    send(b'options savesettings '+layoutcopy.encode()+b'\r');pump(.5)
    assert geometry(layoutfile)==geometry(layoutcopy),('recreated Calls layout drift',geometry(layoutfile),geometry(layoutcopy))
    print('PASS restore recreates missing Calls window with saved geometry')

    # Watch pane persists as an object after Delete ALL hides it. Restore
    # must re-open it, including when its browser is detached in icon state.
    def command(text):
        send(text.encode()+b'\r');pump(.5)
    command('window cascade')
    cascadefile=os.path.join(work,'cascade.cld')
    command('options savesettings '+cascadefile)
    command('options restoresettings '+cascadefile)
    command('options savesettings '+layoutcopy)
    assert geometry(cascadefile)==geometry(layoutcopy),('cascade restore drift',geometry(cascadefile),geometry(layoutcopy))
    command('options restoresettings '+cascadefile)
    command('options savesettings '+layoutcopy)
    assert geometry(cascadefile)==geometry(layoutcopy),('repeat cascade restore drift',geometry(cascadefile),geometry(layoutcopy))
    print('PASS cascade restores exact window geometry repeatedly')
    command('wp x')
    command('window tile')
    command('window select points')
    pointsfile=os.path.join(work,'points-layout.cld')
    command('options savesettings '+pointsfile)
    command('delete all')
    assert 'Watch' not in scr.text(),('delete hides points',scr.text())
    command('options restoresettings '+pointsfile)
    command('options savesettings '+layoutcopy)
    assert geometry(pointsfile)==geometry(layoutcopy),('reopened Points geometry',geometry(pointsfile),geometry(layoutcopy))
    assert 'Watch' in scr.text() and 'x <wp, N>:' in scr.text(),('reopened Points contents',scr.text())
    print('PASS restore reopens hidden Points with exact geometry and contents')
    command('window select points')
    command('window iconize')
    pointsicon=os.path.join(work,'points-icon.cld')
    command('options savesettings '+pointsicon)
    command('options restoresettings '+pointsicon)
    command('options restoresettings '+pointsicon)
    command('options savesettings '+layoutcopy)
    assert geometry(pointsicon)==geometry(layoutcopy),('iconized Points geometry drift',geometry(pointsicon),geometry(layoutcopy))
    command('window select points')
    command('window iconize')
    assert 'Watch' in scr.text() and 'x <wp, N>:' in scr.text(),('restored Points icon expands with contents',scr.text())
    print('PASS twice-restored iconized Points expands with original contents')
    command('window iconize')
    command('delete all')
    command('options restoresettings '+pointsicon)
    command('options savesettings '+layoutcopy)
    assert geometry(pointsicon)==geometry(layoutcopy),('hidden iconized Points restore drift',geometry(pointsicon),geometry(layoutcopy))
    command('window select points')
    command('window iconize')
    assert 'x <wp, N>:' in scr.text(),('hidden Points icon restores browser',scr.text())
    print('PASS hidden iconized Points restores exact layout and expands browser')
    command('options restoresettings '+pointsfile)
    command('window zoom')
    pointszoom=os.path.join(work,'points-zoom.cld')
    command('options savesettings '+pointszoom)
    command('delete all')
    command('options restoresettings '+pointszoom)
    command('options restoresettings '+pointszoom)
    command('options savesettings '+layoutcopy)
    assert geometry(pointszoom)==geometry(layoutcopy),('hidden zoomed Points restore drift',geometry(pointszoom),geometry(layoutcopy))
    command('window zoom')
    command('options savesettings '+layoutcopy)
    assert geometry(pointsfile)==geometry(layoutcopy),('Points unzoom return layout',geometry(pointsfile),geometry(layoutcopy))
    print('PASS hidden zoomed Points restores twice and unzooms to original layout')


    print('PASS CallStack on: routine listed; next routine adds bump; off hides')
    send(b'\x1bx');pump(.7);assert ' File  Edit' in scr.text()
finally:
    try:os.kill(pid,signal.SIGHUP)
    except ProcessLookupError:pass
    for d in (home,rec,work):shutil.rmtree(d,ignore_errors=True)
