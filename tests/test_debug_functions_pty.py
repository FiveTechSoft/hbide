import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile, re

# Linux-only E2E: debugger FUNCTION matrix, durable version of the Oct-25
# ad-hoc inventory (todo debugger 08:15/08:28). One session over a real PTY:
# Command window commands, Step/Trace/NextRoutine, Calls/WorkAreas/Sets
# views, Tracepoint stop-on-change, Point Delete dialog, Speed dialog.
# Semantics kept upstream: watchpoints are display-only, tracepoints stop
# when the value changes (en.txt:358-363).
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
    if not cond:
        open('/tmp/df-fail-%02d.txt' % len(results), 'w').write('FAILED: ' + name + '\n=====\n' + scr.text())

def wait_has(name, subs, timeout=8.0, collapse=True):
    t0 = time.time()
    while True:
        t = scr.text()
        tt = t.replace(' ', '') if collapse else t
        if all(s in tt for s in subs):
            check(name, True); return t
        if time.time() - t0 > timeout:
            check(name, False); return t
        pump(0.3)

def exec_lineno():
    # the code browser marks the exec line with a distinct attribute; read
    # the line number whose text cell attribute differs from its neighbors
    best = None
    for r in range(ROWS):
        line = ''.join(scr.g[r])
        m = re.match(r'\s*x?(\d+):(.*)', line)
        if m and 'x' not in m.group(2):
            pass
    return best

def exec_row_attr(lineno):
    for r in range(ROWS):
        line = ''.join(scr.g[r])
        if re.match(r'[x\s]*%d:' % lineno, line):
            return scr.at[r][3]
    return None

def cur_exec():
    # exec line = the numbered code row whose bg differs from plain code rows
    attrs = {}
    for r in range(ROWS):
        line = ''.join(scr.g[r])
        m = re.match(r'\s*x?(\d+):', line)
        if m:
            attrs.setdefault(scr.at[r][3][1], []).append(int(m.group(1)))
    if len(attrs) < 2:
        return None
    # the minority bg among numbered rows is the exec bar
    minority = min(attrs.values(), key=len)
    return minority[0] if len(minority) == 1 else None

pump(4.0)
wait_has('boot caption noname', ['noname.prg'])
send(b'\x1bf'); pump(0.8); send(b'o')
t0 = time.time()
while 'Open a file' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(work.encode() + b'/fn.prg'); send(b'\r'); pump(1.2)
check('fn.prg open', 'fn.prg' in scr.text())

# no editor BP here (BP stop is covered by test_debug_session_pty): this
# suite proves the TRACEPOINT stops the run on its own.
send(b'\x1br'); pump(0.8); send(b'd')
t0 = time.time()
while 'Command' not in scr.text() and time.time() - t0 < 12.0:
    pump(0.5)
check('debugger UI up', 'Point' in scr.text() and 'Command' in scr.text())

# Point > Tracepoint on n (InputBox "Enter Tracepoint")
send(b'\x1bp'); pump(0.8); send(b't')
t0 = time.time()
while 'Enter Tracepoint' not in scr.text() and time.time() - t0 < 5.0:
    pump(0.3)
check('Tracepoint dialog opens', 'Enter Tracepoint' in scr.text())
send(b'n\r'); pump(1.0)

# F5: n first changes at line 2 -> TP stops at line 3 (no BP exists)
send(b'\x1b[15~'); pump(2.0)
check('tracepoint stops after change (line 3)', cur_exec() == 3)

# Point > Delete...: InputBox asks the item number, prefilled 0; Enter deletes
send(b'\x1bp'); pump(0.8); send(b'd')
t0 = time.time()
while 'Enter item number' not in scr.text() and time.time() - t0 < 5.0:
    pump(0.3)
check('Point Delete dialog opens', 'Enter item number' in scr.text())
send(b'\r'); pump(1.0)
# effect: the points window hid -> Delete is now a no-op (no dialog)
send(b'\x1bp'); pump(0.8); send(b'd'); pump(1.0)
check('deleted point hides window (Delete now no-op)', 'Enter item number' not in scr.text())
send(b'\x1b'); pump(0.5)

