"""Empty quoted arguments retain their position in Start, Script and Debug."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['start','script','debug']:
 target=work/(kind+'.prg');value=work/(kind+'.value')
 target.write_text('procedure main( ... )\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp( hb_AParams() ) )\nreturn\n')
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
  send(b'\x1br');send(b'a');send(b'"" first "" "two words" last ""');send(b'\r',.5)
  for run in range(1):
   value.unlink(missing_ok=True)
   send(b'\x1br');send({'script':b'c','debug':b'd','start':b's'}[kind],1)
   if kind=='start':
    until=time.monotonic()+15
    while not value.exists() and time.monotonic()<until:send(b'\r',.5)
   if kind=='debug':
    check('debug source retains main declaration','procedure main( ... )' in screen.text())
    send(b'\x1b[15~',1)
   check(kind+' run'+str(run+1)+' retains empty argument positions',value.exists() and value.read_text()=='{"", "first", "", "two words", "last", ""}')
   if not value.exists():(work/(kind+str(run)+'.screen')).write_text(screen.text())
  check(kind+' editor remains usable','Edit' in screen.text())
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
