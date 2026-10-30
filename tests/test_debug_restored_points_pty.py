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
    def command(text):
        send(text.encode()+b'\r');pump(.5)
    command('bp 4')
    settings=os.path.join(work,'points.cld')
    command('options savesettings '+settings)
    command('options restoresettings '+settings)
    command('options restoresettings '+settings)
    send(b'\x1b[15~');pump(.9)
    assert execution_line()==4,('restored breakpoint must stop at line4',execution_line(),scr.text())
    print('PASS twice-restored line breakpoint actually stops VM at line4')
    command('delete all')
    # Tracepoint on n, then change n through the real command evaluator.
    command('tp n')
    tracefile=os.path.join(work,'trace.cld')
    command('options savesettings '+tracefile)
    command('options restoresettings '+tracefile)
    command('options restoresettings '+tracefile)
    command('window select points')
    send(b'\r');pump(.3)
    assert 'Enter Watchpoint' in scr.text(),scr.text()
    send(b'\x19n+1\r');pump(.4)
    edited=os.path.join(work,'edited-tracepoint.cld')
    command('options savesettings '+edited)
    assert 'TP n+1' in open(edited).read(),('editing tracepoint must preserve its type',open(edited).read())
    print('PASS editing tracepoint expression preserves TP type')
    command('window select command')
    command('? n := 99')
    send(b'\x1b[15~');pump(.9)
    assert 'Command' in scr.text() and execution_line()==5,('restored tracepoint must stop on change',execution_line(),scr.text())
    assert '99' in scr.text(),('tracepoint changed value',scr.text())
    print('PASS twice-restored tracepoint stops on real value change')
    badpath=os.path.join(work,'missing-parent','settings.cld')
    command('options savesettings '+badpath)
    assert 'Cannot save settings' in scr.text(),('write failure must be visible',scr.text())
    send(b'\r');pump(.4)
    assert not os.path.exists(badpath),badpath
    command('? 6*7')
    assert '42' in scr.text(),('debugger remains usable after failed save',scr.text())
    print('PASS failed settings write is visible and debugger remains usable')
    original=os.path.join(work,'original.cld')
    link=os.path.join(work,'linked.cld')
    open(original,'wb').write(b'ORIGINAL SETTINGS BYTES')
    os.symlink(original,link)
    command('options savesettings '+link)
    assert os.path.islink(link) and open(original,'rb').read()==b'ORIGINAL SETTINGS BYTES',('symlink settings save must fail closed',scr.text())
    assert 'Cannot save settings' in scr.text(),scr.text()
    print('PASS symlink settings save preserves link and original bytes')
    import glob
    recovered=glob.glob(link+'.tmp-*')
    assert len(recovered)==1 and open(recovered[0]).read().startswith('Options Path '),('recoverable settings temp',recovered)
    regular=os.path.join(work,'regular.cld')
    open(regular,'wb').write(b'old')
    os.chmod(regular,0o640)
    command('options savesettings '+regular)
    assert os.stat(regular).st_mode & 0o777==0o640,oct(os.stat(regular).st_mode)
    assert open(regular).read().startswith('Options Path ') and glob.glob(regular+'.tmp-*')==[],regular
    print('PASS settings replacement preserves mode and leaves no success temp')
    command('options restoresettings '+os.path.join(work,'absent.cld'))
    assert 'Settings file not found' in scr.text(),('missing restore must be visible',scr.text())
    command('? 8*8')
    assert '64' in scr.text(),('debugger usable after missing restore',scr.text())
    print('PASS missing settings restore is visible and debugger stays usable')
    command('run speed 7')
    send(b'\x1br');pump(.3);send(b'p');pump(.4)
    assert 'Step delay' in scr.text(),scr.text()
    send(b'\x19-5\r');pump(.4)
    speedfile=os.path.join(work,'speed.cld')
    command('options savesettings '+speedfile)
    assert 'Run Speed 0' in open(speedfile).read(),('negative animation delay must not be stored',open(speedfile).read())
    print('PASS Speed dialog does not store negative delay')
    send(b'\x1br');pump(.3);send(b'p');pump(.3)
    send(b'\x1965535\r');pump(.3)
    command('options savesettings '+speedfile)
    assert 'Run Speed 65534' in open(speedfile).read(),open(speedfile).read()
    command('run speed 7')
    send(b'\x1br');pump(.3);send(b'p');pump(.3)
    send(b'\x1999\x1b');pump(.3)
    command('options savesettings '+speedfile)
    assert 'Run Speed 7' in open(speedfile).read(),open(speedfile).read()
    print('PASS Speed dialog bounds high delay and Cancel preserves prior value')
    send(b'\x1bo');pump(.3);send(b't');pump(.3)
    assert 'Tab width' in scr.text(),scr.text()
    send(b'\x19-3\r');pump(.3)
    tabfile=os.path.join(work,'tab.cld')
    command('options savesettings '+tabfile)
    assert 'Options Tab 1' in open(tabfile).read(),('negative tab width must not be stored',open(tabfile).read())
    print('PASS Tab Width dialog does not store negative width')
    send(b'\x1bo');pump(.3);send(b't');pump(.3)
    send(b'\x1999\r');pump(.3)
    command('options savesettings '+tabfile)
    assert 'Options Tab 16' in open(tabfile).read(),open(tabfile).read()
    command('options tabwidth 0')
    command('options savesettings '+tabfile)
    assert 'Options Tab 1' in open(tabfile).read(),open(tabfile).read()
    command('options tabwidth 4')
    send(b'\x1bo');pump(.3);send(b't');pump(.3)
    send(b'\x1912\x1b');pump(.3)
    command('options savesettings '+tabfile)
    assert 'Options Tab 4' in open(tabfile).read(),open(tabfile).read()
    print('PASS Tab Width bounds dialog and command consistently; Cancel preserves four')
    command('options pathforfiles '+work)
    send(b'\x1bo');pump(.3);send(b'f');pump(.3)
    assert 'Search path for source files:' in scr.text(),scr.text()
    send(b'\x19/not-the-saved-path\x1b');pump(.3)
    pathfile=os.path.join(work,'path-cancel.cld')
    command('options savesettings '+pathfile)
    assert 'Options Path '+work in open(pathfile).read(),('Path dialog Cancel must preserve previous path',open(pathfile).read())
    print('PASS Path For Files dialog Cancel preserves prior path')
    colorsbefore=os.path.join(work,'colors-before.cld')
    colorsafter=os.path.join(work,'colors-after.cld')
    command('options savesettings '+colorsbefore)
    command('options colors {"W/B"}')
    command('options savesettings '+colorsafter)
    def colorline(path):
        return next(x for x in open(path).read().splitlines() if x.startswith('Options Colors '))
    assert colorline(colorsbefore)==colorline(colorsafter),('incomplete color list must preserve palette',colorline(colorsbefore),colorline(colorsafter))
    print('PASS incomplete Colors command preserves complete palette')
    import json
    originalcolors=colorline(colorsbefore)
    palette=json.loads('['+originalcolors[len('Options Colors ')+1:-1]+']')
    for malformed in ['{'+json.dumps(palette+['W/B'])[1:-1]+'}','{'+json.dumps(palette[:-1]+['NOT_A_COLOR'])[1:-1]+'}',','.join('"'+x+'"' for x in palette)]:
        command('options colors '+malformed)
        assert 'Colors expects 11' in scr.text(),('invalid Colors diagnostic',malformed,scr.text())
        command('options savesettings '+colorsafter)
        assert colorline(colorsafter)==originalcolors,('invalid Colors changed palette',malformed,colorline(colorsafter))
    print('PASS invalid count, color token and missing braces preserve palette with error')
    palette[0:4]=['GR+/N','7/0','U/N','I']
    command('options colors {'+json.dumps(palette,separators=(',',':'))[1:-1]+'}')
    command('options savesettings '+colorsafter)
    assert json.loads('['+colorline(colorsafter)[len('Options Colors ')+1:-1]+']')==palette,('valid palette must apply',colorline(colorsafter))
    command('options restoresettings '+colorsbefore)
    command('options savesettings '+colorsafter)
    assert colorline(colorsafter)==originalcolors,('valid saved palette restores',colorline(colorsafter))
    print('PASS complete Colors palette applies and saved original restores')

    command('delete all')
    command('tp n')
    malformeddelete=os.path.join(work,'malformed-delete.cld')
    for invalid in ('0oops','0.5','-1'):
        command('delete tp '+invalid)
        command('options savesettings '+malformeddelete)
        assert any(x.startswith('TP ') for x in open(malformeddelete).read().splitlines()),('malformed index must not delete tracepoint',invalid,open(malformeddelete).read())
    print('PASS malformed Delete TP index leaves points unchanged')
    command('delete tp 0')
    deleted=os.path.join(work,'deleted-tracepoint.cld')
    command('options savesettings '+deleted)
    assert not any(x.startswith('TP ') for x in open(deleted).read().splitlines()),('Delete TP index must remove tracepoint',open(deleted).read())
    print('PASS Delete TP zero removes the tracepoint')
    command('bp 4')
    bpindex=os.path.join(work,'bp-index.cld')
    command('options savesettings '+bpindex)
    assert any(x.startswith('BP ') for x in open(bpindex).read().splitlines()),open(bpindex).read()
    for invalid in ('4oops','4.5','4294967300','999999999999999999999999'):
        command('bp '+invalid)
        command('options savesettings '+bpindex)
        assert any(x.startswith('BP ') for x in open(bpindex).read().splitlines()),('malformed BP line toggled existing point',invalid,open(bpindex).read())
    print('PASS malformed BP line leaves existing breakpoint unchanged')
    for invalid in ('0oops','0.5','-1','4294967296','4294967297','999999999999999999999999'):
        command('delete bp '+invalid)
        command('options savesettings '+bpindex)
        assert any(x.startswith('BP ') for x in open(bpindex).read().splitlines()),('malformed BP index changed points',invalid,open(bpindex).read())
    command('delete bp 0')
    command('options savesettings '+bpindex)
    assert not any(x.startswith('BP ') for x in open(bpindex).read().splitlines()),open(bpindex).read()
    print('PASS malformed BP indexes preserve points and integer zero deletes')
    command('wp n')
    wpindex=os.path.join(work,'wp-index.cld')
    for invalid in ('0oops','0.5','-1'):
        command('delete wp '+invalid)
        command('options savesettings '+wpindex)
        assert any(x.startswith('WP ') for x in open(wpindex).read().splitlines()),('malformed WP index changed points',invalid,open(wpindex).read())
    command('delete wp 0')
    command('options savesettings '+wpindex)
    assert not any(x.startswith('WP ') for x in open(wpindex).read().splitlines()),open(wpindex).read()
    print('PASS malformed WP indexes preserve points and integer zero deletes')


    send(b'\x1bx');pump(.7);assert ' File  Edit' in scr.text()
finally:
    try:os.kill(pid,signal.SIGHUP)
    except ProcessLookupError:pass
    for d in (home,rec,work):shutil.rmtree(d,ignore_errors=True)
