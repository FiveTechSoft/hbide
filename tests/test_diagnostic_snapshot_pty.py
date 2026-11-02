"""Real IDE Edit-menu dispatch. Linux PTY, not visual certification."""
import shlex, shutil, sys
import os, pty, struct, fcntl, termios, select, time, signal, tempfile, pathlib, re
ROWS, COLS = 40, 120
BIN = os.environ.get('HBIDE_BIN', str(pathlib.Path(__file__).resolve().parents[1] / 'hbide'))
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


work = pathlib.Path(tempfile.mkdtemp(prefix='hbide-edit-menu-'))
(work/'home').mkdir(); (work/'rec').mkdir()
(work/'tools').mkdir();(work/'folder:12:part').mkdir()
target = work/'folder:12:part/bad.c'
original = b'int main(void) {\n return unknown_name;\n}\n'
target.write_bytes(original)
project=work/'test.hbp';project.write_text('"folder:12:part/bad.c"\n')
gcc=shutil.which('gcc');assert gcc
receipt=work/'consumed.json';compiler=work/'tools/hbmk2'
compiler.write_text('#!/usr/bin/python3\nimport json,pathlib,subprocess\np=pathlib.Path('+repr(str(target))+')\nb=p.read_bytes()\npathlib.Path('+repr(str(receipt))+').write_text(json.dumps({"path":str(p),"hex":b.hex()}))\nraise SystemExit(subprocess.run(['+repr(gcc)+',"-fsyntax-only",str(p)]).returncode)\n')
compiler.chmod(0o700)
project_mode='--project' in sys.argv
env = dict(os.environ, HOME=str(work/'home'), HBIDE_RECOVERY_DIR=str(work/'rec'), TERM='xterm',PATH=str(work/'tools')+':'+os.environ['PATH'])
pid, fd = pty.fork()
if pid == 0:
    os.execve(BIN, [BIN], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))
scr = Scr(); results = []
def pump(seconds=.4):
    end = time.time()+seconds; buf = b''
    while time.time()<end:
        ready,_,_=select.select([fd],[],[],.05)
        if not ready: continue
        try: data=os.read(fd,65536)
        except OSError: break
        if not data: break
        buf+=data
        for query, answer in [(b'\x1b[6n', b'\x1b[40;1R'), (b'\x1b[18t', b'\x1b[8;40;120t')]:
            while query in buf:
                buf=buf.replace(query,b'',1); os.write(fd,answer)
    scr.feed(buf)
def send(data, pause=.35):
    os.write(fd,data); pump(pause)
def menu(letter):
    send(b'\x1be'); send(letter)
def check(name, ok):
    results.append((name,bool(ok)))
    if not ok: (work/('failure-%02d.txt'%len(results))).write_text(name+'\n'+scr.text())
def saved(name, expected):
    send(b'\x1bOQ', .7)
    check(name, target.read_bytes()==expected)
def jump():send(b'\x1b[19;3~',.4)
def state(label,want):
    check(label,'['+want+']' in scr.text())
    (work/(label+'.screen')).write_text(scr.text())
def build():
    if project_mode:
        send(b'\x1bp');send(b's',.5);send(b'\x1b[20~',1)
        send(b'\r',.5)
    else:
        send(b'\x1br');send(b's',1);send(b'\r',.3);send(b'\r',.5)
try:
    pump(2)
    if project_mode:
        send(b'\x1bp');send(b'o');send(str(project).encode()+b'\r',.6)
        send(b'\x1b[20~',1);send(b'\r',.5)
    else:
        send(b'\x1bf');send(b'o');send(str(target).encode()+b'\r',.6);build()
    import json
    d=json.loads(receipt.read_text())
    check('Controlled reader consumed exact source identity bytes',d['path']==str(target) and bytes.fromhex(d['hex'])==original)
    state('Initial source snapshot match','snapshot=')
    check('Initial diagnostic row2col9',bool(re.search(r'row:\s*2,\s*col:\s*9',scr.text())))
    send(b'\x1b[1;5H');send(b'\r',.3);jump()
    state('Unsaved changed source labelled','changed')
    check('Original jump coordinates preserved',bool(re.search(r'row:\s*2,\s*col:\s*9',scr.text())) and '3 return unknown_name;' in scr.text())
    menu(b'n');jump();state('Undo original bytes match','snapshot=')
    other=work/'other.prg';other.write_bytes(b'other')
    send(b'\x1bf');send(b'o');send(str(other).encode()+b'\r',.4);send(b'X');send(b'\x1bOQ',.4);jump()
    state('Other document edit leaves match','snapshot=')
    send(b'\x1b[1;5H');send(b'\r',.3);saved('Save changed bytes exact',b'\n'+original);jump()
    state('Save without rebuild remains changed','changed')
    build();state('Rebuild replaces version with match','snapshot=')
    check('Rebuild moved diagnostic row3',bool(re.search(r'row:\s*3,\s*col:\s*9',scr.text())))
    d=json.loads(receipt.read_text());check('Rebuild consumed updated bytes',bytes.fromhex(d['hex'])==b'\n'+original)
    send(b'\x1bw');send(b'm',.4)
    check('Message list cache timing legend','cached open' in scr.text() and 'not validity' in scr.text() and 'Enter rechecks' in scr.text())
    send(b'\x1b',.3)
    compiler.rename(work/'disabled-compiler')
    if project_mode:
        send(b'\x1bp');send(b's',.5);send(b'\x1b[20~',.8)
        check('Absent project compiler clears diagnostic ledger','0 diagnostics' in scr.text())
        send(b'\x1b',.3)
    else:
        send(b'\x1br');send(b's',.8);send(b'\r',.4)
    send(b'\x1bw');send(b'm',.4)
    check('Absent compiler never inherits old messages','No compiler messages' in scr.text())
finally:
    os.kill(pid,signal.SIGKILL);os.waitpid(pid,0);os.close(fd)
for name,ok in results: print('PASS' if ok else 'FAIL',name)
print('TOTAL',sum(ok for _,ok in results),'PASS',sum(not ok for _,ok in results),'FAIL')
print('Artifacts',work)
raise SystemExit(int(not all(ok for _,ok in results)))
