// Isolated research only: NUL app state, visible GT keyboard, bounded INKEY.
// No IDE integration; unknown calls never enable swapping.
#include 'hbgtinfo.ch'
STATIC pVisible,pHidden,lBridge:=.F.,nShows:=0,aDebug,cAppScreen
PROCEDURE Main(cResult,cWait)
 LOCAL h:={=>},cBefore,cHidden,bOld,bFilter,nIdle,nKey,nStart,nRows:=MaxRow()+1,nCols:=MaxCol()+1
 pVisible:=hb_gtSelect()
 CLS
 @ 1,1 SAY 'DEBUGGER-RESEARCH'
 cBefore:=SaveScreen()
 pHidden:=hb_gtCreate('NUL')
 hb_gtSelect(pHidden)
 SetMode(nRows,nCols)
 CLS
 @ 2,2 SAY 'APP-RESEARCH-WAIT'
 cHidden:=SaveScreen()
 h['hidden_contains_marker']:=At('A',cHidden)>0
 h['hidden_screen_bytes']:=Len(cHidden)
 bOld:=hb_gtInfo(HB_GTI_INKEYREAD,{||Bridge(cResult)})
 bFilter:=hb_gtInfo(HB_GTI_INKEYFILTER,{|n|FinishKey(n)})
 nIdle:=hb_idleAdd({||PumpKeyboard()})
 h['poll']:=Inkey()
 h['shows_after_poll']:=nShows
 nKey:=Inkey(iif(Empty(cWait),.5,Val(cWait)))
 h['real_key']:=nKey
 h['last_key']:=LastKey()
 nStart:=hb_MilliSeconds()
 h['timeout_key']:=Inkey(.05)
 h['timeout_elapsed_ms']:=hb_MilliSeconds()-nStart
 h['last_after_timeout']:=LastKey()
 h['hidden_buffer_preserved']:=SaveScreen()==cHidden
 h['shows']:=nShows
 hb_gtInfo(HB_GTI_INKEYREAD,bOld)
 hb_gtInfo(HB_GTI_INKEYFILTER,bFilter)
 hb_idleDel(nIdle)
 hb_gtSelect(pVisible)
 h['debugger_buffer_restored']:=SaveScreen()==cBefore
 h['app_remains_after_timeout']:=hb_gtInfo(HB_GTI_GETWIN)[6]==cAppScreen[6]
 h['extra_key']:=Inkey(.03)
 hb_MemoWrit(cResult,hb_jsonEncode(h))
 RETURN
STATIC FUNCTION Bridge(cResult)
 LOCAL aParams:={},i,cName,cApp,cDebugger,nKey,nSeconds,nMask
 IF lBridge
  RETURN 0
 ENDIF
 FOR i:=1 TO 12
  cName:=ProcName(i)
  IF cName=='INKEY'
   aParams:=__dbgVMParLList(i)
   EXIT
  ENDIF
  IF Empty(cName)
   EXIT
  ENDIF
 NEXT
 IF Empty(aParams) .OR. (Len(aParams)>1 .AND. !HB_ISNUMERIC(aParams[1]))
  RETURN 0
 ENDIF
 // Guard frame support before calling this hook in any future product path.
 cAppScreen:=hb_gtInfo(HB_GTI_GETWIN)
 hb_gtSelect(pVisible)
 IF aDebug==NIL
  aDebug:=hb_gtInfo(HB_GTI_GETWIN)
 ENDIF
 hb_gtInfo(HB_GTI_SETWIN,cAppScreen)
 ++nShows
 hb_MemoWrit(cResult+'.ready',hb_ntos(nShows))
 hb_gtSelect(pHidden)
 RETURN 0
STATIC PROCEDURE PumpKeyboard()
 LOCAL nKey
 IF lBridge
  RETURN
 ENDIF
 lBridge:=.T.
 hb_gtSelect(pVisible)
 nKey:=Inkey()
 hb_gtSelect(pHidden)
 IF nKey!=0
  hb_keyPut(nKey)
 ENDIF
 lBridge:=.F.
 RETURN
STATIC FUNCTION FinishKey(nKey)
 hb_gtSelect(pVisible)
 hb_gtInfo(HB_GTI_SETWIN,aDebug)
 hb_gtSelect(pHidden)
 RETURN nKey
