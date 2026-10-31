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
 target=base/'object.prg';value=base/'value.txt';member='LongMember'*6+'X'
 target.write_text('procedure main()\n   local v := MakeValue()\n   hb_MemoWrit( "'+str(value)+'", hb_ntos( v:'+member+' ) )\nreturn\nfunction MakeValue()\n   local oClass:=HBClass():New("LongFixture")\n   oClass:AddData("'+member+'",123456789)\n   oClass:Create()\nreturn oClass:Instance()\n')
 key('alt+f');key('o');text(str(target));key('Return');key('Down');key('Down');key('F9');key('alt+r');key('d');key('F5')
 command('monitor local on');command('window select monitor');key('Return');key('Return')
 key('Return');text('987654321');key('Return')
 cmd('import','-window','root','/downloads/hbide-long-object-native-edited.png')
 key('Return');text('99');key('Escape')
 cmd('import','-window','root','/downloads/hbide-long-object-native-cancel.png')
 key('Escape');key('Escape');key('F5');time.sleep(.7)
 assert value.read_text()=='987654321',value.read_text()
 pathlib.Path('/downloads/hbide-long-object-native-results.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd='/home/sandbox/hbide',text=True).strip(),'member':member,'actual':value.read_text(),'scope':'Native Linux terminal120x40valid61char member edited987654321/cancel99/Resume exact. Not Windows/all geometry.'},indent=2))
 print('evidence',base)

finally:
 base.chmod(0o700)
 if v and v.poll() is None:v.terminate();v.wait(timeout=3)
 if t:
  try:os.killpg(t.pid,signal.SIGKILL);t.wait(timeout=3)
  except ProcessLookupError:pass
 x.terminate();x.wait(timeout=3)
