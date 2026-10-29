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
        open('/tmp/md-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

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

import json

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])

def wait_for(needles, secs=8.0):
    t0 = time.time()
    while time.time() - t0 < secs:
        t = scr.text()
        if all(n in t for n in needles):
            return t
        pump(0.3)
    check('TIMEOUT waiting ' + str(needles) + ' :: ' + scr.text().replace('\n', '|')[-200:], False)
    return scr.text()

def insp_num(label):
    m = re.search(label + r':\s*(\d+)', scr.text())
    return int(m.group(1)) if m else None

# Options > Designer
send(b'\x1bo'); pump(0.8); send(b's')
wait_for(['My Dialog'], secs=5.0)
check('designer opens with default dialog', 'My Dialog' in scr.text())

# Duplicate P selects PushButton then Paste without closing the palette.
send(b'\x1bOQ');pump(.5);send(b'p');pump(.4)
check('duplicate P keeps palette open at PushButton', 'Generate and open' in scr.text())
send(b'p');pump(.4)
check('second P keeps palette open at Paste', 'Generate and open' in scr.text())
send(b'\x1b');pump(.4)
# F2 palette -> ListBo~x -> Enter places it (listbox: resizable W and H)
send(b'\x1bOQ'); pump(1.0)   # F2
check('palette popup opens', 'Generate and open' in scr.text())
send(b'm'); pump(0.8)          # ListBo~x -> placing mode
send(b'\r'); pump(1.0)        # drop at ghost position
check('combobox placed with default item', 'Item 1' in scr.text())

# inspector: F4 shows it, F6 focuses it; fields Row,Col,Variable,Items,Width,Height
send(b'\x1bOS'); pump(0.8)   # F4 -> inspector on
check('inspector visible', 'Inspector' in scr.text())
send(b'\x1b[17~'); pump(0.6) # F6 -> focus inspector
for _ in range(4): send(b'\x1b[B'); pump(0.2)   # Down to Width
for _ in range(3): send(b'\x1b[C'); pump(0.2)   # Right x3 -> width 23
check('resize via inspector: width 20 -> 23', insp_num('Width') == 23)
send(b'\x1b[B'); pump(0.2)   # Down to Height
send(b'\x1b[C'); pump(0.2)   # Right x1 -> height 7
check('resize via inspector: height 6 -> 7', insp_num('Height') == 7)

# F10 save JSON (default mydialog.json in the app CWD = work dir)
send(b'\x1b[21~'); pump(0.8)  # F10
wait_for(['Save dialog as JSON'], secs=4.0)
send(b'\r'); pump(0.5); send(b'\r'); pump(1.0)   # Enter through GET + OK
model = json.load(open(os.path.join(work, 'mydialog.json')))
c0 = model['controls'][0]
check('JSON saved with resized model', c0.get('type') == 'combobox' and c0.get('width') == 23 and c0.get('height') == 7)

# dirty the WIDTH: current field is Height -> Up to Width, Left to 22
send(b'\x1b[A'); pump(0.2)
send(b'\x1b[D'); pump(0.3)
check('model dirtied again (width 22)', insp_num('Width') == 22)

# F12 reload: restores the saved model; Tab re-selects the control (load
# leaves no selection, so the inspector would show DIALOG dims instead)
send(b'\x1b[24~'); pump(0.8)  # F12 -> Open JSON
wait_for(['Open a JSON dialog'], secs=4.0)
send(b'\r'); pump(0.5); send(b'\r'); pump(1.2)
wait_for(['Loaded mydialog.json'], secs=4.0)
send(b'\t'); pump(0.8)        # Tab -> select the listbox
check('F12 reload restores width 23', insp_num('Width') == 23)
check('F12 reload restores height 7', insp_num('Height') == 7)

# F9 Generate PRG -> mydialog.prg with a real LISTBOX line
send(b'\x1b[20~'); pump(1.2)  # F9
check('generate hint shown', 'Generated mydialog.prg' in scr.text())
gen = open(os.path.join(work, 'mydialog.prg')).read()
check('generated PRG contains native dropdown', 'LISTBOX aItems1 DROPDOWN' in gen)

