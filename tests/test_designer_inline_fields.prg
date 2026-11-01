#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'
static nPass:=0
PROCEDURE Main()
   local o:=HbDesigner():New(PropHost():New()),cType,aFields,aField,nField,cValue,h,hAfter,nPairs:=0
   SetMode(40,120)
   Set(_SET_TYPEAHEAD,512)
   o:oWnd:=HBWindow():Dialog('Test',60,20,'W+/W')
   o:FitWindow()
   o:lInspector:=.T.
   for each cType in {'say','get','checkbox','button','radiogroup','listbox','combobox'}
      o:aControls:={DsnNewControl(cType,{})}
      o:nSelected:=1
      aFields:=o:InspFields()
      for nField:=1 to Len(aFields)
         aField:=aFields[nField]
         if aField[3]!='text'.or.aField[2] $ 'when|valid|focus|state'
            loop
         endif
         nPairs++
         o:nInspField:=nField
         o:aUndo:={};o:aRedo:={};o:lDirty:=.F.
         h:=DsnSnapshot(o)
         do case
         case aField[2]=='variable';cValue:='boundValue'
         case aField[2]=='accelerator';cValue:='Z'
         case aField[2]=='items';cValue:="First 'quoted',Second,Third"
         case aField[2]=='action';cValue:="Action( 'quoted' )"
         otherwise;cValue:="Caption 'quoted' & text"
         endcase
         hb_keyPut(K_CTRL_Y);hb_keyPut(cValue);hb_keyPut(K_ENTER)
         o:InspEdit()
         Check(o:aControls[1,aField[2]]==cValue,cType+' '+aField[2]+' typed exact')
         Check(o:lDirty.and.Len(o:aUndo)==1,cType+' one undo dirty')
         hAfter:=DsnSnapshot(o)
         o:Undo()
         Check(DsnSnapEqual(h,DsnSnapshot(o)),cType+' inline undo exact')
         o:Redo()
         Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),cType+' inline redo exact')
         o:nInspField:=nField
         hb_keyPut(K_CTRL_Y);hb_keyPut('discard');hb_keyPut(K_ESC)
         o:InspEdit()
         Check(DsnSnapEqual(hAfter,DsnSnapshot(o)),cType+' inline cancel model exact')
         Check(Len(o:aUndo)==1.and.Empty(o:aRedo),cType+' inline cancel history exact')
      next
   next
   Check(nPairs==13,'thirteen non-event text control-field pairs')
   ? 'TOTAL',nPass,'PASS 0 FAIL'
return
STATIC PROCEDURE Check(lOk,cText)
   if !lOk
      ? 'FAIL:',cText
      ErrorLevel(1)
      QUIT
   endif
   nPass++
return
CLASS PropHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
