"""Actual designer loaded-control clipboard and history dispatch preserves persisted model."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[];created='--create' in sys.argv
for kind in ['say','get','checkbox','button','radiogroup','listbox','combobox']:
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
  if created:
   modelpath=work/'mydialog.json'
   if modelpath.exists():modelpath.unlink()
   pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1bOQ',.3)
   mnemonic={'say':b'l','get':b'i','checkbox':b'b','button':b'p','radiogroup':b'r','listbox':b'x','combobox':b'm'}[kind]
   send(mnemonic);send(b'\r',.3)
   if kind in ['button','radiogroup']:send(b'\r',.3) # duplicate P or R first confirms menu, then places
  else:
   modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':60,'height':20,'controls':[control]}))
   pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
   send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  def model():
   send(b'\x1b[21~',.25)
   if 'Save dialog as JSON' in screen.text():send(b'\r');send(b'\r',.3)
   return json.loads(modelpath.read_text())
  baseline=model()['controls']
  check(kind+(' real F2 create and F10 persist type' if created else ' real F12 load and F10 persist type'),len(baseline)==1 and baseline[0]['type']==kind)
  send(b'\x03');send(b'\x16');send(b'\x16')
  copied=model()['controls'];preserved=[k for k in baseline[0] if k not in ['row','col','variable']]
  check(kind+' Copy two Paste preserves all nonbinding fields',len(copied)==3 and all(all(c[k]==baseline[0][k] for k in preserved) for c in copied))
  if not created:check(kind+' Paste offsets exact',[(c['row'],c['col']) for c in copied]==[(1,2),(2,3),(3,4)])
  else:check(kind+' Paste positions inside existing dialog',all(c['row']>=0 and c['col']>=0 for c in copied))
  check(kind+' bindings unique or absent',all('variable' not in c for c in copied) if 'variable' not in baseline[0] else len({c['variable'].upper() for c in copied})==3)
  send(b'\x1a');check(kind+' Undo removes last only',model()['controls']==copied[:2])
  send(b'\x19');check(kind+' Redo restores complete models',model()['controls']==copied)
  send(b'\x18');check(kind+' Cut removes selected only',model()['controls']==copied[:2])
  send(b'\x1a');check(kind+' Undo Cut restores complete models',model()['controls']==copied)
  send(b'\x16');more=model()['controls']
  check(kind+' Paste after Cut Undo keeps fields',len(more)==4 and all(more[-1][k]==copied[-1][k] for k in preserved))

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
