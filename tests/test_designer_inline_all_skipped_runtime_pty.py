"""Single-control forms with inline WHEN false return without input. Linux bounded fixture."""
import argparse
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
parser=argparse.ArgumentParser();parser.add_argument('--kind',choices=['get','radiogroup','checkbox','listbox','combobox','button'],required=True);args=parser.parse_args();kind=args.kind
for _ in [0]:
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
  event='when'
  offset={'get':4,'radiogroup':4,'checkbox':4,'listbox':6,'combobox':6,'button':6}[kind]
  binding={'get':'CVAR1','radiogroup':'NVAR1','checkbox':'LVAR1','listbox':'NVAR1','combobox':'NVAR1','button':'lDummy'}[kind]
  control={'type':kind,'row':1,'col':2,'width':20,'height':6,'items':'One,Two,Three','caption':'Choice','variable':binding,'style':'brackets','focus':'MarkFocus()',event:'OldState()'}
  modelpath.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':60,'height':20,'controls':[control]}))
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  send(b'\x1bOS');send(b'\x1b[17~')
  for _ in range(offset):send(b'\x1b[B',.03)
  send(b'\r');send(b'\x19MarkState()');send(b'\r');send(b'\x1b[21~',.3)
  controls=json.loads(modelpath.read_text())['controls']
  check('inline event exact persisted',len(controls)==1 and controls[0][event]=='MarkState()')
  send(b'\x1b[20~',.4)
  generated=(work/'fixture.prg').read_text()
  check('actual F9 emits inline event',generated.count('MarkState()')==1)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
# Compile the actual F9 artifact, instrumenting only the return to record bound values.
import subprocess
resultpath=work/'runtime-values.txt';marker=work/'handler-calls.txt'
source=work/'runtime.prg'
value_expr={'get':'AllTrim(CVAR1)','radiogroup':'NVAR1','checkbox':'LVAR1','listbox':'NVAR1','combobox':'NVAR1','button':'lDummy'}[kind]
source.write_text(generated.replace('return lOk','hb_MemoWrit( "'+str(resultpath)+'", hb_ValToExp( { '+value_expr+' } ) )\nreturn lOk')+'\nprocedure Main()\nDlg_Fixture()\nreturn\nfunction MarkState()\n   static nCalls := 0\n   nCalls++\n   hb_MemoWrit( "'+str(marker)+'", hb_ntos(nCalls) )\nreturn .F.\n')
source.write_text(source.read_text()+'\nfunction MarkSentinel()\n hb_MemoWrit("'+str(work/'sentinel.txt')+'", "entered")\nreturn .T.\nfunction MarkFocus()\n hb_MemoWrit("'+str(work/'focus.txt')+'", "entered")\nreturn .T.\n')
runtime=work/'runtime' 
build=subprocess.run(['hbmk2',str(source),*[str(ROOT/x) for x in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']],'-gttrm','-quiet','-o'+str(runtime)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(work/'runtime-build.log').write_bytes(build.stdout)
check('generated inline-edited-control artifact compiles',build.returncode==0)
if build.returncode==0:
 for scenario,keys,expected in [('veto',b'', '')]:
  for path in [resultpath,marker,work/'sentinel.txt',work/'focus.txt']:
   if path.exists():path.unlink()
  pid,fd=pty.fork()
  if pid==0:os.execve(str(runtime),[str(runtime)],dict(os.environ,TERM='xterm'))
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
  try:
   pump(1.5)
   check(kind+' false WHEN evaluated',marker.exists() and int(marker.read_text())>=1)
   check(kind+' all skipped form returns without input',resultpath.exists())
   expected={'get':'{""}','radiogroup':'{1}','checkbox':'{.F.}','listbox':'{1}','combobox':'{1}','button':'{NIL}'}[kind]
   check(kind+' all skipped binding unchanged',resultpath.exists() and resultpath.read_text()==expected)
   if kind!='get':check(kind+' all skipped GUI focus never entered',not (work/'focus.txt').exists())

  finally:
   w=os.waitpid(pid,os.WNOHANG)
   if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
   os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
