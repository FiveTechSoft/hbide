"""AutoRun explicit OK/Cancel gates launch after a real successful build."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'autorun.prg';value=work/'launched.txt'
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
  # Literal arguments prove the launched artifact is this program, not a stale one.
  send(b'\x1br');send(b'a');send(b'first "two words" ""');send(b'\r',.5)
  def set_autorun(end):
   send(b'\x1bo');send(b'c',.5)
   for _ in range(6):send(b'\t')
   send(b' ')
   for _ in range(1 if end=='ok' else 2):send(b'\t')
   send(b'\r',.5)
  def build(label,launch):
   value.unlink(missing_ok=True)
   (work/'autorun').unlink(missing_ok=True)
   send(b'\x1br');send(b's',.5)
   until=time.monotonic()+20
   while not ('Done.' in screen.text() or 'Build OK:' in screen.text()) and time.monotonic()<until:pump(.2)
   (work/(label+'-built.screen')).write_text(screen.text())
   check(label+' actual compiler output','Done.' in screen.text() or 'Build OK:' in screen.text())
   send(b'\r',.8)
   if not launch:
    check(label+' auto-run off message','Built (auto-run off):' in screen.text())
    send(b'\r',.4)
   check(label+' launch matches committed choice',value.exists()==launch)
   if launch:check(label+' launched artifact exact args',value.read_text()=='{"first", "two words", ""}' if value.exists() else False)
   check(label+' fresh executable promoted',(work/'autorun').is_file())
   check(label+' editor restored','Edit' in screen.text())
  build('default-on',True)
  set_autorun('ok')
  build('accepted-off',False)
  set_autorun('cancel')
  build('cancelled-on-remains-off',False)
  set_autorun('ok')
  build('accepted-on',True)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
