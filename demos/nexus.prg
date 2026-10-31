// NEXUS: interactive showcase using hbide's own windows and GET buttons.
// All records are fictional. No network, payments or production data.
#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
static s_get := {}
static s_nCycle := 0, s_cNote := 'Ready. Explore the demo with Tab, Enter or the mouse.'
static s_a := { { 'NOVA STUDIO', 'Design system', 12800, 'READY' }, ;
 { 'ATLAS LAB', 'Data platform', 9600, 'REVIEW' }, ;
 { 'ORBIT WORKS', 'Client portal', 18400, 'ACTIVE' }, ;
 { 'LUMA DIGITAL', 'Mobile launch', 7200, 'READY' } }
procedure Main()
 local cSave := SaveScreen(), nCursor := SetCursor( SC_NONE ), GetList := {}, l1:=.F.,l2:=.F.,l3:=.F.,l4:=.F.,l5:=.F.,o, nMask, cOldCP:=hb_cdpSelect(), nMsg:=Set(_SET_MESSAGE), cOldShadow:=HBBtnShadowColor()
 hb_cdpSelect('UTF8')
 SetMode(40,120)
 Set(_SET_MESSAGE,39)
 Set(_SET_INSERT,.T.)
 o:=HbWindow():New(1,1,37,117,' NEXUS | Harbour business studio ','W+/B')
 o:bInit:={|| Paint()}
 o:Show()
 HBBtnShadowColor('N/W')
 @ 34, 5 GET l1 PUSHBUTTON CAPTION ' Run scenario ' STYLE "[]" COLOR 'W+/BG,W+/B,N/BG,Y+/BG' STATE {|| Simulate(),Paint()}
 @ 34, 30 GET l2 PUSHBUTTON CAPTION ' Inspect data ' STYLE "[]" COLOR 'N/W,W+/B,N/W,R/W' STATE {|| Inspect(),Paint()}
 @ 34, 54 GET l3 PUSHBUTTON CAPTION ' Export CSV ' STYLE "[]" COLOR 'N/W,W+/B,N/W,R/W' STATE {|| ExportDemo(),Paint()}
 @ 34, 77 GET l4 PUSHBUTTON CAPTION ' Reset ' STYLE "[]" COLOR 'N/W,W+/B,N/W,R/W' STATE {|| ResetDemo(),Paint()}
 @ 34, 95 GET l5 PUSHBUTTON CAPTION ' Exit ' STYLE "[]" COLOR 'N/W,W+/B,N/W,R/W' STATE {|| o:End()}
 s_get:=GetList
 nMask:=Set(_SET_EVENTMASK,INKEY_ALL)
 o:Activate(GetList)
 Set(_SET_EVENTMASK,nMask)
 Set(_SET_MESSAGE,nMsg)
 HBBtnShadowColor(cOldShadow)
 hb_cdpSelect(cOldCP)
 RestScreen(0,0,MaxRow(),MaxCol(),cSave)
 SetCursor(nCursor)
return
static procedure Panel(t,l,b,r,title,color)
 local w:=HbWindow():New(t,l,b,r,title,color)
 w:lShadow:=.T.
 w:Show(.F.)
return
static procedure Put(r,c,t,col)
 hb_DispOutAt(r,c,t,col)
