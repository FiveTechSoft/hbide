"""Monitor mouse maps visible rows to actual locals after vertical scroll."""
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
  send(b'monitor local on\r',.4)
  send(b'window select monitor\r',.3)
  send(b'\x1b[6~',.3)
  (work/'monitor-scrolled.screen').write_text(screen.text())
  labels=re.findall(r'V(\d+) <Local',screen.text())
  check('Monitor PageDown exposes later locals',bool(labels) and max(map(int,labels))>7)
  n=int(labels[-2]);label='V%02d <Local'%n
  double(*locate(label));send(b'\x1b[H'+b'\x1b[3~'*2+b'99\r',.4)
  check('doubleclick scrolled Monitor edits exact visible local',bool(re.search(r'V%02d <Local, N>:\s+99\s'%n,screen.text())))
  send(b'\x1b[5~',.3) # PageUp back to first locals
  check('PageUp returns first Monitor locals','V01 <Local' in screen.text())
  click(*locate('V02 <Local'));send(b'\r',.3);send(b'\x1b[H\x1b[3~77\r',.4)
  check('click after PageUp edits correct second local',bool(re.search(r'V02 <Local, N>:\s+77\s',screen.text())))
  send(b'window select command\r',.3);send(b'\x1b[15~',.7)
  expected=list(range(1,13));expected[0]=2;expected[1]=77;expected[n-1]=99
  check('scrolled Monitor edit reaches exact debuggee slot',value.exists() and value.read_text().replace(' ','')=='{'+','.join(map(str,expected))+'}')
  check('scrolled Monitor leaves source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
