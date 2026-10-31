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
 fixture=base/'fixture.json'
 fixture.write_text(json.dumps({'name':'Fixture','caption':'Fixture','width':41,'height':14,'controls':[{'type':'get','row':10,'col':28,'width':10,'variable':'CVAR1'}]}))
 key('alt+o');key('s');key('F12');key('ctrl+y');text(str(fixture));key('Return');key('Return');key('Tab')
 key('F4');key('F7');key('Down');key('Right')
 cmd('import','-window','root','/downloads/hbide-snap-edge-native-moved.png')
 key('F10');moved=json.loads(fixture.read_text())
 assert moved['controls'][0]['row']==11 and moved['controls'][0]['col']==29,moved
 key('ctrl+z')
 cmd('import','-window','root','/downloads/hbide-snap-edge-native-undo.png')
 key('F10');undo=json.loads(fixture.read_text())
 assert undo['controls'][0]['row']==10 and undo['controls'][0]['col']==28,undo
 key('ctrl+y');key('F10');redo=json.loads(fixture.read_text());assert redo==moved
 pathlib.Path('/downloads/hbide-snap-edge-native-results.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd='/home/sandbox/hbide',text=True).strip(),'models':{'moved':moved,'undo':undo,'redo':redo},'scope':'NativeLinux120x40arrows SnapON oddedge GETfit,UndoRedo exact; not drag/pixelsuntilinspection/Windows.'},indent=2))
 print('evidence',base)

finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
