"""Generate and run the committed mixed-control screenshot fixture. Linux only."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[];created='--create' in sys.argv
for kind in ['mixed']:
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
  modelpath.write_bytes((ROOT/'demos/designer/fixture-mas-controles.json').read_bytes())
  pump(.8);send(b'\x1bo');send(b's',.3);send(b'\x1b[24~',.3)
  send(b'\x19'+str(modelpath).encode());send(b'\r');send(b'\r',.3);send(b'\t')
  send(b'\x1b[20~',.4)
  generated=(work/'fixture.prg').read_text()
  check('F9 generates committed mixed-control fixture',all(t in generated for t in ['cNombre','cCorreo','lActivo','lAvisos','nTipo','nProyecto','nBefore']))
  check('designer load preserves all twelve controls',len(json.loads(modelpath.read_text())['controls'])==12)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
# Compile actual F9 artifact. Instrument return only to inspect bound values.
import subprocess
resultpath=work/'runtime-values.json'
source=work/'runtime.prg'
source.write_text(generated.replace('return lOk','hb_MemoWrit( "'+str(resultpath)+'", hb_jsonEncode( { AllTrim(cNombre),AllTrim(cCorreo),lActivo,lAvisos,nTipo,nProyecto,nBefore,lOk } ) )\nreturn lOk')+'\nprocedure Main()\nDlg_Fixture()\nreturn\n')
runtime=work/'runtime'
build=subprocess.run(['hbmk2',str(source),*[str(ROOT/x) for x in ['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']],'-gttrm','-quiet','-o'+str(runtime)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(work/'runtime-build.log').write_bytes(build.stdout)
check('actual mixed generated PRG compiles',build.returncode==0)
if build.returncode==0:
 scenarios=[('escape',None),('save',True),('cancel',False),('selectors',None)] if '--actions' in sys.argv else [('escape',None)]
 for scenario,expected_ok in scenarios:
  resultpath.unlink(missing_ok=True)
  pid,fd=pty.fork()
  if pid==0:os.execve(str(runtime),[str(runtime)],dict(os.environ,TERM='xterm'))
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
  try:
   pump(.8)
   check(scenario+' runtime mixed dialog visible',all(t in screen.text() for t in ['Fixture','Nombre:','Correo:','Activo','Personal','IDE Harbour','Guardar','Cancelar']))
   if scenario=='selectors':
    send(b' ',.2);send(b'\x1b[B',.2);send(b'\t',.2)
    # Nombre, Correo, Activo, Avisos -> radio -> project list
    send(b'\t'*4,.3);send(b'\x1b[B',.2);send(b'\t',.2);send(b'\x1b[B',.2);send(b'\x1b',.4)
   else:
    send(b'\t',.2);send(b'Ana',.2);send(b'\t',.2);send(b'ana@example.test',.2);send(b'\t',.2);send(b' ',.2)
    if scenario=='save':send(b'\t'*4,.3);send(b'\r',.5)
    elif scenario=='cancel':send(b'\t'*5,.3);send(b'\r',.5)
    else:send(b'\x1b',.4)
   check(scenario+' runtime returns and writes bound values',resultpath.exists())
   if resultpath.exists():
    values=json.loads(resultpath.read_text())
    if scenario=='selectors':check('combo radio and list change independent bindings',values[4:7]==[2,2,2])
    else:
     check(scenario+' mixed GET fields retain independent input',values[0:2]==['Ana','ana@example.test'])
     check(scenario+' checkbox state independent',values[2:4]==[True,False])
     check(scenario+' unvisited selectors keep defaults',values[4:7]==[1,1,1])
    if expected_ok is not None:check(scenario+' actual button action returns expected flag',values[7]==expected_ok)
    (work/(scenario+'-values.json')).write_text(json.dumps(values))
   (work/(scenario+'.screen')).write_text(screen.text())
  finally:
   w=os.waitpid(pid,os.WNOHANG)
   if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
   os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
