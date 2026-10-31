#include "hbclass.ch"
STATIC s_nChecks:=0
PROCEDURE Main()
   LOCAL o,cType,cKey,hBefore,hPasted,hCut,hCopied,cName,cOld
   SetMode(40,120)
   FOR EACH cType IN {"say","get","checkbox","button","radiogroup","listbox","combobox"}
      o:=HbDesigner():New(ClipHost():New())
      o:oWnd:=HBWindow():Dialog("Clipboard",60,20,"W+/W")
      o:nDlgWidth:=60;o:nDlgHeight:=20;o:FitWindow()
      o:aControls:={DsnNewControl(cType,{})};o:nSelected:=1
      o:aControls[1,"row"]:=1;o:aControls[1,"col"]:=2
      IF "variable"$o:aControls[1]
         o:aControls[1,"variable"]:=Upper(o:aControls[1,"variable"])
      ENDIF
      IF "items"$o:aControls[1]
         o:aControls[1,"items"]:="Alpha,Quoted 'item',Omega"
      ENDIF
      IF "caption"$o:aControls[1]
         o:aControls[1,"caption"]:="Quoted 'caption'"
      ENDIF
      IF cType!="say"
         FOR EACH cKey IN {"when","valid","focus","state"}
            o:aControls[1,cKey]:="Handler_"+cKey+"( 'quoted', .T. )"
         NEXT
      ENDIF
      hBefore:=DsnSnapshot(o)
      o:CopySelected()
      Check(DsnSnapEqual(hBefore,DsnSnapshot(o)),cType+" Copy leaves entire model unchanged")
      Check(!o:lDirty.and.Empty(o:aUndo),cType+" Copy does not dirty or push history")
      hCopied:=DsnCloneValue(o:oClipboard)
      o:PasteClipboard()
      Check(Len(o:aControls)==2.and.o:nSelected==2,cType+" Paste appends and selects")
      FOR EACH cKey IN hb_HKeys(hCopied)
         IF !(cKey$"row|col|variable")
            Check(hb_jsonEncode(o:aControls[2,cKey])==hb_jsonEncode(hCopied[cKey]),cType+" Paste preserves "+cKey)
         ENDIF
      NEXT
      IF "variable"$hCopied
         Check(Upper(o:aControls[1,"variable"])!=Upper(o:aControls[2,"variable"]),cType+" Paste binding unique ignoring case")
      ENDIF
      Check(o:aControls[2,"row"]==2.and.o:aControls[2,"col"]==3,cType+" Paste exact offset")
      hPasted:=DsnSnapshot(o)
      o:Undo();Check(DsnSnapEqual(hBefore,DsnSnapshot(o)),cType+" Undo Paste full snapshot")
      o:Redo();Check(DsnSnapEqual(hPasted,DsnSnapshot(o)),cType+" Redo Paste full snapshot")
      o:CutSelected();hCut:=DsnSnapshot(o)
      Check(Len(o:aControls)==1.and.hb_jsonEncode(o:aControls[1])==hb_jsonEncode(hBefore["controls"][1]),cType+" Cut only selected clone")
      o:Undo();Check(DsnSnapEqual(hPasted,DsnSnapshot(o)),cType+" Undo Cut full snapshot")
      o:Redo();Check(DsnSnapEqual(hCut,DsnSnapshot(o)),cType+" Redo Cut full snapshot")
      o:Undo();o:CopySelected()
      cKey:=If("items"$o:aControls[2],"items",If("caption"$o:aControls[2],"caption","when"))
      cOld:=o:aControls[2,cKey]
      o:aControls[2,cKey]:="Changed source after Copy"
      o:PasteClipboard()
      Check(o:aControls[3,cKey]==cOld.and.o:aControls[2,cKey]=="Changed source after Copy",cType+" clipboard detached after source mutation")
      Check(Empty(o:aRedo),cType+" new Paste clears redo")
      IF "variable"$o:aControls[1]
         cName:=Upper(o:aControls[3,"variable"])
         Check(cName!=Upper(o:aControls[1,"variable"]).and.cName!=Upper(o:aControls[2,"variable"]),cType+" third binding unique ignoring case")
      ENDIF
   NEXT
   ? "TOTAL",s_nChecks,"PASS 0 FAIL"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   s_nChecks++
   RETURN
CLASS ClipHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