# F2 -> Up wraps to the LAST item "Generate and open" -> overwrite? Yes
# -> designer queues the file and exits; the IDE opens it in the editor
send(b'\x1bOQ'); pump(1.0)   # F2
send(b'\x1b[A'); pump(0.4)   # Up wraps to the last item
send(b'\r'); pump(0.8)
t = scr.text()
if 'Overwrite' in t:
    send(b'\r'); pump(1.5)   # DsnConfirm: Enter fires the focused first button (Yes)
t = wait_for(['mydialog.prg'], secs=5.0)
check('designer exits and IDE opens generated PRG', 'mydialog.prg' in t)
# the generated file is the one already verified on disk; the editor shows it
check('editor left the designer (IDE menu back)', 'Edit' in t and 'Project' in t)

# clean exit: both docs clean
send(b'\x1b'); pump(1.0)
t = scr.text()
if 'Unsaved changes' in t:
    send(b'd'); pump(1.0)
w = os.waitpid(pid, os.WNOHANG)
alive = (w[0] == 0)
check('IDE exits clean', not alive)
if alive:
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)

# Compile and execute the generated artifact, not a hand-written lookalike.
import subprocess
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
runtime_source = os.path.join(work, 'combo-runtime.prg')
value_path = os.path.join(work, 'value.txt')
open(runtime_source, 'w').write(gen.replace('return lOk',
    'hb_MemoWrit( "' + value_path + '", hb_ntos( nVar1 ) )\nreturn lOk') +
    '\nprocedure Main()\nDlg_MyDialog()\nreturn\n')
runtime_bin = os.path.join(work, 'combo-runtime')
build = subprocess.run(['hbmk2', runtime_source] + [os.path.join(root, p) for p in
    ['hbwindow.prg', 'hbmenu.prg', 'hbbutton.prg', 'hbgetu.prg']] +
    ['-gttrm', '-quiet', '-o' + runtime_bin], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
check('generated combobox artifact compiles', build.returncode == 0)
if build.returncode == 0:
    scr = Scr()
    pid, fd = pty.fork()
    if pid == 0:
        os.environ['TERM'] = 'xterm'
        os.execv(runtime_bin, [runtime_bin])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))
    pump(3)
    check('runtime collapsed first item', 'Item 1' in scr.text() and 'Item 2' not in scr.text())
    send(b' '); pump(.5)
    check('runtime space opens dropdown', all(x in scr.text() for x in ['Item 1','Item 2','Item 3']))
    send(b'\x1b[B'); pump(.5)
    send(b'\t'); pump(.4)
    check('runtime tab closes popup', 'Item 2' in scr.text() and 'Item 3' not in scr.text())
    def click_text(label):
        for row in range(ROWS):
            col = ''.join(scr.g[row]).find(label)
            if col >= 0:
                send(b'\x1b[M' + bytes([32, col + 33, row + 33])); pump(.2)
                send(b'\x1b[M' + bytes([35, col + 33, row + 33])); pump(.5)
                return True
        return False
    click_text('Item 2')
    check('runtime mouse opens dropdown', 'Item 3' in scr.text())
    click_text('Item 3')
    check('runtime mouse selects and closes', 'Item 3' in scr.text() and 'Item 1' not in scr.text())
    send(b'\x1b'); pump(.7)
    check('runtime selection reaches bound variable', os.path.exists(value_path) and
          open(value_path).read().strip() == '3')
    w = os.waitpid(pid, os.WNOHANG)
    if w[0] == 0:
        os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)

fails = 0
for name, ok in results:
    print(('PASS' if ok else 'FAIL'), name)
    if not ok: fails += 1
print('TOTAL', len(results)-fails, 'PASS', fails, 'FAIL')
shutil.rmtree(home, ignore_errors=True)
shutil.rmtree(rec, ignore_errors=True)
shutil.rmtree(work, ignore_errors=True)
sys.exit(1 if fails else 0)
