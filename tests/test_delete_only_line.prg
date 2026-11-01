REQUEST HB_CODEPAGE_UTF8
#include "hbclass.ch"
#include "inkey.ch"
static nPass:=0,nFail:=0
procedure Main()
 local o:=HBSrcEdit():New('',2,1,20,79,.T.),c
 hb_cdpSelect('UTF8')
 for each c in {'alpha beta','café',Chr(9)+'x','   '}
 o:LoadText(c)
 o:GoTo(1,7)
 o:DeleteLine()
 Check('sole line cleared byteexact',o:GetText()==''.and.o:LineCount()==1.and.o:Changed())
 Check('deleted text copied intact',o:cClipboard==c)
 o:Undo()
 Check('Undo restores sole line clean',o:GetText()==c.and.!o:Changed())
 o:Redo()
 Check('Redo clears sole line dirty',o:GetText()==''.and.o:Changed())
 next
 o:LoadText('')
 o:cClipboard:='prior clipboard'
 o:DeleteLine()
 Check('empty buffer delete no-op',o:GetText()==''.and.!o:Changed().and.Empty(o:aUndo))
 Check('empty no-op preserves clipboard',o:cClipboard=='prior clipboard')
 o:LoadText('alpha')
 o:GoTo(1,5)
 o:ToggleMark()
 o:GoTo(1,8)
 o:DeleteLine()
 Check('sole-line command consumes old mark',!o:HasMark().and.o:GetText()=='')
 o:Undo()
 Check('Undo sole marked line exact',o:GetText()=='alpha')
 o:LoadText('alpha')
 o:GoTo(1,5)
 o:Edit(Asc('X'))
 o:DeleteLine()
 o:Undo()
 Check('Undo DeleteLine preserves prior typing',o:GetText()=='Xalpha'.and.o:Changed())
 o:Redo()
 Check('Redo DeleteLine clears typed line',o:GetText()=='')
 o:Edit(Asc('Y'))
 o:Undo()
 Check('Undo subsequent typing preserves DeleteLine',o:GetText()=='')
 o:Undo()
 Check('next Undo restores typed line',o:GetText()=='Xalpha')
 o:Undo()
 Check('third Undo returns clean original',o:GetText()=='alpha'.and.!o:Changed())
 ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
 ErrorLevel(iif(nFail==0,0,1))
return
procedure Check(c,l)
 if l;nPass++;else;nFail++;endif
 ? iif(l,'PASS ','FAIL ')+c
return
function HBIDE_MsgAlert(c)
 HB_SYMBOL_UNUSED(c)
return 1
