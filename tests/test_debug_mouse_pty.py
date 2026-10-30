"""Debugger scalar variable edit/Cancel and readonly inspect effects."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local a := 11, b := 22, c := 33\n   a++\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp( { a, b, c } ) )\nreturn\n')
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
  send(b'monitor local on\r',.4)
  check('three locals visible',all(x in screen.text() for x in ['A <Local','B <Local','C <Local']))
  click(*locate('B <Local'))
  send(b'\r',.3);send(b'\x1b[H\x1b[3~\x1b[3~42\r',.4)
  check('single click selects exact local for Enter edit',bool(re.search(r'B <Local, N>:\s+42\s',screen.text())) and bool(re.search(r'A <Local, N>:\s+11\s',screen.text())))
  double(*locate('C <Local'));(work/'double-edit.screen').write_text(screen.text());send(b'\x1b[H\x1b[3~\x1b[3~53\r',.4)
  check('doubleclick edits clicked C not prior B',bool(re.search(r'C <Local, N>:\s+53\s',screen.text())) and bool(re.search(r'B <Local, N>:\s+42\s',screen.text())))
  double(*locate('A <Local'));send(b'99\x1b',.4)
  check('doubleclick typed Cancel preserves A',bool(re.search(r'A <Local, N>:\s+11\s',screen.text())))
  send(b'window select command\r',.3)
  send(b'\x1b[15~',.7)
  check('mouse values execute exact debuggee state',value.exists() and value.read_text().replace(' ','')=='{12,42,53}')
  check('mouse debugger never modifies source bytes',target.read_bytes()==original)
  (work/'debug-mouse-final.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
