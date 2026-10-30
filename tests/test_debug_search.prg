#include "hbclass.ch"
CLASS SearchProbe FROM HBBrwText
 METHOD GetLineColor() INLINE {1,2}
ENDCLASS
FUNCTION __dbgTextToArray(c)
 RETURN hb_ATokens(c,Chr(10))
FUNCTION __dbg()
 RETURN NIL
FUNCTION __dbgIsBreak(a,b,c)
 RETURN -1
PROCEDURE Main()
 LOCAL o,c:=hb_DirTemp()+'search-probe.txt',l,n
 hb_MemoWrit(c,'first needle'+Chr(10)+'second'+Chr(10)+'last needle')
 o:=SearchProbe():New(1,0,10,70,c,'W/B,W+/BG',.T.,4)
 o:ForceStable()
 l:=o:Search('first needle',.T.,0)
 Assert(l .AND. o:nRow==1,'from-top includes first row')
 o:GotoLine(2)
 n:=o:nRow
 l:=o:Search('missing',.T.,0)
 Assert(!l .AND. o:nRow==n,'missing search preserves backing cursor')
 Assert(o:Search('last needle',.T.,1) .AND. o:nRow==3,'next finds later row')
 Assert(o:Search('first needle',.T.,2) .AND. o:nRow==1,'previous finds first row')
 Assert(!o:Search('FIRST NEEDLE',.T.,0),'case sensitive rejects mismatch')
 Assert(o:Search('FIRST NEEDLE',.F.,0) .AND. o:nRow==1,'case insensitive includes first row')
 o:GotoLine(2)
 hb_Run('chmod 000 '+c)
 Assert(!o:LoadFile(c),'unreadable source reports false')
 Assert(o:nRow==2 .AND. o:aRows[1]=='first needle','failed load preserves rows and cursor')
 hb_Run('chmod 600 '+c)
 hb_MemoWrit(c,'')
 Assert(o:LoadFile(c),'empty source is readable')
 hb_MemoWrit('/tmp/hbide-debug-search-tests.txt','PASS search and checked source loads')
 hb_MemoWrit('/tmp/search-model-result.txt',hb_ValToExp({n,o:nRow,l}))
 RETURN

PROCEDURE Assert(l,c)
 IF !l
  hb_MemoWrit('/tmp/hbide-debug-search-tests.txt','FAIL '+c)
  ErrorLevel(1)
  QUIT
 ENDIF
 RETURN
