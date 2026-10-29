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


home = tempfile.mkdtemp(prefix='hbide-nav-home-')
rec  = tempfile.mkdtemp(prefix='hbide-nav-rec-')
work = tempfile.mkdtemp(prefix='hbide-nav-work-')
GOOD = ('#include "hbclass.ch"\n'
        '// function Commented()\n'
        '/* procedure InBlock()\n'
        '   function InBlock2() */\n'
        'function Main( ... )\n'
        '   local a := hb_AParams()\n'
        '   hb_MemoWrit( "args.out", hb_ValToExp( a ) )\n'
        '   Helper()\n'
        '   return nil\n'
        '\n'
        'static procedure Helper()\n'
        '   ? "helper"\n'
        '   return\n'
        '\n'
        'CLASS Demo\n'
        '   METHOD Run()\n'
        'ENDCLASS\n'
        '\n'
        'METHOD Run() CLASS Demo\n'
        '   return Self\n')
BAD = ('function Main()\n'
       '   local x := 1\n'
       '   ? x +\n'
       '   return nil\n'
       '\n'
       'function Other()\n'
       '   local y := := 2\n'
       '   return nil\n')
open(os.path.join(work, 'good.prg'), 'w').write(GOOD)
open(os.path.join(work, 'bad.prg'), 'w').write(BAD)
open(os.path.join(work, 'script.prg'), 'w').write('function Main( ... )\n   hb_MemoWrit( "script.out", hb_ValToExp( hb_AParams() ) )\nreturn nil\n')
open(os.path.join(work, 'other.prg'), 'w').write('function Alone()\nreturn nil\n')
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

def status_row():
    return scr.text().split('\n')[ROWS-1]

KCTRL_G = b'\x07'
KALT_F8 = b'\x1b[19;3~'
KALT_F7 = b'\x1b[18;3~'
KCTRL_F2 = b'\x1b[12;5~'
KALT_0 = b'\x1b0'

pump(4.0)
wait_has('boot', ['noname.prg'])

# ---- 1. Go to function/procedure/method
open_file('good.prg')
check('good.prg opened', 'good.prg' in scr.text())
send(KCTRL_G); pump(1.0)
t = wait_has('function list opens with real entries', ['Gotofunction', 'Main', 'Helper', 'Demo:Run', 'class'])
dlg = t.split('Go to function')[1]   # the editor text behind the dialog shows them
check('commented and block-commented names are not listed', 'Commented' not in dlg and 'InBlock' not in dlg)
check('static procedure labelled', 'static procedure' in t)
send(b'help'); pump(0.6)
t = scr.text()
check('filter narrows list (Helper kept, Main gone)', 'Helper' in t and 'Main' not in t.split('Find:')[1] if 'Find:' in t else False)
send(b'\r'); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Enter jumps to Helper line 11', m and m.group(1) == '11')
send(KCTRL_G); pump(0.8); send(b'\x1b'); pump(0.6)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Esc leaves the cursor where it was', m and m.group(1) == '11')

# ---- 2. error navigation from the build
open_file('bad.prg')
send(b'\x1bf'); pump(0.1)
send(b'\x1b'); pump(0.4)
send(b'\x1br'); pump(0.8); send(b's')      # Run > Start
t = wait_has('failed build shows compiler output', ['Error'], timeout=40)
send(b'\r'); pump(1.5)                     # dismiss the build output dialog
send(b'\r'); pump(2.0)                     # dismiss the "Build failed" dialog
t = scr.text()
m = re.search(r'row:\s*(\d+)', t)
check('failed build lands on the first error line (3)', m and m.group(1) == '3')
check('status row shows message 1/3', '1/3' in status_row() and 'ERROR' in status_row())
send(KALT_F8); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Alt+F8 goes to the second error (line 7)', m and m.group(1) == '7')
check('status row shows message 2/3', '2/3' in status_row())
send(KALT_F8); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Alt+F8 reaches the warning (3/3, line 9)', m and m.group(1) == '9' and '3/3' in status_row() and 'WARNING' in status_row())
send(KALT_F8); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Alt+F8 wraps to the first error', m and m.group(1) == '3' and 'wrapped' in status_row())
send(KALT_F7); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Alt+F7 goes back (wraps to last, line 9)', m and m.group(1) == '9')
# Window > Messages list
send(b'\x1bw'); pump(0.8); send(b'm'); pump(1.0)
t = wait_has('message list opens', ['Compilermessages', 'bad.prg:3', 'bad.prg:7'])
send(b'\x1b[B'); pump(0.2); send(b'\x1b[A'); pump(0.2); send(b'\r'); pump(1.0)
m = re.search(r'row:\s*(\d+)', scr.text())
check('Enter in the list jumps to the picked message', m is not None)

