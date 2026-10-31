"""Actual designer loaded-control clipboard and history dispatch preserves persisted model."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[];created='--create' in sys.argv;popup='--popup' in sys.argv
for kind in ['get']:
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
  control={'type':'get','row':10,'col':28,'width':10,'variable':'CVAR1'}
  modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':41,'height':14,'controls':[control]}))
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  def model():
   send(b'\x1b[21~',.25)
   if 'Save dialog as JSON' in screen.text():send(b'\r');send(b'\r',.3)
   return json.loads(modelpath.read_text())
  baseline=model()['controls'];check('odd-edge fixture exact',baseline[0]['row']==10 and baseline[0]['col']==28)
  send(b'\x1bOQ');send(b'g');send(b'\r')
  send(b'\x1b[B\x1b[C')
  moved=model()['controls'][0]
  check('Snap arrows clamp after rounding at odd edges',moved['row']==11 and moved['col']==29)
  check('complete GET remains within interior',moved['row']+1<=12 and moved['col']+moved['width']<=39)
  check('Snap move keeps dimensions and binding',moved['width']==10 and moved['variable']=='CVAR1')
  send(b'\x1a');check('Undo snapped burst restores complete original',model()['controls']==baseline)
  send(b'\x19');check('Redo snapped burst restores complete edge model',model()['controls']==[moved])

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
