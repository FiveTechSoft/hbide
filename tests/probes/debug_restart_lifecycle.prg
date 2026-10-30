// Research only: owned HRB handle/unload after Break. Not debugger Restart.
#include "hbhrb.ch"
REQUEST HB_HRBLOAD, HB_HRBDO, HB_HRBUNLOAD, GETENV
PROCEDURE Main(cResult)
   LOCAL cBody,oHrb,cFile,n,h:={=>},xBreak,cLog:=cResult+".events"
   LOCAL cCode:="procedure Main(cLog)"+hb_eol()+;
      "static n:=0"+hb_eol()+;
      "n++"+hb_eol()+;
      'hb_MemoWrit(cLog,hb_MemoRead(cLog)+"run"+hb_ntos(n)+";")'+hb_eol()+;
      'Break("probe-abort")'+hb_eol()+;
      "return"+hb_eol()+;
      "exit procedure Cleanup()"+hb_eol()+;
      'hb_MemoWrit(GetEnv("HBIDE_PROBE_EXITLOG"),hb_MemoRead(GetEnv("HBIDE_PROBE_EXITLOG"))+"exit;")'+hb_eol()+;
      "return"+hb_eol()
   hb_SetEnv("HBIDE_PROBE_EXITLOG",cLog)
   hb_MemoWrit(cLog,"")
   cBody:=hb_CompileFromBuf(cCode,"probe","-n","-q2")
   h["compiled"]:=!Empty(cBody)
   FOR n:=1 TO 2
      cFile:=cResult+hb_ntos(n)+".hrb"
      hb_MemoWrit(cFile,cBody)
      oHrb:=hb_hrbLoad(HB_HRB_BIND_FORCELOCAL,cFile)
      BEGIN SEQUENCE
         hb_hrbDo(oHrb,cLog)
      RECOVER USING xBreak
         h["caught"+hb_ntos(n)]:=xBreak=="probe-abort"
      END SEQUENCE
      hb_hrbUnload(oHrb)
      FErase(cFile)
   NEXT
   h["events"]:=hb_MemoRead(cLog)
   h["expected_fresh_runs_and_exit_cleanup"]:=h["events"]=="run1;exit;run1;exit;"
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   IF !h["expected_fresh_runs_and_exit_cleanup"]
      ErrorLevel(1)
   ENDIF
   RETURN
