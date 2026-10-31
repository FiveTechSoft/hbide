"""Tracepoint popup validation, edit type, Delete cancel and real stop-on-change."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local n := 1\n   n := n + 1\n   hb_MemoWrit( "'+str(value)+'", hb_ntos( n ) )\nreturn\n')
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
  send(b'\x1b[B\x1b[B');send(b'\x1b[20~',.4)
  send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
  settings=work/'trace.cld'
  def point_menu(letter):send(b'\x1bp');send(letter,.3)
  def persisted(label,expected):
   send(b'window select command\r',.3);settings.unlink(missing_ok=True)
   send(b'options savesettings '+str(settings).encode()+b'\r',.4)
   points=[x for x in settings.read_text().splitlines() if x.startswith(('TP ','WP '))] if settings.exists() else None
   check(label+' exact saved point expressions',points==expected)
  check('stopped before first increment','Command' in screen.text() and not value.exists())
  point_menu(b't');send(b'n+100\x1b',.4);persisted('cancel add',[])
  point_menu(b't');send(b'bad_expr(\r',.4)
  check('invalid tracepoint add rejected','Expression error' in screen.text())
  send(b'\r',.3);send(b'\x1b',.3);persisted('invalid add',[])
  point_menu(b't');send(b'n\r',.4)
  check('tracepoint n evaluates initial exact value',bool(re.search(r'n <tp, N>:\s+1',screen.text())))
  persisted('add',['TP n'])
  send(b'window select points\r',.4);send(b'\r',.3);send(b'n + 2\r',.4)
  check('editing tracepoint evaluates3',bool(re.search(r'n \+ 2 <tp, N>:\s+3',screen.text())))
  persisted('edit preserves tracepoint type',['TP n + 2'])
  send(b'window select points\r',.4);send(b'\r',.3);send(b'n+200\x1b',.4)
  persisted('cancel edit',['TP n + 2'])
  send(b'window select points\r',.4);send(b'\r',.3);send(b'bad_expr(\r',.4)
  check('invalid tracepoint edit rejected','Expression error' in screen.text())
  send(b'\r',.3);send(b'\x1b',.3);persisted('invalid edit',['TP n + 2'])
  point_menu(b'd');send(b'\x1b',.4);persisted('cancel Delete',['TP n + 2'])
  send(b'\x1b[15~',.7)
  (work/'trace-stop.screen').write_text(screen.text())
  check('Go stops on real tracepoint change before output',not value.exists() and 'Command' in screen.text() and bool(re.search(r'n \+ 2 <tp, N>:\s+4',screen.text())))
  point_menu(b'd');send(b'\r',.4);persisted('delete',[])
  send(b'\x1b[15~',.7)
  check('after Delete Go completes exact debuggee value',value.exists() and value.read_text()=='2')
  check('point operations leave source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
