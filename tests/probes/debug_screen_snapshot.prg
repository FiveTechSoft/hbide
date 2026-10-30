// GT default screen snapshots are not independent hidden rendering contexts.
#include "hbgtinfo.ch"
PROCEDURE Main( cResult )
   LOCAL hApp,hDebug,hAfter,lApp,lDebug,lOutput
   SetMode(25,80)
   hb_DispOutAt(1,1,"APPLICATION ORIGINAL")
   hApp:=hb_gtInfo(HB_GTI_GETWIN)
   hb_DispOutAt(1,1,"DEBUGGER SNAPSHOT   ")
   hDebug:=hb_gtInfo(HB_GTI_GETWIN)
   hb_gtInfo(HB_GTI_SETWIN,hApp)
   hAfter:=hb_gtInfo(HB_GTI_GETWIN)
   lApp:=hAfter[6]==hApp[6]
   hb_gtInfo(HB_GTI_SETWIN,hDebug)
   hAfter:=hb_gtInfo(HB_GTI_GETWIN)
   lDebug:=hAfter[6]==hDebug[6]
   // Output while debugger is current changes that same active buffer.
   hb_DispOutAt(1,1,"APP WRITES TO ACTIVE")
   hAfter:=hb_gtInfo(HB_GTI_GETWIN)
   lOutput:=hAfter[6]!=hDebug[6]
   hb_MemoWrit(cResult,hb_jsonEncode({"app_restored"=>lApp,"debug_restored"=>lDebug,;
      "output_modifies_active_buffer"=>lOutput,"app_snapshot_unmodified"=>hApp[6]!=hAfter[6]}))
   IF !(lApp.and.lDebug.and.lOutput)
      ErrorLevel(1)
   ENDIF
   RETURN
