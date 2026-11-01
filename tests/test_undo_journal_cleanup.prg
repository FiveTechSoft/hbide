#include "hbclass.ch"
#include "inkey.ch"
static nPass:=0,nFail:=0
procedure Main()
 local o:=HBSrcEdit():New('',2,1,20,79,.T.),cKey,cOwn,cOther,cFile
 cFile:=hb_DirTemp()+'hbide-undo-journal-'+hb_ntos(hb_RandomInt(99999999))+'.prg'
 Set(_SET_INSERT,.T.)
 o:LoadText('BASE')
 o:cFile:=cFile
 o:SaveFile()
 cKey:=o:JournalKey()
 cOwn:=hb_FNameMerge(HBIDE_RecoveryDir(),cKey+'--'+HBIDE_RecoverySession(),'.journal')
 cOther:=hb_FNameMerge(HBIDE_RecoveryDir(),cKey+'--OTHER','.journal')
 hb_MemoWrit(cOther,'OTHER UNSAVED')
 o:GoTo(1,5)
 o:Edit(Asc('x'))
 o:UpdateJournal()
 Check('dirty journal exists',hb_FileExists(cOwn))
 o:Undo()
 Check('Undo clean removes own journal',!o:Changed().and.!hb_FileExists(cOwn))
 Check('Undo preserves another session journal',hb_MemoRead(cOther)=='OTHER UNSAVED')
 o:Redo()
 o:UpdateJournal()
 Check('Redo dirty recreates journal',o:Changed().and.hb_FileExists(cOwn))
 o:SaveFile()
 o:Undo()
 o:UpdateJournal()
 Check('Undo before saved state writes dirty journal',o:Changed().and.hb_FileExists(cOwn))
 o:Redo()
 Check('Redo to saved removes own journal',!o:Changed().and.!hb_FileExists(cOwn))
 Check('Redo preserves other session',hb_MemoRead(cOther)=='OTHER UNSAVED')
 o:LoadText('RECOVERED')
 o:SetDirty(.T.)
 o:GoTo(1,5)
 o:Edit(Asc('y'))
 o:UpdateJournal()
 o:Undo()
 Check('Undo recovered baseline keeps own journal',o:Changed().and.hb_FileExists(cOwn))
 FErase(cFile)
 FErase(cOther)
 o:JournalDiscard()
 ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
 ErrorLevel(iif(nFail==0,0,1))
return
procedure Check(c,l)
 if l
 nPass++
 else
 nFail++
 endif
 ? iif(l,'PASS ','FAIL ')+c
return
function HBIDE_MsgAlert(c)
 HB_SYMBOL_UNUSED(c)
return 1
