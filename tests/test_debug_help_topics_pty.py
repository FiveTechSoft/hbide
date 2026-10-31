"""Debugger Help menu opens exact topics and body clicks do not select topics."""
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
  for letter,needle in [(b'a','Select help topic.'),(b'k','Special debugger keys'),(b'w','The Debugger display consists'),(b'm','The debugger menus contain'),(b'c','There are two sets')]:
   send(b'\x1bh');send(letter,.4)
   (work/('help-'+letter.decode()+'.screen')).write_text(screen.text())
   check('Help '+letter.decode()+' dialog opens exact body',' Help ' in screen.text() and needle in screen.text())
   send(b'\x1b')
  send(b'\x1bh');send(b'k',.4)
  check('Keys topic exact initial body','Special debugger keys' in screen.text())
  def mouse(code,row,col,wait=.15):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  mouse(0,10,50);mouse(3,10,50)
  check('body click does not change selected Keys topic','Special debugger keys' in screen.text())
  (work/'help-after-body-click.screen').write_text(screen.text())
  mouse(0,10,0);mouse(3,10,0)
  check('outside click leaves Keys selected','Special debugger keys' in screen.text())
  mouse(0,4,4);mouse(3,4,4)
  check('topic column click still selects next Function body','F1     Help' in screen.text())
  send(b'\x1b');send(b'\x1b[15~',.7)
  check('Help leaves exact debuggee values unchanged',value.exists() and value.read_text().replace(' ','')=='{'+','.join(map(str,[2]+list(range(2,13))))+'}')
  check('Help leaves source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
