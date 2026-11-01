#include "hbclass.ch"
PROCEDURE Main()
   LOCAL o:=HbDesigner():New(PaintHost():New()), cIncremental,cFresh,aOld,aNew
   SetMode(40,120)
   o:oWnd:=HBWindow():Dialog("Fixture",60,20,"W+/W")
   o:FitWindow()
   o:aControls:={DsnNewControl("combobox",{})}
   o:nSelected:=1
   o:lInspector:=.T.
   o:Redraw()
   aOld:=o:InspRect()
   o:nSelected:=0
   o:DrawInspector()
   aNew:=o:InspRect()
   Check(aNew[3]<aOld[3],"fixture inspector shrinks")
   cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
   o:Redraw()
   cFresh:=SaveScreen(0,0,MaxRow(),MaxCol())
   Check(cIncremental==cFresh,"selection inspector repaint equals clean repaint")
   ? "PASS inspector repaint"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
CLASS PaintHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE hb_Scroll(0,0,MaxRow(),MaxCol(),,,"W/B")
ENDCLASS
