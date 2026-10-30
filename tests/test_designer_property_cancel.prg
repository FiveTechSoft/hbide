#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h,i,cKey,cLong,aFields,nField,cValue,hAfter,cType,nEvents:=0,aExpected,aValue,nFieldIndex,nTabs
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
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("8"))
   FOR i:=1 TO 10
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_ENTER)
   o:EditProperties()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"control Cancel button retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"control Cancel button no dirty or undo")
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("X"))
   FOR i:=1 TO 8
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_ENTER)
   o:DlgProperties()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"dialog Cancel button retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"dialog Cancel button no dirty or undo")
   o:lInspector:=.T.
   o:nInspField:=3
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("Z"));hb_keyPut(K_ESC)
   o:InspEdit()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"inspector Esc retains model")
   Check(!o:lDirty .AND. Empty(o:aUndo),"inspector Esc no dirty or undo")
   cLong:="Handler( '"+Replicate("quoted argument ",12)+"', .T. )"
   FOR EACH cKey IN {"action","when","valid","focus","state"}
      o:aControls[1,cKey]:=cLong
   NEXT
   h:=DsnSnapshot(o)
   FOR i:=1 TO 9
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_ENTER)
   o:EditProperties()
   FOR EACH cKey IN {"action","when","valid","focus","state"}
      Check(o:aControls[1,cKey]==cLong,"accept preserves long string handler")
   NEXT
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"undo restores long-handler model exactly")
   FOR i:=1 TO 4
      hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_CTRL_Y);hb_keyPut(Asc("X"));hb_keyPut(K_ESC)
   o:EditProperties()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"cancel after handler edit preserves full handler")
   FOR EACH cType IN {"get","checkbox","button","radiogroup","listbox","combobox"}
   o:aControls:={DsnNewControl(cType,{})}
   o:nSelected:=1
   o:lInspector:=.T.
   aExpected:={"when","valid"}
   IF cType!="get"
      AAdd(aExpected,"focus")
   ENDIF
   IF cType $ "checkbox|listbox|combobox"
      AAdd(aExpected,"state")
   ENDIF
   FOR EACH cKey IN aExpected
      nEvents++
      o:aUndo:={};o:aRedo:={};o:lDirty:=.F.
      aFields:=o:InspFields()
      nField:=AScan(aFields,{|f|f[2]==cKey})
      Check(nField>0,"event field present")
      o:nInspField:=nField
      h:=DsnSnapshot(o)
      cValue:="Keep_"+cKey+"( 'quoted' )"
      hb_keyPut(K_CTRL_Y);hb_keyPut(cValue);hb_keyPut(K_ENTER)
      o:InspEdit()
      Check(o:aControls[1,cKey]==cValue,"inline event accept exact string")
      Check(o:lDirty.and.Len(o:aUndo)==1,"inline event one undo and dirty")
      hAfter:=DsnSnapshot(o)
      o:Undo()
      Check(DsnSnapEqual(h,DsnSnapshot(o)),"inline event undo exact")
      o:Redo()
      Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),"inline event redo exact")
      o:nInspField:=nField
      hb_keyPut(K_CTRL_Y);hb_keyPut("DROP");hb_keyPut(K_ESC)
      o:InspEdit()
      Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),"inline event Esc keeps accepted string")
      Check(Len(o:aUndo)==1.and.Empty(o:aRedo),"inline event Esc preserves history")
   NEXT
   NEXT
   Check(nEvents==20,"all twenty exposed inline control/event pairs exercised")
   // Actual Dialog properties, all seven fields through native queued input.
   o:aControls:={};o:nSelected:=0
   o:aUndo:={};o:aRedo:={};o:lDirty:=.F.
   h:=DsnSnapshot(o)
   FOR EACH aValue IN {"Modal caption","ModalName","60","18","B","W+","Y+/B"}
      hb_keyPut(K_CTRL_Y);hb_keyPut(aValue);hb_keyPut(K_TAB)
   NEXT
   hb_keyPut(K_SPACE)
   o:DlgProperties()
   Check(o:cDlgCaption=="Modal caption","modal dialog caption accepted")
   Check(o:cDlgName=="ModalName","modal dialog name accepted")
   Check(o:nDlgWidth==60.and.o:nDlgHeight==18,"modal dialog dimensions accepted")
   Check(o:cDlgClrBack=="B".and.o:cDlgClrText=="W+".and.o:cDlgClrFocus=="Y+/B","modal dialog colors accepted")
   Check(o:lDirty.and.Len(o:aUndo)==1,"modal dialog one undo and dirty")
   hAfter:=DsnSnapshot(o)
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"modal dialog seven-field undo exact")
   o:Redo()
   Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),"modal dialog seven-field redo exact")
   // Change each field separately, then Esc. Other accepted fields/history stay.
   FOR nFieldIndex:=1 TO 7
      FOR nTabs:=1 TO nFieldIndex-1
         hb_keyPut(K_TAB)
      NEXT
      hb_keyPut(K_CTRL_Y);hb_keyPut("9");hb_keyPut(K_ESC)
      o:DlgProperties()
      Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),"modal dialog each-field Esc exact")
      Check(Len(o:aUndo)==1.and.Empty(o:aRedo),"modal dialog each-field Esc history")
   NEXT
   ? "PASS property cancellation and long handler invariants"
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
