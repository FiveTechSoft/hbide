"""Debugger scalar variable edit/Cancel and readonly inspect effects."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local n := 1\n   n := n + 1\n   hb_MemoWrit( "'+str(value)+'", hb_ntos( n ) )\nreturn\n')
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
   if b'\x1b[6n' in d:os.write(fd,b'\x1b[25;1R')
   if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;25;80t')
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  send(b'\x1b[B\x1b[B');send(b'\x1b[20~',.4)
  send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
  check('debugger stopped before increment','Command' in screen.text())
  send(b'?? n\r',.4)
  (work/'readonly-open.screen').write_text(screen.text())
  check('readonly scalar inspector opens',bool(re.search(r'q n q',screen.text())) and bool(re.search(r'x\s+1\s+x',screen.text())))
  send(b'9',.3)
  check('readonly inspector refuses typed edit','Value cannot be edited' in screen.text())
  send(b'\r',.3);send(b'\x1b',.4)
  send(b'monitor local on\r',.5)
  send(b'window select monitor\r',.4)
  (work/'monitor.screen').write_text(screen.text())
  send(b'\r',.4)
  (work/'edit-open.screen').write_text(screen.text())
  send(b'41\r',.4)
  check('edited Monitor scalar shows41',bool(re.search(r'N <Local, N>:\s+41',screen.text())))
  send(b'\r',.4);send(b'99\x1b',.4)
  check('typed Esc keeps accepted41',bool(re.search(r'N <Local, N>:\s+41',screen.text())))
  send(b'\r',.4);send(b'not_a_valid_expr(\r',.4)
  check('invalid expression shows error','Expression error' in screen.text())
  send(b'\r',.3);send(b'\x1b',.4)
  check('invalid then Esc keeps41',bool(re.search(r'N <Local, N>:\s+41',screen.text())))
  send(b'window select command\r',.3)
  send(b'?? n\r',.4);send(b'7',.3)
  check('readonly after edit refuses mutation','Value cannot be edited' in screen.text())
  send(b'\r',.3);send(b'\x1b',.4)
  send(b'? n\r',.4)
  (work/'after-edit.screen').write_text(screen.text())
  send(b'\x1b[15~',.7)
  check('edited value executes in debuggee',value.exists() and value.read_text()=='42')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
