"""Untitled watch identity is distinct from explicitly loaded noname.prg."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1];ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-watch-'));exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
modes=sys.argv[1:] or ['clean','dirty','new','explicit','saveas','failure','recover-unnamed','recover-relative','recover-named']
for mode in modes:
 w=work/mode;w.mkdir();(w/'home').mkdir();(w/'rec').mkdir();target=w/'noname.prg';original=b'EXISTING_NONAME_SOURCE\n';target.write_bytes(original)
 if mode.startswith('recover-'):
  (w/'rec/dead--old.journal').write_bytes(b'UNSAVED_RECOVERED_TEXT')
  (w/'rec/dead--old.target').write_text('noname.prg' if mode in ['recover-unnamed','recover-relative'] else str(target))
 if mode in ['saveas','failure']:target.unlink()
 pid,fd=pty.fork()
 if pid==0:
  os.chdir(w);os.execve(exe,[exe],dict(os.environ,TERM='xterm',HOME=str(w/'home'),HBIDE_RECOVERY_DIR=str(w/'rec')))
 fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));s=Scr()
 def pump(t):
  end=time.monotonic()+t;buf=b''
  while time.monotonic()<end:
   if not select.select([fd],[],[],.05)[0]:continue
   try:d=os.read(fd,65536)
   except OSError:break
   buf+=d
   if b'\x1b[6n' in d:os.write(fd,b'\x1b[25;1R')
   if b'\x1b[18t' in d:os.write(fd,b'\x1b[8;25;80t')
  s.feed(buf)
 def send(k,t=.2):os.write(fd,k);pump(t)
 def check(label,ok):
  results.append(bool(ok));print(('PASS' if ok else 'FAIL'),mode,label,flush=True)
  if not ok:(w/('failure%d.screen'%len(results))).write_text(s.text())
 def openfile(name):send(b'\x1bf');send(b'o');send(name.encode()+b'\r',.4)
 def saveas(name):send(b'\x1bf');send(b'a');send(name.encode()+b'\r',.5)
 try:
  deadline=time.monotonic()+8
  while ('interrupted session' if mode.startswith('recover-') else 'Hello world from Harbour') not in s.text() and time.monotonic()<deadline:pump(.1)
  if mode=='dirty':send(b'X')
  elif mode=='new':
   other=w/'other.prg';other.write_bytes(b'OTHER_SOURCE\n');openfile(str(other));send(b'\x1bf');send(b'n')
  elif mode=='explicit':openfile('noname.prg');check('explicit source loaded','EXISTING_NONAME_SOURCE' in s.text());target.write_bytes(b'CHANGED_EXPLICIT_SOURCE\n')
  elif mode in ['saveas','failure']:
   send(b'X');saveas('named.prg' if mode=='saveas' else 'missing/named.prg')
   if mode=='failure':send(b'\r')
   else:(w/'named.prg').write_bytes(b'CHANGED_SAVED_SOURCE\n')
   target.write_bytes(original)
  elif mode.startswith('recover-'):
   send(b'r',.8);check('recovered bytes visible','UNSAVED_RECOVERED_TEXT' in s.text())
   if mode.startswith('recover-'):target.write_bytes(b'CHANGED_RECOVERED_SOURCE\n')
  pump(4)
  if mode in ['clean','new']:check('template remains unassociated','Hello world from Harbour' in s.text() and 'File changed on disk' not in s.text())
  elif mode in ['dirty','failure']:check('dirty template has no unrelated conflict','Xfunction Main()' in s.text() and 'File changed on disk' not in s.text())
  elif mode=='explicit':check('explicit relative noname watch active','CHANGED_EXPLICIT_SOURCE' in s.text())
  elif mode=='saveas':check('successful SaveAs watch active','CHANGED_SAVED_SOURCE' in s.text())
  elif mode in ['recover-unnamed','recover-relative']:check('ambiguous legacy retains prior watch policy','File changed on disk and you have unsaved changes' in s.text())
  elif mode=='recover-named':check('named recovery watch active','File changed on disk and you have unsaved changes' in s.text())
  check('homonym bytes untouched by IDE',target.read_bytes()==(b'CHANGED_EXPLICIT_SOURCE\n' if mode=='explicit' else b'CHANGED_RECOVERED_SOURCE\n' if mode.startswith('recover-') else original))
 finally:
  os.kill(pid,signal.SIGKILL);os.waitpid(pid,0);os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
raise SystemExit(not all(results))
