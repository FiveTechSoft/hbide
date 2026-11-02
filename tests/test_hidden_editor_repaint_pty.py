"""Modal cancellation repaint respects hidden editor state, not navigation policy."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['about','open-cancel','goto-cancel','window-cancel']:
 target=work/'help-source.prg'
 target.write_text('procedure main()\nreturn\n')

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
 def check(name,ok):
  results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
  if not ok:(work/(str(len(results))+'.screen')).write_text(screen.text())
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  def route():
   if kind=='about':send(b'\x1bh');send(b'b',.3);send(b'\r',.3)
   elif kind=='open-cancel':send(b'\x1bf');send(b'o',.3);send(b'\x1b',.3)
   elif kind=='goto-cancel':send(b'\x1be');send(b'g',.3);send(b'\x1b',.3)
   else:send(b'\x1bw');send(b'l',.3);send(b'\x1b',.3)
  route();check(kind+' preserves visible source','procedure main()' in screen.text())
  send(b'\x1b[M'+bytes([32,35,34]),.1);send(b'\x1b[M'+bytes([35,35,34]),.2)
  check(kind+' source hides','procedure main()' not in screen.text())
  route();(work/(kind+'-hidden.screen')).write_text(screen.text())
  check(kind+' preserves hidden source','procedure main()' not in screen.text())
  send(b'IGNORED');send(b'\x1bf');send(b'n',.4)
  check(kind+' FileNew explicitly reveals new editor','Hello world from Harbour' in screen.text())
  check(kind+' hidden typing preserved bytes',target.read_text()=='procedure main()\nreturn\n')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