# Ctrl-F5 from Main: next routine ENTRY is bump -> exec line 7
send(b'\x1b[15;5~'); pump(1.5)
check('Ctrl-F5 enters next routine (bump line 7)', cur_exec() == 7)

# Calls view shows the stack with bump over __Main
send(b'\x1bv'); pump(0.8); send(b'c'); pump(1.2)
t = scr.text()
check('Calls window opens', 'Calls' in t)
check('Calls lists bump', 'bump' in t.lower())
send(b'\x1bv'); pump(0.6); send(b'c'); pump(1.0)   # toggle back off

# Trace F10 -> next line same level (7 -> 8); Step F8 returns to Main line 4.
# Harbour semantics (dbgentry.c): Trace sets bTraceOver + level cap (OVER),
# Step leaves it false and breaks at the next executed line at ANY level.
send(b'\x1b[21~'); pump(1.2)
check('Trace F10 steps over to line 8', cur_exec() == 8)
send(b'\x1b[19~'); pump(1.5)
check('Step F8 back in Main (line 4)', cur_exec() == 4)

# WorkAreas F6: no dbf in use -> the documented alert IS the effect
send(b'\x1b[17~'); pump(1.2)
check('WorkAreas F6 alerts when no areas', 'No workareas in use' in scr.text())
send(b'\r'); pump(0.8)   # dismiss alert

# View > Sets: modal System Settings browse; Esc closes
send(b'\x1bv'); pump(0.8); send(b's'); pump(1.2)
t = scr.text()
check('Sets view opens', 'System Settings' in t)
send(b'\x1b'); pump(0.8)

# Run > Speed: InputBox "Step delay" accepts a value
send(b'\x1br'); pump(0.8); send(b'p')
t0 = time.time()
while 'Step delay' not in scr.text() and time.time() - t0 < 5.0:
    pump(0.3)
check('Speed dialog opens', 'Step delay' in scr.text())
send(b'1\r'); pump(0.8)

# Command window: NUM toggles line numbers (unhandled keys route to Command)
send(b'NUM\r'); pump(1.0)
t = scr.text()
check('Command NUM removes line numbers', not re.search(r'x?\d+:', t))
send(b'NUM\r'); pump(1.0)
check('Command NUM restores line numbers', re.search(r'x?\d+:', scr.text()) is not None)

# ---- session 2: Monitor, Window, Options, File, Command expression ----
# close session 1's debugger first: Alt+R inside it only opens its Run popup
send(b'\x1bx'); pump(1.5)
check('session 1 closed to IDE', 'fn.prg' in scr.text() and 'Edit' in scr.text())
# editor BP on line 3 so F5 stops with the local already assigned
send(b'\x1b[B'); pump(0.2); send(b'\x1b[B'); pump(0.2)
send(b'\x1b[20~'); pump(0.8)
send(b'\x1br'); pump(0.8); send(b'd')
t0 = time.time()
while 'Command' not in scr.text() and time.time() - t0 < 12.0:
    pump(0.5)
check('session 2 debugger up', 'Point' in scr.text())
send(b'\x1b[15~'); pump(2.0)
check('session 2 stops at BP line 3', cur_exec() == 3)

# Monitor > Local: the window lists the local with its type tag
send(b'\x1bm'); pump(0.8); send(b'l'); pump(1.2)
check('Monitor Local shows typed var', '<Local' in scr.text())
# Monitor > Sort: reorders without losing the view
send(b'\x1bm'); pump(0.6); send(b'o'); pump(1.0)
check('Monitor Sort keeps the view', '<Local' in scr.text())

