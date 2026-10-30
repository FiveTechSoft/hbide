"""Actual Help Contents mouse tree/buttons and source preservation."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'mouse.prg'
 original=b'alpha beta\r\n\tTABword tail\n'+b''.join(('line%02d text\n'%i).encode() for i in range(3,65))
 original=original.replace(b'line03 text',b'line03 '+b'a'*150+b' ENDMARK tail')
 target.write_bytes(original)
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
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  send(b'X');send(b'\x1bh');send(b'c',.5)
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def click(row,col):mouse(0,row,col);mouse(3,row,col,.2)
  def locate(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  check('Contents opens tree and reading pane','Basics' in screen.text() and 'Search' in screen.text())
  click(*locate('Quick start'))
  (work/'help-selected.screen').write_text(screen.text())
  check('mouse tree selects exact topic','New file:' in screen.text() or 'Quick start ?' in screen.text())
  # reading pane receives Home/End after click, independently of tree selection
  click(*locate('1. Basics'))
  check('mouse first tree row selects Basics not next topic','1. Basics ?' in screen.text())
  click(7,10);send(b'\x1b[F')
  bottom=''.join(screen.g[32])[3:27].strip(' ?')
  # The visible bottom row is selected by mouse after End has scrolled the index.
  click(32,10)
  (work/'help-tree-bottom.screen').write_text(screen.text())
  check('scrolled tree click retains valid reading pane',bool(bottom) and bottom[:12] in ''.join(screen.g[4])[31:])
  click(7,40);send(b'\x1b[F')
  click(*locate('Next'))
  check('Next button with no query explains action','No search yet:' in screen.text())
  def button(label):
   row=36;col=''.join(screen.g[row]).index(label);click(row,col)
  button('Search');send(b'Iconize');send(b'\r')
  (work/'help-search.screen').write_text(screen.text())
  check('Search button executes actual query',"for 'Iconize'" in screen.text() and 'Match 1/' in screen.text())
  click(*locate('Next'))
  (work/'help-next.screen').write_text(screen.text())
  check('Next button advances actual match','Match 2/' in screen.text() and "for 'Iconize'" in screen.text())
  for _ in range(4):mouse(65,10,40,.05)
  (work/'help-wheel.screen').write_text(screen.text())
  counter=re.findall(r'(\d+)/(\d+)',screen.text())
  check('wheel scroll stays within topic bounds',bool(counter) and all(int(a)<=int(b) for a,b in counter))
  click(*locate('Export .md'))
  exported=work/'hbide-help.md'
  check('Export button writes actual catalogue',exported.is_file() and 'Iconize' in exported.read_text() and 'Welcome to hbide' in exported.read_text())
  click(*locate('Close'))
  check('Close button returns dirty document','Xalpha beta' in screen.text() and 'help.prg' not in screen.text())
  send(b'\x1be');send(b'n');send(b'\x1bOQ')
  check('Undo after mouse Help restores exact original bytes',target.read_bytes()==original)
  (work/'help-mouse-final.screen').write_text(screen.text())
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
