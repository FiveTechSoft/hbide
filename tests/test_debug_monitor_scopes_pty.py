"""Monitor scope toggles and Sort affect actual displayed variables and edits."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   local qZ := 11, qA := 12\n   static qStatic := 30\n   public qPublic := 40\n   private qPrivate := 50\n   qZ++\n   hb_MemoWrit( "'+str(value)+'", hb_ValToExp( {qZ,qA,qStatic,qPublic,qPrivate} ) )\nreturn\n')
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
  send(b'\x1b[B'*5);send(b'\x1b[20~',.4)
  send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
  check('debugger stopped before increment','Command' in screen.text())
  def scope(letter):send(b'\x1bm');send(letter)
  def fields():return re.findall(r'(Q[A-Z]+) <(Local|Static|Public|Private)[^>]*>:\s+(-?\d+)',screen.text())
  scope(b'l');check('Local menu displays both exact scalar values',{n:int(x) for n,t,x in fields()}=={'QA':12,'QZ':11})
  before=[n for n,t,x in fields() if t=='Local'];check('unsorted locals retain declaration order',before==['QZ','QA'])
  scope(b'o');check('Sort menu orders actual local names',[n for n,t,x in fields() if t=='Local']==['QA','QZ'])
  scope(b'p');check('Public menu adds actual memvar value',any(n=='QPUBLIC' and t=='Public' and x.strip()=='40' for n,t,x in fields()))
  scope(b'v');check('Private menu adds actual memvar value',any(n=='QPRIVATE' and t=='Private' and x.strip()=='50' for n,t,x in fields()))
  scope(b's');check('Static menu adds actual static value',any(n=='QSTATIC' and t=='Static' and x.strip()=='30' for n,t,x in fields()))
  names=[n for n,t,x in fields()];check('Sort remains active across scope additions',names==sorted(names) and len(names)==5)
  scope(b'p');check('Public toggle removes only public fixture variable',set(n for n,t,x in fields())=={'QA','QZ','QPRIVATE','QSTATIC'})
  scope(b'v');check('Private toggle removes only private fixture variable',set(n for n,t,x in fields())=={'QA','QZ','QSTATIC'})
  scope(b's');check('Static toggle removes only static fixture variable',set(n for n,t,x in fields())=={'QA','QZ'})
  scope(b'a');check('All menu exposes fixture scopes with exact values',{n:int(x) for n,t,x in fields()}=={'QA':12,'QZ':11,'QSTATIC':30,'QPUBLIC':40,'QPRIVATE':50})
  scope(b'a');check('second All hides all fixture variables',not fields())
  send(b'monitor local on\r');send(b'window select monitor\r')
  send(b'\r');send(b'\x1b[H\x1b[3~\x1b[3~77\r')
  check('editing sorted first row targets QA',any(n=='QA' and x.strip()=='77' for n,t,x in fields()))
  send(b'window select command\r');send(b'\x1b[15~',.7)
  check('scope toggles and sorted edit reach exact debuggee slots',value.exists() and value.read_text().replace(' ','')=='{12,77,30,40,50}')
  check('scope test leaves source bytes unchanged',target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
