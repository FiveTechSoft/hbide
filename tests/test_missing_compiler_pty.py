"""Missing compiler never launches or replaces an existing executable. Linux PTY."""
import subprocess,hashlib
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'missing.prg';value=work/'stale-launched.txt'
 target.write_text('procedure main()\n hb_MemoWrit("'+str(value)+'", "stale")\nreturn\n')
 compiler=__import__('shutil').which('hbmk2')
 subprocess.run([compiler,str(target),'-quiet','-o'+str(work/'missing')],check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 previous=(work/'missing').read_bytes();original=target.read_bytes()
 (work/'empty-path').mkdir()
 pid,fd=pty.fork()
 if pid==0:
  os.chdir(work);os.execve(exe,[exe],dict(os.environ,TERM='xterm',HOME=str(work/'home'),HBIDE_RECOVERY_DIR=str(work/'rec'),PATH=str(work/'empty-path')))
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
  for attempt in range(2):
   send(b'\x1br');send(b's',.7)
   (work/('failure-'+str(attempt)+'.screen')).write_text(screen.text())
   check('missing compiler gives clear failed build message','hbmk2 not on PATH' in screen.text() and 'previous' in screen.text() and 'executable left untouched' in screen.text())
   send(b'\r',.4)
   check('previous executable byte exact',(work/'missing').read_bytes()==previous)
   check('stale executable never launched',not value.exists())
   check('source byte exact',target.read_bytes()==original)
   check('no sibling build temp remains',not [p for p in work.iterdir() if p.name.startswith('missing.') and p!=target])
  check('editor remains usable after repeated failure','Edit' in screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
