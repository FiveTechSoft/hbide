"""Debugger inline color and SET value edits validate, apply and Cancel."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'autorun.prg';value=work/'launched.txt'
 target.write_text('procedure main( ... )\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp( hb_AParams() ) )\nreturn\n')
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
   if b'\x1b[6n' in d:os.write(fd,b'\x1b[25;1R')
   if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;25;80t')
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  send(b'\x1br');send(b'd',1)
  check('debugger opens','Command' in screen.text())
  settings=work/'colors.cld'
  def palette():
   send(b'options savesettings '+str(settings).encode()+b'\r',.4)
   body=settings.read_text() if settings.exists() else ''
   return next((x for x in body.splitlines() if x.startswith('Options Colors ')),'')
  original=palette()
  send(b'\x1bo');send(b'c',.4)
  send(b'\r',.3);send(b'"W/R"\r',.4)
  send(b'\x1b',.4)
  changed=palette()
  check('actual color inline applies first palette entry',changed.startswith('Options Colors {"W/R",') and changed!=original)
  send(b'\x1bo');send(b'c',.3);send(b'\x1b[H');send(b'\r',.3);send(b'"N/B"\x1b',.4);send(b'\x1b',.3)
  check('typed Cancel preserves palette',palette()==changed)
  send(b'\x1bo');send(b'c',.3);send(b'\x1b[H');send(b'\r',.3);send(b'12\r',.3)
  check('wrong color type rejected','Must be' in screen.text())
  send(b'\r',.2);send(b'\x1b',.2);send(b'\x1b',.3)
  check('invalid color then Esc preserves palette',palette()==changed)
  send(b'\x1bv');send(b's',.3)
  send(b'\x1b[H\x1b[B\x1b[B') # Decimals numeric SET3
  send(b'\r',.3);send(b'5\r',.4)
  check('SET inline accepted Decimals5',bool(re.search(r'Decimals\s+5',screen.text())))
  send(b'\x1b[H\x1b[B\x1b[B');send(b'\r',.3);send(b'9\x1b',.3)
  check('SET typed Cancel preserves Decimals5',bool(re.search(r'Decimals\s+5',screen.text())))
  send(b'\r',.3);send(b'"wrong"\r',.3)
  check('SET wrong type rejected','Must be numeric' in screen.text())
  send(b'\r',.2);send(b'\x1b',.3)
  check('invalid SET then Esc preserves Decimals5',bool(re.search(r'Decimals\s+5',screen.text())))
  send(b'\x1b',.3)
  send(b'? "DECIMALS="+hb_ntos( Set( 3 ) )\r',.4)
  check('actual SET state observable from debugger','DECIMALS=5' in screen.text())
  (work/'sets-query.screen').write_text(screen.text())
  send(b'\x1bv');send(b's',.3);send(b'\x1b[H\x1b[B\x1b[B');send(b'\r',.3);send(b'2\r',.3);send(b'\x1b',.3)
  send(b'? "RESTORED="+hb_ntos( Set( 3 ) )\r',.4)
  check('restored SET state','RESTORED=2' in screen.text())
  send(b'options colors '+original[len('Options Colors '):].encode()+b'\r',.4)
  check('restored full palette',palette()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
