"""Run to Cursor and Point Breakpoint popup stop before exact mutations."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local n := 1\n   n += 10\n   n += 20\n   n += 30\n   n += 40\n   n += 50\n   hb_MemoWrit("'+str(value)+'",hb_ntos(n))\nreturn\n')
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
 def check(name,ok):
  results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
  if not ok:print(screen.text(),flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  send(b'\x1br');send(b'd',1)
  check('debugger stopped before increment','Command' in screen.text())
  send(b'monitor local on\r');send(b'goto 6\r')
  send(b'\x1br');send(b'c',.6)
  check('Run to Cursor stops before line6 mutation',bool(re.search(r'N <Local, N>:\s+61\s',screen.text())) and not value.exists())
  send(b'goto 8\r');send(b'\x1bp');send(b'b',.3)
  send(b'list bp\r');check('Point Breakpoint adds cursor line8',bool(re.search(r'0\)\s+8\s+__hbide_dbg__',screen.text())))
  send(b'goto 7\r');send(b'\x1br');send(b'c',.6)
  check('second to Cursor stops before line7 mutation',bool(re.search(r'N <Local, N>:\s+101\s',screen.text())) and not value.exists())
  send(b'\x1br');send(b'g',.6)
  check('Run Go stops at popup breakpoint before write',bool(re.search(r'N <Local, N>:\s+151\s',screen.text())) and not value.exists())
  send(b'goto 8\r');send(b'\x1bp');send(b'b',.3)
  send(b'list bp\r');check('second Point Breakpoint removes cursor line8',not re.search(r'0\)\s+8\s+__hbide_dbg__',screen.text()))
  send(b'goto 3\r');send(b'\x1bf');send(b'r',.3)
  check('File Resume does not execute debuggee',not value.exists() and 'Command' in screen.text())
  send(b'\x1bp');send(b'b',.3);send(b'list bp\r')
  check('File Resume restores viewing cursor to paused execution line8',bool(re.search(r'0\)\s+8\s+__hbide_dbg__',screen.text())))
  send(b'\x1bp');send(b'b',.3)
  send(b'\x1br');send(b'g',.7)
  check('Go after removing BP writes exact final result',value.exists() and value.read_text()=='151')
  check('Resume returns to IDE editor','Edit' in screen.text() and 'values.prg' in screen.text())
  check('cursor and breakpoint leave source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
