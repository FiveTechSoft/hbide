// Linux-only experiment. Run under setsid; not the production compiler runner.
#include "fileio.ch"
#include "directry.ch"
PROCEDURE Main(cChild)
   LOCAL hProc,nStatus:=-1,nStart:=hb_MilliSeconds(),nGroup:=posix_getpid(),lRemaining
   hProc:=hb_processOpen('/usr/bin/python3 "'+StrTran(cChild,'"','')+'"')
   IF hProc==-1
      ErrorLevel(1)
      RETURN
   ENDIF
   ? "STARTED",nGroup
   DO WHILE hb_MilliSeconds()-nStart<6000
      IF nStatus==-1
         nStatus:=hb_processValue(hProc,.F.)
         IF nStatus!=-1
            ? "LEADER_EXIT",nStatus
         ENDIF
      ENDIF
      lRemaining:=GroupHasOthers(nGroup)
      IF nStatus!=-1.and.!lRemaining
         ? "GROUP_EMPTY"
         ErrorLevel(nStatus)
         RETURN
      ENDIF
      hb_idleSleep(.02)
   ENDDO
   ? "TIMEOUT: group not accepted complete"
   ErrorLevel(2)
   RETURN
STATIC FUNCTION GroupHasOthers(nGroup)
   LOCAL aFile,cStat,nEnd,a,nPid
   FOR EACH aFile IN Directory('/proc/*','D')
      nPid:=Val(aFile[F_NAME])
      IF nPid<=0.or.nPid==nGroup
         LOOP
      ENDIF
      cStat:=hb_MemoRead('/proc/'+hb_ntos(nPid)+'/stat')
      nEnd:=RAt(')',cStat)
      IF nEnd>0
         a:=hb_ATokens(AllTrim(SubStr(cStat,nEnd+1)),' ')
         IF Len(a)>=4.and.Val(a[3])==nGroup.and.a[1]!='Z'
            RETURN .T.
         ENDIF
      ENDIF
   NEXT
   RETURN .F.
