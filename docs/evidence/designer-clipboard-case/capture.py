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
 key('alt+o');key('s');key('F2');key('m');key('Return')
 key('F4');key('F6');key('Down');key('Down');key('Return');key('ctrl+y');text('NVAR1');key('Return');key('F6')
 key('ctrl+c');key('ctrl+v')
 cmd('import','-window','root','/downloads/hbide-clipboard-case-native-paste.png')
 key('F10');key('Return');key('Return')
 model=json.loads((base/'mydialog.json').read_text())
 assert [c['variable'] for c in model['controls']]==['NVAR1','nVar2'],model
 key('ctrl+z')
 cmd('import','-window','root','/downloads/hbide-clipboard-case-native-undo.png')
 key('F10');model_undo=json.loads((base/'mydialog.json').read_text())
 assert [c['variable'] for c in model_undo['controls']]==['NVAR1'],model_undo
 key('ctrl+y');key('F10');model_redo=json.loads((base/'mydialog.json').read_text())
 assert model_redo==model,model_redo
 pathlib.Path('/downloads/hbide-clipboard-case-native-results.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd='/home/sandbox/hbide',text=True).strip(),'models':{'paste':model,'undo':model_undo,'redo':model_redo},'scope':'Native Linux terminal120x40 keyboard input and full screenshots. Not Windows/all controls.'},indent=2))
 print('evidence',base)

finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
