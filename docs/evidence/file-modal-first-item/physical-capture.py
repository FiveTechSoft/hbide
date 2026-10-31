import os,subprocess,time,signal,tempfile,pathlib,json
base=pathlib.Path(tempfile.mkdtemp(prefix='hbide-animate-visual-'));(base/'home').mkdir();(base/'rec').mkdir()
(base/'home/.config/xfce4/terminal').mkdir(parents=True)
(base/'home/.config/xfce4/terminal/terminalrc').write_text('[Configuration]\nMiscCursorBlinks=FALSE\nShortcutsNoMenukey=TRUE\nMiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK\n')
env=dict(os.environ,DISPLAY=':92',LANG='C.UTF-8',TERM='xterm',PATH='/home/sandbox/harbour/bin/linux/gcc:'+os.environ['PATH'],HOME=str(base/'home'),HBIDE_RECOVERY_DIR=str(base/'rec'),HBIDE_UTF8='0')
x=subprocess.Popen(['Xvfb',':92','-screen','0','1400x900x24'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def cmd(*a):return subprocess.run(a,env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def key(k):cmd('xdotool','key','--clearmodifiers',k);time.sleep(.5)
def text(t):cmd('xdotool','type','--clearmodifiers','--delay','1',t);time.sleep(.15)
def command(t):text(t);key('Return')

t=None;v=None
try:
 time.sleep(.4)
 t=subprocess.Popen(['xfce4-terminal','--disable-server','--hide-menubar','--hide-toolbar','--hide-scrollbar','--geometry=120x40+0+0','--font=DejaVu Sans Mono 12','--execute','/home/sandbox/hbide/hbide'],env=env,cwd=base,start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(4);wid=cmd('xdotool','search','--class','Xfce4-terminal').stdout.decode().splitlines()[-1];cmd('xdotool','windowfocus',wid);time.sleep(.5)
 target=base/'aaa.prg';other=base/'saved with spaces.prg'
 target.write_bytes(b'AAA first\r\nreturn\n');other.write_bytes(b'LONG second\nreturn\n')
 (base/'aaa.hbp').write_text('aaa.prg\n');(base/'bbb.hbp').write_text('"saved with spaces.prg"\n')
 key('alt+f');key('o');key('Tab');key('Home');key('Down')
 cmd('import','-window','root','/downloads/hbide-file-physical-list.png')
 key('Home');key('Down');key('Tab');key('Return')
 key('alt+p');key('o');cmd('xdotool','mousemove','--sync','435','314');cmd('xdotool','click','1');time.sleep(.5)
 cmd('import','-window','root','/downloads/hbide-project-physical-list.png')
 cmd('xdotool','mousemove','--sync','681','504');cmd('xdotool','click','1');time.sleep(.5)
 cmd('import','-window','root','/downloads/hbide-project-physical-opened.png')
 assert target.read_bytes()==b'AAA first\r\nreturn\n'
 assert other.read_bytes()==b'LONG second\nreturn\n'
 print('evidence',base)

finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
