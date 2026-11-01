#include "hbclass.ch"
#include "inkey.ch"
static nPass := 0, nFail := 0
procedure Main()
 local o := HBSrcEdit():New('',2,1,20,79,.T.)
 local cFile := hb_DirTemp()+'hbide-history-'+hb_ntos(hb_RandomInt(99999999))+'.prg'
 local n, cSaved
 Set(_SET_INSERT,.T.)
 o:LoadText('base')
 o:cFile := cFile
 Check('save initial clean baseline',o:SaveFile().and.!o:Changed())
 o:GoTo(1,5)
 o:Edit(Asc('a'))
 Check('typing creates first history op',Len(o:aUndo)==1.and.o:Changed())
 Check('save typing establishes boundary',o:SaveFile().and.!o:Changed())
 cSaved:=o:GetText()
 o:Edit(Asc('b'))
 Check('typing after save cannot fuse saved op',Len(o:aUndo)==2.and.o:Changed())
 o:Undo()
 Check('Undo reaches saved exact and clean',o:GetText()==cSaved.and.!o:Changed())
 o:Undo()
 Check('Undo before saved becomes dirty',o:Changed())
 o:Edit(Asc('x'))
 Check('branch invalidates former saved marker',o:nSavedUndoLen==-1.and.Empty(o:aRedo).and.o:Changed())
 o:Undo()
 Check('branch Undo never claims former save',o:Changed())
 o:LoadText('item000')
 o:SaveFile()
 for n:=1 to 300
   o:ReplaceAll(o:GetText(),'item'+StrZero(n,3))
 next
 Check('history reaches300 cap',Len(o:aUndo)==300)
 Check('save at cap marks current history',o:SaveFile().and.o:nSavedUndoLen==300)
 cSaved:=o:GetText()
 o:ReplaceAll(cSaved,'item301')
 Check('one truncation moves saved marker299',Len(o:aUndo)==300.and.o:nSavedUndoLen==299.and.o:Changed())
 o:Undo()
 Check('Undo at cap reaches saved bytes clean',o:GetText()==cSaved.and.!o:Changed())
 o:Redo()
 Check('Redo at cap dirty',o:Changed())
 for n:=302 to 601
   o:ReplaceAll(o:GetText(),'item'+StrZero(n,3))
 next
 Check('saved state falls off retained history',o:nSavedUndoLen==-1.and.Len(o:aUndo)==300)
 for n:=1 to 300
   o:Undo()
 next
 Check('Undo all retained history remains dirty',Empty(o:aUndo).and.o:Changed())
 Check('old saved bytes not reachable',o:GetText()!=cSaved)
 o:Redo()
 Check('Redo after cap exhaustion remains dirty',o:Changed())
 Check('new save resets unreachable marker',o:SaveFile().and.!o:Changed().and.o:nSavedUndoLen==1)
 o:Undo()
 Check('Undo before new save dirty',o:Changed())
 o:Redo()
 Check('Redo back to new save clean',!o:Changed())
 FErase(cFile)
 FErase(cFile+'.bak')
 ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
 ErrorLevel(iif(nFail==0,0,1))
return
procedure Check(cName,lOk)
 if lOk
   nPass++
 else
   nFail++
 endif
 ? iif(lOk,'PASS ','FAIL ')+cName
return
function HBIDE_MsgAlert(c)
 HB_SYMBOL_UNUSED(c)
return 1
