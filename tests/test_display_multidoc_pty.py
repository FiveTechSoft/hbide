"""Display resizing updates inactive documents before they become active."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['display']:
 first=work/'first.prg';second=work/'second.prg'
 for path in [first,second]:path.write_text('\n'.join(path.stem+' line '+str(n) for n in range(1,101)))

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
   for rr,cc in re.findall(rb'\x1b\[8;(\d+);(\d+)t',d):
    fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',int(rr),int(cc),0,0))
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5)
  for path in [first,second]:
   send(b'\x1bf');send(b'o');send(str(path).encode());send(b'\r',.6)
  send(b'X');send(b'\x1b[17;5~');send(b'Y');send(b'\x1b[17;5~')
  send(b'\x1bo');send(b'd');send(b'\x1b[B');send(b'\x1b[B');send(b'\t');send(b'\r',.8)
  check('Display applies 25x80',struct.unpack('HHHH',fcntl.ioctl(fd,termios.TIOCGWINSZ,b'\0'*8))[:2]==(25,80))
  send(b'\x1b[17;5~',.6)
  for _ in range(8):send(b'\x1b[6~',.1)
  check('inactive document cursor fits resized desktop',screen.r < 23 and screen.c < 79)
  check('inactive document last line visible','first line 100' in '\n'.join(''.join(r) for r in screen.g[2:23]))
  # Return to large grid while first is active; second must also resize.
  send(b'\x1bo');send(b'd');send(b'\x1b[A');send(b'\x1b[A');send(b'\t');send(b'\r',.8)
  check('Display restores 40x120',struct.unpack('HHHH',fcntl.ioctl(fd,termios.TIOCGWINSZ,b'\0'*8))[:2]==(40,120))
  send(b'\x1b[17;5~',.6)
  for _ in range(8):send(b'\x1b[6~',.1)
  check('other document uses expanded rows',screen.r > 22 and screen.r < 38)
  # Both documents retain their own edit history after the geometry changes.
  for path,marker in [(second,'X'),(first,'Y')]:
   send(b'\x1b[1;5H',.2);send(b'\x1be');send(b'n',.3)  # Undo via Edit menu
   send(b'\x1bOQ',.5)  # F2 save named document
   check(path.stem+' undo/save preserves original bytes',path.read_text()=='\n'.join(path.stem+' line '+str(n) for n in range(1,101)))
   send(b'\x1b[17;5~',.4)
  (work/'display.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