# Window Next/Prev (Tab / Shift-Tab): focus moves the hardware cursor
send(b'\x1bv'); pump(0.6); send(b'c'); pump(1.0)   # open Calls as 2nd window
pump(0.5); cur0 = LASTCUR[0]
send(b'\t'); pump(1.0); cur1 = LASTCUR[0]
check('Window Next moves the cursor to another window', cur0 is not None and cur1 is not None and cur0 != cur1)
send(b'\x1b[Z'); pump(1.0)
check('Window Prev moves it back', LASTCUR[0] == cur0)
send(b'\x1bv'); pump(0.6); send(b'c'); pump(0.8)   # close Calls

# Window > Cascade rearranges the visible windows (captions move)
def caption_pos(caption):
    for r in range(ROWS):
        line = ''.join(scr.g[r])
        c = line.find(caption)
        if c >= 0:
            return (r, c)
    return None
# the code window sits below the Monitor; cascade stacks full-screen rects
# with an offset, so its title row moves UP to 1
t0 = time.time()
while caption_pos('__hbide_dbg__') is None and time.time() - t0 < 5.0:
    pump(0.3)
pos_before = caption_pos('__hbide_dbg__')
send(b'\x1bw'); pump(0.8); send(b'c'); pump(1.2)
pos_after = caption_pos('__hbide_dbg__')
check('Cascade rearranges windows', pos_before is not None and pos_after is not None and pos_after[0] < pos_before[0])
# windows are re-stacked, never lost: Tab keeps cycling focus after Cascade
tab_positions = set()
for _ in range(3):
    send(b'\t'); pump(0.7)
    tab_positions.add(LASTCUR[0])
check('Window Next cycles after Cascade (z-order, no loss)', len(tab_positions) >= 2)

# Options > Line Numbers: the x<n>: prefixes vanish and return
send(b'\x1bo'); pump(0.8); send(b'l'); pump(1.0)
check('Options Line Numbers off', not re.search(r'x?\d+:', scr.text()))
send(b'\x1bo'); pump(0.6); send(b'l'); pump(1.0)
check('Options Line Numbers on', re.search(r'x?\d+:', scr.text()) is not None)

# Options > mono Display: the exec bar attribute changes (hotkey 'd';
# 'm' is the upstream stub "Menu Bar" = Not implemented yet)
before = exec_row_attr(3)
send(b'\x1bo'); pump(0.6); send(b'd'); pump(1.0)
after = exec_row_attr(3)
check('Options mono Display changes colors', before is not None and after is not None and before != after)
send(b'\x1bo'); pump(0.6); send(b'd'); pump(1.0)

# Options > path for Files: InputBox opens, Esc cancels
send(b'\x1bo'); pump(0.6); send(b'f')
t0 = time.time()
while 'Search path' not in scr.text() and time.time() - t0 < 5.0:
    pump(0.3)
check('Options path for Files dialog', 'Search path' in scr.text())
send(b'\x1b'); pump(0.6)

# File > Open...: the debugger file dialog opens, Esc cancels
send(b'\x1bf'); pump(0.8); send(b'o'); pump(1.0)
t = scr.text()
check('File Open dialog opens', 'Please choose a source file' in t)
send(b'\x1b'); pump(0.6)

# File > OS Shell: banner, real shell, exit returns to the debugger
send(b'\x1bf'); pump(0.6); send(b's')
t0 = time.time()
while 'RETURN to the Debugger' not in scr.text() and time.time() - t0 < 5.0:
    pump(0.3)
check('OS Shell banner', 'RETURN to the Debugger' in scr.text())
send(b'exit\r')
pump(1.5)
send(b'\x1b[C'); pump(1.0)   # harmless key: forces the debugger repaint
t0 = time.time()
while '__hbide_dbg__' not in scr.text() and time.time() - t0 < 6.0:
    pump(0.3)
check('exit returns to the debugger', '__hbide_dbg__' in scr.text())

# Command window expression: ? 6*7 prints 42
send(b'? 6*7\r'); pump(1.2)
check('Command ? evaluates', '42' in scr.text())