# ---- 3. Save All + window list
open_file('other.prg')
send(b'AA'); pump(0.5)                    # dirty other.prg
send(KALT_0); pump(1.0)
t = wait_has('window list shows documents', ['Windowlist', 'good.prg', 'other.prg', 'bad.prg'])
check('window list marks modified document', re.search(r'\*\s+\S*other\.prg', t) is not None)
send(b'bad'); pump(0.5); send(b'\r'); pump(1.0)
check('window list switches document', 'bad.prg' in scr.text().split('\n')[1])
send(b'ZZ'); pump(0.5)                    # dirty bad.prg too
send(KCTRL_F2); pump(1.5)
check('Save All reports in the status row', 'Save All: 2' in status_row())
check('bad.prg saved to disk', 'ZZ' in open(os.path.join(work, 'bad.prg')).read())
check('other.prg saved to disk', open(os.path.join(work, 'other.prg')).read().startswith('AA'))
send(KCTRL_F2); pump(1.0)
check('Save All with nothing modified says so', 'nothing modified' in status_row())

# ---- 4. Run arguments (Start uses them)
open_file('good.prg')
send(b'\x1br'); pump(0.8); send(b'a'); pump(1.0)
t = wait_has('arguments dialog opens', ['Runarguments'])
send(b'one "two words" three'); send(b'\r'); pump(1.0)
check('arguments confirmed in status row', 'Run arguments:' in status_row())
send(b'\x1br'); pump(0.8); send(b's'); pump(0.5)
t0 = time.time()
argf = os.path.join(work, 'args.out')
while not os.path.exists(argf) and time.time() - t0 < 40:
    send(b'\r'); pump(1.5)
check('Start passes the arguments to the program', os.path.exists(argf) and
      open(argf).read() == '{"one", "two words", "three"}')

# Run > Script receives the same arguments as Main() parameters
open_file('script.prg')
send(b'\x1br'); pump(0.8); send(b'c'); pump(3.0)
sf = os.path.join(work, 'script.out')
check('Script passes the arguments to Main()', os.path.exists(sf) and
      open(sf).read() == '{"one", "two words", "three"}')
# Run > Debug: F5 (Go) lets the debuggee finish; it sees the same arguments
os.remove(sf)
send(b'\x1br'); pump(0.8); send(b'd'); pump(3.0)
send(b'\x1b[15~'); pump(3.0)
check('Debug passes the arguments to Main()', os.path.exists(sf) and
      open(sf).read() == '{"one", "two words", "three"}')
send(b'\x1b'); pump(0.3)
send(b'\x1b[24~'); pump(0.2)
send(b'\x18'); pump(0.2)
os.kill(pid, signal.SIGKILL)

shutil.rmtree(home, True); shutil.rmtree(rec, True)
fails = [n for n, ok in results if not ok]
for n, ok in results: print(('PASS ' if ok else 'FAIL ') + n)
print('%d/%d passed' % (len(results) - len(fails), len(results)))
sys.exit(1 if fails else 0)
