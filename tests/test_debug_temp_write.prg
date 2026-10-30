PROCEDURE Main()
   LOCAL cFile:=hb_cwd()+"owned.tmp",cLink:=hb_cwd()+"linked.tmp"
   Check(HBIDE_DbgWriteNew(cFile,"first"),"new complete bytes")
   Check(hb_MemoRead(cFile)=="first","exact content")
   Check(!HBIDE_DbgWriteNew(cFile,"second"),"existing refuses")
   Check(hb_MemoRead(cFile)=="first","existing preserved")
   Check(HBIDE_DbgWriteNew("empty.tmp",""),"empty valid")
   Check(!HBIDE_DbgWriteNew("no-directory/file.tmp","x"),"bad parent refuses")
#if defined( __PLATFORM__UNIX )
   hb_run('ln -s "'+cFile+'" "'+cLink+'"')
   Check(!HBIDE_DbgWriteNew(cLink,"changed"),"symlink refuses")
   Check(hb_MemoRead(cFile)=="first","symlink target preserved")
   FErase(cLink)
#endif
   FErase(cFile)
   FErase("empty.tmp")
   ? "PASS debug temp writes"
   RETURN
STATIC PROCEDURE Check(lOk,cName)
   IF ! lOk
      ? "FAIL",cName
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