# --- menu checkmark STATE only (durable version of the Oct-25 ad-hoc
# rows). These six checks prove menu state, NOT functional effect:
# RunAtStartup/codeBlockTrace/ShowAllGlobals still lack observable-effect
# coverage and must not be reported as functionally verified. ---
def menu_row(name):
    for line in scr.text().split('\n'):
        if name in line:
            return line
    return ''

# checked rows render a CP437 \xFB (sqrt) before the prompt; the UTF-8
# screen model surfaces it as U+FFFD
def is_checked(row, name):
    return re.search(r'[\u221a\ufffd]\s*' + re.escape(name), row) is not None

send(b'\x1bo'); pump(0.9)
row = menu_row('Run at startup')
check('Run at startup checked by default (Clipper compatible)', is_checked(row, 'Run at startup'))
send(b'u'); pump(0.9)
send(b'\x1bo'); pump(0.9)
row = menu_row('Run at startup')
check('Run at startup unchecks after toggle', 'Run at startup' in row and not is_checked(row, 'Run at startup'))
send(b'u'); pump(0.9)   # restore default

send(b'\x1bo'); pump(0.9)
row = menu_row('codeBlock Trace')
check('codeBlock Trace checked by default', is_checked(row, 'codeBlock Trace'))
send(b'b'); pump(0.9)
send(b'\x1bo'); pump(0.9)
row = menu_row('codeBlock Trace')
check('codeBlock Trace unchecks after toggle', 'codeBlock Trace' in row and not is_checked(row, 'codeBlock Trace'))
send(b'b'); pump(0.9)   # restore default

send(b'\x1bm'); pump(0.9)
row = menu_row('Show all Globals')
check('Show all Globals unchecked by default', 'Show all Globals' in row and not is_checked(row, 'Show all Globals'))
send(b'h'); pump(0.9)
send(b'\x1bm'); pump(0.9)
row = menu_row('Show all Globals')
check('Show all Globals checks after toggle', is_checked(row, 'Show all Globals'))
send(b'h'); pump(0.9)   # restore default

# --- Options > Preprocessed Code: swaps the code window to the .ppo view ---
m = re.search(r'(__hbide_dbg__\S+)\.prg', scr.text())
check('session prg name parsed for PPO', m is not None)
if m:
    ppo = os.path.join(work, m.group(1) + '.ppo')
    open(ppo, 'w').write('PPOMARKERLINE\n')
    send(b'\x1bo'); pump(0.9); send(b'p'); pump(1.2)
    check('PPO shows preprocessed view', 'PPOMARKERLINE' in scr.text() and '.ppo' in scr.text())
    send(b'\x1bo'); pump(0.9); send(b'p'); pump(1.2)
    check('PPO toggles back to source', 'procedure Main' in scr.text() and '.ppo' not in scr.text())

# --- Command window interpreter, effect level: bp set/list/toggle, help ---
def cmd_row():
    r = None
    for i in range(ROWS):
        if re.search(r'>\s*$', ''.join(scr.g[i])):
            r = i   # the active prompt is the LAST '>' row; earlier ones are history
    return r
# focus is effect-verified: the command echo row only appears when the
# Command window get receives the keys
focused = False
for _ in range(4):
    send(b'list bp\r'); pump(1.2)
    if '> list bp' in scr.text():
        focused = True
        break
    send(b'\t'); pump(0.7)
check('Command window focused (echo)', focused)

send(b'bp 7\r'); pump(1.0)
send(b'list bp\r'); pump(1.2)
check('Command bp 7 + list bp shows the breakpoint', re.search(r'\)\s*7', scr.text()) is not None)
send(b'bp 7\r'); pump(1.0)   # toggle off
send(b'list bp\r'); pump(1.2)
tail = scr.text()[scr.text().rfind('> list bp'):]
check('Command bp 7 toggles off (not listed anymore)', re.search(r'\)\s*7', tail) is None)

def help_window_up():
    return any('Help' in line and 'q' in line for line in scr.text().split('\n'))
