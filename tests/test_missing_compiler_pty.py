"""Missing compiler never launches or replaces an existing executable. Linux PTY."""
import subprocess,hashlib,shlex
import os,pty,sys,struct,fcntl,termios,select,time,signal,tempfile,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]; ROWS,COLS=(25,80) if '--small' in sys.argv else (40,120)
text=(ROOT/'tests/test_designer_pty.py').read_text();exec(text[text.index('class Scr:'):text.index('home = tempfile.')])
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-source-run-'));(work/'home').mkdir();(work/'rec').mkdir()
exe=os.environ.get('HBIDE_BIN',str(ROOT/'hbide'));results=[]
success_long='--success-long-output' in sys.argv
recover_promotion='--promotion-retry' in sys.argv
promotion='--promotion-failure' in sys.argv or recover_promotion
restore='--restore' in sys.argv
color_output='--color-output' in sys.argv
horizontal='--horizontal' in sys.argv
long_output='--long-output' in sys.argv
diagnostic='--missing-output-diagnostic' in sys.argv or long_output
missing_output='--missing-output' in sys.argv or diagnostic
failed_output='--failed-output' in sys.argv
fake=missing_output or failed_output or promotion or success_long
for kind in ['autorun']:
 target=work/'missing.prg';value=work/'stale-launched.txt'
 target.write_text('procedure main()\n hb_MemoWrit("'+str(value)+'", "stale")\nreturn\n')
 compiler=__import__('shutil').which('hbmk2')
 subprocess.run([compiler,str(target),'-quiet','-o'+str(work/'missing')],check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 previous=(work/'missing').read_bytes()
 if promotion:
  (work/'missing').unlink();(work/'missing').mkdir();(work/'missing/keep').write_bytes(b'original directory member')
 if restore or recover_promotion or success_long:target.write_text(target.read_text().replace('"stale"','"fresh"'))
 original=target.read_bytes()
 (work/'empty-path').mkdir()
 if fake:
  launcher=work/'empty-path/hbmk2'
  launcher.write_text('#!/bin/sh\nfor arg do case "$arg" in -o*) out=${arg#-o};; esac; done\nprintf \"%s\\n\" "$out" >> '+shlex.quote(str(work/'invocations'))+'\n'+('printf \"broken output\" > "$out"\nexit 7\n' if failed_output else 'exit 0\n'))
  if promotion:
   launcher.write_text(launcher.read_text().replace('exit 0\n','printf "new output" > "$out"\nexit 0\n'))
  if recover_promotion:
   launcher.write_text('#!/bin/sh\nfor arg do case "$arg" in -o*) out=${arg#-o};; esac; done\nprintf "%s\\n" "$out" >> '+shlex.quote(str(work/'invocations'))+'\nPATH='+shlex.quote(os.environ['PATH'])+'; export PATH\nexec '+shlex.quote(compiler)+' "$@"\n')
  if diagnostic:
   launcher.write_text(launcher.read_text().replace('exit 0\n', 'printf \"%s(3) Error E0030 simulated fixture error\\n\" '+shlex.quote(str(target))+'\nexit 0\n'))
  if long_output:
   launcher.write_text(launcher.read_text().replace('printf \"%s(3)', 'i=0; while [ "$i" -lt 60 ]; do printf "compiler progress %s\\n" "$i"; i=$((i+1)); done\n'+ 'printf \"%s(3)'))
  if success_long:
   launcher.write_text('#!/bin/sh\ni=0; while [ "$i" -lt 60 ]; do printf "compiler progress %s\\n" "$i"; i=$((i+1)); done\nPATH='+shlex.quote(os.environ['PATH'])+'; export PATH\nexec '+shlex.quote(compiler)+' "$@"\n')
  if color_output:
   launcher.write_text(launcher.read_text().replace('Error E0030', '\\033[31mError\\033[0m E0030'))
  launcher.chmod(0o700)
 pid,fd=pty.fork()
 if pid==0:
  os.chdir(work);os.execve(exe,[exe],dict(os.environ,TERM='xterm',HOME=str(work/'home'),HBIDE_RECOVERY_DIR=str(work/'rec'),PATH=str(work/'empty-path')))
 fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',ROWS,COLS,0,0));screen=Scr()
 def pump(secs):
  until=time.monotonic()+secs;b=b''
  while time.monotonic()<until:
   r,_,_=select.select([fd],[],[],.05)
   if not r:continue
   try:d=os.read(fd,65536)
   except OSError:break
   b+=d
   if b'\x1b[6n' in d:os.write(fd,('[%d;1R'%ROWS).encode())
   if b'\x1b[18t' in d:os.write(fd,('[8;%d;%dt'%(ROWS,COLS)).encode())
  screen.feed(b)
 def send(b,wait=.35):os.write(fd,b);pump(wait)
 def check(name,ok):results.append(bool(ok));print(('PASS' if ok else 'FAIL'),name,flush=True)
 try:
  pump(1.5);send(b'\x1bf');send(b'o');send(str(target).encode());send(b'\r',.6)
  for attempt in range(1 if promotion else 2):
   send(b'\x1br');send(b's',.7)
   if success_long:
    check('successful real build opens scrollable output','Output - arrows scroll' in screen.text())
    check('viewer does not prematurely launch program',not value.exists())
    check('previous executable stays exact until viewer exits',(work/'missing').read_bytes()==previous)
    send(b'\x1b[F',.3)
    check('End exposes real compiler completion','Done.' in screen.text())
    send(b'\x1b',.7)
    check('Esc viewer exit still runs fresh program',value.exists() and value.read_text()=='fresh')
    check('success promotes different executable',(work/'missing').read_bytes()!=previous)
    check('successful build source byte exact',target.read_bytes()==original)
    check('successful build has no leftover temp',not [p for p in work.iterdir() if p.name.startswith('missing.') and p!=target])
    check('success never shows failure alert','Build failed' not in screen.text())
    break
   if promotion:
    check('build output ready','Build OK:' in screen.text() or (recover_promotion and 'Done.' in screen.text()));send(b'\r',.4)
    (work/'promotion.screen').write_text(screen.text())
    check('replacement failure visible','could not replace' in screen.text())
    check('replacement failure names retained output','new executable kept at' in screen.text() and (work/'invocations').read_text().strip() in ''.join(line[29:91].strip() for line in screen.text().splitlines()))
    check('retained output path has its own complete line',any((work/'invocations').read_text().strip() in line for line in screen.text().splitlines()))
    send(b'\r',.4)
    check('blocked destination directory untouched',(work/'missing/keep').read_bytes()==b'original directory member')
    tmp=pathlib.Path((work/'invocations').read_text().strip())
    retained=tmp.read_bytes()
    check('complete output retained after failed promotion',len(retained)>1000 if recover_promotion else retained==b'new output')
    check('source remains byte exact after failed promotion',target.read_bytes()==original)
    check('no stale executable launched',not value.exists())
    if recover_promotion:
     (work/'missing/keep').unlink();(work/'missing').rmdir()
     send(b'\x1br');send(b's',.7)
     until=time.monotonic()+20
     while not ('Done.' in screen.text() or 'Build OK:' in screen.text()) and time.monotonic()<until:pump(.2)
     check('retry with unblocked destination builds','Done.' in screen.text() or 'Build OK:' in screen.text())
     send(b'\r',.7)
     check('retry launches fresh real compiler result',value.exists() and value.read_text()=='fresh')
     check('retry promotes new executable',(work/'missing').is_file() and (work/'missing').read_bytes()!=previous)
     check('retained first output stays exact',tmp.read_bytes()==retained)
     check('retry preserves source',target.read_bytes()==original)
     check('retry has no unnamed temporary outputs',len([p for p in work.iterdir() if p.name.startswith('missing.') and p!=target])==1)
    break
   if long_output:
    check('long build output opens scrollable viewer','Output - arrows scroll' in screen.text())
    send(b'\x1b[F',.4)
    if color_output:
     (work/('color-'+str(attempt)+'.screen')).write_text(screen.text())
     check('viewer hides GCC color control notation','[31m' not in screen.text() and '[0m' not in screen.text())
    check('End reveals last compiler diagnostic','Error E0030' in screen.text())
    if horizontal:
     for _ in range(12):send(b'\x1b[C'*8,.05)
     check('Right reveals exact diagnostic tail','simulated fixture error' in screen.text())
     for _ in range(12):send(b'\x1b[D'*8,.05)
     check('Left restores diagnostic source path',str(target) in screen.text())
    send(b'\x1b',.4)
   elif diagnostic:
    check('compiler diagnostic output visible','Error E0030' in screen.text())
    send(b'\r',.4)
   (work/('failure-'+str(attempt)+'.screen')).write_text(screen.text())
   check('failed build reports preserved executable','Build failed (status ' in screen.text() and (not fake or 'status '+('7' if failed_output else '0')+')' in screen.text()) and 'previous' in screen.text() and 'executable left untouched' in screen.text())
   if fake:
    calls=(work/'invocations').read_text().splitlines() if (work/'invocations').exists() else []
    check('compiler actually invoked once per attempt',len(calls)==attempt+1 and all(str(work) in c for c in calls))
   send(b'\r',.4)
   if diagnostic:check('failed build navigates to first error despite previous executable',bool(re.search(r'row:\s*3\b',screen.text())) and 'ERROR' in screen.text())
   check('previous executable byte exact',(work/'missing').read_bytes()==previous)
   check('stale executable never launched',not value.exists())
   check('source byte exact',target.read_bytes()==original)
   check('no sibling build temp remains',not [p for p in work.iterdir() if p.name.startswith('missing.') and p!=target])
  if restore:
   launcher=work/'empty-path/hbmk2'
   launcher.write_text('#!/bin/sh\nPATH='+shlex.quote(os.environ['PATH'])+'; export PATH\nexec '+shlex.quote(compiler)+' "$@"\n')
   launcher.chmod(0o700)
   send(b'\x1br');send(b's',.5)
   until=time.monotonic()+20
   while not ('Done.' in screen.text() or 'Build OK:' in screen.text()) and time.monotonic()<until:pump(.2)
   check('restored compiler produces successful output','Done.' in screen.text() or 'Build OK:' in screen.text())
   send(b'\r',.7)
   check('same session launches fresh executable only',value.exists() and value.read_text()=='fresh')
   check('fresh executable replaces old bytes',(work/'missing').read_bytes()!=previous)
   check('rebuild keeps source exact',target.read_bytes()==original)
   send(b'\x1bw');send(b'm',.4)
   check('successful retry clears old failure diagnostics','No compiler messages' in screen.text())
   send(b'\r',.3)
  check('editor remains usable after repeated failure','Edit' in screen.text())

 finally:
  w=os.waitpid(pid,os.WNOHANG)
  if w[0]==0:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
  os.close(fd)
print('TOTAL',sum(results),'PASS',len(results)-sum(results),'FAIL; evidence',work)
sys.exit(not all(results))
