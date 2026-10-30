#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main(cMode)
   LOCAL cInfo:="",cFile:="dsn-write.json",cBytes:='{"controls":[]}',o,cResult
   o:=HbDesigner():New(WriteHost():New())
   SetMode(25,80)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   o:lDirty:=.T.
   IF cMode=="partial"
      o:cFileName:="partial.json"
      o:cDlgName:="partial"
      hb_keyPut(K_ENTER)
      o:SaveJson(.F.)
      Check(o:lDirty,"partial SaveJson keeps dirty")
      Check(hb_MemoRead("partial.json")=="ORIGINAL","partial JSON original intact")
      hb_keyPut(K_ENTER);hb_keyPut(K_ENTER)
      cResult:=o:GeneratePrg()
      Check(cResult==NIL,"partial GeneratePrg refuses")
      Check(hb_MemoRead("partial.prg")=="ORIGINAL","partial PRG original intact")
      ? "PASS actual SaveJson/GeneratePrg partial writes"
      RETURN
   ENDIF
   hb_MemoWrit(cFile,"ORIGINAL")
   Check(DsnSafeMemoWrit(cFile,cBytes,@cInfo),"JSON replaces successfully")
   Check(hb_MemoRead(cFile)==cBytes,"bytes exact")
   hb_DirCreate("blocked.json")
   hb_MemoWrit("blocked.json/sentinel","PRECIOUS")
   Check(!DsnSafeMemoWrit("blocked.json",cBytes,@cInfo),"directory refuses")
   Check(hb_MemoRead("blocked.json/sentinel")=="PRECIOUS","directory child preserved")
   Check("new content kept at"$cInfo,"complete recovery named")
   Check(!DsnSafeMemoWrit("absent-parent/x.json",cBytes,@cInfo),"missing parent refuses")
   Check(!Empty(cInfo),"failure explains")
   ? "PASS designer safe writes bytes and refusal"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN

CLASS WriteHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
