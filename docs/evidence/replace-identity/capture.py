import os,subprocess,time,signal,tempfile,pathlib,json
base=pathlib.Path(tempfile.mkdtemp(prefix='hbide-animate-visual-'));(base/'home').mkdir();(base/'rec').mkdir()
(base/'home/.config/xfce4/terminal').mkdir(parents=True)
(base/'home/.config/xfce4/terminal/terminalrc').write_text('[Configuration]\nMiscCursorBlinks=FALSE\nShortcutsNoMenukey=TRUE\nMiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK\n')
env=dict(os.environ,DISPLAY=':93',LANG='C.UTF-8',TERM='xterm',PATH='/home/sandbox/harbour/bin/linux/gcc:'+os.environ['PATH'],HOME=str(base/'home'),HBIDE_RECOVERY_DIR=str(base/'rec'),HBIDE_UTF8='0')
x=subprocess.Popen(['Xvfb',':93','-screen','0','1400x900x24'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def cmd(*a):return subprocess.run(a,env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def key(k):cmd('xdotool','key','--clearmodifiers',k);time.sleep(.5)
def text(t):cmd('xdotool','type','--clearmodifiers','--delay','1',t);time.sleep(.15)
def command(t):text(t);key('Return')

t=None;v=None
try:
 time.sleep(.4)
 t=subprocess.Popen(['xfce4-terminal','--disable-server','--hide-menubar','--hide-toolbar','--hide-scrollbar','--geometry=120x40+0+0','--font=DejaVu Sans Mono 12','--execute','/home/sandbox/hbide/hbide'],env=env,cwd=base,start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(4);wins=cmd('xdotool','search','--class','Xfce4-terminal').stdout.decode().splitlines();wid=max(wins,key=lambda w:int(cmd('xdotool','getwindowgeometry','--shell',w).stdout.decode().split('WIDTH=')[1].splitlines()[0])*int(cmd('xdotool','getwindowgeometry','--shell',w).stdout.decode().split('HEIGHT=')[1].splitlines()[0]));cmd('xdotool','windowmap',wid);time.sleep(.5);cmd('xdotool','windowfocus',wid);time.sleep(.5)
 target=base/'identity.prg';target.write_bytes(b'alpha')
 key('alt+f');key('o');text(str(target));key('Return');key('alt+e');key('a');text('alpha');key('Tab');text('alpha');key('Return')
 cmd('import','-window','root','/downloads/hbide-replace-identity-native-count.png')
 key('Return');key('alt+f');key('c');assert target.read_bytes()==b'alpha'
 cmd('import','-window','root','/downloads/hbide-replace-identity-native-closed.png')
 pathlib.Path('/downloads/hbide-replace-identity-native-results.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd='/home/sandbox/hbide',text=True).strip(),'dirty':True,'disk_exact':'alpha','scope':'Native120x40 identity replacement counts1 then closes without save prompt; pixels require inspection.'},indent=2))
 print('evidence',base)

finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
