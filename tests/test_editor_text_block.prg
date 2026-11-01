#include "hbclass.ch"
#include "inkey.ch"
static nPass:=0,nFail:=0
procedure Main()
 local o:=HBSrcEdit():New('',2,1,20,79,.T.),c
 Set(_SET_INSERT,.T.)
 o:LoadText('TEXT'+hb_eol()+'/* literal'+hb_eol()+'ENDTEXT'+hb_eol()+'return 42')
 Check('literal opener does not create block comment',!o:BlkCmtState(4))
 Check('payload carries TEXT state',o:aBlkCtx[2]=='@TEXT'.and.o:aBlkCtx[3]=='@TEXT')
 Check('terminator clears carry',o:aBlkCtx[4]=='')
 o:GoTo(1,5)
 o:Edit(K_DEL)
 Check('breaking TEXT makes opener real comment',o:BlkCmtState(4))
 o:Undo()
 Check('Undo restores isolated literal state',!o:BlkCmtState(4).and.o:aBlkCtx[2]=='@TEXT')
 o:Redo()
 Check('Redo restores ordinary comment scan',o:BlkCmtState(4))
 o:Undo()
 o:GoTo(3,1)
 o:Edit(K_DEL)
 Check('breaking terminator retains literal carry',!o:BlkCmtState(4).and.o:aBlkCtx[4]=='@TEXT')
 o:Undo()
 Check('Undo terminator resumes ordinary state',!o:BlkCmtState(4).and.o:aBlkCtx[4]=='')
 o:Redo()
 Check('Redo terminator retains literal carry',!o:BlkCmtState(4).and.o:aBlkCtx[4]=='@TEXT')
 for each c in {'ENDTEXT','endtext // done','ENDTEXT && done','ENDTEXT /* done */'}
 o:LoadText('TEXT'+hb_eol()+'/* literal'+hb_eol()+c+hb_eol()+'return 42')
 Check('raw terminator resumes clean state: '+c,!o:BlkCmtState(4).and.o:aBlkCtx[4]=='')
 next
 o:LoadText('TEXT'+hb_eol()+'ENDTEXTextra'+hb_eol()+'/* literal'+hb_eol()+'ENDTEXT'+hb_eol()+'return 42')
 Check('prefix is not terminator',!o:BlkCmtState(5).and.o:aBlkCtx[4]=='@TEXT'.and.o:aBlkCtx[5]=='')
 o:LoadText('TEXT := 1'+hb_eol()+'/* real'+hb_eol()+'return 42')
 Check('TEXT assignment not stream',o:BlkCmtState(3))
 for each c in {'TEXT // done','TEXT && done','TEXT/* done */','TEXT /* a */ /* b */','TEXT'+Chr(9)+'// done'}
 o:LoadText(c+hb_eol()+'/* literal'+hb_eol()+'ENDTEXT'+hb_eol()+'return 42')
 Check('commented bare opener isolates payload: '+c,!o:BlkCmtState(4).and.o:aBlkCtx[2]=='@TEXT'.and.o:aBlkCtx[4]=='')
 next
 for each c in {'TEXTBOOK','TEXT&& done','TEXT TO c','TEXT /* gap */ := 1','TEXT /* unclosed'}
 o:LoadText(c+hb_eol()+'/* real'+hb_eol()+'return 42')
 Check('non-bare or unclosed opener not literal: '+c,o:BlkCmtState(3).and.o:aBlkCtx[2]!='@TEXT')
 next
 o:LoadText('local TEXT := 1'+hb_eol()+'local x := ;'+hb_eol()+'TEXT'+hb_eol()+'/* real */'+hb_eol()+'return x')
 Check('continued TEXT identifier is ordinary expression',!o:BlkCmtState(5).and.o:aBlkCtx[4]=='')
 o:GoTo(2,5+Len('local x := ;'))
 o:Edit(K_BS)
 Check('deleting continuation enables TEXT stream',!o:BlkCmtState(5).and.o:aBlkCtx[4]=='@TEXT')
 o:Undo()
 Check('Undo continuation edit restores expression',!o:BlkCmtState(5).and.o:aBlkCtx[4]=='')
 o:Redo()
 Check('Redo continuation edit restores stream',!o:BlkCmtState(5).and.o:aBlkCtx[4]=='@TEXT')
 for each c in {'/* prefix */ TEXT','/* a */ /* b */ TEXT // tail'}
 o:LoadText(c+hb_eol()+'/* literal'+hb_eol()+'ENDTEXT'+hb_eol()+'return 42')
 Check('leading closed comments permit stream: '+c,!o:BlkCmtState(4).and.o:aBlkCtx[2]=='@TEXT'.and.o:aBlkCtx[4]=='')
 next
 o:LoadText('/* prefix'+hb_eol()+'*/ TEXT'+hb_eol()+'/* literal'+hb_eol()+'ENDTEXT'+hb_eol()+'return 42')
 Check('closing multiline prefix permits stream',!o:BlkCmtState(5).and.o:aBlkCtx[3]=='@TEXT'.and.o:aBlkCtx[5]=='')
 o:GoTo(2,5+Len('*/ TEXT'))
 o:Edit(K_BS)
 Check('breaking prefixed opener restores real comment',o:BlkCmtState(5))
 o:Undo()
 Check('Undo prefixed opener resumes stream',!o:BlkCmtState(5).and.o:aBlkCtx[3]=='@TEXT')
 o:Redo()
 Check('Redo prefixed opener restores real comment',o:BlkCmtState(5))
 o:LoadText('/* still open'+hb_eol()+'TEXT'+hb_eol()+'*/'+hb_eol()+'return 42')
 Check('TEXT inside unclosed comment not stream',!o:BlkCmtState(4).and.o:aBlkCtx[3]!='@TEXT')
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
