PROCEDURE Main()
   LOCAL cInfo:=""
   hb_MemoWrit("source","CURRENT DISK")
   hb_MemoWrit("source.bak","OLD BACKUP")
   Check(HBIDE_BackupFile("source",@cInfo),"backup succeeds")
   Check(hb_MemoRead("source.bak")=="CURRENT DISK","backup bytes exact")
   Check(hb_MemoRead("source")=="CURRENT DISK","source untouched")
   Check(!HBIDE_BackupFile("missing",@cInfo),"missing refuses")
   FErase("source.bak")
   hb_DirCreate("source.bak")
   hb_MemoWrit("source.bak/sentinel","PRECIOUS")
   Check(!HBIDE_BackupFile("source",@cInfo),"backup directory promotion refuses")
   Check(hb_MemoRead("source.bak/sentinel")=="PRECIOUS","directory preserved")
   Check("new content kept at"$cInfo,"complete backup recovery named")
#if defined(__PLATFORM__UNIX)
   hb_MemoWrit("denied","DISK")
   hb_MemoWrit("denied.bak","PRECIOUS BACKUP")
   hb_Run("chmod 000 denied")
   Check(!HBIDE_BackupFile("denied",@cInfo),"unreadable source refuses")
   Check(hb_MemoRead("denied.bak")=="PRECIOUS BACKUP","unreadable preserves backup")
   hb_Run("chmod 600 denied")
#endif
   ? "PASS backup refusal and bytes"
   RETURN
STATIC PROCEDURE Check(lOk,cName)
   IF !lOk
      ? "FAIL",cName
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
FUNCTION HBIDE_MsgAlert(cText)
   HB_SYMBOL_UNUSED(cText)
   RETURN 1
