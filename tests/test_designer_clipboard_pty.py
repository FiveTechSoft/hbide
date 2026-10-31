"""Actual designer ComboBox clipboard and history dispatch preserves persisted model."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['combobox']:
 modelpath=work/'mydialog.json'
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
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5)
  send(b'\x1bo');send(b's',.5)
  send(b'\x1bOQ');send(b'm');send(b'\r',.5)
  check('ComboBox created in real designer','Item 1' in screen.text())
  def model():
   send(b'\x1b[21~',.4)
   if 'Save dialog as JSON' in screen.text():send(b'\r');send(b'\r',.4)
   (work/'last-model.screen').write_text(screen.text())
   d=__import__('json').loads(modelpath.read_text());return d
  baseline=model();original=baseline['controls'][0]
  check('initial ComboBox model exact type',original['type']=='combobox' and len(baseline['controls'])==1)
  send(b'\x03');send(b'\x16');send(b'\x16')
  pasted=model();c=pasted['controls']
  check('Copy plus two Paste produces three controls',len(c)==3)
  check('pasted variables all unique',len({x['variable'] for x in c})==3)
  preserved=[k for k in original if k not in ['row','col','variable']]
  check('Paste preserves items dimensions and events',all(all(x[k]==original[k] for k in preserved) for x in c))
  check('Paste offsets exact row col',[(x['row'],x['col']) for x in c]==[(min(original['row']+i,baseline['height']-2-original['height']),original['col']+i) for i in range(3)])
  send(b'\x1a');undo=model()
  check('Undo removes only last pasted control',undo['controls']==c[:2])
  send(b'\x19');redo=model()
  check('Redo restores complete pasted model',redo['controls']==c)
  send(b'\x18');cut=model()
  check('Cut selected control removes only last exact model',cut['controls']==c[:2])
  send(b'\x1a');restored=model()
  check('Undo Cut restores complete model',restored['controls']==c)
  send(b'\x16');clone=model()['controls']
  check('Paste after Cut Undo creates unique variable',len(clone)==4 and len({x['variable'] for x in clone})==4)
  check('clipboard remains deep clone of cut control',all(clone[-1][k]==c[-1][k] for k in preserved))

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
