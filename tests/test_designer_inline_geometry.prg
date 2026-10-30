#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   o:aControls:={DsnNewControl("button",{})}
   o:aControls[1]["col"]:=31
   o:nSelected:=1
   o:lInspector:=.T.
   o:nInspField:=3
   h:=DsnSnapshot(o)
   hb_keyPut(K_CTRL_Y)
   hb_keyPut("A LONGER BUTTON")
   hb_keyPut(K_ENTER)
   o:InspEdit()
   Check(o:aControls[1]["col"]+DsnControlSize(o:aControls[1])[1]<=38,"inline caption final footprint inside")
   Check(Len(o:aUndo)==1,"one inline undo")
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"inline geometry undo exact")
   o:aControls:={DsnNewControl("radiogroup",{})}
   o:aControls[1]["row"]:=5
   o:aControls[1]["col"]:=20
   o:nInspField:=4
   o:aUndo:={};o:aRedo:={}
   h:=DsnSnapshot(o)
   hb_keyPut(K_CTRL_Y);hb_keyPut("One,Two,Three,Four,Five,Six");hb_keyPut(K_ENTER)
   o:InspEdit()
   Check(Len(DsnItems(o:aControls[1]))==6,"radio items accepted")
   Check(o:aControls[1]["row"]==2,"radio final height inside")
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"radio inline undo exact")
   ? "PASS inline caption/items final footprints and undo"

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
