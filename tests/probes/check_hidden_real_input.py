"""Send one actual PTY key during bounded hidden-NUL input wait."""
import os,pathlib,pty,select,signal,subprocess,sys,tempfile,time,json
exe=os.path.abspath(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='hbide-hidden-real-') as tmp:
    result=pathlib.Path(tmp)/'result.json';pid,fd=pty.fork()
    if pid==0:os.execve(exe,[exe,str(result)],dict(os.environ,TERM='xterm'))
    sent=False;status=None;end=time.monotonic()+6
    try:
        while time.monotonic()<end:
            if not sent and pathlib.Path(str(result)+'.ready').exists():os.write(fd,b'z');sent=True
            if select.select([fd],[],[],.02)[0]:
                try:data=os.read(fd,65536)
                except OSError:break
                if b'\x1b[6n' in data:os.write(fd,b'\x1b[25;1R')
                if b'\x1b[18t' in data:os.write(fd,b'\x1b[8;25;80t')
            done,status=os.waitpid(pid,os.WNOHANG)
            if done:break
        else:raise RuntimeError('probe timed out')
        if status is None or not done:_,status=os.waitpid(pid,0)
        r=json.loads(result.read_text());r.update(sent_key=122,process_exit=os.waitstatus_to_exitcode(status))
        print(json.dumps(r));assert r['hidden_key']==0 and r['visible_key']==122 and r['process_exit']==0
    finally:
        try:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
        except ProcessLookupError:pass
        except ChildProcessError:pass
        os.close(fd)
