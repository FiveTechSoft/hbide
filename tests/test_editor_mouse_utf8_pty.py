"""UTF8 host actual editor mouse byte effects with BOM TAB and accents."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'mouse.prg'
 original=b'\xef\xbb\xbf'+('\tcafé beta\r\nnaïve año\nend\n').encode()
 target.write_bytes(original)
 pid,fd=pty.fork()
 if pid==0:
  os.chdir(work);os.execve(exe,[exe],dict(os.environ,TERM='xterm',HOME=str(work/'home'),HBIDE_RECOVERY_DIR=str(work/'rec'),HBIDE_UTF8='1'))
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
   (work/'missing-label.screen').write_text(screen.text())
   raise AssertionError('No painted label '+label)
  def saved(label,expected):
   send(b'\x1bOQ',.4);check(label,target.read_bytes()==expected)
   if target.read_bytes()!=expected:print('actual bytes',repr(target.read_bytes()[:50]),flush=True)
  def double(label):
   row,col=locate(label)
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.2)
  check('current UTF8 display fallback observed separately from bytes','caf?' in screen.text() and 'na?ve' in screen.text())
  double('caf?');send(b'Z')
  saved('UTF8 doubleclick replaces whole accented word after TAB',original.replace('café'.encode(),b'Z',1))
  send(b'\x1be');send(b'n');saved('Undo UTF8 word exact BOM TAB mixed EOL',original)
  row,col=locate('beta');click(row,col);send(b'X')
  saved('UTF8 click after accented word maps exact byte',original.replace(b'beta',b'Xbeta',1))
  send(b'\x1be');send(b'n');saved('Undo UTF8 byte insertion exact',original)
  double('na?ve');send(b'\x1b[3~')
  saved('UTF8 doubleclick Delete exact accented word',original.replace('naïve'.encode(),b'',1))
  send(b'\x1be');send(b'n');saved('Undo UTF8 Delete exact',original)
  double('a?o');send(b'Q')
  saved('UTF8 doubleclick final accented word exact',original.replace('año'.encode(),b'Q',1))
  send(b'\x1be');send(b'n');saved('Undo UTF8 final word exact',original)
  (work/'utf8-mouse-final.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
