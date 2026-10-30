#include "hbclass.ch"
PROCEDURE Main()
   LOCAL o:=LoadDesigner():New(LoadHost():New()),h,cJson,cBad,cType,cEvent
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
   o:cDlgClrFocus:="Y+/R"
   hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{},"caption"=>"LEGACY"}))
   o:LoadJson()
   Check(o:cDlgClrFocus==HbDesigner():New(NIL):cDlgClrFocus,"legacy load uses default focus not prior design")
   o:Undo()
   Check(o:cDlgClrFocus=="Y+/R","undo legacy load restores prior focus")
   o:Redo()
   Check(o:cDlgClrFocus==HbDesigner():New(NIL):cDlgClrFocus,"redo legacy load restores default focus")
   hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{},"colorfocus"=>"G+/B"}))
   o:LoadJson()
   Check(o:cDlgClrFocus=="G+/B","explicit focus preserved")
   hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{},"colorfocus"=>""}))
   o:LoadJson()
   Check(o:cDlgClrFocus==HbDesigner():New(NIL):cDlgClrFocus,"empty focus defaults independently")
   FOR EACH cType IN {"radiogroup","listbox","combobox"}
      hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{{"type"=>cType,"variable"=>123}}}))
      o:LoadJson()
      Check(Len(o:aControls)==1.and.HB_IsString(o:aControls[1,"items"]),"actual Load tolerates missing items")
      Check(HB_IsString(o:aControls[1,"variable"]),"actual Load repairs invalid variable type")
   NEXT
   FOR EACH cEvent IN {"when","valid","focus","state"}
      hb_MemoWrit("bad.json",hb_jsonEncode({"controls"=>{{"type"=>"button",cEvent=>123}}}))
      o:LoadJson()
      Check(o:aControls[1,cEvent]=="","actual Load clears nontext event")
      Check(HB_IsString(DsnGenCode(DsnBuildModel(o))),"actual loaded event-safe model generates")
   NEXT
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
