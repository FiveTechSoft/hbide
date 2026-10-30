#include "hbclass.ch"
#include "inkey.ch"
#include "set.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h,cType,n,aSize,hAfter,nRemain,cVariable,cItems
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
   FOR EACH cType IN {"get","checkbox","radiogroup","listbox","combobox"}
      o:aControls:={DsnNewControl(cType,{})};o:nSelected:=1
      o:aUndo:={};o:aRedo:={};o:lDirty:=.F.
      h:=DsnSnapshot(o)
      // Selection controls expose variable/items after row/col; checkbox
      // variable follows caption; GET follows row/col.
      FOR n:=1 TO If(cType=="checkbox",3,2)
         hb_keyPut(K_TAB)
      NEXT
      cVariable:=If(cType=="get","cText",If(cType=="checkbox","lFlag","nChoice"))
      hb_keyPut(K_CTRL_Y);hb_keyPut(cVariable);hb_keyPut(K_TAB)
      DO CASE
      CASE cType $ "radiogroup|listbox|combobox"
         cItems:="First quoted 'item',Second item,Third"
         hb_keyPut(K_CTRL_Y);hb_keyPut(cItems)
         nRemain:=If(cType=="radiogroup",4,7)
      CASE cType=="get"
         nRemain:=3
      OTHERWISE
         nRemain:=4
      ENDCASE
      FOR n:=1 TO nRemain
         hb_keyPut(K_TAB)
      NEXT
      hb_keyPut(K_SPACE)
      o:EditProperties()
      Check(o:aControls[1,"variable"]==cVariable,cType+" modal variable exact")
      IF cType $ "radiogroup|listbox|combobox"
         Check(o:aControls[1,"items"]==cItems,cType+" modal items exact")
      ENDIF
      Check(o:lDirty.and.Len(o:aUndo)==1,cType+" modal binding one undo")
      hAfter:=DsnSnapshot(o)
      o:Undo()
      Check(DsnSnapEqual(h,DsnSnapshot(o)),cType+" modal binding undo exact")
      o:Redo()
      Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),cType+" modal binding redo exact")
   NEXT
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
