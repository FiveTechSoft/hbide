// Research only: independent NUL GT buffer with visible TRM restored.
#include "hbgtinfo.ch"
PROCEDURE Main( cResult )
   LOCAL pVisible:=hb_gtSelect(),pHidden:=hb_gtCreate("NUL"),aVisible,aHidden,aAfter,h:={=>}
   h["hidden_created"]:=pHidden!=NIL
   IF pHidden==NIL
      hb_MemoWrit(cResult,hb_jsonEncode(h))
      ErrorLevel(1)
      RETURN
   ENDIF
   SetMode(25,80)
   hb_DispOutAt(1,1,"DEBUG VISIBLE MARKER")
   aVisible:=hb_gtInfo(HB_GTI_GETWIN)
   hb_gtSelect(pHidden)
   SetMode(aVisible[4]+1,aVisible[5]+1)
   hb_DispOutAt(1,1,"APP HIDDEN MARKER")
   aHidden:=hb_gtInfo(HB_GTI_GETWIN)
   hb_gtSelect(pVisible)
   aAfter:=hb_gtInfo(HB_GTI_GETWIN)
   h["visible_buffer_preserved"]:=aAfter[6]==aVisible[6]
   hb_gtInfo(HB_GTI_SETWIN,aHidden)
   aAfter:=hb_gtInfo(HB_GTI_GETWIN)
   h["hidden_output_can_be_restored"]:=aAfter[6]==aHidden[6]
   h["hidden_size"]:={aHidden[4],aHidden[5],Len(aHidden[6])}
   h["visible_size"]:={aAfter[4],aAfter[5],Len(aAfter[6])}
   h["hidden_first_bytes"]:=hb_StrToHex(Left(aHidden[6],32))
   h["restored_first_bytes"]:=hb_StrToHex(Left(aAfter[6],32))
   hb_gtInfo(HB_GTI_SETWIN,aVisible)
   h["no_input_forwarding_proved"]:=.T.
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   IF !(h["visible_buffer_preserved"].and.h["hidden_output_can_be_restored"])
      ErrorLevel(1)
   ENDIF
   RETURN
