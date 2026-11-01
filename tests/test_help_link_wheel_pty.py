"""Actual related-link help viewer wheel movement and clamps."""
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
  send(b'X');send(b'\x1bh');send(b'i');send(b'Doc: COMPLETION_ROADMAP\r',.5)
  def position():
   for cells in screen.g:
    line=''.join(cells)
    match=re.search(r'Esc close\s+(\d+)/(\d+)',line)
    if match:return tuple(map(int,match.groups()))
   raise AssertionError('No link viewer position')
  def wheel(code):send(b'\x1b[M'+bytes([code+32,40+33,10+33]),.2)
  top=position()
  check('Exact long manual opens link viewer at first line',top[0]==1 and top[1]>3 and 'Doc: COMPLETION_ROADMAP' in screen.text())
  wheel(65);check('Link viewer wheel down moves one line',position()==(2,top[1]))
  wheel(64);check('Link viewer wheel up restores first line',position()==top)
  wheel(64);check('Link viewer wheel up clamps at first line',position()==top)
  send(b'\x1b[F');bottom=position()
  check('Link viewer End reaches last readable top',bottom[0]==bottom[1] and bottom[1]>3)
  wheel(65);check('Link viewer wheel down clamps at end',position()==bottom)
  wheel(64);check('Link viewer wheel up from end moves one line',position()==(bottom[0]-1,bottom[1]))
  send(b'\x1b',.3)
  check('Link viewer returns same dirty source','Xalpha beta' in screen.text())
  send(b'\x1be');send(b'n');send(b'\x1bOQ')
  check('Undo after link viewer wheel restores exact bytes',target.read_bytes()==original)
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
