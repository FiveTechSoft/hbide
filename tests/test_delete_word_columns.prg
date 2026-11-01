REQUEST HB_CODEPAGE_UTF8
#include "hbclass.ch"
#include "inkey.ch"
static nPass:=0,nFail:=0
procedure Main()
 local o:=HBSrcEdit():New('',2,1,20,79,.T.)
 hb_cdpSelect('UTF8')
 o:LoadText('café beta')
 o:GoTo(1,5)
 o:Edit(K_CTRL_T)
 Check('UTF8 word removes whole accented word',o:GetText()==' beta')
 o:Undo()
 Check('UTF8 Undo restores exact',o:GetText()=='café beta')
 o:GoTo(1,8)
 o:Edit(K_CTRL_T)
 Check('UTF8 midword deletes one scalar not byte',o:GetText()=='caf beta')
 o:Undo()
 o:LoadText(Chr(9)+'alpha beta')
 o:GoTo(1,6)
 o:Edit(K_CTRL_T)
 Check('TAB is one model column, not display width',o:GetText()==Chr(9)+' beta')
 o:Undo()
 Check('TAB Undo exact',o:GetText()==Chr(9)+'alpha beta')
 o:LoadText('/* comment'+Chr(10)+'return nil')
 Check('initial block comment reaches next row',o:BlkCmtState(2))
 o:GoTo(1,5)
 o:Edit(K_CTRL_T)
 Check('word deletion invalidates block state',!o:BlkCmtState(2))
 o:Undo()
 Check('Undo restores block state',o:BlkCmtState(2))
 o:Redo()
 Check('Redo clears block state',!o:BlkCmtState(2))
 o:LoadText('alpha beta gamma')
 o:GoTo(1,5)
 o:Edit(K_F8)
 o:GoTo(1,11)
 o:Edit(K_CTRL_T)
 Check('CtrlT consumes marked range before word at cursor',o:GetText()=='beta gamma'.and.!o:HasMark())
 o:Undo()
 Check('marked CtrlT Undo exact',o:GetText()=='alpha beta gamma')
 o:Redo()
 Check('marked CtrlT Redo exact',o:GetText()=='beta gamma')
 o:Edit(Asc('X'))
 Check('typing after CtrlT has no stale selection',o:GetText()=='Xbeta gamma')
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
