"""Large hash inspector navigation edits selected records, not stale rows."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[];array_mode="--array" in sys.argv
for kind in ['hash']:
 target=work/(kind+'.prg');value=work/(kind+'.txt')
 init='{'+', '.join(str(n)+' => '+str(n*10) for n in range(1,41))+'}'
 result='hb_ntos( v:nValue )' if kind=='object' else 'hb_ValToExp( v )'
 code='procedure main()\n   local v := '+init+'\n   hb_MemoWrit( "'+str(value)+'", '+result+' )\nreturn\n'
 if kind=='object':
  code+='function MakeValue()\n   local oClass := HBClass():New( "ModalFixture" )\n   oClass:AddData( "nValue", 1 )\n   oClass:Create()\nreturn oClass:Instance()\n'
 if array_mode:code=code.replace(init,'{'+', '.join(str(n*10) for n in range(1,41))+'}')
 target.write_text(code)
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
  send(b'\x1b[B\x1b[B');send(b'\x1b[20~',.4)
  send(b'\x1br');send(b'd',1);send(b'\x1b[15~',.7)
  check(kind+' debugger stopped','Command' in screen.text())
  send(b'monitor local on\r',.4);send(b'window select monitor\r',.4)
  send(b'\r',.4)
  check(kind+' structured top inspector opens',' V ' in screen.text())
  send(b'9',.3)
  check(kind+' top inspector refuses replacement','Value cannot be edited' in screen.text())
  send(b'\r',.3) # dismiss alert, still in structured inspector
  send(b'\r',.4) # Enter drills into nested browser; edits enabled by default
  (work/(kind+'-browser.screen')).write_text(screen.text())
  send(b'\x1b[F',.3) # End
  check('End selects last hash record','V[40..40]' in screen.text())
  send(b'\r');send(b'4444\r')
  check('last record edit visible',any('V[40]' in ''.join(row) and '4444' in ''.join(row) for row in screen.g))
  send(b'\x1b[6~',.3)
  check('PageDown at end stays at last record','V[40..40]' in screen.text())
  send(b'\x1b[H',.3)
  check('Home selects first hash record','V[1..40]' in screen.text())
  send(b'\x1b[5~',.3)
  check('PageUp at first stays at first record','V[1..40]' in screen.text())
  send(b'\r');send(b'1111\r')
  send(b'\x1b[6~',.3)
  (work/'paged.screen').write_text(screen.text())
  selected=21 # 20 browser rows at80x25, first PageDown moves1->21
  check('PageDown caption follows selected record','V[21..40]' in screen.text())
  send(b'\r');send(b'7777\r')
  send(b'\x1b[5~',.3)
  check('PageUp returns first record','V[1..40]' in screen.text())
  send(b'\x1b',.3);send(b'\x1b',.3);send(b'\x1b[15~',.7)
  actual=value.read_text() if value.exists() else ''
  expected='{'+', '.join(str(n)+'=>'+str(1111 if n==1 else 4444 if n==40 else 7777 if n==selected else n*10) for n in range(1,41))+'}'
  if array_mode:expected='{'+', '.join(str(1111 if n==1 else 4444 if n==40 else 7777 if n==selected else n*10) for n in range(1,41))+'}'
  check('Resume container has exactly the three intended edits',actual==expected)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
