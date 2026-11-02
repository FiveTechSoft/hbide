"""Script cwd changes must not retarget relative open documents after return."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['script']:
 target=work/(kind+'.prg');value=work/(kind+'.value')
 (work/'child').mkdir()
 original=b'procedure Main()\n'+(b' local x\n' if '--error' in sys.argv else b'')+b' hb_cwd( "child" )\n'+(b' x := nil + 1\n' if '--error' in sys.argv else b'')+b'return\n'
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
  pump(1.5);send(b'\x1bf');send(b'o');send(b'script.prg\r',.6)
  (work/'opened.screen').write_text(screen.text())
  check('Relative fixture opened','script.prg' in screen.text() and 'hb_cwd' in screen.text())
  send(b'\x1br');send(b'c',.6)
  if '--error' in sys.argv:
   check('Runtime error visible','Argument error' in screen.text())
   send(b'\r',.4)
  check('Script returns usable editor','Edit' in screen.text())
  pump(1.2)
  check('No false disk deletion after Script','File deleted on disk' not in screen.text())
  if 'File deleted on disk' in screen.text():send(b'\r',.3)
  send(b'X');send(b'\x1bOQ',.6)
  check('Original source not actually deleted',target.exists())
  check('No false recreate prompt','File was deleted on disk' not in screen.text())
  if 'File was deleted on disk' in screen.text():send(b'\r',.6)
  (work/'after-save.screen').write_text(screen.text())
  check('Original relative source saved in its original directory',target.read_bytes()==b'X'+original)
  check('No wrong directory save created',not (work/'child/script.prg').exists())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
