"""Actual Help Index/Contents and context return to an unchanged document."""
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
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  send(b'X')
  send(b'\x1bh');send(b'i');send(b'Find, Replace');send(b'\r',.6)
  check('Index opens requested topic','Find, Replace, Goto Line' in screen.text())
  # 80-column topic scrolls: End must expose literal-blank rule.
  send(b'\x1b[F',.4)
  check('updated search contract is readable','trailing blanks' in screen.text() or 'are kept.' in screen.text())
  send(b'\x1b',.4)
  check('Help close returns same document','help-source.prg' in screen.text() and 'Xprocedure main()' in screen.text())
  send(b'\x1bh');send(b'i');send(b'no-such-topic-zz');send(b'\r',.5)
  check('unknown keyword gives a clear message','No help topic matches:' in screen.text())
  send(b'\r',.4)
  check('unknown keyword returns to source','Xprocedure main()' in screen.text())
  send(b'\x1bh');send(b'c',.5)
  check('Contents opens navigation','Help' in screen.text() and 'Basics' in screen.text())
  send(b'\x1b',.4)
  send(b'\x1bf',.3);send(b'\x1bOP',.5)  # F1 with File menu open
  check('context help opens without executing File action','File menu' in screen.text())
  send(b'\x1b',.4)
  check('context help preserves current document','help-source.prg' in screen.text() and 'Xprocedure main()' in screen.text())
  send(b'\x1be');send(b'n',.3);send(b'\x1bOQ',.5)
  check('undo after Help and save preserves source bytes',target.read_text()=='procedure main()\nreturn\n')
  (work/'help.screen').write_text(screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
