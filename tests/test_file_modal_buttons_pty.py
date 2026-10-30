"""File/project native modal explicit buttons and list selection preserve data."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
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
   if b'\x1b[6n' in d:os.write(fd,b'\x1b[25;1R')
   if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;25;80t')
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5)
  def filemenu(key):send(b'\x1bf');send(key)
  def projectopen():send(b'\x1bp');send(b'o')
  filemenu(b'o');send(str(target).encode());send(b'\t\t\r',.5)
  check('Open explicit OK preserves manually typed name after list focus','AAA first' in screen.text() and 'aaa.prg' in screen.text())
  send(b'X')
  filemenu(b'o');send(str(other).encode());send(b'\t\t\t\r',.5)
  check('Open explicit Cancel retains dirty document','XAAA first' in screen.text())
  filemenu(b'a');send(str(dest).encode());send(b'\t\t\r',.4)
  check('SaveAs explicit Cancel creates no destination',not dest.exists())
  check('SaveAs explicit Cancel retains name and dirty buffer','aaa.prg' in screen.text() and 'XAAA first' in screen.text())
  filemenu(b'a');send(str(dest).encode());send(b'\t\r',.5)
  check('SaveAs explicit OK saves exact mixed EOL bytes',dest.exists() and dest.read_bytes()==b'X'+original)
  check('SaveAs changes identity only on OK','saved with spaces.prg' in screen.text())
  check('SaveAs retains original file',target.read_bytes()==original)
  # Directory order is not alphabetical. Read the selected GET after a
  # real Home/Down selection change, then verify that exact file is opened.
  filemenu(b'o');send(b'\t\x1b[H\x1b[B',.4)
  selected=''.join(screen.g[6][19:56]).strip()
  check('Open list sync produces a known filename',selected in ['aaa.prg','bbb.prg','saved with spaces.prg'])
  send(b'\t\r',.5)
  check('Open list selection opens exact selected file',bool(selected) and selected in screen.text() and ('BBB second' if selected=='bbb.prg' else ('XAAA first' if selected=='saved with spaces.prg' else 'AAA first')) in screen.text())
  before=screen.text()
  projectopen();send(str(work/'aaa.hbp').encode());send(b'\t\t\t\r',.5)
  check('Project explicit Cancel keeps editor',screen.text()==before)
  projectopen();send(str(work/'aaa.hbp').encode());send(b'\t\t\r',.5)
  (work/'project-ok.screen').write_text(screen.text())
  check('Project explicit OK opens manually typed project','aaa.hbp' in screen.text() and 'aaa.prg' in screen.text())
  send(b'\x1b',.4)
  projectopen();send(b'\t\x1b[H\x1b[B',.4)
  selected=''.join(screen.g[6][19:56]).strip()
  check('Project list sync produces known filename',selected in ['aaa.hbp','bbb.hbp'])
  send(b'\t\r',.5)
  (work/'project-list.screen').write_text(screen.text())
  check('Project list selection opens selected project',bool(selected) and selected in screen.text() and selected.replace('.hbp','.prg') in screen.text())
  send(b'\x1b',.4)
  check('source bytes untouched by project navigation',other.read_bytes()==b'BBB second\nreturn\n' and target.read_bytes()==original)

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
