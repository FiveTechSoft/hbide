"""Caller and callee edits of a shadowed local reach distinct actual VM slots."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local shared := 101, childResult\n   childResult := Child()\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp({shared,childResult}) )\nreturn\nfunction Child()\n   local shared := 202\n   shared++\nreturn shared\n')
 original=target.read_bytes()
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
  send(b'\x1br');send(b'd',1)
  send(b'\x1b[19~',.5);send(b'\x1b[19~',.5)
  send(b'callstack on\r',.3);send(b'monitor local on\r',.3)
  send(b'\x1b[19~',.5);send(b'\x1b[19~',.5)
  def mouse(code,row,col,wait=.05):send(b'\x1b[M'+bytes([code+32,col+33,row+33]),wait)
  def click(row,col):mouse(0,row,col);mouse(3,row,col,.2)
  def double(row,col):
   mouse(0,row,col,.01);mouse(3,row,col,.01);mouse(0,row,col,.01);mouse(3,row,col,.2)
  def locate(label):
   for row in range(ROWS):
    col=''.join(screen.g[row]).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  check('callee shadowed local starts202',bool(re.search(r'SHARED <Local, N>:\s+202\s',screen.text())))
  def frame(label):
   for row in range(ROWS):
    line=''.join(screen.g[row]);m=re.search(r'\b'+label+r'\s+x',line)
    if m and m.start()>90:return row,m.start()
   raise AssertionError('No Calls frame '+label)
  def edit(number):
   send(b'window select monitor\r');send(b'\r');send(b'\x1b[H'+b'\x1b[3~'*3+str(number).encode()+b'\r')
  click(*frame('MAIN'))
  check('caller shadowed local starts101',bool(re.search(r'SHARED <Local, N>:\s+101\s',screen.text())))
  edit(707)
  check('caller edit displays707',bool(re.search(r'SHARED <Local, N>:\s+707\s',screen.text())))
  click(*frame('CHILD'))
  check('caller edit does not change callee202',bool(re.search(r'SHARED <Local, N>:\s+202\s',screen.text())))
  edit(808)
  check('callee edit displays808',bool(re.search(r'SHARED <Local, N>:\s+808\s',screen.text())))
  click(*frame('MAIN'))
  check('callee edit leaves caller707',bool(re.search(r'SHARED <Local, N>:\s+707\s',screen.text())))
  click(*frame('CHILD'))
  check('callee edited slot retained808',bool(re.search(r'SHARED <Local, N>:\s+808\s',screen.text())))
  send(b'window select command\r',.3);send(b'\x1b[15~',.7)
  check('Resume proves distinct caller707 and incremented callee809',value.exists() and value.read_text().replace(' ','')=='{707,809}')
  check('frame edits leave source bytes exact',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
