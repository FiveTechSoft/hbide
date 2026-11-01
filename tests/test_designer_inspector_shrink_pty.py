"""Actual inline inspector text editing, Undo/Redo/Esc and persisted JSON. Linux PTY."""
import argparse
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
small='--small' in sys.argv
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
parser=argparse.ArgumentParser();parser.add_argument('--kind',choices=['say','get','button','checkbox','radiogroup','combobox']);parser.add_argument('--events',action='store_true');parser.add_argument('--get',action='store_true');parser.add_argument('--listbox',action='store_true');args=parser.parse_args();args.kind='combobox'
for kind in [args.kind or ('listbox' if args.listbox else ('get' if args.get else 'button'))]:
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
  for rr,cc in re.findall(rb'\x1b\[8;(\d+);(\d+)t',b):fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',int(rr),int(cc),0,0))
  screen.feed(b)
 def send(b,wait=.15):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  control={'type':kind,'row':1,'col':2}
  if kind in ['say','checkbox','button']:control['caption']="Quoted 'caption'"
  if kind in ['get','checkbox','radiogroup','listbox','combobox']:control['variable']={'get':'CVAR1','checkbox':'LVAR1'}.get(kind,'NVAR1')
  if kind in ['get','listbox','combobox']:control['width']=20
  if kind in ['listbox','combobox']:control['height']=6
  if kind in ['radiogroup','listbox','combobox']:control['items']="Alpha,Quoted 'item',Omega"
  if kind=='button':control.update(accelerator='Q',action="Handler( 'quoted' )",style='brackets')
  if kind!='say':
   for key in ['when','valid','focus','state']:control[key]="Handler_"+key+"( 'quoted' )"
  modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':60,'height':20,'controls':[control]}))
  pump(.8)
  if small:
   send(b'\x1bo');send(b'd');send(b'\x1b[B');send(b'\x1b[B');send(b'\t');send(b'\r',.5)
   check('actual Display applies25x80',struct.unpack('HHHH',fcntl.ioctl(fd,termios.TIOCGWINSZ,b'\0'*8))[:2]==(25,80))
  send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  def model():
   send(b'\x1b[21~',.25)
   if 'Save dialog as JSON' in screen.text():send(b'\r');send(b'\r',.3)
   return json.loads(modelpath.read_text())
  baseline=model()['controls']
  send(b'\x1bOS');send(b'\x1b[17~')
  check(kind+' inspector visible','Inspector' in screen.text())
  # Empty client click switches 10-field Combo inspector to 7-field dialog.
  # Coordinates are xterm 1-based, away from control and inspector.
  send(b'\x1b[M'+bytes([32,(42 if small else 60)+33,(17 if small else 22)+33]));send(b'\x1b[M'+bytes([35,(42 if small else 60)+33,(17 if small else 22)+33]),.5)
  check('dialog inspector selected','Name:' in screen.text())
  check('shorter inspector clears old State row','State:' not in screen.text())
  check('shorter inspector clears old Focus row',screen.text().count('Focus:')==1)
  send(b'\t',.5)
  check('Combo inspector restored','State:' in screen.text())
  check('selection only preserves JSON',model()['controls']==baseline)
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
