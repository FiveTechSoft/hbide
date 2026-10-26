#include "inkey.ch"
PROCEDURE Main()
   LOCAL h:=FoxState(),i,c,w
   FoxKey(h,K_DOWN)
   Assert(h['row']==2,'Browse down')
   FoxKey(h,K_END);Assert(h['row']==4,'Browse end')
   FOR i:=1 TO 20;FoxAction(h,5,1);NEXT
   Assert(Len(h['data'])==24 .AND. h['top']==12,'append scrolls viewport')
   FoxKey(h,K_HOME);Assert(h['row']==1 .AND. h['top']==1,'home resets viewport')
   FoxKey(h,K_F4);Assert(h['view']=='screen','window cycle')
   hb_keyPut(K_ESC);FoxButton(h)
   Assert(Empty(h['controls']),'cancel button does not create')
   hb_keyPut(K_ENTER);FoxButton(h)
   Assert(Len(h['controls'])==1,'accept button creates')
   FoxKey(h,K_RIGHT);FoxKey(h,K_DOWN)
   Assert(h['cx']==9 .AND. h['cy']==8,'placement arrows')
   h['view']:='browse';h['row']:=1
   c:=h['data',1,1]
   hb_keyPut(Asc('X'));hb_keyPut(K_ESC);FoxEditCell(h)
   Assert(h['data',1,1]==c,'edit cancel preserves cell')
   hb_keyPut(Asc('X'));hb_keyPut(K_ENTER);FoxEditCell(h)
   Assert(h['data',1,1]==c+'X','edit accept updates cell')
   h['view']:='command';h['input']:='erase all'
   FoxKey(h,K_ENTER)
   Assert(Len(h['data'])==24 .AND. h['view']=='command','command not arbitrary execution')
   FoxKey(h,K_F10);FoxKey(h,K_RIGHT)
   Assert(h['menu']==2,'menu arrows')
   FoxKey(h,K_ESC);Assert(h['menu']==0,'escape closes menu')
   // Window move/size (Ctrl+F7 / Ctrl+F8)
   h:=FoxState()
   w:=h['wins','browse']
   Assert(w[1]==1 .AND. w[2]==0 .AND. w[3]==18 .AND. w[4]==60,'default browse geometry')
   Assert(FoxViewRows(h)==13,'default visible rows')
   FoxKey(h,K_CTRL_F7)
   Assert(h['mode']=='move','ctrl+f7 enters move')
   FoxKey(h,K_RIGHT);FoxKey(h,K_DOWN)
   Assert(w[1]==2 .AND. w[2]==1 .AND. w[3]==19 .AND. w[4]==61,'move shifts window, size preserved')
   Assert(h['row']==1 .AND. Len(h['data'])==4,'move preserves content')
   FoxKey(h,K_ENTER)
   Assert(h['mode']=='','enter ends move')
   FoxKey(h,K_CTRL_F8)
   Assert(h['mode']=='size','ctrl+f8 enters size')
   FoxKey(h,K_LEFT);FoxKey(h,K_UP)
   Assert(w[3]==18 .AND. w[4]==60,'size adjusts corner')
   Assert(FoxViewRows(h)==12,'visible rows follow size')
   FoxKey(h,K_ESC);Assert(h['mode']=='','escape ends size')
   FoxKey(h,K_CTRL_F8)
   FOR i:=1 TO 100;FoxKey(h,K_RIGHT);FoxKey(h,K_DOWN);NEXT
   Assert(w[4]==79 .AND. w[3]==23,'size clamps to desktop')
   FoxKey(h,K_ESC)
   FoxKey(h,K_CTRL_F7)
   FOR i:=1 TO 100;FoxKey(h,K_LEFT);FoxKey(h,K_UP);NEXT
   Assert(w[1]==1 .AND. w[2]==0,'move clamps to desktop')
   FoxKey(h,K_ESC)
   // Below minimum size the window stops shrinking
   FoxKey(h,K_CTRL_F8)
   FOR i:=1 TO 100;FoxKey(h,K_LEFT);FoxKey(h,K_UP);NEXT
   Assert(w[3]-w[1]+1==7 .AND. w[4]-w[2]+1==40,'size clamps to minimum')
   FoxKey(h,K_ESC)
   // Menu Window > Move / Size enter the same modes
   h:=FoxState()
   FoxAction(h,7,5);Assert(h['mode']=='move','menu Window Move')
   FoxKey(h,K_ENTER)
   FoxAction(h,7,6);Assert(h['mode']=='size','menu Window Size')
   FoxKey(h,K_ESC)
   // Screen shrink: cursor clamps into view, control coordinates untouched
   h:=FoxState();h['view']:='screen';h['cx']:=50;h['cy']:=20
   AAdd(h['controls'],{20,50,'OK',.F.,'v',.F.})
   w:=h['wins','screen']
   FoxKey(h,K_CTRL_F8)
   FOR i:=1 TO 60;FoxKey(h,K_LEFT);FoxKey(h,K_UP);NEXT
   FoxKey(h,K_ESC)
   Assert(h['cx']<=w[4]-2 .AND. h['cy']<=w[3]-2,'cursor clamped inside shrunk canvas')
   Assert(h['controls',1,1]==20 .AND. h['controls',1,2]==50,'control keeps coordinates when canvas shrinks')
   // Move shifts controls WITH the window (delta), size does not
   FoxKey(h,K_CTRL_F7)
   FoxKey(h,K_DOWN);FoxKey(h,K_RIGHT)
   FoxKey(h,K_ESC)
   Assert(h['controls',1,1]==21 .AND. h['controls',1,2]==51,'move shifts control with window')
   hb_MemoWrit('/tmp/hbide-foxpro-demo-tests.txt','PASS Browse/scroll/memory edit/placement/button/menus/no evaluation/move/size')
   RETURN
PROCEDURE Assert(l,c)
   IF ! l
      hb_MemoWrit('/tmp/hbide-foxpro-demo-tests.txt','FAIL '+c)
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
