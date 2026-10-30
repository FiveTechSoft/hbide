#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   o:aControls:={DsnNewControl("get",{})}
   o:aControls[1]["width"]:=4
   o:aControls[1]["col"]:=34
   o:nSelected:=1
   h:=DsnSnapshot(o)
   // row, col, variable, width: enlarge at the former rightmost origin.
   hb_keyPut(K_TAB);hb_keyPut(K_TAB);hb_keyPut(K_TAB)
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("2"));hb_keyPut(Asc("0"))
   hb_keyPut(K_TAB);hb_keyPut(K_TAB);hb_keyPut(K_TAB);hb_keyPut(K_SPACE)
   o:EditProperties()
   Check(o:aControls[1]["width"]==20,"accepted new width")
   Check(o:aControls[1]["col"]+o:aControls[1]["width"]<=o:nDlgWidth-2,"resized control remains inside canvas")
   Check(Len(o:aUndo)==1,"single geometry undo")
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"undo restores old geometry")
   o:Redo()
   Check(o:aControls[1]["col"]==18 .AND. o:aControls[1]["width"]==20,"redo final geometry")
   ? "PASS property width clamps final geometry and undo/redo"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
CLASS PropHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
