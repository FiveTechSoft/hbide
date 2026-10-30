"""Close Project, Close Window and About route without losing unrelated work."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['help']:
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
  send(b'X')
  send(b'\x1bh');send(b'b',.5)
  check('About opens actual dialog','HbIde 1.0' in screen.text() and 'Harbour IDE' in screen.text())
  send(b'\r',.4)
  check('About returns edited document','Xprocedure main()' in screen.text())
  send(b'\x1bw');send(b'c',.5)
  check('Window Close asks about active dirty source','Unsaved changes' in screen.text())
  send(b'c',.4)
  check('Window Close Cancel retains dirty text','Xprocedure main()' in screen.text())
  send(b'\x1bw');send(b'c',.4);send(b'd',.5)
  check('Window Close Discard replaces last document with starter','noname.prg' in screen.text() and 'Hello world from Harbour' in screen.text())
  check('Discard never writes edited source',target.read_text()=='procedure main()\nreturn\n')
  project=work/'close.hbp';project.write_text('help-source.prg\n')
  send(b'\x1bp');send(b'o');send(str(project).encode());send(b'\r',.6)
  check('Project opens Sources','SOURCES' in screen.text() and 'close.hbp' in screen.text())
  send(b'\r',.5)  # open source
  send(b'Y')
  send(b'\x1bp');send(b'c',.4)
  check('Close Project keeps edited source open','Yprocedure main()' in screen.text())
  send(b'\x1bp');send(b's',.4)
  check('Sources after Close Project gives no-project notice','Open a .hbp' in screen.text() and 'first' in screen.text())
  send(b'\r',.3)
  check('no-project notice returns dirty document','Yprocedure main()' in screen.text())
  check('Close Project never writes source or HBP',target.read_text()=='procedure main()\nreturn\n' and project.read_text()=='help-source.prg\n')
  (work/'close.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
