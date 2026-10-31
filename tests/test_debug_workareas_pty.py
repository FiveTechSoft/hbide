"""WorkAreas displays real DBFs and preserves application area/record state."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=40,120
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[];script='--script' in sys.argv
for kind in ['autorun']:
 target=work/'values.prg';value=work/'values.txt'
 target.write_text('procedure main()\n   dbCreate("alpha.dbf",{{"NAME","C",12,0},{"QTY","N",5,0}})\n   dbUseArea(.T.,,"alpha.dbf","ALPHA")\n   dbAppend()\n   field->NAME := "FIRST"\n   field->QTY := 11\n   dbCreate("beta.dbf",{{"CODE","C",8,0}})\n   dbUseArea(.T.,,"beta.dbf","BETA")\n   dbAppend()\n   field->CODE := "SECOND"\n   dbSelectArea("ALPHA")\n   hb_MemoWrit("'+str(value)+'",hb_ValToExp({Alias(),RecNo(),field->NAME,field->QTY}))\n   dbCloseAll()\nreturn\n')
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
  if script:
   for n in range(2):
    value.unlink(missing_ok=True)
    send(b'\x1br');send(b'c',.8)
    check('Script DBF run'+str(n+1)+' exact record vector',value.exists() and value.read_text()=='{"ALPHA", 1, "FIRST       ", 11}')
    check('Script DBF run'+str(n+1)+' returns editor without loader error','Edit' in screen.text() and 'Unknown or unregistered' not in screen.text())
   check('Script DBF leaves source bytes unchanged',target.read_bytes()==original)
  else:
   send(b'\x1b[B'*11);send(b'\x1b[20~',.4)
   send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
   check('debugger stopped before increment','Command' in screen.text())
   send(b'\x1bv');send(b'w',.4)
   (work/'workareas-alpha.screen').write_text(screen.text())
   check('View WorkAreas opens actual three browser dialog',all(x in screen.text() for x in [' Area ',' Status ',' Structure ','ALPHA','BETA']))
   check('ALPHA actual field structure shown',bool(re.search(r'NAME\s+C\s+12\s+0',screen.text())) and bool(re.search(r'QTY\s+N\s+5\s+0',screen.text())))
   send(b'\x1b[B',.3)
   (work/'workareas-beta.screen').write_text(screen.text())
   check('switching alias updates exact BETA structure',bool(re.search(r'CODE\s+C\s+8\s+0',screen.text())) and not re.search(r'QTY\s+N\s+5',screen.text()))
   check('switching alias updates Alias status',bool(re.search(r'Alias:\s+BETA',screen.text())))
   send(b'\t');send(b'\x1b[F');send(b'\t');send(b'\x1b[F');send(b'\x1b[Z');send(b'\x1b[Z');send(b'\x1b[A',.3)
   check('cycling panes and returning alias restores ALPHA fields',bool(re.search(r'QTY\s+N\s+5',screen.text())) and bool(re.search(r'Alias:\s+ALPHA',screen.text())))
   send(b'\x1b',.3);check('Esc closes WorkAreas to debugger','Command' in screen.text() and ' Structure ' not in screen.text())
   send(b'\x1b[17~',.3);check('F6 reopens WorkAreas with original alias',bool(re.search(r'Alias:\s+ALPHA',screen.text())))
   send(b'\x1b[B');send(b'\x1b',.3);send(b'\x1b[15~',.7)
   check('Resume retains original workarea record and exact fields',value.exists() and value.read_text()=='{"ALPHA", 1, "FIRST       ", 11}')
   check('WorkAreas inspection leaves source bytes unchanged',target.read_bytes()==original)
 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
