#include "hbclass.ch"
#include "inkey.ch"
#include "set.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h,cType,n,aSize,hAfter
   SetMode(40,120)
   Set(_SET_TYPEAHEAD,512)
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
   FOR EACH cType IN {"listbox","combobox"}
      o:aControls:={DsnNewControl(cType,{})}
      o:aControls[1]["width"]:=4
      o:aControls[1]["height"]:=4
      o:aControls[1]["col"]:=34
      o:aControls[1]["row"]:=6
      h:=DsnSnapshot(o)
      o:aUndo:={};o:aRedo:={}
      FOR n:=1 TO 4
         hb_keyPut(K_TAB)
      NEXT
      hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("2"));hb_keyPut(Asc("0"))
      hb_keyPut(K_TAB);hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("8"))
      FOR n:=1 TO 5
         hb_keyPut(K_TAB)
      NEXT
      hb_keyPut(K_SPACE)
      o:EditProperties()
      aSize:=DsnControlSize(o:aControls[1])
      Check(aSize[1]==20 .AND. aSize[2]==8,cType+" accepted width and height")
      Check(o:aControls[1]["col"]==18 .AND. o:aControls[1]["row"]==2,cType+" final footprint inside")
      Check(Len(o:aUndo)==1,cType+" one undo")
      o:Undo()
      Check(DsnSnapEqual(h,DsnSnapshot(o)),cType+" undo exact")
      o:Redo()
      Check(o:aControls[1]["row"]==2,cType+" redo")
   NEXT
   o:aControls:={DsnNewControl("button",{})}
   o:aControls[1]["col"]:=31
   o:aUndo:={};o:aRedo:={}
   h:=DsnSnapshot(o)
   hb_keyPut(K_TAB);hb_keyPut(K_TAB);hb_keyPut(K_CTRL_Y)
   FOR n:=1 TO 20
      hb_keyPut(Asc("A"))
   NEXT
   FOR n:=1 TO 7
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_SPACE)
   o:EditProperties()
   aSize:=DsnControlSize(o:aControls[1])
   Check(Len(o:aControls[1]["caption"])==20,"button caption accepted")
   Check(o:aControls[1]["col"]+aSize[1]<=38,"button final caption footprint")
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"button undo exact")
   // Button accelerator and brackets are actual modal fields, not helper input.
   o:aControls:={DsnNewControl("button",{})};o:nSelected:=1
   o:aUndo:={};o:aRedo:={};o:lDirty:=.F.
   h:=DsnSnapshot(o)
   hb_keyPut(K_TAB);hb_keyPut(K_TAB);hb_keyPut(K_TAB)
   hb_keyPut(K_CTRL_Y);hb_keyPut("Z");hb_keyPut(K_TAB);hb_keyPut(K_TAB)
   hb_keyPut(K_SPACE)
   FOR n:=1 TO 4
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_SPACE)
   o:EditProperties()
   Check(o:aControls[1,"accelerator"]=="Z","modal accelerator accepted")
   Check(o:aControls[1,"style"]=="brackets","modal brackets accepted")
   Check(o:lDirty.and.Len(o:aUndo)==1,"modal accelerator/style one undo")
   hAfter:=DsnSnapshot(o)
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"modal accelerator/style undo exact")
   o:Redo()
   Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),"modal accelerator/style redo exact")
   ? "PASS final property footprints GET/list/combo/button and undo"

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
