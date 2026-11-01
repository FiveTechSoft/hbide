"""Real-key isolated bridge research, including a measured timeout limitation."""
import os,pathlib,pty,select,signal,sys,tempfile,time,json,fcntl,termios,struct
exe=os.path.abspath(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='hbide-frame-bridge-') as tmp:
 result=pathlib.Path(tmp)/'result.json';pid,fd=pty.fork()
 if pid==0:os.execve(exe,[exe,str(result)],dict(os.environ,TERM='xterm',HARBOUR='//GTTRM:UTF8'))
 fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',25,80,0,0))
 sent=False;status=None;done=0;end=time.monotonic()+6;stream=b''
 try:
  while time.monotonic()<end:
   if not sent and pathlib.Path(str(result)+'.ready').exists():os.write(fd,b'z');sent=True
   if select.select([fd],[],[],.01)[0]:
    try:data=os.read(fd,65536)
    except OSError:break
    stream+=data
    if b'\x1b[6n' in data:os.write(fd,b'\x1b[25;1R')
    if b'\x1b[18t' in data:os.write(fd,b'\x1b[8;25;80t')
   done,status=os.waitpid(pid,os.WNOHANG)
   if done:break
  else:raise RuntimeError('probe timed out')
  if not done:_,status=os.waitpid(pid,0)
  r=json.loads(result.read_text());r.update(process_exit=os.waitstatus_to_exitcode(status),real_key_sent=sent,app_marker_in_terminal=b'APP-RESEARCH-WAIT' in stream,debugger_marker_in_terminal=b'DEBUGGER-RESEARCH' in stream)
  checks={k:r[k]==v for k,v in {'poll':0,'shows_after_poll':0,'real_key':122,'last_key':122,'timeout_key':0,'last_after_timeout':0,'hidden_buffer_preserved':True,'shows':2,'debugger_buffer_restored':True,'extra_key':0,'process_exit':0,'real_key_sent':True,'app_marker_in_terminal':True,'debugger_marker_in_terminal':True}.items()}
  checks['timeout_waits_twice']=r['timeout_elapsed_ms']>=80
  print(json.dumps({'checks':checks,'results':r,'scope':'Actual PTY key, not visual inspection, full debugger integration, arbitrary masks or policy acceptance.'},indent=2));assert all(checks.values())
 finally:
  try:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  except (ProcessLookupError,ChildProcessError):pass
  os.close(fd)
