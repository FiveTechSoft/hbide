#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   CLS
   o:Redraw()
   o:cDlgClrFocus:="Y+/R"
   o:ApplyModel({"controls"=>{DsnNewControl("get",{})},"caption"=>"Legacy default focus"})
   o:oWnd:cCaption:=" Legacy default focus "
   o:nInspCol:=85
   o:FitWindow()
   CLS
   o:lInspector:=.T.
   o:nSelected:=0
   o:Redraw()
   Inkey(5)
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
CLASS PropHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE NIL
ENDCLASS
