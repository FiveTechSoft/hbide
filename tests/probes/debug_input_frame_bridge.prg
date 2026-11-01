// Isolated research only: NUL app state, visible GT keyboard, bounded INKEY.
// No IDE integration; unknown calls never enable swapping.
#include 'hbgtinfo.ch'
STATIC pVisible,pHidden,lBridge:=.F.,nShows:=0
PROCEDURE Main(cResult,cWait)
 LOCAL h:={=>},cBefore,cHidden,bOld,nKey,nStart,nRows:=MaxRow()+1,nCols:=MaxCol()+1
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
 hb_gtSelect(pVisible)
 h['debugger_buffer_restored']:=SaveScreen()==cBefore
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
 lBridge:=.T.
 nSeconds:=iif(HB_ISNUMERIC(aParams[1]),aParams[1],0)
 nMask:=iif(Len(aParams)>1,aParams[2],128)
 cApp:=hb_gtInfo(HB_GTI_GETWIN)
 hb_gtSelect(pVisible)
 cDebugger:=hb_gtInfo(HB_GTI_GETWIN)
 hb_gtInfo(HB_GTI_SETWIN,cApp)
 ++nShows
 hb_MemoWrit(cResult+'.ready',hb_ntos(nShows))
 nKey:=Inkey(nSeconds,nMask)
 hb_gtInfo(HB_GTI_SETWIN,cDebugger)
 hb_gtSelect(pHidden)
 hb_keySetLast(nKey)
 lBridge:=.F.
 // A timeout returns 0, which causes the underlying GT to wait AGAIN.
 // This prototype deliberately exposes that contract limitation.
 RETURN nKey
