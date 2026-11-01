// Standalone visual fixture. Not the IDE startup path or end-to-end interaction.
#include "hbclass.ch"
#include "setcurs.ch"
PROCEDURE Main(cRows,cCols,cState,cReceipt)
   LOCAL o,nRows:=Val(cRows),nCols:=Val(cCols)
   SetMode(nRows,nCols)
   SetCursor(SC_NONE)
   IF MaxRow()!=nRows-1 .or. MaxCol()!=nCols-1
      ErrorLevel(2)
      RETURN
   ENDIF
   o:=HbDesigner():New(VisualPaintHost():New())
   o:oWnd:=HBWindow():Dialog("Inspector repaint fixture",60,20,"W+/W")
   o:FitWindow()
   o:SuspendUI() // no designer Activate loop: stop the raw HBWindow mouse idle
   o:aControls:={DsnNewControl("combobox",{})}
   o:nSelected:=1
   o:lInspector:=.T.
   o:Redraw()
   IF cState=="deselected"
      o:nSelected:=0
      o:DrawInspector()
   ENDIF
   hb_MemoWrit(cReceipt,hb_jsonEncode({"rows"=>MaxRow()+1,"cols"=>MaxCol()+1,"state"=>cState,"inspector"=>o:InspRect(),"handle"=>o:ResizeHandlePos()}))
   Inkey(0)
   RETURN
CLASS VisualPaintHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE hb_Scroll(0,0,MaxRow(),MaxCol(),,,"W/B")
ENDCLASS
