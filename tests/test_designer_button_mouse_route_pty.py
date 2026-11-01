"""Generated button synchronous mouse arm/release/doubleclick runtime."""
import argparse
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
parser=argparse.ArgumentParser()
parser.add_argument('--mixed',action='store_true')
args=parser.parse_args()
caption='He said "yes"' if not args.mixed else 'Say "yes" and '+"'no' ] "+chr(92)
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['button']:
 modelpath=work/'fixture.json'
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
 def send(b,wait=.15):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  control={'type':'button','row':1,'col':2,'caption':caption,'accelerator':'Q','action':'OldAction()','focus':'OldFocus()','style':'brackets'}
  modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':60,'height':20,'controls':[control]}))
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  send(b'\x1bOS');send(b'\x1b[17~')
  edited={'action':'MarkState()', 'focus':'MarkFocus()'}
  for offset,key in [(4,'action'),(8,'focus')]:
   for _ in range(12):send(b'\x1b[A',.02)
   for _ in range(offset):send(b'\x1b[B',.03)
   send(b'\r');send(b'\x19'+edited[key].encode());send(b'\r');send(b'\x1b[21~',.3)
   check('edited '+key+' persisted exact',json.loads(modelpath.read_text())['controls'][0][key]==edited[key])
  send(b'\x1b[20~',.4)
  generated=(work/'fixture.prg').read_text()
  check('actual F9 emits edited action and focus',all(v in generated for v in edited.values()))

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
# Compile the actual F9 artifact, instrumenting only the return to record bound values.
import subprocess
resultpath=work/'runtime-values.txt';marker=work/'handler-calls.txt'
source=work/'runtime.prg'
focus=work/'focus-calls.txt'
source.write_text(generated+'\nprocedure Main()\n   hb_MemoWrit("'+str(resultpath)+'", hb_ValToExp(Dlg_Fixture()))\nreturn\nfunction MarkState()\n   hb_MemoWrit("'+str(marker)+'", hb_MemoRead("'+str(marker)+'") + "x")\nreturn .T.\nfunction MarkFocus()\n   hb_MemoWrit("'+str(focus)+'", "focus")\nreturn .T.\n')
runtime=work/'runtime'
build=subprocess.run(['hbmk2',str(source),*[str(ROOT/x) for x in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']],'-gttrm','-quiet','-o'+str(runtime)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(work/'runtime-build.log').write_bytes(build.stdout)
check('generated inline-edited-button artifact compiles',build.returncode==0)
if build.returncode==0:
 for scenario in ['mouse']:
  for path in [resultpath,marker,focus]:path.unlink(missing_ok=True)
  pid,fd=pty.fork()
  if pid==0:os.execve(str(runtime),[str(runtime)],dict(os.environ,TERM='xterm',DSN_NOROUTE='0'))
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
  try:
   pump(.8)
   row,col=next((r,''.join(cells).index(caption)) for r,cells in enumerate(screen.g) if caption in ''.join(cells))
   def mouse(code,r,c,wait=.2):send(b'\x1b[M'+bytes([code+32,c+33,r+33]),wait)
   def calls():return marker.read_text() if marker.exists() else ''
   mouse(0,row,col)
   check('Press arms button without activating',calls()=='')
   mouse(3,row,col)
   check('Release on same armed button activates once',calls()=='x')
   mouse(0,row,col);mouse(3,0,0)
   check('Release outside after button press does not activate',calls()=='x')
   mouse(0,0,0);mouse(3,row,col)
   check('Press outside release inside does not activate',calls()=='x')
   # Explicit DOWN/UP/DBL/UP event sequence tests paired-up suppression.
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.01);pump(.8)
   check('Double click sequence adds only one activation',calls()=='xx')
   send(b'\x1b',.4)
   check('Mouse fixture exits through Esc',resultpath.exists())
  finally:
   w=os.waitpid(pid,os.WNOHANG)
   if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
   os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
