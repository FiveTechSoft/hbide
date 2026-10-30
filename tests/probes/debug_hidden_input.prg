// Research: synthetic keys isolate per-GT queues, not real keyboard forwarding.
#include "inkey.ch"
PROCEDURE Main( cResult )
   LOCAL pVisible:=hb_gtSelect(),pHidden:=hb_gtCreate("NUL"),h:={=>}
   LOCAL cVisible,cHidden,nHidden,nVisible
   SetColor("W/B")
   cVisible:=SetColor()
   hb_keyPut(65)
   hb_gtSelect(pHidden)
   SetColor("N/W")
   cHidden:=SetColor()
   h["hidden_does_not_see_visible_queue"]:=Inkey()==0
   hb_keyPut(66)
   nHidden:=Inkey()
   hb_gtSelect(pVisible)
   nVisible:=Inkey()
   h["hidden_synthetic_key"]:=nHidden
   h["visible_synthetic_key_preserved"]:=nVisible
   h["visible_color_preserved"]:=SetColor()==cVisible
   hb_gtSelect(pHidden)
   h["hidden_color_preserved"]:=SetColor()==cHidden
   hb_gtSelect(pVisible)
   h["real_keyboard_forwarding_tested"]:=.F.
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   IF !(nHidden==66.and.nVisible==65.and.h["visible_color_preserved"].and.h["hidden_color_preserved"])
      ErrorLevel(1)
   ENDIF
   RETURN
