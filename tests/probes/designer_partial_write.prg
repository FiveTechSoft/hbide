// Harness precreates target then applies RLIMIT_FSIZE64 and ignores SIGXFSZ.
PROCEDURE Main(cTarget,cResult)
   LOCAL lOk:=DsnSafeMemoWrit(cTarget,Replicate("X",512))
   hb_MemoWrit(cResult,iif(lOk,"BAD","REFUSED")+";"+iif(hb_MemoRead(cTarget)=="ORIGINAL","INTACT","CHANGED"))
   IF lOk.or.hb_MemoRead(cTarget)!="ORIGINAL"
      ErrorLevel(1)
   ENDIF
   RETURN
