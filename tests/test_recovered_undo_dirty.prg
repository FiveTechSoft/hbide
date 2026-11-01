#include "hbclass.ch"
#include "inkey.ch"
static nPass := 0, nFail := 0
procedure Main()
 local o := HBSrcEdit():New('',2,1,20,79,.T.)
 local cFile := hb_DirTemp()+'hbide-recovered-undo-'+hb_ntos(hb_RandomInt(99999999))+'.prg'
 Set(_SET_INSERT,.T.)
 o:LoadText('RECOVERED UNSAVED')
 o:cFile := cFile
 o:SetDirty(.T.)
 Check('recovered baseline dirty',o:Changed())
 o:GoTo(1,5)
 o:Edit(Asc('x'))
 o:Undo()
 Check('Undo restores recovered bytes',o:GetText()=='RECOVERED UNSAVED')
 Check('Undo recovered baseline stays dirty',o:Changed())
 o:Redo()
 Check('Redo stays dirty',o:Changed())
 o:Undo()
 Check('second Undo stays dirty',o:Changed())
 Check('save establishes clean baseline',o:SaveFile().and.!o:Changed())
 Check('save writes recovered baseline exact',hb_MemoRead(cFile)=='RECOVERED UNSAVED')
 o:Edit(Asc('y'))
 Check('edit after save dirty',o:Changed())
 o:Undo()
 Check('Undo returns to saved state clean',!o:Changed())
 o:Redo()
 Check('Redo away from saved state dirty',o:Changed())
 o:LoadText('RELOADED')
 o:GoTo(1,5)
 o:Edit(Asc('z'))
 o:Undo()
 Check('normal LoadText baseline stays clean after Undo',!o:Changed())
 FErase(cFile)
 FErase(hb_FNameExtSet(cFile,'.bak'))
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
