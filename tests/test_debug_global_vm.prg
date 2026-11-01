// Current Harbour VM characterization. Not implemented GLOBAL acceptance.
PROCEDURE Main()
   LOCAL a := __dbgVMVarGList(), nPass := 0, nFail := 0
   Check( HB_ISARRAY(a), "VM global list returns array", @nPass, @nFail )
   Check( Empty(a), "current Harbour VM global list is empty", @nPass, @nFail )
   Check( __dbgVMVarGGet(0,1) == NIL, "current Harbour VM global get has no value", @nPass, @nFail )
   ? "TOTAL",nPass,"PASS",nFail,"FAIL"
   ErrorLevel(iif(nFail==0,0,1))
RETURN
STATIC PROCEDURE Check(lOk,cName,nPass,nFail)
   IF lOk
      nPass++
      ? "PASS",cName
   ELSE
      nFail++
      ? "FAIL:",cName
   ENDIF
RETURN
