// Research only: idle is not input-only. Never installed in the debugger.
PROCEDURE Main( cResult, cMode )
   LOCAL pVisible:=hb_gtSelect(),pHidden:=hb_gtCreate("NUL"),h:={=>}
   LOCAL nIdle,nCalls:=0,nMoved:=0,cBefore,cAfter,nKey,nAfter,cHidden
   SetColor("W/B")
   cBefore:=SaveScreen()
   hb_gtSelect(pHidden)
   SetColor("N/W")
   cHidden:=SetColor()
   nIdle:=hb_idleAdd({|| Bridge(pVisible,pHidden,@nCalls,@nMoved,h)})
   hb_MemoWrit(cResult+".ready","NUL READY")
   IF cMode=="sleep"
      hb_idleSleep(.6)
      h["queued_during_sleep"]:=NextKey()
   ENDIF
   nKey:=Inkey(.6)
   h["hidden_context_after_wait"]:=SetColor()==cHidden
   hb_idleDel(nIdle)
   hb_gtSelect(pVisible)
   cAfter:=SaveScreen()
   nAfter:=Inkey(.05)
   h["hidden_key"]:=nKey
   h["visible_key_after"]:=nAfter
   h["visible_buffer_preserved"]:=cBefore==cAfter
   h["idle_calls"]:=nCalls
   h["keys_moved"]:=nMoved
   h["mode"]:=cMode
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   RETURN

STATIC PROCEDURE Bridge(pVisible,pHidden,nCalls,nMoved,h)
   LOCAL nKey,nLevel,aStack:={}
   IF nCalls==0
      FOR nLevel:=0 TO 8
         AAdd(aStack,ProcName(nLevel))
      NEXT
      h["first_idle_stack"]:=aStack
   ENDIF
   ++nCalls
   hb_gtSelect(pVisible)
   nKey:=Inkey()
   hb_gtSelect(pHidden)
   IF nKey!=0
      ++nMoved
      hb_keyPut(nKey)
   ENDIF
   RETURN
