"""Real debugger window menu Move/Size cancel and Zoom/Tile transitions."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local '+', '.join('v%02d := %d'%(n,n) for n in range(1,13))+'\n   v01++\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp( { '+', '.join('v%02d'%n for n in range(1,13))+' } ) )\nreturn\n')
 original=target.read_bytes()
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
  send(b'\x1b[B\x1b[B');send(b'\x1b[20~',.4)
  send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
  check('debugger stopped before increment','Command' in screen.text())
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def click(row,col):mouse(0,row,col);mouse(3,row,col,.2)
  def double(row,col):
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.2)
  def locate(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  send(b'monitor local on\r',.3)
  send(b'window select code\r',.3)
  send(b'window size 10 60\r',.3)
  send(b'window move 3 4\r',.3)
  def position():
   for row,line in enumerate(screen.g):
    col=''.join(line).find('__hbide_dbg__')
    if col>=0:return row,col
  def popup(letter):send(b'\x1bw');send(letter)
  initial=position();check('code caption begins inside requested rect',initial is not None and initial[0]==3)
  popup(b'm');check('Move menu opens arrow edit','Move: arrows' in screen.text())
  send(b'\x1b[B\x1b[C');moved=position()
  check('Move arrows change caption row and col',moved==(initial[0]+1,initial[1]+1))
  send(b'\x1b');check('Move Esc restores caption position',position()==initial)
  popup(b'm');send(b'\x1b[B\x1b[C');send(b'\r')
  check('Move Enter keeps changed position',position()==moved)
  before=screen.text()
  popup(b's');check('Size menu opens arrow edit','Size: arrows' in screen.text())
  send(b'\x1b[B\x1b[C');send(b'\x1b')
  check('Size Esc restores complete painted character grid',screen.text()==before)
  popup(b's');send(b'\x1b[B\x1b[C');send(b'\r')
  resized=screen.text();check('Size Enter changes painted grid',resized!=before)
  popup(b'z');check('Zoom moves code caption to desktop top',position() is not None and position()[0]==1)
  popup(b'z');check('second Zoom restores resized grid',screen.text()==resized)
  popup(b'i');check('Iconize hides selected source text','hb_MemoWrit' not in screen.text())
  popup(b't');check('Tile restores iconized source browser','hb_MemoWrit' in screen.text())
  (work/'tile.screen').write_text(screen.text())
  send(b'window select command\r',.3);send(b'window select code\r',.3)
  check('Tile retains source caption after focus cycle',position() is not None)
  send(b'\x1b[15~',.7)
  check('layout changes preserve exact debuggee values',value.exists() and value.read_text().replace(' ','')=='{'+','.join(map(str,[2]+list(range(2,13))))+'}')
  check('layout changes leave source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
