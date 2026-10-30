"""Actual editor Xterm clicks, doubleclick word and wheel byte effects."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'mouse.prg'
 original=b'alpha beta\r\n\tTABword tail\n'+b''.join(('line%02d text\n'%i).encode() for i in range(3,65))
 original=original.replace(b'line03 text',b'line03 '+b'a'*150+b' ENDMARK tail')
 target.write_bytes(original)
 pid,fd=pty.fork()
 if pid==0:
  os.chdir(work);os.execve(exe,[exe],dict(os.environ,TERM='xterm',HOME=str(work/'home'),HBIDE_RECOVERY_DIR=str(work/'rec')))
 fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
 def pump(secs):
  until=time.monotonic()+secs;b=b''
  while time.monotonic()<until:
   r,_,_=select.select([fd],[],[],.05)
   if not r:continue
   try:d=os.read(fd,65536)
   except OSError:break
   b+=d
   if b'\x1b[6n' in d:os.write(fd,b'\x1b[40;1R')
   if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;40;120t')
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def click(row,col):mouse(0,row,col);mouse(3,row,col,.2)
  def locate(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  def saved(label,expected):
   send(b'\x1bOQ',.4);check(label,target.read_bytes()==expected)
   if target.read_bytes()!=expected:print('actual bytes',repr(target.read_bytes()[:50]),flush=True)
  row,col=locate('beta');click(row,col);send(b'X')
  saved('click places cursor at exact beta byte',original.replace(b'beta',b'Xbeta',1))
  send(b'\x1be');send(b'n');saved('Undo click insertion exact',original)
  row,col=locate('TABword');click(row,col);send(b'Y')
  saved('click expanded TAB maps to correct source byte',original.replace(b'TABword',b'YTABword',1))
  send(b'\x1be');send(b'n');saved('Undo TAB click exact',original)
  def double(label):
   row,col=locate(label)
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.2)
  double('beta')
  send(b'Z');(work/'double.screen').write_text(screen.text());saved('doubleclick selects whole word not line',original.replace(b'beta',b'Z',1))
  send(b'\x1be');send(b'n');saved('Undo doubleclick replacement exact',original)
  double('beta');send(b'\x1b[3~')
  saved('doubleclick Delete removes exact word',original.replace(b'beta',b'',1))
  send(b'\x1be');send(b'n');saved('Undo word Delete exact',original)
  double('TABword');send(b'Q')
  saved('doubleclick expanded TAB selects correct word',original.replace(b'TABword',b'Q',1))
  send(b'\x1be');send(b'n');saved('Undo TAB word replacement exact',original)
  double('beta');send(b'\x1be');send(b'c') # Copy
  send(b'\x1b[F');send(b'\x1be');send(b'p') # End, Paste
  saved('doubleclick Copy uses word not whole line',original.replace(b'beta\r\n',b'beta\r\nbeta\r\n',1))
  send(b'\x1be');send(b'n');saved('Undo copied word paste exact',original)
  double('beta');send(b'\x1be');send(b't') # Cut
  saved('doubleclick Cut removes word only',original.replace(b'beta',b'',1))
  send(b'\x1be');send(b'n');saved('Undo cut word exact',original)
  click(*locate('beta'))
  for _ in range(4):mouse(65,row,col,.1) # xterm wheel down
  check('wheel down moves four source rows',bool(re.search(r'row:\s*5\s*,',screen.text())))
  for _ in range(4):mouse(64,row,col,.1)
  check('wheel up returns to first row',bool(re.search(r'row:\s*1\s*,',screen.text())))
  for _ in range(5):mouse(64,row,col,.1)
  check('wheel top clamps first row',bool(re.search(r'row:\s*1\s*,',screen.text())))
  saved('wheel navigation never changes source bytes',original)
  send(b'\x1b[6~') # PageDown, then map a visible scrolled source row
  labels=re.findall(r'line(\d+) text',screen.text())
  check('PageDown exposes later source rows',bool(labels) and int(labels[0])>3)
  label='line'+labels[0]+' text';click(*locate(label));send(b'V')
  saved('click scrolled row maps exact source byte',original.replace(label.encode(),b'V'+label.encode(),1))
  send(b'\x1be');send(b'n');saved('Undo scrolled row click exact',original)
  send(b'\x1b[1;5H');send(b'\x1b[B');send(b'\x1b[B');send(b'\x1b[F')
  row,col=locate('ENDMARK');click(row,col);send(b'H')
  saved('click horizontally scrolled row exact byte',original.replace(b'ENDMARK',b'HENDMARK',1))
  send(b'\x1be');send(b'n');saved('Undo horizontal click exact',original)
  send(b'\x1b[F');double('ENDMARK');send(b'J')
  saved('doubleclick horizontally scrolled word exact',original.replace(b'ENDMARK',b'J',1))
  send(b'\x1be');send(b'n');saved('Undo horizontal word exact',original)
  send(b'\x1b[1;5H')
  row,col=locate('beta');click(row,col-1);send(b'S')
  saved('whitespace click inserts at precise space',original.replace(b'alpha beta',b'alphaS beta',1))
  send(b'\x1be');send(b'n');saved('Undo whitespace click exact',original)
  row,col=locate('alpha');click(row,col+20);send(b'P')
  saved('click beyond EOL preserves exact padding',original.replace(b'alpha beta',b'alpha beta'+b' '*10+b'P',1))
  send(b'\x1be');send(b'n');saved('Undo beyond EOL exact',original)
  send(b'\x1b[1;5F')
  for _ in range(5):mouse(65,10,10,.1)
  check('wheel bottom clamps final empty row',bool(re.search(r'row:\s*65\s*,',screen.text())))
  saved('bottom wheel preserves every byte',original)
  (work/'mouse-final.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
