// Boundary fixture for the old erase-and-retry fallback, not native Windows.
PROCEDURE Main(cResult)
   LOCAL cBackup:=cResult+".bak",cMissing:=cResult+".missing",h:={=>}
   hb_MemoWrit(cBackup,"OLD BACKUP")
   IF FRename(cMissing,cBackup)!=0
      FErase(cBackup)
      h["second_rename_failed"]:=FRename(cMissing,cBackup)!=0
   ENDIF
   h["old_backup_lost"]:=!hb_FileExists(cBackup)
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   RETURN
