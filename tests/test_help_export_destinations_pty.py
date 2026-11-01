"""Actual Help Contents mouse tree/buttons and source preservation."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
exported=work/'hbide-help.md';victim=work/'existing-notes.md';victim.write_bytes(b'PRIVATE EXISTING NOTES\r\nexact')
kind=os.environ.get('HBIDE_EXPORT_KIND','regular')
if kind=='directory':exported.mkdir()
elif kind=='fifo':os.mkfifo(exported)
elif kind=='dangling':exported.symlink_to('missing-notes.md')
for run_kind in ['autorun']:
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
  click(*locate('Export .md'))
  if kind=='regular':
   check('New regular export succeeds',exported.is_file() and 'Wrote hbide-help.md' in screen.text())
   original_export=exported.read_bytes();exported.chmod(0o640)
   exported.write_bytes(b'EXISTING REGULAR EXPORT')
   click(*locate('Export .md'))
   check('Regular overwrite still allowed and complete',exported.read_bytes()==original_export and 'Wrote hbide-help.md' in screen.text())
   check('Regular export preserves mode',exported.stat().st_mode & 0o777==0o640)
  elif kind=='dangling':
   check('Dangling link refused clearly','Refused symlink' in screen.text())
   check('Dangling link untouched and no target created',exported.is_symlink() and os.readlink(exported)=='missing-notes.md' and not (work/'missing-notes.md').exists())
  else:
   check('Nonregular export refused clearly','Refused non-regular' in screen.text())
   import stat
   check('Nonregular destination unchanged',exported.is_dir() if kind=='directory' else stat.S_ISFIFO(exported.lstat().st_mode))
  check('Unrelated existing notes remain exact',victim.read_bytes()==b'PRIVATE EXISTING NOTES\r\nexact')
  click(*locate('Close'))
  check('Close returns unchanged dirty source','Xalpha beta' in screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