send(b'help\r'); pump(1.2)
check('Command help opens the Help window', help_window_up())
send(b'\x1b'); pump(1.0)
check('Help window closes with ESC', not help_window_up())

# --- Save/Restore Settings round trip: Num Off must persist and come back ---
# bring the code window to the front of the cascade stack (effect-driven):
# gutter digits bleed through even when covered, so require CONTENT text
def code_at_front():
    return 'procedure Main' in scr.text() and 'x := x + 41' in scr.text()
t0 = time.time()
while not code_at_front() and time.time() - t0 < 10.0:
    send(b'\t'); pump(0.7)
check('Code window brought to front', code_at_front())
send(b'\x1bo'); pump(0.6); send(b'l'); pump(1.0)   # line numbers off
check('Settings: line numbers off before save', not re.search(r'x?\d+:', scr.text()))
send(b'\x1bo'); pump(0.6); send(b's')               # Save Settings...
t0 = time.time()
while 'File name' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(b'\r'); pump(1.0)                              # accept default init.cld
cld = os.path.join(work, 'init.cld')
check('Save Settings writes init.cld with Num Off',
      os.path.exists(cld) and 'Num Off' in open(cld).read())
send(b'\x1bo'); pump(0.6); send(b'l'); pump(1.0)   # numbers back on
check('Settings: line numbers on before restore', re.search(r'x?\d+:', scr.text()) is not None)
send(b'\x1bo'); pump(0.6); send(b'r')               # Restore Settings...
t0 = time.time()
while 'File name' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(b'\r'); pump(1.5)
check('Restore Settings reapplies Num Off', not re.search(r'x?\d+:', scr.text()))
send(b'\x1bo'); pump(0.6); send(b'l'); pump(1.0)   # tidy: numbers on again

# --- Options > Tab Width: live propagation to the code browse (91c6a21) ---
# NOTE: an earlier suspicion that PPO restore LOSES tab-indented content was
# wrong - bisected: line 7's visibility flip-flops with the cascade z-order
# (a covering window blanks that band); the text itself is always painted.
def tab_line_col():
    for line in scr.text().split('\n'):
        c = line.find('x := x + 41')
        if c >= 0:
            return c
    return None
t0 = time.time()
while not code_at_front() and time.time() - t0 < 10.0:
    send(b'\t'); pump(0.7)
col4 = tab_line_col()
send(b'\x1bo'); pump(0.6); send(b't')               # Tab Width...
t0 = time.time()
while 'Tab width' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(b'\x1912\r'); pump(1.2)                      # Ctrl+Y clears the get, set 12
col12 = tab_line_col()
check('Tab Width 12 reindents the tabbed line live', col4 is not None and col12 is not None and col12 > col4)
send(b'\x1bo'); pump(0.6); send(b't')
t0 = time.time()
while 'Tab width' not in scr.text() and time.time() - t0 < 4.0:
    pump(0.3)
send(b'\x194\r'); pump(1.2)
check('Tab Width restored to 4', tab_line_col() == col4)

# --- Options > Colors: modal opens and closes (dialog level) ---
send(b'\x1bo'); pump(0.6); send(b'c'); pump(1.0)
check('Colors dialog opens', 'Debugger Colors' in scr.text())
send(b'\x1b'); pump(1.0)
check('Colors dialog closes with ESC', 'Debugger Colors' not in scr.text())

# Alt+X back to the IDE
send(b'\x1bx'); pump(1.5)
check('Alt+X returns to the IDE', 'fn.prg' in scr.text() and 'Edit' in scr.text())

fails = 0
for name, ok in results:
    print(('PASS' if ok else 'FAIL'), name)
    if not ok: fails += 1
print('TOTAL', len(results)-fails, 'PASS', fails, 'FAIL')
shutil.rmtree(home, ignore_errors=True)
shutil.rmtree(rec, ignore_errors=True)
shutil.rmtree(work, ignore_errors=True)
sys.exit(1 if fails else 0)
