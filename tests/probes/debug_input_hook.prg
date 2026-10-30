// Research only: INKEYREAD distinguishes sleep, but not poll from wait.
#include "hbgtinfo.ch"
PROCEDURE Main(cResult)
   LOCAL pVisible:=hb_gtSelect(),pHidden:=hb_gtCreate("NUL"),h:={=>},nCalls:=0
   hb_gtSelect(pHidden)
   hb_gtInfo(HB_GTI_INKEYREAD,{|| CountCall(@nCalls)})
   hb_idleSleep(.05)
   h["calls_after_sleep"]:=nCalls
   h["poll_result"]:=Inkey()
   h["calls_after_poll"]:=nCalls
   h["wait_result"]:=Inkey(.05)
   h["calls_after_wait"]:=nCalls
   hb_gtInfo(HB_GTI_INKEYREAD,{|| 65})
   h["injected_result"]:=Inkey(.05)
   h["lastkey_after_hook"]:=LastKey()
   hb_gtInfo(HB_GTI_INKEYREAD,NIL)
   hb_gtSelect(pVisible)
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   IF !(h["calls_after_sleep"]==0.and.h["calls_after_poll"]==1.and.h["calls_after_wait"]==2.and.h["injected_result"]==65)
      ErrorLevel(1)
   ENDIF
   RETURN
STATIC FUNCTION CountCall(nCalls)
   ++nCalls
   RETURN 0
