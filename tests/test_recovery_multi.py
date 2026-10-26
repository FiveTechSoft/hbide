import os,pty,time,select,signal,fcntl,termios,struct,tempfile,pathlib,sys
BIN = os.path.abspath(sys.argv[1])
# Linux-only modal E2E; argument is the freshly built IDE executable.
rec=tempfile.mkdtemp(prefix='hbide-multi-'); home=tempfile.mkdtemp(prefix='hbide-multi-home-')
for name in ['a','b']:
 pathlib.Path('/tmp/hbide-multi-'+name+'.prg').unlink(missing_ok=True)
for name,content in [('a','precious-A'),('b','precious-B')]:
 pathlib.Path(rec,name+'.journal').write_text(content)
 pathlib.Path(rec,name+'.target').write_text('/tmp/hbide-multi-'+name+'.prg')
env=dict(os.environ,HOME=home,HBIDE_RECOVERY_DIR=rec,TERM='xterm')
pid,fd=pty.fork()
if pid==0:os.execve(BIN,[BIN],env)
fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
def pump(t):
 end=time.time()+t;out=b''
 while time.time()<end:
  if select.select([fd],[],[],.1)[0]:
   try:out+=os.read(fd,65536)
   except OSError:break
 return out
try:
 first=pump(2.5);pathlib.Path('/tmp/bat/multi-first.raw').write_bytes(first);assert b'Interrupted' in first or b'interrupted session' in first
 os.write(fd,b'\r');second=pump(.6)
 assert b'interrupted session' in second
 os.write(fd,b'\r');guard=pump(.6)
 assert b'Unsaved changes' in guard and b'Cancel' in guard
 os.write(fd,b'\x1b');pump(.6) # cancel replacing A with B
 journals=list(pathlib.Path(rec).glob('*.journal'))
 assert pathlib.Path(rec,'a.journal').read_text()=='precious-A'
 assert pathlib.Path(rec,'b.journal').read_text()=='precious-B'
 # A is still current. Saving must target A, never B.
 os.write(fd,b'\x1bOQ');pump(.8)
 assert pathlib.Path('/tmp/hbide-multi-a.prg').read_text()=='precious-A'
 assert pathlib.Path(rec,'b.journal').read_text()=='precious-B'
 assert not pathlib.Path(rec,'a.journal').exists()
 print('PASS recover A; attempt B; Cancel protects A; save A exact; B untouched')
finally:
 os.kill(pid,signal.SIGKILL);os.waitpid(pid,0);os.close(fd)
