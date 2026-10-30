// Bounded real PTY key probe; NUL cannot read terminal just by GT selection.
PROCEDURE Main( cResult )
   LOCAL pVisible:=hb_gtSelect(),pHidden:=hb_gtCreate("NUL"),h:={=>}
   hb_gtSelect(pHidden)
   hb_MemoWrit(cResult+".ready","NUL WAITING")
   h["hidden_key"]:=Inkey(.6)
   hb_gtSelect(pVisible)
   h["visible_key"]:=Inkey(.6)
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   RETURN
