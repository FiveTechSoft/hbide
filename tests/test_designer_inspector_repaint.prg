#include "hbclass.ch"
PROCEDURE Main()
   LOCAL o,cIncremental,cFresh,aOld,aNew,aMode,cFrom,cTo,nFrom,nTo
   LOCAL aTypes:={"say","get","button","checkbox","radiogroup","listbox","combobox"}
   LOCAL nTransitions:=0,nMoves:=0
   FOR EACH aMode IN {{40,120},{25,80}}
      SetMode(aMode[1],aMode[2])
      Check(MaxRow()==aMode[1]-1 .and. MaxCol()==aMode[2]-1,"model mode exact")
      o:=HbDesigner():New(PaintHost():New())
      o:oWnd:=HBWindow():Dialog("Fixture",60,20,"W+/W")
      o:FitWindow()
      o:lInspector:=.T.
      o:aControls:={}
      FOR EACH cFrom IN aTypes
         AAdd(o:aControls,DsnNewControl(cFrom,{}))
      NEXT
      FOR nFrom:=0 TO Len(aTypes)
         FOR nTo:=0 TO Len(aTypes)
            o:nSelected:=nFrom
            aOld:=o:InspRect()
            o:nSelected:=nTo
            aNew:=o:InspRect()
            IF aOld[3]==aNew[3]
               LOOP // Same-height selection uses caller Redraw, not this cache path.
            ENDIF
            o:nSelected:=nFrom
            o:Redraw()
            o:nSelected:=nTo
            o:DrawInspector()
            cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
            o:Redraw()
            cFresh:=SaveScreen(0,0,MaxRow(),MaxCol())
            Check(cIncremental==cFresh,"changed-height selection repaint equals clean repaint")
            nTransitions++
         NEXT
      NEXT
      FOR nFrom:=0 TO Len(aTypes)
         o:nSelected:=nFrom
         o:nInspRow:=2
         o:nInspCol:=86
         o:Redraw()
         o:nInspRow:=6
         o:nInspCol:=5
         o:DrawInspector()
         cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
         o:Redraw()
         Check(cIncremental==SaveScreen(0,0,MaxRow(),MaxCol()),"moved panel restores underlay")
         nMoves++
      NEXT
   NEXT
   ? "PASS inspector repaint",nTransitions,"height transitions",nMoves,"panel moves"
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
