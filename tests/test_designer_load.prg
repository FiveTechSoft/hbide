#include "hbclass.ch"
PROCEDURE Main()
   LOCAL o:=LoadDesigner():New(LoadHost():New()),h,cJson,cBad
   SetMode(25,80)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   o:cFileName:="current.json"
   o:cDlgCaption:="Current unsaved"
   o:lDirty:=.T.
   o:aUndo:={DsnSnapshot(o)}
   h:=DsnSnapshot(o)
   FOR EACH cBad IN {"not JSON",'{"controls":{}}','{"controls":[]','{"controls":[],"caption":"BROKEN"'}
      hb_MemoWrit("bad.json",cBad)
      o:cNext:="bad.json"
      o:LoadJson()
      Check(DsnSnapEqual(h,DsnSnapshot(o)),"invalid model unchanged")
      Check(o:cFileName=="current.json".and.o:lDirty.and.Len(o:aUndo)==1,"invalid identity dirty history unchanged")
   NEXT
   o:cNext:="missing.json"
   o:LoadJson()
   Check(DsnSnapEqual(h,DsnSnapshot(o)).and.o:cFileName=="current.json".and.o:lDirty.and.Len(o:aUndo)==1,"missing retains model identity dirty history")
   hb_MemoWrit("unreadable.json",hb_jsonEncode({"controls"=>{},"caption"=>"DENIED"}))
   hb_Run("chmod 000 unreadable.json")
   o:cNext:="unreadable.json"
   o:LoadJson()
   hb_Run("chmod 600 unreadable.json")
   Check(DsnSnapEqual(h,DsnSnapshot(o)).and.o:cFileName=="current.json".and.o:lDirty.and.Len(o:aUndo)==1,"unreadable retains model identity dirty history")
   o:cNext:="bad.json"
   cJson:=hb_jsonEncode({"controls"=>{},"caption"=>"LOADED"})
   hb_MemoWrit("bad.json",cJson+"TRAILING CORRUPTION")
   o:LoadJson()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"trailing corruption rejected")
   hb_MemoWrit("bad.json",cJson+Chr(0))
   o:LoadJson()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"NUL trailing byte rejected")
   hb_MemoWrit("bad.json",cJson+Chr(13)+Chr(10)+Chr(9)+" ")
   o:LoadJson()
   Check(o:cDlgCaption=="LOADED".and.o:cFileName=="bad.json".and.!o:lDirty,"whitespace suffix accepted")
   o:Undo()
   Check(DsnSnapEqual(h,DsnSnapshot(o)),"undo restores previous model")
   o:Redo()
   Check(o:cDlgCaption=="LOADED","redo restores loaded model")
   hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{123,{"type"=>"NOT_A_CONTROL"}},"caption"=>"SANITIZED"}))
   o:LoadJson()
   Check(Empty(o:aControls).and.Empty(o:cFileName).and.o:lDirty,"skipped invalid controls require new Save As")
   Check("invalid entries skipped"$o:cHint,"skipped entries reported")
   ? "PASS designer load refusals and undo/redo"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
CLASS LoadDesigner FROM HbDesigner
   DATA cNext
   METHOD SelectFileName(cTitle,cDefault) INLINE ::cNext
ENDCLASS
CLASS LoadHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
