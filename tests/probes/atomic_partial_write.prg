// Launch only under a small file-size limit; existing original made by harness.
PROCEDURE Main(cTarget,cResult)
   LOCAL cInfo:="",lOk:=HBIDE_AtomicWriteFile(cTarget,Replicate("X",512),@cInfo)
   hb_MemoWrit(cResult,iif(lOk,"BAD","REFUSED")+";"+iif(hb_MemoRead(cTarget)=="ORIGINAL","INTACT","CHANGED")+";"+iif("recoverable at"$cInfo,"FALSE_PROMISE","NO_PROMISE"))
   IF lOk.or.hb_MemoRead(cTarget)!="ORIGINAL".or."recoverable at"$cInfo
      ErrorLevel(1)
   ENDIF
   RETURN
FUNCTION HBIDE_MsgAlert(cText)
   HB_SYMBOL_UNUSED(cText)
   RETURN 1
