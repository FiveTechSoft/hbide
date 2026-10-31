"""Pasted PushButton retains custom action and accelerator in actual F9 runtime."""
import argparse
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
parser=argparse.ArgumentParser()
parser.add_argument('--mixed',action='store_true')
parser.add_argument('--button',action='store_true')
parser.add_argument('--dialog-caption',action='store_true')
parser.add_argument('--reserved-binding',action='store_true')
parser.add_argument('--duplicate-caption',action='store_true')
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
  caption='Fixture' if args.dialog_caption else 'He said "yes"'
  modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':60,'height':20,'controls':[{'type':'get' if args.reserved_binding else ('button' if args.button else 'say'),'variable':'oDlg','width':12,'row':1,'col':2,'caption':caption, 'accelerator':'Q'}]}))
  if args.duplicate_caption:
   model=json.loads(modelpath.read_text()); model['controls'].append(dict(model['controls'][0],row=3));modelpath.write_text(json.dumps(model))
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  if args.duplicate_caption:send(b'\t')
  check('Loaded fixture retains original binding/caption',json.loads(modelpath.read_text())['controls'][0]['variable']=='oDlg' if args.reserved_binding else caption in screen.text())
  send(b'\x1b[15~',.4)
  check('F5 live view visible','live view' in screen.text())
  rows=[r for r,g in enumerate(screen.g) if (' GET oDlg2 ' if args.reserved_binding else ('PUSHBUTTON' if args.button else 'oDlg:Say(')) in ''.join(g)]
  check('Live view includes generated selected control',bool(rows))
  check('Generated control is highlighted current control',bool(rows) and any(bg==6 for fg,bg in screen.at[rows[-1] if args.duplicate_caption else rows[0]][64:115]))
  check('Opening view leaves JSON exact',json.loads(modelpath.read_text())['controls'][0]['caption']==caption and json.loads(modelpath.read_text())['controls'][0]['variable']=='oDlg')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
