"""List-selected names beyond GET width reject explicitly, typed paths remain authoritative."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/('p'*251+'.prg');project=work/('q'*251+'.hbp');short=work/'ok.prg'
 original=b'LONG precious\r\nreturn\n';target.write_bytes(original);project.write_text('ok.prg\n');short.write_bytes(b'SHORT exact\n')
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
  pump(1.5)
  def filemenu(key):send(b'\x1bf');send(key)
  def projectopen():send(b'\x1bp');send(b'o')
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def clicklabel(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:
     mouse(0,row,col);mouse(3,row,col,.3);return
   (work/'missing.screen').write_text(screen.text());raise AssertionError(label)
  filemenu(b'o');clicklabel('p'*20)
  (work/'open-long.screen').write_text(screen.text())
  clicklabel('OK')
  check('Open long list name rejected not truncated','Path too long (255 chars, max 250)' in screen.text())
  send(b'\r')
  filemenu(b'o');send(str(short).encode());send(b'\t');clicklabel('OK')
  check('typed short path wins despite long initial item','SHORT exact' in screen.text() and 'ok.prg' in screen.text())
  projectopen();send(b'\t\x1b[H');clicklabel('OK')
  check('Project long initial name rejected not truncated','Path too long (255 chars, max 250)' in screen.text())
  send(b'\r')
  check('long name rejection retains correct current document','SHORT exact' in screen.text() and 'ok.prg' in screen.text())
  check('long names never alter any source or project',target.read_bytes()==original and project.read_text()=='ok.prg\n' and short.read_bytes()==b'SHORT exact\n')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
