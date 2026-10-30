PROCEDURE Main()
   LOCAL cOldPath:=GetEnv("PATH"),cRoot:=hb_cwd(),cDir:=cRoot+"path with spaces"+hb_ps()
   hb_DirCreate(cDir)
   hb_SetEnv("PATH",cDir)
   hb_MemoWrit(cDir+"sample.cld","Options Tab 11")
   Check(HBIDE_DbgScriptPath("sample")==cDir+"sample.cld","PATH default extension")
   Check(HBIDE_DbgScriptPath("sample.cld")==cDir+"sample.cld","PATH explicit extension")
   hb_MemoWrit("sample.cld","Options Tab 7")
   Check(HBIDE_DbgScriptPath("sample")=="sample.cld","cwd precedence")
   Check(Empty(HBIDE_DbgScriptPath("missing")),"missing")
   Check(Empty(HBIDE_DbgScriptPath("elsewhere"+hb_ps()+"sample")),"explicit dir no basename fallback")
   hb_MemoWrit(cDir+" leading.cld","Options Tab 9")
   Check(HBIDE_DbgScriptPath(" leading")==cDir+" leading.cld","leading filename preserved")
   hb_MemoWrit(cDir+"other.custom","Options Tab 3")
   Check(HBIDE_DbgScriptPath("other.custom")==cDir+"other.custom","explicit extension preserved")
   Check(Empty(HBIDE_DbgScriptPath(NIL)),"nil")
   Check(Empty(HBIDE_DbgScriptPath("")),"empty")
   hb_SetEnv("PATH",cOldPath)
   ? "PASS script lookup 9 checks"
   RETURN
STATIC PROCEDURE Check(lOk,cName)
   IF ! lOk
      ? "FAIL",cName
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
