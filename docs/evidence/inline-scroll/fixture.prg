#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PropHost():New()),h
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Test",50,16,"W+/W")
   o:FitWindow()
   CLS
   o:Redraw()
   o:aControls:={DsnNewControl("combobox",{})}
   o:aControls[1,"when"]:="Start_"+Replicate("long_expression_",8)+"_TAIL"
   o:nSelected:=1
   o:nInspCol:=85
   o:lInspector:=.T.
   o:Redraw()
   o:nInspField:=AScan(o:InspFields(),{|f|f[2]=="when"})
   o:InspEdit()
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
