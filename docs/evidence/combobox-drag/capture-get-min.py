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
 key('alt+o');key('s')
 (base/'caret.json').write_text(json.dumps({'controls':[{'type':'get','row':0,'col':0,'variable':'cVar1','items':'One,Two','width':10,'when':'Start_'+('long_expression_'*8)+'_TAIL'}]}))
 key('F12');text('caret.json');key('Tab');key('Return');key('Tab');key('Tab')
 cmd('import','-window','root','/downloads/hbide-get-drag-min-before.png')
 # Model20x6 selected, dialog left39/top13: handle row19 col59.
 cmd('xdotool','mousemove','499','274');cmd('xdotool','mousedown','1');time.sleep(.2)
 cmd('xdotool','mousemove','409','274');time.sleep(.5);cmd('xdotool','mouseup','1');time.sleep(.5)
 key('F10')
 after=json.loads((base/'caret.json').read_text());print('AFTER',after['controls'][0])
 cmd('import','-window','root','/downloads/hbide-get-drag-min-resized.png')
 key('ctrl+z');key('F10')
 undo=json.loads((base/'caret.json').read_text());print('UNDO',undo['controls'][0])
 key('ctrl+y');key('F10')
 redo=json.loads((base/'caret.json').read_text());print('REDO',redo['controls'][0])
 cmd('import','-window','root','/downloads/hbide-get-drag-min-redo.png')
 assert after['controls'][0]['width']==1
 assert undo['controls'][0]['width']==10
 assert after['controls']==redo['controls']
 assert all(d['controls'][0]['row']==0 and d['controls'][0]['col']==0 for d in [after,undo,redo])
 key('F12');key('Tab');key('Return');key('F10')
 reloaded=json.loads((base/'caret.json').read_text())
 assert reloaded['controls']==redo['controls']
 print('RELOADED width',reloaded['controls'][0]['width'])
 (base/'drag-results.json').write_text(json.dumps({'after':after,'undo':undo,'redo':redo},indent=2))
 print('evidence',base)
finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
