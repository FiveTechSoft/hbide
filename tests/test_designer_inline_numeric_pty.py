"""Actual inline numeric/style adjustments and persisted history. Linux PTY."""
import argparse
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
parser=argparse.ArgumentParser();parser.add_argument('--kind',choices=['say','get','button','checkbox','radiogroup','combobox']);parser.add_argument('--get',action='store_true');parser.add_argument('--listbox',action='store_true');args=parser.parse_args()
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
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  def model():
   send(b'\x1b[21~',.25)
   if 'Save dialog as JSON' in screen.text():send(b'\r');send(b'\r',.3)
   return json.loads(modelpath.read_text())
  baseline=model()['controls']
  send(b'\x1bOS');send(b'\x1b[17~')
  check(kind+' inspector visible','Inspector' in screen.text())
  fields=[(0,'row'),(1,'col')]
  if kind=='get':fields.append((3,'width'))
  if kind in ['listbox','combobox']:fields.extend([(4,'width'),(5,'height')])
  if kind=='button':fields.append((5,'style'))
  expected=baseline
  for offset,key in fields:
   for _ in range(12):send(b'\x1b[A',.02)
   for _ in range(offset):send(b'\x1b[B',.04)
   send(b'\x1b[C');send(b'\x1b[C')
   changed=model()['controls']
   value=expected[0][key]+2 if key!='style' else expected[0][key]
   check(kind+' inline '+key+' two adjustments persisted',changed[0][key]==value)
   send(b'\x1a');check(kind+' inline '+key+' burst Undo exact',model()['controls']==expected)
   send(b'\x19');check(kind+' inline '+key+' burst Redo exact',model()['controls']==changed)
   expected=changed
  if kind=='button':
   for _ in range(12):send(b'\x1b[A',.02)
   for _ in range(5):send(b'\x1b[B',.04)
   send(b'\r');changed=model()['controls']
   check('button Enter cycles style',changed[0]['style']=='shadow')
   send(b'\x1a');check('button Enter style Undo exact',model()['controls']==expected)
   send(b'\x19');check('button Enter style Redo exact',model()['controls']==changed)
   expected=changed
  check(kind+' no other controls introduced',len(expected)==1)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
