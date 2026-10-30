#include "hbclass.ch"
#include "inkey.ch"
#include "set.ch"
PROCEDURE Main(cMode)
   LOCAL cInfo:="",cFile:="dsn-write.json",cBytes:='{"controls":[]}',o,cResult,i,aFiles,hLoaded,cLong,hBefore
   o:=WriteDesigner():New(WriteHost():New())
   SetMode(25,80)
   Set(_SET_TYPEAHEAD,512)
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
   o:cFileName:="original.json"
   o:cNext:=NIL
   hb_keyPut(K_CTRL_Y)
   FOR i:=1 TO Len("absent/actual.json")
      hb_keyPut(Asc(SubStr("absent/actual.json",i,1)))
   NEXT
   hb_keyPut(K_TAB);hb_keyPut(K_ENTER);hb_keyPut(K_ENTER)
   o:SaveJson(.T.)
   Check(o:cFileName=="original.json".and.o:lDirty,"actual picker failed Save As retains identity/dirty")
   o:cFileName:="original.json"
   o:cNext:="no-parent/new.json"
   hb_keyPut(K_ENTER)
   o:SaveJson(.T.)
   Check(o:cFileName=="original.json","failed Save As retains identity")
   Check(o:lDirty,"failed Save As retains dirty")
   o:SaveJson(.F.)
   Check(File("original.json"),"next Save writes original identity")
   Check(!o:lDirty,"successful Save clears dirty")
   o:cNext:="renamed.json"
   o:SaveJson(.T.)
   Check(o:cFileName=="renamed.json".and.File("renamed.json"),"successful Save As commits identity")
   // Exercise native picker plus actual write/load, not cNext shortcut.
   cLong:="folder with spaces/"+Replicate("segment",8)+".json"
   hb_DirCreate("folder with spaces")
   o:cNext:=NIL
   o:aControls:={DsnNewControl("get",{})}
   o:aControls[1,"caption"]:="retained synthetic payload"
   o:lDirty:=.T.
   hb_keyPut(K_CTRL_Y);hb_keyPut(cLong);hb_keyPut(K_TAB);hb_keyPut(K_SPACE)
   o:SaveJson(.T.)
   Check(o:cFileName==cLong.and.File(cLong).and.!o:lDirty,"long native SaveAs commits full path and clears dirty")
   Check(!File(Left(cLong,35)),"no truncated path destination created")
   hb_jsonDecode(hb_MemoRead(cLong),@hLoaded)
   Check(DsnValidModel(hLoaded),"long native SaveAs writes valid model")
   hBefore:=DsnBuildModel(o)
   o:aControls:={};o:lDirty:=.F.
   // Native picker starts with full long current path; accept without edits.
   hb_keyPut(K_TAB);hb_keyPut(K_SPACE)
   o:LoadJson()
   Check(o:cFileName==cLong.and.!o:lDirty,"long native Load commits full identity")
   Check(hb_jsonEncode(DsnBuildModel(o))==hb_jsonEncode(hBefore),"long native SaveLoad exact model")
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
   o:cFileName:="blocked.json"
   o:lDirty:=.T.
   hb_keyPut(K_ENTER)
   o:SaveJson(.F.)
   Check(o:lDirty.and.o:cFileName=="blocked.json","blocked actual Save keeps design identity/dirty")
   Check(hb_MemoRead("blocked.json/sentinel")=="PRECIOUS","actual Save preserves directory child")
   aFiles:=Directory("blocked.json.tmp-*")
   Check(Len(aFiles)>0,"actual Save retains complete temporary JSON")
   hb_jsonDecode(hb_MemoRead(aFiles[Len(aFiles),1]),@hLoaded)
   Check(DsnValidModel(hLoaded),"retained actual JSON is valid model")
   hb_DirCreate("blocked.prg")
   hb_MemoWrit("blocked.prg/sentinel","PRECIOUS")
   o:cDlgName:="blocked"
   hb_keyPut(K_ENTER)
   cResult:=o:GeneratePrg()
   Check(cResult==NIL,"blocked actual Generate refuses")
   Check(hb_MemoRead("blocked.prg/sentinel")=="PRECIOUS","actual Generate preserves directory child")
   aFiles:=Directory("blocked.prg.tmp-*")
   Check(Len(aFiles)==1,"actual Generate retains complete temporary PRG")
   Check(hb_MemoRead(aFiles[1,1])==DsnGenCode(DsnBuildModel(o)),"retained PRG byte exact")
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

CLASS WriteDesigner FROM HbDesigner
   DATA cNext
   METHOD SelectFileName(cTitle,cDefault) INLINE If(::cNext==NIL,::Super:SelectFileName(cTitle,cDefault),::cNext)
ENDCLASS
