"""Explicit Open restores the current hidden window, keyboard ownership and watch."""
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
  click(0,2)
  check('Top-row File click opens menu','Save As' in screen.text())
  click(10,100)
  check('Outside click dismisses open File menu','Save As' not in screen.text() and 'alpha beta' in screen.text())
  click(*locate('beta'));send(b'X')
  saved('Visible-editor parent click routes insertion to exact byte',original.replace(b'beta',b'Xbeta',1))
  send(b'\x1be');send(b'n');saved('Undo parent-routed insertion exact',original)
  click(1,2)
  check('Code close-glyph click hides editor','alpha beta' not in screen.text())
  click(5,20);send(b'IGNORED')
  check('Click and typing while editor hidden do not reveal source','alpha beta' not in screen.text())
  click(0,2)
  check('File menu remains usable with editor hidden','Save As' in screen.text())
  send(b'o');send(str(target).encode()+b'\r',.6)
  check('Explicit reopen restores title and frame',str(target.name) in ''.join(screen.g[1]) and screen.g[1][0]!=' ' and screen.g[38][0]!=' ')
  send(b'Y');saved('Reopened editor owns keyboard and saves exact bytes',b'Y'+original)
  changed=b'EXTERNAL_WATCH_AFTER_REOPEN\n'
  target.write_bytes(changed);pump(3)
  check('Reopened editor keeps disk watch active','EXTERNAL_WATCH_AFTER_REOPEN' in screen.text())
  check('Watch never writes external change',target.read_bytes()==changed)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