return
static procedure Paint()
 local g,n,total:=0,ready:=0,v, bars:={8,12,10,17,14,21,25,19,28,32}, aMon:={'J','F','M','A','M','J','J','A','S','O'}
 DispBegin()
 hb_Scroll(0,0,39,119,,, 'W/B')
 Put(0,0,PadR('  hbide   /   DEMO LAB',87)+'HARBOUR  |  NATIVE GUI  |  120x40','N/W')
 hb_DispBox(1,1,37,117,HB_B_DOUBLE_UNI,'W+/B')
 Put(2,4,'N E X U S','W+/B')
 Put(2,79,'WORKSPACE  /  EXECUTIVE OVERVIEW','BG+/B')
 Put(3,4,'Ideas into working software. Built with Harbour + hbide.','W/B')
 Put(3,91,'FICTIONAL DEMO DATA','Y+/B')
 hb_Scroll(5,3,31,23,,, 'W/BG')
 Put(6,5,'N / OPERATIONS','W+/BG')
 Put(8,4,PadR(' DEMO FEATURES',19),'N/W')
 Put(10,5,'Live summary','W+/BG')
 Put(12,5,'Portfolio table','W+/BG')
 Put(14,5,'Scenario engine','W+/BG')
 Put(16,5,'Local CSV export','W+/BG')
 Put(22,5,'100% HARBOUR','W+/BG')
 Put(24,5,'Real windows','W/BG')
 Put(25,5,'Real controls','W/BG')
 Put(26,5,'Real actions','W/BG')
 Put(29,5,'LOCAL / OFFLINE','Y+/BG')
 for each v in s_a
 total+=v[3]
 if v[4]=='READY';ready++;endif
 next
 Panel(5,26,11,54,' PORTFOLIO VALUE ','N/W')
 Put(7,29,AllTrim(Transform(total,'999,999'))+' EUR','B/W')
 Put(9,29,'4 sample projects','N/W')
 Panel(5,57,11,85,' READY TO DELIVER ','N/W')
 Put(7,60,hb_ntos(ready)+' / 4 PROJECTS','BG/W')
 Put(9,60,'Scenario '+hb_ntos(s_nCycle)+' | interactive','N/W')
 Panel(5,88,11,114,' APPLICATION ','N/W')
 Put(7,91,'HARBOUR + HBIDE','B/W')
 Put(9,91,'No browser. Native TUI.','N/W')
 Panel(13,26,24,78,' PROJECT PORTFOLIO ','N/W')
 Put(15,28,'CLIENT          WORKSTREAM       EUR    STATUS','B/W')
 hb_DispOutAt(16,28,Replicate(hb_UTF8ToStr('─'),48),'BG/W')
 for n:=1 to Len(s_a)
 Put(16+n,28,PadR(s_a[n,1],16)+PadR(s_a[n,2],16)+PadL(hb_ntos(s_a[n,3]),6)+'  '+PadR(s_a[n,4],6),iif(n==1,'W+/B','N/W'))
 next
 Put(22,28,'[ Run scenario ] advances the next project.','N/W')
 Panel(13,81,24,114,' REVENUE / SAMPLE ','N/W')
 for n:=1 to 10
 v:=Int(bars[n]/5)
 hb_DispOutAt(21-v,83+(n-1)*3,Replicate(hb_UTF8ToStr('█'),2),'BG/W')
 if v>1;hb_Scroll(22-v,83+(n-1)*3,21,84+(n-1)*3,,, 'W/BG');endif
 Put(22,83+(n-1)*3,aMon[n],'N/W')
 next
 Put(14,84,'EUR k / sample only','B/W')
 Panel(26,26,31,114,' ACTIVITY / LOCAL SESSION ','N/W')
 Put(28,29,PadR(Left(s_cNote,81),81),'B/W')
 Put(30,29,'Data stays local. Export writes nexus-demo.csv in the working folder.','N/W')
 hb_Scroll(33,3,36,115,,, 'N/W')
 Put(38,3,'TAB  Move focus     ENTER  Activate     MOUSE  Click     ESC  Return to hbide','W+/B')
 Put(39,0,PadR('  NEXUS DEMO  |  Fictional data, never a real business report',120),'N/W')
 for each g in s_get
 g:control:Display()
 next
 DispEnd()
return
static procedure Simulate()
 local n
 for n:=1 to Len(s_a)
 if s_a[n,4]!='READY'
 s_a[n,4]:='READY';s_nCycle++;s_cNote:='Scenario applied: '+s_a[n,1]+' is now READY. Totals recalculated.'
 return
 endif
 next
 s_cNote:='All sample projects are ready. Reset to replay the scenario.'
return
static procedure ResetDemo()
 s_a[2,4]:='REVIEW';s_a[3,4]:='ACTIVE';s_nCycle:=0
 s_cNote:='Demo reset. All fictional records restored.'
return
static procedure ExportDemo()
 local c:='client,workstream,eur,status'+hb_eol(),a
 for each a in s_a
 c+=a[1]+','+a[2]+','+hb_ntos(a[3])+','+a[4]+hb_eol()
 next
 if hb_MemoWrit('nexus-demo.csv',c)
 s_cNote:='Export complete: nexus-demo.csv | 4 sample rows, exact current statuses.'
 else
 s_cNote:='Export failed. Check write access in the working folder.'
 endif
return
static procedure Inspect()
 local w:=HbWindow():New(12,33,23,94,' SAMPLE DATA INSPECTOR ','N/W'),GetList:={},l:=.F.
 w:lShadow:=.T.
 w:Show()
 Put(14,36,'NOVA STUDIO / Design system','B/W')
 Put(16,36,'Value: 12,800 EUR   |   Status: '+s_a[1,4],'N/W')
 Put(18,36,'Fictional record. No production systems connected.','N/W')
 @ 21,55 GET l PUSHBUTTON CAPTION ' Close ' STYLE "[]" COLOR 'W+/BG,W+/B,N/BG,Y+/BG' STATE {|| w:End()}
 w:Activate(GetList)
return
