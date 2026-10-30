PROCEDURE Main( cChild )
   LOCAL hIn,hOut,hErr,hProc,nStatus,nRead,cBuffer:=Space(8192),cOut:='',nStart:=hb_MilliSeconds()
   hProc:=hb_processOpen('/usr/bin/python3 '+HBIDEProbeQuote( cChild ),@hIn,@hOut,@hErr)
   IF hProc==-1
      ? 'FAIL open'
      ErrorLevel(1)
      RETURN
   ENDIF
   FClose(hIn)
   DO WHILE hb_MilliSeconds()-nStart<700
      nRead:=hb_PRead(hOut,@cBuffer,,10)
      IF nRead>0
         cOut+=Left(cBuffer,nRead)
      ENDIF
      nStatus:=hb_processValue(hProc,.F.)
      IF nStatus!=-1
         EXIT
      ENDIF
      hb_idleSleep(.01)
   ENDDO
   ? 'BEFORE CANCEL',nStatus,cOut
   ? 'CLOSE RESULT',hb_processClose(hProc,.F.)
   ? 'EXIT',hb_processValue(hProc,.T.)
   FClose(hOut)
   FClose(hErr)
RETURN

STATIC FUNCTION HBIDEProbeQuote( cArg )
   RETURN '"'+StrTran(cArg,'"','')+'"'
