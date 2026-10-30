#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   o:aControls:={DsnNewControl("button",{})}
   o:nSelected:=1
   o:lDirty:=.F.
   h:=DsnSnapshot(o)
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("9"));hb_keyPut(K_ESC)
   o:EditProperties()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"control Esc retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"control Esc no dirty or undo")
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("Z"));hb_keyPut(K_ESC)
   o:DlgProperties()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"dialog Esc retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"dialog Esc no dirty or undo")
   o:lInspector:=.T.
   o:nInspField:=3
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("Z"));hb_keyPut(K_ESC)
   o:InspEdit()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"inspector Esc retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"inspector Esc no dirty or undo")
   ? "PASS property Esc model/history invariants"
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
