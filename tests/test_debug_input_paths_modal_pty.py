"""Debugger INPUT/path/custom filename modal acceptance and Cancel effects."""
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
  script=work/'test.cld';script.write_text('Options Tab 11\n')
  settings=work/'path.cld'
  def save(label):
   settings.unlink(missing_ok=True)
   send(b'options savesettings '+str(settings).encode()+b'\r',.4)
   body=settings.read_text() if settings.exists() else ''
   (work/(label+'.screen')).write_text(screen.text())
   return body
  send(b'input\r',.3);send(str(script).encode(),.3);(work/'input-typed.screen').write_text(screen.text());send(b'\r',.4);(work/'input-submitted.screen').write_text(screen.text())
  check('INPUT filename modal executes chosen script','Options Tab 11\n' in save('input-accept'))
  send(b'input\r',.3);send(b'/no-such-file-xyz\r',.4)
  check('INPUT invalid filename shows unavailable','File unavailable' in screen.text())
  send(b'\r',.2);send(b'\x1b',.3)
  check('INPUT invalid then Esc keeps state','Options Tab 11\n' in save('input-invalid'))
  send(b'input\r',.3);send(str(script).encode()+b'\x1b',.3)
  check('INPUT typed Cancel keeps state','Options Tab 11\n' in save('input-cancel'))
  source_dir=work/'extra sources';source_dir.mkdir();(source_dir/'extra.prg').write_text('procedure Extra()\n   ? "EXTRA-SOURCE-MARKER"\nreturn\n')
  send(b'\x1bo');send(b'f');send(str(source_dir).encode()+b'\r',.4)
  check('Path modal persists accepted value',('Options Path '+str(source_dir)+'\n') in save('path-accept'))
  send(b'\x1bo');send(b'f');send(b'/cancelled/path\x1b',.4)
  check('Path typed Cancel preserves prior value',('Options Path '+str(source_dir)+'\n') in save('path-cancel'))
  send(b'\x1bf');send(b'o');send(b'\r',.3) # Another file entry
  check('Open another-file input opens','Please enter the filename' in screen.text())
  send(b'extra.prg\r',.5)
  check('Custom filename resolves accepted source path','EXTRA-SOURCE-MARKER' in screen.text())
  send(b'\x1bf');send(b'o');send(b'\r',.3);send(b'not-opened.prg\x1b',.4)
  check('Custom filename typed Esc preserves source','EXTRA-SOURCE-MARKER' in screen.text() and 'not found' not in screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
