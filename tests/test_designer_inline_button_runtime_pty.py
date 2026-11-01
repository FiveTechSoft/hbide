"""Inline-edited Action/Focus execute in actual F9 runtime via Enter/Space. Not accelerator acceptance."""
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
  edited={'action':'MarkState(), lOk := .T., oDlg:End()', 'focus':'MarkFocus()'}
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
source.write_text(generated+'\nprocedure Main()\n   hb_MemoWrit("'+str(resultpath)+'", hb_ValToExp(Dlg_Fixture()))\nreturn\nfunction MarkState()\n   hb_MemoWrit("'+str(marker)+'", "called")\nreturn .T.\nfunction MarkFocus()\n   hb_MemoWrit("'+str(focus)+'", "focus")\nreturn .T.\n')
runtime=work/'runtime'
build=subprocess.run(['hbmk2',str(source),*[str(ROOT/x) for x in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']],'-gttrm','-quiet','-o'+str(runtime)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(work/'runtime-build.log').write_bytes(build.stdout)
check('generated inline-edited-button artifact compiles',build.returncode==0)
if build.returncode==0:
 for scenario,keys in [('enter',b'\r'),('space',b' ')]:
  for path in [resultpath,marker,focus]:path.unlink(missing_ok=True)
  pid,fd=pty.fork()
  if pid==0:os.execve(str(runtime),[str(runtime)],dict(os.environ,TERM='xterm'))
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
  try:
   # Space animation has .4+.1 seconds of deliberate waits; allow completion.
   pump(.8);check(scenario+' runtime caption retains double quotes',caption in screen.text());send(keys,1.2)
   check(scenario+' generated button accepts dialog true',resultpath.exists() and resultpath.read_text()=='.T.')
   check(scenario+' inline-edited custom action executes',marker.exists() and marker.read_text()=='called')
   check(scenario+' inline-edited focus handler executes',focus.exists() and focus.read_text()=='focus')
  finally:
   w=os.waitpid(pid,os.WNOHANG)
   if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
   os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
