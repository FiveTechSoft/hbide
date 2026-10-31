"""File/project modal mouse buttons preserve exact selected paths and bytes."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'aaa.prg';other=work/'bbb.prg'
 original=b'AAA first\r\nreturn\n';target.write_bytes(original);other.write_bytes(b'BBB second\nreturn\n')
 (work/'aaa.hbp').write_text('aaa.prg\n');(work/'bbb.hbp').write_text('bbb.prg\n')
 dest=work/'saved with spaces.prg'
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
  def filemenu(key):send(b'\x1bf');send(key)
  def projectopen():send(b'\x1bp');send(b'o')
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def clicklabel(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:
     mouse(0,row,col);mouse(3,row,col,.3);return
   (work/'missing.screen').write_text(screen.text());raise AssertionError(label)
  filemenu(b'o');send(str(target).encode())
  (work/'open-modal.screen').write_text(screen.text())
  clicklabel('OK')
  check('Open mouse OK exact file','AAA first' in screen.text() and 'aaa.prg' in screen.text())
  send(b'X')
  filemenu(b'o');send(str(other).encode());clicklabel('Cancel')
  check('Open mouse Cancel preserves dirty source','XAAA first' in screen.text())
  filemenu(b'a');send(str(dest).encode());clicklabel('Cancel')
  check('SaveAs mouse Cancel no new file',not dest.exists())
  check('SaveAs mouse Cancel retains source identity','aaa.prg' in screen.text() and 'XAAA first' in screen.text())
  filemenu(b'a');send(str(dest).encode());clicklabel('OK')
  check('SaveAs mouse OK writes exact mixed EOL',dest.exists() and dest.read_bytes()==b'X'+original)
  check('SaveAs mouse OK changes identity','saved with spaces.prg' in screen.text())
  check('SaveAs mouse keeps original',target.read_bytes()==original)
  projectopen();send(str(work/'aaa.hbp').encode());clicklabel('Cancel')
  check('Project mouse Cancel retains exact editor','saved with spaces.prg' in screen.text() and 'XAAA first' in screen.text())
  projectopen();send(str(work/'aaa.hbp').encode());clicklabel('OK')
  check('Project mouse OK opens exact project','aaa.hbp' in screen.text() and 'aaa.prg' in screen.text())
  send(b'\x1b')
  filemenu(b'o');clicklabel('bbb.prg');clicklabel('OK')
  check('Open mouse list selects exact second file','bbb.prg' in screen.text() and 'BBB second' in screen.text())
  send(b'Y');send(b'\x1bOQ')
  check('mouse opened exact list file saved only selected bytes',other.read_bytes()==b'YBBB second\nreturn\n' and target.read_bytes()==original and dest.read_bytes()==b'X'+original)
  filemenu(b'o');clicklabel('aaa.prg');clicklabel('OK')
  check('Open mouse first list item selects exact original','aaa.prg' in screen.text() and 'AAA first' in screen.text() and 'XAAA first' not in screen.text())
  projectopen();(work/'project-list-before.screen').write_text(screen.text());clicklabel('bbb.hbp');(work/'project-list-selected.screen').write_text(screen.text());clicklabel('OK');(work/'project-list-after.screen').write_text(screen.text())
  check('Project mouse list chooses exact second project','bbb.hbp' in screen.text() and 'bbb.prg' in screen.text())
  send(b'\x1b')
  check('Project mouse operations preserve all file bytes',target.read_bytes()==original and other.read_bytes()==b'YBBB second\nreturn\n' and dest.read_bytes()==b'X'+original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
