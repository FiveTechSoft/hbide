"""Compiler Options radio last-to-first mouse selection and actual argv."""
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=25,80
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
for kind in ['flags']:
 target=work/'flags.prg';target.write_text('procedure main()\nreturn\n')
 value=work/'argv.txt'
 fake=work/'fake-bin';fake.mkdir(exist_ok=True)
 compiler=fake/'hbmk2';compiler.write_text('#!/bin/sh\nprintf \"%s\\n\" \"$@\" > \"'+str(value)+'\"\nexit 7\n');compiler.chmod(0o755)
 pid,fd=pty.fork()
 if pid==0:
  if kind=='flags':os.environ['PATH']=str(fake)+os.pathsep+os.environ['PATH']
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
  def build():
   value.unlink(missing_ok=True)
   send(b'\x1br');send(b's',.7)
   (work/('build-'+str(time.time())+'.screen')).write_text(screen.text())
   check('build failure visible','Build failed (status 7)' in screen.text())
   send(b'\r',.3)
   return value.read_text().splitlines() if value.exists() else []
  args=build()
  check('default GCC warnings strict flags',all(x in args for x in ['-comp=gcc','-w3','-es2']) and '-b' not in args and '-inc' not in args and '-O2' not in args)
  def locate(label):
   for row,cells in reversed(list(enumerate(screen.g))):
    col=''.join(cells).find(label)
    if col>=0:return row,col
   raise AssertionError('No painted label '+label)
  def click(label):
   row,col=locate(label)
   send(b'\x1b[M'+bytes([32,col+33,row+33]),.05)
   send(b'\x1b[M'+bytes([35,col+33,row+33]),.3)
  send(b'\x1bo');send(b'c',.5)
  click('MSVC');click('Warnings');click('Debug info');click('Incremental');click('Optimize code')
  click('Cancel')
  args=build()
  check('Mouse Cancel discards radio and checkbox changes',all(x in args for x in ['-comp=gcc','-w3','-es2']) and '-b' not in args and '-inc' not in args and '-O2' not in args)
  send(b'\x1bo');send(b'c',.5)
  click('MSVC');click('Warnings');click('Debug info');click('Incremental');click('Optimize code')
  click('Help')
  check('Mouse Help opens exact compiler topic','Compiler flags' in screen.text() and 'Warnings:' in screen.text())
  send(b'\x1b',.4)
  check('Help return retains clicked option controls','[X] Debug info' in screen.text() and '[X] Optimize code' in screen.text())
  (work/'before-ok.screen').write_text(screen.text())
  click('OK')
  args=build()
  check('Mouse OK applies radio and checkbox values to actual argv',all(x in args for x in ['-comp=msvc','-w0','-es2','-b','-inc','-O2']) and '-comp=gcc' not in args)
  for caption,compiler_name in [('MinGW64','mingw64'),('GCC','gcc')]:
   send(b'\x1bo');send(b'c',.4)
   click(caption)
   click('OK')
   args=build()
   check('Mouse item '+caption+' reaches exact compiler argv','-comp='+compiler_name in args)
  check('Repeated modal mouse workflow preserves source bytes',target.read_bytes()==b'procedure main()\nreturn\n')

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
