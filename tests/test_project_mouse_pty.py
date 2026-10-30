"""Actual project Sources/Messages mouse navigation and no-write effects."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 originals={}
 for n in range(1,41):
  p=work/('s%02d.prg'%n);b=('procedure M%02d()\n? "marker%02d"\nreturn\n'%(n,n)).encode();p.write_bytes(b);originals[p]=b
 p=work/'bad.prg';b=b'procedure Bad()\n? "ok"\n? x ++ y\nreturn\n';p.write_bytes(b);originals[p]=b
 project=work/'test.hbp';project.write_text('\n'.join(['s%02d.prg'%n for n in range(1,41)]+['bad.prg','missing.prg'])+'\n')
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
  pump(1.5);send(b'\x1bp');send(b'o');send(str(project).encode());send(b'\r',.6)
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def click(row,col):mouse(0,row,col);mouse(3,row,col,.2)
  def double(row,col):
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.2)
  def locate(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  def desktop():send(b'\x1bp');send(b's',.5)
  check('Project opens Sources', 'SOURCES' in screen.text())
  double(3,10)
  check('doubleclick header does not open source', 'SOURCES' in screen.text())
  click(*locate('s02.prg'))
  check('single click selects without opening', 'SOURCES' in screen.text())
  send(b'\r');check('Enter opens clicked exact file', 's02.prg' in screen.text() and 'marker02' in screen.text() and 'SOURCES' not in screen.text())
  desktop();send(b'\x1b[6~')
  labels=re.findall(r's(\d+)\.prg',screen.text())
  pick=next(int(n) for n in labels if int(n)>10)
  double(*locate('s%02d.prg'%pick))
  check('doubleclick scrolled source opens exact file', ('marker%02d'%pick) in screen.text() and 'SOURCES' not in screen.text())
  desktop();send(b'\x1b[F')
  double(*locate('missing.prg'))
  check('doubleclick missing source stays desktop', 'SOURCES' in screen.text() and '[missing]' in screen.text())
  send(b'\x1b[H');send(b'\x1bOS',.3) # F4 Messages
  check('Messages empty has no diagnostics', 'No parsed diagnostics' in screen.text())
  double(6,10)
  check('doubleclick empty Messages does not open file', 'MESSAGES' in screen.text() and 'No parsed diagnostics' in screen.text())
  project.write_text(project.read_text().replace('missing.prg\n',''))
  send(b'\x1b[20~',3) # F9 real build
  check('real failed build parsed bad source', 'BUILD FAILED' in screen.text() and 'ERROR bad.prg:3' in screen.text())
  double(*locate('ERROR bad.prg:3'))
  check('doubleclick diagnostic opens correct file row', 'bad.prg' in screen.text() and 'MESSAGES' not in screen.text() and bool(re.search(r'row:\s*3\s*,',screen.text())))
  check('all source bytes unchanged', all(p.read_bytes()==b for p,b in originals.items()))
  (work/'project-mouse-final.screen').write_text(screen.text())
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
