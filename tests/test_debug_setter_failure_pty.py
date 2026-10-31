"""Failed setter reports its error and preserves readable backing value."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['object']:
 target=work/(kind+'.prg');value=work/(kind+'.txt')
 init={'array':'{1, 2}','hash':'{"one" => 1, "two" => 2}','object':'MakeValue()'}[kind]
 result='hb_ntos( v:nValue )' if kind=='object' else 'hb_ValToExp( v )'
 code='procedure main()\n   local v := '+init+'\n   hb_MemoWrit( "'+str(value)+'", '+result+' )\nreturn\n'
 if kind=='object':
  code+='function MakeValue()\n   local oClass := HBClass():New( "ModalFixture" )\n   oClass:AddData( "nValue", 1 )\n   oClass:AddInline( "Bad", {|self| self:nValue} )\n   oClass:AddInline( "_Bad", {|| 1 / 0} )\n   oClass:Create()\nreturn oClass:Instance()\n'
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
  check('readable getter shows backing1',bool(re.search(r'BAD\s+1\s',screen.text())))
  send(b'\r',.3);send(b'41\r',.4)
  (work/'setter-error.screen').write_text(screen.text())
  check('failed setter error reported','Zero divisor' in screen.text())
  send(b'\r',.3)
  check('failed setter refresh preserves backing1',bool(re.search(r'BAD\s+1\s',screen.text())))
  send(b'\r',.3);send(b'99\x1b',.3)
  check('cancel after setter error preserves backing1',bool(re.search(r'BAD\s+1\s',screen.text())))
  send(b'\x1b',.3);send(b'\x1b',.3);send(b'\x1b[15~',.7)
  check('setter failure leaves debuggee backing1',value.exists() and value.read_text()=='1')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
